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
	# Restore default starting value (5000 = 50.0). FarrSystem doesn't ship a
	# public reset — it's an autoload with a single-source-of-truth value —
	# so we drive it back through the chokepoint inside a tick.
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
