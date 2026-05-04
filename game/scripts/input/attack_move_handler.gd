extends Node
##
## AttackMoveHandler — A-key + click sequence dispatcher.
##
## Per Phase 2 session 1 wave 2B kickoff §2 deliverable 4(a). Sibling node of
## ClickHandler / BoxSelectHandler under main.tscn.
##
## Sequence:
##   1. Player presses `A` while units are selected → enter pending state
##      (`_attack_move_pending = true`). The visual cue (cursor change) lands
##      in Phase 5 polish; for MVP the state is purely model-side.
##   2. Player left-clicks somewhere → consume the click as the attack-move
##      target. Build an AttackMove command and dispatch to every selected
##      unit via Unit.replace_command(&"attack_move", {target: Vector3}).
##   3. Right-click or Escape cancels the pending state without dispatching.
##
## Why a separate node (not click_handler.gd):
##   The click handler's _unhandled_input fans on press for left/right buttons
##   immediately (left-click → select, right-click → move/attack). Adding the
##   A-modifier wait into that path would gate every left-click on a
##   `_attack_move_pending` check, leaking attack-move concerns into the
##   selection flow. A dedicated handler claims the click only when it's
##   active, and otherwise hands input through unchanged.
##
## Input ordering & set_input_as_handled:
##   When `_attack_move_pending == true`, this handler's _unhandled_input runs
##   BEFORE the click_handler's (Godot's _unhandled_input dispatch order is
##   tree-document order; we add this node BEFORE ClickHandler in main.tscn
##   so it fires first). On the consumed click we call
##   `get_viewport().set_input_as_handled()` so click_handler doesn't ALSO
##   process the same press as a selection.
##
## Sim Contract §1.5 fit:
##   Same as ClickHandler. _unhandled_input runs off-tick; replace_command
##   pushes onto the per-unit CommandQueue (Object surface; the StateMachine
##   tick-side dispatcher reads it during its next on-tick transition_to_next).
##
## Out of scope (later phases):
##   - Cursor change while pending (Phase 5 polish).
##   - A on enemy unit while pending (currently the player must click ground;
##     A+click on an enemy would semantically be a forced-attack and reaches
##     the same UnitState_Attacking via the regular right-click path anyway).
##   - Hold A → patrol (Phase 3+).

# ============================================================================
# Configuration
# ============================================================================

## Mirror ClickHandler's raycast distance so the projection matches.
const RAYCAST_DISTANCE: float = 1000.0
const RAYCAST_COLLISION_MASK: int = 0xFFFFFFFF

## Verbose logging — same convention as ClickHandler.DEBUG_LOG_CLICKS.
const DEBUG_LOG_CLICKS: bool = true


# ============================================================================
# State
# ============================================================================

# True when the player has pressed A and we're waiting for the click.
var _attack_move_pending: bool = false


# Test seam — same pattern as click_handler.gd.
var _test_mode: bool = false


func set_test_mode(on: bool) -> void:
	_test_mode = on


# Test-only inspection: is the handler currently waiting for a click?
func is_pending() -> bool:
	return _attack_move_pending


# Test-only setter for forcing the pending state without dispatching a real
# InputEventKey. Production callers go through _unhandled_input.
func set_pending(on: bool) -> void:
	_attack_move_pending = on


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if event is InputEventKey:
		var ek: InputEventKey = event
		if not ek.pressed:
			return
		match ek.keycode:
			KEY_A:
				if SelectionManager.selection_size() == 0:
					if DEBUG_LOG_CLICKS:
						print("[attack-move] A pressed but no selection → no-op")
					return
				_attack_move_pending = true
				if DEBUG_LOG_CLICKS:
					print("[attack-move] A pressed → pending click")
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _attack_move_pending:
					_attack_move_pending = false
					if DEBUG_LOG_CLICKS:
						print("[attack-move] Esc → cancel pending")
					get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if not _attack_move_pending:
		return
	# Pending — consume the click.
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_consume_left_click(mb.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			# Right-click while pending cancels — do NOT fall through to the
			# normal right-click move path (consume the event so click_handler
			# doesn't also see it).
			_attack_move_pending = false
			if DEBUG_LOG_CLICKS:
				print("[attack-move] right-click → cancel pending")
			get_viewport().set_input_as_handled()


# ============================================================================
# Click consumption
# ============================================================================

func _consume_left_click(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_attack_move_hit(hit)


## Routing layer — public so tests can drive the dispatch decision without a
## real Camera3D + physics world. Same shape as ClickHandler.process_*_hit.
##
## Behavior:
##   - Empty hit → cancel pending without dispatching (clicked into the void).
##   - Hit terrain or ground position → build AttackMove command per selected
##     unit and clear pending.
##   - (No special unit-hit branch for now — A+click on an enemy walks toward
##     the enemy's ground position. The unit-state's per-tick engage check
##     will catch the enemy on the way and transition to Attacking.)
func process_attack_move_hit(hit: Dictionary) -> void:
	# Always clear pending — A+click is a single-shot dispatch, regardless of
	# whether the target was actionable.
	_attack_move_pending = false
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[attack-move] click consumed but selection is empty → no-op")
		return
	if hit.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[attack-move] click consumed but no raycast hit → no-op")
		return
	var target: Vector3 = hit.get(&"position", Vector3.ZERO)
	if DEBUG_LOG_CLICKS:
		print("[attack-move] dispatch target=", target, " selected=", sel.size())
	# Per-unit dispatch — every selected friendly walks toward target,
	# engaging anyone they encounter en route. Formation-aware splitting of
	# fire is Phase 3+ (currently every unit treats target identically).
	for u in sel:
		if u != null and is_instance_valid(u):
			u.replace_command(
				Constants.COMMAND_ATTACK_MOVE,
				{&"target": target},
			)


# ============================================================================
# Raycasting (mirrors click_handler.gd's pattern)
# ============================================================================

func _raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return {}
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return {}
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * RAYCAST_DISTANCE
	var world: World3D = _get_world_3d()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, RAYCAST_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _get_world_3d() -> World3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.find_world_3d()
