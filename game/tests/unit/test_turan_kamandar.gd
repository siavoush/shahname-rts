# Tests for the TuranKamandar (Turan archer) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (units) + §11 (Turan faction red palette)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4 (Turan mirror roster)
#
# What we cover:
#   - turan_kamandar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a TuranKamandar (class) and a Unit
#   - unit_type == &"turan_kamandar" so Unit._apply_balance_data_defaults
#     reads the right BalanceData entry
#   - max_hp / move_speed / attack_damage_x100 / attack_speed_per_sec /
#     attack_range all wire through from BalanceData (whatever balance.tres
#     declares; Turan_Kamandar mirrors Iran Kamandar in Phase 2)
#   - Mesh override is a CylinderMesh with Kamandar dimensions (height 0.9,
#     radius 0.25) — same archetype silhouette
#   - Material override is Turan-red (high red, low blue) — distinguishable
#     from Iran-blue Kamandar
#   - Team plumbing: TEAM_TURAN mirrors to SpatialAgentComponent
#   - Bare TuranKamandar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer is populating BalanceData entries
# IN PARALLEL. Tests read balance.tres at test-time and assert wiring.
extends GutTest


const TuranKamandarScene: PackedScene = preload("res://scenes/units/turan_kamandar.tscn")
const TuranKamandarScript: Script = preload("res://scripts/units/turan_kamandar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _tk: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _tk != null and is_instance_valid(_tk):
		_tk.queue_free()
	_tk = null
	SimClock.reset()


func _spawn_turan_kamandar(team: int = Constants.TEAM_TURAN) -> Variant:
	var k: Variant = TuranKamandarScene.instantiate()
	k.team = team
	add_child_autofree(k)
	return k


func _load_turan_kamandar_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	return (units as Dictionary).get(&"turan_kamandar", null)


# ---------------------------------------------------------------------------
# Visual smoke: scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_turan_kamandar_scene_loads() -> void:
	_tk = _spawn_turan_kamandar()
	assert_not_null(_tk, "turan_kamandar.tscn must load to a non-null node")


func test_turan_kamandar_inherits_unit_components() -> void:
	_tk = _spawn_turan_kamandar()
	assert_not_null(_tk.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on TuranKamandar")
	assert_not_null(_tk.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on TuranKamandar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_turan_kamandar_is_a_unit() -> void:
	_tk = _spawn_turan_kamandar()
	var s: Script = _tk.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"TuranKamandar instance must inherit from unit.gd somewhere in its script chain")


func test_turan_kamandar_unit_type_is_turan_kamandar_string_name() -> void:
	_tk = _spawn_turan_kamandar()
	assert_eq(_tk.unit_type, &"turan_kamandar",
		"TuranKamandar.unit_type must be the StringName &\"turan_kamandar\"")


# ---------------------------------------------------------------------------
# BalanceData hookup — mirror of Iran Kamandar (same archetype)
# ---------------------------------------------------------------------------

func test_turan_kamandar_max_hp_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_kamandar_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"turan_kamandar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_tk = _spawn_turan_kamandar()
	var h: Node = _tk.get_health()
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"TuranKamandar max_hp_x100 must wire through BalanceData")


func test_turan_kamandar_move_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_kamandar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_tk = _spawn_turan_kamandar()
	var m: Node = _tk.get_movement()
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"TuranKamandar move_speed must wire through BalanceData")


func test_turan_kamandar_attack_damage_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_turan_kamandar.attack_damage_x100 not yet populated."
		)
		return
	_tk = _spawn_turan_kamandar()
	var c: Node = _tk.get_combat()
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"TuranKamandar attack_damage_x100 must wire through BalanceData")


func test_turan_kamandar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_kamandar.attack_speed_per_sec not yet populated.")
		return
	_tk = _spawn_turan_kamandar()
	var c: Node = _tk.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"TuranKamandar attack_speed_per_sec must wire through BalanceData")


func test_turan_kamandar_attack_range_is_ranged() -> void:
	# Mirror of Iran Kamandar — same ranged-vs-melee invariant.
	var stats: Variant = _load_turan_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_kamandar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_tk = _spawn_turan_kamandar()
	var c: Node = _tk.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"TuranKamandar attack_range must wire through BalanceData")
	assert_true(expected_range >= 5.0,
		"TuranKamandar attack_range must be ranged (≥ 5.0) — mirror Iran Kamandar")


# ---------------------------------------------------------------------------
# Mesh override — same shape as Iran Kamandar, different color
# ---------------------------------------------------------------------------

func test_turan_kamandar_uses_cylinder_mesh_with_kamandar_dimensions() -> void:
	# Same dimensions as Iran Kamandar (height 0.9, radius 0.25). Mirror
	# combat — only team color differs.
	_tk = _spawn_turan_kamandar()
	var mi: MeshInstance3D = _tk.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is CylinderMesh,
		"TuranKamandar mesh must be CylinderMesh (mirror Iran Kamandar)")
	var cm: CylinderMesh = mi.mesh as CylinderMesh
	assert_almost_eq(cm.height, 0.9, 0.001,
		"TuranKamandar CylinderMesh height must be 0.9 (mirror Iran Kamandar)")
	assert_almost_eq(cm.top_radius, 0.25, 0.001,
		"TuranKamandar CylinderMesh top_radius must be 0.25 (mirror Iran Kamandar)")


func test_turan_kamandar_material_is_turan_red() -> void:
	# Turan-red palette: high red (>0.4), low blue (<0.3). Distinguishable
	# from Iran-blue Kamandar. Per kickoff §2 deliverable 3:
	# Color(0.55, 0.15, 0.15) — saturated dark red, the Turan equivalent
	# of Iran Kamandar's darker variant.
	_tk = _spawn_turan_kamandar()
	var mi: MeshInstance3D = _tk.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "TuranKamandar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"TuranKamandar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.r > sm.albedo_color.b,
		"TuranKamandar albedo red must exceed blue (Turan red, not Iran blue), "
		+ "got r=%.2f b=%.2f" % [sm.albedo_color.r, sm.albedo_color.b])
	assert_true(sm.albedo_color.r > 0.4,
		"TuranKamandar albedo red channel must be high (Turan palette), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.3,
		"TuranKamandar albedo blue channel must be low (Turan red, not Iran blue), got b=%.2f"
			% sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — TEAM_TURAN plumbing
# ---------------------------------------------------------------------------

func test_turan_kamandar_team_can_be_assigned_turan() -> void:
	_tk = _spawn_turan_kamandar(Constants.TEAM_TURAN)
	var sa: Node = _tk.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
		"TuranKamandar.team must be mirrored to SpatialAgentComponent.team as TEAM_TURAN")


# ---------------------------------------------------------------------------
# Construction-without-scene
# ---------------------------------------------------------------------------

func test_turan_kamandar_script_directly_constructable() -> void:
	var bare: Variant = TuranKamandarScript.new()
	assert_eq(bare.unit_type, &"turan_kamandar",
		"TuranKamandar.new() (no scene) must set unit_type = &\"turan_kamandar\" in _init")
	bare.free()
