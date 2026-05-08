# Tests for the TuranSavar (Turan cavalry) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (units) + §11 (Turan faction red palette)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4 (Turan mirror roster)
#
# What we cover:
#   - turan_savar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a TuranSavar (class) and a Unit (parent class)
#   - unit_type == &"turan_savar" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry
#   - max_hp / move_speed / attack_damage_x100 / attack_speed_per_sec /
#     attack_range all wire through from BalanceData
#   - Mesh override is a BoxMesh with Savar dimensions (Vector3(0.7, 0.6, 0.7))
#     — same archetype silhouette as Iran Savar
#   - Material override is Turan-red deeper-saturated (high red, low blue)
#   - Team plumbing: TEAM_TURAN mirrors to SpatialAgentComponent
#   - Bare TuranSavar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer is populating BalanceData entries
# IN PARALLEL. Tests read balance.tres at test-time and assert wiring.
extends GutTest


const TuranSavarScene: PackedScene = preload("res://scenes/units/turan_savar.tscn")
const TuranSavarScript: Script = preload("res://scripts/units/turan_savar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _ts: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _ts != null and is_instance_valid(_ts):
		_ts.queue_free()
	_ts = null
	SimClock.reset()


func _spawn_turan_savar(team: int = Constants.TEAM_TURAN) -> Variant:
	var s: Variant = TuranSavarScene.instantiate()
	s.team = team
	add_child_autofree(s)
	return s


func _load_turan_savar_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	return (units as Dictionary).get(&"turan_savar", null)


# ---------------------------------------------------------------------------
# Visual smoke
# ---------------------------------------------------------------------------

func test_turan_savar_scene_loads() -> void:
	_ts = _spawn_turan_savar()
	assert_not_null(_ts, "turan_savar.tscn must load to a non-null node")


func test_turan_savar_inherits_unit_components() -> void:
	_ts = _spawn_turan_savar()
	assert_not_null(_ts.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on TuranSavar")
	assert_not_null(_ts.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on TuranSavar")


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

func test_turan_savar_is_a_unit() -> void:
	_ts = _spawn_turan_savar()
	var s: Script = _ts.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"TuranSavar instance must inherit from unit.gd somewhere in its script chain")


func test_turan_savar_unit_type_is_turan_savar_string_name() -> void:
	_ts = _spawn_turan_savar()
	assert_eq(_ts.unit_type, &"turan_savar",
		"TuranSavar.unit_type must be the StringName &\"turan_savar\"")


# ---------------------------------------------------------------------------
# BalanceData hookup — mirror of Iran Savar
# ---------------------------------------------------------------------------

func test_turan_savar_max_hp_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_savar_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"turan_savar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_ts = _spawn_turan_savar()
	var h: Node = _ts.get_health()
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"TuranSavar max_hp_x100 must wire through BalanceData")


func test_turan_savar_move_speed_wires_through_balance_data() -> void:
	# Cavalry mirror — must be faster than Piyade.
	var stats: Variant = _load_turan_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_savar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_ts = _spawn_turan_savar()
	var m: Node = _ts.get_movement()
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"TuranSavar move_speed must wire through BalanceData")
	assert_true(expected_speed > 2.5,
		"TuranSavar move_speed must exceed Piyade's 2.5 (cavalry-charge invariant)")


func test_turan_savar_attack_damage_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_turan_savar.attack_damage_x100 not yet populated."
		)
		return
	_ts = _spawn_turan_savar()
	var c: Node = _ts.get_combat()
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"TuranSavar attack_damage_x100 must wire through BalanceData")


func test_turan_savar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_turan_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_savar.attack_speed_per_sec not yet populated.")
		return
	_ts = _spawn_turan_savar()
	var c: Node = _ts.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"TuranSavar attack_speed_per_sec must wire through BalanceData")


func test_turan_savar_attack_range_is_melee() -> void:
	# Mirror of Iran Savar — melee, not ranged.
	var stats: Variant = _load_turan_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_savar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_ts = _spawn_turan_savar()
	var c: Node = _ts.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"TuranSavar attack_range must wire through BalanceData")
	assert_true(expected_range < 5.0,
		"TuranSavar attack_range must be melee (< 5.0) — mirror Iran Savar")


# ---------------------------------------------------------------------------
# Mesh override — same shape as Iran Savar, different color
# ---------------------------------------------------------------------------

func test_turan_savar_uses_box_mesh_with_savar_dimensions() -> void:
	# Same dimensions as Iran Savar (Vector3(0.7, 0.6, 0.7)). Mirror combat
	# means same silhouette — only team color differs.
	_ts = _spawn_turan_savar()
	var mi: MeshInstance3D = _ts.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"TuranSavar mesh must be BoxMesh (mirror Iran Savar)")
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.x, 0.7, 0.001,
		"TuranSavar BoxMesh width (X) must be 0.7 (mirror Iran Savar)")
	assert_almost_eq(bm.size.z, 0.7, 0.001,
		"TuranSavar BoxMesh depth (Z) must be 0.7 (mirror Iran Savar)")


func test_turan_savar_material_is_turan_red_deeper_saturated() -> void:
	# Turan-red deeper saturated per kickoff: Color(0.65, 0.15, 0.15) — high
	# red (>0.5), low blue (<0.3). Distinct from Iran-blue Savar (deep blue)
	# and from Turan_Piyade's brighter-but-less-saturated red. The deep-red
	# cue is the Turan analog of Savar's deep-blue: "heavy elite cavalry".
	_ts = _spawn_turan_savar()
	var mi: MeshInstance3D = _ts.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "TuranSavar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"TuranSavar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.r > sm.albedo_color.b,
		"TuranSavar albedo red must exceed blue (Turan red, not Iran blue), "
		+ "got r=%.2f b=%.2f" % [sm.albedo_color.r, sm.albedo_color.b])
	assert_true(sm.albedo_color.r > 0.5,
		"TuranSavar albedo red channel must be high (Turan palette), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.3,
		"TuranSavar albedo blue channel must be low (Turan red), got b=%.2f"
			% sm.albedo_color.b)
	# Distinct from TuranKamandar (0.55, 0.15, 0.15): Savar should be MORE
	# red-saturated (deeper red, the elite cavalry cue).
	assert_true(sm.albedo_color.r - sm.albedo_color.b > 0.4,
		"TuranSavar red-vs-blue contrast must exceed 0.4 (deep saturated red), "
		+ "got r-b=%.2f" % (sm.albedo_color.r - sm.albedo_color.b))


# ---------------------------------------------------------------------------
# Team — TEAM_TURAN plumbing
# ---------------------------------------------------------------------------

func test_turan_savar_team_can_be_assigned_turan() -> void:
	_ts = _spawn_turan_savar(Constants.TEAM_TURAN)
	var sa: Node = _ts.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
		"TuranSavar.team must be mirrored to SpatialAgentComponent.team as TEAM_TURAN")


# ---------------------------------------------------------------------------
# Construction-without-scene
# ---------------------------------------------------------------------------

func test_turan_savar_script_directly_constructable() -> void:
	var bare: Variant = TuranSavarScript.new()
	assert_eq(bare.unit_type, &"turan_savar",
		"TuranSavar.new() (no scene) must set unit_type = &\"turan_savar\" in _init")
	bare.free()
