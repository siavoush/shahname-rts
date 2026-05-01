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
## Phase 0 deliverable. Unit/building spawning stubs are present in the API
## but return null — concrete implementations land Phase 1+ when Unit and
## Building scenes exist. Resource tracking is harness-local (GameState has no
## coin/grain fields yet; those land Phase 3 with ResourceSystem).
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

# === State ==================================================================

var _seed: int
var _scenario: StringName

# Harness-local resource counters (ResourceSystem doesn't exist yet — Phase 3).
# Keys: Constants.TEAM_IRAN, Constants.TEAM_TURAN.
var _coin: Dictionary = {}
var _grain: Dictionary = {}

# Tracked entities — populated by spawn_unit / spawn_building.
# Phase 1+: real Node refs. Phase 0: empty.
var _units: Dictionary = {}     # unit_id -> Node
var _buildings: Dictionary = {} # building_id -> Node

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
## seed: deterministic seed for GameRNG (Phase 0: seed() on global RNG;
##   TODO phase-1: GameRNG.seed_match(seed) once that autoload ships).
## scenario: StringName key into Scenarios.CATALOG (scenarios.gd).
func start_match(seed: int = 0, scenario: StringName = &"empty") -> void:
	_seed = seed
	_scenario = scenario
	_setup()


func _setup() -> void:
	# Reset all autoloads to pristine state so each harness starts clean.
	SimClock.reset()
	GameState.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	PathSchedulerService.reset()

	# Inject MockPathScheduler so no NavigationServer3D contact occurs.
	_mock_scheduler = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock_scheduler)

	# Initialize harness-local resource pools from scenario defaults.
	var scenario_data: Dictionary = _load_scenario(_scenario)
	_coin[Constants.TEAM_IRAN] = scenario_data.get("coin_iran", 150)
	_coin[Constants.TEAM_TURAN] = scenario_data.get("coin_turan", 150)
	_grain[Constants.TEAM_IRAN] = scenario_data.get("grain_iran", 50)
	_grain[Constants.TEAM_TURAN] = scenario_data.get("grain_turan", 50)

	# Set Farr if the scenario overrides it (must happen inside a tick).
	var farr_override: Variant = scenario_data.get("farr", null)
	if farr_override != null:
		# Run one tick to satisfy the on-tick assertion, set farr inside it.
		_run_one_tick_with_farr_set(float(farr_override))

	# Start the match in GameState.
	GameState.start_match(Constants.TEAM_IRAN)


## Release all harness-held state. Call in GUT after_each.
func teardown() -> void:
	# Free any spawned nodes before resetting autoloads.
	for node: Node in _units.values():
		if is_instance_valid(node):
			node.queue_free()
	for node: Node in _buildings.values():
		if is_instance_valid(node):
			node.queue_free()
	_units.clear()
	_buildings.clear()

	PathSchedulerService.reset()
	if _mock_scheduler != null:
		_mock_scheduler.clear_log()
	_mock_scheduler = null

	SimClock.reset()
	GameState.reset()
	FarrSystem.reset()
	SpatialIndex.reset()


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


## Current resources for a team. Returns {coin: int, grain: int}.
func get_resources(team: int) -> Dictionary:
	return {
		"coin": _coin.get(team, 0),
		"grain": _grain.get(team, 0),
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
func snapshot() -> Dictionary:
	var unit_count_iran: int = 0
	var unit_count_turan: int = 0
	for node: Node in _units.values():
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
		"coin_iran": _coin.get(Constants.TEAM_IRAN, 0),
		"grain_iran": _grain.get(Constants.TEAM_IRAN, 0),
		"coin_turan": _coin.get(Constants.TEAM_TURAN, 0),
		"grain_turan": _grain.get(Constants.TEAM_TURAN, 0),
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


## Set resource counts for a team directly (bypass ResourceSystem — Phase 3).
func set_resources(team: int, coin: int, grain: int) -> void:
	_coin[team] = coin
	_grain[team] = grain


# === Entity spawning (Phase 1+ stubs) =======================================
#
# These return null until Unit and Building scenes exist. The API surface is
# locked per TESTING_CONTRACT.md §3.1 so integration tests can be written
# now against the signature and will pass once the scenes ship.

## Spawn a unit of the given type for a team at position. Returns the Unit node.
## Phase 0: push_warning and return null (no Unit scene yet).
func spawn_unit(type: StringName, team: int, position: Vector3) -> Node:
	push_warning(
		"MatchHarness.spawn_unit: Unit scenes not yet implemented (Phase 1). "
		+ "type=%s team=%d pos=%s" % [type, team, position]
	)
	return null


## Spawn a building of the given type for a team at position. Returns the node.
## Phase 0: push_warning and return null (no Building scene yet).
func spawn_building(type: StringName, team: int, position: Vector3) -> Node:
	push_warning(
		"MatchHarness.spawn_building: Building scenes not yet implemented (Phase 3). "
		+ "type=%s team=%d pos=%s" % [type, team, position]
	)
	return null


# === Internal ================================================================

func _load_scenario(key: StringName) -> Dictionary:
	var catalog: Dictionary = ScenariosScript.CATALOG
	if not catalog.has(key):
		push_warning("MatchHarness: unknown scenario '%s'; using 'empty'" % key)
		return catalog.get(&"empty", {})
	return catalog[key]


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
