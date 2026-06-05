# Integration test — HeadlessMatchRunner one-match NDJSON emission.
#
# Per 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §7 Track 2 first bullet:
# "test_headless_runner_one_match.gd — run one match, verify NDJSON emit +
#  clean termination."
#
# Exercises the result-emission schema per docs/AI_VS_AI_RESULT_FORMAT.md
# §2.1: shape of the canonical NDJSON object that a batch-script aggregator
# parses. Uses _assemble_result_dict(duration, iran, turan) to assert on
# the schema without dragging in the SceneTree-dependent _capture_team_fields
# (which queries get_tree() — see the runner's RESET AUDIT block for why
# the in-process test path bypasses that).
#
# The "clean termination" half is verified by _test_skip_emit short-circuit
# semantics: when _emit_result_and_quit() runs with _test_skip_emit=true,
# it returns BEFORE calling quit(0). Per the runner's _emit_result_and_quit
# contract: callers set _outcome + _winner_team, the method seals _match_ended.
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


# Synthetic team dict — mirrors the shape that _capture_team_fields would
# produce at end-of-match. Tests against the canonical AI_VS_AI_RESULT_FORMAT
# §2.1 per-team field set.
func _synthetic_team(
		throne_destroyed: bool,
		throne_hp_pct: float,
		workers: int,
		combat: int,
		buildings: int,
		coin_x100: int,
		grain_x100: int,
		farr_x100: int) -> Dictionary:
	return {
		"throne_destroyed": throne_destroyed,
		"throne_hp_pct_at_end": throne_hp_pct,
		"workers_alive_at_end": workers,
		"combat_units_alive_at_end": combat,
		"buildings_alive_at_end": buildings,
		"buildings_destroyed": 0,
		"coin_x100_at_end": coin_x100,
		"grain_x100_at_end": grain_x100,
		"farr_x100_at_end": farr_x100,
		"units_produced_total": 0,
		"buildings_constructed_total": 0,
	}


# ---------------------------------------------------------------------------
# Schema shape: required top-level keys per AI_VS_AI_RESULT_FORMAT §2.1
# ---------------------------------------------------------------------------

func test_result_dict_has_all_required_top_level_keys() -> void:
	_runner.set(&"_match_id", "match_0001")
	_runner.set(&"_match_seed", 42)
	_runner.set(&"_outcome", "iran_win")
	_runner.set(&"_winner_team", Constants.TEAM_IRAN)
	_runner.set(&"_first_engagement_tick", 1500)
	_runner.set(&"_iran_first_piyade_tick", 2400)
	_runner.set(&"_turan_probes_fired", 2)
	var iran: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 24500, 13200, 4700)
	var turan: Dictionary = _synthetic_team(true, 0.0, 1, 0, 0, 8200, 4100, 1200)
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 18432, iran, turan)

	# Required top-level keys per AI_VS_AI_RESULT_FORMAT §2.1.
	for key: String in [
			"match_id", "seed", "outcome", "winner_team",
			"duration_ticks", "duration_seconds", "first_engagement_tick",
			"timeout", "iran", "turan", "events"]:
		assert_true(result.has(key), "result dict must include key '%s'" % key)


# ---------------------------------------------------------------------------
# Schema shape: top-level field values match input
# ---------------------------------------------------------------------------

func test_result_dict_field_values_round_trip() -> void:
	_runner.set(&"_match_id", "match_0042")
	_runner.set(&"_match_seed", 1234567890)
	_runner.set(&"_outcome", "turan_win")
	_runner.set(&"_winner_team", Constants.TEAM_TURAN)
	_runner.set(&"_first_engagement_tick", 3712)
	_runner.set(&"_iran_first_piyade_tick", 2400)
	_runner.set(&"_turan_probes_fired", 5)
	_runner.set(&"_timeout_triggered", false)
	var iran: Dictionary = _synthetic_team(true, 0.0, 1, 0, 0, 8200, 4100, 1200)
	var turan: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 24500, 13200, 4700)
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 18432, iran, turan)

	assert_eq(result.get("match_id"), "match_0042")
	assert_eq(int(result.get("seed")), 1234567890)
	assert_eq(result.get("outcome"), "turan_win")
	assert_eq(int(result.get("winner_team")), Constants.TEAM_TURAN)
	assert_eq(int(result.get("duration_ticks")), 18432)
	assert_almost_eq(float(result.get("duration_seconds")),
		float(18432) / float(SimClock.SIM_HZ), 0.001)
	assert_eq(int(result.get("first_engagement_tick")), 3712)
	assert_eq(bool(result.get("timeout")), false)


# ---------------------------------------------------------------------------
# Schema shape: nested team dicts are passed through verbatim
# ---------------------------------------------------------------------------

func test_result_dict_per_team_payload_is_passed_through() -> void:
	var iran: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 24500, 13200, 4700)
	var turan: Dictionary = _synthetic_team(true, 0.0, 1, 0, 0, 8200, 4100, 1200)
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 18432, iran, turan)

	var r_iran: Dictionary = result.get("iran")
	assert_eq(bool(r_iran.get("throne_destroyed")), false)
	assert_almost_eq(float(r_iran.get("throne_hp_pct_at_end")), 87.5, 0.001)
	assert_eq(int(r_iran.get("workers_alive_at_end")), 4)
	assert_eq(int(r_iran.get("coin_x100_at_end")), 24500)

	var r_turan: Dictionary = result.get("turan")
	assert_eq(bool(r_turan.get("throne_destroyed")), true)
	assert_eq(int(r_turan.get("buildings_alive_at_end")), 0)
	assert_eq(int(r_turan.get("farr_x100_at_end")), 1200)


# ---------------------------------------------------------------------------
# Events block: aggregates buildings_destroyed across teams
# ---------------------------------------------------------------------------

func test_events_block_aggregates_buildings_destroyed_total() -> void:
	# Override buildings_destroyed per team to non-defaults so the
	# aggregation is observable.
	var iran: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 0, 0, 0)
	iran["buildings_destroyed"] = 3
	var turan: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 0, 0, 0)
	turan["buildings_destroyed"] = 5
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 1000, iran, turan)
	var events: Dictionary = result.get("events")
	assert_eq(int(events.get("buildings_destroyed_total")), 8,
		"events.buildings_destroyed_total must sum iran + turan")


# ---------------------------------------------------------------------------
# Events block: latched signal fields surface
# ---------------------------------------------------------------------------

func test_events_block_surfaces_latched_signals() -> void:
	_runner.set(&"_turan_probes_fired", 7)
	_runner.set(&"_iran_first_piyade_tick", 2400)
	var iran: Dictionary = _synthetic_team(false, 100.0, 4, 0, 1, 0, 0, 0)
	var turan: Dictionary = _synthetic_team(false, 100.0, 0, 0, 1, 0, 0, 0)
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 1, iran, turan)
	var events: Dictionary = result.get("events")
	assert_eq(int(events.get("turan_probes_fired")), 7,
		"events.turan_probes_fired must surface the latched counter")
	assert_eq(int(events.get("iran_first_piyade_tick")), 2400,
		"events.iran_first_piyade_tick must surface the latched tick")


# ---------------------------------------------------------------------------
# NDJSON round-trip: result dict serialises to JSON cleanly
# ---------------------------------------------------------------------------

func test_result_dict_serialises_to_valid_ndjson() -> void:
	_runner.set(&"_match_id", "match_0001")
	_runner.set(&"_match_seed", 42)
	_runner.set(&"_outcome", "iran_win")
	_runner.set(&"_winner_team", Constants.TEAM_IRAN)
	var iran: Dictionary = _synthetic_team(false, 87.5, 4, 8, 6, 24500, 13200, 4700)
	var turan: Dictionary = _synthetic_team(true, 0.0, 1, 0, 0, 8200, 4100, 1200)
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 18432, iran, turan)
	var ndjson: String = JSON.stringify(result)
	assert_true(ndjson.length() > 0, "JSON.stringify must produce a string")
	# NDJSON requires single-line — no embedded newline.
	assert_eq(ndjson.find("\n"), -1,
		"NDJSON line must contain no embedded newlines")
	# Round-trip parse must succeed and preserve top-level keys.
	var parser: JSON = JSON.new()
	var parse_err: int = parser.parse(ndjson)
	assert_eq(parse_err, OK, "NDJSON line must parse back cleanly")
	var parsed: Dictionary = parser.data
	assert_eq(parsed.get("match_id"), "match_0001")
	assert_eq(parsed.get("outcome"), "iran_win")


# ---------------------------------------------------------------------------
# Clean termination: _emit_result_and_quit with _test_skip_emit=true seals
# the match without crashing on the non-running SceneTree.
# ---------------------------------------------------------------------------

func test_emit_result_and_quit_seals_match_ended_under_test_skip() -> void:
	_runner.set(&"_outcome", "iran_win")
	_runner.set(&"_winner_team", Constants.TEAM_IRAN)
	assert_false(bool(_runner.get(&"_match_ended")),
		"pre-emit: _match_ended must be false")
	_runner.call(&"_emit_result_and_quit")
	assert_true(bool(_runner.get(&"_match_ended")),
		"post-emit: _emit_result_and_quit must seal _match_ended=true")


# ---------------------------------------------------------------------------
# Idempotency: calling _emit_result_and_quit twice is a no-op on the second
# call (prevents double-NDJSON in live runs).
# ---------------------------------------------------------------------------

func test_emit_result_and_quit_is_idempotent() -> void:
	_runner.set(&"_outcome", "iran_win")
	_runner.call(&"_emit_result_and_quit")
	# Second call must short-circuit on _match_ended guard, without
	# erroring or flipping fields.
	_runner.set(&"_outcome", "turan_win")  # external state mutation
	_runner.call(&"_emit_result_and_quit")
	# The fields we mutated EXTERNALLY are untouched (the second emit
	# was a no-op); we just verify it didn't crash and _match_ended
	# stays true.
	assert_true(bool(_runner.get(&"_match_ended")),
		"_match_ended must stay true after second emit")
