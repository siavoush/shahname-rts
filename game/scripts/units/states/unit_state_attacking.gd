class_name UnitState_Attacking extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Attacking — the unit is engaging an enemy unit.
##
## Per docs/STATE_MACHINE_CONTRACT.md §3.4 / §3.5 / §6.2 and the Phase 2
## session-1 kickoff §2 deliverable 2.
##
## Lifecycle:
##   - enter(prev, ctx): reads `target_unit_id: int` from
##     `ctx.current_command.payload.target_unit_id`. Looks up the target Unit
##     via a scene-tree walk (matches `unit_id == target_id`). Caches the
##     target, the CombatComponent, and the MovementComponent for per-tick
##     reads. Defensive bail to Idle on any of: missing payload, missing
##     target_unit_id, target lookup miss, freed target — same shape as
##     UnitState_Moving's no-target bail.
##   - _sim_tick(dt, ctx):
##       (a) If the cached target is freed (queue_freed during the
##           previous tick), `transition_to_next` and we're done.
##       (b) Compute XZ distance from self to target.
##       (c) If distance > attack_range: drive
##           `MovementComponent.request_repath(target.global_position)` so
##           the unit walks toward the target. Re-issued each tick — if the
##           target moves, the unit re-paths automatically. Per-tick
##           re-request cost is fine for Phase 2 (15 units max). When unit
##           counts grow past ~50 (Phase 3+), switch to a stale-distance
##           threshold or a per-N-ticks throttle.
##       (d) If distance ≤ attack_range: stop driving movement (cancel any
##           in-flight repath via the scheduler) and call
##           `combat.set_target(target.unit_id)`. CombatComponent's own
##           _sim_tick handles damage/cooldown firing per Phase 2 kickoff
##           §2 deliverable 1.
##   - exit(): defensive cleanup. `combat.set_target(-1)` so the
##     CombatComponent doesn't keep firing at the prior target after the
##     state ends. Cancel any in-flight repath so the scheduler doesn't
##     keep an orphaned PENDING request alive. Same shape as
##     UnitState_Moving.exit.
##
## Per State Machine Contract §3.5, INTERRUPT_NEVER blocks damage-driven
## preemption only — player commands (`replace_command`) and death always
## win. priority=20 sits above Moving's 10: when both are valid same tick,
## Attacking takes precedence (relevant for the future attack-move state's
## engage transition).
##
## Coordination notes (Phase 2 session 1):
##   - CombatComponent.attack_range and CombatComponent.set_target ship in
##     gameplay-systems' parallel wave 1A. Both are read defensively here
##     via has_method / property checks, so this state's commit can land
##     whether or not wave 1A is committed first. When CombatComponent is
##     missing entirely, the state still functions: out-of-range targets
##     drive movement, in-range targets are no-ops on the combat side
##     (push_warning surfaces the missing wiring).
##   - Target lookup walks the scene tree from `get_tree().current_scene`,
##     matching `unit_id == target_id`. For Phase 2's 15-unit cap this is
##     fine. LATER item: a `UnitRegistry` autoload (id → ref dict) closes
##     the cost out at O(1) — surface when unit counts grow past ~100.
##   - `_sim_tick` does NOT emit any signals; CombatComponent / HealthComponent
##     own the unit_died / damage emissions per the cb95d09 re-entrant
##     signal recursion lesson (Known Pitfall #4).

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")


# Cached target unit ref. Set in enter; cleared in exit. Untyped (Variant)
# per the registry-race convention used by other state files.
var _target: Variant = null

# Cached CombatComponent ref. Set in enter; cleared in exit.
var _combat: Variant = null

# Cached MovementComponent ref. Set in enter; cleared in exit.
var _movement: Variant = null


func _init() -> void:
	id = &"attacking"
	priority = 20  # above Moving's 10 — attack preempts move
	# InterruptLevel.NEVER — damage doesn't interrupt the attack itself.
	# Only player commands or death do (Contract §3.5).
	interrupt_level = 2  # InterruptLevel.NEVER


# Entry: read target_unit_id off ctx.current_command, resolve to a live Unit,
# cache the target + combat + movement refs.
#
# Defensive bails to Idle on any of:
#   - null ctx
#   - no current_command stash (direct transition_to(&"attacking") without
#     command dispatch — same shape as UnitState_Moving's defensive bail)
#   - payload missing target_unit_id
#   - target_unit_id doesn't resolve to a live Unit in the scene
func enter(_prev: Object, ctx: Object) -> void:
	_target = null
	_combat = null
	_movement = null

	if ctx == null:
		push_warning("UnitState_Attacking.enter: null ctx — bailing to idle")
		return

	# Resolve combat / movement components. CombatComponent may not exist
	# yet (gameplay-systems parallel wave); we tolerate its absence — the
	# state still drives movement, just no actual damage fires.
	if ctx.has_method(&"get_combat"):
		_combat = ctx.get_combat()
	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()

	# Read target_unit_id off ctx.current_command. If the dispatch wasn't via
	# transition_to_next (no stashed command), bail. Same defensive shape as
	# UnitState_Moving's no-payload bail.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})
	if not payload.has(&"target_unit_id"):
		push_warning(
			"UnitState_Attacking.enter: current_command.payload has no "
			+ "`target_unit_id`; transitioning to idle")
		_request_idle(ctx)
		return
	var target_id_raw: Variant = payload[&"target_unit_id"]
	if typeof(target_id_raw) != TYPE_INT:
		push_warning(
			"UnitState_Attacking.enter: payload.target_unit_id is not an int; "
			+ "transitioning to idle")
		_request_idle(ctx)
		return
	var target_id: int = int(target_id_raw)

	# Resolve the target Unit by id. Scene-tree walk is fine at Phase 2's
	# 15-unit cap; LATER item is a UnitRegistry autoload (see file header).
	var found: Variant = _find_unit_by_id(ctx, target_id)
	if found == null or not is_instance_valid(found):
		push_warning(
			"UnitState_Attacking.enter: target_unit_id=%d does not resolve "
			% target_id
			+ "to a live Unit; transitioning to idle")
		_request_idle(ctx)
		return

	_target = found


# Per-tick:
#   1. If target was freed since last tick: transition_to_next.
#   2. Compute XZ distance to target.
#   3. If out of attack_range: drive request_repath toward target's current pos.
#   4. If in attack_range: cancel in-flight repath, drive combat.set_target.
func _sim_tick(_dt: float, ctx: Object) -> void:
	# Step 1: target validity. queue_freed targets become invalid on the
	# tick after free, which is how dying targets exit combat.
	if _target == null or not is_instance_valid(_target):
		_request_next(ctx)
		return

	# Step 2: distance. XZ-only projection — same convention as SpatialIndex.
	var attack_range: float = _read_attack_range()
	var range_sq: float = attack_range * attack_range
	var self_pos: Vector3 = _get_self_position(ctx)
	var target_pos: Vector3 = _target.global_position
	var dx: float = target_pos.x - self_pos.x
	var dz: float = target_pos.z - self_pos.z
	var dist_sq: float = dx * dx + dz * dz

	if dist_sq > range_sq:
		# Step 3: out of range — walk toward target. Re-issue each tick so a
		# moving target stays tracked. The scheduler cancels prior in-flight
		# requests internally on each new request, so this is safe.
		if _movement != null:
			_movement.request_repath(target_pos)
		return

	# Step 4: in range — stop driving movement, hand off to CombatComponent.
	# Cancel any in-flight repath so MovementComponent doesn't keep stepping
	# the unit's position toward stale waypoints while we attack.
	_cancel_in_flight_repath()
	if _combat != null and _combat.has_method(&"set_target"):
		_combat.set_target(int(_target.unit_id))


# Exit: defensive cleanup. Clear combat target so CombatComponent doesn't
# keep firing at the prior target after this state ends. Cancel any
# in-flight repath so the scheduler doesn't keep an orphaned PENDING
# request alive past the state's lifetime. Same shape as
# UnitState_Moving.exit.
func exit() -> void:
	if _combat != null and _combat.has_method(&"set_target"):
		_combat.set_target(-1)
	_cancel_in_flight_repath()
	_target = null
	_combat = null
	_movement = null


# === Internal helpers ======================================================

# Look up a Unit by unit_id via a scene-tree walk. Returns null if no match.
# Uses the active scene as the search root (`get_tree().current_scene`),
# same root the box-select handler walks for unit-shaped Node3Ds.
#
# LATER: a UnitRegistry autoload would let this be O(1). At Phase 2's 15
# units the linear walk costs nothing; revisit at 100+ units.
func _find_unit_by_id(ctx: Object, target_id: int) -> Variant:
	if ctx == null or not ctx.has_method(&"get_tree"):
		return null
	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		return null
	var root: Node = tree.current_scene
	if root == null:
		# Tests may run units under the GUT scene root rather than a custom
		# current_scene; fall back to the tree root.
		root = tree.root
	if root == null:
		return null
	return _search_for_unit(root, target_id)


# Recursive scene-tree walk. Returns the first Node whose `unit_id` field
# matches target_id. Skips nodes without the field.
func _search_for_unit(node: Node, target_id: int) -> Variant:
	if &"unit_id" in node and int(node.get(&"unit_id")) == target_id:
		return node
	for child in node.get_children():
		var found: Variant = _search_for_unit(child, target_id)
		if found != null:
			return found
	return null


# Read attack_range off the cached CombatComponent. Defensive default of 1.5
# (melee) when the component is missing — mirrors the Phase 2 Piyade default
# from kickoff §2 deliverable 5. The push_warning makes the missing-wiring
# case visible without crashing the live game.
func _read_attack_range() -> float:
	if _combat == null:
		push_warning(
			"UnitState_Attacking: no CombatComponent on unit — using default "
			+ "attack_range=1.5; combat will not actually fire")
		return 1.5
	if not (&"attack_range" in _combat):
		push_warning(
			"UnitState_Attacking: CombatComponent has no `attack_range` field — "
			+ "using default 1.5")
		return 1.5
	return float(_combat.attack_range)


# Read self position from ctx (the owning unit). ctx is a Unit (CharacterBody3D)
# in production; in tests it may be a stub Node3D.
func _get_self_position(ctx: Object) -> Vector3:
	if ctx == null:
		return Vector3.ZERO
	if &"global_position" in ctx:
		return ctx.global_position
	return Vector3.ZERO


# Cancel any in-flight repath request on the cached MovementComponent.
# Mirrors UnitState_Moving.exit's cleanup. Idempotent — cancelling a
# CANCELLED or unknown request is a no-op on both schedulers.
func _cancel_in_flight_repath() -> void:
	if _movement == null:
		return
	var rid: int = int(_movement._request_id)
	if rid != -1 and _movement._scheduler != null:
		_movement._scheduler.cancel_repath(rid)
		_movement._request_id = -1


# Standard-completion path: dispatch the next queued command (or land in
# Idle if the queue is empty). Mirrors UnitState_Moving._request_next.
func _request_next(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to_next()


# Defensive bail for the early-error case (no payload / unresolved target).
# Same shape as UnitState_Moving._request_idle — direct transition_to(&"idle").
func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")
