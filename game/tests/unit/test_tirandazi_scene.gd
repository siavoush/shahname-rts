extends GutTest
## Structural scene tests for tirandazi.tscn.
##
## Covers the Pitfall #15 pattern (§9.F4 mandatory): nested CollisionShape3D
## override via parent="StaticBody3D" — verifies the shape is actually
## overridden and not silently falling back to the base 2.0×1.2×2.0 BoxShape3D.
##
## Trigger condition (§9.F4): tirandazi.tscn overrides CollisionShape3D
## (3.5×1.0×2.0) whose width (3.5) differs from the base (2.0), and height
## (1.0) is LESS than the base (1.2) — the low-profile practice-range shape.
## Wrong parent= syntax causes silent fallback to base shape; this test fails
## loudly in that case.
##
## Structural-scene complement to test_tirandazi.gd's class-behavior coverage.
## Canonical pattern established by test_sarbaz_khaneh_scene.gd (2f31b34) +
## test_atashkadeh_scene.gd (6f33e02).

const SCENE_PATH := "res://scenes/world/buildings/tirandazi.tscn"

var _instance: Node = null


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	_instance = packed.instantiate()
	add_child_autoqfree(_instance)


func test_tirandazi_scene_loads() -> void:
	assert_not_null(_instance, "tirandazi.tscn must load to a non-null node")


func test_collision_shape_matches_mesh_footprint() -> void:
	var body: StaticBody3D = _instance.get_node_or_null("StaticBody3D") as StaticBody3D
	assert_not_null(body, "StaticBody3D must be present (BUG-07 + click-target)")

	var col: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col, "CollisionShape3D must be present under StaticBody3D")

	var box: BoxShape3D = col.shape as BoxShape3D
	assert_not_null(box, "CollisionShape3D.shape must be a BoxShape3D")

	# Pitfall #15 regression guard: if the parent= syntax was wrong the inherited
	# base shape (2.0×1.2×2.0) survives instead of the override (3.5×1.0×2.0).
	# Width X=3.5 is the strongest distinguishing dimension; height Y=1.0 is the
	# LOW-PROFILE guard (tirandazi is shorter than all prior buildings — if the
	# silent-failure form was used, the inherited 1.2 would survive).
	assert_almost_eq(box.size.x, 3.5, 0.01,
		"CollisionShape3D X must be 3.5 (Tirandazi footprint, not base 2.0)")
	assert_almost_eq(box.size.y, 1.0, 0.01,
		"CollisionShape3D Y must be 1.0 (Tirandazi low-profile height, not base 1.2) — Pitfall #15 guard")
	assert_almost_eq(box.size.z, 2.0, 0.01,
		"CollisionShape3D Z must be 2.0 (Tirandazi depth, matching base but part of full-footprint check)")
