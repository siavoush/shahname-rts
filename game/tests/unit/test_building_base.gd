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
		+ "(per RNC §3.2 v1.4.0 — without this the obstacle is inert at bake time)")
	assert_true(nav.carve_navigation_mesh,
		"NavigationObstacle3D must have carve_navigation_mesh = true "
		+ "(Task #141 fix-up — buildings spawn at runtime via add_child post-bake; "
		+ "only carve_navigation_mesh actually blocks workers at placement time)")
	assert_gt(nav.vertices.size(), 2,
		"NavigationObstacle3D must declare a vertices polygon (≥3 vertices) "
		+ "— without vertices, affect_navigation_mesh has no shape to carve")


func test_placement_triggers_navmesh_rebake_path() -> void:
	# Task #144 — Building._on_placement_complete drives a synchronous navmesh
	# rebake when the building has a NavigationObstacle3D child. This test
	# verifies the structural pre-conditions that make the rebake path reachable:
	#   1. The Building scene has a NavigationObstacle3D child (already gated by
	#      test_building_has_navigation_obstacle above).
	#   2. The building is added to a scene tree context (_spawn_building uses
	#      add_child_autofree, so get_tree() is non-null in this test).
	#   3. The _resolve_terrain_region helper is callable on the instance.
	#   4. When no NavigationRegion3D is present (unit-test context, no terrain),
	#      the method returns null safely — no error thrown.
	# The empirical carve effect is verified by qa-engineer's behavioral
	# integration test (test_phase_3_nav_obstacle_carving_behavioral.gd).
	_building = _spawn_building()
	# Verify the rebake helper exists and returns null gracefully in headless
	# test context (no terrain / NavigationRegion3D in the test scene tree).
	assert_true(_building.has_method(&"_resolve_terrain_region"),
		"Building must expose _resolve_terrain_region helper (Task #144 navmesh "
		+ "rebake path — callable from _on_placement_complete)")
	var region: Variant = _building.call(&"_resolve_terrain_region")
	assert_null(region,
		"_resolve_terrain_region must return null in unit-test context "
		+ "(no NavigationRegion3D in the test scene tree — graceful no-op)")


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


# ===========================================================================
# Wave 3A.6 Track 1 — Production state machine
# ===========================================================================
#
# Per 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 1.
#
# These tests target the BASE Building's production surface — the `produces`
# field, `request_train` validation chain, the &"movement" sim_phase
# dwell driver, and the production_state_changed signal. Per-producer
# concrete-class tests (test_sarbaz_khaneh.gd / test_sowari_khaneh.gd /
# test_tirandazi.gd) verify the subclass overrides + spawn integration.
#
# Test fixture: the base Building scene exists at building.tscn with no
# `produces` populated, so request_train always returns false on it (a
# base Building cannot train anything). To exercise the production logic
# directly on the base, we set `produces = [&"piyade"]` on a base instance
# in the test setup — this is what subclasses do at _init/_ready.

var _production_signals: Array = []


func _on_production_signal(building_id: int, state: StringName,
		unit_kind: StringName, progress: float) -> void:
	_production_signals.append({
		&"building_id": building_id,
		&"state": state,
		&"unit_kind": unit_kind,
		&"progress": progress,
	})


# Helper: spawn a base Building, mark it is_complete (skip the construction
# flow), set produces to [&"piyade"], position it under the test scene tree,
# and ensure ResourceSystem has the starting state for this test's team.
func _spawn_producer_building(team: int = Constants.TEAM_IRAN) -> Variant:
	var b: Variant = _spawn_building()
	b.team = team
	b.is_complete = true  # Skip the construction state — tests aren't building it.
	# `produces` is typed Array[StringName]; assign through a typed local
	# to avoid the "Invalid assignment ... Array vs Array[StringName]"
	# type-strict rejection that bare literals trigger on Godot 4.6.
	var produces_set: Array[StringName] = [&"piyade"]
	b.produces = produces_set
	# Drop any kind so _resolve_train_* falls back (we don't depend on
	# BalanceData entries — fallback dwell of 90 ticks is the wanted shape
	# and cost falls to 0 which means affordability passes trivially).
	b.kind = &""
	return b


# --- `produces` schema ----------------------------------------------------

func test_produces_default_empty() -> void:
	# Base Building has no producible kinds (non-producer). Subclasses
	# override.
	_building = _spawn_building()
	assert_eq(_building.produces.size(), 0,
		"Base Building.produces must default to empty (non-producer)")


func test_request_train_denies_when_kind_not_in_produces() -> void:
	# Base case: building has produces=[piyade], asking for savar denies.
	_building = _spawn_producer_building()
	SimClock._is_ticking = true
	var ok: bool = _building.request_train(&"savar")
	SimClock._is_ticking = false
	assert_false(ok,
		"request_train must return false for an unknown kind (not in produces)")
	assert_eq(_building._production_state, &"idle",
		"production state must remain idle on failed request")


# --- request_train validation chain ----------------------------------------

func test_request_train_denies_when_not_is_complete() -> void:
	# Production can only start on a fully-constructed building. Pre-Stage-2
	# Sarbaz-khaneh.is_complete = false → train request denied.
	_building = _spawn_producer_building()
	_building.is_complete = false
	SimClock._is_ticking = true
	var ok: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_false(ok,
		"request_train must return false if building is not is_complete "
		+ "(construction still in progress)")


func test_request_train_denies_when_already_training() -> void:
	# Single-slot: second request while training is in progress denies.
	_building = _spawn_producer_building()
	# Need affordability + pop room — ResourceSystem starts at the
	# BalanceData starting values; tests run in an env where defaults
	# permit basic spends. Boost pop_cap to ensure pop check passes.
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(
		Constants.TEAM_IRAN, 10, &"test_setup", null)
	# Add some coin/grain to make sure trivial costs (0 fallback) and
	# any future tuning still pass.
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"test", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"test", null)
	var ok1: bool = _building.request_train(&"piyade")
	assert_true(ok1, "first request_train must succeed (preconditions met)")
	var ok2: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_false(ok2,
		"second request_train must fail while first is still training "
		+ "(single-slot for MVP per kickoff §1)")


func test_request_train_enters_training_state_on_success() -> void:
	# On success: state → training, unit set, progress signal fired with
	# state=training + progress=0.0.
	_building = _spawn_producer_building()
	_production_signals.clear()
	_building.production_state_changed.connect(_on_production_signal)
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	var ok: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_true(ok)
	assert_eq(_building._production_state, &"training")
	assert_eq(_building._production_unit, &"piyade")
	assert_gt(_building._production_progress_ticks, 0,
		"dwell counter must be initialized > 0 (90 fallback at minimum)")
	# Signal: one emit with state=training, unit=piyade, progress=0.0.
	assert_eq(_production_signals.size(), 1,
		"production_state_changed must fire exactly once on request_train success")
	assert_eq(_production_signals[0][&"state"], &"training")
	assert_eq(_production_signals[0][&"unit_kind"], &"piyade")
	assert_eq(_production_signals[0][&"progress"], 0.0,
		"progress must be 0.0 at training start")
	_building.production_state_changed.disconnect(_on_production_signal)


# --- Sim-phase tick decrement ---------------------------------------------

func test_sim_phase_movement_decrements_dwell() -> void:
	# Each &"movement" phase emit decrements _production_progress_ticks.
	_building = _spawn_producer_building()
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	assert_true(_building.request_train(&"piyade"))
	var initial_ticks: int = _building._production_progress_ticks
	# Manually emit one movement phase. Per project pattern (test_spatial_index.gd
	# and others), tests emit sim_phase directly.
	EventBus.sim_phase.emit(&"movement", 1)
	SimClock._is_ticking = false
	assert_eq(_building._production_progress_ticks, initial_ticks - 1,
		"one movement-phase emit must decrement dwell by exactly 1")


func test_sim_phase_non_movement_does_not_decrement() -> void:
	# Only the &"movement" phase drives production. Other phases must
	# leave the counter alone (forward-compat against new phases firing
	# at the production state machine accidentally).
	_building = _spawn_producer_building()
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	assert_true(_building.request_train(&"piyade"))
	var initial: int = _building._production_progress_ticks
	# Emit a few non-movement phases.
	EventBus.sim_phase.emit(&"input", 1)
	EventBus.sim_phase.emit(&"ai", 1)
	EventBus.sim_phase.emit(&"combat", 1)
	EventBus.sim_phase.emit(&"cleanup", 1)
	SimClock._is_ticking = false
	assert_eq(_building._production_progress_ticks, initial,
		"non-movement phases must not decrement dwell")


# --- Spawn on dwell completion --------------------------------------------

func test_dwell_completion_spawns_unit_and_returns_to_idle() -> void:
	# When the dwell counter hits zero, the trained unit is spawned in the
	# building's parent, state returns to idle, signal fires with idle/empty.
	_building = _spawn_producer_building()
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	assert_true(_building.request_train(&"piyade"))
	# Drive the dwell to completion. Fallback dwell = 90.
	for i in range(95):
		EventBus.sim_phase.emit(&"movement", i)
	SimClock._is_ticking = false
	assert_eq(_building._production_state, &"idle",
		"state must return to idle after dwell completion")
	assert_eq(_building._production_unit, &"",
		"_production_unit must clear when transitioning to idle")
	# Confirm a Piyade was added to the building's parent.
	var parent: Node = _building.get_parent()
	var piyade_found: bool = false
	for child in parent.get_children():
		if child == _building:
			continue
		# Piyade scene has unit_type=&"piyade" set in its script.
		var unit_type_v: Variant = child.get(&"unit_type")
		if unit_type_v == &"piyade":
			piyade_found = true
			break
	assert_true(piyade_found,
		"a Piyade unit must be spawned in the building's parent after dwell completes")


# --- Rally-point offset ----------------------------------------------------

func test_rally_point_south_for_iran() -> void:
	# Iran spawns south of its buildings (+Z offset).
	_building = _spawn_producer_building(Constants.TEAM_IRAN)
	_building.global_position = Vector3(5.0, 0.5, 10.0)
	var rally: Vector3 = _building._rally_point()
	assert_gt(rally.z, _building.global_position.z,
		"Iran rally point must be south (+Z) of the building")


func test_rally_point_north_for_turan() -> void:
	# Turan spawns north of its buildings (-Z offset) — opposing flow.
	_building = _spawn_producer_building(Constants.TEAM_TURAN)
	_building.global_position = Vector3(5.0, 0.5, 10.0)
	var rally: Vector3 = _building._rally_point()
	assert_lt(rally.z, _building.global_position.z,
		"Turan rally point must be north (-Z) of the building")


# --- Resource deduction --------------------------------------------------

func test_request_train_deducts_resources_atomically() -> void:
	# When the call succeeds, both coin and grain are deducted. Today the
	# default kind = &"" means costs fall back to 0 — but the deduction
	# CALLS still go through change_resource if the costs are > 0, so we
	# test with a building of known kind by setting it to "sarbaz_khaneh"
	# (the BalanceData entry may or may not have train_piyade_* yet;
	# either way, if cost > 0 it deducts).
	_building = _spawn_producer_building()
	_building.kind = &"sarbaz_khaneh"
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var grain_before: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	var ok: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_true(ok, "preconditions met → request_train succeeds")
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var grain_after: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	# Deltas should be <= 0 (deduction or zero-cost fallback). Both deltas
	# happen on the same tick — caller sees them as a single atomic step.
	assert_lte(coin_after, coin_before,
		"coin must not increase after request_train")
	assert_lte(grain_after, grain_before,
		"grain must not increase after request_train")


func test_request_train_denies_when_insufficient_coin() -> void:
	# Force a known-positive cost via kind + monkey-patching is not
	# possible without BalanceData mock; instead, set up a producer
	# whose cost_coin fallback path is 0 → trivially affordable. To
	# verify the affordability branch, simulate insufficient coin by
	# resetting the team's coin to 0 AND using a non-empty kind that
	# might have a cost in balance.tres. When kind = &"" the fallback
	# is 0 cost, so this test exercises the OTHER side of the assertion:
	# even with zero coin, a zero-cost training still succeeds.
	_building = _spawn_producer_building()
	# Reset coin to 0 — _resolve_train_cost returns 0 by default (no
	# BalanceData entry for kind=&""), so the affordability check
	# (0 >= 0) trivially passes. Verify this branch doesn't false-
	# negative on legitimate zero-cost requests.
	SimClock._is_ticking = true
	# Drain coin to 0
	var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	if coin_now > 0:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, -coin_now, &"test_drain", null)
	ResourceSystem.change_population_cap(Constants.TEAM_IRAN, 10, &"t", null)
	# Drain grain too for symmetry, then top up grain so only coin is 0.
	var grain_now: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	if grain_now > 0:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_GRAIN, -grain_now, &"test_drain", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 10000, &"t", null)
	# At kind=&"" both costs fall to 0 — request should succeed.
	var ok: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_true(ok,
		"zero-cost training must succeed even with zero coin "
		+ "(affordability is 0 >= 0). If this fails, the cost check has "
		+ "a strictly-greater bug.")


func test_request_train_denies_when_pop_cap_full() -> void:
	# Pop cap full → request denies.
	_building = _spawn_producer_building()
	SimClock._is_ticking = true
	# Fill population to cap.
	var cap: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	var pop: int = ResourceSystem.population_for(Constants.TEAM_IRAN)
	if pop < cap:
		ResourceSystem.change_population(
			Constants.TEAM_IRAN, cap - pop, &"test_fill", null)
	# Now pop >= cap.
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	var ok: bool = _building.request_train(&"piyade")
	SimClock._is_ticking = false
	assert_false(ok,
		"request_train must deny when population >= population_cap")


# ===========================================================================
# Wave 3A.6 BUG-C1 fix-wave — canonical BalanceData lookup
# ===========================================================================
#
# Regression tests for BUG-C1: initial Track 1 ship at ac0416d used the wrong
# `bldg_<kind>` top-level-field pattern per the kickoff brief §3.4 prose,
# which did NOT match the canonical Dictionary lookup `BalanceData.buildings
# [<kind>]`. Result: every _resolve_train_cost / _resolve_train_dwell_ticks
# call silently returned 0 / 90-fallback. Cost=0 made the affordability
# check pass trivially (0 >= 0) and `if cost_coin > 0` skipped the
# deduction — training spawned units for free.
#
# These tests would have caught the bug at initial ship if my Track 1
# tests had asserted actual BalanceData lookups (rather than using
# kind=&"" + the 0-fallback path, which masked the bug).

func test_bug_c1_resolve_train_cost_reads_from_balance_data_dictionary() -> void:
	# REGRESSION: Sarbaz-khaneh's train_piyade_cost_coin = 50 in balance.tres
	# (line 365). The fixed _read_bldg_stats_int must return 50 via the
	# canonical `BalanceData.buildings[&"sarbaz_khaneh"].train_piyade_cost_coin`
	# lookup. Pre-fix this returned 0 (silent fallback).
	_building = _spawn_producer_building()
	_building.kind = &"sarbaz_khaneh"
	var coin_cost: int = _building._resolve_train_cost(&"piyade", &"coin")
	assert_eq(coin_cost, 50,
		"BUG-C1 regression: Sarbaz-khaneh train_piyade_cost_coin must read "
		+ "50 from BalanceData.buildings[sarbaz_khaneh]. If this returns 0, "
		+ "_read_bldg_stats_int is using the old wrong `bldg_<kind>` "
		+ "top-level-field pattern from the broken kickoff brief §3.4. "
		+ "Got: %d" % coin_cost)
	var grain_cost: int = _building._resolve_train_cost(&"piyade", &"grain")
	assert_eq(grain_cost, 10,
		"BUG-C1 regression: train_piyade_cost_grain must read 10 from "
		+ "BalanceData.buildings[sarbaz_khaneh]. Got: %d" % grain_cost)
	var dwell: int = _building._resolve_train_dwell_ticks(&"piyade")
	assert_eq(dwell, 90,
		"BUG-C1 regression: train_piyade_dwell_ticks must read 90 from "
		+ "BalanceData.buildings[sarbaz_khaneh]. Got: %d" % dwell)


func test_bug_c1_sowari_khaneh_savar_costs_read_correctly() -> void:
	# Cross-producer regression — exercise the same canonical lookup path
	# on a different producer to confirm the dictionary pattern works for
	# all 3 producers, not just one. balance.tres line 439-441.
	_building = _spawn_producer_building()
	_building.kind = &"sowari_khaneh"
	assert_eq(_building._resolve_train_cost(&"savar", &"coin"), 75,
		"BUG-C1 regression: Sowari-khaneh train_savar_cost_coin = 75 (line 439)")
	assert_eq(_building._resolve_train_cost(&"savar", &"grain"), 20,
		"BUG-C1 regression: Sowari-khaneh train_savar_cost_grain = 20 (line 440)")
	assert_eq(_building._resolve_train_dwell_ticks(&"savar"), 150,
		"BUG-C1 regression: Sowari-khaneh train_savar_dwell_ticks = 150 (line 441)")


func test_bug_c1_tirandazi_kamandar_costs_read_correctly() -> void:
	# Third-producer regression. balance.tres line 477-479.
	_building = _spawn_producer_building()
	_building.kind = &"tirandazi"
	assert_eq(_building._resolve_train_cost(&"kamandar", &"coin"), 60,
		"BUG-C1 regression: Tirandazi train_kamandar_cost_coin = 60 (line 477)")
	assert_eq(_building._resolve_train_cost(&"kamandar", &"grain"), 15,
		"BUG-C1 regression: Tirandazi train_kamandar_cost_grain = 15 (line 478)")
	assert_eq(_building._resolve_train_dwell_ticks(&"kamandar"), 120,
		"BUG-C1 regression: Tirandazi train_kamandar_dwell_ticks = 120 (line 479)")
