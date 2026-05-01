# Tests for SimClock autoload.
#
# Contract: docs/SIMULATION_CONTRACT.md §1.2 — 30 Hz fixed tick driver,
# accumulator pattern in _physics_process, emits tick_started, sim_phase x7
# (input -> ai -> movement -> spatial_rebuild -> combat -> farr -> cleanup),
# tick_ended via EventBus. is_ticking() returns true only inside _run_tick().
extends GutTest


# Captured across the SimClock tick lifecycle.
var _events: Array = []
# Snapshot of SimClock.is_ticking() at the moment each phase signal fires.
var _is_ticking_per_phase: Array[bool] = []


func before_each() -> void:
	_events = []
	_is_ticking_per_phase = []
	# Connect listeners in this test.
	EventBus.tick_started.connect(_on_tick_started)
	EventBus.tick_ended.connect(_on_tick_ended)
	EventBus.sim_phase.connect(_on_sim_phase)
	# Sync test starts from a known SimClock state. The autoload starts at
	# tick 0; if a previous test advanced it, reset here.
	SimClock.reset()


func after_each() -> void:
	EventBus.tick_started.disconnect(_on_tick_started)
	EventBus.tick_ended.disconnect(_on_tick_ended)
	EventBus.sim_phase.disconnect(_on_sim_phase)
	SimClock.reset()


# Per-signal handlers append a structured row so we can verify ordering later.
func _on_tick_started(tick: int) -> void:
	_events.append({"kind": &"tick_started", "tick": tick, "is_ticking": SimClock.is_ticking()})


func _on_tick_ended(tick: int) -> void:
	_events.append({"kind": &"tick_ended", "tick": tick, "is_ticking": SimClock.is_ticking()})


func _on_sim_phase(phase: StringName, tick: int) -> void:
	_events.append({"kind": &"sim_phase", "phase": phase, "tick": tick})
	_is_ticking_per_phase.append(SimClock.is_ticking())


# -- Constants and shape ------------------------------------------------------

func test_sim_hz_and_dt_are_30hz() -> void:
	assert_eq(SimClock.SIM_HZ, 30)
	assert_almost_eq(SimClock.SIM_DT, 1.0 / 30.0, 1e-6)


func test_phase_order_matches_contract() -> void:
	var expected: Array[StringName] = [
		&"input", &"ai", &"movement", &"spatial_rebuild",
		&"combat", &"farr", &"cleanup",
	]
	assert_eq(SimClock.PHASES, expected, "Phase order locked by Sim Contract §1.2/§2")


# -- is_ticking semantics -----------------------------------------------------

func test_is_ticking_false_at_rest() -> void:
	assert_false(SimClock.is_ticking(), "is_ticking is false outside a tick")


func test_is_ticking_true_only_inside_run_tick() -> void:
	SimClock._test_run_tick()
	# After the tick completes is_ticking flips back to false.
	assert_false(SimClock.is_ticking(), "is_ticking returns to false after the tick")
	# Inside the tick — every phase signal observed should have is_ticking true.
	assert_eq(_is_ticking_per_phase.size(), SimClock.PHASES.size())
	for v in _is_ticking_per_phase:
		assert_true(v, "is_ticking must be true at every phase emission")


# -- Tick monotonicity --------------------------------------------------------

func test_tick_starts_at_zero() -> void:
	assert_eq(SimClock.tick, 0)
	assert_almost_eq(SimClock.sim_time, 0.0, 1e-6)


func test_tick_increments_after_each_run() -> void:
	SimClock._test_run_tick()
	assert_eq(SimClock.tick, 1)
	assert_almost_eq(SimClock.sim_time, SimClock.SIM_DT, 1e-6)
	SimClock._test_run_tick()
	assert_eq(SimClock.tick, 2)
	assert_almost_eq(SimClock.sim_time, 2.0 * SimClock.SIM_DT, 1e-6)


# -- Signal order -------------------------------------------------------------

func test_signals_fire_in_correct_order() -> void:
	SimClock._test_run_tick()
	# Expected sequence: tick_started(0), 7 sim_phase(*, 0), tick_ended(0).
	assert_eq(_events.size(), 1 + SimClock.PHASES.size() + 1)
	assert_eq(_events[0]["kind"], &"tick_started")
	assert_eq(_events[0]["tick"], 0)
	for i in range(SimClock.PHASES.size()):
		var ev: Dictionary = _events[1 + i]
		assert_eq(ev["kind"], &"sim_phase",
			"Position %d must be a sim_phase emission" % (1 + i))
		assert_eq(ev["phase"], SimClock.PHASES[i],
			"sim_phase #%d must match contract order" % i)
		assert_eq(ev["tick"], 0)
	assert_eq(_events[-1]["kind"], &"tick_ended")
	assert_eq(_events[-1]["tick"], 0)


func test_tick_started_observes_pre_increment_tick_value() -> void:
	# tick_started fires with the tick number being executed; tick increments
	# after the tick completes. After the first tick, the next started will
	# carry tick=1.
	SimClock._test_run_tick()
	SimClock._test_run_tick()
	# First tick_started had tick=0, second had tick=1.
	var starts: Array = _events.filter(func(e: Dictionary) -> bool:
		return e["kind"] == &"tick_started")
	assert_eq(starts.size(), 2)
	assert_eq(starts[0]["tick"], 0)
	assert_eq(starts[1]["tick"], 1)


# -- Accumulator behavior -----------------------------------------------------

func test_accumulator_runs_one_tick_per_dt_advanced() -> void:
	# Drive the same logic that _physics_process drives, but with synthetic delta.
	SimClock._test_advance(SimClock.SIM_DT)
	assert_eq(SimClock.tick, 1, "Exactly SIM_DT consumed should produce one tick")


func test_accumulator_runs_multiple_ticks_when_delta_large() -> void:
	# 3.5 * SIM_DT advances should yield 3 ticks; 0.5 * SIM_DT remains in the
	# accumulator for the next call.
	SimClock._test_advance(SimClock.SIM_DT * 3.5)
	assert_eq(SimClock.tick, 3, "Three full SIM_DT periods consumed")
	# Adding another 0.5 dt should now top up to 4 ticks.
	SimClock._test_advance(SimClock.SIM_DT * 0.5)
	assert_eq(SimClock.tick, 4)


func test_accumulator_does_not_tick_on_subdt_delta() -> void:
	SimClock._test_advance(SimClock.SIM_DT * 0.4)
	assert_eq(SimClock.tick, 0, "Sub-dt advance should not produce a tick")
