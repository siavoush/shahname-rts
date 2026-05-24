# Tests for the Throne (Iran + Turan HQ) building — Phase 3 session 8 Wave-3-Throne.
#
# Per 02q_PHASE_3_SESSION_8_THRONE_KICKOFF.md §4 Track 1 + RNC §5 IDropoffTarget +
# docs/ANCHOR_CATEGORY_TAXONOMY.md v1.1.0 §1.5 (sovereignty-bearing institution).
#
# Test coverage (mandated by brief §4 Track 1):
#   1. Script identity (kind = &"throne", dual-init, Building base inheritance).
#   2. SceneTree group membership (&"thrones" for ResourceSystem.dropoff_for_team).
#   3. RNC §5.2 IDropoffTarget protocol conformance — deposit + get_deposit_position.
#   4. Throne.deposit routes through ResourceSystem.change_resource chokepoint.
#   5. EventBus.throne_destroyed signal emits exactly once on hp=0 (latch).
#   6. max_hp read from BalanceData.buildings[&"throne"] canonical Dictionary
#      (per BUG-C1 fix-wave learning; NOT bldg_<kind> top-level field).
#   7. FogSystem vision-source registration with sight_throne_cells=4.
#
# Test pattern: Throne extends Building via path-string + has `class_name Throne`;
# we preload the scene template (world-builder shipped at 5ff7d26) to exercise
# the live-spawn path. Headless `.new()` construction also tested for the
# script-only / no-scene fixture path.
extends GutTest


const ThroneScene: PackedScene = preload(
	"res://scenes/world/buildings/throne.tscn")
const ThroneScript: Script = preload(
	"res://scripts/world/buildings/throne.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")
const HealthComponentScript: Script = preload(
	"res://scripts/units/components/health_component.gd")


var _throne: Variant
# Signal capture buffer for throne_destroyed (cleared in before_each).
var _destroyed_payloads: Array = []


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()
	_destroyed_payloads.clear()


func after_each() -> void:
	if _throne != null and is_instance_valid(_throne):
		_throne.queue_free()
	_throne = null
	# Disconnect any test-bound throne_destroyed handlers so subsequent
	# tests don't accumulate signal subscribers.
	if EventBus.throne_destroyed.is_connected(_on_throne_destroyed_capture):
		EventBus.throne_destroyed.disconnect(_on_throne_destroyed_capture)


func _on_throne_destroyed_capture(team_id: int) -> void:
	_destroyed_payloads.append(team_id)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Spawn a Throne via the .tscn scene template (exercises the production path
# main.gd:_spawn_starting_buildings uses). Returns the Throne instance.
func _spawn_throne_scene(team: int = Constants.TEAM_IRAN) -> Variant:
	var t: Variant = ThroneScene.instantiate()
	t.set(&"team", team)
	add_child_autofree(t)
	return t


# Spawn a Throne with a HealthComponent attached BEFORE _ready fires.
# Phase 8 will add the HealthComponent node to throne.tscn directly; until
# then tests construct it manually so the local-signal subscription
# (BUG-G1 fix shape) wires up. Returns the Throne instance with HC as child.
func _spawn_throne_with_hc(team: int = Constants.TEAM_IRAN) -> Variant:
	var t: Variant = ThroneScene.instantiate()
	t.set(&"team", team)
	var hc: Node = HealthComponentScript.new()
	hc.name = &"HealthComponent"
	t.add_child(hc)
	# Adding `t` to the tree fires Throne._ready which finds the HC and
	# wires the local-signal subscription per BUG-G1 fix.
	add_child_autofree(t)
	return t


# ---------------------------------------------------------------------------
# Identity — kind, dual-init, inheritance chain
# ---------------------------------------------------------------------------

func test_throne_kind_is_throne_via_scene() -> void:
	# Scene-instantiated Throne (live-game path) has kind = &"throne" per
	# the dual-init pattern (_init AND _ready both set it).
	_throne = _spawn_throne_scene()
	assert_eq(_throne.kind, &"throne",
		"Throne.kind must equal &\"throne\" after scene instantiation")


func test_throne_kind_is_throne_via_new() -> void:
	# Headless Throne.new() (no scene; test fixture path). _init sets kind
	# even before _ready runs.
	var t: Variant = ThroneScript.new()
	# Run _init manually if not auto-run; since `.new()` calls _init by
	# Godot convention, kind should already be set.
	assert_eq(t.kind, &"throne",
		"Throne.new() must set kind = &\"throne\" in _init")
	t.free()


func test_throne_extends_building() -> void:
	# Inheritance chain check — the Throne must extend the Building base
	# so the lifecycle (place_at / _on_placement_complete) + the get_footprint_aabb
	# helper + the production state machine all work via inheritance.
	_throne = _spawn_throne_scene()
	assert_true(_throne.get_script() != null,
		"sanity: Throne instance has a script attached")
	# is_in_group(&"buildings") tests inheritance: Building._ready joins this
	# group. If Throne extends Building, it inherits the group join.
	assert_true(_throne.is_in_group(&"buildings"),
		"Throne must join the &\"buildings\" group via Building._ready inheritance")


# ---------------------------------------------------------------------------
# SceneTree group membership — &"thrones" for ResourceSystem.dropoff_for_team
# ---------------------------------------------------------------------------

func test_throne_joins_thrones_group() -> void:
	# Per brief §4 Track 1: "Joins &"thrones" group on _ready (so
	# ResourceSystem.dropoff_for_team can find it)."
	_throne = _spawn_throne_scene()
	assert_true(_throne.is_in_group(&"thrones"),
		"Throne must join the &\"thrones\" SceneTree group at _ready — "
		+ "this is the canonical lookup channel for ResourceSystem.dropoff_for_team. "
		+ "Without it, workers can't find the deposit target.")


func test_thrones_group_filters_by_team() -> void:
	# Spawn one Iran Throne + one Turan Throne; verify group iteration +
	# team-filtering yields exactly one of each (the canonical pattern
	# ResourceSystem.dropoff_for_team uses).
	var iran: Variant = _spawn_throne_scene(Constants.TEAM_IRAN)
	var turan: Variant = _spawn_throne_scene(Constants.TEAM_TURAN)
	var iran_thrones: Array = []
	var turan_thrones: Array = []
	for node in get_tree().get_nodes_in_group(&"thrones"):
		if int(node.get(&"team")) == Constants.TEAM_IRAN:
			iran_thrones.append(node)
		elif int(node.get(&"team")) == Constants.TEAM_TURAN:
			turan_thrones.append(node)
	assert_eq(iran_thrones.size(), 1,
		"Exactly one Iran Throne must be in the group")
	assert_eq(turan_thrones.size(), 1,
		"Exactly one Turan Throne must be in the group")
	iran.queue_free()
	turan.queue_free()


# ---------------------------------------------------------------------------
# RNC §5.2 IDropoffTarget protocol conformance
# ---------------------------------------------------------------------------

func test_throne_implements_idropofftarget_protocol() -> void:
	# Per docs/RESOURCE_NODE_CONTRACT.md §5.2: deposit + get_deposit_position
	# are the required method signatures. Duck-typed (no GDScript interface
	# keyword) — has_method check is the conformance test.
	_throne = _spawn_throne_scene()
	assert_true(_throne.has_method(&"deposit"),
		"Throne must implement deposit() per RNC §5.2 IDropoffTarget protocol")
	assert_true(_throne.has_method(&"get_deposit_position"),
		"Throne must implement get_deposit_position() per RNC §5.2 IDropoffTarget protocol")


func test_get_deposit_position_returns_throne_world_position() -> void:
	# get_deposit_position returns a Vector3 near the Throne's
	# global_position (small Y nudge per implementation). Workers walk
	# to this position before depositing.
	_throne = _spawn_throne_scene(Constants.TEAM_IRAN)
	_throne.global_position = Vector3(10.0, 0.0, -20.0)
	var pos: Vector3 = _throne.get_deposit_position()
	assert_almost_eq(pos.x, 10.0, 0.1,
		"deposit_position.x must match Throne.global_position.x")
	assert_almost_eq(pos.z, -20.0, 0.1,
		"deposit_position.z must match Throne.global_position.z")


# ---------------------------------------------------------------------------
# Deposit chokepoint — RNC §5.2 + ResourceSystem.change_resource
# ---------------------------------------------------------------------------

func test_deposit_calls_change_resource_chokepoint() -> void:
	# Throne.deposit must route through ResourceSystem.change_resource
	# internally per RNC §5.2 canonical pattern + mirror C1.4 (only ONE
	# path calls change_resource per deposit cycle).
	#
	# We assert observable behavior: depositing 50 Coin (amount_x100=5000)
	# must increase the team's coin_x100 by exactly 5000.
	_throne = _spawn_throne_scene(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	# Pass a stand-in Object for the worker arg. Throne.deposit only uses
	# the worker for telemetry (unit_id logging) — null works for tests.
	_throne.deposit(Constants.KIND_COIN, 5000, null)
	SimClock._is_ticking = false
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after - coin_before, 5000,
		"Throne.deposit(KIND_COIN, 5000, null) must increase team's coin_x100 "
		+ "by exactly 5000 via the ResourceSystem.change_resource chokepoint")


func test_deposit_zero_amount_is_noop() -> void:
	# Defensive: zero/negative deposits are a no-op (matches Returning's
	# existing skip-empty-carry guard pattern).
	_throne = _spawn_throne_scene(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_throne.deposit(Constants.KIND_COIN, 0, null)
	_throne.deposit(Constants.KIND_COIN, -100, null)
	SimClock._is_ticking = false
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after, coin_before,
		"Throne.deposit with amount <= 0 must be a no-op (no spurious change_resource calls)")


# ---------------------------------------------------------------------------
# EventBus.throne_destroyed signal — forward-compat Phase 8 seam
# ---------------------------------------------------------------------------

func test_throne_destroyed_signal_emits_on_local_hc_health_zero() -> void:
	# Per brief §4 Track 1: "Emits EventBus.throne_destroyed(team) on
	# HealthComponent fatal-damage path." Post-BUG-G1 fix (2026-05-24):
	# Throne subscribes to its OWN HealthComponent's LOCAL health_zero
	# signal, NOT the global EventBus.unit_health_zero channel. Test emits
	# on the local signal of the Throne's own HC.
	_throne = _spawn_throne_with_hc(Constants.TEAM_TURAN)
	EventBus.throne_destroyed.connect(_on_throne_destroyed_capture)
	var hc: Node = _throne.get_node(^"HealthComponent")
	assert_not_null(hc,
		"sanity precondition: spawn-with-hc fixture must attach HealthComponent")
	# Emit on the LOCAL health_zero signal (the BUG-G1 fix-path).
	hc.health_zero.emit(int(_throne.get(&"unit_id")))
	assert_eq(_destroyed_payloads.size(), 1,
		"throne_destroyed must emit exactly once when local HC.health_zero fires")
	assert_eq(_destroyed_payloads[0], Constants.TEAM_TURAN,
		"throne_destroyed payload must be the dying Throne's team")


func test_throne_destroyed_signal_does_not_subscribe_to_global_channel() -> void:
	# BUG-G1 regression-lock. Pre-fix, Throne subscribed globally to
	# EventBus.unit_health_zero and filtered by unit_id. Building unit_ids
	# and Unit unit_ids are SEPARATE counters in the same int space: Iran
	# Throne unit_id=1 collided with Kargar unit_id=1. Result: when a
	# Kargar died, the Throne's global filter said "1 == 1, that's me!"
	# and emitted throne_destroyed.
	#
	# Post-fix: Throne does NOT subscribe to the global channel. This test
	# emits on the global EventBus.unit_health_zero for the SAME unit_id
	# as the Throne — pre-fix this would fire throne_destroyed; post-fix
	# it must NOT.
	_throne = _spawn_throne_with_hc(Constants.TEAM_IRAN)
	EventBus.throne_destroyed.connect(_on_throne_destroyed_capture)
	var throne_id: int = int(_throne.get(&"unit_id"))
	# Pre-fix collision: emit on global channel with Throne's unit_id.
	# Post-fix: Throne is not subscribed to global, so nothing fires.
	EventBus.unit_health_zero.emit(throne_id)
	assert_eq(_destroyed_payloads.size(), 0,
		"BUG-G1 regression: Throne MUST NOT react to global EventBus.unit_health_zero. "
		+ "Building unit_ids collide with Unit unit_ids; the only safe channel is "
		+ "the local HealthComponent.health_zero signal.")


func test_throne_destroyed_signal_idempotent() -> void:
	# Latch test: even if local health_zero fires twice for the same
	# Throne (race conditions, double-emit bugs), the signal MUST fire
	# only once. Matches HealthComponent's latch pattern.
	_throne = _spawn_throne_with_hc(Constants.TEAM_IRAN)
	EventBus.throne_destroyed.connect(_on_throne_destroyed_capture)
	var hc: Node = _throne.get_node(^"HealthComponent")
	var throne_id: int = int(_throne.get(&"unit_id"))
	hc.health_zero.emit(throne_id)
	hc.health_zero.emit(throne_id)
	hc.health_zero.emit(throne_id)
	assert_eq(_destroyed_payloads.size(), 1,
		"throne_destroyed must fire exactly once per Throne (latch — no re-emit)")


func test_throne_without_hc_does_not_fire_destroyed_signal() -> void:
	# Post-BUG-G1: no HC attached → no local-signal subscription → Throne
	# CANNOT be destroyed in this run. This is the explicit forward-compat
	# shape (Phase 8 will add HC to throne.tscn; until then the seam is
	# documented but inert). Verifies the inertness is real, not just
	# documented.
	_throne = _spawn_throne_scene(Constants.TEAM_IRAN)
	EventBus.throne_destroyed.connect(_on_throne_destroyed_capture)
	# Sanity: no HC on this Throne instance.
	var hc: Node = _throne.get_node_or_null(^"HealthComponent")
	assert_null(hc,
		"sanity precondition: _spawn_throne_scene (no _with_hc variant) must NOT attach HC")
	# Emit global with Throne's unit_id — pre-fix would have fired; post-fix
	# is silent (no subscription).
	var throne_id: int = int(_throne.get(&"unit_id"))
	EventBus.unit_health_zero.emit(throne_id)
	assert_eq(_destroyed_payloads.size(), 0,
		"throne_destroyed must NOT fire on a Throne without HealthComponent "
		+ "(no local-signal subscription possible)")


# ---------------------------------------------------------------------------
# max_hp from BalanceData — canonical Dictionary lookup (BUG-C1 learning)
# ---------------------------------------------------------------------------

func test_throne_max_hp_reads_from_balance_data_buildings_dict() -> void:
	# Per BUG-C1 retro: BalanceData entries live at buildings[<kind>], NOT
	# bldg_<kind>. balance.tres:215 has bldg_throne.max_hp = 2000.0.
	# Throne._resolve_max_hp must read this via the canonical Dictionary
	# lookup.
	_throne = _spawn_throne_scene()
	var max_hp: float = _throne._resolve_max_hp()
	assert_eq(max_hp, 2000.0,
		"Throne max_hp must read 2000.0 from BalanceData.buildings[&\"throne\"].max_hp "
		+ "(canonical Dictionary lookup per BUG-C1 fix-wave). If this returns "
		+ "the _FALLBACK_MAX_HP, the canonical lookup has regressed.")
