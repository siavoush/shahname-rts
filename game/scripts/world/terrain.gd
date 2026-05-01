extends NavigationRegion3D
##
## Terrain — the 256×256 flat ground plane for the MVP battle map.
##
## Phase 0 placeholder. Per CLAUDE.md placeholder policy: flat colored plane
## with a checkerboard shader as a reference texture so the camera has visual
## scale feedback. No real terrain art until the design chat green-lights it
## (won't happen until the MVP loop is fun as boxes).
##
## Map design: "inspired by the plains of Khorasan" per 00_SHAHNAMEH_RESEARCH.md §6.
## That context belongs to Phase 7 (Khorasan map). Phase 0 ships the simplest
## terrain that proves the navmesh, the map size, and the camera bounds work.
## Per Manifesto Principle 4 (Lean Iteration): smallest thing that produces
## real data.
##
## NavigationRegion3D strategy (locked per RESOURCE_NODE_CONTRACT.md §3.2):
##   - Bake the navmesh ONCE at scene-load (_ready).
##   - Buildings add NavigationObstacle3D children at placement time.
##   - NavigationObstacle3D shapes carve the navmesh dynamically — no rebake.
##   - No runtime call to bake_navigation_mesh() after _ready.
##   - This is the only sanctioned bake point (lint rule from session 2 retro).
##
## Map size: Constants.MAP_SIZE_WORLD = 256.0 world units (XZ plane, Y=0).
## Per 02_IMPLEMENTATION_PLAN.md Phase 0 convergence checkpoint. The constant
## is the single source of truth — this script reads it so resizing is a
## one-line Constants change.


func _ready() -> void:
	_configure_navmesh()
	_bake_navmesh()


## Configure the NavigationMesh parameters from Constants before baking.
## Called once in _ready, before the bake.
func _configure_navmesh() -> void:
	if navigation_mesh == null:
		push_error("Terrain: NavigationRegion3D has no NavigationMesh resource assigned.")
		return

	# Agent radius — minimum clearance the baker requires around obstacles.
	# 0.5 world units: clears infantry (smallest mobile unit). Larger units
	# will pathfind on the same mesh. Per Constants.NAV_AGENT_RADIUS.
	navigation_mesh.agent_radius = Constants.NAV_AGENT_RADIUS

	# Cell size for the navmesh voxelizer. Smaller = more accurate but slower.
	# 0.5 matches the agent radius for MVP (cheap bake on the flat plane).
	navigation_mesh.cell_size = 0.25

	# Geometry parse mode: use static physics colliders (BoxShape3D on the
	# StaticBody3D) rather than MeshInstance3D geometry. This avoids a
	# GPU readback on the PlaneMesh (which would stall rendering) and keeps
	# the bake fully on the CPU — correct for both editor and headless runs.
	# The StaticBody3D + CollisionShape3D (BoxShape3D 256×0.1×256) provides
	# the walkable surface shape the NavServer needs.
	navigation_mesh.geometry_parsed_geometry_type = (
		NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	)

	# The navmesh bake covers the full map extent.
	# We specify a filter AABB so the baker doesn't try to walk off the edge.
	var half: float = Constants.MAP_SIZE_WORLD * 0.5
	navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-half, -1.0, -half),
		Vector3(Constants.MAP_SIZE_WORLD, 2.0, Constants.MAP_SIZE_WORLD)
	)
	navigation_mesh.filter_baking_aabb_offset = Vector3.ZERO


## Bake the navmesh synchronously at scene-load.
## This is the ONLY place bake_navigation_mesh() is called in this project.
## Runtime rebake is forbidden per the session-2 lint rule and
## RESOURCE_NODE_CONTRACT.md §3.2. Buildings use NavigationObstacle3D
## dynamic carving instead.
func _bake_navmesh() -> void:
	if navigation_mesh == null:
		push_error("Terrain: cannot bake — no NavigationMesh resource.")
		return
	bake_navigation_mesh(false)  # false = synchronous (not on thread)
