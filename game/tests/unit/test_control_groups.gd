# Tests for ControlGroups autoload — Ctrl+1..9 binds, 1..9 recalls,
# double-tap centers camera.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (2).
#
# What we cover here:
#   - bind(N) snapshots the current SelectionManager set into group N.
#   - bind(N) is idempotent / overwrites — re-binding replaces the prior
#     contents.
#   - recall(N) on an unbound group is a no-op (does not deselect_all).
#   - recall(N) on a bound group replaces the current selection with the
#     group's contents (single-recall path; not a double-tap).
#   - Freed units are filtered on read (lazy is_instance_valid pattern,
#     mirroring SelectionManager) — recalling a group with one freed
#     member returns only the live members.
#   - Double-tap detection uses SimClock.tick (replay-deterministic, NOT
#     wall-clock).
#   - Double-tap window: ≤ DOUBLE_TAP_TICKS triggers center; > does not.
#   - Different keycode between taps cancels the pending double-tap.
#   - reset() wipes all groups (mirrors the SelectionManager test pattern).
#
# We bypass the live InputEventKey path by exercising the public seams
# (bind, recall, recall_with_double_tap) so the GUT runner doesn't need
# real Input.parse_input_event support. The _unhandled_input dispatch is
# tested via direct synthetic InputEventKey injection in a separate test
# section.
extends GutTest


const ControlGroupsScript: Script = preload(
	"res://scripts/input/control_groups.gd")
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain Node3D fake unit — same shape SelectionManager + box-select tests
# use. Selection broadcasts work off `unit_id`; control groups iterate
# the SelectionManager's selected_units as opaque Object refs.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var team: int = 1
	var command_queue: Object = null
	var _selectable: Variant = null

	func get_selectable() -> Object:
		return _selectable

	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


# Stub camera that records center_on calls. The control_groups autoload
# resolves the live CameraController via the scene tree. For tests, we
# inject this stub via the public set_camera_target() seam — no live
# scene wiring required.
class StubCamera extends RefCounted:
	var center_calls: Array = []

	func center_on(world_pos: Vector3) -> void:
		center_calls.append(world_pos)


var groups: Node = null
var stub_camera: StubCamera = null
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	groups = ControlGroupsScript.new()
	add_child_autofree(groups)
	groups.set_test_mode(true)
	stub_camera = StubCamera.new()
	groups.set_camera_target(stub_camera)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()
	groups = null
	stub_camera = null


func _make_unit(uid: int, pos: Vector3 = Vector3.ZERO) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	u.global_position = pos
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


# ============================================================================
# bind(N) — snapshot current selection
# ============================================================================

func test_bind_records_currently_selected_units() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select(b)
	groups.bind(1)
	var members: Array = groups.members_of(1)
	assert_eq(members.size(), 2,
		"bind(N) snapshots the current SelectionManager set")
	assert_true(a in members)
	assert_true(b in members)


func test_bind_with_empty_selection_clears_group() -> void:
	# Pre-condition: group 1 has members.
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	assert_eq(groups.members_of(1).size(), 1)
	# Clear selection then re-bind. The group should now be empty.
	SelectionManager.deselect_all()
	groups.bind(1)
	assert_eq(groups.members_of(1).size(), 0,
		"bind(N) with empty selection makes group N empty")


func test_bind_overwrites_prior_contents() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	groups.bind(1)
	# Now a different selection.
	SelectionManager.deselect_all()
	SelectionManager.select(b)
	groups.bind(1)
	var members: Array = groups.members_of(1)
	assert_eq(members.size(), 1,
		"bind(N) replaces (not appends) prior group contents")
	assert_true(b in members)
	assert_false(a in members)


func test_bind_rejects_out_of_range_keys() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	# 0 and 10+ are NOT valid group keys (the spec is 1..9).
	groups.bind(0)
	groups.bind(10)
	assert_eq(groups.members_of(0).size(), 0,
		"key 0 is not a legal control group")
	assert_eq(groups.members_of(10).size(), 0,
		"keys ≥ 10 are not legal control groups")


# ============================================================================
# recall(N) — restore group as the active selection
# ============================================================================

func test_recall_replaces_selection_with_group_contents() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	var c: FakeUnit = _make_unit(3)
	# Group 1 = {a, b}.
	SelectionManager.select(a)
	SelectionManager.select(b)
	groups.bind(1)
	# Now select c only.
	SelectionManager.deselect_all()
	SelectionManager.select(c)
	# Recall 1 — selection should become {a, b}, c dropped.
	groups.recall(1)
	assert_true(SelectionManager.is_selected(a))
	assert_true(SelectionManager.is_selected(b))
	assert_false(SelectionManager.is_selected(c),
		"recall(N) replaces the entire selection")


func test_recall_unbound_group_is_noop() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	# Group 5 has never been bound.
	groups.recall(5)
	assert_true(SelectionManager.is_selected(a),
		"recall on an unbound group must NOT change the current selection")


func test_recall_filters_freed_units() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select(b)
	groups.bind(1)
	# Free b. The group still references it; recall must filter.
	b.queue_free()
	await get_tree().process_frame  # let queue_free settle
	groups.recall(1)
	assert_true(SelectionManager.is_selected(a))
	assert_eq(SelectionManager.selection_size(), 1,
		"recall filters out freed units; only live members are restored")


# ============================================================================
# Double-tap recall — center camera on group centroid
# ============================================================================

func test_first_recall_does_not_center_camera() -> void:
	var a: FakeUnit = _make_unit(1, Vector3(10, 0, 20))
	SelectionManager.select(a)
	groups.bind(1)
	groups.recall_with_double_tap(1)
	assert_eq(stub_camera.center_calls.size(), 0,
		"first recall must NOT trigger camera centering")


func test_double_tap_within_window_centers_camera() -> void:
	var a: FakeUnit = _make_unit(1, Vector3(10, 0, 20))
	var b: FakeUnit = _make_unit(2, Vector3(30, 0, 40))
	SelectionManager.select(a)
	SelectionManager.select(b)
	groups.bind(1)
	# First tap.
	groups.recall_with_double_tap(1)
	# Advance fewer than DOUBLE_TAP_TICKS sim ticks.
	for _i in range(int(groups.DOUBLE_TAP_TICKS) - 1):
		SimClock._test_run_tick()
	groups.recall_with_double_tap(1)
	assert_eq(stub_camera.center_calls.size(), 1,
		"second recall within DOUBLE_TAP_TICKS triggers camera centering")
	# Centroid is mean of (10,0,20) and (30,0,40) → (20, 0, 30).
	var c: Vector3 = stub_camera.center_calls[0]
	assert_almost_eq(c.x, 20.0, 1e-4)
	assert_almost_eq(c.z, 30.0, 1e-4)


func test_double_tap_outside_window_does_not_center() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	groups.recall_with_double_tap(1)
	# Advance past the window.
	for _i in range(int(groups.DOUBLE_TAP_TICKS) + 1):
		SimClock._test_run_tick()
	groups.recall_with_double_tap(1)
	assert_eq(stub_camera.center_calls.size(), 0,
		"recalls outside the double-tap window must NOT center camera")


func test_different_key_between_taps_cancels_double_tap() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	groups.bind(1)
	SelectionManager.deselect_all()
	SelectionManager.select(b)
	groups.bind(2)
	# Tap 1, then tap 2 within the window: NOT a double-tap of 2.
	groups.recall_with_double_tap(1)
	groups.recall_with_double_tap(2)
	assert_eq(stub_camera.center_calls.size(), 0,
		"different key between taps must not trigger center")


func test_double_tap_unbound_group_is_noop() -> void:
	# Tapping 7 twice when 7 is unbound: no center, no error.
	groups.recall_with_double_tap(7)
	for _i in range(int(groups.DOUBLE_TAP_TICKS) - 1):
		SimClock._test_run_tick()
	groups.recall_with_double_tap(7)
	assert_eq(stub_camera.center_calls.size(), 0,
		"double-tap on unbound group: no center")


func test_double_tap_uses_sim_clock_not_wall_clock() -> void:
	# Determinism: the timer must read SimClock.tick. We verify by
	# advancing SimClock without advancing real time and confirming
	# the window expires in tick-time only.
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	groups.recall_with_double_tap(1)
	# Advance the clock past the window deterministically.
	for _i in range(int(groups.DOUBLE_TAP_TICKS) + 5):
		SimClock._test_run_tick()
	groups.recall_with_double_tap(1)
	assert_eq(stub_camera.center_calls.size(), 0,
		"window expires by tick count, not wall-clock")


# ============================================================================
# Centroid computation
# ============================================================================

func test_centroid_of_single_unit_is_unit_position() -> void:
	var a: FakeUnit = _make_unit(1, Vector3(7, 0, 11))
	SelectionManager.select(a)
	groups.bind(1)
	groups.recall_with_double_tap(1)
	groups.recall_with_double_tap(1)
	var c: Vector3 = stub_camera.center_calls[0]
	assert_almost_eq(c.x, 7.0, 1e-4)
	assert_almost_eq(c.z, 11.0, 1e-4)


func test_centroid_skips_freed_members() -> void:
	var a: FakeUnit = _make_unit(1, Vector3(10, 0, 20))
	var b: FakeUnit = _make_unit(2, Vector3(30, 0, 40))
	SelectionManager.select(a)
	SelectionManager.select(b)
	groups.bind(1)
	# Free b; centroid should be (10, 0, 20).
	b.queue_free()
	await get_tree().process_frame
	groups.recall_with_double_tap(1)
	groups.recall_with_double_tap(1)
	# If only a remains, centroid is a's position.
	assert_eq(stub_camera.center_calls.size(), 1)
	var c: Vector3 = stub_camera.center_calls[0]
	assert_almost_eq(c.x, 10.0, 1e-4)
	assert_almost_eq(c.z, 20.0, 1e-4)


func test_centroid_of_empty_group_is_noop() -> void:
	# Bind an empty group, then double-tap. No center should fire.
	groups.bind(3)
	groups.recall_with_double_tap(3)
	groups.recall_with_double_tap(3)
	assert_eq(stub_camera.center_calls.size(), 0,
		"empty group double-tap: no center")


# ============================================================================
# Synthetic InputEventKey dispatch
# ============================================================================

func test_input_event_key_ctrl_1_binds_group_1() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	# Drive the public input seam directly (test_mode bypasses the engine
	# event pump but we want to test the dispatch logic).
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_1
	ev.ctrl_pressed = true
	ev.pressed = true
	groups.handle_key_event(ev)
	assert_eq(groups.members_of(1).size(), 1,
		"Ctrl+1 binds the current selection to group 1")


func test_input_event_key_1_alone_recalls_group_1() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	SelectionManager.deselect_all()
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_1
	ev.ctrl_pressed = false
	ev.pressed = true
	groups.handle_key_event(ev)
	assert_true(SelectionManager.is_selected(a),
		"1 alone recalls group 1")


func test_input_event_key_release_is_ignored() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	# A release event must NOT bind or recall (production binds on press).
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_1
	ev.ctrl_pressed = true
	ev.pressed = false
	groups.handle_key_event(ev)
	assert_eq(groups.members_of(1).size(), 0,
		"release event must not trigger bind")


func test_input_event_non_digit_ignored() -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_A
	ev.ctrl_pressed = true
	ev.pressed = true
	# Should not crash; should not bind anything.
	groups.handle_key_event(ev)
	for n in range(1, 10):
		assert_eq(groups.members_of(n).size(), 0,
			"non-digit Ctrl+key must not affect any control group")


func test_input_event_key_0_ignored() -> void:
	# 0 is not a legal control group key (1..9 only).
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_0
	ev.ctrl_pressed = true
	ev.pressed = true
	groups.handle_key_event(ev)
	assert_eq(groups.members_of(0).size(), 0,
		"Ctrl+0 must NOT bind group 0 (illegal key)")


# ============================================================================
# reset()
# ============================================================================

func test_reset_clears_all_groups() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	groups.bind(2)
	groups.bind(3)
	groups.reset()
	for n in range(1, 10):
		assert_eq(groups.members_of(n).size(), 0,
			"reset() empties every group")


func test_reset_clears_double_tap_state() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	groups.bind(1)
	groups.recall_with_double_tap(1)
	# reset, then double-tap again — should NOT fire (the first-tap
	# state was wiped).
	groups.reset()
	groups.recall_with_double_tap(1)
	assert_eq(stub_camera.center_calls.size(), 0,
		"reset() wipes the double-tap state machine")
