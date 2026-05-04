class_name StateMachine extends RefCounted
##
## StateMachine — flat FSM, used by both unit FSMs and AI controllers.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.3 / §3 / §4 / §7.
##
## Shape:
##   - States are registered at spawn (one allocation per state per unit)
##     and re-used for the unit's lifetime.
##   - `current` is always non-null after init().
##   - Transitions request via `transition_to(id)`; the swap happens after
##     the current `_sim_tick` returns. Re-entry into the swap loop is
##     bounded by Constants.STATE_MACHINE_TRANSITIONS_PER_TICK (4) to contain
##     runaway chains.
##   - `transition_to_next()` is the dispatcher — pops the front of
##     ctx.command_queue (if present) and transitions to the matching state;
##     else transitions to Idle.
##   - Death preempts any state regardless of interrupt_level via the
##     `EventBus.unit_health_zero` signal.
##
## Why RefCounted, not Node: a 50-vs-50 battle is 100 StateMachines. Putting
## them in the scene tree adds Node overhead per unit (process callbacks,
## tree notifications) we don't need. The unit's `_sim_tick` calls
## `fsm.tick(dt)` once per simulation tick, which is the only entry point.

# Owning unit / controller. Used to read command_queue, unit_id, etc.
var ctx: Object = null

# state_id (StringName) -> State instance. Populated by register() at spawn.
var _states: Dictionary = {}

# Active state. Never null after init().
#
# Untyped (Variant) instead of `State` class_name to avoid a Godot resolve-
# order issue: when GUT loads test scripts whose inner classes extend
# state.gd by path-string, the `State` class_name reference here can fail
# to resolve during early parse. The behavior is the same — only the
# annotation is loosened.
var current: Variant = null

# Pending transition target. &"" means no pending transition.
var _pending_id: StringName = &""

# Transition history ring buffer. Each entry is a Dictionary with shape
# { from: StringName, to: StringName, tick: int, reason: StringName }.
# Capacity from Constants.STATE_MACHINE_HISTORY_SIZE_UNIT (16).
var _history: Array = []
var _history_head: int = 0
var _history_size: int = 0
var _history_capacity: int = Constants.STATE_MACHINE_HISTORY_SIZE_UNIT

# Map from Command.kind to State.id. Used by transition_to_next() to dispatch
# the next queued command into the right work state. The mapping is fixed
# for MVP per Contract §3.4. New command kinds add a row here when they ship.
const _COMMAND_KIND_TO_STATE_ID: Dictionary = {
	&"move": &"moving",
	&"attack": &"attacking",
	&"attack_move": &"attack_move",  # Phase 2 session 1 wave 2B
	&"gather": &"gathering",
	&"build": &"moving",        # build → walk to site → constructing (rider)
	&"ability": &"casting",
}


func _init() -> void:
	_history.resize(_history_capacity)


## Configure history ring capacity. Defaults to STATE_MACHINE_HISTORY_SIZE_UNIT
## (16). AI controllers should call this with STATE_MACHINE_HISTORY_SIZE_AI
## (64) at construction.
func set_history_capacity(n: int) -> void:
	_history_capacity = n
	_history.clear()
	_history.resize(n)
	_history_head = 0
	_history_size = 0


## Register a state. Called once per state at unit spawn. The state's
## `id` field is the dictionary key; subclasses set it in their constructor.
##
## Parameter typed loosely as Object (rather than `State`) for the same
## class_name resolve-order reason documented on `current`.
func register(state: Object) -> void:
	assert(state != null, "StateMachine.register: null state")
	assert(state.id != &"", "StateMachine.register: state.id is empty — subclass must set it")
	_states[state.id] = state


## Initialize with the given starting state id. Sets current, calls enter()
## on it, and connects the death-preempt signal handler. Must be called
## after all states are registered.
func init(initial_id: StringName) -> void:
	assert(_states.has(initial_id),
		"StateMachine.init: unknown state id '%s' (registered: %s)" %
		[initial_id, _states.keys()])
	current = _states[initial_id]
	current.enter(null, ctx)
	# Subscribe to death preempt. State Machine Contract §4.2.
	# We connect lazily here so a StateMachine without a ctx (constructed for
	# tests in isolation) can still init. The connection is tracked so we
	# can disconnect on owner free if needed.
	EventBus.unit_health_zero.connect(_on_unit_health_zero)


## Per-tick entry point. The owning Unit/Controller calls this from its own
## _sim_tick. Runs current._sim_tick, then drains pending transitions in a
## bounded loop (max STATE_MACHINE_TRANSITIONS_PER_TICK).
func tick(dt: float) -> void:
	if current == null:
		return
	current._sim_tick(dt, ctx)
	# Drain pending transitions. The bound contains accidental cycles
	# (state A → enter sets pending B → enter sets pending A → ...).
	var swaps: int = 0
	while _pending_id != &"" and swaps < Constants.STATE_MACHINE_TRANSITIONS_PER_TICK:
		var target_id: StringName = _pending_id
		_pending_id = &""
		_apply_transition(target_id, &"requested")
		swaps += 1
	if _pending_id != &"":
		# We hit the bound with more pending — log and clear, since infinite
		# transition chains are a programming error per Contract §3.3.
		push_warning("StateMachine: pending transition chain exceeded %d swaps; dropping '%s'" %
			[Constants.STATE_MACHINE_TRANSITIONS_PER_TICK, _pending_id])
		_pending_id = &""


## Request a transition to `target_id`. Deferred — the swap happens at the
## end of the current tick (or end of enter() chain). Multiple calls in the
## same tick: the LAST one wins (Contract §3.3 — state's own _sim_tick is
## the only valid caller, so collisions don't happen in practice).
func transition_to(target_id: StringName) -> void:
	assert(_states.has(target_id),
		"StateMachine.transition_to: unknown state id '%s'" % target_id)
	_pending_id = target_id


## Dispatch into the next queued command on ctx.command_queue, or Idle if
## the queue is empty. Per Contract §3.4 — the canonical "I'm done"
## helper that states call on completion.
##
## Stashing the dispatched command on ctx.current_command:
##   The Command is returned to the CommandPool immediately after we read
##   its kind/payload (so the pool can re-rent the instance). Concrete states
##   that need the payload (UnitState_Moving reading `target: Vector3`,
##   UnitState_Attacking reading `target_unit: Node`, etc.) get it via
##   ctx.current_command, populated here as a defensive Dictionary copy.
##   See unit.gd's `current_command` field for the slot's contract.
##
##   When the queue is empty we transition to Idle and clear current_command
##   so a subsequent Idle._sim_tick can't accidentally read a stale payload.
func transition_to_next() -> void:
	if ctx == null or not (&"command_queue" in ctx) or ctx.command_queue == null:
		# Defensive: in tests we may run a StateMachine with a stub ctx that
		# has no queue. Default to Idle.
		_clear_current_command()
		transition_to(&"idle")
		return
	var queue = ctx.command_queue
	# `next_cmd` is a Command (RefCounted with kind and payload) but typed
	# as Variant to dodge the class_name resolve race documented elsewhere.
	var next_cmd = queue.peek()
	if next_cmd == null:
		_clear_current_command()
		transition_to(&"idle")
		return
	queue.pop()
	# Stash a defensive copy of kind/payload on ctx so the receiving state's
	# enter() can read it. The Command itself is returned to the pool below;
	# holding a ref would race with the pool re-renting the same instance.
	var state_id: StringName = _state_for_command(next_cmd.kind)
	_set_current_command(next_cmd.kind, next_cmd.payload)
	CommandPool.return_to_pool(next_cmd)
	transition_to(state_id)


# Stash on ctx if it has a current_command field; harmless no-op for stub
# ctx in unit tests of the framework that don't expose the field. Note: we
# use direct `set` rather than `_set_sim` because current_command is a
# StateMachine-internal dispatch slot, not a SimNode field — it's mutated
# only by transition_to_next, which runs inside the unit's _sim_tick anyway.
func _set_current_command(kind: StringName, payload: Dictionary) -> void:
	if ctx == null:
		return
	if not (&"current_command" in ctx):
		return
	ctx.current_command = {"kind": kind, "payload": payload.duplicate()}


func _clear_current_command() -> void:
	if ctx == null:
		return
	if not (&"current_command" in ctx):
		return
	ctx.current_command = {}


## Live alias for the F3 debug overlay and AI legibility helpers.
func current_state_name() -> StringName:
	if current == null:
		return &""
	return current.id


## Snapshot of the transition history ring, oldest-first. Useful for tests
## and for the F3 overlay to render the last N transitions.
func transition_history() -> Array:
	var out: Array = []
	for i in range(_history_size):
		var idx: int = (_history_head + i) % _history_capacity
		out.append(_history[idx])
	return out


# === Internals ==============================================================

# Run the full transition: prev.exit(), swap current, current.enter(prev, ctx),
# emit telemetry, record history.
func _apply_transition(target_id: StringName, reason: StringName) -> void:
	# `prev` is untyped (Variant) to avoid class_name resolution issues when
	# this script is loaded by GUT before the global registry is populated.
	# `current` is the typed State property at the script top.
	var prev = current
	if prev != null:
		prev.exit()
	current = _states[target_id]
	# Note: per Contract §4.2 the death-preempt handler clears _pending_id
	# explicitly. Normal transitions don't preset _pending_id; enter() may
	# re-set it for chained dispatch.
	current.enter(prev, ctx)
	_record_history(prev.id if prev != null else &"", target_id, reason)
	# Emit transition telemetry. unit_id is read off ctx if available.
	var unit_id: int = -1
	if ctx != null and &"unit_id" in ctx:
		unit_id = int(ctx.unit_id)
	EventBus.unit_state_changed.emit(unit_id,
		prev.id if prev != null else &"",
		target_id,
		SimClock.tick)


# Map a command kind to the state id that should run it.
func _state_for_command(kind: StringName) -> StringName:
	if _COMMAND_KIND_TO_STATE_ID.has(kind):
		return _COMMAND_KIND_TO_STATE_ID[kind]
	# Unknown command kind — defensive default to idle.
	push_warning("StateMachine: no state mapping for command kind '%s'" % kind)
	return &"idle"


# Append to the ring history. Entries are dictionaries to keep tests and
# overlay rendering ergonomic; struct-typed shape is documented above.
func _record_history(from_id: StringName, to_id: StringName, reason: StringName) -> void:
	var entry: Dictionary = {
		"from": from_id,
		"to": to_id,
		"tick": SimClock.tick,
		"reason": reason,
	}
	if _history_size < _history_capacity:
		var idx: int = (_history_head + _history_size) % _history_capacity
		_history[idx] = entry
		_history_size += 1
	else:
		# Ring full — overwrite the head, advance head.
		_history[_history_head] = entry
		_history_head = (_history_head + 1) % _history_capacity


# === Death preemption (Contract §4) =========================================

# Force-transition to Dying regardless of interrupt_level. Cancels any
# in-flight pending transition. Single-tick guarantee: the handler runs
# inside the combat phase, so cleanup observes the dying transition the
# same tick.
func _on_unit_health_zero(unit_id: int) -> void:
	if ctx == null or not (&"unit_id" in ctx):
		return
	if int(ctx.unit_id) != unit_id:
		return
	if current != null and current.id == &"dying":
		return
	if not _states.has(&"dying"):
		# Defensive: a unit without a Dying state can't be force-killed.
		# This is a configuration error — log loudly so we notice.
		push_error("StateMachine: unit %d received unit_health_zero but has no 'dying' state" % unit_id)
		return
	# Cancel any in-flight pending transition; Dying wins.
	_pending_id = &""
	_apply_transition(&"dying", &"death_preempt")
