class_name IPathScheduler extends RefCounted
##
## IPathScheduler — the path-request interface MovementComponent talks to.
##
## Per docs/SIMULATION_CONTRACT.md §4.2.
##
## This is an abstract base. Two concrete implementations land later:
##   - NavigationAgentPathScheduler (engine-architect, session 4) — production
##     wrapper around NavigationServer3D. Polled, never callback-into-gameplay.
##   - MockPathScheduler (qa-engineer, session 4) — straight-line two-waypoint
##     paths for tests. Result is READY on requested_tick + 1.
##
## API contract:
##   request_repath(unit_id, from, to, priority) -> int
##     Issues a non-blocking path request. Returns a request_id used to poll.
##     `priority` is advisory for MVP — accepted on the API, ignored by both
##     implementations. Bucketing arrives if profiling demands it.
##
##   poll_path(request_id) -> Dictionary
##     Returns { state: PathState, waypoints: PackedVector3Array }.
##     Until the request resolves, state == PENDING and waypoints is empty.
##
##   cancel_repath(request_id) -> void
##     Cancels an in-flight request. Idempotent — cancelling an unknown or
##     already-cancelled id is a no-op.
##
## Why a `class_name` on a RefCounted instead of a Godot Interface (Godot
## doesn't have interfaces): this matches the Sim Contract §4.2 sketch
## exactly, gives subclasses a typed seam, and lets PathSchedulerService
## hold an `IPathScheduler` reference cleanly when typed properties land.

# Path-resolution state. PENDING until the scheduler resolves; READY with
# waypoints; FAILED when no path exists; CANCELLED after cancel_repath.
enum PathState { PENDING, READY, FAILED, CANCELLED }


## Issue a non-blocking path request. Override in subclass.
##
## Default body push_errors so an accidental use of the abstract base in a
## live tree fails loudly instead of silently returning a zero id.
func request_repath(_unit_id: int, _from: Vector3, _to: Vector3, _priority: int) -> int:
	push_error("IPathScheduler.request_repath: abstract method — override in subclass")
	return -1


## Poll a previously-issued request. Returns a Dictionary with shape:
##   { state: PathState, waypoints: PackedVector3Array }
##
## Override in subclass. The default returns { state: FAILED, waypoints: [] }.
func poll_path(_request_id: int) -> Dictionary:
	push_error("IPathScheduler.poll_path: abstract method — override in subclass")
	return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}


## Cancel an in-flight request. Idempotent. Override in subclass.
func cancel_repath(_request_id: int) -> void:
	push_error("IPathScheduler.cancel_repath: abstract method — override in subclass")
