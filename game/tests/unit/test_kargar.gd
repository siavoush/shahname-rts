# Tests for the Kargar (Iran worker) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (Iran units, Kargar = worker)
#   - 02b_PHASE_1_KICKOFF.md §2 deliverable 5 (Kargar — first concrete unit type)
#   - kickoff prompt §"Your wave-2 deliverables" #1
#
# What we cover:
#   - kargar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a Kargar (class) and a Unit (parent class)
#   - unit_type == &"kargar" so Unit._apply_balance_data_defaults reads
#     the right BalanceData entry
#   - max_hp comes from BalanceData (60.0 → hp_x100 = 6000)
#   - move_speed comes from BalanceData (3.5)
#   - The mesh override is in place (CylinderMesh, not the base BoxMesh)
#   - The material override is in place (sandy/brown albedo, not base
#     blue-grey)
#   - All component nodes from the inherited unit.tscn are still present
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_unit.gd.
extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const KargarScript: Script = preload("res://scripts/units/kargar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _kargar: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	SimClock.reset()


# Helper — instantiate a Kargar and add it to the test scene tree so
# _ready runs (which is when BalanceData defaults get applied to
# components).
func _spawn_kargar(team: int = Constants.TEAM_IRAN) -> Variant:
	var k: Variant = KargarScene.instantiate()
	k.team = team
	add_child_autofree(k)
	return k


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_kargar_scene_loads() -> void:
	_kargar = _spawn_kargar()
	assert_not_null(_kargar, "kargar.tscn must load to a non-null node")


func test_kargar_inherits_unit_components() -> void:
	# The kargar.tscn inherits from unit.tscn; every component the parent
	# scene declares must be in the tree on the inherited child.
	_kargar = _spawn_kargar()
	assert_not_null(_kargar.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on Kargar")
	assert_not_null(_kargar.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on Kargar")
	assert_not_null(_kargar.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on Kargar")
	assert_not_null(_kargar.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on Kargar")
	assert_not_null(_kargar.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on Kargar")
	assert_not_null(_kargar.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on Kargar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_kargar_is_a_unit() -> void:
	# Kargar extends Unit; the instance must satisfy "is a Unit" so existing
	# selection / command / AI code that types against Unit works without
	# special-casing each subclass. We assert this via script-base-walk
	# rather than `_kargar is Unit` to dodge the class_name registry race
	# (test files parse before the runtime registry has settled — same
	# reason kargar.gd uses path-string extends, see kargar.gd doc comment).
	_kargar = _spawn_kargar()
	var s: Script = _kargar.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"Kargar instance must inherit from unit.gd somewhere in its script chain")


func test_kargar_unit_type_is_kargar_string_name() -> void:
	# Unit._apply_balance_data_defaults uses unit_type as the BalanceData
	# key. If this is wrong, hp / move_speed / costs all silently fall
	# back to whatever the scene defaults are.
	_kargar = _spawn_kargar()
	assert_eq(_kargar.unit_type, &"kargar",
		"Kargar.unit_type must be the StringName &\"kargar\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — the whole point of unit_type being right
# ---------------------------------------------------------------------------

func test_kargar_max_hp_matches_balance_data() -> void:
	# balance.tres declares unit_kargar.max_hp = 60.0 → hp_x100 = 6000.
	# This is the assert that proves Unit._apply_balance_data_defaults
	# saw &"kargar" and looked up the right entry.
	_kargar = _spawn_kargar()
	var h: Node = _kargar.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), 6000,
		"Kargar max_hp_x100 must be 6000 (60.0 from balance.tres unit_kargar.max_hp)")
	assert_eq(int(h.get(&"hp_x100")), 6000,
		"Kargar hp_x100 starts full (init_max_hp sets both max and current)")


func test_kargar_move_speed_matches_balance_data() -> void:
	# balance.tres declares unit_kargar.move_speed = 3.5.
	_kargar = _spawn_kargar()
	var m: Node = _kargar.get_movement()
	assert_not_null(m, "MovementComponent must be reachable via get_movement()")
	assert_almost_eq(float(m.get(&"move_speed")), 3.5, 0.01,
		"Kargar move_speed must be 3.5 (from balance.tres unit_kargar.move_speed)")


# ---------------------------------------------------------------------------
# Mesh override — visually distinct from base unit.tscn
# ---------------------------------------------------------------------------

func test_kargar_uses_cylinder_mesh_not_base_boxmesh() -> void:
	# The base unit.tscn ships a BoxMesh as the placeholder. Kargar
	# overrides to a CylinderMesh so the worker is visually distinct from
	# future cube-based unit types. If this regresses, the placeholder
	# silhouette differentiation regresses with it.
	_kargar = _spawn_kargar()
	var mi: MeshInstance3D = _kargar.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is CylinderMesh,
		"Kargar mesh must be CylinderMesh (placeholder worker silhouette), got %s"
			% [mi.mesh.get_class()])


func test_kargar_material_is_brown_not_blue_grey() -> void:
	# The base unit.tscn material is a blue-grey (0.3, 0.5, 0.7). Kargar
	# overrides to sandy brown (0.65, 0.5, 0.3). This catches the
	# class of bug where the material override silently fails to apply
	# and a Kargar appears in the wrong color.
	_kargar = _spawn_kargar()
	var mi: MeshInstance3D = _kargar.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Kargar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Kargar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	# Channel-by-channel approximate match on the brown placeholder. We
	# don't pin exact values here — if balance/visuals tweaks the brown
	# slightly in the future, this test should still pass for "still in
	# the brown family." But it must NOT be the blue-grey of the base.
	assert_true(sm.albedo_color.r > 0.5,
		"Kargar albedo red channel must be high (brown), got r=%.2f" % sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.5,
		"Kargar albedo blue channel must be low (brown, not blue-grey), got b=%.2f"
			% sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — set externally by spawn code
# ---------------------------------------------------------------------------

func test_kargar_team_can_be_assigned() -> void:
	# Kargar is the Iran worker but the unit class itself is team-agnostic;
	# the spawn code (main.gd) assigns Constants.TEAM_IRAN. A test here
	# just asserts the team plumbing works (Unit._ready mirrors team to
	# SpatialAgentComponent).
	_kargar = _spawn_kargar(Constants.TEAM_IRAN)
	var sa: Node = _kargar.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_IRAN,
		"Kargar.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_kargar_script_directly_constructable() -> void:
	# Some test scenarios will construct a Kargar without going through
	# the .tscn (e.g., harness fixtures that don't want the visual
	# children). The class itself, when instantiated bare, should still
	# self-tag with unit_type = &"kargar" via _init.
	var bare: Variant = KargarScript.new()
	assert_eq(bare.unit_type, &"kargar",
		"Kargar.new() (no scene) must set unit_type = &\"kargar\" in _init")
	# Free without going through queue_free (no scene tree parent).
	bare.free()
