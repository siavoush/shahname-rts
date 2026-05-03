extends Control
##
## AttackRangeOverlay — F4 debug overlay drawing attack-range circles around
## each selected unit.
##
## Phase 2 session 1 wave 2C (ui-developer). Per 02d_PHASE_2_KICKOFF.md §2
## deliverable 9.
##
## Behavior: when F4 is pressed, render a translucent gold circle on the
## ground plane around each selected unit at radius =
## CombatComponent.attack_range. Toggles via DebugOverlayManager (the F1-F4
## framework). Subscribes to EventBus.selection_changed so the circle set
## stays in sync with the player's selection.
##
## Implementation choice — Control + projected circle, NOT Node3D + cylinder:
##   The kickoff brief preferred a 3D overlay ("circles in world space stay
##   correct under camera moves"). However:
##     - DebugOverlayManager.register_overlay statically types its parameter
##       as `Control` and `toggle_overlay` does `_overlays[key] as Control`,
##       which returns null for a Node3D — the F4 toggle would silently no-op.
##     - The wave brief explicitly forbids modifying debug_overlay_manager.gd
##       ("touch only via public API").
##     - Per-frame screen projection of a circle (sample N points on the
##       circle in world space → unproject_position each → polyline) is
##       visually identical to a Node3D cylinder under any camera move. We
##       re-project every frame.
##   Picking Control sidesteps the cross-cutting API change and keeps the
##   overlay inside the file-ownership rules. Documented here so the next
##   reader doesn't relitigate the choice.
##
## CRITICAL: mouse_filter == MOUSE_FILTER_IGNORE — Pitfall #1, the canonical
## session-1 regression. Set in BOTH the .tscn AND defensively at runtime in
## `_ready` (belt-and-braces).
##
## Re-entrancy discipline (Pitfall #4):
##   The overlay subscribes to `EventBus.selection_changed`. Per the cb95d09
##   lesson (BUILD_LOG 2026-05-04), handlers MUST NOT mutate SelectionManager
##   or any state-holder that broadcasts on the same signal. This handler
##   is read-only — it only walks `SelectionManager.selected_units` to
##   collect the new circle set and stashes the entries on `self`. No
##   SelectionManager.* mutators are called from inside the handler.
##
## Sim Contract §1.5 fit:
##   `_process` is NOT used here — entries refresh only when selection
##   changes (signal-driven). `_draw` uses the live Camera3D for projection
##   per frame; that's a UI off-tick read of a Node3D's `transform`, which
##   Sim Contract §1.5 explicitly allows. No sim-state mutation. No
##   write-shaped EventBus.*.emit. No `apply_*` calls.
##
## Live-game-broken-surface answers (Experiment 01):
##
##   1. *State that must work at runtime that no unit test exercises:*
##      - The F4 toggle path through DebugOverlayManager. Headless tests
##        register and call handle_function_key directly; live mode goes
##        through `_unhandled_input` on the manager autoload, requiring
##        process_mode = ALWAYS (already set in Phase 0). If F4 is
##        intercepted by another _unhandled_input listener earlier in the
##        tree, the toggle never reaches us — symptom would be "F4 does
##        nothing" with no error. The manager owns this.
##      - The lifetime ordering: AttackRangeOverlay._ready must run AFTER
##        DebugOverlayManager._ready (autoload — guaranteed) AND must
##        register itself before the user has a chance to press F4. The
##        autoload-vs-scene parse order satisfies this.
##      - Pitfall #4 — the handler reads `SelectionManager.selected_units`
##        but does NOT call select / select_only / deselect_all from inside
##        the handler. (Verified by code inspection in this file's seam.)
##
##   2. *What can a headless test not detect:*
##      - Whether the circle's color (gold, alpha 0.4) reads as "this is a
##        debug visualization" vs. "this is a gameplay element". Lead's
##        live-test feedback may push us to a more saturated band.
##      - Whether the circle is drawn AT the unit's feet (Y=0.05 above
##        ground) or floating awkwardly. The world-space sample loop puts
##        points at Y=0.05; visual feel is the lead's call.
##      - At extreme zoom-out, sampled circle vertices would be sparse
##        enough to look polygonal. _CIRCLE_SAMPLES = 48 gives a smooth
##        appearance at default zoom; tunable.
##
##   3. *Minimum interactive smoke test:*
##      - Lead selects 5 Iran Piyade, hits F4 → 5 gold circles on the
##        ground around them, radius 1.5 (matches BalanceData attack_range).
##      - Lead hits F4 again → circles disappear.
##      - Lead deselects → next F4 press shows nothing (circles still hidden
##        since selection is empty).

# ============================================================================
# Tunables
# ============================================================================

# Color: warm gold, semi-transparent. Matches the kickoff §2 (9) brief.
const _COLOR_CIRCLE: Color = Color(1.0, 0.85, 0.2, 0.55)

# Stroke thickness in screen pixels. Thin enough not to obscure unit
# silhouettes, thick enough to read at default zoom.
const _STROKE_WIDTH: float = 2.0

# Number of sample points around the circle. 48 is smooth at default zoom
# without being expensive. The polyline draws N+1 points (closing the loop).
const _CIRCLE_SAMPLES: int = 48

# Y offset above ground for the sample ring. Just enough to not z-fight
# with terrain at default camera angle.
const _CIRCLE_GROUND_Y: float = 0.05


# ============================================================================
# State (read-only from outside)
# ============================================================================

# The current circle entries. Refreshed on every EventBus.selection_changed.
# Each entry: { unit_id: int, world_pos: Vector3, radius: float }.
# Tests read this back via the public `entries()` accessor.
var _entries: Array = []


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Pitfall #1 — force IGNORE regardless of .tscn state.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	# F4 overlays start hidden — F4 keypress is the only show-path.
	visible = false
	# Register with the F1-F4 framework so handle_function_key(KEY_F4)
	# toggles our visibility. DebugOverlayManager is an autoload — always
	# alive by the time this scene-bound _ready fires.
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F4, self)
	# Subscribe to the selection broadcast. Reading-shaped signal —
	# allowed from any context (Sim Contract §1.5 / L2 allowlist).
	if not EventBus.selection_changed.is_connected(handle_selection_changed):
		EventBus.selection_changed.connect(handle_selection_changed)
	# Seed the initial entry list from any pre-existing selection (e.g., if
	# the overlay is added to the scene AFTER units are selected).
	handle_selection_changed([])


func _exit_tree() -> void:
	# Symmetric disconnect. Matches the hygiene farr_gauge.gd /
	# selected_unit_panel.gd apply.
	if EventBus.selection_changed.is_connected(handle_selection_changed):
		EventBus.selection_changed.disconnect(handle_selection_changed)
	if DebugOverlayManager.is_registered(Constants.OVERLAY_KEY_F4):
		DebugOverlayManager.unregister_overlay(Constants.OVERLAY_KEY_F4)


# ============================================================================
# Selection handler — Pitfall #4 audit point
# ============================================================================
# This handler is the F4 overlay's primary input. Per the cb95d09 lesson,
# we must NOT mutate SelectionManager state (select / deselect / select_only)
# from inside this handler. Verified read-only by code inspection: we walk
# `SelectionManager.selected_units` (a read accessor that returns a fresh
# Array) and stash entries; nothing in this method calls a SelectionManager
# mutator.
#
# Public to let tests drive the path without going through the autoload.
# The signal payload (selected_unit_ids: Array) is unused — we read live
# unit refs off SelectionManager.selected_units instead, so freed entries
# are filtered defensively.

func handle_selection_changed(_selected_unit_ids: Array) -> void:
	var fresh: Array = []
	var live_units: Array = SelectionManager.selected_units
	for u in live_units:
		if u == null or not is_instance_valid(u):
			continue
		# Combat lookup — duck-typed via has_method.
		if not u.has_method(&"get_combat"):
			continue
		var combat: Object = u.call(&"get_combat")
		if combat == null or not is_instance_valid(combat):
			continue
		var range_v: Variant = combat.get(&"attack_range")
		if typeof(range_v) != TYPE_FLOAT and typeof(range_v) != TYPE_INT:
			continue
		var attack_range: float = float(range_v)
		# Skip degenerate zero-radius circles (Kargar workers). The circle
		# would either be invisible or render as a dot — neither helpful.
		if attack_range <= 0.0:
			continue
		var unit_id: int = -1
		var uid_v: Variant = u.get(&"unit_id")
		if typeof(uid_v) == TYPE_INT:
			unit_id = int(uid_v)
		var unit3d: Node3D = u as Node3D
		var world_pos: Vector3 = Vector3.ZERO
		if unit3d != null:
			world_pos = unit3d.global_position
		fresh.append({
			&"unit_id": unit_id,
			&"world_pos": world_pos,
			&"radius": attack_range,
		})
	_entries = fresh
	queue_redraw()


# Public accessors — for tests and the (future) lead's live inspection.
func entries() -> Array:
	# Defensive copy so external callers can't mutate our internal state.
	return _entries.duplicate()


func circle_count() -> int:
	return _entries.size()


# ============================================================================
# Drawing
# ============================================================================
# We sample N points around each circle in world space (XZ plane, fixed Y
# slightly above ground) and unproject each through the live Camera3D to
# screen. Then draw_polyline connects the points. This produces a circle
# that follows the camera correctly under any view transform — same visual
# result as a Node3D cylinder, no API surface for the manager to widen.

func _draw() -> void:
	if _entries.is_empty():
		return
	var camera: Camera3D = _resolve_camera()
	if camera == null:
		return
	for entry in _entries:
		var center_world: Vector3 = entry.get(&"world_pos", Vector3.ZERO)
		var r: float = float(entry.get(&"radius", 0.0))
		if r <= 0.0:
			continue
		# Drop the center to the ground plane and lift slightly so the
		# polyline doesn't z-fight terrain.
		var ground_center: Vector3 = Vector3(
				center_world.x, _CIRCLE_GROUND_Y, center_world.z)
		# Sample the ring.
		var screen_pts: PackedVector2Array = PackedVector2Array()
		var any_visible: bool = false
		for i in range(_CIRCLE_SAMPLES + 1):
			var theta: float = TAU * float(i) / float(_CIRCLE_SAMPLES)
			var sample: Vector3 = ground_center + Vector3(
					cos(theta) * r, 0.0, sin(theta) * r)
			if camera.is_position_behind(sample):
				# A behind-camera sample on the ring means the circle
				# straddles the camera plane; we just append a sentinel
				# and continue. draw_polyline tolerates this by drawing
				# the visible segments.
				continue
			screen_pts.append(camera.unproject_position(sample))
			any_visible = true
		if any_visible and screen_pts.size() >= 2:
			draw_polyline(screen_pts, _COLOR_CIRCLE, _STROKE_WIDTH, true)


# ============================================================================
# Internals
# ============================================================================

func _resolve_camera() -> Camera3D:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()
