class_name UnitState_Moving extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Moving — the unit is walking toward a target Vector3.
##
## Per docs/STATE_MACHINE_CONTRACT.md §3.4 / §6.2 worked example:
##   - enter(prev, ctx) reads `ctx.current_command["payload"]["target"]`
##     (a Vector3) and calls `ctx.get_movement().request_repath(target)`.
##     The path scheduler is non-blocking; the result lands on a later tick.
##   - _sim_tick(dt, ctx) drives `ctx.get_movement()._sim_tick(dt)`. This is
##     wave 1's "the unit also needs a _sim_tick driver" note made concrete:
##     until the MovementSystem phase coordinator lands (see LATER items in
##     wave 1 retro / BUILD_LOG), the Moving state IS the per-tick driver
##     for MovementComponent. When the phase coordinator ships, this driving
##     call moves out of Moving's _sim_tick and into the coordinator; Moving
##     then only checks `is_moving` for arrival.
##   - On arrival (MovementComponent.is_moving false after a tick where it
##     was previously true, OR the path resolved FAILED / CANCELLED), the
##     state calls `ctx.fsm.transition_to_next()`. The StateMachine framework
##     either dispatches the next queued command (Shift+click queue) or
##     transitions to Idle.
##   - exit() cancels any in-flight path request via the MovementComponent's
##     scheduler. Defensive — the typical exit reason is the player issued
##     a new command (replace_command), which by State Machine Contract §3.5
##     means we must clean up before the new state's enter runs.
##
## interrupt_level: COMBAT — non-combat movement is interruptible by damage.
## Per the contract enum: NONE=damage doesn't interrupt; COMBAT=damage
## interrupts; NEVER=damage cannot interrupt at all (only player commands +
## death). Moving is COMBAT because a worker walking past an enemy doesn't
## need to be the kind of "thick-skinned" that NEVER implies; if the
## combat system later wants to flip this to NONE for "casual" movement,
## the change is a one-line edit. Player replace_command always wins
## regardless of interrupt_level (Contract §3.5).
##
## Failure handling:
##   If MovementComponent reports FAILED (no path exists — common on day-1
##   when units can be commanded outside the navmesh; rare in production
##   once the navmesh is well-configured), we transition_to_next() with a
##   push_warning. Same primitive as a successful arrival — concrete
##   "give up and idle" is what the player will see, which is the right
##   default for MVP.
##
## Lifecycle (in order):
##   1. enter():
##      a. Cache references: movement = ctx.get_movement().
##      b. Read target from ctx.current_command.payload.target. Defensive:
##         if no current_command (we got here via direct transition_to,
##         not via transition_to_next), bail to Idle with a warning.
##      c. movement.request_repath(target).
##      d. Reset _arrival_pending — we haven't ticked the movement yet, so
##         is_moving may be false until the path resolves and waypoints
##         are loaded.
##   2. _sim_tick():
##      a. movement._sim_tick(dt) — drives the per-tick path resolution
##         and position-stepping.
##      b. After the tick, check movement state:
##         - If path_state is FAILED → transition_to_next, push_warning.
##         - If path is READY and we've started moving (is_moving became
##           true), set _arrival_pending = true.
##         - If _arrival_pending is true and is_moving is false (we
##           consumed the last waypoint), transition_to_next.
##   3. exit():
##      a. If movement still has an in-flight request, cancel it via
##         movement._scheduler.cancel_repath(movement._request_id).
##         Defensive — see contract §3.5.

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")


# Cached MovementComponent ref. Set in enter; cleared in exit. Untyped per
# project-wide class_name registry race convention.
var _movement: Variant = null

# Latched once the unit has been observed *moving* during this state's
# tenure. Without this latch we can't distinguish "haven't started yet"
# (is_moving == false because path is still PENDING) from "just arrived"
# (is_moving == false because the last waypoint was consumed). The latch
# flips true on the first tick where is_moving was true; arrival is
# detected by the next is_moving == false reading.
var _arrival_pending: bool = false

# Most recent target requested. Used for diagnostic logs and to detect
# repeated requests to the same target (an idempotent re-issue is harmless).
var _target: Vector3 = Vector3.ZERO


func _init() -> void:
	id = &"moving"
	priority = 10
	# InterruptLevel.COMBAT — damage interrupts non-combat movement. See
	# the rationale block at the top of this file.
	interrupt_level = 1  # InterruptLevel.COMBAT


# Entry: read target off ctx.current_command, kick off the path request.
#
# `ctx.current_command` is populated by StateMachine.transition_to_next()
# (see state_machine.gd) before we get here. Shape:
#   { "kind": StringName, "payload": Dictionary }
# Move commands carry `payload.target` as a Vector3 per State Machine
# Contract §2.4 / §6.2 worked example.
func enter(_prev: Object, ctx: Object) -> void:
	_movement = null
	_arrival_pending = false
	if ctx == null:
		push_warning("UnitState_Moving.enter: null ctx — bailing to idle")
		return

	# Resolve the MovementComponent. ctx may be a Unit (which exposes
	# get_movement()) or a stub fixture in tests; we accept either shape.
	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()
	if _movement == null:
		push_warning("UnitState_Moving.enter: no MovementComponent on ctx — transitioning to idle")
		_request_idle(ctx)
		return

	# Read target off ctx.current_command. If the dispatch wasn't via
	# transition_to_next (e.g., a direct transition_to(&"moving") with no
	# command stash), there's nothing to move toward — bail.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})
	if not payload.has(&"target"):
		push_warning(
			"UnitState_Moving.enter: current_command.payload has no `target`; transitioning to idle")
		_request_idle(ctx)
		return
	var target_raw: Variant = payload[&"target"]
	if typeof(target_raw) != TYPE_VECTOR3:
		push_warning(
			"UnitState_Moving.enter: payload.target is not a Vector3; transitioning to idle")
		_request_idle(ctx)
		return

	_target = target_raw
	_movement.request_repath(_target)


# Per-tick: drive the MovementComponent and watch for completion.
#
# Until the MovementSystem phase coordinator lands (a LATER item per
# wave 1's retro), Moving's _sim_tick *is* the per-tick driver for
# MovementComponent. When the coordinator ships:
#   - The coordinator iterates registered MovementComponents and calls
#     their _sim_tick during the `movement` phase.
#   - Moving's _sim_tick stops calling movement._sim_tick directly and
#     instead just polls movement.is_moving / movement.path_state.
# This single-line refactor is documented in BUILD_LOG / wave-2 retro.
func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null:
		return

	# Drive the movement component. Same code path as the future phase
	# coordinator will use — Moving just calls it directly for now.
	_movement._sim_tick(dt)

	# Check for path failure. FAILED is sticky in MovementComponent (the
	# scheduler returned no path and we cleared in-flight handles). Bail
	# back to whatever's queued, or Idle.
	var path_state: int = _movement.path_state
	if path_state == _IPathScheduler.PathState.FAILED \
			or path_state == _IPathScheduler.PathState.CANCELLED:
		push_warning(
			"UnitState_Moving: path resolution failed (state=%d, target=%s); transitioning"
			% [path_state, str(_target)])
		_request_next(ctx)
		return

	# Latch _arrival_pending once we've ingested a path. The path is
	# ingested on the first tick where the scheduler reports READY — at
	# which point the MovementComponent has waypoints and either is_moving
	# is true (more waypoints to consume) or it instantly arrived in a
	# single tick (huge move_speed or short distance). Either way, "we
	# have a path" is the correct latch condition.
	#
	# Why latch at all (rather than just check is_moving every tick):
	# between enter() (which calls request_repath but doesn't load
	# waypoints — the scheduler is non-blocking) and the first _sim_tick
	# that polls READY, is_moving is false because there are no waypoints
	# yet. Without the latch we'd immediately transition back to Idle on
	# the entry tick, never having moved. The latch flips on path arrival
	# and stays on; arrival is then detected by the next is_moving == false
	# reading.
	if path_state == _IPathScheduler.PathState.READY:
		_arrival_pending = true
	if _arrival_pending and not _movement.is_moving:
		# Path was loaded and we've consumed all waypoints — arrival.
		# Dispatch into whatever's queued next (or Idle).
		_request_next(ctx)


# Exit: cancel any in-flight repath request. Defensive cleanup per
# Contract §3.5. The typical exit cause is the player issuing a new
# command via Unit.replace_command (which clears the queue, pushes a
# fresh Command, and calls transition_to_next — landing us on the new
# state directly). Cancelling here means the scheduler doesn't keep an
# orphaned PENDING request alive past the state's lifetime.
#
# Note: MovementComponent.request_repath ALSO cancels the prior request,
# so canceling here is technically redundant for the common case. We
# still cancel explicitly because:
#   (a) The next state may not be Moving (could be Attacking, Constructing,
#       Idle, etc.) — and those states won't issue their own repath that
#       would shadow ours.
#   (b) Explicit cleanup is cheaper than reasoning about "did the next
#       state happen to call request_repath?" and matches the contract's
#       intent of states owning their own teardown.
func exit() -> void:
	if _movement != null:
		var rid: int = int(_movement._request_id)
		if rid != -1 and _movement._scheduler != null:
			_movement._scheduler.cancel_repath(rid)
			# Reset the in-flight handle so MovementComponent doesn't poll a
			# cancelled request next tick.
			_movement._request_id = -1
	_movement = null
	_arrival_pending = false


# Helpers to dispatch. _request_idle is the early-bail path for "we can't
# even start the move." _request_next is the standard-completion path that
# either dispatches the next queued command or lands on Idle.

func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")


func _request_next(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to_next()
