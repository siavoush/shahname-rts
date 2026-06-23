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
##   - Owns the two-stage lifecycle seam (session 3 wave 1C):
##       Stage 1 — place_at(world_pos, team, placer_unit_id) runs on
##         the placement-finalization tick (sub-frame, the same tick the
##         worker reaches the build site). It sets position + team,
##         flips is_complete = true, fires _on_placement_complete.
##         This is the *structural* arrival of the building (visible,
##         click-targetable, navmesh-carved).
##       Stage 2 — _on_construction_complete(placer_unit_id) runs after
##         construction_ticks ticks elapse inside
##         UnitState_Constructing._sim_tick. This is the *operational*
##         arrival: the building begins functioning (Mazra'eh flips
##         is_gatherable, Ma'dan registers as an extraction modifier
##         on the adjacent mine, Atashkadeh would start emitting Farr).
##         The construction_finalized(placer_unit_id) signal emits
##         immediately after the virtual hook returns — that is the
##         externally-observable completion signal for UI / telemetry.
##     The two stages exist because a Khaneh now takes ~3s of dwell and
##     Mazra'eh / Ma'dan take ~20s. The structural placement happens
##     immediately on arrival so the player sees feedback (the building
##     footprint appears, the progress bar starts), but the building
##     does NOT yet function — workers cannot gather from a half-built
##     Mazra'eh, a half-built Ma'dan does not buff the adjacent mine.
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
##   - Construction-in-progress visuals — session 3 wave 1C ships the
##     construction timer + progress signal (consumed by the UI progress
##     bar Control). The in-progress mesh / partial-HP state remains out
##     of scope; the building's MeshInstance3D appears immediately at
##     placement, and the dwell progress is communicated via the
##     progress bar UI alone.
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


## Emitted by UnitState_Constructing._sim_tick immediately AFTER the
## _on_construction_complete virtual fires on this building — the
## externally-observable completion signal for the two-stage lifecycle.
##
## placer_unit_id is the Kargar.unit_id of the worker that built this
## building; matches the value passed to _on_construction_complete.
## May be -1 if the worker died mid-construction (forward-compat — the
## current Track 1 implementation tears down the construction state on
## death, so this signal does not fire in that path).
##
## Why this signal exists alongside the virtual hook (per ui-developer-p3s3
## integration brief, Task #139): the progress-bar UI Control needs an
## externally-observable hide-trigger. The available signals at Stage 2
## without this addition were:
##   - is_complete flips at Stage 1 (too early — the bar should still
##     show during construction).
##   - construction_progress_updated is clamped strictly below 10000
##     (the no-double-emit rule means progress never reaches 100%).
##   - _on_construction_complete is a virtual method, not a signal —
##     not observable from outside the building.
## So the UI overlay couldn't resolve a clean hide-trigger. This signal
## closes the gap: connect once at building_placed, disconnect on
## construction_finalized.
##
## Emitter contract (load-bearing, mirrors construction_progress_updated):
##   - Emitted exactly ONCE per built building, at Stage 2 (after the
##     virtual hook runs and operational side-effects have applied —
##     Mazra'eh.is_gatherable = true is visible to receivers).
##   - Emitted from inside UnitState_Constructing._sim_tick (on-tick by
##     construction). Consumers may mutate spatial/resource state without
##     an _is_ticking guard.
##   - Emit ORDERING: the virtual `_on_construction_complete` fires
##     FIRST, then this signal. Receivers see post-Stage-2 state on
##     readout (is_gatherable, registered modifiers, etc).
##   - No emit if construction is interrupted mid-dwell (worker killed,
##     player cancels). Same contract as construction_progress_updated:
##     interruption produces no completion signal.
##
## Why emit from UnitState_Constructing (not from base _on_construction_complete):
##   Mirroring construction_progress_updated's pattern keeps a single
##   driver (the construction state) for all externally-observable
##   lifecycle events. Subclass overrides (Mazra'eh, Ma'dan) currently do
##   not call super._on_construction_complete; forcing them to remember
##   `super.` to preserve a base-class emit is the kind of constraint
##   that catches nobody until a UI hide bug ships. The state-driven
##   emit fires unconditionally.
signal construction_finalized(placer_unit_id: int)


## Emitted on every state transition of the production state machine AND
## on every dwell-tick decrement while training. Drives the Track 2
## ProductionPanel UI (progress bar + remaining-time label) and any future
## telemetry / AI consumer.
##
## Wave 3A.6 Track 1 — first unit-production signal on the Building base.
##
## Payload:
##   - building_id: this building's unit_id (Building's own id space, distinct
##     from the worker's unit_id used in construction signals).
##   - state: &"idle" (no training) or &"training" (dwell in progress).
##   - unit_kind: the StringName of the unit being trained (e.g. &"piyade").
##     Empty StringName &"" when state == &"idle".
##   - progress_fraction: [0.0, 1.0] — how far through the dwell. 0.0 at
##     start of training, approaches 1.0 just before spawn, 0.0 again in
##     idle.
##
## Emit cadence:
##   - On request_train success → one emit with state=&"training", progress=0.0.
##   - On every dwell tick → one emit with updated progress.
##   - On spawn-complete → one emit with state=&"idle", unit_kind=&"", progress=0.0.
##   - On request_train failure (insufficient resources, pop full, already
##     training): NO emit — the rejection is communicated via the bool return
##     of request_train, not the signal.
##
## Emit context: from inside the EventBus.sim_phase &"movement" handler,
## i.e. on-tick (mirrors UnitState_Constructing's on-tick emit discipline
## for construction_progress_updated). Consumers may mutate spatial /
## resource state without an _is_ticking guard.
signal production_state_changed(
	building_id: int,
	state: StringName,
	unit_kind: StringName,
	progress_fraction: float)


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


# === Production schema (wave 3A.6) ==========================================
#
# Per 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 1.
#
# `produces` is the producer-building schema: the list of unit kinds this
# building can train. Empty array = non-producer (Khaneh, Mazra'eh, Ma'dan,
# Atashkadeh — they exist but cannot train units). Subclasses override
# in _init AND _ready (dual-init pattern per kargar.gd / khaneh.gd /
# sarbaz_khaneh.gd headers — scene defaults clobber _init writes between
# _init and _ready, so both setters are required).
#
# Iran Tier-1 + Tier-2 mapping (wave 3A.6 scope):
#   - Sarbaz-khaneh: [&"piyade"]
#   - Sowari-khaneh: [&"savar"]  (NOT [&"savar", &"asb_savar_kamandar"] —
#                                  AsbSavarKamandar production deferred per
#                                  kickoff §1.)
#   - Tirandazi: [&"kamandar"]
#
# Future Tier-2 / post-MVP additions (e.g. Throne → Kargar) extend this
# pattern without touching the base API.

## List of unit kinds this building can produce. Empty = non-producer.
## Set by subclasses in _init AND _ready (dual-init).
@export var produces: Array[StringName] = []

## Internal production state machine state. &"idle" (no training in progress)
## or &"training" (a unit is currently being trained — dwell decrement
## active). Single-slot for MVP — see kickoff §1 ("Train queue depth > 1"
## explicitly deferred).
var _production_state: StringName = &"idle"

## The kind of unit currently being trained. Empty StringName when idle.
## Used at spawn time to look up the scene path + at signal emit time to
## tell UI consumers what's training.
var _production_unit: StringName = &""

## Dwell countdown — initialized to train_<unit>_dwell_ticks at
## request_train, decrements once per &"movement" sim_phase tick, spawn
## fires when this reaches 0.
var _production_progress_ticks: int = 0

## Total dwell ticks for the current training — captured at request_train
## time so the progress_fraction calculation has a stable denominator
## (mirrors UnitState_Constructing._total_construction_ticks).
var _production_total_ticks: int = 0

# UI-queued train request (off-tick buffer). The train button fires during
# input handling (off-tick), but request_train's resource deduction must run
# on-tick (ResourceSystem.change_resource asserts on-tick). So the button sets
# this and _on_sim_phase commits it on the next &"movement" phase. Empty when
# nothing is queued. NOT part of the determinism snapshot — it is a player-input
# buffer, written only off-tick by the UI; the deterministic commit is on-tick.
# Fixes the "free units" bug (training never charged) — playtest 2026-06-22.
var _pending_train_request: StringName = &""

## Team-side rally-point offset along the Z axis, in metres. Iran spawns
## south of its buildings (+Z); Turan spawns north (-Z) — opposing flow.
## The fixed magnitude is FOOTPRINT_HALF_Z + 2.0m by default; subclasses
## may override _rally_offset() for non-default footprints.
const _RALLY_OFFSET_MAGNITUDE: float = 2.0


# === Unit scene table (production spawn) ====================================
#
# Per kickoff §4 Track 1: spawn integration "reuse main.gd:_spawn_unit
# pattern OR add MatchSystem.spawn_trained_unit autoload — simplest path."
#
# Decision: inline preload table on the Building base, mirroring
# unit_state_constructing.gd's _BUILDING_SCENE_PATHS pattern. Production
# spawns happen from Building._spawn_trained_unit (below); centralizing
# the per-kind scene lookup here keeps the Building producer-side
# self-contained, avoids a new autoload, and matches the pattern the
# project already uses elsewhere.
#
# Per CLAUDE.md: each entry is a per-kind unit scene path. Iran units only
# for the 3 wave-3A.6 pairs (the production system is symmetric; Wave 3B's
# DummyAI will exercise the Turan side). Turan-mirror entries ship now so
# the Wave 3B handoff is a no-op.
const _UNIT_SCENE_PATHS: Dictionary = {
	&"piyade": "res://scenes/units/piyade.tscn",
	&"savar": "res://scenes/units/savar.tscn",
	&"kamandar": "res://scenes/units/kamandar.tscn",
	# Turan mirrors — wired now so Wave 3B can drive Turan production
	# without touching this table again. Per kickoff §1 the production
	# system is symmetric; only the AI driver differs.
	&"turan_piyade": "res://scenes/units/turan_piyade.tscn",
	&"turan_savar": "res://scenes/units/turan_savar.tscn",
	&"turan_kamandar": "res://scenes/units/turan_kamandar.tscn",
}


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

	# Wave 3A.6 Track 1 — subscribe to the &"movement" sim_phase so the
	# production state machine can decrement its dwell counter on-tick.
	# Same pattern Unit uses (unit.gd:362-363): each Building hooks the
	# phase directly until a central BuildingSystem coordinator ships
	# (LATER). For non-producer buildings (empty `produces`) the handler
	# early-bails — the connection cost is one signal per building, tiny.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)

	# Wave 3-BuildingDestructibility (session 9) — every building gets HP
	# + a local-signal subscription per BUG-G1 fix-pattern. Throne's
	# implementation (factored from throne.gd:393-435) promoted to base
	# per architecture-reviewer C4.4 — all 8 subclasses inherit; only
	# _on_health_zero is subclass-specific.
	_init_health_from_balance_data()


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
	# §9.M6 — log the team transition + placement. Building._ready fires
	# with team=TEAM_NEUTRAL (default); place_at is when the building
	# transitions to its owning team. Pre-this-log, this transition was
	# invisible, which masked partial-state buildings (worker interrupted
	# mid-construction → place_at never runs → team stays at 0 → AI
	# targeting filters reject it).
	print("[%s] place_at team=%d position=%s placer_unit_id=%d is_complete=true" % [
		str(kind), team, str(world_pos), placer_unit_id])
	_on_placement_complete(placer_unit_id)


# === Subclass hooks ==========================================================

## Called from inside place_at — Stage 1 of the two-stage lifecycle.
## Fires on the placement-finalization tick (sub-frame, the same tick
## the worker reaches the build site), after the building's position /
## team / is_complete have been written. Subclasses override for
## *structural* side-effects — things that should happen as soon as
## the building exists in the world even though it is not yet
## operational:
##   - Khaneh: bump ResourceSystem.population_cap + emit building_placed.
##     (Khaneh keeps its activation here because population-cap is a
##     resource-system invariant, not a gameplay-functional one.)
##   - Mazra'eh: register with ResourceSystem.register_node, fog vision.
##     The gatherable flip (is_gatherable = true) moves to Stage 2.
##   - Ma'dan: emit building_placed, register fog vision. The mine
##     modifier registration moves to Stage 2.
##
## Base class implementation: trigger an explicit synchronous navmesh
## rebake using the Godot 4.6 source-geometry pipeline if this building
## has a NavigationObstacle3D child.
##
## Wave 1D fix for L25 (Task #149) — supersedes the v0.1.0-rc.1 spike's
## convenience-wrapper approach (Task #144 `region.bake_navigation_mesh(false)`
## shipped at 910bd9a). Root cause validated against Godot 4.6 source:
## `NavigationRegion3D::bake_navigation_mesh()` (the convenience wrapper)
## HARDCODES `this` as the parse-root passed to
## `NavigationServer3D::parse_source_geometry_data()`. Combined with
## `nav_mesh_generator_3d.cpp:236-255` showing `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`
## uses the passed-in p_root_node as-is (not escalated to `get_tree().root`),
## the convenience wrapper can never see sibling-of-Terrain buildings — they
## live under `&World` in the scene tree (per `unit_state_constructing.gd:
## _resolve_placement_parent`), not under Terrain. The explicit pipeline
## below passes `get_tree().root` as the parse-root, walking the whole tree.
##
## See `docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0 §0.1 for the four-round
## archaeology that led to this fix, and `docs/RESOURCE_NODE_CONTRACT.md`
## §3.2 v1.4.0 for the canonical pipeline contract.
##
## Subclasses that override MUST call super._on_placement_complete(placer_unit_id)
## to preserve the rebake. Khaneh, Mazra'eh, Ma'dan all call super as the
## first line of their override.
##
## placer_unit_id is the Kargar's id, forwarded for telemetry symmetry
## with apply_farr_change / change_resource's source_unit pattern.
func _on_placement_complete(_placer_unit_id: int) -> void:
	var nav: NavigationObstacle3D = find_child(
		"NavigationObstacle3D", false, false) as NavigationObstacle3D
	if nav == null:
		return  # Mazra'eh and other walkable buildings have no obstacle — skip.
	var region: NavigationRegion3D = _resolve_terrain_region()
	if region == null:
		push_warning("Building._on_placement_complete: no NavigationRegion3D "
			+ "found in scene tree; navmesh rebake skipped for %s" % name)
		return
	# Explicit 4-call pipeline. Sync via bake_from_source_geometry_data
	# (not _async) — deterministic, sim-tick safe (Sim Contract §1.6).
	var source: NavigationMeshSourceGeometryData3D = (
		NavigationMeshSourceGeometryData3D.new())
	NavigationServer3D.parse_source_geometry_data(
		region.navigation_mesh, source, get_tree().root)
	NavigationServer3D.bake_from_source_geometry_data(
		region.navigation_mesh, source)


## Walk get_tree().root looking for the first NavigationRegion3D.
## The MVP scene has exactly one (terrain.tscn root). Returns null if
## none found — callers push_warning and skip the rebake gracefully.
## MVP assumes a single NavigationRegion3D in the scene. Multi-region maps
## would require region-by-position lookup; revisit when that need surfaces.
func _resolve_terrain_region() -> NavigationRegion3D:
	return _find_nav_region(get_tree().root)


func _find_nav_region(node: Node) -> NavigationRegion3D:
	if node is NavigationRegion3D:
		return node as NavigationRegion3D
	for child in node.get_children():
		var found: NavigationRegion3D = _find_nav_region(child)
		if found != null:
			return found
	return null


## Called from UnitState_Constructing._sim_tick after construction_ticks
## ticks have elapsed since the worker's arrival at the build site —
## Stage 2 of the two-stage lifecycle.
##
## Lifecycle sequence:
##   place_at (Stage 1)                    ← structural arrival
##       → _on_placement_complete (sub-frame, same tick)
##   ...construction_ticks ticks elapse...
##   _on_construction_complete (Stage 2)   ← operational arrival
##       → construction_finalized signal emits (externally-observable)
##
## Subclasses override for *operational* side-effects — things gated on
## the construction timer completing so the building cannot function
## while it is half-built:
##   - Mazra'eh: flip is_gatherable = true (workers may now gather).
##   - Ma'dan: register as the adjacent MineNode's extraction modifier
##     (the buff applies from this tick onward).
##   - Atashkadeh (future): start emitting passive Farr per tick.
##   - Sarbaz-khaneh (future): become eligible as a production target.
##
## Base class is a no-op. Khaneh does not override (its only side-effect
## — the pop-cap bump — runs at Stage 1; a half-built Khaneh has no
## operational dimension to gate).
##
## placer_unit_id is the Kargar's id of the worker that built this. May
## be -1 if the worker died mid-construction (forward-compat — the
## current Track 1 implementation tears down the construction state on
## death, so this hook does not fire in that path, but the field is
## permitted for symmetry with _on_placement_complete).
##
## Called from inside UnitState_Constructing._sim_tick (the worker's
## _sim_tick). On-tick by construction; consumers can mutate spatial /
## resource state without an _is_ticking guard.
func _on_construction_complete(_placer_unit_id: int) -> void:
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


# === Production state machine (wave 3A.6) ===================================
#
# Per 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 1.
#
# Public API: request_train(unit_kind: StringName) -> bool. Called by UI
# (ProductionPanel button click — Track 2) or AI (Wave 3B DummyAI). On
# success: deducts coin+grain atomically, enters &"training" state,
# kicks off the dwell countdown. On failure: returns false WITHOUT
# mutating any state — the caller is responsible for showing a deny tone.
#
# Per-tick driver: _on_sim_phase decrements the counter on every
# &"movement" phase. When it reaches zero, the trained unit spawns
# at the rally-point offset (south of Iran buildings, north of Turan),
# state returns to idle, and the production_state_changed signal fires
# one final time with state=&"idle".
#
# Single-slot for MVP: a second request_train while training is in
# progress returns false (deny). Multi-slot queue is a polish item
# explicitly deferred per kickoff §1.


## Public request to start training a unit at this building.
##
## Validation chain (ALL must pass for success):
##   1. produces.has(unit_kind) — this building can train this kind.
##   2. _production_state == &"idle" — not already training (single-slot).
##   3. ResourceSystem.coin_x100_for(team) >= cost_coin * 100.
##   4. ResourceSystem.grain_x100_for(team) >= cost_grain * 100.
##   5. ResourceSystem.population_for(team) < ResourceSystem.population_cap_for(team).
##   6. is_complete — the building has finished construction (Stage 2 over).
##   7. The kind must be in _UNIT_SCENE_PATHS — defensive against typos.
##
## On success: deducts both resources atomically (Sim Contract §1.3 — the
## two deductions happen inside one sim_phase tick, so they are atomic from
## the consumer's perspective even though they go through change_resource
## twice). Sets _production_state=&"training", _production_unit=unit_kind,
## reads dwell from BalanceData.buildings[<self.kind>].train_<unit>_dwell_ticks,
## emits production_state_changed.
##
## On failure: returns false WITHOUT mutating any state. No signal emit;
## the caller must communicate the rejection (deny tone, tooltip).
##
## Returns true on success, false on any validation failure.
##
## Sanctioned-write context: this method MUST be called from inside a
## sim_phase handler (so the change_resource calls are on-tick). The
## ProductionPanel UI's button-click handler routes through a deferred
## call (Track 2's concern) — the timing is the caller's responsibility,
## not this method's.
func request_train(unit_kind: StringName) -> bool:
	# 1. Can this building train this kind?
	if not produces.has(unit_kind):
		return false
	# 6. Building must be operationally ready (construction complete).
	if not is_complete:
		return false
	# 2. Single-slot: refuse if already training.
	if _production_state != &"idle":
		return false
	# 7. Defensive: scene must be loadable for this kind.
	if not _UNIT_SCENE_PATHS.has(unit_kind):
		push_warning(
			"Building.request_train: unknown unit_kind '%s' "
			% unit_kind
			+ "(not in _UNIT_SCENE_PATHS) — denied")
		return false
	# 3 + 4. Affordability check — read costs from BalanceData via
	# canonical Dictionary lookup: BalanceData.buildings[<self.kind>].train_<unit>_cost_*
	# (BUG-C1 fix-wave: kickoff brief §3.4 incorrectly described a
	# `bldg_<kind>` top-level-field pattern that does not exist).
	var cost_coin: int = _resolve_train_cost(unit_kind, &"coin")
	var cost_grain: int = _resolve_train_cost(unit_kind, &"grain")
	if ResourceSystem.coin_x100_for(team) < cost_coin * 100:
		return false
	if ResourceSystem.grain_x100_for(team) < cost_grain * 100:
		return false
	# 5. Population cap check.
	if ResourceSystem.population_for(team) >= ResourceSystem.population_cap_for(team):
		return false
	# All checks passed — commit.
	# Atomic deduction: per Sim Contract §1.3 both change_resource calls
	# happen on this tick. If one were to fail mid-way (e.g. some future
	# clamp behavior), the second wouldn't have run. Today both succeed
	# unconditionally given the pre-check above.
	if cost_coin > 0:
		ResourceSystem.change_resource(
			team, Constants.KIND_COIN, -cost_coin * 100,
			&"unit_production_cost", self)
	if cost_grain > 0:
		ResourceSystem.change_resource(
			team, Constants.KIND_GRAIN, -cost_grain * 100,
			&"unit_production_cost", self)
	_production_state = &"training"
	_production_unit = unit_kind
	_production_total_ticks = _resolve_train_dwell_ticks(unit_kind)
	_production_progress_ticks = _production_total_ticks
	# Per signal contract: emit on transition with progress=0.0 at start.
	production_state_changed.emit(unit_id, _production_state, _production_unit, 0.0)
	return true


# Off-tick-safe train request — the player path. The train button fires during
# input handling, NOT on a sim tick, so we cannot deduct here (request_train ->
# ResourceSystem.change_resource asserts on-tick, resource_system.gd:207; an
# off-tick call silently skips the deduction = free units, playtest 2026-06-22).
# Instead buffer the kind and let _on_sim_phase commit it via request_train() on
# the next &"movement" phase (on-tick) — the player-path analogue of how build
# commands defer to the sim. AI callers stay on request_train() directly (they
# already run on-tick from the &"ai" phase). Returns false on the cheap off-tick
# reads (incomplete / already training / already queued); affordability is the
# authoritative on-tick re-check at commit time.
func queue_train(unit_kind: StringName) -> bool:
	if not is_complete:
		return false
	if _production_state != &"idle":
		return false
	if _pending_train_request != &"":
		return false
	_pending_train_request = unit_kind
	print("[building] train queued kind=%s unit_id=%d (commits next movement phase)"
		% [unit_kind, unit_id])
	return true


# Sim-phase handler. Drives the production state machine's dwell counter
# during the &"movement" phase only (same phase Unit uses for its FSM —
# unit.gd:391-396). Non-producer buildings (empty produces) early-bail.
#
# The &"movement" phase is the right home for production-tick decrement
# even though the work isn't "movement": there is no &"production" phase
# in SIM_CONTRACT, and adding one would require an engine-architect
# spike that is out of scope per kickoff §4 standby. The &"movement"
# phase runs once per tick after AI and before combat, so production
# decrement happens between AI-driven decisions and combat resolution —
# the right order for trained units to enter the world before any
# combat-phase consumer notices them.
func _on_sim_phase(phase: StringName, _tick: int) -> void:
	if phase != &"movement":
		return
	# Commit a UI-queued train request on-tick. The train button buffered it
	# off-tick (queue_train); request_train's deduction can only run on-tick.
	# Return after the attempt so a freshly-started dwell isn't decremented on
	# the same tick it began. Fixes the "free units" bug (playtest 2026-06-22).
	if _pending_train_request != &"":
		var requested: StringName = _pending_train_request
		_pending_train_request = &""
		var ok: bool = request_train(requested)
		print("[building] deferred train commit kind=%s ok=%s unit_id=%d"
			% [requested, ok, unit_id])
		return
	if _production_state != &"training":
		return
	_production_progress_ticks -= 1
	if _production_progress_ticks > 0:
		# Still dwelling — emit progress.
		var frac: float = 0.0
		if _production_total_ticks > 0:
			var elapsed: int = _production_total_ticks - _production_progress_ticks
			frac = float(elapsed) / float(_production_total_ticks)
		production_state_changed.emit(unit_id, _production_state, _production_unit, frac)
		return
	# Dwell complete — spawn the unit, transition back to idle.
	# Cache the kind before clearing state, since the signal emit at the
	# bottom carries &"idle" + &"".
	var spawned_kind: StringName = _production_unit
	_spawn_trained_unit(spawned_kind)
	_production_state = &"idle"
	_production_unit = &""
	_production_progress_ticks = 0
	_production_total_ticks = 0
	production_state_changed.emit(unit_id, _production_state, &"", 0.0)


# Disconnect from sim_phase on tree exit. Symmetric with the connect in
# _ready; freed buildings should not keep their handler subscribed.
func _exit_tree() -> void:
	if EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.disconnect(_on_sim_phase)


# Spawn the trained unit at this building's rally-point offset. The spawn
# pattern mirrors main.gd:_spawn_unit — instantiate the scene, set team +
# position BEFORE add_child (so the unit's _ready sees correct values when
# it mirrors team to SpatialAgentComponent and registers with FogSystem),
# then add to the world subtree.
#
# The world parent is the building's own parent: every Building is added
# to the &World node (per main.gd:_spawn_starting_resources pattern + the
# construction state's _resolve_placement_parent). Putting trained units
# under the same parent keeps the scene-tree shape consistent.
func _spawn_trained_unit(unit_kind: StringName) -> void:
	var path: String = _UNIT_SCENE_PATHS.get(unit_kind, "")
	if path == "":
		push_warning(
			"Building._spawn_trained_unit: no scene for kind '%s'" % unit_kind)
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning(
			"Building._spawn_trained_unit: failed to load scene at %s" % path)
		return
	var unit_node: Node3D = scene.instantiate() as Node3D
	if unit_node == null:
		push_warning(
			"Building._spawn_trained_unit: scene instantiate returned null "
			+ "for kind '%s'" % unit_kind)
		return
	# Set team + position BEFORE add_child so _ready sees correct values.
	unit_node.set(&"team", team)
	unit_node.position = _rally_point()
	# Use the building's own parent — typically &World. If the building
	# has no parent (test fixture), fall back to adding to self so the
	# unit at least enters a SceneTree for its _ready to fire.
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	parent.add_child(unit_node)


# Compute the rally-point offset in world coordinates. Iran spawns south
# of its buildings (+Z offset); Turan spawns north (-Z offset). The
# magnitude is FOOTPRINT_HALF_Z + _RALLY_OFFSET_MAGNITUDE so units don't
# spawn inside the building's footprint.
#
# Subclasses with non-default footprints may override _rally_offset() to
# tune the offset shape; the base implementation uses get_footprint_aabb's
# Z extent.
func _rally_point() -> Vector3:
	var aabb: AABB = get_footprint_aabb()
	var half_z: float = aabb.size.z * 0.5
	var z_offset: float = half_z + _RALLY_OFFSET_MAGNITUDE
	# Iran south (+Z), Turan north (-Z). Neutral defaults to south for
	# test-fixture sanity.
	if team == Constants.TEAM_TURAN:
		z_offset = -z_offset
	return global_position + Vector3(0.0, 0.0, z_offset)


# Read train cost from BalanceData (canonical Dictionary lookup):
#   BalanceData.buildings[<self.kind>].train_<unit_kind>_cost_<resource>
#
# resource is &"coin" or &"grain". Returns 0 if any step fails — the
# affordability check above will then succeed at zero cost (visibly-wrong
# fallback per §9.L9: "free units pop out instantly" is diagnosable).
#
# §9.H3 first-exercise: this is the first runtime read of the wave-3A.6
# BalanceData training schema fields. A typo'd field name would silently
# return 0; the Track 1 tests + Track 3's per-building test sweep catch
# this typo-bait surface.
func _resolve_train_cost(unit_kind: StringName, resource: StringName) -> int:
	var field_name: StringName = StringName(
		"train_" + String(unit_kind) + "_cost_" + String(resource))
	return _read_bldg_stats_int(field_name)


# Read dwell ticks from BalanceData (canonical Dictionary lookup):
#   BalanceData.buildings[<self.kind>].train_<unit_kind>_dwell_ticks
#
# Fallback to 90 (3s @ 30Hz, matches Khaneh construction_ticks fallback)
# when BalanceData / the entry / the field is missing. Per §9.L9: free
# units at zero dwell would be too disorienting to debug visually, so we
# fall back to a reasonable non-zero value instead.
func _resolve_train_dwell_ticks(unit_kind: StringName) -> int:
	var field_name: StringName = StringName(
		"train_" + String(unit_kind) + "_dwell_ticks")
	var v: int = _read_bldg_stats_int(field_name)
	if v <= 0:
		return 90  # ~3s @ 30Hz — visibly-slower-than-instant fallback.
	return v


# Generic helper to read an int field from
# BalanceData.buildings[<self.kind>]. Returns 0 on any defensive failure
# (file missing, BD null, dict missing/wrong-type, entry missing, field
# missing, type mismatch).
#
# Schema: BalanceData.buildings is a Dictionary keyed by kind StringName
# (NOT top-level `bldg_<kind>` fields). Matches the canonical pattern at
# unit_state_constructing.gd:519 _resolve_construction_ticks and
# production_panel.gd:_read_balance_int.
#
# BUG-C1 fix-wave history: initial Track 1 ship (ac0416d) used the
# wrong `bldg_<kind>` top-level-field pattern per the kickoff brief
# §3.4 prose — that field never existed on BalanceData, so every
# _resolve_train_cost / _resolve_train_dwell_ticks call silently fell
# through to 0 / 90-fallback. The user live-test caught it: training
# spawned units without deducting resources because cost=0 affordability
# checks (0 >= 0) passed trivially and `if cost_coin > 0` skipped the
# deduction. Fixed here to use the canonical Dictionary lookup.
func _read_bldg_stats_int(field_name: StringName) -> int:
	if kind == &"":
		return 0
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null or not (stats is Resource):
		return 0
	var v: Variant = (stats as Resource).get(field_name)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return 0
	return int(v)


# === HealthComponent integration (Wave 3-BuildingDestructibility) ===========
#
# Per brief v1.0.1 §3.1 + §6 (architecture-reviewer C4.3 + C4.4):
# factored from throne.gd:393-435 to base so all 8 building subclasses
# inherit the HealthComponent wiring + local-signal subscription. Only
# _on_health_zero is subclass-specific (per-building cleanup).
#
# **BUG-G1 fix-pattern (session-8 architecture-reviewer finding):**
# Buildings subscribe to their OWN HealthComponent.health_zero LOCAL
# signal, NOT the global EventBus.unit_health_zero channel. Buildings
# and Units have SEPARATE unit_id counters that collide in the same
# int space (Iran Throne unit_id=1 collides with Kargar #1 unit_id=1).
# The Unit-side global-filter pattern is safe within the Unit
# namespace; Buildings cannot use the same channel safely.
#
# **§9.D8/D10 cross-track diagnostic note:** the HealthComponent node
# is added to the base building.tscn (session 9 wave); subclasses
# inherit the node for free. Concrete subclasses do NOT need per-scene
# HealthComponent overrides.


## Latch so the destruction signal emits exactly once per building.
## Mirror of HealthComponent's _zero_emitted pattern at
## health_component.gd:74 — once destroyed, always destroyed.
## Subclass _on_health_zero overrides should check this before
## emitting the destruction signal.
var _destruction_emitted: bool = false


## Returns the building's HealthComponent child node, or null if the
## scene doesn't have one (test fixture / pre-Wave-3-BD scene).
## Duck-typed protocol match for combat_component.gd:195-199 —
## CombatComponent calls `target.get_health()` to check target validity
## and deal damage. Returning the HC node lets the combat path work
## with buildings (it doesn't differentiate Unit vs Building targets).
##
## **Untyped Node return** (not HealthComponent) to avoid hard
## class_name dependency at parse time — matches the unit.gd:get_health
## pattern. Callers may type-narrow via `as HealthComponent`.
func get_health() -> Node:
	return get_node_or_null(^"HealthComponent")


## Initialize HealthComponent from BalanceData.buildings[<kind>].max_hp
## per the BUG-C1 canonical Dictionary-lookup pattern. Subscribe to the
## LOCAL HC.health_zero signal per BUG-G1 fix-pattern.
##
## Called from base Building._ready (above) — every building runs this
## at scene-ready time. If HealthComponent is absent in the scene
## (test fixture or pre-Wave-3-BD scene), the function early-bails
## defensively: building remains invulnerable for that run, with a
## diagnostic log. Production scenes always have HC via the base
## building.tscn (Wave 3-BuildingDestructibility scene-edit).
##
## Subclasses do NOT override this; they override _on_health_zero
## for cleanup specifics (per architecture-reviewer C4.4 + §3.1 item 3).
func _init_health_from_balance_data() -> void:
	var hc: Node = get_node_or_null(^"HealthComponent")
	if hc == null:
		# Test fixture or pre-Wave-3-BD scene. Building remains
		# invulnerable; log so live-test can flag missing HC.
		print("[%s]   no HealthComponent in scene — building cannot be "
			% str(kind)
			+ "destroyed in this run (test fixture or pre-Wave-3-BD scene)")
		return
	# Subscribe to LOCAL health_zero signal — BUG-G1 fix-pattern. The
	# local signal cannot collide because we connect to OUR component's
	# signal directly; no global namespace involved.
	# (§9.M7 L7 cleanup: the former `if hc.has_signal(&"health_zero")`
	# guard + warn-and-bail else-branch was a stale relic — health_zero
	# is contract-promised on HealthComponent (health_component.gd, BUG-G1
	# pattern) and every scene + test fixture attaches the real script.
	# Direct access fails loudly at this line on contract regression.)
	if not hc.health_zero.is_connected(_on_health_zero):
		hc.health_zero.connect(_on_health_zero)
	# Initialize HC from BalanceData (canonical Dictionary lookup per
	# BUG-C1 + §9.L11 — reads buildings[<kind>].max_hp, NOT bldg_<kind>).
	# (§9.M7 L7 cleanup: former `if hc.has_method(&"init_max_hp")` guard
	# silently skipped max-HP init on contract drift — init_max_hp is the
	# HC contract; unguarded call() errors loudly if it ever goes missing.)
	var max_hp: float = _resolve_max_hp()
	hc.call(&"init_max_hp", max_hp)
	# (Review-panel M7 cleanup: the former `if hc.has_method(&"set")`
	# guard was vacuous — every Object has set(); it could only mask a
	# wrong-property silent no-op. Direct assignment per §9.M7.)
	hc.set(&"unit_id", unit_id)
	# Session-11 hotfix (review ARCH-1) — unit_id collision ROOT fix.
	# Building ids and Unit ids collide in the same int space; suppress the
	# global unit_health_zero / unit_died emits for Building HCs so a razed
	# building can never death-preempt (and free) a same-id healthy Unit or
	# misfire a worker-death Farr drain. Building death surfaces via the
	# LOCAL hc.health_zero subscription above (BUG-G1 pattern) + the typed
	# EventBus.building_destroyed emit in _on_health_zero.
	hc.set(&"emit_global_death_signals", false)


## Read max_hp from BalanceData.buildings[<kind>].max_hp via the
## canonical Dictionary lookup per BUG-C1 fix-wave learning. Falls
## back to 100.0 if any defensive step fails (file missing, BD null,
## dict missing, entry missing, type mismatch).
##
## Fallback rationale: 100.0 is a visible-positive value — a building
## with fallback HP can still be attacked + destroyed, but in a
## diagnostic timeframe (50× faster than the typical 500-2000 HP
## production range). §9.L9 fallback-by-failure-visibility-shape:
## fallback should be diagnosable when it fires, not silent. 100.0
## flagged via the log line in _init_health_from_balance_data.
func _resolve_max_hp() -> float:
	const _FALLBACK_MAX_HP: float = 100.0
	if kind == &"":
		return _FALLBACK_MAX_HP
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return _FALLBACK_MAX_HP
	var bd: Resource = load(path)
	if bd == null:
		return _FALLBACK_MAX_HP
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return _FALLBACK_MAX_HP
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null or not (stats is Resource):
		return _FALLBACK_MAX_HP
	var v: Variant = (stats as Resource).get(&"max_hp")
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return _FALLBACK_MAX_HP
	return float(v)


## Subclass hook fired when this building's HealthComponent emits its
## local health_zero signal. Default implementation:
##   1. Latch via _destruction_emitted (idempotent — only fires once).
##   2. Log destruction with [<kind>] tag per §9.M6.
##   3. Emit generic EventBus.building_destroyed(team, kind, unit_id).
##   4. queue_free().
##
## Subclasses override to ADD specific cleanup BEFORE the emit + free.
## Subclass override pattern (per architecture-reviewer C4.4 + §3.1.a):
##   func _on_health_zero(unit_id_in: int) -> void:
##       if _destruction_emitted: return
##       # ... subclass-specific cleanup (registry/group/Subsystem) ...
##       super._on_health_zero(unit_id_in)  # fire the base latch + emit + free
##
## Throne also emits the specific EventBus.throne_destroyed signal
## (Phase 8 win-screen consumer) AFTER cleanup but BEFORE super-call,
## OR by calling super first and then emitting. Both shapes work; the
## existing throne.gd:_on_health_zero is the canonical reference.
##
## unit_id_in parameter retained for telemetry symmetry with the
## global signal shape; local-signal subscription guarantees this
## matches self.unit_id by construction.
func _on_health_zero(unit_id_in: int) -> void:
	if _destruction_emitted:
		return
	_destruction_emitted = true
	# §9.M6 — log destruction with kind-tag for live-test diagnostics.
	print("[%s] destroyed team=%d unit_id=%d" % [str(kind), team, unit_id])
	# Emit generic destruction signal (architecture-reviewer C2.1 R4
	# resolution — per-building signals would proliferate, generic
	# scales cleanly with AI consumers).
	EventBus.building_destroyed.emit(team, kind, unit_id)
	# Free the node. _exit_tree (with proper super-call per §3.1 item 5)
	# handles fog deregister + sim_phase disconnect.
	queue_free()
