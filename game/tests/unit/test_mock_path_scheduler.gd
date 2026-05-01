# Tests for MockPathScheduler.
#
# Contract: docs/SIMULATION_CONTRACT.md §4.3 + docs/TESTING_CONTRACT.md §3.4.
# MockPathScheduler is a test double for IPathScheduler that:
#   - Returns a unique, monotonically-increasing request_id per request_repath.
#   - Reports PENDING until SimClock.tick >= requested_tick + 1.
#   - Reports READY at tick+1 with a straight-line [from, to] waypoint pair.
#   - Transitions to CANCELLED on cancel_repath; all other states are sticky.
#   - Never touches NavigationServer3D.
#   - Exposes call_log: Array[Dictionary] (per §4.3), get_request_count_for_unit(), clear_log().
extends GutTest


# Preload the scripts at the module level so GUT's collector can parse this
# file even before the global class_name registry finishes populating (same
# pattern used in test_path_scheduler_service.gd).
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")


# Untyped Variant to avoid the class_name registry race documented in
# ARCHITECTURE.md §6 v0.4.0. Behavior is unchanged; the preloaded script ref
# carries all methods. Do not add a MockPathScheduler type annotation here.
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	_mock = MockPathSchedulerScript.new()


func after_each() -> void:
	_mock.clear_log()
	SimClock.reset()


# ---------------------------------------------------------------------------
# request_repath — ID and log recording
# ---------------------------------------------------------------------------

func test_request_repath_returns_positive_unique_ids() -> void:
	# Each call must return a new, positive, strictly-increasing request id.
	# Explicit int type avoids inference failure when _mock is Variant.
	var id1: int = _mock.request_repath(1, Vector3.ZERO, Vector3(5, 0, 0), 0)
	var id2: int = _mock.request_repath(1, Vector3.ZERO, Vector3(10, 0, 0), 0)
	assert_true(id1 > 0, "First request_id must be positive")
	assert_true(id2 > id1, "Second request_id must be greater than the first")


func test_request_repath_records_entry_in_log() -> void:
	# call_log must contain a full snapshot of the call parameters per §4.3.
	var from := Vector3(1.0, 0.0, 2.0)
	var to := Vector3(7.0, 0.0, 4.0)
	var rid: int = _mock.request_repath(42, from, to, 3)

	var log: Array = _mock.call_log
	assert_eq(log.size(), 1, "Exactly one entry recorded")
	var entry: Dictionary = log[0]
	assert_eq(entry.request_id, rid)
	assert_eq(entry.unit_id, 42)
	assert_eq(entry.from, from)
	assert_eq(entry.to, to)
	assert_eq(entry.priority, 3)
	assert_eq(entry.requested_tick, 0, "Requested at tick 0 (before any tick runs)")


func test_multiple_requests_for_same_unit_logged_separately() -> void:
	# Two requests for unit_id 7 must both appear in call_log as distinct rows.
	_mock.request_repath(7, Vector3.ZERO, Vector3(1, 0, 0), 0)
	_mock.request_repath(7, Vector3.ZERO, Vector3(2, 0, 0), 0)
	var log: Array = _mock.call_log
	assert_eq(log.size(), 2, "Both requests logged")
	assert_eq(log[0].unit_id, 7)
	assert_eq(log[1].unit_id, 7)
	# The two entries must carry different request_ids.
	assert_ne(log[0].request_id, log[1].request_id)


# ---------------------------------------------------------------------------
# poll_path — PENDING before the ready tick
# ---------------------------------------------------------------------------

func test_poll_path_returns_pending_before_ready_tick() -> void:
	# Request issued at tick 0. poll_path at tick 0 must return PENDING.
	var rid: int = _mock.request_repath(1, Vector3.ZERO, Vector3(10, 0, 0), 0)
	# SimClock.tick is still 0 at this point (no ticks have run).
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.PENDING,
		"Path must be PENDING at the tick it was requested (tick 0)")
	assert_eq(result.waypoints.size(), 0, "PENDING result has no waypoints")


# ---------------------------------------------------------------------------
# poll_path — READY at requested_tick + 1
# ---------------------------------------------------------------------------

func test_poll_path_returns_ready_at_tick_plus_one() -> void:
	# Request at tick 0; advance SimClock to tick 1 (requested_tick + 1).
	var rid: int = _mock.request_repath(1, Vector3.ZERO, Vector3(10, 0, 0), 0)
	SimClock._test_run_tick()   # tick becomes 1 after this call
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.READY,
		"Path must become READY at requested_tick + 1")


func test_poll_path_ready_waypoints_are_straight_line_from_to() -> void:
	# The READY result must contain exactly [from, to] as the waypoints.
	var from := Vector3(3.0, 0.0, 1.0)
	var to := Vector3(9.0, 0.0, 5.0)
	var rid: int = _mock.request_repath(1, from, to, 0)
	SimClock._test_run_tick()
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.READY)
	assert_eq(result.waypoints.size(), 2,
		"Straight-line mock produces exactly two waypoints")
	assert_eq(result.waypoints[0], from, "First waypoint is 'from'")
	assert_eq(result.waypoints[1], to, "Second waypoint is 'to'")


func test_poll_path_remains_pending_until_enough_ticks_elapse() -> void:
	# Request at tick 0; still PENDING at tick 0, READY at tick 1.
	var rid: int = _mock.request_repath(5, Vector3.ZERO, Vector3(1, 0, 0), 0)
	# Tick 0: PENDING.
	var before: Dictionary = _mock.poll_path(rid)
	assert_eq(before.state, IPathSchedulerScript.PathState.PENDING)
	SimClock._test_run_tick()  # tick advances to 1
	# Tick 1: READY.
	var after: Dictionary = _mock.poll_path(rid)
	assert_eq(after.state, IPathSchedulerScript.PathState.READY)


# ---------------------------------------------------------------------------
# cancel_repath
# ---------------------------------------------------------------------------

func test_cancel_repath_sets_state_to_cancelled() -> void:
	var rid: int = _mock.request_repath(2, Vector3.ZERO, Vector3(5, 0, 0), 0)
	_mock.cancel_repath(rid)
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.CANCELLED,
		"Cancelled request must poll as CANCELLED")
	assert_eq(result.waypoints.size(), 0, "CANCELLED result has no waypoints")


func test_cancel_repath_is_idempotent_on_unknown_id() -> void:
	# Cancelling an id that was never issued must not crash or raise an error.
	# GUT will catch any uncaught error, so simply calling this is the assertion.
	_mock.cancel_repath(99999)
	pass_test("cancel_repath with unknown id did not crash")


func test_cancelled_state_does_not_flip_to_ready_after_tick() -> void:
	# Once CANCELLED, a request must not silently flip to READY on the next tick.
	var rid: int = _mock.request_repath(3, Vector3.ZERO, Vector3(8, 0, 0), 0)
	_mock.cancel_repath(rid)
	SimClock._test_run_tick()  # would normally be the ready tick
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.CANCELLED,
		"CANCELLED must be sticky even after the ready tick passes")


# ---------------------------------------------------------------------------
# fail_next_request
# ---------------------------------------------------------------------------

func test_fail_next_request_causes_next_request_to_resolve_as_failed() -> void:
	_mock.fail_next_request()
	var rid: int = _mock.request_repath(4, Vector3.ZERO, Vector3(1, 0, 0), 0)
	SimClock._test_run_tick()
	var result: Dictionary = _mock.poll_path(rid)
	assert_eq(result.state, IPathSchedulerScript.PathState.FAILED,
		"Request after fail_next_request() must resolve to FAILED")


func test_fail_next_request_clears_after_one_use() -> void:
	# The flag must auto-clear: only the immediately-following request fails.
	_mock.fail_next_request()
	var rid_fail: int = _mock.request_repath(4, Vector3.ZERO, Vector3(1, 0, 0), 0)
	var rid_ok: int = _mock.request_repath(4, Vector3.ZERO, Vector3(2, 0, 0), 0)
	SimClock._test_run_tick()
	var result_fail: Dictionary = _mock.poll_path(rid_fail)
	var result_ok: Dictionary = _mock.poll_path(rid_ok)
	assert_eq(result_fail.state, IPathSchedulerScript.PathState.FAILED,
		"First request after fail_next must be FAILED")
	assert_eq(result_ok.state, IPathSchedulerScript.PathState.READY,
		"Second request (after flag cleared) must be READY")


# ---------------------------------------------------------------------------
# get_request_count_for_unit
# ---------------------------------------------------------------------------

func test_get_request_count_for_unit_returns_correct_count() -> void:
	_mock.request_repath(10, Vector3.ZERO, Vector3(1, 0, 0), 0)
	_mock.request_repath(10, Vector3.ZERO, Vector3(2, 0, 0), 0)
	_mock.request_repath(10, Vector3.ZERO, Vector3(3, 0, 0), 0)
	_mock.request_repath(20, Vector3.ZERO, Vector3(4, 0, 0), 0)

	assert_eq(_mock.get_request_count_for_unit(10), 3,
		"Unit 10 made 3 requests")
	assert_eq(_mock.get_request_count_for_unit(20), 1,
		"Unit 20 made 1 request")
	assert_eq(_mock.get_request_count_for_unit(99), 0,
		"Unit 99 made no requests")


# ---------------------------------------------------------------------------
# clear_log
# ---------------------------------------------------------------------------

func test_clear_log_resets_all_state() -> void:
	_mock.request_repath(1, Vector3.ZERO, Vector3(5, 0, 0), 0)
	_mock.request_repath(2, Vector3.ZERO, Vector3(5, 0, 0), 0)
	_mock.clear_log()

	assert_eq(_mock.call_log.size(), 0,
		"call_log must be empty after clear_log")
	assert_eq(_mock.get_request_count_for_unit(1), 0,
		"Unit counts must reset to 0 after clear_log")

	# IDs restart from 1 after clear, so a fresh request gets id == 1.
	var rid: int = _mock.request_repath(1, Vector3.ZERO, Vector3(3, 0, 0), 0)
	assert_eq(rid, 1, "request_id counter resets to 1 after clear_log")


# ---------------------------------------------------------------------------
# Unknown request_id on poll_path
# ---------------------------------------------------------------------------

func test_poll_path_returns_failed_for_unknown_id() -> void:
	var result: Dictionary = _mock.poll_path(99999)
	assert_eq(result.state, IPathSchedulerScript.PathState.FAILED,
		"Unknown request_id must return FAILED, not crash")
	assert_eq(result.waypoints.size(), 0)
