# Tests for FarrLogOverlay — F2 debug overlay (Phase 4 wave 1).
#
# Contract:
#   - CLAUDE.md — "every Farr change as a floating log"; F2 = Farr log.
#   - docs/SIMULATION_CONTRACT.md §1.5 — queue-then-drain: farr_changed events
#     enqueue in the handler, the visual update drains in _process (off-tick).
#   - game/scripts/ui/overlays/farr_log_overlay.gd — the SUT.
#
# Coverage:
#   - Registers with DebugOverlayManager under OVERLAY_KEY_F2.
#   - Starts hidden; F2 toggle flips visibility.
#   - Queue-then-drain: farr_changed enqueues; _process drains into _entries.
#   - Bounded to MAX_ENTRIES (oldest fall off).
extends GutTest

const _OverlayScene: PackedScene = preload(
	"res://scenes/ui/overlays/farr_log_overlay.tscn")

var _overlay: Control = null


func before_each() -> void:
	DebugOverlayManager.reset()
	_overlay = _OverlayScene.instantiate()
	add_child_autofree(_overlay)


func after_each() -> void:
	DebugOverlayManager.reset()


func test_overlay_registers_under_f2_key() -> void:
	assert_true(DebugOverlayManager.is_registered(Constants.OVERLAY_KEY_F2),
		"FarrLogOverlay must register with DebugOverlayManager under F2")
	assert_eq(DebugOverlayManager.get_overlay(Constants.OVERLAY_KEY_F2), _overlay,
		"the registered F2 overlay must be this FarrLogOverlay instance")


func test_overlay_starts_hidden() -> void:
	assert_false(_overlay.visible,
		"F2 overlay starts hidden — F2 keypress is the only show-path")


func test_f2_toggle_flips_visibility() -> void:
	assert_false(_overlay.visible)
	DebugOverlayManager.handle_function_key(KEY_F2)
	assert_true(_overlay.visible, "F2 toggle shows the overlay")
	DebugOverlayManager.handle_function_key(KEY_F2)
	assert_false(_overlay.visible, "second F2 toggle hides it again")


func test_mouse_filter_is_ignore() -> void:
	# Pitfall #1 — the overlay must never eat clicks.
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"FarrLogOverlay mouse_filter must be IGNORE (Pitfall #1)")


func test_farr_changed_enqueues_then_drains() -> void:
	# Queue-then-drain (Sim Contract §1.5): the handler ONLY enqueues; _process
	# drains into the displayed _entries.
	_overlay.handle_farr_changed(-0.5, "snowball_kill_outnumbered", 42, 49.5, 100)
	assert_eq(_overlay.pending_count(), 1,
		"handle_farr_changed enqueues (does not synchronously mutate _entries)")
	assert_eq(_overlay.entries().size(), 0,
		"entries empty until _process drains the queue")
	_overlay.drain_for_test()
	assert_eq(_overlay.pending_count(), 0, "drain empties the pending queue")
	assert_eq(_overlay.entries().size(), 1, "drained event lands in _entries")
	var e: Dictionary = _overlay.entries()[0]
	assert_almost_eq(float(e["amount"]), -0.5, 1e-6)
	assert_eq(String(e["reason"]), "snowball_kill_outnumbered")
	assert_almost_eq(float(e["farr_after"]), 49.5, 1e-6)


func test_log_bounded_to_max_entries() -> void:
	# Push more than MAX_ENTRIES; oldest fall off.
	var cap: int = _overlay.MAX_ENTRIES
	for i in range(cap + 5):
		_overlay.handle_farr_changed(1.0, "atashkadeh_emission", -1,
			50.0 + float(i), i)
	_overlay.drain_for_test()
	assert_eq(_overlay.entries().size(), cap,
		"log is bounded to MAX_ENTRIES — oldest entries fall off")
	# The newest entry (tick = cap+4) must be retained.
	var newest: Dictionary = _overlay.entries()[_overlay.entries().size() - 1]
	assert_eq(int(newest["tick"]), cap + 4,
		"the most-recent event is retained after trimming")


func test_overlay_subscribes_to_farr_changed() -> void:
	assert_true(EventBus.farr_changed.is_connected(_overlay._on_farr_changed),
		"FarrLogOverlay subscribes to EventBus.farr_changed")
