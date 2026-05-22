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
## Wave 3A.5 scope (NOT this file at 3A.0):
##   - register_vision_source / deregister_vision_source full implementation.
##   - fog_update phase handler (per-tick clear + rebuild from _sources).
##   - cleanup death-freeze pass.
##   - Replace 7-building sight=0 forward-compat call-sites with BalanceData reads.
##   - Unit-side registration in unit._ready + death path.
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
## 3A.0 stub: always false (no vision sources registered; _currently_visible
##   is all-zero; no per-tick recompute runs until 3A.5).
## Wave 3A.5 supersedes with: _currently_visible[team_id][cell_index] == 1.
func is_visible_to(team_id: int, world_pos: Vector3) -> bool:
	# Suppress unused-parameter warnings at 3A.0. 3A.5 uses both.
	var _team: int = team_id
	var _pos: Vector3 = world_pos
	return false


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

## Register a node as a vision source.
## 3A.0 stub: callable so has_method returns true (unblocks 7 building seams);
##   no-ops silently. Returns -1 (sentinel handle for "stub, not registered").
## Wave 3A.5 supersedes with: _sources population + static-source caching.
## §9.L6: the 7 building forward-compat guards start executing at 3A.0 ship.
##   All call register_vision_source(self, team, 0, true) — stub accepts all
##   arguments, returns -1, no observable effect.
func register_vision_source(
		_node: Node3D,
		_team_id: int,
		_sight_radius_cells: int,
		_is_static: bool = false) -> int:
	# 3A.0 no-op stub. Wave 3A.5: populate _sources, cache static cell sets.
	return -1


## Remove a vision source by handle.
## 3A.0 stub: idempotent no-op. Safe to call with -1 or any unknown handle.
## Wave 3A.5 supersedes with: _sources.erase(handle).
func deregister_vision_source(_handle: int) -> void:
	# 3A.0 no-op stub. Wave 3A.5: _sources.erase(handle).
	pass


# ---------------------------------------------------------------------------
# Private helpers — autoload + BalanceData reads
# ---------------------------------------------------------------------------

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
