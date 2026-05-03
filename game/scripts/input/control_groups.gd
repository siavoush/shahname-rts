extends Node
##
## ControlGroups — Ctrl+1..9 binds, 1..9 recalls, double-tap centers camera.
##
## Phase 1 session 2 wave 2A (ui-developer). Per docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (2).
##
## Responsibilities:
##   - Ctrl+N (N ∈ 1..9): snapshot the current SelectionManager set into
##     internal group N. Subsequent presses of Ctrl+N replace prior contents.
##   - N alone: replace the current selection with the contents of group N
##     (filtering freed units).
##   - N twice within ≤ DOUBLE_TAP_TICKS sim ticks: center the camera on the
##     group's centroid (mean XZ position of live members).
##
## Why an autoload (and not a Node in main.tscn):
##   Control groups are gameplay-session state — they outlive any individual
##   scene transition (UI overlay, pause menu, debug panel) and need a single
##   global instance accessible to any future hotkey rebinder, replay player,
##   or panel UI. Mirrors the SelectionManager pattern. Ordered AFTER
##   SelectionManager in `[autoload]` so this autoload's _ready can rely on
##   SelectionManager.selected_units returning live data.
##
## Sim Contract §1.5 fit:
##   _unhandled_input runs off-tick. We read SelectionManager.selected_units
##   (off-tick read, fine), call SelectionManager.deselect_all / select / etc.
##   (UI mutations through a read-shaped seam — the EventBus.selection_changed
##   broadcast is L2-allowlisted), and call CameraController.center_on
##   (camera-side state, not gameplay state). No on-tick reads or writes to
##   gameplay-state-protected fields happen here.
##
## Determinism:
##   Double-tap timing reads SimClock.tick — NOT wall-clock. Per L5 lint rule
##   ("no Time.get_*_msec / get_unix_time in gameplay code") and the project's
##   replay-determinism guarantee. 350ms ≈ 10.5 ticks at 30Hz; we round to
##   DOUBLE_TAP_TICKS = 10. Adjustable knob.
##
## Live-game-broken-surface (kickoff §2 (2)):
##
##   1. State that must work at runtime that no unit test exercises:
##      - The autoload must be registered in project.godot's [autoload] section
##        AFTER SelectionManager (parse-time ordering — at this autoload's
##        _ready, SelectionManager must already be parsed).
##      - InputEventKey.ctrl_pressed reads the platform's modifier-state at
##        event-emission time. Headless tests construct events directly; live
##        OS auto-repeat may double-fire keys (which we do NOT want for bind —
##        we treat repeats as no-ops via `event.echo`).
##      - CameraController.center_on must be a real method on the live camera
##        rig under main.tscn. The kickoff explicitly authorizes adding it as
##        a single-line public method if missing.
##
##   2. What can a headless test not detect that the lead would notice:
##      - Double-tap timing FEEL — DOUBLE_TAP_TICKS=10 (~333ms at 30Hz) is the
##        kickoff's 350ms guess minus rounding. Lead may want 7 or 13.
##      - Whether the camera centering is a snap or a smooth tween (we snap;
##        animated centering can be added later via the camera_controller).
##      - Whether `Ctrl+1+2` fires ambiguously when the player is sloppy
##        (each key is dispatched separately by the engine; we bind on Ctrl+1
##        press and again on Ctrl+2 press — both get bound).
##      - OS-level keyboard-repeat — covered by event.echo filter.
##
##   3. Minimum interactive smoke test:
##      - Lead boxes 3 kargars, hits Ctrl+1, deselects, hits 1: same 3 selected.
##      - Lead hits 1 again within ~350ms: camera centers on them.
##      - Lead binds a different selection to Ctrl+2; toggles 1 ↔ 2 — both work.

# ============================================================================
# Configuration
# ============================================================================

## Sim ticks within which two recalls of the same key are treated as a
## double-tap (camera centering). 30Hz × 0.333s ≈ 10 ticks. Kickoff's spec
## is "≤350ms" — we land at 333ms via integer rounding for tick-determinism.
const DOUBLE_TAP_TICKS: int = 10

## Verbose logging of every bind/recall/double-tap. On until interactive
## testing confirms reliability; flip off later or gate behind
## DebugOverlayManager.
const DEBUG_LOG_GROUPS: bool = true


# ============================================================================
# Internal state
# ============================================================================

## Per-group membership. Keyed by int 1..9; value is an Array of unit refs
## (untyped to dodge the class_name registry race documented in
## docs/ARCHITECTURE.md §6 v0.4.0). Members are filtered with is_instance_valid
## on every read — same lazy pattern as SelectionManager.
var _groups: Dictionary = {}

## Last keycode used in `recall_with_double_tap`. Used to detect rapid
## repeats on the same key.
var _last_recall_keycode: int = -1

## SimClock.tick at the most-recent recall_with_double_tap. -1 sentinel
## meaning "no prior recall." Compared against current SimClock.tick to
## decide whether the second tap is within DOUBLE_TAP_TICKS.
var _last_recall_tick: int = -1

## Optional injected camera target (RefCounted with `center_on(Vector3)`).
## Tests inject a stub via set_camera_target(). Production resolves the
## real CameraController lazily on first use.
var _camera_target: Object = null

## When true, _unhandled_input is a no-op. Tests flip this on so the
## public seams (bind / recall / handle_key_event) drive the autoload
## without a real Input pump.
var _test_mode: bool = false


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Initialize all 9 group keys to empty arrays. Avoids "key not present"
	# branches in members_of and centroid logic.
	for n in range(1, 10):
		_groups[n] = []


func set_test_mode(on: bool) -> void:
	_test_mode = on


## Inject a camera target (any Object with `center_on(Vector3)`). Tests use
## a stub; production code can override the autoload's lazy-resolved
## CameraController via this seam if a custom camera mode wants the events.
func set_camera_target(target: Object) -> void:
	_camera_target = target


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if event is InputEventKey:
		handle_key_event(event as InputEventKey)


## Public test seam — dispatch a key event. Production code routes through
## _unhandled_input → handle_key_event; tests call this directly with a
## synthesized InputEventKey.
##
## Filters:
##   - Only `pressed` events (not releases).
##   - Only non-echo events (OS-level key repeat is suppressed; otherwise
##     holding `1` would re-recall every frame).
##   - Only digit keycodes 1..9 (KEY_0 is excluded — control groups are 1..9).
func handle_key_event(event: InputEventKey) -> void:
	if not event.pressed:
		return
	if event.echo:
		return
	var n: int = _digit_for_keycode(event.keycode)
	if n < 1 or n > 9:
		return
	# Modifier-key state read off the event itself (per-event read is more
	# reliable than Input.is_key_pressed, which races between event emission
	# and dispatch).
	if event.ctrl_pressed:
		bind(n)
		# Claim the event so other input layers don't also see Ctrl+N.
		var vp: Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return
	# Bare digit: recall (with double-tap detection).
	recall_with_double_tap(n)
	var vp2: Viewport = get_viewport()
	if vp2 != null:
		vp2.set_input_as_handled()


# ============================================================================
# Public API
# ============================================================================

## Snapshot the current SelectionManager.selected_units into group N.
## Replaces (does NOT append to) any prior group contents. Out-of-range
## keys are silently ignored.
func bind(n: int) -> void:
	if n < 1 or n > 9:
		return
	var snapshot: Array = []
	for u in SelectionManager.selected_units:
		if is_instance_valid(u):
			snapshot.append(u)
	_groups[n] = snapshot
	if DEBUG_LOG_GROUPS:
		print("[control-groups] bind ", n, " count=", snapshot.size())


## Recall group N: replace the current selection with the live members of
## group N. No-op if the group is unbound or empty (leaves prior selection
## untouched). Out-of-range keys are silently ignored.
##
## "No-op on empty" is deliberate: an unbound group should not surprise the
## player by clearing their selection. The kickoff's smoke-test sequence
## ("Lead deselects, hits 1, sees the same 3 selected") implies recall is a
## one-way restore, not a "1=clear if unbound" key.
func recall(n: int) -> void:
	if n < 1 or n > 9:
		return
	if not _groups.has(n):
		return
	var live: Array = _live_members(n)
	if live.is_empty():
		return
	# Replace the selection. SelectionManager.select_only takes one unit;
	# rebuild via deselect_all + add_to_selection iteration.
	SelectionManager.deselect_all()
	for u in live:
		SelectionManager.add_to_selection(u)
	if DEBUG_LOG_GROUPS:
		print("[control-groups] recall ", n, " count=", live.size())


## Recall group N AND track double-tap state. The first tap restores the
## selection; the second tap on the same key within DOUBLE_TAP_TICKS sim
## ticks centers the camera on the group's centroid. Different keys reset
## the timer.
##
## This is the production input path; `recall(n)` exists separately for
## tests / programmatic access that don't want the camera side-effect.
func recall_with_double_tap(n: int) -> void:
	if n < 1 or n > 9:
		return
	# Always perform the recall (even on the second tap — re-selects the
	# same group, which is a no-op visually but keeps state coherent).
	recall(n)
	var current_tick: int = int(SimClock.tick)
	var elapsed: int = current_tick - _last_recall_tick
	if (_last_recall_keycode == n
			and _last_recall_tick != -1
			and elapsed <= DOUBLE_TAP_TICKS):
		# Double-tap on same key inside the window → center camera.
		_center_camera_on_group(n)
		# Reset the state so a third tap doesn't auto-double-fire.
		_last_recall_keycode = -1
		_last_recall_tick = -1
		return
	# First tap (or tap on a different key, or stale tap) → arm the timer.
	_last_recall_keycode = n
	_last_recall_tick = current_tick


## Read accessor: live members of group N (filters freed units). Returns a
## fresh shallow copy so callers can iterate safely without observing
## concurrent mutations. Out-of-range keys return an empty array.
func members_of(n: int) -> Array:
	if not _groups.has(n):
		return []
	return _live_members(n)


## Reset to pristine state. Mirrors the SelectionManager.reset / SimClock.reset
## pattern — called by GUT before_each / after_each so tests don't leak group
## bindings across cases.
func reset() -> void:
	_groups.clear()
	for n in range(1, 10):
		_groups[n] = []
	_last_recall_keycode = -1
	_last_recall_tick = -1


# ============================================================================
# Internals
# ============================================================================

## Map a keycode (KEY_0..KEY_9) to its digit (0..9). Returns -1 for
## non-digit keycodes.
func _digit_for_keycode(keycode: int) -> int:
	# Godot's KEY_0..KEY_9 are contiguous integer constants. We index them
	# explicitly to avoid relying on numeric ordering (which is contiguous
	# but stating it explicitly is safer for cross-platform stability).
	match keycode:
		KEY_0: return 0
		KEY_1: return 1
		KEY_2: return 2
		KEY_3: return 3
		KEY_4: return 4
		KEY_5: return 5
		KEY_6: return 6
		KEY_7: return 7
		KEY_8: return 8
		KEY_9: return 9
		_: return -1


## Filter group N's stored refs to only live units. Defensive — units may
## have been queue_freed since the bind without our knowing.
func _live_members(n: int) -> Array:
	var out: Array = []
	if not _groups.has(n):
		return out
	for u in _groups[n]:
		if is_instance_valid(u):
			out.append(u)
	return out


## Compute mean XZ position of group N's live members. Returns Vector3.ZERO
## if the group is empty. Y is preserved as 0 — the camera target_position
## sits on the ground plane.
func _centroid_of_group(n: int) -> Vector3:
	var live: Array = _live_members(n)
	if live.is_empty():
		return Vector3.ZERO
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for u in live:
		if u is Node3D:
			sum += (u as Node3D).global_position
			count += 1
	if count == 0:
		return Vector3.ZERO
	return Vector3(sum.x / float(count), 0.0, sum.z / float(count))


## Drive the camera to the group's centroid via CameraController.center_on.
## Resolves the live camera lazily on first use; production wiring drops the
## CameraRig under main.tscn's `World` so we walk down from current_scene.
func _center_camera_on_group(n: int) -> void:
	var live: Array = _live_members(n)
	if live.is_empty():
		return
	var centroid: Vector3 = _centroid_of_group(n)
	var target: Object = _camera_target
	if target == null:
		target = _resolve_camera_controller()
	if target == null:
		if DEBUG_LOG_GROUPS:
			print("[control-groups] no CameraController resolvable; skip center")
		return
	if target.has_method(&"center_on"):
		target.call(&"center_on", centroid)
		if DEBUG_LOG_GROUPS:
			print("[control-groups] center_on ", centroid, " group=", n)


## Walk the scene tree from current_scene looking for a CameraController.
## Identified by duck-typing: a node that has the `center_on` method AND a
## `target_position` property — the unique CameraController surface.
func _resolve_camera_controller() -> Object:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.current_scene
	if root == null:
		return null
	return _find_camera_controller(root)


func _find_camera_controller(node: Node) -> Object:
	if node == null:
		return null
	if node.has_method(&"center_on") and (&"target_position" in node):
		return node
	for child in node.get_children():
		var found: Object = _find_camera_controller(child)
		if found != null:
			return found
	return null
