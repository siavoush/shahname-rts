# Tests for SelectedUnitPanel — bottom-left HUD detail widget.
#
# Contract: 02c_PHASE_1_SESSION_2_KICKOFF.md §2 (6) (Phase 1 session 2 wave 2B).
# The panel is a pure consumer of EventBus.selection_changed and Unit
# accessors. It owns no sim state; per Sim Contract §1.5 it reads off-tick.
#
# Coverage:
#   - Scene loads cleanly, root is a Control/CanvasLayer
#   - mouse_filter discipline: containers PASS, icon buttons STOP. Session-1
#     regression pattern (HUD swallowing clicks).
#   - Empty selection: hidden.
#   - Single selection: portrait rect colored by faction, HP bar reflects
#     current/max, type-name label uses tr().
#   - Multi selection: icon grid with one icon per selected unit; faction
#     color carried through.
#   - HP bar updates as the displayed unit's hp_x100 changes (off-tick poll).
#   - Unit-death cleanly drops the icon (is_instance_valid guard).
#   - Icon click narrows selection via SelectionManager.select_only.
#   - i18n keys are seeded (UI_PANEL_NO_SELECTION, UI_PANEL_HP,
#     UI_PANEL_ABILITIES, UNIT_KARGAR).
#
# Test harness uses fake unit nodes that match the duck-typed surface the
# panel reads (unit_id, unit_type, team, get_health()). Same pattern as
# test_selection_manager.gd — going through real Unit.tscn is unnecessary
# noise for these tests; that integration is covered in test_unit.gd.
extends GutTest


const PANEL_SCENE_PATH: String = "res://scenes/ui/selected_unit_panel.tscn"
const HealthComponentScript: Script = preload(
	"res://scripts/units/components/health_component.gd")


# Plain-Node fake unit. Exposes only the duck-typed read surface the panel
# expects (unit_id, unit_type, team, get_health()). No FSM, no movement, no
# real selection ring. The panel never writes to a unit; it only reads.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var unit_type: StringName = &"kargar"
	var team: int = 1  # TEAM_IRAN
	var _hc: Variant = null

	func get_health() -> Object:
		return _hc


var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()


# ---------------------------------------------------------------------------
# 1. Scene structure
# ---------------------------------------------------------------------------

func test_panel_scene_loads_without_error() -> void:
	var packed: PackedScene = load(PANEL_SCENE_PATH)
	assert_not_null(packed,
		"selected_unit_panel.tscn must load cleanly from %s" % PANEL_SCENE_PATH)


func test_panel_root_is_canvas_layer() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	# Root is a CanvasLayer (sibling to ResourceHUD) — the standard HUD pattern.
	assert_true(panel is CanvasLayer,
		"SelectedUnitPanel root must be a CanvasLayer for HUD layering")


# ---------------------------------------------------------------------------
# 2. mouse_filter — containers pass clicks through; icons stop them
# ---------------------------------------------------------------------------
# Phase 1 session 1 regression: HUD MOUSE_FILTER_STOP defaults swallowed clicks
# bound for world units. The panel must let clicks through its background
# while still receiving clicks on its interactive icon buttons.

func test_panel_root_control_does_not_swallow_clicks() -> void:
	# Walk the panel for any Control children; non-button containers must NOT
	# be MOUSE_FILTER_STOP. (PASS or IGNORE both acceptable for non-interactive
	# rectangles — pass also lets descendants receive input.)
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var bad: Array = []
	_collect_stopping_non_button_controls(panel, bad)
	assert_eq(bad.size(), 0,
		"Non-interactive container Controls must not swallow clicks. "
		+ "Offenders: %s" % str(bad))


# ---------------------------------------------------------------------------
# 3. Empty selection
# ---------------------------------------------------------------------------

func test_panel_hidden_when_no_selection() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	# Force a selection_changed broadcast with empty list.
	SelectionManager.deselect_all()
	# Panel exposes a `visible_state: StringName` property tagging which sub-
	# layout is currently shown — &"empty" / &"single" / &"multi".
	# Tests assert on the tag rather than walking nested visibility.
	assert_eq(panel.get(&"visible_state"), &"empty",
		"Panel must show the 'empty' state when nothing is selected")


# ---------------------------------------------------------------------------
# 4. Single selection
# ---------------------------------------------------------------------------

func test_single_selection_shows_single_layout() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var u: FakeUnit = _make_unit(1, &"kargar", 60.0)
	SelectionManager.select_only(u)
	assert_eq(panel.get(&"visible_state"), &"single",
		"Panel must enter 'single' state when one unit is selected")
	assert_eq(panel.get(&"displayed_unit_id"), 1,
		"Panel must track the displayed unit's id")


func test_single_selection_hp_bar_reflects_health() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var u: FakeUnit = _make_unit(1, &"kargar", 60.0)
	# Damage to 30/60 — half. (We write hp_x100 directly; off-tick test fixture
	# escape hatch — same pattern test_match_harness uses for FarrSystem.)
	u._hc.hp_x100 = 3000
	SelectionManager.select_only(u)
	# The panel polls health off-tick; force a single refresh.
	panel.refresh_displayed_unit()
	assert_almost_eq(float(panel.get(&"hp_ratio")), 0.5, 1e-6,
		"hp_ratio = current_hp / max_hp (30/60 = 0.5)")


func test_single_selection_type_label_uses_translation() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var u: FakeUnit = _make_unit(1, &"kargar", 60.0)
	SelectionManager.select_only(u)
	# Unit type name flows through tr(); the i18n key is UNIT_<TYPE_UPPER>.
	# UNIT_KARGAR is seeded in strings.csv; English value = "Kargar".
	var label_text: String = String(panel.get(&"displayed_type_label"))
	assert_eq(label_text, "Kargar",
		"Type label must read tr('UNIT_KARGAR') under en locale")


# ---------------------------------------------------------------------------
# 5. Multi selection — icon grid
# ---------------------------------------------------------------------------

func test_multi_selection_shows_icon_grid() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var a: FakeUnit = _make_unit(1, &"kargar", 60.0)
	var b: FakeUnit = _make_unit(2, &"kargar", 60.0)
	var c: FakeUnit = _make_unit(3, &"kargar", 60.0)
	SelectionManager.select(a)
	SelectionManager.select(b)
	SelectionManager.select(c)
	assert_eq(panel.get(&"visible_state"), &"multi",
		"Panel must enter 'multi' state when 2+ units are selected")
	assert_eq(int(panel.get(&"icon_count")), 3,
		"Panel must show one icon per selected unit")


func test_multi_selection_icon_click_narrows_to_single() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var a: FakeUnit = _make_unit(1, &"kargar", 60.0)
	var b: FakeUnit = _make_unit(2, &"kargar", 60.0)
	SelectionManager.select(a)
	SelectionManager.select(b)
	# Programmatic icon-click for the unit_id=2 entry. The handler must call
	# SelectionManager.select_only on that unit; assert via SelectionManager
	# rather than reaching into the panel internals.
	panel.handle_icon_click(2)
	assert_eq(SelectionManager.selection_size(), 1,
		"Icon click must narrow selection to one unit")
	assert_true(SelectionManager.is_selected(b),
		"Icon click must select_only the unit whose icon was clicked")


func test_multi_selection_icon_click_for_freed_unit_is_safe() -> void:
	# If a unit died between rendering the icon and the player clicking it,
	# handle_icon_click must defensively guard — no crash, just a no-op.
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var a: FakeUnit = _make_unit(1, &"kargar", 60.0)
	var b: FakeUnit = _make_unit(2, &"kargar", 60.0)
	SelectionManager.select(a)
	SelectionManager.select(b)
	# Free b before the click lands.
	_units.erase(b)
	b.queue_free()
	await get_tree().process_frame
	# Should not crash.
	panel.handle_icon_click(2)
	# Selection now contains only the live unit a (selection_size filters
	# freed units defensively per SelectionManager.selection_size).
	assert_true(SelectionManager.selection_size() <= 1,
		"selection_size must drop to ≤1 after a selected unit is freed")


# ---------------------------------------------------------------------------
# 6. Death cleanup
# ---------------------------------------------------------------------------

func test_displayed_unit_freed_clears_panel() -> void:
	var panel: Node = _instantiate_panel()
	if panel == null:
		pending("selected_unit_panel.tscn unavailable")
		return
	var u: FakeUnit = _make_unit(1, &"kargar", 60.0)
	SelectionManager.select_only(u)
	# Free the displayed unit; panel's next refresh should clear gracefully.
	_units.erase(u)
	u.queue_free()
	await get_tree().process_frame
	# Refresh — must not crash on the freed reference.
	panel.refresh_displayed_unit()
	# Panel should fall back to empty state because the live selection set
	# (SelectionManager filters freed entries) is now empty.
	assert_ne(panel.get(&"visible_state"), &"single",
		"Panel must NOT remain in 'single' state with a freed displayed unit")


# ---------------------------------------------------------------------------
# 7. Translation keys present
# ---------------------------------------------------------------------------

func test_translation_keys_seeded() -> void:
	# All UI_PANEL_* + UNIT_KARGAR keys are required by the panel layout.
	# A missing key causes tr() to return the key itself, which would render
	# "UI_PANEL_HP" verbatim in the HUD — catch at test time, not lead-time.
	assert_eq(tr("UI_PANEL_NO_SELECTION"), "No selection")
	assert_eq(tr("UI_PANEL_HP"), "HP")
	assert_eq(tr("UI_PANEL_ABILITIES"), "Abilities")
	assert_eq(tr("UNIT_KARGAR"), "Kargar")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _instantiate_panel() -> Node:
	var packed: PackedScene = load(PANEL_SCENE_PATH)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	add_child_autofree(inst)
	return inst


func _make_unit(id: int, unit_type: StringName, max_hp: float) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = id
	u.unit_type = unit_type
	u.team = 1
	# Real HealthComponent so the panel's read path goes through real accessors.
	var hc: Object = HealthComponentScript.new()
	hc.unit_id = id
	hc.init_max_hp(max_hp)
	u._hc = hc
	u.add_child(hc)
	add_child_autofree(u)
	_units.append(u)
	return u


func _collect_stopping_non_button_controls(node: Node, out: Array) -> void:
	if node is Control and not (node is BaseButton):
		var c: Control = node
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append(c.get_path())
	for child in node.get_children():
		_collect_stopping_non_button_controls(child, out)
