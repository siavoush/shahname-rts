# Tests for CameraController.
#
# Contract: 02_IMPLEMENTATION_PLAN.md Phase 0 — fixed isometric camera, no
# rotation, WASD pan, edge-pan within 50px of viewport edge, scroll-wheel
# zoom with min/max clamps, camera bounds matching the map size. Per the
# Sync 6 Engine-Constraint convergence and 00_SHAHNAMEH_RESEARCH.md the
# camera is locked to a fixed angle (Persian-miniature aesthetic).
#
# These tests instantiate the controller in isolation so they don't depend
# on the camera_rig.tscn scene tree or a real Viewport — pan/zoom math is
# exposed as pure-ish methods on the controller (pan_by, zoom_by,
# clamp_to_bounds, compute_pan_axis) so each can be exercised headless.
extends GutTest


const CameraControllerScript: Script = preload("res://scripts/camera/camera_controller.gd")


var ctrl: Node = null


func before_each() -> void:
	ctrl = CameraControllerScript.new()
	# add_child gives the node a tree so any @onready/get_viewport-style code
	# in the controller has a host. The controller MUST work without a real
	# Camera3D child — tests cover the math, not the scene wiring.
	add_child_autofree(ctrl)
	ctrl.set_test_mode(true)  # disables _process driving from real input/viewport


func after_each() -> void:
	ctrl = null


# -- No rotation API ---------------------------------------------------------

func test_controller_does_not_expose_rotation_api() -> void:
	# Per Sync 6 Engine-Constraint convergence, camera is fixed isometric.
	# No method named rotate_*, no property named yaw / pitch / orbit on the
	# controller surface. This test is the lint anchor — if anyone adds a
	# rotation method later, this test catches it before the contract drift.
	assert_false(ctrl.has_method("rotate_yaw"), "Camera must not expose yaw rotation")
	assert_false(ctrl.has_method("rotate_pitch"), "Camera must not expose pitch rotation")
	assert_false(ctrl.has_method("orbit"), "Camera must not orbit the target")
	assert_false(ctrl.has_method("set_yaw"), "Camera must not expose yaw setter")
	assert_false(ctrl.has_method("set_pitch"), "Camera must not expose pitch setter")
	# No yaw/pitch/orbit property either — get() returns null for missing props.
	assert_null(ctrl.get(&"yaw"), "yaw property must not exist")
	assert_null(ctrl.get(&"pitch"), "pitch property must not exist")


# -- Pan accumulation under WASD --------------------------------------------

func test_pan_accumulates_target_position_with_delta() -> void:
	ctrl.target_position = Vector3.ZERO
	# +X axis input for one second at default pan_speed should advance target
	# by exactly pan_speed in world X.
	ctrl.pan_by(Vector2(1.0, 0.0), 1.0)
	assert_almost_eq(ctrl.target_position.x, ctrl.pan_speed, 1e-4,
		"+X input over 1.0s delta should move target_position by pan_speed on X")
	assert_almost_eq(ctrl.target_position.z, 0.0, 1e-4,
		"Pure +X input must not move Z")


func test_pan_uses_z_axis_for_forward() -> void:
	# +Y axis input ("up", forward in screen space) maps to -Z in world space
	# for a top-down/isometric camera (camera looks roughly toward +Z, so
	# panning "forward" decreases Z).
	ctrl.target_position = Vector3.ZERO
	ctrl.pan_by(Vector2(0.0, 1.0), 1.0)
	assert_almost_eq(ctrl.target_position.x, 0.0, 1e-4)
	# Either +Z or -Z is acceptable as long as it's consistent and non-zero;
	# the controller documents which it uses.
	assert_true(absf(ctrl.target_position.z) > 0.0,
		"+Y screen-axis input must move target along Z")


func test_diagonal_input_is_normalized_no_speed_boost() -> void:
	# Diagonal (1, 1) input must NOT move sqrt(2) faster than pure-axis input.
	ctrl.target_position = Vector3.ZERO
	ctrl.pan_by(Vector2(1.0, 1.0), 1.0)
	# Distance in XZ plane (Y is fixed for the rig).
	var moved: float = Vector2(ctrl.target_position.x, ctrl.target_position.z).length()
	assert_almost_eq(moved, ctrl.pan_speed, 1e-4,
		"Diagonal input must be normalized — same speed as pure-axis input")


func test_zero_input_does_not_move() -> void:
	ctrl.target_position = Vector3(1, 0, 1)
	ctrl.pan_by(Vector2.ZERO, 1.0)
	assert_eq(ctrl.target_position, Vector3(1, 0, 1),
		"Zero input must leave target_position untouched")


func test_pan_speed_is_frame_rate_independent() -> void:
	# Two half-second steps should equal one full-second step.
	ctrl.target_position = Vector3.ZERO
	ctrl.pan_by(Vector2(1, 0), 0.5)
	ctrl.pan_by(Vector2(1, 0), 0.5)
	var two_step: float = ctrl.target_position.x
	ctrl.target_position = Vector3.ZERO
	ctrl.pan_by(Vector2(1, 0), 1.0)
	var one_step: float = ctrl.target_position.x
	assert_almost_eq(two_step, one_step, 1e-4,
		"Pan must be frame-rate independent (two halves == one whole)")


# -- Zoom clamps -------------------------------------------------------------

func test_zoom_in_decreases_distance() -> void:
	ctrl.zoom_distance = ctrl.zoom_max
	var before: float = ctrl.zoom_distance
	ctrl.zoom_by(-1.0)  # negative = zoom in (closer)
	assert_true(ctrl.zoom_distance < before, "Zoom in must decrease zoom_distance")


func test_zoom_out_increases_distance() -> void:
	ctrl.zoom_distance = ctrl.zoom_min
	var before: float = ctrl.zoom_distance
	ctrl.zoom_by(1.0)
	assert_true(ctrl.zoom_distance > before, "Zoom out must increase zoom_distance")


func test_zoom_clamps_to_min() -> void:
	ctrl.zoom_distance = ctrl.zoom_min
	# Hammer zoom-in repeatedly — distance must not drop below zoom_min.
	for i in range(20):
		ctrl.zoom_by(-1.0)
	assert_almost_eq(ctrl.zoom_distance, ctrl.zoom_min, 1e-4,
		"Zoom must clamp to zoom_min on excessive zoom-in")


func test_zoom_clamps_to_max() -> void:
	ctrl.zoom_distance = ctrl.zoom_max
	for i in range(20):
		ctrl.zoom_by(1.0)
	assert_almost_eq(ctrl.zoom_distance, ctrl.zoom_max, 1e-4,
		"Zoom must clamp to zoom_max on excessive zoom-out")


# -- Camera bounds (clamp to map) -------------------------------------------

func test_pan_clamps_to_map_bounds_on_positive_axis() -> void:
	# Map is centered at origin, half-extent = MAP_SIZE_WORLD / 2.
	# Push hard +X for many seconds — target must clamp to the bound, not pass it.
	ctrl.target_position = Vector3.ZERO
	for i in range(100):
		ctrl.pan_by(Vector2(1, 0), 1.0)
	var half_extent: float = ctrl.map_size * 0.5
	assert_true(ctrl.target_position.x <= half_extent + 1e-4,
		"Target_x must not exceed map half-extent (got %.2f, max %.2f)" % [
			ctrl.target_position.x, half_extent])


func test_pan_clamps_to_map_bounds_on_negative_axis() -> void:
	ctrl.target_position = Vector3.ZERO
	for i in range(100):
		ctrl.pan_by(Vector2(-1, 0), 1.0)
	var half_extent: float = ctrl.map_size * 0.5
	assert_true(ctrl.target_position.x >= -half_extent - 1e-4,
		"Target_x must not undershoot -map half-extent")


func test_explicit_clamp_to_bounds() -> void:
	# Setting target_position outside the bounds via the helper clamps it.
	var clamped: Vector3 = ctrl.clamp_to_bounds(Vector3(9999.0, 0.0, -9999.0))
	var half_extent: float = ctrl.map_size * 0.5
	assert_almost_eq(clamped.x, half_extent, 1e-4)
	assert_almost_eq(clamped.z, -half_extent, 1e-4)


# -- Edge-pan ----------------------------------------------------------------

func test_compute_edge_pan_axis_returns_zero_in_center() -> void:
	# A 1280x720 viewport with mouse at (640, 360) is dead-center — no edge-pan.
	var axis: Vector2 = ctrl.compute_edge_pan_axis(Vector2(640, 360), Vector2(1280, 720))
	assert_eq(axis, Vector2.ZERO, "Center mouse must produce zero edge-pan axis")


func test_compute_edge_pan_axis_triggers_within_threshold() -> void:
	# Mouse at (10, 360) — 10px from left edge, well within the 50px threshold.
	var axis: Vector2 = ctrl.compute_edge_pan_axis(Vector2(10, 360), Vector2(1280, 720))
	assert_true(axis.x < 0.0, "Mouse near left edge must produce negative X axis")
	assert_almost_eq(axis.y, 0.0, 1e-4, "Mouse not near top/bottom must leave Y axis at 0")


func test_compute_edge_pan_axis_does_not_trigger_outside_threshold() -> void:
	# Mouse at (200, 360) — 200px from left edge, well outside the 50px threshold.
	var axis: Vector2 = ctrl.compute_edge_pan_axis(Vector2(200, 360), Vector2(1280, 720))
	assert_eq(axis, Vector2.ZERO, "Mouse outside edge threshold must not trigger pan")


func test_compute_edge_pan_axis_top_edge_triggers_positive_y() -> void:
	# Convention matches WASD: ax.y = +1 means "forward." Mouse-near-top fires
	# the same axis as pressing W, so both input paths pan the camera in the
	# same world direction.
	var axis: Vector2 = ctrl.compute_edge_pan_axis(Vector2(640, 5), Vector2(1280, 720))
	assert_true(axis.y > 0.0, "Mouse near top edge must produce +Y axis (forward, matches WASD W)")


func test_compute_edge_pan_axis_bottom_right_corner() -> void:
	# Right edge → +X (matches WASD D). Bottom edge → -Y (matches WASD S).
	var axis: Vector2 = ctrl.compute_edge_pan_axis(Vector2(1275, 715), Vector2(1280, 720))
	assert_true(axis.x > 0.0, "Mouse near right edge must produce +X axis")
	assert_true(axis.y < 0.0, "Mouse near bottom edge must produce -Y axis (backward, matches WASD S)")


# -- Edge-pan threshold matches contract -------------------------------------

func test_edge_pan_threshold_is_50_pixels() -> void:
	# Per 02_IMPLEMENTATION_PLAN.md Phase 0 — edge trigger at 50px.
	assert_eq(ctrl.edge_pan_threshold_px, 50,
		"Edge-pan threshold must be 50px per Phase 0 contract")
