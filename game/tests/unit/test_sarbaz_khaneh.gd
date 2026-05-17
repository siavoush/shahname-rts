# Tests for the Sarbaz-khaneh (Iran barracks) building — Phase 3 session 4 wave 2A.
#
# Per 02h_PHASE_3_SESSION_4_KICKOFF.md §3 wave 2A + 01_CORE_MECHANICS.md §5.
# Third anchor-category Building variant: identity-bearing institutional.
# Distinct from Khaneh (civic-anchor) / Mazra'eh (resource-producing) /
# Ma'dan (labor-organization).
#
# Test coverage:
#   1. Script identity (kind = &"sarbaz_khaneh", dual-init pattern,
#      Building base inheritance chain).
#   2. is_ready_to_produce flag — Stage-2 operational marker. Defaults
#      false; flips true at _on_construction_complete (Stage 2). The
#      operational-gating discipline parallel to Mazra'eh.is_gatherable.
#   3. Two-stage lifecycle BEHAVIORAL: Stage 1 (place_at) does NOT set
#      is_ready_to_produce; Stage 2 (_on_construction_complete) does.
#   4. super() chain — _on_placement_complete calls super (Wave 1D
#      rebake pipeline); _on_construction_complete calls super (session-3
#      retro §9 super()-call discipline).
#   5. Placement-side-effect signals (EventBus.building_placed emit with
#      kind = &"sarbaz_khaneh", team, position).
#   6. Cost helper (cost_coin() reads BalanceData with defensive fallback).
#   7. Autoload-guard pattern (FogSystem absent → no crash on placement).
#
# Test pattern: prefer `.new()` headless construction over scene
# instantiation. world-builder-p3s2 ships sarbaz_khaneh.tscn on Track 2 in
# parallel; this test file (Track 1 scope) does NOT preload the scene —
# scene-level coverage (mesh, NavigationObstacle3D, click-target body)
# lives in world-builder's wave-2A test additions.
extends GutTest


const SarbazKhanehScript: Script = preload(
	"res://scripts/world/buildings/sarbaz_khaneh.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _sarbaz_khaneh: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _sarbaz_khaneh != null and is_instance_valid(_sarbaz_khaneh):
		_sarbaz_khaneh.queue_free()
	_sarbaz_khaneh = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_sarbaz_khaneh(team: int = Constants.TEAM_IRAN) -> Variant:
	# Headless construction via .new() — does not require the parallel
	# Track-2 scene file (sarbaz_khaneh.tscn). When world-builder ships
	# the scene, scene-level tests can add MazraehScene-style preloads.
	var b: Variant = SarbazKhanehScript.new()
	b.team = team
	add_child_autofree(b)
	return b


# ---------------------------------------------------------------------------
# Identity — kind, dual-init, inheritance chain
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = SarbazKhanehScript.new()
	assert_eq(bare.kind, &"sarbaz_khaneh",
		"SarbazKhaneh.new() (no scene) must set kind = &\"sarbaz_khaneh\" in _init")
	bare.free()


func test_sarbaz_khaneh_kind_post_ready() -> void:
	# Dual-init pattern — _ready must reaffirm kind after the engine
	# resets @export defaults between _init and _ready.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_eq(_sarbaz_khaneh.kind, &"sarbaz_khaneh",
		"SarbazKhaneh.kind must be &\"sarbaz_khaneh\" after _ready")


func test_sarbaz_khaneh_inherits_building_base() -> void:
	# Same script-base-walk pattern as test_madan.gd / test_mazraeh.gd —
	# dodges class_name registry race per Pitfall #13.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	var s: Script = _sarbaz_khaneh.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"SarbazKhaneh instance must inherit from building.gd in its script chain")


func test_sarbaz_khaneh_class_name_is_sarbaz_khaneh() -> void:
	# Per loremaster transliteration-consistency rule (catches rename drift).
	# Script.get_global_name() returns the GDScript class_name; for
	# `class_name SarbazKhaneh` this must return "SarbazKhaneh".
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	var s: Script = _sarbaz_khaneh.get_script()
	var global_name: StringName = s.get_global_name()
	assert_eq(global_name, &"SarbazKhaneh",
		"sarbaz_khaneh.gd must declare class_name SarbazKhaneh "
		+ "(transliteration discipline). Got: " + global_name)


func test_sarbaz_khaneh_joins_buildings_group_on_ready() -> void:
	# Inherited from Building._ready — consumers iterate
	# &"buildings" group for AI / UI / placement-validity discovery.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_true(_sarbaz_khaneh.is_in_group(&"buildings"),
		"SarbazKhaneh inherits Building._ready add_to_group(&\"buildings\")")


# ---------------------------------------------------------------------------
# is_ready_to_produce field — Stage-2 operational marker
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_has_is_ready_to_produce_field() -> void:
	# Public surface for Phase-4 production-queue. Must be exposed for
	# future consumers (UnitProductionQueue, build menu, AI training).
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_true(&"is_ready_to_produce" in _sarbaz_khaneh,
		"SarbazKhaneh must expose is_ready_to_produce field for Phase-4 "
		+ "production-queue discovery")


func test_sarbaz_khaneh_is_ready_to_produce_defaults_false() -> void:
	# Default false ensures operational-gating discipline at spawn: a
	# freshly-instantiated Sarbaz-khaneh cannot accept training requests
	# until construction completes. Mirrors Mazra'eh.is_gatherable's
	# default-false pattern.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_false(_sarbaz_khaneh.is_ready_to_produce,
		"SarbazKhaneh.is_ready_to_produce must default false at spawn — "
		+ "the building exists but cannot yet train soldiers")


# ---------------------------------------------------------------------------
# Two-stage lifecycle BEHAVIORAL — Stage 1 vs Stage 2 operational gating
# ---------------------------------------------------------------------------

func test_is_ready_to_produce_stays_false_after_place_at_only() -> void:
	# BEHAVIORAL: place_at fires Stage 1 (_on_placement_complete — structural).
	# is_ready_to_produce is a Stage-2 (operational) marker that requires
	# _on_construction_complete to run. Driving place_at alone must leave
	# is_ready_to_produce = false. Mirrors Mazra'eh's
	# test_mazraeh_is_gatherable_stays_false_after_place_at_only contract.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_false(_sarbaz_khaneh.is_ready_to_produce,
		"sanity: false at spawn")
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_sarbaz_khaneh.is_ready_to_produce,
		"BEHAVIORAL: is_ready_to_produce must REMAIN false after place_at "
		+ "alone — Stage 1 is structural; the operational flip is gated "
		+ "on Stage 2 (_on_construction_complete) per wave-1C lifecycle.")


func test_is_ready_to_produce_flips_on_construction_complete() -> void:
	# Stage 2 hook fires the flip. Drive the hook directly to lock the
	# per-hook contract; integration-level driving-via-construction-ticks
	# coverage lives in test_unit_state_constructing.gd.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_sarbaz_khaneh.is_ready_to_produce,
		"sanity: still false post-Stage-1")
	# Fire Stage 2 directly. Production caller is
	# UnitState_Constructing._sim_tick at dwell-complete.
	_sarbaz_khaneh._on_construction_complete(1)
	assert_true(_sarbaz_khaneh.is_ready_to_produce,
		"is_ready_to_produce must be true after _on_construction_complete "
		+ "(Stage 2 operational flip)")


# ---------------------------------------------------------------------------
# Placement side-effect — EventBus.building_placed signal
# ---------------------------------------------------------------------------

func test_placement_emits_building_placed_signal() -> void:
	# _on_placement_complete (Stage 1) must emit EventBus.building_placed
	# with kind = &"sarbaz_khaneh". Telemetry / AI / UI consumers
	# distinguish kinds via this signal payload.
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team, &"pos": pos})
	EventBus.building_placed.connect(handler)
	_sarbaz_khaneh = _spawn_sarbaz_khaneh(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3(15.0, 0.0, -8.0), Constants.TEAM_IRAN, 13)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"SarbazKhaneh placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 13, "signal carries placer worker unit_id (13)")
	assert_eq(ev[&"kind"], &"sarbaz_khaneh",
		"signal carries kind &\"sarbaz_khaneh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries TEAM_IRAN")


# ---------------------------------------------------------------------------
# place_at — base lifecycle integration
# ---------------------------------------------------------------------------

func test_place_at_sets_global_position() -> void:
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3(10.0, 0.0, 5.0), Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_almost_eq(_sarbaz_khaneh.global_position.x, 10.0, 0.0001,
		"place_at sets global_position.x")
	assert_almost_eq(_sarbaz_khaneh.global_position.z, 5.0, 0.0001,
		"place_at sets global_position.z")


func test_place_at_marks_is_complete_true() -> void:
	# is_complete is the STRUCTURAL marker (set by Building.place_at).
	# Distinct from is_ready_to_produce (operational, set by Stage 2).
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	assert_false(_sarbaz_khaneh.is_complete, "starts incomplete")
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_sarbaz_khaneh.is_complete,
		"is_complete = true after place_at (Stage 1 structural placement)")


# ---------------------------------------------------------------------------
# FogSystem guard — forward-compat (no crash when absent)
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_placement_no_crash_when_fogsystem_absent() -> void:
	# When FogSystem singleton is NOT present (test runs / wave 3A pending),
	# placement must succeed without error. Same autoload-guard pattern as
	# Khaneh / Mazra'eh / Ma'dan.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh()
	SimClock._is_ticking = true
	_sarbaz_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_sarbaz_khaneh.is_complete,
		"SarbazKhaneh placement completes without error when FogSystem absent")


# ---------------------------------------------------------------------------
# Static cost helper — read by BuildMenu (Track 4 ui-developer)
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_cost_coin_returns_balance_data_value_or_fallback() -> void:
	# Cost reads BalanceData.buildings.sarbaz_khaneh.coin_cost with defensive
	# fallback (100 per 01_CORE_MECHANICS.md §5). balance-engineer's Track 3
	# ships the BalanceData entry; until then, fallback is returned.
	# Either way, the static helper exists so BuildMenu can read the cost
	# without instantiating a SarbazKhaneh scene.
	var cost: int = SarbazKhanehScript.call(&"cost_coin")
	assert_true(cost > 0,
		"SarbazKhaneh.cost_coin() must return a positive value (either "
		+ "BalanceData entry or the 100-coin fallback). Got: %d" % cost)
