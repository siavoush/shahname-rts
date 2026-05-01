extends Node
##
## SpatialIndex — uniform 8m-grid index over the XZ plane.
##
## Per docs/SIMULATION_CONTRACT.md §3:
##   - Single uniform grid, cell size 8m (Constants.SPATIAL_CELL_SIZE).
##   - Y axis ignored; flat 2D over XZ.
##   - Three query shapes: query_radius, query_nearest_n, query_radius_team.
##   - Population: any node with a SpatialAgentComponent child auto-registers
##     on _ready, deregisters on tree_exiting.
##   - Rebuild at the start of the spatial_rebuild phase.
##
## Storage shape: cells (Dictionary[Vector2i, Array[SpatialAgentComponent]]).
## We index *components*, not their parent units, because the component holds
## the team/radius the queries need. Callers that want the parent unit do
## `agent.get_parent()`.
##
## Read-safety from _input/_process between ticks: per Sim Contract §3.4,
## queries from off-tick contexts read the most-recently-rebuilt state. No
## special locking required — queries are pure reads against the cells dict.
##
## Determinism note: query results are returned as Array[Node]. Order within
## a cell is deterministic (insertion order), but cells are scanned by
## Dictionary iteration order, which is stable in Godot's Dictionary type.
## query_nearest_n explicitly sorts by distance for determinism. Tests that
## care about order must filter or sort.

# All registered agents, keyed by Vector2i cell coords. Rebuilt from scratch
# in _rebuild() — cheap at MVP scale (200-ish agents). Per-frame complexity
# is documented in Sim Contract §3.3.
var _cells: Dictionary = {}

# Master list of currently-registered agents. _rebuild() iterates this list
# to fill _cells. Kept as a plain Array; ordering is registration order,
# which is deterministic given deterministic spawn order.
var _agents: Array[Node] = []


func _ready() -> void:
	# Listen for the spatial_rebuild phase signal. Per Sim Contract §1.2/§2 the
	# spatial_rebuild phase runs between movement and combat; combat queries
	# read the rebuilt index.
	EventBus.sim_phase.connect(_on_sim_phase)


# === Registration ============================================================

## Register a SpatialAgentComponent so it participates in queries. Idempotent —
## registering an already-registered agent is a no-op. Components call this
## from their own _ready hook (see SpatialAgentComponent).
func register(agent: Node) -> void:
	if agent in _agents:
		return
	_agents.append(agent)
	# Also place into the right cell now so queries between rebuilds work.
	# _rebuild() will reconcile on the next spatial_rebuild phase.
	_insert_into_cell(agent)


## Deregister an agent. Idempotent — removing an unknown agent is a no-op.
## Called from SpatialAgentComponent._exit_tree.
func unregister(agent: Node) -> void:
	_agents.erase(agent)
	_remove_from_cell(agent)


## Diagnostic: number of currently-registered agents. Useful for tests.
func agent_count() -> int:
	return _agents.size()


# === Queries =================================================================

## Return all agents within `radius` of `center` on the XZ plane.
##
## Complexity: O(C + k) where C ≈ (2r/CELL_SIZE)² and k = candidates.
func query_radius(center: Vector3, radius: float) -> Array[Node]:
	var results: Array[Node] = []
	var radius_sq := radius * radius
	var cells := _cells_in_radius(center, radius)
	for cell_key in cells:
		if not _cells.has(cell_key):
			continue
		for agent in _cells[cell_key]:
			if not is_instance_valid(agent):
				continue
			var pos := _agent_world_position(agent)
			if _xz_distance_sq(pos, center) <= radius_sq:
				results.append(agent)
	return results


## Return all agents within `radius` of `center` whose `team` matches `team`.
## team = Constants.TEAM_ANY (-1) means "any team" — equivalent to query_radius.
##
## Filter is applied during cell scan to avoid copying the full neighborhood.
func query_radius_team(center: Vector3, radius: float, team: int) -> Array[Node]:
	if team == Constants.TEAM_ANY:
		return query_radius(center, radius)
	var results: Array[Node] = []
	var radius_sq := radius * radius
	var cells := _cells_in_radius(center, radius)
	for cell_key in cells:
		if not _cells.has(cell_key):
			continue
		for agent in _cells[cell_key]:
			if not is_instance_valid(agent):
				continue
			# Avoid a hard `as SpatialAgentComponent` cast here — autoloads
			# parse before class_name registration completes, so the typed
			# cast can fail at script-reload time. The component sets `team`
			# as a property; read it duck-typed.
			if int(agent.get(&"team")) != team:
				continue
			var pos := _agent_world_position(agent)
			if _xz_distance_sq(pos, center) <= radius_sq:
				results.append(agent)
	return results


## Return up to `n` nearest agents to `point`, optionally filtered by team.
## team = Constants.TEAM_ANY (-1) for any team.
##
## Implementation spirals outward by cell-radius until at least `n` candidates
## are collected (or all cells exhausted), then sorts by distance and trims.
## Complexity O(C + k log k) per Sim Contract §3.3.
##
## Per the contract: this query excludes the source if the source is itself a
## registered agent. We approximate this by NOT auto-excluding (the caller
## holds the source ref) — a follow-up phase will pin this down when the
## first concrete consumer lands. See ARCHITECTURE.md §6.
func query_nearest_n(point: Vector3, n: int, team_filter: int) -> Array[Node]:
	if n <= 0:
		return []
	var candidates: Array[Node] = []
	# Spiral cell-radius outward until we have at least n candidates, capped
	# at a sane upper bound to avoid pathological scans on near-empty maps.
	var max_radius_cells: int = 64   # 64 * 8m = 512m, larger than the 256m map
	var collected := 0
	for ring in range(max_radius_cells):
		var ring_cells := _ring_cells(point, ring)
		for cell_key in ring_cells:
			if not _cells.has(cell_key):
				continue
			for agent in _cells[cell_key]:
				if not is_instance_valid(agent):
					continue
				if team_filter != Constants.TEAM_ANY:
					# Duck-typed read; same rationale as query_radius_team.
					if int(agent.get(&"team")) != team_filter:
						continue
				candidates.append(agent)
				collected += 1
		if collected >= n:
			break
	# Sort by squared distance for determinism + cheap.
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		return _xz_distance_sq(_agent_world_position(a), point) \
			< _xz_distance_sq(_agent_world_position(b), point))
	if candidates.size() > n:
		candidates = candidates.slice(0, n)
	# slice() returns Array (untyped); rebuild as Array[Node] for return type.
	var typed: Array[Node] = []
	for c in candidates:
		typed.append(c)
	return typed


# === Rebuild =================================================================
# Wired to EventBus.sim_phase. Runs only when phase == spatial_rebuild.
# Tests can call _rebuild() directly to verify the bin shape without driving
# the full tick loop.

func _on_sim_phase(phase: StringName, _tick: int) -> void:
	if phase != Constants.PHASE_SPATIAL_REBUILD:
		return
	_rebuild()


## Rebuild the cell index from the current agent list. O(N) in the agent count.
## Public so tests can drive it without the EventBus path.
func _rebuild() -> void:
	_cells.clear()
	# Filter dead agents while we're here — defensive against unregister
	# races (object freed without _exit_tree firing).
	var live: Array[Node] = []
	for agent in _agents:
		if is_instance_valid(agent):
			live.append(agent)
			_insert_into_cell(agent)
	_agents = live


# === Test/diagnostic helpers ================================================

## Reset to pristine state. Used by GUT before_each / after_each — mirrors
## SimClock.reset / GameState.reset.
func reset() -> void:
	_cells.clear()
	_agents.clear()


# === Internals ===============================================================

# Convert a world position (XZ) to a cell index.
func _world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / Constants.SPATIAL_CELL_SIZE)),
		int(floor(pos.z / Constants.SPATIAL_CELL_SIZE)))


# Pull XZ position from a registered agent. Wraps SpatialAgentComponent so
# queries don't have to know the projection rule. Duck-typed (uses
# has_method) so the autoload parses cleanly even before class_name
# resolution completes.
func _agent_world_position(agent: Node) -> Vector3:
	if agent.has_method(&"world_position"):
		return agent.call(&"world_position")
	# Fallback: if the parent is a Node3D, use its global_position.
	var p := agent.get_parent()
	if p is Node3D:
		return (p as Node3D).global_position
	return Vector3.ZERO


# XZ-only squared distance (Y ignored; cheap — no sqrt).
func _xz_distance_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


# Insert an agent into its current cell. Used by both register() (initial
# placement) and _rebuild (full reconstruction).
func _insert_into_cell(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	var pos := _agent_world_position(agent)
	var key := _world_to_cell(pos)
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(agent)


# Best-effort removal from any cell that contains the agent. We don't store a
# back-reference (component → cell), so this scans any cells that were
# possibly populated. At MVP scale this is fine; if it shows up in profiling
# we add the back-ref.
func _remove_from_cell(agent: Node) -> void:
	for cell_key in _cells.keys():
		var bucket: Array = _cells[cell_key]
		bucket.erase(agent)


# All cell keys whose AABB intersects the (center, radius) circle. We use the
# cell AABB bounding box as the conservative gate; per-agent distance check
# happens in the query body.
func _cells_in_radius(center: Vector3, radius: float) -> Array:
	var min_cell := _world_to_cell(Vector3(center.x - radius, 0.0, center.z - radius))
	var max_cell := _world_to_cell(Vector3(center.x + radius, 0.0, center.z + radius))
	var result: Array = []
	for cx in range(min_cell.x, max_cell.x + 1):
		for cz in range(min_cell.y, max_cell.y + 1):
			result.append(Vector2i(cx, cz))
	return result


# All cells exactly `ring` cell-units away from the center (in Chebyshev /
# king-move distance). ring == 0 is the single source cell.
func _ring_cells(center: Vector3, ring: int) -> Array:
	var center_cell := _world_to_cell(center)
	if ring == 0:
		return [center_cell]
	var result: Array = []
	# Top/bottom rows.
	for dx in range(-ring, ring + 1):
		result.append(Vector2i(center_cell.x + dx, center_cell.y - ring))
		result.append(Vector2i(center_cell.x + dx, center_cell.y + ring))
	# Left/right columns (excluding corners already covered above).
	for dz in range(-ring + 1, ring):
		result.append(Vector2i(center_cell.x - ring, center_cell.y + dz))
		result.append(Vector2i(center_cell.x + ring, center_cell.y + dz))
	return result
