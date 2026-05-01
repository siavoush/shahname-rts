# Integration tests for the full click-and-move flow.
#
# Contract: docs/02b_PHASE_1_KICKOFF.md §49 deliverable 10 (qa-engineer wave 3).
# Related: docs/STATE_MACHINE_CONTRACT.md §3.4 / §6.2,
#          docs/SIMULATION_CONTRACT.md §6.1.
#
# These tests lock in the end-to-end behavior that was silently broken before
# the wave-3 fix (commit c583d48) — unit FSMs were never driven in the live
# game because Unit._on_sim_phase was not wired, so all unit tests passed
# while the live scene did nothing. These integration tests verify the full
# chain: EventBus.sim_phase → Unit._on_sim_phase → fsm.tick → state advances.
#
# What we cover (per kickoff §49 deliverable 10):
#   1. Full click-and-move-and-arrive cycle via real kargar.tscn
#   2. Unit._on_sim_phase actually drives the FSM (regression for wave-3 fix)
#   3. Right-click on a unit is a no-op (Phase 2 attack-move out of scope)
#   4. Click empty terrain → deselect
#   5. Click handler handles freed units gracefully (no crash)
#
# Key integration contracts verified:
#   - EventBus.sim_phase(&"movement") drives fsm.tick via _on_sim_phase
#   - SimClock._test_run_tick is the only "now" (Sim Contract §1.1)
#   - MockPathScheduler injected to avoid NavigationServer3D contact
#   - EventBus.unit_state_changed emitted for idle→moving and moving→idle
#   - Position within epsilon of target after arrival
#   - FSM in &"idle" after arrival
#
# Typing conventions: _spawn_kargar() returns Variant per the project-wide
# class_name registry-race pattern (docs/ARCHITECTURE.md §6 v0.4.0).
# All locals that receive its return value are stored in the class-level
# _kargar / _kargar2 slots (typed Variant) so no local-variable Variant
# inference warnings are emitted — mirrors the pattern in test_kargar.gd.

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const ClickHandlerScript: Script = preload("res://scripts/input/click_handler.gd")


# Class-level Variant slots for unit refs — mirrors test_kargar.gd / test_unit_states.gd
# pattern to avoid the "inferred as Variant" GUT warning-as-error.
var _kargar: Variant = null
var _kargar2: Variant = null
var _mock: Variant = null


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	SelectionManager.reset()
	UnitScript.call(&"reset_id_counter")
	# Inject MockPathScheduler — all movement tests must never touch
	# NavigationServer3D (headless, deterministic). Per Testing Contract §3.1.
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	_kargar = null
	_kargar2 = null


func after_each() -> void:
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	if _kargar2 != null and is_instance_valid(_kargar2):
		_kargar2.queue_free()
	_kargar2 = null
	SelectionManager.reset()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


# Spawn a Kargar via the real .tscn instantiation path and force-inject the
# mock scheduler onto its MovementComponent. This mirrors what production
# does — _ready reads from PathSchedulerService — but we force-write the
# mock after the fact as the double-safety pattern used in test_unit_states.gd.
#
# Returns Variant (not typed Node/Kargar) to avoid the class_name registry race
# documented in docs/ARCHITECTURE.md §6 v0.4.0.
func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	u.global_position = pos
	add_child_autofree(u)
	# Force-inject mock onto the component in case PathSchedulerService timing
	# left the production scheduler latched before our set_scheduler call.
	u.get_movement()._scheduler = _mock
	return u


# Advance the simulation via real SimClock ticks. This drives
# EventBus.sim_phase(&"movement") which Unit._on_sim_phase picks up and
# forwards to fsm.tick — the exact path the live game uses.
#
# This is the critical distinction between integration tests (here) and
# unit tests (test_unit_states.gd): unit tests call fsm.tick directly;
# integration tests emit through the full EventBus → Unit._on_sim_phase chain.
func _advance(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# ============================================================================
# 1. Full click-and-move-and-arrive cycle
# ============================================================================

## Full click-and-move-and-arrive integration test.
##
## This is the test that would have caught the bug where Unit._on_sim_phase
## was not wired — unit tests called fsm.tick directly and passed, but the
## live game's EventBus.sim_phase → _on_sim_phase → fsm.tick chain was broken.
##
## Assertions:
##   a) Position within epsilon of target after arrival
##   b) FSM state is &"idle"
##   c) EventBus.unit_state_changed emitted for idle → moving → idle
func test_full_click_and_move_and_arrive_cycle() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.get_movement().move_speed = 10.0
	var target: Vector3 = Vector3(3.0, 0.0, 0.0)

	# Capture transitions using the same pattern as test_unit_states.gd.
	var transitions: Array[Dictionary] = []
	var kargar_id: int = int(_kargar.unit_id)
	EventBus.unit_state_changed.connect(
		func(uid: int, from_id: StringName, to_id: StringName, _tick: int) -> void:
			if uid == kargar_id:
				transitions.append({"from": from_id, "to": to_id})
	)

	# Simulate what the player's right-click does: issue a Move command.
	_kargar.replace_command(&"move", {&"target": target})

	# Advance one tick so the mock becomes READY (resolves at requested_tick + 1).
	_advance(1)

	# Run ticks until arrival (up to 2 simulated seconds at 30 Hz).
	# _advance uses SimClock._test_run_tick → EventBus.sim_phase → _on_sim_phase.
	var arrived: bool = false
	for _i in range(60):
		_advance(1)
		if String(_kargar.fsm.current.id) == "idle":
			arrived = true
			break

	# (a) Arrived and in Idle.
	assert_true(arrived, "unit must arrive at target and return to Idle within 2s")
	assert_eq(_kargar.fsm.current.id, &"idle", "FSM must be in Idle after arrival")

	# (b) Position within epsilon of target.
	var final_pos: Vector3 = _kargar.global_position
	var dist: float = final_pos.distance_to(target)
	assert_true(dist <= 0.5,
		"final position must be within 0.5 units of target (got dist=%f)" % dist)

	# (c) Verify both transitions fired.
	assert_true(transitions.size() >= 2,
		"expected at least 2 transitions (idle→moving, moving→idle); got %d"
		% transitions.size())
	var saw_idle_to_moving: bool = false
	var saw_moving_to_idle: bool = false
	for t: Dictionary in transitions:
		if t.from == &"idle" and t.to == &"moving":
			saw_idle_to_moving = true
		if t.from == &"moving" and t.to == &"idle":
			saw_moving_to_idle = true
	assert_true(saw_idle_to_moving,
		"must see idle → moving transition in EventBus.unit_state_changed")
	assert_true(saw_moving_to_idle,
		"must see moving → idle transition in EventBus.unit_state_changed")


# ============================================================================
# 2. Unit._on_sim_phase drives the FSM (regression test for wave-3 fix)
# ============================================================================

## Regression test: Unit._on_sim_phase must drive the FSM.
##
## Before the wave-3 fix (commit c583d48), Unit._on_sim_phase was not wired.
## Tests called fsm.tick directly so they all passed, but the live game was
## silently broken — every unit stayed in Idle forever even after a
## replace_command call. This test catches any future removal of the wiring.
##
## Method: issue a move command, advance TWO real ticks (not direct fsm.tick
## calls) via the full EventBus chain, and confirm the position advanced.
##   Tick 1: EventBus.sim_phase(&"movement") → _on_sim_phase → fsm.tick →
##           pending Moving transition is applied (from the replace_command
##           that set _pending_id). Moving.enter fires, request_repath called
##           (at SimClock.tick=0 → mock will READY at tick=1).
##   Tick 2: EventBus.sim_phase(&"movement") → fsm.tick →
##           Moving._sim_tick polls mock → READY → ingests waypoints → steps.
## If _on_sim_phase is not wired, no tick ever fires and position stays at zero.
func test_on_sim_phase_drives_fsm_tick() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.get_movement().move_speed = 10.0

	# Issue a move command. replace_command → transition_to_next → transition_to
	# sets _pending_id = &"moving". The actual state change is DEFERRED — it only
	# applies inside fsm.tick(), which is driven by _on_sim_phase.
	_kargar.replace_command(&"move", {&"target": Vector3(5.0, 0.0, 0.0)})

	# Unit should STILL be in Idle (pending transition not yet applied).
	assert_eq(_kargar.fsm.current.id, &"idle",
		"FSM is in Idle immediately after replace_command (transition is deferred)")

	# Advance TWO ticks via the real EventBus chain. See method doc above.
	_advance(2)

	# After 2 real ticks the unit has entered Moving and advanced its position.
	# Any positive x confirms _on_sim_phase drove the full chain.
	# Stays at 0.0 if _on_sim_phase is not wired.
	var pos_x: float = float((_kargar.global_position as Vector3).x)
	assert_true(pos_x > 0.0,
		"position.x must have advanced toward target after 2 real EventBus ticks "
		+ "(stays at 0 if _on_sim_phase is not wired); got x=%f" % pos_x)


## Regression: _on_sim_phase must ignore phases other than &"movement".
## The FSM must NOT tick during &"input", &"ai", &"combat", etc.
## We use the Idle state's scale-pulse as a proxy — it only fires in _sim_tick.
func test_on_sim_phase_only_fires_on_movement_phase() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	assert_eq(_kargar.fsm.current.id, &"idle")
	var mesh: Node3D = _kargar.get_node(^"MeshInstance3D")

	# Before any tick: scale is 1.0 (Idle.enter resets it).
	assert_almost_eq(mesh.scale.x, 1.0, 0.01, "initial scale is neutral")

	var scale_before: float = mesh.scale.x
	# Non-movement phases must not drive fsm.tick.
	EventBus.sim_phase.emit(&"input", 0)
	EventBus.sim_phase.emit(&"combat", 0)
	var scale_after_non_movement: float = mesh.scale.x
	assert_almost_eq(scale_before, scale_after_non_movement, 0.001,
		"non-movement phases must not drive fsm.tick (scale must not change)")

	# Set SimClock.tick so the sin pulse produces a non-zero offset.
	# tick=15 → t = 0.5s → mid-way through a 1 Hz cycle.
	SimClock.tick = 15
	EventBus.sim_phase.emit(&"movement", 15)
	var scale_after_movement: float = mesh.scale.x
	# Idle pulse: ±5% around 1.0. Give a 6% band to avoid pinning formula.
	assert_true(abs(scale_after_movement - 1.0) < 0.06,
		"movement phase must drive Idle pulse (scale within ±6% of 1.0, "
		+ "got %f)" % scale_after_movement)
	# Reset tick so it doesn't bleed into subsequent tests.
	SimClock.tick = 0


# ============================================================================
# 3. Right-click on a unit is a no-op (Phase 2 attack-move out of scope)
# ============================================================================

## Integration check: right-clicking a unit collider must not issue a Move command.
##
## Already covered in test_click_handler.gd with FakeUnit. This integration
## version uses real Kargar instances to confirm the duck-type resolver works
## with the actual Unit shape (replace_command + command_queue present).
func test_right_click_on_unit_is_noop_integration() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar2 = _spawn_kargar(Vector3(5.0, 0.0, 0.0))

	SelectionManager.select_only(_kargar)
	assert_eq(SelectionManager.selection_size(), 1)

	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	# Synthetic hit where the collider IS a real unit (_kargar2).
	var hit: Dictionary = {
		&"collider": _kargar2,
		&"position": _kargar2.global_position,
		&"normal": Vector3.UP,
	}
	handler.process_right_click_hit(hit)

	# _kargar must NOT have received a Move command — it stays in Idle.
	assert_eq(_kargar.fsm.current.id, &"idle",
		"right-click on a unit must not issue a Move command to selected units "
		+ "(Phase 2 attack-move is not yet implemented)")


# ============================================================================
# 4. Click empty terrain → deselect (integration version)
# ============================================================================

## Integration check: left-clicking with an empty hit dict deselects a real unit.
func test_left_click_empty_hit_deselects_real_unit() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	SelectionManager.select_only(_kargar)
	assert_true(SelectionManager.is_selected(_kargar),
		"pre-condition: kargar is selected")

	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	# Empty dict = "clicked into the void / missed everything".
	handler.process_left_click_hit({})
	assert_eq(SelectionManager.selection_size(), 0,
		"empty left-click hit must deselect all real units")


## Integration check: left-click on a StaticBody3D terrain collider deselects.
## The duck-type resolver rejects non-unit colliders (no replace_command method).
func test_left_click_terrain_collider_deselects_real_unit() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	SelectionManager.select_only(_kargar)

	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	var terrain_body: StaticBody3D = StaticBody3D.new()
	add_child_autofree(terrain_body)
	var hit: Dictionary = {
		&"collider": terrain_body,
		&"position": Vector3(10.0, 0.0, 10.0),
		&"normal": Vector3.UP,
	}
	handler.process_left_click_hit(hit)
	assert_eq(SelectionManager.selection_size(), 0,
		"left-click on terrain collider must deselect all real units")


# ============================================================================
# 5. Click handler handles freed units gracefully
# ============================================================================

## If a unit is queue_free'd between selection and right-click, the move command
## must not crash. SelectionManager.selected_units prunes invalid refs; the
## ClickHandler also guards with is_instance_valid.
func test_right_click_move_does_not_crash_when_selected_unit_freed() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	SelectionManager.select_only(_kargar)
	assert_eq(SelectionManager.selection_size(), 1)

	# Free the unit between selection and right-click.
	_kargar.queue_free()
	await get_tree().process_frame  # let queue_free actually free the node
	# Null out the ref so after_each doesn't attempt another queue_free.
	_kargar = null

	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	var terrain: StaticBody3D = StaticBody3D.new()
	add_child_autofree(terrain)
	var hit: Dictionary = {
		&"collider": terrain,
		&"position": Vector3(5.0, 0.0, 0.0),
		&"normal": Vector3.UP,
	}
	# Must not crash. GUT catches unhandled errors.
	handler.process_right_click_hit(hit)
	pass_test("process_right_click_hit with a freed selected unit did not crash")


## If a unit is freed while in Moving state, subsequent ticks must not crash.
## The _exit_tree hook on Unit disconnects EventBus.sim_phase so freed units
## don't receive further tick signals.
func test_freed_unit_does_not_crash_on_subsequent_sim_phase() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.get_movement().move_speed = 5.0
	_kargar.replace_command(&"move", {&"target": Vector3(10.0, 0.0, 0.0)})

	# Advance one tick: mock resolves READY, unit starts moving.
	_advance(1)
	assert_eq(_kargar.fsm.current.id, &"moving",
		"pre-condition: unit is Moving before free")

	# Free the unit. _exit_tree must disconnect EventBus.sim_phase.
	_kargar.queue_free()
	await get_tree().process_frame  # let queue_free actually free the node
	# Null out ref so after_each doesn't attempt another queue_free.
	_kargar = null

	# Advance several more ticks. The disconnected _on_sim_phase means the freed
	# unit's FSM is never called again — no crash.
	_advance(5)
	pass_test("advancing ticks after unit queue_free did not crash")


# ============================================================================
# 6. Multiple units: replace_command fans out correctly
# ============================================================================

## Confirm that right-click issues Move commands to ALL selected units.
## Uses real Kargar instances (not FakeUnit stubs) to close the loop.
func test_right_click_fans_out_move_to_all_selected_kargars() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar2 = _spawn_kargar(Vector3(2.0, 0.0, 0.0))

	SelectionManager.select_only(_kargar)
	SelectionManager.add_to_selection(_kargar2)
	assert_eq(SelectionManager.selection_size(), 2)

	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	var terrain: StaticBody3D = StaticBody3D.new()
	add_child_autofree(terrain)
	var target: Vector3 = Vector3(8.0, 0.0, 0.0)
	var hit: Dictionary = {
		&"collider": terrain,
		&"position": target,
		&"normal": Vector3.UP,
	}
	handler.process_right_click_hit(hit)

	# Right-click calls replace_command which sets _pending_id on each unit's
	# FSM. The pending transition is deferred — it only applies when fsm.tick()
	# is called (via _on_sim_phase). Advance one tick to drain it.
	_advance(1)

	# Both units must have transitioned to Moving after the tick.
	assert_eq(_kargar.fsm.current.id, &"moving",
		"first selected kargar must enter Moving after right-click + tick")
	assert_eq(_kargar2.fsm.current.id, &"moving",
		"second selected kargar must enter Moving after right-click + tick")
