extends Node
##
## SimClock — the 30 Hz fixed-tick driver for the simulation layer.
##
## Per docs/SIMULATION_CONTRACT.md §1.1:
##   "Gameplay state mutates only inside a _sim_tick() call dispatched by
##    SimClock. All other code reads only."
##
## SimClock does not call _sim_tick on any component directly. It only emits
## EventBus signals — tick_started, then sim_phase for each of the seven
## phases in canonical order, then tick_ended. Phase coordinators (landing
## session 2+) listen for sim_phase and iterate their registered components.
## This indirection is what lets advance_ticks(n) and the live
## _physics_process driver share the same code path. See Sim Contract §2.1.
##
## Hard rule (§1.1): no gameplay code reads Time.get_ticks_msec(),
## OS.get_unix_time(), or accumulates its own delta. The only "now" is
## SimClock.tick and SimClock.sim_time.

const SIM_HZ: int = 30
const SIM_DT: float = 1.0 / 30.0

# Canonical phase order, locked by Sim Contract §2.
# Wave 3A.0 (2026-05-22): &"fog_update" inserted between &"input" and &"ai"
# per FOG_DATA_CONTRACT.md §4. At Wave 3A.0 the phase fires but no handler
# is connected (FogSystem stub) — no observable behavior change. At Wave 3A.5
# FogSystem connects + recomputes _currently_visible per tick before AI reads.
const PHASES: Array[StringName] = [
	&"input", &"fog_update", &"ai", &"movement", &"spatial_rebuild",
	&"combat", &"farr", &"cleanup",
]

# Monotonic tick counter. Starts at 0; increments at the end of each tick.
var tick: int = 0

# Derived: tick * SIM_DT. Cached to avoid float multiply at every read.
var sim_time: float = 0.0

# Internal — the assertion target read by SimNode._set_sim().
var _is_ticking: bool = false

# Accumulator pattern (Sim Contract §1.2). Real frame deltas funnel into here;
# every time the accumulator crosses SIM_DT we run exactly one fixed tick.
var _accumulator: float = 0.0

# ---- Per-phase tick profiler (Wave C1, GAP-3) -------------------------------
#
# Measures wall-time per sim_phase per tick. EventBus.sim_phase.emit() is
# SYNCHRONOUS — every subscriber for a phase runs to completion inside the
# emit() call — so bracketing each emit with TimeProvider.now_usec() reads
# captures the FULL cost of that phase across all subscribers. (A subscriber
# could only ever time its own handler; this is the one seam that sees the
# whole phase. That is why the profiler lives here and not in the runner.)
#
# Enabled ONLY by HeadlessMatchRunner under --profile-ticks. The disabled
# path costs a single bool check per tick — no per-frame overhead in live
# games. Wall-clock reads go through TimeProvider.now_usec() (the documented
# usec passthrough); sim_clock.gd is also on the L5 lint allowlist, but
# routing through TimeProvider keeps one sanctioned wall-clock surface.
#
# §9.M6 note: the profiler mutates no gameplay state and emits no signals;
# its observable output is the '[profile]' summary block the runner prints
# at interval boundaries + match end (print_profile_summary below).
var profiling_enabled: bool = false
var _profile_total_usec: Dictionary = {}  # StringName phase -> int usec
var _profile_max_usec: Dictionary = {}    # StringName phase -> int usec
var _profile_max_tick: Dictionary = {}    # StringName phase -> tick of max
var _profile_ticks_measured: int = 0


func _init() -> void:
	# Seed the per-phase accumulator keys so the hot loop can use direct
	# indexing (a missing key fails loudly instead of silently creating a
	# new bucket — §9.M7).
	reset_profile()


## Returns true while a tick is in progress. SimNode._set_sim() asserts on
## this; UI / off-tick code may read it for diagnostic purposes only.
func is_ticking() -> bool:
	return _is_ticking


## Drive the fixed tick from real frame time. _physics_process is preferred
## over _process because the engine guarantees fixed-step semantics (Godot
## smooths variable-frame deltas before delivering them to physics).
func _physics_process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= SIM_DT:
		_accumulator -= SIM_DT
		_run_tick()


# Emit the canonical signal sequence for one tick. The body is intentionally
# small — phase coordinators do the per-component work in their own
# sim_phase handlers. Keeping this method shared between live and headless
# paths is the whole point.
func _run_tick() -> void:
	_is_ticking = true
	EventBus.tick_started.emit(tick)
	if profiling_enabled:
		# Profiled path (headless --profile-ticks only). emit() is
		# synchronous, so t1 - t0 is the full subscriber cost of the phase.
		for phase in PHASES:
			var t0: int = TimeProvider.now_usec()
			EventBus.sim_phase.emit(phase, tick)
			var elapsed: int = TimeProvider.now_usec() - t0
			_profile_total_usec[phase] += elapsed
			if elapsed > _profile_max_usec[phase]:
				_profile_max_usec[phase] = elapsed
				_profile_max_tick[phase] = tick
		_profile_ticks_measured += 1
	else:
		# Live path — zero profiling overhead beyond the bool check above.
		for phase in PHASES:
			EventBus.sim_phase.emit(phase, tick)
	EventBus.tick_ended.emit(tick)
	_is_ticking = false
	tick += 1
	sim_time = float(tick) * SIM_DT


# ---- Test hooks -------------------------------------------------------------
#
# These are public so GUT (and the future MatchHarness) can drive the clock
# manually. They share the exact same _run_tick() body the live path uses,
# satisfying Sim Contract §6.1's "must do" list — advance_ticks must not
# diverge from _physics_process.

## Run exactly one fixed tick, ignoring the accumulator. Intended for tests
## and the headless MatchHarness (Phase 0 session 2+).
func _test_run_tick() -> void:
	_run_tick()


## Run as many ticks as fit in the supplied delta, mirroring the
## _physics_process accumulator. Useful for testing accumulator semantics
## directly.
func _test_advance(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= SIM_DT:
		_accumulator -= SIM_DT
		_run_tick()


## Reset to a pristine state. GUT before_each / after_each call this so tests
## don't leak tick counts across cases. Also disarms + clears the profiler so
## a profiling test can never leak measurement state into its neighbors.
func reset() -> void:
	tick = 0
	sim_time = 0.0
	_is_ticking = false
	_accumulator = 0.0
	profiling_enabled = false
	reset_profile()


# ---- Per-phase tick profiler API (Wave C1, GAP-3) ---------------------------

## Zero every per-phase accumulator. Called from _init (key seeding), reset(),
## and by HeadlessMatchRunner immediately before it flips profiling_enabled
## so a measurement window always starts clean.
func reset_profile() -> void:
	for phase in PHASES:
		_profile_total_usec[phase] = 0
		_profile_max_usec[phase] = 0
		_profile_max_tick[phase] = -1  # -1 sentinel = no max recorded yet
	_profile_ticks_measured = 0


## Number of ticks measured since the last reset_profile(). Test surface +
## summary denominator.
func profile_ticks_measured() -> int:
	return _profile_ticks_measured


## Total accumulated usec for one phase. Test surface — fails loudly (missing
## key) if asked about a phase that is not in PHASES.
func profile_total_usec(phase: StringName) -> int:
	return _profile_total_usec[phase]


## Build the '[profile]' summary block as a multi-line String. Pure read —
## no state change, no print — so tests can assert on the exact text without
## stdout capture. Columns per GAP-3: per-phase total ms, % of phase work,
## mean usec/tick, max usec in a single tick (+ which tick, for spotting
## spikes like spawn or first-engagement ticks).
##
## NOTE: phase work excludes tick_started/tick_ended subscriber cost and
## engine overhead between physics frames, so the derived ticks/wall-sec
## figure is an UPPER BOUND on achievable sim rate, not a prediction.
func build_profile_summary(context: String) -> String:
	if _profile_ticks_measured == 0:
		return "[profile] %s — no ticks measured (profiling_enabled=%s)" % [
			context, profiling_enabled,
		]
	var grand_total: int = 0
	for phase in PHASES:
		grand_total += int(_profile_total_usec[phase])
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[profile] ===== per-phase sim timing — %s (%d ticks measured) =====" % [
		context, _profile_ticks_measured,
	])
	lines.append("[profile] %-16s %10s %7s %13s %9s %9s" % [
		"phase", "total_ms", "pct", "mean_us/tick", "max_us", "max_tick",
	])
	for phase in PHASES:
		var total: int = int(_profile_total_usec[phase])
		var pct: float = 0.0
		if grand_total > 0:
			pct = 100.0 * float(total) / float(grand_total)
		lines.append("[profile] %-16s %10.1f %6.1f%% %13.1f %9d %9d" % [
			String(phase),
			float(total) / 1000.0,
			pct,
			float(total) / float(_profile_ticks_measured),
			int(_profile_max_usec[phase]),
			int(_profile_max_tick[phase]),
		])
	lines.append("[profile] %-16s %10.1f %6.1f%% %13.1f" % [
		"ALL_PHASES",
		float(grand_total) / 1000.0,
		100.0,
		float(grand_total) / float(_profile_ticks_measured),
	])
	if grand_total > 0:
		lines.append(("[profile] phase-work rate upper bound: ~%.1f sim-ticks/wall-sec "
				+ "(excludes engine + tick_started/tick_ended overhead)") % (
			1000000.0 * float(_profile_ticks_measured) / float(grand_total)))
	return "\n".join(lines)


## Print the summary block to stdout (the per-match log under the batch
## runner). Lines are '[profile]'-prefixed and never start with '{', so the
## batch script's `rg '^\{'` NDJSON extraction is unaffected — the block is
## a log artifact, NOT part of the NDJSON schema (balance-engineer-owned).
func print_profile_summary(context: String) -> void:
	print(build_profile_summary(context))
