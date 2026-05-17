extends Node3D
##
## Building — abstract base for player- and AI-placed structures.
##
## Per Phase 3 session 1 wave 1C kickoff (02f_PHASE_3_KICKOFF.md §3) +
## 01_CORE_MECHANICS.md §5 (building roster).
##
## Wave 1C ships Khaneh as the first concrete subclass; session 2+ adds
## Mazra'eh, Ma'dan, Sarbaz-khaneh, Atashkadeh. The abstract-base-then-
## concrete-scene pattern mirrors ResourceNode → MineNode (Phase 3 wave 1A)
## — the same template the gather-loop deliverable proved out.
##
## What this base class DOES:
##   - Pins the field schema (kind, team, unit_id, is_complete) every
##     subclass exposes.
##   - Owns the placement seam: place_at(world_pos, team, placer_unit_id)
##     sets position + team, marks is_complete = true, and (in concrete
##     subclasses' _on_placement_complete hook) bumps population_cap /
##     emits building_placed / etc.
##   - Adds itself to the &"buildings" SceneTree group so consumers
##     (UI, AI, future production system) can iterate buildings without
##     walking the world subtree.
##
## What this base class does NOT do:
##   - Visuals (mesh, material) — subclass scenes own those.
##   - NavigationObstacle3D — added at the subclass scene level per
##     RESOURCE_NODE_CONTRACT §3.2 (the runtime navmesh-carve seam — we
##     attach the obstacle here at placement time, not via a navmesh
##     rebake which §3.2 forbids).
##   - Resource deduction — UnitState_Constructing's on-arrival step
##     deducts via ResourceSystem.change_resource. The Building itself
##     doesn't reach into the economy.
##   - Construction-in-progress visuals — Phase 3 session 1 wave 1C ships
##     INSTANT placement (Khaneh appears the tick the worker arrives).
##     Session 2 adds the progress-bar / in-progress mesh / partial-HP
##     state alongside the proper construction timer.
##
## Why extend Node3D directly (not SimNode):
##   Same rationale as ResourceNode: the Building lives in the world and
##   must expose global_position to consumers (workers pathing around it,
##   selection raycasts hitting it). SimNode is extends Node — losing the
##   Node3D surface would force every consumer through a parent-walk.
##
##   The on-tick discipline still applies — every mutation of is_complete /
##   the population_cap bump / the building_placed emit happens from inside
##   UnitState_Constructing._sim_tick (the worker's _sim_tick). So we're
##   on-tick by construction; the SimNode assert would just be belt-and-
##   braces. Same compromise as MineNode (see resource_node.gd header).
##
## Why extend by path-string (not class_name on the base):
##   Same class_name registry race that bites Unit / Kargar / ResourceNode
##   — subclass scenes parsed at scene-tree warm-up may run before the
##   Building class_name is in the global registry. Path-string extends
##   sidesteps the race entirely. Khaneh / future concrete buildings
##   extend by path-string too.
##
## Source: 01_CORE_MECHANICS.md §5 (building list); CLAUDE.md "colored
## rectangles for buildings with floating text labels" placeholder rule.
##
## Cross-faction caveat (shahnameh-loremaster review 2026-05-14):
##   The current concrete subclass (Khaneh) is shaped around the Iranian
##   side of the Iran-Turan opposition: settled household, population
##   cap as "people-of-the-land grown into soldier-supply." The
##   abstract seam itself (place_at + _on_placement_complete hook) is
##   faction-neutral — a Turan-side analogue (steppe-tent / yurt:
##   *otaq* or *khargah*, both Shahnameh-attested) can plug into the
##   same hook and bump pop-cap identically. But the cultural-rationale
##   header block IS Iran-coded for now (see khaneh.gd). When the first
##   Turan building ships (Phase 3 session 2 / Phase 4), it MUST carry
##   a parallel substantive cultural-note block — per
##   00_SHAHNAMEH_RESEARCH.md §7's "design Turan as worthy rivals, not
##   cartoon villains" rule. Suggested Turan-side referents: Piran's
##   hospitality of Siavush, Manijeh's palace, Afrasiyab's court scenes
##   (NOT Afrasiyab himself — he's the antagonist; the Turan-people
##   dignity comes from Piran / Manijeh / the otaq tradition). Flagged
##   for whoever owns Turan-side building work in the upcoming sessions.

# === Signals =================================================================

## Emitted by UnitState_Constructing._sim_tick on every dwell tick during
## construction to drive the progress-bar UI (Track 2A) and any future
## telemetry consumer.
##
## percent_x100 ∈ [0, 10000] — basis-point encoding per project convention
## (multiplied by 100 so integer math carries two decimal places of
## precision without floating-point). Value formula:
##   percent_x100 = total_ticks_elapsed × 10000 / total_construction_ticks
##
## Emitter contract (load-bearing, per Track 2A / Track 1 coordination):
##   - Emitted DURING the dwell phase only: from the first post-arrival
##     tick through the last tick before placement fires.
##   - Does NOT emit at completion. The placement event is signalled by
##     _on_placement_complete firing (and EventBus.building_placed
##     propagating), which is semantically distinct from progress.
##     Emitting at percent_x100 = 10000 before the completion hook fires
##     would create a race with consumers that expect the building to be
##     is_complete when they read progress = 100%. The no-double-emit rule
##     is the contract: progress and completion are separate signals.
##   - Emitted from inside SimClock's tick (UnitState_Constructing is a
##     _sim_tick caller) — consumers must treat this as an on-tick signal
##     and defer any physics/spatial mutations accordingly.
##   - The emitter (UnitState_Constructing, Track 1 scope) holds a
##     reference to the Building node via _perform_placement's building
##     local. Consumer (ui-developer's Track 2A progress bar) connects in
##     the UI layer; no connection is established in Building itself.
##
## Wave 1C note: Track 1 (gp-sys) wires the emit call site; this signal
## declaration is Track 2B's deliverable. The signal name and int signature
## are load-bearing — any rename requires coordinating with gp-sys + ui-dev.
signal construction_progress_updated(percent_x100: int)


# === Schema fields ===========================================================

## Building kind. Subclass sets in _init AND _ready (dual-init pattern per
## kargar.gd's header — scene defaults clobber _init values between _init
## and _ready, so both setters are required for scene-loaded instances).
## Examples: &"khaneh", &"mazraeh", &"atashkadeh".
@export var kind: StringName = &""

## Owning team (Constants.TEAM_IRAN / TEAM_TURAN). Set by the placement
## flow (UnitState_Constructing reads the placing worker's team and
## propagates it). TEAM_NEUTRAL is the default — a neutral building is
## a bug condition (every placed building has a team).
@export var team: int = Constants.TEAM_NEUTRAL

## Identity assigned at placement from a static counter. Distinct namespace
## from Unit.unit_id — buildings are buildings, units are units, and a
## future telemetry sink will demultiplex on signal name + type, not on
## a shared id pool.
##
## Note: the EventBus.building_placed signal carries the PLACING WORKER's
## unit_id (per the signal's field doc) — that's a different number from
## this `unit_id` field on the Building itself. Workers and Buildings each
## have their own monotonic id counter. The signal payload reflects the
## causation chain (which worker did this), not the building's identity.
## If a future consumer needs the building's own id, expose it then.
var unit_id: int = -1

## False during construction-in-progress, true once placement is finalized.
## Session 1 wave 1C: instant — flips to true at the same tick the worker
## arrives. Session 2's in-progress state will leave this false until the
## construction timer expires, with HP scaling up alongside it.
var is_complete: bool = false


# === Static unit_id counter (Building's own, separate from Unit's) ==========

static var _next_building_id: int = 1


## Reset the Building unit_id counter. Called at match start by MatchHarness
## and the live boot path so the first placed building is always #1 for
## deterministic replay/snapshot comparison.
static func reset_id_counter() -> void:
	_next_building_id = 1


# === Lifecycle ==============================================================

func _ready() -> void:
	# Assign a fresh building id from the static counter if not already
	# set (tests may pin a known id pre-_ready for fixture determinism).
	if unit_id == -1:
		unit_id = _next_building_id
		_next_building_id += 1

	# Join the &"buildings" group so consumers (AI, UI, telemetry) can
	# iterate without walking the world subtree. Mirror of how units join
	# implicit groups via SpatialAgentComponent registration.
	add_to_group(&"buildings")


# === Placement API ==========================================================

## place_at — finalize this building's placement at a world position.
##
## Called by UnitState_Constructing's on-arrival step (Phase 3 session 1
## wave 1C). The state instantiates the Building scene, adds it as a
## child of the world Node, then calls this method to:
##   1. Set global_position.
##   2. Set team to the placing worker's team.
##   3. Flip is_complete to true.
##   4. Fire _on_placement_complete (subclass hook) — Khaneh uses this to
##      bump ResourceSystem.population_cap; future buildings use it for
##      their own placement side-effects (Atashkadeh starts emitting Farr,
##      Mazra'eh registers a gathering target with ResourceSystem, etc.).
##
## Why a method (not just direct field writes from the state)? The
## placement step is the building's lifecycle pivot — concentrating it
## in one method gives every subclass one hook (_on_placement_complete)
## to override, instead of every caller knowing about every side-effect.
## Mirrors ResourceNode.complete_extract's "hook for subclass cleanup"
## pattern.
##
## placer_unit_id is the Kargar's unit_id (Unit.unit_id). Passed through
## to _on_placement_complete so subclasses that emit signals (Khaneh →
## EventBus.building_placed) carry the attribution.
##
## Pre-condition: the Building has been added to the scene tree (so _ready
## has run and unit_id is assigned). The caller (the construction state)
## guarantees this — instantiate → add_child → place_at.
##
## Sanctioned-write context: this method is called from inside
## UnitState_Constructing._sim_tick, which is the worker's _sim_tick.
## On-tick by construction; same shape as ResourceNode.complete_extract.
func place_at(world_pos: Vector3, owner_team: int, placer_unit_id: int) -> void:
	global_position = world_pos
	team = owner_team
	is_complete = true
	_on_placement_complete(placer_unit_id)


# === Subclass hooks ==========================================================

## Called from inside place_at after the building's position / team /
## is_complete have been set. Subclasses override to add concrete
## side-effects:
##   - Khaneh: bump ResourceSystem.population_cap + emit building_placed.
##   - Mazra'eh (session 2+): register as a Grain gather target.
##   - Atashkadeh (session 2+): start emitting Farr per tick.
##
## Base class is a no-op so a subclass with NO post-placement side-effect
## (a future decorative building, perhaps?) needs no override.
##
## placer_unit_id is the Kargar's id, forwarded for telemetry symmetry
## with apply_farr_change / change_resource's source_unit pattern.
func _on_placement_complete(_placer_unit_id: int) -> void:
	pass


# === Footprint API ===========================================================
#
# Phase 3 session 2 wave 1A — cross-wave deliverable for Room B's
# FOG_DATA_CONTRACT.md v1.3.0 §3.2. FogSystem (wave 3A) consumes this method
# to compute building visibility footprints in fog cells without reaching
# into per-scene CollisionShape3D paths. Centralizing the footprint contract
# on the Building base lets each subclass override for non-rectangular cases
# while the default (BoxMesh / BoxShape3D) covers Khaneh, Mazra'eh,
# Sarbaz-khaneh, Atashkadeh at MVP scale.
#
# The 8m × 0 × 8m fallback (= 2 × FOG_CELL_SIZE on a 4m fog grid) handles
# the wave-ordering edge case where a Building instance is queried before a
# scene-level mesh/shape is wired up. FogSystem's per-tick cost on a 2×2
# cell footprint is still O(1) per source, so the fallback is non-catastrophic.

## Fog-cell fallback constant. Per FOG_DATA_CONTRACT v1.3.0 §1.1, the fog
## grid uses 4m cells; the fallback is 2×2 cells = 8m on a side. Hardcoded
## here rather than read from FogConfig because the constant is
## documentation-of-intent — a Building's "I have no mesh" fallback should
## not depend on whether the fog autoload has loaded. When FogConfig ships
## in wave 3A, world-builder may switch this to read from BalanceData;
## that's a one-line follow-up and not a wave-1A concern.
const _FOOTPRINT_FALLBACK_SIZE_M: float = 8.0


## Returns the building's world-aligned footprint AABB.
##
## Used by FogSystem (wave 3A) to compute the cells a building reveals when
## visible. The AABB position is the min-corner in world coordinates; size
## is the extent. Y is included for completeness but consumers (fog) ignore
## it — visibility is XZ-only.
##
## Default implementation: scan for a MeshInstance3D child, take its
## local-space AABB, translate by the mesh's transform + the building's
## global_position. Covers the Phase 3 Building subtree shape (see
## scenes/world/buildings/building.tscn): root Node3D → MeshInstance3D
## with a BoxMesh sized to the building's silhouette. Concrete subclasses
## that ship the standard mesh layout get correct footprints for free.
##
## Fallback: if no MeshInstance3D is found in the subtree, return an AABB
## sized _FOOTPRINT_FALLBACK_SIZE_M centered on global_position. Per
## FOG_DATA_CONTRACT v1.3.0 §3.2: "If wave 3A (FogSystem) ships before
## wave 1A (Mazra'eh + the method), FogSystem falls back to a 2×2 default
## per the base implementation's fallback clause." The fallback is also
## the right answer for hypothetical mesh-less Building instances (tests
## that .new() the script without instantiating a scene).
##
## Subclass override pattern: a future building with a non-box silhouette
## (e.g., L-shaped Sarbaz-khaneh barracks) overrides this to return a
## custom AABB based on its scene composition.
func get_footprint_aabb() -> AABB:
	var mesh: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		# Mesh local AABB → world AABB. The mesh node may carry a local
		# transform (the base scene Y-offsets the MeshInstance3D by 0.6 so
		# the mesh sits on top of the terrain plane). We compose the
		# mesh's local-relative transform with the building's global
		# transform to get the AABB in world space.
		var local_aabb: AABB = mesh.mesh.get_aabb()
		# Transform from the mesh's local space to world space.
		# mesh.global_transform converts mesh-local to world. Apply to
		# both corners; rebuild AABB from min/max.
		var world_xform: Transform3D = mesh.global_transform
		var world_aabb: AABB = world_xform * local_aabb
		# AABB may have negative size components if the transform is
		# unusual; AABB.abs() normalizes.
		return world_aabb.abs()
	# Fallback: 8m × 0 × 8m centered on global_position. Y size = 0 keeps
	# the AABB "flat" for fog; fog ignores Y anyway, but emitting a 0-Y
	# size avoids carrying noise into downstream consumers.
	var half: float = _FOOTPRINT_FALLBACK_SIZE_M * 0.5
	return AABB(
		global_position - Vector3(half, 0.0, half),
		Vector3(_FOOTPRINT_FALLBACK_SIZE_M, 0.0, _FOOTPRINT_FALLBACK_SIZE_M),
	)
