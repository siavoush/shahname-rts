extends GutTest
##
## Tests for AttackRangeOverlay — Phase 2 session 1 wave 2C (ui-developer).
##
## Per 02d_PHASE_2_KICKOFF.md §2 deliverable 9: when F4 is pressed, render
## attack-range circles around each currently-selected unit. Subscribes to
## EventBus.selection_changed; toggles via DebugOverlayManager.
##
## Implementation choice (documented in the source): the overlay is a `Control`
## (NOT a Node3D root) because `DebugOverlayManager.register_overlay(key,
## overlay: Control)` is statically typed against `Control`. Registering a
## Node3D would fail-silent under the manager's `as Control` cast (returns
## null → toggle no-ops). Brief preferred 3D for correctness-under-camera-move,
## but per-frame screen projection in `_draw` produces visually identical
## results and stays inside the file-ownership rules ("touch DebugOverlayManager
## only via public API"). See AttackRangeOverlay docstring for rationale.
##
## Coverage:
##   - circle_count == selected unit count.
##   - Each circle's radius matches `combat.attack_range` for its unit.
##   - F4 toggle hides / shows via DebugOverlayManager.handle_function_key.
##   - Selection-changed signal updates the circle set.
##   - DebugOverlayManager has the overlay registered under
##     `Constants.OVERLAY_KEY_F4` after _ready.
##   - Defensive: units without a CombatComponent are skipped (no crash).
##   - Defensive: empty selection produces zero circles.
##
## Tests use FakeUnit fixtures (Node3D + duck-typed get_combat()) to avoid
## a real Camera3D dependency. The render path (Control._draw) is exercised
## indirectly via the public `entries` accessor — same pattern test_farr_gauge
## uses for its color-band assertions.

const AttackRangeOverlayScript: Script = preload(
	"res://scripts/ui/overlays/attack_range_overlay.gd")
const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain-Node3D fake unit. Surface mirrors what the overlay reads:
#   unit_id: int
#   team: int
#   global_position: Vector3
#   get_combat() -> Object (returns a FakeCombat-shaped node)
#   get_selectable() -> Object (lets SelectionManager.select work cleanly)
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var team: int = 1  # Constants.TEAM_IRAN
	var command_queue: Object = null
	var _combat: Object = null
	var _selectable: Variant = null
	func get_combat() -> Object:
		return _combat
	func get_selectable() -> Object:
		return _selectable


# Plain RefCounted-style fake combat with the one field the overlay reads.
class FakeCombat extends Node:
	var attack_range: float = 1.5


var overlay: Control
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	SelectionManager.reset()
	DebugOverlayManager.reset()
	overlay = AttackRangeOverlayScript.new()
	add_child_autofree(overlay)
	# Force one process_frame so _ready runs and the overlay registers
	# itself with DebugOverlayManager / connects to EventBus.
	await get_tree().process_frame
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	DebugOverlayManager.reset()
	SimClock.reset()


func _make_unit(uid: int, attack_range: float, world_pos: Vector3 = Vector3.ZERO) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.team = Constants.TEAM_IRAN
	u.global_position = world_pos
	add_child_autofree(u)
	var combat: FakeCombat = FakeCombat.new()
	combat.attack_range = attack_range
	u.add_child(combat)
	u._combat = combat
	# A SelectableComponent so SelectionManager doesn't choke when calling
	# select() — same fixture pattern as test_box_select_handler.
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


# ---------------------------------------------------------------------------
# Registration with DebugOverlayManager
# ---------------------------------------------------------------------------

func test_overlay_registers_with_debug_manager_under_f4_key() -> void:
	assert_true(DebugOverlayManager.is_registered(Constants.OVERLAY_KEY_F4),
			"AttackRangeOverlay must register itself under OVERLAY_KEY_F4 in _ready")
	assert_same(DebugOverlayManager.get_overlay(Constants.OVERLAY_KEY_F4), overlay)


func test_overlay_starts_hidden() -> void:
	# F4 is a debug overlay — boots invisible. F4-press is the only way to
	# show it. Matches the kickoff §2 (9) "Hits F4 → circles render" framing.
	assert_false(overlay.visible,
			"AttackRangeOverlay must start hidden (F4 toggles it on)")


func test_f4_toggle_shows_then_hides() -> void:
	# Drive through DebugOverlayManager — the production path.
	DebugOverlayManager.handle_function_key(KEY_F4)
	assert_true(overlay.visible, "first F4 press must show the overlay")
	DebugOverlayManager.handle_function_key(KEY_F4)
	assert_false(overlay.visible, "second F4 press must hide the overlay")


# ---------------------------------------------------------------------------
# Selection-driven circle entries
# ---------------------------------------------------------------------------

func test_no_selection_no_circles() -> void:
	# Empty broadcast → entries empty.
	overlay.handle_selection_changed([])
	assert_eq(overlay.circle_count(), 0,
			"empty selection must produce zero circles")


func test_one_selected_unit_one_circle() -> void:
	var u: FakeUnit = _make_unit(1, 1.5, Vector3(5, 0, 5))
	# Drive via SelectionManager so the production signal path is exercised.
	SelectionManager.select(u)
	assert_eq(overlay.circle_count(), 1,
			"one selected unit must produce one circle")


func test_multiple_selected_units_produce_multiple_circles() -> void:
	var a: FakeUnit = _make_unit(1, 1.5, Vector3(0, 0, 0))
	var b: FakeUnit = _make_unit(2, 2.0, Vector3(2, 0, 2))
	var c: FakeUnit = _make_unit(3, 1.5, Vector3(-2, 0, -2))
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	SelectionManager.add_to_selection(c)
	assert_eq(overlay.circle_count(), 3,
			"three selected units must produce three circles")


func test_circle_radius_matches_combat_attack_range() -> void:
	var u: FakeUnit = _make_unit(1, 4.25, Vector3(10, 0, -3))
	SelectionManager.select(u)
	var entries: Array = overlay.entries()
	assert_eq(entries.size(), 1)
	assert_almost_eq(float(entries[0].get(&"radius")), 4.25, 0.0001,
			"circle radius must equal the unit's combat.attack_range")


func test_circle_world_pos_matches_unit_position() -> void:
	var u: FakeUnit = _make_unit(1, 1.5, Vector3(7, 0, -11))
	SelectionManager.select(u)
	var entries: Array = overlay.entries()
	assert_eq(entries.size(), 1)
	# The overlay carries the unit's global_position so _draw can project
	# it through the live Camera3D.
	var pos: Variant = entries[0].get(&"world_pos")
	assert_eq(pos, Vector3(7, 0, -11),
			"circle world_pos must mirror the unit's global_position")


func test_selection_change_replaces_circle_set() -> void:
	var a: FakeUnit = _make_unit(1, 1.5, Vector3(0, 0, 0))
	var b: FakeUnit = _make_unit(2, 2.0, Vector3(2, 0, 2))
	SelectionManager.select(a)
	assert_eq(overlay.circle_count(), 1)
	# Replace selection with b only — circle count stays 1, but the
	# unit-id changes.
	SelectionManager.select_only(b)
	assert_eq(overlay.circle_count(), 1)
	var entries: Array = overlay.entries()
	assert_eq(int(entries[0].get(&"unit_id")), 2,
			"selection_changed must drive a fresh entry list")


func test_deselect_all_clears_circles() -> void:
	var u: FakeUnit = _make_unit(1, 1.5, Vector3(0, 0, 0))
	SelectionManager.select(u)
	assert_eq(overlay.circle_count(), 1)
	SelectionManager.deselect_all()
	assert_eq(overlay.circle_count(), 0,
			"deselect_all must clear the circle set")


# ---------------------------------------------------------------------------
# Defensive
# ---------------------------------------------------------------------------

func test_unit_without_combat_component_is_skipped() -> void:
	# A unit with no CombatComponent must be skipped silently — Kargars
	# may be selected; they have no attack_range to draw.
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = 99
	u.team = Constants.TEAM_IRAN
	u.global_position = Vector3.ZERO
	add_child_autofree(u)
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = 99
	u.add_child(sc)
	u._selectable = sc
	# u._combat stays null
	_units.append(u)
	SelectionManager.select(u)
	assert_eq(overlay.circle_count(), 0,
			"selected unit without a CombatComponent must be skipped silently")


func test_zero_attack_range_unit_is_skipped() -> void:
	# A Kargar-shaped unit with attack_range = 0 (worker, can't fight) must
	# not draw a degenerate zero-radius circle. Skip for visual cleanliness.
	var u: FakeUnit = _make_unit(1, 0.0, Vector3.ZERO)
	SelectionManager.select(u)
	assert_eq(overlay.circle_count(), 0,
			"attack_range == 0 must skip the circle")


func test_freed_unit_is_skipped_without_crash() -> void:
	# Selection signal carries unit_ids; the overlay walks
	# SelectionManager.selected_units (which lazy-filters freed entries).
	# An entry that goes invalid between broadcasts must be skipped, not
	# crash the projection loop.
	var u: FakeUnit = _make_unit(1, 1.5, Vector3.ZERO)
	SelectionManager.select(u)
	assert_eq(overlay.circle_count(), 1)
	u.queue_free()
	await get_tree().process_frame
	# Force the overlay to re-collect entries from the (now-stale) selection.
	overlay.handle_selection_changed([1])
	assert_eq(overlay.circle_count(), 0,
			"freed units must be skipped without crash")


# ---------------------------------------------------------------------------
# Mouse-filter discipline (Pitfall #1)
# ---------------------------------------------------------------------------

func test_mouse_filter_is_ignore_at_runtime() -> void:
	# The overlay is a fullscreen Control. Default MOUSE_FILTER_STOP would
	# eat every click in the viewport rect — Pitfall #1, the canonical
	# session-1 regression.
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"Pitfall #1 — overlay.mouse_filter must be MOUSE_FILTER_IGNORE")
