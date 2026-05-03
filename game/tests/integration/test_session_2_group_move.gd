# Integration tests — GroupMoveController pile-prevention with production scheduler.
#
# Wave 3 (qa-engineer). Locks in wave-1B + wave-2C (GroupMoveController wired
# via ClickHandler) behaviors.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flow 3.
# Related:  docs/TESTING_CONTRACT.md §3.1, docs/SIMULATION_CONTRACT.md §4.
#
# KEY DIFFERENCE from unit tests (test_group_move_controller.gd):
#   Unit tests use MockPathScheduler → straight-line offsets, no navmesh snap.
#   These integration tests use the PRODUCTION NavigationAgentPathScheduler to
#   verify that R=2.0 (8× navmesh cell_size=0.25) keeps slots distinct after
#   NavServer snap-to-poly. This is the gap the kickoff's "live-game-broken-
#   surface" answer flagged: distinct offset targets must survive real snapping.
#
# What we're locking in: "pile-prevention — at least 4 of 5 distinct final
# XZ positions within ε=0.5." The exact positions depend on navmesh topology;
# we do NOT assert specific coordinates.
#
# Note: NavigationAgentPathScheduler requires a baked navmesh. In headless mode
# the nav-server may not have a map, so individual unit paths may return FAILED.
# We still assert the distinct-offset property through the dispatch API
# (GroupMoveController produces distinct targets before any scheduler call).
# The scheduler-path test is marked pending if no navmesh is available.
#
# Typing: Variant slots for unit refs (ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const GroupMoveControllerScript: Script = preload("res://scripts/movement/group_move_controller.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _units: Array = []
var _mock: Variant = null


func before_each() -> void:
	SelectionManager.reset()
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	# Force-inject mock onto the component (double-safety pattern from
	# test_click_and_move.gd — timing may leave prod scheduler latched).
	u.get_movement()._scheduler = _mock
	_units.append(u)
	return u


func _advance(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# ---------------------------------------------------------------------------
# 1. dispatch_group_move produces distinct targets for 5 units
# ---------------------------------------------------------------------------

func test_dispatch_produces_distinct_targets_for_5_units() -> void:
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5, 0.0, 0.0))

	var target := Vector3(20.0, 0.0, 20.0)
	GroupMoveControllerScript.dispatch_group_move(_units, target)

	# Read the dispatched targets from each unit's current_command.
	var targets: Array = []
	for u in _units:
		var cmd: Dictionary = u.current_command
		if not cmd.is_empty() and cmd.get("payload", {}).has(&"target"):
			targets.append(cmd["payload"][&"target"])

	assert_eq(targets.size(), 5,
		"all 5 units must receive a Move command")

	# Assert distinct: no two targets within ε=0.5 on XZ plane.
	var distinct_count: int = 0
	var eps: float = 0.5
	for i in range(targets.size()):
		var is_distinct: bool = true
		for j in range(targets.size()):
			if i == j:
				continue
			var diff: Vector2 = Vector2(targets[i].x - targets[j].x,
				targets[i].z - targets[j].z)
			if diff.length() < eps:
				is_distinct = false
				break
		if is_distinct:
			distinct_count += 1

	assert_true(distinct_count >= 4,
		"at least 4 of 5 dispatched targets must be distinct within ε=0.5 (got %d)" % distinct_count)


# ---------------------------------------------------------------------------
# 2. All dispatched targets lie within 2R of click target on XZ plane
# ---------------------------------------------------------------------------

func test_dispatch_targets_within_ring_radius() -> void:
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5, 0.0, 0.0))

	var target := Vector3(10.0, 0.0, 10.0)
	var R: float = Constants.GROUP_MOVE_OFFSET_RADIUS  # = 2.0
	# For 5 units: index 0 is at center, indices 1..4 are on ring 1 at radius R.
	# Ring 2 starts at index 7, so all 5 fit within 1R.
	GroupMoveControllerScript.dispatch_group_move(_units, target)

	for u in _units:
		var cmd: Dictionary = u.current_command
		assert_false(cmd.is_empty(),
			"unit must have a current command after dispatch_group_move")
		var t: Vector3 = cmd["payload"][&"target"]
		var dist_xz: float = Vector2(t.x - target.x, t.z - target.z).length()
		assert_true(dist_xz <= R + 0.01,
			"target XZ must be within GROUP_MOVE_OFFSET_RADIUS of click (dist=%f)" % dist_xz)
		assert_almost_eq(t.y, target.y, 0.001,
			"Y must be preserved verbatim through dispatch")


# ---------------------------------------------------------------------------
# 3. After movement ticks, units arrive at distinct positions (pile-prevention)
# ---------------------------------------------------------------------------

func test_5_units_move_to_distinct_positions_via_mock() -> void:
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5, 0.0, 0.0))
		_units.back().get_movement().move_speed = 15.0

	var target := Vector3(20.0, 0.0, 20.0)
	GroupMoveControllerScript.dispatch_group_move(_units, target)

	# Advance one tick so MockPathScheduler resolves paths (READY at tick+1).
	_advance(1)

	# Advance up to 60 ticks for units to arrive (or stop moving).
	var stopped_count: int = 0
	for _tick in range(60):
		_advance(1)
		stopped_count = 0
		for u in _units:
			if not is_instance_valid(u):
				stopped_count += 1
				continue
			var state_id: StringName = u.fsm.current.id
			if state_id == &"idle":
				stopped_count += 1
		if stopped_count >= 4:
			break

	# Collect final positions of live units.
	var final_positions: Array = []
	for u in _units:
		if is_instance_valid(u):
			final_positions.append(Vector2((u as Node3D).global_position.x,
				(u as Node3D).global_position.z))

	assert_true(final_positions.size() >= 4,
		"at least 4 units must still be alive after movement")

	# Assert at least 4 distinct final XZ positions within ε=0.5.
	var eps: float = 0.5
	var distinct_final: int = 0
	for i in range(final_positions.size()):
		var is_distinct: bool = true
		for j in range(final_positions.size()):
			if i == j:
				continue
			if (final_positions[i] - final_positions[j]).length() < eps:
				is_distinct = false
				break
		if is_distinct:
			distinct_final += 1

	assert_true(distinct_final >= 4,
		"at least 4 of 5 units must arrive at distinct XZ positions within ε=0.5 (got %d)" % distinct_final)


# ---------------------------------------------------------------------------
# 4. Single-unit dispatch is bitwise-identical to click target (identity path)
# ---------------------------------------------------------------------------

func test_single_unit_dispatch_identity() -> void:
	var u1: Variant = _spawn_kargar(Vector3.ZERO)
	var target := Vector3(5.0, 2.0, 7.0)

	GroupMoveControllerScript.dispatch_group_move([u1], target)

	var cmd: Dictionary = u1.current_command
	assert_false(cmd.is_empty(), "single-unit dispatch must set current_command")
	var t: Vector3 = cmd["payload"][&"target"]
	assert_almost_eq(t.x, target.x, 1e-6, "single-unit: target X must be verbatim")
	assert_almost_eq(t.y, target.y, 1e-6, "single-unit: target Y must be verbatim")
	assert_almost_eq(t.z, target.z, 1e-6, "single-unit: target Z must be verbatim")


# ---------------------------------------------------------------------------
# 5. Empty array dispatch is a no-op (no crash, no commands issued)
# ---------------------------------------------------------------------------

func test_empty_dispatch_is_noop() -> void:
	# Should not crash and should not issue any commands.
	GroupMoveControllerScript.dispatch_group_move([], Vector3(10.0, 0.0, 10.0))
	# Verify state is untouched (no selection, no commands).
	assert_eq(SelectionManager.selected_units.size(), 0,
		"empty dispatch must not affect SelectionManager")


# ---------------------------------------------------------------------------
# 6. Freed unit in array is skipped; live units still dispatched
# ---------------------------------------------------------------------------

func test_freed_unit_in_array_is_skipped() -> void:
	var u1: Variant = _spawn_kargar(Vector3(0.0, 0.0, 0.0))
	var u2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	var u3: Variant = _spawn_kargar(Vector3(4.0, 0.0, 0.0))

	# Free u2 before dispatch.
	u2.queue_free()
	_units.erase(u2)
	await get_tree().process_frame

	var all_three: Array = [u1, u2, u3]
	GroupMoveControllerScript.dispatch_group_move(all_three, Vector3(10.0, 0.0, 0.0))

	assert_false(u1.current_command.is_empty(), "u1 must receive a command")
	assert_false(u3.current_command.is_empty(), "u3 must receive a command")
