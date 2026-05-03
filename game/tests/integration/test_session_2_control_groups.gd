# Integration tests — control group bind/recall/center round-trip.
#
# Wave 3 (qa-engineer). Locks in wave-2A (ControlGroups autoload) behaviors.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flow 2.
# Related:  docs/TESTING_CONTRACT.md §3.1.
#
# Strategy: ControlGroups is an autoload. Tests call its public API directly
# (bind, recall, recall_with_double_tap) with test_mode=true so no Input pump
# is needed. Camera centering is verified via an injected stub that records
# center_on calls.
#
# Typing: Variant slots for unit refs (ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _units: Array = []


# Minimal camera stub — records center_on calls.
class _CameraStub extends RefCounted:
	var calls: Array = []  # Array of Vector3
	func center_on(pos: Vector3) -> void:
		calls.append(pos)


func before_each() -> void:
	SelectionManager.reset()
	ControlGroups.reset()
	SimClock.reset()
	ControlGroups.set_test_mode(true)
	UnitScript.call(&"reset_id_counter")
	_units.clear()


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	ControlGroups.reset()
	ControlGroups.set_test_mode(false)
	SimClock.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	_units.append(u)
	return u


# ---------------------------------------------------------------------------
# 1. Bind 3 units → deselect → recall → same 3 selected
# ---------------------------------------------------------------------------

func test_bind_and_recall_restores_selection() -> void:
	var u1: Variant = _spawn_kargar(Vector3(0.0, 0.0, 0.0))
	var u2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	var u3: Variant = _spawn_kargar(Vector3(4.0, 0.0, 0.0))

	SelectionManager.add_to_selection(u1)
	SelectionManager.add_to_selection(u2)
	SelectionManager.add_to_selection(u3)
	ControlGroups.bind(1)

	SelectionManager.deselect_all()
	assert_eq(SelectionManager.selected_units.size(), 0)

	ControlGroups.recall(1)
	assert_eq(SelectionManager.selected_units.size(), 3,
		"recall after bind must restore all 3 units to selection")

	# Verify by unit_id not refs.
	var ids: Array = []
	for u in SelectionManager.selected_units:
		ids.append(int(u.unit_id))
	assert_true(ids.has(int(u1.unit_id)) and ids.has(int(u2.unit_id)) and ids.has(int(u3.unit_id)),
		"recalled selection must contain the same unit_ids as bound")


# ---------------------------------------------------------------------------
# 2. Bind, free one unit, recall → 2 selected (live filter)
# ---------------------------------------------------------------------------

func test_recall_filters_freed_units() -> void:
	var u1: Variant = _spawn_kargar(Vector3(0.0, 0.0, 0.0))
	var u2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	var u3: Variant = _spawn_kargar(Vector3(4.0, 0.0, 0.0))

	SelectionManager.add_to_selection(u1)
	SelectionManager.add_to_selection(u2)
	SelectionManager.add_to_selection(u3)
	ControlGroups.bind(2)
	SelectionManager.deselect_all()

	# Free u2 — simulates unit death.
	u2.queue_free()
	# Remove from cleanup list since it's already freed.
	_units.erase(u2)

	# Advance one process frame to let queue_free propagate.
	await get_tree().process_frame

	ControlGroups.recall(2)
	assert_eq(SelectionManager.selected_units.size(), 2,
		"recall after one unit freed must select only the 2 live units")


# ---------------------------------------------------------------------------
# 3. Recall an unbound group → no-op (does NOT clear prior selection)
# ---------------------------------------------------------------------------

func test_recall_unbound_group_is_noop() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	assert_eq(SelectionManager.selected_units.size(), 1)

	# Group 5 was never bound.
	ControlGroups.recall(5)

	assert_eq(SelectionManager.selected_units.size(), 1,
		"recall of unbound group must leave current selection unchanged")


# ---------------------------------------------------------------------------
# 4. Double-tap recall → camera centering invoked once with group centroid
# ---------------------------------------------------------------------------

func test_double_tap_recall_centers_camera() -> void:
	var u1: Variant = _spawn_kargar(Vector3(0.0, 0.0, 0.0))
	var u2: Variant = _spawn_kargar(Vector3(4.0, 0.0, 0.0))

	SelectionManager.add_to_selection(u1)
	SelectionManager.add_to_selection(u2)
	ControlGroups.bind(3)
	SelectionManager.deselect_all()

	# Inject camera stub.
	var cam_stub: _CameraStub = _CameraStub.new()
	ControlGroups.set_camera_target(cam_stub)

	# First tap — arms the timer.
	ControlGroups.recall_with_double_tap(3)
	assert_eq(cam_stub.calls.size(), 0,
		"first tap must not call center_on")

	# Second tap within DOUBLE_TAP_TICKS — must trigger centering.
	# No ticks elapsed → elapsed = 0, well within DOUBLE_TAP_TICKS = 10.
	ControlGroups.recall_with_double_tap(3)
	assert_eq(cam_stub.calls.size(), 1,
		"second tap within window must call center_on exactly once")

	# Centroid of u1=(0,0,0) and u2=(4,0,0) → (2,0,0).
	var centroid: Vector3 = cam_stub.calls[0]
	assert_almost_eq(centroid.x, 2.0, 0.01,
		"centroid X must be mean of 0 and 4 (= 2)")
	assert_almost_eq(centroid.z, 0.0, 0.01,
		"centroid Z must be 0")
	assert_almost_eq(centroid.y, 0.0, 0.01,
		"centroid Y must be 0 (ground-plane target)")


# ---------------------------------------------------------------------------
# 5. Double-tap on different key resets window (no center_on triggered)
# ---------------------------------------------------------------------------

func test_double_tap_different_key_no_center() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	ControlGroups.bind(1)
	var u2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	SelectionManager.add_to_selection(u2)
	ControlGroups.bind(2)
	SelectionManager.deselect_all()

	var cam_stub: _CameraStub = _CameraStub.new()
	ControlGroups.set_camera_target(cam_stub)

	# Tap 1, then tap 2 — different keys → no double-tap.
	ControlGroups.recall_with_double_tap(1)
	ControlGroups.recall_with_double_tap(2)

	assert_eq(cam_stub.calls.size(), 0,
		"tapping different keys back-to-back must not trigger centering")


# ---------------------------------------------------------------------------
# 6. Recall stale tap (elapsed > DOUBLE_TAP_TICKS) → no camera center
# ---------------------------------------------------------------------------

func test_stale_double_tap_no_center() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	ControlGroups.bind(4)
	SelectionManager.deselect_all()

	var cam_stub: _CameraStub = _CameraStub.new()
	ControlGroups.set_camera_target(cam_stub)

	# First tap at tick 0.
	ControlGroups.recall_with_double_tap(4)
	# Advance past the double-tap window (DOUBLE_TAP_TICKS = 10).
	for _i in range(11):
		SimClock._test_run_tick()

	# Second tap at tick 11 — outside window.
	ControlGroups.recall_with_double_tap(4)
	assert_eq(cam_stub.calls.size(), 0,
		"tap after double-tap window has expired must not call center_on")
