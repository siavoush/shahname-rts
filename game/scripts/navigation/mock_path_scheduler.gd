extends "res://scripts/core/path_scheduler.gd"
##
## MockPathScheduler — test double for IPathScheduler.
##
## Per docs/SIMULATION_CONTRACT.md §4.3 and docs/TESTING_CONTRACT.md §3.4:
##   - Returns a straight-line path (no NavigationServer3D contact whatsoever).
##   - Result becomes READY on requested_tick + 1, matching the contract's
##     "result delivered tick+1" guarantee.
##   - Exposes a full request log so tests can assert which paths were requested,
##     in what order, and with what arguments.
##   - Does NOT touch NavigationServer3D or any Godot navigation API.
##     That is the whole point of the mock — headless tests cannot deadlock on
##     NavigationServer3D, and determinism requires no engine navigation state.
##
## Usage (in GUT tests):
##   var mock := MockPathScheduler.new()
##   PathSchedulerService.set_scheduler(mock)
##   # or inject directly on a component:
##   unit.get_movement()._scheduler = mock
##
## Call log shape (one entry per request_repath call):
##   { request_id: int, unit_id: int, from: Vector3, to: Vector3,
##     priority: int, requested_tick: int }

class_name MockPathScheduler

# Internal request table. Key = request_id (int). Value = Dictionary:
#   { unit_id, from, to, priority, requested_tick, state, will_fail }
var _requests: Dictionary = {}

## Chronological log of every request_repath call — per SIMULATION_CONTRACT.md §4.3.
## Each entry: { request_id: int, unit_id: int, from: Vector3, to: Vector3,
##               priority: int, requested_tick: int }
var call_log: Array[Dictionary] = []

# Monotonic counter for request IDs. Starts at 1; 0 is reserved as "none".
var _next_id: int = 1

# When true, the *next* call to request_repath will produce a FAILED result
# instead of a straight-line path. Automatically cleared after one use.
var _fail_next: bool = false


## Issue a non-blocking path request.
##
## Returns a unique request_id (positive integer, monotonically increasing).
## Records (unit_id, from, to, priority, requested_tick) in the internal log.
## Schedules the result to become READY on SimClock.tick + 1.
## If fail_next_request() was called, this request will resolve to FAILED.
func request_repath(unit_id: int, from: Vector3, to: Vector3, priority: int) -> int:
	var rid := _next_id
	_next_id += 1

	# Capture the current tick so poll_path knows when to flip PENDING → result.
	var requested_tick: int = SimClock.tick

	var will_fail: bool = _fail_next
	_fail_next = false  # auto-clear after one use

	var entry: Dictionary = {
		"request_id": rid,
		"unit_id": unit_id,
		"from": from,
		"to": to,
		"priority": priority,
		"requested_tick": requested_tick,
		"state": PathState.PENDING,
		"will_fail": will_fail,
	}

	_requests[rid] = entry

	# Public call_log uses a subset of fields (no internal state / will_fail).
	call_log.append({
		"request_id": rid,
		"unit_id": unit_id,
		"from": from,
		"to": to,
		"priority": priority,
		"requested_tick": requested_tick,
	})

	return rid


## Poll a previously-issued request.
##
## Returns { state: PathState, waypoints: PackedVector3Array }.
## State is PENDING until SimClock.tick >= requested_tick + 1.
## On the ready tick, state becomes READY with waypoints [from, to] (two
## points — straight line, no obstacle avoidance), or FAILED if
## fail_next_request() was called before the request.
## Unknown or CANCELLED request_ids return FAILED immediately.
func poll_path(request_id: int) -> Dictionary:
	if not _requests.has(request_id):
		return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}

	var entry: Dictionary = _requests[request_id]

	# CANCELLED and already-resolved states are sticky — return as-is.
	if entry.state == PathState.CANCELLED:
		return {"state": PathState.CANCELLED, "waypoints": PackedVector3Array()}

	if entry.state == PathState.READY:
		return {"state": PathState.READY, "waypoints": _straight_line(entry)}

	if entry.state == PathState.FAILED:
		return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}

	# Still PENDING — check if the ready tick has arrived.
	if SimClock.tick >= entry.requested_tick + 1:
		if entry.will_fail:
			entry.state = PathState.FAILED
			return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}
		else:
			entry.state = PathState.READY
			return {"state": PathState.READY, "waypoints": _straight_line(entry)}

	# Not ready yet.
	return {"state": PathState.PENDING, "waypoints": PackedVector3Array()}


## Cancel an in-flight request. Idempotent — cancelling an unknown or
## already-cancelled request is a no-op (no error, no crash).
func cancel_repath(request_id: int) -> void:
	if not _requests.has(request_id):
		return
	var entry: Dictionary = _requests[request_id]
	if entry.state == PathState.PENDING:
		entry.state = PathState.CANCELLED


## Force the *next* call to request_repath to resolve as FAILED instead of
## returning a straight-line path. Clears automatically after one use.
## Enables tests to exercise the "no path exists" branch without real nav.
func fail_next_request() -> void:
	_fail_next = true


# ---------------------------------------------------------------------------
# Inspection methods (test-only, per Testing Contract §3.4)
# ---------------------------------------------------------------------------

## Return how many repaths were requested for a given unit_id.
## Counts all requests ever made, including cancelled ones.
func get_request_count_for_unit(unit_id: int) -> int:
	var count: int = 0
	for entry: Dictionary in call_log:
		if entry.unit_id == unit_id:
			count += 1
	return count


## Reset all internal state — request table, call_log, and the next-id counter.
## Call this in GUT before_each / after_each to isolate tests.
func clear_log() -> void:
	_requests.clear()
	call_log.clear()
	_next_id = 1
	_fail_next = false


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _straight_line(entry: Dictionary) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(entry.from)
	pts.append(entry.to)
	return pts
