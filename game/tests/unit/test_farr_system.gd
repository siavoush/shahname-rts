# Tests for FarrSystem autoload.
#
# Contract:
#   - 01_CORE_MECHANICS.md §4 — Farr full spec (range 0-100, starts 50,
#     generators, drains, snowball protection)
#   - docs/SIMULATION_CONTRACT.md §1.6 — fixed-point integer arithmetic
#     (farr_x100: int; 50.0 Farr = 5000 stored). Float conversion only at
#     HUD/telemetry boundaries.
#   - CLAUDE.md — apply_farr_change(amount, reason, source_unit) is the
#     non-negotiable chokepoint; every Farr change is logged and emits
#     EventBus.farr_changed.
#
# Phase 0 session 4 wave 1 scope: chokepoint + storage + clamp + assertion.
# Generators (Atashkadeh +1/min, etc.) and drains (worker killed -1, etc.)
# are Phase 4 work — not exercised here.
#
# On-tick assertion: per docs/SIMULATION_CONTRACT.md §1.3, the assert is
# "enforcement-via-crash-in-debug, not enforcement-via-test." GUT cannot
# trap a fired assert in-process. We verify the prerequisite (is_ticking
# is false outside a tick) instead — same pattern as test_sim_node.gd.
extends GutTest


# -- Signal capture helpers ---------------------------------------------------

var _farr_events: Array = []


func _on_farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int) -> void:
	_farr_events.append({
		"amount": amount,
		"reason": reason,
		"source_unit_id": source_unit_id,
		"farr_after": farr_after,
		"tick": tick,
	})


# Helper: run a Callable inside a single sim tick so apply_farr_change's
# on-tick assert is satisfied. Mirrors the pattern in test_sim_node.gd.
# We hook the &"farr" phase since that is FarrSystem's natural home in
# the canonical pipeline (per docs/SIMULATION_CONTRACT.md §2 phase 6).
func _run_inside_tick(body: Callable) -> void:
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			body.call()
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)


func before_each() -> void:
	_farr_events = []
	SimClock.reset()
	# Phase 4 wave 1: clear the emitter registry + accrual accumulator + re-arm
	# the upkeep cadence so D2/D3 tests start from a pristine FarrSystem. reset()
	# emits a synthetic farr_changed, but we connect _on_farr_changed AFTER it,
	# so the reset emit isn't captured. reset() also re-sets _farr_x100 to the
	# BalanceData starting value (5000), so the manual restore below is belt-and-
	# braces (kept so the test reads clearly).
	FarrSystem.reset()
	# Restore default starting value (5000 = 50.0).
	_run_inside_tick(func() -> void:
		var current_x100: int = FarrSystem._farr_x100
		var delta_to_default: int = 5000 - current_x100
		if delta_to_default != 0:
			# Bypass apply_farr_change to avoid emitting a fake before_each
			# event. Direct write is safe here because we are on-tick (this
			# closure runs inside _run_inside_tick).
			FarrSystem._set_sim(&"_farr_x100", 5000)
	)
	EventBus.farr_changed.connect(_on_farr_changed)
	_farr_events = []   # discard any signal captured during the reset closure


func after_each() -> void:
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)
	# Clear any emitter registry leakage so the next test (and other suites)
	# don't see a lingering emitter accruing Farr.
	FarrSystem.reset()
	SimClock.reset()


# -- Default value -----------------------------------------------------------

func test_value_farr_defaults_to_fifty() -> void:
	# Per 01_CORE_MECHANICS.md §4.1: starting Farr is 50 (neutral).
	# Per Sim Contract §1.6: 50.0 == 5000 in fixed-point.
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-6,
		"Default Farr is 50.0 per §4.1 of 01_CORE_MECHANICS.md")


func test_internal_storage_is_fixed_point_int() -> void:
	# Per Sim Contract §1.6: backing store is integer (Farr × 100).
	# 50.0 Farr = 5000 stored.
	assert_eq(typeof(FarrSystem._farr_x100), TYPE_INT,
		"Internal storage must be integer (Sim Contract §1.6)")
	assert_eq(FarrSystem._farr_x100, 5000,
		"50.0 Farr is stored as 5000 (× 100)")


# -- apply_farr_change happy path -------------------------------------------

func test_positive_delta_raises_value() -> void:
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(5.0, "test_positive", null)
	)
	assert_almost_eq(FarrSystem.value_farr, 55.0, 1e-6,
		"+5 from 50 → 55")


func test_negative_delta_lowers_value() -> void:
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(-10.0, "test_negative", null)
	)
	assert_almost_eq(FarrSystem.value_farr, 40.0, 1e-6,
		"-10 from 50 → 40")


# -- Fixed-point fidelity (the §1.6 motivation) -----------------------------

func test_small_fractional_delta_is_exact() -> void:
	# IEEE-754 floats can drift on repeated additions of 0.05 across
	# platforms; with fixed-point the result is exact.
	# 0.05 → roundi(0.05 * 100) = 5 added to _farr_x100.
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(0.05, "test_fractional", null)
	)
	assert_eq(FarrSystem._farr_x100, 5005,
		"0.05 delta adds exactly 5 to _farr_x100 (no float drift)")
	assert_almost_eq(FarrSystem.value_farr, 50.05, 1e-9,
		"0.05 delta yields 50.05 with no IEEE-754 drift")


func test_repeated_fractional_deltas_do_not_drift() -> void:
	# Add 0.1 ten times. With float math this would land at 50.99999...
	# With fixed-point it lands at exactly 51.0.
	_run_inside_tick(func() -> void:
		for i in range(10):
			FarrSystem.apply_farr_change(0.1, "test_drift", null)
	)
	assert_eq(FarrSystem._farr_x100, 5100,
		"10 × 0.1 deltas land exactly at 5100 (51.0)")
	assert_almost_eq(FarrSystem.value_farr, 51.0, 1e-9)


# -- Clamping to [0, 100] ---------------------------------------------------

func test_positive_delta_saturates_at_one_hundred() -> void:
	# Per §4.1: range is [0, 100]. Overflow is clamped, not wrapped.
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(200.0, "test_clamp_high", null)
	)
	assert_almost_eq(FarrSystem.value_farr, 100.0, 1e-6,
		"+200 saturates at 100.0")
	assert_eq(FarrSystem._farr_x100, 10000,
		"Clamp ceiling is 10000 in fixed-point")


func test_negative_delta_saturates_at_zero() -> void:
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(-200.0, "test_clamp_low", null)
	)
	assert_almost_eq(FarrSystem.value_farr, 0.0, 1e-6,
		"-200 saturates at 0.0")
	assert_eq(FarrSystem._farr_x100, 0,
		"Clamp floor is 0 in fixed-point")


# -- EventBus.farr_changed emission -----------------------------------------

func test_farr_changed_signal_fires_with_correct_args() -> void:
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(3.0, "hero_rescue", null)
	)
	assert_eq(_farr_events.size(), 1, "Exactly one farr_changed emit")
	var ev: Dictionary = _farr_events[0]
	assert_almost_eq(ev["amount"], 3.0, 1e-6, "amount carries delta")
	assert_eq(ev["reason"], "hero_rescue", "reason carries pass-through string")
	assert_eq(ev["source_unit_id"], -1,
		"source_unit_id is -1 sentinel when source_unit is null")
	assert_almost_eq(ev["farr_after"], 53.0, 1e-6,
		"farr_after reflects post-clamp value")
	assert_eq(ev["tick"], SimClock.tick - 1,
		"tick carries SimClock.tick at apply time (tick incremented after _run_tick)")


func test_farr_changed_emits_clamped_amount_when_saturating() -> void:
	# When the requested delta would exceed the clamp, the signal must report
	# the *effective* delta (what actually moved), not the requested one — so
	# downstream consumers see a coherent ledger of movement.
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(200.0, "test_clamp_signal", null)
	)
	assert_eq(_farr_events.size(), 1)
	var ev: Dictionary = _farr_events[0]
	# Started at 50, clamped to 100 — effective delta is +50.
	assert_almost_eq(ev["amount"], 50.0, 1e-6,
		"Emitted amount reflects post-clamp effective delta")
	assert_almost_eq(ev["farr_after"], 100.0, 1e-6)


# -- Multiple changes accumulate correctly -----------------------------------

func test_consecutive_changes_accumulate() -> void:
	_run_inside_tick(func() -> void:
		FarrSystem.apply_farr_change(5.0, "a", null)
		FarrSystem.apply_farr_change(-2.0, "b", null)
		FarrSystem.apply_farr_change(0.5, "c", null)
	)
	# 50 + 5 - 2 + 0.5 = 53.5
	assert_almost_eq(FarrSystem.value_farr, 53.5, 1e-6)
	assert_eq(_farr_events.size(), 3, "Three apply calls = three emits")


# -- Off-tick mutation precondition (per Sim Contract §1.3 enforcement model)
#
# The on-tick assertion in apply_farr_change is enforcement-via-crash-in-debug
# (compiles out in release; GUT cannot trap an asserting thread). We can still
# verify the prerequisite — that SimClock.is_ticking() is false outside a
# tick — exactly the pattern test_sim_node.gd uses for its same constraint.

func test_is_ticking_is_false_outside_tick_window() -> void:
	assert_false(SimClock.is_ticking(),
		"Outside any tick, is_ticking must be false — the precondition the "
		+ "apply_farr_change assert fires on")


# ===========================================================================
# D2 — Building-emitter registry (register_emitter / unregister_emitter)
# ===========================================================================
#
# Contract: 01_CORE_MECHANICS.md §4.3 generators. register_emitter(building,
# farr_per_min); per-tick fixed-point accrual on the &"farr" phase; flush
# whole-x100 increments via apply_farr_change (Sim Contract §1.6 — no drift).

# Minimal emitter fake — a Node with a unit_id (so the Atashkadeh-loss
# unregister-by-unit_id path can match) + kind.
class FakeEmitter extends Node:
	var unit_id: int = -1
	var kind: StringName = &"atashkadeh"


func _make_emitter(uid: int) -> FakeEmitter:
	var e: FakeEmitter = FakeEmitter.new()
	e.unit_id = uid
	add_child_autofree(e)
	return e


# Drive N &"farr" sim phases (the per-tick accrual seam). Mirrors the live
# pipeline — emits sim_phase(&"farr", tick) so FarrSystem._on_sim_phase fires.
func _advance_farr_phases(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# Reset the clock to tick 0 + re-arm the upkeep cadence so timing-sensitive
# tests have a deterministic baseline. before_each's _run_inside_tick advances
# the clock by 1 tick; the upkeep cadence (first fire at tick == interval)
# needs tick 0 as the reference. After this, _advance_farr_phases(N) runs ticks
# 0..N-1, and upkeep fires on the tick where tick == 1800 (so N=1801 includes
# the fire; N=1800 stops at tick 1799 — no fire).
func _reset_clock_for_timing() -> void:
	SimClock.reset()          # tick → 0
	FarrSystem.reset()        # clears emitters + re-arms _next_upkeep_tick = 1800


func test_register_emitter_lifecycle() -> void:
	var e: FakeEmitter = _make_emitter(701)
	assert_false(FarrSystem.is_emitter_registered(e),
		"emitter not registered before register_emitter")
	FarrSystem.register_emitter(e, 1.0)
	assert_true(FarrSystem.is_emitter_registered(e),
		"register_emitter makes the building a registered emitter")
	assert_eq(FarrSystem.emitter_count(), 1, "exactly one emitter registered")
	FarrSystem.unregister_emitter(e)
	assert_false(FarrSystem.is_emitter_registered(e),
		"unregister_emitter removes the building")
	assert_eq(FarrSystem.emitter_count(), 0, "registry empty after unregister")


func test_register_emitter_idempotent() -> void:
	var e: FakeEmitter = _make_emitter(702)
	FarrSystem.register_emitter(e, 1.0)
	FarrSystem.register_emitter(e, 1.0)  # re-register (rate update) — no dup
	assert_eq(FarrSystem.emitter_count(), 1,
		"re-registering the same building does not duplicate")
	FarrSystem.unregister_emitter(e)


func test_unregister_unknown_emitter_is_noop() -> void:
	var e: FakeEmitter = _make_emitter(703)
	# Never registered — unregister is a safe no-op (logged).
	FarrSystem.unregister_emitter(e)
	assert_eq(FarrSystem.emitter_count(), 0, "unregister of unknown is a no-op")


func test_emitter_accrual_yields_exact_increment_over_one_game_minute() -> void:
	# A single +1/min emitter (Atashkadeh) over exactly 1 game-minute (1800
	# ticks) accrues exactly +1.00 Farr (50.0 → 51.0). Fixed-point, no drift.
	# NB: 1800 ticks would ALSO trigger one upkeep fire (coin, not Farr) — that
	# doesn't touch _farr_x100, so the Farr assertion is unaffected.
	_reset_clock_for_timing()
	var e: FakeEmitter = _make_emitter(704)
	# register_emitter is a plain registry write (off-tick safe).
	FarrSystem.register_emitter(e, 1.0)
	_advance_farr_phases(1800)
	assert_eq(FarrSystem._farr_x100, 5100,
		"1800 farr-phases of a +1/min emitter = exactly +1.00 Farr (5100 x100)")
	assert_almost_eq(FarrSystem.value_farr, 51.0, 1e-9)
	FarrSystem.unregister_emitter(e)


func test_emitter_accrual_no_drift_partial_minute() -> void:
	# Over HALF a game-minute (900 ticks) a +1/min emitter accrues exactly +0.50
	# Farr (numerator 900*100 = 90000; 90000/1800 = 50 whole x100-Farr units).
	# Verifies per-tick fixed-point accumulation, not per-minute rounding.
	_reset_clock_for_timing()
	var e: FakeEmitter = _make_emitter(705)
	FarrSystem.register_emitter(e, 1.0)
	_advance_farr_phases(900)
	assert_eq(FarrSystem._farr_x100, 5050,
		"900 farr-phases of +1/min = exactly +0.50 Farr (5050 x100), no drift")
	FarrSystem.unregister_emitter(e)


func test_emitter_accrual_zero_when_no_emitters() -> void:
	# No emitters → no accrual. Farr stays put over many phases.
	_reset_clock_for_timing()
	_advance_farr_phases(900)
	assert_eq(FarrSystem._farr_x100, 5000,
		"no emitters → Farr unchanged across phases")


func test_two_emitters_accrue_aggregate_rate() -> void:
	# Two +1/min emitters = +2/min aggregate; over 900 ticks → +1.00 Farr.
	_reset_clock_for_timing()
	var e1: FakeEmitter = _make_emitter(706)
	var e2: FakeEmitter = _make_emitter(707)
	FarrSystem.register_emitter(e1, 1.0)
	FarrSystem.register_emitter(e2, 1.0)
	_advance_farr_phases(900)
	assert_eq(FarrSystem._farr_x100, 5100,
		"two +1/min emitters over 900 ticks = +1.00 Farr (aggregate +2/min)")
	FarrSystem.unregister_emitter(e1)
	FarrSystem.unregister_emitter(e2)


# ===========================================================================
# D2 — Atashkadeh-loss drain (building_destroyed channel)
# ===========================================================================

func test_atashkadeh_loss_drains_five_farr() -> void:
	# building_destroyed with kind=&"atashkadeh" fires the -5 Farr drain
	# (drain_rates[&"building_destroyed_atashkadeh"] = 5.0). Emit on-tick so
	# apply_farr_change's assert holds.
	_run_inside_tick(func() -> void:
		EventBus.building_destroyed.emit(
			Constants.TEAM_IRAN, Constants.BUILDING_KIND_ATASHKADEH, 9001)
	)
	assert_almost_eq(FarrSystem.value_farr, 45.0, 1e-4,
		"Atashkadeh loss drains -5 Farr (50.0 → 45.0) — the sacred flame is extinguished")


func test_non_atashkadeh_destruction_does_not_drain() -> void:
	# A non-Atashkadeh building destruction does NOT drain Farr this wave
	# (civilian/military building-loss keys are forward-compat, not wired).
	_run_inside_tick(func() -> void:
		EventBus.building_destroyed.emit(Constants.TEAM_IRAN, &"khaneh", 9002)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"non-Atashkadeh building destruction does not drain Farr this wave")


func test_atashkadeh_destruction_unregisters_emitter() -> void:
	# Destroying an Atashkadeh that was a registered emitter must unregister it
	# (a destroyed building can't keep its flame). The unregister matches by the
	# building's unit_id (the signal carries unit_id, not the Node).
	var e: FakeEmitter = _make_emitter(9003)
	FarrSystem.register_emitter(e, 1.0)
	assert_eq(FarrSystem.emitter_count(), 1)
	_run_inside_tick(func() -> void:
		EventBus.building_destroyed.emit(
			Constants.TEAM_IRAN, Constants.BUILDING_KIND_ATASHKADEH, 9003)
	)
	assert_eq(FarrSystem.emitter_count(), 0,
		"destroying the Atashkadeh unregisters it as an emitter (by unit_id)")


# ===========================================================================
# D3 — Royal-largesse Coin upkeep
# ===========================================================================
#
# Contract: DECISIONS.md 2026-06-22 §1.2. 8 coin/military-unit/game-minute,
# first drain at tick 1800. Drains TREASURY via ResourceSystem (NOT Farr).

# Military-unit fake in the &"units" group (so the upkeep enumeration finds it).
class FakeMilUnit extends Node:
	var unit_id: int = -1
	var unit_type: StringName = &""
	var team: int = 0
	var _dying: bool = false
	func is_dying() -> bool:
		return _dying


func _make_mil_unit(uid: int, ut: StringName, t: int, dying: bool = false) -> FakeMilUnit:
	var u: FakeMilUnit = FakeMilUnit.new()
	u.unit_id = uid
	u.unit_type = ut
	u.team = t
	u._dying = dying
	add_child_autofree(u)
	u.add_to_group(&"units")
	return u


func test_upkeep_drains_coin_per_military_unit_at_one_minute() -> void:
	# 2 Iran military units → 8*2 = 16 coin drained at tick 1800. _advance_farr_
	# phases(1801) runs ticks 0..1800, so the tick==1800 fire is included.
	_reset_clock_for_timing()
	ResourceSystem.reset()
	_make_mil_unit(801, &"piyade", Constants.TEAM_IRAN)
	_make_mil_unit(802, &"piyade", Constants.TEAM_IRAN)
	var start_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_advance_farr_phases(1801)
	var end_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(start_coin - end_coin, 16 * 100,
		"upkeep drains 8 coin/military-unit × 2 units = 16 coin at the 1-min mark")


func test_upkeep_does_not_fire_before_one_minute() -> void:
	# _advance_farr_phases(1800) runs ticks 0..1799 — stops one short of the
	# tick==1800 fire. No upkeep drain yet.
	_reset_clock_for_timing()
	ResourceSystem.reset()
	_make_mil_unit(811, &"piyade", Constants.TEAM_IRAN)
	var start_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_advance_farr_phases(1800)
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), start_coin,
		"no upkeep drain before tick 1800 (first fire at t=60s, not turn-1)")


func test_upkeep_zero_military_zero_drain() -> void:
	_reset_clock_for_timing()
	ResourceSystem.reset()
	# A worker (Kargar) does NOT count toward upkeep — upkeep is a standing-army
	# cost. Only a worker present → zero drain.
	_make_mil_unit(821, &"kargar", Constants.TEAM_IRAN)
	var start_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_advance_farr_phases(1801)
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), start_coin,
		"zero military units (only a worker) → zero upkeep drain")


func test_upkeep_excludes_dying_military() -> void:
	_reset_clock_for_timing()
	ResourceSystem.reset()
	# One living + one dying military unit → only the living one is charged.
	_make_mil_unit(831, &"piyade", Constants.TEAM_IRAN)            # living
	_make_mil_unit(832, &"piyade", Constants.TEAM_IRAN, true)      # dying
	var start_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_advance_farr_phases(1801)
	var drained: int = start_coin - ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(drained, 8 * 100,
		"upkeep charges only LIVING military (1×8 coin); the dying unit is excluded")


func test_upkeep_per_team_independent() -> void:
	_reset_clock_for_timing()
	ResourceSystem.reset()
	# 1 Iran military, 3 Turan military → Iran -8, Turan -24, independently.
	_make_mil_unit(841, &"piyade", Constants.TEAM_IRAN)
	_make_mil_unit(842, &"turan_piyade", Constants.TEAM_TURAN)
	_make_mil_unit(843, &"turan_piyade", Constants.TEAM_TURAN)
	_make_mil_unit(844, &"turan_piyade", Constants.TEAM_TURAN)
	var iran_start: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var turan_start: int = ResourceSystem.coin_x100_for(Constants.TEAM_TURAN)
	_advance_farr_phases(1801)
	assert_eq(iran_start - ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 8 * 100,
		"Iran drained 8 coin (1 military unit)")
	assert_eq(turan_start - ResourceSystem.coin_x100_for(Constants.TEAM_TURAN), 24 * 100,
		"Turan drained 24 coin (3 military units) — per-team independent")


func test_upkeep_drains_treasury_not_farr() -> void:
	# Discipline: upkeep moves COIN, never Farr. After a 1-min upkeep cycle the
	# Farr meter is untouched (the emitter accrual is the only Farr mover here,
	# and there are no emitters).
	_reset_clock_for_timing()
	ResourceSystem.reset()
	_make_mil_unit(851, &"piyade", Constants.TEAM_IRAN)
	_advance_farr_phases(1801)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-6,
		"upkeep drains COIN (treasury), NOT Farr — the meter stays at 50.0")
