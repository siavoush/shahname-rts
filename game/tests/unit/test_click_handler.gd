# Tests for ClickHandler — left/right click → SelectionManager + move command.
#
# Contract: docs/02b_PHASE_1_KICKOFF.md §2 (2)+(3) and the wave-2 brief.
# Phase 2 session 1 wave 2B extends right-click to dispatch Attack commands
# when the hit collider is an enemy Unit (deliverable 2 input wiring).
#
# What we cover:
#   - Left click on a unit → SelectionManager.select_only(unit)
#   - Left click on terrain (collider that isn't a unit) → deselect_all
#   - Left click on empty space (no hit) → deselect_all
#   - Right click on terrain with a unit selected → Move Command pushed
#   - Right click with no units selected → no-op
#   - Right click on an enemy unit (Phase 2 wave 2B) → Attack Command pushed
#     to every selected unit with payload = { target_unit_id: int }
#   - Right click on a friendly unit → no-op (friendly fire / follow / guard
#     semantics are later phases; documented choice)
#   - Right click on empty space → no-op
#   - Move Command shape: kind = &"move", payload = { target: Vector3 }
#   - Attack Command shape: kind = &"attack",
#                            payload = { target_unit_id: int }
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
# unit_id, get_selectable, team). Inherits CharacterBody3D so a future stricter
# `is Unit` check still works (CharacterBody3D is the production base).
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
func _make_unit(uid: int, team: int = Constants.TEAM_IRAN) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.team = team
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


func test_right_click_on_enemy_unit_pushes_attack_command() -> void:
	# Phase 2 session 1 wave 2B (deliverable 2 input wiring): right-clicking an
	# ENEMY unit (different team) issues an Attack command to every selected
	# unit. Payload carries the target's unit_id so UnitState_Attacking can
	# resolve it via the scene-tree walk.
	var selected: FakeUnit = _make_unit(1, Constants.TEAM_IRAN)
	var enemy: FakeUnit = _make_unit(2, Constants.TEAM_TURAN)
	SelectionManager.select(selected)
	handler.process_right_click_hit(_hit(enemy, Vector3(3.0, 0.0, 0.0)))
	assert_eq(selected._replace_call_count, 1,
		"right-click on an enemy unit must push exactly one Attack Command "
		+ "to each selected unit")
	assert_eq(selected._last_replace_kind, Constants.COMMAND_ATTACK,
		"Attack Command must use Constants.COMMAND_ATTACK (&\"attack\") — "
		+ "matches StateMachine._COMMAND_KIND_TO_STATE_ID dispatch table")


func test_right_click_attack_command_payload_has_target_unit_id() -> void:
	# Payload shape contract with UnitState_Attacking — see
	# unit_state_attacking.gd::enter() reading payload[&"target_unit_id"].
	var selected: FakeUnit = _make_unit(1, Constants.TEAM_IRAN)
	var enemy: FakeUnit = _make_unit(42, Constants.TEAM_TURAN)
	SelectionManager.select(selected)
	handler.process_right_click_hit(_hit(enemy, Vector3.ZERO))
	assert_true(selected._last_replace_payload.has(&"target_unit_id"),
		"Attack Command payload must contain a `target_unit_id` key")
	assert_eq(int(selected._last_replace_payload[&"target_unit_id"]), 42,
		"Attack Command payload.target_unit_id matches the clicked unit's id")


func test_right_click_attack_dispatches_to_every_selected_unit() -> void:
	# Multi-selection: every selected friendly gets the Attack Command with
	# the same target_unit_id. (Group-move's ring distribution does NOT apply
	# to attack — formation engagement priority is Phase 3+.)
	var a: FakeUnit = _make_unit(1, Constants.TEAM_IRAN)
	var b: FakeUnit = _make_unit(2, Constants.TEAM_IRAN)
	var c: FakeUnit = _make_unit(3, Constants.TEAM_IRAN)
	var enemy: FakeUnit = _make_unit(99, Constants.TEAM_TURAN)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	SelectionManager.add_to_selection(c)
	handler.process_right_click_hit(_hit(enemy, Vector3.ZERO))
	for u in [a, b, c]:
		assert_eq(u._replace_call_count, 1,
			"every selected unit must get exactly one Attack Command")
		assert_eq(u._last_replace_kind, Constants.COMMAND_ATTACK)
		assert_eq(int(u._last_replace_payload[&"target_unit_id"]), 99)


func test_right_click_on_friendly_unit_is_noop() -> void:
	# Friendly fire / follow / guard semantics are later phases. For Phase 2
	# session 1, right-clicking a same-team unit is a no-op — the selected
	# units do nothing rather than walking to the friendly's position.
	var selected: FakeUnit = _make_unit(1, Constants.TEAM_IRAN)
	var friendly: FakeUnit = _make_unit(2, Constants.TEAM_IRAN)
	SelectionManager.select(selected)
	handler.process_right_click_hit(_hit(friendly, Vector3(5.0, 0.0, 5.0)))
	assert_eq(selected._replace_call_count, 0,
		"right-click on a same-team friendly unit must NOT push a command "
		+ "(friendly-fire / guard / follow are later phases)")


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
	#
	# Wave 2C update: the dispatch routes through GroupMoveController, which
	# still issues exactly one replace_command per live unit — observable end
	# state matches the pre-wire-up behavior.
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
# Right click — multi-selection routes through GroupMoveController (wave 2C)
# ===========================================================================

func test_right_click_multi_selection_distributes_targets() -> void:
	# Wave 2C wire-up: when 2+ units are selected, the right-click handler
	# routes through GroupMoveController.dispatch_group_move so units get
	# distinct ring-offset targets instead of piling on the exact click point.
	# The controller's algorithm puts unit 0 at center (target verbatim) and
	# units 1..N on a ring of radius Constants.GROUP_MOVE_OFFSET_RADIUS.
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	var c: FakeUnit = _make_unit(3)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	SelectionManager.add_to_selection(c)
	var click_target: Vector3 = Vector3(10.0, 0.0, 20.0)
	handler.process_right_click_hit(_terrain_hit(click_target))
	# Each unit got exactly one move command.
	assert_eq(a._replace_call_count, 1)
	assert_eq(b._replace_call_count, 1)
	assert_eq(c._replace_call_count, 1)
	# Targets are not all identical — at least 2 of 3 must differ from each
	# other (formation distribution). Center slot may equal click_target;
	# ring slots must offset.
	var ta: Vector3 = a._last_replace_payload[&"target"]
	var tb: Vector3 = b._last_replace_payload[&"target"]
	var tc: Vector3 = c._last_replace_payload[&"target"]
	var distinct_count: int = 0
	if not ta.is_equal_approx(tb):
		distinct_count += 1
	if not tb.is_equal_approx(tc):
		distinct_count += 1
	if not ta.is_equal_approx(tc):
		distinct_count += 1
	assert_gte(distinct_count, 2,
		"3-unit selection must produce at least 2 pairs of distinct targets "
		+ "(ring distribution prevents pile-up)")


func test_right_click_multi_selection_targets_within_radius() -> void:
	# Each dispatched target must lie within the ring radius of the click
	# point on the XZ plane — the controller's geometry contract. Y is
	# preserved verbatim from the click.
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	var c: FakeUnit = _make_unit(3)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	SelectionManager.add_to_selection(c)
	var click_target: Vector3 = Vector3(0.0, 1.5, 0.0)
	handler.process_right_click_hit(_terrain_hit(click_target))
	var max_offset: float = Constants.GROUP_MOVE_OFFSET_RADIUS + 1e-3
	for u in [a, b, c]:
		var t: Vector3 = u._last_replace_payload[&"target"]
		var dx: float = t.x - click_target.x
		var dz: float = t.z - click_target.z
		var dist: float = sqrt(dx * dx + dz * dz)
		assert_lte(dist, max_offset,
			"each unit's target must lie within R of the click on the XZ plane")
		assert_almost_eq(t.y, click_target.y, 1e-4,
			"Y is preserved verbatim through the controller")


func test_right_click_single_selection_target_unchanged() -> void:
	# Single-selection must remain bitwise-identical to pre-wire-up behavior:
	# the target is the click point verbatim, no ring offset. This is the
	# regression guard for session-1's single-click move test suite.
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	var click_target: Vector3 = Vector3(7.5, 0.0, -3.25)
	handler.process_right_click_hit(_terrain_hit(click_target))
	var t: Vector3 = u._last_replace_payload[&"target"]
	assert_almost_eq(t.x, click_target.x, 1e-6,
		"single-unit dispatch is identity — no offset math, no float drift")
	assert_almost_eq(t.y, click_target.y, 1e-6)
	assert_almost_eq(t.z, click_target.z, 1e-6)


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
