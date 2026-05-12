# Tests for the Savar (Iran cavalry) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (Iran units, Savar = heavy mounted infantry)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 2 (cavalry roster)
#
# What we cover:
#   - savar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a Savar (class) and a Unit (parent class)
#   - unit_type == &"savar" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry
#   - max_hp / move_speed / attack_damage_x100 / attack_speed_per_sec /
#     attack_range all wire through from BalanceData (whatever balance.tres
#     declares)
#   - The mesh override is a BoxMesh, larger than Piyade's (the heavier
#     cavalry silhouette)
#   - The material override is Iran-blue deeper-saturated (high blue, low
#     red), distinguishable from Piyade's lighter blue and Kamandar's darker
#     variant
#   - Team plumbing mirrors to SpatialAgentComponent
#   - Bare Savar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer is populating BalanceData entries
# IN PARALLEL. Tests read balance.tres at test-time and assert wiring,
# not numbers — same pattern as test_kamandar.gd.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0).
extends GutTest


const SavarScene: PackedScene = preload("res://scenes/units/savar.tscn")
const SavarScript: Script = preload("res://scripts/units/savar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _savar: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _savar != null and is_instance_valid(_savar):
		_savar.queue_free()
	_savar = null
	SimClock.reset()


func _spawn_savar(team: int = Constants.TEAM_IRAN) -> Variant:
	var s: Variant = SavarScene.instantiate()
	s.team = team
	add_child_autofree(s)
	return s


func _load_savar_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	return (units as Dictionary).get(&"savar", null)


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_savar_scene_loads() -> void:
	_savar = _spawn_savar()
	assert_not_null(_savar, "savar.tscn must load to a non-null node")


func test_savar_inherits_unit_components() -> void:
	_savar = _spawn_savar()
	assert_not_null(_savar.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on Savar")
	assert_not_null(_savar.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on Savar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_savar_is_a_unit() -> void:
	_savar = _spawn_savar()
	var s: Script = _savar.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"Savar instance must inherit from unit.gd somewhere in its script chain")


func test_savar_unit_type_is_savar_string_name() -> void:
	_savar = _spawn_savar()
	assert_eq(_savar.unit_type, &"savar",
		"Savar.unit_type must be the StringName &\"savar\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — wiring verification, not number pinning
# ---------------------------------------------------------------------------

func test_savar_max_hp_wires_through_balance_data() -> void:
	var stats: Variant = _load_savar_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"savar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_savar = _spawn_savar()
	var h: Node = _savar.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"Savar max_hp_x100 must wire through BalanceData unit_savar.max_hp (got %s)"
			% [expected_max_hp])


func test_savar_move_speed_wires_through_balance_data() -> void:
	# Cavalry must be FAST — kickoff §2 deliverable 2 specifies move_speed
	# 4.5 (vs Piyade's 2.5). Verify the BalanceData → MovementComponent
	# wiring carries this value through.
	var stats: Variant = _load_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"savar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_savar = _spawn_savar()
	var m: Node = _savar.get_movement()
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"Savar move_speed must wire through BalanceData unit_savar.move_speed")
	# Sanity: cavalry should be faster than Piyade's 2.5 (otherwise it's just
	# a beefier Piyade — not the cavalry charge archetype).
	assert_true(expected_speed > 2.5,
		"Savar move_speed must exceed Piyade's 2.5 (cavalry-charge invariant), "
		+ "got %s" % [expected_speed])


func test_savar_attack_damage_wires_through_balance_data() -> void:
	var stats: Variant = _load_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_savar.attack_damage_x100 not yet populated."
		)
		return
	_savar = _spawn_savar()
	var c: Node = _savar.get_combat()
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"Savar attack_damage_x100 must wire through BalanceData")


func test_savar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_savar.attack_speed_per_sec not yet populated.")
		return
	_savar = _spawn_savar()
	var c: Node = _savar.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"Savar attack_speed_per_sec must wire through BalanceData")


func test_savar_attack_range_is_melee() -> void:
	# Savar is melee cavalry — range slightly longer than Piyade (mounted
	# reach), but still functionally melee (well under 5.0). This is the
	# inverse of Kamandar's ranged-invariant test.
	var stats: Variant = _load_savar_stats()
	if stats == null:
		pending("BalanceData entry for &\"savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_savar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_savar = _spawn_savar()
	var c: Node = _savar.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"Savar attack_range must wire through BalanceData")
	assert_true(expected_range < 5.0,
		"Savar attack_range must be melee (< 5.0 — under Kamandar's ranged "
		+ "threshold), got %s" % [expected_range])


# ---------------------------------------------------------------------------
# Mesh override — bigger silhouette than Piyade (the cavalry visual cue)
# ---------------------------------------------------------------------------

func test_savar_uses_box_mesh_larger_than_piyade() -> void:
	# Per kickoff §2 deliverable 2: Savar visual is "larger cube/rectangle
	# (size Vector3(0.7, 0.6, 0.7))". Larger than Piyade's 0.5 × 0.7 × 0.5
	# in WIDTH (the horse + rider footprint). Read as cavalry by mass.
	_savar = _spawn_savar()
	var mi: MeshInstance3D = _savar.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"Savar mesh must be BoxMesh (heavier cavalry silhouette), got %s"
			% [mi.mesh.get_class()])
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.x, 0.7, 0.001,
		"Savar BoxMesh width (X) must be 0.7 (wider than Piyade's 0.5 — cavalry footprint)")
	assert_almost_eq(bm.size.z, 0.7, 0.001,
		"Savar BoxMesh depth (Z) must be 0.7 (wider than Piyade's 0.5)")
	# Width invariant — the load-bearing visual cue is "this is wider than
	# the foot infantry" (horse + rider). Height isn't the differentiator.
	assert_true(bm.size.x > 0.5,
		"Savar must be wider than Piyade's 0.5 box (cavalry visual cue)")


func test_savar_material_is_iran_blue_deeper_saturated() -> void:
	# Iran-blue deeper saturated per kickoff: Color(0.15, 0.25, 0.65) — high
	# blue (>0.5), low red (<0.3). Distinct from Piyade (0.3, 0.4, 0.7) by
	# being darker/deeper blue, and from Kamandar (0.20, 0.30, 0.55) by
	# being more saturated. The deep-blue cue communicates "heavy elite cav".
	_savar = _spawn_savar()
	var mi: MeshInstance3D = _savar.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Savar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Savar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.b > 0.5,
		"Savar albedo blue must be high (Iran palette), got b=%.2f"
			% sm.albedo_color.b)
	assert_true(sm.albedo_color.r < 0.3,
		"Savar albedo red channel must be low (Iran palette, not Turan-red), got r=%.2f"
			% sm.albedo_color.r)
	# Distinct from Kamandar: Savar is more BLUE-SATURATED (closer to pure
	# Iran-blue), Kamandar is more muted.
	assert_true(sm.albedo_color.b - sm.albedo_color.r > 0.3,
		"Savar blue-vs-red contrast must exceed 0.3 (deep saturated blue), "
		+ "got b-r=%.2f" % (sm.albedo_color.b - sm.albedo_color.r))


# ---------------------------------------------------------------------------
# Team — set externally by spawn code
# ---------------------------------------------------------------------------

func test_savar_team_can_be_assigned() -> void:
	_savar = _spawn_savar(Constants.TEAM_IRAN)
	var sa: Node = _savar.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_IRAN,
		"Savar.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_savar_script_directly_constructable() -> void:
	var bare: Variant = SavarScript.new()
	assert_eq(bare.unit_type, &"savar",
		"Savar.new() (no scene) must set unit_type = &\"savar\" in _init")
	bare.free()
