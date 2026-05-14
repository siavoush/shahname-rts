# Regression lock — Godot's _unhandled_input dispatch order for siblings.
#
# This test exists because the project initially codified the WRONG
# convention. The AttackMoveHandler precedent header (Phase 2 session 1
# wave 2B) and the BuildPlacementHandler header (Phase 3 session 1 wave
# 1C) both stated:
#
#   "Godot's _unhandled_input dispatch is tree-document order — lower-
#    index sibling runs first."
#
# Empirically (confirmed by this test + by the live-game log diagnostic
# during Phase 3 session 1 lead live-test #2, 2026-05-14), the actual
# behavior is the OPPOSITE: HIGHER-index sibling fires FIRST.
#
# Concrete consequence: a Node-tree input handler that wants to consume
# clicks before its siblings see them MUST be the LATER sibling. The
# regression tests `amh.get_index() < ch.get_index()` and
# `bph.get_index() < ch.get_index()` were locking in the BROKEN order.
# They have been flipped as of BUG-10 fix.
#
# This test pins the Godot dispatch order so a future engine change
# would surface immediately rather than as silent input-handler dead
# branches.

extends GutTest


# Test-only handler that records its sibling index when _unhandled_input fires.
class FireRecorder:
	extends Node
	var fire_order: Array

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			fire_order.append(get_index())


func test_godot_unhandled_input_dispatches_reverse_sibling_order() -> void:
	var shared: Array = []
	var parent: Node = Node.new()
	add_child_autofree(parent)
	# Three handlers, idx 0/1/2.
	for i in range(3):
		var h: FireRecorder = FireRecorder.new()
		h.fire_order = shared
		parent.add_child(h)
	await get_tree().process_frame
	# Synthesize a left-mouse press.
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(100, 100)
	Input.parse_input_event(ev)
	await get_tree().process_frame
	# REVERSE-SIBLING ORDER: idx 2 first, then idx 1, then idx 0.
	# If this fails, Godot changed its dispatch behavior — the entire
	# input-handler sibling-position convention across input/*.gd must
	# be re-audited.
	assert_eq(shared, [2, 1, 0],
		"Godot _unhandled_input must dispatch in reverse sibling order "
		+ "(higher idx first). Got %s" % str(shared))
