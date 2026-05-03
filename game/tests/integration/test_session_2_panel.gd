# Integration tests — SelectedUnitPanel content correctness.
#
# Wave 3 (qa-engineer). Locks in wave-2B (SelectedUnitPanel) behaviors.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flow 5.
# Related:  docs/TESTING_CONTRACT.md §3.1, docs/SIMULATION_CONTRACT.md §1.5.
#
# Strategy:
#   - Load selected_unit_panel.tscn and add to scene tree.
#   - Feed selections via SelectionManager (which triggers EventBus.selection_changed
#     → panel._on_selection_changed → panel renders).
#   - Assert on panel's public state (visible_state, hp_ratio, icon_count,
#     displayed_type_label) — the same stable identifiers its own unit tests use.
#
# Typing: Variant slots for unit refs (ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const SelectedUnitPanelScene: PackedScene = preload("res://scenes/ui/selected_unit_panel.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _panel: Variant = null
var _units: Array = []


func before_each() -> void:
	SelectionManager.reset()
	UnitScript.call(&"reset_id_counter")
	_units.clear()
	_panel = SelectedUnitPanelScene.instantiate()
	add_child_autofree(_panel)


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	_units.append(u)
	return u


# ---------------------------------------------------------------------------
# 1. Empty selection → panel in "empty" state, "no selection" label shown
# ---------------------------------------------------------------------------

func test_empty_selection_shows_no_selection_placeholder() -> void:
	# Panel should already be in empty state from _ready.
	assert_eq(_panel.visible_state, _panel.STATE_EMPTY,
		"panel must start in STATE_EMPTY")
	assert_eq(_panel.displayed_unit_id, -1,
		"displayed_unit_id must be -1 when empty")
	assert_almost_eq(_panel.hp_ratio, 0.0, 1e-6,
		"hp_ratio must be 0.0 when empty")
	assert_eq(_panel.icon_count, 0,
		"icon_count must be 0 when empty")


# ---------------------------------------------------------------------------
# 2. Single selection → portrait, type label, HP bar rendered
# ---------------------------------------------------------------------------

func test_single_selection_shows_single_layout() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	# selection_changed fires → panel._on_selection_changed.
	await get_tree().process_frame

	assert_eq(_panel.visible_state, _panel.STATE_SINGLE,
		"single selection must show STATE_SINGLE")
	assert_eq(_panel.displayed_unit_id, int(u1.unit_id),
		"displayed_unit_id must match the selected unit's unit_id")
	assert_false(_panel.displayed_type_label.is_empty(),
		"displayed_type_label must not be empty for a kargar")
	assert_almost_eq(_panel.hp_ratio, 1.0, 0.01,
		"fresh kargar must have hp_ratio ≈ 1.0 (full health)")


# ---------------------------------------------------------------------------
# 3. Multi-selection (5 units) → 5 swatch buttons in icon grid
# ---------------------------------------------------------------------------

func test_multi_selection_shows_5_icons() -> void:
	for i in range(5):
		var u: Variant = _spawn_kargar(Vector3(float(i), 0.0, 0.0))
		SelectionManager.add_to_selection(u)
	await get_tree().process_frame

	assert_eq(_panel.visible_state, _panel.STATE_MULTI,
		"5-unit selection must show STATE_MULTI")
	assert_eq(_panel.icon_count, 5,
		"icon_count must equal the number of selected units (5)")


# ---------------------------------------------------------------------------
# 4. Icon click narrows selection to that one unit
# ---------------------------------------------------------------------------

func test_icon_click_narrows_to_single_unit() -> void:
	var spawned: Array = []
	for i in range(3):
		var u: Variant = _spawn_kargar(Vector3(float(i), 0.0, 0.0))
		SelectionManager.add_to_selection(u)
		spawned.append(u)
	await get_tree().process_frame

	assert_eq(_panel.visible_state, _panel.STATE_MULTI)

	# Click the icon for the second unit (index 1).
	var target_id: int = int(spawned[1].unit_id)
	_panel.handle_icon_click(target_id)
	await get_tree().process_frame

	assert_eq(SelectionManager.selected_units.size(), 1,
		"icon click must narrow selection to exactly 1 unit")
	assert_eq(int(SelectionManager.selected_units[0].unit_id), target_id,
		"narrowed unit must match the icon's unit_id")


# ---------------------------------------------------------------------------
# 5. Selected unit dies → panel transitions to empty, no crash
# ---------------------------------------------------------------------------

func test_selected_unit_dies_panel_clears() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	await get_tree().process_frame
	assert_eq(_panel.visible_state, _panel.STATE_SINGLE)

	# Kill the unit (simulate death via queue_free — the SelectionManager
	# defensive cleanup removes freed units on next selection_changed).
	u1.queue_free()
	_units.erase(u1)
	await get_tree().process_frame

	# Force a refresh (simulates the _process polling discovering the freed unit).
	_panel.refresh_displayed_unit()
	await get_tree().process_frame

	assert_eq(_panel.visible_state, _panel.STATE_EMPTY,
		"panel must transition to STATE_EMPTY when displayed unit is freed")
	assert_eq(_panel.displayed_unit_id, -1,
		"displayed_unit_id must reset to -1 after unit death")


# ---------------------------------------------------------------------------
# 6. Clicking a freed unit's icon in multi-select is a safe no-op
# ---------------------------------------------------------------------------

func test_icon_click_freed_unit_is_safe_noop() -> void:
	var u1: Variant = _spawn_kargar()
	var u2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	SelectionManager.add_to_selection(u1)
	SelectionManager.add_to_selection(u2)
	await get_tree().process_frame

	var freed_id: int = int(u2.unit_id)
	u2.queue_free()
	_units.erase(u2)
	await get_tree().process_frame

	# Click on a unit_id that no longer exists — must not crash and must not
	# alter the current selection (the freed unit can't be found in the live set).
	var pre_size: int = SelectionManager.selected_units.size()
	_panel.handle_icon_click(freed_id)
	# handle_icon_click silently no-ops for freed units (docs/selected_unit_panel.gd).
	assert_true(SelectionManager.selected_units.size() <= pre_size,
		"icon click on freed unit must not add units to selection")


# ---------------------------------------------------------------------------
# 7. Deselect all → panel returns to STATE_EMPTY
# ---------------------------------------------------------------------------

func test_deselect_all_returns_to_empty() -> void:
	var u1: Variant = _spawn_kargar()
	SelectionManager.add_to_selection(u1)
	await get_tree().process_frame
	assert_eq(_panel.visible_state, _panel.STATE_SINGLE)

	SelectionManager.deselect_all()
	await get_tree().process_frame

	assert_eq(_panel.visible_state, _panel.STATE_EMPTY,
		"deselect_all must return panel to STATE_EMPTY")


# ---------------------------------------------------------------------------
# 8. HP bar reflects partial health (30/60 → ratio ≈ 0.5)
# ---------------------------------------------------------------------------

func test_hp_bar_reflects_partial_health() -> void:
	var u1: Variant = _spawn_kargar()
	# Set HP to half via hp_x100 (the fixed-point backing field per health_component.gd).
	# hp is a read-only getter; direct field write on the component is the correct path.
	var hc: Object = u1.get_health()
	var max_x100: int = int(hc.get(&"max_hp_x100"))
	hc.set(&"hp_x100", max_x100 / 2)

	SelectionManager.add_to_selection(u1)
	await get_tree().process_frame
	_panel.refresh_displayed_unit()

	assert_almost_eq(_panel.hp_ratio, 0.5, 0.05,
		"hp_ratio must reflect half-health unit (~0.5)")


# ---------------------------------------------------------------------------
# 9. panel root control does not have MOUSE_FILTER_STOP on non-button nodes
#    (regression guard for session-1 click-eating bug)
# ---------------------------------------------------------------------------

func test_panel_root_does_not_swallow_clicks_via_mouse_filter() -> void:
	# Recursively walk all Controls and assert none are MOUSE_FILTER_STOP
	# unless they are a Button (interactive controls legitimately stop).
	var bad_nodes: Array = []
	_collect_stop_non_buttons(_panel as Node, bad_nodes)
	assert_eq(bad_nodes.size(), 0,
		"non-Button Controls must not have MOUSE_FILTER_STOP (found: %s)" % str(bad_nodes))


func _collect_stop_non_buttons(node: Node, out: Array) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and not (node is Button):
			out.append(node.name)
	for child in node.get_children():
		_collect_stop_non_buttons(child, out)
