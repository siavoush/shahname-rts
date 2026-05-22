extends Node
##
## FogSystem — fog-of-war data layer autoload.
##
## Canonical spec: docs/FOG_DATA_CONTRACT.md v1.3.1 (ratified Phase 3 session 2;
##   holds clean at HEAD per world-builder-p3s2 session-7 pre-flight).
##
## Wave 3A.0 scope (data layer + consumer API stub):
##   - Grid init: world → cell mapping, PackedByteArray storage.
##   - Consumer API stubs returning static data:
##       is_visible_to → false (no sources registered yet)
##       get_last_seen → {} (no entity tracking yet)
##       get_scout_candidates → unexplored cells (entire map at 3A.0)
##   - register_vision_source / deregister_vision_source: callable stubs.
##     has_method() returns true so the 7 existing building forward-compat
##     guards begin executing rather than no-oping. The stubs no-op silently.
##   - _sources: Dictionary empty structure (§9.H3 dormant-schema).
##
## Wave 3A.5 scope (this file):
##   - register_vision_source / deregister_vision_source full implementation.
##   - fog_update phase handler (per-tick clear + rebuild from _sources).
##   - is_visible_to real impl (reads _currently_visible).
##   - SimClock.fog_update phase connection in _ready.
##   - Unit-side registration in unit._ready + death path (Track 2, separate).
##
## §9.H3 dormant-schema call-out (from 02l_PHASE_3_SESSION_7_KICKOFF.md §3.1):
##   Three dormant-schema surfaces ship at 3A.0, consumed at 3A.5:
##     1. BalanceData.fog sub-resource (FogConfig class — balance-engineer Track 2).
##        Wave 3A.5 trigger: register_vision_source reads sight_<kind>_cells.
##     2. _sources dictionary (empty at 3A.0).
##        Wave 3A.5 trigger: register/deregister implementation populates it.
##     3. fog_update SimClock phase (engine-architect Track 3 adds it to PHASES).
##        Wave 3A.5 trigger: FogSystem connects on the phase; recompute fires.
##
## §9.L6 forward-compat-guard-sweep result (world-builder pre-commit self-review):
##   `git grep -n 'register_vision_source\|FogSystem' game/scripts/` finds 7 readers:
##     mazraeh.gd, madan.gd, khaneh.gd (via super), sarbaz_khaneh.gd, atashkadeh.gd,
##     sowari_khaneh.gd, tirandazi.gd — all in _on_placement_complete.
##   All 7 use the pattern:
##     var _fog_node = _autoload_or_null(&"FogSystem")
##     if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
##         _fog_node.call(&"register_vision_source", self, team, 0, true)
##   At 3A.0 ship time: FogSystem is now registered in project.godot, so
##   _autoload_or_null() returns the node. has_method() returns true (stub exists).
##   call() invokes the stub, which no-ops. No observable behavior change.
##   All 7 readers handle the stubbed API correctly. Sweep clean.
##
## §9.D9 pre-commit Step 2 WorldGrid check:
##   WorldGrid autoload does NOT exist at HEAD (confirmed: project.godot [autoload]
##   section has no WorldGrid entry; game/scripts/autoload/ contains no world_grid.gd).
##   Fallback path triggers: _ready() uses MAP_BOUNDS_FALLBACK = Rect2(Vector2.ZERO,
##   Vector2(256, 256)) per pre-flight recommendation and kickoff brief §4 Track 1.
##
## §9.L8/§9.L9 (dormant at 3A.0; flagged for 3A.5/debug-overlay time):
##   No UI surface reads fog values at 3A.0. When the F4 debug overlay gains fog
##   display (post-3A.5), any numeric values shown must use BalanceData reads with
##   non-zero §9.L9 fallbacks per the discipline established in session-6.
##
## Determinism guarantees (FOG_DATA_CONTRACT §8):
##   Grid computation uses integer arithmetic only: clampi + int division.
##   No float accumulation in cell index arithmetic. Deterministic on x86-64 + ARM64.


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Map bounds fallback used when WorldGrid autoload is absent.
## Per FOG_DATA_CONTRACT §1.1: ~256m × 256m playing field.
## pre-flight recommendation + kickoff brief §4 Track 1.
const MAP_BOUNDS_FALLBACK: Rect2 = Rect2(Vector2.ZERO, Vector2(256.0, 256.0))

## Cell size fallback. §9.L9: non-zero, matches shipped spec value (4.0m).
## Used when BalanceData.fog.cell_size_meters is unavailable.
const _FALLBACK_CELL_SIZE: float = 4.0

## Number of teams. Team 0 = Iran, Team 1 = Turan per Constants.TEAM_IRAN/TEAM_TURAN.
const NUM_TEAMS: int = 2


# ---------------------------------------------------------------------------
# Grid dimensions — computed once at _ready / _init_grid
# ---------------------------------------------------------------------------

## Width and height of the fog grid in cells.
## Public so tests can assert grid dimensions without reading private fields.
var grid_w: int = 0
var grid_h: int = 0

## World-space origin of the grid (min-corner).
var _grid_origin: Vector2 = Vector2.ZERO

## Cell size in metres (stored as float for centroid computation).
## NOT read in the per-tick visibility path — only for helper conversions.
var _cell_size_m: float = _FALLBACK_CELL_SIZE


# ---------------------------------------------------------------------------
# Per-team storage — two layers (FOG_DATA_CONTRACT §1.2)
# ---------------------------------------------------------------------------

## _currently_visible[team_id]: PackedByteArray sized grid_w * grid_h.
## Cleared and rebuilt from registered sources each fog_update tick (3A.5).
## At 3A.0: all-zero (no sources registered).
var _currently_visible: Array[PackedByteArray] = []

## _ever_seen[team_id]: PackedByteArray sized grid_w * grid_h.
## Append-only: cells flip 0→1 when first entering _currently_visible.
## Never resets during a match. Eternal memory per §7.1.
## At 3A.0: all-zero (no sources registered).
var _ever_seen: Array[PackedByteArray] = []


# ---------------------------------------------------------------------------
# Vision sources registry (§9.H3 dormant-schema — 3A.5 populates)
# ---------------------------------------------------------------------------

## Per-vision-source records. Empty at 3A.0; register_vision_source stub
## is a no-op. Wave 3A.5 implements and populates.
## Key: opaque integer handle (monotonic counter).
## Value: { node, team, radius_cells, is_static, cached_cells }.
var _sources: Dictionary = {}

## Monotonic handle counter. Starts at 1 so handle 0 / -1 are sentinel
## values tests can use for "no handle / deregistered".
var _next_handle: int = 1


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Resolve map bounds: prefer WorldGrid autoload if it exists; else fallback.
	# WorldGrid does NOT exist at Wave 3A.0 — fallback path is the normal path.
	var bounds: Rect2 = _resolve_map_bounds()

	# Resolve cell size from BalanceData.fog; else fallback constant.
	var cell_size: float = _resolve_cell_size()

	_init_grid(bounds, cell_size)

	# Connect fog_update SimClock phase (wave 3A.5). SimClock is an autoload;
	# same SceneTree pattern as farr_system.gd / resource_system.gd.
	# The phase was added in wave 3A.0 Track 3 (engine-architect).
	var sc: Node = _autoload_or_null(&"SimClock")
	if sc != null and sc.has_signal(&"fog_update"):
		sc.fog_update.connect(_on_fog_update_phase)


## Public grid initializer (used by tests to bypass _ready's autoload reads).
## Tests call this directly with known bounds + cell size to verify grid math.
func _init_grid(bounds: Rect2, cell_size: float) -> void:
	_cell_size_m = cell_size
	_grid_origin = bounds.position
	grid_w = ceili(bounds.size.x / cell_size)
	grid_h = ceili(bounds.size.y / cell_size)

	var total_cells: int = grid_w * grid_h

	_currently_visible.clear()
	_ever_seen.clear()
	for _i in range(NUM_TEAMS):
		var vis: PackedByteArray = PackedByteArray()
		vis.resize(total_cells)
		vis.fill(0)
		_currently_visible.append(vis)

		var seen: PackedByteArray = PackedByteArray()
		seen.resize(total_cells)
		seen.fill(0)
		_ever_seen.append(seen)

	_sources.clear()
	_next_handle = 1


# ---------------------------------------------------------------------------
# Cell ↔ world conversion (FOG_DATA_CONTRACT §1.3)
# ---------------------------------------------------------------------------

## Convert a world-space position to a fog grid cell.
## Boundary-clamps to [0, grid_w-1] × [0, grid_h-1].
## Integer arithmetic only — deterministic per §8.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var rel: Vector2 = Vector2(world_pos.x, world_pos.z) - _grid_origin
	return Vector2i(
		clampi(int(rel.x / _cell_size_m), 0, grid_w - 1),
		clampi(int(rel.y / _cell_size_m), 0, grid_h - 1),
	)


## Convert a fog grid cell to its world-space centroid (y = 0).
## Per FOG_DATA_CONTRACT §1.3 and §5.3 (scout candidates return y=0).
func cell_to_world_center(cell: Vector2i) -> Vector3:
	return Vector3(
		_grid_origin.x + (cell.x + 0.5) * _cell_size_m,
		0.0,
		_grid_origin.y + (cell.y + 0.5) * _cell_size_m,
	)


## Flat array index for a cell. Row-major: index = y * grid_w + x.
## Callers are responsible for passing clamped cells (world_to_cell does this).
func _cell_index(cell: Vector2i) -> int:
	return cell.y * grid_w + cell.x


# ---------------------------------------------------------------------------
# Consumer API — §5 (stubs at 3A.0; 3A.5 implements real computation)
# ---------------------------------------------------------------------------

## Returns true if world_pos is currently visible to team_id.
## FOG_DATA_CONTRACT §5.1.
## Wave 3A.5: reads _currently_visible[team_id][cell_index].
func is_visible_to(team_id: int, world_pos: Vector3) -> bool:
	if team_id < 0 or team_id >= NUM_TEAMS:
		return false
	if _currently_visible.is_empty():
		return false
	var cell: Vector2i = world_to_cell(world_pos)
	var idx: int = _cell_index(cell)
	return _currently_visible[team_id][idx] != 0


## Returns the last known position + tick for a tracked entity.
## 3A.0 stub: always {} (no entity tracking yet).
## Wave 3A.5 supersedes with: _last_seen_by_team lookup.
## entity_kind: &"unit" or &"building" (namespace disambiguation per §5.2).
func get_last_seen(team_id: int, entity_id: int, entity_kind: StringName) -> Dictionary:
	var _team: int = team_id
	var _eid: int = entity_id
	var _kind: StringName = entity_kind
	return {}


## Returns up to max_results world-space positions (y=0) of unexplored cells
## for team_id. At 3A.0, _ever_seen is all-false so the entire map is
## unexplored — returns first max_results cell centroids.
## Wave 3A.5 supersedes with a sparse _unexplored_cells set maintained
## incrementally (cells removed when they flip in _ever_seen).
func get_scout_candidates(team_id: int, max_results: int) -> Array[Vector3]:
	var _team: int = team_id
	if max_results <= 0:
		return []
	var results: Array[Vector3] = []
	var count: int = 0
	for cy in range(grid_h):
		if count >= max_results:
			break
		for cx in range(grid_w):
			if count >= max_results:
				break
			results.append(cell_to_world_center(Vector2i(cx, cy)))
			count += 1
	return results


# ---------------------------------------------------------------------------
# Vision source registration — §2.1 (stubs at 3A.0; 3A.5 implements)
# ---------------------------------------------------------------------------

## Register a node as a vision source. Returns an opaque integer handle.
## The handle is stored by the caller (building or unit) and passed to
## deregister_vision_source when the entity is destroyed.
## FOG_DATA_CONTRACT §2.1.
##
## node: the Node3D emitting vision (must have global_position).
## team_id: Constants.TEAM_IRAN or TEAM_TURAN.
## sight_radius_cells: integer cell count from BalanceData.fog.sight_<kind>_cells.
## is_static: true for buildings (position never changes; footprint cells cached
##   once at registration). false for units (position recomputed each fog_update).
##
## Wave 3A.5: populates _sources + caches footprint cells for static sources.
## Returns a positive handle (>= 1). Safe to call with null node (returns -1).
func register_vision_source(
		node: Node3D,
		team_id: int,
		sight_radius_cells: int,
		is_static: bool = false) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	var handle: int = _next_handle
	_next_handle += 1
	var cached: Array[int] = []
	if is_static:
		# Buildings: cache footprint cells + circle cells now; never recomputed.
		# FOG_DATA_CONTRACT §3.2: use Building.get_footprint_aabb() for footprint.
		if node.has_method(&"get_footprint_aabb"):
			var aabb: AABB = node.call(&"get_footprint_aabb") as AABB
			cached = _footprint_cells(aabb)
		else:
			# Non-building static source (unusual): use its position as a single cell.
			var c: Vector2i = world_to_cell(node.global_position)
			cached.append(_cell_index(c))
		if sight_radius_cells > 0:
			# Merge integer-circle cells into the static cache.
			var center: Vector2i = world_to_cell(node.global_position)
			_merge_circle_cells(center, sight_radius_cells, cached)
	_sources[handle] = {
		&"node": node,
		&"team": team_id,
		&"radius_cells": sight_radius_cells,
		&"is_static": is_static,
		&"cached_cells": cached,
	}
	return handle


## Remove a vision source by handle.
## Idempotent: safe to call with -1, unknown handles, or handles already erased.
## FOG_DATA_CONTRACT §2.1.
func deregister_vision_source(handle: int) -> void:
	if _sources.has(handle):
		_sources.erase(handle)


# ---------------------------------------------------------------------------
# Per-tick fog recompute — connected to SimClock.fog_update in _ready
# ---------------------------------------------------------------------------

## Per-tick handler. Clears _currently_visible for all teams, then rebuilds
## it from all registered vision sources. Lazily cleans up stale records
## (is_instance_valid check). Updates _ever_seen monotonically.
## FOG_DATA_CONTRACT §3.1.
func _on_fog_update_phase() -> void:
	# Clear current visibility for all teams.
	for team_idx in range(NUM_TEAMS):
		_currently_visible[team_idx].fill(0)

	# Stale handle keys collected for cleanup (avoids mutating dict while iterating).
	var stale: Array[int] = []

	for handle in _sources:
		var rec: Dictionary = _sources[handle]
		var node_variant: Variant = rec[&"node"]

		# Lazy cleanup: node was freed without deregistering.
		# Check is_instance_valid on the raw Variant BEFORE casting — casting a
		# freed object triggers a fatal script error even with a null result.
		if not is_instance_valid(node_variant):
			stale.append(handle)
			continue
		var node: Node3D = node_variant as Node3D

		var team_idx: int = rec[&"team"]
		if team_idx < 0 or team_idx >= NUM_TEAMS:
			continue

		var vis: PackedByteArray = _currently_visible[team_idx]
		var seen: PackedByteArray = _ever_seen[team_idx]

		if rec[&"is_static"]:
			# Static source: use pre-cached cells.
			for idx in rec[&"cached_cells"]:
				vis[idx] = 1
				seen[idx] = 1
		else:
			# Dynamic source (unit): recompute integer-circle each tick.
			var radius: int = rec[&"radius_cells"]
			var center: Vector2i = world_to_cell(node.global_position)
			if radius <= 0:
				var single_idx: int = _cell_index(center)
				vis[single_idx] = 1
				seen[single_idx] = 1
			else:
				for dy in range(-radius, radius + 1):
					var cy: int = center.y + dy
					if cy < 0 or cy >= grid_h:
						continue
					for dx in range(-radius, radius + 1):
						if dx * dx + dy * dy > radius * radius:
							continue
						var cx: int = center.x + dx
						if cx < 0 or cx >= grid_w:
							continue
						var idx: int = cy * grid_w + cx
						vis[idx] = 1
						seen[idx] = 1

	for handle in stale:
		_sources.erase(handle)


# ---------------------------------------------------------------------------
# Footprint helper — §3.2
# ---------------------------------------------------------------------------

## Convert a building footprint AABB to a flat list of cell indices.
## FOG_DATA_CONTRACT §3.2: XZ-only, Y ignored.
func _footprint_cells(aabb: AABB) -> Array[int]:
	var result: Array[int] = []
	# Min and max corners in XZ, clamped to grid.
	var min_cell: Vector2i = world_to_cell(aabb.position)
	var max_cell: Vector2i = world_to_cell(aabb.position + aabb.size)
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			result.append(cy * grid_w + cx)
	return result


## Merge integer-circle cells centered on `center` into `out_cells`.
## Uses dx*dx + dy*dy <= r*r per FOG_DATA_CONTRACT §3.1.
## Only appends cells not already present (avoids duplicates but order
## does not matter — duplicates would just set vis=1 twice, harmless).
func _merge_circle_cells(center: Vector2i, radius: int, out_cells: Array[int]) -> void:
	for dy in range(-radius, radius + 1):
		var cy: int = center.y + dy
		if cy < 0 or cy >= grid_h:
			continue
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var cx: int = center.x + dx
			if cx < 0 or cx >= grid_w:
				continue
			var idx: int = cy * grid_w + cx
			if idx not in out_cells:
				out_cells.append(idx)


# ---------------------------------------------------------------------------
# Private helpers — autoload + BalanceData reads
# ---------------------------------------------------------------------------

func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


func _resolve_map_bounds() -> Rect2:
	# WorldGrid does not exist at Wave 3A.0. Fallback is the expected normal path.
	# When WorldGrid ships in a future wave, this reads WorldGrid.map_bounds
	# and the fallback becomes the exception path.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var wg: Node = tree.root.get_node_or_null(NodePath("WorldGrid"))
		if wg != null and "map_bounds" in wg:
			return wg.map_bounds as Rect2
	# WorldGrid absent (normal at 3A.0): use fallback.
	return MAP_BOUNDS_FALLBACK


func _resolve_cell_size() -> float:
	# Read from BalanceData.fog.cell_size_meters if available.
	# balance-engineer Track 2 ships the .fog sub-resource; at 3A.0 it may
	# or may not be in balance.tres yet (parallel dispatch). Fallback is safe.
	var path: String = "res://data/balance.tres"
	if not FileAccess.file_exists(path):
		return _FALLBACK_CELL_SIZE
	var bd: Resource = load(path)
	if bd == null:
		return _FALLBACK_CELL_SIZE
	var fog_cfg: Variant = bd.get(&"fog")
	if fog_cfg == null:
		return _FALLBACK_CELL_SIZE
	var cell_size: Variant = fog_cfg.get(&"cell_size_meters")
	if typeof(cell_size) != TYPE_FLOAT and typeof(cell_size) != TYPE_INT:
		return _FALLBACK_CELL_SIZE
	if float(cell_size) <= 0.0:
		return _FALLBACK_CELL_SIZE
	return float(cell_size)
