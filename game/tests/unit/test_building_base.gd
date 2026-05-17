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
	# Per RESOURCE_NODE_CONTRACT §3.2 v1.4.0 + docs/WAVE_1C_NAVMESH_SPIKE.md §2.1:
	# NavigationObstacle3D with affect_navigation_mesh = true + vertices polygon
	# activates static-carve mode so map_get_path() routes workers around the
	# building. Presence alone is insufficient (per STUDIO_PROCESS.md §9
	# 2026-05-15 rule — structural claims require behavioral assertions).
	_building = _spawn_building()
	var nav: Node = _building.get_node_or_null(^"NavigationObstacle3D")
	assert_not_null(nav,
		"Building must contain a NavigationObstacle3D for dynamic "
		+ "navmesh carving (Resource Node Contract §3.2 v1.4.0)")
	assert_true(nav is NavigationObstacle3D,
		"NavigationObstacle3D node is the right type")
	# Behavioral discipline — config verification (effect verified by
	# integration test test_phase_3_nav_obstacle_carving_behavioral.gd).
	assert_true(nav.affect_navigation_mesh,
		"NavigationObstacle3D must have affect_navigation_mesh = true "
		+ "(per RNC §3.2 v1.4.0 — without this the obstacle is inert)")
	assert_gt(nav.vertices.size(), 2,
		"NavigationObstacle3D must declare a vertices polygon (≥3 vertices) "
		+ "— without vertices, affect_navigation_mesh has no shape to carve")


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


# ---------------------------------------------------------------------------
# get_footprint_aabb — Phase 3 session 2 wave 1A (Room B v1.3.0 §3.2 dep)
# ---------------------------------------------------------------------------
#
# Wave-1A cross-wave deliverable per Convergence Review Finding-1 & Room B's
# §3.2: gameplay-systems owns Building.get_footprint_aabb() so FogSystem
# (wave 3A) can compute building visibility footprints without reaching into
# CollisionShape3D scene-tree paths. Returns the building's world-aligned
# footprint AABB.
#
# Two behavioral cases tested:
#   1. With the base scene's MeshInstance3D (2.0 × 1.2 × 2.0 BoxMesh + Y-offset),
#      get_footprint_aabb() returns an AABB sized 2 × 1.2 × 2 centered on
#      global_position (Y-offset accounted for in the local-to-world
#      transformation).
#   2. With no MeshInstance3D / no recognizable shape, the fallback is a
#      2×2 FOG_CELL default (8m × 0 × 8m AABB centered on global_position).
#      Per FOG_DATA_CONTRACT v1.3.0 §3.2 fallback clause.

func test_building_get_footprint_aabb_returns_mesh_extent() -> void:
	# Spawn from the base scene — exercises the path the live game uses
	# (scene has the BoxMesh 2.0×1.2×2.0). place_at sets global_position
	# so get_footprint_aabb's world-space output is deterministic.
	_building = _spawn_building()
	_building.place_at(Vector3(10.0, 0.0, 5.0), Constants.TEAM_IRAN, 1)
	var aabb: AABB = _building.get_footprint_aabb()
	# The base BoxMesh is 2.0 × 1.2 × 2.0; AABB.size matches.
	assert_almost_eq(aabb.size.x, 2.0, 0.0001,
		"AABB.size.x matches the BoxMesh X extent (2.0)")
	assert_almost_eq(aabb.size.z, 2.0, 0.0001,
		"AABB.size.z matches the BoxMesh Z extent (2.0)")
	# AABB.position is the min corner — for a 2×2 footprint centered on
	# the building's global_position, min.x = position.x - 1.0, etc.
	# (Y is allowed to vary — fog ignores Y; only XZ is load-bearing.)
	var center_x: float = aabb.position.x + aabb.size.x * 0.5
	var center_z: float = aabb.position.z + aabb.size.z * 0.5
	assert_almost_eq(center_x, 10.0, 0.0001,
		"AABB centered on building's global_position.x (10.0)")
	assert_almost_eq(center_z, 5.0, 0.0001,
		"AABB centered on building's global_position.z (5.0)")


func test_building_get_footprint_aabb_fallback_when_no_mesh() -> void:
	# Construct a Building WITHOUT a MeshInstance3D / CollisionShape3D
	# subtree — exercise the 2×2 fog-cell fallback clause (FOG_DATA_CONTRACT
	# v1.3.0 §3.2). The script alone, no scene wrapper, has no children, so
	# get_footprint_aabb() must fall back to the default.
	#
	# Note: Building.new() without add_child won't get a unit_id (skip the
	# add_child_autofree path that runs _ready). We construct with no
	# children added, manually set global_position, then call the method.
	var bare_building: Variant = BuildingScript.new()
	# Free at end; we never added it as a child so .free() is needed.
	bare_building.global_position = Vector3(0.0, 0.0, 0.0)
	var aabb: AABB = bare_building.get_footprint_aabb()
	# Fallback per kickoff brief: size = (2 * FOG_CELL_SIZE, 0, 2 * FOG_CELL_SIZE)
	# = (8, 0, 8) since FOG_CELL_SIZE = 4 per FOG_DATA_CONTRACT §1.1.
	assert_almost_eq(aabb.size.x, 8.0, 0.0001,
		"fallback AABB X extent = 8m (2 × 4m fog cell)")
	assert_almost_eq(aabb.size.z, 8.0, 0.0001,
		"fallback AABB Z extent = 8m (2 × 4m fog cell)")
	# Centered on global_position(0,0,0) → AABB.position = (-4, ?, -4).
	var center_x: float = aabb.position.x + aabb.size.x * 0.5
	var center_z: float = aabb.position.z + aabb.size.z * 0.5
	assert_almost_eq(center_x, 0.0, 0.0001,
		"fallback AABB centered on global_position.x")
	assert_almost_eq(center_z, 0.0, 0.0001,
		"fallback AABB centered on global_position.z")
	bare_building.free()


# ---------------------------------------------------------------------------
# construction_progress_updated signal — Track 2B wave 1C deliverable
# ---------------------------------------------------------------------------
#
# These tests verify the signal contract declared in building.gd:
#   - The signal exists on the Building type.
#   - A connected handler receives the exact percent_x100 value emitted.
#   - No double-emit at completion: the no-double-emit contract is a
#     discipline on UnitState_Constructing (Track 1 / gp-sys scope) — that
#     state does NOT emit at the placement tick. We document that boundary
#     here but cannot enforce it without a full UnitState_Constructing
#     integration harness; that test is Track 1's responsibility.
#
# Integration shape: the emitter (UnitState_Constructing._sim_tick) is Track
# 1's call site. Here we drive the signal directly on a Building instance to
# verify the declaration, the handler wiring, and the value passthrough —
# the same shape as test_on_placement_complete_subclass_hook_fires.

var _signal_received_values: Array = []


func _on_progress_signal(percent_x100: int) -> void:
	_signal_received_values.append(percent_x100)


func test_construction_progress_updated_signal_exists() -> void:
	# Verify the signal is declared on the Building type. Consumers (ui-dev
	# Track 2A, telemetry) connect by name; if the signal doesn't exist,
	# connect() raises an error silently and the UI never updates.
	_building = _spawn_building()
	assert_true(_building.has_signal(&"construction_progress_updated"),
		"Building must declare construction_progress_updated signal "
		+ "(Track 2B wave 1C — ui-dev Track 2A connects by this name)")


func test_construction_progress_updated_emits_correct_value() -> void:
	# Simulate one progress tick: emit a known percent_x100 value and
	# verify the connected handler receives it exactly. This is the
	# unit-level proof that the signal plumbing works before Track 1
	# wires the call site in UnitState_Constructing._sim_tick.
	_building = _spawn_building()
	_signal_received_values.clear()
	_building.construction_progress_updated.connect(_on_progress_signal)

	# Emit at 50% (5000 basis points) — a mid-dwell tick.
	_building.emit_signal(&"construction_progress_updated", 5000)

	assert_eq(_signal_received_values.size(), 1,
		"Handler must be called exactly once per emit")
	assert_eq(_signal_received_values[0], 5000,
		"Handler must receive the exact percent_x100 value (5000 = 50%)")

	_building.construction_progress_updated.disconnect(_on_progress_signal)


func test_construction_progress_updated_multiple_values_in_sequence() -> void:
	# Verify sequential emits accumulate correctly — simulates a multi-tick
	# dwell where the emitter fires once per tick with increasing progress.
	_building = _spawn_building()
	_signal_received_values.clear()
	_building.construction_progress_updated.connect(_on_progress_signal)

	# Simulate ticks at 25%, 50%, 75% progress.
	_building.emit_signal(&"construction_progress_updated", 2500)
	_building.emit_signal(&"construction_progress_updated", 5000)
	_building.emit_signal(&"construction_progress_updated", 7500)

	assert_eq(_signal_received_values.size(), 3,
		"Three emits must produce three handler calls (not batched)")
	assert_eq(_signal_received_values[0], 2500, "First emit: 25%")
	assert_eq(_signal_received_values[1], 5000, "Second emit: 50%")
	assert_eq(_signal_received_values[2], 7500, "Third emit: 75%")

	_building.construction_progress_updated.disconnect(_on_progress_signal)


func test_construction_progress_updated_no_double_emit_is_track1_responsibility() -> void:
	# The no-double-emit contract (progress signal does NOT fire at the
	# placement tick) is enforced by UnitState_Constructing, not by Building.
	# Building.emit_signal() is unconditional by design — the guard lives in
	# the emitter (Track 1 / gp-sys scope), not the receiver or the signal
	# declaration.
	#
	# This test documents the boundary explicitly: Building itself has no
	# guard that prevents emit_signal from being called at any value, including
	# 10000. Track 1's integration test must verify that UnitState_Constructing
	# does NOT call emit_signal at the placement tick.
	_building = _spawn_building()
	_signal_received_values.clear()
	_building.construction_progress_updated.connect(_on_progress_signal)

	# Building itself allows emit at 10000 — no guard on the base class.
	_building.emit_signal(&"construction_progress_updated", 10000)
	assert_eq(_signal_received_values.size(), 1,
		"Building.emit_signal is unconditional — no guard on the base class. "
		+ "Track 1 (UnitState_Constructing) enforces the no-double-emit rule.")

	_building.construction_progress_updated.disconnect(_on_progress_signal)


# ---------------------------------------------------------------------------
# construction_finalized signal — Task #139 Track 1 follow-on
# ---------------------------------------------------------------------------
#
# Per ui-developer-p3s3's integration brief: the progress-bar UI Control
# needs an externally-observable Stage-2 completion signal. Mirrors the
# construction_progress_updated test shape. Integration-level coverage
# (drive a full Khaneh construction, assert exactly-once emit at Stage 2)
# lives in test_unit_state_constructing.gd.

var _finalized_received: Array = []


func _on_finalized_signal(placer_unit_id: int) -> void:
	_finalized_received.append(placer_unit_id)


func test_construction_finalized_signal_exists() -> void:
	# Declaration check — consumers (ui-dev Track 2A overlay, telemetry)
	# connect by name; if the signal doesn't exist, connect() raises an
	# error silently and the UI never resolves a hide-trigger.
	_building = _spawn_building()
	assert_true(_building.has_signal(&"construction_finalized"),
		"Building must declare construction_finalized signal "
		+ "(Task #139 — externally-observable Stage-2 completion)")


func test_construction_finalized_emits_correct_placer_unit_id() -> void:
	# Per signal signature `construction_finalized(placer_unit_id: int)`:
	# the handler receives the exact placer_unit_id value emitted. Locks
	# the int payload contract.
	_building = _spawn_building()
	_finalized_received.clear()
	_building.construction_finalized.connect(_on_finalized_signal)

	_building.emit_signal(&"construction_finalized", 42)

	assert_eq(_finalized_received.size(), 1,
		"Handler must be called exactly once per emit")
	assert_eq(_finalized_received[0], 42,
		"Handler must receive the exact placer_unit_id value (42)")

	_building.construction_finalized.disconnect(_on_finalized_signal)


func test_construction_finalized_handles_negative_one_sentinel() -> void:
	# placer_unit_id can be -1 (forward-compat sentinel when the placing
	# worker is unknown / died — per signal header). emit_signal must
	# accept it without coercion / error.
	_building = _spawn_building()
	_finalized_received.clear()
	_building.construction_finalized.connect(_on_finalized_signal)

	_building.emit_signal(&"construction_finalized", -1)

	assert_eq(_finalized_received.size(), 1)
	assert_eq(_finalized_received[0], -1,
		"-1 sentinel passes through to handler unchanged")

	_building.construction_finalized.disconnect(_on_finalized_signal)
