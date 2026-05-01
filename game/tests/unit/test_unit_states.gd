# Tests for UnitState_Idle and UnitState_Moving + integration of the
# Idle → Moving → Idle cycle.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §3.4 (transition_to_next),
# §3.5 (no-veto rule for player commands), §6.2 (worked example).
#
# What we cover:
#   - Idle id / priority / interrupt_level
#   - Idle.enter caches the MeshInstance3D and resets scale
#   - Idle._sim_tick is a no-op when no Mesh; pulses scale when Mesh present
#   - Idle.exit restores scale
#   - StateMachine dispatches a queued Move command into Moving (transition_to_next)
#   - Moving id / priority / interrupt_level
#   - Moving.enter reads target from ctx.current_command.payload.target and
#     calls request_repath
#   - Moving.enter without a current_command transitions to Idle (defensive)
#   - Moving._sim_tick advances MovementComponent
#   - Moving transitions to Idle on arrival (full cycle)
#   - Moving handles FAILED path resolution (transitions to next via warning)
#   - Moving.exit cancels in-flight repath
#   - Full Idle → Moving → Idle integration cycle via the unit.tscn template
#     and a MockPathScheduler injected through PathSchedulerService
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/unit.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateIdleScript: Script = preload("res://scripts/units/states/unit_state_idle.gd")
const UnitStateMovingScript: Script = preload("res://scripts/units/states/unit_state_moving.gd")
const StateMachineScript: Script = preload("res://scripts/core/state_machine/state_machine.gd")
const CommandQueueScript: Script = preload("res://scripts/core/state_machine/command_queue.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")


var _unit: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	# Inject a MockPathScheduler so the Moving state's path requests don't
	# touch NavigationServer3D. Tests that need a real scheduler can override.
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _unit != null and is_instance_valid(_unit):
		_unit.queue_free()
	_unit = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


# Spawn a Unit instance via the .tscn template so all components are present
# (HealthComponent, MovementComponent, SelectableComponent, SpatialAgent).
# The Unit base class registers Idle and Moving on _ready.
func _spawn_unit(unit_type: StringName = &"kargar", team: int = 1) -> Variant:
	var u: Variant = UnitScene.instantiate()
	u.unit_type = unit_type
	u.team = team
	add_child_autofree(u)
	# Override the MovementComponent's scheduler with the test mock — _ready
	# pulled the production NavigationAgentPathScheduler from the service,
	# but we replaced it via PathSchedulerService.set_scheduler before
	# spawning, so MovementComponent picks up the mock. Defensive check:
	# in case _ready timing left the production scheduler latched, force-
	# inject the mock on the component itself.
	u.get_movement()._scheduler = _mock
	return u


# Drive a sim tick on the unit's FSM and the MovementComponent inside the
# tick boundary so the on-tick assert in components doesn't trip. Mirrors
# the pattern in test_movement_component.gd.
func _tick_fsm() -> void:
	SimClock._is_ticking = true
	_unit.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# UnitState_Idle — shape and behavior
# ---------------------------------------------------------------------------

func test_idle_state_id_priority_and_interrupt_level() -> void:
	var idle: Variant = UnitStateIdleScript.new()
	assert_eq(idle.id, &"idle", "Idle.id is &\"idle\"")
	assert_eq(idle.priority, 0, "Idle.priority is 0 (lowest)")
	assert_eq(idle.interrupt_level, 0,
		"Idle.interrupt_level is InterruptLevel.NONE (0)")


func test_idle_enter_caches_mesh_and_resets_scale() -> void:
	_unit = _spawn_unit()
	# After _ready, the Unit's FSM should already be in Idle (init(&"idle")
	# fires from base class). The mesh exists; scale has been reset by
	# Idle.enter.
	assert_eq(_unit.fsm.current.id, &"idle",
		"Unit base class lands in Idle after _ready")
	var mesh: Node3D = _unit.get_node(^"MeshInstance3D")
	assert_almost_eq(mesh.scale.x, 1.0, 0.001,
		"mesh scale reset to 1.0 on Idle.enter")


func test_idle_sim_tick_pulses_mesh_scale() -> void:
	_unit = _spawn_unit()
	var mesh: Node3D = _unit.get_node(^"MeshInstance3D")
	# Drive several ticks; the Idle state's _sim_tick should write the
	# pulsing scale based on SimClock.tick. We don't assert the exact value
	# (the formula is sin-based and version-checked in the source); we
	# assert the scale stays in a small band around 1.0 (±5% per the
	# constant) and varies over time.
	#
	# We need to advance SimClock.tick across iterations so the pulse
	# formula sees a varying t — _tick_fsm only flips _is_ticking, doesn't
	# advance the counter, so we use _test_run_tick to push the clock.
	var seen_scales: Array[float] = []
	for i in range(15):  # ~half a second at 30 Hz
		_tick_fsm()
		seen_scales.append(mesh.scale.x)
		SimClock._test_run_tick()  # advance tick so next pulse phase moves
	# All scales must be within ±5% of 1.0 (the pulse amplitude).
	for s: float in seen_scales:
		assert_true(s >= 0.95 and s <= 1.05,
			"pulse stays within ±5% (got %f)" % s)
	# At least one scale must differ from 1.0 (we ticked enough that the
	# pulse has moved off zero).
	var any_off_neutral: bool = false
	for s: float in seen_scales:
		if abs(s - 1.0) > 0.001:
			any_off_neutral = true
			break
	assert_true(any_off_neutral, "pulse must move scale away from neutral")


func test_idle_exit_restores_scale_to_neutral() -> void:
	_unit = _spawn_unit()
	var mesh: Node3D = _unit.get_node(^"MeshInstance3D")
	# Drive a tick so pulse has moved scale off neutral.
	_tick_fsm()
	# Force a transition to Moving — this calls Idle.exit().
	# We need a current_command for Moving's enter to find a target.
	_unit.current_command = {"kind": &"move",
			"payload": {"target": Vector3(10.0, 0.0, 0.0)}}
	_unit.fsm.transition_to(&"moving")
	_tick_fsm()  # apply transition, then tick Moving
	assert_eq(_unit.fsm.current.id, &"moving",
		"transitioned to Moving after Idle.exit")
	# Idle.exit should have restored scale to (1, 1, 1).
	assert_almost_eq(mesh.scale.x, 1.0, 0.001,
		"Idle.exit restores mesh scale to 1.0")


# ---------------------------------------------------------------------------
# UnitState_Moving — shape and behavior
# ---------------------------------------------------------------------------

func test_moving_state_id_priority_and_interrupt_level() -> void:
	var moving: Variant = UnitStateMovingScript.new()
	assert_eq(moving.id, &"moving", "Moving.id is &\"moving\"")
	assert_eq(moving.priority, 10,
		"Moving.priority is 10 (above Idle's 0)")
	assert_eq(moving.interrupt_level, 1,
		"Moving.interrupt_level is InterruptLevel.COMBAT (1)")


func test_moving_enter_reads_target_and_calls_request_repath() -> void:
	# The right-click-to-move flow: ui-developer builds a Move command with
	# payload.target as Vector3, pushes it via Unit.replace_command. The
	# Unit's StateMachine dispatches to Moving via transition_to_next, which
	# stashes the payload on ctx.current_command. Moving.enter reads it and
	# calls request_repath.
	_unit = _spawn_unit()
	_unit.replace_command(&"move", {&"target": Vector3(10.0, 0.0, 0.0)})
	# After replace_command, the FSM has a pending transition to Moving.
	# Drain it.
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"moving",
		"replace_command + Move dispatches into Moving")
	# Moving.enter should have called request_repath on the MovementComponent,
	# which logged a call on the mock.
	assert_eq(_mock.call_log.size(), 1,
		"Moving.enter must call request_repath exactly once")
	var entry: Dictionary = _mock.call_log[0]
	assert_eq(entry.to, Vector3(10.0, 0.0, 0.0),
		"request_repath target matches command payload")
	assert_eq(entry.unit_id, int(_unit.unit_id),
		"request_repath uses the unit's id")


func test_moving_enter_without_current_command_transitions_to_idle() -> void:
	# Defensive case: a direct transition_to(&"moving") without a stashed
	# current_command should transition back to Idle with a warning.
	_unit = _spawn_unit()
	# Confirm we start in Idle.
	assert_eq(_unit.fsm.current.id, &"idle")
	_unit.current_command = {}  # explicit empty
	_unit.fsm.transition_to(&"moving")
	_tick_fsm()
	# After Moving.enter sees no payload, it requests transition to Idle.
	# That request gets drained on the same tick (via the chained-transition
	# loop in StateMachine.tick) — landing us back in Idle.
	assert_eq(_unit.fsm.current.id, &"idle",
		"Moving with no current_command transitions back to Idle")


func test_moving_enter_without_target_in_payload_transitions_to_idle() -> void:
	# A current_command with payload missing `target` is also a defensive
	# bail to Idle — protects against malformed commands from upstream.
	_unit = _spawn_unit()
	_unit.current_command = {"kind": &"move", "payload": {}}
	_unit.fsm.transition_to(&"moving")
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle",
		"Moving with no target in payload transitions back to Idle")


func test_moving_sim_tick_advances_position() -> void:
	# Full path: command, dispatch, drive ticks, observe position changes.
	_unit = _spawn_unit()
	_unit.global_position = Vector3.ZERO
	# Set move_speed manually (BalanceData provides 3.5 for kargar; we want
	# something fast enough to see motion in a few ticks).
	_unit.get_movement().move_speed = 5.0
	_unit.replace_command(&"move", {&"target": Vector3(10.0, 0.0, 0.0)})
	# Drain transition into Moving.
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"moving")
	# At this point: request was made on tick 0 (before any ticks); the mock
	# requires SimClock.tick >= requested_tick + 1. Calling _tick_fsm above
	# advanced our local clock indirectly via SimClock._test_run_tick? No —
	# _tick_fsm only flips _is_ticking, doesn't advance tick. We need the
	# mock to resolve, which requires SimClock.tick to advance.
	SimClock._test_run_tick()  # advance to tick 1; mock now READY
	# Now drive Moving._sim_tick; it polls READY, ingests waypoints, and
	# advances position by move_speed * dt.
	_tick_fsm()
	# Position should have moved toward (10, 0, 0).
	assert_true(_unit.global_position.x > 0.0,
		"position advanced toward target after _sim_tick (got x=%f)" %
		_unit.global_position.x)


func test_moving_transitions_to_idle_on_arrival() -> void:
	# End-to-end: command → Moving → arrival → Idle. Use a huge move_speed
	# so we arrive in one or two ticks.
	_unit = _spawn_unit()
	_unit.global_position = Vector3.ZERO
	_unit.get_movement().move_speed = 100.0  # arrive in one tick
	_unit.replace_command(&"move", {&"target": Vector3(1.0, 0.0, 0.0)})
	_tick_fsm()  # drain dispatch into Moving
	assert_eq(_unit.fsm.current.id, &"moving")
	# Advance the clock so the mock resolves to READY.
	SimClock._test_run_tick()
	# Tick 1: Moving polls READY, ingests waypoints, advances → arrives → latches.
	_tick_fsm()
	# Tick 2: is_moving is now false (we consumed the last waypoint last tick),
	# arrival latch is true, so Moving requests transition_to_next which lands
	# us in Idle (no next command queued).
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle",
		"Moving transitions to Idle on arrival when queue is empty")


func test_moving_handles_failed_path_resolution() -> void:
	# Configure the mock to fail the next request. Moving should bail out
	# back to Idle (or whatever's queued next).
	_unit = _spawn_unit()
	_mock.fail_next_request()
	_unit.replace_command(&"move", {&"target": Vector3(100.0, 0.0, 0.0)})
	_tick_fsm()  # drain dispatch
	assert_eq(_unit.fsm.current.id, &"moving")
	# Advance clock so the mock can resolve to FAILED.
	SimClock._test_run_tick()
	# Tick: MovementComponent polls FAILED; Moving sees FAILED and bails.
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle",
		"FAILED path resolution drops back to Idle")


func test_moving_exit_cancels_in_flight_repath() -> void:
	# Issue a Move; before the path resolves, swap to a different command
	# (which forces Moving.exit). The mock should see the original request
	# as CANCELLED.
	_unit = _spawn_unit()
	_unit.replace_command(&"move", {&"target": Vector3(50.0, 0.0, 0.0)})
	_tick_fsm()  # drain into Moving; request issued
	assert_eq(_unit.fsm.current.id, &"moving")
	var first_id: int = int(_unit.get_movement()._request_id)
	assert_true(first_id > 0)
	# Force a transition to Idle by directly calling transition_to. Moving.exit
	# should cancel the in-flight request.
	_unit.fsm.transition_to(&"idle")
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle")
	# The mock must report the original request as CANCELLED (cancel_repath
	# flips PENDING → CANCELLED on the mock).
	var poll: Dictionary = _mock.poll_path(first_id)
	assert_eq(poll.state, IPathSchedulerScript.PathState.CANCELLED,
		"Moving.exit must cancel the in-flight repath")


# ---------------------------------------------------------------------------
# Integration: full Idle → Moving → Idle cycle
# ---------------------------------------------------------------------------

func test_full_idle_moving_idle_cycle() -> void:
	# The "click and move" headless equivalent. ui-developer's right-click
	# handler will eventually call Unit.replace_command(&"move", {...}); we
	# do that here and verify the full flow.
	_unit = _spawn_unit()
	_unit.global_position = Vector3.ZERO
	_unit.get_movement().move_speed = 10.0  # 10 units/sec
	# Track state transitions via EventBus.unit_state_changed.
	var transitions: Array[Dictionary] = []
	EventBus.unit_state_changed.connect(
		func(unit_id: int, from_id: StringName, to_id: StringName, tick: int) -> void:
			transitions.append({
				"unit_id": unit_id, "from": from_id, "to": to_id, "tick": tick,
			})
	)
	# Confirm initial state.
	assert_eq(_unit.fsm.current.id, &"idle", "starts in Idle")
	# Issue the move command.
	_unit.replace_command(&"move", {&"target": Vector3(2.0, 0.0, 0.0)})
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"moving", "dispatched into Moving")
	# Advance clock so the mock can ready the path.
	SimClock._test_run_tick()
	# Drive ticks until we arrive. Loop is bounded so a stuck unit doesn't
	# spin forever.
	var arrived: bool = false
	for i in range(30):  # 1 second of sim time
		_tick_fsm()
		if _unit.fsm.current.id == &"idle":
			arrived = true
			break
	assert_true(arrived,
		"unit must arrive at target and return to Idle within 1s of sim time")
	# Position is approximately at the target (within a tick's overshoot
	# window).
	assert_almost_eq(_unit.global_position.x, 2.0, 0.5,
		"final position is near target")
	# Two transitions observed: idle→moving and moving→idle.
	# (Plus possibly transition_to(&"idle") chains if the queue stalls.)
	assert_true(transitions.size() >= 2,
		"observed at least two transitions (got %d)" % transitions.size())
	var seen_idle_to_moving: bool = false
	var seen_moving_to_idle: bool = false
	for t: Dictionary in transitions:
		if t.from == &"idle" and t.to == &"moving":
			seen_idle_to_moving = true
		if t.from == &"moving" and t.to == &"idle":
			seen_moving_to_idle = true
	assert_true(seen_idle_to_moving,
		"saw idle → moving transition in EventBus.unit_state_changed")
	assert_true(seen_moving_to_idle,
		"saw moving → idle transition in EventBus.unit_state_changed")


func test_unit_base_registers_idle_and_moving() -> void:
	# Sanity: the Unit base class registers Idle and Moving on _ready, so
	# concrete unit types don't need to repeat the boilerplate.
	_unit = _spawn_unit()
	assert_true(_unit.fsm._states.has(&"idle"),
		"Unit base class registers Idle")
	assert_true(_unit.fsm._states.has(&"moving"),
		"Unit base class registers Moving")
	assert_eq(_unit.fsm.current.id, &"idle",
		"FSM initializes to Idle by default")
