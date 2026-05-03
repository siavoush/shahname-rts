extends Node
##
## BoxSelectHandler — left-mouse drag → marquee rectangle → multi-select.
##
## Phase 1 session 2 wave 1A (ui-developer). Per docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (1).
##
## Responsibilities:
##   - Intercept left-mouse press; remember the press position.
##   - On left-mouse motion past a small dead zone (DRAG_DEAD_ZONE_PX),
##     enter drag mode and show a translucent rectangle overlay.
##   - On left-mouse release:
##       * If drag mode was active: project every Iran unit's world
##         position to screen via Camera3D.unproject_position; collect those
##         whose projection falls inside the rect; route through
##         SelectionManager.select_only(...) (or add_to_selection on Shift).
##       * If drag mode was NOT active (the press was a click, not a drag):
##         hand the event off to ClickHandler.process_left_click_hit() so
##         single-click selection still works. We intercepted the press, so
##         ClickHandler's _unhandled_input never saw it; this is the
##         coordination seam the kickoff doc calls out.
##
## Why a Node, not an autoload:
##   The handler needs a Camera3D to project positions and a Viewport to
##   anchor the overlay. Both are scene-bound. An autoload would have to
##   defensively resolve both every frame; a scene-attached Node has them
##   one parent away. The single-instance discipline is preserved by adding
##   exactly one BoxSelectHandler under Main in main.tscn.
##
## Why intercept the press (not just the release):
##   ClickHandler's _unhandled_input fires on press (line ~107 of
##   click_handler.gd). If we let the press through, ClickHandler would
##   already deselect_all on a left-click-on-empty-space, and the user's
##   in-progress drag would start with an empty selection — Shift+drag
##   would still work, but a no-modifier drag would visually "jump" through
##   the empty state. Better: BoxSelectHandler always claims the left-press
##   first (via tree-order in `_unhandled_input`), then on release decides
##   click-vs-drag and dispatches accordingly.
##
## Sim Contract §1.5 fit:
##   _unhandled_input runs off-tick. The handler reads simulation state
##   (unit positions) freely per Sim Contract §1.5 / §3.4. The selection
##   broadcast (EventBus.selection_changed) is read-shaped and L2-allowlisted.
##   No on-tick mutations happen here.
##
## Live-game-broken-surface (kickoff §2 (1)):
##
##   1. State that must work at runtime that no unit test exercises:
##      - The DragOverlay Control's mouse_filter MUST be MOUSE_FILTER_IGNORE
##        (= 2). Per session 1's regression, a Control on top of the viewport
##        with the default MOUSE_FILTER_STOP swallows mouse events silently.
##      - Camera3D.unproject_position must be called per visible unit, per
##        release event. Unit tests use a Variant projection helper; the
##        handler resolves the live Camera3D from get_viewport().get_camera_3d().
##      - Coordination with click_handler.gd: we intercept on press, set
##        input handled, and forward to its public process_left_click_hit
##        on a non-drag release (the click case). This is the seam the
##        kickoff doc forbids us to refactor — we use the existing API.
##
##   2. What can a headless test not detect that the lead would notice:
##      - Visual: the rectangle's transparency (0.20 fill, 0.80 stroke) and
##        anchoring against the viewport. Tested manually by the lead.
##      - Behavioral: drag-from-HUD-into-world. The HUD's labels were set
##        to MOUSE_FILTER_IGNORE in session 1, so the press hits this
##        handler. If the HUD is later given an interactive Control, the
##        coordination is "HUD's _gui_input claims it; this handler never
##        sees it" — by then we'll know if there's a bug.
##      - Drag in all four corner-directions (TL→BR, BR→TL, TR→BL, BL→TR).
##        Math is tested in test_box_select_math.gd (rect_from_corners
##        normalizes), but the visual rectangle's anchor only manifests on
##        a real viewport.
##      - Quick-click-with-tiny-jitter (1–2px movement). Tested in math
##        (is_past_dead_zone), but the precise dead-zone feel is the lead's
##        call.
##
##   3. Minimum interactive smoke test (lead's checklist):
##      - Drag from top-left to bottom-right across the kargars: all 5
##        selected, gold rings appear.
##      - Drag from bottom-right to top-left: same result.
##      - Shift+drag across a partial subset while 2 are already selected:
##        the new ones are added; existing ones stay.
##      - Quick-click on one kargar: selects that one only (single-click
##        path still works through the coordination seam).
##      - Click on empty space: deselects all (single-click path).

# ============================================================================
# Configuration
# ============================================================================

## Pixels of mouse movement past the press position before we treat the
## gesture as a drag. Below this, on release we delegate to the click path.
##
## 4px is a comfortable dead zone for both mouse and trackpad — small
## enough that an intentional drag feels responsive, large enough that
## sub-pixel jitter on a deliberate click doesn't accidentally box-select
## the unit you just clicked. Tune in editor if it feels wrong.
const DRAG_DEAD_ZONE_PX: float = 4.0

## Verbose logging of every press/motion/release. Phase 1 session 2 wave
## 1A diagnostic — left ON until interactive testing confirms the gesture
## is reliable.
const DEBUG_LOG_DRAG: bool = true


# ============================================================================
# Dependencies
# ============================================================================

const _BoxSelectMath: Script = preload("res://scripts/input/box_select_math.gd")
const _DragOverlayScene: PackedScene = preload(
	"res://scenes/ui/drag_overlay.tscn")


# ============================================================================
# Runtime state
# ============================================================================

## True between left-press and left-release.
var _press_active: bool = false

## True once the press has moved past DRAG_DEAD_ZONE_PX. Tells release
## whether to box-select (drag) or delegate to ClickHandler (click).
var _drag_active: bool = false

## Screen-space press position. Captured on left-press; used as the rect's
## anchor corner during drag.
var _press_pos: Vector2 = Vector2.ZERO

## Most-recent screen-space cursor position during drag. Updated on each
## InputEventMouseMotion while _press_active.
var _current_pos: Vector2 = Vector2.ZERO

## True iff Shift was held at press time (additive selection mode).
var _shift_at_press: bool = false


## Reference to the spawned overlay (a CanvasLayer-rooted Control). null
## when not dragging. Created on first drag activation, freed on _exit_tree.
var _overlay: CanvasLayer = null

## Cached pointer to the ClickHandler sibling — populated lazily on first
## use so the test_mode path (no ClickHandler in scene) works without
## crashing.
var _click_handler: Node = null

## When true, _unhandled_input is a no-op. Tests flip this on so they can
## drive press / motion / release through the public seams without going
## through the input system.
var _test_mode: bool = false


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Spawn the overlay once, hidden. Showing/hiding is cheap; the overlay
	# itself is small (a CanvasLayer with one custom-drawing Control).
	if _DragOverlayScene != null:
		_overlay = _DragOverlayScene.instantiate() as CanvasLayer
		if _overlay != null:
			_overlay.visible = false
			add_child(_overlay)


func set_test_mode(on: bool) -> void:
	_test_mode = on


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _press_active:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_begin_press(mb.position, mb.shift_pressed)
		# Always claim the press — we own click-vs-drag arbitration.
		get_viewport().set_input_as_handled()
	else:
		# Release: capture release position, then arbitrate.
		var release_pos: Vector2 = mb.position
		var was_drag: bool = _drag_active
		var shift: bool = _shift_at_press
		_finish_press()
		if was_drag:
			_finalize_drag(release_pos, shift)
		else:
			_delegate_click_release(release_pos)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	_current_pos = mm.position
	if not _drag_active:
		if _BoxSelectMath.is_past_dead_zone(_press_pos, _current_pos, DRAG_DEAD_ZONE_PX):
			_drag_active = true
			_show_overlay()
			if DEBUG_LOG_DRAG:
				print("[box-select] drag activated at ", _current_pos)
	if _drag_active:
		_update_overlay_rect()


# ============================================================================
# Press lifecycle (testable seams)
# ============================================================================

## Public test seam — start a press at `pos` with optional Shift modifier.
func begin_press(pos: Vector2, shift: bool) -> void:
	_begin_press(pos, shift)


## Public test seam — synthesize motion at `pos`. Triggers drag activation
## if past the dead zone.
func update_motion(pos: Vector2) -> void:
	if not _press_active:
		return
	_current_pos = pos
	if not _drag_active:
		if _BoxSelectMath.is_past_dead_zone(_press_pos, _current_pos, DRAG_DEAD_ZONE_PX):
			_drag_active = true
			_show_overlay()
	if _drag_active:
		_update_overlay_rect()


## Public test seam — end the press. Returns true if the gesture was a
## drag, false if it was a click. Caller decides what to do with the
## release (the production code finalizes the box-select; tests assert
## the return value + drag rect).
func end_press() -> bool:
	var was_drag: bool = _drag_active
	_finish_press()
	return was_drag


## Public test seam — current drag rect, normalized. Empty Rect2 if not
## dragging.
func current_drag_rect() -> Rect2:
	if not _drag_active:
		return Rect2()
	return _BoxSelectMath.rect_from_corners(_press_pos, _current_pos)


## Public test seam — invoke the box-select with an injected projection
## helper. `project_unit(unit) -> Dictionary({screen_pos, on_screen})` is
## the same shape the math helper expects in `units_in_rect`. This avoids
## the GUT runner needing a real Camera3D for the unit-of-the-handler
## tests.
func box_select_units(rect: Rect2, units: Array, project_unit: Callable, shift: bool) -> Array:
	var projected: Array = []
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		var entry: Dictionary = project_unit.call(u) as Dictionary
		entry[&"unit"] = u
		projected.append(entry)
	var hits: Array = _BoxSelectMath.units_in_rect(rect, projected)
	_commit_selection(hits, shift)
	return hits


# ============================================================================
# Internals
# ============================================================================

func _begin_press(pos: Vector2, shift: bool) -> void:
	_press_active = true
	_drag_active = false
	_press_pos = pos
	_current_pos = pos
	_shift_at_press = shift
	if DEBUG_LOG_DRAG:
		print("[box-select] press at ", pos, " shift=", shift)


func _finish_press() -> void:
	_press_active = false
	_hide_overlay()
	_drag_active = false


func _finalize_drag(release_pos: Vector2, shift: bool) -> void:
	_current_pos = release_pos
	var rect: Rect2 = _BoxSelectMath.rect_from_corners(_press_pos, release_pos)
	if DEBUG_LOG_DRAG:
		print("[box-select] release: drag-rect=", rect, " shift=", shift)
	# Collect candidates from the live world, project, filter, apply.
	var camera: Camera3D = _resolve_camera()
	if camera == null:
		if DEBUG_LOG_DRAG:
			print("[box-select] no Camera3D resolvable; skip box-select")
		return
	var viewport_size: Vector2 = Vector2.ZERO
	var vp: Viewport = get_viewport()
	if vp != null:
		viewport_size = vp.get_visible_rect().size
	var candidates: Array = _gather_candidate_units()
	var projected: Array = []
	for u in candidates:
		projected.append(_project_unit(u, camera, viewport_size))
	var hits: Array = _BoxSelectMath.units_in_rect(rect, projected)
	if DEBUG_LOG_DRAG:
		print("[box-select] candidates=", candidates.size(),
			" hits=", hits.size(), " shift=", shift)
	_commit_selection(hits, shift)


func _delegate_click_release(release_pos: Vector2) -> void:
	# Resolve the click handler the first time we need it.
	if _click_handler == null:
		_click_handler = _resolve_click_handler()
	if _click_handler == null:
		# No ClickHandler in the scene (test mode or stripped scene). The
		# release is silently dropped; single-click selection won't work
		# but the box-select path is the test surface here.
		if DEBUG_LOG_DRAG:
			print("[box-select] click release; no ClickHandler resolvable")
		return
	# Run the same raycast ClickHandler runs internally, then route through
	# its public seam. We can't call its private _handle_left_click because
	# that re-runs the raycast; we stay on the public process_left_click_hit
	# path so the coordination is one-direction (we feed it; it doesn't feed
	# back to us).
	var hit: Dictionary = _raycast_left_click(release_pos)
	if _click_handler.has_method(&"process_left_click_hit"):
		_click_handler.call(&"process_left_click_hit", hit)


# Spawn a fresh raycast against the world for the click-release case. This
# duplicates click_handler.gd's _raycast_from_screen body (the kickoff doc
# forbids us from modifying click_handler.gd), but the duplication is small
# and self-contained — both implementations follow Sim Contract §3.4 ("read-
# safe between tick boundaries from _input").
func _raycast_left_click(screen_pos: Vector2) -> Dictionary:
	var vp: Viewport = get_viewport()
	if vp == null:
		return {}
	var camera: Camera3D = vp.get_camera_3d()
	if camera == null:
		return {}
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * 1000.0
	var world: World3D = vp.find_world_3d()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, 0xFFFFFFFF)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


# Walk the scene under our ancestor chain looking for any Node tagged
# "ClickHandler" — sibling lookup that survives the lazy-init pattern even
# if main.tscn renames us. Returns null if not found.
func _resolve_click_handler() -> Node:
	# Try our parent first (sibling lookup).
	var p: Node = get_parent()
	if p == null:
		return null
	for sib in p.get_children():
		if sib == self:
			continue
		if sib.has_method(&"process_left_click_hit"):
			return sib
	return null


# Resolve the active Camera3D. Off-tick read of viewport state per Sim
# Contract §1.5.
func _resolve_camera() -> Camera3D:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()


# Walk the scene under our parent's ancestry looking for any node whose
# `unit_id` field is a non-negative int and whose `team` matches the
# player team (Iran). This is the "every selectable unit in the world"
# sweep — for Phase 1 session 2 the scope is the 5 Kargars. SpatialIndex
# would be a faster source but for ≤200 units the linear walk is fine
# (Sim Contract §3.3 budgets — N=5 today, never more than ~50 in MVP).
#
# The kickoff doc explicitly says "iterate the Units in the scene OR use
# SpatialIndex" — at this scale the linear walk is the simpler choice
# (no autoload dependency, deterministic order, easy to test).
func _gather_candidate_units() -> Array:
	var hits: Array = []
	var root: Node = get_tree().current_scene
	if root == null:
		return hits
	_collect_unit_shaped(root, hits)
	return hits


func _collect_unit_shaped(node: Node, out: Array) -> void:
	# Duck-type: a unit has unit_id and team and a global_position. The
	# same shape ClickHandler uses for unit-resolution, minus the
	# `replace_command` requirement (we don't issue commands here).
	if (&"unit_id" in node) and (&"team" in node) and (node is Node3D):
		var team_v: Variant = node.get(&"team")
		if int(team_v) == Constants.TEAM_IRAN:
			out.append(node)
	for child in node.get_children():
		_collect_unit_shaped(child, out)


# Project a single unit. Returns the dict shape `units_in_rect` expects.
# Wraps the small but error-prone behind-camera + viewport-clip checks.
func _project_unit(unit: Object, camera: Camera3D, viewport_size: Vector2) -> Dictionary:
	if not is_instance_valid(unit):
		return { &"unit": unit, &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var unit3d: Node3D = unit as Node3D
	if unit3d == null:
		return { &"unit": unit, &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var world_pos: Vector3 = unit3d.global_position
	# Camera3D.is_position_behind catches the "unit is behind the camera"
	# case where unproject_position returns garbage (Godot 4 behavior).
	if camera.is_position_behind(world_pos):
		return { &"unit": unit, &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var screen: Vector2 = camera.unproject_position(world_pos)
	# Off-viewport-clip is a UX choice: we still consider on_screen=true if
	# inside the rect-the-player-drew, even if outside the viewport. The
	# rect itself is bounded by the viewport (you can't drag outside), so
	# this is moot in practice — but we leave the wider behavior in case
	# a future zoom-out drag cascades units near the edge.
	var on_screen: bool = true
	if viewport_size != Vector2.ZERO:
		if screen.x < -1.0 or screen.y < -1.0 or screen.x > viewport_size.x + 1.0 or screen.y > viewport_size.y + 1.0:
			on_screen = false
	return { &"unit": unit, &"screen_pos": screen, &"on_screen": on_screen }


# Commit the box-select result to SelectionManager. Two paths:
#   - Shift held at press: add_to_selection for each hit, preserving
#     previously-selected units.
#   - No Shift: select_only — replace the entire selection with the hits.
#     If the rect was empty (no hits), we still call deselect_all to make
#     drag-on-empty-space match the documented "drag clears prior selection
#     if you let go on nothing" RTS convention.
func _commit_selection(hits: Array, shift: bool) -> void:
	if shift:
		for u in hits:
			if is_instance_valid(u):
				SelectionManager.add_to_selection(u)
		return
	if hits.is_empty():
		SelectionManager.deselect_all()
		return
	# Replace selection with the hit set. select_only takes one unit; we
	# manually rebuild the set by deselecting everyone then selecting each
	# hit. This emits one signal per select, but the scale is small enough
	# (≤ candidate count) that the cost is invisible.
	# A future SelectionManager.select_many(units) would reduce this to one
	# emit; out of scope for wave 1A per the kickoff's "do NOT modify
	# selection_manager.gd" rule.
	SelectionManager.deselect_all()
	for u in hits:
		if is_instance_valid(u):
			SelectionManager.add_to_selection(u)


# ============================================================================
# Overlay
# ============================================================================

func _show_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	_update_overlay_rect()


func _hide_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = false


func _update_overlay_rect() -> void:
	if _overlay == null:
		return
	# The overlay's root Control is a child named "Rect" (see drag_overlay.tscn).
	# It exposes set_drag_rect(rect) for the math handoff.
	if _overlay.has_method(&"set_drag_rect"):
		var r: Rect2 = _BoxSelectMath.rect_from_corners(_press_pos, _current_pos)
		_overlay.call(&"set_drag_rect", r)
