# Tests for the BuildMenu — Phase 3 session 1 wave 1C deliverable 5.
#
# Per 02f_PHASE_3_KICKOFF.md §3 wave 1C. The build menu is a
# CanvasLayer-anchored Control panel that appears when a Kargar is
# selected and surfaces one button per available building type.
#
# What we cover:
#   - Scene loads cleanly with the script attached.
#   - mouse_filter discipline (Pitfall #1): decorative controls = PASS,
#     button = STOP (Button default — not overridden in .tscn).
#   - Visibility logic: hidden when nothing selected; hidden when only
#     combat units selected; visible when a Kargar is in the selection.
#   - Button label reflects BalanceData cost via tr().
#   - Button click emits EventBus.build_placement_started with the
#     right payload (building_kind, cost_coin_x100).
#   - Pitfall #4 awareness: the handler does NOT mutate ResourceSystem
#     synchronously — assert Coin counter is unchanged after pressing
#     the button (cost-deduction happens at placement time, not at
#     button-press time).
extends GutTest


const BuildMenuScene: PackedScene = preload(
	"res://scenes/ui/build_menu.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _menu: Variant
var _kargar: Variant
var _piyade: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")
	SelectionManager.reset()
	ResourceSystem.reset()


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	if _piyade != null and is_instance_valid(_piyade):
		_piyade.queue_free()
	_piyade = null
	SelectionManager.reset()
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_menu() -> Variant:
	var m: Variant = BuildMenuScene.instantiate()
	add_child_autofree(m)
	return m


func _spawn_kargar() -> Variant:
	var u: Variant = KargarScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	return u


func _spawn_piyade() -> Variant:
	var u: Variant = PiyadeScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	return u


# ---------------------------------------------------------------------------
# Scene smoke
# ---------------------------------------------------------------------------

func test_scene_loads() -> void:
	_menu = _spawn_menu()
	assert_not_null(_menu, "build_menu.tscn must load")
	assert_true(_menu is CanvasLayer, "BuildMenu is a CanvasLayer")
	assert_not_null(_menu.get_node_or_null(^"Root"),
		"BuildMenu must expose a Root Control")
	assert_not_null(_menu.get_node_or_null(^"Root/Margin/VBox/KhanehButton"),
		"BuildMenu must expose the KhanehButton")
	assert_not_null(_menu.get_node_or_null(^"Root/Margin/VBox/MazraehButton"),
		"BuildMenu must expose the MazraehButton (wave 1A late-add)")
	assert_not_null(_menu.get_node_or_null(^"Root/Margin/VBox/MadanButton"),
		"BuildMenu must expose the MadanButton (wave 1B)")


# ---------------------------------------------------------------------------
# Mouse filter discipline — Pitfall #1
# ---------------------------------------------------------------------------

func test_root_uses_mouse_filter_stop_bug08_shield() -> void:
	# BUG-08 fix: the Root Control must use MOUSE_FILTER_STOP so the
	# ENTIRE menu surface is an input shield — clicks within the menu's
	# screen rect never fall through to _unhandled_input regardless of
	# the Button's action_mode default (ACTION_MODE_BUTTON_RELEASE) or
	# any future button-property change.
	#
	# Pitfall #1 deeper read: the original wave-1C choice of PASS for
	# Root relied on visibility=false as the primary defense when the
	# menu is hidden. STOP is strictly safer when the menu IS visible:
	# the Button's STOP captures clicks on the button itself, but
	# clicks on decorative menu surface (background, padding) on PRESS
	# would otherwise leak to ClickHandler + BPH _unhandled_input on
	# the PRESS edge (Button.action_mode = ACTION_MODE_BUTTON_RELEASE
	# only consumes on RELEASE), triggering ClickHandler's
	# deselect-all-on-empty-terrain branch. STOP blocks that path.
	_menu = _spawn_menu()
	var root: Control = _menu.get_node(^"Root")
	assert_eq(root.mouse_filter, Control.MOUSE_FILTER_STOP,
		"BUG-08: Root must use MOUSE_FILTER_STOP — the entire menu "
		+ "surface is an input shield, defending against Button "
		+ "action_mode-on-press fall-through")


func test_decorative_controls_use_mouse_filter_pass() -> void:
	# Decorative children stay PASS so input layering inside the menu
	# (button highlighted on hover, etc.) keeps working. Only the Root
	# is STOP — clicks INSIDE the menu rect get captured at Root; the
	# button (also STOP, the default) catches them on the way through.
	# Background/Margin/VBox/Header all PASS because they're never the
	# intended click target.
	_menu = _spawn_menu()
	var bg: ColorRect = _menu.get_node(^"Root/Background")
	var margin: MarginContainer = _menu.get_node(^"Root/Margin")
	var vbox: VBoxContainer = _menu.get_node(^"Root/Margin/VBox")
	var header: Label = _menu.get_node(^"Root/Margin/VBox/HeaderLabel")
	# MOUSE_FILTER_PASS = 1 (Godot enum). Tests against the enum value
	# directly to avoid binding to a name; the property compares int.
	assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_PASS,
		"Background ColorRect must use MOUSE_FILTER_PASS (decorative)")
	assert_eq(margin.mouse_filter, Control.MOUSE_FILTER_PASS,
		"Margin container must use MOUSE_FILTER_PASS")
	assert_eq(vbox.mouse_filter, Control.MOUSE_FILTER_PASS,
		"VBox container must use MOUSE_FILTER_PASS")
	assert_eq(header.mouse_filter, Control.MOUSE_FILTER_PASS,
		"HeaderLabel must use MOUSE_FILTER_PASS (decorative)")


func test_khaneh_button_uses_mouse_filter_stop() -> void:
	# Button default is MOUSE_FILTER_STOP. Not overridden in .tscn —
	# omission is intentional. Confirms the button actually catches
	# clicks (vs. the decorative controls letting them pass through).
	_menu = _spawn_menu()
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/KhanehButton")
	assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP,
		"KhanehButton must use MOUSE_FILTER_STOP (Pitfall #1) so the "
		+ "click reliably lands on the button")


# ---------------------------------------------------------------------------
# Visibility — show when Kargar selected, hide otherwise
# ---------------------------------------------------------------------------

func test_menu_starts_hidden_when_no_selection() -> void:
	_menu = _spawn_menu()
	var root: Control = _menu.get_node(^"Root")
	assert_false(root.visible,
		"BuildMenu starts hidden (no selection at boot)")


func test_menu_shows_when_kargar_selected() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var root: Control = _menu.get_node(^"Root")
	assert_true(root.visible,
		"BuildMenu becomes visible when a Kargar is selected")


func test_menu_hidden_when_only_combat_unit_selected() -> void:
	# Piyade is not a worker (unit_type != &"kargar"). Selecting only a
	# Piyade should NOT show the build menu — building placement is
	# worker-only in Phase 3.
	_menu = _spawn_menu()
	_piyade = _spawn_piyade()
	SelectionManager.select_only(_piyade)
	var root: Control = _menu.get_node(^"Root")
	assert_false(root.visible,
		"BuildMenu stays hidden when only a combat unit is selected")


func test_menu_visible_with_mixed_selection_containing_kargar() -> void:
	# A box-selection that includes BOTH a Kargar and a Piyade should
	# still show the build menu — workers in the selection can build.
	# (Production-side UX: clicking Khaneh dispatches to all workers in
	# the selection.)
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	_piyade = _spawn_piyade()
	SelectionManager.select(_kargar)
	SelectionManager.select(_piyade)
	var root: Control = _menu.get_node(^"Root")
	assert_true(root.visible,
		"BuildMenu visible when selection contains at least one Kargar")


func test_menu_hidden_after_deselect_all() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var root: Control = _menu.get_node(^"Root")
	assert_true(root.visible, "sanity: visible before deselect")
	SelectionManager.deselect_all()
	assert_false(root.visible,
		"BuildMenu hides after deselect_all (Kargar no longer in selection)")


# ---------------------------------------------------------------------------
# Button label — cost from BalanceData via tr()
# ---------------------------------------------------------------------------

func test_khaneh_button_label_shows_cost() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/KhanehButton")
	# tr("UI_BUILDING_KHANEH_COST") → "Khaneh (%d Coin)" → "Khaneh (50 Coin)".
	# (tr returns the key itself when no translation is set up — strings.csv
	# fills the en column so "Khaneh (50 Coin)" is the expected runtime value.
	# Loremaster review 2026-05-14: Persian-primary label per the established
	# UNIT_KARGAR convention.)
	assert_true(btn.text.contains("50"),
		"KhanehButton label must include the cost (50) — got '%s'" % btn.text)


# ---------------------------------------------------------------------------
# Button click — emits build_placement_started
# ---------------------------------------------------------------------------

func test_button_press_emits_build_placement_started() -> void:
	# Capture EventBus.build_placement_started emissions.
	var captured: Array = []
	var handler: Callable = func(kind: StringName, cost: int) -> void:
		captured.append({&"kind": kind, &"cost": cost})
	EventBus.build_placement_started.connect(handler)

	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/KhanehButton")
	# Emit the button's pressed signal directly — same effect as a real
	# click without needing the input layer.
	btn.pressed.emit()
	EventBus.build_placement_started.disconnect(handler)
	assert_eq(captured.size(), 1,
		"build_placement_started fires exactly once per button press")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"kind"], &"khaneh",
		"Signal carries building_kind = &\"khaneh\"")
	assert_eq(ev[&"cost"], 5000,
		"Signal carries cost_coin_x100 = 5000 (50 Coin)")


# ---------------------------------------------------------------------------
# Pitfall #4 awareness — button press does NOT mutate ResourceSystem
# ---------------------------------------------------------------------------

func test_button_press_does_not_deduct_coin_synchronously() -> void:
	# The button is UI-shaped: it emits a read-shaped signal. Cost
	# deduction happens at PLACEMENT (UnitState_Constructing's
	# on-arrival step), not at button-press time. This is the SC2/AoE
	# convention and the wave-1C kickoff is explicit on this point.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/KhanehButton")
	btn.pressed.emit()
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, coin_after,
		"Button press must NOT deduct Coin synchronously (Pitfall #4 — "
		+ "deduction happens at placement, not at button press)")


# ---------------------------------------------------------------------------
# Mazra'eh button — wave-1A late-add for live-test
# ---------------------------------------------------------------------------
# Per session-2 wave-1A late-add brief: wave 1A shipped Mazra'eh class +
# scene but the build menu only exposed Khaneh, blocking live-test. The
# tests below mirror the Khaneh coverage so the new button has parity
# coverage: visibility (gated on Kargar selection), button press emits
# build_placement_started with KIND_MAZRAEH + cost_x100, and the label
# refreshes to the BalanceData cost via tr().

func test_mazraeh_button_visible_when_kargar_selected() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var root: Control = _menu.get_node(^"Root")
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/MazraehButton")
	assert_true(root.visible,
		"BuildMenu root must be visible when a Kargar is selected")
	assert_true(btn.visible,
		"MazraehButton must be visible (parent visible, button visible)")


func test_mazraeh_button_uses_mouse_filter_stop() -> void:
	# Same Pitfall #1 invariant as the Khaneh button — STOP by default
	# so the click reliably lands on the button itself.
	_menu = _spawn_menu()
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/MazraehButton")
	assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP,
		"MazraehButton must use MOUSE_FILTER_STOP (Pitfall #1)")


func test_mazraeh_button_label_shows_cost() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/MazraehButton")
	# tr("UI_BUILDING_MAZRAEH_COST") → "Mazra'eh (%d Coin)" →
	# "Mazra'eh (60 Coin)" per balance.tres bldg_mazraeh.coin_cost=60.
	assert_true(btn.text.contains("60"),
		"MazraehButton label must include the cost (60) — got '%s'" % btn.text)


func test_mazraeh_button_press_emits_build_placement_started_with_kind_mazraeh() -> void:
	var captured: Array = []
	var handler: Callable = func(kind: StringName, cost: int) -> void:
		captured.append({&"kind": kind, &"cost": cost})
	EventBus.build_placement_started.connect(handler)

	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/MazraehButton")
	btn.pressed.emit()
	EventBus.build_placement_started.disconnect(handler)
	assert_eq(captured.size(), 1,
		"build_placement_started fires exactly once per MazraehButton press")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"kind"], &"mazraeh",
		"Signal carries building_kind = &\"mazraeh\"")
	assert_eq(ev[&"cost"], 6000,
		"Signal carries cost_coin_x100 = 6000 (60 Coin × 100)")


func test_mazraeh_button_press_does_not_deduct_coin_synchronously() -> void:
	# Pitfall #4 symmetry: the Mazra'eh button is UI-shaped too. No
	# Coin mutation at press time — deduction happens at placement.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/MazraehButton")
	btn.pressed.emit()
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, coin_after,
		"MazraehButton press must NOT deduct Coin synchronously (Pitfall #4)")


# ---------------------------------------------------------------------------
# Sarbaz-khaneh button (Wave 2A)
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_button_visible_when_kargar_selected() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var root: Control = _menu.get_node(^"Root")
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/SarbazKhanehButton")
	assert_true(root.visible,
		"BuildMenu root must be visible when a Kargar is selected")
	assert_true(btn.visible,
		"SarbazKhanehButton must be visible (parent visible, button visible)")


func test_sarbaz_khaneh_button_uses_mouse_filter_stop() -> void:
	# Same Pitfall #1 invariant as Khaneh/Mazra'eh/Ma'dan buttons.
	_menu = _spawn_menu()
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/SarbazKhanehButton")
	assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP,
		"SarbazKhanehButton must use MOUSE_FILTER_STOP (Pitfall #1)")


func test_sarbaz_khaneh_button_label_shows_cost() -> void:
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/SarbazKhanehButton")
	# tr("UI_BUILDING_SARBAZ_KHANEH_COST") → "Sarbaz-khaneh (%d Coin)" →
	# "Sarbaz-khaneh (100 Coin)" per balance.tres bldg_sarbaz_khaneh.coin_cost=100.
	assert_true(btn.text.contains("100"),
		"SarbazKhanehButton label must include the cost (100) — got '%s'" % btn.text)


func test_sarbaz_khaneh_button_press_emits_build_placement_started_with_kind() -> void:
	var captured: Array = []
	var handler: Callable = func(kind: StringName, cost: int) -> void:
		captured.append({&"kind": kind, &"cost": cost})
	EventBus.build_placement_started.connect(handler)

	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/SarbazKhanehButton")
	btn.pressed.emit()
	EventBus.build_placement_started.disconnect(handler)
	assert_eq(captured.size(), 1,
		"build_placement_started fires exactly once per SarbazKhanehButton press")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"kind"], &"sarbaz_khaneh",
		"Signal carries building_kind = &\"sarbaz_khaneh\"")
	assert_eq(ev[&"cost"], 10000,
		"Signal carries cost_coin_x100 = 10000 (100 Coin × 100)")


func test_sarbaz_khaneh_button_press_does_not_deduct_coin_synchronously() -> void:
	# Pitfall #4 symmetry: the Sarbaz-khaneh button is UI-shaped too. No
	# Coin mutation at press time — deduction happens at placement.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_menu = _spawn_menu()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	var btn: Button = _menu.get_node(^"Root/Margin/VBox/SarbazKhanehButton")
	btn.pressed.emit()
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, coin_after,
		"SarbazKhanehButton press must NOT deduct Coin synchronously (Pitfall #4)")
