extends GutTest
##
## Unit tests for MatchHarness — the deterministic test fixture.
##
## Per docs/TESTING_CONTRACT.md §3.1: MatchHarness is the only approved way to
## create a deterministic mini-match in a GUT test. These tests verify the
## harness API itself works correctly before integration tests rely on it.
##
## Test categories:
##   - start_match / _setup resets all autoloads
##   - advance_ticks advances SimClock.tick by exactly n
##   - snapshot() returns a flat primitive-only Dict with all required keys
##   - _test_set_farr updates Farr correctly AND emits farr_changed
##   - teardown() cleans up all state
##   - MockPathScheduler is injected into PathSchedulerService
##   - Same seed produces identical snapshots (mini determinism test)
##
## Usage pattern (class_name removed from harness; preload the script):
##   const _H := preload("res://tests/harness/match_harness.gd")
##   var h := _H.new(); h.start_match(seed, scenario)
##   h.teardown()

# Preloaded script ref — no class_name on MatchHarness (registry race pattern,
# docs/ARCHITECTURE.md §6 v0.4.0). Callers use _MH.new() then h.start_match().
const _MH: Script = preload("res://tests/harness/match_harness.gd")

# Per-test harness instance. Created in each test that needs one.
var _h: Variant = null

# Signal capture list for farr_changed events.
var _farr_events: Array = []

func _on_farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int) -> void:
	_farr_events.append({
		"amount": amount,
		"reason": reason,
		"source_unit_id": source_unit_id,
		"farr_after": farr_after,
		"tick": tick,
	})


func before_each() -> void:
	_farr_events = []
	# Do NOT create a harness here — each test creates its own to isolate
	# the start_match / teardown lifecycle.


func after_each() -> void:
	# Ensure any harness instance from the test is torn down.
	if _h != null:
		_h.teardown()
		_h = null
	# Disconnect signal if connected.
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)
	# Reset autoloads to safe state regardless of what the test did.
	SimClock.reset()
	GameState.reset()
	PathSchedulerService.reset()


# Helper: create + start_match in one step.
func _make_harness(match_seed: int = 0, scenario: StringName = &"empty") -> Variant:
	var h: Variant = _MH.new()
	h.start_match(match_seed, scenario)
	return h


# ---------------------------------------------------------------------------
# start_match / _setup tests
# ---------------------------------------------------------------------------

func test_start_match_resets_sim_clock_tick_to_zero() -> void:
	# Dirty the clock first, then verify the harness resets it.
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	assert_eq(SimClock.tick, 2, "Pre-condition: clock is at tick 2")

	_h = _make_harness(0, &"empty")
	assert_eq(SimClock.tick, 0, "start_match must reset SimClock.tick to 0")


func test_start_match_sets_game_state_to_playing() -> void:
	_h = _make_harness(0, &"empty")
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_PLAYING,
		"start_match must set GameState.match_phase to PLAYING")


func test_start_match_resets_game_state_winner() -> void:
	# Dirty GameState with a winner from a prior "match".
	GameState.match_phase = Constants.MATCH_PHASE_PLAYING
	GameState.winner_team = Constants.TEAM_TURAN

	_h = _make_harness(0, &"empty")
	assert_eq(GameState.winner_team, Constants.OUTCOME_NONE,
		"start_match must clear winner_team to OUTCOME_NONE")


func test_start_match_injects_mock_path_scheduler() -> void:
	_h = _make_harness(0, &"empty")
	assert_true(PathSchedulerService.has_scheduler(),
		"PathSchedulerService must have a scheduler after start_match")


func test_start_match_resets_farr_to_starting_value() -> void:
	# Dirty Farr by writing directly (off-tick OK here since we're not using
	# apply_farr_change, which would assert on-tick).
	FarrSystem._farr_x100 = 9999

	_h = _make_harness(0, &"empty")
	# Starting value from balance.tres is 50.0; fallback if file absent is also 50.0.
	assert_almost_eq(FarrSystem.value_farr, 50.0, 0.01,
		"start_match must reset Farr to the starting_value (50.0)")


func test_start_match_captures_match_start_tick() -> void:
	_h = _make_harness(0, &"empty")
	# After _setup, GameState.start_match was called at SimClock.tick == 0.
	assert_eq(GameState.match_start_tick, 0,
		"match_start_tick should be 0 after start_match at tick 0")


# ---------------------------------------------------------------------------
# advance_ticks tests
# ---------------------------------------------------------------------------

func test_advance_ticks_increments_sim_clock_by_n() -> void:
	_h = _make_harness(0, &"empty")
	var tick_before: int = SimClock.tick
	_h.advance_ticks(10)
	assert_eq(SimClock.tick, tick_before + 10,
		"advance_ticks(10) must increment SimClock.tick by exactly 10")


func test_advance_ticks_zero_does_not_change_tick() -> void:
	_h = _make_harness(0, &"empty")
	var tick_before: int = SimClock.tick
	_h.advance_ticks(0)
	assert_eq(SimClock.tick, tick_before,
		"advance_ticks(0) must not change the tick")


func test_advance_ticks_uses_sim_phase_signals() -> void:
	# Verify that sim_phase signals are emitted (i.e., the pipeline runs).
	_h = _make_harness(0, &"empty")
	var phases_seen: Array[StringName] = []
	var capture: Callable = func(phase: StringName, _tick: int) -> void:
		phases_seen.append(phase)
	EventBus.sim_phase.connect(capture)
	_h.advance_ticks(1)
	EventBus.sim_phase.disconnect(capture)
	# Seven phases per tick.
	assert_eq(phases_seen.size(), 7,
		"advance_ticks(1) must emit 7 sim_phase signals (one per pipeline phase)")
	# First and last phases.
	assert_eq(phases_seen[0], &"input", "First phase must be 'input'")
	assert_eq(phases_seen[6], &"cleanup", "Last phase must be 'cleanup'")


# ---------------------------------------------------------------------------
# snapshot() tests
# ---------------------------------------------------------------------------

func test_snapshot_returns_dict_with_all_required_keys() -> void:
	_h = _make_harness(0, &"empty")
	var snap: Dictionary = _h.snapshot()

	assert_true(snap.has("tick"), "snapshot must have 'tick'")
	assert_true(snap.has("farr"), "snapshot must have 'farr'")
	assert_true(snap.has("coin_iran"), "snapshot must have 'coin_iran'")
	assert_true(snap.has("grain_iran"), "snapshot must have 'grain_iran'")
	assert_true(snap.has("coin_turan"), "snapshot must have 'coin_turan'")
	assert_true(snap.has("grain_turan"), "snapshot must have 'grain_turan'")
	assert_true(snap.has("unit_count_iran"), "snapshot must have 'unit_count_iran'")
	assert_true(snap.has("unit_count_turan"), "snapshot must have 'unit_count_turan'")


func test_snapshot_values_are_primitives_only() -> void:
	# Testing Contract §3.1: no nested Dicts, no Node refs.
	_h = _make_harness(0, &"empty")
	var snap: Dictionary = _h.snapshot()
	for key: String in snap:
		var val: Variant = snap[key]
		var t: int = typeof(val)
		var is_primitive: bool = (
			t == TYPE_INT or t == TYPE_FLOAT or
			t == TYPE_STRING or t == TYPE_STRING_NAME or
			t == TYPE_BOOL
		)
		assert_true(is_primitive,
			"snapshot key '%s' must be a primitive (got type %d)" % [key, t])


func test_snapshot_tick_reflects_advance_ticks() -> void:
	_h = _make_harness(0, &"empty")
	_h.advance_ticks(15)
	var snap: Dictionary = _h.snapshot()
	# "empty" scenario has no farr override so no extra ticks in _setup.
	assert_eq(snap["tick"], 15, "snapshot['tick'] must reflect SimClock.tick")


func test_snapshot_farr_reflects_current_farr() -> void:
	_h = _make_harness(0, &"empty")
	var snap: Dictionary = _h.snapshot()
	assert_almost_eq(float(snap["farr"]), FarrSystem.value_farr, 1e-6,
		"snapshot['farr'] must match FarrSystem.value_farr")


func test_snapshot_resources_reflect_set_resources() -> void:
	_h = _make_harness(0, &"empty")
	_h.set_resources(Constants.TEAM_IRAN, 300, 75)
	var snap: Dictionary = _h.snapshot()
	assert_eq(snap["coin_iran"], 300, "snapshot['coin_iran'] must reflect set_resources")
	assert_eq(snap["grain_iran"], 75, "snapshot['grain_iran'] must reflect set_resources")


# ---------------------------------------------------------------------------
# _test_set_farr tests
# ---------------------------------------------------------------------------

func test_test_set_farr_updates_farr_value() -> void:
	_h = _make_harness(0, &"empty")
	_h._test_set_farr(37.5)
	assert_almost_eq(_h.get_farr(), 37.5, 1e-4,
		"_test_set_farr must update FarrSystem to the target value")


func test_test_set_farr_emits_farr_changed_event() -> void:
	_h = _make_harness(0, &"empty")
	EventBus.farr_changed.connect(_on_farr_changed)

	_h._test_set_farr(70.0)

	assert_true(_farr_events.size() >= 1,
		"_test_set_farr must emit at least one farr_changed event")
	var last_ev: Dictionary = _farr_events[-1]
	assert_eq(last_ev["reason"], &"test_set",
		"farr_changed emitted by _test_set_farr must carry reason 'test_set'")
	assert_almost_eq(last_ev["farr_after"], 70.0, 1e-4,
		"farr_changed emitted by _test_set_farr must carry the new value")


func test_test_set_farr_clamps_to_zero() -> void:
	_h = _make_harness(0, &"empty")
	_h._test_set_farr(-999.0)
	assert_almost_eq(_h.get_farr(), 0.0, 1e-4,
		"_test_set_farr(-999) must clamp to 0.0")


func test_test_set_farr_clamps_to_one_hundred() -> void:
	_h = _make_harness(0, &"empty")
	_h._test_set_farr(9999.0)
	assert_almost_eq(_h.get_farr(), 100.0, 1e-4,
		"_test_set_farr(9999) must clamp to 100.0")


# ---------------------------------------------------------------------------
# teardown tests
# ---------------------------------------------------------------------------

func test_teardown_resets_game_state_to_lobby() -> void:
	_h = _make_harness(0, &"empty")
	_h.teardown()
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_LOBBY,
		"teardown() must reset GameState.match_phase to LOBBY")
	_h = null  # already torn down; prevent after_each double-teardown


func test_teardown_clears_path_scheduler() -> void:
	_h = _make_harness(0, &"empty")
	_h.teardown()
	assert_false(PathSchedulerService.has_scheduler(),
		"teardown() must clear PathSchedulerService scheduler")
	_h = null  # already torn down


func test_teardown_resets_sim_clock() -> void:
	_h = _make_harness(0, &"empty")
	_h.advance_ticks(50)
	_h.teardown()
	assert_eq(SimClock.tick, 0,
		"teardown() must reset SimClock.tick to 0")
	_h = null  # already torn down


func test_subsequent_start_match_does_not_see_prior_state() -> void:
	# Harness 1: advance ticks and set non-default resources.
	var h1: Variant = _make_harness(0, &"empty")
	h1.advance_ticks(20)
	h1.set_resources(Constants.TEAM_IRAN, 999, 888)
	h1.teardown()

	# Harness 2: fresh instance, same scenario — must start clean.
	var h2: Variant = _make_harness(0, &"empty")
	var snap: Dictionary = h2.snapshot()
	# Tick should be 0, not 20.
	assert_eq(snap["tick"], 0, "New harness after teardown must start at tick 0")
	# Resources should be defaults, not 999.
	assert_true(snap["coin_iran"] < 999,
		"New harness after teardown must have default resources, not prior harness's values")
	h2.teardown()


# ---------------------------------------------------------------------------
# Determinism mini-test (same seed → same snapshot)
# ---------------------------------------------------------------------------

func test_same_seed_produces_identical_snapshots() -> void:
	var h1: Variant = _make_harness(12345, &"empty")
	h1.advance_ticks(30)
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	var h2: Variant = _make_harness(12345, &"empty")
	h2.advance_ticks(30)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	assert_eq(snap1, snap2,
		"Two harness instances with the same seed must produce identical snapshots "
		+ "after the same advance_ticks call")
