extends Node

# Right-click move dispatcher — single-unit fast path returns target verbatim,
# multi-unit selection fans out across a ring (wave 2C wiring).
const _GroupMove := preload("res://scripts/movement/group_move_controller.gd")
##
## ClickHandler — translates raw mouse clicks into SelectionManager + Unit
## command writes.
##
## Phase 1 session 1 wave 2 (ui-developer). Per docs/02b_PHASE_1_KICKOFF.md §2 (2)+(3).
##
## Responsibilities:
##   - Left-click anywhere: raycast from camera through mouse position. If hit
##     is a Unit (or a child of a Unit), SelectionManager.select_only(unit). If
##     hit is empty terrain (or no hit), SelectionManager.deselect_all().
##   - Right-click anywhere: raycast from camera through mouse position. If hit
##     is terrain (NOT a unit), build a Move Command (kind = &"move",
##     payload = {target: Vector3}) and push to each currently-selected unit's
##     command_queue via Unit.replace_command. If no units are selected, no-op.
##
## Sim Contract §1.5 fit:
##   _unhandled_input runs off-tick — exactly the right context per the contract
##   ("UI-side state ... CAN be mutated from _input"). The SelectionManager
##   broadcast emits EventBus.selection_changed (read-shaped, L2-allowlisted).
##   Unit.replace_command pushes to a CommandQueue — that is gameplay-state
##   mutation, but the queue is observable-only-by-the-state-machine-tick;
##   per the State Machine Contract §3.4 the state machine will dispatch the
##   command on its next on-tick `transition_to_next()`. Calling replace_command
##   from off-tick is safe because the queue mutation is buffered: `tick()`
##   reads `_pending_id` after `current._sim_tick`, and `replace_command`
##   itself calls `fsm.transition_to_next()` which sets `_pending_id`. The
##   StateMachine's bounded-chain loop in `tick()` drains it on the next
##   sim-tick. No off-tick write to component-owned `_set_sim`-protected fields
##   happens here — only queue / pending-id mutation, which is RefCounted/Object
##   surface. (See engine-architect's wave 1 design note in §6 v0.9.0.)
##
## Sim Contract §3.4 fit:
##   Raycast queries SpatialIndex/PhysicsServer indirectly via direct_space_state.
##   Both are read-safe between tick boundaries from _input / _process. We do
##   not touch the SpatialIndex directly here (that pattern is reserved for
##   AoE-style per-radius selects in Phase 1 session 2's box-drag). For
##   single-click, a physics raycast against unit collision shapes is the
##   simplest precise hit-test and avoids mismatches between visual and
##   spatial-index positions.
##
## Wiring:
##   This script is attached to a node under Main in main.tscn so its
##   _unhandled_input fires for clicks not consumed by the camera or HUD.
##   The camera's _unhandled_input handles MOUSE_WHEEL_UP/DOWN only, so left
##   and right click events propagate down to us.
##
## Out of scope (Phase 1 session 2 onward):
##   - Box / drag selection (left-click-drag → rectangle marquee → multi-select)
##   - Shift+click add-to-selection
##   - Ctrl+1-9 control groups
##   - Double-click select-all-of-type
##   - Attack-move (A + click) — Phase 2
##   - Hover info / cursor changes per context

# ============================================================================
# Configuration
# ============================================================================

## Maximum raycast distance from camera origin. 1000 world-units covers any
## sensible RTS click on a 256m map even from extreme zoom-out. Larger values
## are cheap; this is just the line length, not a per-distance cost.
const RAYCAST_DISTANCE: float = 1000.0

## Collision mask for the raycast. 0xFFFFFFFF = "all layers" — for MVP we hit
## every static body in the scene (terrain + unit collision shapes). Refining
## per-layer (e.g., one layer for selectables, another for terrain) is a
## post-Phase-2 optimization when the layer system actually matters.
const RAYCAST_COLLISION_MASK: int = 0xFFFFFFFF

## Verbose logging of every click and raycast result. Phase 1 wave 2
## diagnostic — left ON until interactive testing confirms the click flow
## is reliable on the live build, then can be flipped off (or gated by
## DebugOverlayManager) once the path is trusted.
const DEBUG_LOG_CLICKS: bool = true


# ============================================================================
# Lifecycle
# ============================================================================

## Disable the handler entirely. Tests flip this on so they can drive
## select / move flows directly through the SelectionManager + Unit APIs
## without a real Viewport / Camera3D / physics world.
var _test_mode: bool = false


func set_test_mode(on: bool) -> void:
	_test_mode = on


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	# Only react on press (not release). RTS convention is press-to-act so
	# rapid click flurries don't double-fire on the release edge.
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if DEBUG_LOG_CLICKS:
				print("[click] LEFT press at screen=", mb.position)
			_handle_left_click(mb.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if DEBUG_LOG_CLICKS:
				print("[click] RIGHT press at screen=", mb.position)
			_handle_right_click(mb.position)
			get_viewport().set_input_as_handled()


# ============================================================================
# Left click — selection
# ============================================================================

## Raycast the click position against the world. If we hit a Unit, select_only;
## if we hit terrain or nothing, deselect_all.
func _handle_left_click(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_left_click_hit(hit)


## Routing layer — public so tests can drive the select/deselect decision
## without a real Camera3D + physics world. Callers from production go through
## `_handle_left_click(screen_pos)`; tests inject a synthetic hit Dictionary
## (or an empty Dict for "missed").
##
## Hit-dictionary shape mirrors what PhysicsDirectSpaceState3D.intersect_ray
## returns: empty Dict on miss, otherwise has `collider`, `position`, `normal`,
## etc. We only consume `collider` for the unit lookup.
func process_left_click_hit(hit: Dictionary) -> void:
	if hit.is_empty():
		# No collider hit — clicked into the void / off the terrain. Deselect.
		if DEBUG_LOG_CLICKS:
			print("[click] LEFT: no raycast hit → deselect_all")
		SelectionManager.deselect_all()
		return
	var unit: Object = _resolve_unit_from_hit(hit)
	if unit != null:
		if DEBUG_LOG_CLICKS:
			var uid_v: Variant = unit.get(&"unit_id")
			print("[click] LEFT: hit unit id=", uid_v, " collider=", hit.get(&"collider"))
		SelectionManager.select_only(unit)
	else:
		# Hit something that wasn't a unit (terrain, future props, etc.) — deselect.
		if DEBUG_LOG_CLICKS:
			print("[click] LEFT: hit non-unit collider=", hit.get(&"collider"), " → deselect_all")
		SelectionManager.deselect_all()


# ============================================================================
# Right click — issue Move command
# ============================================================================

## Raycast the click position. If we hit terrain (not a unit), build a Move
## Command and replace_command on every selected unit. If no units are selected,
## or we hit a unit (Phase 2 will route this to attack-move), no-op.
func _handle_right_click(screen_pos: Vector2) -> void:
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		# Nothing selected — nothing to command.
		return
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_right_click_hit(hit)


## Routing layer — public so tests can drive the move-command decision without
## a real Camera3D + physics world. Same shape as `process_left_click_hit`.
##
## If no units are selected, no-op (the caller's _handle_right_click also
## short-circuits, but this method is defensive so direct test calls behave
## the same way as the input-driven path).
##
## Dispatch table (Phase 2 session 1 wave 2B):
##   - hit empty / no selection → no-op.
##   - hit is a Unit AND hit_unit.team != selected_team → Attack Command per
##     selected unit. Payload carries target_unit_id; UnitState_Attacking
##     resolves the live ref via scene-tree walk.
##   - hit is a Unit AND hit_unit.team == selected_team → no-op (friendly
##     fire / follow / guard are later phases — documented choice).
##   - hit is terrain (collider isn't unit-shaped) → group-move dispatch via
##     GroupMoveController (existing wave 2C behavior).
func process_right_click_hit(hit: Dictionary) -> void:
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		# Nothing selected — nothing to command.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: no selection → no-op")
		return
	if hit.is_empty():
		# Right-clicked into the void / off the terrain — no actionable target.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: no raycast hit → no-op")
		return
	# Branch on hit-unit team relative to the selection's team. The reference
	# team is read off the first selected unit's `team` field (selection is
	# always single-team in MVP — Iran selecting their own; cross-team multi-
	# select would imply spectator mode which is out of scope for Phase 2).
	var hit_unit: Object = _resolve_unit_from_hit(hit)
	if hit_unit != null:
		var hit_team: int = _read_team(hit_unit)
		var sel_team: int = _read_team(sel[0])
		if hit_team != sel_team:
			# Enemy: dispatch Attack command per selected unit.
			var target_uid_v: Variant = hit_unit.get(&"unit_id")
			if target_uid_v == null or typeof(target_uid_v) != TYPE_INT:
				if DEBUG_LOG_CLICKS:
					print("[click] RIGHT: enemy hit but unit_id missing/typed wrong → no-op")
				return
			var target_uid: int = int(target_uid_v)
			if DEBUG_LOG_CLICKS:
				print("[click] RIGHT: attack command target_unit_id=",
					target_uid, " selected=", sel.size())
			# Per-unit dispatch: UnitState_Attacking handles target resolution
			# + range checks. Group formation engagement priority (split fire,
			# focus fire) is Phase 3+ — for now every selected friendly attacks
			# the same target.
			for u in sel:
				if u != null and is_instance_valid(u):
					u.replace_command(
						Constants.COMMAND_ATTACK,
						{&"target_unit_id": target_uid},
					)
			return
		# Friendly: no-op. Follow / guard / friendly-fire are later phases.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: hit friendly unit (same team=",
				sel_team, ") → no-op")
		return
	var target: Vector3 = hit.get(&"position", Vector3.ZERO)
	if DEBUG_LOG_CLICKS:
		print("[click] RIGHT: move command target=", target, " selected=", sel.size())
	# Single and multi selections both route through the controller — its
	# size-1 identity path keeps single-click bitwise-identical, multi-unit
	# distributes on the GROUP_MOVE_OFFSET_RADIUS ring. The controller invokes
	# Unit.replace_command(&"move", {target}) per live unit (is_instance_valid
	# filtered).
	_GroupMove.dispatch_group_move(sel, target)


## Read the `team` field off a Unit-shaped Node, defaulting to TEAM_NEUTRAL
## when the field is missing. Same defensive pattern as _is_unit_shaped's
## duck-typing — avoids an `is Unit` check that would re-introduce the
## class_name registry race.
func _read_team(unit: Object) -> int:
	if unit == null:
		return Constants.TEAM_NEUTRAL
	if not (&"team" in unit):
		return Constants.TEAM_NEUTRAL
	return int(unit.get(&"team"))


# ============================================================================
# Raycasting
# ============================================================================

## Issue a physics raycast from the active Camera3D through the screen-space
## click position. Returns the hit Dictionary (collider, position, normal, ...)
## or an empty Dictionary if no hit / no camera available.
##
## Per Sim Contract §3.4: PhysicsServer queries from _input are safe between
## tick boundaries. The query is purely read-shaped; we never write to the
## physics world or the spatial index from this path.
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
	var world: World3D = get_world_3d_safe()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, RAYCAST_COLLISION_MASK)
	# Hit collision shapes only; no Area3Ds. Unit's CharacterBody3D + terrain
	# StaticBody3D are both bodies.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


## Resolve the Unit (or Unit subclass) that a raycast hit belongs to.
##
## Strategy: the hit `collider` is the StaticBody3D / CharacterBody3D the ray
## struck. Engine-architect's wave 1 confirmed that Unit extends CharacterBody3D
## directly, so when a ray hits a unit, `collider` IS the Unit instance. For
## defensive coverage (a future scene structure that nests collision under a
## child node), we walk up the parent chain looking for an ancestor that
## responds to the `replace_command` and `command_queue` methods/fields — the
## Unit-shaped duck-typing.
##
## Returns null if no Unit is found in the ancestor chain (e.g., the ray hit
## the terrain's StaticBody3D, which is not a Unit). Untyped Object return
## per the project class_name registry race convention.
func _resolve_unit_from_hit(hit: Dictionary) -> Object:
	var collider_v: Variant = hit.get(&"collider", null)
	if collider_v == null:
		return null
	var node: Node = collider_v
	while node != null:
		if _is_unit_shaped(node):
			return node
		node = node.get_parent()
	return null


## Duck-type check: is `n` a Unit (or behaves like one)?
##
## We do not `is Unit` because the global class_name registry race makes typed
## checks brittle in autoload-and-test contexts (per docs/ARCHITECTURE.md §6
## v0.4.0). Instead we look for the Unit-defining surface: a `command_queue`
## field plus the `replace_command` method. Concrete Unit subclasses (Kargar,
## etc., gameplay-systems wave 2) inherit both, so the check carries forward.
func _is_unit_shaped(n: Node) -> bool:
	if n == null:
		return false
	if not n.has_method(&"replace_command"):
		return false
	if not (&"command_queue" in n):
		return false
	return true


## get_world_3d() exists on Node3D but our handler is a plain Node. Resolve
## via the viewport, which always has a World3D in a 3D scene.
func get_world_3d_safe() -> World3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	# In Godot 4, `Viewport.get_world_3d()` returns the scene's World3D.
	return viewport.find_world_3d()
