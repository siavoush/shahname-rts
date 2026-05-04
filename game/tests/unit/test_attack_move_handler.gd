# Tests for AttackMoveHandler — A+click dispatching attack-move commands.
#
# Contract: docs/02d_PHASE_2_KICKOFF.md §2 deliverable 4(a).
#
# AttackMoveHandler is a sibling Node of ClickHandler that watches for the
# A-key + left-click sequence. We bypass real input event dispatch by using
# the public process_attack_move_hit(hit) seam plus the test-only set_pending
# and is_pending helpers.
#
# What we cover:
#   - is_pending() default false; flipping via set_pending(true).
#   - process_attack_move_hit with selection + valid hit → AttackMove
#     command per selected unit (kind=&"attack_move", payload.target = hit pos).
#   - process_attack_move_hit clears the pending flag whether or not the
#     dispatch succeeded.
#   - process_attack_move_hit with empty hit → no-op (pending cleared).
#   - process_attack_move_hit with no selection → no-op (pending cleared).
extends GutTest


const AttackMoveHandlerScript: Script = preload(
	"res://scripts/input/attack_move_handler.gd"
)
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd"
)


class FakeUnit extends CharacterBody3D:
	var unit_id: int = -1
	var team: int = Constants.TEAM_IRAN
	var command_queue: Object = null
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


var handler: Node
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	handler = AttackMoveHandlerScript.new()
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


func _make_unit(uid: int) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	add_child_autofree(u)
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


func _terrain_hit(pos: Vector3) -> Dictionary:
	var sb: StaticBody3D = StaticBody3D.new()
	add_child_autofree(sb)
	return {&"collider": sb, &"position": pos, &"normal": Vector3.UP}


# ---------------------------------------------------------------------------
# Pending state plumbing
# ---------------------------------------------------------------------------

func test_default_pending_is_false() -> void:
	assert_false(handler.is_pending(),
		"AttackMoveHandler defaults to not-pending")


func test_set_pending_flips_flag() -> void:
	handler.set_pending(true)
	assert_true(handler.is_pending(),
		"set_pending(true) flips the flag")
	handler.set_pending(false)
	assert_false(handler.is_pending())


# ---------------------------------------------------------------------------
# Dispatch on click consumption
# ---------------------------------------------------------------------------

func test_process_hit_dispatches_attack_move_to_selected_unit() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	handler.set_pending(true)
	var target: Vector3 = Vector3(15.0, 0.0, 25.0)
	handler.process_attack_move_hit(_terrain_hit(target))
	assert_eq(u._replace_call_count, 1,
		"selected unit must receive exactly one attack_move command")
	assert_eq(u._last_replace_kind, Constants.COMMAND_ATTACK_MOVE,
		"command kind is Constants.COMMAND_ATTACK_MOVE (&\"attack_move\")")
	assert_true(u._last_replace_payload.has(&"target"),
		"payload must carry the `target` key (Vector3)")
	var t: Vector3 = u._last_replace_payload[&"target"]
	assert_almost_eq(t.x, target.x, 1e-4)
	assert_almost_eq(t.y, target.y, 1e-4)
	assert_almost_eq(t.z, target.z, 1e-4)


func test_process_hit_dispatches_to_every_selected_unit() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	var c: FakeUnit = _make_unit(3)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	SelectionManager.add_to_selection(c)
	handler.set_pending(true)
	handler.process_attack_move_hit(_terrain_hit(Vector3(0.0, 0.0, 5.0)))
	for u in [a, b, c]:
		assert_eq(u._replace_call_count, 1,
			"every selected unit gets the attack_move command")
		assert_eq(u._last_replace_kind, Constants.COMMAND_ATTACK_MOVE)


func test_process_hit_clears_pending_on_success() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	handler.set_pending(true)
	handler.process_attack_move_hit(_terrain_hit(Vector3.ZERO))
	assert_false(handler.is_pending(),
		"pending must clear after dispatch — A+click is a single-shot")


# ---------------------------------------------------------------------------
# No-op cases (pending cleared either way)
# ---------------------------------------------------------------------------

func test_process_hit_with_empty_hit_is_noop() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	handler.set_pending(true)
	handler.process_attack_move_hit({})
	assert_eq(u._replace_call_count, 0,
		"empty hit must not dispatch any command")
	assert_false(handler.is_pending(),
		"pending must clear even on empty hit (cancels the A-mode)")


func test_process_hit_with_no_selection_is_noop() -> void:
	# Selection is empty.
	handler.set_pending(true)
	handler.process_attack_move_hit(_terrain_hit(Vector3.ZERO))
	assert_false(handler.is_pending(),
		"pending must clear even with no selection")
