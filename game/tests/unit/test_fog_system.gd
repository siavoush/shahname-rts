# Tests for FogSystem autoload — data layer + real vision-source API.
#
# Contract: docs/FOG_DATA_CONTRACT.md §1 (grid schema), §2.1 (registration API),
#           §3.1 (per-tick integer-circle), §3.2 (building footprint cells),
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
#   - is_visible_to: real path — register static source, call _on_fog_update_phase,
#     verify cells become visible (wave 3A.5)
#   - register_vision_source: returns positive handle, populates _sources
#   - deregister_vision_source: idempotent, erases record
#   - _on_fog_update_phase: clears + rebuilds; lazy stale cleanup
#   - is_visible_to: returns false when source deregistered / no sources
#   - get_last_seen: returns {} (unchanged at 3A.5 — 3A.7 scope)
#   - get_scout_candidates: returns unexplored cells up to max_results
#   - Storage init: PackedByteArrays sized correctly
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
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog.grid_w, 64, "256m / 4m = 64 cells wide")
	assert_eq(fog.grid_h, 64, "256m / 4m = 64 cells tall")
	fog.free()


func test_grid_dimensions_non_power_of_two() -> void:
	# ceili: 100m / 4m = 25 cells exactly.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(100, 100)), 4.0)
	assert_eq(fog.grid_w, 25)
	assert_eq(fog.grid_h, 25)
	fog.free()


func test_grid_dimensions_non_divisible() -> void:
	# ceili: 101m / 4m = 26 cells (ceiling).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(101, 101)), 4.0)
	assert_eq(fog.grid_w, 26)
	assert_eq(fog.grid_h, 26)
	fog.free()


# --- world_to_cell ---

func test_world_to_cell_origin_is_zero_zero() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(0.0, 0.0, 0.0))
	assert_eq(cell, Vector2i(0, 0), "world origin maps to cell (0,0)")
	fog.free()


func test_world_to_cell_interior_point() -> void:
	# At 4m/cell, world pos (6, 0, 10) → cell (1, 2) (int divide: 6/4=1, 10/4=2).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(6.0, 0.0, 10.0))
	assert_eq(cell, Vector2i(1, 2))
	fog.free()


func test_world_to_cell_clamps_negative_to_zero() -> void:
	# Positions below the map origin clamp to cell (0,0).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(-10.0, 0.0, -10.0))
	assert_eq(cell, Vector2i(0, 0), "negative world positions must clamp to cell (0,0)")
	fog.free()


func test_world_to_cell_clamps_beyond_max() -> void:
	# Positions beyond the map extent clamp to (grid_w-1, grid_h-1).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(999.0, 0.0, 999.0))
	assert_eq(cell, Vector2i(63, 63), "out-of-bounds world positions must clamp to last cell")
	fog.free()


func test_world_to_cell_with_nonzero_origin() -> void:
	# Map starting at (-128, -128) in world space: point (0,0,0) → cell (32, 32).
	var fog: Node = _make_fog_with_bounds(
		Rect2(Vector2(-128.0, -128.0), Vector2(256.0, 256.0)), 4.0)
	var cell: Vector2i = fog.world_to_cell(Vector3(0.0, 0.0, 0.0))
	assert_eq(cell, Vector2i(32, 32), "world_to_cell must account for map origin offset")
	fog.free()


# --- cell_to_world_center ---

func test_cell_to_world_center_origin_cell() -> void:
	# Cell (0,0) center at (2, 0, 2) with 4m cells (half = 2m).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var pos: Vector3 = fog.cell_to_world_center(Vector2i(0, 0))
	assert_eq(pos, Vector3(2.0, 0.0, 2.0), "cell (0,0) center must be at (2,0,2) for 4m cells")
	fog.free()


func test_cell_to_world_center_interior_cell() -> void:
	# Cell (3, 5) center: x = 3*4 + 2 = 14, z = 5*4 + 2 = 22.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var pos: Vector3 = fog.cell_to_world_center(Vector2i(3, 5))
	assert_eq(pos, Vector3(14.0, 0.0, 22.0))
	fog.free()


# --- Round-trip: world_to_cell → cell_to_world_center ---

func test_world_to_cell_roundtrip_stays_in_same_cell() -> void:
	# Pick a world point; convert to cell; get centroid; convert back.
	# The centroid must land in the same cell as the original point.
	# FOG_DATA_CONTRACT §8: deterministic arithmetic guarantees.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var original_pos: Vector3 = Vector3(22.5, 0.0, 37.1)
	var cell: Vector2i = fog.world_to_cell(original_pos)
	var centroid: Vector3 = fog.cell_to_world_center(cell)
	var cell_from_centroid: Vector2i = fog.world_to_cell(centroid)
	assert_eq(cell_from_centroid, cell, "centroid of a cell must map back to the same cell")
	fog.free()


# --- _cell_index ---

func test_cell_index_origin() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog._cell_index(Vector2i(0, 0)), 0, "cell (0,0) must have flat index 0")
	fog.free()


func test_cell_index_formula_row_major() -> void:
	# Row-major: index = y * grid_w + x.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	# grid_w = 64. Cell (3, 2) → 2*64 + 3 = 131.
	assert_eq(fog._cell_index(Vector2i(3, 2)), 131)
	fog.free()


func test_cell_index_last_cell() -> void:
	# Last cell (63, 63) → 63 * 64 + 63 = 4095.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_eq(fog._cell_index(Vector2i(63, 63)), 4095)
	fog.free()


# --- Storage init ---

func test_storage_arrays_sized_correctly() -> void:
	# 64*64 = 4096 bytes per layer per team.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
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
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	for i in range(fog._currently_visible[0].size()):
		if fog._currently_visible[0][i] != 0:
			fail_test("_currently_visible[Iran] must be all-zero at init, byte %d = %d" \
				% [i, fog._currently_visible[0][i]])
			fog.free()
			return
	assert_true(true, "_currently_visible[Iran] is all-zero at init")
	fog.free()


func test_ever_seen_init_all_zero() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	for i in range(fog._ever_seen[0].size()):
		if fog._ever_seen[0][i] != 0:
			fail_test("_ever_seen[Iran] must be all-zero at init, byte %d = %d" \
				% [i, fog._ever_seen[0][i]])
			fog.free()
			return
	assert_true(true, "_ever_seen[Iran] is all-zero at init")
	fog.free()


# --- Consumer API stubs (3A.0: static data) ---

func test_is_visible_to_returns_false_when_no_sources() -> void:
	# No sources registered → _currently_visible all-zero → always false.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_false(fog.is_visible_to(0, Vector3(50.0, 0.0, 50.0)),
		"is_visible_to must return false when no sources registered")
	assert_false(fog.is_visible_to(1, Vector3(100.0, 0.0, 100.0)),
		"is_visible_to must return false for any team when no sources")
	fog.free()


func test_get_last_seen_returns_empty_dict_stub() -> void:
	# 3A.0 stub: no entity tracking yet → always {}.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var result: Dictionary = fog.get_last_seen(0, 1, &"unit")
	assert_true(result.is_empty(),
		"get_last_seen must return {} at 3A.0 (no entity tracking)")
	fog.free()


func test_get_last_seen_returns_empty_for_building() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var result: Dictionary = fog.get_last_seen(0, 1, &"building")
	assert_true(result.is_empty(),
		"get_last_seen(&'building') must return {} at 3A.0")
	fog.free()


func test_get_scout_candidates_returns_array() -> void:
	# 3A.0: _ever_seen all-false → entire map is unexplored → returns up to max_results cells.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 5)
	assert_eq(results.size(), 5, "get_scout_candidates must return exactly max_results cells when enough unexplored exist")
	fog.free()


func test_get_scout_candidates_respects_max_results() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 1)
	assert_eq(results.size(), 1, "max_results=1 must return exactly 1 candidate")
	fog.free()


func test_get_scout_candidates_returns_vector3_y_zero() -> void:
	# FOG_DATA_CONTRACT §5.3: return world-space Vector3 with y=0.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 3)
	for pos in results:
		assert_eq(pos.y, 0.0, "scout candidate y must be 0 per FOG_DATA_CONTRACT §5.3")
	fog.free()


func test_get_scout_candidates_zero_max_returns_empty() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var results: Array[Vector3] = fog.get_scout_candidates(0, 0)
	assert_eq(results.size(), 0, "max_results=0 must return empty array")
	fog.free()


# --- Registration (real implementation — wave 3A.5) ---

func test_register_null_node_returns_minus_one() -> void:
	# Registering a null node is a no-op; returns -1 sentinel.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var handle: int = fog.register_vision_source(null, 0, 3, true)
	assert_eq(handle, -1, "register_vision_source(null, ...) must return -1 sentinel")
	assert_true(fog._sources.is_empty(), "_sources must stay empty after null registration")
	fog.free()


func test_register_valid_node_returns_positive_handle() -> void:
	# A valid Node3D returns handle >= 1; _sources is populated.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	add_child_autofree(dummy)
	var handle: int = fog.register_vision_source(dummy, 0, 2, false)
	assert_gt(handle, 0, "register_vision_source must return handle >= 1 for a valid node")
	assert_true(fog._sources.has(handle), "_sources must contain the returned handle")
	fog.free()


func test_register_populates_sources_record() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	add_child_autofree(dummy)
	var handle: int = fog.register_vision_source(dummy, 1, 3, false)
	var rec: Dictionary = fog._sources[handle]
	assert_eq(rec[&"team"], 1, "source record must carry the registered team")
	assert_eq(rec[&"radius_cells"], 3, "source record must carry the sight radius")
	assert_false(rec[&"is_static"], "source record must carry is_static=false")
	fog.free()


func test_register_static_source_caches_cells() -> void:
	# Static sources (is_static=true) cache their cells at registration.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(10.0, 0.0, 10.0)
	add_child_autofree(dummy)
	var handle: int = fog.register_vision_source(dummy, 0, 2, true)
	var rec: Dictionary = fog._sources[handle]
	assert_true(rec[&"is_static"], "source record must carry is_static=true")
	# With radius=2 the cached_cells array must be non-empty.
	assert_gt(rec[&"cached_cells"].size(), 0,
		"static source with radius=2 must have non-empty cached_cells")
	fog.free()


func test_deregister_removes_source() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	add_child_autofree(dummy)
	var handle: int = fog.register_vision_source(dummy, 0, 1, false)
	assert_true(fog._sources.has(handle))
	fog.deregister_vision_source(handle)
	assert_false(fog._sources.has(handle), "deregister must remove the source record")
	fog.free()


func test_deregister_idempotent_on_sentinel() -> void:
	# -1 is the "not registered" sentinel; deregister must not crash.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	fog.deregister_vision_source(-1)
	assert_true(true, "deregister_vision_source(-1) must not crash")
	fog.free()


func test_deregister_idempotent_on_unknown_handle() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	fog.deregister_vision_source(9999)
	assert_true(true, "deregister_vision_source(9999) must not crash")
	fog.free()


func test_sources_dict_is_empty_at_init() -> void:
	# _sources starts empty; populated only by register_vision_source.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_true(fog._sources.is_empty(), "_sources must be empty after _init_grid")
	fog.free()


# --- Per-tick recompute: _on_fog_update_phase ---

func test_fog_update_makes_unit_position_visible() -> void:
	# Register a dynamic unit source, fire fog_update, verify the unit's
	# cell is visible. FOG_DATA_CONTRACT §3.1.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(20.0, 0.0, 20.0)
	add_child_autofree(dummy)
	# sight=1 so the circle covers the center cell.
	fog.register_vision_source(dummy, 0, 1, false)
	fog._on_fog_update_phase()
	assert_true(fog.is_visible_to(0, Vector3(20.0, 0.0, 20.0)),
		"unit's own cell must be visible to its team after fog_update")
	fog.free()


func test_fog_update_does_not_reveal_other_team() -> void:
	# Iran unit's vision must not reveal cells for team Turan.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(20.0, 0.0, 20.0)
	add_child_autofree(dummy)
	fog.register_vision_source(dummy, 0, 1, false)  # team 0 = Iran
	fog._on_fog_update_phase()
	assert_false(fog.is_visible_to(1, Vector3(20.0, 0.0, 20.0)),
		"Iran unit vision must not reveal cells for Turan")
	fog.free()


func test_fog_update_clears_previous_tick() -> void:
	# Move unit to a new position; old position should no longer be visible.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(8.0, 0.0, 8.0)
	add_child_autofree(dummy)
	fog.register_vision_source(dummy, 0, 0, false)  # radius=0 = single cell
	fog._on_fog_update_phase()
	assert_true(fog.is_visible_to(0, Vector3(8.0, 0.0, 8.0)))
	# Move unit far away.
	dummy.global_position = Vector3(200.0, 0.0, 200.0)
	fog._on_fog_update_phase()
	assert_false(fog.is_visible_to(0, Vector3(8.0, 0.0, 8.0)),
		"old position must not be visible after unit moves and fog_update fires")
	fog.free()


func test_fog_update_integer_circle_radius_2() -> void:
	# At radius=2, the center cell and adjacent cells within r=2 circle must be
	# visible. FOG_DATA_CONTRACT §3.1: dx*dx + dy*dy <= r*r.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	# Place unit at cell (5,5) — world (22, 0, 22) (5*4+2 = 22 is centroid).
	dummy.global_position = Vector3(22.0, 0.0, 22.0)
	add_child_autofree(dummy)
	fog.register_vision_source(dummy, 0, 2, false)
	fog._on_fog_update_phase()
	# Center cell (5,5) must be visible.
	assert_true(fog.is_visible_to(0, fog.cell_to_world_center(Vector2i(5, 5))),
		"center cell (5,5) must be visible at radius=2")
	# Cell (5,7) is at dy=2, dx=0 → 0+4=4 <= 4 → visible (boundary).
	assert_true(fog.is_visible_to(0, fog.cell_to_world_center(Vector2i(5, 7))),
		"cell (5,7) at dy=2 must be visible (boundary of r=2 circle)")
	# Cell (5,8) is at dy=3 → 9 > 4 → NOT visible.
	assert_false(fog.is_visible_to(0, fog.cell_to_world_center(Vector2i(5, 8))),
		"cell (5,8) at dy=3 must NOT be visible (outside r=2 circle)")
	fog.free()


func test_fog_update_stale_source_cleanup() -> void:
	# A source whose node has been freed should be lazily removed from _sources.
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	# Do NOT add to scene tree — position irrelevant; stale path never reads it.
	# Use free() (not queue_free) so is_instance_valid returns false immediately
	# without requiring an await that could leak physics ticks into SimClock.
	var handle: int = fog.register_vision_source(dummy, 0, 1, false)
	assert_true(fog._sources.has(handle))
	# Free the node without deregistering (simulates death without cleanup).
	dummy.free()
	fog._on_fog_update_phase()
	assert_false(fog._sources.has(handle),
		"stale source record must be lazily removed by _on_fog_update_phase")
	fog.free()


func test_ever_seen_is_append_only() -> void:
	# Cells that became visible in tick 1 must stay in _ever_seen after tick 2
	# even if the source moved away (ever_seen never resets).
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(8.0, 0.0, 8.0)
	add_child_autofree(dummy)
	fog.register_vision_source(dummy, 0, 0, false)  # radius=0
	fog._on_fog_update_phase()
	var cell: Vector2i = fog.world_to_cell(Vector3(8.0, 0.0, 8.0))
	var idx: int = fog._cell_index(cell)
	assert_eq(fog._ever_seen[0][idx], 1, "_ever_seen must be 1 after first visibility")
	# Move away and update.
	dummy.global_position = Vector3(200.0, 0.0, 200.0)
	fog._on_fog_update_phase()
	# _currently_visible cleared; _ever_seen still 1.
	assert_eq(fog._currently_visible[0][idx], 0,
		"_currently_visible must be 0 after unit moves away")
	assert_eq(fog._ever_seen[0][idx], 1,
		"_ever_seen must remain 1 — it never resets (eternal memory §7.1)")
	fog.free()


func test_is_visible_to_out_of_range_team_returns_false() -> void:
	var fog: Node = _make_fog_with_bounds(Rect2(Vector2.ZERO, Vector2(256, 256)), 4.0)
	assert_false(fog.is_visible_to(-1, Vector3.ZERO),
		"team_id=-1 must return false")
	assert_false(fog.is_visible_to(99, Vector3.ZERO),
		"team_id out of range must return false")
	fog.free()
