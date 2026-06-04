# Integration test — HeadlessMatchRunner timeout boundary.
#
# Per 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §7 Track 2 fourth bullet:
# "test_headless_runner_timeout.gd — synthesize a sim that never terminates,
#  verify runner times out at 60,000 ticks + emits outcome=stalemate."
#
# Exercises the _process(dt) timeout-boundary arithmetic:
#   _process called while SimClock.tick - _start_tick < _timeout_ticks → no-op
#   _process called once SimClock.tick - _start_tick >= _timeout_ticks  → flip
#       _timeout_triggered=true + _outcome=stalemate + _winner_team=-1
#
# Per 02t §3 Q2 (RESOLVED v1.0.1): timeout = 60,000 ticks (33 min @ 30Hz).
# 60K is a lot of ticks to count up to in a unit test; this test uses
# smaller _timeout_ticks values so the boundary itself is exercised in
# both passing and failing positions WITHOUT advancing SimClock to 60K.
extends GutTest


const RunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


var _runner: Variant = null


func before_each() -> void:
	SimClock.reset()
	_runner = RunnerScript.new()
	_runner.set(&"_test_skip_emit", true)


func after_each() -> void:
	if _runner != null:
		_runner.free()
		_runner = null
	SimClock.reset()


# Helper: advance SimClock by n ticks using the canonical Sim Contract §6.1
# test path (same as MatchHarness.advance_ticks).
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
# Below timeout: _process is a pass-through (no field flip)
# ---------------------------------------------------------------------------

func test_process_below_timeout_does_not_flip_outcome() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(50)  # at tick 50, below 100-tick threshold
	var pre_outcome: String = String(_runner.get(&"_outcome"))
	_runner.call(&"_process", 0.0)
	assert_eq(_runner.get(&"_outcome"), pre_outcome,
		"_process below timeout must NOT flip outcome")
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"_process below timeout must NOT set _timeout_triggered")


# ---------------------------------------------------------------------------
# At timeout boundary: _process flips outcome=stalemate
# ---------------------------------------------------------------------------

func test_process_at_timeout_flips_to_stalemate() -> void:
	# Configure a small timeout so we can hit the boundary cheaply.
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(100)  # SimClock.tick=100, _start_tick=0 → delta=100 >= 100
	_runner.call(&"_process", 0.0)
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"_process at timeout boundary must set _timeout_triggered=true")
	assert_eq(_runner.get(&"_outcome"), "stalemate",
		"_process at timeout boundary must flip outcome to stalemate")
	assert_eq(int(_runner.get(&"_winner_team")), -1,
		"_process at timeout boundary must set winner_team=-1 (stalemate)")


# ---------------------------------------------------------------------------
# Past timeout: _process still triggers stalemate (idempotent flip)
# ---------------------------------------------------------------------------

func test_process_past_timeout_still_triggers_stalemate() -> void:
	# At tick 250 with timeout=100 + start_tick=0, delta=250 > 100.
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_advance_ticks(250)
	_runner.call(&"_process", 0.0)
	assert_true(bool(_runner.get(&"_timeout_triggered")),
		"_process past timeout must still flip _timeout_triggered=true")
	assert_eq(_runner.get(&"_outcome"), "stalemate",
		"_process past timeout must still flip outcome to stalemate")


# ---------------------------------------------------------------------------
# start_tick offset is honored: timeout is RELATIVE to match-start, not
# absolute SimClock tick
# ---------------------------------------------------------------------------

func test_timeout_is_relative_to_start_tick() -> void:
	# Simulate a runner that started at SimClock.tick=50 with timeout=100.
	# At SimClock.tick=140 (delta=90), should NOT timeout.
	_advance_ticks(50)
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 50)
	_advance_ticks(90)  # SimClock.tick=140, delta=140-50=90 < 100
	_runner.call(&"_process", 0.0)
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"timeout must be RELATIVE to _start_tick, not absolute")


# ---------------------------------------------------------------------------
# Match-already-ended: _process short-circuits past timeout check
# ---------------------------------------------------------------------------

func test_process_after_match_ended_is_noop() -> void:
	_runner.set(&"_timeout_ticks", 100)
	_runner.set(&"_start_tick", 0)
	_runner.set(&"_match_ended", true)
	# Set a known prior outcome so we can detect any unwanted overwrite.
	_runner.set(&"_outcome", "iran_win")
	_advance_ticks(200)  # well past timeout
	_runner.call(&"_process", 0.0)
	assert_eq(_runner.get(&"_outcome"), "iran_win",
		"_process after _match_ended must NOT overwrite outcome")
	assert_false(bool(_runner.get(&"_timeout_triggered")),
		"_process after _match_ended must NOT flip _timeout_triggered")
