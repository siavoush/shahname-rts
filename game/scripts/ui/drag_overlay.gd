extends CanvasLayer
##
## DragOverlay — translucent rectangle drawn while the player is box-
## selecting.
##
## Phase 1 session 2 wave 1A (ui-developer). Per docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (1).
##
## Why a CanvasLayer with a child Control:
##   The CanvasLayer renders above the 3D viewport, independent of the
##   camera transform. The child Control draws the actual rectangle via
##   _draw() — a custom-drawing pattern is the cheapest way to render a
##   filled+stroked rectangle without an additional StyleBox or NinePatch.
##
## CRITICAL: mouse_filter MUST be MOUSE_FILTER_IGNORE (= 2)
##   Session 1's regression bug: a Control on top of the viewport with the
##   default MOUSE_FILTER_STOP silently swallows mouse events behind it.
##   The drag overlay is decoration only — it must never absorb clicks.
##   Both this CanvasLayer's child (the Rect Control) and any nested
##   Controls have mouse_filter = MOUSE_FILTER_IGNORE configured in the
##   .tscn. _ready double-checks the invariant at runtime.
##
## Sim Contract §1.5 fit:
##   This is a pure UI overlay. _process is not implemented; visibility
##   and rect changes are pushed by box_select_handler.gd via the public
##   set_drag_rect(rect) seam.

# Cached reference to the child Control that does the drawing.
@onready var _rect_node: Control = $Rect


func _ready() -> void:
	# Defensive: re-assert the mouse_filter invariant. If anyone edits
	# the .tscn and accidentally flips it back to MOUSE_FILTER_STOP, this
	# will silently force-correct it at runtime.
	if _rect_node != null:
		_rect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Public API: set the screen-space rectangle to draw. Called by
## BoxSelectHandler every motion event during drag. Triggers a redraw on
## the child via queue_redraw().
func set_drag_rect(rect: Rect2) -> void:
	if _rect_node == null:
		return
	_rect_node.set(&"drag_rect", rect)
	_rect_node.queue_redraw()
