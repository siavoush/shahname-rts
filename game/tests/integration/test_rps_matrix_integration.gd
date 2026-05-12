# Integration tests for the RPS multiplier flowing through CombatComponent.
#
# Phase 2 session 2 wave 2A. Per 02e_PHASE_2_SESSION_2_KICKOFF.md §2 item 5:
# "CombatComponent's damage-fire path scales attack_damage_x100 by the
# CombatMatrix multiplier for the (attacker_type, target_type) pair."
#
# Critical contract from balance-engineer wave 1B:
#   CombatComponent MUST call CombatMatrix.get_multiplier(attacker, target) —
#   NOT effectiveness[atk][def] raw dict access. The get_multiplier() method
#   does Turan-mirror folding (strips "turan_" prefix, including the special
#   case "turan_asb_savar" → "asb_savar_kamandar"). Raw dict access bypasses
#   this and Turan units deal wrong damage in-game while headless tests pass.
#
# What this file covers:
#   1. Piyade (1000 dmg) vs Savar at 1.5× → 1500 fixed-point damage applied.
#   2. Savar (1200 dmg) vs Kamandar at 2.0× → 2400 fixed-point damage applied.
#   3. Turan-fold parity — Turan_Piyade vs Turan_Savar applies the same scaled
#      damage as Iran Piyade vs Iran Savar (1500). Validates the Turan-mirror
#      folding gets exercised at the live damage-fire site, not just inside
#      get_multiplier() in isolation.
#   4. Default 1.0× when CombatMatrix is unavailable / pair unknown.
#   5. Single-shot damage outcome — attacker fires once, target HP drops by
#      EXACTLY base × multiplier rounded.
#   6. Integration smoke — two real unit scenes (Piyade vs Savar) collide via
#      the production EventBus chain; HP after a known number of hits matches
#      the scaled-damage prediction within fixed-point tolerance.
#
# Sim Contract §1.6: damage is fixed-point integer (attack_damage_x100). The
# multiplier is float, but the scaled damage is rounded to int BEFORE the
# take_damage_x100 call. Float damage is NEVER stored on a SimNode field.
#
# Untyped Variant fixtures per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0).
extends GutTest


# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------

const CombatComponentScript: Script = preload("res://scripts/units/components/combat_component.gd")
const HealthComponentScript: Script = preload("res://scripts/units/components/health_component.gd")
const CombatMatrixScript: Script = preload("res://data/sub_resources/combat_matrix.gd")

const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const SavarScene: PackedScene = preload("res://scenes/units/savar.tscn")
const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const TuranSavarScene: PackedScene = preload("res://scenes/units/turan_savar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")

const BALANCE_PATH: String = "res://data/balance.tres"


# ---------------------------------------------------------------------------
# Test fixture — bare Node3D + CombatComponent + HealthComponent.
# Mirrors the test_combat_component.gd pattern. We add unit_type to both the
# attacker and target (CombatComponent reads target.unit_type for the
# multiplier lookup, NOT just target.get_health()).
# ---------------------------------------------------------------------------

class _TypedFakeUnit extends Node3D:
	var unit_id: int = -1
	var unit_type: StringName = &""
	var _health: Node = null

	func get_health() -> Node:
		return _health


var _attacker: _TypedFakeUnit
var _target: _TypedFakeUnit
var _combat: Variant
var _target_health: Variant
var _matrix: Variant


func before_each() -> void:
	SimClock.reset()

	# Build the matrix. We hand-populate a tiny matrix so tests don't depend
	# on balance.tres values changing — the production matrix is exercised in
	# the integration smoke test at the bottom of this file.
	_matrix = CombatMatrixScript.new()
	_matrix.effectiveness = {
		&"piyade": {&"piyade": 1.0, &"savar": 1.5, &"kamandar": 1.0},
		&"savar": {&"kamandar": 2.0, &"savar": 1.0, &"piyade": 0.7},
		&"kamandar": {&"piyade": 1.5, &"savar": 0.7, &"kamandar": 1.0},
	}

	# Build the target (HP=100, type=savar by default — overridden per-test).
	_target = _TypedFakeUnit.new()
	_target.unit_id = 200
	_target.unit_type = &"savar"
	add_child_autofree(_target)
	_target.global_position = Vector3.ZERO

	_target_health = HealthComponentScript.new()
	_target_health.unit_id = 200
	_target.add_child(_target_health)
	_target_health.init_max_hp(100.0)
	_target._health = _target_health

	# Build the attacker (1.0 unit away on X, in default 2.0 attack range).
	_attacker = _TypedFakeUnit.new()
	_attacker.unit_id = 100
	_attacker.unit_type = &"piyade"
	add_child_autofree(_attacker)
	_attacker.global_position = Vector3(1.0, 0.0, 0.0)

	_combat = CombatComponentScript.new()
	_combat.attack_damage_x100 = 1000   # 10.0 dmg/hit (matches Piyade balance)
	_combat.attack_speed_per_sec = 1.0
	_combat.attack_range = 2.0
	# Wire the type and matrix the component needs at damage-fire time.
	_combat.attacker_unit_type = &"piyade"
	_combat.combat_matrix = _matrix
	_attacker.add_child(_combat)

	# Lookup callable resolves unit_id 200 → _target.
	_combat.target_lookup_callable = func(uid: int) -> Node3D:
		if _target != null and is_instance_valid(_target) and _target.unit_id == uid:
			return _target
		return null


func after_each() -> void:
	# add_child_autofree handles parent cleanup; components go down with parents.
	SimClock.reset()


# Helper: run one tick around _combat._sim_tick, satisfying SimNode._set_sim's
# is_ticking assertion.
func _combat_tick() -> void:
	SimClock._is_ticking = true
	_combat._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# 1. Piyade vs Savar at 1.5×
# ---------------------------------------------------------------------------

func test_piyade_vs_savar_applies_1_5x_multiplier() -> void:
	# Piyade base damage 1000 (10.0). Savar target. Multiplier 1.5 → 1500.
	# 100.0 hp - 15.0 = 85.0 → 8500 fixed-point.
	_combat.attacker_unit_type = &"piyade"
	_target.unit_type = &"savar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 8500,
		"Piyade vs Savar: base 1000 * 1.5 = 1500 damage applied; HP "
		+ "10000 - 1500 = 8500 expected")


# ---------------------------------------------------------------------------
# 2. Savar vs Kamandar at 2.0×
# ---------------------------------------------------------------------------

func test_savar_vs_kamandar_applies_2_0x_multiplier() -> void:
	# Savar base damage 1200 (12.0). Kamandar target. Multiplier 2.0 → 2400.
	# 100.0 hp - 24.0 = 76.0 → 7600 fixed-point.
	_combat.attacker_unit_type = &"savar"
	_combat.attack_damage_x100 = 1200
	_target.unit_type = &"kamandar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 7600,
		"Savar vs Kamandar: base 1200 * 2.0 = 2400 damage applied; HP "
		+ "10000 - 2400 = 7600 expected")


# ---------------------------------------------------------------------------
# 3. Turan mirror fold — Turan_Piyade vs Turan_Savar matches Iran parity
# ---------------------------------------------------------------------------

func test_turan_piyade_vs_turan_savar_folds_to_1_5x() -> void:
	# Turan_Piyade attacker, Turan_Savar target. CombatMatrix's get_multiplier
	# strips the "turan_" prefix on both, resolving to the (piyade, savar)
	# row → 1.5. Same scaled damage as the Iran-vs-Iran case.
	_combat.attacker_unit_type = &"turan_piyade"
	_target.unit_type = &"turan_savar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 8500,
		"Turan_Piyade vs Turan_Savar must fold to (piyade, savar) → 1.5×; HP "
		+ "10000 - 1500 = 8500 expected. If this fails, CombatComponent is "
		+ "doing raw effectiveness[atk][def] instead of get_multiplier(...) "
		+ "and Turan-mirror folding is bypassed.")


# ---------------------------------------------------------------------------
# 4. Default 1.0× — unknown pair, missing matrix
# ---------------------------------------------------------------------------

func test_unknown_pair_defaults_to_1_0x() -> void:
	# Unknown attacker type. get_multiplier returns 1.0 → unscaled damage.
	# 100.0 - 10.0 = 90.0 → 9000.
	_combat.attacker_unit_type = &"__future_unit__"
	_target.unit_type = &"savar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 9000,
		"Unknown attacker type must default to 1.0× (unscaled): 10000 - 1000 = 9000")


func test_no_matrix_assigned_defaults_to_1_0x() -> void:
	# CombatComponent without a combat_matrix wired must still fire damage
	# (1.0× neutral fallback), not crash. Matches the spec that CombatComponent
	# tolerates a missing matrix during partial wiring (forward-compat for
	# headless test fixtures that don't load BalanceData).
	_combat.combat_matrix = null
	_combat.attacker_unit_type = &"piyade"
	_target.unit_type = &"savar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 9000,
		"Missing combat_matrix must default to 1.0× neutral: 10000 - 1000 = 9000")


# ---------------------------------------------------------------------------
# 5. Single-shot damage outcome — exact rounding
# ---------------------------------------------------------------------------

func test_single_shot_damage_rounds_to_int() -> void:
	# 1255 * 1.5 = 1882.5 → roundi → 1883.
	# 100.0 - 18.83 = 81.17 → 8117 fixed-point.
	_combat.attacker_unit_type = &"piyade"
	_combat.attack_damage_x100 = 1255
	_target.unit_type = &"savar"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 8117,
		"Scaled damage must be roundi'd to int (Sim Contract §1.6): "
		+ "1255 * 1.5 = 1882.5 → roundi → 1883; HP 10000 - 1883 = 8117")


func test_neutral_pair_unchanged_damage() -> void:
	# Same-type matchup is neutral 1.0× — base damage unchanged.
	_combat.attacker_unit_type = &"piyade"
	_target.unit_type = &"piyade"
	_combat.set_target(200)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 9000,
		"Piyade vs Piyade is neutral 1.0×: HP 10000 - 1000 = 9000")


# ---------------------------------------------------------------------------
# 6. Integration smoke — real unit scenes via the production EventBus chain
# ---------------------------------------------------------------------------
# Verifies the multiplier integration applies in the LIVE damage-fire path,
# not just the unit-test fixture. If this passes, Pitfall #2 doesn't bite —
# the integration is wired into _sim_tick which is driven via the FSM.

var _mock: Variant = null
var _iran_piyade: Variant = null
var _iran_savar: Variant = null


func _setup_integration_fixture() -> void:
	# Mirror the test_phase_2_session_1_combat.gd setup pattern.
	CommandPool.reset()
	SelectionManager.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	DebugOverlayManager.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func _teardown_integration_fixture() -> void:
	if _iran_piyade != null and is_instance_valid(_iran_piyade):
		_iran_piyade.queue_free()
	if _iran_savar != null and is_instance_valid(_iran_savar):
		_iran_savar.queue_free()
	_iran_piyade = null
	_iran_savar = null
	SelectionManager.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	DebugOverlayManager.reset()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null


func test_live_piyade_vs_savar_scales_damage_via_eventbus_chain() -> void:
	# Live integration: spawn real Piyade and Savar scenes, dispatch an Attack
	# command, advance ticks via the real EventBus.sim_phase chain. After a
	# single attack lands, the Savar's HP must reflect the 1.5× scaled damage.
	#
	# Critical: this exercises the FULL chain from BalanceData → Unit
	# ._apply_balance_data_defaults → CombatComponent fields →
	# UnitState_Attacking._sim_tick → combat._sim_tick → matrix lookup →
	# scaled take_damage_x100. If any link is broken (e.g., unit_type not
	# propagated, matrix not assigned), this fails while the unit-fixture
	# tests above might still pass.
	_setup_integration_fixture()

	_iran_piyade = PiyadeScene.instantiate()
	add_child_autofree(_iran_piyade)
	_iran_piyade.global_position = Vector3.ZERO
	_iran_piyade.team = Constants.TEAM_IRAN
	_iran_piyade.get_movement()._scheduler = _mock

	_iran_savar = SavarScene.instantiate()
	add_child_autofree(_iran_savar)
	_iran_savar.global_position = Vector3(1.0, 0.0, 0.0)  # in 1.5 attack_range
	_iran_savar.team = Constants.TEAM_TURAN
	_iran_savar.get_movement()._scheduler = _mock

	# Pull the production-wired BalanceData values so the assertion below is
	# self-consistent regardless of balance.tres tuning. Piyade base damage
	# from balance.tres × 1.5 (Piyade vs Savar matrix entry) rounded.
	var bd: Resource = ResourceLoader.load(
		BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var piyade_stats: Variant = bd.get(&"units").get(&"piyade")
	var base_dmg_x100: int = int(piyade_stats.get(&"attack_damage_x100"))
	var matrix: Variant = bd.get(&"combat")
	var mult: float = float(matrix.call(&"get_multiplier", &"piyade", &"savar"))
	# Defensive: the Savar entry must exist in balance.tres for this test to
	# be meaningful — wave-1B shipped it; assert here for fail-fast clarity.
	var savar_stats: Variant = bd.get(&"units").get(&"savar")
	var savar_max_hp_x100: int = int(float(savar_stats.get(&"max_hp")) * 100.0)
	var expected_dmg_x100: int = roundi(float(base_dmg_x100) * mult)
	var expected_hp_x100: int = savar_max_hp_x100 - expected_dmg_x100

	var initial_hp_x100: int = int(_iran_savar.get_health().hp_x100)
	assert_eq(initial_hp_x100, savar_max_hp_x100,
		"pre-condition: Savar HP wired from balance.tres")

	# Issue Attack command and advance one cycle (1 tick is enough — the
	# attack fires immediately on engagement because cooldown starts at 0).
	_iran_piyade.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_iran_savar.unit_id)})

	# A few ticks to let the FSM transition + first-tick attack land.
	for _i in range(3):
		SimClock._test_run_tick()

	var hp_after: int = int(_iran_savar.get_health().hp_x100)
	# The first attack fires on the in-range tick; cooldown blocks subsequent
	# fires within the 3-tick window (30-tick cooldown @ 30 Hz at 1.0/sec).
	# Therefore exactly one attack lands → expected_hp_x100.
	assert_eq(hp_after, expected_hp_x100,
		"Live Piyade vs Savar after one attack must apply scaled damage: "
		+ "base=%d × mult=%.2f → %d; HP %d → %d expected, got %d"
		% [base_dmg_x100, mult, expected_dmg_x100,
			initial_hp_x100, expected_hp_x100, hp_after])

	_teardown_integration_fixture()
