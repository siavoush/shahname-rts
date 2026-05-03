# Integration tests — double-click select-of-type ring-visibility regression.
#
# Wave 3 / bugfix (ui-developer). Covers the live-game-broken-surface that
# the existing tests/unit/test_double_click_select.gd missed: selection-set
# membership was correct, but the actual selection ring on units 2..N never
# became visible after `select_visible_of_type`.
#
# The original unit tests use a FakeUnit that exposes `unit_id` and a
# SelectableComponent — but their assertions only check
# `SelectionManager.is_selected(unit)`. They do NOT verify that each
# SelectableComponent's `is_selected` flag flipped, nor that its `_ring`
# became `visible`. This test exercises real Kargar instances spawned via
# the kargar.tscn template (same path as the live game) and asserts on the
# component-side state and ring visibility.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (3) + the live-game-
# broken-surface principle in docs/PROCESS_EXPERIMENTS.md.
#
# Typing: Variant slots for unit refs (class_name registry-race pattern,
# ARCHITECTURE.md §6 v0.4.0).

extends GutTest


const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const DoubleClickSelectScript: Script = preload(
	"res://scripts/input/double_click_select.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _detector: Node = null
var _units: Array = []


func before_each() -> void:
	SelectionManager.reset()
	UnitScript.call(&"reset_id_counter")
	_units.clear()
	_detector = DoubleClickSelectScript.new()
	add_child_autofree(_detector)
	_detector.set_test_mode(true)


func after_each() -> void:
	for u in _units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	_detector = null


# Spawn a real Kargar via the production scene template. Wait one frame so
# the SelectableComponent's deferred ring add_child has landed (the ring is
# created in _ready via call_deferred — see selectable_component.gd). Without
# this await the _ring node may exist but not yet be in the scene tree, and
# `_ring.visible` reads the same regardless, but consumers that walk the
# tree to find the ring would miss it.
func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	_units.append(u)
	return u


# Pull the SelectableComponent off a unit and return its `_ring` node.
# Returns null if either the component or the ring isn't resolvable.
func _ring_of(u: Variant) -> Node3D:
	if u == null or not is_instance_valid(u):
		return null
	var sc: Object = u.get_selectable()
	if sc == null:
		return null
	var ring_v: Variant = sc.get(&"_ring")
	if ring_v == null:
		return null
	return ring_v as Node3D


# All-units-on-screen projector for select_visible_of_type.
static func _project_all_on_screen(_u: Object) -> Dictionary:
	return { &"screen_pos": Vector2(100, 100), &"on_screen": true }


# ============================================================================
# 1. The headless reproduction of the live bug
# ============================================================================

# Spawn 5 real Kargars, drive select_visible_of_type as the production code
# would, then assert all 5 components show is_selected=true AND all 5 rings
# show _ring.visible=true. If this test fails, we've reproduced the bug
# the lead saw in the live game.
func test_select_of_type_makes_all_kargar_rings_visible() -> void:
	var kargars: Array = []
	for i in range(5):
		var k: Variant = _spawn_kargar(Vector3(float(i) - 2.0, 0.0, 0.0))
		kargars.append(k)
	# Allow SelectableComponent's deferred add_child(_ring) to land — the
	# ring is created and parented via call_deferred inside _ready, so the
	# first frame after spawn is when the ring actually joins the tree.
	await get_tree().process_frame

	# Drive the same path the live game uses: production select_visible_of_type
	# with a deselect_all + add_to_selection per hit.
	var target: Variant = kargars[0]
	_detector.select_visible_of_type(
		target, kargars, Callable(self, &"_project_all_on_screen"))

	# All 5 should be in SelectionManager's set (this part the existing tests
	# cover; we re-assert here as a sanity floor).
	assert_eq(SelectionManager.selected_units.size(), 5,
		"all 5 kargars must be in SelectionManager's selection set")

	# THE REGRESSION ASSERT: every component's is_selected flag is true.
	for k in kargars:
		var sc: Object = k.get_selectable()
		assert_true(sc.get(&"is_selected"),
			"SelectableComponent.is_selected must be true on unit_id=%d after select_visible_of_type"
			% int(k.unit_id))

	# AND: every ring node must report visible=true. This is the property
	# the live game renders; it is what the lead actually saw fail.
	for k in kargars:
		var ring: Node3D = _ring_of(k)
		assert_not_null(ring,
			"unit_id=%d must have a resolvable selection ring" % int(k.unit_id))
		assert_true(ring.visible,
			"ring on unit_id=%d must be visible after select_visible_of_type"
			% int(k.unit_id))


# ============================================================================
# 2. Same path, but driven through the production add-to-selection loop
#    explicitly (mirrors what select_visible_of_type does internally).
# ============================================================================

# This is a finer-grained reproduction: bypass select_visible_of_type and
# call SelectionManager.deselect_all + add_to_selection directly, exactly
# the way the production method's body does. If THIS fails too, the bug
# is in SelectionManager / SelectableComponent rather than in
# select_visible_of_type's filtering.
func test_deselect_all_then_add_to_selection_loop_makes_all_rings_visible() -> void:
	var kargars: Array = []
	for i in range(5):
		var k: Variant = _spawn_kargar(Vector3(float(i) - 2.0, 0.0, 0.0))
		kargars.append(k)
	await get_tree().process_frame

	SelectionManager.deselect_all()
	for k in kargars:
		SelectionManager.add_to_selection(k)

	for k in kargars:
		var ring: Node3D = _ring_of(k)
		assert_not_null(ring)
		assert_true(ring.visible,
			"ring on unit_id=%d must be visible after the manual loop"
			% int(k.unit_id))


# ============================================================================
# 3. Signal-driven path — drive double-click via SelectionManager.select_only,
#    NOT direct API. This is the actual production codepath (ClickHandler →
#    SelectionManager.select_only → DoubleClickSelect._on_selection_changed).
# ============================================================================

# Set up the detector with NOT test_mode (so it owns the signal handler)
# and feed it candidate / projector seams. Then call select_only twice on the
# same kargar within DOUBLE_CLICK_TICKS to trigger the expansion via the
# real signal-driven path (not via direct select_visible_of_type).
func test_signal_driven_double_click_makes_all_rings_visible() -> void:
	# Detector was created in before_each with test_mode=true. We need a
	# different setup here: detector with test_mode OFF so the signal
	# auto-connects, but with injected candidate provider + projector so
	# we don't need a real Camera3D.
	_detector.set_test_mode(false)
	# Setup 5 kargars. Stash them in a closure-accessible variable.
	var kargars: Array = []
	for i in range(5):
		var k: Variant = _spawn_kargar(Vector3(float(i) - 2.0, 0.0, 0.0))
		kargars.append(k)
	await get_tree().process_frame

	_detector.set_candidate_provider(func() -> Array: return kargars)
	_detector.set_projector(Callable(self, &"_project_all_on_screen"))

	# First click: arms the detector.
	SimClock.reset()
	var target: Variant = kargars[0]
	SelectionManager.select_only(target)
	# Should be just one selection.
	assert_eq(SelectionManager.selected_units.size(), 1,
		"after first select_only, only 1 unit selected")

	# Advance simclock by a few ticks (within window).
	for _i in range(int(_detector.DOUBLE_CLICK_TICKS) - 1):
		SimClock._test_run_tick()

	# Second click on same kargar — triggers double-click expansion.
	# The expansion runs deferred (next idle frame) so we await one frame
	# before asserting on the post-expansion state.
	SelectionManager.select_only(target)
	await get_tree().process_frame

	# After expansion, all 5 should be selected and all rings visible.
	assert_eq(SelectionManager.selected_units.size(), 5,
		"after signal-driven double-click, all 5 kargars must be selected")

	for k in kargars:
		var sc: Object = k.get_selectable()
		assert_true(sc.get(&"is_selected"),
			"unit_id=%d component.is_selected must be true after signal-driven double-click"
			% int(k.unit_id))
		var ring: Node3D = _ring_of(k)
		assert_not_null(ring)
		assert_true(ring.visible,
			"unit_id=%d ring must be visible after signal-driven double-click"
			% int(k.unit_id))


# ============================================================================
# 4. Re-trigger: deselect, then select again — rings flicker correctly.
# ============================================================================

# Regression guard for "ring stays off after deselect→reselect" — the
# state-machine in SelectableComponent._apply_selection short-circuits when
# is_selected is unchanged, so this asserts the off→on→off→on cycle works
# end-to-end across the broadcast surface.
func test_deselect_then_reselect_cycle_keeps_rings_in_sync() -> void:
	var kargars: Array = []
	for i in range(3):
		var k: Variant = _spawn_kargar(Vector3(float(i), 0.0, 0.0))
		kargars.append(k)
	await get_tree().process_frame

	# First select.
	for k in kargars:
		SelectionManager.add_to_selection(k)
	for k in kargars:
		assert_true(_ring_of(k).visible)

	# Deselect.
	SelectionManager.deselect_all()
	for k in kargars:
		assert_false(_ring_of(k).visible,
			"ring on unit_id=%d must be hidden after deselect_all"
			% int(k.unit_id))

	# Re-select.
	for k in kargars:
		SelectionManager.add_to_selection(k)
	for k in kargars:
		assert_true(_ring_of(k).visible,
			"ring on unit_id=%d must be visible again after re-select"
			% int(k.unit_id))
