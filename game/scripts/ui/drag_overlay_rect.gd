extends Control
##
## DragOverlayRect — child Control of DragOverlay that custom-draws the
## marquee rectangle.
##
## Phase 1 session 2 wave 1A (ui-developer).
##
## Style choices:
##   - Fill: light gold (Iran palette) at 0.20 alpha for a subtle inside.
##   - Stroke: same gold at 0.85 alpha for the visible border.
##   - 1px outline for a clean look at all zoom levels.
##
## mouse_filter is MOUSE_FILTER_IGNORE — this Control must never swallow
## clicks. See drag_overlay.gd's docstring.

const FILL_COLOR: Color = Color(1.0, 0.85, 0.2, 0.20)
const STROKE_COLOR: Color = Color(1.0, 0.85, 0.2, 0.85)
const STROKE_WIDTH: float = 1.0


# Set by parent's set_drag_rect; read by _draw.
var drag_rect: Rect2 = Rect2()


func _ready() -> void:
	# Belt-and-braces: re-assert mouse_filter at runtime in case the
	# .tscn drifts.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Skip drawing when the rect has no area (the parent CanvasLayer is
	# hidden in that case anyway, but defensively guard).
	if drag_rect.size.x <= 0.0 or drag_rect.size.y <= 0.0:
		return
	# Fill.
	draw_rect(drag_rect, FILL_COLOR, true)
	# Stroke.
	draw_rect(drag_rect, STROKE_COLOR, false, STROKE_WIDTH)
