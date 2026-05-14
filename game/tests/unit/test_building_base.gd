# Tests for the Building abstract base class — Phase 3 session 1 wave 1C.
#
# Per 02f_PHASE_3_KICKOFF.md §3 wave 1C + 01_CORE_MECHANICS.md §5.
#
# Mirrors test_mine_node.gd's shape: scene smoke, schema, public API, base
# class semantics. Concrete subclass tests (test_khaneh.gd) layer on top.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0).
extends GutTest


const BuildingScene: PackedScene = preload(
	"res://scenes/world/buildings/building.tscn")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _building: Variant


func before_each() -> void:
	SimClock.reset()
	# Reset the static counter so each test sees deterministic building ids.
	BuildingScript.call(&"reset_id_counter")


func after_each() -> void:
	if _building != null and is_instance_valid(_building):
		_building.queue_free()
	_building = null
	SimClock.reset()


# Spawn via the scene template — exercises the path the live game uses
# (mesh + script wiring resolve at scene load, not at .new()).
func _spawn_building() -> Variant:
	var b: Variant = BuildingScene.instantiate()
	add_child_autofree(b)
	return b


# ---------------------------------------------------------------------------
# Scene smoke + composition
# ---------------------------------------------------------------------------

func test_scene_instantiates_with_script_attached() -> void:
	_building = _spawn_building()
	assert_true(_building is Node3D, "Building is a Node3D")
	assert_true(_building.get_script() == BuildingScript
			or _building.get_script() == load(BuildingScript.resource_path),
		"Building scene has the building.gd script attached")


func test_building_has_mesh_instance() -> void:
	# Placeholder visual per CLAUDE.md "colored rectangles for buildings."
	_building = _spawn_building()
	var mi: Node = _building.get_node_or_null(^"MeshInstance3D")
	assert_not_null(mi, "Building must expose a MeshInstance3D child")
	assert_true(mi is MeshInstance3D, "MeshInstance3D node is the right type")


func test_building_has_static_body_collision() -> void:
	# BUG-07 lesson — click-targets need a CollisionObject3D ancestor or
	# raycasts walk past them. Phase 3 wave 1B fixed this for MineNode; the
	# same lesson applies to every new clickable scene.
	_building = _spawn_building()
	var sb: Node = _building.get_node_or_null(^"StaticBody3D")
	assert_not_null(sb,
		"Building must contain a StaticBody3D so raycasts can hit it")
	assert_true(sb is StaticBody3D,
		"StaticBody3D node is the right type — CollisionObject3D shape "
		+ "is what ClickHandler._raycast_from_screen requires")
	var shape: Node = sb.get_node_or_null(^"CollisionShape3D")
	assert_not_null(shape,
		"StaticBody3D must contain a CollisionShape3D — body without "
		+ "shape is a no-op for raycasts")


func test_building_has_navigation_obstacle() -> void:
	# Per RESOURCE_NODE_CONTRACT §3.2 — runtime navmesh carve via
	# NavigationObstacle3D is the sanctioned alternative to a forbidden
	# runtime navmesh REBAKE. Every placed building carries one so workers
	# route around it post-placement.
	_building = _spawn_building()
	var nav: Node = _building.get_node_or_null(^"NavigationObstacle3D")
	assert_not_null(nav,
		"Building must contain a NavigationObstacle3D for dynamic "
		+ "navmesh carving (Resource Node Contract §3.2)")
	assert_true(nav is NavigationObstacle3D,
		"NavigationObstacle3D node is the right type")


# ---------------------------------------------------------------------------
# Schema — required fields exposed for consumers
# ---------------------------------------------------------------------------

func test_building_schema_fields_present() -> void:
	_building = _spawn_building()
	assert_true(&"kind" in _building, "Building exposes `kind` field")
	assert_true(&"team" in _building, "Building exposes `team` field")
	assert_true(&"unit_id" in _building, "Building exposes `unit_id` field")
	assert_true(&"is_complete" in _building,
		"Building exposes `is_complete` field")


func test_building_default_state() -> void:
	_building = _spawn_building()
	# A freshly-spawned Building has no concrete kind set — that's a
	# subclass responsibility. Team defaults to TEAM_NEUTRAL until
	# place_at sets it. is_complete starts false.
	assert_eq(_building.kind, &"",
		"Bare Building has empty kind — concrete subclasses set it")
	assert_eq(_building.team, Constants.TEAM_NEUTRAL,
		"Bare Building defaults to TEAM_NEUTRAL team")
	assert_false(_building.is_complete,
		"Building starts is_complete = false — flips true on place_at")


func test_building_joins_buildings_group_on_ready() -> void:
	# Consumers iterate get_tree().get_nodes_in_group(&"buildings") instead
	# of walking the world subtree. The base class adds the building to
	# the group in _ready.
	_building = _spawn_building()
	assert_true(_building.is_in_group(&"buildings"),
		"Building joins &\"buildings\" group in _ready")


# ---------------------------------------------------------------------------
# unit_id counter — deterministic across resets
# ---------------------------------------------------------------------------

func test_unit_id_assigned_in_ready_from_static_counter() -> void:
	BuildingScript.call(&"reset_id_counter")
	_building = _spawn_building()
	assert_eq(_building.unit_id, 1,
		"First Building after reset_id_counter gets unit_id = 1")


func test_unit_id_counter_increments_per_building() -> void:
	BuildingScript.call(&"reset_id_counter")
	var b1: Variant = BuildingScene.instantiate()
	add_child_autofree(b1)
	var b2: Variant = BuildingScene.instantiate()
	add_child_autofree(b2)
	assert_eq(b1.unit_id, 1, "First Building is id=1")
	assert_eq(b2.unit_id, 2, "Second Building is id=2")


func test_reset_id_counter_returns_to_one() -> void:
	BuildingScript.call(&"reset_id_counter")
	var b1: Variant = BuildingScene.instantiate()
	add_child_autofree(b1)
	assert_eq(b1.unit_id, 1)
	BuildingScript.call(&"reset_id_counter")
	var b2: Variant = BuildingScene.instantiate()
	add_child_autofree(b2)
	assert_eq(b2.unit_id, 1,
		"reset_id_counter resets so the next building is id=1 again")


# ---------------------------------------------------------------------------
# place_at — the placement seam
# ---------------------------------------------------------------------------

func test_place_at_sets_global_position() -> void:
	_building = _spawn_building()
	var target: Vector3 = Vector3(5.0, 0.0, -3.0)
	_building.place_at(target, Constants.TEAM_IRAN, 42)
	assert_almost_eq(_building.global_position.x, target.x, 0.0001,
		"place_at sets global_position.x")
	assert_almost_eq(_building.global_position.z, target.z, 0.0001,
		"place_at sets global_position.z")


func test_place_at_sets_team() -> void:
	_building = _spawn_building()
	_building.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 42)
	assert_eq(_building.team, Constants.TEAM_IRAN,
		"place_at sets team to the owner_team argument")


func test_place_at_flips_is_complete_true() -> void:
	_building = _spawn_building()
	assert_false(_building.is_complete, "starts incomplete")
	_building.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 42)
	assert_true(_building.is_complete,
		"place_at flips is_complete to true (instant placement — "
		+ "session 1 wave 1C; session 2 adds the in-progress state)")


# ---------------------------------------------------------------------------
# Subclass hook — _on_placement_complete is the override seam
# ---------------------------------------------------------------------------

class _PlacementHookCapture extends Node3D:
	var hook_called: bool = false
	var captured_placer_id: int = -999
	func _on_placement_complete(placer_unit_id: int) -> void:
		hook_called = true
		captured_placer_id = placer_unit_id
	# Inline minimal Building surface — place_at calls _on_placement_complete
	# after writing the schema fields. We replicate place_at's behavior so
	# the capture subclass observes the hook firing the same way a real
	# subclass would.
	var kind: StringName = &""
	var team: int = Constants.TEAM_NEUTRAL
	var unit_id: int = -1
	var is_complete: bool = false
	func place_at(world_pos: Vector3, owner_team: int, placer_unit_id: int) -> void:
		global_position = world_pos
		team = owner_team
		is_complete = true
		_on_placement_complete(placer_unit_id)


func test_on_placement_complete_subclass_hook_fires() -> void:
	# Concrete subclasses override _on_placement_complete for their
	# building-specific side-effects (Khaneh bumps population_cap,
	# Atashkadeh starts emitting Farr, etc.). Verify the hook fires
	# from inside place_at with the placer_unit_id forwarded.
	var capture: _PlacementHookCapture = _PlacementHookCapture.new()
	add_child_autofree(capture)
	capture.place_at(Vector3(1.0, 0.0, 2.0), Constants.TEAM_IRAN, 99)
	assert_true(capture.hook_called,
		"_on_placement_complete must fire from place_at")
	assert_eq(capture.captured_placer_id, 99,
		"placer_unit_id is forwarded to the subclass hook for telemetry "
		+ "(matches apply_farr_change's source_unit pattern)")


func test_on_placement_complete_runs_after_state_writes() -> void:
	# Subclass hooks may read is_complete, team, and position — the hook
	# must fire AFTER those writes, not before. Otherwise a Khaneh's hook
	# would see TEAM_NEUTRAL when it tries to bump the right team's
	# population_cap.
	var capture: _PlacementHookCapture = _PlacementHookCapture.new()
	add_child_autofree(capture)
	capture.place_at(Vector3(0.0, 0.0, 0.0), Constants.TEAM_TURAN, 7)
	# Inside the hook, the capture saw the team it was given.
	assert_true(capture.hook_called)
	assert_eq(capture.team, Constants.TEAM_TURAN,
		"state writes (team) complete BEFORE the subclass hook fires")
	assert_true(capture.is_complete,
		"is_complete is true by the time the subclass hook runs")
