# Tests for UnitState_Dying.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §3.5 (interrupt levels), §4 (death
# preempt). The state ships in Phase 2 session 1 wave 3 as the BUG-03 fix —
# StateMachine._on_unit_health_zero force-transitions into &"dying" but the
# state was previously unregistered, so the unit was never queue_freed.
#
# Coverage:
#   - id == &"dying", priority == 100, interrupt_level == 2 (NEVER).
#   - enter() calls queue_free.call_deferred on the owning ctx.
#   - enter() with null/invalid ctx is a no-op (defensive).
#   - Registered on a real Unit, the death-preempt EventBus path frees the unit.
#
# Typing: Variant slots — docs/ARCHITECTURE.md §6 v0.4.0 class_name registry race.
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/unit.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateDyingScript: Script = preload(
	"res://scripts/units/states/unit_state_dying.gd"
)


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	SimClock.reset()
	CommandPool.reset()


# ---------------------------------------------------------------------------
# Shape: id / priority / interrupt_level
# ---------------------------------------------------------------------------

func test_dying_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateDyingScript.new()
	assert_eq(s.id, &"dying", "Dying.id is &\"dying\"")
	assert_eq(s.priority, 100,
		"Dying.priority is 100 (top of the pile, above Attacking's 20)")
	assert_eq(s.interrupt_level, 2,
		"Dying.interrupt_level is 2 (NEVER) — death cannot be interrupted")


# ---------------------------------------------------------------------------
# enter(): defensive guards
# ---------------------------------------------------------------------------

func test_enter_with_null_ctx_is_noop() -> void:
	# Defensive: enter() must tolerate null ctx (matches the rest of the
	# state framework's null-guard convention).
	var s: Variant = UnitStateDyingScript.new()
	# No assertion needed — we just want this to not crash.
	s.enter(null, null)
	pass_test("Dying.enter(null, null) is a safe no-op")


func test_enter_with_freed_ctx_is_noop() -> void:
	# Defensive: ctx may have been freed between the death-preempt firing
	# and Dying.enter running. is_instance_valid guards the call.
	var s: Variant = UnitStateDyingScript.new()
	var n: Node = Node.new()
	n.queue_free()
	await get_tree().process_frame
	s.enter(null, n)
	pass_test("Dying.enter on a freed ctx is a safe no-op")


# ---------------------------------------------------------------------------
# enter(): schedules queue_free
# ---------------------------------------------------------------------------

func test_enter_schedules_queue_free_on_unit() -> void:
	# Spawn a real Unit, run enter() against it as ctx, and assert that
	# after one process_frame the unit is no longer a valid instance.
	var u: Variant = UnitScene.instantiate()
	u.unit_type = &"piyade"
	add_child_autofree(u)
	assert_true(is_instance_valid(u), "pre-condition: unit is valid")

	var s: Variant = UnitStateDyingScript.new()
	s.enter(null, u)

	# call_deferred queue_free runs at the next idle tick of the scene tree.
	await get_tree().process_frame
	# After the deferred free fires, the unit should be queued for deletion.
	# is_instance_valid returns false once the underlying object is freed.
	assert_false(is_instance_valid(u),
		"Unit must be freed after Dying.enter + one process_frame "
		+ "(queue_free.call_deferred ran)")


# ---------------------------------------------------------------------------
# Integration: full death-preempt chain frees the unit
# ---------------------------------------------------------------------------

func test_unit_health_zero_signal_frees_unit_via_dying_state() -> void:
	# Verify the full chain: EventBus.unit_health_zero →
	# StateMachine._on_unit_health_zero → _apply_transition(&"dying") →
	# UnitState_Dying.enter → queue_free.call_deferred → unit freed.
	var u: Variant = UnitScene.instantiate()
	u.unit_type = &"piyade"
	add_child_autofree(u)
	# Wait for _ready so the FSM is set up and connected to EventBus.
	await get_tree().process_frame
	assert_true(is_instance_valid(u), "pre-condition: unit is valid after _ready")
	assert_true(u.fsm._states.has(&"dying"),
		"pre-condition: dying state must be registered (BUG-03 fix)")

	# Fire the death-preempt signal directly. StateMachine listens for it.
	EventBus.unit_health_zero.emit(int(u.unit_id))

	# Allow the deferred queue_free to land.
	await get_tree().process_frame
	assert_false(is_instance_valid(u),
		"Unit must be freed after EventBus.unit_health_zero fires for its id")
