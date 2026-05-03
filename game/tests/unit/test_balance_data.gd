# Tests for BalanceData Resource + sub-resources.
#
# Contract: docs/TESTING_CONTRACT.md §1.1, §1.2, §1.3
# Schema source: game/data/balance_data.gd + game/data/sub_resources/*.gd
# Fixture file: game/data/balance.tres (loaded via Constants.PATH_BALANCE_DATA)
#
# Coverage:
#   - BalanceData loads cleanly from balance.tres
#   - All sub-resources are populated and have correct types
#   - constants_version is set
#   - Spot-checks of specific spec values
#   - validate_hard() catches each of the 4 invariants
#   - validate_hard() passes a clean config
#   - validate_soft() returns an Array (may be empty for clean config)
#
# NOTE on class_name resolution:
# Preload script refs are used per the established pattern in this codebase
# (see test_state_machine.gd and ARCHITECTURE.md §6 v0.4.0 delta):
# GUT collects test scripts before the global class_name registry is populated
# in headless mode. Preloading forces Godot to register each class_name at
# parse time, making typed checks work reliably.
extends GutTest

# Preload all sub-resource scripts. This forces class_name registration before
# the test methods execute, enabling instanceof checks and typed var declarations.
const BalanceDataScript: Script = preload("res://data/balance_data.gd")
const UnitStatsScript: Script = preload("res://data/sub_resources/unit_stats.gd")
const BuildingStatsScript: Script = preload("res://data/sub_resources/building_stats.gd")
const FarrConfigScript: Script = preload("res://data/sub_resources/farr_config.gd")
const CombatMatrixScript: Script = preload("res://data/sub_resources/combat_matrix.gd")
const EconomyConfigScript: Script = preload("res://data/sub_resources/economy_config.gd")
const ResourceNodeConfigScript: Script = preload("res://data/sub_resources/resource_node_config.gd")
const AIConfigScript: Script = preload("res://data/sub_resources/ai_config.gd")

const BALANCE_PATH: String = "res://data/balance.tres"

# Untyped Variant to avoid class_name resolution race in before_each
var _balance: Variant


func before_each() -> void:
	# Load a fresh BalanceData from the canonical .tres each test.
	# CACHE_MODE_IGNORE forces a fresh load so test mutations don't leak.
	var loaded: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_not_null(loaded, "balance.tres must load without error")
	_balance = loaded


func after_each() -> void:
	_balance = null


# ---------------------------------------------------------------------------
# 1. Load and shape
# ---------------------------------------------------------------------------

func test_balance_tres_loads_as_balance_data() -> void:
	# Canonical load path. If this fails, everything else is moot.
	assert_not_null(_balance, "balance.tres should deserialize to a BalanceData instance")
	assert_true(_balance.get_script() == BalanceDataScript,
		"balance.tres must have BalanceData as its script")


func test_constants_version_is_set() -> void:
	# constants_version must be a non-empty string per TESTING_CONTRACT.md §1.1.
	# qa-engineer will wire file-hash auto-derivation in wave 2 (MatchHarness);
	# for now it is a manual stamp.
	assert_not_null(_balance)
	assert_false((_balance as Resource).get(&"constants_version").is_empty(),
		"constants_version must be set — empty string means logs are unidentifiable.")


func test_units_dict_is_populated() -> void:
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	assert_false(units.is_empty(), "units dict must have at least one entry")


func test_buildings_dict_is_populated() -> void:
	assert_not_null(_balance)
	var buildings: Dictionary = _balance.get(&"buildings")
	assert_false(buildings.is_empty(), "buildings dict must have at least one entry")


func test_farr_sub_resource_is_present() -> void:
	assert_not_null(_balance)
	var farr: Variant = _balance.get(&"farr")
	assert_not_null(farr, "farr sub-resource must be populated")
	assert_true(farr is Resource, "farr must be a Resource")
	assert_true((farr as Resource).get_script() == FarrConfigScript,
		"farr must have FarrConfig as its script")


func test_combat_sub_resource_is_present() -> void:
	assert_not_null(_balance)
	var combat: Variant = _balance.get(&"combat")
	assert_not_null(combat, "combat sub-resource must be populated")
	assert_true(combat is Resource, "combat must be a Resource")
	assert_true((combat as Resource).get_script() == CombatMatrixScript,
		"combat must have CombatMatrix as its script")


func test_economy_sub_resource_is_present() -> void:
	assert_not_null(_balance)
	var economy: Variant = _balance.get(&"economy")
	assert_not_null(economy, "economy sub-resource must be populated")
	assert_true(economy is Resource, "economy must be a Resource")
	assert_true((economy as Resource).get_script() == EconomyConfigScript,
		"economy must have EconomyConfig as its script")


func test_economy_resource_nodes_is_present() -> void:
	assert_not_null(_balance)
	var economy: Variant = _balance.get(&"economy")
	assert_not_null(economy)
	var res_nodes: Variant = (economy as Resource).get(&"resource_nodes")
	assert_not_null(res_nodes,
		"economy.resource_nodes (ResourceNodeConfig) must be populated")
	assert_true(res_nodes is Resource, "economy.resource_nodes must be a Resource")
	assert_true((res_nodes as Resource).get_script() == ResourceNodeConfigScript,
		"economy.resource_nodes must have ResourceNodeConfig as its script")


func test_ai_sub_resource_is_present() -> void:
	assert_not_null(_balance)
	var ai_cfg: Variant = _balance.get(&"ai")
	assert_not_null(ai_cfg, "ai sub-resource must be populated")
	assert_true(ai_cfg is Resource, "ai must be a Resource")
	assert_true((ai_cfg as Resource).get_script() == AIConfigScript,
		"ai must have AIConfig as its script")


# ---------------------------------------------------------------------------
# 2. Spec value spot-checks
# ---------------------------------------------------------------------------

func test_farr_tier2_threshold_matches_spec() -> void:
	# "Tier 2 (Fortress) requires Farr >= 40 to advance" — 01_CORE_MECHANICS.md §4.2
	assert_not_null(_balance)
	var farr: Variant = _balance.get(&"farr")
	assert_almost_eq(float(farr.get(&"tier2_threshold")), 40.0, 1e-4,
		"farr.tier2_threshold must be 40.0 per spec")


func test_farr_kaveh_trigger_threshold_matches_spec() -> void:
	# "Farr drops below 15 AND remains there for 30s" — 01_CORE_MECHANICS.md §9.1
	assert_not_null(_balance)
	var farr: Variant = _balance.get(&"farr")
	assert_almost_eq(float(farr.get(&"kaveh_trigger_threshold")), 15.0, 1e-4,
		"farr.kaveh_trigger_threshold must be 15.0 per spec")


func test_farr_kaveh_grace_ticks_matches_spec() -> void:
	# "30-second grace period" at 30Hz = 900 ticks — 01_CORE_MECHANICS.md §9.1
	assert_not_null(_balance)
	var farr: Variant = _balance.get(&"farr")
	assert_eq(int(farr.get(&"kaveh_grace_ticks")), 900,
		"farr.kaveh_grace_ticks must be 900 (30s at 30Hz)")


func test_farr_starting_value_matches_spec() -> void:
	# "Starting value: 50 (neutral)" — 01_CORE_MECHANICS.md §4.1
	assert_not_null(_balance)
	var farr: Variant = _balance.get(&"farr")
	assert_almost_eq(float(farr.get(&"starting_value")), 50.0, 1e-4,
		"farr.starting_value must be 50.0 per spec")


func test_ai_normal_techup_ticks_matches_spec() -> void:
	# "~5 minutes" at 30Hz = 9000 ticks — docs/AI_DIFFICULTY.md §1
	assert_not_null(_balance)
	var ai_cfg: Variant = _balance.get(&"ai")
	assert_eq(int(ai_cfg.get(&"normal_techup_ticks")), 9000,
		"ai.normal_techup_ticks must be 9000 (5 min at 30Hz) per AI_DIFFICULTY.md §1")


func test_economy_starting_coin_is_reasonable() -> void:
	# 01_CORE_MECHANICS.md §2 spawn conditions; Testing Contract §1.2 starting_coin = 150
	assert_not_null(_balance)
	var economy: Variant = _balance.get(&"economy")
	assert_gt(int(economy.get(&"starting_coin")), 0,
		"economy.starting_coin must be positive to start a match")


func test_minimum_unit_types_present() -> void:
	# Phase 0 must have at minimum: kargar, piyade, kamandar
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	assert_true(units.has(&"kargar"), "units must include 'kargar'")
	assert_true(units.has(&"piyade"), "units must include 'piyade'")
	assert_true(units.has(&"kamandar"), "units must include 'kamandar'")


func test_minimum_building_types_present() -> void:
	# Phase 0 must have at minimum: throne, khaneh, mazraeh, atashkadeh
	assert_not_null(_balance)
	var buildings: Dictionary = _balance.get(&"buildings")
	assert_true(buildings.has(&"throne"), "buildings must include 'throne'")
	assert_true(buildings.has(&"khaneh"), "buildings must include 'khaneh'")
	assert_true(buildings.has(&"mazraeh"), "buildings must include 'mazraeh'")
	assert_true(buildings.has(&"atashkadeh"), "buildings must include 'atashkadeh'")


func test_piyade_unit_stats_type_is_correct() -> void:
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	var piyade_stats: Variant = units.get(&"piyade")
	assert_not_null(piyade_stats, "piyade entry must exist")
	assert_true(piyade_stats is Resource, "piyade value must be a Resource")
	assert_true((piyade_stats as Resource).get_script() == UnitStatsScript,
		"piyade value must have UnitStats script")


func test_atashkadeh_farr_per_tick_is_nonzero() -> void:
	# Atashkadeh generates +1 Farr/min = 1/1800 Farr/tick ≈ 0.000556
	# — 01_CORE_MECHANICS.md §4.3 and §5
	assert_not_null(_balance)
	var buildings: Dictionary = _balance.get(&"buildings")
	var atashkadeh: Variant = buildings.get(&"atashkadeh")
	assert_not_null(atashkadeh)
	assert_true(atashkadeh is Resource)
	var fpt: float = float((atashkadeh as Resource).get(&"farr_per_tick"))
	assert_gt(fpt, 0.0,
		"atashkadeh.farr_per_tick must be > 0 (generates Farr per 01_CORE_MECHANICS.md §4.3)")


# ---------------------------------------------------------------------------
# 3. validate_hard() — each invariant
# ---------------------------------------------------------------------------

func test_validate_hard_passes_clean_config() -> void:
	# The canonical balance.tres must pass hard validation with no errors.
	assert_not_null(_balance)
	var errors: Array = _balance.call(&"validate_hard")
	assert_eq(errors.size(), 0,
		"validate_hard() must return empty array for canonical balance.tres. Got: %s" % str(errors))


func test_validate_hard_catches_negative_hp() -> void:
	# Invariant 1: any HP or cost value < 0
	assert_not_null(_balance)
	var bad_unit: Resource = UnitStatsScript.new()
	bad_unit.set(&"max_hp", -10.0)
	bad_unit.set(&"damage", 5.0)
	bad_unit.set(&"coin_cost", 50)
	bad_unit.set(&"grain_cost", 10)
	var units: Dictionary = _balance.get(&"units")
	units[&"__bad_unit__"] = bad_unit
	_balance.set(&"units", units)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch a unit with negative max_hp")


func test_validate_hard_catches_negative_building_cost() -> void:
	# Invariant 1: building with negative coin_cost
	assert_not_null(_balance)
	var bad_bldg: Resource = BuildingStatsScript.new()
	bad_bldg.set(&"max_hp", 500.0)
	bad_bldg.set(&"coin_cost", -50)
	bad_bldg.set(&"grain_cost", 0)
	var buildings: Dictionary = _balance.get(&"buildings")
	buildings[&"__bad_bldg__"] = bad_bldg
	_balance.set(&"buildings", buildings)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch a building with negative coin_cost")


func test_validate_hard_catches_kaveh_threshold_above_tier2() -> void:
	# Invariant 2: kaveh_trigger_threshold >= tier2_threshold
	# "Kaveh Event fires before Tier 2 is reachable — logically incoherent."
	assert_not_null(_balance)
	var farr: Resource = _balance.get(&"farr")
	var tier2_val: float = float(farr.get(&"tier2_threshold"))
	farr.set(&"kaveh_trigger_threshold", tier2_val + 5.0)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch kaveh_trigger_threshold >= tier2_threshold")


func test_validate_hard_catches_kaveh_threshold_equal_tier2() -> void:
	# Invariant 2 edge case: exactly equal is also incoherent
	assert_not_null(_balance)
	var farr: Resource = _balance.get(&"farr")
	var tier2_val: float = float(farr.get(&"tier2_threshold"))
	farr.set(&"kaveh_trigger_threshold", tier2_val)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch kaveh_trigger_threshold == tier2_threshold")


func test_validate_hard_catches_zero_grace_ticks() -> void:
	# Invariant 3: kaveh_grace_ticks == 0 removes player response window
	# "design invariant from 01_CORE_MECHANICS.md §9.1"
	assert_not_null(_balance)
	var farr: Resource = _balance.get(&"farr")
	farr.set(&"kaveh_grace_ticks", 0)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch kaveh_grace_ticks == 0")


func test_validate_hard_catches_combat_matrix_value_above_5() -> void:
	# Invariant 4: effectiveness value > 5.0 (almost certainly a data entry error)
	assert_not_null(_balance)
	var combat: Resource = _balance.get(&"combat")
	var effectiveness: Dictionary = combat.get(&"effectiveness")
	effectiveness[&"__test_atk__"] = {&"__test_def__": 6.5}
	combat.set(&"effectiveness", effectiveness)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch a combat effectiveness value > 5.0")


func test_validate_hard_catches_combat_matrix_value_negative() -> void:
	# Invariant 4: effectiveness value < 0.0
	assert_not_null(_balance)
	var combat: Resource = _balance.get(&"combat")
	var effectiveness: Dictionary = combat.get(&"effectiveness")
	effectiveness[&"__test_neg__"] = {&"__test_def__": -1.0}
	combat.set(&"effectiveness", effectiveness)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch a negative combat effectiveness value")


# ---------------------------------------------------------------------------
# 4. validate_soft()
# ---------------------------------------------------------------------------

func test_validate_soft_returns_array() -> void:
	# validate_soft() must always return an Array[String], never null or crash.
	assert_not_null(_balance)
	var warnings: Array = _balance.call(&"validate_soft")
	assert_not_null(warnings, "validate_soft() must return an Array")
	assert_true(warnings is Array, "validate_soft() return value must be an Array")


func test_validate_soft_clean_config_is_array() -> void:
	# The canonical balance.tres should return a valid Array from validate_soft().
	# Not asserting size == 0 — soft warnings are non-blocking; balance engineer
	# may intentionally leave some as tuning notes.
	assert_not_null(_balance)
	var warnings: Array = _balance.call(&"validate_soft")
	assert_true(warnings is Array,
		"validate_soft() must return an Array[String] for the canonical config")


# ---------------------------------------------------------------------------
# 5. Phase 2 session 1 — combat fields on UnitStats
# ---------------------------------------------------------------------------

func test_unit_stats_has_attack_damage_x100_field() -> void:
	# Verify the new fixed-point field exists on the UnitStats schema.
	var stats: Resource = UnitStatsScript.new()
	assert_true(stats.get(&"attack_damage_x100") != null or stats.get(&"attack_damage_x100") == 0,
		"UnitStats must have attack_damage_x100 field (Sim Contract §1.6 fixed-point)")


func test_unit_stats_has_attack_speed_per_sec_field() -> void:
	var stats: Resource = UnitStatsScript.new()
	# Default value should be 1.0 per schema definition
	assert_almost_eq(float(stats.get(&"attack_speed_per_sec")), 1.0, 1e-4,
		"UnitStats must have attack_speed_per_sec field with default 1.0")


func test_kargar_combat_fields_populated() -> void:
	# Kargar: workers don't attack — attack_damage_x100 = 0.
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	var kargar: Resource = units.get(&"kargar")
	assert_not_null(kargar, "kargar entry must exist")
	assert_eq(int(kargar.get(&"attack_damage_x100")), 0,
		"kargar.attack_damage_x100 must be 0 — workers cannot attack")
	assert_almost_eq(float(kargar.get(&"attack_speed_per_sec")), 1.0, 1e-4,
		"kargar.attack_speed_per_sec must be 1.0 (irrelevant since damage is 0)")
	assert_almost_eq(float(kargar.get(&"attack_range")), 0.0, 1e-4,
		"kargar.attack_range must be 0.0 — workers do not engage in melee")


func test_piyade_entry_exists_with_combat_stats() -> void:
	# Piyade: Iran infantry — 1000 x100 damage = 10 dmg/hit; kills Kargar in 6 hits.
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	var piyade: Resource = units.get(&"piyade")
	assert_not_null(piyade, "piyade entry must exist")
	assert_almost_eq(float(piyade.get(&"max_hp")), 100.0, 1e-4,
		"piyade.max_hp must be 100.0 (1.7× Kargar's 60)")
	assert_almost_eq(float(piyade.get(&"move_speed")), 2.5, 1e-4,
		"piyade.move_speed must be 2.5 (slower than Kargar's 3.5)")
	assert_eq(int(piyade.get(&"attack_damage_x100")), 1000,
		"piyade.attack_damage_x100 must be 1000 (= 10.0 dmg; 6 hits to kill Kargar)")
	assert_almost_eq(float(piyade.get(&"attack_speed_per_sec")), 1.0, 1e-4,
		"piyade.attack_speed_per_sec must be 1.0")
	assert_almost_eq(float(piyade.get(&"attack_range")), 1.5, 1e-4,
		"piyade.attack_range must be 1.5 (melee)")


func test_turan_piyade_entry_exists_and_mirrors_iran_piyade() -> void:
	# Turan_Piyade: mirror of Iran Piyade for session 1.
	# RPS effectiveness differentiating them ships in Phase 2 session 2.
	assert_not_null(_balance)
	var units: Dictionary = _balance.get(&"units")
	assert_true(units.has(&"turan_piyade"), "turan_piyade entry must exist")
	var turan: Resource = units.get(&"turan_piyade")
	var iran: Resource = units.get(&"piyade")
	assert_not_null(turan)
	assert_not_null(iran)
	assert_almost_eq(float(turan.get(&"max_hp")), float(iran.get(&"max_hp")), 1e-4,
		"turan_piyade.max_hp must mirror iran piyade")
	assert_almost_eq(float(turan.get(&"move_speed")), float(iran.get(&"move_speed")), 1e-4,
		"turan_piyade.move_speed must mirror iran piyade")
	assert_eq(int(turan.get(&"attack_damage_x100")), int(iran.get(&"attack_damage_x100")),
		"turan_piyade.attack_damage_x100 must mirror iran piyade")
	assert_almost_eq(float(turan.get(&"attack_speed_per_sec")), float(iran.get(&"attack_speed_per_sec")), 1e-4,
		"turan_piyade.attack_speed_per_sec must mirror iran piyade")
	assert_almost_eq(float(turan.get(&"attack_range")), float(iran.get(&"attack_range")), 1e-4,
		"turan_piyade.attack_range must mirror iran piyade")


func test_validate_hard_rejects_negative_attack_damage_x100() -> void:
	# Hard invariant: attack_damage_x100 must be >= 0.
	assert_not_null(_balance)
	var bad_unit: Resource = UnitStatsScript.new()
	bad_unit.set(&"max_hp", 100.0)
	bad_unit.set(&"attack_damage_x100", -1)
	bad_unit.set(&"attack_speed_per_sec", 1.0)
	bad_unit.set(&"attack_range", 1.5)
	var units: Dictionary = _balance.get(&"units")
	units[&"__bad_dmg__"] = bad_unit
	_balance.set(&"units", units)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch negative attack_damage_x100")


func test_validate_hard_rejects_zero_attack_speed_per_sec() -> void:
	# Hard invariant: attack_speed_per_sec must be > 0 (prevents divide-by-zero in cooldown).
	assert_not_null(_balance)
	var bad_unit: Resource = UnitStatsScript.new()
	bad_unit.set(&"max_hp", 100.0)
	bad_unit.set(&"attack_damage_x100", 1000)
	bad_unit.set(&"attack_speed_per_sec", 0.0)
	bad_unit.set(&"attack_range", 1.5)
	var units: Dictionary = _balance.get(&"units")
	units[&"__bad_speed__"] = bad_unit
	_balance.set(&"units", units)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch zero attack_speed_per_sec")


func test_validate_hard_rejects_negative_attack_range() -> void:
	# Hard invariant: attack_range must be >= 0 (negative range is nonsensical).
	assert_not_null(_balance)
	var bad_unit: Resource = UnitStatsScript.new()
	bad_unit.set(&"max_hp", 100.0)
	bad_unit.set(&"attack_damage_x100", 1000)
	bad_unit.set(&"attack_speed_per_sec", 1.0)
	bad_unit.set(&"attack_range", -1.0)
	var units: Dictionary = _balance.get(&"units")
	units[&"__bad_range__"] = bad_unit
	_balance.set(&"units", units)
	var errors: Array = _balance.call(&"validate_hard")
	assert_gt(errors.size(), 0,
		"validate_hard() must catch negative attack_range")
