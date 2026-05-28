class_name UnitState_Gathering extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Gathering — the Kargar worker's "walk to node, dwell, extract" state.
##
## Source: 01_CORE_MECHANICS.md §3 (Iran economy — workers gather from map
## nodes) + docs/RESOURCE_NODE_CONTRACT.md §4 (three-call API consumer view)
## + 02f_PHASE_3_KICKOFF.md §3 (Phase 3 wave 1A deliverable 1).
##
## Cultural note: the worker (کارگر / kargar) embodies the foundational
## RTS archetype — and in Shahnameh, the labor of the people of the soil
## is the substrate every dynasty rests on. The gather loop is the first
## visible expression of that — small, repetitive, undramatic, and yet
## without it Iran has nothing to spend.
##
## State machinery contract (docs/STATE_MACHINE_CONTRACT.md §3):
##   - enter(prev, ctx): resolve the target node from current_command, kick
##     off movement toward it, prepare the dwell timer.
##   - _sim_tick(dt, ctx): drive movement until arrival, then request a slot
##     and dwell; on dwell-completion, complete the extract, populate the
##     unit's carry, and transition to Returning.
##   - exit(): cancel in-flight repath; release the slot if we hold one.
##     Resource Node Contract §4.1: "release_extract always called even on
##     death." Defensive — death-preempt may exit() us with a slot grabbed.
##
## id = &"gathering" — LOAD-BEARING per Open Space sync (ARCHITECTURE.md §6
## v0.20.0). The Farr-drain dispatcher (Phase 3 wave 1B) reads current.id
## at unit-death time to distinguish gather-death (drain -0.5) from
## idle-death (drain -1.0). Do NOT rename this StringName. The dispatcher
## must read the id BEFORE the FSM swaps to Dying (subscribe to
## EventBus.unit_health_zero pre-preempt, OR latch last_alive_state_id
## before swap) — that's wave 1B's concern, but the id is the contract.
##
## interrupt_level = COMBAT (1):
##   Phase 3 wave 1A has no auto-attack stances (Open Space resolved
##   stance=PASSIVE by default for Phase 3). A worker getting shot at while
##   gathering: damage interrupts the gather. The unit transitions to
##   Dying via the death-preempt path if the damage kills; otherwise the
##   state continues. (Phase 6's defensive stance adds counter-attack
##   triggers; not in scope here.)
##
##   Player commands always win regardless of interrupt_level — a
##   right-click new target during gather replaces the queue and dispatches
##   into Moving / Attacking (Contract §3.5).
##
## priority = 5: above Idle (0), below Moving (10) and AttackMove (15).
##   No competing transitions in Phase 3 — the priority field doesn't
##   currently arbitrate anything for Gathering, but we keep the value
##   ordered consistently with the rest of the FSM for future-self.
##
## Payload shape (read off ctx.current_command.payload):
##   { target_node: Node } where target_node is a ResourceNode (MineNode in
##   wave 1A; Mazra'eh in wave 1B+).
##
##   Why Node ref (not id) for wave 1A:
##   The kickoff doc references `target_node_id` for forward-compat with a
##   future ResourceNodeRegistry autoload (analogous to the proposed
##   UnitRegistry per LATER L1). Wave 1A doesn't have such a registry; the
##   Node ref is the simplest forward-compat seam — the input layer (wave
##   1B's click handler) passes a Node ref, the state reads it directly.
##   When the registry ships, swap to id-based lookup with a fall-through
##   to ref (or migrate both call sites at once). Both producer and consumer
##   of the payload are in this project; we control the migration window.
##
## Carry storage (`_carry_kind` and `_carry_amount_x100` on the Kargar):
##   The carry payload from complete_extract gets written to two fields on
##   the unit — `_carry_kind: StringName` and `_carry_amount_x100: int`
##   (fixed-point per Sim Contract §1.6). These fields live on Unit (added
##   in this wave alongside the state). UnitState_Returning reads them on
##   exit at the Throne; the input layer / debug overlay may also read for
##   UI feedback (wave 1B's HUD wire-up).

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")

# Cached references — set in enter, cleared in exit.
var _movement: Variant = null
var _target_node: Variant = null

# Latch for arrival detection. Mirrors UnitState_Moving / _AttackMove.
var _arrival_pending: bool = false

# True when we've successfully requested a slot at the mine. Drives the
# dwell-tick loop and the release_extract path on exit.
var _slot_held: bool = false

# Sim-tick countdown for the dwell. Initialized from target_node.extract_ticks
# at request-success time. When this hits 0, complete_extract fires and we
# transition to Returning.
var _dwell_remaining_ticks: int = 0


func _init() -> void:
	id = &"gathering"  # LOAD-BEARING — see header. Open Space v0.20.0.
	priority = 5
	interrupt_level = 1  # InterruptLevel.COMBAT


# Entry: cache movement, read target_node from current_command, request the
# path. Defensive bails (no movement, missing target, dead target, wrong type)
# all transition immediately to Idle with a warning — mirrors UnitState_Moving's
# defensive structure.
func enter(_prev: Object, ctx: Object) -> void:
	_movement = null
	_target_node = null
	_arrival_pending = false
	_slot_held = false
	_dwell_remaining_ticks = 0
	_cached_unit_id = -1

	if ctx == null:
		push_warning("UnitState_Gathering.enter: null ctx — bailing to idle")
		return

	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()
	if _movement == null:
		push_warning(
			"UnitState_Gathering.enter: no MovementComponent on ctx — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	# Read target_node off current_command. Same shape as Moving's enter.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})
	if not payload.has(&"target_node"):
		push_warning(
			"UnitState_Gathering.enter: current_command.payload has no "
			+ "`target_node`; transitioning to idle"
		)
		_request_idle(ctx)
		return
	var raw_target: Variant = payload[&"target_node"]
	# Validate the ref. is_instance_valid catches the queue_free'd mine case;
	# the has-method check catches "wrong type accidentally passed in".
	if raw_target == null \
			or not is_instance_valid(raw_target) \
			or not (raw_target is Node) \
			or not raw_target.has_method(&"request_extract"):
		push_warning(
			"UnitState_Gathering.enter: target_node is invalid / not a "
			+ "ResourceNode; transitioning to idle"
		)
		_request_idle(ctx)
		return
	_target_node = raw_target
	_movement.request_repath((_target_node as Node3D).global_position)


# Per-tick: drive movement during walk; on arrival, request slot; dwell;
# complete; transition to Returning.
func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null or _target_node == null:
		return
	# Defensive: target may have queue_free'd mid-trip (depleted by another
	# worker, or destroyed). Bail to Idle — Phase 6 auto-retarget belongs to
	# the AI controller, not the state (Resource Node Contract §9 #1).
	if not is_instance_valid(_target_node):
		_request_idle(ctx)
		return

	# Walking phase: drive the MovementComponent. Same pattern as Moving and
	# AttackMove. The future MovementSystem coordinator (LATER L2) takes over
	# this drive call when it ships.
	_movement._sim_tick(dt)

	# Path failure → bail. Worker couldn't reach the mine; no auto-retry.
	var path_state: int = _movement.path_state
	if path_state == _IPathScheduler.PathState.FAILED \
			or path_state == _IPathScheduler.PathState.CANCELLED:
		push_warning(
			"UnitState_Gathering: path resolution failed (state=%d, target=%s); "
			% [path_state, str((_target_node as Node3D).global_position)]
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	# Latch arrival on READY. Mirrors Moving / AttackMove arrival pattern.
	if path_state == _IPathScheduler.PathState.READY:
		_arrival_pending = true
	if not (_arrival_pending and not _movement.is_moving):
		return  # still walking — try again next tick

	# Arrived. Two sub-phases: request the slot if we don't have one, then
	# count down dwell.
	if not _slot_held:
		var unit_id: int = int(ctx.unit_id)
		var granted: bool = _target_node.request_extract(unit_id)
		if not granted:
			# Slot rejected (max_slots taken by another worker, or node depleted
			# between enter and arrival). Two distinct sub-cases:
			#   1. Node depleted (is_gatherable flipped false) → bail to Idle
			#      so the worker isn't stuck waiting on a dead node forever.
			#   2. Node still gatherable, slot just busy → WAIT next to it,
			#      retry next sim_phase. This is the AoE2-style queue: with
			#      max_slots=1 (Phase 3 wave 1A simplification), multi-select
			#      gather sends all workers to the same node and they queue
			#      sequentially. Pre-fix, all but the first bailed to Idle and
			#      sat there permanently — the user could not see any gather
			#      progress after the first carry.
			# Live-test 2026-05-24 (BUG-F1) surfaced this: multi-selected
			# workers gathered visibly but only the slot-holder walked back
			# to the Throne; everyone else sat silently in Idle. The code
			# comment at this site explicitly anticipated this fix
			# ("Wave 1B can add a 'wait next to the node' sub-state if
			# playtest shows the bail is too aggressive").
			var still_gatherable: bool = bool(_target_node.is_gatherable)
			if not still_gatherable:
				push_warning(
					"UnitState_Gathering: slot rejected at %s for unit %d, "
					% [str((_target_node as Node3D).global_position), unit_id]
					+ "node not gatherable — transitioning to idle"
				)
				_request_idle(ctx)
				return
			# Throttle the [gather] log so the queue doesn't flood — one line
			# per second per waiting worker is enough for diagnosis. SIM_HZ=30,
			# so log every 30 ticks. We don't have a tick counter on the state,
			# but SimClock.tick is available via the autoload.
			if int(SimClock.tick) % 30 == 0:
				print("[gather] unit=", unit_id,
					" waiting for slot at mine ",
					(_target_node as Node3D).global_position)
			return  # stay in Gathering, retry next sim_phase
		_slot_held = true
		_cached_unit_id = unit_id
		# Initialize dwell from the node's extract_ticks (per-kind config;
		# wave 1A: hardcoded constant on MineNode).
		_dwell_remaining_ticks = int(_target_node.extract_ticks)
		# Edge case: extract_ticks == 0 means "one-tick extract" — we still
		# need at least one tick of waiting before complete fires, otherwise
		# the player can't perceive the gather as a gather. Bump to 1.
		if _dwell_remaining_ticks <= 0:
			_dwell_remaining_ticks = 1

	# Dwell countdown.
	_dwell_remaining_ticks -= 1
	if _dwell_remaining_ticks > 0:
		return  # still dwelling

	# Dwell complete — pull the carry payload. This decrements reserves on
	# the node and frees our slot (complete_extract is double-release-safe
	# with the exit() release path).
	var payload: Dictionary = _target_node.complete_extract(int(ctx.unit_id))
	# §9.M6 — gather-completion event log. One-shot per gather cycle (per-tick
	# dwell countdown is silent; only the completion fires this print).
	print("[gather] unit_id=%d completed kind=%s amount_x100=%d" % [
		int(ctx.unit_id),
		str(payload.get(&"kind", &"")),
		int(payload.get(&"amount_x100", 0))])
	# Mark the slot as no longer held so exit() doesn't double-release
	# (release_extract is idempotent but the slot is gone).
	_slot_held = false
	_cached_unit_id = -1
	# Carry must be written to the unit BEFORE we transition — Returning's
	# enter() reads it for the deposit step.
	var carry_kind: StringName = payload.get(&"kind", &"")
	var carry_amount: int = int(payload.get(&"amount_x100", 0))
	# Write carry to the unit. Unit base class added _carry_kind and
	# _carry_amount_x100 fields in this wave. set() is fine here — we're
	# inside the unit's _sim_tick (the on-tick discipline applies even
	# though Unit isn't a SimNode; the discipline is preserved by
	# construction since this writer is only ever called from _sim_tick).
	if &"_carry_kind" in ctx:
		ctx.set(&"_carry_kind", carry_kind)
	if &"_carry_amount_x100" in ctx:
		ctx.set(&"_carry_amount_x100", carry_amount)

	# Queue a return command, then transition. We use the standard dispatch
	# path: push a &"return" command onto the queue (no wave-1A consumer
	# for the queue beyond Returning itself), but the state machine maps
	# &"return" → &"returning" via the COMMAND_KIND_TO_STATE_ID dict.
	# However, that mapping doesn't exist yet — Phase 3 wave 1A adds it
	# alongside this state. Simpler path: stash the next-state's payload on
	# ctx.current_command directly, then transition_to(&"returning"). The
	# state machine's transition_to wins regardless of the queue's state.
	# UnitState_Returning's enter() reads ctx.current_command.payload for
	# the same reason Moving / AttackMove do.
	#
	# We pass the same target_node so Returning knows which mine to loop
	# back to once the deposit is done (the gather loop). The Throne lookup
	# happens inside Returning's enter — wave 1A uses a scene-tree walk; wave
	# 1B uses ResourceSystem.dropoff_for_team.
	if &"current_command" in ctx:
		ctx.current_command = {
			"kind": &"return",
			"payload": {
				&"target_node": _target_node,
				&"carry_kind": carry_kind,
				&"carry_amount_x100": carry_amount,
			},
		}
	if &"fsm" in ctx and ctx.fsm != null:
		ctx.fsm.transition_to(&"returning")


# Exit: cancel in-flight repath; release the slot if we still hold one.
# Resource Node Contract §4.1 — "release_extract always called even on death."
# Idempotent on the node side (release of an unowned slot is a no-op), so
# the exit path can call unconditionally.
func exit() -> void:
	if _movement != null:
		var rid: int = int(_movement._request_id)
		if rid != -1 and _movement._scheduler != null:
			_movement._scheduler.cancel_repath(rid)
			_movement._request_id = -1
	# Release the slot. _slot_held is the latch — but we also call
	# release_extract unconditionally as belt-and-braces, since
	# release_extract is documented as idempotent for the death-path
	# (Contract §4.1).
	if _target_node != null and is_instance_valid(_target_node):
		# Read the unit_id off ctx — but we don't have ctx in exit(). The
		# convention across the codebase (see UnitState_Moving / Attacking
		# exit) is to use the cached refs only. We need a way to get the
		# unit_id without ctx.
		#
		# Workaround: cache the unit_id at slot-grant time. This avoids
		# the API contortion of passing ctx through exit. The cached value
		# is the only thing exit needs from the unit; everything else is
		# torn down on the unit side by the StateMachine framework.
		if _slot_held and _cached_unit_id != -1:
			_target_node.release_extract(_cached_unit_id)
	_movement = null
	_target_node = null
	_arrival_pending = false
	_slot_held = false
	_dwell_remaining_ticks = 0
	_cached_unit_id = -1


# Cached unit_id for the exit() release_extract path. Set when we grab a
# slot in _sim_tick (the same place that flips _slot_held true). Reset on
# exit. We could read ctx.unit_id directly in _sim_tick, but caching here
# means exit() needs no ctx parameter (the base State signature is exit() ->
# void; passing ctx would break the polymorphism).
var _cached_unit_id: int = -1


# Override needed: _sim_tick wraps the slot-grab in a helper so the
# cached unit_id is set in the same place we flip _slot_held. Kept inline
# above for legibility; this comment documents the invariant: _slot_held
# == true implies _cached_unit_id != -1.


func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")
