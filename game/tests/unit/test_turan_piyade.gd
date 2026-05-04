# Tests for the TuranPiyade (Turan foot infantry) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (units) + §11 (Turan faction)
#   - 02d_PHASE_2_KICKOFF.md §2 deliverable 6 (first Turan combat unit type)
#
# What we cover:
#   - turan_piyade.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a TuranPiyade and a Unit (parent class)
#   - unit_type == &"turan_piyade" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry (mirrored stats — same as Iran Piyade)
#   - max_hp matches BalanceData (100.0)
#   - move_speed matches BalanceData (2.5)
#   - Combat fields match (same as Iran Piyade for session 1 mirror combat)
#   - Mesh override is a BoxMesh with the same dimensions as Iran Piyade
#   - Material override is Turan-red (high red, low blue) — distinct from
#     Iran-blue and from Kargar brown
#   - Team plumbing: TEAM_TURAN mirrors to SpatialAgentComponent
#   - Bare TuranPiyade.new() construction sets unit_type
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_piyade.gd.
extends GutTest


const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const TuranPiyadeScript: Script = preload("res://scripts/units/turan_piyade.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _tp: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _tp != null and is_instance_valid(_tp):
		_tp.queue_free()
	_tp = null
	SimClock.reset()


func _spawn_turan_piyade(team: int = Constants.TEAM_TURAN) -> Variant:
	var p: Variant = TuranPiyadeScene.instantiate()
	p.team = team
	add_child_autofree(p)
	return p


# ---------------------------------------------------------------------------
# Visual smoke: scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_turan_piyade_scene_loads() -> void:
	_tp = _spawn_turan_piyade()
	assert_not_null(_tp, "turan_piyade.tscn must load to a non-null node")


func test_turan_piyade_inherits_unit_components() -> void:
	_tp = _spawn_turan_piyade()
	assert_not_null(_tp.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on TuranPiyade")
	assert_not_null(_tp.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on TuranPiyade")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_turan_piyade_is_a_unit() -> void:
	_tp = _spawn_turan_piyade()
	var s: Script = _tp.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"TuranPiyade instance must inherit from unit.gd somewhere in its script chain")


func test_turan_piyade_unit_type_is_turan_piyade_string_name() -> void:
	_tp = _spawn_turan_piyade()
	assert_eq(_tp.unit_type, &"turan_piyade",
		"TuranPiyade.unit_type must be the StringName &\"turan_piyade\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — mirror combat means stats match Iran Piyade
# ---------------------------------------------------------------------------

func test_turan_piyade_max_hp_matches_balance_data() -> void:
	# balance.tres declares unit_turan_piyade.max_hp = 100.0 (mirror).
	_tp = _spawn_turan_piyade()
	var h: Node = _tp.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), 10000,
		"TuranPiyade max_hp_x100 must be 10000 (mirror Iran Piyade)")


func test_turan_piyade_move_speed_matches_balance_data() -> void:
	_tp = _spawn_turan_piyade()
	var m: Node = _tp.get_movement()
	assert_almost_eq(float(m.get(&"move_speed")), 2.5, 0.01,
		"TuranPiyade move_speed must be 2.5 (mirror Iran Piyade)")


func test_turan_piyade_attack_damage_matches_balance_data() -> void:
	_tp = _spawn_turan_piyade()
	var c: Node = _tp.get_combat()
	assert_eq(int(c.get(&"attack_damage_x100")), 1000,
		"TuranPiyade attack_damage_x100 must be 1000 (mirror Iran Piyade)")


func test_turan_piyade_attack_speed_matches_balance_data() -> void:
	_tp = _spawn_turan_piyade()
	var c: Node = _tp.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), 1.0, 0.01,
		"TuranPiyade attack_speed_per_sec must be 1.0 (mirror Iran Piyade)")


func test_turan_piyade_attack_range_matches_balance_data() -> void:
	_tp = _spawn_turan_piyade()
	var c: Node = _tp.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), 1.5, 0.01,
		"TuranPiyade attack_range must be 1.5 (mirror Iran Piyade)")


# ---------------------------------------------------------------------------
# Mesh override — same shape as Iran Piyade, different color
# ---------------------------------------------------------------------------

func test_turan_piyade_uses_box_mesh_with_piyade_height() -> void:
	# Same dimensions as Iran Piyade (0.5 × 0.7 × 0.5). Mirror combat — only
	# color differs.
	_tp = _spawn_turan_piyade()
	var mi: MeshInstance3D = _tp.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"TuranPiyade mesh must be BoxMesh (same archetype as Iran Piyade)")
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.y, 0.7, 0.001,
		"TuranPiyade BoxMesh height must be 0.7 (mirror Iran Piyade)")


func test_turan_piyade_material_is_turan_red() -> void:
	# Turan-red albedo: high red (>0.6), low blue (<0.4). Distinguishable
	# from Iran-blue Piyade (low red, high blue) AND from Kargar brown
	# (high red but low blue is not enough alone — Turan-red has a much
	# more saturated red than the earth-tone brown).
	_tp = _spawn_turan_piyade()
	var mi: MeshInstance3D = _tp.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "TuranPiyade must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"TuranPiyade material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.r > 0.6,
		"TuranPiyade albedo red channel must be high (Turan red), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.4,
		"TuranPiyade albedo blue channel must be low (Turan red, not Iran blue), got b=%.2f"
			% sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — TEAM_TURAN plumbing (this is the new thing wave-2A verifies)
# ---------------------------------------------------------------------------

func test_turan_piyade_team_can_be_assigned_turan() -> void:
	# This is the live-game-broken-surface answer for deliverable 6:
	# verify TEAM_TURAN mirrors correctly to the SpatialAgentComponent.
	# Iran-only spatial filters (e.g., SelectionManager filtering Iran)
	# should exclude these; cross-team queries should find them.
	_tp = _spawn_turan_piyade(Constants.TEAM_TURAN)
	var sa: Node = _tp.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
		"TuranPiyade.team must be mirrored to SpatialAgentComponent.team as TEAM_TURAN")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_turan_piyade_script_directly_constructable() -> void:
	var bare: Variant = TuranPiyadeScript.new()
	assert_eq(bare.unit_type, &"turan_piyade",
		"TuranPiyade.new() (no scene) must set unit_type = &\"turan_piyade\" in _init")
	bare.free()
