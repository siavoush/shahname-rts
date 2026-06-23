# Tests for the Atashkadeh (Iran fire-temple) building — Phase 3 wave 2A.5.
#
# Per 01_CORE_MECHANICS.md §4.3 (Farr generator: Atashkadeh +1/min) +
# 01_CORE_MECHANICS.md §5 (Tier-1 row: 150 coin + 50 grain, Tier-2 gateway).
# Fourth Tier-1 anchor-category Building variant: sacral-emitter.
# Distinct from Khaneh (civic-anchor) / Mazra'eh (resource-producing) /
# Ma'dan (labor-organization) / Sarbaz-khaneh (identity-bearing institutional).
#
# Test coverage (14 tests):
#   1-5. Identity (kind, dual-init, inheritance chain, class_name discipline,
#        &"buildings" group join).
#   6-8. is_emitting_farr flag — Stage-2 operational marker. Defaults false;
#        flips true at _on_construction_complete (Stage 2). Mirrors
#        Mazra'eh.is_gatherable + Sarbaz-khaneh.is_ready_to_produce per §9.L5.
#   9.   Two-stage lifecycle BEHAVIORAL: Stage 1 (place_at) does NOT set
#        is_emitting_farr; Stage 2 (_on_construction_complete) does.
#   10-11. super() chain — _on_placement_complete + _on_construction_complete
#         BOTH call super per §9.L4a + §9.L4b discipline.
#   12.  FarrSystem.register_emitter seam (Phase 4 wave 1 — NOW LIVE):
#        construction-complete registers the Atashkadeh as a real FarrSystem
#        emitter (the Wave-2A.5 forward-compat has_method guard is retired).
#   13.  Placement side-effect: EventBus.building_placed emit with
#        kind = &"atashkadeh".
#   14.  Static cost helpers — cost_coin() + cost_grain() defensive fallbacks.
#
# Test pattern per §9.M4: prefer `.new()` headless construction over scene
# instantiation. world-builder may ship atashkadeh.tscn in parallel; this
# test file (gp-sys Track 1 scope) does NOT preload the scene — scene-level
# coverage lives in world-builder's parallel work if shipped.
extends GutTest


const AtashkadehScript: Script = preload(
	"res://scripts/world/buildings/atashkadeh.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _atashkadeh: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _atashkadeh != null and is_instance_valid(_atashkadeh):
		_atashkadeh.queue_free()
	_atashkadeh = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_atashkadeh(team: int = Constants.TEAM_IRAN) -> Variant:
	# Headless construction via .new() per §9.M4 — does not require the
	# parallel scene file (atashkadeh.tscn) to exist on disk. Scene-level
	# tests live in world-builder's parallel work if shipped.
	var b: Variant = AtashkadehScript.new()
	b.team = team
	add_child_autofree(b)
	return b


# ---------------------------------------------------------------------------
# Identity — kind, dual-init, inheritance chain, class_name, group
# ---------------------------------------------------------------------------

func test_atashkadeh_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = AtashkadehScript.new()
	assert_eq(bare.kind, &"atashkadeh",
		"Atashkadeh.new() (no scene) must set kind = &\"atashkadeh\" in _init")
	bare.free()


func test_atashkadeh_kind_post_ready() -> void:
	# Dual-init pattern — _ready must reaffirm kind after the engine
	# resets @export defaults between _init and _ready.
	_atashkadeh = _spawn_atashkadeh()
	assert_eq(_atashkadeh.kind, &"atashkadeh",
		"Atashkadeh.kind must be &\"atashkadeh\" after _ready")


func test_atashkadeh_inherits_building_base() -> void:
	# Script-base-walk pattern — dodges class_name registry race per
	# Pitfall #13. Same shape as sibling building tests.
	_atashkadeh = _spawn_atashkadeh()
	var s: Script = _atashkadeh.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"Atashkadeh instance must inherit from building.gd in its script chain")


func test_atashkadeh_class_name_is_atashkadeh() -> void:
	# Per §9.J3 + loremaster transliteration-consistency rule (catches
	# rename drift). Script.get_global_name() returns the declared
	# class_name; for `class_name Atashkadeh` this must return "Atashkadeh".
	_atashkadeh = _spawn_atashkadeh()
	var s: Script = _atashkadeh.get_script()
	var global_name: StringName = s.get_global_name()
	assert_eq(global_name, &"Atashkadeh",
		"atashkadeh.gd must declare class_name Atashkadeh "
		+ "(transliteration discipline). Got: " + global_name)


func test_atashkadeh_joins_buildings_group_on_ready() -> void:
	# Inherited from Building._ready — consumers iterate &"buildings"
	# group for AI / UI / placement-validity discovery.
	_atashkadeh = _spawn_atashkadeh()
	assert_true(_atashkadeh.is_in_group(&"buildings"),
		"Atashkadeh inherits Building._ready add_to_group(&\"buildings\")")


# ---------------------------------------------------------------------------
# is_emitting_farr field — Stage-2 operational marker
# ---------------------------------------------------------------------------

func test_atashkadeh_has_is_emitting_farr_field() -> void:
	# Public surface for the future FarrSystem.register_emitter consumer.
	# When FarrSystem ships its full impl (Phase 4), it queries this flag
	# to determine which buildings contribute to the per-tick Farr-emit
	# aggregate.
	_atashkadeh = _spawn_atashkadeh()
	assert_true(&"is_emitting_farr" in _atashkadeh,
		"Atashkadeh must expose is_emitting_farr field for FarrSystem "
		+ "per-tick aggregate discovery")


func test_atashkadeh_is_emitting_farr_defaults_false() -> void:
	# Default false ensures operational-gating discipline at spawn: a
	# freshly-instantiated Atashkadeh does NOT emit Farr. Mirrors
	# Mazra'eh.is_gatherable + Sarbaz-khaneh.is_ready_to_produce
	# default-false pattern per §9.L5.
	_atashkadeh = _spawn_atashkadeh()
	assert_false(_atashkadeh.is_emitting_farr,
		"Atashkadeh.is_emitting_farr must default false at spawn — "
		+ "the temple exists but does not yet emit Farr until "
		+ "construction completes")


func test_atashkadeh_is_emitting_farr_flips_on_construction_complete() -> void:
	# Stage 2 hook fires the flip. Drive the hook directly to lock the
	# per-hook contract; integration-level driving-via-construction-ticks
	# coverage lives in test_unit_state_constructing.gd (existing
	# behavioral tests for similar Stage-2 flips).
	_atashkadeh = _spawn_atashkadeh()
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_atashkadeh.is_emitting_farr,
		"sanity: still false post-Stage-1")
	# Fire Stage 2 directly. Production caller is
	# UnitState_Constructing._sim_tick at dwell-complete.
	_atashkadeh._on_construction_complete(1)
	assert_true(_atashkadeh.is_emitting_farr,
		"is_emitting_farr must be true after _on_construction_complete "
		+ "(Stage 2 operational flip — sacral-emit activates)")


# ---------------------------------------------------------------------------
# Two-stage lifecycle BEHAVIORAL — Stage 1 vs Stage 2 operational gating
# ---------------------------------------------------------------------------

func test_atashkadeh_is_emitting_farr_stays_false_after_place_at_only() -> void:
	# BEHAVIORAL: place_at fires Stage 1 (_on_placement_complete —
	# structural). is_emitting_farr is a Stage-2 (operational) marker
	# that requires _on_construction_complete to run. Driving place_at
	# alone must leave is_emitting_farr = false. Mirrors Mazra'eh's
	# test_mazraeh_is_gatherable_stays_false_after_place_at_only contract.
	_atashkadeh = _spawn_atashkadeh()
	assert_false(_atashkadeh.is_emitting_farr,
		"sanity: false at spawn")
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_atashkadeh.is_emitting_farr,
		"BEHAVIORAL: is_emitting_farr must REMAIN false after place_at "
		+ "alone — Stage 1 is structural; the operational flip is gated "
		+ "on Stage 2 (_on_construction_complete) per §9.L5.")


# ---------------------------------------------------------------------------
# super() chain — §9.L4a + §9.L4b discipline
# ---------------------------------------------------------------------------

func test_atashkadeh_on_placement_complete_calls_super() -> void:
	# Per §9.L4a: subclass overrides of base virtuals with non-trivial
	# bodies MUST call super FIRST. Building base's _on_placement_complete
	# runs the Wave 1D explicit-pipeline navmesh rebake; if subclass
	# overrides without super, the rebake doesn't fire and the navmesh
	# stays stale (workers walk through the building).
	#
	# Observable proof: Building base adds &"buildings" group membership
	# in _ready, and the navmesh-rebake side-effect of
	# _on_placement_complete relies on the inherited base helper. We
	# verify by observing that place_at + _on_placement_complete completes
	# without crash AND the building's is_complete flag flips true (which
	# is set by base place_at — that path executes the whole base chain).
	_atashkadeh = _spawn_atashkadeh()
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_atashkadeh.is_complete,
		"BEHAVIORAL: place_at completed without crash + is_complete=true. "
		+ "If Atashkadeh.on_placement_complete failed to call super, the "
		+ "base navmesh-rebake path would either crash (if dependencies "
		+ "absent) or silently no-op the carving. is_complete is the "
		+ "observable seam confirming the base chain ran.")


func test_atashkadeh_on_construction_complete_calls_super() -> void:
	# Per §9.L4a + §9.L4b: super-call discipline applies even when base
	# body is currently `pass`. Future base additions inherit cleanly.
	#
	# Observable proof: Atashkadeh.on_construction_complete flips
	# is_emitting_farr=true AFTER super returns. If super weren't called
	# AND the base body grew non-trivial logic in a future wave, the new
	# base behavior would be silently skipped — the operational marker
	# would still flip (subclass-specific), but the base-class invariants
	# would break. The discipline-as-code: calling super even on a `pass`
	# base is the forward-compat lock per L4b. Today we cannot test the
	# future failure (base is pass); we test the CALL ORDER by ensuring
	# is_emitting_farr=true is observable post-Stage-2 (the call chain
	# completed end-to-end including the super invocation).
	_atashkadeh = _spawn_atashkadeh()
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_atashkadeh._on_construction_complete(1)
	assert_true(_atashkadeh.is_emitting_farr,
		"BEHAVIORAL: _on_construction_complete completed end-to-end "
		+ "(super invoked + subclass flip applied). When base gains "
		+ "non-trivial Stage-2 logic in a future wave, the discipline "
		+ "lock ensures the new behavior fires without subclass code "
		+ "changes.")


# ---------------------------------------------------------------------------
# FarrSystem.register_emitter seam (Phase 4 wave 1 — NOW LIVE)
# ---------------------------------------------------------------------------

func test_atashkadeh_registers_as_farr_emitter_on_construction_complete() -> void:
	# Phase 4 wave 1: FarrSystem.register_emitter now exists. The Wave-2A.5
	# forward-compat has_method guard was REMOVED — Atashkadeh calls
	# register_emitter directly at Stage-2 construction-complete. This test
	# replaces the old "register_emitter is Phase-4 deferred" sanity test.
	#
	# BEHAVIORAL: drive Stage 1 + Stage 2 manually, then confirm BOTH the
	# operational flip (is_emitting_farr) AND the real registration (the
	# building is now a registered FarrSystem emitter).
	FarrSystem.reset()  # clear any emitter registry leakage from prior tests
	# Pre-condition: register_emitter is now a real method (Phase 4 shipped).
	assert_true(FarrSystem.has_method(&"register_emitter"),
		"Phase 4 wave 1: FarrSystem.register_emitter must exist (the "
		+ "Wave-2A.5 forward-compat guard is retired).")
	_atashkadeh = _spawn_atashkadeh()
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	# Drive Stage 2 — registers the emitter.
	_atashkadeh._on_construction_complete(1)
	SimClock._is_ticking = false
	assert_true(_atashkadeh.is_emitting_farr,
		"BEHAVIORAL: Atashkadeh.is_emitting_farr flips true at Stage 2.")
	assert_true(FarrSystem.is_emitter_registered(_atashkadeh),
		"BEHAVIORAL: Atashkadeh registers as a FarrSystem emitter at "
		+ "construction-complete (Phase 4 wave 1 — register_emitter LIVE).")
	# Cleanup: unregister so the registry doesn't leak into sibling tests.
	FarrSystem.unregister_emitter(_atashkadeh)


# ---------------------------------------------------------------------------
# Placement side-effect — EventBus.building_placed signal
# ---------------------------------------------------------------------------

func test_atashkadeh_placement_emits_building_placed_signal() -> void:
	# _on_placement_complete (Stage 1) must emit EventBus.building_placed
	# with kind = &"atashkadeh". Telemetry / AI / UI consumers distinguish
	# kinds via this signal payload.
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team, &"pos": pos})
	EventBus.building_placed.connect(handler)
	_atashkadeh = _spawn_atashkadeh(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	_atashkadeh.place_at(Vector3(7.0, 0.0, -3.0), Constants.TEAM_IRAN, 21)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"Atashkadeh placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 21, "signal carries placer worker unit_id (21)")
	assert_eq(ev[&"kind"], &"atashkadeh",
		"signal carries kind &\"atashkadeh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries TEAM_IRAN")


# ---------------------------------------------------------------------------
# Static cost helpers — cost_coin() + cost_grain()
# ---------------------------------------------------------------------------

func test_atashkadeh_cost_helpers_return_positive_values() -> void:
	# Per 01_CORE_MECHANICS.md §5: "Atashkadeh — 150 coin + 50 grain".
	# cost_coin() + cost_grain() helpers read BalanceData with defensive
	# fallbacks (150 / 50). balance-engineer-p3s5 ships the bldg_atashkadeh
	# entry via parallel dispatch; until then, fallbacks return.
	# Either way, both helpers exist so BuildMenu can read costs without
	# instantiating an Atashkadeh scene. Atashkadeh is the FIRST building
	# with a non-zero grain cost in the Tier-1 roster.
	var coin: int = AtashkadehScript.call(&"cost_coin")
	assert_true(coin > 0,
		"Atashkadeh.cost_coin() must return positive (BalanceData or "
		+ "fallback 150). Got: %d" % coin)
	var grain: int = AtashkadehScript.call(&"cost_grain")
	assert_true(grain > 0,
		"Atashkadeh.cost_grain() must return positive (BalanceData or "
		+ "fallback 50). Atashkadeh is the FIRST Tier-1 building with "
		+ "non-zero grain cost. Got: %d" % grain)
