---
title: Resource Node Schema Contract
type: contract
status: ratified
version: 1.4.0
owner: world-builder
summary: Resource gathering — ResourceNode hierarchy (MineNode + Mazra'eh-as-Building-subclass via duck-typing), three-call extract API (request_extract / complete_extract / release_extract), IDropoffTarget protocol, fertile-zone placement, EventBus signals, BalanceData keys. v1.2.2 expands §4.5 to declare all 5 shipped Mazra'eh ResourceNode-shape fields + introduces §4.6 documenting the kind-vs-resource_kind separation for resource-producing Building subclasses. v1.2.3 surgical correction — §4.5 example + prose align with shipped is_gatherable = false default + flip-on-placement. v1.3.0 (wave 1B) — new §4.7 documents the extraction-modifier-emitter pattern (Ma'dan as canonical example, ResourceNode register_extraction_modifier / effective_yield_per_trip_x100 API, stacking-rule policy, navmesh-obstacle-reinforces-cultural-framing convention). v1.3.1 (wave 1B live-test) — §3.2 honesty correction surfaced NavigationObstacle3D inert-under-shipped-architecture (L25). v1.3.2 (wave 1C close, 2026-05-17) — §3.2 status refresh after four-round investigation. v1.4.0 (wave 1D, 2026-05-17) — §3.2 positive prose: canonical Godot 4.6 source-geometry-pipeline rebake from `Building._on_placement_complete` using explicit `parse_source_geometry_data(get_tree().root)` + `bake_from_source_geometry_data` calls. L25 + L26 RESOLVED.
audience: all
read_when: working-on-resources-mines-farms-gather-or-worker-ai
prerequisites: [MANIFESTO.md, SIMULATION_CONTRACT.md, STATE_MACHINE_CONTRACT.md]
ssot_for:
  - ResourceNode abstract base + MineNode subclass + Mazra'eh duck-typed Building subclass
  - three-call extract API (request_extract / complete_extract / release_extract) with Dictionary payload
  - state-side dwell counter pattern (extract_ticks field on node, countdown on UnitState_Gathering)
  - IDropoffTarget duck-typed protocol
  - fertile-zone placement (Array[Vector2i] map metadata, WorldGrid.is_fertile)
  - NavigationObstacle3D ownership (mine scenes + structural Building scenes carry it; farms don't) + canonical Godot 4.6 source-geometry-pipeline rebake from `Building._on_placement_complete` — see §3.2 v1.4.0
  - depletion lifecycle (queue_free.call_deferred for mines; building-destruction for farms)
  - four resource-node EventBus signals
  - resource_node_depleted dual-mode payload (API ref + telemetry destructure)
  - ResourceNodeConfig keys (mine + farm yield/stock/workers)
  - extraction-modifier-emitter pattern (Ma'dan canonical example, ResourceNode register_extraction_modifier API)
  - modifier-stacking policy (default first-registered-wins per BalanceData modifier_stacks)
  - navmesh-obstacle-reinforces-cultural-framing convention (§4.7.5 documented INTENT — mechanical half inert; see §3.2)
references: [SIMULATION_CONTRACT.md, STATE_MACHINE_CONTRACT.md, TESTING_CONTRACT.md]
tags: [resources, mines, farms, gather, navigation, fertile-tiles, signals]
created: 2026-04-30
last_updated: 2026-05-17
provenance: Outcome of Sync 4 — joint Constraint Negotiation between world-builder and gameplay-systems. Path 2 (workers gather grain) ratified by design chat 2026-04-30. Convergence Review revisions 2026-05-01. v1.2.0 wave-1A patch (2026-05-14) — §4 SSOT-fix to align consumer-facing API prose with shipped code (the wave-1A implementation walked away from the v1 begin_extract / tick_extract / ExtractResult-enum shape; this contract version documents the actual three-call API in flight) + Mazra'eh-as-duck-typed-Building-subclass shape from Room A Open Space. v1.2.1 surgical patch (2026-05-14) — ResourceSystem.register_node signature change to take kind as explicit parameter (`register_node(node, kind: StringName)`); v1.2.0 implementation read node.kind which collided with Mazra'eh's Building-kind field (&"mazraeh") vs the resource kind (&"grain"). v1.2.1 caught pre-consumption (no wave-1A consumer queries the registry yet) via world-builder's §4.5 prose review. v1.2.2 (2026-05-14, gp-sys) — §4.5 expanded to declare all 5 SHIPPED Mazra'eh fields (resource_kind, reserves_x100, max_slots, is_gatherable, yield_per_trip_x100, plus extract_ticks) after world-builder's `6d73889` shipped the schema per arch-reviewer BLOCK-A. New §4.6 documents the kind-vs-resource_kind separation pattern for resource-producing Building subclasses (Building-identity kind + Resource-identity resource_kind on the same instance — the dual-field convention applies to Building subclasses only; ResourceNode subclasses keep `kind` as resource identity). v1.2.3 (2026-05-14, gp-sys, re-review BLOCK-C) — §4.5 example + prose `is_gatherable` default corrected from `true` to `false` to align with shipped code post-`3183c7c` (Mazra'eh now defaults `false`, `_on_placement_complete` flips to `true`; default-false enforces forward-compat lock against gather-during-construction for future Building subclasses). Regression-test locked at `test_mazraeh.gd:388`. v1.3.0 (2026-05-15, gp-sys, wave 1B Commit 4) — new §4.7 documents the extraction-modifier-emitter pattern shipped in wave 1B (Ma'dan canonical example): ResourceNode base `register_extraction_modifier` / `unregister_extraction_modifier` / `effective_yield_per_trip_x100` API (shipped at 3d7b722), modifier-emitter duck-typed surface (`yield_multiplier_x100()` method), stacking-rule policy (default first-registered-wins per design Q3), modifier-emitter Building convention (no resource_kind, no gather schema, finds target via `&"resource_nodes"` group), navmesh-obstacle-reinforces-cultural-framing convention (lead's 2026-05-15 ratification — modifier-frame buildings have obstacle; resource-producing-frame buildings like Mazra'eh do not). v1.3.2 (2026-05-17, engine-architect-p3s2, wave 1C Phase 2C honest-archaeology patch) — §3.2 status refresh post-four-round investigation (Task #126 spike + Tasks #140, #142, #146 diagnostic rounds): documents the four configuration layers currently shipped (`affect_navigation_mesh = true` + `carve_navigation_mesh = true` + `vertices` polygon at `90d39bd`/`bc34c39`; manual `region.bake_navigation_mesh(false)` from `Building._on_placement_complete` at `910bd9a`; `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` parse scope at `be8c355`; L6 lint revised at `c480303`) plus the unresolved hypothesis surface (R4-α through R4-ε) for the dedicated investigation wave. v1.4.0 (2026-05-17, engine-architect-p3s2, wave 1D resolution — Task #149) — §3.2 positive prose: lead's research-validated Godot 4.6 source inspection identified the parse-root hardcoding in `NavigationRegion3D::bake_navigation_mesh()` convenience wrapper. Resolved via explicit pipeline `parse_source_geometry_data(region.navmesh, source, get_tree().root)` + `bake_from_source_geometry_data(region.navmesh, source)` in `Building._on_placement_complete`. L6 lint extended to forbid `bake_from_source_geometry_data_async` outside terrain.gd alongside the existing `bake_navigation_mesh(true)` ban. L25 + L26 RESOLVED. Cross-references `docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0 (full archaeology + Round 4 resolution) + ARCHITECTURE.md §6 v0.23.0 wave-close + §7 L25/L26 closed entries.
---

# Resource Node Schema Contract

> Foundation: this contract sits on top of `SIMULATION_CONTRACT.md` and `STATE_MACHINE_CONTRACT.md`. All node state mutation happens inside `_sim_tick`. All cross-component writes go through method calls, never reaching in. No exceptions.

---

## 0. Why this document exists

Iran's economy has two resource types with fundamentally different source semantics: Coin from pre-placed, depletable mines; Grain from player-built farms on map-designated fertile zones. The worker's `Gathering` state must not branch on source type — that asymmetry belongs to the node hierarchy, not the consumer. This contract pins the boundary between what world-builder owns (terrain, placement, depletion, navmesh) and what gameplay-systems owns (gather loop, deposit, balance data).

**In scope:** `ResourceNode` type hierarchy, placement API, depletion lifecycle, navmesh interaction, consumer-facing gather API, dropoff protocol, EventBus signals, BalanceData keys.

**Out of scope:** worker `Gathering` state internals beyond the API sketch in §4; building construction sequence (Building system contract); unit carry animations; audio feedback.

---

## 1. Type Hierarchy

### 1.1 Decision: Option A — abstract base class with two MVP subclasses

Single `ResourceNode` base class. **`MineNode` (coin) and `Mazra'eh` (grain) are the two concrete subclasses at MVP.** Both participate in the same gather/extract API. The worker's `Gathering` state sees only `ResourceNode` — no subclass branching in consumer code regardless of which resource the kargar is gathering.

```gdscript
# world/resource_node.gd
class_name ResourceNode extends SimNode

## Readable properties — safe to read from _sim_tick at any phase.
var resource_kind: StringName = &""     # &"coin" (MineNode) | &"grain" (Mazra'eh)
var is_gatherable: bool = true          # false when depleted, destroyed, or under construction
var current_stock: int = 0              # -1 means infinite (Mazra'eh — gathered indefinitely)
var max_workers: int = 1                # simultaneous gather slots

## Called by Gathering state to begin a gather cycle. Returns false if
## node is at capacity, depleted, or invalid for this worker.
func begin_extract(worker: Node) -> bool:
    return false  # subclass implements

## Called each _sim_tick while worker is gathering.
func tick_extract(worker: Node, dt: float) -> ExtractResult:
    return ExtractResult.INVALID  # subclass implements

## Called when worker departs (trip complete, interrupted, or dead).
func release_extract(worker: Node) -> void:
    pass  # subclass implements

## Returns the Node3D the worker should walk to for deposit.
## MVP: returns the player's Throne for any subclass.
## Future subclasses may return alternate depots.
func get_dropoff_target(worker: Node) -> Node3D:
    return null  # subclass implements
```

The abstract base class pays for itself at MVP — two subclasses share the consumer API, and post-MVP additions (Div faction economics, possible fishing or lumber sources) plug in as further subclasses without touching the worker's `Gathering` state or the §4 consumer surface. Per Manifesto Principle 5 (Platforms not features).

### 1.2 `ExtractResult` enum

```gdscript
# world/resource_node.gd (inner class or top of file)
enum ExtractResult {
    GATHERING,       # still in progress this tick
    YIELD_READY,     # trip complete; worker carries resource_kind * yield_amount
    NODE_DEPLETED,   # mine ran out mid-trip; worker carries partial or nothing
    NODE_FULL,       # all slots occupied (rare — another worker beat you to it)
    INVALID,         # node destroyed or otherwise unregistered
}
```

`YIELD_READY` does not carry the amount — the worker reads its own carry state, which is set by `tick_extract` via the node calling the worker's `set_carry(kind, amount)` method. Mutation ownership stays local: the node calls a method on the worker rather than reaching into the worker's fields.

### 1.3 `MineNode`

```gdscript
# world/mine_node.gd
class_name MineNode extends ResourceNode
```

- `resource_kind = &"coin"`
- `current_stock` initialized from `BalanceData.mine_initial_stock` (see §7)
- `max_workers = 2` (two kargar can share a mine)
- Depletable: `current_stock` decrements each trip. When it reaches 0, `is_gatherable = false` and `EventBus.resource_node_depleted.emit(self)` fires (see §6)

### 1.4 `Mazra'eh` (grain) — `Building` subclass with duck-typed gather surface (wave-1A, 2026-05-14)

> **v1.2.0 correction (2026-05-14):** the v1 spec said `Mazraeh extends ResourceNode`. The wave-1A implementation (Room A Open Space, 2026-05-14) chose option (iii): `Mazra'eh extends Building` and duck-types the three-call API on itself. See §4.5 for the full rationale. The v1.1 §1.4 prose below is retained for history but the class hierarchy it describes is NOT shipped.

`Mazra'eh` is the player-built farm building. It extends `Building` (not `ResourceNode`) to preserve the full building lifecycle: construction timer, HP/HealthComponent (wave 1C — not present in wave 1A), build-menu integration, the `&"buildings"` SceneTree group, and placement hooks. It duck-types the three-call gather API on itself so `UnitState_Gathering`'s `has_method(&"request_extract")` filter at line 143 discovers it without class-coupling.

```gdscript
# game/scripts/world/buildings/mazraeh.gd  (world-builder)
extends "res://scripts/world/buildings/building.gd"
class_name Mazraeh

# kind = &"mazraeh" (Building kind — set via KIND_MAZRAEH constant, dual-init).
# Resource kind &"grain" is returned by complete_extract as Constants.KIND_GRAIN
# in the { kind, amount_x100 } payload — NOT stored as a field here.

const _WAVE_1A_EXTRACT_TICKS: int = 90         # 3s dwell at SIM_HZ=30
const _WAVE_1A_YIELD_PER_TRIP_X100: int = 200  # 2 Grain per trip

func request_extract(unit_id: int) -> bool: ...
func complete_extract(unit_id: int) -> Dictionary: ...
func release_extract(unit_id: int) -> void: ...
var extract_ticks: int = _WAVE_1A_EXTRACT_TICKS  # read by UnitState_Gathering L210
```

- Grain yield: `_WAVE_1A_YIELD_PER_TRIP_X100 = 200` (2 Grain/trip). BalanceData-driven from wave 1B.
- Infinite reserves: `complete_extract` never depletes — no `reserves_x100` sentinel field (Mazra'eh extends Building, not ResourceNode). Returns full payload unconditionally.
- Single gather slot for wave 1A (`_occupied: Dictionary` with size ≤ 1).
- `is_complete` (from Building base) gates `request_extract` — returns `false` before `place_at`.
- No `NavigationObstacle3D` — workers walk onto the farm tile (mines are obstacles, farms are walk-on).
- HP/HealthComponent: ships wave 1C. Destruction lifecycle is a forward-compat hook that cannot fire in wave 1A.

**Rationale (per design chat resolution 2026-04-30 + Room A 2026-05-14):** workers gathering grain preserves the foundational RTS archetype where workers drive the economy. The earlier passive-generator alternative would have stripped that role for one resource type, breaking the worker's centrality. The duck-type option (iii) over `extends ResourceNode` preserves the full Building lifecycle without multiple-inheritance gymnastics. See §4.5 for the detailed comparison.

### 1.5 Why `current_stock = -1` for `Mazra'eh`

A Mazra'eh does not deplete from being gathered. It only stops yielding when destroyed. This avoids a "grain runs out" failure mode that would push the player into a perpetual farm-rebuilding micro-loop, which is not in the design intent. The depletion concept stays meaningful for finite map resources (mines), and the destruction concept stays meaningful for player-built structures (farms) — distinct mechanics, distinct mental models.

If post-MVP design wants soil exhaustion or grain-cap mechanics, the same `current_stock` field can carry that load: positive integer with decrement-per-trip, identical to `MineNode`. The base class shape already supports it; only the Mazra'eh subclass code would change.

---

## 2. Placement and Fertile Zones

### 2.1 Mine placement

Mine nodes are placed at map-authoring time inside `game/scenes/maps/khorasan.tscn`. They are static — no runtime spawning of mines. Each `MineNode` instance in the scene tree is pre-positioned. The map author (world-builder) places them symmetrically across the two spawns per the map design.

`MineNode` scenes include a `NavigationObstacle3D` child (see §3.2). No runtime code is required to set up navmesh carving for mines.

### 2.2 Fertile zones — zones, not nodes

Fertile tiles are **not `ResourceNode` instances**. They are map metadata: designated areas where a `Mazra'eh` building may be placed.

```gdscript
# world/world_grid.gd  (autoload, owned by world-builder)
extends Node

## Grid cell size in world units. Matches NavigationRegion3D agent radius rounding.
const CELL_SIZE: float = 2.0

## Exported on the map scene — set at authoring time, not runtime.
@export var fertile_cells: Array[Vector2i] = []

## Called by the building placement system at ghost-preview time.
func is_fertile(cell: Vector2i) -> bool:
    return cell in fertile_cells

## Convert world position to grid cell.
func world_to_cell(world_pos: Vector3) -> Vector2i:
    return Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.z / CELL_SIZE))
```

The building placement system (gameplay-systems) calls `WorldGrid.is_fertile(cell)` when the player tries to place a `Mazra'eh`. If `false`, placement is rejected. No fertile-zone scene files, no fertile-zone runtime nodes.

### 2.3 Mine node registration

`MineNode._ready()` self-registers with `ResourceSystem` (gameplay-systems autoload):

```gdscript
func _ready() -> void:
    ResourceSystem.register_node(self)
```

The Mazra'eh self-registers with `ResourceSystem` when its construction-complete signal fires (not at `_ready()` — under-construction farms are not gatherable). On fatal damage, it deregisters before being freed. `ResourceSystem` owns the registry; both `MineNode` and `Mazra'eh` opt in via the same `register_node` / `unregister_node` calls.

---

## 3. Lifecycle, Depletion, and NavMesh

### 3.1 Mine depletion sequence

1. `tick_extract` runs inside `_sim_tick` during the `combat` phase (resource extraction is treated as a combat-phase actor — see §4 for phase assignment rationale).
2. When `current_stock` would go to 0 or below, the node sets `is_gatherable = false` via `_set_sim`, computes the partial yield for the current worker's trip, and emits `EventBus.resource_node_depleted.emit(self)` at end of tick (deferred to `cleanup` phase via a flag — see §3.3).
3. Any worker whose `tick_extract` returns `NODE_DEPLETED` this or next tick transitions to `Idle` via `transition_to_next()` (State Machine Contract §3.4) and seeks the nearest non-depleted node via `ResourceSystem`.
4. The `MineNode` scene remains in the tree. It does not `queue_free`. Visual state is updated by world-builder responding to `resource_node_depleted` signal (greyed-out mesh, particle cutoff).

### 3.2 `NavigationObstacle3D` ownership (v1.4.0)

Each `MineNode` and structural `Building` scene (Khaneh, Ma'dan, future Sarbaz-khaneh) includes a `NavigationObstacle3D` child configured at authoring time with `affect_navigation_mesh = true` + `carve_navigation_mesh = true` + a `vertices: PackedVector3Array` polygon matching the building footprint plus a small margin. When the building is placed at runtime via `add_child`, `Building._on_placement_complete()` drives an explicit synchronous navmesh rebake using the Godot 4.6 source-geometry pipeline — this is what actually makes the path query (`NavigationServer3D.map_get_path()`) route workers AROUND placed buildings.

**The canonical rebake pipeline** (shipped at `building.gd._on_placement_complete`, wave 1D Task #149):

```gdscript
var source := NavigationMeshSourceGeometryData3D.new()
NavigationServer3D.parse_source_geometry_data(
    region.navigation_mesh, source, get_tree().root)
NavigationServer3D.bake_from_source_geometry_data(
    region.navigation_mesh, source)
```

**Why the explicit pipeline (not the convenience wrapper).** `NavigationRegion3D::bake_navigation_mesh()` is a convenience wrapper that hardcodes `this` (the region itself) as the parse-root passed to `parse_source_geometry_data()`. Since buildings live as siblings of Terrain under `&World` (per `unit_state_constructing.gd:_resolve_placement_parent` returning the worker's parent), the convenience wrapper's parse-root never sees them. Validated against Godot 4.6 source at `scene/3d/navigation/navigation_region_3d.cpp` + `modules/navigation_3d/nav_mesh_generator_3d.cpp:236-255`. The explicit pipeline passes `get_tree().root` directly, walking the entire scene tree.

**Why sync (not async).** `bake_from_source_geometry_data` is the synchronous form; `bake_from_source_geometry_data_async` is the async form. The async form races sim ticks and produces non-deterministic navmesh state across AI-vs-AI sims (Sim Contract §1.6 violation). CI lint rule **L6** (`tools/lint_simulation.sh`) forbids the async form outside `terrain.gd`; the sync form is permitted project-wide. Per-placement cost on the 256×256 flat MVP plane is <15ms — placement events are seconds apart, so cumulative re-bake cost is negligible across a match.

**Obstacle config per scene.** All three obstacle-bearing scenes set both flags identically:

| Scene | Footprint (X × Z) | Polygon (vertices, ±) | Source |
|---|---|---|---|
| `building.tscn` (Khaneh inherits) | 2.0 × 2.0 | ±1.1 | `90d39bd` (Phase 2A, Task #135) |
| `madan.tscn` | 2.5 × 2.5 | ±1.35 | `90d39bd` (Phase 2A, Task #135) |
| `mine_node.tscn` | r = 0.75 cylinder | 8-vertex octagon @ 0.85m | `bc34c39` (Phase 2A.1, Task #141) |
| `mazraeh.tscn` | 4.0 × 4.0 | **NONE — walkable** | (no obstacle by design) |

The 0.1m margin compensates for the navmesh `agent_radius = NAV_AGENT_RADIUS = 0.5` erosion. Without it, the eroded boundary flushes with the visual silhouette and workers may snag at corners.

**`affect_navigation_mesh` + `carve_navigation_mesh` both required.** These are independent participation flags (verified via Godot binary symbol enumeration — see `docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0 §0.1 Round 1):
- `affect_navigation_mesh = true` — bake-time participation. Contributes to bakes triggered during scene-load (e.g., obstacle present in `terrain.tscn` subtree at `_ready` bake).
- `carve_navigation_mesh = true` — runtime participation. Contributes to bakes triggered after scene-load (the building-placement path this contract covers).

Belt-and-suspenders pattern: both flags set together covers both lifecycle paths.

**Subclass override discipline.** Subclasses that override `_on_placement_complete` (Khaneh, Mazra'eh, Ma'dan) MUST call `super._on_placement_complete(placer_unit_id)` as the first line of their override — otherwise the rebake doesn't fire. This is enforced by the behavioral integration test (`test_phase_3_nav_obstacle_carving_behavioral.gd`) that asserts post-placement waypoints route around the building footprint. Mazra'eh has no `NavigationObstacle3D`, so `find_child` returns null and the rebake short-circuits — Mazra'eh remains correctly walkable.

**Depleted mine policy.** When a `MineNode` depletes (`is_gatherable = false`), the `NavigationObstacle3D` stays active — the carved navmesh region remains carved, and workers continue routing around the derelict deposit. This matches the Shahnameh intent (mining sites leave navigationally impassable ruins) and the explicit pipeline naturally supports it: the obstacle is a `_ready`-time child of the mine, not depletion-state-dependent. No code path removes the obstacle. If post-MVP design adds a "clear ruins" mechanic (escalated to `QUESTIONS_FOR_DESIGN.md`), the cleanup path would `queue_free` the obstacle node and trigger a fresh rebake.

**Behavioral test discipline.** Tests of structural elements whose purpose is to cause an effect on adjacent systems (NavigationObstacle3D, CollisionShape3D, signal subscriptions, etc.) MUST assert the EFFECT, not just the presence — see STUDIO_PROCESS §9 "Cross-cutting structural claims require behavioral assertions" rule (2026-05-15, added in direct response to the L25 finding). The `test_phase_3_nav_obstacle_carving_behavioral.gd` integration test exercises this discipline: it places a building, queries `NavigationServer3D.map_get_path()` from a worker's spawn point to a target on the opposite side, and asserts the returned waypoints route AROUND the building's footprint (no waypoint inside the carved region).

**Forward-investment.** This pipeline scales linearly with scene-tree size. For Phase 6+ AI with ~200 units + buildings, the parse step's tree-walk remains negligible (it filters by node-type contribution; non-Mesh / non-Collider / non-Obstacle nodes are skipped). If parse cost ever surfaces as a profile hotspot, the optimization path is `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN` mode + a dedicated `&"navmesh_contributors"` group — captured as forward-investment, not pursued today.

**Cross-references:**
- `docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0 — full four-round-plus-resolution archaeology with empirical-probe artifacts (Godot binary symbol enumeration, scene-tree shape, qa probe results, Godot 4.6 source validation).
- `docs/ARCHITECTURE.md` §7 L25 + L26 — closed with closing-SHA reference.
- STUDIO_PROCESS §9 retro signal — Godot 4.x engine-feature claim "enumerate API defaults at every step in the call chain" rule (four-incident pattern, now formalized).

---

**Pre-v1.4.0 prose retained below for archaeology — DO NOT TRUST as current behavior:**

> **⚠️ v1.3.2 status refresh (2026-05-17, post-wave-1C four-round investigation):** Wave 1C spike ran four rounds of empirically-tested mechanism corrections (Task #126 + Tasks #140, #142, #146). The four-round trail surfaced the bake-vs-trigger semantics, the source-geometry-parse scope, and ultimately the parse-root hardcoding in the convenience wrapper. Lead's option-B decision (2026-05-17) initially deferred the dedicated investigation, but user pushback against the deferral framing triggered Wave 1D (Task #149) which resolved the mechanism via the explicit pipeline now documented at the top of this section.

> **⚠️ v1.3.1 honesty correction (2026-05-15, engine-architect-p3s2 wave-1B live-test investigation):** The previous version of this section claimed `NavigationObstacle3D` children carve the navmesh dynamically at runtime without a rebake. That claim was structurally false under the shipped architecture as of 2026-05-15. Resolved at wave 1D — see top of section for the canonical pipeline.

Each `MineNode` scene includes a `NavigationObstacle3D` child configured at authoring time. **No runtime code adds, removes, or resizes this obstacle.** When the mine depletes:

- The obstacle stays active — depleted mines remain physically impassable. ← TRUE as of v1.4.0 (the carve persists; only `queue_free` would remove it).
- This is intentional: derelict mine ruins are navigational obstacles, consistent with the Shahnameh setting. ← intent realized as of v1.4.0.

**Design escalation (ruins clearing):** Whether workers can later "clear" depleted mine ruins (removing the obstacle, reclaiming the cell) is a gameplay question outside this contract's scope. Escalated to `QUESTIONS_FOR_DESIGN.md`. If ruins clearing ships, it will update this contract in a future sync. Implementation under the v1.4.0 pipeline: `queue_free` the obstacle node, then trigger a fresh `parse_source_geometry_data` + `bake_from_source_geometry_data` cycle to remove the carved region.

### 3.3 Depletion signal emission timing

`EventBus.resource_node_depleted` must not emit mid-tick (Simulation Contract §1.1 — write-shaped signals forbidden from off-phase code). Emission is deferred to the `cleanup` phase:

```gdscript
# mine_node.gd
var _depleted_this_tick: bool = false

func tick_extract(worker: Node, dt: float) -> ExtractResult:
    # ... decrement stock ...
    if current_stock <= 0:
        _set_sim(&"is_gatherable", false)
        _depleted_this_tick = true
        return ExtractResult.NODE_DEPLETED
    return ExtractResult.GATHERING

func _sim_tick(dt: float) -> void:
    if _depleted_this_tick:
        _set_sim(&"_depleted_this_tick", false)
        EventBus.resource_node_depleted.emit(self)
```

The `cleanup` phase coordinator calls this node's `_sim_tick` to flush the deferred emit. The signal fires exactly once, in the correct phase.

### 3.4 Mazra'eh lifecycle (wave 1A — partial; HP/destruction deferred to wave 1C)

> **v1.2.0 correction (2026-05-14):** the v1 spec described a full `is_gatherable` + `HealthComponent` depletion lifecycle. In wave 1A, HP/HealthComponent on buildings does not exist yet. The destruction lifecycle described below is the forward-intended design; the parts marked **[wave 1C]** are not yet implemented.

**Wave 1A (shipped):**
- `is_complete` (Building base field) starts `false` at spawn; set `true` by `place_at`. This is the gate for `request_extract` — workers cannot gather from an unplaced Mazra'eh.
- `_on_placement_complete` self-registers with `ResourceSystem.register_node(self)` (guarded by `has_method` — ships wave 1B).
- Grain yield is infinite — `complete_extract` returns the full per-trip payload unconditionally; no depletion state.
- No `NavigationObstacle3D` — workers walk onto the farm tile.

**[wave 1C] Forward-intended destruction lifecycle:**
- `is_gatherable` set `false` permanently when the building takes fatal damage (HealthComponent zero).
- On destruction: Mazra'eh emits `EventBus.resource_node_depleted.emit(self)` (deferred to `cleanup` phase) and deregisters from `ResourceSystem`. Workers holding a gather slot at destruction time see an empty payload from `complete_extract` on the next completed trip and transition to Idle.
- Destruction does not leave a navmesh-blocking ruin (unlike `MineNode` per §3.2); the farm is fully cleaned up on destruction.

---

## 4. Consumer-Facing API — the `Gathering` State's View

> **Version 1.2.0 reality check (2026-05-14):** the §4 prose below describes the API the SHIPPED wave-1A code uses (`request_extract` / `complete_extract` / `release_extract` with `Dictionary` payloads + a state-side dwell counter). The original v1 contract spec'd `begin_extract` / `tick_extract` / `release_extract` with an `ExtractResult` enum; the wave-1A implementation (2026-05-08, see ARCHITECTURE.md §6 v0.20.2) deliberately walked away from that design for the rationale documented in `game/scripts/world/resource_nodes/resource_node.gd` lines 12–33 (no per-worker progress dict on the node, no deferred-emit cleanup, no node `_sim_tick`). This SSOT-fix patch (v1.2.0) brings the contract in line with the shipped code per the §9 2026-05-14 rule (SSOT prose contradictions are BLOCKING at wave-close).

### 4.1 The shipped three-call API

The worker's `UnitState_Gathering` state holds two refs: a target node (any node duck-typing the three-call API, including non-`ResourceNode` subclasses — see §4.5 for Mazra'eh) and nothing else. Carry state lives on the worker. The state issues exactly three calls into the node across its lifetime:

1. `node.request_extract(unit_id: int) -> bool` from `_sim_tick` after the worker arrives at the node. Returns `false` if the node is depleted, full (all `max_slots` occupied), or this `unit_id` already holds a slot here. State transitions to Idle on rejection.
2. `node.complete_extract(unit_id: int) -> Dictionary` from `_sim_tick` after the state-side dwell timer (`_dwell_remaining_ticks`) reaches zero. Returns `{ kind: StringName, amount_x100: int }` — the carry payload. Decrements the node's `reserves_x100` (no-op for `Mazra'eh` with `reserves_x100 = -1`) and frees the worker's slot. Empty payload (`kind=&""`, `amount_x100=0`) signals an unknown-worker double-complete; the state never receives this in correctly-shaped code.
3. `node.release_extract(unit_id: int) -> void` from `exit()`. Idempotent — releasing a slot the worker doesn't hold is a no-op. Per State Machine Contract §3.2, `exit()` is called on every leave path including death.

**Why state-side dwell (not on-node tick accumulator):** the wave-1A simplification keeps the node's API surface to three methods and avoids a per-worker progress dictionary on the node. The state has its own `_dwell_remaining_ticks` counter, initialized at slot-grant time from `node.extract_ticks` (a public field, kind-specific). The node doesn't need a `_sim_tick`; depletion is computed inside `complete_extract` at trip-end.

The `UnitState_Gathering` state has no knowledge of mines, farms, depletion semantics, fertile zones, or building lifecycles. All that lives behind the three method calls and the node's `extract_ticks` field.

### 4.2 Gathering state skeleton (shipped, abbreviated)

The shipped state at `game/scripts/units/states/unit_state_gathering.gd` follows this shape. The full implementation includes movement-driving + path-state branches; the gather-specific surface below is the contract-relevant subset.

```gdscript
# game/scripts/units/states/unit_state_gathering.gd  (gameplay-systems)
class_name UnitState_Gathering extends "res://scripts/core/state_machine/unit_state.gd"

# id = &"gathering" — LOAD-BEARING per Open Space sync (ARCHITECTURE.md §6
# v0.20.0). The Farr-drain dispatcher reads current.id at unit-death time
# to distinguish gather-death (drain -0.5) from idle-death (drain -1.0).

var _target_node: Variant = null         # any node duck-typing request_extract
var _slot_held: bool = false
var _dwell_remaining_ticks: int = 0      # state-side dwell counter
var _cached_unit_id: int = -1

func enter(_prev: Object, ctx: Object) -> void:
    # ... resolve target_node from ctx.current_command.payload &"target_node"
    # Defensive: validate target via has_method(&"request_extract") — duck-type
    # check is the discovery seam; no class_name check needed. Both MineNode
    # and Mazra'eh-as-Building pass.

func _sim_tick(dt: float, ctx: Object) -> void:
    # ... drive movement until arrival ...
    if not _slot_held:
        var granted: bool = _target_node.request_extract(int(ctx.unit_id))
        if not granted:
            ctx.fsm.transition_to(&"idle")  # see §9 #1 (retarget policy)
            return
        _slot_held = true
        _cached_unit_id = int(ctx.unit_id)
        _dwell_remaining_ticks = int(_target_node.extract_ticks)
        if _dwell_remaining_ticks <= 0:
            _dwell_remaining_ticks = 1   # one-tick minimum
    _dwell_remaining_ticks -= 1
    if _dwell_remaining_ticks > 0:
        return   # still dwelling
    # Dwell complete — pull the carry payload.
    var payload: Dictionary = _target_node.complete_extract(int(ctx.unit_id))
    _slot_held = false
    var carry_kind: StringName = payload.get(&"kind", &"")
    var carry_amount_x100: int = int(payload.get(&"amount_x100", 0))
    # Carry written to ctx._carry_kind / _carry_amount_x100 — UnitState_Returning
    # reads these in its enter() for the deposit step.
    ctx.set(&"_carry_kind", carry_kind)
    ctx.set(&"_carry_amount_x100", carry_amount_x100)
    ctx.fsm.transition_to(&"returning")

func exit() -> void:
    if _target_node != null and is_instance_valid(_target_node) and _slot_held:
        if _cached_unit_id != -1:
            _target_node.release_extract(_cached_unit_id)
    # Reset state.
```

What this demonstrates:
- **One polymorphic call surface.** The state uses `has_method(&"request_extract")` as the discovery filter. It has no idea whether `_target_node` is a `MineNode extends ResourceNode` or a `Mazra'eh extends Building` (see §4.5).
- **State-side dwell counter.** Decoupled from the node's tick path. `_dwell_remaining_ticks` lives on the state and counts down in the state's `_sim_tick`.
- **Dictionary payload.** `complete_extract` returns `{ kind, amount_x100 }` — typed bag, not an enum. Branch on whether the kind is non-empty if you need to distinguish empty (unknown-worker) from valid payloads.
- **Carry mutation via `ctx.set()`.** The state writes `_carry_kind` / `_carry_amount_x100` on the worker directly. The node does NOT call into the worker — the wave-1A simplification moved that responsibility to the state (vs. the original v1 design which had the node call `worker.set_carry()`).
- **Deterministic cleanup at `exit()`.** Per State Machine Contract §3.2, `exit()` is called on every leave path. The idempotent `release_extract` makes the slot-release safe even when the slot has already been freed by a previous `complete_extract` call.

### 4.3 Worker carry storage

The carry payload is two fields on the worker:

```gdscript
# game/scripts/units/unit.gd or kargar.gd  (gameplay-systems)
var _carry_kind: StringName = &""           # &"coin" | &"grain" | &""(empty)
var _carry_amount_x100: int = 0             # fixed-point per Sim Contract §1.6
```

These are written by `UnitState_Gathering` at trip-end (read from `complete_extract`'s return Dictionary) and read by `UnitState_Returning` at the deposit step. The fields live on the unit script; `_carry_kind = &""` is the "empty carry" sentinel.

`UnitState_Returning` calls the dropoff target's `deposit(resource_kind, amount, worker)` method (see §5), then resets carry to `&""` / `0`.

### 4.4 What the `Gathering` state does NOT do

- Does not call into the worker via a node-side method (no `node` → `worker.set_carry()` indirection — payload comes back from `complete_extract` as a Dictionary).
- Does not look up the next node when one depletes. Auto-retarget is escalated to design (§9 #1) and lives in `ResourceSystem` or a future scouting AI if/when it ships, not in this state.
- Does not validate the dropoff. `UnitState_Returning` does the dropoff handoff; the gather state's job ends at `transition_to(&"returning")` with the carry written.

### 4.5 Mazra'eh — first non-`ResourceNode` consumer of the three-call API (2026-05-14)

Per Room A Open Space (2026-05-14, see `02g_PHASE_3_SESSION_2_KICKOFF.md` §2.4 Decision 4), Mazra'eh extends `Building` (not `ResourceNode`) and implements the three-call API as duck-typed methods on itself. The schema collision — Mazra'eh is simultaneously a `Building` (placement lifecycle, HP, &"buildings" group, unit_id counter) and a "resource node" from the gather-loop perspective — is resolved by **duck-typing the three-call API** rather than forcing single-inheritance gymnastics.

```gdscript
# game/scripts/world/buildings/mazraeh.gd  (world-builder)
extends "res://scripts/world/buildings/building.gd"
class_name Mazraeh

# Mazra'eh implements the three-call ResourceNode API on itself.
# UnitState_Gathering's has_method(&"request_extract") filter discovers
# Mazra'eh without needing it to extend ResourceNode.

# Building-identity field (inherited from Building base, set via dual-init pattern):
var kind: StringName = &"mazraeh"             # BUILDING kind (KIND_MAZRAEH constant)

# ResourceNode-shape fields (declared on Mazra'eh so consumer duck-type checks
# work — click_handler.gd:447 reads `&"is_gatherable" in n`, plus future
# AI / save-game / introspection paths read the schema directly):
var resource_kind: StringName = &"grain"      # RESOURCE kind for ResourceSystem registry seam
var reserves_x100: int = -1                   # -1 sentinel = infinite (per §1.5)
var max_slots: int = 1                        # single gather slot for wave 1A
var is_gatherable: bool = false               # wave-1A: false until _on_placement_complete flips
                                              #   to true (wave-1C: flip moves to
                                              #   _on_construction_complete when timer + HP ship)
var yield_per_trip_x100: int = 200            # 2 Grain per trip (Room A R1-α dehqan-long-dwell tuning)
var extract_ticks: int = 90                   # 3s dwell at 30Hz — "tending the field"

# Three-call API (mirrors ResourceNode base shape — see §4.1):
func request_extract(unit_id: int) -> bool: ...
func complete_extract(unit_id: int) -> Dictionary: ...
func release_extract(unit_id: int) -> void: ...
```

**Why option (iii) duck-type (vs (i) extends ResourceNode + replicate Building, (ii) Building with composed ResourceNode child):**

- `UnitState_Gathering` already discovers consumers via `has_method(&"request_extract")` (the wave-1A design choice that paid back here). No state-side change required to support Mazra'eh.
- Both `Building` (placement lifecycle, build-menu integration, NavObstacle owning) and `ResourceNode` (three-call API) bases stay clean. No subclass forced to mix concerns.
- The cost — Mazra'eh re-implements the three-call methods rather than inheriting them — is ~30 lines of code. Acceptable for a single concrete subclass; if future buildings need the same shape (post-MVP), the gather methods can hoist into a shared mixin module or a small composition helper.

**Mazra'eh-specific differences from MineNode (worth flagging for §8's worked example):**

- `reserves_x100 = -1` (infinite — per §1.5; same field name as ResourceNode base, distinct from §1's older `current_stock` shorthand). `complete_extract`'s decrement is a no-op for negative sentinels.
- `extract_ticks = 90` (3s dwell) — longer than MineNode's 60-tick dwell. Reads visually as "tending the field" (dehqan stewardship — see Mazra'eh script header) rather than "extracting from the mine."
- `yield_per_trip_x100 = 200` (2 Grain per trip) — smaller than MineNode's coin payload (1000 = 10 Coin). Long dwell + small payload combine for the trickle-yield visual.
- `is_gatherable` defaults `false`; `_on_placement_complete` flips it to `true` (wave 1A); wave 1C will move the flip to `_on_construction_complete()` when construction timer + HealthComponent ship. Default-false enforces forward-compat lock against gather-during-construction for future Building subclasses (the next subclass that ships a construction-timer can rely on the default-false invariant; gather attempts during construction return false from `request_extract`). Regression test locked at `test_mazraeh.gd:388` (`test_mazraeh_is_gatherable_flips_on_placement`).
- Mazra'eh self-registers with `ResourceSystem.register_node(self, resource_kind)` at construction-complete — the `resource_kind` FIELD is passed (`&"grain"`), not a literal. The field IS the canonical SSOT for "what resource does this building produce?" See §4.6 for the kind-vs-resource_kind separation rationale; v1.2.1 §9.X for the API-discovery history.
- No `NavigationObstacle3D` — workers walk ONTO the farm tile to gather (§3.2).

The cultural-framing rationale for the long dwell lives in `mazraeh.gd`'s header — the *dehqan* (دهقان, landed cultivator) model from Ferdowsi's Shahnameh — and is referenced here for visibility but is NOT load-bearing for the API contract. Loremaster reviews the cultural framing at wave-close.

### 4.6 The `kind` vs `resource_kind` separation (2026-05-14, v1.2.2)

Resource-producing **Building** subclasses carry TWO StringName identity fields:

| Field | Owned by | Purpose | Mazra'eh example | MineNode-as-ResourceNode equivalent |
|---|---|---|---|---|
| `kind` | Building base (set via `KIND_<NAME>` constant, dual-init pattern) | Building-identity — answers "what kind of building is this?" Used by build menu, save/load, telemetry, building-list iteration. | `&"mazraeh"` | n/a — MineNode extends ResourceNode, not Building |
| `resource_kind` | Mazra'eh (and any future resource-producing Building subclass) | Resource-identity — answers "what kind of resource does this building produce?" Used by ResourceSystem registry, AI scout enumeration, gather-target selection. | `&"grain"` | MineNode's `kind = &"coin"` IS its resource identity — its Building-side identity doesn't exist because it's not a Building |

The asymmetry exists because **MineNode** is a `ResourceNode` (resource-first identity — `kind` IS the resource kind), while **Mazra'eh** is a `Building` (building-first identity — `kind` is the Building kind, AND `resource_kind` carries the resource identity separately). Consumers that enumerate resource sources query `resource_kind` for Buildings and `kind` for ResourceNode subclasses; the ResourceSystem registry's explicit-kind parameter (§4.5 register_node signature) accepts either at the call site, decoupling registry consumers from the field-name asymmetry.

**For future resource-producing Building subclasses** (post-MVP examples: a "Forester's Hut" producing wood, a "Fishery" producing fish, a Tier-2 "Caravanserai" producing trade-goods), the pattern is:
- Building base supplies `kind = &"<subclass-name>"` via dual-init constant.
- The subclass declares `var resource_kind: StringName = &"<resource-name>"` as an additional field.
- The subclass's `_on_placement_complete` calls `ResourceSystem.register_node(self, resource_kind)`.

The field is conventionally placed in a "ResourceNode-shape fields" block in the script, distinct from the Building-identity block, so a reader scanning the class can see the two layers without confusion.

**For ResourceNode subclasses** (MineNode, future Mazra'eh-renamed-to-ResourceNode-subclass-if-anyone-ever-redesigns-it), `kind` carries the resource identity and `resource_kind` is unnecessary. The dual-field convention is Building-specific.

### 4.7 Extraction-modifier registry — buff-emitter pattern (2026-05-15, v1.3.0)

A second category of non-resource-producing Building subclass: the **modifier-emitter**. Where the §4.5/4.6 pattern documents Buildings that PRODUCE a resource (Mazra'eh, future Atashkadeh-variant farms), this section documents Buildings that AMPLIFY an existing ResourceNode's payload (Ma'dan today; future post-MVP economic-multiplier buildings).

**Motivating example — Ma'dan (مَعدَن, "ore-source"):** Per Open Space Room A Option B (2026-05-14), Ma'dan is NOT a separate resource source registering under `&"coin"`. Instead, Ma'dan is placed adjacent to an existing MineNode and registers as that mine's *extraction modifier*. The mine's `complete_extract()` returns the multiplied payload (base × Ma'dan's `yield_multiplier_x100 / 100`). The labor-organization framing (per loremaster brief-time review 2026-05-15, see `madan.gd` header) maps directly: the mine is the canonical resource, the Ma'dan is the organized labor amplifying its output. Mirrors AoE2's Mining Camp + raw resource node pattern.

#### 4.7.1 ResourceNode base API (shipped at 3d7b722)

```gdscript
# scripts/world/resource_nodes/resource_node.gd

var _modifiers: Array[Node] = []          # registered modifier-emitter nodes

## Register a modifier-emitter on this ResourceNode. Returns true on
## success, false on rejection (null/invalid, same-modifier-twice, OR
## stacking=false-and-already-registered).
func register_extraction_modifier(modifier_node: Node) -> bool: ...

## Idempotent removal. Mirrors release_extract pattern.
func unregister_extraction_modifier(modifier_node: Node) -> void: ...

## Compose base yield_per_trip_x100 with registered modifiers' multipliers.
## With no modifiers: returns base unchanged (zero overhead for plain MineNodes).
## With one modifier: base * modifier.yield_multiplier_x100 / 100.
## With multiple modifiers + stacking=true: compounds multiplicatively
## (post-MVP forward-compat; stacking=false is locked at MVP).
func effective_yield_per_trip_x100() -> int: ...
```

`ResourceNode.complete_extract()` reads `effective_yield_per_trip_x100()` instead of the raw `yield_per_trip_x100` field. The change is invisible for mines with no adjacent modifier (effective == base); for mines with a registered modifier the payload's `amount_x100` reflects the multiplied value. **Reserves decrement by the EFFECTIVE amount** — a buffed mine depletes faster per trip, which is correct semantics: the multiplier amplifies the worker's haul AND the mine's wear.

#### 4.7.2 Modifier-emitter duck-typed surface

A modifier-emitter must expose one instance method, duck-typed by `has_method` check:

```gdscript
## Required on modifier-emitter Buildings.
## Returns the yield multiplier in x100 fixed-point.
## Convention: 150 = 1.5x, 200 = 2.0x, 100 = no-op (1.0x).
func yield_multiplier_x100() -> int: ...
```

The ResourceNode does not class-check the modifier — it duck-types on the method. This keeps the base class faction-neutral; a future post-MVP Turan-specific modifier-emitter plugs into the same surface without any Building base extension.

#### 4.7.3 Stacking rule

Per design Q3 (Open Space 2026-05-14, lead's 2026-05-15 confirmation):

- Default `modifier_stacks = false` (in BalanceData per `building_stats.gd:modifier_stacks`).
- With `stacks=false` and a modifier already registered, additional `register_extraction_modifier` calls return false silently. **First-registered-wins.** Subsequent modifier-emitters within range still place as buildings; they just do not contribute to the mine's effective yield.
- With `stacks=true` (post-MVP forward-compat; not exercised at MVP), modifiers compound multiplicatively in `effective_yield_per_trip_x100`.

The stacking policy is read from the FIRST registered modifier's BalanceData entry. At MVP this is consistent because all modifier-emitters of the same kind share the policy; at post-MVP scale where mixed-stacking-policy modifiers might register, the first-registered policy wins by precedent (predictable, not surprising).

#### 4.7.4 Modifier-emitter Building convention

A modifier-emitter Building subclass:

- Declares `kind = &"<subclass-name>"` via dual-init constant (same as any Building subclass — see §4.6 for the convention).
- Does NOT declare `resource_kind` (it does not produce a resource).
- Does NOT register with `ResourceSystem.register_node` (the ResourceNode it modifies is already the canonical registry entry).
- Does NOT declare ResourceNode-shape gather schema fields (no `is_gatherable`, no `reserves_x100`, no `max_slots`, no `yield_per_trip_x100`). The `click_handler._is_resource_node_shaped` check correctly excludes modifier-emitters from gather routing.
- In `_on_placement_complete`: finds the nearest matching ResourceNode within `modifier_radius_m` (from BalanceData), calls `target_node.register_extraction_modifier(self)`. Wave-1B Ma'dan iterates the `&"resource_nodes"` SceneTree group (added in wave-1B base `_ready`) for this discovery.
- Implements `yield_multiplier_x100() -> int` returning the BalanceData-driven multiplier (with defensive fallback per Khaneh/Mazra'eh precedent).

#### 4.7.5 Navmesh-obstacle convention reinforces cultural framing

Per lead's 2026-05-15 ratification (Wave 1B Commit 1 review): modifier-emitter Buildings carry a `NavigationObstacle3D` so workers route AROUND them — a structural worksite, not soft terrain. **Contrast with resource-producing Buildings** like Mazra'eh, which deliberately have NO obstacle so workers walk ONTO the farm. The contrast is mechanically functional (Mazra'eh's gather geometry needs workers to step onto the tile; Ma'dan's gather geometry has workers approach the mine itself, with Ma'dan adjacent to it) AND culturally aligned (Mazra'eh's *dehqan* stewardship implies the field IS walked; Ma'dan's labor-organization frame implies the operation IS routed around).

The pattern: in future Building subclasses, the obstacle / no-obstacle choice should reflect the building's cultural-mechanical category. Anchor-frame buildings tied to soft terrain (farms, perhaps future orchards): no obstacle. Modifier-frame or structural-frame buildings (Ma'dan, future Atashkadeh, fortifications): obstacle. Documented here for the precedent.

---

## 5. Dropoff API — `IDropoffTarget` Protocol

### 5.1 Duck-typed protocol (no GDScript interface keyword)

GDScript has no formal `interface`. We document the protocol here and rely on dynamic dispatch + a one-line type comment at each implementer.

**Required method signature** (anything implementing `IDropoffTarget` must expose):

```gdscript
## IDropoffTarget protocol — see RESOURCE_NODE_CONTRACT.md §5
func deposit(resource_kind: StringName, amount: int, worker: Unit) -> void: ...

## Returns the world position the worker should walk to before depositing.
func get_deposit_position() -> Vector3: ...
```

### 5.2 MVP implementation

Only `Throne` implements the protocol for MVP. Every `ResourceNode.get_dropoff_target()` returns the player's Throne instance.

```gdscript
# buildings/throne.gd
class_name Throne extends Building
## Implements IDropoffTarget — see RESOURCE_NODE_CONTRACT.md §5

func deposit(resource_kind: StringName, amount: int, worker: Unit) -> void:
    ResourceSystem.add(resource_kind, amount)
    EventBus.resources_deposited.emit(worker.unit_id, resource_kind, amount, SimClock.tick)

func get_deposit_position() -> Vector3:
    return $DepositMarker.global_position
```

### 5.3 Future upgrade path

If a future entity (Mazra'eh-as-grain-depot, forward depot building, etc.) becomes a dropoff target, it adds the same two methods plus the `## Implements IDropoffTarget` comment. The corresponding `ResourceNode.get_dropoff_target()` returns the new instance instead of the Throne. Zero changes elsewhere — the worker's `Gathering` and `Deposit` states see the same surface. Constraint #3 from R1 (no Throne baked into worker code) is satisfied at zero MVP runtime cost.

For MVP, both `MineNode` and `Mazra'eh` return the Throne from `get_dropoff_target`. Whether a Tier 2 Mazra'eh becomes its own grain depot is a balance/strategy decision deferred to the design chat.

---

## 6. EventBus Signals

| Signal | Emitter | Tick phase | API payload | NDJSON telemetry payload |
|---|---|---|---|---|
| `extract_started` | `MineNode` or `Mazra'eh` from `begin_extract` | called within worker's `_sim_tick` ⇒ `combat` phase | `(worker_id: int, node_id: int, tick: int)` | same — all fields serializable |
| `extract_completed` | `ResourceNode._sim_tick` when worker hits YIELD_READY | `combat` phase | `(worker_id: int, node_id: int, yield_amount: int, tick: int)` | same |
| `resources_deposited` | `IDropoffTarget.deposit` | `combat` phase | `(worker_id: int, resource_kind: StringName, amount: int, tick: int)` | same |
| `resource_node_depleted` | `ResourceNode._sim_tick` (deferred via flag, see §3.3) | `cleanup` phase | `(node: ResourceNode)` | MatchLogger sink reads `node.node_id`, `node.resource_kind`, `node.global_position` from the ref — see note below |

All four are write-shaped. They are added to `EventBus._SINK_SIGNALS` per Simulation Contract §7 so `MatchLogger` (Phase 6) sinks them automatically — flagging this as a one-line follow-up patch on `event_bus.gd` for engine-architect at sign-off.

**`resource_node_depleted` dual-mode payload (v1.1.1):** the signal passes the `ResourceNode` ref directly (not an id). In-game consumers (AI re-tasking, world-builder depletion visual handler, threat assessment) benefit from immediate ref access with no `ResourceSystem.get_node_by_id()` lookup required. NDJSON serialization (Testing Contract §2.3) does not receive the ref — `MatchLogger`'s sink handler destructures the ref into serializable fields at point of logging:

```gdscript
# In MatchLogger's sink handler for resource_node_depleted:
func _on_resource_node_depleted(node: ResourceNode) -> void:
    _write({
        "type": "resource_node_depleted",
        "tick": SimClock.tick,
        "sim_time": SimClock.sim_time,
        "node_id": node.node_id,
        "resource_kind": node.resource_kind,
        "position": { "x": node.global_position.x, "z": node.global_position.z },
    })
```

This separation is intentional: the API payload optimizes for in-game consumers; the telemetry payload optimizes for NDJSON serialization. World-builder owns this signal; payload shape locked by world-builder in §3.

---

## 7. `BalanceData.tres` Keys

Per Testing Contract §1.1, all tunable numbers live on `BalanceData`. Resource node tunables sit in a new `EconomyConfig.resource_nodes` sub-resource:

```gdscript
class_name ResourceNodeConfig extends Resource
@export var mine_initial_stock: int = 1500           # MineNode.current_stock at spawn
@export var mine_max_workers: int = 2                # MineNode.max_workers
@export var coin_yield_per_trip: int = 10            # carried per full load
@export var coin_yield_per_tick: int = 1             # decrement applied during tick_extract
@export var grain_yield_per_trip: int = 8            # carried per full load (Mazra'eh). SUPERSEDED: Room A ratified 2 Grain/trip (02g §2.4, 2026-05-14, postdates this draft); balance.tres carries the ratified 2 since the 2026-06-08 SSOT wiring (wave B1). The .tres is authoritative per this section's own "numbers are starting points" rule.
@export var grain_yield_per_tick: int = 1            # accumulated per tick of gathering
@export var farm_max_workers: int = 1                # Mazra'eh.max_workers (default 1: tend the field; balance-engineer tunable)
@export var trip_full_load_ticks: int = 60           # 2s at 30Hz; capacity equivalent
```

The `farm_max_workers = 1` default reflects "tend the field" mental model (one farmer per farm) and a deliberate asymmetry from `mine_max_workers = 2` (mines support a small team). Balance-engineer can flip either independently. If playtest data shows farms feel under-utilized at 1 worker, raising it to 2 is a `BalanceData.tres` edit, no code change.

Numbers are starting points, not contracts — balance-engineer tunes via `data/balance.tres`. `gameplay-systems` adds the keys; `balance-engineer` sets the values per Testing Contract §1.

The keys live under `BalanceData.economy.resource_nodes.*`. `MineNode._ready()` reads its starting stock from `BalanceData.economy.resource_nodes.mine_initial_stock` and assigns to `current_stock` via `_set_sim` once. Per-tick yields are read fresh each `tick_extract` (cheap; no caching needed at MVP scale).

---

## 8. Worked Example: Kargar Mines Coin → Deposits at Throne

The example below traces a full gather→deposit cycle for a coin mine using the SHIPPED three-call API (v1.2.0 §4). The grain path is identical except for `kind = &"grain"`, the `Mazra'eh` target node (extends Building, duck-types the API — see §4.5), and the BalanceData yield/dwell numbers — same EventBus emissions, same state transitions, same dropoff. World-builder to extend with mine-side or farm-side visual/proxy specifics if needed.

```
tick T0    Player right-clicks coin mine M1 with one kargar selected.
             Input layer: unit.replace_command(&"gather", { target_node: M1 }).
             FSM transition_to(&"moving") routes the kargar toward M1.

tick T1-T6   UnitState_Moving drives the MovementComponent toward M1.position.

tick T7    Path consumed; arrival latched. UnitState_Moving completes,
             pops the residual Gather command, transitions to UnitState_Gathering.
             UnitState_Gathering._sim_tick():
               M1.request_extract(kargar.unit_id) -> true (slot 1/1 occupied).
               EventBus.extract_started.emit(kargar.unit_id, M1.node_id, 7).
               _dwell_remaining_ticks = M1.extract_ticks (60 at MVP).

tick T8-T67  Each tick: _dwell_remaining_ticks counts down on the state.
              The node has no _sim_tick — it's idle through the dwell.
              60 ticks = 2s at SIM_HZ=30.

tick T68    _dwell_remaining_ticks reaches 0.
              payload: Dictionary = M1.complete_extract(kargar.unit_id)
                returns { kind: &"coin", amount_x100: 1000 }  (10 Coin).
              M1.reserves_x100 decrements by 1000.
              kargar._carry_kind / _carry_amount_x100 written by the state.
              EventBus.extract_completed.emit(kargar.unit_id, M1.node_id, 1000, 68).
              State transitions to UnitState_Returning.
              UnitState_Gathering.exit(): M1.release_extract — slot already
                freed inside complete_extract, idempotent no-op here.

tick T69-T74  UnitState_Returning drives the kargar toward the Throne via
              ResourceSystem.dropoff_for_team or a scene-tree lookup.

tick T75    Arrival at Throne. UnitState_Returning calls
              throne.deposit(kargar._carry_kind, kargar._carry_amount_x100, kargar)
              -> throne.deposit(&"coin", 1000, kargar).
              ResourceSystem.change_resource(team, &"coin", +1000,
                                              &"gather_deposit", kargar).
              EventBus.resources_deposited.emit(kargar.unit_id, &"coin", 1000, 75).
              kargar._carry_kind = &"", _carry_amount_x100 = 0.
              UnitState_Returning.transition_to_next() — queue empty, Idle.

[loop: kargar would normally have a follow-up gather queued via Shift-click,
 or auto-return logic per §9 #1 once design resolves it]
```

**Grain path variant (Mazra'eh, wave 1A 2026-05-14):** the same trace with three differences — (a) `kind = &"grain"`; (b) `extract_ticks = 90` (3s dwell, "tending the field"); (c) `yield_per_trip_x100 = 200` (2 Grain per trip). Mazra'eh's `complete_extract` is a no-op on the `reserves_x100` decrement because `reserves_x100 = -1` (infinite, per §1.5). All EventBus emissions, state transitions, and dropoff calls are identical to the coin path. The duck-typed three-call API (§4.5) means UnitState_Gathering does not branch on the target's class.

---

## 9. Open Questions / Design-Chat Escalations

1. **Auto-retarget policy when a worker's gather node depletes mid-cycle.** Spec doesn't say. Should the worker (a) idle, (b) auto-find the nearest same-resource node, (c) return any half-load to dropoff first then idle? Modern RTS QoL says (b); strict-determinism preference says (a). Default in this contract: (a) idle. Same default applies when `begin_extract` returns false at `enter` (§4.2). Flagged for design.

2. **Ruins clearing:** Do depleted `MineNode` ruins stay permanently, or can workers later clear them (removing the `NavigationObstacle3D` and reclaiming the cell for building)? Escalated to `QUESTIONS_FOR_DESIGN.md`. This affects map control decisions and late-game expansion strategy — a design call, not an implementation choice.

3. **Multi-worker mine slots:** `MineNode.max_workers = 2` is a starting value. Does the design want saturation (diminishing returns per extra worker after some threshold) or hard caps? Currently hard cap — second worker is simply rejected if both slots occupied. Escalated if the design chat wants saturation mechanics.

4. **Snowball protection clarification (carry-over from Sync 4 R1 critique).** Not directly resource-node, but `EventBus.resource_node_depleted` is the signal we'd wire snowball "destroying enemy economy" Farr drains to. Design chat needs to define "broken economy" before that wiring is real.

---

### 9.X Resolved

- *(2026-04-30, design chat)* **Grain mechanic — Path 2 ratified.** Workers gather grain from `Mazra'eh` farms via the standard `ResourceNode` API. Reasoning: workers are foundational to the RTS archetype; passive grain would have stripped that role for one resource type and broken the worker's centrality. Div faction may receive different economics post-MVP — separate research track. Patch applied in v1.1: §1.1 (two MVP subclasses), §1.4 (Mazra'eh extends `ResourceNode`), §1.5 (rationale for `current_stock = -1`), §2.3 (Mazra'eh self-registration), §3.4 (lifecycle restored), §6 (EventBus emitter language), §7 (`grain_yield_per_trip`, `grain_yield_per_tick`, `farm_max_workers` keys added).

- *(2026-05-14, Phase 3 session 2 Room A Open Space — wave 1A SSOT-fix patch)* **§4 consumer-facing API rewritten to match shipped code.** The original v1 contract spec'd `begin_extract` / `tick_extract` / `release_extract` with an `ExtractResult` enum. The wave-1A implementation (2026-05-08, see ARCHITECTURE.md §6 v0.20.2) deliberately walked away from that design — the shipped API is `request_extract` / `complete_extract` / `release_extract` with `Dictionary` payloads, and the dwell counter lives on `UnitState_Gathering` (`_dwell_remaining_ticks`), not on the node. Rationale documented in `game/scripts/world/resource_nodes/resource_node.gd` lines 12–33: dwell-on-state-side, payload-on-completion, no per-worker progress dict on the node, no node `_sim_tick`. **The §9 2026-05-14 rule (SSOT prose contradictions are BLOCKING at wave-close)** made this patch a wave-1A blocker. v1.2.0 §4 + §8 now describe the shipped semantics. Also added §4.5 documenting Mazra'eh as the first non-`ResourceNode` consumer of the duck-typed three-call API — Mazra'eh extends `Building` (option iii from Room A), and `UnitState_Gathering`'s `has_method(&"request_extract")` filter at `unit_state_gathering.gd:143` is the discovery seam. The cultural-framing rationale for Mazra'eh's longer dwell (90 ticks vs MineNode's 60) lives in `mazraeh.gd`'s header and is NOT load-bearing for the API contract. **Caveat (RESOLVED at 91f48ad):** §1.4 + §3.4 corrections (Mazra'eh extends Building, HP/destruction is wave-1C) landed in world-builder's `91f48ad` follow-up patch.

- *(2026-05-14, Phase 3 session 2 — wave 1A post-close fix-up)* **v1.2.1: `ResourceSystem.register_node` signature changed from `(node)` to `(node, kind: StringName)`.** v1.2.0 §4.5 sketched Mazra'eh with `kind = &"grain"` as a field, and the v1.2.0 `register_node` impl read kind from `node.kind`. Both were wrong — the actual Mazra'eh has `kind = &"mazraeh"` (Building kind), and the v1.2.0 registry would have stored Mazra'eh under `&"mazraeh"`, NOT `&"grain"`. A future AI consumer doing `ResourceSystem.get_nodes_of_kind(&"grain")` would have missed every Mazra'eh. World-builder caught the §4.5 prose error in their post-commit review of v1.2.0 (`fd731e9`); the deeper registry-key bug surfaced from the same finding. **Caught pre-consumption** — no wave-1A consumer queries the registry; bug was latent. v1.2.1 fix:
  - `register_node(node, kind: StringName)` — caller passes the RESOURCE kind explicitly. Decouples registered-kind from node.kind, eliminates the field-name ambiguity at the seam between MineNode (kind IS resource kind) and Mazra'eh-as-Building (kind is Building kind). Two new tests cover the decoupling: `test_register_node_stores_under_explicit_kind`, `test_register_node_decouples_node_kind_from_registered_kind`.
  - `unregister_node(node)` signature unchanged — still scans all buckets, no kind argument needed. Caller's death/teardown path doesn't have to remember the registered kind. One new test affirms this: `test_unregister_node_no_kind_arg_finds_node_under_any_kind`.
  - `mazraeh.gd:128` call-site updated to `ResourceSystem.register_node(self, Constants.KIND_GRAIN)`.
  - §4.5 prose corrected: `kind = &"mazraeh"` (Building kind) + explicit Constants.KIND_GRAIN at register-call.
  - Discovered by: world-builder's post-commit §4.5 review (proper review discipline catching real bugs, not just prose). Captured for retro as a Manifesto Principle 1 (Truth-Seeking) success: empirical verification of contract claims against shipped code surfaces real issues even when the design has been ratified in Open Space. Cites the §9 2026-05-14 "SSOT prose contradictions are BLOCKING at wave-close" rule retroactively — the v1.2.0 prose error WAS a SSOT contradiction (doc claimed `kind = &"grain"`, code had `kind = &"mazraeh"`), and the deeper registry-key bug was the consequence.

- *(2026-05-14, Phase 3 session 2 — wave 1A close-review trio findings, v1.2.2 schema alignment)* **§4.5 expanded to declare all 5 shipped Mazra'eh fields + §4.6 introduces the kind-vs-resource_kind separation pattern.** Arch-reviewer BLOCK-A (priority-0 cross-cutting) at close-review caught that `click_handler.gd:447` checks `&"is_gatherable" in n` AND `has_method(&"request_extract")` — Mazra'eh missing the `is_gatherable` field caused right-click-on-Mazra'eh to fall through silently. Arch-reviewer's PRIORITY-LOW preferred path was the `resource_kind` separate-field design (option (i) from my v1.2.1 fix-up discussion), which lead ratified as the canonical shape — world-builder shipped at `6d73889` adding all 5 fields: `is_gatherable: bool = true`, `resource_kind: StringName = Constants.KIND_GRAIN`, `reserves_x100: int = -1`, `max_slots: int = 1`, `yield_per_trip_x100: int = 200`. Plus `extract_ticks: int = 90` (already public but called out in §4.5 alongside the new five). World-builder also folded the call-site refinement: `register_node(self, resource_kind)` reads from the field, not the literal — the field is the canonical SSOT for "what resource does this building produce?" v1.2.2 §4.5 documents this state. v1.2.2 §4.6 introduces the kind-vs-resource_kind separation as a general convention for resource-producing Building subclasses (Mazra'eh today, future Atashkadeh / Caravanserai / Forester's Hut / Fishery post-MVP). Cites Manifesto Principle 8 (Separation of Concerns) — Building-identity (`kind`) and Resource-identity (`resource_kind`) are distinct concerns; conflating them is what produced the v1.2.0 registry-key bug. The option-(ii) explicit-kind register_node signature shipped at `2695fea` remains correct and complementary — the call site delegates to the field, the registry accepts the explicit kind, both layers serve different consumers (introspection vs registry bucket).

- *(2026-05-14, Phase 3 session 2 — wave 1A re-review BLOCK-C, v1.2.3 surgical correction)* **§4.5 `is_gatherable` default corrected from `true` to `false` to match shipped code.** v1.2.2 introduced a NEW SSOT-prose-vs-shipped-code contradiction: §4.5 example (line 377) + prose (line 399) wrote `is_gatherable: bool = true` reflecting v1.2.2's draft understanding that "Mazra'eh is ready immediately at construction-complete." But world-builder's `3183c7c` (the wave-1A re-review fix-wave) flipped the shipped default to `false`, with a flip-to-true inside `_on_placement_complete` — establishing the default-false invariant as a forward-compat lock against gather-during-construction for future Building subclasses (wave 1C will move the flip to `_on_construction_complete` once construction timer + HP ship). Arch-reviewer BLOCK-C at re-review caught the prose-vs-code drift; same §9 2026-05-14 SSOT-rule fired as BLOCK-B. v1.2.3 fix: §4.5 example shows `is_gatherable: bool = false` with comment documenting the flip-on-placement pattern; §4.5 prose explains the default-false invariant. Regression test locked at `test_mazraeh.gd:388` (`test_mazraeh_is_gatherable_flips_on_placement`). **Process retro signal:** v1.2.2 prose was written against the shipped code at the moment of v1.2.2's authoring (which DID have `is_gatherable = true`), but world-builder's `3183c7c` flipped the shipped state mid-wave; v1.2.2 went stale before it could be re-verified at re-review. This is a new manifestation of the SSOT-discipline pattern: prose authored against shipped state can go stale if the shipped state moves before the next review pass. The §9 rule "SSOT prose contradictions BLOCKING at wave-close" handled this correctly; the re-review caught it within the same wave. Cites Manifesto Principle 1 (Truth-Seeking) operating recursively — even contract prose that was correct at authoring needs re-verification when the underlying code shifts.

---

*Status: v1.2.3 ratified. §1–§3 by world-builder; §4–§7 by gameplay-systems; §8 by gameplay-systems; §9 shared. v1 signed off by both authors 2026-04-30. v1.1 patch applied 2026-04-30 in response to design chat resolving §9 #4 to Path 2 (workers gather grain). v1.1.1 patch applied 2026-04-30: §6 `resource_node_depleted` updated from single-payload to dual-mode — Node ref for in-game consumers, MatchLogger sink destructures to serializable fields for NDJSON telemetry. Option (a) chosen per engine-architect's Convergence Review finding. v1.2.0 (2026-05-14, gp-sys) — §4 SSOT-fix to align consumer-facing API with shipped code + §4.5 Mazra'eh-as-duck-typed-Building documentation. v1.2.0 §1.4 + §3.4 caveat patched at `91f48ad` (world-builder). v1.2.1 (2026-05-14, gp-sys) — surgical patch on ResourceSystem.register_node signature to take explicit kind parameter; v1.2.0 §4.5 prose corrected (Mazra'eh's `kind` is the Building kind `&"mazraeh"`, NOT the resource kind `&"grain"`). v1.2.2 (2026-05-14, gp-sys) — §4.5 schema declaration expanded to all 5 shipped fields after world-builder's `6d73889` (BLOCK-A) shipped the field shape; §4.6 introduced documenting the kind-vs-resource_kind separation pattern for resource-producing Building subclasses. v1.2.3 (2026-05-14, gp-sys) — re-review BLOCK-C: §4.5 example + prose `is_gatherable` default corrected from `true` to `false` to match shipped code post-`3183c7c`; regression-test-locked at `test_mazraeh.gd:388`.*
