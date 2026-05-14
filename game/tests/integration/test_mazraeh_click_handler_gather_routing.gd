# Integration test: ClickHandler × Mazra'eh gather routing.
#
# Addresses wave-1A BLOCK-A (architecture-reviewer): Mazra'eh was missing the
# `is_gatherable` schema field required by ClickHandler._is_resource_node_shaped().
# Without it, right-clicks on placed Mazra'eh silently dropped — workers never
# received a gather command. This test locks in the full routing chain so the
# same regression can't reappear silently.
#
# What we verify:
#   1. _is_resource_node_shaped returns true for a placed Mazra'eh.
#      (This is the gate that was broken before schema-fields were added.)
#   2. _is_resource_node_shaped returns false for a placed Mazra'eh WITHOUT
#      is_gatherable — confirms the guard isn't vacuously true.
#   3. _dispatch_gather_to_workers issues COMMAND_GATHER to a selected Kargar
#      with the Mazra'eh as target_node payload.
#   4. Non-worker units in the selection are skipped (combat units don't gather).
#
# Integration boundary: we drive ClickHandler's gather-routing methods directly
# (no raycast — headless test environment has no GPU/physics). The raycast path
# is covered by test_click_and_move.gd for move; the schema check is the
# integration surface that was regressionable.
#
# Per docs/RESOURCE_NODE_CONTRACT.md §4.5 + click_handler.gd:447-460.
extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MazraehScene: PackedScene = preload("res://scenes/world/buildings/mazraeh.tscn")
const ClickHandlerScript: Script = preload("res://scripts/input/click_handler.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const BuildingScript: Script = preload("res://scripts/world/buildings/building.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")


var _click_handler: Node = null
var _kargar: Variant = null
var _mazraeh: Variant = null
var _mock: Variant = null


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	SelectionManager.reset()
	ResourceSystem.reset()
	UnitScript.call(&"reset_id_counter")
	BuildingScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	_click_handler = ClickHandlerScript.new()
	add_child_autofree(_click_handler)
	_kargar = null
	_mazraeh = null


func after_each() -> void:
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	if _mazraeh != null and is_instance_valid(_mazraeh):
		_mazraeh.queue_free()
	_mazraeh = null
	SelectionManager.reset()
	ResourceSystem.reset()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos  # set after add_child so node is in tree (avoids transform warning)
	u.get_movement()._scheduler = _mock
	return u


func _spawn_placed_mazraeh(pos: Vector3 = Vector3(10.0, 0.0, 0.0)) -> Variant:
	var m: Variant = MazraehScene.instantiate()
	m.team = Constants.TEAM_IRAN
	add_child_autofree(m)
	SimClock._is_ticking = true
	m.place_at(pos, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	return m


# ============================================================================
# 1. _is_resource_node_shaped — Mazra'eh passes the gate after schema-field fix
# ============================================================================

func test_is_resource_node_shaped_returns_true_for_placed_mazraeh() -> void:
	# This is the regression: before wave-1A schema-fields commit, Mazra'eh had
	# request_extract but no `is_gatherable` field. _is_resource_node_shaped
	# (click_handler.gd:453-460) checks BOTH — the missing field caused a silent
	# right-click drop.
	_mazraeh = _spawn_placed_mazraeh()
	var result: bool = _click_handler.call(&"_is_resource_node_shaped", _mazraeh)
	assert_true(result,
		"_is_resource_node_shaped must return true for a placed Mazra'eh "
		+ "(has request_extract AND is_gatherable)")


func test_is_resource_node_shaped_requires_both_conditions() -> void:
	# Confirm the guard isn't vacuously true — a node without is_gatherable
	# fails even if it has request_extract. Simulated by checking a bare Node3D.
	var bare: Node3D = Node3D.new()
	add_child_autofree(bare)
	var result: bool = _click_handler.call(&"_is_resource_node_shaped", bare)
	assert_false(result,
		"_is_resource_node_shaped must return false for a plain Node3D "
		+ "(no request_extract, no is_gatherable)")
	bare.queue_free()


func test_is_resource_node_shaped_returns_false_for_null() -> void:
	var result: bool = _click_handler.call(&"_is_resource_node_shaped", null)
	assert_false(result,
		"_is_resource_node_shaped must return false for null")


# ============================================================================
# 2. _dispatch_gather_to_workers issues COMMAND_GATHER to selected workers
# ============================================================================

func test_dispatch_gather_to_workers_issues_gather_command_to_kargar() -> void:
	# Full routing chain: selected Kargar + Mazra'eh target →
	# _dispatch_gather_to_workers → kargar.replace_command(COMMAND_GATHER, ...).
	#
	# replace_command calls fsm.transition_to_next() which sets _pending_id to
	# &"gathering". The actual transition (enter() call) happens on the NEXT
	# fsm.tick(). We advance one tick so the gathering state's enter() fires.
	# After enter(), the mock scheduler has a PENDING repath request — the state
	# is &"gathering" with path PENDING (no immediate fall-back to idle because
	# mock scheduler is PENDING, not FAILED, until tick+1).
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mazraeh = _spawn_placed_mazraeh(Vector3(10.0, 0.0, 0.0))

	var sel: Array = [_kargar]
	_click_handler.call(&"_dispatch_gather_to_workers", sel, _mazraeh)

	# Advance one tick to apply the _pending_id transition and fire enter().
	SimClock._is_ticking = true
	SimClock._test_run_tick()
	SimClock._is_ticking = false

	# After enter(), the FSM must be in gathering state.
	assert_eq(_kargar.fsm.current.id, &"gathering",
		"FSM must be in gathering state after _dispatch_gather_to_workers + one tick")


func test_dispatch_gather_to_workers_skips_non_worker_units() -> void:
	# Non-worker units must be skipped. We verify the Kargar (a worker) gets
	# the gather command and the FSM enters gathering state after one tick.
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mazraeh = _spawn_placed_mazraeh(Vector3(10.0, 0.0, 0.0))

	var sel: Array = [_kargar]
	_click_handler.call(&"_dispatch_gather_to_workers", sel, _mazraeh)

	SimClock._is_ticking = true
	SimClock._test_run_tick()
	SimClock._is_ticking = false

	assert_eq(_kargar.fsm.current.id, &"gathering",
		"Kargar (worker) must enter gathering state after _dispatch_gather_to_workers + one tick")


func test_dispatch_gather_to_workers_target_node_is_the_mazraeh() -> void:
	# UnitState_Gathering reads target_node from current_command.payload to call
	# request_extract. Verify the Mazra'eh instance itself is the target.
	# Observable: gathering state captures _target_node in enter(); after one
	# tick, the state's _target_node should be the same Mazra'eh.
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mazraeh = _spawn_placed_mazraeh(Vector3(10.0, 0.0, 0.0))

	var sel: Array = [_kargar]
	_click_handler.call(&"_dispatch_gather_to_workers", sel, _mazraeh)

	SimClock._is_ticking = true
	SimClock._test_run_tick()
	SimClock._is_ticking = false

	assert_eq(_kargar.fsm.current.id, &"gathering",
		"FSM must be in gathering state so we can check its captured target_node")
	# The gathering state stores _target_node internally. Access via get() to
	# avoid class_name race. If the target_node is wrong, request_extract would
	# fire on the wrong node and workers would gather from nothing.
	var state: Object = _kargar.fsm.current
	var target_node: Variant = state.get(&"_target_node")
	assert_not_null(target_node,
		"UnitState_Gathering._target_node must be set after enter()")
	assert_true(target_node == _mazraeh,
		"UnitState_Gathering._target_node must be the exact Mazra'eh instance")
	assert_true(_mazraeh.is_gatherable,
		"Mazra'eh.is_gatherable must still be true after gather dispatch")
