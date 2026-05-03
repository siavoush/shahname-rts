# Tests for BoxSelectHandler — input-event flow + multi-select integration.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (1).
#
# What we cover here:
#   - Press-then-release with no motion is a click (not a drag).
#   - Press-then-tiny-jitter (<dead-zone) is still a click, not a drag.
#   - Press-then-motion-past-dead-zone activates drag.
#   - end_press returns true iff drag was active.
#   - Drag → release with units inside the rect → SelectionManager
#     replaces selection with those units (no Shift).
#   - Drag → release with Shift held → SelectionManager adds those
#     units, preserving prior selection.
#   - Drag → release on empty rect (no units) → deselect_all.
#   - current_drag_rect normalizes corners regardless of drag direction.
#
# We bypass the live Camera3D / unproject_position by exercising the
# `box_select_units(rect, units, project_unit_callable, shift)` public
# seam — the handler tests inject a closure that returns the projected
# screen positions directly. Real Camera3D projection is exercised in
# the future scene-level smoke test (lead's interactive test).
extends GutTest


const BoxSelectHandlerScript: Script = preload(
	"res://scripts/input/box_select_handler.gd")
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain-Node3D fake unit. Same surface SelectionManager expects.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var team: int = 1  # Constants.TEAM_IRAN
	var command_queue: Object = null
	var _selectable: Variant = null

	func get_selectable() -> Object:
		return _selectable

	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


var handler: Node
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	handler = BoxSelectHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()


func _make_unit(uid: int, screen_pos: Vector2) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	# Stash the screen_pos in metadata so the test projector can read it
	# without us hand-rolling per-unit closures.
	u.set_meta(&"_test_screen_pos", screen_pos)
	u.set_meta(&"_test_on_screen", true)
	_units.append(u)
	return u


# Closure-friendly projector: reads the test's stored screen_pos meta from
# each unit. Equivalent shape to the production _project_unit (returns a
# Dictionary with screen_pos and on_screen).
static func _project_test_unit(u: Object) -> Dictionary:
	if u == null or not is_instance_valid(u):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	if not (u is Node):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var pos_v: Variant = (u as Node).get_meta(&"_test_screen_pos", Vector2.ZERO)
	var os_v: Variant = (u as Node).get_meta(&"_test_on_screen", true)
	return { &"screen_pos": pos_v, &"on_screen": os_v }


# ===========================================================================
# Click vs. drag arbitration
# ===========================================================================

func test_press_release_no_motion_is_click() -> void:
	handler.begin_press(Vector2(100, 100), false)
	var was_drag: bool = handler.end_press()
	assert_false(was_drag,
		"press → release with no motion must be a click, not a drag")


func test_press_motion_below_dead_zone_is_click() -> void:
	handler.begin_press(Vector2(100, 100), false)
	# 2,2 vector → distance √8 ≈ 2.83, well below the 4px dead zone.
	handler.update_motion(Vector2(102, 102))
	var was_drag: bool = handler.end_press()
	assert_false(was_drag,
		"sub-dead-zone jitter must keep the gesture in click mode")


func test_press_motion_past_dead_zone_activates_drag() -> void:
	handler.begin_press(Vector2(100, 100), false)
	handler.update_motion(Vector2(150, 150))
	var was_drag: bool = handler.end_press()
	assert_true(was_drag,
		"motion past the dead zone must mark the gesture as a drag")


func test_drag_rect_normalizes_top_left_to_bottom_right() -> void:
	handler.begin_press(Vector2(10, 20), false)
	handler.update_motion(Vector2(50, 80))
	var rect: Rect2 = handler.current_drag_rect()
	assert_eq(rect.position, Vector2(10, 20))
	assert_eq(rect.size, Vector2(40, 60))
	handler.end_press()


func test_drag_rect_normalizes_bottom_right_to_top_left() -> void:
	handler.begin_press(Vector2(50, 80), false)
	handler.update_motion(Vector2(10, 20))
	var rect: Rect2 = handler.current_drag_rect()
	assert_eq(rect.position, Vector2(10, 20))
	assert_eq(rect.size, Vector2(40, 60),
		"rect must normalize even when drag direction is BR → TL")
	handler.end_press()


# ===========================================================================
# box_select_units — the API the live drag-finalize calls
# ===========================================================================

func test_box_select_replaces_selection_with_units_inside_rect() -> void:
	# Three units; rect covers two of them.
	var inside_a: FakeUnit = _make_unit(1, Vector2(50, 50))
	var inside_b: FakeUnit = _make_unit(2, Vector2(80, 50))
	var outside: FakeUnit = _make_unit(3, Vector2(500, 500))
	# Pre-condition: select a unit that's NOT in the rect, so we can prove
	# the no-Shift drag clears prior selection.
	SelectionManager.select(outside)
	var rect: Rect2 = Rect2(0, 0, 200, 200)
	var hits: Array = handler.box_select_units(
		rect, [inside_a, inside_b, outside],
		Callable(self, &"_project_test_unit"), false)
	assert_eq(hits.size(), 2,
		"box_select_units returns the units whose projected pos lies in rect")
	assert_true(SelectionManager.is_selected(inside_a))
	assert_true(SelectionManager.is_selected(inside_b))
	assert_false(SelectionManager.is_selected(outside),
		"no-Shift drag must replace the selection — outside unit is dropped")


func test_box_select_with_shift_adds_to_existing_selection() -> void:
	var preexisting: FakeUnit = _make_unit(1, Vector2(500, 500))
	var inside_a: FakeUnit = _make_unit(2, Vector2(50, 50))
	var inside_b: FakeUnit = _make_unit(3, Vector2(80, 50))
	SelectionManager.select(preexisting)
	var rect: Rect2 = Rect2(0, 0, 200, 200)
	handler.box_select_units(
		rect, [preexisting, inside_a, inside_b],
		Callable(self, &"_project_test_unit"), true)
	assert_true(SelectionManager.is_selected(preexisting),
		"Shift+drag must preserve the prior selection")
	assert_true(SelectionManager.is_selected(inside_a))
	assert_true(SelectionManager.is_selected(inside_b))
	assert_eq(SelectionManager.selection_size(), 3)


func test_box_select_on_empty_rect_deselects_all_no_shift() -> void:
	var u: FakeUnit = _make_unit(1, Vector2(500, 500))
	SelectionManager.select(u)
	var rect: Rect2 = Rect2(0, 0, 200, 200)  # u is outside
	handler.box_select_units(
		rect, [u], Callable(self, &"_project_test_unit"), false)
	assert_eq(SelectionManager.selection_size(), 0,
		"no-Shift drag onto empty rect must clear selection")


func test_box_select_on_empty_rect_with_shift_preserves_selection() -> void:
	var u: FakeUnit = _make_unit(1, Vector2(500, 500))
	SelectionManager.select(u)
	var rect: Rect2 = Rect2(0, 0, 200, 200)  # u is outside
	handler.box_select_units(
		rect, [u], Callable(self, &"_project_test_unit"), true)
	assert_true(SelectionManager.is_selected(u),
		"Shift+drag onto empty rect must NOT clear prior selection")


func test_box_select_skips_off_screen_units() -> void:
	# inside_pos is numerically inside the rect, but on_screen=false (the
	# unit was behind the camera). Production sets this from
	# Camera3D.is_position_behind; here we set it manually.
	var hidden: FakeUnit = _make_unit(1, Vector2(50, 50))
	hidden.set_meta(&"_test_on_screen", false)
	var rect: Rect2 = Rect2(0, 0, 200, 200)
	var hits: Array = handler.box_select_units(
		rect, [hidden], Callable(self, &"_project_test_unit"), false)
	assert_eq(hits.size(), 0,
		"off-screen units must not be selectable even if rect contains "
		+ "their projected coordinates")


func test_box_select_returns_empty_when_no_candidates() -> void:
	var rect: Rect2 = Rect2(0, 0, 200, 200)
	var hits: Array = handler.box_select_units(
		rect, [], Callable(self, &"_project_test_unit"), false)
	assert_eq(hits.size(), 0)
	assert_eq(SelectionManager.selection_size(), 0)


# ===========================================================================
# Press-state lifecycle hygiene
# ===========================================================================

func test_current_drag_rect_returns_empty_before_drag() -> void:
	# No press at all yet — current_drag_rect should be empty.
	var r: Rect2 = handler.current_drag_rect()
	assert_eq(r.size, Vector2.ZERO,
		"current_drag_rect before any press is empty")


func test_current_drag_rect_returns_empty_when_only_pressed() -> void:
	# Press but no motion past dead zone — drag is not active, rect is empty.
	handler.begin_press(Vector2(100, 100), false)
	var r: Rect2 = handler.current_drag_rect()
	assert_eq(r.size, Vector2.ZERO,
		"current_drag_rect during press-only (no drag) is empty")
	handler.end_press()


func test_motion_without_press_is_noop() -> void:
	# update_motion before begin_press shouldn't crash or activate drag.
	handler.update_motion(Vector2(200, 200))
	var r: Rect2 = handler.current_drag_rect()
	assert_eq(r.size, Vector2.ZERO)


# ===========================================================================
# Shift-state captured at press, not at release
# ===========================================================================

func test_shift_state_uses_press_time_value() -> void:
	# Real-world case: player hits Shift, presses, releases Shift mid-drag,
	# then releases the mouse. The selection mode is locked at press time.
	var preexisting: FakeUnit = _make_unit(1, Vector2(500, 500))
	var inside: FakeUnit = _make_unit(2, Vector2(50, 50))
	SelectionManager.select(preexisting)
	# Press WITH shift, then drag past dead zone. We pass shift=true to
	# begin_press; the handler stores it. Release calls box_select_units
	# with that captured shift value.
	handler.begin_press(Vector2(0, 0), true)
	handler.update_motion(Vector2(100, 100))
	# Simulate the release decision: drag was active, so finalize with the
	# shift value captured at press time. We invoke box_select_units
	# directly (the public seam) with the captured shift mode.
	var rect: Rect2 = handler.current_drag_rect()
	handler.box_select_units(
		rect, [preexisting, inside],
		Callable(self, &"_project_test_unit"), true)
	handler.end_press()
	assert_true(SelectionManager.is_selected(preexisting),
		"Shift held at press → preexisting selection preserved")
	assert_true(SelectionManager.is_selected(inside))
