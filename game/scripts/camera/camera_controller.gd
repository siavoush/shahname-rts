extends Node3D
##
## CameraController — fixed-isometric RTS camera rig.
##
## Per 02_IMPLEMENTATION_PLAN.md Phase 0 + Sync 6 Engine-Constraint convergence:
## the camera is locked to a fixed isometric angle. Rotation is explicitly
## out of scope — it removes a class of bugs (selection raycast, edge-pan
## logic, minimap orientation, fog framing) and matches the Persian-miniature
## aesthetic per 00_SHAHNAMEH_RESEARCH.md.
##
## Responsibilities:
##   - WASD pan: keyboard-axis input moves the rig (and therefore the camera)
##     along the XZ plane.
##   - Edge pan: when the mouse is within edge_pan_threshold_px (50px per the
##     contract) of any viewport edge, pan in that direction.
##   - Scroll-wheel zoom: scroll moves the camera closer to / further from the
##     rig along its forward axis, clamped to [zoom_min, zoom_max].
##   - Camera bounds: target position clamps to half the map size on each
##     XZ axis (map is centered at origin per world-builder's terrain plane).
##   - Frame-rate independent: every motion is multiplied by delta.
##   - Diagonal movement is normalized — no √2 speed boost.
##
## Off-tick reads only. Per docs/SIMULATION_CONTRACT.md §1.1, the camera reads
## sim state freely from `_process` and `_input` but never writes sim state.
## Position is camera-side state (not gameplay state), so the SimNode invariant
## doesn't apply here — but discipline does.
##
## Tests in tests/unit/test_camera_controller.gd cover pan, zoom clamps,
## edge-pan threshold, no-rotation API surface, and bounds clamping.

# === TUNING (Phase 0 placeholders — these may move to BalanceData later) ===
# These are camera-feel knobs, not gameplay-balance numbers, so they live on
# the controller for now. If a "camera config" emerges, hoist there.

## World-units per second of pan motion at full input.
@export var pan_speed: float = 30.0

## Pixels from any viewport edge that triggers edge-pan.
## Locked at 50 per 02_IMPLEMENTATION_PLAN.md Phase 0 contract.
@export var edge_pan_threshold_px: int = 50

## World-units per scroll-wheel notch of zoom motion.
@export var zoom_step: float = 4.0

## Min/max zoom distance from the rig along the camera's local -Z axis.
@export var zoom_min: float = 12.0
@export var zoom_max: float = 80.0

## Default zoom distance at boot (between min and max).
@export var zoom_default: float = 40.0

## Map size in world units. Half-extent on each side of origin.
## Mirrors `Constants.MAP_SIZE_WORLD` when world-builder lands it. Until then,
## we read defensively (Constants.get returns null for missing) and fall back
## to 256.0 — the agreed Phase 0 map size.
@export var map_size: float = 256.0


# === RUNTIME STATE ==========================================================

## The pivot position the rig sits at (camera follows this on XZ).
## Public for tests; canonical write happens in pan_by / clamp_to_bounds.
var target_position: Vector3 = Vector3.ZERO

## Distance from rig to camera along the camera's forward axis.
## Public for tests; canonical write happens in zoom_by.
var zoom_distance: float = 0.0

## When true, _process / _input are no-ops. Tests flip this on so the math
## helpers (pan_by, zoom_by, clamp_to_bounds, compute_edge_pan_axis)
## can be exercised without a real Viewport / InputMap.
var _test_mode: bool = false


# === LIFECYCLE ==============================================================

func _ready() -> void:
	# Defensively read MAP_SIZE_WORLD from Constants if it's been added by
	# world-builder's parallel session. Fallback keeps the controller working
	# during the brief window where camera lands first.
	var ms_from_constants: Variant = Constants.get(&"MAP_SIZE_WORLD")
	if ms_from_constants != null and (ms_from_constants is float or ms_from_constants is int):
		map_size = float(ms_from_constants)

	zoom_distance = clampf(zoom_default, zoom_min, zoom_max)
	target_position = clamp_to_bounds(target_position)
	_apply_transforms()


func _process(delta: float) -> void:
	if _test_mode:
		return
	# Drain WASD axis. Project actions land in InputMap when main scene wires
	# the rig in — for Phase 0 we use literal keycodes so the controller works
	# the moment it's added to a scene.
	var axis: Vector2 = _read_keyboard_pan_axis()

	# Edge-pan additively combines with WASD; player can also lean on the edge.
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var mouse_pos: Vector2 = viewport.get_mouse_position()
		var vp_size: Vector2 = viewport.get_visible_rect().size
		axis += compute_edge_pan_axis(mouse_pos, vp_size)

	if axis != Vector2.ZERO:
		pan_by(axis, delta)
	_apply_transforms()


func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_by(-1.0)
				_apply_transforms()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1.0)
				_apply_transforms()


# === PUBLIC API (called by tests + by _process when not in test mode) =======

## Move the rig along the XZ plane by `axis` (screen-space, +Y = forward) for
## `delta` seconds. Diagonal input is normalized: pure axis vs. (1, 1) move
## the same distance.
##
## Direction is camera-relative: "+Y forward" means "the direction the camera
## is currently looking, projected onto the ground." We compute the pan in
## the rig's local frame (rig-local -Z = camera-forward) and rotate it through
## the rig's world basis. With the camera_rig.tscn yaw of +45°, this makes
## screen-up follow where the camera actually points (NE in world terms),
## not the world -Z axis. Without the basis multiply, edge-pan and WASD both
## drift relative to the camera view.
func pan_by(axis: Vector2, delta: float) -> void:
	if axis == Vector2.ZERO:
		return
	# Normalize so diagonal movement isn't faster than pure-axis.
	var dir: Vector2 = axis.normalized()
	# Build the pan in rig-local space: +X = camera-right, -Z = camera-forward.
	# Screen-axis convention is +Y = forward, so +Y maps to local -Z.
	var local_pan: Vector3 = Vector3(dir.x, 0.0, -dir.y) * pan_speed * delta
	# Rotate through the rig's basis to get the world-space delta. If the rig
	# isn't yet in the tree (test fixtures), basis is identity and this is a
	# no-op — preserving the headless-test contract.
	var world_pan: Vector3 = global_transform.basis * local_pan if is_inside_tree() \
		else local_pan
	target_position = clamp_to_bounds(target_position + world_pan)


## Zoom the camera in (negative scroll) or out (positive scroll). Clamped to
## [zoom_min, zoom_max].
func zoom_by(scroll_delta: float) -> void:
	zoom_distance = clampf(zoom_distance + scroll_delta * zoom_step, zoom_min, zoom_max)


## Clamp a candidate target position to the map's XZ bounds. Map is centered
## at origin so the legal range is [-map_size/2, +map_size/2] on each axis.
## Returns the clamped position; does NOT mutate target_position.
func clamp_to_bounds(p: Vector3) -> Vector3:
	var half: float = map_size * 0.5
	return Vector3(
		clampf(p.x, -half, half),
		p.y,
		clampf(p.z, -half, half),
	)


## Compute an edge-pan axis from the current mouse position and viewport size.
## Returns a Vector2 in screen-space convention (+Y = up/forward, +X = right).
## Each component is in [-1, 0, +1]: 0 if outside the threshold, signed otherwise.
##
## Convention matches WASD: ax.y = +1 means "pan forward" (screen-up), so
## mouse-near-top produces ax.y = +1 — same as pressing W. Without that
## alignment, edge-pan would move the camera in the opposite world direction
## from WASD (the original wave-1 implementation had this inverted, with
## edge-top producing ax.y = -1; that is the bug the user reported).
func compute_edge_pan_axis(mouse_pos: Vector2, viewport_size: Vector2) -> Vector2:
	var threshold: float = float(edge_pan_threshold_px)
	var ax: Vector2 = Vector2.ZERO
	if mouse_pos.x < threshold:
		ax.x = -1.0
	elif mouse_pos.x > viewport_size.x - threshold:
		ax.x = 1.0
	if mouse_pos.y < threshold:
		ax.y = 1.0   # near top edge → pan forward (matches WASD W)
	elif mouse_pos.y > viewport_size.y - threshold:
		ax.y = -1.0  # near bottom edge → pan backward (matches WASD S)
	return ax


## Test hook: disable _process / _unhandled_input handling. Tests call this
## so the controller can be exercised in isolation without a real viewport
## or InputMap, and so they don't race the engine's own _process tick.
func set_test_mode(on: bool) -> void:
	_test_mode = on


# === INTERNAL ===============================================================

# WASD axis — simple keyboard read, no InputMap dependency. The fixed isometric
# camera contract says rotation is OUT, so the axis is screen-space and we can
# bind directly to physical keys here.
func _read_keyboard_pan_axis() -> Vector2:
	var ax: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		ax.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		ax.x -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		ax.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		ax.y -= 1.0
	return ax


# Sync the rig position and the camera-child distance to the latest state.
# Internal — called by _process / _unhandled_input after every state mutation.
func _apply_transforms() -> void:
	if not is_inside_tree():
		return
	global_position = target_position
	# Camera child is positioned in the rig's local +Y / +Z plane such that,
	# combined with the Camera3D's -55° pitch (set ONCE in camera_rig.tscn and
	# never modified per the no-rotation contract), the camera looks at the
	# rig origin. The Y/Z split is sin/cos of the pitch angle:
	#   pitch = 55° ⇒ Y = zoom_distance * sin(55°) ≈ zoom_distance * 0.819
	#                  Z = zoom_distance * cos(55°) ≈ zoom_distance * 0.574
	# This places the camera elevated above and behind the target — the
	# "two-thirds top-down" RTS framing per camera_rig.tscn's authoring note.
	# Without the Y component the camera sits at ground level (Y=0) and
	# looks down through the terrain plane, rendering nothing visible.
	var cam: Camera3D = _find_camera_child()
	if cam != null:
		const PITCH_SIN: float = 0.819152  # sin(55°)
		const PITCH_COS: float = 0.573576  # cos(55°)
		cam.position = Vector3(0.0, zoom_distance * PITCH_SIN, zoom_distance * PITCH_COS)


func _find_camera_child() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	return null
