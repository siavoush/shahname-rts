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
## Construction-in-progress (session 3 wave 1C):
##   The Building scene is INSTANTIATED on the tick the worker arrives
##   at the build site — it appears in the world immediately (so the
##   player sees structural feedback and the progress bar starts).
##   Building.place_at runs at that same tick, firing Stage 1
##   (_on_placement_complete) for structural side-effects.
##
##   Then the worker DWELLS for construction_ticks ticks (per-kind, read
##   from BalanceData.buildings[building_kind].construction_ticks). Each
##   dwell tick:
##     1. Decrement _dwell_remaining_ticks.
##     2. Emit Building.construction_progress_updated(percent_x100)
##        where percent_x100 = elapsed * 10000 / total. The UI progress
##        bar consumes this signal.
##   When the dwell completes (Stage 2):
##     1. Building._on_construction_complete fires — operational
##        activation (Mazra'eh.is_gatherable flips, Ma'dan registers
##        with the adjacent mine, etc.).
##     2. Building.construction_finalized(placer_unit_id) signal emits
##        — the externally-observable completion signal. UI / telemetry
##        consumers connect here; resolves the progress-overlay
##        hide-trigger gap (Task #139).
##     3. The worker transitions back to Idle.
##
##   The progress signal does NOT fire at the completion tick — Stage 2
##   activation is the distinct "we're done" signal. Per the Building
##   signal header: double-emitting at 100% would race with consumers
##   that expect operational state when they see progress = 100%.

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
	&"sarbaz_khaneh": "res://scenes/world/buildings/sarbaz_khaneh.tscn",
	&"atashkadeh": "res://scenes/world/buildings/atashkadeh.tscn",
}


# === Dwell config ===========================================================
#
# Sim-tick countdown for the post-arrival dwell. Session 3 wave 1C
# (Track 1) reads the per-kind value from
#   BalanceData.buildings[building_kind].construction_ticks
# via _resolve_construction_ticks(). Khaneh = 90 (~3s at 30Hz),
# Mazra'eh / Ma'dan = 600 (~20s) per balance-engineer's wave-1C ship.
#
# _CONSTRUCTING_DWELL_FALLBACK is used when:
#   (a) BalanceData is unreachable / missing the entry / wrong type, OR
#   (b) the entry has construction_ticks <= 0.
# Falling back to a non-zero value keeps the construction loop functional
# in tests that exercise the state with a misconfigured (or absent)
# BalanceData. We choose 90 to match Khaneh's shipped value — that is
# the only kind validated to feel right in the live test, so it is the
# safest fallback for any future kind whose value has not yet been tuned.
const _CONSTRUCTING_DWELL_FALLBACK: int = 90  # ~3 sec at 30Hz


# === Cached state ===========================================================
# All cleared in exit(). Set during enter / _sim_tick.

var _movement: Variant = null

# Cached from the command payload at enter().
var _building_kind: StringName = &""
var _target_position: Vector3 = Vector3.ZERO

# Latch for arrival detection. Mirrors Moving / Gathering / Returning.
var _arrival_pending: bool = false

# Dwell countdown — initialized to the per-kind construction_ticks value
# (from BalanceData) at the same tick the building is structurally
# placed, counts down in _sim_tick until _on_construction_complete fires.
var _dwell_remaining_ticks: int = 0

# Total dwell ticks for the current build — captured at dwell init so
# the percent_x100 progress calculation has a stable denominator even
# if BalanceData were hot-reloaded mid-construction (a future affordance;
# see balance_data.gd header "Hot-reload" section).
var _total_construction_ticks: int = 0

# Reference to the Building scene placed at arrival. We need this across
# subsequent ticks to (a) emit construction_progress_updated on it each
# dwell tick and (b) fire _on_construction_complete at completion.
# Defensive Variant typing — the scene is loaded dynamically per kind so
# a concrete typed reference would require importing every subclass.
var _building_ref: Variant = null

# True once the Building has been structurally placed (Stage 1 —
# place_at fired). From here on, the dwell countdown drives progress
# emits and the Stage 2 trigger.
var _structurally_placed: bool = false

# True once Stage 2 (_on_construction_complete) has fired. Defensive
# against re-entering the completion block on subsequent ticks before
# the transition_to(&"idle") lands (transitions are queued; the
# StateMachine may take one more tick to actually swap states).
var _operationally_complete: bool = false


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
	_total_construction_ticks = 0
	_building_ref = null
	_structurally_placed = false
	_operationally_complete = false

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


# Per-tick: drive movement, detect arrival, do structural placement on
# the arrival tick, then count down construction ticks while emitting
# progress, then fire operational completion. Same arrival-latch pattern
# as Gathering / Returning; restructured for the two-stage lifecycle.
func _sim_tick(dt: float, ctx: Object) -> void:
	if _movement == null:
		return
	if _operationally_complete:
		return  # Stage 2 already fired this entry; wait for FSM swap.

	# Drive the MovementComponent — only relevant pre-arrival. Once
	# the worker has arrived and the building is structurally placed,
	# the worker stays put; driving movement is a no-op but harmless.
	if not _structurally_placed:
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

		# Arrived this tick — perform Stage 1 structural placement now.
		# Steps:
		#   1. Check affordability + deduct cost via ResourceSystem.
		#      change_resource. If cost-check fails (worker had funds at
		#      dispatch but spent them between then and arrival), bail
		#      to Idle without placing.
		#   2. Instantiate the Building scene + add as a child of the
		#      world.
		#   3. Call building.place_at(target, team, unit_id) — the base
		#      Building hook fires the subclass _on_placement_complete
		#      (Khaneh bumps population_cap + emits building_placed;
		#      Mazra'eh / Ma'dan run their *structural* side-effects only
		#      — Stage 2 functional activation is gated below).
		#   4. Initialize the dwell countdown from BalanceData and fall
		#      through to the progress / completion logic.
		if not _perform_placement(ctx):
			# Either cost check failed or scene load failed; bail.
			_request_idle(ctx)
			return
		_structurally_placed = true
		_total_construction_ticks = _resolve_construction_ticks(_building_kind)
		_dwell_remaining_ticks = _total_construction_ticks
		# Fall through to the dwell tick — this tick counts toward
		# construction so a kind with construction_ticks = 1 completes
		# on the arrival tick itself (degenerate-edge correctness).

	# Dwell-phase tick: decrement, then either emit progress or fire
	# operational completion. Reaching this line implies
	# _structurally_placed == true and a valid _building_ref.
	_dwell_remaining_ticks -= 1
	if _dwell_remaining_ticks > 0:
		# Still dwelling — emit progress and return. Progress is
		# basis-point fraction of completed ticks vs total.
		_emit_construction_progress()
		return

	# Dwell complete — fire Stage 2 operational activation. Per the
	# Building.construction_progress_updated signal header: we do NOT
	# emit progress at 10000 here; the _on_construction_complete hook
	# and the construction_finalized signal together signal completion.
	#
	# Emit ORDERING is load-bearing per the construction_finalized signal
	# header on Building base: the virtual hook fires FIRST (operational
	# side-effects apply — is_gatherable flips, modifier registers), THEN
	# the signal fires. UI / telemetry consumers connecting to
	# construction_finalized see post-Stage-2 state on readout.
	if _building_ref != null and is_instance_valid(_building_ref):
		var placer_unit_id: int = -1
		if ctx != null and &"unit_id" in ctx:
			placer_unit_id = int(ctx.unit_id)
		_building_ref.call(&"_on_construction_complete", placer_unit_id)
		# Emit construction_finalized AFTER the virtual runs — the
		# externally-observable Stage-2 completion signal. Resolves the
		# ui-developer-p3s3 progress-overlay hide-trigger gap (Task #139).
		# is_instance_valid re-check is belt-and-braces against a
		# subclass _on_construction_complete that queue_frees self
		# (no concrete subclass does this today, but the guard is cheap).
		if is_instance_valid(_building_ref):
			_building_ref.emit_signal(
				&"construction_finalized", placer_unit_id)
	_operationally_complete = true
	_request_idle(ctx)


# Emit Building.construction_progress_updated with the current basis-
# point progress. percent_x100 = elapsed * 10000 / total, where
#   elapsed = total - remaining
# Computed from the cached _total_construction_ticks so a hot-reload of
# BalanceData mid-construction cannot produce a discontinuous progress
# value (the denominator is frozen at dwell init).
#
# Edge case: total <= 0 implies we already completed at structural-
# placement time; don't emit. The caller guarantees this branch only
# runs when _dwell_remaining_ticks > 0, which implies total > 0.
func _emit_construction_progress() -> void:
	if _building_ref == null or not is_instance_valid(_building_ref):
		return
	if _total_construction_ticks <= 0:
		return
	var elapsed: int = _total_construction_ticks - _dwell_remaining_ticks
	# Clamp into [0, 9999] — completion (10000) is signalled by Stage 2
	# firing, NOT by this emit. The signal contract on Building forbids
	# a 10000 emit before _on_construction_complete fires.
	if elapsed < 0:
		elapsed = 0
	var percent_x100: int = elapsed * 10000 / _total_construction_ticks
	if percent_x100 >= 10000:
		percent_x100 = 9999
	_building_ref.emit_signal(&"construction_progress_updated", percent_x100)


# Stage 1 — cost check, scene instantiation, place_at. Pulled into a
# helper so _sim_tick's main loop stays the readable arrival-latch
# pattern. Returns true on success (caller proceeds to dwell phase),
# false on failure (caller transitions to Idle without placing).
#
# On success, _building_ref is populated with the placed Building so
# subsequent dwell ticks can emit progress and fire Stage 2 on it.
func _perform_placement(ctx: Object) -> bool:
	if ctx == null:
		return false
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
			return false
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
		return false
	var building: Node3D = scene.instantiate() as Node3D
	var parent: Node = _resolve_placement_parent(ctx)
	if parent == null:
		push_warning(
			"UnitState_Constructing._perform_placement: no valid parent "
			+ "for the new building — discarding instance"
		)
		building.free()
		return false
	parent.add_child(building)
	# place_at sets global_position + team + is_complete; fires the
	# subclass hook (_on_placement_complete) which is where structural
	# side-effects run (Khaneh bumps population_cap, Mazra'eh /
	# Ma'dan register fog vision). Operational side-effects (Mazra'eh.
	# is_gatherable flip, Ma'dan modifier registration) are deferred to
	# _on_construction_complete in the dwell-complete branch.
	building.place_at(_target_position, team, unit_id)
	_building_ref = building
	return true


# Resolve the parent node for the placed building. The worker's parent
# is the most natural choice — workers and buildings live in the same
# world subtree.
func _resolve_placement_parent(ctx: Object) -> Node:
	if ctx == null or not (ctx is Node):
		return null
	return (ctx as Node).get_parent()


# Read per-kind construction_ticks from BalanceData.buildings[kind].
# construction_ticks. Defensive fall-through pattern consistent with
# _resolve_cost_coin / Unit._apply_balance_data_defaults: missing file /
# missing entry / wrong type / non-positive value → push_warning and
# return _CONSTRUCTING_DWELL_FALLBACK (90 ticks). The warning surfaces
# so balance-engineer notices when a new kind ships without its
# construction_ticks tuned.
func _resolve_construction_ticks(kind: StringName) -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData file '%s' missing for kind=%s; " % [path, kind]
			+ "falling back to %d ticks" % _CONSTRUCTING_DWELL_FALLBACK
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	var bd: Resource = load(path)
	if bd == null:
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData failed to load for kind=%s; " % kind
			+ "falling back to %d ticks" % _CONSTRUCTING_DWELL_FALLBACK
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData.buildings is not a Dictionary for kind=%s; " % kind
			+ "falling back to %d ticks" % _CONSTRUCTING_DWELL_FALLBACK
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null:
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData.buildings[%s] missing; " % kind
			+ "falling back to %d ticks" % _CONSTRUCTING_DWELL_FALLBACK
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	var ticks_v: Variant = stats.get(&"construction_ticks")
	if typeof(ticks_v) != TYPE_INT and typeof(ticks_v) != TYPE_FLOAT:
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData.buildings[%s].construction_ticks is not " % kind
			+ "numeric (got type %d); falling back to %d ticks"
			% [typeof(ticks_v), _CONSTRUCTING_DWELL_FALLBACK]
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	var ticks: int = int(ticks_v)
	if ticks <= 0:
		push_warning(
			"UnitState_Constructing._resolve_construction_ticks: "
			+ "BalanceData.buildings[%s].construction_ticks = %d " % [kind, ticks]
			+ "is non-positive; falling back to %d ticks"
			% _CONSTRUCTING_DWELL_FALLBACK
		)
		return _CONSTRUCTING_DWELL_FALLBACK
	return ticks


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
#
# Mid-construction interruption (interrupt_level = COMBAT): the building
# has already been structurally placed (Stage 1 ran on the arrival tick)
# and the Coin has been deducted. The half-built building stays in the
# world but never receives _on_construction_complete — Mazra'eh stays
# ungatherable, Ma'dan does not buff its mine. Cleanup of the orphaned
# building (free it? leave it as a derelict?) is out of scope for Track
# 1; for now the building lingers as a half-complete shell. A future
# task adds HP / destruction so the derelict can be destroyed manually.
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
	_total_construction_ticks = 0
	_building_ref = null
	_structurally_placed = false
	_operationally_complete = false


func _request_idle(ctx: Object) -> void:
	if ctx == null or not (&"fsm" in ctx) or ctx.fsm == null:
		return
	ctx.fsm.transition_to(&"idle")
