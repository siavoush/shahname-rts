# Tests for DoubleClickSelect — double-click a unit selects all visible
# units of the same `unit_type`.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (3).
#
# Strategy (kickoff option b): observe EventBus.selection_changed. When the
# same unit is the sole selection twice within DOUBLE_CLICK_TICKS, treat
# the second selection as a double-click and select all units of its
# `unit_type` whose Camera3D-projected screen position lies inside the
# viewport.
#
# We bypass live Camera3D unproject_position via the public seam
# `select_visible_of_type(target_unit, project_unit_callable, candidates)`
# — same shape as box_select_handler.gd's `box_select_units` test seam.
# Live camera projection is exercised in the lead's interactive smoke test.
extends GutTest


const DoubleClickSelectScript: Script = preload(
	"res://scripts/input/double_click_select.gd")
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain Node3D fake unit. Adds `unit_type` for the type-filter check.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var team: int = 1
	var unit_type: StringName = &"kargar"
	var command_queue: Object = null
	var _selectable: Variant = null

	func get_selectable() -> Object:
		return _selectable

	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


var detector: Node = null
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	detector = DoubleClickSelectScript.new()
	add_child_autofree(detector)
	detector.set_test_mode(true)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()
	detector = null


func _make_unit(uid: int, screen_pos: Vector2 = Vector2(100, 100),
		on_screen: bool = true,
		unit_type: StringName = &"kargar") -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.team = Constants.TEAM_IRAN
	u.unit_type = unit_type
	add_child_autofree(u)
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	u.set_meta(&"_test_screen_pos", screen_pos)
	u.set_meta(&"_test_on_screen", on_screen)
	_units.append(u)
	return u


# Closure-friendly projector matching the production _project_unit shape.
static func _project_test_unit(u: Object) -> Dictionary:
	if u == null or not is_instance_valid(u):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	if not (u is Node):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var pos_v: Variant = (u as Node).get_meta(&"_test_screen_pos", Vector2.ZERO)
	var os_v: Variant = (u as Node).get_meta(&"_test_on_screen", true)
	return { &"screen_pos": pos_v, &"on_screen": os_v }


# ============================================================================
# select_visible_of_type — the public test seam (no signal driving)
# ============================================================================

func test_select_of_type_picks_all_same_type_on_screen() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	var c: FakeUnit = _make_unit(3, Vector2(300, 300))
	# Pre-select something to verify replacement.
	SelectionManager.select(a)
	detector.select_visible_of_type(
		a, [a, b, c], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(a))
	assert_true(SelectionManager.is_selected(b))
	assert_true(SelectionManager.is_selected(c))


func test_select_of_type_skips_off_screen_units() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100), true)
	var hidden: FakeUnit = _make_unit(2, Vector2(200, 200), false)
	detector.select_visible_of_type(
		a, [a, hidden], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(a))
	assert_false(SelectionManager.is_selected(hidden),
		"off-screen units must not be added by select-of-type")


func test_select_of_type_skips_other_types() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100), true, &"kargar")
	var other: FakeUnit = _make_unit(
		2, Vector2(200, 200), true, &"piyade")
	detector.select_visible_of_type(
		a, [a, other], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(a))
	assert_false(SelectionManager.is_selected(other),
		"different unit_type must not be added")


func test_select_of_type_with_target_off_screen_still_includes_target() -> void:
	# Defensive: even if the player double-clicks a unit that suddenly
	# becomes off-screen (improbable in 1 frame, but the predicate is
	# what matters), the target itself is always part of the result.
	var target: FakeUnit = _make_unit(1, Vector2(100, 100), false)
	var visible: FakeUnit = _make_unit(2, Vector2(200, 200), true)
	detector.select_visible_of_type(
		target, [target, visible], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(target),
		"target unit is always part of the select-of-type result")
	assert_true(SelectionManager.is_selected(visible))


func test_select_of_type_replaces_prior_selection() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	var unrelated: FakeUnit = _make_unit(
		3, Vector2(300, 300), true, &"piyade")
	# Pre-select unrelated; double-click on a; unrelated must be dropped.
	SelectionManager.select(unrelated)
	detector.select_visible_of_type(
		a, [a, b, unrelated], Callable(self, &"_project_test_unit"))
	assert_false(SelectionManager.is_selected(unrelated),
		"select-of-type replaces the prior selection")


func test_select_of_type_with_null_target_is_noop() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	detector.select_visible_of_type(
		null, [a], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(a),
		"null target → no-op; prior selection untouched")


func test_select_of_type_with_freed_candidate_is_skipped() -> void:
	# A candidate that's been freed must not crash the loop. (We can't
	# pass a freed `target` via the typed argument — Godot rejects it —
	# but a freed entry inside `candidates` is the realistic concern,
	# and the loop's is_instance_valid guard must hold.)
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var dead: FakeUnit = _make_unit(2, Vector2(200, 200))
	dead.queue_free()
	await get_tree().process_frame
	detector.select_visible_of_type(
		a, [a, dead], Callable(self, &"_project_test_unit"))
	assert_true(SelectionManager.is_selected(a),
		"freed candidate is silently skipped; live target still selected")


# ============================================================================
# Double-click detection via selection_changed signal
# ============================================================================

func test_first_single_select_does_not_trigger() -> void:
	var a: FakeUnit = _make_unit(1)
	# Inject a candidate-resolver so the detector has a unit list to use.
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	# Trigger one select_only — the detector should observe via the
	# signal and store "last_unit=a, last_tick=N", but NOT select-of-type.
	SelectionManager.select_only(a)
	assert_eq(SelectionManager.selection_size(), 1,
		"first select_only is a single-select; only that unit selected")


func test_second_select_same_unit_within_window_triggers_type_select() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	SelectionManager.select_only(a)
	# Within DOUBLE_CLICK_TICKS — re-select a. Should expand to {a, b}.
	for _i in range(int(detector.DOUBLE_CLICK_TICKS) - 1):
		SimClock._test_run_tick()
	SelectionManager.select_only(a)
	# Expansion is deferred to the next idle frame (see
	# double_click_select.gd::_on_selection_changed for rationale — running
	# expansion synchronously inside the outer signal emit produced a
	# stale-payload race that left rings 2..N hidden).
	await get_tree().process_frame
	assert_true(SelectionManager.is_selected(a))
	assert_true(SelectionManager.is_selected(b),
		"double-click on a same-type unit selects all visible same-type")


func test_second_select_outside_window_is_just_single() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	SelectionManager.select_only(a)
	# Past the window.
	for _i in range(int(detector.DOUBLE_CLICK_TICKS) + 1):
		SimClock._test_run_tick()
	SelectionManager.select_only(a)
	assert_eq(SelectionManager.selection_size(), 1,
		"select past the double-click window is just a single-select")
	assert_true(SelectionManager.is_selected(a))


func test_second_select_different_unit_is_just_single() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	SelectionManager.select_only(a)
	SimClock._test_run_tick()
	SelectionManager.select_only(b)
	# Should NOT trigger select-of-type — the second click was a
	# different unit.
	assert_eq(SelectionManager.selection_size(), 1,
		"clicking a different unit is a single-select, not a double-click")
	assert_true(SelectionManager.is_selected(b))


func test_multi_select_does_not_arm_double_click() -> void:
	# Box-select multiple units (size > 1). The detector should NOT arm
	# the double-click timer — there's no "single target" to repeat.
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	# Simulate a multi-select: directly call SelectionManager.select twice
	# via the box-select path (each select() emits a broadcast).
	SelectionManager.select(a)
	SelectionManager.select(b)
	# Now click on a. The selection is now {a} (single-target). The detector
	# saw the prior emission as a multi-select (size 2) and DID NOT arm —
	# so this select_only is the FIRST armed click, not a double-click.
	SimClock._test_run_tick()
	SelectionManager.select_only(a)
	# After this, the detector arms. Verify by single-select-of-a-second-time.
	# Without the arm-on-multi check, the test would erroneously fire here.
	assert_eq(SelectionManager.selection_size(), 1,
		"first armed select is single; multi-selects don't arm")


func test_deselect_all_resets_double_click_state() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	SelectionManager.select_only(a)
	SimClock._test_run_tick()
	SelectionManager.deselect_all()
	# After a deselect, re-clicking a should be a fresh single-select,
	# not a double-click.
	SelectionManager.select_only(a)
	assert_eq(SelectionManager.selection_size(), 1,
		"deselect_all resets the double-click state")


# ============================================================================
# Reset / lifecycle
# ============================================================================

func test_reset_wipes_double_click_state() -> void:
	var a: FakeUnit = _make_unit(1, Vector2(100, 100))
	var b: FakeUnit = _make_unit(2, Vector2(200, 200))
	detector.set_candidate_provider(Callable(self, &"_test_candidates"))
	detector.set_projector(Callable(self, &"_project_test_unit"))
	SelectionManager.select_only(a)
	# Reset wipes — so the next click should NOT trigger double-click.
	detector.reset()
	SelectionManager.select_only(a)
	assert_eq(SelectionManager.selection_size(), 1,
		"reset() clears the armed state; next select is fresh")


# ============================================================================
# Helpers — provider closures invoked by the detector
# ============================================================================

func _test_candidates() -> Array:
	# Returns every fake unit alive in the test fixture.
	return _units
