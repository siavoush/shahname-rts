# Integration test — HeadlessMatchRunner --profile-ticks flag (Wave C1, GAP-3).
#
# Drives the runner's argv-parse + profiler-arming seams in-process (same
# pattern as test_headless_runner_timeout.gd: RunnerScript.new() without
# add_child, direct method calls — _ready never fires, so no Engine pacing
# knobs are touched and no subscriptions leak).
#
# The "no [profile] output without the flag" guarantee is pinned as a chain:
#   (a) _profile_enabled defaults false (here);
#   (b) _parse_args_from without --profile-ticks leaves it false (here);
#   (c) _apply_profile_flag without the flag does NOT arm SimClock (here);
#   (d) with SimClock.profiling_enabled false, zero data accumulates
#       (test_sim_clock_profiler.gd) — and every print site in the runner
#       (_on_sim_phase interval block + _emit_result_and_quit final block)
#       is gated on _profile_enabled, so nothing prints.
# The flag-present real-data round-trip (§9.M8) is the Wave C1 empirical
# profiled match itself — [profile] blocks verified in the live match log.
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


# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------

func test_profile_flag_defaults_to_false() -> void:
	assert_false(bool(_runner.get(&"_profile_enabled")),
		"--profile-ticks must be opt-in: default false")


func test_parse_without_flag_leaves_profiling_off() -> void:
	_runner.call(&"_parse_args_from", PackedStringArray([
		"--headless-batch", "--match-id", "match_0001", "--seed", "42",
		"--timeout-ticks", "3000",
	]))
	assert_false(bool(_runner.get(&"_profile_enabled")),
		"a flagless arg set must leave _profile_enabled false")


func test_parse_with_flag_enables_profiling() -> void:
	_runner.call(&"_parse_args_from", PackedStringArray([
		"--headless-batch", "--match-id", "match_0002", "--seed", "7",
		"--profile-ticks", "--timeout-ticks", "3000",
	]))
	assert_true(bool(_runner.get(&"_profile_enabled")),
		"--profile-ticks must set _profile_enabled")
	# The bare flag must not eat its neighbors (it consumes no value).
	assert_eq(String(_runner.get(&"_match_id")), "match_0002",
		"--match-id must still parse alongside --profile-ticks")
	assert_eq(int(_runner.get(&"_match_seed")), 7,
		"--seed must still parse alongside --profile-ticks")
	assert_eq(int(_runner.get(&"_timeout_ticks")), 3000,
		"--timeout-ticks AFTER the bare flag must still parse")


# ---------------------------------------------------------------------------
# SimClock arming
# ---------------------------------------------------------------------------

func test_apply_profile_flag_arms_sim_clock_when_enabled() -> void:
	_runner.set(&"_profile_enabled", true)
	_runner.call(&"_apply_profile_flag")
	assert_true(SimClock.profiling_enabled,
		"_apply_profile_flag with the flag set must arm SimClock.profiling_enabled")
	assert_eq(SimClock.profile_ticks_measured(), 0,
		"arming must start from a clean measurement window (reset_profile first)")


func test_apply_profile_flag_is_noop_when_disabled() -> void:
	_runner.call(&"_apply_profile_flag")
	assert_false(SimClock.profiling_enabled,
		"_apply_profile_flag without the flag must NOT arm SimClock")


# ---------------------------------------------------------------------------
# End-to-end in-process: armed profiler measures ticks driven through the
# canonical SimClock test path (the same _run_tick body the live driver uses)
# ---------------------------------------------------------------------------

func test_armed_profiler_measures_driven_ticks() -> void:
	_runner.set(&"_profile_enabled", true)
	_runner.call(&"_apply_profile_flag")
	for _i in range(10):
		SimClock._test_run_tick()
	assert_eq(SimClock.profile_ticks_measured(), 10,
		"every tick driven after arming must be measured")
	var summary: String = SimClock.build_profile_summary("in-process")
	assert_string_contains(summary, "10 ticks measured",
		"summary must reflect the driven tick count")
