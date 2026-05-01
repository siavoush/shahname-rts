extends Node
##
## DebugOverlayManager — F1–F4 toggle registry for debug overlays.
##
## Per 02_IMPLEMENTATION_PLAN.md Phase 0 + CLAUDE.md ("Debug overlays are
## first-class citizens. Build them early, use them forever."): this autoload
## is the framework only. Concrete overlays land WITH their owning systems
## in later phases per the kickoff doc:
##
##   F1 → pathfinding routes  (Phase 6 — ai-engineer)
##   F2 → Farr change log     (Phase 4 — gameplay-systems)
##   F3 → AI state             (Phase 6 — ai-engineer)
##   F4 → attack ranges        (Phase 2 — ui-developer)
##
## Per docs/SIMULATION_CONTRACT.md §1.5, debug overlays read sim state freely
## from `_process` but NEVER write. Every overlay registered here observes the
## simulation; none mutates it. The lint rule (L1) catches the worst offenders;
## the discipline below is reviewed at code-review.
##
## Key conventions:
##   - StringName keys (`Constants.OVERLAY_KEY_F1` … `OVERLAY_KEY_F4`).
##   - Overlays are `Control` nodes (HUD-layer, not Node3D).
##   - Toggling flips `Control.visible`; we never `queue_free` registered
##     overlays — the owning system manages lifecycle.
##   - Re-registering the same key replaces the prior entry (last-writer-wins).
##     Lets editor scene-reloads work cleanly without bookkeeping.
##
## Tests in tests/unit/test_debug_overlay_manager.gd cover the registry shape,
## toggle behavior, F1-F4 key dispatch, and reset semantics.

# === REGISTRY ===============================================================
# StringName key → Control node. Dictionary, not Array, because overlays
# self-register by key and look themselves up the same way. We don't iterate
# the registry per-frame; this is a low-traffic structure.
var _overlays: Dictionary = {}


# === LIFECYCLE ==============================================================

func _ready() -> void:
	# Tell the engine to keep delivering input to us even when nothing else
	# in the tree handles function keys. Critical: the manager runs in the
	# UI layer (off-tick) and intercepts F1-F4 globally.
	process_mode = Node.PROCESS_MODE_ALWAYS


# F1-F4 dispatch lives in _unhandled_input so gameplay UI consuming text input
# (e.g. a future console / chat) gets first crack at function keys before us.
# Per Sim Contract §1.5 — UI input handling is off-tick and read-only. We
# never mutate sim state here; toggle_overlay only flips Control.visible.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo:
			handle_function_key(ke.keycode)


# === PUBLIC API =============================================================

## Register an overlay under `key`. Re-registering replaces. Idempotent on
## (key, overlay) repeat.
func register_overlay(key: StringName, overlay: Control) -> void:
	_overlays[key] = overlay


## Remove the overlay registered under `key`. No-op if `key` is unknown.
func unregister_overlay(key: StringName) -> void:
	_overlays.erase(key)


## Returns true iff `key` has a live registration.
func is_registered(key: StringName) -> bool:
	return _overlays.has(key)


## Returns the Control registered under `key`, or null if missing.
func get_overlay(key: StringName) -> Control:
	if _overlays.has(key):
		return _overlays[key] as Control
	return null


## All registered keys. Returned as Array (StringName values).
func registered_keys() -> Array:
	return _overlays.keys()


## Flip the visibility of the overlay registered under `key`. No-op if `key`
## is unknown — useful when an F-key is bound for a future-phase overlay
## that doesn't exist yet.
func toggle_overlay(key: StringName) -> void:
	if not _overlays.has(key):
		return
	var overlay: Control = _overlays[key] as Control
	if overlay == null:
		return
	overlay.visible = not overlay.visible


## Map a raw keycode to the overlay key and toggle. Public so tests can drive
## the dispatch without forging InputEventKey objects.
func handle_function_key(keycode: int) -> void:
	var key: StringName = _keycode_to_overlay_key(keycode)
	if key == &"":
		return
	toggle_overlay(key)


## Clear the registry. Used in tests; production code should call this only
## on hard scene reload.
func reset() -> void:
	_overlays.clear()


# === INTERNAL ===============================================================

# F1-F4 → overlay key. Returns the empty StringName for any other keycode,
# which `handle_function_key` treats as a no-op.
func _keycode_to_overlay_key(keycode: int) -> StringName:
	match keycode:
		KEY_F1:
			return Constants.OVERLAY_KEY_F1
		KEY_F2:
			return Constants.OVERLAY_KEY_F2
		KEY_F3:
			return Constants.OVERLAY_KEY_F3
		KEY_F4:
			return Constants.OVERLAY_KEY_F4
		_:
			return &""
