# Tests for SelectableComponent.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md context (selection is a UI concern;
# the simulation neither produces nor consumes EventBus.selection_changed).
#
# What we cover:
#   - select() sets is_selected and shows the ring
#   - deselect() clears is_selected and hides the ring
#   - listening to EventBus.selection_changed updates state per unit_id
#   - components NOT in the broadcast list become deselected
#   - default ring is created when no ring_path is provided
extends GutTest


const SelectableComponentScript: Script = preload("res://scripts/units/components/selectable_component.gd")


var _parent: Node3D
var _sc: Variant


func before_each() -> void:
	SimClock.reset()
	_parent = Node3D.new()
	add_child_autofree(_parent)

	_sc = SelectableComponentScript.new()
	_sc.unit_id = 7
	_parent.add_child(_sc)


func after_each() -> void:
	if is_instance_valid(_sc):
		_sc.queue_free()
	if is_instance_valid(_parent):
		_parent.queue_free()
	SimClock.reset()


# ---------------------------------------------------------------------------
# select / deselect
# ---------------------------------------------------------------------------

func test_select_sets_is_selected_and_shows_ring() -> void:
	assert_false(_sc.is_selected, "fresh component is unselected")
	_sc.select()
	assert_true(_sc.is_selected, "select() sets is_selected to true")
	assert_true(_sc._ring.visible, "select() shows the ring")


func test_deselect_clears_is_selected_and_hides_ring() -> void:
	_sc.select()
	_sc.deselect()
	assert_false(_sc.is_selected, "deselect() clears is_selected")
	assert_false(_sc._ring.visible, "deselect() hides the ring")


func test_select_is_idempotent() -> void:
	_sc.select()
	_sc.select()
	assert_true(_sc.is_selected,
		"select() called twice still results in is_selected = true")


func test_deselect_is_idempotent_when_already_unselected() -> void:
	# A fresh component is unselected. deselect() must not crash or
	# create false negatives.
	_sc.deselect()
	assert_false(_sc.is_selected)


# ---------------------------------------------------------------------------
# Default ring construction
# ---------------------------------------------------------------------------

func test_default_ring_is_created_when_no_ring_path_set() -> void:
	# The component constructed in before_each had no ring_path; default ring exists.
	# Note: the ring is added to the parent via call_deferred (to avoid
	# "parent busy setting up children" when the unit composes us in its
	# own _ready); wait one frame for the deferred call to settle.
	await get_tree().process_frame
	assert_not_null(_sc._ring, "default ring must be auto-created")
	assert_true(_sc._ring is MeshInstance3D, "ring is a MeshInstance3D")
	# Ring is a sibling under the parent so it follows the unit's transform.
	assert_eq(_sc._ring.get_parent(), _parent,
		"ring is parented to the unit, not the component")


func test_default_ring_starts_hidden() -> void:
	assert_false(_sc._ring.visible,
		"ring must start hidden — visible only when selected")


# ---------------------------------------------------------------------------
# EventBus.selection_changed subscription
# ---------------------------------------------------------------------------

func test_selection_changed_signal_with_my_id_selects() -> void:
	# Broadcast a list containing this component's unit_id.
	EventBus.selection_changed.emit([7] as Array)
	assert_true(_sc.is_selected,
		"component with matching unit_id must become selected")
	assert_true(_sc._ring.visible)


func test_selection_changed_signal_without_my_id_deselects() -> void:
	_sc.select()
	# Now broadcast a list that does NOT contain this component's id.
	EventBus.selection_changed.emit([99, 100] as Array)
	assert_false(_sc.is_selected,
		"component must deselect when its id is absent from the broadcast")
	assert_false(_sc._ring.visible)


func test_selection_changed_with_empty_list_deselects() -> void:
	_sc.select()
	EventBus.selection_changed.emit([] as Array)
	assert_false(_sc.is_selected,
		"empty selection list must deselect every unit")


func test_selection_changed_handles_multiple_ids() -> void:
	# A list with multiple ids, including ours, must select us.
	EventBus.selection_changed.emit([3, 7, 9] as Array)
	assert_true(_sc.is_selected)


# ---------------------------------------------------------------------------
# Cleanup on tree exit
# ---------------------------------------------------------------------------

func test_disconnect_on_exit_tree_does_not_crash_on_late_emit() -> void:
	# A unit that exits the tree must disconnect cleanly so a later
	# selection_changed broadcast doesn't try to call into a freed
	# component. This is the §5 lifetime guarantee implicit in the
	# component pattern.
	_sc.queue_free()
	# Wait for the queued free to actually happen.
	await get_tree().process_frame
	# Now emit — must not crash.
	EventBus.selection_changed.emit([7] as Array)
	pass_test("selection_changed emit after component free did not crash")
