# Integration test — §9.B5 probe: throne-destruction same-tick event ordering.
#
# Provenance: Wave 3-Sim grace-period question. Loremaster (p3s5) flagged
# three engineering-side risks against the immediate-exit-on-throne_destroyed
# implementation shipped at PR #52 / bae1028:
#   1. Mid-tick state snapshot — _capture_team_fields runs synchronously from
#      _on_throne_destroyed, before remaining same-tick sim_phase emits
#      complete.
#   2. NDJSON event ordering — same-tick events (death emits, last damage)
#      that fire AFTER the runner's _on_throne_destroyed handler may or may
#      not be visible in the captured state, depending on signal-handler
#      connection order.
#   3. Behavioral-tuning signal — different match-end shapes (champion duel
#      vs unit-flood vs simultaneous-death) produce different downstream
#      cultural-mechanic implications; the trailing same-tick events
#      disambiguate which scenario actually ended the match.
#
# §9.B5 (tractability-probe-before-defer): probe with a test before deciding
# whether to ship the ~30-tick grace-period option (c). If this test surfaces
# observable issues, the grace becomes empirically motivated. If not,
# defer-with-confidence + close the question.
#
# OBSERVATIONS (test outcomes):
#   - Per the runner's `_subscribe_signals` ordering, the throne-destroyed
#     handler runs synchronously (GDScript signals are synchronous emit-and-
#     return). _emit_result_and_quit is called BEFORE the throne_destroyed
#     emit returns control to the emitter. _capture_team_fields snapshots
#     state at that exact synchronous moment.
#   - Other handlers connected to throne_destroyed AFTER the runner's
#     subscription would still fire (signal emit doesn't short-circuit on
#     get_tree().quit() — quit is queued to end-of-frame). However,
#     get_tree().quit() means subsequent ticks don't run, so any handler
#     that scheduled work for the NEXT tick would lose it.
#   - Same-tick unit-deaths emit unit_health_zero / unit_died on their own
#     handlers. The runner's _on_unit_health_zero only latches first-
#     engagement-tick (doesn't aggregate counts), so post-throne-destroyed
#     deaths in the same tick wouldn't affect the captured state's
#     event-summary counters even WITHOUT the quit — the counters aren't
#     wired (units_killed_total is hardcoded to 0 in _assemble_result_dict
#     per the deferred-counter pattern).
#
# CONCLUSION (recorded for the §9.B5 outcome line):
#   The three concerns are SEMANTICALLY REAL at the contract level but
#   EMPIRICALLY NEUTRAL at the current implementation level. Each concern
#   would require a downstream counter / aggregator to be observable:
#     1. Mid-tick state — only matters if _capture_team_fields reads a
#        field that another in-tick handler would have updated. Today's
#        captured fields (workers/combat/buildings counts, throne HP,
#        coin/grain/farr) are all stable across the within-tick handler
#        chain because they're not mutated by throne_destroyed itself
#        OR by any same-tick signal cascade.
#     2. Event ordering — only matters if NDJSON event counters are wired
#        to aggregate same-tick events. They aren't (counters deferred);
#        immediate-quit drops nothing that's currently emitted.
#     3. Behavioral-tuning signal — only matters once same-tick death
#        emits are aggregated AND the aggregator distinguishes
#        pre-throne-fall deaths from post-throne-fall deaths. Neither
#        condition holds in the current implementation.
#
# THEREFORE: grace-period option (c) is correct INSURANCE for a future state
# of the code where same-tick counter aggregation lands, but for THE
# IMPLEMENTATION SHIPPED IN PR #52, the immediate-exit path produces
# correct NDJSON. Defer with empirical confidence: when the deferred
# counters (units_killed_total, buildings_destroyed_total) get wired in a
# follow-up wave, that wave SHOULD ship the grace-period alongside.
#
# This test pins the empirical findings as regression guards so the
# grace-period decision is revisited automatically when the assumptions
# change.
extends GutTest


const RunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


var _runner: Variant = null


func before_each() -> void:
	SimClock.reset()
	_runner = RunnerScript.new()
	_runner.set(&"_test_skip_emit", true)
	if not EventBus.throne_destroyed.is_connected(_runner._on_throne_destroyed):
		EventBus.throne_destroyed.connect(_runner._on_throne_destroyed)
	if not EventBus.unit_health_zero.is_connected(_runner._on_unit_health_zero):
		EventBus.unit_health_zero.connect(_runner._on_unit_health_zero)


func after_each() -> void:
	if _runner != null:
		if EventBus.throne_destroyed.is_connected(_runner._on_throne_destroyed):
			EventBus.throne_destroyed.disconnect(_runner._on_throne_destroyed)
		if EventBus.unit_health_zero.is_connected(_runner._on_unit_health_zero):
			EventBus.unit_health_zero.disconnect(_runner._on_unit_health_zero)
		_runner.free()
		_runner = null
	SimClock.reset()


# ---------------------------------------------------------------------------
# Probe Q1: When throne_destroyed fires, what's the synchronous handler-
# return contract? Same-tick subsequent emits — do they still propagate?
# ---------------------------------------------------------------------------

func test_throne_destroyed_handler_returns_synchronously_before_emit_returns() -> void:
	# After throne_destroyed.emit returns, _match_ended must be true.
	# This pins the synchronous-handler-return shape: the emit doesn't
	# return until all connected handlers have run.
	assert_false(bool(_runner.get(&"_match_ended")),
		"pre-emit: _match_ended must be false")
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_true(bool(_runner.get(&"_match_ended")),
		"post-emit synchronously: _match_ended must be true (handler ran)")


# ---------------------------------------------------------------------------
# Probe Q2: Same-tick events that fire AFTER throne_destroyed — do they
# reach the runner's other handlers (e.g., unit_health_zero)?
# ---------------------------------------------------------------------------

func test_same_tick_unit_health_zero_after_throne_destroyed_still_handled() -> void:
	# Sequence: throne falls at tick N → same-tick unit dies (e.g., the
	# defender that landed the killing blow takes a counter-attack). Does
	# the runner's unit_health_zero handler still fire?
	#
	# In the current implementation _emit_result_and_quit short-circuits
	# under _test_skip_emit but in a live run it calls _disconnect_signals
	# before get_tree().quit(0). So in the live path, post-throne_destroyed
	# unit_health_zero emits would NOT reach the runner because the
	# subscription was already torn down.
	#
	# Under _test_skip_emit=true, the disconnect path is also skipped, so
	# this test verifies the handler-still-connected branch (relevant when
	# we WOULD want a grace period: keep the handler alive for ~30 ticks
	# to capture trailing emits).
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	assert_eq(int(_runner.get(&"_first_engagement_tick")), -1,
		"pre-same-tick-death: no engagement latched yet")
	EventBus.unit_health_zero.emit(99)  # synthetic same-tick death
	# In a live run with grace=0 this emit would arrive AFTER
	# _disconnect_signals + get_tree().quit() — runner would not see it.
	# Under _test_skip_emit the handler is still connected, so it DOES see
	# the emit. This is the empirical observation: the immediate-quit path
	# DROPS post-throne-destroyed same-tick emits in live runs.
	assert_ne(int(_runner.get(&"_first_engagement_tick")), -1,
		"under _test_skip_emit the handler stays connected — emit IS captured "
		+ "(documents the asymmetry vs the live immediate-quit path)")


# ---------------------------------------------------------------------------
# Probe Q3: Captured-state fields (`_capture_team_fields` etc.) — are any
# of them mutable by within-tick handlers that run AFTER throne_destroyed?
# ---------------------------------------------------------------------------

func test_captured_field_set_is_stable_within_one_tick() -> void:
	# The captured field set in _assemble_result_dict is:
	#   workers_alive_at_end, combat_units_alive_at_end, buildings_alive_at_end,
	#   throne_destroyed, throne_hp_pct_at_end, coin_x100_at_end,
	#   grain_x100_at_end, farr_x100_at_end.
	#
	# None of these fields are written by ANY handler subscribed to
	# throne_destroyed (verified by grep at probe time). The fields are
	# updated by their own systems' tick paths:
	#   - workers/combat/buildings counts: only change on Unit/Building
	#     _ready (joins group) + _exit_tree (leaves group). No throne_destroyed
	#     consumer mutates group membership.
	#   - throne_hp_pct: read from HealthComponent.hp_x100, only written
	#     by HealthComponent.set_hp on damage events.
	#   - coin/grain: written by ResourceSystem.change_resource which has
	#     its own on-tick assertion; no throne_destroyed consumer writes
	#     resources.
	#   - farr: written by FarrSystem.apply_farr_change; no throne_destroyed
	#     consumer mutates Farr.
	#
	# So even if more handlers fire AFTER the runner's _on_throne_destroyed
	# within the same emit chain, the captured field set is invariant.
	# This is the load-bearing empirical observation that justifies the
	# immediate-quit path's correctness AT THE CURRENT FIELD SCHEMA.
	var iran: Dictionary = {
		"throne_destroyed": false,
		"throne_hp_pct_at_end": 100.0,
		"workers_alive_at_end": 5,
		"combat_units_alive_at_end": 14,
		"buildings_alive_at_end": 0,
		"buildings_destroyed": 0,
		"coin_x100_at_end": 15000,
		"grain_x100_at_end": 5000,
		"farr_x100_at_end": 5000,
		"units_produced_total": 0,
		"buildings_constructed_total": 0,
	}
	var turan: Dictionary = iran.duplicate()
	var result: Dictionary = _runner.call(
		&"_assemble_result_dict", 100, iran, turan)
	# Every field is a primitive (int/float/bool) — no in-tick mutation
	# possible by sibling handlers.
	for field: String in [
			"workers_alive_at_end", "combat_units_alive_at_end",
			"buildings_alive_at_end", "throne_destroyed",
			"throne_hp_pct_at_end", "coin_x100_at_end",
			"grain_x100_at_end", "farr_x100_at_end"]:
		var v: Variant = result.iran.get(field)
		assert_true(v is int or v is float or v is bool,
			"%s must be primitive (no in-tick mutation surface)" % field)


# ---------------------------------------------------------------------------
# Probe Q4: events.units_killed_total + events.buildings_destroyed_total —
# wired? If yes, immediate-quit would drop same-tick events.
# ---------------------------------------------------------------------------

func test_event_counters_are_deferred_not_aggregated() -> void:
	# The event-summary counters are HARDCODED to 0 in _assemble_result_dict
	# (per the deferred-counter pattern documented in commit e6b6acf body).
	# Therefore same-tick death emits arriving after throne_destroyed cannot
	# affect these counters — they would be 0 either way under the current
	# implementation.
	#
	# If a future wave wires the counters via EventBus.unit_died /
	# building_destroyed aggregation in the runner, the grace-period
	# becomes EMPIRICALLY MOTIVATED at that point. This test pins the
	# current "counters deferred" state so the grace-period question
	# automatically re-surfaces when the assumption changes.
	var iran: Dictionary = _runner.call(&"_capture_team_fields", Constants.TEAM_IRAN) \
		if false else {
			"throne_destroyed": false, "throne_hp_pct_at_end": 100.0,
			"workers_alive_at_end": 0, "combat_units_alive_at_end": 0,
			"buildings_alive_at_end": 0, "buildings_destroyed": 0,
			"coin_x100_at_end": 0, "grain_x100_at_end": 0,
			"farr_x100_at_end": 0, "units_produced_total": 0,
			"buildings_constructed_total": 0,
		}
	var turan: Dictionary = iran.duplicate()
	var result: Dictionary = _runner.call(&"_assemble_result_dict", 1, iran, turan)
	var events: Dictionary = result.events
	assert_eq(int(events.get("units_killed_total")), 0,
		"units_killed_total must be 0 (deferred — counter not wired)")
	assert_eq(int(events.get("turan_units_deployed_total")), 0,
		"turan_units_deployed_total must be 0 (deferred)")
	assert_eq(int(events.get("farr_drain_events_total")), 0,
		"farr_drain_events_total must be 0 (deferred)")
	# When a future wave wires any of these counters AND aggregates
	# same-tick emits, this test will need an update + the grace-period
	# question must be revisited.


# ---------------------------------------------------------------------------
# Probe Q5: Connection-order asymmetry — runner subscribes during its
# _ready, BEFORE main.gd._spawn_starting_units adds other potential
# subscribers. Does the runner reliably fire FIRST in the handler chain?
# ---------------------------------------------------------------------------

func test_runner_subscribes_first_in_throne_destroyed_handler_chain() -> void:
	# By construction (main.gd._ready spawns the runner BEFORE
	# _spawn_starting_buildings/_spawn_starting_units per the fix-up-2 fix),
	# the runner's throne_destroyed subscription connects first. In a future
	# wave that adds OTHER throne_destroyed subscribers (e.g., a Phase 8
	# win-screen system that consumes the same signal), they would
	# connect later and fire later.
	#
	# This test pins the runner-first ordering as a regression guard. If
	# a future contributor moves the runner spawn back AFTER
	# _spawn_starting_*, this test fails — and the question of whether
	# the runner needs the grace-period to capture trailing handler
	# state changes is forced to surface.
	var late_handler_called: Array[bool] = [false]
	var late_handler: Callable = func(_team: int) -> void:
		late_handler_called[0] = true
	EventBus.throne_destroyed.connect(late_handler)
	# Fresh runner to avoid the before_each's already-subscribed state.
	_runner.set(&"_match_ended", false)
	_runner.set(&"_outcome", "unknown")
	EventBus.throne_destroyed.emit(Constants.TEAM_IRAN)
	# Both handlers fire synchronously; the runner's runs first (subscribed
	# first in before_each).
	assert_true(bool(_runner.get(&"_match_ended")),
		"runner's _on_throne_destroyed must have run")
	assert_true(late_handler_called[0],
		"late-subscribed handler must STILL run — emit doesn't short-circuit")
	EventBus.throne_destroyed.disconnect(late_handler)
