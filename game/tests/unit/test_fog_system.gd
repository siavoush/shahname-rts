# Tests for FogSystem autoload — data layer + consumer API stubs.
#
# Contract: docs/FOG_DATA_CONTRACT.md §1 (grid schema), §2.1 (registration API),
#           §5 (consumer API), §8 (determinism guarantees).
# Source: game/scripts/autoload/fog_system.gd
#
# Coverage:
#   - FogSystem instantiates and has correct API surface
#   - Grid init: grid_w / grid_h computed correctly from map bounds + cell size
#   - world_to_cell: correct cell computation, clamping at boundaries
#   - cell_to_world_center: correct world-space centroid
#   - world_to_cell → cell_to_world_center round-trip: centroid stays in same cell
#   - _cell_index: correct flat-array index, no bounds crash at edges
#   - is_visible_to: returns false at 3A.0 (no sources; _currently_visible all-zero)
#   - get_last_seen: returns {} at 3A.0 (no sources tracked)
#   - get_scout_candidates: returns unexplored cells up to max_results at 3A.0
#   - register_vision_source / deregister_vision_source: callable stubs (no crash)
#   - Storage init: PackedByteArrays sized correctly
#
# §9.H3 dormant-schema call-out: FogSystem._sources dict exists but is empty at
# 3A.0. Wave 3A.5 populates it via register/deregister implementation.
# Wave 3A.5 consumer trigger: _sources population + fog_update phase handler.
extends GutTest

const FogSystemScript: Script = preload("res://scripts/autoload/fog_system.gd")

var _fog: Node


func before_each() -> void:
	_fog = FogSystemScript.new()
	# Bypass _ready (which reads autoloads); call _init_grid directly for test.
	# Tests that need grid data call _make_fog_with_bounds instead.


func after_each() -> void:
	if is_instance_valid(_fog):
		_fog.free()


# --- Grid init helpers ---

func _make_fog_with_bounds(bounds: Rect2, cell_size: float) -> Node:
	var fog: Node = FogSystemScript.new()
	fog._init_grid(bounds, cell_size)
	return fog


# --- Instantiation ---

func test_fog_system_instantiates() -> void:
	assert_not_null(_fog, "FogSystem must instantiate cleanly via .new()")


func test_fog_system_has_is_visible_to() -> void:
	assert_true(_fog.has_method("is_visible_to"),
		"FogSystem must expose is_visible_to() per FOG_DATA_CONTRACT §5.1")


func test_fog_system_has_get_last_seen() -> void:
	assert_true(_fog.has_method("get_last_seen"),
		"FogSystem must expose get_last_seen() per FOG_DATA_CONTRACT §5.2")


func test_fog_system_has_get_scout_candidates() -> void:
	assert_true(_fog.has_method("get_scout_candidates"),
		"FogSystem must expose get_scout_candidates() per FOG_DATA_CONTRACT §5.3")


func test_fog_system_has_register_vision_source() -> void:
	# §9.L6: 7 existing buildings call has_method(&"register_vision_source").
	# This must return true at 3A.0 ship time so the guards start executing.
	assert_true(_fog.has_method("register_vision_source"),
		"FogSystem must expose register_vision_source() — 7 building seams call has_method on this")


func test_fog_system_has_deregister_vision_source() -> void:
	assert_true(_fog.has_method("deregister_vision_source"),
		"FogSystem must expose deregister_vision_source() per FOG_DATA_CONTRACT §2.1")


# --- Grid dimension computation ---

func test_grid_dimensions_from_256x256_map() -> void:
	# FOG_DATA_CONTRACT §1.1: at 4m/cell, 256m map → 64 × 64 = 4096 cells per team.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog.grid_w, 64, "256m / 4m = 64 cells wide")
	assert_eq(fog.grid_h, 64, "256m / 4m = 64 cells tall")
	fog.free()


func test_grid_dimensions_non_power_of_two() -> void:
	# ceili: 100m / 4m = 25 cells exactly.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(100, 100)), 4.0)
	assert_eq(fog.grid_w, 25)
	assert_eq(fog.grid_h, 25)
	fog.free()


func test_grid_dimensions_non_divisible() -> void:
	# ceili: 101m / 4m = 26 cells (ceiling).
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(101, 101)), 4.0)
	assert_eq(fog.grid_w, 26)
	assert_eq(fog.grid_h, 26)
	fog.free()


# --- world_to_cell ---

func test_world_to_cell_origin_is_zero_zero() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(0.0, 0.0, 0.0))
	assert_eq(cell, Vector2i(0, 0), "world origin maps to cell (0,0)")
	fog.free()


func test_world_to_cell_interior_point() -> void:
	# At 4m/cell, world pos (6, 0, 10) → cell (1, 2) (int divide: 6/4=1, 10/4=2).
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(6.0, 0.0, 10.0))
	assert_eq(cell, Vector2i(1, 2))
	fog.free()


func test_world_to_cell_clamps_negative_to_zero() -> void:
	# Positions below the map origin clamp to cell (0,0).
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(-10.0, 0.0, -10.0))
	assert_eq(cell, Vector2i(0, 0), "negative world positions must clamp to cell (0,0)")
	fog.free()


func test_world_to_cell_clamps_beyond_max() -> void:
	# Positions beyond the map extent clamp to (grid_w-1, grid_h-1).
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(999.0, 0.0, 999.0))
	assert_eq(cell, Vector2i(63, 63), "out-of-bounds world positions must clamp to last cell")
	fog.free()


func test_world_to_cell_with_nonzero_origin() -> void:
	# Map starting at (-128, -128) in world space: point (0,0,0) → cell (32, 32).
	var fog: FogSystem = _make_fog_with_bounds(
		Rect2(Vector2(-128.0, -128.0), Vector2(256.0, 256.0)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(0.0, 0.0, 0.0))
	assert_eq(cell, Vector2i(32, 32), "world_to_cell must account for map origin offset")
	fog.free()


# --- cell_to_world_center ---

func test_cell_to_world_center_origin_cell() -> void:
	# Cell (0,0) center at (2, 0, 2) with 4m cells (half = 2m).
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var pos: Vector3 = fog.cell_to_world_center(Vector2i(0, 0))
	assert_eq(pos, Vector3(2.0, 0.0, 2.0), "cell (0,0) center must be at (2,0,2) for 4m cells")
	fog.free()


func test_cell_to_world_center_interior_cell() -> void:
	# Cell (3, 5) center: x = 3*4 + 2 = 14, z = 5*4 + 2 = 22.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var pos: Vector3 = fog.cell_to_world_center(Vector2i(3, 5))
	assert_eq(pos, Vector3(14.0, 0.0, 22.0))
	fog.free()


# --- Round-trip: world_to_cell → cell_to_world_center ---

func test_world_to_cell_roundtrip_stays_in_same_cell() -> void:
	# Pick a world point; convert to cell; get centroid; convert back.
	# The centroid must land in the same cell as the original point.
	# FOG_DATA_CONTRACT §8: deterministic arithmetic guarantees.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var original_pos: Vector3 = Vector3(22.5, 0.0, 37.1)
	var cell: Vector2i = fog.world_to_cell(original_pos)
	var centroid: Vector3 = fog.cell_to_world_center(cell)
	var cell_from_centroid: Vector2i = fog.world_to_cell(centroid)
	assert_eq(cell_from_centroid, cell, "centroid of a cell must map back to the same cell")
	fog.free()


# --- _cell_index ---

func test_cell_index_origin() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog._cell_index(Vector2i(0, 0)), 0, "cell (0,0) must have flat index 0")
	fog.free()


func test_cell_index_formula_row_major() -> void:
	# Row-major: index = y * grid_w + x.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	# grid_w = 64. Cell (3, 2) → 2*64 + 3 = 131.
	assert_eq(fog._cell_index(Vector2i(3, 2)), 131)
	fog.free()


func test_cell_index_last_cell() -> void:
	# Last cell (63, 63) → 63 * 64 + 63 = 4095.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog._cell_index(Vector2i(63, 63)), 4095)
	fog.free()


# --- Storage init ---

func test_storage_arrays_sized_correctly() -> void:
	# 64*64 = 4096 bytes per layer per team.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	# Two teams (TEAM_IRAN=0, TEAM_TURAN=1).
	assert_eq(fog._currently_visible[0].size(), 4096,
		"_currently_visible[Iran] must be grid_w*grid_h bytes")
	assert_eq(fog._currently_visible[1].size(), 4096,
		"_currently_visible[Turan] must be grid_w*grid_h bytes")
	assert_eq(fog._ever_seen[0].size(), 4096)
	assert_eq(fog._ever_seen[1].size(), 4096)
	fog.free()


func test_storage_init_all_zero() -> void:
	# At init, no visibility — all bytes must be 0.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	for i in range(fog._currently_visible[0].size()):
		if fog._currently_visible[0][i] != 0:
			fail_test("_currently_visible[Iran] must be all-zero at init, byte %d = %d" \
				% [i, fog._currently_visible[0][i]])
			fog.free()
			return
	assert_true(true, "_currently_visible[Iran] is all-zero at init")
	fog.free()


func test_ever_seen_init_all_zero() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	for i in range(fog._ever_seen[0].size()):
		if fog._ever_seen[0][i] != 0:
			fail_test("_ever_seen[Iran] must be all-zero at init, byte %d = %d" \
				% [i, fog._ever_seen[0][i]])
			fog.free()
			return
	assert_true(true, "_ever_seen[Iran] is all-zero at init")
	fog.free()


# --- Consumer API stubs (3A.0: static data) ---

func test_is_visible_to_returns_false_stub() -> void:
	# 3A.0 stub: no vision sources registered → always false.
	# Wave 3A.5 supersedes: register sources, per-tick recompute populates.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_false(fog.is_visible_to(0, Vector3(50.0, 0.0, 50.0)),
		"is_visible_to must return false at 3A.0 (no sources)")
	assert_false(fog.is_visible_to(1, Vector3(100.0, 0.0, 100.0)),
		"is_visible_to must return false for any team at 3A.0")
	fog.free()


func test_get_last_seen_returns_empty_dict_stub() -> void:
	# 3A.0 stub: no entity tracking yet → always {}.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var result: Dictionary = fog.get_last_seen(0, 1, &"unit")
	assert_true(result.is_empty(),
		"get_last_seen must return {} at 3A.0 (no entity tracking)")
	fog.free()


func test_get_last_seen_returns_empty_for_building() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var result: Dictionary = fog.get_last_seen(0, 1, &"building")
	assert_true(result.is_empty(),
		"get_last_seen(&'building') must return {} at 3A.0")
	fog.free()


func test_get_scout_candidates_returns_array() -> void:
	# 3A.0: _ever_seen all-false → entire map is unexplored → returns up to max_results cells.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 5)
	assert_eq(results.size(), 5, "get_scout_candidates must return exactly max_results cells when enough unexplored exist")
	fog.free()


func test_get_scout_candidates_respects_max_results() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 1)
	assert_eq(results.size(), 1, "max_results=1 must return exactly 1 candidate")
	fog.free()


func test_get_scout_candidates_returns_vector3_y_zero() -> void:
	# FOG_DATA_CONTRACT §5.3: return world-space Vector3 with y=0.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 3)
	for pos in results:
		assert_eq(pos.y, 0.0, "scout candidate y must be 0 per FOG_DATA_CONTRACT §5.3")
	fog.free()


func test_get_scout_candidates_zero_max_returns_empty() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 0)
	assert_eq(results.size(), 0, "max_results=0 must return empty array")
	fog.free()


# --- Registration stubs (callable, no crash) ---

func test_register_vision_source_stub_does_not_crash() -> void:
	# §9.L6: 7 existing building seams call register_vision_source.
	# The stub must be callable without crashing.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var handle = fog.register_vision_source(null, 0, 3, true)
	# Stub returns -1 (no-op handle) — just verify no crash and callable.
	assert_true(true, "register_vision_source stub must not crash")
	fog.free()


func test_deregister_vision_source_stub_does_not_crash() -> void:
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	fog.deregister_vision_source(-1)
	assert_true(true, "deregister_vision_source stub must not crash")
	fog.free()


func test_deregister_idempotent_on_invalid_handle() -> void:
	# Deregister with a handle that was never registered; must not crash.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	fog.deregister_vision_source(9999)
	assert_true(true, "deregister_vision_source must be idempotent on unknown handles")
	fog.free()


func test_sources_dict_is_empty_at_init() -> void:
	# §9.H3 dormant-schema: _sources dict ships empty at 3A.0.
	# Wave 3A.5 populates it when register_vision_source gains its implementation.
	var fog: FogSystem = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_true(fog._sources.is_empty(),
		"_sources must be empty at 3A.0 (register stub does not populate)")
	fog.free()
