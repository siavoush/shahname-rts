# Unit tests — SimClock per-phase tick profiler (Wave C1, GAP-3).
#
# The profiler brackets each EventBus.sim_phase.emit() inside
# SimClock._run_tick with TimeProvider.now_usec() reads — the ONLY seam that
# sees the full synchronous subscriber cost of a phase (a subscriber can only
# time its own handler). These tests pin:
#
#   1. Disabled-by-default: profiling_enabled is false after reset(); ticks
#      run with it false accumulate NOTHING. Combined with the runner-side
#      flag default (test_headless_runner_profile_flag.gd) this is the
#      "no [profile] output without the flag" guarantee — every print site
#      (print_profile_summary calls in the runner) is gated on the flag,
#      and the data they would print never even accumulates.
#   2. Enabled path: each _run_tick increments ticks-measured and accumulates
#      per-phase totals (deterministic count; totals are wall-clock and only
#      asserted for non-negativity / monotonicity, never exact values).
#   3. build_profile_summary is a pure read: '[profile]'-prefixed lines, all
#      eight canonical phases present, never a line starting with '{' (the
#      batch script extracts NDJSON via rg '^\{' — a summary line that looked
#      like JSON would corrupt results.ndjson).
#   4. reset() clears profiler state (no cross-test leak).
extends GutTest


func before_each() -> void:
	SimClock.reset()


func after_each() -> void:
	SimClock.reset()


# ---------------------------------------------------------------------------
# 1 — disabled by default, zero accumulation
# ---------------------------------------------------------------------------

func test_profiling_disabled_by_default() -> void:
	assert_false(SimClock.profiling_enabled,
		"profiling_enabled must default to false — live games never pay the cost")


func test_disabled_ticks_accumulate_nothing() -> void:
	for _i in range(5):
		SimClock._test_run_tick()
	assert_eq(SimClock.profile_ticks_measured(), 0,
		"ticks run with profiling disabled must not be measured")
	for phase: StringName in SimClock.PHASES:
		assert_eq(SimClock.profile_total_usec(phase), 0,
			"phase '%s' must have zero accumulated usec when disabled" % phase)


func test_disabled_summary_reports_no_ticks_measured() -> void:
	for _i in range(3):
		SimClock._test_run_tick()
	var summary: String = SimClock.build_profile_summary("test")
	assert_string_contains(summary, "no ticks measured",
		"summary with zero measured ticks must say so instead of dividing by zero")
	assert_true(summary.begins_with("[profile]"),
		"even the empty summary must carry the [profile] prefix")


# ---------------------------------------------------------------------------
# 2 — enabled path accumulates
# ---------------------------------------------------------------------------

func test_enabled_ticks_increment_measured_count() -> void:
	SimClock.profiling_enabled = true
	for _i in range(7):
		SimClock._test_run_tick()
	assert_eq(SimClock.profile_ticks_measured(), 7,
		"each profiled _run_tick must increment the measured-tick count")


func test_enabled_totals_are_non_negative_and_monotonic() -> void:
	SimClock.profiling_enabled = true
	for _i in range(3):
		SimClock._test_run_tick()
	var after_three: Dictionary = {}
	for phase: StringName in SimClock.PHASES:
		var total: int = SimClock.profile_total_usec(phase)
		assert_true(total >= 0,
			"phase '%s' total usec must be >= 0, got %d" % [phase, total])
		after_three[phase] = total
	for _i in range(3):
		SimClock._test_run_tick()
	for phase: StringName in SimClock.PHASES:
		assert_true(SimClock.profile_total_usec(phase) >= int(after_three[phase]),
			"phase '%s' total must be monotonically non-decreasing" % phase)


# ---------------------------------------------------------------------------
# 3 — summary shape
# ---------------------------------------------------------------------------

func test_summary_lists_every_canonical_phase() -> void:
	SimClock.profiling_enabled = true
	for _i in range(4):
		SimClock._test_run_tick()
	var summary: String = SimClock.build_profile_summary("shape-test")
	for phase: StringName in SimClock.PHASES:
		assert_string_contains(summary, String(phase),
			"summary must include a row for phase '%s'" % phase)
	assert_string_contains(summary, "4 ticks measured",
		"summary header must carry the measured-tick count")
	assert_string_contains(summary, "shape-test",
		"summary header must carry the caller-supplied context")
	assert_string_contains(summary, "ALL_PHASES",
		"summary must include the all-phases footer row")


func test_summary_every_line_is_profile_prefixed_and_never_json_shaped() -> void:
	# The batch script extracts the NDJSON result via `rg '^\{' | tail -1`.
	# A summary line starting with '{' would be mistaken for the result.
	SimClock.profiling_enabled = true
	for _i in range(2):
		SimClock._test_run_tick()
	var summary: String = SimClock.build_profile_summary("json-safety")
	for line: String in summary.split("\n"):
		assert_true(line.begins_with("[profile]"),
			"every summary line must start with '[profile]', got: %s" % line)
		assert_false(line.begins_with("{"),
			"no summary line may start with '{' (NDJSON extraction safety)")


# ---------------------------------------------------------------------------
# 4 — reset discipline
# ---------------------------------------------------------------------------

func test_reset_disarms_and_clears_profiler() -> void:
	SimClock.profiling_enabled = true
	for _i in range(5):
		SimClock._test_run_tick()
	assert_eq(SimClock.profile_ticks_measured(), 5, "precondition: ticks measured")
	SimClock.reset()
	assert_false(SimClock.profiling_enabled,
		"reset() must disarm the profiler (no cross-test leak)")
	assert_eq(SimClock.profile_ticks_measured(), 0,
		"reset() must clear the measured-tick count")
	for phase: StringName in SimClock.PHASES:
		assert_eq(SimClock.profile_total_usec(phase), 0,
			"reset() must zero phase '%s' accumulator" % phase)


func test_reset_profile_clears_accumulators_only() -> void:
	SimClock.profiling_enabled = true
	for _i in range(2):
		SimClock._test_run_tick()
	SimClock.reset_profile()
	assert_eq(SimClock.profile_ticks_measured(), 0,
		"reset_profile() must zero the measured-tick count")
	assert_true(SimClock.profiling_enabled,
		"reset_profile() must NOT disarm the flag — it only clears the window "
		+ "(the runner calls it right before arming)")
