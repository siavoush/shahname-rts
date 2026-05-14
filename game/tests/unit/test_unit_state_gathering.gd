# Tests for UnitState_Gathering — the Kargar worker's gather state.
#
# Per docs/STATE_MACHINE_CONTRACT.md §3 + docs/RESOURCE_NODE_CONTRACT.md §4 +
# Phase 3 wave 1A kickoff §3.
#
# What we cover:
#   - id / priority / interrupt_level shape (id = &"gathering" is contract
#     per Open Space sync v0.20.0; do not rename).
#   - enter resolves target node, sets up movement to its position.
#   - _sim_tick drives movement while walking; calls request_extract on
#     arrival; counts down dwell; complete_extract on dwell completion;
#     populates carry on Kargar; transitions to Returning.
#   - exit cancels in-flight repath; releases slot if mid-extract per
#     Resource Node Contract §4.1.
#   - Defensive bails (missing target, missing payload, slot rejection).
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateGatheringScript: Script = preload(
	"res://scripts/units/states/unit_state_gathering.gd")
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd")
const IPathSchedulerScript: Script = preload(
	"res://scripts/core/path_scheduler.gd")


var _unit: Variant
var _mine: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _unit != null and is_instance_valid(_unit):
		_unit.queue_free()
	_unit = null
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	_mine = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


func _spawn_unit_and_mine() -> void:
	_unit = UnitScene.instantiate()
	_unit.team = Constants.TEAM_IRAN
	add_child_autofree(_unit)
	_unit.get_movement()._scheduler = _mock
	_unit.global_position = Vector3.ZERO
	_unit.get_movement().move_speed = 100.0  # fast — arrive in one tick

	_mine = MineNodeScene.instantiate()
	add_child_autofree(_mine)
	_mine.global_position = Vector3(5.0, 0.0, 0.0)


func _tick_fsm() -> void:
	SimClock._is_ticking = true
	_unit.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# Shape — id, priority, interrupt_level.
# ---------------------------------------------------------------------------

func test_gathering_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateGatheringScript.new()
	# id = &"gathering" is LOAD-BEARING per Open Space sync v0.20.0 — the
	# Farr-drain dispatcher (Phase 3 wave 1B) reads current.id at unit-death
	# time to distinguish gather-death (-0.5) from idle-death (-1.0).
	# DO NOT rename this StringName.
	assert_eq(s.id, &"gathering",
		"Gathering.id is &\"gathering\" (Open Space contract — Farr-drain key)")
	assert_eq(s.priority, 5,
		"Gathering.priority is 5 (above Idle, below Moving's 10)")
	assert_eq(s.interrupt_level, 1,
		"Gathering.interrupt_level is COMBAT (1) — passive combat interrupts the gather")


# ---------------------------------------------------------------------------
# enter — read target_node from current_command, start moving.
# ---------------------------------------------------------------------------

func test_enter_reads_target_node_and_requests_repath() -> void:
	_spawn_unit_and_mine()
	# Replace the unit's command with a gather toward the mine.
	_unit.replace_command(&"gather",
		{&"target_node": _mine})
	_tick_fsm()  # drain dispatch
	assert_eq(_unit.fsm.current.id, &"gathering",
		"replace_command(&\"gather\") dispatches into Gathering")
	# request_repath fired with the mine's position.
	assert_eq(_mock.call_log.size(), 1,
		"Gathering.enter calls request_repath exactly once")
	var entry: Dictionary = _mock.call_log[0]
	assert_eq(entry.to, _mine.global_position,
		"request_repath target matches mine.global_position")


func test_enter_without_target_node_bails_to_idle() -> void:
	# Defensive: empty payload — state bails to Idle.
	_spawn_unit_and_mine()
	_unit.current_command = {"kind": &"gather", "payload": {}}
	_unit.fsm.transition_to(&"gathering")
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle",
		"Gathering with no target_node bails to Idle")


func test_enter_with_freed_target_node_bails_to_idle() -> void:
	_spawn_unit_and_mine()
	_mine.queue_free()
	# Multiple frames for the free to take effect.
	await get_tree().process_frame
	await get_tree().process_frame
	# Manually feed a stale ref. After queue_free,
	# is_instance_valid(_mine) is false but the variable is still bound.
	_unit.current_command = {"kind": &"gather",
		"payload": {&"target_node": _mine}}
	_unit.fsm.transition_to(&"gathering")
	_tick_fsm()
	assert_eq(_unit.fsm.current.id, &"idle",
		"Gathering with an invalid target_node ref bails to Idle")
	_mine = null  # already freed


# ---------------------------------------------------------------------------
# _sim_tick — walk-then-extract-then-Returning lifecycle.
# ---------------------------------------------------------------------------

func test_sim_tick_drives_movement_while_walking() -> void:
	_spawn_unit_and_mine()
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()  # drain into Gathering — request_repath issued
	# Advance clock so mock resolves to READY next poll.
	SimClock._test_run_tick()
	var pos_before: Vector3 = _unit.global_position
	_tick_fsm()  # Gathering._sim_tick polls READY, drives movement
	# Position should have advanced toward the mine.
	assert_true(_unit.global_position.x > pos_before.x,
		"position advances toward the mine during walk phase")


func test_sim_tick_requests_extract_on_arrival() -> void:
	_spawn_unit_and_mine()
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()
	SimClock._test_run_tick()
	# Drive ticks until arrival + extract request.
	var requested: bool = false
	for i in range(60):
		_tick_fsm()
		if _mine.occupied_slots() == 1:
			requested = true
			break
	assert_true(requested,
		"Gathering requests an extract slot after arriving at the mine")


func test_sim_tick_completes_extract_after_dwell() -> void:
	_spawn_unit_and_mine()
	# Shorten the dwell so the test runs quickly.
	_mine.extract_ticks = 3
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()
	SimClock._test_run_tick()
	# Drive ticks until the state transitions out of Gathering.
	var transitioned: bool = false
	for i in range(80):
		_tick_fsm()
		if _unit.fsm.current.id != &"gathering":
			transitioned = true
			break
	assert_true(transitioned,
		"Gathering transitions out after dwell completes")
	# The next state is Returning (with carry populated).
	assert_eq(_unit.fsm.current.id, &"returning",
		"transition target is Returning (loop continuation)")
	# Carry on the unit reflects the mine's yield.
	assert_eq(_unit._carry_kind, Constants.KIND_COIN,
		"Kargar._carry_kind set to coin after complete_extract")
	assert_true(_unit._carry_amount_x100 > 0,
		"Kargar._carry_amount_x100 positive after complete_extract")


func test_sim_tick_bails_to_idle_when_slot_request_rejected() -> void:
	# Pre-occupy the mine's only slot. Gathering arrives, requests, fails,
	# transitions to Idle.
	_spawn_unit_and_mine()
	_mine.max_slots = 1
	_mine.request_extract(999)  # phantom worker holds the slot
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()
	SimClock._test_run_tick()
	var bailed: bool = false
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id == &"idle":
			bailed = true
			break
	assert_true(bailed,
		"Gathering bails to Idle when the slot request is rejected on arrival")


# ---------------------------------------------------------------------------
# exit — slot release + repath cancel.
# ---------------------------------------------------------------------------

func test_exit_cancels_in_flight_repath() -> void:
	_spawn_unit_and_mine()
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()  # request_repath issued, in flight
	var first_id: int = int(_unit.get_movement()._request_id)
	assert_true(first_id > 0)
	# Force-transition out of Gathering — exit() should cancel.
	_unit.fsm.transition_to(&"idle")
	_tick_fsm()
	var poll: Dictionary = _mock.poll_path(first_id)
	assert_eq(poll.state, IPathSchedulerScript.PathState.CANCELLED,
		"Gathering.exit cancels the in-flight repath")


func test_exit_releases_slot_when_mid_extract() -> void:
	# Contract §4.1 — release_extract always called even on death. We assert
	# this by getting the worker to hold a slot, then forcing an exit.
	_spawn_unit_and_mine()
	_mine.extract_ticks = 1000  # long dwell so we exit mid-dwell
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()
	SimClock._test_run_tick()
	# Drive until the worker has requested a slot.
	var grabbed: bool = false
	for i in range(60):
		_tick_fsm()
		if _mine.occupied_slots() == 1:
			grabbed = true
			break
	assert_true(grabbed, "worker grabbed the slot")
	# Force exit — simulates Dying preempt or player replace_command.
	_unit.fsm.transition_to(&"idle")
	_tick_fsm()
	# Slot is released per contract §4.1.
	assert_eq(_mine.occupied_slots(), 0,
		"Gathering.exit released the slot on early exit (Contract §4.1)")
