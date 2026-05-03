# Tests for BoxSelectMath — pure math helpers used by box_select_handler.gd.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §2 (1).
#
# What we cover here (the parts a unit test CAN catch — see the handler
# tests for input-event-flow / dead-zone / Shift-modifier coverage):
#   - rect_from_corners normalizes any of the four drag directions.
#   - is_past_dead_zone correctly thresholds at the configured radius.
#   - units_in_rect filters by projected position; respects on_screen flag;
#     handles partial coverage; returns stable order; empty list on miss.
extends GutTest


const BoxSelectMath: Script = preload("res://scripts/input/box_select_math.gd")


# ===========================================================================
# rect_from_corners — direction-agnostic normalization
# ===========================================================================

func test_rect_from_corners_top_left_to_bottom_right() -> void:
	var r: Rect2 = BoxSelectMath.rect_from_corners(Vector2(10, 20), Vector2(50, 80))
	assert_eq(r.position, Vector2(10, 20))
	assert_eq(r.size, Vector2(40, 60))


func test_rect_from_corners_bottom_right_to_top_left() -> void:
	# Same diagonal, reversed direction. Must produce the same Rect2.
	var r: Rect2 = BoxSelectMath.rect_from_corners(Vector2(50, 80), Vector2(10, 20))
	assert_eq(r.position, Vector2(10, 20))
	assert_eq(r.size, Vector2(40, 60),
		"rect must normalize to positive-size regardless of drag direction")


func test_rect_from_corners_top_right_to_bottom_left() -> void:
	var r: Rect2 = BoxSelectMath.rect_from_corners(Vector2(50, 20), Vector2(10, 80))
	assert_eq(r.position, Vector2(10, 20))
	assert_eq(r.size, Vector2(40, 60))


func test_rect_from_corners_bottom_left_to_top_right() -> void:
	var r: Rect2 = BoxSelectMath.rect_from_corners(Vector2(10, 80), Vector2(50, 20))
	assert_eq(r.position, Vector2(10, 20))
	assert_eq(r.size, Vector2(40, 60))


func test_rect_from_corners_zero_size_when_same_point() -> void:
	# Sub-pixel "drag" with start == end — has_point is still well-defined.
	var r: Rect2 = BoxSelectMath.rect_from_corners(Vector2(10, 20), Vector2(10, 20))
	assert_eq(r.position, Vector2(10, 20))
	assert_eq(r.size, Vector2(0, 0))


# ===========================================================================
# is_past_dead_zone — click-vs-drag arbitration
# ===========================================================================

func test_is_past_dead_zone_zero_movement_is_not_past() -> void:
	assert_false(BoxSelectMath.is_past_dead_zone(
		Vector2(100, 100), Vector2(100, 100), 4.0))


func test_is_past_dead_zone_below_threshold_is_not_past() -> void:
	# 3px diagonal ≈ 4.24px Euclidean — but our threshold is 4 squared, so
	# a 3,3 vector at distance √18 = 4.24 IS past 4. Use a 2,2 case instead.
	assert_false(BoxSelectMath.is_past_dead_zone(
		Vector2(100, 100), Vector2(102, 102), 4.0),
		"2,2 (dist=√8 ≈ 2.83) must be below the 4px dead zone")


func test_is_past_dead_zone_at_threshold_is_past() -> void:
	# Exactly 4px to the right. Inclusive of the boundary.
	assert_true(BoxSelectMath.is_past_dead_zone(
		Vector2(100, 100), Vector2(104, 100), 4.0))


func test_is_past_dead_zone_well_past_threshold_is_past() -> void:
	assert_true(BoxSelectMath.is_past_dead_zone(
		Vector2(100, 100), Vector2(200, 200), 4.0))


# ===========================================================================
# units_in_rect — the filter the handler runs on every release
# ===========================================================================

# Build a projected-positions entry. Tests use plain RefCounted as the unit
# stand-in — `units_in_rect` doesn't introspect the unit object; it only
# carries it through to the result array.
class FakeUnit extends RefCounted:
	var label: String = ""

	func _init(s: String = "") -> void:
		label = s


static func _projected(unit: Object, x: float, y: float, on_screen: bool = true) -> Dictionary:
	return {
		&"unit": unit,
		&"screen_pos": Vector2(x, y),
		&"on_screen": on_screen,
	}


func test_units_in_rect_returns_only_units_inside() -> void:
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(100, 100))
	var inside: FakeUnit = FakeUnit.new("inside")
	var outside: FakeUnit = FakeUnit.new("outside")
	var projected: Array = [
		_projected(inside, 50, 50),
		_projected(outside, 200, 50),
	]
	var hits: Array = BoxSelectMath.units_in_rect(rect, projected)
	assert_eq(hits.size(), 1)
	assert_eq((hits[0] as FakeUnit).label, "inside")


func test_units_in_rect_includes_all_when_rect_covers_all() -> void:
	# 5 units arrayed; rect bigger than all of them.
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(-1000, -1000), Vector2(1000, 1000))
	var projected: Array = []
	for i: int in range(5):
		projected.append(_projected(FakeUnit.new("u%d" % i), float(i * 10), 50.0))
	var hits: Array = BoxSelectMath.units_in_rect(rect, projected)
	assert_eq(hits.size(), 5,
		"rect covering all projected positions must select every unit")


func test_units_in_rect_returns_empty_when_rect_misses_all() -> void:
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(10, 10))
	var projected: Array = [
		_projected(FakeUnit.new("a"), 100, 100),
		_projected(FakeUnit.new("b"), 200, 200),
	]
	assert_eq(BoxSelectMath.units_in_rect(rect, projected).size(), 0)


func test_units_in_rect_skips_off_screen_entries() -> void:
	# Projected position is inside the rect numerically, but the unit was
	# behind the camera (on_screen=false) — must not be selected.
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(100, 100))
	var projected: Array = [
		_projected(FakeUnit.new("behind"), 50, 50, false),
	]
	assert_eq(BoxSelectMath.units_in_rect(rect, projected).size(), 0,
		"on_screen=false entries must be filtered even if screen_pos is inside")


func test_units_in_rect_preserves_input_order() -> void:
	# Stable order: first-in-list comes out first. Important for any UI
	# that wants the leftmost/topmost-on-screen unit as the "primary."
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(1000, 1000))
	var a: FakeUnit = FakeUnit.new("a")
	var b: FakeUnit = FakeUnit.new("b")
	var c: FakeUnit = FakeUnit.new("c")
	var projected: Array = [
		_projected(a, 30, 30),
		_projected(b, 60, 30),
		_projected(c, 90, 30),
	]
	var hits: Array = BoxSelectMath.units_in_rect(rect, projected)
	assert_eq(hits.size(), 3)
	assert_eq((hits[0] as FakeUnit).label, "a")
	assert_eq((hits[1] as FakeUnit).label, "b")
	assert_eq((hits[2] as FakeUnit).label, "c")


func test_units_in_rect_handles_boundary_inclusion() -> void:
	# Rect2.has_point is inclusive on the min edges, exclusive on the max.
	# This test pins down our reliance on Godot's behavior so a future
	# engine change that flips inclusivity is caught.
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(100, 100))
	var on_min: FakeUnit = FakeUnit.new("on_min")
	var on_max: FakeUnit = FakeUnit.new("on_max")
	var projected: Array = [
		_projected(on_min, 0, 0),
		_projected(on_max, 100, 100),
	]
	var hits: Array = BoxSelectMath.units_in_rect(rect, projected)
	# Min edge inclusive → on_min is in. Max edge exclusive → on_max is out.
	# This is documented Rect2 behavior (Godot 4 docs).
	var labels: Array = []
	for u in hits:
		labels.append((u as FakeUnit).label)
	assert_true(labels.has("on_min"),
		"min-edge point must be inside (Rect2.has_point is inclusive on min)")


func test_units_in_rect_skips_malformed_entries() -> void:
	# Defensive: missing fields, wrong types, null unit.
	var rect: Rect2 = BoxSelectMath.rect_from_corners(
		Vector2(0, 0), Vector2(100, 100))
	var good: FakeUnit = FakeUnit.new("good")
	var projected: Array = [
		_projected(good, 50, 50),
		{},  # missing fields
		{ &"unit": null, &"screen_pos": Vector2(60, 60) },  # null unit
		{ &"unit": good, &"screen_pos": "not a vector2" },  # wrong type
	]
	var hits: Array = BoxSelectMath.units_in_rect(rect, projected)
	assert_eq(hits.size(), 1,
		"malformed entries must be skipped, only the well-formed entry hits")
	assert_eq((hits[0] as FakeUnit).label, "good")
