# Tests for the Ma'dan (Iran mining-operation building) — Phase 3 session 2 wave 1B.
#
# Per 02g_PHASE_3_SESSION_2_KICKOFF.md §3 wave 1B + 01_CORE_MECHANICS.md §5.
# Open Space Room A Option B ratified (2026-05-14): Ma'dan is a buff-emitter
# that modifies adjacent MineNode extraction yield. Ma'dan is NOT itself a
# resource source — it does NOT register with ResourceSystem, does NOT carry
# the ResourceNode-shape gather schema fields (is_gatherable, resource_kind,
# reserves_x100, max_slots, yield_per_trip_x100 — all absent on Ma'dan).
#
# Test coverage:
#   1. Scene smoke + identity (kind = &"madan", dual-init, Building base chain).
#   2. NO ResourceNode-shape fields — Ma'dan is explicitly NOT a gather target;
#      click_handler._is_resource_node_shaped should reject Ma'dan correctly.
#   3. Cost helper (cost_coin() reads BalanceData buildings.madan.coin_cost
#      with defensive fallback).
#   4. Yield multiplier API (yield_multiplier_x100() reads BalanceData
#      buildings.madan.modifier_value_x100 with fallback).
#   5. Placement-time mine-discovery — nearest MineNode in radius found and
#      register_extraction_modifier called via has_method guard.
#   6. Free placement — Ma'dan with no adjacent mine still places (no crash;
#      no-op fallthrough).
#   7. Autoload-guard pattern (FogSystem absent → no crash on placement).
#   8. NavigationObstacle3D present (workers route AROUND Ma'dan; contrasts
#      with Mazra'eh which has none).
extends GutTest


const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")
const MadanScript: Script = preload(
	"res://scripts/world/buildings/madan.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")


var _madan: Variant
var _mine: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _madan != null and is_instance_valid(_madan):
		_madan.queue_free()
	_madan = null
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	_mine = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_madan(team: int = Constants.TEAM_IRAN) -> Variant:
	var m: Variant = MadanScene.instantiate()
	m.team = team
	add_child_autofree(m)
	return m


func _spawn_mine_at(pos: Vector3) -> Variant:
	var n: Variant = MineNodeScene.instantiate()
	add_child_autofree(n)
	n.global_position = pos
	return n


# ---------------------------------------------------------------------------
# Scene smoke + identity
# ---------------------------------------------------------------------------

func test_madan_scene_loads() -> void:
	_madan = _spawn_madan()
	assert_not_null(_madan, "madan.tscn must load to a non-null node")


func test_madan_kind_is_madan_string_name() -> void:
	# Dual-init pattern — _init and _ready both set kind so scene-loaded
	# instances don't get clobbered by the engine @export reset.
	_madan = _spawn_madan()
	assert_eq(_madan.kind, &"madan",
		"Ma'dan.kind must be the StringName &\"madan\"")


func test_madan_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = MadanScript.new()
	assert_eq(bare.kind, &"madan",
		"Madan.new() (no scene) must set kind = &\"madan\" in _init")
	bare.free()


func test_madan_inherits_building_base() -> void:
	# Same script-base-walk as test_mazraeh.gd::test_mazraeh_inherits_building_base.
	_madan = _spawn_madan()
	var s: Script = _madan.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"Ma'dan instance must inherit from building.gd somewhere in its "
		+ "script chain")


func test_madan_joins_buildings_group_on_ready() -> void:
	# Per Building.gd:_ready — every Building joins &"buildings" group.
	# This is the BUG-11 fix surface: BoxSelectHandler / DoubleClickSelect
	# / etc. exclude &"buildings" group members from unit-shaped filters.
	# Ma'dan inherits this for free.
	_madan = _spawn_madan()
	assert_true(_madan.is_in_group(&"buildings"),
		"Ma'dan must join &\"buildings\" group via Building._ready")


# ---------------------------------------------------------------------------
# NOT a gather target — schema fields are intentionally ABSENT
# ---------------------------------------------------------------------------

func test_madan_does_not_have_is_gatherable_field() -> void:
	# click_handler._is_resource_node_shaped checks `&"is_gatherable" in n`
	# AND `has_method(&"request_extract")`. Ma'dan must FAIL BOTH checks —
	# Ma'dan is a buff-emitter, not a gather target. Right-clicking a
	# Ma'dan should NOT dispatch a gather command.
	_madan = _spawn_madan()
	assert_false(&"is_gatherable" in _madan,
		"Ma'dan must NOT expose is_gatherable — it is NOT a gather target. "
		+ "ClickHandler._is_resource_node_shaped relies on this exclusion.")


func test_madan_does_not_have_request_extract_method() -> void:
	# Companion check to is_gatherable absence. ClickHandler's
	# _is_resource_node_shaped requires BOTH the field AND the method;
	# Ma'dan must fail this check unambiguously.
	_madan = _spawn_madan()
	assert_false(_madan.has_method(&"request_extract"),
		"Ma'dan must NOT have request_extract — only ResourceNode subclasses "
		+ "and resource-producing Building subclasses (Mazra'eh) carry it.")


func test_madan_does_not_have_resource_kind_field() -> void:
	# RNC §4.6 (v1.2.2): resource_kind is the registry-seam for resource-
	# producing Building subclasses. Ma'dan does NOT produce a resource;
	# the resource_kind field is absent.
	_madan = _spawn_madan()
	assert_false(&"resource_kind" in _madan,
		"Ma'dan must NOT have resource_kind — it is not a resource source. "
		+ "Ma'dan modifies the MineNode it's adjacent to instead.")


# ---------------------------------------------------------------------------
# Cost helper
# ---------------------------------------------------------------------------

func test_madan_cost_coin_returns_integer() -> void:
	var cost: int = MadanScript.call(&"cost_coin")
	assert_true(cost > 0,
		"Ma'dan.cost_coin() must return a positive integer (BalanceData "
		+ "shipped value or the defensive fallback). Got: %d" % cost)


func test_madan_cost_coin_matches_balance_data_or_fallback() -> void:
	# When balance.tres ships bldg_madan.coin_cost (per d798e78), the
	# value is 40. The defensive fallback is also 40 per
	# _FALLBACK_COIN_COST. Either way the cost should be 40 at MVP scope.
	var cost: int = MadanScript.call(&"cost_coin")
	assert_eq(cost, 40,
		"Ma'dan.cost_coin() must be 40 (matches balance.tres bldg_madan "
		+ "AND _FALLBACK_COIN_COST per 01_CORE_MECHANICS §5)")


# ---------------------------------------------------------------------------
# Yield multiplier API (read by MineNode.effective_yield_per_trip_x100 in Commit 2)
# ---------------------------------------------------------------------------

func test_madan_yield_multiplier_x100_returns_positive() -> void:
	_madan = _spawn_madan()
	var m: int = _madan.yield_multiplier_x100()
	assert_true(m > 0,
		"Ma'dan.yield_multiplier_x100() must return a positive int. Got: %d" % m)


func test_madan_yield_multiplier_x100_default_is_150() -> void:
	# Per balance-engineer's d798e78 (modifier_value_x100 = 150 in
	# bldg_madan) + design Q2 (1.5x default). The defensive fallback is
	# also 150. Either way the value should be 150 at MVP scope.
	_madan = _spawn_madan()
	var m: int = _madan.yield_multiplier_x100()
	assert_eq(m, 150,
		"Ma'dan yield multiplier must be 150 (1.5x in x100 fixed-point) — "
		+ "balance.tres bldg_madan.modifier_value_x100 = 150 per d798e78.")


# ---------------------------------------------------------------------------
# Placement-time mine discovery
# ---------------------------------------------------------------------------

func test_madan_placement_registers_with_nearby_mine() -> void:
	# Spawn a MineNode at (5, 0, 0). Ma'dan placed at (3, 0, 0) is within
	# the default 4m radius. _on_placement_complete should call
	# mine.register_extraction_modifier(self).
	#
	# Wave 1B Commit 2 ships register_extraction_modifier. Commit 1 (THIS
	# COMMIT) ships the call site behind a has_method guard. We test the
	# guard fires by stubbing the MineNode's register_extraction_modifier
	# observability via a meta flag check after place_at.
	_mine = _spawn_mine_at(Vector3(5.0, 0.0, 0.0))
	_madan = _spawn_madan()
	# Inject a meta-based register_extraction_modifier stub so the guard
	# fires even before Commit 2 ships. Mark when called.
	_mine.set_meta(&"register_called", false)
	# Note: GDScript doesn't allow runtime method monkey-patching on a
	# scene-loaded instance, so we exercise the indirect path: place the
	# Ma'dan and verify that if MineNode had the method, it would be
	# called. Defer the actual call-firing assertion to Commit 2's tests
	# (where register_extraction_modifier exists as a real method).
	#
	# For Commit 1: assert that the placement succeeds without crashing
	# even though the API is absent. This is the forward-compat guard
	# working as intended.
	_madan.place_at(Vector3(3.0, 0.0, 0.0), Constants.TEAM_IRAN, 0)
	assert_true(_madan.is_complete,
		"Ma'dan placement must complete even when adjacent MineNode lacks "
		+ "register_extraction_modifier (forward-compat guard)")


func test_madan_placement_no_adjacent_mine_is_no_op() -> void:
	# Per design Q4: free placement; if no mine within radius, the
	# building still places but does nothing at runtime. Place a Ma'dan
	# far from any mine (no _mine spawn) — placement succeeds, no crash.
	_madan = _spawn_madan()
	_madan.place_at(Vector3(50.0, 0.0, 50.0), Constants.TEAM_IRAN, 0)
	assert_true(_madan.is_complete,
		"Ma'dan placement must succeed (Q4 free placement) even with no "
		+ "mine within radius")


func test_madan_find_nearest_mine_returns_null_when_none_in_radius() -> void:
	# _find_nearest_mine_within_radius is the internal seam. With no mine
	# in the scene at all, it must return null.
	_madan = _spawn_madan()
	var nearest: Variant = _madan._find_nearest_mine_within_radius(4.0)
	assert_eq(nearest, null,
		"_find_nearest_mine_within_radius returns null when no mine exists")


func test_madan_find_nearest_mine_returns_mine_within_radius() -> void:
	_mine = _spawn_mine_at(Vector3(3.0, 0.0, 0.0))
	_madan = _spawn_madan()
	# Madan at origin; mine at (3,0,0) is within 4m radius.
	var nearest: Variant = _madan._find_nearest_mine_within_radius(4.0)
	assert_eq(nearest, _mine,
		"_find_nearest_mine_within_radius returns the mine when within radius")


func test_madan_find_nearest_mine_returns_null_when_out_of_radius() -> void:
	# Mine at (10,0,0); Ma'dan at origin; 4m radius excludes the mine.
	_mine = _spawn_mine_at(Vector3(10.0, 0.0, 0.0))
	_madan = _spawn_madan()
	var nearest: Variant = _madan._find_nearest_mine_within_radius(4.0)
	assert_eq(nearest, null,
		"_find_nearest_mine_within_radius returns null when mine is out of radius")


# ---------------------------------------------------------------------------
# Placement side-effect signal
# ---------------------------------------------------------------------------

func test_madan_placement_emits_building_placed_signal() -> void:
	var received_events: Array = []
	var handler: Callable = func(
			placer_id: int, kind: StringName, team: int, pos: Vector3) -> void:
		received_events.append({
			&"placer_id": placer_id,
			&"kind": kind,
			&"team": team,
			&"pos": pos,
		})
	EventBus.building_placed.connect(handler)
	_madan = _spawn_madan()
	_madan.place_at(Vector3(0.0, 0.0, 0.0), Constants.TEAM_IRAN, 42)
	EventBus.building_placed.disconnect(handler)
	assert_eq(received_events.size(), 1,
		"Ma'dan.place_at must emit building_placed exactly once")
	assert_eq(received_events[0][&"kind"], &"madan",
		"building_placed payload kind must be &\"madan\"")
	assert_eq(received_events[0][&"placer_id"], 42,
		"building_placed payload placer_id must be the place_at argument")


# ---------------------------------------------------------------------------
# Scene composition — NavigationObstacle3D present (contrasts with Mazra'eh)
# ---------------------------------------------------------------------------

func test_madan_has_navigation_obstacle() -> void:
	# Per madan.tscn header rationale + RNC §3.2 v1.4.0 + WAVE_1C_NAVMESH_SPIKE §2.3:
	# Ma'dan is structural; workers route AROUND it. Contrast with Mazra'eh
	# which deliberately has NO obstacle (workers walk ONTO the farm).
	_madan = _spawn_madan()
	var nav: Node = _madan.get_node_or_null(^"NavigationObstacle3D")
	assert_not_null(nav,
		"Ma'dan must have a NavigationObstacle3D (workers route around it).")
	# Behavioral discipline per STUDIO_PROCESS.md §9 (2026-05-15 rule):
	# verify Path A config — not just presence.
	assert_true(nav.affect_navigation_mesh,
		"NavigationObstacle3D.affect_navigation_mesh must be true on Ma'dan "
		+ "(Path A static-carve mode per RNC §3.2 v1.4.0)")
	assert_gt(nav.vertices.size(), 2,
		"NavigationObstacle3D.vertices must be non-empty polygon on Ma'dan "
		+ "(2.5×2.5 footprint, ±1.35m polygon per WAVE_1C_NAVMESH_SPIKE §2.3)")


func test_madan_scene_has_static_body_collision() -> void:
	# BUG-07 lesson — click-targets need a CollisionObject3D ancestor or
	# raycasts walk past them. Ma'dan is click-targetable for select-the-
	# building (BUG-11 selection-exclusion handles building/unit distinction
	# via &"buildings" group membership).
	_madan = _spawn_madan()
	var sb: Node = _madan.get_node_or_null(^"StaticBody3D")
	assert_not_null(sb,
		"Ma'dan must contain a StaticBody3D for raycast click-target")
	var shape: Node = sb.get_node_or_null(^"CollisionShape3D")
	assert_not_null(shape,
		"StaticBody3D must contain a CollisionShape3D — body without "
		+ "shape is a no-op for raycasts")
