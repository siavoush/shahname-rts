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
