extends Control
##
## HealthBarsOverlay — floating per-unit HP bars rendered as a single Control.
##
## Phase 2 session 1 wave 2C (ui-developer). Per 02d_PHASE_2_KICKOFF.md §2
## deliverable 8.
##
## Purpose: surface each on-screen damaged unit's HP at a glance — green when
## healthy, yellow when wounded, red when near death. The most-load-bearing
## piece of combat-feel feedback in the MVP HUD.
##
## Implementation choice (kickoff option b — single overlay vs. per-unit
## Sprite3D-Viewport):
##   We use ONE Control overlaid on the HUD CanvasLayer. Each frame, _process
##   gathers every Iran/Turan unit, projects its world position to screen via
##   the live Camera3D, and queue_redraw — _draw paints horizontal bars at the
##   projected positions.
##
##   Trade-offs vs. per-unit Sprite3D + Viewport:
##     + One _draw call per frame instead of N. At 50+ units the per-unit
##       Viewport approach allocates one sub-viewport per unit (Godot 4
##       guidance: heavy at scale).
##     + No per-unit lifecycle bookkeeping — units freed mid-frame just don't
##       contribute to the next entry list. No orphan Sprite3Ds to clean up.
##     − One _draw means the entire overlay redraws when ANY unit's HP
##       changes. At session-1's 15-unit cap this is invisible; well below
##       the bottleneck threshold.
##     − Bar position is screen-space, not world-space — stays correct under
##       camera moves because we re-project every frame.
##
## CRITICAL: mouse_filter == MOUSE_FILTER_IGNORE — Pitfall #1, the canonical
## session-1 regression. A fullscreen Control with the default STOP would
## silently eat every click in the viewport. Set in BOTH the .tscn AND
## defensively at runtime in `_ready` (belt-and-braces against editor
## accidents).
##
## Sim Contract §1.5 fit:
##   `_process` is the polling driver — the kickoff explicitly authorizes UI
##   off-tick reads of sim state (HealthComponent.hp_x100, Unit.unit_type,
##   global_position). No sim-state mutation. No EventBus.*.emit (write-shaped
##   signals forbidden in _process by lint L2). No `apply_*`, `*_tick(`, or
##   `*State.update()` calls (lint L1).
##
## Color thresholds (kickoff §2 deliverable 8):
##   HP > 70%        → green
##   30% ≤ HP ≤ 70%  → yellow
##   HP < 30%        → red
## Boundary policy (mirrors farr_gauge color-band convention): inclusive at the
## yellow band's bounds — exactly 70% is yellow, exactly 30% is yellow. Avoids
## flicker at boundary HP values during combat.
##
## Width by unit-size class (kickoff):
##   kargar (small)        → 32 px
##   piyade / turan_piyade → 48 px (medium)
## Unknown unit_type falls back to medium.
##
## Live-game-broken-surface answers (Experiment 01):
##
##   1. *State that must work at runtime that no unit test exercises:*
##      - The Camera3D unproject_position projection. Tests inject a closure;
##        the production path resolves the camera via
##        `get_viewport().get_camera_3d()` each frame. If the camera rig
##        re-parents (e.g., a future cinematic), that lookup must keep working.
##      - is_position_behind: a unit BEHIND the camera (rare at top-down, but
##        possible during free camera) projects to garbage screen coordinates.
##        Filter via `Camera3D.is_position_behind` BEFORE unproject_position.
##      - Per-frame cost at 50+ units. Headless test runs are O(N) over a tiny
##        Array; live with hundreds of units would warrant an early-out by
##        spatial query, but at session-1 scale (10 units) the linear walk is
##        invisible.
##
##   2. *What can a headless test not detect:*
##      - Bar width readability at default zoom. 32 px / 48 px were chosen to
##        be visible without overpowering the unit silhouette — lead's call.
##      - Vertical offset above the unit's mesh top — `_BAR_HEIGHT_OFFSET = 30`
##        was tuned for a Piyade cube ~1.0 tall at default isometric distance;
##        cavalry / heroes (Phase 5) may need a per-unit-type offset.
##      - Color-band feel: green→yellow→red gradient is the MVP convention,
##        not necessarily optimal. Lead may want a smoother gradient
##        (interpolated colors) instead of three discrete bands; that would be
##        a 5-line refactor of `_color_for_band` if requested.
##      - Whether the HP bars compete visually with the SelectedUnitPanel
##        (bottom-left) or FarrGauge (top-right) at 1920×1080.
##
##   3. *Minimum interactive smoke test:*
##      - Lead's Piyade attacks a Turan Piyade. Bar fades green → yellow → red
##        as combat proceeds. Bar disappears when target dies.
##      - At full HP (boot), no bars visible — clean default.

# ============================================================================
# Tunables
# ============================================================================

# Color-band thresholds. Lower bounds are INCLUSIVE — exactly 70% → yellow,
# exactly 30% → yellow.
const _GREEN_LOWER_BOUND: float = 0.70
const _YELLOW_LOWER_BOUND: float = 0.30

# Width per unit-size class (kickoff §2 deliverable 8).
const _WIDTH_SMALL: int = 32   # kargar
const _WIDTH_MEDIUM: int = 48  # piyade, turan_piyade, default

# Bar height (px) and vertical offset above the projected unit position.
# 4 px reads cleanly at 1280×720 default zoom; 30 px puts the bar above a
# unit's head silhouette without clipping into other units in formation.
const _BAR_HEIGHT: float = 4.0
const _BAR_HEIGHT_OFFSET: float = 30.0
const _BAR_BG_PADDING: float = 1.0  # outline thickness on each side

# Color-band tags. Tests assert on these StringNames, not RGB triples — the
# implementer can tune the palette without breaking tests. Same convention
# as farr_gauge.gd.
const BAND_GREEN: StringName = &"green"
const BAND_YELLOW: StringName = &"yellow"
const BAND_RED: StringName = &"red"

# Concrete colors per band. Tunable by lead live-test feedback without
# breaking tests (which key off the StringName tags).
const _COLOR_GREEN: Color = Color(0.25, 0.85, 0.25)
const _COLOR_YELLOW: Color = Color(0.95, 0.80, 0.20)
const _COLOR_RED: Color = Color(0.90, 0.20, 0.20)
const _COLOR_BG: Color = Color(0.10, 0.10, 0.10, 0.85)


# ============================================================================
# State (read-only from outside)
# ============================================================================

# The most-recent entry list compute_bar_entries produced. Cached per frame
# so _draw can paint without re-walking the unit set. Tests read this back
# via the public seam.
var _entries: Array = []


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Pitfall #1 belt-and-braces: even if the .tscn says STOP (or someone
	# accidentally edits it later), force IGNORE here. The overlay never
	# absorbs clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor full-screen so projected screen coordinates land in our local
	# Control space. (The .tscn does this too; setting here defensively
	# covers test instances spawned via .new() without a scene wrapper.)
	anchor_right = 1.0
	anchor_bottom = 1.0


# Off-tick poll — the kickoff authorizes UI reads of sim state from `_process`
# per Sim Contract §1.5. We do not mutate any SimNode state, do not emit any
# write-shaped signal, and do not call `apply_*` / `*_tick(` / `*State.update()`
# (lint L1, L2 compliance).
#
# Per frame we (a) gather all Iran/Turan units in the scene, (b) project to
# screen via the live Camera3D, (c) compute color-band tag and width per unit,
# (d) queue_redraw so `_draw` paints the entries.
func _process(_dt: float) -> void:
	var camera: Camera3D = _resolve_camera()
	if camera == null:
		# No camera resolvable yet (e.g., during scene boot before the
		# camera rig's _ready runs). Clear entries so the screen stays
		# blank — preferable to drawing at stale projected positions.
		if not _entries.is_empty():
			_entries = []
			queue_redraw()
		return
	var viewport_size: Vector2 = Vector2.ZERO
	var vp: Viewport = get_viewport()
	if vp != null:
		viewport_size = vp.get_visible_rect().size
	var units: Array = _gather_candidate_units()
	var projector: Callable = func(u: Object) -> Dictionary:
		return _project_unit(u, camera, viewport_size)
	_entries = compute_bar_entries(units, projector)
	queue_redraw()


# ============================================================================
# Public seam — pure function, testable without a Camera3D
# ============================================================================

## Compute the entry list for a given set of units, given a projector
## Callable that returns `{ screen_pos: Vector2, on_screen: bool }` for each
## unit. The production path passes a closure over the live Camera3D; tests
## inject a closure that reads test metadata.
##
## Returns an Array of Dictionaries:
##   {
##     unit_id: int,
##     unit_type: StringName,
##     screen_pos: Vector2,
##     hp_ratio: float,            (current_hp / max_hp, clamped [0, 1])
##     band: StringName,           (BAND_GREEN / BAND_YELLOW / BAND_RED)
##     width: int,                 (px, by unit-size class)
##   }
##
## Skipped units (never appear in the entry list):
##   - null / freed Object
##   - missing get_health() method
##   - max_hp_x100 == 0 (uninitialized component)
##   - hp_x100 >= max_hp_x100 (full HP — clean visual default)
##   - off_screen (per the projector)
##
## Intentionally NOT named `apply_*` — lint rule L1 forbids `apply_*` in any
## file with `_process`.
func compute_bar_entries(units: Array, project_unit: Callable) -> Array:
	var out: Array = []
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		# Health read — duck-typed via has_method to keep the overlay
		# independent of the HealthComponent class_name registry race.
		if not u.has_method(&"get_health"):
			continue
		var hc: Object = u.call(&"get_health")
		if hc == null or not is_instance_valid(hc):
			continue
		var hp_x100_v: Variant = hc.get(&"hp_x100")
		var max_x100_v: Variant = hc.get(&"max_hp_x100")
		if typeof(hp_x100_v) != TYPE_INT or typeof(max_x100_v) != TYPE_INT:
			continue
		var hp_x100: int = int(hp_x100_v)
		var max_x100: int = int(max_x100_v)
		if max_x100 <= 0:
			continue  # uninitialized component → skip rather than divide
		if hp_x100 >= max_x100:
			continue  # full HP → clean visual default
		var ratio: float = clampf(float(hp_x100) / float(max_x100), 0.0, 1.0)
		# Projection + on-screen filter.
		var entry: Dictionary = project_unit.call(u) as Dictionary
		var on_screen: bool = bool(entry.get(&"on_screen", false))
		if not on_screen:
			continue
		var screen_pos: Vector2 = entry.get(&"screen_pos", Vector2.ZERO) as Vector2
		# Unit-type-driven width.
		var unit_type: StringName = &""
		var ut_v: Variant = u.get(&"unit_type")
		if typeof(ut_v) == TYPE_STRING_NAME or typeof(ut_v) == TYPE_STRING:
			unit_type = StringName(ut_v)
		var unit_id: int = -1
		var uid_v: Variant = u.get(&"unit_id")
		if typeof(uid_v) == TYPE_INT:
			unit_id = int(uid_v)
		out.append({
			&"unit_id": unit_id,
			&"unit_type": unit_type,
			&"screen_pos": screen_pos,
			&"hp_ratio": ratio,
			&"band": _band_for_ratio(ratio),
			&"width": _width_for_unit_type(unit_type),
		})
	return out


# ============================================================================
# Drawing
# ============================================================================

func _draw() -> void:
	for entry in _entries:
		var screen_pos: Vector2 = entry.get(&"screen_pos", Vector2.ZERO) as Vector2
		var width: int = int(entry.get(&"width", _WIDTH_MEDIUM))
		var ratio: float = float(entry.get(&"hp_ratio", 0.0))
		var band: StringName = entry.get(&"band", BAND_GREEN) as StringName
		# Position: centered horizontally on the unit, above by _BAR_HEIGHT_OFFSET.
		var bar_x: float = screen_pos.x - float(width) * 0.5
		var bar_y: float = screen_pos.y - _BAR_HEIGHT_OFFSET
		# Background rect (full width).
		var bg_rect: Rect2 = Rect2(
				bar_x - _BAR_BG_PADDING,
				bar_y - _BAR_BG_PADDING,
				float(width) + 2.0 * _BAR_BG_PADDING,
				_BAR_HEIGHT + 2.0 * _BAR_BG_PADDING)
		draw_rect(bg_rect, _COLOR_BG, true)
		# Fill rect (proportional width).
		var fill_w: float = float(width) * ratio
		if fill_w > 0.0:
			var fill_rect: Rect2 = Rect2(bar_x, bar_y, fill_w, _BAR_HEIGHT)
			draw_rect(fill_rect, _color_for_band(band), true)


# ============================================================================
# Internals
# ============================================================================

# Map an HP ratio to its color-band tag. Boundary policy: inclusive at the
# yellow band's bounds — exactly 0.70 is yellow, exactly 0.30 is yellow.
func _band_for_ratio(ratio: float) -> StringName:
	if ratio > _GREEN_LOWER_BOUND:
		return BAND_GREEN
	if ratio >= _YELLOW_LOWER_BOUND:
		return BAND_YELLOW
	return BAND_RED


func _color_for_band(band: StringName) -> Color:
	match band:
		BAND_GREEN:
			return _COLOR_GREEN
		BAND_YELLOW:
			return _COLOR_YELLOW
		BAND_RED:
			return _COLOR_RED
		_:
			return _COLOR_GREEN


func _width_for_unit_type(unit_type: StringName) -> int:
	match unit_type:
		&"kargar":
			return _WIDTH_SMALL
		&"piyade", &"turan_piyade":
			return _WIDTH_MEDIUM
		_:
			return _WIDTH_MEDIUM  # safe default


# Resolve the live Camera3D off the viewport. Same lookup pattern used by
# box_select_handler.gd, double_click_select.gd. Returns null during early
# scene boot before the camera rig has _ready'd.
func _resolve_camera() -> Camera3D:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()


# Walk the scene tree from the current scene root looking for unit-shaped
# Node3Ds (have unit_id + team + Node3D). The team filter is intentionally
# permissive: BOTH Iran AND Turan units get bars (a Turan Piyade taking
# damage from your Piyade should also show its HP draining — that's the
# combat-feel signal).
#
# At session-1 scale (~15 units) the linear walk is invisible. A spatial
# query would be a Phase 4 perf optimization once unit count grows past
# the bottleneck threshold (LATER).
func _gather_candidate_units() -> Array:
	var hits: Array = []
	var root: Node = null
	if get_tree() != null:
		root = get_tree().current_scene
	if root == null:
		return hits
	_collect_unit_shaped(root, hits)
	return hits


func _collect_unit_shaped(node: Node, out: Array) -> void:
	if (&"unit_id" in node) and (&"team" in node) and (node is Node3D):
		out.append(node)
	for child in node.get_children():
		_collect_unit_shaped(child, out)


# Project a single unit's world position to screen via the live Camera3D.
# Returns the dict shape `compute_bar_entries` expects.
func _project_unit(unit: Object, camera: Camera3D, viewport_size: Vector2) -> Dictionary:
	if not is_instance_valid(unit):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var unit3d: Node3D = unit as Node3D
	if unit3d == null:
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var world_pos: Vector3 = unit3d.global_position
	if camera.is_position_behind(world_pos):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var screen: Vector2 = camera.unproject_position(world_pos)
	var on_screen: bool = true
	if viewport_size != Vector2.ZERO:
		# 1px tolerance on each edge (matches double_click_select's filter).
		if screen.x < -1.0 or screen.y < -1.0 \
				or screen.x > viewport_size.x + 1.0 \
				or screen.y > viewport_size.y + 1.0:
			on_screen = false
	return { &"screen_pos": screen, &"on_screen": on_screen }
