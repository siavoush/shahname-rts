# Tests for CombatMatrix sub-resource.
#
# Contract: docs/TESTING_CONTRACT.md §1.2
# Schema source: game/data/sub_resources/combat_matrix.gd
# Fixture: game/data/balance.tres (loaded via canonical path)
#
# Coverage:
#   - get_multiplier returns spec value for known pairs
#   - get_multiplier returns 1.0 for unknown / missing pairs (forward-compat)
#   - Turan mirror folding: turan_piyade row matches piyade row semantically
#   - Turan mirror folding: turan_savar, turan_kamandar, turan_asb_savar fold correctly
#   - validate_hard() still passes with full RPS table populated
#   - All 16-cell RPS table values are within [0.0, 5.0]
#
# Design note on Turan mirror folding:
#   The effectiveness dict stores rows only for Iran base types.
#   get_multiplier() strips the "turan_" prefix so turan_piyade lookups resolve
#   to the piyade row, turan_savar to savar, etc.
#   This keeps the data at 16 cells (4×4) rather than duplicating to 36+ cells.
#   Wave 2A (CombatComponent) MUST use get_multiplier(), not raw dict access.
extends GutTest

const CombatMatrixScript: Script = preload("res://data/sub_resources/combat_matrix.gd")

const BALANCE_PATH: String = "res://data/balance.tres"

var _balance: Variant
var _combat: Variant


func before_each() -> void:
	var loaded: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_not_null(loaded, "balance.tres must load without error")
	_balance = loaded
	_combat = loaded.get(&"combat")
	assert_not_null(_combat, "combat sub-resource must exist")


func after_each() -> void:
	_balance = null
	_combat = null


# ---------------------------------------------------------------------------
# 1. API shape
# ---------------------------------------------------------------------------

func test_combat_matrix_has_get_multiplier_method() -> void:
	# get_multiplier must exist on CombatMatrix as the canonical lookup API.
	# Wave 2A CombatComponent uses this — not raw dict access.
	assert_true(_combat.has_method("get_multiplier"),
		"CombatMatrix must expose get_multiplier(attacker, target) -> float")


func test_get_multiplier_returns_float() -> void:
	var result: Variant = _combat.call("get_multiplier", &"piyade", &"piyade")
	assert_true(result is float or result is int,
		"get_multiplier must return a numeric value")


# ---------------------------------------------------------------------------
# 2. Known pairs — spec values from 02e_PHASE_2_SESSION_2_KICKOFF.md §2 item 5
# ---------------------------------------------------------------------------

func test_piyade_vs_piyade_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"piyade"))
	assert_almost_eq(mult, 1.0, 1e-4, "piyade vs piyade must be 1.0 (neutral)")


func test_piyade_vs_kamandar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "piyade vs kamandar must be 1.0 per RPS spec")


func test_piyade_vs_savar_is_anti_cav() -> void:
	# Piyade spears beat cavalry — 1.5× per spec
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"savar"))
	assert_almost_eq(mult, 1.5, 1e-4, "piyade vs savar must be 1.5 (anti-cavalry)")


func test_piyade_vs_asb_savar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"asb_savar_kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "piyade vs asb_savar_kamandar must be 1.0 per spec")


func test_kamandar_vs_piyade_is_anti_melee() -> void:
	# Archers shred slow infantry — 1.5× per spec
	var mult: float = float(_combat.call("get_multiplier", &"kamandar", &"piyade"))
	assert_almost_eq(mult, 1.5, 1e-4, "kamandar vs piyade must be 1.5 (archers vs infantry)")


func test_kamandar_vs_kamandar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"kamandar", &"kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "kamandar vs kamandar must be 1.0")


func test_kamandar_vs_savar_is_disadvantaged() -> void:
	# Kamandar disadvantaged vs heavy cavalry — 0.7× per spec
	var mult: float = float(_combat.call("get_multiplier", &"kamandar", &"savar"))
	assert_almost_eq(mult, 0.7, 1e-4, "kamandar vs savar must be 0.7 (disadvantaged vs heavy cav)")


func test_kamandar_vs_asb_savar_is_disadvantaged() -> void:
	# Kamandar disadvantaged vs mobile horse archers — 0.7× per spec
	var mult: float = float(_combat.call("get_multiplier", &"kamandar", &"asb_savar_kamandar"))
	assert_almost_eq(mult, 0.7, 1e-4, "kamandar vs asb_savar_kamandar must be 0.7")


func test_savar_vs_piyade_is_disadvantaged() -> void:
	# Savar disadvantaged vs Piyade spears — 0.7× per spec
	var mult: float = float(_combat.call("get_multiplier", &"savar", &"piyade"))
	assert_almost_eq(mult, 0.7, 1e-4, "savar vs piyade must be 0.7 (cav vs spears)")


func test_savar_vs_kamandar_is_charge_bonus() -> void:
	# Cavalry charges archers — 2.0× per spec (decisive advantage)
	var mult: float = float(_combat.call("get_multiplier", &"savar", &"kamandar"))
	assert_almost_eq(mult, 2.0, 1e-4, "savar vs kamandar must be 2.0 (cavalry charge vs archers)")


func test_savar_vs_savar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"savar", &"savar"))
	assert_almost_eq(mult, 1.0, 1e-4, "savar vs savar must be 1.0")


func test_savar_vs_asb_savar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"savar", &"asb_savar_kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "savar vs asb_savar_kamandar must be 1.0 per spec")


func test_asb_savar_vs_piyade_is_slight_advantage() -> void:
	# Horse archers kite slow infantry — 1.2× per spec
	var mult: float = float(_combat.call("get_multiplier", &"asb_savar_kamandar", &"piyade"))
	assert_almost_eq(mult, 1.2, 1e-4, "asb_savar_kamandar vs piyade must be 1.2 (kiting advantage)")


func test_asb_savar_vs_kamandar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"asb_savar_kamandar", &"kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "asb_savar_kamandar vs kamandar must be 1.0")


func test_asb_savar_vs_savar_is_disadvantaged() -> void:
	# Horse archers outrun but lose prolonged engagement vs heavy cav — 0.5× per spec
	var mult: float = float(_combat.call("get_multiplier", &"asb_savar_kamandar", &"savar"))
	assert_almost_eq(mult, 0.5, 1e-4, "asb_savar_kamandar vs savar must be 0.5")


func test_asb_savar_vs_asb_savar_is_neutral() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"asb_savar_kamandar", &"asb_savar_kamandar"))
	assert_almost_eq(mult, 1.0, 1e-4, "asb_savar_kamandar vs asb_savar_kamandar must be 1.0")


# ---------------------------------------------------------------------------
# 3. Unknown pair default — forward-compat
# ---------------------------------------------------------------------------

func test_unknown_attacker_returns_default_1() -> void:
	# Unit type not in matrix (future unit type) defaults to 1.0
	var mult: float = float(_combat.call("get_multiplier", &"__future_unit__", &"piyade"))
	assert_almost_eq(mult, 1.0, 1e-4,
		"get_multiplier must return 1.0 for unknown attacker type (forward-compat)")


func test_unknown_target_returns_default_1() -> void:
	# Known attacker, unknown target — default 1.0
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"__future_unit__"))
	assert_almost_eq(mult, 1.0, 1e-4,
		"get_multiplier must return 1.0 for unknown target type (forward-compat)")


func test_both_unknown_returns_default_1() -> void:
	var mult: float = float(_combat.call("get_multiplier", &"__x__", &"__y__"))
	assert_almost_eq(mult, 1.0, 1e-4,
		"get_multiplier must return 1.0 when both types are unknown")


func test_empty_matrix_returns_default_1() -> void:
	# CombatMatrix with no entries must still return 1.0 for any pair.
	var empty_matrix: Resource = CombatMatrixScript.new()
	var mult: float = float(empty_matrix.call("get_multiplier", &"piyade", &"savar"))
	assert_almost_eq(mult, 1.0, 1e-4,
		"Empty CombatMatrix must return 1.0 (not crash) for any pair")


# ---------------------------------------------------------------------------
# 4. Turan mirror folding
# ---------------------------------------------------------------------------

func test_turan_piyade_attacker_folds_to_piyade() -> void:
	# turan_piyade as attacker should resolve to same row as piyade
	var iran_mult: float = float(_combat.call("get_multiplier", &"piyade", &"savar"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"turan_piyade", &"savar"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_piyade attacker must fold to piyade row (same multiplier vs savar)")


func test_turan_kamandar_attacker_folds_to_kamandar() -> void:
	var iran_mult: float = float(_combat.call("get_multiplier", &"kamandar", &"piyade"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"turan_kamandar", &"piyade"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_kamandar attacker must fold to kamandar row")


func test_turan_savar_attacker_folds_to_savar() -> void:
	var iran_mult: float = float(_combat.call("get_multiplier", &"savar", &"kamandar"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"turan_savar", &"kamandar"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_savar attacker must fold to savar row (2.0 vs kamandar)")


func test_turan_asb_savar_attacker_folds_to_asb_savar() -> void:
	var iran_mult: float = float(_combat.call("get_multiplier", &"asb_savar_kamandar", &"piyade"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"turan_asb_savar", &"piyade"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_asb_savar attacker must fold to asb_savar_kamandar row")


func test_turan_target_folds_for_lookup() -> void:
	# As a TARGET, turan_savar folds to savar column
	var iran_mult: float = float(_combat.call("get_multiplier", &"kamandar", &"savar"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"kamandar", &"turan_savar"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_savar as target must fold to savar column")


func test_turan_piyade_target_folds_for_lookup() -> void:
	# As a TARGET, turan_piyade folds to piyade column
	var iran_mult: float = float(_combat.call("get_multiplier", &"savar", &"piyade"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"savar", &"turan_piyade"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_piyade as target must fold to piyade column")


func test_both_turan_folds_correctly() -> void:
	# turan_kamandar vs turan_piyade should resolve to kamandar vs piyade
	var iran_mult: float = float(_combat.call("get_multiplier", &"kamandar", &"piyade"))
	var turan_mult: float = float(_combat.call("get_multiplier", &"turan_kamandar", &"turan_piyade"))
	assert_almost_eq(turan_mult, iran_mult, 1e-4,
		"turan_kamandar vs turan_piyade must fold to kamandar vs piyade multiplier")


# ---------------------------------------------------------------------------
# 5. RPS triangle integrity — the three decisive matchups
# ---------------------------------------------------------------------------

func test_rps_kamandar_beats_piyade() -> void:
	# Core RPS: kamandar > piyade (1.5×)
	var mult: float = float(_combat.call("get_multiplier", &"kamandar", &"piyade"))
	assert_gt(mult, 1.0, "kamandar must have >1.0 advantage vs piyade (RPS triangle)")


func test_rps_savar_beats_kamandar() -> void:
	# Core RPS: savar > kamandar (2.0×)
	var mult: float = float(_combat.call("get_multiplier", &"savar", &"kamandar"))
	assert_gt(mult, 1.0, "savar must have >1.0 advantage vs kamandar (RPS triangle)")


func test_rps_piyade_beats_savar() -> void:
	# Core RPS: piyade > savar (1.5×)
	var mult: float = float(_combat.call("get_multiplier", &"piyade", &"savar"))
	assert_gt(mult, 1.0, "piyade must have >1.0 advantage vs savar (RPS triangle)")


func test_rps_triangle_is_symmetric_in_advantage_direction() -> void:
	# If A has advantage vs B, B must NOT have advantage vs A (RPS must be directional)
	var kami_vs_piy: float = float(_combat.call("get_multiplier", &"kamandar", &"piyade"))
	var piy_vs_kami: float = float(_combat.call("get_multiplier", &"piyade", &"kamandar"))
	# Kamandar beats piyade; piyade does NOT beat kamandar (should be neutral 1.0)
	assert_gt(kami_vs_piy, 1.0, "kamandar vs piyade must be > 1.0")
	assert_almost_eq(piy_vs_kami, 1.0, 1e-4,
		"piyade vs kamandar must be 1.0 (not a counter in either direction)")


func test_all_rps_values_within_hard_bounds() -> void:
	# All values in the effectiveness dict must be within [0.0, 5.0]
	# (BalanceData.validate_hard() enforces this, but verify here as well)
	var effectiveness: Dictionary = _combat.get(&"effectiveness")
	for attacker_key: Variant in effectiveness:
		var row: Variant = effectiveness[attacker_key]
		assert_true(row is Dictionary,
			"effectiveness[%s] must be a Dictionary" % str(attacker_key))
		for target_key: Variant in row:
			var val: float = float(row[target_key])
			assert_true(val >= 0.0 and val <= 5.0,
				"effectiveness[%s][%s] = %.2f must be in [0.0, 5.0]"
				% [str(attacker_key), str(target_key), val])


# ---------------------------------------------------------------------------
# 6. validate_hard still passes with full table
# ---------------------------------------------------------------------------

func test_validate_hard_passes_with_full_rps_table() -> void:
	# validate_hard() must return empty errors with the full 16-cell RPS table populated.
	assert_not_null(_balance)
	var errors: Array = _balance.call(&"validate_hard")
	assert_eq(errors.size(), 0,
		"validate_hard() must pass with full RPS matrix. Errors: %s" % str(errors))
