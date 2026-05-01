# Tests for GameState autoload.
#
# Contract: 02_IMPLEMENTATION_PLAN.md §2 (Phase 0). Match phase lifecycle
# (lobby → playing → ended), winner registration, match_start_tick capture,
# match-relative time reads.
extends GutTest


func before_each() -> void:
	# Pristine SimClock and GameState for each test. Match-relative reads
	# depend on both; resetting both keeps tests isolated.
	SimClock.reset()
	GameState.reset()


func after_each() -> void:
	SimClock.reset()
	GameState.reset()


# -- Initial state -----------------------------------------------------------

func test_initial_state_is_lobby() -> void:
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_LOBBY)
	assert_eq(GameState.winner_team, Constants.OUTCOME_NONE)
	assert_eq(GameState.match_start_tick, -1, "Sentinel: no match has started")
	assert_eq(GameState.player_team, Constants.TEAM_IRAN)


func test_match_tick_zero_before_match_starts() -> void:
	# match_tick() must return 0 (not -1, not crash) when match_start_tick is
	# the sentinel.
	assert_eq(GameState.match_tick(), 0)
	assert_almost_eq(GameState.match_time(), 0.0, 1e-6)


# -- start_match transitions phase ------------------------------------------

func test_start_match_flips_phase_and_records_tick() -> void:
	# Advance SimClock so match_start_tick has a non-zero capture target.
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	assert_eq(SimClock.tick, 3)
	GameState.start_match()
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_PLAYING)
	assert_eq(GameState.match_start_tick, 3,
		"match_start_tick captures SimClock.tick at start_match")
	assert_eq(GameState.winner_team, Constants.OUTCOME_NONE,
		"Winner stays unset during PLAYING")


func test_start_match_accepts_team_override() -> void:
	GameState.start_match(Constants.TEAM_TURAN)
	assert_eq(GameState.player_team, Constants.TEAM_TURAN)


func test_start_match_when_already_playing_is_noop() -> void:
	# Run a few ticks, start a match, then try to re-start — match_start_tick
	# must NOT change (would corrupt match-relative time reads).
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	GameState.start_match()
	var captured := GameState.match_start_tick
	SimClock._test_run_tick()
	GameState.start_match()
	assert_eq(GameState.match_start_tick, captured,
		"Re-entering start_match must not overwrite match_start_tick")


# -- match_tick math ---------------------------------------------------------

func test_match_tick_returns_relative_offset() -> void:
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	GameState.start_match()    # match_start_tick = 2
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	assert_eq(GameState.match_tick(), 3, "5 - 2 = 3 ticks since match start")
	assert_almost_eq(GameState.match_time(), 3.0 * SimClock.SIM_DT, 1e-6)


# -- end_match logic ---------------------------------------------------------

func test_end_match_records_winner_and_flips_phase() -> void:
	GameState.start_match()
	GameState.end_match(Constants.OUTCOME_IRAN_WIN)
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_ENDED)
	assert_eq(GameState.winner_team, Constants.OUTCOME_IRAN_WIN)


func test_end_match_supports_draw() -> void:
	GameState.start_match()
	GameState.end_match(Constants.OUTCOME_NONE)
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_ENDED)
	assert_eq(GameState.winner_team, Constants.OUTCOME_NONE,
		"Draw outcome leaves winner unset")


func test_end_match_outside_playing_is_noop() -> void:
	# Calling end_match in LOBBY (no start_match yet) must not flip the phase
	# to ENDED — it would skip the playing phase altogether.
	GameState.end_match(Constants.OUTCOME_IRAN_WIN)
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_LOBBY,
		"end_match without start_match must be ignored")


# -- reset() -----------------------------------------------------------------

func test_reset_returns_to_lobby() -> void:
	GameState.start_match(Constants.TEAM_TURAN)
	GameState.end_match(Constants.OUTCOME_IRAN_WIN)
	GameState.reset()
	assert_eq(GameState.match_phase, Constants.MATCH_PHASE_LOBBY)
	assert_eq(GameState.winner_team, Constants.OUTCOME_NONE)
	assert_eq(GameState.match_start_tick, -1)
	assert_eq(GameState.player_team, Constants.TEAM_IRAN)
