class_name UnitState_Constructing extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Constructing — Kargar worker's "walk to site, dwell, place" state.
##
## Source: 01_CORE_MECHANICS.md §5 (Iran buildings — workers construct) +
## 02f_PHASE_3_KICKOFF.md §3 wave 1C deliverable 3 (placement state
## skeleton — INSTANT placement on arrival; session 2 adds the
## in-progress construction timer + progress bar).
##
## Cultural note: the worker (کارگر / kargar) constructing the home
## (خانه / khaneh) is the visible expression of settled life that
## defines the Iran side in the Shahnameh's worldview — kingdoms are
## what they BUILD, not just whom they defeat. Mirrors Jamshid's
## tool-and-hall era, Fereydun's halls of state.
##
## State machinery contract (docs/STATE_MACHINE_CONTRACT.md §3):
##   - enter(prev, ctx): resolve building_kind + target_position from
##     current_command, kick off movement toward the site, prepare the
##     dwell counter.
##   - _sim_tick(dt, ctx): drive movement until arrival, then dwell;
##     on dwell-complete, instantiate the Building scene, place it,
##     deduct the cost via ResourceSystem.change_resource, then
##     transition back to Idle.
##   - exit(): cancel in-flight repath. If interrupted mid-dwell
##     before placement, no refund (worker died / redirected before
##     placement completed — same loss-pattern as gather-trip-death
##     per Open Space sync; documented in this state's body).
##
## id = &"constructing" — LOAD-BEARING per Constants.STATE_CONSTRUCTING.
## A future Farr-drain-on-construction-death key would dispatch on this
## id; do NOT rename without coordinating with FarrDrainDispatcher.
##
## priority = 5: same band as Gathering / Returning (the worker's
## "doing-a-task" states). No competing transitions; the priority
## field doesn't currently arbitrate for this state.
##
## interrupt_level = COMBAT (1):
##   Same rationale as Gathering — damage interrupts construction.
##   Player commands always win (Contract §3.5) — right-clicking a
##   new target mid-construction abandons the build and walks to the
##   new target, no refund.
##
## Payload shape (read off ctx.current_command.payload):
##   {
##     building_kind: StringName,    e.g., &"khaneh"
##     target_position: Vector3,     world-space placement point
##   }
##
##   building_kind is the BalanceData.buildings key. The state looks up
##   the cost from BalanceData and the scene PackedScene from a small
##   internal lookup table (no autoload registry yet; one entry per
##   concrete building shipping in Phase 3 session 1).
##
## Cost-deduction timing (LOAD-BEARING):
##   The Coin cost is deducted at PLACEMENT TIME — when the building
##   actually appears on the map — NOT at command-dispatch time when
##   the player clicks. Rationale:
##     1. The player can cancel the construct command (right-click
##        elsewhere) between dispatch and arrival without losing the
##        Coin — same UX precedent as SC2 / AoE.
##     2. The build menu UI does NOT pre-deduct; it just checks
##        affordability at dispatch time and rejects if insufficient.
##     3. If the worker dies en route, the Coin is NOT refunded — but
##        also NOT deducted (it was never deducted in the first place).
##        Net: dying en route is the player's loss of the worker, not
##        the cost.
##   Wave 1B's UnitState_Returning has the analogous timing for the
##   deposit: it credits at arrival, not at start-of-walk.
##
## Construction-in-progress: NOT in session 1.
##   The Khaneh appears INSTANTLY on the dwell-complete tick. Session 2
##   adds the in-progress mesh + progress-bar UI + partial-HP state.
##   The placement dwell here (CONSTRUCTING_DWELL_TICKS) is the
##   placeholder for that future timer — short enough (~3s at 30Hz) to
##   not feel like dead air, long enough for the worker to "look like
##   it's doing something" before the building pops in.

const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")
const _BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")

# === Scene table — kind StringName → PackedScene path ======================
#
# Wave 1C ships Khaneh as the only entry. Session 2 adds Mazra'eh /
# Ma'dan / Sarbaz-khaneh / Atashkadeh — append to this table as each
# concrete building ships. Path-string preload sidesteps the
# PackedScene class_name dependencies the same way every other
# scene preload in this codebase does (kargar.gd has a similar list).
#
# Why a dict-of-paths and not a dict-of-PackedScene refs:
# PackedScene refs would hold the scene resource in memory at parse
# time. With one entry that's fine; with 4+ entries the cost grows.
# Lazy-loading via load(path) at use-time matches the MineNode /
# kargar.tscn pattern in main.gd which preloads explicitly for
# match-start spawn but not for "build menu might place this one
# someday." A future BuildingRegistry autoload (LATER L?) would own
# this table — for now it lives here.
const _BUILDING_SCENE_PATHS: Dictionary = {
	&"khaneh": "res://scenes/world/buildings/khaneh.tscn",
	&"mazraeh": "res://scenes/world/buildings/mazraeh.tscn",
	&"madan": "res://scenes/world/buildings/madan.tscn",
}


# === Dwell config ===========================================================
#
# Sim-tick countdown for the on-arrival dwell. Session 1 wave 1C uses a
# short placeholder so the lead's first live-test doesn't feel like dead
# air. Session 2's construction-timer wave replaces this with a per-
# kind BalanceData.buildings[kind].construction_ticks read.
#
# Why a constant here (not BalanceData yet):
#   construction_ticks IS in BalanceData (Khaneh: 90 ticks = ~3s at
#   30Hz). But session 1's "instant placement on arrival" semantics
#   mean we don't NEED the per-kind value yet — every building takes
#   the same short dwell here just for animation feel. Session 2
#   reads the per-kind value when the progress-bar UI ships and the
#   dwell becomes the actual construction time, not just a "looks
#   busy" pad. The constant documents the placeholder choice; the
#   data-driven read replaces it in session 2.
const _CONSTRUCTING_DWELL_TICKS: int = 90  # ~3 sec at 30Hz


# === Cached state ===========================================================
# All cleared in exit(). Set during enter / _sim_tick.

var _movement: Variant = null

# Cached from the command payload at enter().
var _building_kind: StringName = &""
var _target_position: Vector3 = Vector3.ZERO

# Latch for arrival detection. Mirrors Moving / Gathering / Returning.
var _arrival_pending: bool = false

# Dwell countdown — initialized when arrival detected, counts down in
# _sim_tick until placement fires.
var _dwell_remaining_ticks: int = 0

# True once placement has fired. Defensive against re-entering the
# placement block on subsequent ticks before the transition_to(&"idle")
# lands (transitions are queued; the StateMachine may take one more
# tick to actually swap states).
var _placed: bool = false


func _init() -> void:
	id = Constants.STATE_CONSTRUCTING
	priority = 5
	interrupt_level = 1  # InterruptLevel.COMBAT


# Entry: cache movement, read payload, issue the path. Defensive bails
# on missing / malformed payload — same shape as Gathering's enter.
func enter(_prev: Object, ctx: Object) -> void:
	_movement = null
	_building_kind = &""
	_target_position = Vector3.ZERO
	_arrival_pending = false
	_dwell_remaining_ticks = 0
	_placed = false

	if ctx == null:
		push_warning("UnitState_Constructing.enter: null ctx — bailing to idle")
		return

	if ctx.has_method(&"get_movement"):
		_movement = ctx.get_movement()
	if _movement == null:
		push_warning(
			"UnitState_Constructing.enter: no MovementComponent on ctx — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return

	# Read payload off ctx.current_command. Same shape as Gathering.
	var cmd: Dictionary = {}
	if &"current_command" in ctx:
		var raw: Variant = ctx.current_command
		if typeof(raw) == TYPE_DICTIONARY:
			cmd = raw
	var payload: Dictionary = cmd.get(&"payload", {})

	# Validate building_kind — must be a known concrete subclass.
	var raw_kind: Variant = payload.get(&"building_kind", &"")
	if typeof(raw_kind) != TYPE_STRING_NAME or raw_kind == &"":
		push_warning(
			"UnitState_Constructing.enter: payload missing building_kind — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return
	if not _BUILDING_SCENE_PATHS.has(raw_kind):
		push_warning(
			"UnitState_Constructing.enter: unknown building_kind '%s' "
			% raw_kind
			+ "(not in _BUILDING_SCENE_PATHS) — transitioning to idle"
		)
		_request_idle(ctx)
		return
	_building_kind = raw_kind

	# Validate target_position.
	var raw_pos: Variant = payload.get(&"target_position", null)
	if raw_pos == null or typeof(raw_pos) != TYPE_VECTOR3:
		push_warning(
			"UnitState_Constructing.enter: payload missing target_position — "
			+ "transitioning to idle"
		)
		_request_idle(ctx)
		return
	_target_position = raw_pos

	# Kick off the path. Even when target_position is the worker's own
	# position (zero-walk), the path request still fires — arrival
	# latches on the next tick.
	_movement.request_repath(_target_position)


# Per-tick: drive movement, detect arrival, count dwell, fire placement,
# transition to Idle. Same arrival-latch pattern as Gathering / Returning.
func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null:
		return
	if _placed:
		return  # Already placed this entry; wait for the FSM to swap us.

	# Drive the MovementComponent. Same pattern as Moving / Gathering.
	_movement._sim_tick(dt)

	# Path failure → bail to Idle. The worker couldn't reach the build
	# site; no auto-retry. Cost is NOT deducted in this branch (we
	# never reached placement).
	var path_state: int = _movement.path_state
	if path_state == _IPathScheduler.PathState.FAILED \
			or path_state == _IPathScheduler.PathState.CANCELLED:
		push_warning(
			"UnitState_Constructing: path resolution failed "
			+ "(state=%d, target=%s, kind=%s); transitioning to idle"
			% [path_state, str(_target_position), _building_kind]
		)
		_request_idle(ctx)
		return

	# Latch arrival on READY. Mirrors Moving / AttackMove / Gathering.
	if path_state == _IPathScheduler.PathState.READY:
		_arrival_pending = true
	if not (_arrival_pending and not _movement.is_moving):
		return  # still walking

	# Arrived — start / continue the dwell countdown.
	if _dwell_remaining_ticks == 0 and not _placed:
		# Initialize the dwell ON THE FIRST POST-ARRIVAL TICK. We init
		# to _CONSTRUCTING_DWELL_TICKS - 1 so the dwell+placement
		# sequence completes after exactly N ticks of dwell (the
		# placement happens on the Nth tick, not the N+1th).
		_dwell_remaining_ticks = _CONSTRUCTING_DWELL_TICKS

	_dwell_remaining_ticks -= 1
	if _dwell_remaining_ticks > 0:
		return  # still dwelling

	# Dwell complete — fire placement. Three steps:
	#   1. Check affordability + deduct cost via ResourceSystem.
	#      change_resource. If cost-check fails (worker had funds at
	#      dispatch but spent them between then and arrival), bail to
	#      Idle without placing.
	#   2. Instantiate the Building scene + add as a child of the
	#      world.
	#   3. Call building.place_at(target, team, unit_id) — the base
	#      Building hook fires the subclass _on_placement_complete
	#      (Khaneh bumps population_cap + emits building_placed).
	_perform_placement(ctx)
	_placed = true
	_request_idle(ctx)


# Cost + placement + transition. Pulled into a helper so _sim_tick's
# main loop stays the readable arrival-latch pattern.
func _perform_placement(ctx: Object) -> void:
	if ctx == null:
		return
	# Resolve team from the unit. Defensive default TEAM_NEUTRAL is a
	# bug condition (every unit has a team), but tolerated.
	var team: int = Constants.TEAM_NEUTRAL
	if &"team" in ctx:
		team = int(ctx.team)
	var unit_id: int = -1
	if &"unit_id" in ctx:
		unit_id = int(ctx.unit_id)

	# Cost check + deduction. The build menu pre-screens affordability
	# at dispatch time; this is the second line of defense for the
	# "spent it during walk" edge case.
	var cost_coin: int = _resolve_cost_coin(_building_kind)
	if cost_coin > 0:
		var have_x100: int = ResourceSystem.coin_x100_for(team)
		if have_x100 < cost_coin * 100:
			push_warning(
				"UnitState_Constructing: insufficient Coin at placement "
				+ "(team=%d, have_x100=%d, need_x100=%d, kind=%s) — "
				% [team, have_x100, cost_coin * 100, _building_kind]
				+ "transitioning to idle without placing"
			)
			return  # No deduct, no place — _request_idle is called by
			        # the caller's next branch.
		# Deduct via the chokepoint. Negative amount = spend per
		# ResourceSystem's convention.
		ResourceSystem.change_resource(
			team, Constants.KIND_COIN, -cost_coin * 100,
			&"building_construction", ctx)

	# Instantiate and place. The Building scene must be added to a
	# parent BEFORE place_at runs (so _ready has fired and the building
	# has its unit_id assigned). The natural parent is the worker's
	# world parent — typically the &"World" node in main.tscn or the
	# test's harness root.
	var path: String = _BUILDING_SCENE_PATHS[_building_kind]
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning(
			"UnitState_Constructing._perform_placement: failed to load "
			+ "scene at '%s' for kind=%s" % [path, _building_kind]
		)
		return
	var building: Node3D = scene.instantiate() as Node3D
	var parent: Node = _resolve_placement_parent(ctx)
	if parent == null:
		push_warning(
			"UnitState_Constructing._perform_placement: no valid parent "
			+ "for the new building — discarding instance"
		)
		building.free()
		return
	parent.add_child(building)
	# place_at sets global_position + team + is_complete; fires the
	# subclass hook (_on_placement_complete) which is where Khaneh
	# bumps population_cap and emits the building_placed signal.
	building.place_at(_target_position, team, unit_id)


# Resolve the parent node for the placed building. The worker's parent
# is the most natural choice — workers and buildings live in the same
# world subtree.
func _resolve_placement_parent(ctx: Object) -> Node:
	if ctx == null or not (ctx is Node):
		return null
	return (ctx as Node).get_parent()


# Read the Coin cost from BalanceData.buildings[kind].coin_cost.
# Defensive fall-through pattern (missing file / entry / wrong type
# → 0) consistent with Unit._apply_balance_data_defaults and
# Khaneh.cost_coin.
func _resolve_cost_coin(kind: StringName) -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null:
		return 0
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return 0
	return int(coin_v)


# Exit: cancel in-flight repath. Same pattern as Moving / Gathering.
# Note: no refund on interrupt — see header rationale.
func exit() -> void:
	if _movement != null:
		var rid: int = int(_movement._request_id)
		if rid != -1 and _movement._scheduler != null:
			_movement._scheduler.cancel_repath(rid)
			_movement._request_id = -1
	_movement = null
	_building_kind = &""
	_target_position = Vector3.ZERO
	_arrival_pending = false
	_dwell_remaining_ticks = 0
	_placed = false


func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")
