# Tests for FarrDrainDispatcher autoload — Phase 3 wave 1B.
#
# Contract:
#   - 02f_PHASE_3_KICKOFF.md §2 Open Space resolution (2026-05-13):
#     - drain_rates positive magnitudes; dispatcher applies negative sign
#     - subscribe to unit_health_zero PRE-Dying-swap (NOT unit_died, which
#       fires from Dying.enter — every death would look like state.id ==
#       &"dying")
#   - 01_CORE_MECHANICS.md §4 — Farr drain rates spec
#   - game/scripts/autoload/farr_drain_dispatcher.gd — the SUT
#
# Coverage:
#   - Subscription: subscribes to EventBus.unit_health_zero, NOT unit_died.
#   - Dispatch table: state.id × unit_type → drain key resolution.
#   - Lookup: BalanceData.farr.drain_rates[key] used as the magnitude.
#   - Sign: dispatcher applies -magnitude at call site (positive magnitudes
#     stored in BalanceData).
extends GutTest


# Helper: run a Callable inside a single sim tick. Same pattern as
# test_farr_system.gd. The handler fires inside the combat phase so
# apply_farr_change's on-tick assert holds.
func _run_inside_tick(body: Callable) -> void:
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			body.call()
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)


func before_each() -> void:
	SimClock.reset()
	# Restore Farr to spec default (50.0) directly.
	FarrSystem._farr_x100 = 5000
	FarrDrainDispatcher.reset()


func after_each() -> void:
	SimClock.reset()
	FarrSystem._farr_x100 = 5000
	FarrDrainDispatcher.reset()


# === Subscription contract — UNIT_HEALTH_ZERO, NOT UNIT_DIED ===============

func test_dispatcher_subscribes_to_unit_health_zero_not_unit_died() -> void:
	# Critical contract from the Open Space resolution: the dispatcher must
	# read FSM state PRE-Dying-swap, which means it subscribes to
	# unit_health_zero (emitted before the StateMachine death-preempt swaps
	# the state to Dying) — not unit_died (emitted from Dying.enter, which
	# would always read state.id == &"dying").
	assert_true(
		EventBus.unit_health_zero.is_connected(
			FarrDrainDispatcher._on_unit_health_zero),
		"FarrDrainDispatcher MUST subscribe to unit_health_zero"
	)


func test_dispatcher_does_not_subscribe_to_unit_died() -> void:
	# Negative contract: the dispatcher must NOT subscribe to unit_died.
	# Subscribing to unit_died would always see state.id == &"dying" (the
	# Dying state's enter() is what emits unit_died via HealthComponent),
	# collapsing the two drain keys into one.
	assert_false(
		EventBus.unit_died.is_connected(
			FarrDrainDispatcher._on_unit_health_zero),
		"FarrDrainDispatcher MUST NOT subscribe to unit_died — that would "
		+ "read state.id pos-Dying-swap and collapse drain keys"
	)


# === Dispatch table — resolve_drain_key ====================================

func test_resolve_drain_key_idle_kargar_returns_worker_killed_idle() -> void:
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"idle", &"kargar"),
		&"worker_killed_idle",
		"idle Kargar → worker_killed_idle"
	)


func test_resolve_drain_key_gathering_returns_worker_killed_during_gather() -> void:
	# Any unit type in gathering state — the carry was in progress.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"gathering", &"kargar"),
		&"worker_killed_during_gather",
		"gathering → worker_killed_during_gather"
	)


func test_resolve_drain_key_returning_returns_worker_killed_during_gather() -> void:
	# Symmetric with gathering — the worker was mid-task.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"returning", &"kargar"),
		&"worker_killed_during_gather",
		"returning → worker_killed_during_gather"
	)


func test_resolve_drain_key_idle_piyade_returns_empty() -> void:
	# Non-worker in idle: no drain. A Piyade standing idle that dies is normal
	# combat attrition, not a worker-loss penalty.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"idle", &"piyade"),
		&"",
		"idle non-worker → no drain"
	)


func test_resolve_drain_key_attacking_returns_empty() -> void:
	# Combat-state death: no drain. Phase 3 doesn't drain for combat-unit
	# deaths — snowball protection in §4.3 covers that and ships Phase 4+.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"attacking", &"piyade"),
		&"",
		"attacking → no drain"
	)


# === End-to-end emit — apply_farr_change is called with negative sign ======

# Fake Unit with the duck-typed surface the dispatcher reads (unit_id,
# unit_type, fsm.current.id). Extends Node so the scene-tree walk finds it.
class FakeFSM:
	var current: FakeState = null


class FakeState:
	var id: StringName = &""


class FakeUnit extends Node:
	var unit_id: int = -1
	var unit_type: StringName = &""
	var fsm: FakeFSM = FakeFSM.new()
	# replace_command is the duck-type marker the dispatcher's
	# _find_unit_recursive looks for in addition to unit_id.
	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


func _make_fake_unit(uid: int, ut: StringName, state_id: StringName) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.unit_type = ut
	u.fsm.current = FakeState.new()
	u.fsm.current.id = state_id
	add_child_autofree(u)
	return u


func test_idle_kargar_death_drains_farr_by_one() -> void:
	var u: FakeUnit = _make_fake_unit(101, &"kargar", &"idle")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	# Started at 50.0 (5000 x100). Drain magnitude 1.0 (positive) applied as
	# -1.0 → 49.0.
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"idle Kargar death drains Farr by 1.0 (50.0 → 49.0)")


func test_gathering_kargar_death_drains_farr_by_half() -> void:
	var u: FakeUnit = _make_fake_unit(102, &"kargar", &"gathering")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	# 50.0 - 0.5 = 49.5.
	assert_almost_eq(FarrSystem.value_farr, 49.5, 1e-4,
		"gathering Kargar death drains Farr by 0.5 (50.0 → 49.5)")


func test_returning_kargar_death_drains_farr_by_half() -> void:
	var u: FakeUnit = _make_fake_unit(103, &"kargar", &"returning")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	assert_almost_eq(FarrSystem.value_farr, 49.5, 1e-4,
		"returning Kargar death drains Farr by 0.5 (50.0 → 49.5)")


func test_non_worker_death_does_not_drain() -> void:
	var u: FakeUnit = _make_fake_unit(104, &"piyade", &"attacking")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"non-worker death in combat state does not drain Farr")


func test_unknown_unit_id_does_not_crash() -> void:
	# Defensive: unknown unit_id (already freed, or test artifact) just bails
	# silently without mutating Farr.
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(99999)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"unknown unit_id bails silently — no Farr change")
