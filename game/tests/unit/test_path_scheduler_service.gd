# Tests for IPathScheduler interface + PathSchedulerService autoload.
#
# Contract: docs/SIMULATION_CONTRACT.md §4.2 / §4.3 — interface compiles,
# PathSchedulerService returns null when no scheduler set, accepts a
# mock-style implementation when set.
extends GutTest


# Preload the interface script so the test parses cleanly even when GUT's
# collector runs before the global class_name registry is fully populated.
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")


# A tiny mock scheduler used only here. NOT MockPathScheduler (that's the
# qa-engineer's session 4 deliverable). This stub exists to verify the
# service accepts injection. Extends the IPathScheduler interface via the
# preloaded script ref; we override only what we need.
class _StubScheduler extends "res://scripts/core/path_scheduler.gd":
	var requests: Array = []
	var next_id: int = 1

	func request_repath(unit_id: int, _from: Vector3, _to: Vector3, priority: int) -> int:
		var rid := next_id
		next_id += 1
		requests.append({"id": rid, "unit": unit_id, "priority": priority})
		return rid

	func poll_path(_request_id: int) -> Dictionary:
		return {"state": IPathSchedulerScript.PathState.READY, "waypoints": PackedVector3Array()}

	func cancel_repath(_request_id: int) -> void:
		pass


func before_each() -> void:
	PathSchedulerService.reset()


func after_each() -> void:
	PathSchedulerService.reset()


# -- Default state -----------------------------------------------------------
# Phase 1 changed the default from `null` to a fresh production
# NavigationAgentPathScheduler instance. Tests that need the null state
# write `set_scheduler(null)` explicitly.

func test_service_starts_with_production_scheduler() -> void:
	assert_not_null(PathSchedulerService.scheduler,
		"Phase 1 default: production NavigationAgentPathScheduler is wired at boot")
	assert_true(PathSchedulerService.has_scheduler())


func test_set_scheduler_null_clears_to_null() -> void:
	# Tests that exercise the null-scheduler defensive path can opt into
	# null explicitly.
	PathSchedulerService.set_scheduler(null)
	assert_null(PathSchedulerService.scheduler)
	assert_false(PathSchedulerService.has_scheduler())


# -- Injection ---------------------------------------------------------------

func test_set_scheduler_stores_the_instance() -> void:
	var stub := _StubScheduler.new()
	PathSchedulerService.set_scheduler(stub)
	assert_same(PathSchedulerService.scheduler, stub,
		"set_scheduler stores the supplied IPathScheduler verbatim")
	assert_true(PathSchedulerService.has_scheduler())


func test_reset_reverts_to_production_default() -> void:
	# Phase 1 contract: reset() reverts to a fresh production scheduler,
	# not null. The test injects a stub then calls reset() and asserts
	# the result is non-null and not the stub.
	var stub := _StubScheduler.new()
	PathSchedulerService.set_scheduler(stub)
	PathSchedulerService.reset()
	assert_not_null(PathSchedulerService.scheduler,
		"reset must revert to the production default, not null")
	assert_ne(PathSchedulerService.scheduler, stub,
		"reset must replace the stub with a fresh production scheduler")


# -- Interface shape ---------------------------------------------------------

func test_path_state_enum_values() -> void:
	# Per Sim Contract §4.2 — PENDING, READY, FAILED, CANCELLED in that order.
	assert_eq(IPathSchedulerScript.PathState.PENDING, 0)
	assert_eq(IPathSchedulerScript.PathState.READY, 1)
	assert_eq(IPathSchedulerScript.PathState.FAILED, 2)
	assert_eq(IPathSchedulerScript.PathState.CANCELLED, 3)


func test_concrete_scheduler_satisfies_request_poll_cancel() -> void:
	var stub := _StubScheduler.new()
	# Request: returns a non-negative id.
	var rid := stub.request_repath(7, Vector3.ZERO, Vector3(10, 0, 10), 0)
	assert_true(rid > 0, "Stub returns a non-negative request id")
	assert_eq(stub.requests.size(), 1)
	# Poll: returns the documented Dictionary shape.
	var result: Dictionary = stub.poll_path(rid)
	assert_true(result.has("state"))
	assert_true(result.has("waypoints"))
	# Cancel: must be callable without crashing.
	stub.cancel_repath(rid)
