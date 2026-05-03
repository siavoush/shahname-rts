extends Node
##
## DoubleClickSelect — observe SelectionManager broadcasts; on rapid
## same-unit re-selection, expand to all visible same-type units on screen.
##
## Phase 1 session 2 wave 2A (ui-developer). Per docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (3).
##
## Detection strategy (kickoff option b — "Coordinate via SelectionManager
## .select_only events"):
##   We subscribe to EventBus.selection_changed. Whenever the payload is
##   exactly one unit (a single-target click), we check whether that same
##   unit was the sole selection on a recent prior emission within
##   DOUBLE_CLICK_TICKS sim ticks. If yes, we treat the second click as a
##   double-click and replace the current selection with every same-type
##   unit visible on screen.
##
## Why option (b) over (a):
##   ClickHandler claims left-press first (via _unhandled_input), and
##   BoxSelectHandler intercepts left-press even earlier in tree order. A
##   sibling-ordered "second-listener" pattern would have to coordinate with
##   the BoxSelectHandler's input-handled claim — fragile. The
##   selection_changed signal is already fired exactly once per logical
##   selection mutation; observing it makes our detector independent of
##   which input layer routed the click.
##
## Sim Contract §1.5 fit:
##   - EventBus.selection_changed is read-shaped; subscribing from a Node
##     attached to main.tscn is allowed (it's just a UI signal handler).
##   - We mutate SelectionManager (deselect_all + add_to_selection) inside
##     the signal handler. This is on a UI signal, not a sim signal —
##     so it's an off-tick UI write, identical pattern to box_select_handler.
##   - We read SimClock.tick (off-tick read, fine).
##   - We do not read or write any gameplay-state-protected fields.
##
## Determinism:
##   The double-click window uses SimClock.tick. 30Hz × 0.300s ≈ 9 ticks;
##   we land at DOUBLE_CLICK_TICKS = 9 (round to nearest int). Wall-clock
##   would violate L5 (no Time.get_*_msec in gameplay code).
##
## Live-game-broken-surface (kickoff §2 (3)):
##
##   1. State that must work at runtime that no unit test exercises:
##      - Camera3D.unproject_position must run on the live camera with the
##        unit's actual global_position. Headless tests inject a projector
##        closure; live mode resolves Camera3D from the viewport.
##      - The selection_changed signal must connect successfully — the
##        autoload (SelectionManager) must already be parsed when this Node
##        attaches in main.tscn (it is — autoload parse-time precedes
##        scene-tree _ready).
##      - Subscribers see exactly one emission per SelectionManager
##        mutation. If a future "select_many" fast-path lands on
##        SelectionManager that emits twice for one logical operation, the
##        double-click detection would false-fire. Mitigated by the
##        "selection size must be 1" gate.
##
##   2. What can a headless test not detect that the lead would notice:
##      - Double-click timing FEEL — DOUBLE_CLICK_TICKS=9 (~300ms) is the
##        kickoff guess. Lead may want 7 or 12.
##      - Whether the visible-on-screen filter actually does the right
##        thing when the player is zoomed in/out. Test mode injects
##        on_screen flags; live mode runs Camera3D.is_position_behind +
##        viewport-rect comparison.
##      - Whether the player's intent was "double-click" vs. "two
##        separate clicks on the same unit, deliberately." UX call.
##
##   3. Minimum interactive smoke test:
##      - Lead double-clicks one kargar with all 5 visible: all 5 selected.
##      - Lead pans so only 2 are on screen, double-clicks one: only those
##        2 selected.
##      - Lead clicks one kargar, waits 1 second, clicks again: single-
##        select both times (window expired).

# ============================================================================
# Configuration
# ============================================================================

## Sim ticks within which two single-target selections of the same unit
## are treated as a double-click. 30Hz × 0.300s ≈ 9 ticks.
const DOUBLE_CLICK_TICKS: int = 9

## Verbose logging. On until interactive testing confirms reliability.
const DEBUG_LOG_DOUBLE_CLICK: bool = true


# ============================================================================
# Internal state
# ============================================================================

## Most-recently-observed sole-selection unit. -1 sentinel meaning "none."
## Compared against the next select_only payload to detect double-click.
var _armed_unit_id: int = -1

## Cached ref to the actual unit (so we can read its unit_type without
## another scene walk). Filtered with is_instance_valid on use.
var _armed_unit_ref: Object = null

## SimClock.tick at the time _armed_unit_id was set. -1 sentinel.
var _armed_tick: int = -1

## When true, _ready does not auto-connect to the signal and the test seam
## (set_candidate_provider, set_projector, select_visible_of_type) drives
## the logic directly. Tests still flip the signal-driven path back on by
## NOT calling set_test_mode(true) — see the second test section.
var _test_mode: bool = false

## Optional injected candidate-provider (RefCounted Callable returning an
## Array of unit refs). Production walks the scene tree on every double-
## click; tests inject a fixed list.
var _candidate_provider: Callable = Callable()

## Optional injected projector (Callable: unit -> Dictionary{screen_pos,
## on_screen}). Mirrors box_select_handler's test seam.
var _projector: Callable = Callable()


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Connect to selection broadcasts. We do this even in test mode so the
	# signal-driven double-click tests work without re-wiring; the
	# `_test_mode` flag is only checked when test code wants to fully
	# isolate the public seam (currently no such test, but the field exists
	# for symmetry with the rest of the input layer).
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


func set_test_mode(on: bool) -> void:
	_test_mode = on


## Inject a candidate-provider — Callable returning an Array of unit refs.
## Production walks the scene tree from current_scene; tests pass a fixture
## list. The projector is the second seam (set_projector).
func set_candidate_provider(provider: Callable) -> void:
	_candidate_provider = provider


## Inject a projector — Callable(unit) -> Dictionary{screen_pos, on_screen}.
## Mirrors box_select_handler's seam.
func set_projector(projector: Callable) -> void:
	_projector = projector


# ============================================================================
# Signal handler — the production detection path
# ============================================================================

func _on_selection_changed(unit_ids: Array) -> void:
	# Only single-target selections arm or fire double-click.
	if unit_ids.size() != 1:
		# A multi-select (or a deselect_all → empty) clears the armed state.
		# Without this, a multi-select-then-single-select would false-fire
		# on a third single-select if it happened to match.
		_disarm()
		return
	var sole_id: int = int(unit_ids[0])
	var current_tick: int = int(SimClock.tick)
	var elapsed: int = current_tick - _armed_tick
	if (sole_id == _armed_unit_id
			and _armed_tick != -1
			and elapsed <= DOUBLE_CLICK_TICKS
			and is_instance_valid(_armed_unit_ref)):
		# Double-click! Expand selection to same-type-on-screen.
		var target: Object = _armed_unit_ref
		_disarm()  # Reset before mutating selection (which re-emits the signal).
		_expand_to_visible_of_type(target)
		return
	# First (or fresh) single-target select: arm the detector.
	_armed_unit_id = sole_id
	_armed_unit_ref = _resolve_unit_by_id(sole_id)
	_armed_tick = current_tick


# ============================================================================
# Public API — test seam + production-callable
# ============================================================================

## Direct entry point for the type-select operation. Used by:
##   - Tests that want to validate the type-filter / on-screen-filter logic
##     without driving signals.
##   - Future hotkeys (e.g., "select-all-on-screen" key) that don't go
##     through the double-click path.
##
## Walks `candidates`, projects each via `project_unit`, filters to those
## with the same unit_type as `target_unit` and on_screen=true, replaces
## the current selection with the result. The target unit is always
## included (even if its projection reports off_screen — defensive against
## a 1-frame projection edge case).
func select_visible_of_type(target_unit: Object, candidates: Array,
		project_unit: Callable) -> void:
	if target_unit == null or not is_instance_valid(target_unit):
		return
	if not (&"unit_type" in target_unit):
		return
	var t_type: StringName = target_unit.get(&"unit_type")
	var hits: Array = [target_unit]
	for u in candidates:
		if u == null or not is_instance_valid(u):
			continue
		if u == target_unit:
			continue
		if not (&"unit_type" in u):
			continue
		if u.get(&"unit_type") != t_type:
			continue
		var entry: Dictionary = project_unit.call(u) as Dictionary
		var on_screen: bool = bool(entry.get(&"on_screen", false))
		if not on_screen:
			continue
		hits.append(u)
	# Replace selection.
	SelectionManager.deselect_all()
	for u in hits:
		if is_instance_valid(u):
			SelectionManager.add_to_selection(u)
	if DEBUG_LOG_DOUBLE_CLICK:
		print("[double-click] select-of-type type=", t_type,
			" hits=", hits.size())


## Reset to pristine state. Mirrors the SelectionManager.reset / etc.
## pattern. Test before_each / after_each call this so armed state doesn't
## leak between cases.
func reset() -> void:
	_disarm()


# ============================================================================
# Internals
# ============================================================================

func _disarm() -> void:
	_armed_unit_id = -1
	_armed_unit_ref = null
	_armed_tick = -1


## Resolve a unit by its unit_id. Walks SelectionManager.selected_units
## first (the most likely source — we just observed its broadcast).
func _resolve_unit_by_id(unit_id: int) -> Object:
	for u in SelectionManager.selected_units:
		if not is_instance_valid(u):
			continue
		var uid_v: Variant = u.get(&"unit_id")
		if uid_v != null and int(uid_v) == unit_id:
			return u
	return null


## Drive the type-select using the production camera + scene-walk path
## (or the injected test-mode seams). Splits the projector / candidate
## resolution from the core logic so unit tests can stub each piece.
func _expand_to_visible_of_type(target_unit: Object) -> void:
	var candidates: Array
	if _candidate_provider.is_valid():
		candidates = _candidate_provider.call() as Array
	else:
		candidates = _gather_candidate_units()
	var projector: Callable
	if _projector.is_valid():
		projector = _projector
	else:
		projector = Callable(self, &"_live_project_unit")
	select_visible_of_type(target_unit, candidates, projector)


## Walk the scene tree from current_scene collecting unit-shaped Iran
## nodes. Same heuristic as box_select_handler.gd's _gather_candidate_units.
func _gather_candidate_units() -> Array:
	var hits: Array = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return hits
	var root: Node = tree.current_scene
	if root == null:
		return hits
	_collect_unit_shaped(root, hits)
	return hits


func _collect_unit_shaped(node: Node, out: Array) -> void:
	if (&"unit_id" in node) and (&"team" in node) and (&"unit_type" in node) and (node is Node3D):
		var team_v: Variant = node.get(&"team")
		if int(team_v) == Constants.TEAM_IRAN:
			out.append(node)
	for child in node.get_children():
		_collect_unit_shaped(child, out)


## Project a single unit using the live Camera3D. Mirrors
## box_select_handler.gd's _project_unit, kept inline to avoid an
## inter-handler dependency.
func _live_project_unit(unit: Object) -> Dictionary:
	if not is_instance_valid(unit):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var unit3d: Node3D = unit as Node3D
	if unit3d == null:
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var vp: Viewport = get_viewport()
	if vp == null:
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var camera: Camera3D = vp.get_camera_3d()
	if camera == null:
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var world_pos: Vector3 = unit3d.global_position
	if camera.is_position_behind(world_pos):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var screen: Vector2 = camera.unproject_position(world_pos)
	var vp_size: Vector2 = vp.get_visible_rect().size
	var on_screen: bool = true
	if vp_size != Vector2.ZERO:
		if screen.x < -1.0 or screen.y < -1.0 or screen.x > vp_size.x + 1.0 or screen.y > vp_size.y + 1.0:
			on_screen = false
	return { &"screen_pos": screen, &"on_screen": on_screen }
