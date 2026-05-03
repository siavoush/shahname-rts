extends GutTest
##
## Tests for FarrGauge — circular Farr meter widget (Phase 1 session 2 wave 1C).
##
## Replaces the Phase 0 text "Farr: 50" readout with a circular `_draw`-based
## gauge that subscribes to `EventBus.farr_changed`. Threshold ticks (Tier 2
## and Kaveh trigger) are read from `BalanceData.farr` per CLAUDE.md.
##
## Coverage (expanded for Task 110):
##   - Scene loads cleanly and exposes the expected node API
##   - mouse_filter == IGNORE on root + every descendant Control
##     (CLAUDE.md hard constraint; session-1 regression)
##   - Initial Farr seeded from FarrSystem.value_farr at _ready
##   - EventBus.farr_changed updates the gauge's target Farr
##   - Threshold values read from BalanceData.farr (no hardcoded numbers)
##   - Edge cases: 0, exactly Tier 2 (40), exactly Kaveh trigger (15), 70, 100,
##     just-below each band boundary, clamp on bad input
##   - Defensive degradation: no FarrSystem autoload → falls back to spec default
##   - Constants.FARR_MAX is referenced (not hardcoded 100.0)
##   - Fill ratio computation: clamp(target_farr / tier2_threshold, 0, 1)
##   - Color-band classification (BAND_GOLD / BAND_IVORY / BAND_DIM / BAND_RED)
##     matching 01_CORE_MECHANICS.md §4.4 thresholds
##   - Signal connection lifecycle (connect at _ready, disconnect at tree_exit)
##   - Signal-to-redraw integration: emit → tween settles → band tag flips
##
## Test discipline mirrors test_resource_hud.gd: snapshot live FarrSystem state
## in before_each, restore in after_each, never leak signal connections.
##
## Per Sim Contract §1.5: the gauge reads sim state off-tick. Tests do not
## advance SimClock unless verifying the post-emit state — and even then we
## bypass apply_farr_change (which asserts on-tick) by writing _farr_x100
## directly + manually emitting a synthetic farr_changed signal, the same
## escape MatchHarness uses (FarrSystem.reset).
##
## Color-band classification per 01_CORE_MECHANICS.md §4.4:
##   ≥ 70 → gold (and glowing)
##   40 ≤ x < 70 → ivory
##   15 ≤ x < 40 → dim
##   < 15 → red (and pulsing)
## Boundary policy: inclusive at the lower bound of each band — exactly 70 is
## gold, exactly 40 is ivory, exactly 15 is dim. Avoids 14.99-vs-15.00 jitter
## across the Kaveh-warning UI.
##
## Color-band tags are exposed by the gauge as StringNames (BAND_*) so tests
## assert on the tag, not the RGB color — implementer can tune the palette
## without breaking tests.


# Color-band identifiers per 01_CORE_MECHANICS.md §4.4. The gauge exposes a
# `color_band: StringName` property; the implementer maps these tags to
# concrete Color values internally.
const BAND_GOLD: StringName = &"gold"      # ≥ 70
const BAND_IVORY: StringName = &"ivory"    # 40 ≤ x < 70
const BAND_DIM: StringName = &"dim"        # 15 ≤ x < 40
const BAND_RED: StringName = &"red"        # < 15


const GAUGE_SCENE_PATH: String = "res://scenes/ui/farr_gauge.tscn"


# Capture the live FarrSystem backing store so other tests don't see leaks.
var _saved_farr_x100: Variant = null


func before_each() -> void:
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr != null:
		_saved_farr_x100 = farr.get(&"_farr_x100")
	else:
		_saved_farr_x100 = null


func after_each() -> void:
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr != null and _saved_farr_x100 != null:
		farr.set(&"_farr_x100", _saved_farr_x100)


# ---------------------------------------------------------------------------
# 1. Scene structure — loads cleanly
# ---------------------------------------------------------------------------

func test_farr_gauge_scene_loads_without_error() -> void:
	var packed: PackedScene = load(GAUGE_SCENE_PATH)
	assert_not_null(packed,
		"farr_gauge.tscn must load cleanly from %s" % GAUGE_SCENE_PATH)


func test_farr_gauge_root_is_control() -> void:
	# Custom Control with _draw — must be a Control so the HUD HBox can layout it.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	assert_true(gauge is Control,
		"FarrGauge root must be a Control (or subclass) for HBox layout integration")


# ---------------------------------------------------------------------------
# 2. mouse_filter — must NOT swallow clicks (CLAUDE.md hard constraint)
# ---------------------------------------------------------------------------
# Phase 1 session 1 regression (HUD labels eating clicks via default
# MOUSE_FILTER_STOP) — the gauge must not repeat that mistake.

func test_gauge_mouse_filter_is_ignore() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	assert_eq(gauge.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Gauge mouse_filter must be IGNORE — must not swallow clicks "
		+ "passing through to world units (CLAUDE.md hard constraint)")


# ---------------------------------------------------------------------------
# 3. Initial Farr seeded from FarrSystem.value_farr at _ready
# ---------------------------------------------------------------------------

func test_initial_displayed_farr_seeds_from_farr_system() -> void:
	# Set FarrSystem to a recognizable non-default value, then instantiate the
	# gauge. The gauge's displayed value should match the FarrSystem state at
	# _ready time, not the spec default (50.0).
	#
	# We write _farr_x100 directly (off-tick) — the gauge's _ready reads
	# `value_farr` (a getter computed off the fixed-point store). No on-tick
	# constraint applies because we're not going through apply_farr_change.
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr == null:
		pending("FarrSystem autoload missing; can't seed initial value")
		return
	farr.set(&"_farr_x100", 7300)   # 73.0
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	# Public read: a `displayed_farr` property exposes the gauge's current
	# rendered Farr — used by tests and by the F2 debug overlay later.
	var displayed: Variant = gauge.get(&"displayed_farr")
	assert_not_null(displayed,
		"Gauge must expose a `displayed_farr` property")
	assert_almost_eq(float(displayed), 73.0, 1e-6,
		"Gauge.displayed_farr must seed from FarrSystem.value_farr at _ready")


func test_initial_displayed_farr_falls_back_when_farr_system_missing() -> void:
	# When the FarrSystem autoload doesn't exist (test scenes loading the gauge
	# in isolation), the gauge falls back to the spec default 50.0 from
	# 01_CORE_MECHANICS.md §4.1. If a real autoload IS registered (it always
	# is in this project's project.godot), skip — the path is unreachable.
	if get_tree().root.get_node_or_null(NodePath("FarrSystem")) != null:
		pending("FarrSystem autoload registered; defensive fallback path unreachable")
		return
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	var displayed: Variant = gauge.get(&"displayed_farr")
	assert_almost_eq(float(displayed), 50.0, 1e-6,
		"Without FarrSystem, gauge must fall back to spec default 50.0")


# ---------------------------------------------------------------------------
# 4. EventBus.farr_changed updates the gauge target
# ---------------------------------------------------------------------------
# The signal payload's `farr_after` field is authoritative. The gauge stores it
# as `target_farr`; a tween (kicked off in _on_farr_changed) interpolates
# `displayed_farr` toward it. Tests that don't want to await tween steps
# should read `target_farr` directly.

func test_farr_changed_signal_updates_target_farr() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	# Manually emit a synthetic farr_changed (off-tick is fine — same escape
	# MatchHarness uses for FarrSystem.reset).
	EventBus.farr_changed.emit(7.0, "test_signal", -1, 57.0, 0)
	# The handler should have run synchronously (Godot signals are sync).
	var target: Variant = gauge.get(&"target_farr")
	assert_not_null(target, "Gauge must expose a `target_farr` property")
	assert_almost_eq(float(target), 57.0, 1e-6,
		"target_farr must reflect signal payload's farr_after field")


func test_farr_changed_clamps_target_above_max() -> void:
	# Defensive clamp at the gauge boundary. The chokepoint
	# (FarrSystem.apply_farr_change) already clamps, so out-of-range values
	# shouldn't reach here in production — but test scenes / synthetic emits
	# (and a future Phase 5 hot-reload of FARR_MAX) might. Keep the gauge
	# robust.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test_clamp_high", -1, 250.0, 0)
	var target: Variant = gauge.get(&"target_farr")
	assert_almost_eq(float(target), Constants.FARR_MAX, 1e-6,
		"target_farr must clamp to Constants.FARR_MAX on out-of-range signal payload")


func test_farr_changed_clamps_target_below_zero() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test_clamp_low", -1, -10.0, 0)
	var target: Variant = gauge.get(&"target_farr")
	assert_almost_eq(float(target), 0.0, 1e-6,
		"target_farr must clamp to 0.0 on negative signal payload")


# ---------------------------------------------------------------------------
# 5. Edge case Farr values — exact threshold reads
# ---------------------------------------------------------------------------

func test_target_farr_at_zero_holds_zero() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 0.0, 0)
	var target: Variant = gauge.get(&"target_farr")
	assert_almost_eq(float(target), 0.0, 1e-6,
		"Farr at exactly 0 must store as 0 (no underflow)")


func test_target_farr_at_max_holds_max() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, Constants.FARR_MAX, 0)
	var target: Variant = gauge.get(&"target_farr")
	assert_almost_eq(float(target), Constants.FARR_MAX, 1e-6,
		"Farr at exactly FARR_MAX must store unchanged (no overflow clamp)")


# ---------------------------------------------------------------------------
# 6. Threshold reads from BalanceData
# ---------------------------------------------------------------------------
# CLAUDE.md: "no magic numbers in gameplay code" + "Threshold values read from
# BalanceData.farr_config." The gauge must read kaveh_trigger_threshold and
# tier2_threshold from BalanceData, not hardcode 15 / 40.

func test_threshold_values_loaded_from_balance_data() -> void:
	# Validates the gauge surfaces threshold accessors that match BalanceData.
	# The gauge owns its own load (defensive — same pattern as FarrSystem)
	# rather than reaching through FarrSystem, which keeps the gauge usable
	# in test scenes that don't autoload FarrSystem.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	# Load BalanceData ourselves to confirm what the gauge SHOULD have read.
	var bd: Resource = load(Constants.PATH_BALANCE_DATA)
	if bd == null:
		pending("BalanceData.tres unavailable")
		return
	var farr_cfg: Variant = bd.get(&"farr")
	if farr_cfg == null:
		pending("BalanceData.farr missing")
		return
	var expected_tier2: float = float(farr_cfg.get(&"tier2_threshold"))
	var expected_kaveh: float = float(farr_cfg.get(&"kaveh_trigger_threshold"))

	var gauge_tier2: Variant = gauge.get(&"tier2_threshold")
	var gauge_kaveh: Variant = gauge.get(&"kaveh_trigger_threshold")
	assert_not_null(gauge_tier2, "Gauge must expose tier2_threshold")
	assert_not_null(gauge_kaveh, "Gauge must expose kaveh_trigger_threshold")
	assert_almost_eq(float(gauge_tier2), expected_tier2, 1e-6,
		"tier2_threshold must match BalanceData.farr.tier2_threshold")
	assert_almost_eq(float(gauge_kaveh), expected_kaveh, 1e-6,
		"kaveh_trigger_threshold must match BalanceData.farr.kaveh_trigger_threshold")


# ---------------------------------------------------------------------------
# 7. Tween / displayed value behaviour
# ---------------------------------------------------------------------------

func test_displayed_farr_starts_equal_to_target_at_ready() -> void:
	# At _ready, before any tween, displayed_farr and target_farr are equal —
	# no animation on initial seed (tween only on subsequent farr_changed).
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr == null:
		pending("FarrSystem autoload missing")
		return
	farr.set(&"_farr_x100", 4200)   # 42.0
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	var displayed: float = float(gauge.get(&"displayed_farr"))
	var target: float = float(gauge.get(&"target_farr"))
	assert_almost_eq(displayed, target, 1e-6,
		"On initial seed, displayed_farr == target_farr (no startup tween)")


func test_displayed_farr_eventually_matches_target_after_tween() -> void:
	# Drive a farr_changed; pump enough frames for the 0.25s tween to settle
	# (≈15 frames at 60fps; we use a generous margin). After the tween,
	# displayed_farr must equal target_farr.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(20.0, "tween_test", -1, 70.0, 0)
	# Pump frames. SceneTreeTween auto-starts and runs in process; await
	# multiple frames to give it time to complete (0.25s ≈ 15 frames @ 60Hz;
	# 30 frames is generous).
	for i in range(30):
		await get_tree().process_frame
	var displayed: float = float(gauge.get(&"displayed_farr"))
	assert_almost_eq(displayed, 70.0, 0.5,
		"After tween settles, displayed_farr must reach target_farr (within 0.5)")


# ---------------------------------------------------------------------------
# 8. Descendant mouse_filter — every Control in the tree must IGNORE
# ---------------------------------------------------------------------------
# A child Control with the default MOUSE_FILTER_STOP can swallow clicks even
# when the root is IGNORE — this is exactly how the session-1 HUD-label
# regression bit us. Walk the tree and assert every descendant Control too.

func test_gauge_descendant_controls_mouse_filter_ignore() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	var offenders: Array[String] = []
	_collect_mouse_blocking_controls(gauge, offenders)
	assert_true(offenders.is_empty(),
		"Every descendant Control must MOUSE_FILTER_IGNORE; offenders: %s" % str(offenders))


# ---------------------------------------------------------------------------
# 9. Fill ratio computation
# ---------------------------------------------------------------------------
# Per kickoff §149 ("fills from 0 to FARR_TIER2_THRESHOLD"): the gauge fill
# ratio is clamp(target_farr / tier2_threshold, 0, 1). At 40 Farr the gauge
# is full; above 40 the fill stays at 1.0 and the GOLD color band carries
# the "above-Tier-2" signal, not the fill itself.

func test_fill_ratio_at_zero_is_zero() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 0.0, 0)
	var ratio: Variant = gauge.get(&"fill_ratio")
	assert_not_null(ratio, "Gauge must expose `fill_ratio` for the visual fill")
	assert_almost_eq(float(ratio), 0.0, 1e-6,
		"Farr 0 → fill_ratio 0.0")


func test_fill_ratio_at_tier2_threshold_is_one() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 40.0, 0)
	assert_almost_eq(float(gauge.get(&"fill_ratio")), 1.0, 1e-6,
		"Farr 40 (= tier2_threshold) → fill_ratio 1.0")


func test_fill_ratio_above_tier2_clamps_to_one() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 100.0, 0)
	assert_almost_eq(float(gauge.get(&"fill_ratio")), 1.0, 1e-6,
		"Farr 100 → fill_ratio clamped at 1.0; gold band signals overshoot")


func test_fill_ratio_at_midpoint_is_half() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 20.0, 0)
	assert_almost_eq(float(gauge.get(&"fill_ratio")), 0.5, 1e-6,
		"Farr 20 (half of tier2_threshold 40) → fill_ratio 0.5")


# ---------------------------------------------------------------------------
# 10. Color band classification per §4.4
# ---------------------------------------------------------------------------

func test_color_band_at_zero_is_red() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 0.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_RED,
		"Farr 0 → red band (Kaveh territory)")


func test_color_band_just_below_kaveh_threshold_is_red() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 14.99, 0)
	assert_eq(gauge.get(&"color_band"), BAND_RED,
		"Farr 14.99 (just below kaveh_trigger_threshold) → red")


func test_color_band_at_kaveh_threshold_is_dim() -> void:
	# Inclusive lower bound: exactly 15 is dim, only values < 15 are red.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 15.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_DIM,
		"Farr 15.0 (= kaveh_trigger_threshold) → dim, not red")


func test_color_band_just_below_tier2_is_dim() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 39.99, 0)
	assert_eq(gauge.get(&"color_band"), BAND_DIM,
		"Farr 39.99 (just below tier2_threshold) → dim")


func test_color_band_at_tier2_threshold_is_ivory() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 40.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_IVORY,
		"Farr 40 (= tier2_threshold) → ivory")


func test_color_band_at_default_starting_value_is_ivory() -> void:
	# 50.0 is the default starting Farr per 01_CORE_MECHANICS.md §4.1.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 50.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_IVORY,
		"Farr 50 (default starting value) → ivory")


func test_color_band_just_below_seventy_is_ivory() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 69.99, 0)
	assert_eq(gauge.get(&"color_band"), BAND_IVORY,
		"Farr 69.99 (just below gold band) → ivory")


func test_color_band_at_seventy_is_gold() -> void:
	# Spec phrasing "≥ 70": exactly 70 is gold.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, 70.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_GOLD,
		"Farr 70 → gold (≥ 70 inclusive)")


func test_color_band_at_max_is_gold() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "test", -1, Constants.FARR_MAX, 0)
	assert_eq(gauge.get(&"color_band"), BAND_GOLD,
		"Farr at FARR_MAX → gold")


# ---------------------------------------------------------------------------
# 11. Signal connection — gauge subscribes to EventBus.farr_changed at _ready
# ---------------------------------------------------------------------------

func test_gauge_connects_to_farr_changed_at_ready() -> void:
	# The gauge must register itself as a subscriber to EventBus.farr_changed
	# at _ready so the host scene doesn't have to wire it. We can't ask "is
	# this Callable connected?" without a ref, but we can count connections
	# before/after instantiation.
	var connections_before: int = EventBus.farr_changed.get_connections().size()
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	var connections_after: int = EventBus.farr_changed.get_connections().size()
	assert_eq(connections_after, connections_before + 1,
		"FarrGauge must connect itself to EventBus.farr_changed at _ready")


func test_gauge_disconnects_on_tree_exit() -> void:
	# Symmetric cleanup: when the gauge leaves the tree, the connection count
	# returns to baseline. Prevents the F2 overlay (Phase 4) from being
	# confused by ghost connections after scene teardown.
	var connections_before: int = EventBus.farr_changed.get_connections().size()
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	# Force-remove + free synchronously; add_child_autofree's queue_free is
	# async and would land after this assertion.
	gauge.get_parent().remove_child(gauge)
	gauge.free()
	var connections_after: int = EventBus.farr_changed.get_connections().size()
	assert_eq(connections_after, connections_before,
		"Tree exit must disconnect from farr_changed; no ghost connections")


# ---------------------------------------------------------------------------
# 12. Signal-to-redraw integration chain
# ---------------------------------------------------------------------------
# End-to-end: emit a farr_changed payload that crosses a band boundary, pump
# frames to let the tween settle, assert both target_farr and displayed_farr
# reflect the new value, and color_band tag flips to the new band.

func test_signal_to_band_change_integration_gold() -> void:
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	# Start the gauge in ivory by seeding 50.
	EventBus.farr_changed.emit(0.0, "seed", -1, 50.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_IVORY,
		"Precondition: seeded at 50 → ivory band")
	# Drive a crossing into gold.
	EventBus.farr_changed.emit(25.0, "cross_to_gold", -1, 75.0, 0)
	# Let the tween settle (0.25s ≈ 15 frames @ 60Hz; 30 frames is generous).
	for i in range(30):
		await get_tree().process_frame
	assert_eq(gauge.get(&"color_band"), BAND_GOLD,
		"After crossing 70, color_band must flip to gold")
	assert_almost_eq(float(gauge.get(&"displayed_farr")), 75.0, 0.5,
		"After tween settles, displayed_farr reaches farr_after (within 0.5)")


func test_signal_to_band_change_integration_red() -> void:
	# Most consequential UX cue: tanking Farr below 15 must light up red.
	var gauge: Control = _instantiate_gauge()
	if gauge == null:
		pending("farr_gauge.tscn unavailable")
		return
	EventBus.farr_changed.emit(0.0, "seed", -1, 30.0, 0)
	assert_eq(gauge.get(&"color_band"), BAND_DIM,
		"Precondition: seeded at 30 → dim band")
	EventBus.farr_changed.emit(-20.0, "cross_to_red", -1, 10.0, 0)
	for i in range(30):
		await get_tree().process_frame
	assert_eq(gauge.get(&"color_band"), BAND_RED,
		"Crossing below 15 must light the red Kaveh-warning band")
	assert_almost_eq(float(gauge.get(&"displayed_farr")), 10.0, 0.5,
		"After tween, displayed_farr reaches the post-crossing farr_after")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _instantiate_gauge() -> Control:
	var packed: PackedScene = load(GAUGE_SCENE_PATH)
	if packed == null:
		return null
	var gauge: Control = packed.instantiate() as Control
	if gauge == null:
		return null
	add_child_autofree(gauge)
	return gauge


# Recursively collect any descendant Control whose mouse_filter is not
# MOUSE_FILTER_IGNORE. Returns the offending node paths for a self-naming
# assertion message.
func _collect_mouse_blocking_controls(node: Node, out: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var c: Control = child
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append(node.get_path_to(c).get_concatenated_names())
		_collect_mouse_blocking_controls(child, out)
