# Tests for the worker-killed Farr-drain pipeline — Phase 3 wave 1B.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §4 (Farr drains: "Worker killed idle (-1)")
#   - 02f_PHASE_3_KICKOFF.md §2 Open Space resolution (2026-05-13):
#     drain dispatcher subscribes to unit_health_zero PRE-Dying-swap,
#     reads fsm.current.id, dispatches via BalanceData.farr.drain_rates.
#   - CLAUDE.md: "All Farr changes flow through apply_farr_change..."
#
# Migration note (this file pre-dated the dispatcher):
#   Phase 2 session 1 wave 2A shipped a different mechanism — FarrSystem
#   subscribed to EventBus.unit_died and parsed an "_idle_worker" cause-
#   string suffix that HealthComponent appended. That path is RETIRED
#   as of Phase 3 wave 1B (Open Space 2026-05-13). The dispatcher
#   replaces it; behavior is functionally equivalent for the idle-worker
#   case, but extends to gathering/returning workers and reads from
#   BalanceData rather than hardcoded -1.
#
#   The new dispatcher's primary unit-test coverage lives in
#   test_farr_drain_dispatcher.gd (12 tests). This file keeps a thin layer
#   of behavior coverage verifying the LIVE path: emitting
#   EventBus.unit_health_zero with a Kargar in the scene tree must produce
#   the expected Farr movement.
extends GutTest


# Helper: emit inside a sim tick so apply_farr_change's on-tick assert holds.
func _on_tick(body: Callable) -> void:
	SimClock._is_ticking = true
	body.call()
	SimClock._is_ticking = false


# Capture buffer for farr_changed payloads.
var _captured_farr_deltas: Array[Dictionary] = []


func _on_farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int) -> void:
	_captured_farr_deltas.append({
		&"amount": amount,
		&"reason": reason,
		&"source_unit_id": source_unit_id,
		&"farr_after": farr_after,
		&"tick": tick,
	})


# Fake Unit with the dispatcher's duck-typed surface.
class FakeFSM:
	var current: FakeState = null


class FakeState:
	var id: StringName = &""


class FakeUnit extends Node:
	var unit_id: int = -1
	var unit_type: StringName = &""
	var fsm: FakeFSM = FakeFSM.new()
	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


var _fake_units: Array = []


func _make_fake_unit(uid: int, ut: StringName, state_id: StringName) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.unit_type = ut
	u.fsm.current = FakeState.new()
	u.fsm.current.id = state_id
	add_child_autofree(u)
	_fake_units.append(u)
	return u


func before_each() -> void:
	SimClock.reset()
	FarrSystem.reset()
	FarrDrainDispatcher.reset()
	_captured_farr_deltas.clear()
	_fake_units.clear()
	EventBus.farr_changed.connect(_on_farr_changed)


func after_each() -> void:
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)
	SimClock.reset()
	FarrSystem.reset()
	FarrDrainDispatcher.reset()


# ---------------------------------------------------------------------------
# New mechanism — unit_health_zero + dispatcher → Farr drain
# ---------------------------------------------------------------------------

func test_idle_worker_killed_drops_farr_by_one() -> void:
	# A Kargar in &"idle" dies. FarrDrainDispatcher reads fsm.current.id,
	# dispatches worker_killed_idle (magnitude 1.0), FarrSystem applies -1.0.
	var u: FakeUnit = _make_fake_unit(3, &"kargar", &"idle")
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 1.0, 0.001,
		"idle worker death must drop Farr by exactly 1.0, before=%.2f after=%.2f"
			% [farr_before, farr_after])
	assert_eq(_captured_farr_deltas.size(), 1,
		"Exactly one farr_changed event with reason 'worker_killed_idle' must fire")
	var p: Dictionary = _captured_farr_deltas[0]
	assert_almost_eq(float(p[&"amount"]), -1.0, 0.001,
		"farr_changed delta must be -1.0")
	assert_eq(p[&"reason"], "worker_killed_idle",
		"farr_changed reason must be 'worker_killed_idle' (matches §4 spec)")


func test_gathering_worker_killed_drops_farr_by_half() -> void:
	# A Kargar in &"gathering" dies — lighter drain per Open Space.
	var u: FakeUnit = _make_fake_unit(4, &"kargar", &"gathering")
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 0.5, 0.001,
		"gathering worker death must drop Farr by exactly 0.5")
	assert_eq(_captured_farr_deltas[0][&"reason"], "worker_killed_during_gather",
		"reason must be 'worker_killed_during_gather'")


func test_non_worker_killed_does_not_drop_farr() -> void:
	# A Piyade (combat unit) dying — no worker-loss drain.
	var u: FakeUnit = _make_fake_unit(6, &"piyade", &"attacking")
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before, farr_after, 0.001,
		"non-worker death must NOT change Farr")
	assert_eq(_captured_farr_deltas.size(), 0,
		"no farr_changed must fire for non-worker death")


func test_multiple_idle_worker_deaths_drop_farr_proportionally() -> void:
	# Three idle workers killed → Farr drops by 3.0 total.
	var u1: FakeUnit = _make_fake_unit(1, &"kargar", &"idle")
	var u2: FakeUnit = _make_fake_unit(2, &"kargar", &"idle")
	var u3: FakeUnit = _make_fake_unit(3, &"kargar", &"idle")
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_health_zero.emit(u1.unit_id)
		EventBus.unit_health_zero.emit(u2.unit_id)
		EventBus.unit_health_zero.emit(u3.unit_id)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 3.0, 0.001,
		"3 idle worker deaths must drop Farr by exactly 3.0, got %.2f"
			% (farr_before - farr_after))
	assert_eq(_captured_farr_deltas.size(), 3,
		"3 farr_changed emits, one per death")


# ---------------------------------------------------------------------------
# Wiring — FarrDrainDispatcher subscription survives reset()
# ---------------------------------------------------------------------------

func test_dispatcher_subscription_present_at_ready() -> void:
	# The dispatcher autoload subscribes to unit_health_zero in _ready.
	# This must remain connected so the live game drains Farr correctly.
	assert_true(
		EventBus.unit_health_zero.is_connected(
			FarrDrainDispatcher._on_unit_health_zero),
		"FarrDrainDispatcher must subscribe to unit_health_zero at _ready"
	)


# ---------------------------------------------------------------------------
# Legacy mechanism retired — unit_died with _idle_worker suffix is a no-op
# ---------------------------------------------------------------------------

func test_unit_died_with_idle_worker_suffix_no_longer_drains() -> void:
	# Phase 3 wave 1B retired the cause-string suffix parsing path. Emitting
	# unit_died with the legacy "_idle_worker" suffix must NOT drain Farr —
	# the dispatcher subscribes to unit_health_zero (PRE-Dying-swap), so
	# unit_died is no longer the trigger.
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_died.emit(
			3, 7, &"melee_attack_idle_worker", Vector3.ZERO,
		)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before, farr_after, 0.001,
		"Legacy unit_died + _idle_worker suffix path is RETIRED (Open Space 2026-05-13). "
		+ "Farr must remain unchanged.")
