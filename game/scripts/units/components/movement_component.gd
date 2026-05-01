extends "res://scripts/core/sim_node.gd"
##
## MovementComponent — wraps the IPathScheduler integration for a Unit.
##
## Per docs/SIMULATION_CONTRACT.md §4.1.
##
## Lifecycle:
##   - On _ready: pulls the active scheduler from PathSchedulerService and
##     reads move_speed from BalanceData. Tests can override _scheduler
##     directly after construction.
##   - On request_repath(target): cancels any in-flight request, issues a
##     new one through _scheduler, stores _request_id and _target. The
##     scheduler is non-blocking — the result lands on a later tick.
##   - On _sim_tick(dt): if a request is PENDING, polls; if READY, advances
##     the parent Node3D's global_position toward the current waypoint at
##     move_speed * dt. When we reach a waypoint, advance the index. When
##     we reach the last waypoint, mark complete (path_state stays READY,
##     waypoints empty, is_moving false).
##
## Position writes:
##   The parent Node3D's global_position is mutated directly during the
##   movement phase. This is the §4.1 carve-out from the SimNode discipline:
##   global_position is a Godot built-in setter, not a SimNode field, and
##   routing every position write through _set_sim adds noise without value.
##   The on-tick invariant still holds — these writes only happen inside
##   _sim_tick, which the movement phase coordinator drives. Position writes
##   from off-tick contexts (like _process) are forbidden by the same rule,
##   enforced by lint rule L1 rather than the runtime assert.
##
## Scheduler injection:
##   `_scheduler` defaults to PathSchedulerService.scheduler at _ready.
##   Tests inject MockPathScheduler by writing the field directly *after*
##   the component enters the tree (or by replacing PathSchedulerService.scheduler
##   before _ready fires). Either way, the public API surface is the same.
##
## Why extend SimNode (via path-string preload, not class_name)?
## Path-string base avoids the class_name registry race used elsewhere in
## the project (docs/ARCHITECTURE.md §6 v0.4.0). class_name retained on the
## component so unit scripts can declare typed @onready var movement: MovementComponent.
class_name MovementComponent

# Path scheduler interface — see docs/SIMULATION_CONTRACT.md §4.2.
const _IPathScheduler: Script = preload("res://scripts/core/path_scheduler.gd")

# Reference to the unit's id, supplied by the parent Unit on _ready. The
# scheduler logs by unit_id; using -1 as the sentinel for "unset" mirrors
# HealthComponent and FarrSystem patterns.
@export var unit_id: int = -1

# Move speed in world units per second. Set from BalanceData by the parent
# Unit's _ready. Tests may set it directly.
var move_speed: float = 0.0

# Active scheduler. Variant typing: per the project-wide convention
# (docs/ARCHITECTURE.md §6 v0.4.0), we avoid hard class_name dependencies
# at autoload-parse time. Resolved in _ready from PathSchedulerService.
var _scheduler: Variant = null

# Current path-request id; -1 sentinel means "no in-flight request".
var _request_id: int = -1

# Cached path waypoints from the most recent READY result.
var _waypoints: PackedVector3Array = PackedVector3Array()

# Index of the current waypoint we're moving toward. Increments as we
# arrive at each. When _waypoint_index >= _waypoints.size(), the path
# is consumed.
var _waypoint_index: int = 0

# Most recent target supplied to request_repath. Stored for diagnostics
# and so tests can verify that a repeated call to the same target is
# observable.
var _target: Vector3 = Vector3.ZERO

# Latched view of the most recent poll_path state. Public reads go through
# the path_state property which polls live.
#
# This buffer exists so consumers (like states' _sim_tick) can read state
# without an explicit poll, and so tests can inspect the last-known state.
var _last_path_state: int = _IPathScheduler.PathState.READY

# Distance threshold for "arrived at this waypoint". Smaller than the
# move-per-tick distance so units don't overshoot at low speeds; larger
# than 0 so floating-point drift doesn't trap us in an arrival loop.
const _WAYPOINT_REACHED_EPSILON: float = 0.05


# === Lifecycle ==============================================================

func _ready() -> void:
	# Pull the default scheduler from the service. Tests that inject their
	# own scheduler write to _scheduler directly after add_child_autofree.
	if _scheduler == null:
		_scheduler = PathSchedulerService.scheduler


# === Public API =============================================================

## Request a path to `target`. Cancels any in-flight request first.
## Non-blocking: the result lands on a later tick. Caller polls path_state
## or simply lets _sim_tick consume the result automatically.
##
## Off-tick callers are tolerated here — the request is a deferred ask,
## not a simulation-state mutation. The scheduler implementation itself
## may capture SimClock.tick at request time (MockPathScheduler does this).
func request_repath(target: Vector3) -> void:
	if _scheduler == null:
		# No scheduler wired (PathSchedulerService.scheduler is null and
		# tests didn't inject one). Defensive: log and bail.
		push_warning("MovementComponent: no scheduler available; ignoring repath request")
		return
	# Cancel any in-flight request. cancel_repath is idempotent on unknown ids.
	if _request_id != -1:
		_scheduler.cancel_repath(_request_id)
	_target = target
	_request_id = _scheduler.request_repath(
		unit_id,
		_get_owner_position(),
		target,
		0,  # priority — advisory per Sim Contract §4.2
	)
	# Reset the cached path while the new request is pending.
	_waypoints = PackedVector3Array()
	_waypoint_index = 0
	_last_path_state = _IPathScheduler.PathState.PENDING


## Live read of the current path state. Polls the scheduler if a request
## is in flight; otherwise returns the last-known state. Off-tick safe.
##
## Returns: an int matching IPathScheduler.PathState (PENDING / READY /
## FAILED / CANCELLED). Consumers may compare against the enum directly.
var path_state: int:
	get:
		if _request_id == -1 or _scheduler == null:
			return _last_path_state
		var result: Dictionary = _scheduler.poll_path(_request_id)
		return int(result.get("state", _IPathScheduler.PathState.FAILED))


## True when there are unconsumed waypoints to move toward. Becomes false
## either at spawn (no path requested), after path completion, or after a
## FAILED / CANCELLED resolution.
var is_moving: bool:
	get:
		return _waypoint_index < _waypoints.size()


# === Per-tick simulation ====================================================

## Per-tick movement integration.
##
## Runs in the `movement` phase via the unit's StateMachine.tick path.
## Order:
##   1. If _request_id is set and scheduler hasn't resolved, poll. Cache
##      the result; if READY, copy waypoints in.
##   2. If we have unconsumed waypoints, step the parent's position toward
##      the current waypoint. On arrival, advance _waypoint_index. If we
##      arrived at the last waypoint, the path is complete; subsequent
##      ticks will be no-ops until the next request.
func _sim_tick(dt: float) -> void:
	# Step 1: resolve any in-flight request.
	if _request_id != -1 and _scheduler != null:
		var result: Dictionary = _scheduler.poll_path(_request_id)
		var state: int = int(result.get("state", _IPathScheduler.PathState.FAILED))
		_last_path_state = state
		if state == _IPathScheduler.PathState.READY:
			_waypoints = result.get("waypoints", PackedVector3Array())
			_waypoint_index = 0
			# A straight-line mock path's first waypoint is the source
			# position. Skip it to avoid a no-op tick at spawn.
			if _waypoints.size() > 0:
				var dist_sq: float = _xz_distance_sq(
					_waypoints[0], _get_owner_position())
				if dist_sq <= _WAYPOINT_REACHED_EPSILON * _WAYPOINT_REACHED_EPSILON:
					_waypoint_index = 1
			_request_id = -1
		elif state == _IPathScheduler.PathState.FAILED \
				or state == _IPathScheduler.PathState.CANCELLED:
			# No path; clear in-flight handle. Caller may request again.
			_request_id = -1
			_waypoints = PackedVector3Array()
			_waypoint_index = 0
		# PENDING — just wait; check again next tick.

	# Step 2: advance along path if we have one.
	if not is_moving:
		return
	var owner_node: Node3D = _get_owner_node3d()
	if owner_node == null:
		return
	var current_wp: Vector3 = _waypoints[_waypoint_index]
	var pos: Vector3 = owner_node.global_position
	var to_wp: Vector3 = current_wp - pos
	# Y axis is ignored for movement decisions (flat XZ plane per Constants);
	# we still copy Y from the waypoint when we arrive so any future height
	# variation is preserved without active interpolation here.
	to_wp.y = 0.0
	var dist: float = to_wp.length()
	if dist <= _WAYPOINT_REACHED_EPSILON:
		# Snap to the waypoint and advance the index.
		owner_node.global_position = Vector3(current_wp.x, pos.y, current_wp.z)
		_waypoint_index += 1
		return
	var step: float = move_speed * dt
	if step >= dist:
		# Step would overshoot — snap to the waypoint and advance.
		owner_node.global_position = Vector3(current_wp.x, pos.y, current_wp.z)
		_waypoint_index += 1
		return
	# Standard step toward the waypoint.
	var direction: Vector3 = to_wp / dist
	owner_node.global_position = pos + direction * step


# === Internal helpers =======================================================

func _get_owner_node3d() -> Node3D:
	var p: Node = get_parent()
	if p is Node3D:
		return p as Node3D
	return null


func _get_owner_position() -> Vector3:
	var n: Node3D = _get_owner_node3d()
	if n == null:
		return Vector3.ZERO
	return n.global_position


# XZ-only squared distance helper — same projection rule as SpatialIndex.
func _xz_distance_sq(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return dx * dx + dz * dz
