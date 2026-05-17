extends GutTest
## Structural scene tests for sarbaz_khaneh.tscn.
##
## Covers the Pitfall #15 fix (Wave 2A fix-up): nested CollisionShape3D override
## via parent="StaticBody3D" — verifies the shape is actually overridden and not
## silently falling back to the base 2.0×1.2×2.0 BoxShape3D.
##
## Structural-scene complement to test_sarbaz_khaneh.gd's class-behavior coverage.

const SCENE_PATH := "res://scenes/world/buildings/sarbaz_khaneh.tscn"

var _instance: Node = null


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	_instance = packed.instantiate()
	add_child_autoqfree(_instance)


func test_sarbaz_khaneh_scene_loads() -> void:
	assert_not_null(_instance, "sarbaz_khaneh.tscn must load to a non-null node")


func test_collision_shape_matches_mesh_footprint() -> void:
	var body: StaticBody3D = _instance.get_node_or_null("StaticBody3D") as StaticBody3D
	assert_not_null(body, "StaticBody3D must be present (BUG-07 + click-target)")

	var col: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col, "CollisionShape3D must be present under StaticBody3D")

	var box: BoxShape3D = col.shape as BoxShape3D
	assert_not_null(box, "CollisionShape3D.shape must be a BoxShape3D")

	# Pitfall #15 regression guard: if the parent= syntax was wrong the inherited
	# base shape (2.0×1.2×2.0) survives instead of the override (3.0×1.2×2.0).
	assert_almost_eq(box.size.x, 3.0, 0.01,
		"CollisionShape3D X must be 3.0 (Sarbaz-khaneh footprint, not base 2.0)")
	assert_almost_eq(box.size.z, 2.0, 0.01,
		"CollisionShape3D Z must be 2.0 (Sarbaz-khaneh footprint, not base 2.0)")
