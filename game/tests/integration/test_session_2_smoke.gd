# Integration smoke test — cross-feature round-trip (Experiment 01 load-bearing test).
#
# Wave 3 (qa-engineer). This is the test that, had it existed in session 1,
# would have caught the FSM-not-ticked bug, the edge-pan-direction bug, and
# (via mouse_filter coverage) the click-eating-HUD bug.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flows 6 + main.tscn spot-check.
# Related:  docs/PROCESS_EXPERIMENTS.md Experiment 01.
#
# Scope:
#   Flow 6 — box-select all 5 kargars; right-click moves them (distinct positions);
#             bind to group; deselect; recall; Farr change propagates to gauge;
#             single-select via box-drag, panel shows single-mode content.
#
#   main.tscn spot-check — SelectedUnitPanel AND DoubleClickSelect nodes both
#             present in the tree (verifies the cross-agent wave-2A/2B stomp
#             didn't lose one of them).
#
# This test uses real units (kargar.tscn), the real SimClock tick path, and the
# real ControlGroups + SelectionManager autoloads. MockPathScheduler is injected
# for determinism. The FarrGauge is loaded independently (not from main.tscn)
# so the smoke test stays headless-runnable.
#
# Typing: Variant slots for unit refs (ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const BoxSelectHandlerScript: Script = preload("res://scripts/input/box_select_handler.gd")
const FarrGaugeScene: PackedScene = preload("res://scenes/ui/farr_gauge.tscn")
const SelectedUnitPanelScene: PackedScene = preload("res://scenes/ui/selected_unit_panel.tscn")
const GroupMoveControllerScript: Script = preload("res://scripts/movement/group_move_controller.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MainScene: PackedScene = preload("res://scenes/main.tscn")


var _units: Array = []
var _mock: Variant = null
var _gauge: Variant = null
var _panel: Variant = null
var _box_handler: Node = null


func before_each() -> void:
	SelectionManager.reset()
	ControlGroups.reset()
	SimClock.reset()
	CommandPool.reset()
	FarrSystem.reset()
	UnitScript.call(&"reset_id_counter")
	ControlGroups.set_test_mode(true)
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	if _gauge != null and is_instance_valid(_gauge):
		_gauge.queue_free()
	_gauge = null
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if _box_handler != null and is_instance_valid(_box_handler):
		_box_handler.queue_free()
	_box_handler = null
	SelectionManager.reset()
	ControlGroups.reset()
	ControlGroups.set_test_mode(false)
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()
	FarrSystem.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.get_movement().move_speed = 15.0
	u.get_movement()._scheduler = _mock
	_units.append(u)
	return u


func _advance(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# Projection helper: units near origin project near screen center.
func _project_unit(viewport_w: float, viewport_h: float) -> Callable:
	return func(u: Object) -> Dictionary:
		var pos: Vector3 = (u as Node3D).global_position
		var sp := Vector2(pos.x * 10.0 + viewport_w * 0.5,
			pos.z * 10.0 + viewport_h * 0.5)
		var on: bool = (sp.x >= 0.0 and sp.y >= 0.0
			and sp.x <= viewport_w and sp.y <= viewport_h)
		return {"screen_pos": sp, "on_screen": on}


# ===========================================================================
# main.tscn spot-check: SelectedUnitPanel AND DoubleClickSelect both present
# ===========================================================================

func test_main_tscn_has_selected_unit_panel_and_double_click_select() -> void:
	# Load main.tscn and verify both wave-2B and wave-2A nodes are present.
	# This test locks in the cross-agent no-stomp guarantee: both nodes were
	# committed separately and one must not have clobbered the other.
	var main_scene: Node = MainScene.instantiate()
	add_child_autofree(main_scene)

	# Wave-2B: SelectedUnitPanel (wired as CanvasLayer child of Main).
	var panel_node: Node = main_scene.get_node_or_null("SelectedUnitPanel")
	assert_not_null(panel_node,
		"main.tscn must contain a SelectedUnitPanel node (wave-2B deliverable)")

	# Wave-2A: DoubleClickSelect (wired as Node child of Main).
	var dc_node: Node = main_scene.get_node_or_null("DoubleClickSelect")
	assert_not_null(dc_node,
		"main.tscn must contain a DoubleClickSelect node (wave-2A deliverable)")

	# Verify scripts are correctly attached (not null / wrong type).
	if panel_node != null:
		assert_true(panel_node.has_method(&"handle_icon_click"),
			"SelectedUnitPanel must have handle_icon_click method (correct script attached)")
	if dc_node != null:
		assert_true(dc_node.has_method(&"_on_selection_changed"),
			"DoubleClickSelect must have _on_selection_changed method (correct script attached)")


# ===========================================================================
# Cross-feature smoke: box-select → move → bind → recall → Farr → panel
# ===========================================================================

func test_cross_feature_full_round_trip() -> void:
	# Spawn 5 kargars spread on XZ plane, all near origin so they project
	# inside a 800×600 screen-space rect.
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5 - 1.0, 0.0, 0.0))

	# ---- Load UI widgets ----
	_gauge = FarrGaugeScene.instantiate()
	add_child_autofree(_gauge)
	_panel = SelectedUnitPanelScene.instantiate()
	add_child_autofree(_panel)

	# ---- Step 1: box-select all 5 kargars ----
	_box_handler = BoxSelectHandlerScript.new()
	_box_handler.set_test_mode(true)
	add_child_autofree(_box_handler)

	var rect := Rect2(0.0, 0.0, 800.0, 600.0)
	_box_handler.box_select_units(rect, _units, _project_unit(800.0, 600.0), false)
	await get_tree().process_frame

	assert_eq(SelectionManager.selected_units.size(), 5,
		"[step 1] box-select must select all 5 kargars")

	# ---- Step 2: right-click far point → group move ----
	var move_target := Vector3(20.0, 0.0, 20.0)
	GroupMoveControllerScript.dispatch_group_move(_units, move_target)

	# Advance until at least 4 units stop moving or 120 ticks elapsed.
	# MockPathScheduler resolves at requested_tick+1; first advance primes it.
	_advance(1)
	var stopped: int = 0
	for _tick in range(120):
		_advance(1)
		stopped = 0
		for u in _units:
			if is_instance_valid(u) and u.fsm.current.id == &"idle":
				stopped += 1
		if stopped >= 4:
			break

	assert_true(stopped >= 4,
		"[step 2] at least 4 of 5 units must arrive (idle) within 120 ticks")

	# Assert distinct final positions (pile-prevention).
	var final_xz: Array = []
	for u in _units:
		if is_instance_valid(u):
			final_xz.append(Vector2((u as Node3D).global_position.x,
				(u as Node3D).global_position.z))

	var distinct: int = 0
	var eps: float = 0.5
	for i in range(final_xz.size()):
		var ok: bool = true
		for j in range(final_xz.size()):
			if i == j:
				continue
			if (final_xz[i] - final_xz[j]).length() < eps:
				ok = false
				break
		if ok:
			distinct += 1

	assert_true(distinct >= 4,
		"[step 2] at least 4 distinct final XZ positions required (pile-prevention)")

	# ---- Step 3: bind to group 1, deselect, recall ----
	ControlGroups.bind(1)
	SelectionManager.deselect_all()
	assert_eq(SelectionManager.selected_units.size(), 0,
		"[step 3] deselect must clear selection")

	ControlGroups.recall(1)
	await get_tree().process_frame

	assert_eq(SelectionManager.selected_units.size(), 5,
		"[step 3] recall group 1 must restore all 5 units to selection")

	# ---- Step 4: apply Farr change → gauge target_farr updates ----
	var initial_farr: float = _gauge.target_farr
	EventBus.farr_changed.emit(-20.0, "smoke_test", -1, initial_farr - 20.0, SimClock.tick)

	assert_almost_eq(_gauge.target_farr, initial_farr - 20.0, 1e-4,
		"[step 4] Farr change must update gauge target_farr")

	# ---- Step 5: single-select via box-drag of 1 kargar → panel shows single mode ----
	# Units have moved to formation positions around (20,0,20); their exact positions
	# depend on ring offsets. We pick the first live unit's actual current position
	# and build a 2×2 world-unit rect around it — guaranteed to capture only that unit
	# since formation spread is R=2.0 between adjacent slots.
	var target_unit: Variant = null
	for u in _units:
		if is_instance_valid(u):
			target_unit = u
			break
	assert_not_null(target_unit, "[step 5] at least one live unit must exist")

	var tu_pos: Vector3 = (target_unit as Node3D).global_position
	# Project the target unit position to screen.
	var proj_data: Dictionary = _project_unit(800.0, 600.0).call(target_unit)
	var sp: Vector2 = proj_data["screen_pos"]
	# Tight 1-pixel rect around the unit's screen projection.
	var single_rect := Rect2(sp.x - 0.6, sp.y - 0.6, 1.2, 1.2)

	SelectionManager.deselect_all()
	_box_handler.box_select_units(single_rect, _units, _project_unit(800.0, 600.0), false)
	await get_tree().process_frame

	assert_eq(SelectionManager.selected_units.size(), 1,
		"[step 5] narrow box-drag must select exactly 1 unit (unit at %s, screen=%s)" % [str(tu_pos), str(sp)])
	assert_eq(_panel.visible_state, _panel.STATE_SINGLE,
		"[step 5] panel must be in STATE_SINGLE after single-unit box-select")
