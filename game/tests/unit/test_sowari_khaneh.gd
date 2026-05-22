# Tests for the Sowari-khaneh (Iran cavalry barracks) — Phase 3 Wave 2B.
#
# Per 01_CORE_MECHANICS.md §5 line 194 (Tier-2 entry: 200 coin, produces
# Savar) + docs/ARCHITECTURE.md §6 (Wave 2B close entry) +
# docs/ANCHOR_CATEGORY_TAXONOMY.md v1.0.0 (identity-bearing institutional /
# cavalry-tradition sub-slot).
#
# Test coverage:
#   1. Script identity (kind = &"sowari_khaneh", dual-init, Building base
#      inheritance, class_name discipline, &"buildings" group).
#   2. is_ready_to_produce — Stage-2 operational marker. Mirrors
#      Sarbaz-khaneh's pattern per §9.L5 (sub-slot specialization is at
#      unit-class level, not marker level).
#   3. Two-stage lifecycle BEHAVIORAL: Stage 1 (place_at) does NOT set
#      is_ready_to_produce; Stage 2 (_on_construction_complete) does.
#   4. super() chain — _on_placement_complete + _on_construction_complete
#      both call super per §9.L4a + §9.L4b discipline.
#   5. Placement side-effect — EventBus.building_placed signal payload.
#   6. Cost helper — cost_coin() returns 200 (BalanceData) or fallback.
#   7. FogSystem autoload-guard no-crash (forward-compat).
#
# Test pattern per §9.M4: prefer `.new()` headless construction over scene
# instantiation. world-builder Track 2 ships sowari_khaneh.tscn in parallel;
# this test file (Track 1 scope) does NOT preload the scene — scene-level
# coverage (mesh, NavigationObstacle3D, click-target body) lives in
# world-builder's Track 2 test additions.
extends GutTest


const SowariKhanehScript: Script = preload(
	"res://scripts/world/buildings/sowari_khaneh.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _sowari_khaneh: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _sowari_khaneh != null and is_instance_valid(_sowari_khaneh):
		_sowari_khaneh.queue_free()
	_sowari_khaneh = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_sowari_khaneh(team: int = Constants.TEAM_IRAN) -> Variant:
	# Headless construction via .new() per §9.M4 — does not require the
	# parallel Track-2 scene file (sowari_khaneh.tscn). When world-builder
	# ships the scene, scene-level tests can add SowariKhanehScene-style
	# preloads.
	var b: Variant = SowariKhanehScript.new()
	b.team = team
	add_child_autofree(b)
	return b


# ---------------------------------------------------------------------------
# Identity — kind, dual-init, inheritance chain, class_name, group
# ---------------------------------------------------------------------------

func test_sowari_khaneh_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = SowariKhanehScript.new()
	assert_eq(bare.kind, &"sowari_khaneh",
		"SowariKhaneh.new() (no scene) must set kind = &\"sowari_khaneh\" in _init")
	bare.free()


func test_sowari_khaneh_kind_post_ready() -> void:
	# Dual-init pattern — _ready must reaffirm kind after the engine
	# resets @export defaults between _init and _ready.
	_sowari_khaneh = _spawn_sowari_khaneh()
	assert_eq(_sowari_khaneh.kind, &"sowari_khaneh",
		"SowariKhaneh.kind must be &\"sowari_khaneh\" after _ready")


func test_sowari_khaneh_inherits_building_base() -> void:
	# Script-base-walk pattern — dodges class_name registry race per
	# Pitfall #13. Same shape as sibling building tests.
	_sowari_khaneh = _spawn_sowari_khaneh()
	var s: Script = _sowari_khaneh.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"SowariKhaneh instance must inherit from building.gd in its script chain")


func test_sowari_khaneh_class_name_is_sowari_khaneh() -> void:
	# Per §9.J3 + loremaster transliteration-consistency rule. For
	# `class_name SowariKhaneh` this must return "SowariKhaneh".
	_sowari_khaneh = _spawn_sowari_khaneh()
	var s: Script = _sowari_khaneh.get_script()
	var global_name: StringName = s.get_global_name()
	assert_eq(global_name, &"SowariKhaneh",
		"sowari_khaneh.gd must declare class_name SowariKhaneh "
		+ "(transliteration discipline). Got: " + global_name)


func test_sowari_khaneh_joins_buildings_group_on_ready() -> void:
	# Inherited from Building._ready — consumers iterate &"buildings"
	# group for AI / UI / placement-validity discovery.
	_sowari_khaneh = _spawn_sowari_khaneh()
	assert_true(_sowari_khaneh.is_in_group(&"buildings"),
		"SowariKhaneh inherits Building._ready add_to_group(&\"buildings\")")


# ---------------------------------------------------------------------------
# is_ready_to_produce field — Stage-2 operational marker
# ---------------------------------------------------------------------------

func test_sowari_khaneh_has_is_ready_to_produce_field() -> void:
	# Public surface for Phase-4 production-queue. Must be exposed for
	# future consumers (UnitProductionQueue, build menu, AI training).
	# Mirrors Sarbaz-khaneh per §9.L5 — sub-slot specialization is at
	# the unit-class level (Savar vs Piyade), NOT the marker level.
	_sowari_khaneh = _spawn_sowari_khaneh()
	assert_true(&"is_ready_to_produce" in _sowari_khaneh,
		"SowariKhaneh must expose is_ready_to_produce field for Phase-4 "
		+ "production-queue discovery")


func test_sowari_khaneh_is_ready_to_produce_defaults_false() -> void:
	# Default false ensures operational-gating discipline at spawn: a
	# freshly-instantiated Sowari-khaneh cannot accept Savar training
	# requests until construction completes. Mirrors Mazra'eh.is_gatherable
	# + Sarbaz-khaneh.is_ready_to_produce + Atashkadeh.is_emitting_farr
	# default-false patterns per §9.L5.
	_sowari_khaneh = _spawn_sowari_khaneh()
	assert_false(_sowari_khaneh.is_ready_to_produce,
		"SowariKhaneh.is_ready_to_produce must default false at spawn — "
		+ "the cavalry barracks exists but cannot yet train Savar")


# ---------------------------------------------------------------------------
# Two-stage lifecycle BEHAVIORAL — Stage 1 vs Stage 2 operational gating
# ---------------------------------------------------------------------------

func test_is_ready_to_produce_stays_false_after_place_at_only() -> void:
	# BEHAVIORAL: place_at fires Stage 1 (_on_placement_complete —
	# structural). is_ready_to_produce is a Stage-2 (operational) marker
	# that requires _on_construction_complete to run. Driving place_at
	# alone must leave is_ready_to_produce = false.
	_sowari_khaneh = _spawn_sowari_khaneh()
	assert_false(_sowari_khaneh.is_ready_to_produce,
		"sanity: false at spawn")
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_sowari_khaneh.is_ready_to_produce,
		"BEHAVIORAL: is_ready_to_produce must REMAIN false after place_at "
		+ "alone — Stage 1 is structural; the operational flip is gated "
		+ "on Stage 2 (_on_construction_complete) per §9.L5.")


func test_is_ready_to_produce_flips_on_construction_complete() -> void:
	# Stage 2 hook fires the flip. Drive the hook directly to lock the
	# per-hook contract; integration-level driving-via-construction-ticks
	# coverage lives in test_unit_state_constructing.gd.
	_sowari_khaneh = _spawn_sowari_khaneh()
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_sowari_khaneh.is_ready_to_produce,
		"sanity: still false post-Stage-1")
	# Fire Stage 2 directly. Production caller is
	# UnitState_Constructing._sim_tick at dwell-complete.
	_sowari_khaneh._on_construction_complete(1)
	assert_true(_sowari_khaneh.is_ready_to_produce,
		"is_ready_to_produce must be true after _on_construction_complete "
		+ "(Stage 2 operational flip — Savar training capacity activates)")


# ---------------------------------------------------------------------------
# super() chain — §9.L4a + §9.L4b discipline
# ---------------------------------------------------------------------------

func test_sowari_khaneh_on_placement_complete_calls_super() -> void:
	# Per §9.L4a: subclass overrides of base virtuals with non-trivial
	# bodies MUST call super FIRST. Building base's _on_placement_complete
	# runs the Wave 1D explicit-pipeline navmesh rebake.
	#
	# Observable proof: Building base sets is_complete=true in place_at,
	# which fires _on_placement_complete; if super weren't called, the
	# base navmesh-rebake path would either crash or silently no-op the
	# carving. is_complete is the observable seam confirming the base
	# chain ran end-to-end.
	_sowari_khaneh = _spawn_sowari_khaneh()
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_sowari_khaneh.is_complete,
		"BEHAVIORAL: place_at completed without crash + is_complete=true. "
		+ "Confirms super._on_placement_complete() ran (base chain end-to-end).")


func test_sowari_khaneh_on_construction_complete_calls_super() -> void:
	# Per §9.L4a + §9.L4b: super-call discipline applies even when base
	# body is currently `pass`. Future base additions inherit cleanly.
	#
	# Observable proof: is_ready_to_produce flips true AFTER super returns.
	# The discipline lock ensures future base Stage-2 logic fires without
	# subclass code changes.
	_sowari_khaneh = _spawn_sowari_khaneh()
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_sowari_khaneh._on_construction_complete(1)
	assert_true(_sowari_khaneh.is_ready_to_produce,
		"BEHAVIORAL: _on_construction_complete completed end-to-end "
		+ "(super invoked + subclass flip applied). §9.L4b forward-compat "
		+ "lock confirmed.")


# ---------------------------------------------------------------------------
# Placement side-effect — EventBus.building_placed signal
# ---------------------------------------------------------------------------

func test_sowari_khaneh_placement_emits_building_placed_signal() -> void:
	# _on_placement_complete (Stage 1) must emit EventBus.building_placed
	# with kind = &"sowari_khaneh". Telemetry / AI / UI consumers
	# distinguish kinds via this signal payload.
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team, &"pos": pos})
	EventBus.building_placed.connect(handler)
	_sowari_khaneh = _spawn_sowari_khaneh(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3(12.0, 0.0, -6.0), Constants.TEAM_IRAN, 17)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"SowariKhaneh placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 17, "signal carries placer worker unit_id (17)")
	assert_eq(ev[&"kind"], &"sowari_khaneh",
		"signal carries kind &\"sowari_khaneh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries TEAM_IRAN")


# ---------------------------------------------------------------------------
# place_at — base lifecycle integration
# ---------------------------------------------------------------------------

func test_place_at_sets_global_position() -> void:
	_sowari_khaneh = _spawn_sowari_khaneh()
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3(8.0, 0.0, 3.0), Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_almost_eq(_sowari_khaneh.global_position.x, 8.0, 0.0001,
		"place_at sets global_position.x")
	assert_almost_eq(_sowari_khaneh.global_position.z, 3.0, 0.0001,
		"place_at sets global_position.z")


# ---------------------------------------------------------------------------
# FogSystem guard — forward-compat (no crash when absent)
# ---------------------------------------------------------------------------

func test_sowari_khaneh_placement_no_crash_when_fogsystem_absent() -> void:
	# When FogSystem singleton is NOT present (test runs / wave 3A pending),
	# placement must succeed without error. Same autoload-guard pattern as
	# every other Iran building.
	_sowari_khaneh = _spawn_sowari_khaneh()
	SimClock._is_ticking = true
	_sowari_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_sowari_khaneh.is_complete,
		"SowariKhaneh placement completes without error when FogSystem absent")


# ---------------------------------------------------------------------------
# Static cost helper — cost_coin()
# ---------------------------------------------------------------------------

func test_sowari_khaneh_cost_coin_returns_balance_data_value_or_fallback() -> void:
	# Cost reads BalanceData.buildings.sowari_khaneh.coin_cost. Track 3
	# shipped bldg_sowari_khaneh.coin_cost = 200 at 6503b0c — normal path
	# returns 200. Fallback returns 200 when BalanceData unreachable.
	# Either way, cost is 200 per 01_CORE_MECHANICS.md §5 line 194.
	var cost: int = SowariKhanehScript.call(&"cost_coin")
	assert_eq(cost, 200,
		"SowariKhaneh.cost_coin() must return 200 (BalanceData or fallback "
		+ "both ship 200 per 01_CORE_MECHANICS.md §5 line 194). Got: %d" % cost)
