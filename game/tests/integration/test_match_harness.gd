# Tests for MatchHarness + Scenarios.
#
# Contract: docs/TESTING_CONTRACT.md §3.1 + docs/SIMULATION_CONTRACT.md §6.1-6.2.
#
# These are integration-style tests: they exercise the harness API itself
# (not gameplay systems inside it). Phase 0 — unit/building spawning is stubbed.
#
# The determinism regression test (§6.2) is included here as a skeleton.
# It passes at Phase 0 because both harnesses produce identical Farr/resource
# state after 30 ticks of an empty match. It will exercise real gameplay
# correctness once Phase 1+ systems register with the tick pipeline.
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const ScenariosScript: Script = preload("res://tests/harness/scenarios.gd")


# ---------------------------------------------------------------------------
# Lifecycle helpers
# ---------------------------------------------------------------------------

var _h: Variant = null


func after_each() -> void:
	if _h != null:
		_h.teardown()
		_h = null
	SimClock.reset()
	GameState.reset()
	FarrSystem.reset()


# Helper: instantiate + start_match in one step.
# No class_name on MatchHarness (registry-race pattern, ARCHITECTURE.md §6 v0.4.0).
func _make(match_seed: int = 0, scenario: StringName = &"empty") -> Variant:
	var h: Variant = MatchHarnessScript.new()
	h.start_match(match_seed, scenario)
	return h


# ---------------------------------------------------------------------------
# MatchHarness.start_match + teardown
# ---------------------------------------------------------------------------

func test_create_returns_a_harness_instance() -> void:
	_h = _make(0, &"empty")
	assert_not_null(_h, "start_match must produce a non-null harness")


func test_create_sets_gamestate_to_playing() -> void:
	_h = _make(0, &"empty")
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_PLAYING,
		"GameState must be PLAYING after harness creation")


func test_create_resets_simclock_to_tick_zero() -> void:
	SimClock._test_run_tick()  # pre-tick to simulate prior state
	_h = _make(0, &"empty")
	assert_eq(SimClock.tick, 0, "SimClock must be reset to 0 on harness creation")


func test_teardown_resets_simclock() -> void:
	_h = _make(0, &"empty")
	_h.advance_ticks(5)
	_h.teardown()
	assert_eq(SimClock.tick, 0, "teardown must reset SimClock to 0")
	_h = null


func test_teardown_resets_gamestate_to_lobby() -> void:
	_h = _make(0, &"empty")
	_h.teardown()
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_LOBBY,
		"teardown must restore GameState to LOBBY")
	_h = null


func test_teardown_resets_farr_to_default() -> void:
	_h = _make(0, &"empty")
	_h._test_set_farr(30.0)
	_h.teardown()
	_h = null
	# After teardown + reset, FarrSystem should be back at 50.0 (spec default).
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"FarrSystem must be reset after teardown")


# ---------------------------------------------------------------------------
# advance_ticks
# ---------------------------------------------------------------------------

func test_advance_ticks_increments_simclock() -> void:
	_h = _make(0, &"empty")
	_h.advance_ticks(10)
	assert_eq(SimClock.tick, 10, "advance_ticks(10) must advance SimClock by 10")


func test_advance_ticks_zero_is_a_noop() -> void:
	_h = _make(0, &"empty")
	_h.advance_ticks(0)
	assert_eq(SimClock.tick, 0, "advance_ticks(0) must not move SimClock")


# ---------------------------------------------------------------------------
# get_farr
# ---------------------------------------------------------------------------

func test_get_farr_returns_50_in_empty_scenario() -> void:
	_h = _make(0, &"empty")
	assert_almost_eq(_h.get_farr(), 50.0, 1e-4,
		"empty scenario must start with Farr 50.0 (spec default)")


# ---------------------------------------------------------------------------
# _test_set_farr
# ---------------------------------------------------------------------------

func test_test_set_farr_changes_farr_value() -> void:
	_h = _make(0, &"empty")
	_h._test_set_farr(30.0)
	assert_almost_eq(_h.get_farr(), 30.0, 1e-4,
		"_test_set_farr must override Farr to the requested value")


func test_test_set_farr_emits_farr_changed_signal() -> void:
	_h = _make(0, &"empty")
	var captured: Array = []
	var _listener: Callable = func(amt, _reason, _src, _after, _tick): captured.append(amt)
	EventBus.farr_changed.connect(_listener)
	_h._test_set_farr(40.0)
	EventBus.farr_changed.disconnect(_listener)
	assert_eq(captured.size(), 1,
		"_test_set_farr must emit exactly one farr_changed signal")
	assert_almost_eq(captured[0], -10.0, 1e-4,
		"farr_changed amount must reflect the delta from 50.0 to 40.0")


func test_test_set_farr_clamps_to_valid_range() -> void:
	_h = _make(0, &"empty")
	_h._test_set_farr(200.0)
	assert_almost_eq(_h.get_farr(), 100.0, 1e-4,
		"_test_set_farr must clamp to max Farr (100.0)")
	_h._test_set_farr(-50.0)
	assert_almost_eq(_h.get_farr(), 0.0, 1e-4,
		"_test_set_farr must clamp to min Farr (0.0)")


# ---------------------------------------------------------------------------
# set_resources + get_resources
# ---------------------------------------------------------------------------

func test_set_resources_and_get_resources_round_trip() -> void:
	_h = _make(0, &"empty")
	_h.set_resources(Constants.TEAM_IRAN, 300, 120)
	var res: Dictionary = _h.get_resources(Constants.TEAM_IRAN)
	assert_eq(res.coin, 300, "coin must reflect set_resources value")
	assert_eq(res.grain, 120, "grain must reflect set_resources value")


func test_get_resources_default_matches_scenario_empty() -> void:
	_h = _make(0, &"empty")
	var res: Dictionary = _h.get_resources(Constants.TEAM_IRAN)
	assert_eq(res.coin, 150, "empty scenario default coin is 150")
	assert_eq(res.grain, 50, "empty scenario default grain is 50")


func test_set_resources_does_not_affect_other_team() -> void:
	_h = _make(0, &"empty")
	_h.set_resources(Constants.TEAM_IRAN, 500, 500)
	var turan: Dictionary = _h.get_resources(Constants.TEAM_TURAN)
	assert_eq(turan.coin, 150, "Turan coin must be unaffected by Iran set_resources")
	assert_eq(turan.grain, 50, "Turan grain must be unaffected by Iran set_resources")


# ---------------------------------------------------------------------------
# snapshot — primitive-only flat Dictionary
# ---------------------------------------------------------------------------

func test_snapshot_returns_correct_keys() -> void:
	_h = _make(0, &"empty")
	var snap: Dictionary = _h.snapshot()
	assert_true(snap.has("tick"))
	assert_true(snap.has("farr"))
	assert_true(snap.has("coin_iran"))
	assert_true(snap.has("grain_iran"))
	assert_true(snap.has("coin_turan"))
	assert_true(snap.has("grain_turan"))
	assert_true(snap.has("unit_count_iran"))
	assert_true(snap.has("unit_count_turan"))


func test_snapshot_tick_matches_simclock() -> void:
	_h = _make(0, &"empty")
	_h.advance_ticks(7)
	var snap: Dictionary = _h.snapshot()
	assert_eq(snap.tick, 7, "snapshot tick must match SimClock.tick")


func test_snapshot_farr_matches_get_farr() -> void:
	_h = _make(0, &"empty")
	var snap: Dictionary = _h.snapshot()
	assert_almost_eq(snap.farr, _h.get_farr(), 1e-6,
		"snapshot.farr must equal get_farr()")


func test_snapshot_coin_reflects_set_resources() -> void:
	_h = _make(0, &"empty")
	_h.set_resources(Constants.TEAM_IRAN, 999, 0)
	var snap: Dictionary = _h.snapshot()
	assert_eq(snap.coin_iran, 999)


# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

func test_scenario_kaveh_edge_pre_sets_farr() -> void:
	_h = _make(0, &"kaveh_edge")
	assert_almost_eq(_h.get_farr(), 16.0, 1e-4,
		"kaveh_edge scenario must set Farr to 16.0")


func test_scenario_rich_sets_high_resources() -> void:
	_h = _make(0, &"rich")
	var res: Dictionary = _h.get_resources(Constants.TEAM_IRAN)
	assert_eq(res.coin, 1000)
	assert_eq(res.grain, 1000)


func test_scenario_starved_sets_zero_resources() -> void:
	_h = _make(0, &"starved")
	var res: Dictionary = _h.get_resources(Constants.TEAM_IRAN)
	assert_eq(res.coin, 0)
	assert_eq(res.grain, 0)


func test_scenarios_catalog_has_required_keys() -> void:
	assert_true(ScenariosScript.CATALOG.has(&"empty"))
	assert_true(ScenariosScript.CATALOG.has(&"basic_combat"))
	assert_true(ScenariosScript.CATALOG.has(&"kaveh_edge"))


# ---------------------------------------------------------------------------
# Determinism regression test skeleton — Sim Contract §6.2
# ---------------------------------------------------------------------------

func test_same_seed_same_snapshot_after_30_ticks() -> void:
	# Two independent harnesses with the same seed and scenario must produce
	# identical snapshots after the same number of ticks. At Phase 0, the only
	# live state is Farr and harness-local resources — both are deterministic.
	# This test grows more meaningful as Phase 1+ systems register with the
	# tick pipeline and generate real gameplay events.
	var h_a: Variant = _make(42, &"empty")
	var h_b: Variant = _make(42, &"empty")

	h_a.advance_ticks(30)
	h_b.advance_ticks(30)

	var snap_a: Dictionary = h_a.snapshot()
	var snap_b: Dictionary = h_b.snapshot()

	assert_eq(snap_a, snap_b,
		"Two harnesses with identical seed + scenario must produce identical snapshots")

	h_a.teardown()
	h_b.teardown()
	_h = null  # prevent double teardown in after_each
