# Integration tests — box / drag selection flow.
#
# Wave 3 (qa-engineer). Locks in wave-1A (BoxSelectHandler) behaviors via
# integration tests that would have caught live-game regressions.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flow 1.
# Related:  docs/TESTING_CONTRACT.md §3.1, docs/SIMULATION_CONTRACT.md §1.5.
#
# Strategy: use BoxSelectHandler's public test seams (begin_press /
# update_motion / end_press / box_select_units) and an injected projection
# callable so tests don't need a real Camera3D. Units are spawned via the
# real kargar.tscn so SelectionManager integration is genuine.
#
# Typing: Variant slots for unit refs (class_name registry-race pattern,
# ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const BoxSelectHandlerScript: Script = preload("res://scripts/input/box_select_handler.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _handler: Node = null
var _units: Array = []


func before_each() -> void:
	SelectionManager.reset()
	UnitScript.call(&"reset_id_counter")
	_units.clear()
	_handler = BoxSelectHandlerScript.new()
	_handler.set_test_mode(true)
	add_child_autofree(_handler)


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()


# Spawn a kargar at world_pos; register in _units for cleanup.
func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	_units.append(u)
	return u


# Simple projection helper: maps a unit's 3D XZ to screen 2D (1:10 scale).
# All units within [0, viewport_w] x [0, viewport_h] are on-screen.
func _project(viewport_w: float, viewport_h: float) -> Callable:
	return func(u: Object) -> Dictionary:
		var pos: Vector3 = (u as Node3D).global_position
		var sp := Vector2(pos.x * 10.0 + viewport_w * 0.5,
			pos.z * 10.0 + viewport_h * 0.5)
		var on: bool = (sp.x >= 0.0 and sp.y >= 0.0
			and sp.x <= viewport_w and sp.y <= viewport_h)
		return {"screen_pos": sp, "on_screen": on}


# ---------------------------------------------------------------------------
# 1. Drag covering all 5 units → all 5 selected
# ---------------------------------------------------------------------------

func test_drag_covering_all_units_selects_all() -> void:
	# Place 5 units near origin, projected near screen-centre (800×600).
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5 - 1.0, 0.0, 0.0))

	var rect := Rect2(0.0, 0.0, 800.0, 600.0)
	_handler.box_select_units(rect, _units, _project(800.0, 600.0), false)

	assert_eq(SelectionManager.selected_units.size(), 5,
		"drag covering all 5 units must select all 5")


# ---------------------------------------------------------------------------
# 2. Drag covering 0 units (no Shift) → selection cleared
# ---------------------------------------------------------------------------

func test_drag_covering_no_units_clears_selection() -> void:
	for i in range(5):
		_spawn_kargar(Vector3(float(i) * 0.5 - 1.0, 0.0, 0.0))
	# Pre-select some units.
	SelectionManager.add_to_selection(_units[0])
	SelectionManager.add_to_selection(_units[1])
	assert_eq(SelectionManager.selected_units.size(), 2)

	# Rect far off-screen so no units project inside it.
	var rect := Rect2(9000.0, 9000.0, 1.0, 1.0)
	_handler.box_select_units(rect, _units, _project(800.0, 600.0), false)

	assert_eq(SelectionManager.selected_units.size(), 0,
		"drag covering 0 units without Shift must clear selection")


# ---------------------------------------------------------------------------
# 3. Shift-drag covering 3 extra units after pre-selecting 2 → 5 selected
# ---------------------------------------------------------------------------

func test_shift_drag_additive_selection() -> void:
	# Two groups of units at different screen positions.
	# Group A: far left (will NOT be in the drag rect)
	var u_a1: Variant = _spawn_kargar(Vector3(-50.0, 0.0, 0.0))
	var u_a2: Variant = _spawn_kargar(Vector3(-50.0, 0.0, 2.0))
	# Group B: near origin (WILL be inside the drag rect)
	var u_b1: Variant = _spawn_kargar(Vector3(1.0, 0.0, 0.0))
	var u_b2: Variant = _spawn_kargar(Vector3(2.0, 0.0, 0.0))
	var u_b3: Variant = _spawn_kargar(Vector3(3.0, 0.0, 0.0))

	# Pre-select group A.
	SelectionManager.add_to_selection(u_a1)
	SelectionManager.add_to_selection(u_a2)
	assert_eq(SelectionManager.selected_units.size(), 2)

	# Shift-drag over group B only (group A projects far off-screen).
	var all_units: Array = [u_a1, u_a2, u_b1, u_b2, u_b3]
	# Projection: screen 400,300 centre. Group A at x=-50 → screen x=-50*10+400=-100 (off)
	# Group B at x=1..3 → screen x=10..30+400=410..430 (inside rect 350..500)
	var rect := Rect2(350.0, 250.0, 150.0, 100.0)
	_handler.box_select_units(rect, all_units, _project(800.0, 600.0), true)

	assert_eq(SelectionManager.selected_units.size(), 5,
		"Shift-drag additive must combine 2 pre-selected + 3 newly inside rect = 5")


# ---------------------------------------------------------------------------
# 4. begin_press → update_motion past dead zone → end_press returns true (drag)
# ---------------------------------------------------------------------------

func test_press_past_dead_zone_is_drag() -> void:
	_handler.begin_press(Vector2(100.0, 100.0), false)
	_handler.update_motion(Vector2(110.0, 110.0))  # 14px move, past 4px dead zone
	var was_drag: bool = _handler.end_press()
	assert_true(was_drag, "motion past dead zone must result in drag=true")


# ---------------------------------------------------------------------------
# 5. Quick press + release within dead zone → end_press returns false (click)
# ---------------------------------------------------------------------------

func test_press_within_dead_zone_is_click() -> void:
	_handler.begin_press(Vector2(100.0, 100.0), false)
	_handler.update_motion(Vector2(102.0, 101.0))  # 2.2px, under 4px dead zone
	var was_drag: bool = _handler.end_press()
	assert_false(was_drag, "motion under dead zone must result in drag=false (click path)")


# ---------------------------------------------------------------------------
# 6. current_drag_rect is empty before drag activates, non-empty after
# ---------------------------------------------------------------------------

func test_current_drag_rect_state() -> void:
	assert_eq(_handler.current_drag_rect(), Rect2(),
		"drag rect must be empty before any press")

	_handler.begin_press(Vector2(50.0, 50.0), false)
	assert_eq(_handler.current_drag_rect(), Rect2(),
		"drag rect must be empty when press active but not yet past dead zone")

	_handler.update_motion(Vector2(70.0, 80.0))  # 25px — past dead zone
	var r: Rect2 = _handler.current_drag_rect()
	assert_true(r.size.x > 0.0 and r.size.y > 0.0,
		"drag rect must have positive size once drag is active")


# ---------------------------------------------------------------------------
# 7. Motion without prior press is a no-op (no crash, no state change)
# ---------------------------------------------------------------------------

func test_motion_without_press_is_noop() -> void:
	# No begin_press called — update_motion must silently ignore.
	_handler.update_motion(Vector2(200.0, 200.0))
	assert_eq(_handler.current_drag_rect(), Rect2(),
		"motion without press must leave drag rect empty")
	assert_eq(SelectionManager.selected_units.size(), 0,
		"motion without press must not change selection")
