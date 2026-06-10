# Integration test — Wave 3-Sim Track 3 batch runner dry-run validation.
#
# Verifies that:
#   1. tools/run_ai_vs_ai_batch.sh --dry-run N=3 exits 0.
#   2. results.ndjson contains exactly 3 lines, each valid JSON.
#   3. Required top-level fields are present in every match record.
#   4. Outcomes are one of: iran_win / turan_win / stalemate.
#   5. tools/aggregate_match_results.py produces valid aggregate.json.
#   6. Aggregate has expected shape: batch_meta, outcomes, duration_ticks,
#      iran_economy_at_end, turan_economy_at_end, military_at_end, events.
#   7. Seed derivation is deterministic: match_seed = master_seed XOR match_index.
#
# These tests run entirely via OS.execute() (shell-out) — they do not launch a
# real Godot match (Track 2 / headless_match_runner.gd is not required to be
# present for Track 3 tests). The --dry-run flag injects fixture NDJSON so the
# batch script is exercised without Godot invocations.
#
# The tests write to OS.get_temp_dir() / "shahnameh_batch_test_<random>" and
# clean up on teardown. No persistent side effects.
extends GutTest

const _MASTER_SEED: int = 12345
const _N_MATCHES: int = 3
const _REQUIRED_MATCH_FIELDS: Array[String] = [
	"match_id", "seed", "outcome", "winner_team",
	"duration_ticks", "duration_seconds", "first_engagement_tick", "timeout",
	"iran", "turan", "events",
]
const _REQUIRED_FACTION_FIELDS: Array[String] = [
	"throne_destroyed", "throne_hp_pct_at_end",
	"workers_alive_at_end", "combat_units_alive_at_end", "buildings_alive_at_end",
	"buildings_destroyed", "coin_x100_at_end", "grain_x100_at_end", "farr_x100_at_end",
	"units_produced_total", "buildings_constructed_total",
]
const _VALID_OUTCOMES: Array[String] = ["iran_win", "turan_win", "stalemate"]

var _output_dir: String = ""
var _results_ndjson: String = ""
var _aggregate_json: String = ""
var _repo_root: String = ""
var _batch_script: String = ""
var _aggregate_script: String = ""


func before_each() -> void:
	# Locate repo root from this test file's path (res:// → absolute).
	var test_path: String = ProjectSettings.globalize_path("res://tests/integration/test_batch_runner_dry_run.gd")
	# tests/integration/test_batch_runner_dry_run.gd → up 3 levels → repo root/game → up 1 → repo root
	_repo_root = test_path.get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	_batch_script = _repo_root.path_join("tools/run_ai_vs_ai_batch.sh")
	_aggregate_script = _repo_root.path_join("tools/aggregate_match_results.py")

	# Create a temp output dir unique to this test run.
	var rand_suffix: int = randi() % 100000
	_output_dir = OS.get_temp_dir().path_join("shahnameh_batch_test_%d" % rand_suffix)
	_results_ndjson = _output_dir.path_join("results.ndjson")
	_aggregate_json = _output_dir.path_join("aggregate.json")

	# Verify scripts exist before proceeding.
	assert_true(FileAccess.file_exists(_batch_script),
		"tools/run_ai_vs_ai_batch.sh must exist at: " + _batch_script)
	assert_true(FileAccess.file_exists(_aggregate_script),
		"tools/aggregate_match_results.py must exist at: " + _aggregate_script)


func after_each() -> void:
	# Clean up temp output.
	if DirAccess.dir_exists_absolute(_output_dir):
		var dir: DirAccess = DirAccess.open(_output_dir)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					dir.remove(fname)
				fname = dir.get_next()
		DirAccess.remove_absolute(_output_dir)


# ---------------------------------------------------------------------------
# Helper — run the batch script via OS.execute and return exit code.
# ---------------------------------------------------------------------------
func _run_batch(extra_args: Array = []) -> int:
	var args: Array[String] = [
		"bash",
		_batch_script,
		str(_N_MATCHES),
		"--master-seed", str(_MASTER_SEED),
		"--output", _output_dir,
		"--dry-run",
	]
	args.append_array(extra_args)
	# OS.execute with shell true — use "/bin/bash" -c to string-build the command.
	var cmd: String = " ".join(args.map(func(a: String) -> String: return '"%s"' % a))
	var output: Array[String] = []
	var exit_code: int = OS.execute("/bin/bash", ["-c", cmd], output, true)
	return exit_code


# ---------------------------------------------------------------------------
# Helper — parse NDJSON file into Array of Dictionaries.
# ---------------------------------------------------------------------------
func _parse_ndjson(path: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return results
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			results.append(parsed as Dictionary)
	f.close()
	return results


# ---------------------------------------------------------------------------
# Flow 1 — Batch script exits 0 for N=3 dry-run.
# ---------------------------------------------------------------------------
func test_batch_script_exits_zero_on_dry_run() -> void:
	var exit_code: int = _run_batch()
	assert_eq(exit_code, 0,
		"run_ai_vs_ai_batch.sh --dry-run N=3 must exit 0. Got: " + str(exit_code))


# ---------------------------------------------------------------------------
# Flow 2 — results.ndjson is created with exactly N lines.
# ---------------------------------------------------------------------------
func test_results_ndjson_has_n_lines() -> void:
	_run_batch()

	assert_true(FileAccess.file_exists(_results_ndjson),
		"results.ndjson must exist at: " + _results_ndjson)

	var records: Array[Dictionary] = _parse_ndjson(_results_ndjson)
	assert_eq(records.size(), _N_MATCHES,
		"results.ndjson must have exactly %d records, got %d" % [_N_MATCHES, records.size()])


# ---------------------------------------------------------------------------
# Flow 3 — Every match record has required top-level fields.
# ---------------------------------------------------------------------------
func test_each_record_has_required_fields() -> void:
	_run_batch()
	var records: Array[Dictionary] = _parse_ndjson(_results_ndjson)

	if records.is_empty():
		pending("No records — batch script may not have run.")
		return

	for i in range(records.size()):
		var rec: Dictionary = records[i]
		for field: String in _REQUIRED_MATCH_FIELDS:
			assert_true(rec.has(field),
				"Record[%d] missing required field '%s'. match_id=%s" % [i, field, str(rec.get("match_id", "?"))])


# ---------------------------------------------------------------------------
# Flow 4 — Faction sub-objects have required fields.
# ---------------------------------------------------------------------------
func test_faction_objects_have_required_fields() -> void:
	_run_batch()
	var records: Array[Dictionary] = _parse_ndjson(_results_ndjson)

	if records.is_empty():
		pending("No records.")
		return

	for i in range(records.size()):
		var rec: Dictionary = records[i]
		for faction: String in ["iran", "turan"]:
			assert_true(rec.has(faction) and rec[faction] is Dictionary,
				"Record[%d] '%s' must be a Dictionary" % [i, faction])
			if not (rec.has(faction) and rec[faction] is Dictionary):
				continue
			var fdict: Dictionary = rec[faction] as Dictionary
			for field: String in _REQUIRED_FACTION_FIELDS:
				assert_true(fdict.has(field),
					"Record[%d].%s missing required field '%s'" % [i, faction, field])


# ---------------------------------------------------------------------------
# Flow 5 — outcome field is one of the valid values.
# ---------------------------------------------------------------------------
func test_outcomes_are_valid() -> void:
	_run_batch()
	var records: Array[Dictionary] = _parse_ndjson(_results_ndjson)

	if records.is_empty():
		pending("No records.")
		return

	for i in range(records.size()):
		var oc: String = str(records[i].get("outcome", ""))
		assert_true(oc in _VALID_OUTCOMES,
			"Record[%d] outcome='%s' must be one of %s" % [i, oc, str(_VALID_OUTCOMES)])


# ---------------------------------------------------------------------------
# Flow 6 — Seed derivation: match_seed == master_seed XOR match_index.
# ---------------------------------------------------------------------------
func test_seed_derivation_is_deterministic() -> void:
	_run_batch()
	var records: Array[Dictionary] = _parse_ndjson(_results_ndjson)

	if records.is_empty():
		pending("No records.")
		return

	for i in range(records.size()):
		var expected_seed: int = _MASTER_SEED ^ i
		var actual_seed: int = int(records[i].get("seed", -1))
		assert_eq(actual_seed, expected_seed,
			"Record[%d] seed=%d must equal master_seed(%d) XOR %d = %d" % [
				i, actual_seed, _MASTER_SEED, i, expected_seed])


# ---------------------------------------------------------------------------
# Flow 7 — aggregate.json is produced and has expected top-level keys.
# ---------------------------------------------------------------------------
func test_aggregate_json_has_required_keys() -> void:
	_run_batch()

	assert_true(FileAccess.file_exists(_aggregate_json),
		"aggregate.json must exist at: " + _aggregate_json)

	var f: FileAccess = FileAccess.open(_aggregate_json, FileAccess.READ)
	if f == null:
		fail_test("Could not open aggregate.json")
		return
	var raw: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary,
		"aggregate.json must parse as a JSON object")
	if not parsed is Dictionary:
		return

	var agg: Dictionary = parsed as Dictionary
	for key: String in ["batch_meta", "outcomes", "duration_ticks",
			"duration_seconds", "first_engagement_tick",
			"iran_economy_at_end", "turan_economy_at_end",
			"military_at_end", "events"]:
		assert_true(agg.has(key),
			"aggregate.json missing top-level key '%s'" % key)


# ---------------------------------------------------------------------------
# Flow 8 — batch_meta reports correct totals.
# ---------------------------------------------------------------------------
func test_aggregate_batch_meta_totals() -> void:
	_run_batch()

	if not FileAccess.file_exists(_aggregate_json):
		pending("aggregate.json not produced.")
		return

	var f: FileAccess = FileAccess.open(_aggregate_json, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var agg: Variant = JSON.parse_string(raw)
	if not agg is Dictionary:
		pending("aggregate.json did not parse.")
		return

	var meta: Variant = (agg as Dictionary).get("batch_meta", null)
	assert_true(meta is Dictionary, "batch_meta must be a Dictionary")
	if not meta is Dictionary:
		return

	assert_eq(int((meta as Dictionary).get("valid_matches", 0)), _N_MATCHES,
		"batch_meta.valid_matches must equal N=%d" % _N_MATCHES)
	assert_eq(int((meta as Dictionary).get("invalid_lines", -1)), 0,
		"batch_meta.invalid_lines must be 0 for clean dry-run fixture")


# ---------------------------------------------------------------------------
# Flow 9 — outcomes sum equals N.
# ---------------------------------------------------------------------------
func test_aggregate_outcomes_sum_to_n() -> void:
	_run_batch()

	if not FileAccess.file_exists(_aggregate_json):
		pending("aggregate.json not produced.")
		return

	var f: FileAccess = FileAccess.open(_aggregate_json, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var agg: Variant = JSON.parse_string(raw)
	if not agg is Dictionary:
		pending("aggregate.json did not parse.")
		return

	var oc: Variant = (agg as Dictionary).get("outcomes", null)
	assert_true(oc is Dictionary, "outcomes must be a Dictionary")
	if not oc is Dictionary:
		return

	var total: int = (
		int((oc as Dictionary).get("iran_win", 0))
		+ int((oc as Dictionary).get("turan_win", 0))
		+ int((oc as Dictionary).get("stalemate", 0))
	)
	assert_eq(total, _N_MATCHES,
		"outcomes iran_win + turan_win + stalemate must sum to %d, got %d" % [_N_MATCHES, total])


# ---------------------------------------------------------------------------
# Flow 10 — Round-trip: canonical NDJSON → aggregate_match_results.py → no
# zero-fallback collapses on key fields.
#
# Feeds the §5 Example A line from AI_VS_AI_RESULT_FORMAT.md directly through
# the aggregator (bypassing the batch script). Asserts that the aggregator reads
# canonical field names (combat_units_alive_at_end, events.*) correctly —
# values must match the fixture, not fall back to 0.
#
# This is the test that would have caught C1.1. Any future drift between spec
# field names and aggregator field names will fail here.
# ---------------------------------------------------------------------------
func test_round_trip_canonical_ndjson_through_aggregator() -> void:
	# Spec §5 Example A — Iran decisive win. Field names are canonical per
	# v1.1.0 (§9.M8 fixture-sync: this string MUST stay byte-identical to the
	# Example A line in docs/AI_VS_AI_RESULT_FORMAT.md §5 — update both
	# together). v1.1.0: turan.farr_x100_at_end is the -1 sentinel.
	const SPEC_EXAMPLE_A: String = '{"match_id":"match_0001","seed":987654321,"outcome":"iran_win","winner_team":1,"duration_ticks":22140,"duration_seconds":738.0,"first_engagement_tick":3598,"timeout":false,"iran":{"throne_destroyed":false,"throne_hp_pct_at_end":91.2,"workers_alive_at_end":4,"combat_units_alive_at_end":6,"buildings_alive_at_end":4,"buildings_destroyed":0,"coin_x100_at_end":18400,"grain_x100_at_end":9500,"farr_x100_at_end":4820,"units_produced_total":8,"buildings_constructed_total":4},"turan":{"throne_destroyed":true,"throne_hp_pct_at_end":0.0,"workers_alive_at_end":0,"combat_units_alive_at_end":0,"buildings_alive_at_end":0,"buildings_destroyed":1,"coin_x100_at_end":0,"grain_x100_at_end":0,"farr_x100_at_end":-1,"units_produced_total":0,"buildings_constructed_total":0},"events":{"turan_probes_fired":6,"turan_units_deployed_total":30,"buildings_destroyed_total":1,"units_killed_total":28,"farr_drain_events_total":9,"kaveh_event_triggered":false,"iran_first_piyade_tick":2401}}'

	# Write as a 1-line NDJSON file.
	var ndjson_path: String = _output_dir.path_join("round_trip.ndjson")
	var agg_path: String = _output_dir.path_join("round_trip_agg.json")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var f: FileAccess = FileAccess.open(ndjson_path, FileAccess.WRITE)
	if f == null:
		fail_test("Could not write round-trip NDJSON fixture to: " + ndjson_path)
		return
	f.store_string(SPEC_EXAMPLE_A + "\n")
	f.close()

	# Run aggregator directly (no batch script involved).
	var cmd: String = '"%s" "%s" "%s" --output "%s"' % [
		"python3", _aggregate_script, ndjson_path, agg_path
	]
	var output: Array[String] = []
	var exit_code: int = OS.execute("/bin/bash", ["-c", cmd], output, true)
	assert_eq(exit_code, 0, "aggregate_match_results.py must exit 0 on canonical NDJSON. Output: " + str(output))

	if exit_code != 0:
		return

	var af: FileAccess = FileAccess.open(agg_path, FileAccess.READ)
	if af == null:
		fail_test("Could not open round-trip aggregate.json at: " + agg_path)
		return
	var raw: String = af.get_as_text()
	af.close()

	var agg: Variant = JSON.parse_string(raw)
	assert_true(agg is Dictionary, "round-trip aggregate.json must parse as JSON object")
	if not agg is Dictionary:
		return
	var d: Dictionary = agg as Dictionary

	# iran.combat_units_alive_at_end = 6 → military_at_end.iran_units_alive median must be 6.0, not 0.0
	var mil: Variant = d.get("military_at_end", null)
	assert_true(mil is Dictionary, "military_at_end must be a Dictionary")
	if mil is Dictionary:
		var iran_units: Variant = (mil as Dictionary).get("iran_units_alive", null)
		assert_true(iran_units is Dictionary, "military_at_end.iran_units_alive must be a Dictionary")
		if iran_units is Dictionary:
			var median: float = float((iran_units as Dictionary).get("median", 0.0))
			assert_eq(median, 6.0,
				"military_at_end.iran_units_alive.median must be 6.0 (from combat_units_alive_at_end=6), not " + str(median))

	# events.turan_probes_fired = 6 → events.turan_probes_fired.total must be 6, not 0
	var ev_agg: Variant = d.get("events", null)
	assert_true(ev_agg is Dictionary, "aggregate events key must exist")
	if ev_agg is Dictionary:
		var probes: Variant = (ev_agg as Dictionary).get("turan_probes_fired", null)
		assert_true(probes is Dictionary, "events.turan_probes_fired must be a Dictionary")
		if probes is Dictionary:
			var total_probes: int = int((probes as Dictionary).get("total", 0))
			assert_eq(total_probes, 6,
				"events.turan_probes_fired.total must be 6 (from events.turan_probes_fired=6), not " + str(total_probes))

	# events.units_killed_total = 28 → events.units_killed_total.total must be 28, not 0
	if ev_agg is Dictionary:
		var kills: Variant = (ev_agg as Dictionary).get("units_killed_total", null)
		if kills is Dictionary:
			var total_kills: int = int((kills as Dictionary).get("total", 0))
			assert_eq(total_kills, 28,
				"events.units_killed_total.total must be 28 (from events.units_killed_total=28), not " + str(total_kills))

	# v1.1.0 — events.farr_drain_events_total = 9 must aggregate (new field
	# in the events stats block).
	if ev_agg is Dictionary:
		var drains: Variant = (ev_agg as Dictionary).get("farr_drain_events_total", null)
		assert_true(drains is Dictionary,
			"events.farr_drain_events_total must be aggregated (v1.1.0)")
		if drains is Dictionary:
			assert_eq(int((drains as Dictionary).get("total", 0)), 9,
				"events.farr_drain_events_total.total must be 9")

	# v1.1.0 — turan.farr_x100_at_end = -1 sentinel must be EXCLUDED from
	# Turan Farr stats, not averaged in (RESULT_FORMAT §7.3). With this
	# single-record fixture every Turan record is the sentinel → samples=0
	# and the stats collapse to zeros, NOT to -1.
	var turan_econ: Variant = d.get("turan_economy_at_end", null)
	assert_true(turan_econ is Dictionary, "turan_economy_at_end must be a Dictionary")
	if turan_econ is Dictionary:
		var t_farr: Variant = (turan_econ as Dictionary).get("farr_x100", null)
		assert_true(t_farr is Dictionary, "turan_economy_at_end.farr_x100 must be a Dictionary")
		if t_farr is Dictionary:
			assert_eq(int((t_farr as Dictionary).get("samples", -99)), 0,
				"turan farr_x100 samples must be 0 — every record carried the -1 sentinel")
			assert_eq(float((t_farr as Dictionary).get("median", -99.0)), 0.0,
				"turan farr_x100 median must be 0.0 (no samples), NOT -1 averaged in")
			assert_eq(float((t_farr as Dictionary).get("mean", -99.0)), 0.0,
				"turan farr_x100 mean must be 0.0 (no samples), NOT -1 averaged in")
