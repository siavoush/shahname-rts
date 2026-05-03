class_name UnitState_AttackMove extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_AttackMove — walk to a target, engage anything in ENGAGE_RADIUS
## along the way, resume after kill.
##
## Per docs/STATE_MACHINE_CONTRACT.md §3.4 / §3.5 / §6.2 and the Phase 2
## session-1 kickoff §2 deliverable 4.
##
## Composition strategy:
##   The move logic is identical to UnitState_Moving — request_repath on
##   enter(), drive _movement._sim_tick each tick, transition_to_next on
##   arrival. The new behavior is per-tick `SpatialIndex.query_radius_team`
##   for opposing-team enemies in ENGAGE_RADIUS; if found, the state queues a
##   resume-AttackMove with the original target (so transition_to_next from
##   Attacking re-enters AttackMove cleanly when the enemy dies) and
##   transitions to Attacking with the discovered enemy as target_unit_id.
##
## Why a separate state (not a flag on Moving):
##   - Different `interrupt_level`: AttackMove is committed engagement
##     movement (NEVER) so damage doesn't yank the unit out mid-charge,
##     whereas Moving is COMBAT-interruptible (worker walking past combat
##     dives off-path on damage). Keeping the levels separate means the
##     contract is legible without conditional branches.
##   - The per-tick spatial query is a non-trivial cost; gating it in a
##     dedicated state means workers / non-combat moves never pay for it.
##   - Clean re-entry semantics: transition_to_next looks up
##     COMMAND_KIND_TO_STATE_ID[&"attack_move"] = &"attack_move" so the
##     resume-after-kill cycle is just a queue push, not a Moving-vs-
##     AttackMove disambiguation.
##
## Resume-after-kill mechanic (the trickiest piece):
##   When _sim_tick discovers an enemy and decides to transition to Attacking,
##   it does the following BEFORE the transition_to(&"attacking") call:
##     1. Build a resume command:
##          { kind = COMMAND_ATTACK_MOVE, payload = { target = <original_target> } }
##     2. Push it onto ctx.command_queue (NOT replace_command — replace_command
##        clears the queue and immediately requests transition_to_next, which
##        would compete with our explicit transition_to(&"attacking")).
##     3. Build the Attack command:
##          { kind = COMMAND_ATTACK, payload = { target_unit_id = <enemy_id> } }
##     4. Insert it at the FRONT of the queue (push_front) so it dispatches
##        BEFORE the resume-AttackMove. We then call transition_to_next
##        instead of transition_to(&"attacking") — the queue's head IS the
##        Attack command; transition_to_next will read its payload, stash it
##        on ctx.current_command, and dispatch into Attacking via the standard
##        kind→state_id mapping.
##   When Attacking exits (target dead → transition_to_next), the queue's
##   head is now our resume-AttackMove. Standard dispatch re-enters this
##   state with the original target.
##
## interrupt_level: NEVER — same as Attacking. The unit is committed to the
## engage-or-arrive cycle; player commands (replace_command) and death are
## the only interrupts. Per State Machine Contract §3.5 player commands
## ALWAYS win regardless of interrupt_level.
##
## priority: 15 — between Moving's 10 and Attacking's 20. AttackMove
## preempts Moving (a worker shift-queueing an attack-move after a move
## inherits the more-committed behavior); Attacking preempts AttackMove
## (the engage transition is downstream of the engagement check, not a
## priority comparison).
##
## Lifecycle:
##   enter(prev, ctx):
##     - Read target: Vector3 from ctx.current_command.payload.target.
##     - Cache movement reference, request_repath toward target.
##     - Reset _arrival_pending latch.
##     - Defensive bails: missing payload → idle, malformed target → idle,
##       no MovementComponent → idle. Same shape as UnitState_Moving.
##
##   _sim_tick(dt, ctx):
##     1. Drive movement: same call as Moving. Sets _arrival_pending on READY.
##     2. Check for path failure: FAILED/CANCELLED → transition_to_next.
##     3. Check for arrival: latched + !is_moving → transition_to_next.
##     4. If we're still moving and haven't transitioned: query the spatial
##        index for opposing-team enemies in ENGAGE_RADIUS. If any:
##          a. Sort by squared distance, take the closest.
##          b. Build resume-AttackMove command on the queue (back).
##          c. Build Attack command on the queue front.
##          d. transition_to_next — the standard dispatcher pops the front
##             (Attack), stashes payload on ctx.current_command, lands in
##             Attacking with the enemy id ready.
##
##   exit():
##     - Cancel any in-flight repath. Same shape as Moving.exit.
##
## Coordination notes:
##   - Reads SpatialIndex.query_radius_team — relies on opposing-team agents
##     being registered. Test setup must call SpatialIndex._rebuild() after
##     spawning units; production rebuilds automatically each tick.
##   - Reads the OPPOSING_TEAM derived from ctx.team:
##       team == TEAM_IRAN → opposing = TEAM_TURAN
##       team == TEAM_TURAN → opposing = TEAM_IRAN
##       else → TEAM_ANY (defensive — neutral / future factions engage all
##              non-self teams; this is a Phase 2 placeholder until the
##              alliance system lands).
##   - The query returns SpatialAgentComponent nodes. The actual Unit is
##     `agent.get_parent()` per SpatialAgentComponent's contract.

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")


# Cached MovementComponent ref. Same convention as UnitState_Moving.
var _movement: Variant = null

# Original move target — kept verbatim so the resume-AttackMove command
# carries the same target the player issued, not a stale snapshot of the
# unit's current position.
var _target: Vector3 = Vector3.ZERO

# Latch for arrival detection. Mirrors UnitState_Moving's _arrival_pending.
# Flips true on first READY tick; arrival fires when latched + is_moving false.
var _arrival_pending: bool = false


func _init() -> void:
	id = &"attack_move"
	priority = 15  # between Moving's 10 and Attacking's 20
	# InterruptLevel.NEVER — engagement movement is committed. Same as Attacking.
	interrupt_level = 2  # InterruptLevel.NEVER


func enter(_prev: Object, ctx: Object) -> void:
	_movement = null
	_arrival_pending = false
	_target = Vector3.ZERO

	if ctx == null:
		push_warning("UnitState_AttackMove.enter: null ctx — bailing to idle")
		return

	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()
	if _movement == null:
		push_warning(
			"UnitState_AttackMove.enter: no MovementComponent on ctx — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	# Read target off ctx.current_command. Same shape as Moving's enter.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})
	if not payload.has(&"target"):
		push_warning(
			"UnitState_AttackMove.enter: current_command.payload has no "
			+ "`target`; transitioning to idle"
		)
		_request_idle(ctx)
		return
	var target_raw: Variant = payload[&"target"]
	if typeof(target_raw) != TYPE_VECTOR3:
		push_warning(
			"UnitState_AttackMove.enter: payload.target is not a Vector3; "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	_target = target_raw
	_movement.request_repath(_target)


func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null:
		return

	# Drive movement. Same as Moving — until the MovementSystem phase
	# coordinator ships, the state owns the per-tick driver.
	_movement._sim_tick(dt)

	# Path failure → fall through to next command (or Idle).
	var path_state: int = _movement.path_state
	if path_state == _IPathScheduler.PathState.FAILED \
			or path_state == _IPathScheduler.PathState.CANCELLED:
		push_warning(
			"UnitState_AttackMove: path resolution failed (state=%d, target=%s); "
			% [path_state, str(_target)]
			+ "transitioning"
		)
		_request_next(ctx)
		return

	# Latch arrival on READY.
	if path_state == _IPathScheduler.PathState.READY:
		_arrival_pending = true
	if _arrival_pending and not _movement.is_moving:
		# Arrived at target. Same dispatch as Moving.
		_request_next(ctx)
		return

	# Engage check: any opposing-team enemy in ENGAGE_RADIUS?
	var enemy: Object = _find_engage_target(ctx)
	if enemy == null:
		return

	# Found one. Queue resume-AttackMove (so the unit returns to its travel
	# after the kill), then push Attack at the front of the queue and
	# transition_to_next — the standard dispatcher hands off to Attacking
	# with the enemy id stashed on ctx.current_command.
	if not _enqueue_resume_and_attack(ctx, enemy):
		return  # defensive — couldn't queue, stay in AttackMove


# === Internal helpers =====================================================

# Find the closest opposing-team enemy within Constants.ENGAGE_RADIUS of
# the unit's position. Returns null if none in range.
#
# Returns the actual Unit (agent.get_parent()), not the SpatialAgentComponent,
# so callers can read the unit_id directly. Filters out invalid / freed
# agents and units defensively.
func _find_engage_target(ctx: Object) -> Object:
	if ctx == null:
		return null
	var self_pos: Vector3 = _get_self_position(ctx)
	var opposing: int = _opposing_team(int(ctx.get(&"team")))
	var radius: float = Constants.ENGAGE_RADIUS
	# Defensive: SpatialIndex is an autoload; if absent (shouldn't happen) the
	# query call would error. Fast-fail rather than crash.
	var hits: Array = SpatialIndex.query_radius_team(self_pos, radius, opposing)
	if hits.is_empty():
		return null
	# Closest-first by squared XZ distance. Determinism is fine — Array sort
	# is stable across platforms in Godot 4.
	var best: Object = null
	var best_dist_sq: float = INF
	for agent in hits:
		if agent == null or not is_instance_valid(agent):
			continue
		var unit: Node = agent.get_parent()
		if unit == null or not is_instance_valid(unit):
			continue
		# Skip self defensively — query results may include the source if it's
		# also registered under the queried team filter (it shouldn't be, since
		# we're filtering for the OPPOSING team, but the guard is cheap).
		if unit == ctx:
			continue
		var pos: Vector3 = unit.global_position
		var dx: float = pos.x - self_pos.x
		var dz: float = pos.z - self_pos.z
		var d_sq: float = dx * dx + dz * dz
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = unit
	return best


# Queue a resume-AttackMove and an Attack command, then transition_to_next.
# Returns true on success; false on a command-queue or transition failure
# (defensive — caller stays in AttackMove on false).
func _enqueue_resume_and_attack(ctx: Object, enemy: Object) -> bool:
	if ctx == null:
		return false
	# Queue the resume command at the BACK so it fires AFTER the Attack.
	# append_command (Unit method, see unit.gd §State Machine Contract §2.5)
	# is the sanctioned write path; it doesn't trigger transition_to_next.
	if ctx.has_method(&"append_command"):
		ctx.append_command(
			Constants.COMMAND_ATTACK_MOVE,
			{&"target": _target},
		)
	else:
		return false
	# Push the Attack command to the FRONT of the queue, then transition_to_next.
	# transition_to_next pops the front, stashes payload on ctx.current_command,
	# and dispatches to Attacking via the kind→state_id mapping. This matches
	# the standard command-dispatch path and keeps the resume-after-kill
	# mechanic legible.
	#
	# We use direct queue push_front + manual command construction here because
	# the "append at front + transition" combination doesn't have a single
	# Unit-level helper. The CommandPool rent + push_front is the canonical
	# AI-panic-insertion pattern (per State Machine Contract §2.4 / §2.5);
	# attack-move's engage discovery is morally the same — an interruption
	# from the unit's own state, not an external player command, that wants
	# the next state RIGHT NOW with stable queue semantics for the resume.
	if not (&"command_queue" in ctx) or ctx.command_queue == null:
		return false
	var attack_cmd: Command = CommandPool.rent()
	attack_cmd.kind = Constants.COMMAND_ATTACK
	attack_cmd.payload = {&"target_unit_id": int(enemy.get(&"unit_id"))}
	ctx.command_queue.push_front(attack_cmd)
	# Hand off to the dispatcher. transition_to_next reads the queue head,
	# stashes payload, and lands us in Attacking with target_unit_id ready.
	if &"fsm" in ctx and ctx.fsm != null:
		ctx.fsm.transition_to_next()
	return true


# Translate a unit's team to the team it should engage. Phase 2 is binary
# Iran ↔ Turan. Neutral (or future factions) engage anyone — TEAM_ANY.
# Replace this with an alliance-table lookup when Phase 4+ ships factions
# beyond Iran/Turan.
func _opposing_team(self_team: int) -> int:
	if self_team == Constants.TEAM_IRAN:
		return Constants.TEAM_TURAN
	if self_team == Constants.TEAM_TURAN:
		return Constants.TEAM_IRAN
	return Constants.TEAM_ANY


func _get_self_position(ctx: Object) -> Vector3:
	if ctx == null:
		return Vector3.ZERO
	if &"global_position" in ctx:
		return ctx.global_position
	return Vector3.ZERO


func exit() -> void:
	if _movement != null:
		var rid: int = int(_movement._request_id)
		if rid != -1 and _movement._scheduler != null:
			_movement._scheduler.cancel_repath(rid)
			_movement._request_id = -1
	_movement = null
	_arrival_pending = false


func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")


func _request_next(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to_next()
