# Integration test — Phase 3 session 9 Wave-3-BuildingDestructibility.
#
# Per 02s brief v1.0.1 §3.1 item 7 (architecture-reviewer C4.2):
# ONE parameterized integration test (Ma'dan canonical) — full
# combat→HC→destruction→cleanup→signal chain via direct
# HC.health_zero emit (skips the full combat path; CombatComponent
# integration is exercised by existing combat tests, this test focuses
# on the destruction handler chain).
extends GutTest


const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")
const ThroneScene: PackedScene = preload(
	"res://scenes/world/buildings/throne.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _madan: Variant
var _throne: Variant
var _mine: Variant
var _world_root: Node
var _destruction_payloads: Array = []


func before_each() -> void:
	SimClock.reset()
	ResourceSystem.reset()
	BuildingScript.call(&"reset_id_counter")
	_destruction_payloads.clear()
	_world_root = Node3D.new()
	_world_root.name = &"WorldRoot"
	add_child_autofree(_world_root)


func after_each() -> void:
	if EventBus.building_destroyed.is_connected(_on_building_destroyed_capture):
		EventBus.building_destroyed.disconnect(_on_building_destroyed_capture)
	for ref in [_madan, _throne, _mine]:
		if ref != null and is_instance_valid(ref):
			ref.queue_free()
	_madan = null
	_throne = null
	_mine = null
	_world_root = null
	SimClock._is_ticking = false
	SimClock.reset()
	ResourceSystem.reset()


func _on_building_destroyed_capture(team: int, kind: StringName, unit_id: int) -> void:
	_destruction_payloads.append({
		&"team": team, &"kind": kind, &"unit_id": unit_id,
	})


# ---------------------------------------------------------------------------
# Full destruction chain — Ma'dan canonical (per architecture-reviewer C4.2)
# ---------------------------------------------------------------------------

func test_madan_destruction_full_cleanup_chain() -> void:
	# Setup: Ma'dan with HC. Destroy via local HC.health_zero emit
	# (skips combat path; tests destruction handler directly).
	_madan = MadanScene.instantiate()
	_madan.set(&"team", Constants.TEAM_IRAN)
	_world_root.add_child(_madan)
	# Connect destruction-capture handler.
	EventBus.building_destroyed.connect(_on_building_destroyed_capture)
	# Sanity: HC present.
	var hc: Node = _madan.get_node_or_null(^"HealthComponent")
	assert_not_null(hc, "sanity: Ma'dan has HC (Wave 3-BD inheritance)")
	var madan_id: int = int(_madan.get(&"unit_id"))
	# Trigger destruction via local HC.health_zero emit (bypasses
	# combat path).
	hc.health_zero.emit(madan_id)
	# Assert generic building_destroyed signal fired with correct payload.
	assert_eq(_destruction_payloads.size(), 1,
		"building_destroyed must emit exactly once on local HC.health_zero")
	assert_eq(_destruction_payloads[0][&"team"], Constants.TEAM_IRAN,
		"Payload team matches Ma'dan team")
	assert_eq(_destruction_payloads[0][&"kind"], &"madan",
		"Payload kind matches Ma'dan kind")
	assert_eq(_destruction_payloads[0][&"unit_id"], madan_id,
		"Payload unit_id matches Ma'dan unit_id")


func test_destruction_signal_latch_idempotent() -> void:
	# Even if HC.health_zero fires multiple times, building_destroyed
	# fires exactly once per building (latch — _destruction_emitted gate
	# at base building.gd:_on_health_zero).
	_madan = MadanScene.instantiate()
	_madan.set(&"team", Constants.TEAM_IRAN)
	_world_root.add_child(_madan)
	EventBus.building_destroyed.connect(_on_building_destroyed_capture)
	var hc: Node = _madan.get_node_or_null(^"HealthComponent")
	var madan_id: int = int(_madan.get(&"unit_id"))
	hc.health_zero.emit(madan_id)
	hc.health_zero.emit(madan_id)
	hc.health_zero.emit(madan_id)
	assert_eq(_destruction_payloads.size(), 1,
		"building_destroyed latch: emits exactly once per building "
		+ "regardless of HC.health_zero re-emit count")


# ---------------------------------------------------------------------------
# BUG-G1 regression — global EventBus.unit_health_zero with building unit_id
# must NOT fire building_destroyed (Buildings subscribe to LOCAL signal only)
# ---------------------------------------------------------------------------

func test_bug_g1_regression_global_unit_health_zero_silent_for_madan() -> void:
	# BUG-G1 invariant: Buildings subscribe to LOCAL HC.health_zero, NOT
	# global EventBus.unit_health_zero. Emitting global with the building's
	# unit_id MUST NOT fire building_destroyed.
	_madan = MadanScene.instantiate()
	_madan.set(&"team", Constants.TEAM_IRAN)
	_world_root.add_child(_madan)
	EventBus.building_destroyed.connect(_on_building_destroyed_capture)
	var madan_id: int = int(_madan.get(&"unit_id"))
	EventBus.unit_health_zero.emit(madan_id)
	assert_eq(_destruction_payloads.size(), 0,
		"BUG-G1 invariant: global EventBus.unit_health_zero MUST NOT fire "
		+ "building_destroyed (Buildings use LOCAL HC signal only)")


func test_bug_g1_regression_global_unit_health_zero_silent_for_throne() -> void:
	# Mirror BUG-G1 test for Throne — same invariant applies to ALL building
	# subclasses uniformly (base building.gd handles subscription).
	_throne = ThroneScene.instantiate()
	_throne.set(&"team", Constants.TEAM_IRAN)
	_world_root.add_child(_throne)
	EventBus.building_destroyed.connect(_on_building_destroyed_capture)
	var throne_id: int = int(_throne.get(&"unit_id"))
	EventBus.unit_health_zero.emit(throne_id)
	assert_eq(_destruction_payloads.size(), 0,
		"BUG-G1 invariant: global EventBus.unit_health_zero MUST NOT fire "
		+ "building_destroyed for Throne (LOCAL HC signal only)")


# ---------------------------------------------------------------------------
# Throne destruction — both signals fire
# ---------------------------------------------------------------------------

var _throne_destroyed_payloads: Array = []


func _on_throne_destroyed_capture(team: int) -> void:
	_throne_destroyed_payloads.append(team)


func test_throne_destruction_emits_both_signals() -> void:
	# Throne emits BOTH the specific throne_destroyed (Phase 8 win-screen
	# consumer) AND the generic building_destroyed (AI consumers).
	_throne_destroyed_payloads.clear()
	_throne = ThroneScene.instantiate()
	_throne.set(&"team", Constants.TEAM_TURAN)
	_world_root.add_child(_throne)
	EventBus.building_destroyed.connect(_on_building_destroyed_capture)
	EventBus.throne_destroyed.connect(_on_throne_destroyed_capture)
	var hc: Node = _throne.get_node_or_null(^"HealthComponent")
	var throne_id: int = int(_throne.get(&"unit_id"))
	hc.health_zero.emit(throne_id)
	# Both signals must fire.
	assert_eq(_throne_destroyed_payloads.size(), 1,
		"Throne destruction fires specific throne_destroyed once")
	assert_eq(_throne_destroyed_payloads[0], Constants.TEAM_TURAN,
		"throne_destroyed payload matches Throne's team")
	assert_eq(_destruction_payloads.size(), 1,
		"Throne destruction ALSO fires generic building_destroyed once")
	assert_eq(_destruction_payloads[0][&"kind"], &"throne",
		"Generic building_destroyed payload includes kind=throne")
	EventBus.throne_destroyed.disconnect(_on_throne_destroyed_capture)
