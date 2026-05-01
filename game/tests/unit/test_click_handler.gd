# Tests for ClickHandler — left/right click → SelectionManager + move command.
#
# Contract: docs/02b_PHASE_1_KICKOFF.md §2 (2)+(3) and the wave-2 brief.
#
# What we cover:
#   - Left click on a unit → SelectionManager.select_only(unit)
#   - Left click on terrain (collider that isn't a unit) → deselect_all
#   - Left click on empty space (no hit) → deselect_all
#   - Right click on terrain with a unit selected → Move Command pushed
#   - Right click with no units selected → no-op
#   - Right click on a unit (attack-move target, Phase 2) → no-op for wave 2
#   - Right click on empty space → no-op
#   - Move Command shape: kind = &"move", payload = { target: Vector3 }
#
# We bypass real raycasting by exercising `process_left_click_hit(hit)` and
# `process_right_click_hit(hit)` directly with synthetic hit Dictionaries.
# This is the public seam the production input path also uses (after the
# raycast resolves to a Dict). Real-raycast wiring is exercised by the
# scene-level smoke test (Phase 1 session 1 wave 3 qa-engineer integration
# test) — unit-level tests stay focused on routing logic.
extends GutTest


const ClickHandlerScript: Script = preload("res://scripts/input/click_handler.gd")
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Fake unit with the duck-typed surface ClickHandler expects. Mirrors the
# shape SelectionManager + ClickHandler probe (replace_command, command_queue,
# unit_id, get_selectable). Inherits CharacterBody3D so a future stricter
# `is Unit` check still works (CharacterBody3D is the production base).
class FakeUnit extends CharacterBody3D:
	var unit_id: int = -1
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
	handler = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)  # disables _unhandled_input wiring
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	SimClock.reset()


# Build a fake unit with a real SelectableComponent attached.
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


# Build a synthetic hit Dictionary as if the raycast hit `collider` at `pos`.
func _hit(collider: Node, pos: Vector3) -> Dictionary:
	return {
		&"collider": collider,
		&"position": pos,
		&"normal": Vector3.UP,
	}


# Build a "terrain hit" — a collider that isn't unit-shaped (StaticBody3D).
func _terrain_hit(pos: Vector3) -> Dictionary:
	var sb: StaticBody3D = StaticBody3D.new()
	add_child_autofree(sb)
	return _hit(sb, pos)


# ===========================================================================
# Left click — hit a unit
# ===========================================================================

func test_left_click_on_unit_selects_only_that_unit() -> void:
	var u: FakeUnit = _make_unit(7)
	handler.process_left_click_hit(_hit(u, Vector3(1, 0, 1)))
	assert_true(SelectionManager.is_selected(u),
		"left-click on a unit must select that unit")
	assert_eq(SelectionManager.selection_size(), 1)


func test_left_click_on_unit_replaces_existing_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	handler.process_left_click_hit(_hit(b, Vector3.ZERO))
	assert_false(SelectionManager.is_selected(a),
		"a previously-selected unit must be deselected by a fresh left-click")
	assert_true(SelectionManager.is_selected(b))


# ===========================================================================
# Left click — hit terrain
# ===========================================================================

func test_left_click_on_terrain_deselects_all() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	handler.process_left_click_hit(_terrain_hit(Vector3(5, 0, 5)))
	assert_eq(SelectionManager.selection_size(), 0,
		"left-click on terrain (non-unit collider) must deselect everything")


func test_left_click_on_empty_space_deselects_all() -> void:
	# Empty hit dict — raycast missed everything.
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	handler.process_left_click_hit({})
	assert_eq(SelectionManager.selection_size(), 0,
		"left-click on empty space (no hit) must deselect everything")


# ===========================================================================
# Right click — issue Move command
# ===========================================================================

func test_right_click_on_terrain_pushes_move_command_to_selected_unit() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	var target: Vector3 = Vector3(10.0, 0.0, 20.0)
	handler.process_right_click_hit(_terrain_hit(target))
	assert_eq(u._replace_call_count, 1,
		"right-click on terrain with a selected unit must call replace_command once")


func test_right_click_move_command_has_correct_kind() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	handler.process_right_click_hit(_terrain_hit(Vector3.ZERO))
	assert_eq(u._last_replace_kind, Constants.COMMAND_MOVE,
		"Move Command must use Constants.COMMAND_MOVE (&\"move\") — coordination "
		+ "contract with ai-engineer's UnitState_Moving")


func test_right_click_move_command_has_correct_target_payload() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	var target: Vector3 = Vector3(7.5, 0.0, -3.25)
	handler.process_right_click_hit(_terrain_hit(target))
	assert_true(u._last_replace_payload.has(&"target"),
		"Move Command payload must contain a `target` key")
	var payload_target: Vector3 = u._last_replace_payload[&"target"]
	assert_almost_eq(payload_target.x, target.x, 1e-4)
	assert_almost_eq(payload_target.y, target.y, 1e-4)
	assert_almost_eq(payload_target.z, target.z, 1e-4)


func test_right_click_with_no_selection_is_noop() -> void:
	# Pre-condition: no units selected.
	assert_eq(SelectionManager.selection_size(), 0)
	# Right-click should NOT crash and NOT call replace_command on anyone.
	# Sanity: build a unit not selected and confirm replace_command never fires.
	var u: FakeUnit = _make_unit(1)
	handler.process_right_click_hit(_terrain_hit(Vector3.ZERO))
	assert_eq(u._replace_call_count, 0,
		"right-click with no selection must not push a command to any unit")


func test_right_click_on_unit_is_noop_in_wave2() -> void:
	# Phase 2 will route this to attack-move; for now, right-clicking a unit
	# is a no-op (the move command must NOT be pushed with the clicked unit's
	# position as the target).
	var selected: FakeUnit = _make_unit(1)
	var target_unit: FakeUnit = _make_unit(2)
	SelectionManager.select(selected)
	handler.process_right_click_hit(_hit(target_unit, Vector3.ZERO))
	assert_eq(selected._replace_call_count, 0,
		"right-click on a unit must NOT push a Move Command in Phase 1 wave 2")


func test_right_click_on_empty_space_is_noop() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	handler.process_right_click_hit({})
	assert_eq(u._replace_call_count, 0,
		"right-click on empty space (no raycast hit) must not push a command")


# ===========================================================================
# Right click — multiple selected units (forward-compat for session 2)
# ===========================================================================

func test_right_click_pushes_command_to_every_selected_unit() -> void:
	# Wave 2 single-click selects single unit; but the API supports
	# multi-selection (add_to_selection). When session 2 wires Shift+click, the
	# right-click move flow fans out to every selected unit. Test it now so the
	# wave-2 plumbing is forward-compatible.
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	handler.process_right_click_hit(_terrain_hit(Vector3(5, 0, 5)))
	assert_eq(a._replace_call_count, 1,
		"every selected unit gets the Move Command")
	assert_eq(b._replace_call_count, 1,
		"every selected unit gets the Move Command")


# ===========================================================================
# Resolve-unit walk-up (defensive: nested colliders)
# ===========================================================================

func test_resolve_unit_walks_up_collider_ancestor_chain() -> void:
	# If a future scene structure puts the CollisionShape3D under a child
	# (instead of directly on the Unit's CharacterBody3D root), the resolver
	# must still find the unit by walking up.
	var u: FakeUnit = _make_unit(1)
	# Synthetic nested collider: a Node3D child of the Unit. The hit's
	# `collider` field points to this child, but the Unit is the parent.
	var child: Node3D = Node3D.new()
	u.add_child(child)
	handler.process_left_click_hit(_hit(child, Vector3.ZERO))
	assert_true(SelectionManager.is_selected(u),
		"resolver must find the Unit by walking up from a nested collider")


# ===========================================================================
# is_unit_shaped duck-type (terrain hit must NOT register as a unit)
# ===========================================================================

func test_terrain_collider_does_not_resolve_as_unit() -> void:
	# A plain StaticBody3D has neither `replace_command` nor `command_queue`,
	# so it must not be treated as a unit. Already covered indirectly via
	# `test_left_click_on_terrain_deselects_all`, but worth its own anchor.
	var pre_units: Array = SelectionManager.selected_units
	assert_eq(pre_units.size(), 0)
	handler.process_left_click_hit(_terrain_hit(Vector3.ZERO))
	# No selection should have happened (and the deselect_all path is the
	# only one that fires — emit_count is verified in test_selection_manager).
	assert_eq(SelectionManager.selection_size(), 0)
