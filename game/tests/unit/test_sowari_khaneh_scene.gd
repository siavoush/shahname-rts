extends GutTest
## Structural scene tests for sowari_khaneh.tscn.
##
## Covers the Pitfall #15 pattern (§9.F4 mandatory): nested CollisionShape3D
## override via parent="StaticBody3D" — verifies the shape is actually
## overridden and not silently falling back to the base 2.0×1.2×2.0 BoxShape3D.
##
## Trigger condition (§9.F4): sowari_khaneh.tscn overrides CollisionShape3D
## (3.0×1.4×2.5) whose width (3.0) and depth (2.5) both differ from the base
## (2.0×2.0), and height (1.4) differs from the base (1.2). Wrong parent= syntax
## causes silent fallback to base shape; this test fails loudly in that case.
##
## Structural-scene complement to test_sowari_khaneh.gd's class-behavior
## coverage. Canonical pattern established by test_sarbaz_khaneh_scene.gd
## (2f31b34) + test_atashkadeh_scene.gd (6f33e02).

const SCENE_PATH := "res://scenes/world/buildings/sowari_khaneh.tscn"

var _instance: Node = null


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	_instance = packed.instantiate()
	add_child_autoqfree(_instance)


func test_sowari_khaneh_scene_loads() -> void:
	assert_not_null(_instance, "sowari_khaneh.tscn must load to a non-null node")


func test_collision_shape_matches_mesh_footprint() -> void:
	var body: StaticBody3D = _instance.get_node_or_null("StaticBody3D") as StaticBody3D
	assert_not_null(body, "StaticBody3D must be present (BUG-07 + click-target)")

	var col: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col, "CollisionShape3D must be present under StaticBody3D")

	var box: BoxShape3D = col.shape as BoxShape3D
	assert_not_null(box, "CollisionShape3D.shape must be a BoxShape3D")

	# Pitfall #15 regression guard: if the parent= syntax was wrong the inherited
	# base shape (2.0×1.2×2.0) survives instead of the override (3.0×1.4×2.5).
	# Width X=3.0 and depth Z=2.5 are the primary distinguishing dimensions
	# vs the base 2.0×2.0 XZ footprint.
	assert_almost_eq(box.size.x, 3.0, 0.01,
		"CollisionShape3D X must be 3.0 (Sowari-khaneh footprint, not base 2.0)")
	assert_almost_eq(box.size.y, 1.4, 0.01,
		"CollisionShape3D Y must be 1.4 (Sowari-khaneh height, not base 1.2) — Pitfall #15 guard")
	assert_almost_eq(box.size.z, 2.5, 0.01,
		"CollisionShape3D Z must be 2.5 (Sowari-khaneh depth, not base 2.0)")
