extends GutTest
## Structural scene tests for throne.tscn.
##
## Covers the Pitfall #15 pattern (§9.F4 mandatory + §9.F4 in-either-direction
## discipline): nested CollisionShape3D override via parent="StaticBody3D" —
## verifies the shape is actually overridden and NOT silently falling back to
## the base 2.0×1.2×2.0 BoxShape3D.
##
## Trigger condition (§9.F4 in-either-direction): Throne overrides in BOTH
## directions from the base (x=4.0 > base 2.0; y=3.0 > base 1.2). Testing
## only one dimension would miss the silent-fallback failure mode where the
## base shape survives with all three dimensions. Both x AND z are asserted.
##
## Also asserts mesh size, gold-accent material, and NavigationObstacle3D
## presence (brief §4 Track 2 explicit requirements).
##
## Structural-scene complement to test_throne.gd's class-behavior coverage
## (Track 1 / gp-sys deliverable). Canonical pattern from:
##   test_sarbaz_khaneh_scene.gd (2f31b34)
##   test_atashkadeh_scene.gd (6f33e02)
##   test_sowari_khaneh_scene.gd (Wave 2B Track 2)

const SCENE_PATH := "res://scenes/world/buildings/throne.tscn"

var _instance: Node = null


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	_instance = packed.instantiate()
	add_child_autoqfree(_instance)


func test_throne_scene_loads() -> void:
	assert_not_null(_instance, "throne.tscn must load to a non-null node")


func test_mesh_size_matches_spec() -> void:
	var mesh_inst: MeshInstance3D = _instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mesh_inst, "MeshInstance3D must be present")

	var box: BoxMesh = mesh_inst.mesh as BoxMesh
	assert_not_null(box, "MeshInstance3D.mesh must be a BoxMesh")

	# §9.F4 in-either-direction: x=4.0 > base 2.0, z=4.0 > base 2.0, y=3.0 > base 1.2.
	# Wrong syntax causes silent fallback to base 2.0×1.2×2.0 — all three fail.
	assert_almost_eq(box.size.x, 4.0, 0.01,
		"Throne mesh X must be 4.0 (royal-seat footprint, not base 2.0)")
	assert_almost_eq(box.size.y, 3.0, 0.01,
		"Throne mesh Y must be 3.0 (sovereign height, not base 1.2) — Pitfall #15 guard")
	assert_almost_eq(box.size.z, 4.0, 0.01,
		"Throne mesh Z must be 4.0 (royal-seat footprint, not base 2.0)")


func test_collision_shape_matches_mesh_footprint() -> void:
	var body: StaticBody3D = _instance.get_node_or_null("StaticBody3D") as StaticBody3D
	assert_not_null(body, "StaticBody3D must be present (BUG-07 + click-target)")

	var col: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col, "CollisionShape3D must be present under StaticBody3D")

	var box: BoxShape3D = col.shape as BoxShape3D
	assert_not_null(box, "CollisionShape3D.shape must be a BoxShape3D")

	# Pitfall #15 regression guard: if parent= syntax was wrong the inherited
	# base shape (2.0×1.2×2.0) survives instead of the override (4.0×3.0×4.0).
	# Both x AND z are asserted (§9.F4 in-either-direction — catches both
	# wrong-syntax failure modes).
	assert_almost_eq(box.size.x, 4.0, 0.01,
		"CollisionShape3D X must be 4.0 (Throne footprint, not base 2.0) — Pitfall #15 guard")
	assert_almost_eq(box.size.y, 3.0, 0.01,
		"CollisionShape3D Y must be 3.0 (Throne height, not base 1.2) — Pitfall #15 guard")
	assert_almost_eq(box.size.z, 4.0, 0.01,
		"CollisionShape3D Z must be 4.0 (Throne footprint, not base 2.0) — Pitfall #15 guard")


func test_material_is_gold_accent() -> void:
	var mesh_inst: MeshInstance3D = _instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mesh_inst, "MeshInstance3D must be present")

	var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be a StandardMaterial3D")

	# Gold accent Color(0.85, 0.7, 0.3) — kingship transcends faction color.
	# Both Iran-blue and Turan-red Thrones share this gold accent.
	assert_almost_eq(mat.albedo_color.r, 0.85, 0.01,
		"Throne material R must be ~0.85 (gold accent)")
	assert_almost_eq(mat.albedo_color.g, 0.7, 0.01,
		"Throne material G must be ~0.7 (gold accent)")
	assert_almost_eq(mat.albedo_color.b, 0.3, 0.01,
		"Throne material B must be ~0.3 (gold accent, not base grey 0.55)")


func test_navigation_obstacle_is_present_and_active() -> void:
	var obstacle: NavigationObstacle3D = _instance.get_node_or_null("NavigationObstacle3D") as NavigationObstacle3D
	assert_not_null(obstacle, "NavigationObstacle3D must be present (workers must path around Throne)")

	# Both flags required for runtime-spawned buildings per RNC §3.2 v1.4.0
	# and building.tscn two-flag rationale (Task #141 + engine-architect hypothesis 5).
	# These flags are INHERITED from building.tscn base (not overridden); this test
	# confirms override of vertices does NOT clear the inherited flag values.
	assert_true(obstacle.carve_navigation_mesh,
		"NavigationObstacle3D.carve_navigation_mesh must be true (runtime carve at placement)")
	assert_true(obstacle.affect_navigation_mesh,
		"NavigationObstacle3D.affect_navigation_mesh must be true (bake-time + editor)")
