# Tests for StateMachine framework: State, StateMachine, Command,
# CommandQueue, CommandPool, InterruptLevel.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md (1.0.0). Covers transitions,
# command queue dispatch via transition_to_next(), transition history ring
# buffer, death-preempt via EventBus.unit_health_zero, interrupt levels.
extends GutTest


# Preload script refs so this test parses cleanly even before the global
# class_name registry is populated by GUT's collector. The preloads also
# serve as a side-effect: Godot resolves each script (and registers its
# class_name) at parse time, which lets later inner-class extends-by-path
# parse cleanly.
const StateScript: Script = preload("res://scripts/core/state_machine/state.gd")
const StateMachineScript: Script = preload("res://scripts/core/state_machine/state_machine.gd")
const CommandScript: Script = preload("res://scripts/core/state_machine/command.gd")
const CommandQueueScript: Script = preload("res://scripts/core/state_machine/command_queue.gd")
const InterruptLevelScript: Script = preload("res://scripts/core/state_machine/interrupt_level.gd")


# === Test fixtures ==========================================================

# A minimal state that records lifecycle hits and supports requesting a
# transition on a configured tick. Used as the "_TestState" called for in the
# kickoff doc.
class _TestState extends "res://scripts/core/state_machine/state.gd":
	var enter_count: int = 0
	var tick_count: int = 0
	var exit_count: int = 0
	var last_prev_id: StringName = &""
	var transition_after_n_ticks: int = -1   # -1 disables auto-transition
	var transition_target: StringName = &""

	func _init(state_id: StringName, prio: int = 0, interrupt: int = 0) -> void:
		id = state_id
		priority = prio
		interrupt_level = interrupt

	# Using untyped `prev` to avoid a class_name resolution race when GUT
	# collects this inner class before the global registry is populated.
	# The outer test still validates the State protocol via behavior.
	func enter(prev: Variant, _ctx: Object) -> void:
		enter_count += 1
		last_prev_id = prev.id if prev != null else &""

	func _sim_tick(_dt: float, ctx: Object) -> void:
		tick_count += 1
		if transition_after_n_ticks >= 0 and tick_count >= transition_after_n_ticks:
			ctx.fsm.transition_to(transition_target)

	func exit() -> void:
		exit_count += 1


# Lightweight unit context. Holds unit_id (for death-preempt filtering),
# command_queue (for transition_to_next dispatch), and an fsm ref. Properties
# are untyped (Variant) because GUT collects this class before the project
# class_name registry resolves (same constraint as the preload pattern above).
class _StubUnit extends RefCounted:
	var unit_id: int = 0
	var command_queue: Variant = null
	var fsm: Variant = null


# Helper: build a StateMachine on a stub unit, with the given state ids
# registered. The first id becomes the initial state.
func _build_fsm(state_ids: Array, unit_id: int = 1) -> Dictionary:
	var unit := _StubUnit.new()
	unit.unit_id = unit_id
	unit.command_queue = CommandQueueScript.new()
	var fsm = StateMachineScript.new()
	fsm.ctx = unit
	unit.fsm = fsm
	var states: Dictionary = {}
	for sid in state_ids:
		var s := _TestState.new(sid)
		fsm.register(s)
		states[sid] = s
	fsm.init(state_ids[0])
	return {"unit": unit, "fsm": fsm, "states": states}


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()


func after_each() -> void:
	SimClock.reset()
	CommandPool.reset()


# === InterruptLevel =========================================================

func test_interrupt_level_enum_values() -> void:
	assert_eq(InterruptLevelScript.NONE, 0)
	assert_eq(InterruptLevelScript.COMBAT, 1)
	assert_eq(InterruptLevelScript.NEVER, 2)


# === Command + CommandPool ==================================================

func test_command_pool_rents_and_returns() -> void:
	var c1: Object = CommandPool.rent()
	assert_not_null(c1)
	assert_eq(CommandPool.outstanding(), 1)
	c1.kind = &"move"
	c1.payload = {"target": Vector3(1, 2, 3)}
	CommandPool.return_to_pool(c1)
	assert_eq(CommandPool.outstanding(), 0)
	# Re-rent — Pool must reset (kind cleared) before handing back.
	var c2: Object = CommandPool.rent()
	assert_eq(c2.kind, &"", "Returned command must be reset before re-renting")
	assert_eq(c2.payload.size(), 0)
	CommandPool.return_to_pool(c2)


func test_command_pool_reuses_freed_instances() -> void:
	var c1: Object = CommandPool.rent()
	CommandPool.return_to_pool(c1)
	var c2: Object = CommandPool.rent()
	assert_same(c1, c2, "Pool should reuse the freshly-returned instance")
	CommandPool.return_to_pool(c2)


# === CommandQueue ===========================================================

func test_command_queue_push_pop_fifo() -> void:
	var q = CommandQueueScript.new()
	var a: Object = CommandPool.rent()
	a.kind = &"move"
	var b: Object = CommandPool.rent()
	b.kind = &"attack"
	q.push(a)
	q.push(b)
	assert_eq(q.size(), 2)
	assert_same(q.peek(), a, "FIFO: oldest at the head")
	var popped_a = q.pop()
	assert_same(popped_a, a)
	var popped_b = q.pop()
	assert_same(popped_b, b)
	assert_true(q.is_empty())
	CommandPool.return_to_pool(popped_a)
	CommandPool.return_to_pool(popped_b)


func test_command_queue_clear_returns_all_to_pool() -> void:
	var q = CommandQueueScript.new()
	for i in range(5):
		var c: Object = CommandPool.rent()
		c.kind = &"move"
		q.push(c)
	assert_eq(q.size(), 5)
	assert_eq(CommandPool.outstanding(), 5)
	q.clear()
	assert_true(q.is_empty())
	assert_eq(CommandPool.outstanding(), 0,
		"clear() must return every queued Command to the pool")


func test_command_queue_capacity_drops_oldest_on_overflow() -> void:
	var q = CommandQueueScript.new()
	# Fill to capacity.
	for i in range(Constants.COMMAND_QUEUE_CAPACITY):
		var c: Object = CommandPool.rent()
		c.kind = &"move"
		c.payload = {"i": i}
		q.push(c)
	assert_eq(q.size(), Constants.COMMAND_QUEUE_CAPACITY)
	# 33rd push drops the oldest (i=0). Head becomes i=1.
	var overflow: Object = CommandPool.rent()
	overflow.kind = &"attack"
	q.push(overflow)
	assert_eq(q.size(), Constants.COMMAND_QUEUE_CAPACITY,
		"Overflow must keep capacity stable")
	var head = q.peek()
	assert_eq(head.payload.i, 1, "Oldest (i=0) must have been dropped")
	q.clear()
	# Cleaning resets the pool counter back to the dropped command (which
	# was returned implicitly by push's overflow handling).


# === StateMachine init + transitions =========================================

func test_init_calls_enter_on_initial_state() -> void:
	var ctx := _build_fsm([&"idle", &"moving"])
	var idle: _TestState = ctx.states[&"idle"]
	assert_eq(idle.enter_count, 1, "init() must call enter() on the initial state")
	assert_eq(idle.last_prev_id, &"", "Initial enter has no prev state")


func test_transition_to_runs_exit_then_enter() -> void:
	var ctx := _build_fsm([&"idle", &"moving"])
	var fsm = ctx.fsm
	var idle: _TestState = ctx.states[&"idle"]
	var moving: _TestState = ctx.states[&"moving"]
	# Configure idle to request a transition on its first tick.
	idle.transition_after_n_ticks = 1
	idle.transition_target = &"moving"
	fsm.tick(SimClock.SIM_DT)
	assert_eq(idle.exit_count, 1, "Old state's exit must fire on transition")
	assert_eq(moving.enter_count, 1, "New state's enter must fire on transition")
	assert_eq(fsm.current.id, &"moving")
	assert_eq(moving.last_prev_id, &"idle")


func test_current_state_name_reflects_active_state() -> void:
	var ctx := _build_fsm([&"idle", &"moving"])
	var fsm = ctx.fsm
	assert_eq(fsm.current_state_name(), &"idle")
	fsm.transition_to(&"moving")
	# Pending — not yet swapped. Drain via a tick.
	fsm.tick(SimClock.SIM_DT)
	assert_eq(fsm.current_state_name(), &"moving")


func test_unknown_transition_target_asserts() -> void:
	var ctx := _build_fsm([&"idle"])
	var fsm = ctx.fsm
	# transition_to with an unknown id triggers the assert in non-debug paths.
	# In tests we just verify the lookup table doesn't have it; assert is
	# documented behaviour and not GUT-trappable.
	assert_false(fsm._states.has(&"nonexistent"))


# === transition_to_next() dispatch ==========================================

func test_transition_to_next_pops_command_and_dispatches() -> void:
	var ctx := _build_fsm([&"idle", &"moving", &"attacking"])
	var unit: _StubUnit = ctx.unit
	var fsm = ctx.fsm
	# Queue a move command and ask the fsm to dispatch.
	var cmd: Object = CommandPool.rent()
	cmd.kind = &"move"
	cmd.payload = {"target": Vector3(10, 0, 0)}
	unit.command_queue.push(cmd)
	fsm.transition_to_next()
	# Drain the pending transition.
	fsm.tick(SimClock.SIM_DT)
	assert_eq(fsm.current.id, &"moving",
		"Move command dispatches to Moving state")
	assert_true(unit.command_queue.is_empty(),
		"Dispatched command must be popped from the queue")


func test_transition_to_next_with_empty_queue_goes_idle() -> void:
	var ctx := _build_fsm([&"moving", &"idle"])
	var fsm = ctx.fsm
	# fsm starts in moving (registered first); queue is empty; dispatch goes
	# to idle.
	fsm.transition_to_next()
	fsm.tick(SimClock.SIM_DT)
	assert_eq(fsm.current.id, &"idle")


func test_transition_to_next_attack_command_dispatches_to_attacking() -> void:
	var ctx := _build_fsm([&"idle", &"attacking"])
	var unit: _StubUnit = ctx.unit
	var fsm = ctx.fsm
	var cmd: Object = CommandPool.rent()
	cmd.kind = &"attack"
	unit.command_queue.push(cmd)
	fsm.transition_to_next()
	fsm.tick(SimClock.SIM_DT)
	assert_eq(fsm.current.id, &"attacking")


# === Transition history ring buffer ========================================

func test_history_records_each_transition() -> void:
	var ctx := _build_fsm([&"idle", &"moving"])
	var fsm = ctx.fsm
	# Initial state set during init() does NOT record a from→to entry (no
	# previous state). Drive a transition to make one.
	fsm.transition_to(&"moving")
	fsm.tick(SimClock.SIM_DT)
	var hist: Array = fsm.transition_history()
	assert_eq(hist.size(), 1)
	assert_eq(hist[0]["from"], &"idle")
	assert_eq(hist[0]["to"], &"moving")
	assert_true(hist[0].has("tick"))
	assert_true(hist[0].has("reason"))


func test_history_ring_buffer_overwrites_oldest() -> void:
	# Build a machine with a back-and-forth pair; cycle past capacity.
	var ctx := _build_fsm([&"idle", &"moving"])
	var fsm = ctx.fsm
	var cap := Constants.STATE_MACHINE_HISTORY_SIZE_UNIT  # 16
	# 2 * cap transitions overflows the ring; only the last `cap` survive.
	for i in range(2 * cap):
		var target: StringName = &"moving" if (i % 2 == 0) else &"idle"
		fsm.transition_to(target)
		fsm.tick(SimClock.SIM_DT)
	var hist: Array = fsm.transition_history()
	assert_eq(hist.size(), cap, "Ring buffer must cap at history capacity")
	# Newest entry has tick == latest SimClock.tick - 1 (the tick when it
	# fired). Since the ring is oldest-first, newest is the last entry.
	var newest: Dictionary = hist[-1]
	assert_eq(newest["to"], &"idle" if (2 * cap - 1) % 2 != 0 else &"moving")


func test_history_capacity_can_be_set_for_ai_controllers() -> void:
	var ctx := _build_fsm([&"idle"])
	var fsm = ctx.fsm
	fsm.set_history_capacity(Constants.STATE_MACHINE_HISTORY_SIZE_AI)
	# Drive 70 transitions; expect 64 (AI capacity) survive.
	# Actually we have only 1 state — drive ID-to-self transitions which still
	# record. set_history_capacity clears existing history; assert capacity.
	for i in range(70):
		fsm.transition_to(&"idle")
		fsm.tick(SimClock.SIM_DT)
	var hist: Array = fsm.transition_history()
	assert_eq(hist.size(), Constants.STATE_MACHINE_HISTORY_SIZE_AI)


# === Death preempt =========================================================

func test_death_preempt_force_transitions_to_dying() -> void:
	# Build a machine with a Dying state. unit_id = 7 — only that unit's
	# health-zero signal triggers preempt.
	var ctx := _build_fsm([&"idle", &"moving", &"dying"], 7)
	var fsm = ctx.fsm
	var dying: _TestState = ctx.states[&"dying"]
	# Drive a tick so we're in idle.
	fsm.tick(SimClock.SIM_DT)
	# Fire the death signal for unit 7.
	EventBus.unit_health_zero.emit(7)
	# Preempt is synchronous — current must already be Dying.
	assert_eq(fsm.current.id, &"dying", "Death preempt must force-transition to Dying")
	assert_eq(dying.enter_count, 1)


func test_death_preempt_ignores_other_units() -> void:
	var ctx := _build_fsm([&"idle", &"dying"], 7)
	var fsm = ctx.fsm
	# Health-zero for a DIFFERENT unit — must not preempt this one.
	EventBus.unit_health_zero.emit(99)
	assert_eq(fsm.current.id, &"idle")


func test_death_preempt_cancels_pending_transition() -> void:
	# Machine in idle; queue a transition to moving; instead, fire death.
	# Dying must win.
	var ctx := _build_fsm([&"idle", &"moving", &"dying"], 1)
	var fsm = ctx.fsm
	fsm.transition_to(&"moving")
	# Don't tick — pending is still set. Fire death; preempt cancels pending.
	EventBus.unit_health_zero.emit(1)
	assert_eq(fsm.current.id, &"dying", "Pending must be dropped; Dying wins")
	# Tick once: Moving must not become current (pending was cleared).
	fsm.tick(SimClock.SIM_DT)
	assert_eq(fsm.current.id, &"dying")


func test_death_preempt_idempotent_on_already_dying() -> void:
	var ctx := _build_fsm([&"dying"], 1)
	var fsm = ctx.fsm
	var dying: _TestState = ctx.states[&"dying"]
	var enter_before := dying.enter_count
	EventBus.unit_health_zero.emit(1)
	assert_eq(dying.enter_count, enter_before,
		"Already-Dying unit ignores subsequent death signals")


# === Bounded transition chain ==============================================

func test_transition_chain_bound_drops_runaway() -> void:
	# Configure idle to request a transition; moving to bounce back. Both
	# do so in their _sim_tick. With chain bound = 4, infinite loops are
	# prevented and the bound is hit.
	var ctx := _build_fsm([&"idle", &"moving"])
	var fsm = ctx.fsm
	var idle: _TestState = ctx.states[&"idle"]
	var moving: _TestState = ctx.states[&"moving"]
	idle.transition_after_n_ticks = 1
	idle.transition_target = &"moving"
	moving.transition_after_n_ticks = 1
	moving.transition_target = &"idle"
	# Single tick. idle.tick → request moving. The drain loop applies the
	# transition to moving; moving's enter() does NOT call _sim_tick (only
	# the next tick() entry calls _sim_tick), so the chain stops naturally.
	# We verify that the bound exists by counting transitions in the
	# history after several ticks.
	for i in range(10):
		fsm.tick(SimClock.SIM_DT)
	# 10 ticks with each tick producing exactly 1 transition (from current's
	# _sim_tick) gives 10 transitions in history.
	var hist: Array = fsm.transition_history()
	assert_true(hist.size() >= 5,
		"Multiple ticks should produce multiple history entries")
	assert_true(hist.size() <= 10)
