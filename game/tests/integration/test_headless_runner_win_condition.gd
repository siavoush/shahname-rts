# Integration test — HeadlessMatchRunner win-condition routing.
#
# Per 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §7 Track 2 third bullet:
# "test_headless_runner_win_condition.gd — synthesize Throne destruction,
#  verify runner detects + emits outcome=X_win."
#
# Drives EventBus.throne_destroyed(team_id) against a runner instance and
# asserts the field-flip semantics of _on_throne_destroyed:
#   team_id=TEAM_IRAN  → _outcome="turan_win" + _winner_team=TEAM_TURAN
#   team_id=TEAM_TURAN → _outcome="iran_win"  + _winner_team=TEAM_IRAN
#   team_id=neutral    → _outcome="stalemate" + _winner_team=-1
#
# _test_skip_emit=true short-circuits the SceneTree-touching emit path so
# the runner's signal handler is testable in-process.
#
# Result-format v1.1.0 (Track B2): throne_destroyed no longer ends the match
# immediately — it LATCHES the result and arms the deterministic grace window
# (Constants.SIM_THRONE_GRACE_TICKS); the NDJSON emit happens at grace-end in
# the sim_phase cleanup handler. These tests therefore assert the LATCH
# semantics (_grace_active + outcome/winner); the grace-window mechanics are
# pinned in test_headless_runner_throne_destruction_same_tick_ordering.gd.
extends GutTest


const RunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


var _runner: Variant = null


func before_each() -> void:
	SimClock.reset()
	_runner = RunnerScript.new()
	_runner.set(&"_test_skip_emit", true)
	# Connect the runner's handler exactly as _subscribe_signals would. We
	# do this manually rather than calling _subscribe_signals to keep the
	# test surface minimal (we are only exercising throne_destroyed).
	if not EventBus.throne_destroyed.is_connected(_runner._on_throne_destroyed):
		EventBus.throne_destroyed.connect(_runner._on_throne_destroyed)


func after_each() -> void:
	if _runner != null:
		if EventBus.throne_destroyed.is_connected(_runner._on_throne_destroyed):
			EventBus.throne_destroyed.disconnect(_runner._on_throne_destroyed)
		_runner.free()
		_runner = null
	SimClock.reset()


# ---------------------------------------------------------------------------
# Win-condition: Iran throne falls → Turan wins
# ---------------------------------------------------------------------------

func test_iran_throne_destroyed_routes_to_turan_win() -> void:
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_eq(_runner.get(&"_outcome"), "turan_win",
		"Iran throne destruction must flip outcome to turan_win")
	assert_eq(int(_runner.get(&"_winner_team")), Constants.TEAM_TURAN,
		"Iran throne destruction must set winner_team=TEAM_TURAN")
	assert_true(bool(_runner.get(&"_grace_active")),
		"throne_destroyed must arm the grace window (result latched; emit "
		+ "happens at grace_end_tick per result-format v1.1.0)")


# ---------------------------------------------------------------------------
# Win-condition: Turan throne falls → Iran wins
# ---------------------------------------------------------------------------

func test_turan_throne_destroyed_routes_to_iran_win() -> void:
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)
	assert_eq(_runner.get(&"_outcome"), "iran_win",
		"Turan throne destruction must flip outcome to iran_win")
	assert_eq(int(_runner.get(&"_winner_team")), Constants.TEAM_IRAN,
		"Turan throne destruction must set winner_team=TEAM_IRAN")
	assert_true(bool(_runner.get(&"_grace_active")),
		"throne_destroyed must arm the grace window (result latched; emit "
		+ "happens at grace_end_tick per result-format v1.1.0)")


# ---------------------------------------------------------------------------
# Defensive: unexpected team id maps to stalemate sentinel
# ---------------------------------------------------------------------------

func test_unknown_team_throne_destroyed_routes_to_stalemate() -> void:
	# Defensive branch in _on_throne_destroyed: any team_id outside
	# {TEAM_IRAN, TEAM_TURAN} maps to stalemate to avoid silently winning.
	EventBus.throne_destroyed.emit(Constants.TEAM_NEUTRAL)
	assert_eq(_runner.get(&"_outcome"), "stalemate",
		"unknown team_id must flip outcome to stalemate")
	assert_eq(int(_runner.get(&"_winner_team")), -1,
		"unknown team_id must set winner_team=-1 (stalemate sentinel)")


# ---------------------------------------------------------------------------
# Idempotency: second throne_destroyed after the first is a no-op
# ---------------------------------------------------------------------------

func test_second_throne_destroyed_is_ignored_after_match_end() -> void:
	# First emit latches the result + arms the grace window.
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	var first_outcome: String = String(_runner.get(&"_outcome"))
	var first_winner: int = int(_runner.get(&"_winner_team"))
	# Second emit on the OTHER team must NOT flip fields — the runner
	# short-circuits via the _grace_active guard (first-throne-wins).
	# Without this guard the runner would overwrite the result and the
	# NDJSON line would lie.
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)
	assert_eq(_runner.get(&"_outcome"), first_outcome,
		"second throne_destroyed must NOT overwrite outcome")
	assert_eq(int(_runner.get(&"_winner_team")), first_winner,
		"second throne_destroyed must NOT overwrite winner_team")


# ---------------------------------------------------------------------------
# Signal subscription: _subscribe_signals connects the handler
# ---------------------------------------------------------------------------

func test_subscribe_signals_connects_throne_destroyed_handler() -> void:
	# Fresh runner without manual connect.
	var fresh: Variant = RunnerScript.new()
	fresh.set(&"_test_skip_emit", true)
	assert_false(
		EventBus.throne_destroyed.is_connected(fresh._on_throne_destroyed),
		"pre-subscribe: handler must NOT be connected")
	fresh.call(&"_subscribe_signals")
	assert_true(
		EventBus.throne_destroyed.is_connected(fresh._on_throne_destroyed),
		"post-subscribe: handler must be connected")
	# Result-format v1.1.0 — the counter + tick-check subscriptions ride the
	# same _subscribe_signals call; spot-check the new connections.
	assert_true(EventBus.unit_died.is_connected(fresh._on_unit_died),
		"post-subscribe: unit_died counter handler must be connected")
	assert_true(EventBus.sim_phase.is_connected(fresh._on_sim_phase),
		"post-subscribe: sim_phase end-check handler must be connected")
	# Cleanup — symmetric teardown of the full connection set.
	fresh.call(&"_disconnect_signals")
	fresh.free()
