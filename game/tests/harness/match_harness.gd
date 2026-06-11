##
## MatchHarness — deterministic mini-match fixture for GUT integration tests.
##
## Per docs/TESTING_CONTRACT.md §3.1 and docs/SIMULATION_CONTRACT.md §6.1.
##
## Usage:
##   var h := MatchHarnessScript.new(42, &"empty")
##   h.advance_ticks(30)
##   assert_almost_eq(h.get_farr(), 50.0, 1e-4)
##   h.teardown()
##
## v2 (Wave C3, tests-ARCH-1 — closes the Phase-0 debt):
##   - start_match/teardown now reset ALL 13 resettable autoloads (inventory
##     from `grep 'func reset' game/scripts/autoload/` — see
##     _reset_all_autoloads). Phase-0 covered only 5 of them; the other 8
##     were the per-test boilerplate every integration test re-derived.
##   - spawn_unit / spawn_building are REAL: they instantiate the canonical
##     unit/building scenes (same pattern as test_phase_3_throne_deposit /
##     test_phase_3_building_production: set team + position BEFORE
##     add_child) under a harness-owned spawn root in the live SceneTree.
##   - snapshot() reads the LIVE autoloads (ResourceSystem fixed-point
##     stores, &"units" group census) instead of the Phase-0 harness-local
##     dicts that stopped being wired to anything when ResourceSystem
##     shipped in Phase 3.
##   - Resource state (get_resources/set_resources/scenario overrides) is
##     backed by ResourceSystem; the harness-local _coin/_grain dicts are
##     deleted. Scenario keys NOT set by a scenario keep the BalanceData
##     starting values ResourceSystem.reset() loads (SSOT — the old 150/50
##     literals duplicated balance.tres).
##
## The harness never calls _physics_process. All ticks advance via
## SimClock._test_run_tick(), which shares the exact _run_tick() body the
## live driver uses — guaranteed by Sim Contract §6.1.

# No class_name — avoid the global registry race documented in
# docs/ARCHITECTURE.md §6 v0.4.0. GUT collects test scripts before the
# class_name registry is fully populated; a class_name on this RefCounted
# would cause "Identifier not found: MatchHarness" errors in test files
# that try to use the class. Callers use:
#   const _MatchHarnessScript := preload("res://tests/harness/match_harness.gd")
#   var h := _MatchHarnessScript.create(seed, scenario)
extends RefCounted

const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")

# Pin balance.tres in the ResourceCache for the whole test process. v2's
# _reset_all_autoloads() calls FarrDrainDispatcher.reset() (which drops its
# lazily-cached BalanceData ref) on every start_match AND teardown; without a
# persistent holder, the ResourceCache evicts balance.tres and every
# subsequent load() — one per Unit._ready via _apply_balance_data_defaults,
# one per ResourceSystem.reset(), etc. — re-parses the ~700-line .tres from
# text, which empirically dominates suite runtime. This const is held by the
# script for the process lifetime, so every load(PATH_BALANCE_DATA) stays a
# cache hit. (Path literal mirrors Constants.PATH_BALANCE_DATA — preload
# requires a constant expression.)
const _BalanceDataPin: Resource = preload("res://data/balance.tres")

# Unit + Building base scripts — for the static reset_id_counter() calls at
# match start. Every match's first unit must be unit_id 1 AND every match's
# first building must be building_id 1, or two consecutive in-process runs
# diverge on id-keyed lookups — determinism prerequisite, Sim Contract §6.2.
# (Unit and Building each own a distinct id counter; both reset. The TEST-4
# determinism test originally failed precisely because the Building counter
# drifted across runs, shifting which BUG-H8 unit-vs-building id collisions
# occurred.)
const _UnitScript: Script = preload("res://scripts/units/unit.gd")
const _BuildingScript: Script = preload("res://scripts/world/buildings/building.gd")

# Spawn catalogs — StringName type/kind → scene path. Scene filenames match
# the unit_type / kind StringNames 1:1 (e.g. &"turan_piyade" →
# turan_piyade.tscn), but the explicit dictionary keeps the contract visible
# and makes an unknown key fail LOUDLY (§9.L9) instead of producing a
# load(null) crash deep in the engine.
const _UNIT_SCENE_PATHS: Dictionary = {
	&"kargar": "res://scenes/units/kargar.tscn",
	&"piyade": "res://scenes/units/piyade.tscn",
	&"kamandar": "res://scenes/units/kamandar.tscn",
	&"savar": "res://scenes/units/savar.tscn",
	&"asb_savar_kamandar": "res://scenes/units/asb_savar_kamandar.tscn",
	&"turan_piyade": "res://scenes/units/turan_piyade.tscn",
	&"turan_kamandar": "res://scenes/units/turan_kamandar.tscn",
	&"turan_savar": "res://scenes/units/turan_savar.tscn",
	&"turan_asb_savar": "res://scenes/units/turan_asb_savar.tscn",
}

const _BUILDING_SCENE_PATHS: Dictionary = {
	&"throne": "res://scenes/world/buildings/throne.tscn",
	&"khaneh": "res://scenes/world/buildings/khaneh.tscn",
	&"mazraeh": "res://scenes/world/buildings/mazraeh.tscn",
	&"madan": "res://scenes/world/buildings/madan.tscn",
	&"sarbaz_khaneh": "res://scenes/world/buildings/sarbaz_khaneh.tscn",
	&"sowari_khaneh": "res://scenes/world/buildings/sowari_khaneh.tscn",
	&"tirandazi": "res://scenes/world/buildings/tirandazi.tscn",
	&"atashkadeh": "res://scenes/world/buildings/atashkadeh.tscn",
}

# === State ==================================================================

var _seed: int
var _scenario: StringName

# Tracked entities — populated by spawn_unit / spawn_building.
# Keys: the entity's unit_id (units and buildings each own an id space).
var _units: Dictionary = {}     # unit_id -> Node
var _buildings: Dictionary = {} # building unit_id -> Node

# Harness-owned SceneTree parent for everything spawn_unit / spawn_building
# create. Created lazily on first spawn, freed (synchronously — Pitfall #17)
# in teardown so spawned entities' _exit_tree deregistrations (fog handles,
# sim_phase disconnects) run BEFORE the next harness's start_match.
var _spawn_root: Node3D = null

# The injected MockPathScheduler — cleared on teardown.
var _mock_scheduler: Variant = null


# === Construction ==========================================================

## Initialize a new match. Call on a freshly-instantiated harness.
##
## Callers create the harness via preloaded script ref, then call start_match:
##
##   const _H := preload("res://tests/harness/match_harness.gd")
##   var h := _H.new()
##   h.start_match(seed=42, scenario=&"empty")
##   h.advance_ticks(30)
##   h.teardown()
##
## The Testing Contract §3.1 specifies MatchHarness.new(seed, scenario) as a
## static factory. We cannot use a static factory because it would need to
## preload itself (circular), and class_name is removed for the registry-race
## workaround. start_match() on a freshly .new()'d instance is equivalent.
##
## seed: deterministic seed for the match. v2 seeds the global RNG (mirrors
##   HeadlessMatchRunner._ready's §9.D9 Q3 discipline — zero production
##   randf/randi call-sites exist per L3 lint, but if one ever lands, the
##   seeded RNG keeps same-seed runs reproducible).
##   TODO phase-future: GameRNG.seed_match(seed) once that autoload ships.
## scenario: StringName key into Scenarios.CATALOG (scenarios.gd).
func start_match(seed: int = 0, scenario: StringName = &"empty") -> void:
	_seed = seed
	_scenario = scenario
	_setup()


func _setup() -> void:
	# Reset all resettable autoloads to pristine state (v2: all 13, not 5).
	_reset_all_autoloads()

	# §9.D9 Q3 RNG discipline — see start_match docstring.
	seed(_seed)

	# Inject MockPathScheduler so no NavigationServer3D contact occurs.
	# MovementComponent resolves its scheduler from PathSchedulerService at
	# _ready, so the injection must precede any spawn_unit call.
	_mock_scheduler = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock_scheduler)

	# Apply scenario resource overrides to the LIVE ResourceSystem. Keys the
	# scenario does not set keep the BalanceData starting values that
	# ResourceSystem.reset() just loaded.
	var scenario_data: Dictionary = _load_scenario(_scenario)
	_apply_scenario_resources(scenario_data)

	# Set Farr if the scenario overrides it.
	var farr_override: Variant = scenario_data.get("farr", null)
	if farr_override != null:
		_run_one_tick_with_farr_set(float(farr_override))

	# Start the match in GameState.
	GameState.start_match(Constants.TEAM_IRAN)


## Release all harness-held state. Call in GUT after_each.
func teardown() -> void:
	# Free harness-spawned nodes FIRST, so their _exit_tree deregistrations
	# (FogSystem handles, sim_phase disconnects, SpatialIndex agents) run
	# against still-live autoload state. Synchronous free(), NOT queue_free:
	# Pitfall #17 — queue_free + await leaks _physics_process ticks into
	# SimClock, and a queue_freed unit stays in the tree (and in &"units",
	# still ticking on sim_phase) until a frame boundary, which a
	# back-to-back start_match in the same test body never reaches.
	# Units already pending deletion (death path queue_free.call_deferred)
	# are freed here too; the deferred call validity-checks at flush.
	if _spawn_root != null and is_instance_valid(_spawn_root):
		_spawn_root.free()
	_spawn_root = null
	_units.clear()
	_buildings.clear()

	if _mock_scheduler != null:
		_mock_scheduler.clear_log()
	_mock_scheduler = null

	# Reset all autoloads (PathSchedulerService.reset() reverts to a fresh
	# production NavigationAgentPathScheduler — drops the mock).
	_reset_all_autoloads()


# === Core simulation ========================================================

## Advance the simulation by n ticks using the exact same _run_tick() path as
## the live _physics_process driver (Sim Contract §6.1). EventBus.sim_phase
## signals drive all registered phase coordinators — no special harness paths.
func advance_ticks(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# === State queries ===========================================================

## Current Farr value as float (FarrSystem.value_farr).
func get_farr() -> float:
	return FarrSystem.value_farr


## Current resources for a team. Returns {coin: int, grain: int} in whole
## resource units (v2: read from ResourceSystem's fixed-point store; integer
## division truncates sub-unit fractions — tests needing exact values read
## ResourceSystem.coin_x100_for / grain_x100_for directly).
func get_resources(team: int) -> Dictionary:
	return {
		"coin": ResourceSystem.coin_x100_for(team) / 100,
		"grain": ResourceSystem.grain_x100_for(team) / 100,
	}


## Look up a unit by its integer unit_id. Returns null if not found or freed.
func get_unit(unit_id: int) -> Node:
	var node: Variant = _units.get(unit_id, null)
	if node == null:
		return null
	if not is_instance_valid(node):
		_units.erase(unit_id)
		return null
	return node


## Flat primitive-only snapshot of all observable state.
## GDScript == compares nested Dicts by reference — nested Dicts would silently
## break the determinism regression test. Every value here is int, float, or
## String. Per TESTING_CONTRACT.md §3.1.
##
## v2 (tests-ARCH-1 dead-field fix): resources read ResourceSystem's
## fixed-point store (the Phase-0 harness-local dicts tracked nothing once
## ResourceSystem shipped); unit counts census the canonical &"units"
## SceneTree group (the Unit-discovery primitive per Wave 3-Sim c05ba77)
## so units spawned by ANY path — harness, test-local add_child, building
## production — are counted. Note: a unit in &"dying" that has queue_freed
## but not yet left the tree still counts (it is still observable sim state).
func snapshot() -> Dictionary:
	var unit_count_iran: int = 0
	var unit_count_turan: int = 0
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	for node: Node in st.get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		var team: Variant = node.get(&"team")
		if team == Constants.TEAM_IRAN:
			unit_count_iran += 1
		elif team == Constants.TEAM_TURAN:
			unit_count_turan += 1

	return {
		"tick": SimClock.tick,
		"farr": FarrSystem.value_farr,
		"coin_iran": ResourceSystem.coin_x100_for(Constants.TEAM_IRAN) / 100,
		"grain_iran": ResourceSystem.grain_x100_for(Constants.TEAM_IRAN) / 100,
		"coin_turan": ResourceSystem.coin_x100_for(Constants.TEAM_TURAN) / 100,
		"grain_turan": ResourceSystem.grain_x100_for(Constants.TEAM_TURAN) / 100,
		"unit_count_iran": unit_count_iran,
		"unit_count_turan": unit_count_turan,
	}


# === State setters ===========================================================

## Override Farr directly without going through apply_farr_change logic.
## Per Testing Contract §3.1 (_test_set_farr semantics):
##   "bypasses apply_farr_change() (test-only escape), but MUST emit
##    EventBus.farr_changed(...) so F2 debug overlay and any other subscribers
##    see the synthetic mutation."
##
## This is an off-tick write — the method does NOT drive an internal tick.
## The Testing Contract's "must be called inside advance_ticks" refers to the
## worked example (§3.3), not a hard requirement for this method. The FarrSystem
## comment "emitted signal reports what the meter actually moved" applies to
## apply_farr_change; _test_set_farr is the escape hatch that bypasses the
## on-tick assert entirely. The same pattern is used by FarrSystem.reset() which
## also writes _farr_x100 off-tick (documented in its source comment).
func _test_set_farr(value: float) -> void:
	var target_x100: int = clampi(roundi(value * 100.0), 0, 10000)
	var old_x100: int = FarrSystem._farr_x100

	# Direct field write — bypasses apply_farr_change and its on-tick assert.
	# This is the test-only escape per Testing Contract §3.1.
	FarrSystem._farr_x100 = target_x100

	# Synthesize farr_changed so F2 overlay and all subscribers see the mutation.
	var effective_delta: float = float(target_x100 - old_x100) / 100.0
	EventBus.farr_changed.emit(
		effective_delta,
		&"test_set",
		-1,
		FarrSystem.value_farr,
		SimClock.tick,
	)


## Set resource counts for a team directly. v2: writes ResourceSystem's
## fixed-point store directly — the test-only off-tick escape (the
## change_resource chokepoint asserts SimClock.is_ticking(), and fixture
## setup runs off-tick; same pattern as _test_set_farr's direct _farr_x100
## write). Deliberately does NOT emit resource_changed: unlike _test_set_farr,
## the Testing Contract mandates no synthetic emit here, and tests that count
## resource_changed events must not see fixture-setup noise.
func set_resources(team: int, coin: int, grain: int) -> void:
	ResourceSystem._coin_x100[team] = coin * 100
	ResourceSystem._grain_x100[team] = grain * 100


# === Entity spawning (v2 — real scenes) =====================================

## Spawn a unit of the given type for a team at position. Returns the Unit
## node (or null + push_error for an unknown type — §9.L9 loud fallback).
##
## Canonical instantiation pattern (mirrors test_phase_3_throne_deposit.gd):
## team and position are set BEFORE add_child so Unit._ready's spatial-agent
## team mirror, fog vision-source registration, and the unit_spawned payload
## all carry the real team. The spawned unit's MovementComponent resolves the
## harness's MockPathScheduler from PathSchedulerService at _ready — no
## NavigationServer3D contact.
func spawn_unit(type: StringName, team: int, position: Vector3) -> Node:
	if not _UNIT_SCENE_PATHS.has(type):
		push_error(
			"MatchHarness.spawn_unit: unknown unit type '%s' " % type
			+ "(catalog: %s)" % str(_UNIT_SCENE_PATHS.keys())
		)
		return null
	var scene: PackedScene = load(_UNIT_SCENE_PATHS[type])
	var u: Node = scene.instantiate()
	u.set(&"team", team)
	u.set(&"position", position)
	_ensure_spawn_root().add_child(u)  # triggers Unit._ready: id, groups, fog
	var unit_id: int = int(u.get(&"unit_id"))
	_units[unit_id] = u
	print("[harness] spawn_unit type=%s team=%d unit_id=%d pos=%s" % [
		type, team, unit_id, str(position),
	])
	return u


## Spawn a building of the given kind for a team at position. Returns the node
## (or null + push_error for an unknown kind — §9.L9 loud fallback).
##
## Deliberately does NOT run the placement pipeline (Building.place_at →
## navmesh bake → construction stages): headless tests must not touch
## NavigationServer3D, and most tests want a building in a known stage they
## control. The scene lands as-instantiated (is_complete = false for
## constructible kinds); tests needing an operational building flip
## `b.is_complete = true` — the canonical pattern per
## test_phase_3_building_production.gd._spawn_sarbaz_khaneh_complete.
func spawn_building(type: StringName, team: int, position: Vector3) -> Node:
	if not _BUILDING_SCENE_PATHS.has(type):
		push_error(
			"MatchHarness.spawn_building: unknown building kind '%s' " % type
			+ "(catalog: %s)" % str(_BUILDING_SCENE_PATHS.keys())
		)
		return null
	var scene: PackedScene = load(_BUILDING_SCENE_PATHS[type])
	var b: Node = scene.instantiate()
	b.set(&"team", team)
	b.set(&"position", position)
	_ensure_spawn_root().add_child(b)  # triggers Building._ready: id, groups
	var building_id: int = int(b.get(&"unit_id"))
	_buildings[building_id] = b
	print("[harness] spawn_building kind=%s team=%d unit_id=%d pos=%s" % [
		type, team, building_id, str(position),
	])
	return b


# === Internal ================================================================

# Reset every autoload that exposes reset(). Inventory source:
# `grep -rn 'func reset' game/scripts/autoload/` — 13 of the 16 registered
# autoloads (TimeProvider, EventBus, Constants hold no per-match state).
# Keep in sync with test_headless_runner_reset_discipline.gd's
# _RUNNER_EXTRA_RESET_AUTOLOADS (the 8 that Phase-0 MatchHarness missed) —
# that test is the regression guard for this list.
func _reset_all_autoloads() -> void:
	SimClock.reset()
	GameState.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	PathSchedulerService.reset()
	ResourceSystem.reset()
	FogSystem.reset()
	CommandPool.reset()
	FarrDrainDispatcher.reset()
	SelectionManager.reset()
	DebugOverlayManager.reset()
	TuranController.reset()
	DummyIranController.reset()
	# Not autoloads, but match-scoped static state: the Unit and Building id
	# counters (distinct id spaces, each with its own static counter). Both
	# must reset or consecutive in-process runs diverge — Sim Contract §6.2.
	_UnitScript.call(&"reset_id_counter")
	_BuildingScript.call(&"reset_id_counter")


# Lazily create the harness-owned spawn parent in the live SceneTree.
func _ensure_spawn_root() -> Node3D:
	if _spawn_root != null and is_instance_valid(_spawn_root):
		return _spawn_root
	_spawn_root = Node3D.new()
	_spawn_root.name = "MatchHarnessSpawnRoot"
	(Engine.get_main_loop() as SceneTree).root.add_child(_spawn_root)
	return _spawn_root


func _load_scenario(key: StringName) -> Dictionary:
	var catalog: Dictionary = ScenariosScript.CATALOG
	if not catalog.has(key):
		push_warning("MatchHarness: unknown scenario '%s'; using 'empty'" % key)
		return catalog.get(&"empty", {})
	return catalog[key]


# Apply scenario resource overrides to ResourceSystem (direct fixed-point
# writes — same test-only off-tick escape as set_resources). Only keys the
# scenario explicitly sets are written; everything else keeps the BalanceData
# starting values ResourceSystem.reset() loaded.
func _apply_scenario_resources(scenario_data: Dictionary) -> void:
	var key_map: Array = [
		["coin_iran", ResourceSystem._coin_x100, Constants.TEAM_IRAN],
		["coin_turan", ResourceSystem._coin_x100, Constants.TEAM_TURAN],
		["grain_iran", ResourceSystem._grain_x100, Constants.TEAM_IRAN],
		["grain_turan", ResourceSystem._grain_x100, Constants.TEAM_TURAN],
	]
	for entry: Array in key_map:
		var scenario_key: String = entry[0]
		if scenario_data.has(scenario_key):
			var store: Dictionary = entry[1]
			store[entry[2]] = int(scenario_data[scenario_key]) * 100


# Set Farr off-tick for scenario initialization. Uses the same off-tick write
# pattern as _test_set_farr (which is itself the test-only escape from
# apply_farr_change's on-tick assert). Scenario setup happens before any
# advance_ticks call, so off-tick is correct here.
func _run_one_tick_with_farr_set(value: float) -> void:
	var target_x100: int = clampi(roundi(value * 100.0), 0, 10000)
	var old_x100: int = FarrSystem._farr_x100
	FarrSystem._farr_x100 = target_x100
	var effective_delta: float = float(target_x100 - old_x100) / 100.0
	EventBus.farr_changed.emit(
		effective_delta, &"scenario_init", -1, FarrSystem.value_farr, SimClock.tick,
	)


# Preload scenarios script for the catalog. Late-bound so the script file
# can reference MatchHarness without a circular dependency.
const ScenariosScript: Script = preload("res://tests/harness/scenarios.gd")
