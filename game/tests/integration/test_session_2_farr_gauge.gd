# Integration tests — FarrGauge listener round-trip.
#
# Wave 3 (qa-engineer). Locks in wave-1C (FarrGauge) behaviors.
#
# Contract: docs/02c_PHASE_1_SESSION_2_KICKOFF.md §3 flow 4.
# Related:  docs/SIMULATION_CONTRACT.md §1.5 (UI off-tick reads).
#
# Strategy:
#   - Load farr_gauge.tscn and add to scene tree.
#   - Use FarrSystem.apply_farr_change (inside a SimClock tick) or
#     EventBus.farr_changed.emit directly (off-tick) to signal the gauge.
#   - Verify target_farr and color_band update correctly on signal receipt.
#
# Sim Contract §1.5: the gauge's _on_farr_changed handler fires off-tick (it's
# a UI subscriber). Tests can emit farr_changed directly and read target_farr
# immediately — no tick advance required for the listener round-trip.
# The tween animates displayed_farr asynchronously; tests assert target_farr
# (the post-signal commanded value) rather than displayed_farr.

extends GutTest


const FarrGaugeScene: PackedScene = preload("res://scenes/ui/farr_gauge.tscn")


var _gauge: Variant = null


func before_each() -> void:
	SimClock.reset()
	FarrSystem.reset()


func after_each() -> void:
	if _gauge != null and is_instance_valid(_gauge):
		_gauge.queue_free()
	_gauge = null
	SimClock.reset()
	FarrSystem.reset()


func _load_gauge() -> void:
	_gauge = FarrGaugeScene.instantiate()
	add_child_autofree(_gauge)


# ---------------------------------------------------------------------------
# 1. Gauge subscribes to farr_changed; target_farr reflects change
# ---------------------------------------------------------------------------

func test_farr_changed_signal_updates_target_farr() -> void:
	_load_gauge()
	# FarrSystem starts at 50.0. Emit a +10 change to 60.0.
	EventBus.farr_changed.emit(10.0, "test", -1, 60.0, SimClock.tick)

	assert_almost_eq(_gauge.target_farr, 60.0, 1e-4,
		"target_farr must reflect farr_after from farr_changed signal")


# ---------------------------------------------------------------------------
# 2. color_band: red below kaveh_trigger_threshold (< 15)
# ---------------------------------------------------------------------------

func test_color_band_red_below_kaveh_threshold() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(-45.0, "drain", -1, 5.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_RED,
		"Farr=5 must produce BAND_RED (< kaveh_trigger_threshold=15)")


# ---------------------------------------------------------------------------
# 3. color_band: dim between kaveh and tier2 thresholds (15..39)
# ---------------------------------------------------------------------------

func test_color_band_dim_between_kaveh_and_tier2() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(-25.0, "drain", -1, 25.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_DIM,
		"Farr=25 must produce BAND_DIM (15 <= 25 < 40)")


# ---------------------------------------------------------------------------
# 4. color_band: ivory at tier2 threshold (40..69)
# ---------------------------------------------------------------------------

func test_color_band_ivory_at_tier2_threshold() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(-10.0, "drain", -1, 40.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_IVORY,
		"Farr=40 must produce BAND_IVORY (exactly at tier2_threshold)")


# ---------------------------------------------------------------------------
# 5. color_band: ivory in 40..69 range
# ---------------------------------------------------------------------------

func test_color_band_ivory_in_40_to_69() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(5.0, "gain", -1, 55.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_IVORY,
		"Farr=55 must produce BAND_IVORY (40 <= 55 < 70)")


# ---------------------------------------------------------------------------
# 6. color_band: gold at 70+
# ---------------------------------------------------------------------------

func test_color_band_gold_at_70_plus() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(30.0, "gain", -1, 80.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_GOLD,
		"Farr=80 must produce BAND_GOLD (>= 70)")


# ---------------------------------------------------------------------------
# 7. color_band: inclusive boundary at exactly 15 → dim (not red)
# ---------------------------------------------------------------------------

func test_color_band_boundary_at_15_is_dim() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(-35.0, "drain", -1, 15.0, SimClock.tick)
	assert_eq(_gauge.color_band, _gauge.BAND_DIM,
		"Farr=15 exactly must produce BAND_DIM (inclusive lower bound of dim range)")


# ---------------------------------------------------------------------------
# 8. gauge seeded from FarrSystem at _ready (not default 50.0 if system differs)
# ---------------------------------------------------------------------------

func test_gauge_seeded_from_farr_system_at_ready() -> void:
	# Set FarrSystem to a non-default value before loading gauge.
	FarrSystem._farr_x100 = 3000  # Farr = 30.0
	_load_gauge()
	assert_almost_eq(_gauge.target_farr, 30.0, 0.1,
		"gauge must read FarrSystem.value_farr at _ready (not hardcoded 50.0)")


# ---------------------------------------------------------------------------
# 9. Signal arriving before gauge is in tree must not crash (defensive autoload)
# ---------------------------------------------------------------------------

func test_signal_before_gauge_in_tree_no_crash() -> void:
	# Emit farr_changed with no gauge in tree — must not crash.
	# FarrSystem should reflect the new value regardless.
	var initial_farr_x100: int = FarrSystem._farr_x100
	EventBus.farr_changed.emit(-5.0, "test", -1, 45.0, SimClock.tick)
	# Signal emitted without gauge — FarrSystem state is unchanged by the signal.
	assert_eq(FarrSystem._farr_x100, initial_farr_x100,
		"emitting farr_changed with no gauge in tree must not alter FarrSystem state")


# ---------------------------------------------------------------------------
# 10. Multiple sequential changes accumulate correctly
# ---------------------------------------------------------------------------

func test_multiple_farr_changes_accumulate_in_target() -> void:
	_load_gauge()
	EventBus.farr_changed.emit(-10.0, "drain1", -1, 40.0, SimClock.tick)
	assert_almost_eq(_gauge.target_farr, 40.0, 1e-4)
	EventBus.farr_changed.emit(-10.0, "drain2", -1, 30.0, SimClock.tick)
	assert_almost_eq(_gauge.target_farr, 30.0, 1e-4,
		"second farr_changed must update target_farr to the new farr_after")
