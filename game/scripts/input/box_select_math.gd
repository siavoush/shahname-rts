extends RefCounted
##
## BoxSelectMath — pure math helpers for marquee/box selection.
##
## Phase 1 session 2 wave 1A (ui-developer). Per docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (1).
##
## Why a separate file:
##   The screen-space rectangle math + projected-position filter is the
##   load-bearing logic of box selection, but it has zero engine
##   dependencies once the projection is done. Splitting the math out from
##   the input handler lets unit tests exercise the filter without spinning
##   up a real Camera3D / Viewport / scene tree (which the headless GUT
##   runner can't reliably do for unproject_position).
##
##   The handler (`box_select_handler.gd`) calls `Camera3D.unproject_position`
##   per visible unit, builds the projected-positions list, and hands it to
##   `units_in_rect()`. The handler unit-tests the input-event flow (press /
##   motion / release / dead-zone / Shift modifier); this file's tests
##   exercise every screen-rect axis-direction case, edge-on-rect, etc.
##
## RefCounted, no class_name — same project-wide registry-race avoidance
## as MatchHarness, MockPathScheduler, etc. Callers preload by path.

# ============================================================================
# Public API
# ============================================================================

## Build a normalized Rect2 from two corners. Either corner may be the
## "start" or the "end" of the drag — direction-agnostic.
##
## A Rect2 with negative size in either dimension is technically valid but
## confuses `Rect2.has_point` and `Rect2.intersects`. Always normalize via
## abs-of-size so downstream callers get a well-formed rect regardless of
## which direction the player dragged in (top-left → bottom-right vs.
## bottom-right → top-left vs. either of the cross-diagonals).
static func rect_from_corners(a: Vector2, b: Vector2) -> Rect2:
	var x_min: float = min(a.x, b.x)
	var y_min: float = min(a.y, b.y)
	var x_max: float = max(a.x, b.x)
	var y_max: float = max(a.y, b.y)
	return Rect2(Vector2(x_min, y_min), Vector2(x_max - x_min, y_max - y_min))


## True if the player has dragged far enough to qualify as a box-select
## intent, rather than a click-with-jitter.
##
## `start` and `current` are screen-space positions (pixels). `dead_zone_px`
## is the radius (Manhattan-equivalent for cheapness) below which we treat
## the gesture as "still a click."
##
## Per the live-game-broken-surface analysis: a sub-pixel jitter on press-
## release must not be mistaken for a drag, or single-click selection
## breaks. A 4px dead zone is comfortable for both mouse and trackpad
## without feeling laggy on real drags.
static func is_past_dead_zone(start: Vector2, current: Vector2, dead_zone_px: float) -> bool:
	# Use squared distance to avoid sqrt — micro-optimization that costs
	# nothing in clarity since the dead_zone_px is squared once at the
	# call site.
	var dx: float = current.x - start.x
	var dy: float = current.y - start.y
	return (dx * dx + dy * dy) >= (dead_zone_px * dead_zone_px)


## Filter a list of (unit, projected_screen_pos) pairs to only those whose
## projected position falls inside `rect`.
##
## `projected` is an Array of Dictionaries: each entry has
##   { &"unit": Object, &"screen_pos": Vector2, &"on_screen": bool }.
##
## Entries with on_screen=false (unit is behind the camera or off-viewport
## per the projection helper) are skipped. The handler is responsible for
## populating on_screen correctly — see `box_select_handler.gd`'s
## `_project_unit` for the production implementation.
##
## Returns an Array of unit Objects in the same order they appeared in
## `projected`. Order is stable so callers iterating the result for visual
## feedback (e.g., portrait grid) get a deterministic layout from a
## deterministic input.
static func units_in_rect(rect: Rect2, projected: Array) -> Array:
	var hits: Array = []
	for entry in projected:
		if not (entry is Dictionary):
			continue
		if not entry.get(&"on_screen", true):
			continue
		var pos: Variant = entry.get(&"screen_pos")
		if not (pos is Vector2):
			continue
		var unit: Variant = entry.get(&"unit")
		if unit == null:
			continue
		if rect.has_point(pos):
			hits.append(unit)
	return hits
