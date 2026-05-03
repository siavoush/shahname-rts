# Tests for the Piyade (Iran foot infantry) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (Iran units, Piyade = foot infantry)
#   - 02d_PHASE_2_KICKOFF.md §2 deliverable 5 (first Iran combat unit type)
#
# What we cover:
#   - piyade.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a Piyade (class) and a Unit (parent class)
#   - unit_type == &"piyade" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry
#   - max_hp comes from BalanceData (100.0 → hp_x100 = 10000)
#   - move_speed comes from BalanceData (2.5)
#   - attack_damage_x100 comes from BalanceData (1000)
#   - attack_speed_per_sec comes from BalanceData (1.0)
#   - attack_range comes from BalanceData (1.5)
#   - The mesh override is in place (BoxMesh, taller than Kargar)
#   - The material override is Iran-blue (high blue, lower red than Kargar)
#   - Team plumbing mirrors to SpatialAgentComponent
#   - Bare Piyade.new() construction sets unit_type
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_kargar.gd.
extends GutTest


const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const PiyadeScript: Script = preload("res://scripts/units/piyade.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _piyade: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _piyade != null and is_instance_valid(_piyade):
		_piyade.queue_free()
	_piyade = null
	SimClock.reset()


# Helper — instantiate a Piyade and add it to the test scene tree so
# _ready runs (which is when BalanceData defaults get applied to
# components).
func _spawn_piyade(team: int = Constants.TEAM_IRAN) -> Variant:
	var p: Variant = PiyadeScene.instantiate()
	p.team = team
	add_child_autofree(p)
	return p


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_piyade_scene_loads() -> void:
	_piyade = _spawn_piyade()
	assert_not_null(_piyade, "piyade.tscn must load to a non-null node")


func test_piyade_inherits_unit_components() -> void:
	# The piyade.tscn inherits from unit.tscn; every component the parent
	# scene declares must be in the tree on the inherited child —
	# including CombatComponent (wave 1A).
	_piyade = _spawn_piyade()
	assert_not_null(_piyade.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on Piyade")
	assert_not_null(_piyade.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on Piyade")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_piyade_is_a_unit() -> void:
	# Piyade extends Unit; assert via script-base-walk to dodge the class_name
	# registry race (same pattern as test_kargar.gd).
	_piyade = _spawn_piyade()
	var s: Script = _piyade.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"Piyade instance must inherit from unit.gd somewhere in its script chain")


func test_piyade_unit_type_is_piyade_string_name() -> void:
	# Unit._apply_balance_data_defaults uses unit_type as the BalanceData
	# key. If this is wrong, all combat fields silently fall back to
	# component defaults.
	_piyade = _spawn_piyade()
	assert_eq(_piyade.unit_type, &"piyade",
		"Piyade.unit_type must be the StringName &\"piyade\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — combat fields are the new wave-1A read seams
# ---------------------------------------------------------------------------

func test_piyade_max_hp_matches_balance_data() -> void:
	# balance.tres declares unit_piyade.max_hp = 100.0 → hp_x100 = 10000.
	_piyade = _spawn_piyade()
	var h: Node = _piyade.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), 10000,
		"Piyade max_hp_x100 must be 10000 (100.0 from balance.tres unit_piyade.max_hp)")
	assert_eq(int(h.get(&"hp_x100")), 10000,
		"Piyade hp_x100 starts full (init_max_hp sets both max and current)")


func test_piyade_move_speed_matches_balance_data() -> void:
	# balance.tres declares unit_piyade.move_speed = 2.5.
	_piyade = _spawn_piyade()
	var m: Node = _piyade.get_movement()
	assert_not_null(m, "MovementComponent must be reachable via get_movement()")
	assert_almost_eq(float(m.get(&"move_speed")), 2.5, 0.01,
		"Piyade move_speed must be 2.5 (from balance.tres unit_piyade.move_speed)")


func test_piyade_attack_damage_matches_balance_data() -> void:
	# balance.tres declares unit_piyade.attack_damage_x100 = 1000.
	_piyade = _spawn_piyade()
	var c: Node = _piyade.get_combat()
	assert_not_null(c, "CombatComponent must be reachable via get_combat()")
	assert_eq(int(c.get(&"attack_damage_x100")), 1000,
		"Piyade attack_damage_x100 must be 1000 (from balance.tres unit_piyade.attack_damage_x100)")


func test_piyade_attack_speed_matches_balance_data() -> void:
	# balance.tres declares unit_piyade.attack_speed_per_sec = 1.0.
	_piyade = _spawn_piyade()
	var c: Node = _piyade.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), 1.0, 0.01,
		"Piyade attack_speed_per_sec must be 1.0 (from balance.tres)")


func test_piyade_attack_range_matches_balance_data() -> void:
	# balance.tres declares unit_piyade.attack_range = 1.5.
	_piyade = _spawn_piyade()
	var c: Node = _piyade.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), 1.5, 0.01,
		"Piyade attack_range must be 1.5 (from balance.tres)")


# ---------------------------------------------------------------------------
# Mesh override — visually distinct from base unit.tscn AND Kargar
# ---------------------------------------------------------------------------

func test_piyade_uses_box_mesh_with_taller_height() -> void:
	# The Piyade overrides to a BoxMesh sized 0.5 × 0.7 × 0.5 — taller than
	# the base unit's 0.5 × 0.6 × 0.5. The +0.1 height differentiates Piyade
	# from any future cube-based worker / specialist.
	_piyade = _spawn_piyade()
	var mi: MeshInstance3D = _piyade.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"Piyade mesh must be BoxMesh (placeholder soldier silhouette), got %s"
			% [mi.mesh.get_class()])
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.y, 0.7, 0.001,
		"Piyade BoxMesh height must be 0.7 (taller than base 0.6)")


func test_piyade_material_is_iran_blue() -> void:
	# Iran-blue albedo: high blue (>0.6), low red (<0.4). Distinguishable
	# from the base unit blue-grey AND from the Kargar sandy brown.
	_piyade = _spawn_piyade()
	var mi: MeshInstance3D = _piyade.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Piyade must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Piyade material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.b > 0.6,
		"Piyade albedo blue channel must be high (Iran blue), got b=%.2f"
			% sm.albedo_color.b)
	assert_true(sm.albedo_color.r < 0.4,
		"Piyade albedo red channel must be low (Iran blue, not Turan-red), got r=%.2f"
			% sm.albedo_color.r)


# ---------------------------------------------------------------------------
# Team — set externally by spawn code
# ---------------------------------------------------------------------------

func test_piyade_team_can_be_assigned() -> void:
	# Same team-plumbing assertion as test_kargar.gd. Iran Piyade is set to
	# Constants.TEAM_IRAN by main.gd's spawn code.
	_piyade = _spawn_piyade(Constants.TEAM_IRAN)
	var sa: Node = _piyade.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_IRAN,
		"Piyade.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_piyade_script_directly_constructable() -> void:
	# Test scenarios that construct a Piyade without going through the .tscn
	# (e.g., harness fixtures that don't want the visual children) must still
	# get unit_type = &"piyade" via _init.
	var bare: Variant = PiyadeScript.new()
	assert_eq(bare.unit_type, &"piyade",
		"Piyade.new() (no scene) must set unit_type = &\"piyade\" in _init")
	# Free without going through queue_free (no scene tree parent).
	bare.free()
