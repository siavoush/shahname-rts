# Integration test — HeadlessMatchRunner timeout boundary (tick-driven).
#
# Per 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §7 Track 2 fourth bullet:
# "test_headless_runner_timeout.gd — synthesize a sim that never terminates,
#  verify runner times out at 60,000 ticks + emits outcome=stalemate."
#
# DET-3 (result-format v1.1.0): the timeout check moved from _process
# (frame-dependent — stalemate records were not run-reproducible under
# variable frame pacing) to the sim_phase &"cleanup" handler. These tests
# drive the REAL wiring path: _subscribe_signals connects _on_sim_phase to
# EventBus.sim_phase, and SimClock._test_run_tick emits the canonical phase
# sequence — so advancing the clock exercises the boundary exactly as a
# live run would (BUG-D1 wiring-path discipline).
#
# Per 02t §3 Q2 (RESOLVED v1.0.1): timeout = 60,000 ticks (33 min @ 30Hz).
# 60K is a lot of ticks to count up to in a unit test; these tests use
# smaller _timeout_ticks values so the boundary itself is exercised in
# both passing and failing positions WITHOUT advancing SimClock to 60K.
extends GutTest


const RunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


var _runner: Variant = null


func before_each() -> void:
	SimClock.reset()
	TuranController.reset()
	_runner = RunnerScript.new()
	_runner.set(&"_test_skip_emit", true)
	_runner.call(&"_subscribe_signals")


func after_each() -> void:
	if _runner != null:
		_runner.call(&"_disconnect_signals")
		_runner.free()
		_runner = null
	SimClock.reset()
	TuranController.reset()


# Helper: advance SimClock by n ticks using the canonical Sim Contract §6.1
# test path (same as MatchHarness.advance_ticks). The runner's cleanup-phase
# handler fires on every advanced tick.
func _advance_ticks(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# ---------------------------------------------------------------------------
# Default timeout configuration
# ---------------------------------------------------------------------------

func test_default_timeout_ticks_is_60000_per_brief_q2() -> void:
	# Per 02t §3 Q2 RESOLVED v1.0.1: 60,000 ticks (33 min @ 30Hz).
	assert_eq(int(_runner.get(&"_timeout_ticks")), 60000,
		"runner default timeout must be 60,000 ticks per brief Q2")


# ---------------------------------------------------------------------------
# Below timeout: cleanup-phase check is a pass-through (no field flip)
# ---------------------------------------------------------------------------

func test_cleanup_below_timeout_does_not_flip_outcome() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(50)  # cleanup fired at ticks 0..49, all below threshold
	var pre_outcome: String = String(_runner.get(&"_outcome"))
	# Explicit boundary probe at the current tick (50 < 100).
	EventBus.sim_phase.emit(Constants.PHASE_CLEANUP, SimClock.tick)
	assert_eq(_runner.get(&"_outcome"), pre_outcome,
		"cleanup check below timeout must NOT flip outcome")
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"cleanup check below timeout must NOT set _timeout_triggered")


# ---------------------------------------------------------------------------
# At timeout boundary: cleanup-phase check flips outcome=stalemate
# ---------------------------------------------------------------------------

func test_cleanup_at_timeout_flips_to_stalemate() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	# Advance to ONE BELOW the boundary, then verify nothing flipped, then
	# cross it. Cleanup during the run of tick N sees SimClock.tick == N,
	# so the flip happens during the tick where tick - start == timeout.
	_advance_ticks(100)  # ran ticks 0..99 — max delta seen by cleanup = 99
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"tick 99 cleanup is below the 100-tick boundary — no flip yet")
	_advance_ticks(1)  # runs tick 100 — cleanup sees delta 100 >= 100
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"cleanup at timeout boundary must set _timeout_triggered=true")
	assert_eq(_runner.get(&"_outcome"), "stalemate",
		"cleanup at timeout boundary must flip outcome to stalemate")
	assert_eq(int(_runner.get(&"_winner_team")), -1,
		"cleanup at timeout boundary must set winner_team=-1 (stalemate)")
	assert_true(bool(_runner.get(&"_match_ended")),
		"timeout must seal the match (no grace for stalemates)")


# ---------------------------------------------------------------------------
# DET-3 run-reproducibility pin: the recorded duration is the BOUNDARY tick,
# regardless of how far the clock over-runs. Pre-fix, _process detection lag
# made this 100..100+N depending on frame pacing.
# ---------------------------------------------------------------------------

func test_timeout_duration_is_tick_deterministic() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(250)  # over-run far past the boundary
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"over-running the boundary must still flip _timeout_triggered=true")
	assert_eq(_runner.get(&"_outcome"), "stalemate",
		"over-running the boundary must still flip outcome to stalemate")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 100,
		"recorded duration must be the boundary tick (100), NOT the tick at "
		+ "which a frame-dependent check happened to run — DET-3 invariant")


# ---------------------------------------------------------------------------
# Phase filter: non-cleanup phases never trigger the boundary checks
# ---------------------------------------------------------------------------

func test_non_cleanup_phases_do_not_trigger_timeout() -> void:
	_runner.set(&"_timeout_ticks", 10)
	_runner.set(&"_start_tick", 0)
	# Put the clock past the boundary WITHOUT running full ticks: emit only
	# non-cleanup phases at a synthetic past-boundary tick.
	SimClock.tick = 50
	for phase: StringName in [Constants.PHASE_INPUT, Constants.PHASE_AI,
			Constants.PHASE_COMBAT, Constants.PHASE_FARR]:
		EventBus.sim_phase.emit(phase, SimClock.tick)
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"only the cleanup phase may run the timeout boundary check")
	EventBus.sim_phase.emit(Constants.PHASE_CLEANUP, SimClock.tick)
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"the cleanup phase at the same tick must trigger the timeout")


# ---------------------------------------------------------------------------
# start_tick offset is honored: timeout is RELATIVE to match-start, not
# absolute SimClock tick
# ---------------------------------------------------------------------------

func test_timeout_is_relative_to_start_tick() -> void:
	# Simulate a runner that started at SimClock.tick=50 with timeout=100.
	_advance_ticks(50)
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 50)
	_advance_ticks(90)  # ran ticks 50..139 — max delta seen = 139-50 = 89
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"timeout must be RELATIVE to _start_tick, not absolute")
	_advance_ticks(11)  # runs through tick 150 — delta 100 >= 100
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"boundary at start_tick + timeout must trigger")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 100,
		"duration must be relative to _start_tick")


# ---------------------------------------------------------------------------
# Match-already-ended: cleanup check short-circuits
# ---------------------------------------------------------------------------

func test_cleanup_after_match_ended_is_noop() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_runner.set(&"_match_ended", true)
	# Set a known prior outcome so we can detect any unwanted overwrite.
	_runner.set(&"_outcome", "iran_win")
	_advance_ticks(200)  # well past timeout
	assert_eq(_runner.get(&"_outcome"), "iran_win",
		"cleanup after _match_ended must NOT overwrite outcome")
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"cleanup after _match_ended must NOT flip _timeout_triggered")


# ---------------------------------------------------------------------------
# Grace precedence: a throne that falls BEFORE the timeout boundary resolves
# as a WIN even if the grace window spans the boundary — the grace check
# runs before the timeout check.
# ---------------------------------------------------------------------------

func test_grace_spanning_timeout_boundary_resolves_as_win() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(95)
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)  # grace_end = 125
	_advance_ticks(10)  # crosses the 100-tick timeout boundary mid-grace
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"timeout must NOT fire while the grace window is active")
	assert_eq(_runner.get(&"_outcome"), "iran_win",
		"latched win outcome must survive crossing the timeout boundary")
	_advance_ticks(25)  # through grace_end_tick = 125
	assert_true(bool(_runner.get(&"_match_ended")),
		"grace must seal the match at grace_end_tick")
	assert_eq(_runner.get(&"_outcome"), "iran_win",
		"sealed outcome must be the win, not a stalemate")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 95,
		"duration must be the throne-fall tick (95), grace excluded")
