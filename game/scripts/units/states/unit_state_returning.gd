class_name UnitState_Returning extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Returning — the Kargar worker's "carry back, deposit, loop" state.
##
## Source: 01_CORE_MECHANICS.md §3 (Iran economy — workers deliver to the
## Throne) + docs/RESOURCE_NODE_CONTRACT.md §5 (IDropoffTarget protocol) +
## 02f_PHASE_3_KICKOFF.md §3 (Phase 3 wave 1A deliverable 2).
##
## Lifecycle:
##   - enter(prev, ctx): cache movement, locate the deposit target (the
##     Throne for wave 1A; ResourceSystem.dropoff_for_team for wave 1B+),
##     issue request_repath toward it.
##   - _sim_tick(dt, ctx): drive movement until arrival; on arrival, run
##     the deposit (wave 1A: stub — just zero the carry; wave 1B wires
##     into ResourceSystem.add). Then loop back to Gathering with the
##     SAME target_node (gather-deposit-gather cycle).
##   - exit(): cancel in-flight repath.
##
## The deposit-stub seam (wave 1A vs wave 1B):
##   Wave 1A doesn't have a ResourceSystem autoload. The state's deposit
##   step is "zero the unit's _carry_* fields" — visible in headless tests
##   and inert in the live game (no HUD increment yet). Wave 1B's
##   ResourceSystem.add(team, kind, amount_x100) takes over the deposit
##   side; the state's call here changes to:
##     ResourceSystem.add(ctx.team, ctx.get(&"_carry_kind"),
##                        ctx.get(&"_carry_amount_x100"))
##   followed by the same zero-out. The seam is deliberately a no-op for
##   wave 1A so the integration tests (wave 3) can exercise the loop
##   topology without the autoload existing.
##
## The "Throne" lookup for wave 1A:
##   Phase 0/1/2 didn't ship a Throne building. Wave 1A doesn't either —
##   "deposit" means "transition back to Gathering at the same node." So
##   the state's deposit target IS the unit's own position (the gather
##   cycle is a small loop at the mine, not a back-and-forth across the
##   map). When the Throne ships (Phase 3 wave 1B or later), the deposit
##   target switches to the Throne's position via:
##     - Resource Node Contract §5.2: ResourceNode.get_dropoff_target(unit)
##       returns the Throne. Wave 1B adds this to MineNode.
##     - Or ResourceSystem.dropoff_for_team(team) when the autoload ships.
##
##   For wave 1A the payload carries an explicit `deposit_target` field
##   (a Vector3) that the Gathering state stuffs into the queued return
##   command. If absent, wave 1A falls back to "deposit at current
##   position" (no walk, immediate deposit + loop).
##
## id = &"returning". priority = 5 (same as Gathering — they're peers in
## the gather loop). interrupt_level = COMBAT (same as Gathering — damage
## interrupts the return; player commands always win).
##
## Cultural note (shahnameh-loremaster review 2026-05-14):
##   In the Shahnameh, the relationship between king and people is
##   reciprocal — the people offer tribute and labor to the seat of
##   royal power, and the just king's farr makes that tribute fruitful
##   for the realm. Workers depositing at the Throne is the gameplay
##   surfacing of that exchange: the Kargar's return-and-deposit beat
##   is not just resource bookkeeping but the moment the farr-bearing
##   king's authority gains material expression. See 01_CORE_MECHANICS.md
##   §3 (resources) + §4 (farr) — the latter is what gives the deposit
##   beat its meaning beyond accounting. Symmetry with sibling states
##   Gathering (people-of-the-soil labor) and Constructing (settled-life
##   anchoring) per CLAUDE.md "save design rationale alongside the code."

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")


var _movement: Variant = null

# Vector3 the worker walks back to. Wave 1A fallback: the worker's own
# position (zero-distance "return" — immediate deposit + loop). When a
# Throne ships, the payload carries the Throne's deposit marker position.
var _deposit_target_pos: Vector3 = Vector3.ZERO

# Latch for arrival — same pattern as Moving / Gathering / AttackMove.
var _arrival_pending: bool = false

# True if the deposit-step has already fired this entry. Defensive against
# the "no walk" / "instant arrival" path running the deposit twice.
var _deposited: bool = false

# The mine the gather loop is anchored on. After deposit completes, we
# transition back to Gathering with this Node as the target — sustains the
# loop without input layer intervention.
var _loop_target_node: Variant = null


func _init() -> void:
	id = &"returning"
	priority = 5
	interrupt_level = 1  # InterruptLevel.COMBAT


# Entry: cache movement, read deposit_target + loop target from payload,
# issue the path. Defensive bails on missing payload / no movement, same
# shape as Gathering's enter.
func enter(_prev: Object, ctx: Object) -> void:
	_movement = null
	_deposit_target_pos = Vector3.ZERO
	_arrival_pending = false
	_deposited = false
	_loop_target_node = null

	if ctx == null:
		push_warning("UnitState_Returning.enter: null ctx — bailing to idle")
		return

	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()
	if _movement == null:
		push_warning(
			"UnitState_Returning.enter: no MovementComponent on ctx — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	# Read payload.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})

	# Loop target (the mine the worker came from). Optional — without it
	# the worker idles after deposit instead of looping.
	var raw_loop: Variant = payload.get(&"target_node", null)
	if raw_loop != null and is_instance_valid(raw_loop) and raw_loop is Node:
		_loop_target_node = raw_loop

	# Deposit target. Three-tier resolution:
	#   1. Explicit payload Vector3 (test fixtures / scripted scenarios).
	#   2. Wave-3-Throne canonical: ResourceSystem.dropoff_for_team(team)
	#      → throne.get_deposit_position(). Workers VISIBLY walk to the
	#      Throne to complete the gather-deposit-loop cycle. This is the
	#      production path on `feat/wave-3throne-iran-turan-hq`.
	#   3. Zero-walk fallback to own position (no Throne spawned — test
	#      fixtures + pre-Throne-spawn boot).
	# BUG-E1 fix-wave (2026-05-24): tier 2 was missing in the original
	# Wave-3-Throne ship. `_perform_deposit()` correctly routed the credit
	# through `throne.deposit()`, but `enter()` left `_deposit_target_pos`
	# at the worker's own position, so the worker never visibly walked
	# to the Throne. The fix wires `get_deposit_position()` here so the
	# walk-step and the deposit-step both point at the Throne.
	var raw_deposit: Variant = payload.get(&"deposit_target", null)
	if raw_deposit != null and typeof(raw_deposit) == TYPE_VECTOR3:
		_deposit_target_pos = raw_deposit
	else:
		var team_for_dropoff: int = Constants.TEAM_NEUTRAL
		if &"team" in ctx:
			team_for_dropoff = int(ctx.team)
		var dropoff: Node3D = ResourceSystem.dropoff_for_team(team_for_dropoff)
		if dropoff != null and is_instance_valid(dropoff) \
				and dropoff.has_method(&"get_deposit_position"):
			_deposit_target_pos = dropoff.call(&"get_deposit_position")
		else:
			# Zero-walk fallback (test fixtures, pre-Throne-spawn boot).
			_deposit_target_pos = _get_self_position(ctx)

	# Kick off the path. If the deposit target is the unit's own position,
	# the request still fires (the path will arrive on a later tick at
	# distance 0; the arrival latch trips immediately). The simpler "skip
	# the walk entirely for zero-distance" optimization is a wave-1B pass.
	_movement.request_repath(_deposit_target_pos)


# Per-tick: drive movement, detect arrival, run deposit, loop back to
# Gathering. Same arrival-latch pattern as Moving / Gathering / AttackMove.
func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null:
		return

	_movement._sim_tick(dt)

	var path_state: int = _movement.path_state
	if path_state == _IPathScheduler.PathState.FAILED \
			or path_state == _IPathScheduler.PathState.CANCELLED:
		push_warning(
			"UnitState_Returning: path resolution failed (state=%d, deposit_target=%s); "
			% [path_state, str(_deposit_target_pos)]
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	if path_state == _IPathScheduler.PathState.READY:
		_arrival_pending = true
	if not (_arrival_pending and not _movement.is_moving):
		return  # still walking

	# Arrived. Deposit step (wave 1A: stub — clear carry).
	if not _deposited:
		_perform_deposit(ctx)
		_deposited = true

	# Loop back to Gathering with the SAME target_node, or transition to
	# Idle if the mine is gone (depleted / freed).
	if _loop_target_node != null and is_instance_valid(_loop_target_node):
		# Check the mine is still gatherable. If it depleted while we were
		# walking back, transition to Idle instead of looping into a
		# guaranteed-failed gather.
		var gatherable: Variant = _loop_target_node.get(&"is_gatherable")
		if typeof(gatherable) == TYPE_BOOL and bool(gatherable):
			# Stuff a new gather command into current_command so Gathering's
			# enter() reads the right target. We bypass append_command +
			# transition_to_next because we want the explicit
			# transition_to(&"gathering") path — no queue contention with
			# a Shift-queued follow-up the player may have layered on.
			if &"current_command" in ctx:
				ctx.current_command = {
					"kind": &"gather",
					"payload": {&"target_node": _loop_target_node},
				}
			if &"fsm" in ctx and ctx.fsm != null:
				ctx.fsm.transition_to(&"gathering")
			return
	# Mine gone / depleted — fall through to Idle. Idle's _sim_tick is a
	# no-op (mesh pulse only); the next player command picks the worker up.
	_request_idle(ctx)


# Wave 1B deposit (Wave-3-Throne refactor) — routes the carry through the
# canonical IDropoffTarget path when a Throne exists for the worker's team;
# falls back to the inline `ResourceSystem.change_resource` chokepoint call
# when no Throne is present (test fixtures, pre-Throne-spawn boot).
#
# Mirror C1.4 disambiguation (Wave-3-Throne brief v1.0.2): ONLY ONE path
# calls `change_resource` per deposit cycle:
#   - Throne-present path: `throne.deposit(kind, amount_x100, worker)` —
#     the Throne owns the chokepoint call internally per RNC §5.2.
#     Returning passes the worker as the source_unit for telemetry symmetry.
#   - Throne-absent path: this state's inline `change_resource(...)` call
#     (preserved exactly as wave 1B shipped — test fixtures that don't
#     spawn a Throne continue to work).
# The exclusion is mandatory: calling both paths would double-credit the
# deposit. The if/else structure below enforces this by construction.
#
# Sim-tick mutation through chokepoint is allowed (Sim Contract §1.3): this
# state's _sim_tick is driven by the unit's StateMachine which is itself
# driven by EventBus.sim_phase. Whether the chokepoint call lives in this
# function (Throne-absent fallback) or inside Throne.deposit (Throne-present
# canonical path), the on-tick assert is satisfied by construction.
#
# Source reference: 01_CORE_MECHANICS.md §1 + §2 + §5 (Iran/Turan each starts
# with one Throne; loss = defeat; workers deliver resources to the Throne);
# docs/RESOURCE_NODE_CONTRACT.md §5 (IDropoffTarget protocol — deposit +
# get_deposit_position canonical method signatures).
func _perform_deposit(ctx: Object) -> void:
	if ctx == null:
		return
	# Read carry. _carry_kind is the StringName resource kind (KIND_COIN /
	# KIND_GRAIN); _carry_amount_x100 is the fixed-point amount the worker is
	# returning with. Both were written by UnitState_Gathering on
	# complete_extract (gathering.gd):
	var kind: Variant = ctx.get(&"_carry_kind") if &"_carry_kind" in ctx else &""
	var amount_x100: Variant = ctx.get(&"_carry_amount_x100") if &"_carry_amount_x100" in ctx else 0
	# Defensive: if the carry is empty (zero-walk return with no extract,
	# stale-carry edge case) skip the deposit. Calling change_resource with
	# amount_x100 == 0 would emit a delta-zero signal which is noisy on the
	# HUD's poll path; cheaper to bail.
	if typeof(kind) == TYPE_STRING_NAME and kind != &"" \
			and typeof(amount_x100) == TYPE_INT and int(amount_x100) > 0:
		# Resolve team from the unit. Defensive default: TEAM_NEUTRAL — but
		# a worker with no team is a bug condition; the team field is
		# set on spawn for every unit.
		var team: int = Constants.TEAM_NEUTRAL
		if &"team" in ctx:
			team = int(ctx.team)
		# Wave-3-Throne canonical RNC §5.2 routing.
		# ResourceSystem.dropoff_for_team is Pitfall-#16-safe (validates
		# is_instance_valid before return); the further has_method check
		# here is belt-and-braces against a future non-Throne &"thrones"
		# group member (impossible at MVP but cheap to guard).
		var dropoff: Node3D = ResourceSystem.dropoff_for_team(team)
		if dropoff != null and is_instance_valid(dropoff) \
				and dropoff.has_method(&"deposit"):
			# Throne-present path. Throne.deposit owns the chokepoint
			# call internally; we do NOT call change_resource here.
			# C1.4 only-one-path enforced.
			dropoff.call(&"deposit", kind, int(amount_x100), ctx)
		else:
			# Throne-absent fallback (test fixtures, pre-spawn). Preserve
			# the wave 1B inline call exactly as shipped.
			ResourceSystem.change_resource(
				team, kind, int(amount_x100), &"gather_deposit", ctx)
	# Zero the carry via set(). Same rationale as Gathering's carry-write —
	# we're inside the unit's _sim_tick path (the on-tick discipline applies
	# by construction).
	if &"_carry_kind" in ctx:
		ctx.set(&"_carry_kind", &"")
	if &"_carry_amount_x100" in ctx:
		ctx.set(&"_carry_amount_x100", 0)


# Exit: cancel any in-flight repath. Same pattern as Moving.
func exit() -> void:
	if _movement != null:
		var rid: int = int(_movement._request_id)
		if rid != -1 and _movement._scheduler != null:
			_movement._scheduler.cancel_repath(rid)
			_movement._request_id = -1
	_movement = null
	_loop_target_node = null
	_arrival_pending = false
	_deposited = false


func _get_self_position(ctx: Object) -> Vector3:
	if ctx == null:
		return Vector3.ZERO
	if &"global_position" in ctx:
		return ctx.global_position
	return Vector3.ZERO


func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")
