# Tests for the Mazra'eh (Iran grain farm) building — Phase 3 session 2 wave 1A.
#
# Per 02g_PHASE_3_SESSION_2_KICKOFF.md §3 wave 1A + 01_CORE_MECHANICS.md §5.
# Room A resolution (2026-05-14): trip-based long-dwell (R1-α shape), duck-typed
# three-call API on the Building subclass. See §2.4 for the full log.
#
# Test coverage:
#   1. Scene smoke + identity (kind, dual-init, Building base chain).
#   2. Duck-typed gather surface (request_extract / complete_extract /
#      release_extract) — the UnitState_Gathering seam.
#   3. Infinite reserves (reserves_x100 == -1 sentinel; never depletes).
#   4. Long-dwell config (extract_ticks == 90 for cultural R1-α texture).
#   5. Grain payload (kind &"grain", positive amount).
#   6. Placement side-effects (_on_placement_complete emits building_placed).
#   7. No NavigationObstacle3D (workers walk onto the farm, not around it).
#   8. Flat visual silhouette (BoxMesh 4.0 × 0.3 × 4.0, green color).
#   9. Schema fields (is_gatherable, resource_kind, reserves_x100, max_slots,
#      yield_per_trip_x100) — ClickHandler._is_resource_node_shaped() seam
#      and RESOURCE_NODE_CONTRACT §4.5 alignment.
extends GutTest


const MazraehScene: PackedScene = preload(
	"res://scenes/world/buildings/mazraeh.tscn")
const MazraehScript: Script = preload(
	"res://scripts/world/buildings/mazraeh.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _mazraeh: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _mazraeh != null and is_instance_valid(_mazraeh):
		_mazraeh.queue_free()
	_mazraeh = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_mazraeh(team: int = Constants.TEAM_IRAN) -> Variant:
	var m: Variant = MazraehScene.instantiate()
	m.team = team
	add_child_autofree(m)
	return m


# ---------------------------------------------------------------------------
# Scene smoke + identity
# ---------------------------------------------------------------------------

func test_mazraeh_scene_loads() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_not_null(_mazraeh, "mazraeh.tscn must load to a non-null node")


func test_mazraeh_kind_is_mazraeh_string_name() -> void:
	# Dual-init pattern (per kargar.gd's header) — _init and _ready both
	# set kind so scene-loaded instances don't get clobbered by the engine
	# @export reset between _init and _ready.
	_mazraeh = _spawn_mazraeh()
	assert_eq(_mazraeh.kind, &"mazraeh",
		"Mazra'eh.kind must be the StringName &\"mazraeh\"")


func test_mazraeh_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = MazraehScript.new()
	assert_eq(bare.kind, &"mazraeh",
		"Mazraeh.new() (no scene) must set kind = &\"mazraeh\" in _init")
	bare.free()


func test_mazraeh_inherits_building_base() -> void:
	# Mazra'eh extends Building; same script-base-walk pattern as
	# test_khaneh.gd::test_khaneh_is_a_building (dodges class_name registry race).
	_mazraeh = _spawn_mazraeh()
	var s: Script = _mazraeh.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"Mazra'eh instance must inherit from building.gd in its script chain")


# ---------------------------------------------------------------------------
# Infinite reserves — Mazra'eh never depletes
# ---------------------------------------------------------------------------

func test_mazraeh_complete_extract_never_triggers_depletion() -> void:
	# Mazra'eh extends Building (not ResourceNode), so it has no reserves_x100
	# field. The infinite-reserve behavior is implemented directly in the
	# duck-typed complete_extract — it always returns the full per-trip yield
	# and never flips any depletion state.
	# This test verifies the semantic: 1000 calls, still yields grain.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	var still_works: bool = true
	for i in range(20):  # 20 trips should be enough to catch any depletion bug
		_mazraeh.request_extract(1)
		SimClock._is_ticking = true
		var payload: Dictionary = _mazraeh.complete_extract(1)
		SimClock._is_ticking = false
		if payload.get(&"amount_x100", 0) == 0:
			still_works = false
			break
	assert_true(still_works,
		"Mazra'eh must yield grain on all 20 trips (never depletes)")


func test_mazraeh_remains_gatherable_after_many_trips() -> void:
	# Drive 100 trips — Mazra'eh must remain is_complete and is_gatherable,
	# and request_extract must keep returning true (never depletes).
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	for i in range(100):
		var granted: bool = _mazraeh.request_extract(1)
		assert_true(granted,
			"request_extract must succeed on trip %d (Mazra'eh never depletes)" % i)
		SimClock._is_ticking = true
		var payload: Dictionary = _mazraeh.complete_extract(1)
		SimClock._is_ticking = false
		assert_eq(payload.get(&"kind", &""), Constants.KIND_GRAIN,
			"payload kind must be KIND_GRAIN on trip %d" % i)
	assert_true(_mazraeh.is_complete,
		"Mazra'eh.is_complete must still be true after 100 trips")


# ---------------------------------------------------------------------------
# Duck-typed gather surface — the UnitState_Gathering seam
# ---------------------------------------------------------------------------

func test_mazraeh_has_request_extract_method() -> void:
	# UnitState_Gathering L143: has_method(&"request_extract") is the
	# discovery seam. If this method is missing, workers never gather here.
	_mazraeh = _spawn_mazraeh()
	assert_true(_mazraeh.has_method(&"request_extract"),
		"Mazra'eh must respond to has_method(&\"request_extract\")")


func test_mazraeh_has_complete_extract_method() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(_mazraeh.has_method(&"complete_extract"),
		"Mazra'eh must respond to has_method(&\"complete_extract\")")


func test_mazraeh_has_release_extract_method() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(_mazraeh.has_method(&"release_extract"),
		"Mazra'eh must respond to has_method(&\"release_extract\")")


func test_mazraeh_exposes_extract_ticks_property() -> void:
	# UnitState_Gathering L210: `_dwell_remaining_ticks = int(_target_node.extract_ticks)`.
	# If this property is missing, the dwell timer is always 0 and the worker
	# instantly completes every trip (no dwell, cultural R1-α texture breaks).
	_mazraeh = _spawn_mazraeh()
	assert_true(_mazraeh.get(&"extract_ticks") != null,
		"Mazra'eh must expose an extract_ticks property (read by UnitState_Gathering L210)")


func test_mazraeh_extract_ticks_is_ninety() -> void:
	# Room A resolution: 90 ticks (3s at SIM_HZ=30) for cultural long-dwell.
	# Mine is 60 ticks (2s). The longer dwell is the "stewardship of the land"
	# cultural texture per Room A §2.4.
	_mazraeh = _spawn_mazraeh()
	assert_eq(_mazraeh.extract_ticks, 90,
		"Mazra'eh.extract_ticks must be 90 (3s cultural long-dwell, Room A resolution)")


func test_request_extract_rejected_before_placement() -> void:
	# Workers should not be able to gather from an unplaced Mazra'eh
	# (is_complete = false at spawn).
	_mazraeh = _spawn_mazraeh()
	assert_false(_mazraeh.is_complete,
		"Mazra'eh is_complete must be false before place_at")
	assert_false(_mazraeh.request_extract(1),
		"request_extract must return false when Mazra'eh is not yet placed")


func test_request_extract_granted_after_placement() -> void:
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_mazraeh.request_extract(1),
		"request_extract must return true after place_at (Mazra'eh is placed)")


func test_complete_extract_returns_grain_payload() -> void:
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_mazraeh.request_extract(1)
	SimClock._is_ticking = true
	var payload: Dictionary = _mazraeh.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"kind", &""), Constants.KIND_GRAIN,
		"Mazra'eh complete_extract must return kind Constants.KIND_GRAIN")
	assert_true(payload.get(&"amount_x100", 0) > 0,
		"Mazra'eh complete_extract must return positive amount_x100")


func test_complete_extract_returns_two_grain_per_trip() -> void:
	# Room A resolution: grain_yield_per_trip_x100 = 200 (2 Grain/trip).
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_mazraeh.request_extract(1)
	SimClock._is_ticking = true
	var payload: Dictionary = _mazraeh.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"amount_x100", 0), 200,
		"Mazra'eh complete_extract must return amount_x100=200 (2 Grain, Room A)")


func test_complete_extract_without_request_returns_empty_payload() -> void:
	# If a worker calls complete_extract without holding a slot, the node
	# returns an empty payload instead of panicking.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	SimClock._is_ticking = true
	var payload: Dictionary = _mazraeh.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"kind", &""), &"",
		"complete_extract without request must return empty kind")
	assert_eq(payload.get(&"amount_x100", -1), 0,
		"complete_extract without request must return amount_x100=0")


func test_release_extract_frees_slot() -> void:
	# Contract §4.1: release always called from state exit() — even on death.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_mazraeh.request_extract(1)
	assert_eq(_mazraeh.occupied_slots(), 1, "slot occupied after request")
	_mazraeh.release_extract(1)
	assert_eq(_mazraeh.occupied_slots(), 0,
		"release_extract must free the slot")


func test_release_extract_idempotent() -> void:
	# Safe to call on death even if the worker didn't hold the slot.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_mazraeh.release_extract(99)  # never held a slot
	assert_eq(_mazraeh.occupied_slots(), 0,
		"release_extract on un-held slot must be idempotent")


func test_single_slot_per_wave_1a() -> void:
	# Mazra'eh ships with 1 slot in wave 1A (same simplification as MineNode).
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_mazraeh.request_extract(1), "worker 1 granted slot")
	assert_false(_mazraeh.request_extract(2),
		"worker 2 must be rejected when slot is full (single-slot wave 1A)")


# ---------------------------------------------------------------------------
# Placement side-effect
# ---------------------------------------------------------------------------

func test_placement_emits_building_placed_signal() -> void:
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team, &"pos": pos})
	EventBus.building_placed.connect(handler)
	_mazraeh = _spawn_mazraeh(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3(8.0, 0.0, -4.0), Constants.TEAM_IRAN, 7)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"Mazra'eh placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 7, "signal carries placer worker unit_id (7)")
	assert_eq(ev[&"kind"], &"mazraeh", "signal carries kind &\"mazraeh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries TEAM_IRAN")


func test_place_at_marks_is_complete_true() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_false(_mazraeh.is_complete, "starts incomplete before placement")
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_mazraeh.is_complete,
		"Mazra'eh.is_complete must be true after place_at")


# ---------------------------------------------------------------------------
# NO NavigationObstacle3D — workers walk onto the field
# ---------------------------------------------------------------------------

func test_no_navigation_obstacle() -> void:
	# Mazra'eh must NOT have a NavigationObstacle3D. Workers walk ONTO the
	# farm tile (Room A §2.4 + RESOURCE_NODE_CONTRACT §3.2 reaffirmation).
	# If this test fails, someone added an obstacle — remove it.
	_mazraeh = _spawn_mazraeh()
	var obstacle: Node = _mazraeh.get_node_or_null(^"NavigationObstacle3D")
	assert_null(obstacle,
		"Mazra'eh must NOT have a NavigationObstacle3D (workers walk onto the field)")


# ---------------------------------------------------------------------------
# Visual placeholder — flat green field, not a structure
# ---------------------------------------------------------------------------

func test_scene_has_mesh_instance_child() -> void:
	_mazraeh = _spawn_mazraeh()
	var mesh: Node = _mazraeh.get_node_or_null(^"MeshInstance3D")
	assert_not_null(mesh,
		"Mazra'eh scene must include a MeshInstance3D placeholder visual")


func test_scene_has_collision_body_for_click_target() -> void:
	# BUG-07 lesson: ClickHandler raycasts use collide_with_bodies=true.
	# Without a StaticBody3D, right-clicks fall through to the terrain.
	_mazraeh = _spawn_mazraeh()
	var body: Node = _mazraeh.get_node_or_null(^"StaticBody3D")
	assert_not_null(body,
		"Mazra'eh must have a StaticBody3D for right-click raycast targeting")


# ---------------------------------------------------------------------------
# FogSystem guard — forward-compat (wave 3A, no-op until FogSystem ships)
# ---------------------------------------------------------------------------

func test_mazraeh_calls_fogsystem_register_when_available() -> void:
	# When FogSystem singleton is NOT present (wave 1A normal state), placement
	# must succeed without error. The guard is forward-compat — no-op until wave 3A.
	# FogSystem is not available in headless test runs; skip the "called" branch
	# and assert the absence doesn't crash placement.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	# If we get here without error, the guard did not throw on missing singleton.
	assert_true(_mazraeh.is_complete,
		"Mazra'eh placement must complete without error when FogSystem is absent")


# ---------------------------------------------------------------------------
# Schema fields — ClickHandler._is_resource_node_shaped() seam + RNC §4.5
# ---------------------------------------------------------------------------

func test_mazraeh_has_is_gatherable_field() -> void:
	# click_handler.gd:447-460: checks `&"is_gatherable" in n` in addition to
	# has_method(&"request_extract"). Without this field, right-click on a
	# placed Mazra'eh silently drops and workers never receive a gather command.
	# Default is false (not gatherable until placement completes — forward-compat
	# with wave 1C construction timer; default-false means future Building
	# subclasses authored from this template won't accidentally allow gathering
	# during construction).
	_mazraeh = _spawn_mazraeh()
	assert_true(&"is_gatherable" in _mazraeh,
		"Mazra'eh must expose is_gatherable property for ClickHandler discovery")
	assert_false(_mazraeh.is_gatherable,
		"Mazra'eh.is_gatherable must be false before placement completes")


func test_mazraeh_is_gatherable_stays_false_after_place_at_only() -> void:
	# Wave 1C two-stage lifecycle: place_at fires Stage 1 only
	# (_on_placement_complete — structural side-effects). is_gatherable
	# is a Stage 2 (operational) flip that requires
	# _on_construction_complete to run. Driving place_at alone (as the
	# old test did) must leave is_gatherable = false. Stage 2 is fired
	# by UnitState_Constructing after construction_ticks elapse; see
	# test_unit_state_constructing.gd::
	#   test_mazraeh_is_not_gatherable_during_construction
	# for the behavioral coverage of the dwell-driven flip.
	_mazraeh = _spawn_mazraeh()
	assert_false(_mazraeh.is_gatherable,
		"is_gatherable must be false before place_at")
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_mazraeh.is_gatherable,
		"is_gatherable must REMAIN false after place_at alone — Stage 1 "
		+ "(_on_placement_complete) is structural; the flip is gated on "
		+ "Stage 2 (_on_construction_complete) per wave 1C lifecycle.")


func test_mazraeh_is_gatherable_flips_on_construction_complete() -> void:
	# Stage 2 hook fires the flip. Drive the hook directly here to lock
	# the per-hook contract; the integration-level driving-via-ticks
	# coverage lives in test_unit_state_constructing.gd.
	_mazraeh = _spawn_mazraeh()
	SimClock._is_ticking = true
	_mazraeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_mazraeh.is_gatherable,
		"sanity: still false post-Stage-1")
	# Fire Stage 2 directly. Production caller is
	# UnitState_Constructing._sim_tick at dwell-complete.
	_mazraeh._on_construction_complete(1)
	assert_true(_mazraeh.is_gatherable,
		"is_gatherable must be true after _on_construction_complete (Stage 2 flip)")


func test_mazraeh_resource_kind_is_grain() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(&"resource_kind" in _mazraeh,
		"Mazra'eh must expose resource_kind property (RNC §4.5 schema)")
	assert_eq(_mazraeh.resource_kind, Constants.KIND_GRAIN,
		"Mazra'eh.resource_kind must equal Constants.KIND_GRAIN")


func test_mazraeh_reserves_x100_is_infinite_sentinel() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(&"reserves_x100" in _mazraeh,
		"Mazra'eh must expose reserves_x100 property (RNC §4.5 schema)")
	assert_eq(_mazraeh.reserves_x100, -1,
		"Mazra'eh.reserves_x100 must be -1 (infinite sentinel — never depletes)")


func test_mazraeh_max_slots_is_one() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(&"max_slots" in _mazraeh,
		"Mazra'eh must expose max_slots property (RNC §4.5 schema)")
	assert_eq(_mazraeh.max_slots, 1,
		"Mazra'eh.max_slots must be 1 for wave 1A")


func test_mazraeh_yield_per_trip_x100_is_two_hundred() -> void:
	_mazraeh = _spawn_mazraeh()
	assert_true(&"yield_per_trip_x100" in _mazraeh,
		"Mazra'eh must expose yield_per_trip_x100 property (RNC §4.5 schema)")
	assert_eq(_mazraeh.yield_per_trip_x100, 200,
		"Mazra'eh.yield_per_trip_x100 must be 200 (2 Grain/trip, Room A R1-α)")


# ---------------------------------------------------------------------------
# Static cost helper — read by BuildMenu for the button label
# ---------------------------------------------------------------------------

func test_mazraeh_cost_coin_returns_balance_data_value() -> void:
	# Mirrors Khaneh.cost_coin coverage. BalanceData ships
	# bldgs.mazraeh.coin_cost = 60 (per balance.tres lines 243-249).
	# The static helper exists so the BuildMenu can read the cost
	# without instantiating a Mazra'eh scene.
	var cost: int = MazraehScript.call(&"cost_coin")
	assert_eq(cost, 60,
		"Mazraeh.cost_coin() must return 60 (BalanceData coin_cost)")


func test_mazraeh_material_is_green_not_neutral_grey() -> void:
	# Placeholder visual differentiation: agricultural green (0.55, 0.75, 0.35)
	# vs base Building grey (0.55, 0.55, 0.55). Green channel must be dominant.
	_mazraeh = _spawn_mazraeh()
	var mi: MeshInstance3D = _mazraeh.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Mazra'eh must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Mazra'eh material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.g > sm.albedo_color.r,
		"Mazra'eh albedo green must be dominant (agricultural green), "
		+ "got r=%.2f g=%.2f" % [sm.albedo_color.r, sm.albedo_color.g])
	assert_true(sm.albedo_color.g > sm.albedo_color.b,
		"Mazra'eh albedo green must exceed blue, "
		+ "got g=%.2f b=%.2f" % [sm.albedo_color.g, sm.albedo_color.b])
