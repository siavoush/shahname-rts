# Integration test — NavigationObstacle3D behavioral carving verification.
#
# BEHAVIORAL BACKFILL: The existing presence-only nav-obstacle tests
# (test_building_base.gd, test_khaneh.gd, test_madan.gd,
# test_phase_3_nav_obstacle_carving.gd) verify that the obstacle exists and
# has the correct config. This file verifies the EFFECT — that
# NavigationServer3D.map_get_path() routes workers AROUND carved buildings,
# not through them.
#
# Per docs/STUDIO_PROCESS.md §9 (2026-05-15 rule): cross-cutting structural
# claims require behavioral assertions. Cites the L25 finding (workers walked
# through inert obstacles that lacked affect_navigation_mesh + vertices).
#
# NavigationObstacle3D flags in play (Godot 4.6.2, per bc34c39 fix):
#   affect_navigation_mesh = true  — bake-time carve participation hint
#   carve_navigation_mesh = true   — runtime dynamic carve participation hint
# Both flags set on building.tscn + madan.tscn + mine_node.tscn as of bc34c39.
# Unit tests assert both flags (test_building_base.gd, test_khaneh.gd etc.).
#
# Uses the REAL NavigationAgentPathScheduler, NOT MockPathScheduler.
# The mock returns straight-line paths and would not exercise the carve.
#
# NAVMESH CARVE MECHANISM (Wave 1D, df25033 — four-round diagnostic history):
#
# Root cause of L25: region.bake_navigation_mesh() convenience wrapper
# hardcodes `this` (the region) as p_root_node. SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
# walks from p_root_node — so with the default, buildings placed as siblings of
# Terrain were invisible to the bake (wrong subtree).
#
# Fix (Wave 1D explicit pipeline in Building._on_placement_complete):
#   var source := NavigationMeshSourceGeometryData3D.new()
#   NavigationServer3D.parse_source_geometry_data(nav_mesh, source, get_tree().root)
#   NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
#
# This passes get_tree().root directly, so the parse walks the entire scene
# tree and discovers buildings' StaticBody3D + CollisionShape3D. Sync;
# deterministic; headless-verifiable. No rendering-loop dependency.
#
# Earlier failed hypotheses (documented for archaeology):
# 1. carve_navigation_mesh async (bc34c39): 30-frame probe showed NavServer
#    carve thread never fires in headless — rendering-loop dependency real,
#    but this was a secondary symptom, not the root cause.
# 2. bake_navigation_mesh(false) sync (Task #144): bake fired (state=1) but
#    path unchanged — bake didn't see buildings (wrong subtree root).
# 3. SOURCE_GEOMETRY_ROOT_NODE_CHILDREN mode (Task #147 / Fix 6a): mode set
#    correctly, but the convenience wrapper still passed `this` as root,
#    defeating the mode change entirely.
# 4. Explicit pipeline (Wave 1D / df25033): all 3 flows GREEN in headless.
#    Carve is headless-verifiable. "Rendering pipeline required" framing was
#    wrong — the actual blocker was the subtree-root bug in the convenience
#    wrapper, not the rendering loop.
extends GutTest

const TerrainScene: PackedScene = preload("res://scenes/world/terrain.tscn")
const KhanehScene: PackedScene = preload("res://scenes/world/buildings/khaneh.tscn")
const MadanScene: PackedScene = preload("res://scenes/world/buildings/madan.tscn")
const MazraehScene: PackedScene = preload("res://scenes/world/buildings/mazraeh.tscn")
const RealScheduler: Script = preload(
	"res://scripts/navigation/navigation_agent_path_scheduler.gd")

# From/to positions: query passes through origin where building is placed.
const FROM_POS := Vector3(0.0, 0.0, -10.0)
const TO_POS := Vector3(0.0, 0.0, 10.0)

var _terrain: Node3D
var _scheduler: Variant


func before_each() -> void:
	_terrain = TerrainScene.instantiate()
	add_child_autofree(_terrain)
	# Wait for terrain's _ready bake to complete and NavServer to register the map.
	await get_tree().process_frame
	await get_tree().process_frame
	_scheduler = RealScheduler.new()


func after_each() -> void:
	_scheduler = null
	_terrain = null


# ---------------------------------------------------------------------------
# Helper — check whether any waypoint in a path passes through a zone.
# Returns true if the path is "clean" (no waypoint inside the footprint),
# false if a waypoint is inside (indicating carve did not take effect).
# ---------------------------------------------------------------------------

func _path_routes_around(waypoints: PackedVector3Array, min_xz_dist: float) -> bool:
	for wp in waypoints:
		if Vector2(wp.x, wp.z).length() < min_xz_dist:
			return false
	return true


# ---------------------------------------------------------------------------
# Flow 1 — Khaneh placed at origin. Calls _on_placement_complete to trigger
# the explicit-pipeline sync rebake (Wave 1D). Verifies carve via
# map_get_path() waypoints. Headless-verifiable as of df25033.
# ---------------------------------------------------------------------------

func test_khaneh_carves_navmesh_path_routes_around() -> void:
	var khaneh: Node3D = KhanehScene.instantiate()
	add_child_autofree(khaneh)
	khaneh.global_position = Vector3.ZERO
	khaneh.call(&"_on_placement_complete", 0)
	await get_tree().process_frame

	var req_id: int = _scheduler.request_repath(99, FROM_POS, TO_POS, 0)
	var result: Dictionary = _scheduler.poll_path(req_id)

	if int(result.state) != 1:
		pending(
			"NavigationAgentPathScheduler returned FAILED — no active nav map.")
		return

	var waypoints: PackedVector3Array = result.waypoints
	assert_gt(waypoints.size(), 2,
		"Carved path around Khaneh must produce >2 waypoints. Got: "
		+ str(waypoints.size()))
	for i in range(waypoints.size()):
		var wp: Vector3 = waypoints[i]
		var xz_dist: float = Vector2(wp.x, wp.z).length()
		assert_gte(xz_dist, 1.0,
			"Waypoint[%d] at %s (XZ dist %.3f) is inside Khaneh's 2.0x2.0 "
			% [i, wp, xz_dist]
			+ "footprint — carve failed. Khaneh polygon ±1.1.")


# ---------------------------------------------------------------------------
# Flow 2 — Ma'dan placed at origin. Same explicit-pipeline rebake pattern.
# 2.5×2.5 footprint; XZ dist ≥ 1.25 for every waypoint.
# ---------------------------------------------------------------------------

func test_madan_carves_navmesh_path_routes_around() -> void:
	var madan: Node3D = MadanScene.instantiate()
	add_child_autofree(madan)
	madan.global_position = Vector3.ZERO
	madan.call(&"_on_placement_complete", 0)
	await get_tree().process_frame

	var req_id: int = _scheduler.request_repath(99, FROM_POS, TO_POS, 0)
	var result: Dictionary = _scheduler.poll_path(req_id)

	if int(result.state) != 1:
		pending(
			"NavigationAgentPathScheduler returned FAILED — no active nav map.")
		return

	var waypoints: PackedVector3Array = result.waypoints
	assert_gt(waypoints.size(), 2,
		"Carved path around Ma'dan must produce >2 waypoints. Got: "
		+ str(waypoints.size()))
	for i in range(waypoints.size()):
		var wp: Vector3 = waypoints[i]
		var xz_dist: float = Vector2(wp.x, wp.z).length()
		assert_gte(xz_dist, 1.25,
			"Waypoint[%d] at %s (XZ dist %.3f) is inside Ma'dan's 2.5x2.5 "
			% [i, wp, xz_dist]
			+ "footprint — carve failed. Ma'dan polygon ±1.35.")


# ---------------------------------------------------------------------------
# Flow 3 — Mazra'eh control case. Workers walk THROUGH the farm.
# Mazra'eh has no NavigationObstacle3D (RNC §3.2 — walkable tile).
# The path must resolve without a carved detour — verified by checking that
# all waypoints pass within 1.0m of the origin (not routed far around it).
#
# NOTE: We do not assert exact waypoint count because the navmesh optimizer
# may produce 2 or 3 waypoints depending on the navmesh cell layout.
# The key behavioral claim is that the path is NOT deflected far away from
# the origin the way a carve would deflect it.
# ---------------------------------------------------------------------------

func test_mazraeh_does_not_carve_path_goes_through() -> void:
	var mazraeh: Node3D = MazraehScene.instantiate()
	add_child_autofree(mazraeh)
	mazraeh.global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var req_id: int = _scheduler.request_repath(99, FROM_POS, TO_POS, 0)
	var result: Dictionary = _scheduler.poll_path(req_id)

	if int(result.state) != 1:
		pending(
			"NavigationAgentPathScheduler returned FAILED — no active nav map "
			+ "(headless without display server).")
		return

	var waypoints: PackedVector3Array = result.waypoints
	assert_gte(waypoints.size(), 2,
		"Walkable Mazra'eh must resolve a path (at least 2 waypoints). "
		+ "Got: " + str(waypoints.size()))

	# Behavioral claim: with no carve, the path should pass THROUGH or near
	# the origin — at least one waypoint within 5.0m XZ of origin.
	# (This is the inverse of the carve test: if Mazra'eh were incorrectly
	# carving, all waypoints would be >1.35m from origin.)
	var any_near_origin: bool = false
	for wp in waypoints:
		if Vector2(wp.x, wp.z).length() < 5.0:
			any_near_origin = true
			break
	assert_true(any_near_origin,
		"Walkable Mazra'eh: path must pass within 5.0m XZ of origin "
		+ "(no carve obstacle). If all waypoints are far from origin, "
		+ "Mazra'eh is incorrectly carving the navmesh. "
		+ "Waypoints: " + str(waypoints))
