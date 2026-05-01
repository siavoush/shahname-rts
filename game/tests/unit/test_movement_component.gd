# Tests for MovementComponent.
#
# Contract: docs/SIMULATION_CONTRACT.md §4.1.
#
# What we cover:
#   - request_repath stores the in-flight request_id and target
#   - request_repath cancels prior in-flight request via the scheduler
#   - path_state polls live and returns PENDING immediately, READY at tick+1
#   - _sim_tick advances position toward the current waypoint at move_speed * dt
#   - _sim_tick completes when the last waypoint is reached
#   - FAILED state clears the in-flight request without leaving stale waypoints
#   - is_moving reflects waypoint progress correctly
#   - idempotent on repeat requests (cancels old, replaces with new)
extends GutTest


const MovementComponentScript: Script = preload("res://scripts/units/components/movement_component.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")


# Test fixture: a Node3D parent owning the MovementComponent. The component
# reads global_position from its parent (per Sim Contract §4.1's
# Node3D.global_position carve-out).
var _parent: Node3D
var _mc: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	_parent = Node3D.new()
	_parent.global_position = Vector3(0.0, 0.0, 0.0)
	add_child_autofree(_parent)

	_mock = MockPathSchedulerScript.new()

	_mc = MovementComponentScript.new()
	_mc.unit_id = 7
	_mc.move_speed = 5.0  # 5 units/sec ≈ 1/6 unit per 30Hz tick
	# Inject the mock scheduler before _ready so the path goes through it.
	_mc._scheduler = _mock
	_parent.add_child(_mc)


func after_each() -> void:
	if is_instance_valid(_mc):
		_mc.queue_free()
	if is_instance_valid(_parent):
		_parent.queue_free()
	SimClock.reset()


# Helper: drive a real SimClock tick. The phase coordinators aren't yet
# wired in Phase 0, so we manually call _sim_tick(SimClock.SIM_DT) inside
# a real tick boundary — same pattern HealthComponent tests use.
func _sim_tick_one() -> void:
	SimClock._is_ticking = true
	_mc._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false
	# Advance the clock so the mock's "ready at requested_tick + 1"
	# semantics work. _test_run_tick advances tick, but flips
	# _is_ticking on its own; we don't need its phase emissions here.
	SimClock._test_run_tick()


# ---------------------------------------------------------------------------
# request_repath
# ---------------------------------------------------------------------------

func test_request_repath_stores_request_id() -> void:
	# Initial: no in-flight request.
	assert_eq(_mc._request_id, -1, "no request before request_repath")

	_mc.request_repath(Vector3(10.0, 0.0, 0.0))

	# After request: id is positive (the mock returns 1 for the first call).
	assert_true(_mc._request_id > 0, "request_id stored after request_repath")
	assert_eq(_mc._target, Vector3(10.0, 0.0, 0.0), "target stored")


func test_request_repath_logs_call_to_scheduler() -> void:
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	assert_eq(_mock.call_log.size(), 1)
	var entry: Dictionary = _mock.call_log[0]
	assert_eq(entry.unit_id, 7, "scheduler sees the unit_id we set")
	assert_eq(entry.from, Vector3.ZERO)
	assert_eq(entry.to, Vector3(10.0, 0.0, 0.0))


func test_request_repath_cancels_prior_in_flight_request() -> void:
	# Issue first request, then a second before the first resolves.
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	var first_id: int = _mc._request_id
	_mc.request_repath(Vector3(20.0, 0.0, 0.0))

	# The mock should now report the first request as CANCELLED.
	var first_result: Dictionary = _mock.poll_path(first_id)
	assert_eq(first_result.state, IPathSchedulerScript.PathState.CANCELLED,
		"prior in-flight request must be cancelled")
	# The component now tracks the new id.
	assert_ne(_mc._request_id, first_id, "request_id updated to new request")


# ---------------------------------------------------------------------------
# path_state
# ---------------------------------------------------------------------------

func test_path_state_pending_immediately_after_request() -> void:
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	# At the same tick (0), the mock holds PENDING.
	assert_eq(_mc.path_state, IPathSchedulerScript.PathState.PENDING)


func test_path_state_ready_at_next_tick() -> void:
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	# Advance SimClock by one tick — that's the mock's ready boundary.
	SimClock._test_run_tick()
	assert_eq(_mc.path_state, IPathSchedulerScript.PathState.READY)


# ---------------------------------------------------------------------------
# _sim_tick — advance along path
# ---------------------------------------------------------------------------

func test_sim_tick_advances_position_toward_target_when_path_ready() -> void:
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))

	# Advance the clock so the mock resolves to READY for our next tick.
	SimClock._test_run_tick()  # tick: 0 -> 1; mock now READY

	# First sim_tick: the component polls (sees READY), copies waypoints,
	# and advances by move_speed * dt = 5.0 * (1/30) ≈ 0.1667 toward target.
	SimClock._is_ticking = true
	_mc._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false

	var pos: Vector3 = _parent.global_position
	# x should have advanced toward 10 by ~0.1667.
	assert_almost_eq(pos.x, 5.0 / 30.0, 0.01,
		"position must advance by move_speed * dt toward target")
	assert_eq(pos.z, 0.0, "z unchanged on a straight x-axis path")


func test_sim_tick_completes_when_reaches_destination() -> void:
	# Use a small target so we can reach it in a few ticks.
	_mc.move_speed = 100.0  # huge speed → arrive in one tick
	_mc.request_repath(Vector3(1.0, 0.0, 0.0))
	SimClock._test_run_tick()  # mock resolves to READY

	# One sim_tick: 100 * (1/30) ≈ 3.33 — overshoots the 1.0 target,
	# so we snap to the target and advance the waypoint index.
	SimClock._is_ticking = true
	_mc._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false

	assert_almost_eq(_parent.global_position.x, 1.0, 0.01,
		"position must snap to target on overshoot")
	# After arrival at the only waypoint, is_moving must be false.
	assert_false(_mc.is_moving,
		"is_moving must be false after reaching the last waypoint")


func test_is_moving_is_false_before_request() -> void:
	# A freshly-spawned component has no path; not moving.
	assert_false(_mc.is_moving, "fresh component is not moving")


func test_is_moving_is_true_while_path_in_progress() -> void:
	_mc.request_repath(Vector3(20.0, 0.0, 0.0))
	SimClock._test_run_tick()  # mock READY
	# Take the first sim_tick to ingest the path.
	SimClock._is_ticking = true
	_mc._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false
	# Path has a remaining waypoint we haven't reached → is_moving true.
	assert_true(_mc.is_moving, "is_moving true while path waypoints remain")


# ---------------------------------------------------------------------------
# FAILED handling
# ---------------------------------------------------------------------------

func test_failed_path_clears_in_flight_request() -> void:
	# Force the next request to fail.
	_mock.fail_next_request()
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	SimClock._test_run_tick()  # mock now reports FAILED for this request

	# The component should observe the FAILED state when ticked, clear the
	# in-flight request id, and not be moving.
	SimClock._is_ticking = true
	_mc._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false

	assert_eq(_mc._request_id, -1, "FAILED clears _request_id")
	assert_false(_mc.is_moving, "FAILED leaves the component non-moving")
	assert_eq(_parent.global_position, Vector3.ZERO,
		"FAILED produces no position change")


# ---------------------------------------------------------------------------
# Idempotency on repeat target
# ---------------------------------------------------------------------------

func test_repeat_request_to_same_target_replaces_in_flight() -> void:
	# A defensive property: a state that wants to "set the same target
	# again" must produce a clean second request with no leftover
	# waypoints from the prior attempt.
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	var first_id: int = _mc._request_id
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	assert_ne(_mc._request_id, first_id, "second request gets a new id")
	# Old request should be cancelled in the mock.
	var first_result: Dictionary = _mock.poll_path(first_id)
	assert_eq(first_result.state, IPathSchedulerScript.PathState.CANCELLED)


# ---------------------------------------------------------------------------
# Scheduler not present — defensive degradation
# ---------------------------------------------------------------------------

func test_request_repath_without_scheduler_does_not_crash() -> void:
	_mc._scheduler = null
	# Must not crash; just push a warning.
	_mc.request_repath(Vector3(10.0, 0.0, 0.0))
	assert_eq(_mc._request_id, -1, "no request id stored when scheduler missing")
