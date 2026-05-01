extends "res://scripts/core/path_scheduler.gd"
##
## NavigationAgentPathScheduler — production IPathScheduler.
##
## Per docs/SIMULATION_CONTRACT.md §4.3.
##
## Wraps Godot 4's NavigationServer3D synchronous map_get_path() query. The
## terrain scene (game/scenes/world/terrain.tscn) is a NavigationRegion3D
## that bakes a navmesh in _ready (see game/scripts/world/terrain.gd). Every
## queried path uses the *default* navigation map of the World3D the
## scheduler is asked to query against.
##
## The default navigation map for the active scene tree is resolved through
## the SceneTree's main viewport — World3D.navigation_map. The scheduler
## holds the map RID directly so it does not need to walk the tree on every
## query.
##
## Synchronous semantics:
##   NavigationServer3D.map_get_path() in Godot 4 returns a PackedVector3Array
##   immediately (no callback). For our flat-terrain MVP this is fine —
##   navmesh queries on a 256m flat plane are cheap. If later phases need
##   async pathfinding (large open-world maps, hundreds of units), we can
##   move to NavigationAgent3D.target_reached signal-driven flow without
##   changing the IPathScheduler interface.
##
## State table:
##   We mirror MockPathScheduler's request bookkeeping so tests that swap in
##   the production scheduler behave identically — request_id is positive,
##   poll_path returns READY/FAILED/CANCELLED with waypoints. Synchronously-
##   resolved requests skip PENDING entirely; they go straight to READY (or
##   FAILED if NavigationServer3D returns an empty path).
##
## Determinism note:
##   NavigationServer3D pathfinding is deterministic on a fixed navmesh —
##   the navmesh is baked once at scene-load and never re-baked at runtime
##   (per RESOURCE_NODE_CONTRACT.md §3.2). Same map + same from + same to
##   = same waypoints across runs. This is what lets headless tests and
##   live runs share results.
##
## Path-string base class (extends "res://scripts/core/path_scheduler.gd"):
##   Same project-wide convention as MockPathScheduler — avoids the
##   class_name registry race that bites RefCounted-based scripts loaded
##   by GUT collectors. Functionally equivalent to extends IPathScheduler.

class_name NavigationAgentPathScheduler


# Per-request bookkeeping. Key = request_id; value = Dictionary with the
# resolution state and waypoints we computed at request time.
var _requests: Dictionary = {}

# Monotonic request id counter. Starts at 1 (0 reserved for "no request").
var _next_id: int = 1

# Cached reference to the navigation map RID. Resolved lazily on first
# request from the SceneTree's main viewport's World3D.navigation_map.
# Tests can override by writing _map_rid_override.
var _map_rid_override: RID = RID()


# === IPathScheduler implementation ==========================================

func request_repath(unit_id: int, from: Vector3, to: Vector3, priority: int) -> int:
	var rid: int = _next_id
	_next_id += 1

	var map_rid: RID = _resolve_map_rid()
	var waypoints: PackedVector3Array = PackedVector3Array()
	var state: int = PathState.FAILED

	if not map_rid.is_valid():
		# No active navigation map (e.g., headless test without a scene).
		# Mark as FAILED so the consumer can fall back or retry.
		push_warning(
			"NavigationAgentPathScheduler: no active navigation map; "
			+ "request from unit %d (%s -> %s, priority=%d) FAILED"
			% [unit_id, from, to, priority]
		)
	else:
		# Synchronous query. The 4th param (true) is `optimize` — collapses
		# colinear segments. We set it true since flat-terrain paths often
		# resolve to a straight line of just two waypoints; the optimizer
		# preserves this naturally.
		waypoints = NavigationServer3D.map_get_path(map_rid, from, to, true)
		if waypoints.size() >= 2:
			state = PathState.READY
		else:
			# An empty (or degenerate single-point) result means the
			# NavigationServer couldn't connect from→to on the baked mesh.
			state = PathState.FAILED

	_requests[rid] = {
		"unit_id": unit_id,
		"from": from,
		"to": to,
		"priority": priority,
		"requested_tick": SimClock.tick,
		"state": state,
		"waypoints": waypoints,
	}
	return rid


func poll_path(request_id: int) -> Dictionary:
	if not _requests.has(request_id):
		return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}
	var entry: Dictionary = _requests[request_id]
	var state: int = int(entry.state)
	if state == PathState.CANCELLED:
		return {"state": PathState.CANCELLED, "waypoints": PackedVector3Array()}
	if state == PathState.FAILED:
		return {"state": PathState.FAILED, "waypoints": PackedVector3Array()}
	# READY (synchronous query).
	return {"state": state, "waypoints": entry.waypoints}


func cancel_repath(request_id: int) -> void:
	if not _requests.has(request_id):
		return
	var entry: Dictionary = _requests[request_id]
	# Sticky semantics: only PENDING (none in this implementation) or READY
	# transitions to CANCELLED. FAILED stays FAILED — caller already
	# observed it; cancel is a no-op there.
	if int(entry.state) == PathState.READY:
		entry.state = PathState.CANCELLED
		entry.waypoints = PackedVector3Array()


# === Test/diagnostic helpers ================================================

## Override the navigation map RID for tests that don't have a live scene
## tree. Pass an empty RID() to revert to auto-detection.
func set_map_rid_override(rid: RID) -> void:
	_map_rid_override = rid


## Reset internal state. Mirrors MockPathScheduler.clear_log so the two
## schedulers have a parallel teardown surface for harness reuse.
func clear_log() -> void:
	_requests.clear()
	_next_id = 1


# === Internal ===============================================================

func _resolve_map_rid() -> RID:
	if _map_rid_override.is_valid():
		return _map_rid_override
	# Resolve the active navigation map from the main loop's scene tree.
	# Engine.get_main_loop() returns SceneTree (or null in pure-script
	# headless contexts without a scene). Defensive against both.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return RID()
	var root: Window = tree.root
	if root == null:
		return RID()
	# World3D's navigation_map is the default map for any 3D node in the
	# scene tree under that viewport. Per Godot 4 navigation docs.
	var world: World3D = root.world_3d
	if world == null:
		return RID()
	return world.navigation_map
