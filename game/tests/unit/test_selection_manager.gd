# Tests for SelectionManager autoload.
#
# Contract: docs/02b_PHASE_1_KICKOFF.md §2 (7) + this session's brief —
#   - SelectionManager.select adds to selection and emits selection_changed
#   - select_only clears existing selection then selects the target
#   - deselect_all clears selection and emits an empty broadcast
#   - add_to_selection scaffolded API (Phase 1 session 2 wires Shift+click)
#   - is_selected and selection_size read accessors
#   - SelectableComponent on the unit toggles via the autoload's calls
#
# Test fixtures use a minimal "fake unit" Node3D wrapper that exposes the
# Unit-shaped surface ClickHandler and SelectionManager rely on:
#   - unit_id: int
#   - get_selectable() returning a real SelectableComponent
#   - replace_command method (no-op for these tests)
#   - command_queue field (CommandQueue stub)
#
# Going through real Unit.tscn is unnecessary for these tests; the Unit
# class is integration-tested in test_unit.gd. We test the autoload's
# state machine + signal emission contract here.
extends GutTest


const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain-Node fake unit. Exposes the duck-typed surface SelectionManager
# expects (get_selectable, unit_id, command_queue, replace_command).
# Inherits Node3D so ring's parent expectation is satisfied.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var command_queue: Object = null  # stubbed; tests don't drive the queue here
	var _selectable: Variant = null
	var _last_replace_kind: StringName = &""
	var _last_replace_payload: Dictionary = {}
	var _replace_call_count: int = 0

	func get_selectable() -> Object:
		return _selectable

	func replace_command(kind: StringName, payload: Dictionary) -> void:
		_replace_call_count += 1
		_last_replace_kind = kind
		_last_replace_payload = payload


# Captures EventBus.selection_changed payload(s).
class SignalRecorder extends RefCounted:
	var emissions: Array = []

	func on_selection_changed(ids: Array) -> void:
		# Make a defensive copy — Godot may pass the same Array reference
		# across emissions (it shouldn't but better safe).
		var copy: Array = []
		for id in ids:
			copy.append(int(id))
		emissions.append(copy)


var _recorder: SignalRecorder
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	_recorder = SignalRecorder.new()
	# Re-connect every test so a freshly-reset autoload still sees us.
	if not EventBus.selection_changed.is_connected(_recorder.on_selection_changed):
		EventBus.selection_changed.connect(_recorder.on_selection_changed)
	_units.clear()


func after_each() -> void:
	if _recorder != null and EventBus.selection_changed.is_connected(_recorder.on_selection_changed):
		EventBus.selection_changed.disconnect(_recorder.on_selection_changed)
	_recorder = null
	# Free any spawned fake units so the global SelectionManager doesn't keep
	# stale references around for the next test.
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()


# Construct a fake unit with a real SelectableComponent attached. Adds it to
# the scene so the component's _ready (which subscribes to EventBus and
# creates its ring) actually runs.
func _make_unit(uid: int) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	add_child_autofree(u)
	# Attach a real SelectableComponent so select()/deselect() route
	# through the same code path the production Unit takes.
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


# ===========================================================================
# select()
# ===========================================================================

func test_select_adds_unit_to_selection() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	assert_eq(SelectionManager.selection_size(), 1,
		"select() must add the unit to the selection set")
	assert_true(SelectionManager.is_selected(u),
		"is_selected() must report true after select()")


func test_select_emits_selection_changed_with_unit_id() -> void:
	var u: FakeUnit = _make_unit(42)
	SelectionManager.select(u)
	assert_eq(_recorder.emissions.size(), 1,
		"select() must emit selection_changed exactly once")
	assert_eq(_recorder.emissions[0], [42],
		"signal payload must contain the selected unit_id")


func test_select_calls_select_on_selectable_component() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	# The SelectableComponent's is_selected reflects the toggle.
	assert_true(u._selectable.is_selected,
		"SelectableComponent.is_selected must be true after SelectionManager.select()")


func test_select_is_idempotent() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	SelectionManager.select(u)  # re-select same unit — should no-op
	assert_eq(SelectionManager.selection_size(), 1,
		"select() of an already-selected unit must be idempotent")
	assert_eq(_recorder.emissions.size(), 1,
		"re-selecting the same unit must NOT emit a second signal")


func test_select_null_is_safe_noop() -> void:
	SelectionManager.select(null)
	assert_eq(SelectionManager.selection_size(), 0,
		"select(null) must be a safe no-op")
	assert_eq(_recorder.emissions.size(), 0,
		"select(null) must not emit a signal")


# ===========================================================================
# select_only()
# ===========================================================================

func test_select_only_replaces_existing_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	_recorder.emissions.clear()  # ignore the first emission
	SelectionManager.select_only(b)
	assert_eq(SelectionManager.selection_size(), 1,
		"select_only must clear existing selection")
	assert_true(SelectionManager.is_selected(b),
		"select_only target must be in selection")
	assert_false(SelectionManager.is_selected(a),
		"previously-selected unit must be deselected by select_only")


func test_select_only_deselects_old_unit_visual() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select_only(b)
	assert_false(a._selectable.is_selected,
		"old unit's SelectableComponent must be deselected by select_only")
	assert_true(b._selectable.is_selected,
		"new unit's SelectableComponent must be selected by select_only")


func test_select_only_emits_signal_exactly_once() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.select_only(b)
	assert_eq(_recorder.emissions.size(), 1,
		"select_only must emit selection_changed exactly once (single-broadcast contract)")
	assert_eq(_recorder.emissions[0], [2],
		"signal payload must contain only the new target")


func test_select_only_with_null_clears_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.select_only(null)
	assert_eq(SelectionManager.selection_size(), 0,
		"select_only(null) clears the selection (deselect-all semantics)")
	assert_eq(_recorder.emissions.size(), 1,
		"select_only(null) emits once")
	assert_eq(_recorder.emissions[0], [],
		"select_only(null) emits empty list")


# ===========================================================================
# deselect_all()
# ===========================================================================

func test_deselect_all_clears_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	SelectionManager.deselect_all()
	assert_eq(SelectionManager.selection_size(), 0,
		"deselect_all clears the selection set")
	assert_false(a._selectable.is_selected,
		"every previously-selected unit's component must be deselected")


func test_deselect_all_emits_empty_broadcast() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.deselect_all()
	assert_eq(_recorder.emissions.size(), 1,
		"deselect_all emits selection_changed exactly once")
	assert_eq(_recorder.emissions[0], [],
		"deselect_all emits an empty list")


func test_deselect_all_on_empty_set_still_emits() -> void:
	# This is an explicit choice (documented in source) — deselect_all on an
	# already-empty set still emits the empty broadcast so consumers re-render.
	SelectionManager.deselect_all()
	assert_eq(_recorder.emissions.size(), 1,
		"deselect_all on empty selection still broadcasts")


# ===========================================================================
# add_to_selection() — Phase 1 session 2 hook (API exists, ring scaffolded now)
# ===========================================================================

func test_add_to_selection_extends_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	assert_eq(SelectionManager.selection_size(), 2,
		"add_to_selection adds without clearing")
	assert_true(SelectionManager.is_selected(a))
	assert_true(SelectionManager.is_selected(b))


# ===========================================================================
# Lifecycle / freed units
# ===========================================================================

func test_freed_units_are_filtered_from_selection_size() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select(b)
	a.queue_free()
	# Wait for the queued free.
	await get_tree().process_frame
	# selection_size filters freed units defensively.
	assert_eq(SelectionManager.selection_size(), 1,
		"freed units must not be counted in selection_size")


func test_reset_clears_selection_without_emitting() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.reset()
	assert_eq(SelectionManager.selection_size(), 0,
		"reset() clears the selection set")
	assert_eq(_recorder.emissions.size(), 0,
		"reset() does NOT emit (per source contract — use deselect_all for the broadcast)")


# ===========================================================================
# selected_units accessor (returns a fresh copy; safe to iterate)
# ===========================================================================

func test_selected_units_returns_a_copy() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	var sel: Array = SelectionManager.selected_units
	assert_eq(sel.size(), 1)
	# Mutating the returned array must not affect the autoload's state.
	sel.clear()
	assert_eq(SelectionManager.selection_size(), 1,
		"selected_units returns a fresh copy; mutating it must not leak")
