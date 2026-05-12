# Tests for the Kamandar (Iran archer) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (Iran units, Kamandar = ranged infantry)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 1 (first ranged Iran unit)
#
# What we cover:
#   - kamandar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a Kamandar (class) and a Unit (parent class)
#   - unit_type == &"kamandar" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry
#   - max_hp wires through from BalanceData (whatever balance.tres declares)
#   - move_speed wires through from BalanceData
#   - attack_damage_x100 wires through from BalanceData
#   - attack_speed_per_sec wires through from BalanceData
#   - attack_range wires through from BalanceData (the ranged-attack signal)
#   - The mesh override is a CylinderMesh, tall and narrow (the bow-guy silhouette)
#   - The material override is Iran-blue darker variant (high blue, low red,
#     darker than Piyade's blue)
#   - Team plumbing mirrors to SpatialAgentComponent
#   - Bare Kamandar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer is populating BalanceData entries
# for kamandar / savar / turan_kamandar / turan_savar IN PARALLEL with this
# wave (1A). This test deliberately reads balance.tres at test-time and
# asserts the component value matches what BalanceData says — that way the
# test verifies WIRING (the unit reads from BalanceData), not NUMBERS (which
# balance-engineer owns). When wave-1B's balance.tres entries land, these
# tests pin the wiring; when balance-engineer tunes numbers, no test churn.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_piyade.gd.
extends GutTest


const KamandarScene: PackedScene = preload("res://scenes/units/kamandar.tscn")
const KamandarScript: Script = preload("res://scripts/units/kamandar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _kamandar: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _kamandar != null and is_instance_valid(_kamandar):
		_kamandar.queue_free()
	_kamandar = null
	SimClock.reset()


# Helper — instantiate a Kamandar and add it to the test scene tree so
# _ready runs (which is when BalanceData defaults get applied to
# components).
func _spawn_kamandar(team: int = Constants.TEAM_IRAN) -> Variant:
	var k: Variant = KamandarScene.instantiate()
	k.team = team
	add_child_autofree(k)
	return k


# Helper — read the kamandar UnitStats sub-resource from balance.tres at
# test-time. Returns null if BalanceData isn't loadable or the entry is
# missing (wave-1B not yet shipped in the parallel-wave window).
func _load_kamandar_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	return (units as Dictionary).get(&"kamandar", null)


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_kamandar_scene_loads() -> void:
	_kamandar = _spawn_kamandar()
	assert_not_null(_kamandar, "kamandar.tscn must load to a non-null node")


func test_kamandar_inherits_unit_components() -> void:
	# The kamandar.tscn inherits from unit.tscn; every component the parent
	# scene declares must be in the tree on the inherited child.
	_kamandar = _spawn_kamandar()
	assert_not_null(_kamandar.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on Kamandar")
	assert_not_null(_kamandar.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on Kamandar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_kamandar_is_a_unit() -> void:
	# Kamandar extends Unit; assert via script-base-walk to dodge the class_name
	# registry race (same pattern as test_kargar.gd / test_piyade.gd).
	_kamandar = _spawn_kamandar()
	var s: Script = _kamandar.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"Kamandar instance must inherit from unit.gd somewhere in its script chain")


func test_kamandar_unit_type_is_kamandar_string_name() -> void:
	# Unit._apply_balance_data_defaults uses unit_type as the BalanceData
	# key. If this is wrong, all combat fields silently fall back to
	# component defaults.
	_kamandar = _spawn_kamandar()
	assert_eq(_kamandar.unit_type, &"kamandar",
		"Kamandar.unit_type must be the StringName &\"kamandar\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — wiring verification, not number pinning.
# Tests load balance.tres at runtime and assert components match.
# ---------------------------------------------------------------------------

func test_kamandar_max_hp_wires_through_balance_data() -> void:
	# Verify Unit._apply_balance_data_defaults pipes max_hp from
	# BalanceData.units[&"kamandar"].max_hp into HealthComponent.max_hp_x100.
	# Number is whatever balance-engineer wave-1B landed in balance.tres.
	var stats: Variant = _load_kamandar_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"kamandar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_kamandar = _spawn_kamandar()
	var h: Node = _kamandar.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"Kamandar max_hp_x100 must wire through BalanceData unit_kamandar.max_hp (got %s)"
			% [expected_max_hp])


func test_kamandar_move_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"kamandar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_kamandar = _spawn_kamandar()
	var m: Node = _kamandar.get_movement()
	assert_not_null(m, "MovementComponent must be reachable via get_movement()")
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"Kamandar move_speed must wire through BalanceData unit_kamandar.move_speed")


func test_kamandar_attack_damage_wires_through_balance_data() -> void:
	# The new wave-1B contract: attack_damage_x100 must be populated for
	# combat units. If missing or 0, Kamandar can't attack and is broken.
	var stats: Variant = _load_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_kamandar.attack_damage_x100 not yet populated "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	_kamandar = _spawn_kamandar()
	var c: Node = _kamandar.get_combat()
	assert_not_null(c, "CombatComponent must be reachable via get_combat()")
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"Kamandar attack_damage_x100 must wire through BalanceData")


func test_kamandar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_kamandar.attack_speed_per_sec not yet populated.")
		return
	_kamandar = _spawn_kamandar()
	var c: Node = _kamandar.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"Kamandar attack_speed_per_sec must wire through BalanceData")


func test_kamandar_attack_range_wires_through_balance_data() -> void:
	# attack_range is the load-bearing field for "is this unit ranged?" —
	# Piyade has 1.5 (melee), Kamandar has ~8.0 (ranged). The ranged-vs-melee
	# distinction is the entire point of this unit type.
	var stats: Variant = _load_kamandar_stats()
	if stats == null:
		pending("BalanceData entry for &\"kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_kamandar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_kamandar = _spawn_kamandar()
	var c: Node = _kamandar.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"Kamandar attack_range must wire through BalanceData (ranged > melee)")
	assert_true(expected_range >= 5.0,
		"Kamandar attack_range must be at least 5.0 to read as ranged "
		+ "(melee Piyade is 1.5; got %s)" % [expected_range])


# ---------------------------------------------------------------------------
# Mesh override — visually distinct silhouette (the bow-guy)
# ---------------------------------------------------------------------------

func test_kamandar_uses_cylinder_mesh_tall_and_narrow() -> void:
	# Kickoff §2 deliverable 1: Kamandar visual is "tall narrow cylinder
	# (height 0.9, radius 0.25 — distinguishably 'the bow guy')". This
	# differentiates Kamandar from the cube-based Piyade and the squat
	# Kargar cylinder.
	_kamandar = _spawn_kamandar()
	var mi: MeshInstance3D = _kamandar.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is CylinderMesh,
		"Kamandar mesh must be CylinderMesh (tall-narrow archer silhouette), got %s"
			% [mi.mesh.get_class()])
	var cm: CylinderMesh = mi.mesh as CylinderMesh
	assert_almost_eq(cm.height, 0.9, 0.001,
		"Kamandar CylinderMesh height must be 0.9 (taller than Kargar's 0.7)")
	assert_almost_eq(cm.top_radius, 0.25, 0.001,
		"Kamandar CylinderMesh top_radius must be 0.25 (narrower than Kargar's 0.35)")


func test_kamandar_material_is_iran_blue_darker() -> void:
	# Iran-blue darker variant per kickoff: Color(0.20, 0.30, 0.55) — high
	# blue (>0.4 to be unambiguously blue), low red (<0.35), and DARKER than
	# Piyade's (0.3, 0.4, 0.7). The dark variant is the visual cue for
	# "specialist Iran combat unit" vs. Piyade's lighter "core Iran infantry".
	_kamandar = _spawn_kamandar()
	var mi: MeshInstance3D = _kamandar.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Kamandar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Kamandar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.b > sm.albedo_color.r,
		"Kamandar albedo blue must exceed red (Iran blue, not Turan-red), "
		+ "got r=%.2f b=%.2f" % [sm.albedo_color.r, sm.albedo_color.b])
	assert_true(sm.albedo_color.r < 0.35,
		"Kamandar albedo red channel must be low (Iran palette), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.65,
		"Kamandar albedo blue must be DARKER than Piyade's 0.7 (specialist "
		+ "variant), got b=%.2f" % sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — set externally by spawn code
# ---------------------------------------------------------------------------

func test_kamandar_team_can_be_assigned() -> void:
	# Iran Kamandar is set to Constants.TEAM_IRAN by main.gd's spawn code
	# (extend in wave 2B). Assert the plumbing the same way Piyade does.
	_kamandar = _spawn_kamandar(Constants.TEAM_IRAN)
	var sa: Node = _kamandar.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_IRAN,
		"Kamandar.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_kamandar_script_directly_constructable() -> void:
	# Test scenarios that construct a Kamandar without going through the .tscn
	# (e.g., harness fixtures that don't want the visual children) must still
	# get unit_type = &"kamandar" via _init.
	var bare: Variant = KamandarScript.new()
	assert_eq(bare.unit_type, &"kamandar",
		"Kamandar.new() (no scene) must set unit_type = &\"kamandar\" in _init")
	bare.free()
