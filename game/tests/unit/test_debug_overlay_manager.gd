# Tests for DebugOverlayManager autoload.
#
# Contract: 02_IMPLEMENTATION_PLAN.md Phase 0 + CLAUDE.md ("Debug overlays as
# first-class. Bind toggles to F1-F4."). The framework is a registry: overlays
# (Control nodes from later phases) register themselves; F1-F4 toggles flip
# their `visible` field. Per the kickoff doc, concrete overlays land WITH
# their owning systems in later phases — Phase 0 ships the registry only.
#
# Per docs/SIMULATION_CONTRACT.md §1.5, overlays read sim state from _process
# but never write. That discipline is documented at the manager level.
extends GutTest


# Each test starts with a clean registry.
func before_each() -> void:
	DebugOverlayManager.reset()


func after_each() -> void:
	DebugOverlayManager.reset()


# -- Registry shape ----------------------------------------------------------

func test_autoload_is_reachable() -> void:
	assert_not_null(DebugOverlayManager,
		"DebugOverlayManager must be registered as an autoload")


func test_default_registry_is_empty() -> void:
	assert_eq(DebugOverlayManager.registered_keys().size(), 0,
		"Fresh DebugOverlayManager has no overlays registered")


func test_register_adds_overlay_under_key() -> void:
	var overlay: Control = Control.new()
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(&"f1_pathfinding", overlay)
	assert_true(DebugOverlayManager.is_registered(&"f1_pathfinding"))
	assert_same(DebugOverlayManager.get_overlay(&"f1_pathfinding"), overlay)


func test_register_replaces_existing_under_same_key() -> void:
	# Re-registering the same key updates the entry (last-writer-wins).
	# Useful in tests + when an overlay scene reloads in editor.
	var first: Control = Control.new()
	var second: Control = Control.new()
	add_child_autofree(first)
	add_child_autofree(second)
	DebugOverlayManager.register_overlay(&"f1_pathfinding", first)
	DebugOverlayManager.register_overlay(&"f1_pathfinding", second)
	assert_same(DebugOverlayManager.get_overlay(&"f1_pathfinding"), second,
		"Re-registering the same key replaces the prior overlay")


func test_unregister_removes_overlay() -> void:
	var overlay: Control = Control.new()
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(&"f4_attack_ranges", overlay)
	DebugOverlayManager.unregister_overlay(&"f4_attack_ranges")
	assert_false(DebugOverlayManager.is_registered(&"f4_attack_ranges"))


func test_unregister_unknown_key_is_noop() -> void:
	# Idempotency — calling unregister on a key that was never registered
	# should not crash.
	DebugOverlayManager.unregister_overlay(&"never_registered")
	assert_eq(DebugOverlayManager.registered_keys().size(), 0)


# -- Toggle behavior ---------------------------------------------------------

func test_toggle_flips_visibility_off_then_on() -> void:
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(&"f2_farr_log", overlay)
	# First toggle → visible
	DebugOverlayManager.toggle_overlay(&"f2_farr_log")
	assert_true(overlay.visible, "First toggle flips invisible → visible")
	# Second toggle → hidden again
	DebugOverlayManager.toggle_overlay(&"f2_farr_log")
	assert_false(overlay.visible, "Second toggle flips visible → invisible")


func test_double_toggle_returns_to_original_state() -> void:
	var overlay: Control = Control.new()
	overlay.visible = true
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(&"f3_state_machine", overlay)
	DebugOverlayManager.toggle_overlay(&"f3_state_machine")
	DebugOverlayManager.toggle_overlay(&"f3_state_machine")
	assert_true(overlay.visible, "Two toggles must return to original state")


func test_toggle_unknown_key_is_noop() -> void:
	# Toggling an unregistered key shouldn't crash. Useful when an early-phase
	# session has F1 bound but F1's overlay (phase 6) isn't built yet.
	DebugOverlayManager.toggle_overlay(&"f1_pathfinding")
	# No overlays registered, no error → assertion is just "we got here".
	assert_eq(DebugOverlayManager.registered_keys().size(), 0)


# -- F1-F4 key dispatch ------------------------------------------------------
# Per 02_IMPLEMENTATION_PLAN.md Phase 0:
#   F1 = pathfinding routes (Phase 6)
#   F2 = Farr change log    (Phase 4)
#   F3 = AI state           (Phase 6)
#   F4 = attack ranges      (Phase 2)
# The constants live on Constants (OVERLAY_KEY_F1..F4); the manager must use
# those when an F-key is pressed.

func test_handle_function_key_toggles_f1() -> void:
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F1, overlay)
	DebugOverlayManager.handle_function_key(KEY_F1)
	assert_true(overlay.visible, "F1 must toggle the F1-bound overlay on")


func test_handle_function_key_toggles_f2() -> void:
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F2, overlay)
	DebugOverlayManager.handle_function_key(KEY_F2)
	assert_true(overlay.visible, "F2 must toggle the F2-bound overlay on")


func test_handle_function_key_toggles_f3() -> void:
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F3, overlay)
	DebugOverlayManager.handle_function_key(KEY_F3)
	assert_true(overlay.visible, "F3 must toggle the F3-bound overlay on")


func test_handle_function_key_toggles_f4() -> void:
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F4, overlay)
	DebugOverlayManager.handle_function_key(KEY_F4)
	assert_true(overlay.visible, "F4 must toggle the F4-bound overlay on")


func test_handle_function_key_does_not_dispatch_other_keys() -> void:
	# Pressing F5 or A should NOT toggle any of the F1-F4 overlays.
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F1, overlay)
	DebugOverlayManager.handle_function_key(KEY_F5)
	DebugOverlayManager.handle_function_key(KEY_A)
	assert_false(overlay.visible,
		"Non-F1-F4 keys must not toggle any overlay")


func test_double_press_f_key_hides_again() -> void:
	# Press F2 twice — overlay back to invisible.
	var overlay: Control = Control.new()
	overlay.visible = false
	add_child_autofree(overlay)
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F2, overlay)
	DebugOverlayManager.handle_function_key(KEY_F2)
	DebugOverlayManager.handle_function_key(KEY_F2)
	assert_false(overlay.visible, "Double-press F2 must hide the overlay again")


# -- Reset -------------------------------------------------------------------

func test_reset_clears_all_registrations() -> void:
	var a: Control = Control.new()
	var b: Control = Control.new()
	add_child_autofree(a)
	add_child_autofree(b)
	DebugOverlayManager.register_overlay(&"f1_pathfinding", a)
	DebugOverlayManager.register_overlay(&"f4_attack_ranges", b)
	DebugOverlayManager.reset()
	assert_eq(DebugOverlayManager.registered_keys().size(), 0,
		"reset() must clear the registry entirely")
