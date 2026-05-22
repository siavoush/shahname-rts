# Tests for FogConfig sub-resource.
#
# Contract: docs/FOG_DATA_CONTRACT.md §2.2 (sight-radius table) + §7 (BalanceData keys)
# Schema source: game/data/sub_resources/fog_config.gd
#
# Coverage:
#   - FogConfig instantiates cleanly
#   - All @export fields have correct GDScript types
#   - Default values are non-zero (§9.L9 fallback-by-failure-visibility-shape —
#     non-zero defaults match what 3A.5 consumers actually need; no silent-zero)
#   - cell_size_meters is positive (required for grid init in fog_system.gd)
#   - Per-kind sight radii match FOG_DATA_CONTRACT §2.2 spec values
extends GutTest

# Preload forces class_name registration before test methods execute.
# Same class_name registry race workaround as test_balance_data.gd + test_state_machine.gd.
const FogConfigScript: Script = preload("res://data/sub_resources/fog_config.gd")


func test_fog_config_instantiates() -> void:
	var fc: Resource = FogConfigScript.new()
	assert_not_null(fc, "FogConfig must instantiate cleanly")


func test_fog_config_has_correct_type() -> void:
	var fc: Resource = FogConfigScript.new()
	assert_true(fc is Resource, "FogConfig must be a Resource subclass")


func test_cell_size_meters_is_positive() -> void:
	var fc: Resource = FogConfigScript.new()
	assert_gt(fc.cell_size_meters, 0.0, "cell_size_meters must be positive (grid init divides by it)")


func test_cell_size_meters_default_is_spec_value() -> void:
	# FOG_DATA_CONTRACT §1.1 + §2.2: 4m per cell.
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.cell_size_meters, 4.0, "cell_size_meters default must be 4.0 per FOG_DATA_CONTRACT §1.1")


func test_sight_sarbazkhane_cells_default() -> void:
	# FOG_DATA_CONTRACT §2.2 table: Sarbaz-khaneh = 3 cells (12m).
	# §9.L9: non-zero default matching shipped spec value.
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.sight_sarbazkhane_cells, 3,
		"sight_sarbazkhane_cells default must be 3 per FOG_DATA_CONTRACT §2.2")


func test_sight_atashkadeh_cells_default() -> void:
	# FOG_DATA_CONTRACT §2.2 table: Atashkadeh = 2 cells (8m).
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.sight_atashkadeh_cells, 2,
		"sight_atashkadeh_cells default must be 2 per FOG_DATA_CONTRACT §2.2")


func test_tier2_building_sight_defaults_nonzero() -> void:
	# Sowari-khaneh and Tirandazi: Tier-2 institutional buildings.
	# Set to 2 cells (same as Atashkadeh — compact institutional footprint).
	var fc: Resource = FogConfigScript.new()
	assert_gt(fc.sight_sowari_khaneh_cells, 0,
		"sight_sowari_khaneh_cells must be > 0 per §9.L9")
	assert_gt(fc.sight_tirandazi_cells, 0,
		"sight_tirandazi_cells must be > 0 per §9.L9")


func test_unit_sight_defaults_nonzero() -> void:
	# FOG_DATA_CONTRACT §2.2: kargar=3, piyade=3, kamandar=4, savar=4, rostam=5.
	var fc: Resource = FogConfigScript.new()
	assert_gt(fc.sight_kargar_cells, 0, "sight_kargar_cells must be > 0")
	assert_gt(fc.sight_piyade_cells, 0, "sight_piyade_cells must be > 0")
	assert_gt(fc.sight_kamandar_cells, 0, "sight_kamandar_cells must be > 0")
	assert_gt(fc.sight_savar_cells, 0, "sight_savar_cells must be > 0")
	assert_gt(fc.sight_rostam_cells, 0, "sight_rostam_cells must be > 0")


func test_unit_sight_defaults_match_spec() -> void:
	# FOG_DATA_CONTRACT §2.2 canonical values.
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.sight_kargar_cells, 3, "kargar: 3 cells per §2.2")
	assert_eq(fc.sight_piyade_cells, 3, "piyade: 3 cells per §2.2")
	assert_eq(fc.sight_kamandar_cells, 4, "kamandar: 4 cells per §2.2")
	assert_eq(fc.sight_savar_cells, 4, "savar: 4 cells per §2.2")
	assert_eq(fc.sight_rostam_cells, 5, "rostam: 5 cells per §2.2")


func test_throne_sight_default_matches_spec() -> void:
	# FOG_DATA_CONTRACT §2.2: Throne = 4 cells (16m).
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.sight_throne_cells, 4, "throne: 4 cells per §2.2")


func test_khaneh_mazraeh_madan_sight_are_zero() -> void:
	# Khaneh / Mazra'eh / Ma'dan are non-military buildings that reveal only
	# their own footprint (§9.L3 forward-compat note from pre-flight: sight=0
	# means "footprint only, no surrounding radius"). Their sight_cells fields
	# exist in FogConfig for completeness but are intentionally 0 at Wave 3A.0;
	# balance-engineer tunes them via balance.tres at 3A.5 brief-time.
	var fc: Resource = FogConfigScript.new()
	assert_eq(fc.sight_khaneh_cells, 0, "khaneh sight_cells = 0 (footprint-only placeholder)")
	assert_eq(fc.sight_mazraeh_cells, 0, "mazraeh sight_cells = 0 (footprint-only placeholder)")
	assert_eq(fc.sight_madan_cells, 0, "madan sight_cells = 0 (footprint-only placeholder)")
