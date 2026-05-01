extends Node
##
## GameState — match-level state registry.
##
## Per 02_IMPLEMENTATION_PLAN.md §2 (Phase 0) and the Constants/BalanceData
## split (TESTING_CONTRACT §1.1): GameState holds the "what match are we in,
## who's playing" pieces of runtime state. Tunable numbers live in
## BalanceData; structural keys live in Constants. GameState holds neither —
## it tracks the current match's lifecycle.
##
## Lifecycle: lobby → playing → ended. Match start records the tick on
## SimClock so that match-relative time reads as `SimClock.tick -
## GameState.match_start_tick`. Winner is set when a match ends; before that,
## `winner_team == Constants.OUTCOME_NONE`.
##
## Kept deliberately small. Complex match metadata (seed, scenario, map id)
## belongs on a higher-level MatchSession Resource we'll introduce when the
## menu→match flow lands (Phase 8). Phase 0 needs only what the foundational
## subsystems and tests require.

# === Match phase ============================================================
# One of Constants.MATCH_PHASE_LOBBY / MATCH_PHASE_PLAYING / MATCH_PHASE_ENDED.
# StringName so log lines and signal payloads are self-describing.
var match_phase: StringName = Constants.MATCH_PHASE_LOBBY

# === Winner =================================================================
# Constants.OUTCOME_NONE while not yet decided. Set on end_match().
var winner_team: int = Constants.OUTCOME_NONE

# === Match-relative time ====================================================
# SimClock.tick at the moment start_match() ran. Match-relative time is the
# subtraction (SimClock.tick - match_start_tick). -1 sentinel means "no match
# has started since boot/last reset."
var match_start_tick: int = -1

# === Player team ============================================================
# Which team the human player controls in this match. MVP is Iran vs Turan;
# default to Iran (the protagonist faction). Mutable so AI-vs-AI sim harness
# can override before match start.
var player_team: int = Constants.TEAM_IRAN


## Begin a match. Records the SimClock tick as match_start_tick, flips phase
## to PLAYING, clears any prior winner. Player team can be overridden via
## the optional argument; defaults to Iran.
##
## Idempotency: if the match is already PLAYING, this is a no-op (caller
## probably re-entered start_match by accident; resetting match_start_tick
## mid-match would corrupt match-relative time reads).
func start_match(team: int = Constants.TEAM_IRAN) -> void:
	if match_phase == Constants.MATCH_PHASE_PLAYING:
		push_warning("GameState.start_match called while already PLAYING — ignored")
		return
	match_phase = Constants.MATCH_PHASE_PLAYING
	match_start_tick = SimClock.tick
	winner_team = Constants.OUTCOME_NONE
	player_team = team


## End the match. Sets the winner and flips phase to ENDED. The winner
## argument is the Constants.OUTCOME_* value (which is also the team id, or
## OUTCOME_NONE for a draw).
func end_match(winner: int) -> void:
	if match_phase != Constants.MATCH_PHASE_PLAYING:
		push_warning("GameState.end_match called outside PLAYING phase — ignored")
		return
	match_phase = Constants.MATCH_PHASE_ENDED
	winner_team = winner


## Match-relative tick. Returns 0 if no match has started; else the number of
## ticks since start_match() recorded match_start_tick.
func match_tick() -> int:
	if match_start_tick < 0:
		return 0
	return SimClock.tick - match_start_tick


## Match-relative seconds. Convenience for HUD/telemetry.
func match_time() -> float:
	return float(match_tick()) * SimClock.SIM_DT


## Test-only: reset to lobby state. Used by GUT before_each / after_each so
## tests don't leak state across cases. Mirrors the pattern on SimClock /
## TimeProvider (Sim Contract §6.1).
func reset() -> void:
	match_phase = Constants.MATCH_PHASE_LOBBY
	winner_team = Constants.OUTCOME_NONE
	match_start_tick = -1
	player_team = Constants.TEAM_IRAN
