# Integration test — TEST-3: REAL subprocess smoke of the headless batch
# pipeline (Wave C3; named at session-10, carried as QA debt since).
#
# Unlike test_batch_runner_dry_run.gd (which exercises the batch script's
# shell logic with --dry-run fixture NDJSON and never launches Godot), this
# test boots the REAL pipeline exactly once:
#
#   tools/run_ai_vs_ai_batch.sh 1 --timeout-ticks 120 --godot <this binary>
#     → fresh Godot process → main.tscn boot (all autoloads register)
#     → --headless-batch detected → HeadlessMatchRunner spawned
#     → 120 sim ticks → timeout → stalemate NDJSON → quit(0)
#     → aggregate_match_results.py → aggregate.json
#
# THIS is the test that would have caught the Wave 3-Sim '-s mode boots no
# autoloads' compile failure BEFORE the manual smoke did: any regression in
# the boot mode, autoload registration, main.gd flag-detect, runner compile,
# NDJSON emission, or exit-code discipline fails here at suite time.
#
# RUNTIME COST (measured 2026-06-11 on the dev machine, warm import cache):
#   one subprocess boot ≈ 36-43 s wall. Accepted as ONE test per the Wave C3
#   brief ("one subprocess boot — acceptable as ONE test; document the cost").
#   Do NOT add more subprocess-booting tests here — extend assertions inside
#   the single boot instead.
#
# WATCHDOG: the subprocess is wrapped in a 180 s kill loop so a regression
# where the runner never quits degrades to a loud test failure (exit 124)
# instead of hanging the whole suite / pre-commit gate forever. The watchdog
# is written to a TEMP SCRIPT FILE and invoked with plain argv — it cannot be
# passed inline via `bash -c '<script>'`, because Godot's OS.execute with
# output capture routes the command line through a shell on macOS/Unix, which
# pre-expands `$@` / `$!` / `$(...)` inside the argument before the real bash
# ever sees it (empirically verified; the inline form mangles to a syntax
# error). File-based script + $-free argv sidesteps the double-expansion.
#
# GODOT binary selection: OS.get_executable_path() — the binary running this
# very test is by definition a working Godot 4 for this project, so the test
# is environment-portable (no hardcoded /Applications path; the batch
# script's --godot flag is the seam, same convention the script documents).
extends GutTest

const _MASTER_SEED: int = 777
const _TIMEOUT_TICKS: int = 120
const _WATCHDOG_SECONDS: int = 180

# Field lists mirror AI_VS_AI_RESULT_FORMAT.md §2.1 (same as the dry-run
# validation test — keep the two in sync with the spec doc).
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

var _output_dir: String = ""


func before_each() -> void:
	var rand_suffix: int = randi() % 100000
	_output_dir = OS.get_temp_dir().path_join(
		"shahnameh_subprocess_smoke_%d" % rand_suffix)


func after_each() -> void:
	# Clean up temp output (results.ndjson, aggregate.json, match_0000.log —
	# the batch script writes flat files only).
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


func _repo_root() -> String:
	var test_path: String = ProjectSettings.globalize_path(
		"res://tests/integration/test_batch_runner_subprocess_smoke.gd")
	# tests/integration/<file> → game/ → repo root.
	return test_path.get_base_dir().get_base_dir().get_base_dir().get_base_dir()


# Watchdog shell script body. Lives in a file (NOT an inline bash -c arg —
# see file header). Usage: bash watchdog.sh <command...>. Runs <command...>
# in the background; propagates its exit code if it finishes inside the
# window; exits 124 after _WATCHDOG_SECONDS otherwise (best-effort TERM to
# the batch bash + any orphaned headless-batch Godot).
func _watchdog_script_text() -> String:
	return ("#!/usr/bin/env bash\n"
		+ "\"$@\" &\n"
		+ "pid=$!\n"
		+ "for _ in $(seq 1 %d); do\n" % _WATCHDOG_SECONDS
		+ "  kill -0 \"$pid\" 2>/dev/null || { wait \"$pid\"; exit $?; }\n"
		+ "  sleep 1\n"
		+ "done\n"
		+ "kill -TERM \"$pid\" 2>/dev/null\n"
		+ "pkill -TERM -f -- '--headless-batch' 2>/dev/null\n"
		+ "exit 124\n")


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
# THE one subprocess boot. All assertions live in this single test so the
# ~40 s cost is paid exactly once per suite run.
# ---------------------------------------------------------------------------
func test_real_headless_pipeline_one_match_end_to_end() -> void:
	var batch_script: String = _repo_root().path_join("tools/run_ai_vs_ai_batch.sh")
	assert_true(FileAccess.file_exists(batch_script),
		"tools/run_ai_vs_ai_batch.sh must exist at: " + batch_script)

	var godot_bin: String = OS.get_executable_path()
	var results_ndjson: String = _output_dir.path_join("results.ndjson")
	var aggregate_json: String = _output_dir.path_join("aggregate.json")
	var match_log: String = _output_dir.path_join("match_0000.log")

	# Watchdog wrapper (see file header for why this is a temp FILE, not an
	# inline `bash -c` script): launch the batch script in the background,
	# poll liveness once per second up to _WATCHDOG_SECONDS, then kill
	# (batch bash + best-effort the headless-batch Godot child) and exit
	# 124 — a hung runner becomes a loud failure, not a hung suite.
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var watchdog_path: String = _output_dir.path_join("watchdog.sh")
	var wf: FileAccess = FileAccess.open(watchdog_path, FileAccess.WRITE)
	if wf == null:
		fail_test("Could not write watchdog script to: " + watchdog_path)
		return
	wf.store_string(_watchdog_script_text())
	wf.close()

	var args: Array[String] = [
		watchdog_path,
		"bash", batch_script, "1",
		"--master-seed", str(_MASTER_SEED),
		"--output", _output_dir,
		"--timeout-ticks", str(_TIMEOUT_TICKS),
		"--godot", godot_bin,
	]
	var output: Array = []
	var exit_code: int = OS.execute("/bin/bash", PackedStringArray(args), output, true)

	# --- Exit discipline -----------------------------------------------------
	if exit_code == 124:
		fail_test("Watchdog fired after %d s — the headless runner never quit. "
			% _WATCHDOG_SECONDS
			+ "Check match log (timeout/grace emit path): " + match_log)
		return
	assert_eq(exit_code, 0,
		"run_ai_vs_ai_batch.sh (1 real match, %d-tick timeout) must exit 0. "
			% _TIMEOUT_TICKS
		+ "Got %d. Batch output:\n%s" % [exit_code, "\n".join(
			output.map(func(o: Variant) -> String: return str(o)))])
	if exit_code != 0:
		return

	# --- NDJSON: exactly one line, parses, schema-complete --------------------
	assert_true(FileAccess.file_exists(results_ndjson),
		"results.ndjson must exist at: " + results_ndjson)
	var records: Array[Dictionary] = _parse_ndjson(results_ndjson)
	assert_eq(records.size(), 1,
		"results.ndjson must contain exactly 1 parseable record for a "
		+ "1-match batch, got %d" % records.size())
	if records.size() != 1:
		return
	var rec: Dictionary = records[0]

	for field: String in _REQUIRED_MATCH_FIELDS:
		assert_true(rec.has(field),
			"NDJSON record missing required top-level field '%s'" % field)
	for faction: String in ["iran", "turan"]:
		if rec.get(faction, null) is Dictionary:
			var fdict: Dictionary = rec[faction]
			for field: String in _REQUIRED_FACTION_FIELDS:
				assert_true(fdict.has(field),
					"NDJSON record %s missing required field '%s'" % [faction, field])

	# --- Real-data semantics (M8: not just shape) ------------------------------
	# 120 ticks cannot reach a throne kill (first probe fires at tick 3600),
	# so the deterministic outcome is a timeout stalemate at exactly the
	# timeout boundary (DET-3 made the timeout tick-deterministic).
	assert_eq(str(rec.get("outcome", "")), "stalemate",
		"120-tick match must time out as a stalemate (no combat possible yet)")
	assert_eq(bool(rec.get("timeout", false)), true,
		"timeout flag must be true on the stalemate path")
	assert_eq(int(rec.get("seed", -1)), _MASTER_SEED ^ 0,
		"match seed must equal master_seed XOR 0 for match index 0")
	assert_gte(int(rec.get("duration_ticks", -1)), _TIMEOUT_TICKS,
		"duration_ticks must be >= the timeout boundary")
	# The starting roster is alive and untouched at tick 120 — workers field
	# proves the subprocess actually booted main.tscn's roster, not an
	# empty scene (the field would be 0 on a silent boot regression).
	var iran: Dictionary = rec.get("iran", {})
	assert_gt(int(iran.get("workers_alive_at_end", 0)), 0,
		"Iran workers_alive_at_end must be > 0 — the starting roster did "
		+ "not spawn in the subprocess boot")

	# --- Aggregate exists and parses -------------------------------------------
	assert_true(FileAccess.file_exists(aggregate_json),
		"aggregate.json must exist at: " + aggregate_json)
	var af: FileAccess = FileAccess.open(aggregate_json, FileAccess.READ)
	if af == null:
		fail_test("Could not open aggregate.json at: " + aggregate_json)
		return
	var agg: Variant = JSON.parse_string(af.get_as_text())
	af.close()
	assert_true(agg is Dictionary, "aggregate.json must parse as a JSON object")
