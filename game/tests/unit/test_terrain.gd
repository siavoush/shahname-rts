extends GutTest
##
## Tests for the terrain plane and map configuration.
##
## Coverage:
##   - Constants.MAP_SIZE_WORLD is present and correct
##   - Constants.NAV_AGENT_RADIUS is present and correct
##   - Terrain scene loads cleanly
##   - Terrain mesh dimensions match MAP_SIZE_WORLD × MAP_SIZE_WORLD at Y=0
##   - NavigationRegion3D is present in the terrain scene
##   - NavigationRegion3D navigation map is valid after scene-load bake
##
## Per docs/ARCHITECTURE.md §4 — world-builder owns game/scripts/world/ and
## game/scenes/world/. Per docs/RESOURCE_NODE_CONTRACT.md §3.2: navmesh is
## baked once at scene-load; buildings add NavigationObstacle3D children
## to carve dynamically. No runtime rebake.
##
## Phase 0 deliverable: smallest terrain that proves nav, map size, and
## camera bounds can all share a single source of truth (Constants).
## Per Manifesto Principle 4 (Lean Iteration).


const TERRAIN_SCENE_PATH: String = "res://scenes/world/terrain.tscn"


# ---------------------------------------------------------------------------
# 1. Constants — map configuration keys
# ---------------------------------------------------------------------------

func test_map_size_world_constant_exists_and_is_correct() -> void:
	# MAP_SIZE_WORLD must be 256.0 — the convergence-locked map size.
	# Per 02_IMPLEMENTATION_PLAN.md Phase 0 and the convergence checkpoint.
	assert_eq(Constants.MAP_SIZE_WORLD, 256.0,
		"Constants.MAP_SIZE_WORLD must be 256.0 (convergence-locked)")


func test_nav_agent_radius_constant_exists_and_is_sensible() -> void:
	# NAV_AGENT_RADIUS must be positive and <= smallest unit footprint.
	# 0.5 world units per session-3 wave-2 spec. Structural — code shape
	# changes if this moves, so it lives in Constants not BalanceData.
	assert_true(Constants.NAV_AGENT_RADIUS > 0.0,
		"NAV_AGENT_RADIUS must be positive")
	assert_eq(Constants.NAV_AGENT_RADIUS, 0.5,
		"NAV_AGENT_RADIUS must be 0.5 world units (infantry clearance)")


# ---------------------------------------------------------------------------
# 2. Terrain scene — load and structure
# ---------------------------------------------------------------------------

func test_terrain_scene_loads_without_error() -> void:
	# The scene file must exist and parse cleanly. A nil result means the
	# file is missing or has a GDScript syntax error.
	var packed: PackedScene = load(TERRAIN_SCENE_PATH)
	assert_not_null(packed,
		"terrain.tscn must load cleanly from %s" % TERRAIN_SCENE_PATH)


func test_terrain_scene_has_navigation_region() -> void:
	# Root of terrain.tscn must be (or contain) a NavigationRegion3D.
	# Per RESOURCE_NODE_CONTRACT.md §3.2: the navmesh is the world-builder's
	# domain; buildings carve it via NavigationObstacle3D children.
	var packed: PackedScene = load(TERRAIN_SCENE_PATH)
	if packed == null:
		pending("terrain.tscn not yet created")
		return
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var nav_region: NavigationRegion3D = _find_first(scene, "NavigationRegion3D")
	assert_not_null(nav_region,
		"terrain scene must contain a NavigationRegion3D node")


func test_terrain_mesh_is_correct_size() -> void:
	# The terrain mesh must be MAP_SIZE_WORLD × MAP_SIZE_WORLD (256×256).
	# Y position of the mesh origin must be at or near 0 (flat plane).
	var packed: PackedScene = load(TERRAIN_SCENE_PATH)
	if packed == null:
		pending("terrain.tscn not yet created")
		return
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var mesh_instance: MeshInstance3D = _find_first(scene, "MeshInstance3D")
	assert_not_null(mesh_instance,
		"terrain scene must contain a MeshInstance3D")
	if mesh_instance == null:
		return

	# Check AABB size in world space.
	# PlaneMesh with MAP_SIZE_WORLD size produces AABB of (256, 0, 256).
	# We allow a small epsilon for floating-point representation.
	var aabb: AABB = mesh_instance.get_aabb()
	var expected_size: float = Constants.MAP_SIZE_WORLD
	assert_almost_eq(aabb.size.x, expected_size, 0.1,
		"terrain mesh X extent must equal MAP_SIZE_WORLD")
	assert_almost_eq(aabb.size.z, expected_size, 0.1,
		"terrain mesh Z extent must equal MAP_SIZE_WORLD")


func test_terrain_mesh_sits_at_y_zero() -> void:
	# The terrain plane center must be at Y=0 (the XZ ground plane).
	var packed: PackedScene = load(TERRAIN_SCENE_PATH)
	if packed == null:
		pending("terrain.tscn not yet created")
		return
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var mesh_instance: MeshInstance3D = _find_first(scene, "MeshInstance3D")
	if mesh_instance == null:
		pending("MeshInstance3D not found")
		return
	assert_almost_eq(mesh_instance.global_position.y, 0.0, 0.05,
		"terrain mesh must sit on the XZ plane at Y=0")


func test_navigation_region_has_valid_map_after_scene_load() -> void:
	# After the terrain scene is added to the tree, the NavigationRegion3D
	# must have already baked its navmesh (bake happens in _ready).
	# We verify this by checking that the navigation map RID is valid.
	# Per RESOURCE_NODE_CONTRACT.md §3.2 and session-3 wave-2 spec:
	# bake once at scene-load; no runtime rebake.
	var packed: PackedScene = load(TERRAIN_SCENE_PATH)
	if packed == null:
		pending("terrain.tscn not yet created")
		return
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	# Allow one frame for _ready to fire and bake to propagate.
	await get_tree().process_frame
	var nav_region: NavigationRegion3D = _find_first(scene, "NavigationRegion3D")
	if nav_region == null:
		pending("NavigationRegion3D not found")
		return
	var map_rid: RID = nav_region.get_navigation_map()
	assert_true(map_rid.is_valid(),
		"NavigationRegion3D.get_navigation_map() must return a valid RID after scene-load bake")


# ---------------------------------------------------------------------------
# Helper — recursive first-match node search by class name
# ---------------------------------------------------------------------------

func _find_first(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_first(child, class_name_str)
		if result != null:
			return result
	return null
