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
const PHASES: Array[StringName] = [
	&"input", &"ai", &"movement", &"spatial_rebuild",
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
## don't leak tick counts across cases.
func reset() -> void:
	tick = 0
	sim_time = 0.0
	_is_ticking = false
	_accumulator = 0.0
