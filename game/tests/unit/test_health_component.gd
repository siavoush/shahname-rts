# Tests for HealthComponent.
#
# Contract: docs/SIMULATION_CONTRACT.md §1.3 (SimNode discipline) + §1.6
# (fixed-point) + docs/STATE_MACHINE_CONTRACT.md §4 (death preempt via
# EventBus.unit_health_zero).
#
# What we cover:
#   - init_max_hp sets both max and current hp to full
#   - hp / max_hp accessors return float; is_alive returns bool
#   - take_damage decreases hp, clamps to 0, never goes negative
#   - take_damage at hp=0 fires EventBus.unit_health_zero exactly once
#   - over-kill (further damage past 0) does NOT re-emit unit_health_zero
#   - heal increases hp, clamps to max_hp
#   - on-tick mutation works (within SimClock _test_run_tick)
#   - fixed-point arithmetic doesn't drift across many small deltas
extends GutTest


# Preload by path so this test parses cleanly under GUT regardless of
# class_name registry order. Same pattern as test_mock_path_scheduler.gd.
const HealthComponentScript: Script = preload("res://scripts/units/components/health_component.gd")


# Untyped Variant container holds the component reference.
var _hc: Variant
var _captured_zero_emits: Array[int] = []


func before_each() -> void:
	SimClock.reset()
	_captured_zero_emits.clear()
	_hc = HealthComponentScript.new()
	# Components extend SimNode/Node; add as a child of the test root so
	# its _ready and _exit_tree fire the same way they would in a unit scene.
	add_child_autofree(_hc)
	_hc.unit_id = 42
	# Subscribe to capture death emissions deterministically.
	EventBus.unit_health_zero.connect(_on_unit_health_zero)


func after_each() -> void:
	if EventBus.unit_health_zero.is_connected(_on_unit_health_zero):
		EventBus.unit_health_zero.disconnect(_on_unit_health_zero)
	SimClock.reset()


func _on_unit_health_zero(unit_id: int) -> void:
	_captured_zero_emits.append(unit_id)


# Helper: wrap a closure-style mutation inside a tick boundary so _set_sim
# asserts are satisfied. GUT can't run code "inside" SimClock's emit loop,
# so we open a single tick around the body via _is_ticking flip — same
# discipline as MatchHarness.advance_ticks and the FarrSystem tests.
#
# We simulate exactly one tick so SimClock.is_ticking() returns true while
# the body executes. The body mutates the HealthComponent.
func _on_tick(body: Callable) -> void:
	# Drive a real tick so the assert in _set_sim passes. We can't reach
	# inside the tick from a callable cleanly because the contract says we
	# don't call _sim_tick directly — but we can flip _is_ticking the same
	# way the live driver does and run the body. This mirrors the pattern
	# used by FarrSystem tests (tests/unit/test_farr_system.gd).
	SimClock._is_ticking = true
	body.call()
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# init_max_hp
# ---------------------------------------------------------------------------

func test_init_max_hp_sets_both_max_and_current_to_full() -> void:
	_hc.init_max_hp(60.0)
	assert_eq(_hc.max_hp_x100, 6000, "max_hp_x100 stored as fixed-point")
	assert_eq(_hc.hp_x100, 6000, "hp_x100 starts at full")
	assert_eq(_hc.hp, 60.0, "hp accessor returns float")
	assert_eq(_hc.max_hp, 60.0, "max_hp accessor returns float")


func test_init_max_hp_clamps_negative_to_zero() -> void:
	# Defensive: a misconfigured BalanceData entry shouldn't make hp negative.
	_hc.init_max_hp(-10.0)
	assert_eq(_hc.max_hp_x100, 0)
	assert_eq(_hc.hp_x100, 0)


func test_init_max_hp_rounds_fractional_correctly() -> void:
	# 60.5 * 100 = 6050; 60.554 * 100 = 6055.4 -> roundi = 6055.
	_hc.init_max_hp(60.554)
	assert_eq(_hc.max_hp_x100, 6055)


# ---------------------------------------------------------------------------
# is_alive
# ---------------------------------------------------------------------------

func test_is_alive_true_at_full_hp() -> void:
	_hc.init_max_hp(60.0)
	assert_true(_hc.is_alive, "is_alive must be true when hp > 0")


func test_is_alive_false_at_zero() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(60.0, null))
	assert_false(_hc.is_alive, "is_alive must be false when hp == 0")


# ---------------------------------------------------------------------------
# take_damage
# ---------------------------------------------------------------------------

func test_take_damage_decreases_hp() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(20.0, null))
	assert_eq(_hc.hp_x100, 4000, "hp_x100 = 60.0 - 20.0 = 40.0 = 4000 fixed")
	assert_eq(_hc.hp, 40.0)


func test_take_damage_clamps_at_zero() -> void:
	_hc.init_max_hp(60.0)
	# Massive overkill — must clamp to 0, not go negative.
	_on_tick(func() -> void: _hc.take_damage(1000.0, null))
	assert_eq(_hc.hp_x100, 0, "hp_x100 must clamp at 0, not go negative")
	assert_eq(_hc.hp, 0.0)


func test_take_damage_emits_unit_health_zero_at_zero() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(60.0, null))
	assert_eq(_captured_zero_emits.size(), 1,
		"unit_health_zero must fire exactly once when hp reaches 0")
	assert_eq(_captured_zero_emits[0], 42, "emission carries the component's unit_id")


func test_take_damage_does_not_emit_above_zero() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(20.0, null))
	assert_eq(_captured_zero_emits.size(), 0,
		"unit_health_zero must NOT fire while hp > 0")


func test_overkill_does_not_re_emit() -> void:
	# Once dead, further damage must not re-emit unit_health_zero.
	# This is the latch preventing State Machine death-preempt from
	# being triggered repeatedly by sustained DoT after death.
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(60.0, null))
	_on_tick(func() -> void: _hc.take_damage(20.0, null))
	_on_tick(func() -> void: _hc.take_damage(20.0, null))
	assert_eq(_captured_zero_emits.size(), 1,
		"unit_health_zero must fire exactly ONCE — the latch must prevent re-emit")


func test_take_damage_ignores_negative_amounts() -> void:
	# Negative damage is silently ignored. Healing has its own method.
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(-10.0, null))
	assert_eq(_hc.hp_x100, 6000, "negative damage must not heal")


func test_take_damage_ignores_zero_amount() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(0.0, null))
	assert_eq(_hc.hp_x100, 6000)


# ---------------------------------------------------------------------------
# heal
# ---------------------------------------------------------------------------

func test_heal_increases_hp() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(40.0, null))
	# hp now 20.0
	_on_tick(func() -> void: _hc.heal(15.0))
	assert_eq(_hc.hp_x100, 3500, "hp = 20 + 15 = 35.0 = 3500 fixed")


func test_heal_clamps_at_max() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage(10.0, null))
	# hp now 50.0
	_on_tick(func() -> void: _hc.heal(100.0))
	assert_eq(_hc.hp_x100, _hc.max_hp_x100,
		"heal must clamp at max_hp")


func test_heal_ignores_negative() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.heal(-10.0))
	assert_eq(_hc.hp_x100, 6000, "negative heal must not damage")


# ---------------------------------------------------------------------------
# Fixed-point determinism
# ---------------------------------------------------------------------------

func test_many_small_damages_sum_exactly() -> void:
	# Repeatedly damage by 0.01 (1 fixed-point unit). After 100 hits we
	# must be exactly 1.0 hp lower with NO float drift. This is the
	# whole point of the fixed-point storage discipline (Sim Contract §1.6).
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void:
		for _i in range(100):
			_hc.take_damage(0.01, null)
	)
	# Started at 60.0; took 100 hits of 0.01 each; should be exactly 59.0.
	assert_eq(_hc.hp_x100, 5900,
		"100 * 0.01 damage must sum to exactly 1.0 hp (no IEEE-754 drift)")


# ---------------------------------------------------------------------------
# On-tick discipline (the Sim Contract guarantee)
# ---------------------------------------------------------------------------

# Note: the actual off-tick crash via assert is enforcement-via-crash-in-debug
# per Sim Contract §1.3 / docs/ARCHITECTURE.md §6 v0.2.0. GUT cannot trap the
# fired assert; the on-tick happy path is what we verify here. The lint rule
# (L1) catches the static off-tick caller pattern at commit time.

func test_take_damage_works_inside_real_sim_clock_tick() -> void:
	# Drive an actual SimClock._test_run_tick around a phased mutation.
	# The mutation has to happen during the tick — we use a one-shot
	# subscription to sim_phase to mutate inside the movement phase
	# (where MovementComponent normally runs). This is the integration
	# shape: a "do work during phase X" pattern for unit components.
	_hc.init_max_hp(60.0)
	var phase_handler := func(phase: StringName, _t: int) -> void:
		if phase == &"combat":
			_hc.take_damage(10.0, null)
	EventBus.sim_phase.connect(phase_handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(phase_handler)
	assert_eq(_hc.hp_x100, 5000,
		"take_damage within a real tick (combat phase) must mutate hp_x100")


# ---------------------------------------------------------------------------
# take_damage_x100 — fixed-point hot path used by CombatComponent
# ---------------------------------------------------------------------------

func test_take_damage_x100_decrements_exactly() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage_x100(1255, null, &"melee_attack"))
	assert_eq(_hc.hp_x100, 6000 - 1255,
		"take_damage_x100 with 1255 must decrement hp_x100 by exactly 1255 (no float round-trip)")


func test_take_damage_x100_ignores_non_positive() -> void:
	_hc.init_max_hp(60.0)
	_on_tick(func() -> void: _hc.take_damage_x100(0, null, &"melee_attack"))
	_on_tick(func() -> void: _hc.take_damage_x100(-100, null, &"melee_attack"))
	assert_eq(_hc.hp_x100, 6000, "take_damage_x100 must ignore <= 0 amounts")


# ---------------------------------------------------------------------------
# last_death_position + unit_died emit (Phase 2 deliverable 3)
# ---------------------------------------------------------------------------

# A small local fixture that places the HealthComponent under a Node3D
# parent so global_position can be set and read at death time.
class _HealthHostNode3D extends Node3D:
	var unit_id: int = -1


# Capture buffer for unit_died signal payloads.
var _captured_unit_died: Array[Dictionary] = []


func _on_unit_died(unit_id: int, killer_unit_id: int, cause: StringName, position: Vector3) -> void:
	_captured_unit_died.append({
		&"unit_id": unit_id,
		&"killer_unit_id": killer_unit_id,
		&"cause": cause,
		&"position": position,
	})


func test_last_death_position_captured_before_emit() -> void:
	# Build a hosted HealthComponent so global_position is meaningful.
	# add_child_autofree -> set position -> add component (per the wave-1 lesson
	# in test_combat_component / BUILD_LOG v0.14.5: Node3D.global_transform
	# asserts is_inside_tree()).
	var host := _HealthHostNode3D.new()
	host.unit_id = 7
	add_child_autofree(host)
	host.global_position = Vector3(12.0, 0.0, -5.0)

	var hc: Variant = HealthComponentScript.new()
	hc.unit_id = 7
	host.add_child(hc)
	hc.init_max_hp(20.0)

	_captured_unit_died.clear()
	EventBus.unit_died.connect(_on_unit_died)
	_on_tick(func() -> void: hc.take_damage_x100(2000, null, &"melee_attack"))
	EventBus.unit_died.disconnect(_on_unit_died)

	assert_eq(hc.last_death_position, Vector3(12.0, 0.0, -5.0),
		"last_death_position must be captured from the parent's global_position at death")
	assert_eq(_captured_unit_died.size(), 1,
		"unit_died must fire exactly once when hp reaches 0")
	var payload: Dictionary = _captured_unit_died[0]
	assert_eq(payload[&"unit_id"], 7, "payload carries the dying unit's id")
	assert_eq(payload[&"position"], Vector3(12.0, 0.0, -5.0),
		"payload carries the captured death position")


func test_unit_died_payload_includes_killer_and_cause() -> void:
	# Build attacker (provides unit_id for killer plumbing) + victim.
	var attacker := _HealthHostNode3D.new()
	attacker.unit_id = 99
	add_child_autofree(attacker)

	var host := _HealthHostNode3D.new()
	host.unit_id = 8
	add_child_autofree(host)
	host.global_position = Vector3(0.0, 0.0, 0.0)

	var hc: Variant = HealthComponentScript.new()
	hc.unit_id = 8
	host.add_child(hc)
	hc.init_max_hp(10.0)

	_captured_unit_died.clear()
	EventBus.unit_died.connect(_on_unit_died)
	_on_tick(func() -> void: hc.take_damage_x100(1500, attacker, &"ranged_attack"))
	EventBus.unit_died.disconnect(_on_unit_died)

	assert_eq(_captured_unit_died.size(), 1, "unit_died fires once on death")
	var payload: Dictionary = _captured_unit_died[0]
	assert_eq(payload[&"killer_unit_id"], 99,
		"killer_unit_id must be pulled off source.unit_id duck-typed")
	assert_eq(payload[&"cause"], &"melee_attack" if false else &"ranged_attack",
		"cause string must propagate from the damage call into the payload")


func test_unit_died_does_not_double_emit_on_overkill() -> void:
	var host := _HealthHostNode3D.new()
	host.unit_id = 10
	add_child_autofree(host)

	var hc: Variant = HealthComponentScript.new()
	hc.unit_id = 10
	host.add_child(hc)
	hc.init_max_hp(10.0)

	_captured_unit_died.clear()
	EventBus.unit_died.connect(_on_unit_died)
	_on_tick(func() -> void: hc.take_damage_x100(1500, null, &"melee_attack"))
	# Over-kill — the latch must prevent a second emit.
	_on_tick(func() -> void: hc.take_damage_x100(500, null, &"melee_attack"))
	EventBus.unit_died.disconnect(_on_unit_died)

	assert_eq(_captured_unit_died.size(), 1,
		"unit_died must NOT re-emit on over-kill — same latch as unit_health_zero")


func test_unit_health_zero_fires_before_unit_died() -> void:
	# Listener-order discipline (cb95d09 lesson). The two death signals fire
	# in order: unit_health_zero first (StateMachine death-preempt), then
	# unit_died (broader telemetry / Farr-drain). Listeners that depend on
	# the FSM having transitioned (e.g., FarrSystem reading is_idle()) need
	# the FSM-side signal to land first.
	var host := _HealthHostNode3D.new()
	host.unit_id = 11
	add_child_autofree(host)

	var hc: Variant = HealthComponentScript.new()
	hc.unit_id = 11
	host.add_child(hc)
	hc.init_max_hp(5.0)

	var order: Array[StringName] = []
	var on_zero := func(_uid: int) -> void:
		order.append(&"unit_health_zero")
	var on_died := func(_uid: int, _kid: int, _c: StringName, _p: Vector3) -> void:
		order.append(&"unit_died")
	EventBus.unit_health_zero.connect(on_zero)
	EventBus.unit_died.connect(on_died)
	_on_tick(func() -> void: hc.take_damage_x100(1000, null, &"melee_attack"))
	EventBus.unit_health_zero.disconnect(on_zero)
	EventBus.unit_died.disconnect(on_died)

	assert_eq(order.size(), 2, "both death signals must fire")
	assert_eq(order[0], &"unit_health_zero",
		"unit_health_zero must fire BEFORE unit_died (FSM preempt before telemetry)")
	assert_eq(order[1], &"unit_died",
		"unit_died fires AFTER unit_health_zero")
