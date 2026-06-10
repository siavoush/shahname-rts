# Integration test — §9.B5 probe RESOLUTION: throne-destruction grace window
# + live event-counter aggregation (result-format v1.1.0, Track B2).
#
# Provenance: Wave 3-Sim grace-period question. Loremaster (p3s5) flagged
# three engineering-side risks against the immediate-exit-on-throne_destroyed
# implementation shipped at PR #52 / bae1028:
#   1. Mid-tick state snapshot — _capture_team_fields runs synchronously from
#      _on_throne_destroyed, before remaining same-tick sim_phase emits
#      complete.
#   2. NDJSON event ordering — same-tick events (death emits, last damage)
#      that fire AFTER the runner's _on_throne_destroyed handler may or may
#      not be visible in the captured state.
#   3. Behavioral-tuning signal — different match-end shapes (champion duel
#      vs unit-flood vs simultaneous-death) produce different downstream
#      cultural-mechanic implications; the trailing same-tick events
#      disambiguate which scenario actually ended the match.
#
# PROBE HISTORY (PR #54): engine-architect's probe found the three concerns
# "SEMANTICALLY REAL but EMPIRICALLY NEUTRAL while the event counters are
# hardcoded 0". The probe's pinned conclusion: "when the deferred counters
# (units_killed_total, buildings_destroyed_total) get wired in a follow-up
# wave, that wave SHOULD ship the grace-period alongside." The original
# test_event_counters_are_deferred_not_aggregated existed to FAIL when the
# counters got wired, forcing this re-evaluation.
#
# RE-EVALUATION (result-format v1.1.0, this file's current state): the
# counters ARE wired (EventBus.unit_died / building_destroyed / farr_changed
# / unit_spawned aggregation in the runner), so the concerns became real and
# the pinned resolution shipped: a deterministic grace window of
# Constants.SIM_THRONE_GRACE_TICKS sim ticks. On the first throne_destroyed
# the runner latches winner/outcome/duration_ticks (throne-fall tick) and
# keeps every subscription alive; the NDJSON emit + quit happen in the
# sim_phase &"cleanup" handler on the first tick where
# SimClock.tick >= grace_end_tick. The tests below REPLACE the deferred-
# counter pins with the new invariants:
#   - counters aggregate from live EventBus emits
#   - same-tick + during-grace events ARE counted
#   - the emit fires exactly at grace_end_tick (tick-deterministic)
#   - duration_ticks records the throne-fall tick, grace excluded
#   - second throne_destroyed during grace cannot flip the latched result
extends GutTest


const RunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


var _runner: Variant = null


func before_each() -> void:
	SimClock.reset()
	TuranController.reset()
	_runner = RunnerScript.new()
	_runner.set(&"_test_skip_emit", true)
	# Full wiring fidelity (BUG-D1 discipline): use the runner's own
	# _subscribe_signals so the tests exercise the REAL connection set —
	# throne_destroyed, unit_health_zero, unit_spawned, unit_died,
	# building_destroyed, farr_changed, sim_phase.
	_runner.call(&"_subscribe_signals")


func after_each() -> void:
	if _runner != null:
		_runner.call(&"_disconnect_signals")
		_runner.free()
		_runner = null
	SimClock.reset()
	TuranController.reset()


# Helper: advance SimClock by n ticks via the canonical Sim Contract §6.1
# test path. Because the runner's _on_sim_phase is genuinely connected,
# every advanced tick drives the grace/timeout boundary checks exactly as
# a live run would.
func _advance_ticks(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# ---------------------------------------------------------------------------
# Invariant 1: throne_destroyed latches the result + arms the grace window
# synchronously — it does NOT end the match.
# ---------------------------------------------------------------------------

func test_throne_destroyed_latches_grace_synchronously() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_true(bool(_runner.get(&"_grace_active")),
		"throne_destroyed must arm the grace window synchronously")
	assert_false(bool(_runner.get(&"_match_ended")),
		"throne_destroyed must NOT end the match — emit happens at grace end")
	assert_eq(_runner.get(&"_outcome"), "turan_win",
		"winner must be latched at throne fall")
	assert_eq(int(_runner.get(&"_grace_end_tick")),
		SimClock.tick + Constants.SIM_THRONE_GRACE_TICKS,
		"grace_end_tick must be throne-fall tick + SIM_THRONE_GRACE_TICKS")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 5,
		"duration_ticks must be latched at the throne-fall tick")


# ---------------------------------------------------------------------------
# Invariant 2: events firing AFTER throne_destroyed (same tick or during the
# grace window) ARE counted — subscriptions stay live until the emit.
# ---------------------------------------------------------------------------

func test_same_tick_events_after_throne_destroyed_are_counted() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_eq(int(_runner.get(&"_units_killed_total")), 0,
		"pre-cascade: no kills counted yet")
	# Same-tick cascade: the defender that landed the killing blow dies to a
	# counter-attack; a building collapses; a Farr drain lands.
	EventBus.unit_died.emit(99, 12, &"melee_attack", Vector3.ZERO)
	EventBus.building_destroyed.emit(Constants.TEAM_IRAN, &"khaneh", 201)
	EventBus.farr_changed.emit(-1.0, "worker_killed_idle", 99, 49.0, SimClock.tick)
	assert_eq(int(_runner.get(&"_units_killed_total")), 1,
		"unit_died after throne fall must still be counted (grace live)")
	assert_eq(int(_runner.get(&"_buildings_destroyed_iran")), 1,
		"building_destroyed after throne fall must still be counted")
	assert_eq(int(_runner.get(&"_farr_drain_events_total")), 1,
		"negative farr_changed after throne fall must still be counted")
	assert_false(bool(_runner.get(&"_match_ended")),
		"match must still be open inside the grace window")


func test_events_during_grace_ticks_are_counted() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	# Trailing events several ticks INTO the grace window.
	_advance_ticks(3)
	EventBus.unit_died.emit(42, -1, &"farr_drain", Vector3.ZERO)
	EventBus.unit_died.emit(43, -1, &"farr_drain", Vector3.ZERO)
	assert_eq(int(_runner.get(&"_units_killed_total")), 2,
		"deaths during grace ticks must be counted")
	assert_false(bool(_runner.get(&"_match_ended")),
		"grace window must still be open at fall_tick + 3")


# ---------------------------------------------------------------------------
# Invariant 3: counters aggregate from live EventBus emits and surface in
# the assembled result dict (events block + per-team buildings_destroyed).
# ---------------------------------------------------------------------------

func test_event_counters_aggregate_into_result_dict() -> void:
	_advance_ticks(1)
	# Kills: unit-only channel.
	EventBus.unit_died.emit(10, 20, &"melee_attack", Vector3.ZERO)
	EventBus.unit_died.emit(11, 21, &"melee_attack", Vector3.ZERO)
	# Buildings: one per team + a Throne (excluded per schema §2.2).
	EventBus.building_destroyed.emit(Constants.TEAM_IRAN, &"khaneh", 201)
	EventBus.building_destroyed.emit(Constants.TEAM_TURAN, &"sarbaz_khaneh", 202)
	EventBus.building_destroyed.emit(Constants.TEAM_IRAN, &"throne", 203)
	# Farr: 3 drains, 1 generation (only drains count), 1 zero-delta clamp.
	EventBus.farr_changed.emit(-1.0, "worker_killed_idle", 10, 49.0, SimClock.tick)
	EventBus.farr_changed.emit(-0.5, "worker_killed_during_gather", 11, 48.5, SimClock.tick)
	EventBus.farr_changed.emit(-2.0, "snowball_drain", -1, 46.5, SimClock.tick)
	EventBus.farr_changed.emit(2.0, "atashkadeh_generation", -1, 48.5, SimClock.tick)
	EventBus.farr_changed.emit(0.0, "drain_clamped_at_floor", -1, 0.0, SimClock.tick)
	# Turan deployments via unit_spawned (Iran spawn must not count).
	EventBus.unit_spawned.emit({&"unit_type": &"piyade",
		&"team": Constants.TEAM_TURAN, &"unit_id": 50, &"position": Vector3.ZERO})
	EventBus.unit_spawned.emit({&"unit_type": &"savar",
		&"team": Constants.TEAM_TURAN, &"unit_id": 51, &"position": Vector3.ZERO})
	EventBus.unit_spawned.emit({&"unit_type": &"piyade",
		&"team": Constants.TEAM_IRAN, &"unit_id": 52, &"position": Vector3.ZERO})

	assert_eq(int(_runner.get(&"_units_killed_total")), 2)
	assert_eq(int(_runner.get(&"_buildings_destroyed_iran")), 1,
		"Iran khaneh counted; Iran THRONE excluded (win-condition, not stat)")
	assert_eq(int(_runner.get(&"_buildings_destroyed_turan")), 1)
	assert_eq(int(_runner.get(&"_farr_drain_events_total")), 3,
		"only negative effective deltas count (not generation, not 0.0 clamp)")
	assert_eq(int(_runner.get(&"_turan_units_deployed_total")), 2,
		"only team==TURAN unit_spawned emits count")

	# Round the counters through _assemble_result_dict — the events block
	# must surface them, and buildings_destroyed_total must equal the sum
	# of the per-team counters carried in the team dicts.
	var iran: Dictionary = _team_fixture(int(_runner.get(&"_buildings_destroyed_iran")))
	var turan: Dictionary = _team_fixture(int(_runner.get(&"_buildings_destroyed_turan")))
	var result: Dictionary = _runner.call(&"_assemble_result_dict", 100, iran, turan)
	var events: Dictionary = result.get("events")
	assert_eq(int(events.get("units_killed_total")), 2,
		"events.units_killed_total must surface the aggregated counter")
	assert_eq(int(events.get("buildings_destroyed_total")), 2,
		"events.buildings_destroyed_total must sum per-team counters")
	assert_eq(int(events.get("farr_drain_events_total")), 3,
		"events.farr_drain_events_total must surface the aggregated counter")
	assert_eq(int(events.get("turan_units_deployed_total")), 2,
		"events.turan_units_deployed_total must surface the aggregated counter")


# ---------------------------------------------------------------------------
# Invariant 3b (session-11 integration fix-up): production counters — the
# last two GP-6 zero-fields. tick > 0 is the production-source
# discriminator; building_constructed is the Stage-2 completion channel.
# ---------------------------------------------------------------------------

func test_production_counters_discriminate_roster_from_produced() -> void:
	# Tick 0: match-start roster spawns — must NOT count as produced and
	# must NOT latch first_piyade (observation-smoke regression: the latch
	# caught pre-spawned roster piyades at tick 0, dead-at-0 every match).
	EventBus.unit_spawned.emit({&"unit_type": &"piyade",
		&"team": Constants.TEAM_IRAN, &"unit_id": 60, &"position": Vector3.ZERO})
	EventBus.unit_spawned.emit({&"unit_type": &"kargar",
		&"team": Constants.TEAM_IRAN, &"unit_id": 61, &"position": Vector3.ZERO})
	assert_eq(int(_runner.get(&"_units_produced_iran")), 0,
		"tick-0 roster spawns are structural, not produced (schema §2.2)")
	assert_eq(int(_runner.get(&"_iran_first_piyade_tick")), -1,
		"tick-0 roster piyade must NOT latch first_piyade — the field "
		+ "validates BUILD-ORDER production timing, not match-start spawns")

	# Tick > 0: produced units count + latch fires with the real tick.
	_advance_ticks(7)
	EventBus.unit_spawned.emit({&"unit_type": &"piyade",
		&"team": Constants.TEAM_IRAN, &"unit_id": 62, &"position": Vector3.ZERO})
	EventBus.unit_spawned.emit({&"unit_type": &"savar",
		&"team": Constants.TEAM_TURAN, &"unit_id": 63, &"position": Vector3.ZERO})
	assert_eq(int(_runner.get(&"_units_produced_iran")), 1,
		"tick>0 Iran spawn counts as produced")
	assert_eq(int(_runner.get(&"_units_produced_turan")), 1,
		"tick>0 Turan spawn counts as produced")
	assert_eq(int(_runner.get(&"_iran_first_piyade_tick")), 7,
		"first TRAINED piyade latches at its spawn tick")

	# Stage-2 completions count per team; surfaces in the team dicts.
	EventBus.building_constructed.emit(Constants.TEAM_IRAN, &"khaneh", 301)
	EventBus.building_constructed.emit(Constants.TEAM_IRAN, &"mazraeh", 302)
	EventBus.building_constructed.emit(Constants.TEAM_TURAN, &"khaneh", 303)
	assert_eq(int(_runner.get(&"_buildings_constructed_iran")), 2)
	assert_eq(int(_runner.get(&"_buildings_constructed_turan")), 1)

	# The live surfacing seam is _capture_team_fields (NOT _assemble's
	# verbatim pass-through) — call it directly and assert the two
	# formerly-hardcoded-0 keys now carry the per-team counters.
	var iran_captured: Dictionary = _runner.call(
		&"_capture_team_fields", Constants.TEAM_IRAN)
	var turan_captured: Dictionary = _runner.call(
		&"_capture_team_fields", Constants.TEAM_TURAN)
	assert_eq(int(iran_captured.get("units_produced_total")), 1,
		"iran.units_produced_total must surface the per-team counter "
		+ "(was hardcoded 0 — GP-6)")
	assert_eq(int(iran_captured.get("buildings_constructed_total")), 2,
		"iran.buildings_constructed_total must surface the per-team counter "
		+ "(was hardcoded 0 — GP-6)")
	assert_eq(int(turan_captured.get("buildings_constructed_total")), 1,
		"turan.buildings_constructed_total must surface the per-team counter")


# ---------------------------------------------------------------------------
# Invariant 4: the NDJSON emit happens exactly at grace_end_tick — tick-
# deterministic, independent of frame pacing.
# ---------------------------------------------------------------------------

func test_emit_happens_exactly_at_grace_end_tick() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)
	var grace_end: int = int(_runner.get(&"_grace_end_tick"))
	assert_eq(grace_end, 5 + Constants.SIM_THRONE_GRACE_TICKS)
	# Advance one tick at a time; record the tick DURING which the runner
	# sealed the match. The cleanup handler fires while SimClock.tick is
	# still the running tick's index (increment happens at tick end).
	var sealed_during_tick: int = -1
	for _i in range(Constants.SIM_THRONE_GRACE_TICKS + 5):
		var tick_being_run: int = SimClock.tick
		SimClock._test_run_tick()
		if bool(_runner.get(&"_match_ended")):
			sealed_during_tick = tick_being_run
			break
	assert_eq(sealed_during_tick, grace_end,
		"runner must seal the match during the tick where SimClock.tick == "
		+ "grace_end_tick — no earlier, no later")


func test_duration_records_throne_fall_tick_not_emit_tick() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)
	_advance_ticks(Constants.SIM_THRONE_GRACE_TICKS + 2)
	assert_true(bool(_runner.get(&"_match_ended")),
		"grace must have elapsed by fall_tick + GRACE + 2")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 5,
		"duration_ticks must record the THRONE-FALL tick (grace excluded) — "
		+ "pacing-signal purity per AI_VS_AI_RESULT_FORMAT §2.2 v1.1.0")


# ---------------------------------------------------------------------------
# Invariant 5: a second throne_destroyed during the grace window cannot flip
# the latched result (first-throne-wins).
# ---------------------------------------------------------------------------

func test_second_throne_destroyed_during_grace_is_ignored() -> void:
	_advance_ticks(5)
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_eq(_runner.get(&"_outcome"), "turan_win")
	# Mutual-destruction cascade: the other throne falls inside the grace.
	_advance_ticks(2)
	EventBus.throne_destroyed.emit(Constants.TEAM_TURAN)
	assert_eq(_runner.get(&"_outcome"), "turan_win",
		"second throne fall during grace must NOT flip the latched outcome")
	assert_eq(int(_runner.get(&"_winner_team")), Constants.TEAM_TURAN,
		"second throne fall during grace must NOT flip the latched winner")
	assert_eq(int(_runner.get(&"_result_duration_ticks")), 5,
		"second throne fall during grace must NOT re-latch duration")


# ---------------------------------------------------------------------------
# Probe Q3 (retained from PR #54): captured-state fields are primitives —
# no in-tick mutation surface for sibling handlers.
# ---------------------------------------------------------------------------

func test_captured_field_set_is_stable_within_one_tick() -> void:
	# The captured per-team fields are all primitives (int/float/bool); even
	# if more handlers fire AFTER the runner's within the same emit chain,
	# the captured field set is invariant. With the grace window the capture
	# now happens at grace-end cleanup — strictly LATER than every same-tick
	# gameplay emit, which strengthens the original finding.
	var iran: Dictionary = _team_fixture(0)
	var turan: Dictionary = iran.duplicate()
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 100, iran, turan)
	for field: String in [
			"workers_alive_at_end", "combat_units_alive_at_end",
			"buildings_alive_at_end", "throne_destroyed",
			"throne_hp_pct_at_end", "coin_x100_at_end",
			"grain_x100_at_end", "farr_x100_at_end"]:
		var v: Variant = result.iran.get(field)
		assert_true(v is int or v is float or v is bool,
			"%s must be primitive (no in-tick mutation surface)" % field)


# ---------------------------------------------------------------------------
# Probe Q5 (retained, updated): runner subscribes first in the
# throne_destroyed handler chain; emit doesn't short-circuit late handlers.
# ---------------------------------------------------------------------------

func test_runner_subscribes_first_in_throne_destroyed_handler_chain() -> void:
	# By construction (main.gd._ready spawns the runner BEFORE
	# _spawn_starting_buildings/_spawn_starting_units), the runner's
	# throne_destroyed subscription connects first. Late subscribers still
	# fire — and with the grace window they fire while the match is still
	# OPEN, so any state they mutate is captured at grace-end.
	var late_handler_called: Array[bool] = [false]
	var late_handler: Callable = func(_team: int) -> void:
		late_handler_called[0] = true
	EventBus.throne_destroyed.connect(late_handler)
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_true(bool(_runner.get(&"_grace_active")),
		"runner's _on_throne_destroyed must have run (grace armed)")
	assert_true(late_handler_called[0],
		"late-subscribed handler must STILL run — emit doesn't short-circuit")
	EventBus.throne_destroyed.disconnect(late_handler)


# ---------------------------------------------------------------------------
# Fixture helper — canonical per-team dict shape (schema §2.1).
# ---------------------------------------------------------------------------

func _team_fixture(buildings_destroyed: int) -> Dictionary:
	return {
		"throne_destroyed": false,
		"throne_hp_pct_at_end": 100.0,
		"workers_alive_at_end": 5,
		"combat_units_alive_at_end": 14,
		"buildings_alive_at_end": 0,
		"buildings_destroyed": buildings_destroyed,
		"coin_x100_at_end": 15000,
		"grain_x100_at_end": 5000,
		"farr_x100_at_end": 5000,
		"units_produced_total": 0,
		"buildings_constructed_total": 0,
	}
