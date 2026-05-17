extends Control
##
## ConstructionProgressOverlay — floating per-building construction progress
## bars rendered as a single Control.
##
## Phase 3 session 3 wave 1C Track 2A (ui-developer). Pairs with the
## `Building.construction_progress_updated(percent_x100)` signal shipped in
## Track 2B at commit 82bf198 and the per-tick emit driven by Track 1's
## UnitState_Constructing state machine.
##
## Purpose: surface each on-screen in-progress building's construction
## progress at a glance. A plain horizontal bar with a "BUILDING N%" label
## above each building under construction; hides on completion. The most
## load-bearing piece of feedback for the new (Phase 3 session 3) construction
## timer — without it the player has no signal that placing a Mazra'eh /
## Ma'dan triggered work in progress.
##
## Architectural pattern: forks the health_bars_overlay.gd pattern (single
## Control on the HUD CanvasLayer, _process polls + projects, _draw paints).
## Reason for the fork (not a per-building child Sprite3D / Viewport): same
## trade-off bundle health_bars_overlay locked in (see its header §lines
## 13-29). One _draw call, one mouse_filter discipline point, no per-instance
## bookkeeping when a Building queue_free()s mid-construction.
##
## State source: rather than connecting/disconnecting the
## `construction_progress_updated` signal per building (which complicates the
## "building freed mid-progress" cleanup story), we cache the most-recent
## percent_x100 keyed by Building instance_id. The cache is pruned each
## frame against the live `&"buildings"` group membership — orphaned entries
## drop out automatically, identical to how health_bars_overlay handles
## freed units.
##
## Hide-on-completion choice (kickoff §5 + Track 1 follow-on at 3fbce2b):
##   We hide on the `construction_finalized(placer_unit_id)` signal — emitted
##   by UnitState_Constructing AFTER `_on_construction_complete` runs (Stage 2,
##   operational arrival). The handler erases the per-building cache entry;
##   `compute_bar_entries` returns nothing for buildings with no cache entry.
##
##   Why not `building.is_complete == true`: under Track 1's two-stage
##   lifecycle (gp-sys's commit 2cedf81), `is_complete` flips at the START
##   of construction (inside `place_at`, Stage 1 / structural placement),
##   NOT at the end. A bar gated on `is_complete` would never show.
##
##   Why not `percent_x100 >= 10000`: per the construction_progress_updated
##   emitter contract (gp-sys's commit, _emit_construction_progress L361-368),
##   the signal is CLAMPED into [0, 9999] for the entire dwell phase to keep
##   "progress" and "completion" as distinct signals. 10000 never fires.
##
##   Defence in depth: ALSO filter out cache entries with percent_x100 >= 10000
##   in `compute_bar_entries` — covers a hypothetical future emit-path that
##   bypasses the clamp (or a cheat / debug "instant complete" action that
##   writes 10000 to the cache directly through a test seam). This belt-and-
##   braces gate costs nothing and preserves the original kickoff §5
##   "belt-and-braces" intent under the new lifecycle.
##
## CRITICAL: mouse_filter == MOUSE_FILTER_IGNORE — Pitfall #1, the canonical
## session-1 regression. A fullscreen Control with the default STOP would
## silently eat every click in the viewport AND break the box-select drag
## hit-test. Set in BOTH the .tscn AND defensively at runtime in `_ready`
## (belt-and-braces against editor accidents).
##
## Sim Contract §1.5 fit:
##   `_process` is the polling driver — UI off-tick reads of sim state are
##   sanctioned. We read `building.global_position`, write nothing on the
##   sim side. The cache update / erase happens in our signal handlers
##   (`_on_construction_progress_updated`, `_on_construction_finalized`)
##   which are invoked from inside the emitter's _sim_tick frame — receiving
##   a signal during a sim tick and writing to a private UI cache is
##   sanctioned (the signals are read-shaped from our consumer's POV; we
##   never re-emit anything write-shaped).
##
## Sources:
##   - 01_CORE_MECHANICS.md §5 (building roster) + §11 (UI requirements).
##   - building.gd: construction_progress_updated + construction_finalized
##     signal declarations and emitter contracts.
##   - unit_state_constructing.gd: emit sites (per-tick progress + post-Stage-2
##     finalize). Emit ORDERING is load-bearing — Stage 2 virtual fires first,
##     then construction_finalized emits, so consumers see post-Stage-2 state.
##   - health_bars_overlay.gd: forked pattern.
##   - CLAUDE.md "translation table from day one" + placeholder visual rule.

# ============================================================================
# Tunables
# ============================================================================

# Bar dimensions (px). 64 wide reads cleanly above a 2m-square Khaneh
# footprint at default zoom — wider than the 32/48 health bar set because
# buildings occupy more screen real estate than units. Tunable by lead live-
# test feedback without breaking tests (which key off the signal payload,
# not the rendered geometry).
const _BAR_WIDTH: float = 64.0
const _BAR_HEIGHT: float = 6.0
const _BAR_BG_PADDING: float = 1.0

# Vertical offset above the projected building position. 36 px sits above
# a Building's 1.2-tall placeholder mesh at default isometric distance
# without clipping into other buildings in a tight build cluster.
const _BAR_HEIGHT_OFFSET: float = 36.0

# Label offset above the bar — the "BUILDING N%" text floats above the
# coloured fill rect.
const _LABEL_HEIGHT_OFFSET: float = 18.0

# Basis-points convention (per project convention; matches Building signal).
const _PERCENT_X100_MAX: int = 10000

# Colours. Construction bar uses a single brand colour — yellow / amber, the
# "work in progress" semantic. Distinct from the green/yellow/red HP bar
# palette so the player parses bar-kind by colour at a glance.
const _COLOR_FILL: Color = Color(0.95, 0.75, 0.20)
const _COLOR_BG: Color = Color(0.10, 0.10, 0.10, 0.85)
const _COLOR_LABEL: Color = Color(1.0, 1.0, 1.0, 1.0)
const _COLOR_LABEL_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.85)

# Translation key for the floating label (CLAUDE.md "translation table from
# day one" rule). The English form is "BUILDING %d%%"; Persian column blank
# until Tier 2. Format-substituted via tr() % [percent].
const _LABEL_KEY: StringName = &"UI_BUILDING_CONSTRUCTION_PROGRESS"


# ============================================================================
# State
# ============================================================================

# Cache of the most-recent percent_x100 per building, keyed by
# Building.get_instance_id() (an int — stable across the lifetime of the
# Object, and never reused after free, per Godot 4 docs). We key on
# instance_id rather than the Object reference itself because Dictionary
# keys can persist past a Node free() while is_instance_valid would still
# refuse — using instance_id gives us a clean "lookup-by-stable-handle"
# story without holding strong references that would prevent cleanup.
var _percent_cache: Dictionary = {}

# Set of building instance_ids whose signal we've already connected to.
# Connecting a Godot signal a second time raises a warning + double-fires;
# this dedupe is critical because _process discovers buildings every frame
# and would otherwise reconnect on every pass.
var _connected: Dictionary = {}

# The most-recent entry list compute_bar_entries produced. Cached per frame
# so _draw can paint without re-walking the building set. Tests read this
# back via the public seam.
var _entries: Array = []


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Pitfall #1 belt-and-braces: even if the .tscn says STOP (or someone
	# accidentally edits it later), force IGNORE here. The overlay never
	# absorbs clicks. The box-select drag test below catches this regression
	# behaviorally if the discipline ever slips.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor full-screen so projected screen coordinates land in our local
	# Control space.
	anchor_right = 1.0
	anchor_bottom = 1.0


# Off-tick poll. Per Sim Contract §1.5, UI reads of sim state from `_process`
# are sanctioned. We do not mutate sim state, do not emit write-shaped
# signals, and do not call apply_* / *_tick( / *State.update() (lint L1, L2
# compliance).
#
# Per frame we (a) gather all buildings via the &"buildings" SceneTree group,
# (b) lazily connect to their construction_progress_updated signal once each,
# (c) project to screen via the live Camera3D, (d) filter the cache against
# live buildings (drop stale entries for queue_freed buildings), (e) compute
# entry list and queue_redraw.
func _process(_dt: float) -> void:
	var camera: Camera3D = _resolve_camera()
	if camera == null:
		# No camera resolvable yet (scene boot order). Clear entries so the
		# screen stays blank — preferable to drawing at stale projections.
		if not _entries.is_empty():
			_entries = []
			queue_redraw()
		return
	var viewport_size: Vector2 = Vector2.ZERO
	var vp: Viewport = get_viewport()
	if vp != null:
		viewport_size = vp.get_visible_rect().size
	var buildings: Array = _gather_buildings()
	# Lazy signal connect — newly-placed buildings get their signal hooked
	# the first frame they appear in the group.
	for b in buildings:
		_ensure_signal_connected(b)
	# Prune cache against the live set.
	_prune_stale_cache(buildings)
	# Project + compute entries.
	var projector: Callable = func(b: Object) -> Dictionary:
		return _project_building(b, camera, viewport_size)
	_entries = compute_bar_entries(buildings, _percent_cache, projector)
	queue_redraw()


# ============================================================================
# Public seam — pure function, testable without a Camera3D
# ============================================================================

## Compute the entry list for a given set of buildings + percent cache +
## projector Callable. The production path passes a closure over the live
## Camera3D; tests inject a closure that reads per-building test metadata.
##
## Returns an Array of Dictionaries:
##   {
##     building_id: int,           (instance_id, stable per-lifetime)
##     screen_pos: Vector2,
##     percent_x100: int,          (basis points 0..10000)
##     percent: int,               (display percent 0..100, floored)
##   }
##
## Skipped buildings (never appear in the entry list):
##   - null / freed Object
##   - percent_x100 cache missing (no progress signal received yet — e.g.,
##     a building placed instantly without a construction phase, OR a
##     building whose construction_finalized handler has erased the entry).
##     Cache absence IS the hide-on-completion signal under Track 1's
##     two-stage lifecycle — see header `Hide-on-completion choice`.
##   - percent_x100 >= 10000 (defence-in-depth — the per-tick emit clamps
##     into [0, 9999] per the construction_progress_updated contract; this
##     gate covers a hypothetical bypass path or a test-seam injection).
##   - off_screen (per the projector)
##
## Intentionally NOT named `apply_*` — lint rule L1 forbids `apply_*` in any
## file with `_process`.
##
## Note: `building.is_complete` is INTENTIONALLY not consulted. Under Track 1's
## two-stage lifecycle (gp-sys's commit 2cedf81 + 3fbce2b), is_complete flips
## at the START of construction (Stage 1, structural placement), not the end.
## A gate on is_complete would hide every bar immediately. The
## construction_finalized signal handler is the correct hide-trigger.
func compute_bar_entries(
		buildings: Array,
		percent_cache: Dictionary,
		project_building: Callable
) -> Array:
	var out: Array = []
	for b in buildings:
		if b == null or not is_instance_valid(b):
			continue
		var bid: int = b.get_instance_id()
		# Skip buildings we have no progress signal for yet — a freshly-
		# instantiated building before its first tick has no cache entry.
		# After construction_finalized fires, the entry is erased — same
		# "no cache entry" path. Better to render nothing than render 0%
		# (which would imply the timer is stuck).
		if not percent_cache.has(bid):
			continue
		var percent_x100_v: Variant = percent_cache[bid]
		if typeof(percent_x100_v) != TYPE_INT:
			continue
		var percent_x100: int = int(percent_x100_v)
		if percent_x100 < 0:
			continue
		if percent_x100 >= _PERCENT_X100_MAX:
			continue  # belt-and-braces against an unclamped emit path
		# Projection + on-screen filter.
		var entry: Dictionary = project_building.call(b) as Dictionary
		var on_screen: bool = bool(entry.get(&"on_screen", false))
		if not on_screen:
			continue
		var screen_pos: Vector2 = entry.get(&"screen_pos", Vector2.ZERO) as Vector2
		var percent_display: int = clampi(percent_x100 / 100, 0, 100)
		out.append({
			&"building_id": bid,
			&"screen_pos": screen_pos,
			&"percent_x100": percent_x100,
			&"percent": percent_display,
		})
	return out


## Public test seam — simulate receiving a signal emit. Production code
## connects to `Building.construction_progress_updated` and routes through
## `_on_construction_progress_updated`; tests feed the cache directly via
## this seam without needing to register Building signals.
func ingest_progress(building: Object, percent_x100: int) -> void:
	if building == null or not is_instance_valid(building):
		return
	_percent_cache[building.get_instance_id()] = percent_x100


## Public test seam — read back the cache for assertion.
func get_cached_percent_x100(building: Object) -> int:
	if building == null or not is_instance_valid(building):
		return -1
	var bid: int = building.get_instance_id()
	if not _percent_cache.has(bid):
		return -1
	return int(_percent_cache[bid])


# ============================================================================
# Signal sinks — invoked from inside the emitter's _sim_tick frame
# ============================================================================

# Per-building signal binding closes over the building ref so the sink knows
# which cache entry to update. The `bind` form is the idiomatic Godot 4
# pattern for "I need to know which emitter fired".
func _on_construction_progress_updated(percent_x100: int, building: Object) -> void:
	if building == null or not is_instance_valid(building):
		return
	_percent_cache[building.get_instance_id()] = percent_x100


# Stage 2 (operational arrival) sink — erases the cache entry so the bar
# hides. Per the construction_finalized emitter contract (gp-sys's commit
# 3fbce2b in unit_state_constructing.gd line ~351-360), this fires AFTER
# `_on_construction_complete` runs on the building, so any subclass
# state mutation (Mazra'eh.is_gatherable, Ma'dan modifier registration)
# is visible by the time we get here. We only care about the cache
# erasure; the placer_unit_id arg is forwarded by the bound emitter and
# accepted for signature compatibility.
#
# We do NOT drop `_connected[bid]` here — the building is still alive after
# Stage 2 and the signal connections still exist. Dropping the dedupe entry
# would cause `_ensure_signal_connected` to retry the connect on every
# subsequent frame, which Godot logs as an ERROR each time
# (live-test fix-up: was spamming the log post-completion). `_connected[bid]`
# is correctly dropped by `_prune_stale_cache` when the building queue_frees.
func _on_construction_finalized(_placer_unit_id: int, building: Object) -> void:
	if building == null or not is_instance_valid(building):
		return
	_percent_cache.erase(building.get_instance_id())


# ============================================================================
# Drawing
# ============================================================================

func _draw() -> void:
	var default_font: Font = ThemeDB.fallback_font
	var default_font_size: int = ThemeDB.fallback_font_size
	for entry in _entries:
		var screen_pos: Vector2 = entry.get(&"screen_pos", Vector2.ZERO) as Vector2
		var percent_x100: int = int(entry.get(&"percent_x100", 0))
		var percent: int = int(entry.get(&"percent", 0))
		# Position: centered horizontally on the building, above by
		# _BAR_HEIGHT_OFFSET.
		var bar_x: float = screen_pos.x - _BAR_WIDTH * 0.5
		var bar_y: float = screen_pos.y - _BAR_HEIGHT_OFFSET
		# Background rect (full width).
		var bg_rect: Rect2 = Rect2(
				bar_x - _BAR_BG_PADDING,
				bar_y - _BAR_BG_PADDING,
				_BAR_WIDTH + 2.0 * _BAR_BG_PADDING,
				_BAR_HEIGHT + 2.0 * _BAR_BG_PADDING)
		draw_rect(bg_rect, _COLOR_BG, true)
		# Fill rect (proportional width based on percent_x100).
		var fill_ratio: float = clampf(
				float(percent_x100) / float(_PERCENT_X100_MAX), 0.0, 1.0)
		var fill_w: float = _BAR_WIDTH * fill_ratio
		if fill_w > 0.0:
			var fill_rect: Rect2 = Rect2(bar_x, bar_y, fill_w, _BAR_HEIGHT)
			draw_rect(fill_rect, _COLOR_FILL, true)
		# Floating label "BUILDING N%" above the bar. Translation key per
		# CLAUDE.md "translation table from day one" rule — never hardcode
		# the English form.
		if default_font != null:
			var label_template: String = tr(_LABEL_KEY)
			var label: String = label_template % percent
			var label_y: float = bar_y - _LABEL_HEIGHT_OFFSET
			# Center the label horizontally on the building.
			var text_size: Vector2 = default_font.get_string_size(
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					default_font_size)
			var label_x: float = screen_pos.x - text_size.x * 0.5
			# Outline draw (1px in each cardinal + diagonal direction) then
			# fill — keeps the label readable against light / dark terrain.
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					draw_string(
							default_font,
							Vector2(label_x + float(dx), label_y + float(dy)),
							label,
							HORIZONTAL_ALIGNMENT_LEFT,
							-1.0,
							default_font_size,
							_COLOR_LABEL_OUTLINE)
			draw_string(
					default_font,
					Vector2(label_x, label_y),
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					default_font_size,
					_COLOR_LABEL)


# ============================================================================
# Internals
# ============================================================================

# Connect to a building's construction_progress_updated AND
# construction_finalized signals if not yet connected. The bind(building)
# closures carry the building ref into the sinks so each knows which cache
# entry to update / erase.
#
# Both signals are connected as a pair — a building emitting progress
# without ever emitting finalize is the in-progress path; finalize is the
# completion-erase path. The dedupe flag in `_connected` covers both: we
# either connected both or neither.
func _ensure_signal_connected(building: Object) -> void:
	if building == null or not is_instance_valid(building):
		return
	var bid: int = building.get_instance_id()
	if _connected.has(bid):
		return
	# Defensive — Building.gd declares both signals in the base, but if the
	# building under inspection is a duck-typed test fixture it may not
	# have them.
	if not building.has_signal(&"construction_progress_updated"):
		return
	if not building.has_signal(&"construction_finalized"):
		return
	var progress_sink: Callable = Callable(
			self, &"_on_construction_progress_updated").bind(building)
	var finalize_sink: Callable = Callable(
			self, &"_on_construction_finalized").bind(building)
	# Belt-and-braces — Godot 4 logs an ERROR if you `connect` an
	# already-connected callable, even though the semantics are no-op.
	# The `_connected[bid]` dict above is the primary dedupe; this
	# `is_connected` guard is defensive against any path that bypasses
	# the dict (e.g., a future caller invoking _ensure_signal_connected
	# after a manual _connected.erase).
	var err_progress: int = OK
	if not building.is_connected(&"construction_progress_updated", progress_sink):
		err_progress = building.connect(
				&"construction_progress_updated", progress_sink)
	var err_finalize: int = OK
	if not building.is_connected(&"construction_finalized", finalize_sink):
		err_finalize = building.connect(
				&"construction_finalized", finalize_sink)
	# Mark connected only if BOTH succeeded (or were already connected
	# via the is_connected short-circuit, which yields err = OK). Partial
	# connections would leave the bar visible forever (progress connected,
	# finalize missing).
	if err_progress == OK and err_finalize == OK:
		_connected[bid] = true


# Remove cache entries for buildings that are no longer in the live group
# (queue_freed, scene-changed, etc.). Without this, the cache would grow
# unbounded over a long match.
func _prune_stale_cache(live_buildings: Array) -> void:
	if _percent_cache.is_empty() and _connected.is_empty():
		return
	var live_ids: Dictionary = {}
	for b in live_buildings:
		if b != null and is_instance_valid(b):
			live_ids[b.get_instance_id()] = true
	# Walk a copy of the keys — Dictionary.erase during iteration is allowed
	# in Godot 4 GDScript but using a copied keys array is the conservative
	# pattern, matches resource_system.gd's prune walkers.
	var cache_keys: Array = _percent_cache.keys()
	for k in cache_keys:
		if not live_ids.has(k):
			_percent_cache.erase(k)
	var conn_keys: Array = _connected.keys()
	for k in conn_keys:
		if not live_ids.has(k):
			_connected.erase(k)


# Gather all live buildings via the &"buildings" SceneTree group (every
# Building joins this group on _ready — see building.gd line 171).
func _gather_buildings() -> Array:
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(&"buildings")


# Resolve the live Camera3D off the viewport. Same lookup pattern used by
# health_bars_overlay.gd, box_select_handler.gd. Returns null during early
# scene boot before the camera rig has _ready'd.
func _resolve_camera() -> Camera3D:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()


# Project a single building's world position to screen via the live Camera3D.
# Returns the dict shape compute_bar_entries expects.
func _project_building(building: Object, camera: Camera3D, viewport_size: Vector2) -> Dictionary:
	if not is_instance_valid(building):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var b3d: Node3D = building as Node3D
	if b3d == null:
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var world_pos: Vector3 = b3d.global_position
	if camera.is_position_behind(world_pos):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var screen: Vector2 = camera.unproject_position(world_pos)
	var on_screen: bool = true
	if viewport_size != Vector2.ZERO:
		# 1px tolerance on each edge (matches health_bars_overlay's filter).
		if screen.x < -1.0 or screen.y < -1.0 \
				or screen.x > viewport_size.x + 1.0 \
				or screen.y > viewport_size.y + 1.0:
			on_screen = false
	return { &"screen_pos": screen, &"on_screen": on_screen }
