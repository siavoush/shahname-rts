# Tests for the FarrSystem worker-killed-idle drain (Phase 2 session 1
# wave 2A deliverable 10).
#
# Spec references:
#   - 01_CORE_MECHANICS.md §4 (Farr drains: "Worker killed idle (-1)")
#   - 02d_PHASE_2_KICKOFF.md §2 deliverable 10 (cause-string strategy (c))
#   - CLAUDE.md: "All Farr changes flow through apply_farr_change..."
#
# The cause-string convention (chosen per kickoff brief: strategy (c)):
#   - HealthComponent's death emit augments the cause field with an
#     "_idle_worker" suffix when the dying unit is a Kargar AND its FSM is
#     in &"idle" at the moment of death.
#   - FarrSystem subscribes to EventBus.unit_died; if the cause string
#     contains "_idle_worker", it calls apply_farr_change(-1.0, ...).
#   - The convention is forward-extensible: other "X killed Y in state Z"
#     drains can use suffixes ("_fleeing", "_engaged", etc.) without
#     extending the signal signature.
#
# We test the FarrSystem listener in isolation (drive the unit_died emit
# directly) so this file doesn't depend on CombatComponent firing —
# CombatComponent → HealthComponent → unit_died is exercised in
# test_health_component / test_combat_component already.
#
# Re-entrancy guard: the FarrSystem listener calls ONLY apply_farr_change
# (the documented chokepoint). No SelectionManager mutation, no signal
# re-emit. The cb95d09-class re-entrancy bug (BUILD_LOG 2026-05-04) is
# avoided by construction — apply_farr_change emits farr_changed but
# nothing in this test path subscribes to farr_changed in a way that
# would re-mutate unit_died subscribers.
extends GutTest


# Helper: drive a body inside a tick so on-tick asserts (in
# apply_farr_change) pass. Same _on_tick pattern as test_health_component
# / test_farr_system.
func _on_tick(body: Callable) -> void:
	SimClock._is_ticking = true
	body.call()
	SimClock._is_ticking = false


# Capture buffer for farr_changed payloads (deltas applied by FarrSystem).
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


# Reset Farr to 50.0 and re-arm the capture buffer between tests so each
# starts from a known baseline.
func before_each() -> void:
	SimClock.reset()
	FarrSystem.reset()
	_captured_farr_deltas.clear()
	EventBus.farr_changed.connect(_on_farr_changed)


func after_each() -> void:
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)
	SimClock.reset()
	FarrSystem.reset()


# ---------------------------------------------------------------------------
# Cause-string parsing — listener correctly identifies idle-worker deaths
# ---------------------------------------------------------------------------

func test_idle_worker_killed_drops_farr_by_one() -> void:
	# Simulate the HealthComponent emit shape: cause contains "_idle_worker"
	# suffix. FarrSystem's listener should detect that and apply -1.0.
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_died.emit(
			3,                       # dying unit_id (a Kargar in idle)
			7,                       # killer_unit_id (a Turan Piyade)
			&"melee_attack_idle_worker",
			Vector3(2.0, 0.0, 5.0),
		)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 1.0, 0.001,
		"idle worker death must drop Farr by exactly 1.0, before=%.2f after=%.2f"
			% [farr_before, farr_after])
	assert_eq(_captured_farr_deltas.size(), 1,
		"exactly one farr_changed must fire for one idle worker death")
	var p: Dictionary = _captured_farr_deltas[0]
	assert_almost_eq(float(p[&"amount"]), -1.0, 0.001,
		"farr_changed delta must be -1.0")
	assert_eq(p[&"reason"], "worker_killed_idle",
		"farr_changed reason must be 'worker_killed_idle' (matches §4 spec)")


func test_non_idle_worker_killed_does_not_drop_farr() -> void:
	# A Kargar killed while NOT idle (e.g., gathering, fleeing, or any
	# non-idle state) should not trigger the idle-worker drain. The cause
	# carries no "_idle_worker" suffix in that case.
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_died.emit(
			3,
			7,
			&"melee_attack",  # bare cause, no suffix
			Vector3(2.0, 0.0, 5.0),
		)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before, farr_after, 0.001,
		"non-idle worker death must NOT change Farr, before=%.2f after=%.2f"
			% [farr_before, farr_after])
	assert_eq(_captured_farr_deltas.size(), 0,
		"no farr_changed must fire for non-idle worker death")


func test_non_worker_killed_does_not_drop_farr() -> void:
	# A Piyade (or any non-Kargar) killed should not trigger the idle-worker
	# drain — even if somehow the cause contained the suffix (defense in
	# depth). The whole drain is conditional on the cause string having
	# "_idle_worker" in it; non-worker deaths don't get that suffix from
	# HealthComponent in the first place, so this test asserts no surprises
	# from cause strings that don't match.
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		EventBus.unit_died.emit(
			6,                # a Piyade unit_id
			11,               # killer
			&"melee_attack",  # bare cause, no suffix
			Vector3(0.0, 0.0, 0.0),
		)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before, farr_after, 0.001,
		"non-worker death must NOT change Farr")
	assert_eq(_captured_farr_deltas.size(), 0,
		"no farr_changed must fire for non-worker death with bare cause")


# ---------------------------------------------------------------------------
# Multiple deaths — ledger correctness
# ---------------------------------------------------------------------------

func test_multiple_idle_worker_deaths_drop_farr_proportionally() -> void:
	# Three idle workers killed in sequence → Farr drops by 3.0 total.
	# Each drop is its own farr_changed emit; the cumulative ledger is
	# what the F2 overlay (Phase 4) and Kaveh-trigger (Phase 5) will read.
	var farr_before: float = FarrSystem.value_farr
	_on_tick(func() -> void:
		for i in range(3):
			EventBus.unit_died.emit(
				i + 1,
				99,
				&"melee_attack_idle_worker",
				Vector3.ZERO,
			)
	)
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 3.0, 0.001,
		"3 idle worker deaths must drop Farr by exactly 3.0, got %.2f"
			% (farr_before - farr_after))
	assert_eq(_captured_farr_deltas.size(), 3,
		"3 farr_changed emits, one per death")


# ---------------------------------------------------------------------------
# Wiring — listener is connected at FarrSystem _ready and survives reset
# ---------------------------------------------------------------------------

func test_farr_drain_listener_connected_after_ready() -> void:
	# Live-game-broken-surface: FarrSystem must subscribe to unit_died at
	# autoload _ready time. If a connection is missing in _ready, the live
	# game silently never drains Farr from worker deaths — exactly the
	# "tests pass but live broken" failure mode session 1 is built to
	# avoid.
	#
	# Direct check: there's at least one connection on EventBus.unit_died
	# pointing back into FarrSystem.
	var has_connection: bool = false
	for c in EventBus.unit_died.get_connections():
		var callable: Callable = c[&"callable"] as Callable
		if callable.get_object() == FarrSystem:
			has_connection = true
			break
	assert_true(has_connection,
		"FarrSystem must have a listener on EventBus.unit_died (worker-killed-idle drain)")


func test_farr_drain_listener_connected_after_reset() -> void:
	# reset() is the test-harness escape used by MatchHarness between
	# matches. After reset, the listener must still be live so a freshly-
	# started match also drains Farr correctly.
	FarrSystem.reset()
	var has_connection: bool = false
	for c in EventBus.unit_died.get_connections():
		var callable: Callable = c[&"callable"] as Callable
		if callable.get_object() == FarrSystem:
			has_connection = true
			break
	assert_true(has_connection,
		"FarrSystem listener must remain connected after reset()")
