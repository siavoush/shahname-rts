extends Node
##
## BuildPlacementHandler — input handler for the building-placement flow.
##
## Phase 3 session 1 wave 1C deliverable 6. Per
## 02f_PHASE_3_KICKOFF.md §3 wave 1C.
##
## Flow:
##   1. Player clicks a build-menu button → BuildMenu emits
##      EventBus.build_placement_started(kind, cost_x100) → this handler
##      enters placement mode (_placement_kind != &""; ghost preview
##      spawned and follows the cursor).
##   2. Cursor moves → ghost preview tracks mouse position (raycast to
##      terrain). Color is green when valid (on terrain, away from
##      existing buildings), red when invalid.
##   3. Player left-clicks valid terrain → dispatch COMMAND_CONSTRUCT
##      to every Kargar in the selection. Exit placement mode.
##   4. Player right-clicks OR presses Escape → cancel placement.
##      Ghost despawns. No command dispatched.
##
## Why a separate node (not folded into ClickHandler):
##   Gather routing went into ClickHandler (wave 1B) but the placement
##   flow has stateful cursor-tracking that doesn't fit the
##   "press → consume" shape of single-click selection. A dedicated
##   handler keeps click_handler.gd lean and the placement-mode
##   state local. Same precedent as AttackMoveHandler being a sibling
##   of ClickHandler.
##
## Input ordering (Pitfall #5):
##   When _placement_kind != &"", this handler's _unhandled_input
##   consumes the click BEFORE ClickHandler interprets it. Godot's
##   _unhandled_input dispatch is tree-document order — lower-index
##   sibling runs first. So this handler is placed BEFORE ClickHandler
##   in main.tscn so it fires first. When in placement mode it consumes
##   the click and calls `get_viewport().set_input_as_handled()`;
##   ClickHandler never sees the event. Same convention as
##   AttackMoveHandler (also placed before ClickHandler in main.tscn).
##   Regression-locked by test_main_tscn_build_placement_handler_before_click_handler
##   and test_pitfall_5_build_placement_handler_before_click_handler_standalone
##   in tests/integration/test_phase_3_khaneh_placement.gd.
##
##   When _placement_kind == &"" (no active placement), the handler
##   short-circuits and lets ClickHandler do its normal job.
##
## Sim Contract §1.5 fit:
##   Same as ClickHandler / AttackMoveHandler. _unhandled_input runs
##   off-tick; the COMMAND_CONSTRUCT dispatch goes via
##   Unit.replace_command (Object surface, queued for the next on-tick
##   transition_to_next). The cost-affordability pre-screen reads from
##   ResourceSystem (off-tick read; Sim Contract §1.5 sanctions UI
##   reads of sim state).
##
## Ghost preview:
##   A separate Node3D instance loaded from ghost_placement_preview.tscn
##   (the ghost is a translucent Khaneh-mesh; deliberately NO collision
##   shape — the ghost must not block raycasts or unit physics). The
##   ghost's color is driven by `_placement_is_valid` — green when
##   placement is valid, red when invalid. Validity is currently:
##     - hit a valid terrain raycast (not off the map);
##     - placement does NOT overlap an existing building (group lookup,
##       cheap with ~1-3 buildings in session 1).
##   Future validity checks (Phase 4+): on navmesh, within tech-radius,
##   resource constraints.
##
## Pitfall #4 awareness:
##   The build_placement_started handler enters placement mode and
##   spawns the ghost. We DO NOT mutate ResourceSystem here. The
##   affordability check at confirm-time reads ResourceSystem.coin_x100_for
##   (read-only); the actual deduction lives in UnitState_Constructing's
##   on-arrival step.
##
## Pitfall #1 awareness:
##   The ghost preview is a Node3D in the world, NOT a Control. Not
##   subject to mouse_filter discipline. The build menu (which IS a
##   Control surface) handles its own mouse_filter; this handler only
##   touches 3D world space.
##
## BUG-07 lesson awareness:
##   The ghost preview INTENTIONALLY has no collision body — it must
##   not be raycast-target. The PLACED Khaneh (created by
##   UnitState_Constructing) does have a StaticBody3D via the base
##   Building scene (deliverable 1's BUG-07 lesson). So the placement
##   chain is consistent: ghost = no collision, placed = collision.

const RAYCAST_DISTANCE: float = 1000.0
const RAYCAST_COLLISION_MASK: int = 0xFFFFFFFF
const DEBUG_LOG_CLICKS: bool = true

# Ghost preview scene — translucent Khaneh visual that follows the cursor.
const _GhostPreviewScene: PackedScene = preload(
	"res://scenes/world/buildings/ghost_placement_preview.tscn")


# ============================================================================
# State
# ============================================================================

# When non-empty StringName, the handler is in placement mode for that
# building kind (currently only &"khaneh" — extend with session 2's
# building roster).
var _placement_kind: StringName = &""

# Cost (in coin_x100) of the building being placed. Cached from the
# build_placement_started signal so the confirm step can affordability-
# check without re-reading BalanceData.
var _placement_cost_x100: int = 0

# The ghost preview Node3D instance. Spawned on entering placement
# mode, freed on exit / confirm.
var _ghost: Node3D = null

# Whether the current ghost position is a valid placement target.
# Drives the ghost color (green=true, red=false). Read by tests and
# by the confirm step (invalid clicks are rejected, ghost stays).
var _placement_is_valid: bool = false

# Last-known cursor world position. Updated in _process; read by the
# confirm step (so the dispatched COMMAND_CONSTRUCT uses the position
# the player visually clicked on).
var _last_cursor_world_pos: Vector3 = Vector3.ZERO


# Test seam — same pattern as ClickHandler / AttackMoveHandler.
var _test_mode: bool = false


func set_test_mode(on: bool) -> void:
	_test_mode = on


# Test-only inspectors.
func is_placement_active() -> bool:
	return _placement_kind != &""


func placement_kind() -> StringName:
	return _placement_kind


func ghost_is_valid() -> bool:
	return _placement_is_valid


func get_ghost() -> Node3D:
	return _ghost


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	if not EventBus.build_placement_started.is_connected(_on_build_placement_started):
		EventBus.build_placement_started.connect(_on_build_placement_started)
	# BUG-08 guard — auto-cancel placement if the selection no longer
	# contains a Kargar mid-placement. Defends against ANY deselection
	# path (Button-press race in deliverable 5 / BUG-08; control-group
	# recall to a non-Kargar; scripted deselect_all; future paths). Without
	# this guard, an orphaned ghost stays in the world and the next
	# confirm-click silently fails on the empty-selection branch — the
	# exact failure mode the lead live-tested at Phase 3 session 1 close.
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.build_placement_started.is_connected(_on_build_placement_started):
		EventBus.build_placement_started.disconnect(_on_build_placement_started)
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)
	_destroy_ghost()


# ============================================================================
# Signal handlers
# ============================================================================

# BUG-08 — auto-cancel placement when the selection no longer contains
# a Kargar mid-placement. The selection_changed signal carries unit_ids,
# but we route through SelectionManager.selected_units for live Node refs
# (the live ref is needed for the _find_first_worker duck-type check).
# Same defensive pattern as build_menu.gd::_on_selection_changed.
func _on_selection_changed(_selected_unit_ids: Array) -> void:
	if _placement_kind == &"":
		return  # not in placement mode — nothing to guard.
	var sel: Array = SelectionManager.selected_units
	if _find_first_worker(sel) == null:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] BUG-08 guard — selection lost its "
				+ "Kargar mid-placement; auto-cancelling")
		_cancel_placement()


# Enter placement mode. Spawn the ghost preview as a child of the
# scene-tree root so it lives in world space and survives until we
# explicitly destroy it.
func _on_build_placement_started(building_kind: StringName, cost_coin_x100: int) -> void:
	# If we're already in placement mode (player clicked the build button
	# twice rapidly, or the menu is buggy), reset the prior ghost first.
	if _placement_kind != &"":
		_destroy_ghost()
	_placement_kind = building_kind
	_placement_cost_x100 = cost_coin_x100
	_placement_is_valid = false
	_spawn_ghost()
	if DEBUG_LOG_CLICKS:
		print("[build-placement] entered placement mode for kind=",
			building_kind, " cost_x100=", cost_coin_x100)


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if _placement_kind == &"":
		return  # not in placement mode — let other handlers run.
	if not (event is InputEventMouseButton):
		# Mouse motion is handled in _process for ghost tracking, not here.
		# Escape cancels.
		if event is InputEventKey:
			var ek: InputEventKey = event
			if ek.pressed and ek.keycode == KEY_ESCAPE:
				_cancel_placement()
				get_viewport().set_input_as_handled()
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_confirm_click(mb.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			# Right-click cancels placement (RTS convention).
			_cancel_placement()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _test_mode:
		return
	if _placement_kind == &"":
		return
	# Track cursor. Update ghost position + validity each frame.
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_update_ghost_from_screen(screen_pos)


# ============================================================================
# Click + ghost handlers
# ============================================================================

# Handle a left-click during placement mode. If the click is on valid
# terrain AND there's a Kargar in the selection, dispatch the
# COMMAND_CONSTRUCT to that worker and exit placement mode. Otherwise
# reject (ghost stays, mode stays).
func _handle_confirm_click(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_confirm_click_hit(hit)


# Public for tests. Same shape as ClickHandler.process_*_hit — drives the
# logic without needing a live Camera3D / physics world.
func process_confirm_click_hit(hit: Dictionary) -> void:
	if _placement_kind == &"":
		return
	if hit.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click — no raycast hit, "
				+ "rejecting (ghost stays in placement mode)")
		return
	# Validate. Refresh _placement_is_valid against the click point
	# (more authoritative than the last _process update — the click
	# point may differ from cursor by a frame).
	var hit_pos: Vector3 = hit.get(&"position", Vector3.ZERO)
	var valid: bool = _is_placement_valid_at(hit_pos)
	if not valid:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click on INVALID location ",
				hit_pos, " — rejecting")
		return
	# Affordability gate. Read ResourceSystem.coin_x100_for and reject
	# if the player no longer has the coin (they may have spent it
	# between menu-press and confirm-click).
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but selection is empty"
				+ " — rejecting (no worker to dispatch to)")
		_cancel_placement()
		return
	var worker: Object = _find_first_worker(sel)
	if worker == null:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but selection has no "
				+ "worker — rejecting")
		_cancel_placement()
		return
	var team: int = Constants.TEAM_NEUTRAL
	if &"team" in worker:
		team = int(worker.get(&"team"))
	if ResourceSystem.coin_x100_for(team) < _placement_cost_x100:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but insufficient Coin"
				+ " — rejecting (have=%d need=%d)"
				% [ResourceSystem.coin_x100_for(team), _placement_cost_x100])
		_cancel_placement()
		return
	# Dispatch! Build the COMMAND_CONSTRUCT payload + push to the worker.
	worker.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": _placement_kind,
			&"target_position": hit_pos,
		},
	)
	if DEBUG_LOG_CLICKS:
		print("[build-placement] dispatched COMMAND_CONSTRUCT kind=",
			_placement_kind, " pos=", hit_pos, " worker_id=",
			worker.get(&"unit_id"))
	# Exit placement mode — ghost despawns, _placement_kind cleared.
	_destroy_ghost()
	_placement_kind = &""
	_placement_cost_x100 = 0


# Update ghost transform from a screen-space cursor position. Public for
# tests so they can inject a fake screen_pos without a Camera3D.
func _update_ghost_from_screen(screen_pos: Vector2) -> void:
	if _ghost == null:
		return
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	if hit.is_empty():
		# Off-map — leave ghost where it was; mark invalid.
		_placement_is_valid = false
		_set_ghost_color(_placement_is_valid)
		return
	var pos: Vector3 = hit.get(&"position", Vector3.ZERO)
	_last_cursor_world_pos = pos
	_ghost.global_position = pos
	_placement_is_valid = _is_placement_valid_at(pos)
	_set_ghost_color(_placement_is_valid)


# Validity check — currently:
#   1. Hit position is on the terrain plane (Y close to 0).
#   2. Position does not overlap an existing building (group lookup +
#      simple distance threshold).
# Future (Phase 4+): on-navmesh check, tech-radius constraint, resource
# requirements.
func _is_placement_valid_at(pos: Vector3) -> bool:
	# Off-map / clearly out of range — terrain plane is Y=0, allow some
	# tolerance for raycast slop.
	if pos.y > 1.0 or pos.y < -1.0:
		return false
	# Overlap check against placed buildings. Use the &"buildings"
	# group (every Building joins it on _ready per deliverable 1).
	# Threshold = 2.5 (Khaneh footprint 2x2 with half-diagonal ~1.4,
	# plus margin). Future kinds may need per-kind footprint reads.
	const _OVERLAP_THRESHOLD: float = 2.5
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if not is_instance_valid(b):
			continue
		if not (b is Node3D):
			continue
		var bp: Vector3 = (b as Node3D).global_position
		var dx: float = bp.x - pos.x
		var dz: float = bp.z - pos.z
		if dx * dx + dz * dz < _OVERLAP_THRESHOLD * _OVERLAP_THRESHOLD:
			return false
	return true


# ============================================================================
# Cancel / ghost management
# ============================================================================

func _cancel_placement() -> void:
	if DEBUG_LOG_CLICKS:
		print("[build-placement] placement cancelled (kind was=",
			_placement_kind, ")")
	_destroy_ghost()
	_placement_kind = &""
	_placement_cost_x100 = 0
	_placement_is_valid = false


func _spawn_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_destroy_ghost()
	_ghost = _GhostPreviewScene.instantiate() as Node3D
	# Add to the scene tree root so the ghost lives in world space.
	# Defensive — get_tree().root may be null in some test contexts;
	# in production it's always there.
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		# No tree — abort spawn silently. Test fixtures may construct
		# the handler without a tree.
		_ghost.free()
		_ghost = null
		return
	tree.root.add_child(_ghost)


func _destroy_ghost() -> void:
	if _ghost == null:
		return
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


# Set the ghost mesh's color to green (valid) or red (invalid). The
# ghost preview script (ghost_placement_preview.gd) owns the color
# logic; we just flip an exposed property.
func _set_ghost_color(is_valid: bool) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		return
	if _ghost.has_method(&"set_validity"):
		_ghost.call(&"set_validity", is_valid)


# ============================================================================
# Helpers
# ============================================================================

# Find the first Kargar in the selection. Returns null if none.
# Same duck-type as BuildMenu / ClickHandler.
func _find_first_worker(sel: Array) -> Object:
	for u in sel:
		if u == null or not is_instance_valid(u):
			continue
		var ut: Variant = u.get(&"unit_type")
		if typeof(ut) == TYPE_STRING_NAME and ut == &"kargar":
			return u
	return null


# Raycast from camera through screen-space cursor. Same pattern as
# ClickHandler._raycast_from_screen — duplicate code, but the
# alternative is exposing ClickHandler's helper publicly which would
# couple the two handlers.
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
	var world: World3D = viewport.find_world_3d()
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
