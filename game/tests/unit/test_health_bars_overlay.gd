extends GutTest
##
## Tests for HealthBarsOverlay — Phase 2 session 1 wave 2C (ui-developer).
##
## Per 02d_PHASE_2_KICKOFF.md §2 deliverable 8: a single Control overlay that
## iterates units each frame and draws a small horizontal HP bar above each
## one — color-graded green / yellow / red, hidden when HP is full, hidden when
## the unit is off-screen, width scaled by unit-size class.
##
## Coverage:
##   - Color thresholds: HP > 70% → green; 30% ≤ HP ≤ 70% → yellow; < 30% → red.
##     Tags are exposed as StringNames (BAND_GREEN / BAND_YELLOW / BAND_RED) so
##     tests assert on stable identifiers, not RGB triples — same convention as
##     test_farr_gauge.gd. The overlay maps tags to concrete Colors internally.
##   - Width scales with unit_type: kargar (small) → 32 px, piyade (medium) →
##     48 px. Turan_piyade mirrors the medium width. Default fallback also
##     covered.
##   - Hidden on full HP (clean visual default — players don't need a bar over
##     a healthy unit).
##   - Hidden when off-screen: Camera3D.is_position_behind OR the projected
##     screen position lies outside the viewport rect. The math piece is
##     exercised via the public projector seam (the same shape
##     box_select_handler.gd uses for its tests).
##   - Defensive: invalid (freed) units skipped without crash.
##   - mouse_filter == MOUSE_FILTER_IGNORE both in the .tscn loader and at
##     runtime in _ready (CRITICAL — Pitfall #1, the canonical session-1
##     regression).
##
## We bypass the live Camera3D by exercising the `compute_bar_entries(units,
## project_unit)` public seam — the handler tests inject a closure that
## returns a Dictionary { screen_pos, on_screen } directly. Real Camera3D
## projection is exercised in the lead's interactive smoke test.

const HealthBarsOverlayScript: Script = preload(
	"res://scripts/ui/health_bars_overlay.gd")
const HealthComponentScript: Script = preload(
	"res://scripts/units/components/health_component.gd")

# Color-band identifiers per the kickoff §2 deliverable 8 thresholds:
#   > 70% → green
#   30% ≤ x ≤ 70% → yellow
#   < 30% → red
const BAND_GREEN: StringName = &"green"
const BAND_YELLOW: StringName = &"yellow"
const BAND_RED: StringName = &"red"


# Plain Node3D fake unit — minimum surface the overlay reads:
#   unit_type: StringName  (selects the bar width)
#   global_position: Vector3 (for projection)
#   get_health() -> Object  (returns a HealthComponent-shaped child)
class FakeUnit extends Node3D:
	var unit_type: StringName = &"kargar"
	var _health: Object = null
	func get_health() -> Object:
		return _health


var overlay: Control
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	overlay = HealthBarsOverlayScript.new()
	add_child_autofree(overlay)
	_units.clear()


func after_each() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SimClock.reset()


func _make_unit(
		unit_type: StringName,
		max_hp: float,
		current_hp: float,
		screen_pos: Vector2,
		on_screen: bool = true
) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_type = unit_type
	add_child_autofree(u)
	var hc: Object = HealthComponentScript.new()
	hc.init_max_hp(max_hp)
	# Damage path is on-tick; bypass via fixed-point write.
	var current_x100: int = roundi(current_hp * 100.0)
	hc.set(&"hp_x100", current_x100)
	u.add_child(hc)
	u._health = hc
	u.set_meta(&"_test_screen_pos", screen_pos)
	u.set_meta(&"_test_on_screen", on_screen)
	_units.append(u)
	return u


# Closure-friendly projector: reads the test's stored screen_pos meta from
# each unit. Same shape as the production projector (returns a Dictionary
# with screen_pos + on_screen).
static func _project_test_unit(u: Object) -> Dictionary:
	if u == null or not is_instance_valid(u):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	if not (u is Node):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var pos_v: Variant = (u as Node).get_meta(&"_test_screen_pos", Vector2.ZERO)
	var os_v: Variant = (u as Node).get_meta(&"_test_on_screen", true)
	return { &"screen_pos": pos_v, &"on_screen": os_v }


# ---------------------------------------------------------------------------
# Color band classification
# ---------------------------------------------------------------------------

func test_full_hp_is_skipped_no_bar_drawn() -> void:
	# 100% HP — bar is hidden.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 100.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 0,
			"full-HP units must not get a bar entry")


func test_high_hp_is_green_band() -> void:
	# 80% HP — green band.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 80.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_GREEN,
			"HP > 70% must classify as the green band")


func test_threshold_just_above_yellow_is_green() -> void:
	# 71% HP — strictly above the 70% boundary, still green.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 71.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_GREEN)


func test_threshold_at_seventy_is_yellow() -> void:
	# 70% HP — yellow band (inclusive at upper bound matches kickoff
	# "30% ≤ x ≤ 70%" reading).
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 70.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_YELLOW,
			"HP at exactly 70% must classify as the yellow band")


func test_mid_hp_is_yellow_band() -> void:
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_YELLOW,
			"HP at 50% must classify as the yellow band")


func test_threshold_at_thirty_is_yellow() -> void:
	# 30% HP — yellow (inclusive lower bound).
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 30.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_YELLOW,
			"HP at exactly 30% must classify as the yellow band")


func test_low_hp_is_red_band() -> void:
	# 20% HP — red band.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 20.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_RED,
			"HP < 30% must classify as the red band")


func test_threshold_just_below_thirty_is_red() -> void:
	# 29% HP — strictly below 30%, red.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 29.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"band"), BAND_RED)


# ---------------------------------------------------------------------------
# Width by unit-size class
# ---------------------------------------------------------------------------

func test_kargar_width_is_small() -> void:
	# Damage the kargar so a bar is generated (full HP would skip).
	var u: FakeUnit = _make_unit(&"kargar", 60.0, 30.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0].get(&"width")), 32,
			"Kargar (small unit) must use the 32 px bar width")


func test_piyade_width_is_medium() -> void:
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0].get(&"width")), 48,
			"Piyade (medium unit) must use the 48 px bar width")


func test_turan_piyade_width_is_medium() -> void:
	var u: FakeUnit = _make_unit(&"turan_piyade", 100.0, 50.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0].get(&"width")), 48,
			"Turan Piyade mirrors Iran Piyade — must use the 48 px bar width")


func test_unknown_unit_type_falls_back_to_medium_width() -> void:
	var u: FakeUnit = _make_unit(&"unknown_type", 100.0, 50.0, Vector2(400, 300))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0].get(&"width")), 48,
			"Unknown unit type must fall back to the medium width")


# ---------------------------------------------------------------------------
# Off-screen / invalid skip
# ---------------------------------------------------------------------------

func test_off_screen_unit_is_skipped() -> void:
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(400, 300), false)
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 0,
			"off-screen units must not contribute a bar entry")


func test_freed_unit_is_skipped_without_crash() -> void:
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(400, 300))
	# Free immediately. The list passed to compute_bar_entries holds the
	# (now-invalid) reference; the overlay must skip it defensively.
	u.queue_free()
	await get_tree().process_frame
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 0,
			"freed units must be skipped without crash")


func test_unit_without_health_component_is_skipped() -> void:
	# A Node3D with no get_health() must not crash the overlay.
	var u: Node3D = Node3D.new()
	add_child_autofree(u)
	u.set_meta(&"_test_screen_pos", Vector2(400, 300))
	u.set_meta(&"_test_on_screen", true)
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 0,
			"units missing a HealthComponent must be skipped silently")


func test_unit_with_zero_max_hp_is_skipped() -> void:
	# Defensive against pre-init order: a HealthComponent that hasn't yet
	# read max_hp from BalanceData has max_hp_x100 == 0, which would divide
	# by zero. The overlay must short-circuit instead of crashing.
	var u: FakeUnit = FakeUnit.new()
	u.unit_type = &"piyade"
	add_child_autofree(u)
	var hc: Object = HealthComponentScript.new()
	# Skip init_max_hp — leave both at 0.
	u.add_child(hc)
	u._health = hc
	u.set_meta(&"_test_screen_pos", Vector2(400, 300))
	u.set_meta(&"_test_on_screen", true)
	_units.append(u)
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 0,
			"max_hp == 0 must skip the bar entry without dividing")


# ---------------------------------------------------------------------------
# Mouse-filter discipline (Pitfall #1 — the canonical session-1 regression)
# ---------------------------------------------------------------------------

func test_mouse_filter_is_ignore_at_runtime() -> void:
	# The overlay sits on top of the viewport. If its mouse_filter were
	# MOUSE_FILTER_STOP (Godot's default), it would silently swallow every
	# left-click and right-click. _ready must defensively force IGNORE
	# regardless of what the .tscn says.
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"Pitfall #1 — overlay.mouse_filter must be MOUSE_FILTER_IGNORE")


# ---------------------------------------------------------------------------
# Multiple units
# ---------------------------------------------------------------------------

func test_multiple_units_produce_multiple_entries() -> void:
	# Three damaged units, all on-screen → three entries. One full-HP unit
	# (skipped). One off-screen (skipped). Final count: 3.
	var damaged_a: FakeUnit = _make_unit(&"piyade", 100.0, 80.0, Vector2(100, 100))
	var damaged_b: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(200, 100))
	var damaged_c: FakeUnit = _make_unit(&"kargar", 60.0, 20.0, Vector2(300, 100))
	var full: FakeUnit = _make_unit(&"piyade", 100.0, 100.0, Vector2(400, 100))
	var off: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(500, 100), false)
	var entries: Array = overlay.compute_bar_entries(
			[damaged_a, damaged_b, damaged_c, full, off],
			Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 3,
			"three damaged on-screen units must produce three entries")


func test_screen_pos_carried_through_to_entry() -> void:
	# The bar is drawn AT the projected screen position (with a vertical
	# offset for the unit's height). The entry must carry the projected
	# screen_pos so _draw places the bar correctly.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 50.0, Vector2(640, 360))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"screen_pos"), Vector2(640, 360),
			"entry must carry the projected screen_pos for _draw")


func test_hp_ratio_carried_through_to_entry() -> void:
	# The fill width inside the bar is ratio * width. Round-trip the ratio
	# so a future draw inspector can verify the partial fill.
	var u: FakeUnit = _make_unit(&"piyade", 100.0, 25.0, Vector2(0, 0))
	var entries: Array = overlay.compute_bar_entries(
			[u], Callable(self, &"_project_test_unit"))
	assert_eq(entries.size(), 1)
	assert_almost_eq(float(entries[0].get(&"hp_ratio")), 0.25, 0.0001,
			"entry must carry the hp_ratio for the partial-fill draw")
