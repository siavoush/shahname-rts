---
title: Resource Node Schema Contract
type: contract
status: ratified
version: 1.2.0
owner: world-builder
summary: Resource gathering — ResourceNode hierarchy (MineNode + Mazra'eh-as-Building-subclass via duck-typing), three-call extract API (request_extract / complete_extract / release_extract), IDropoffTarget protocol, fertile-zone placement, EventBus signals, BalanceData keys.
audience: all
read_when: working-on-resources-mines-farms-gather-or-worker-ai
prerequisites: [MANIFESTO.md, SIMULATION_CONTRACT.md, STATE_MACHINE_CONTRACT.md]
ssot_for:
  - ResourceNode abstract base + MineNode subclass + Mazra'eh duck-typed Building subclass
  - three-call extract API (request_extract / complete_extract / release_extract) with Dictionary payload
  - state-side dwell counter pattern (extract_ticks field on node, countdown on UnitState_Gathering)
  - IDropoffTarget duck-typed protocol
  - fertile-zone placement (Array[Vector2i] map metadata, WorldGrid.is_fertile)
  - NavigationObstacle3D ownership (mine scenes carry it; farms don't)
  - depletion lifecycle (queue_free.call_deferred for mines; building-destruction for farms)
  - four resource-node EventBus signals
  - resource_node_depleted dual-mode payload (API ref + telemetry destructure)
  - ResourceNodeConfig keys (mine + farm yield/stock/workers)
references: [SIMULATION_CONTRACT.md, STATE_MACHINE_CONTRACT.md, TESTING_CONTRACT.md]
tags: [resources, mines, farms, gather, navigation, fertile-tiles, signals]
created: 2026-04-30
last_updated: 2026-05-14
provenance: Outcome of Sync 4 — joint Constraint Negotiation between world-builder and gameplay-systems. Path 2 (workers gather grain) ratified by design chat 2026-04-30. Convergence Review revisions 2026-05-01. v1.2.0 wave-1A patch (2026-05-14) — §4 SSOT-fix to align consumer-facing API prose with shipped code (the wave-1A implementation walked away from the v1 begin_extract / tick_extract / ExtractResult-enum shape; this contract version documents the actual three-call API in flight) + Mazra'eh-as-duck-typed-Building-subclass shape from Room A Open Space.
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

### 1.4 `Mazra'eh` (grain) — `ResourceNode` subclass, worker-gathered

`Mazra'eh` is the player-built farm building. It extends `ResourceNode` and implements the same gather/extract API as `MineNode` so the worker's `Gathering` state treats both identically. The fertile-zone placement validation (§2.2) restricts where it can be built; the Building system owns its construction and HP.

```gdscript
# buildings/mazraeh.gd
class_name Mazraeh extends ResourceNode
```

- `resource_kind = &"grain"`
- `current_stock = -1` (infinite — a healthy farm yields indefinitely; see §1.5 below)
- `max_workers` from `BalanceData.economy.resource_nodes.farm_max_workers` (see §7; default 1)
- `is_gatherable = false` while under construction, set `true` when the construction-complete signal fires, set `false` permanently when the building takes fatal damage
- No `NavigationObstacle3D` on the Mazra'eh — workers walk onto the farm tile to gather (mines are obstacles, farms are walk-on)

**Rationale (per design chat resolution 2026-04-30):** workers gathering grain preserves the foundational RTS archetype where workers drive the economy. The earlier passive-generator alternative would have stripped that role for one resource type, breaking the worker's centrality and creating an awkward asymmetry between Coin (worker-gathered) and Grain (auto-generated). Worker-gathered grain is consistent with `01_CORE_MECHANICS.md` §3 ("Workers gather resources from map nodes" applied uniformly). The Div faction may receive different economics post-MVP — that is a separate design track.

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

### 3.2 `NavigationObstacle3D` ownership

Each `MineNode` scene includes a `NavigationObstacle3D` child configured at authoring time. **No runtime code adds, removes, or resizes this obstacle.** When the mine depletes:

- The obstacle stays active — depleted mines remain physically impassable.
- This is intentional: derelict mine ruins are navigational obstacles, consistent with the Shahnameh setting.

**Design escalation (ruins clearing):** Whether workers can later "clear" depleted mine ruins (removing the obstacle, reclaiming the cell) is a gameplay question outside this contract's scope. Escalated to `QUESTIONS_FOR_DESIGN.md`. If ruins clearing ships, it will update this contract in a future sync.

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

### 3.4 Mazra'eh (`FarmNode`) lifecycle

- `is_gatherable` starts `false` while under construction
- Set to `true` by the Building system's construction-complete signal handler. Mazra'eh self-registers with `ResourceSystem` at the same moment (§2.3)
- Set to `false` permanently when the building takes fatal damage (HealthComponent zero)
- On destruction, the Mazra'eh emits `EventBus.resource_node_depleted.emit(self)` (deferred to `cleanup` phase via the same `_pending_depletion` pattern as `MineNode` §3.3) and deregisters from `ResourceSystem`. Consumers do not distinguish between mine-out-of-stock and farm-destroyed — both are "this node is no longer a viable target." The building then `queue_free`s normally; any worker still holding a ticket on this Mazra'eh sees `INVALID` next tick and transitions to `Idle` per §4.2

Workers can walk onto the Mazra'eh's tile to gather — there is no `NavigationObstacle3D` on the farm. Destruction does not leave a navmesh-blocking ruin (unlike `MineNode` per §3.2); the farm is fully cleaned up on destruction.

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

var kind: StringName = &"grain"             # duck-type field for ResourceSystem registry
var reserves_x100: int = -1                  # -1 sentinel = infinite (per §1.5); same field name as ResourceNode base
var max_slots: int = 1                       # from BalanceData.economy.resource_nodes.farm_max_workers
var extract_ticks: int = 90                  # from BalanceData — "tending" dwell, 3s at 30Hz
var yield_per_trip_x100: int = 200           # from BalanceData — 2 Grain per trip
var is_gatherable: bool = false              # flips true at construction-complete
# (slot bookkeeping replicated from ResourceNode.gd, OR composed via small helper)

func request_extract(unit_id: int) -> bool: ...   # see ResourceNode shape
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
- `is_gatherable = false` while under construction; flips `true` when the building system's construction-complete signal fires.
- Mazra'eh self-registers with `ResourceSystem.register_node(self)` at construction-complete (the wave-1A API, see Decision 4 above + §2.3).
- No `NavigationObstacle3D` — workers walk ONTO the farm tile to gather (§3.2).

The cultural-framing rationale for the long dwell lives in `mazraeh.gd`'s header — the *dehqan* (دهقان, landed cultivator) model from Ferdowsi's Shahnameh — and is referenced here for visibility but is NOT load-bearing for the API contract. Loremaster reviews the cultural framing at wave-close.

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
@export var grain_yield_per_trip: int = 8            # carried per full load (Mazra'eh)
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

- *(2026-05-14, Phase 3 session 2 Room A Open Space — wave 1A SSOT-fix patch)* **§4 consumer-facing API rewritten to match shipped code.** The original v1 contract spec'd `begin_extract` / `tick_extract` / `release_extract` with an `ExtractResult` enum. The wave-1A implementation (2026-05-08, see ARCHITECTURE.md §6 v0.20.2) deliberately walked away from that design — the shipped API is `request_extract` / `complete_extract` / `release_extract` with `Dictionary` payloads, and the dwell counter lives on `UnitState_Gathering` (`_dwell_remaining_ticks`), not on the node. Rationale documented in `game/scripts/world/resource_nodes/resource_node.gd` lines 12–33: dwell-on-state-side, payload-on-completion, no per-worker progress dict on the node, no node `_sim_tick`. **The §9 2026-05-14 rule (SSOT prose contradictions are BLOCKING at wave-close)** made this patch a wave-1A blocker. v1.2.0 §4 + §8 now describe the shipped semantics. Also added §4.5 documenting Mazra'eh as the first non-`ResourceNode` consumer of the duck-typed three-call API — Mazra'eh extends `Building` (option iii from Room A), and `UnitState_Gathering`'s `has_method(&"request_extract")` filter at `unit_state_gathering.gd:143` is the discovery seam. The cultural-framing rationale for Mazra'eh's longer dwell (90 ticks vs MineNode's 60) lives in `mazraeh.gd`'s header and is NOT load-bearing for the API contract. **Caveat:** §1.4 still says `Mazraeh extends ResourceNode` and §3.4 still describes Mazra'eh's depletion-on-fatal-damage path — both are world-builder-owned sections (§1–§3) and will need a follow-up patch from world-builder when wave 1A's Mazra'eh scene + class file ship and HP arrives at wave 1C. Flagged for world-builder's wave-1A close report.

---

*Status: v1.1.1 ratified. §1–§3 by world-builder; §4–§7 by gameplay-systems; §8 by gameplay-systems; §9 shared. v1 signed off by both authors 2026-04-30. v1.1 patch applied 2026-04-30 in response to design chat resolving §9 #4 to Path 2 (workers gather grain). v1.1.1 patch applied 2026-04-30: §6 `resource_node_depleted` updated from single-payload to dual-mode — Node ref for in-game consumers, MatchLogger sink destructures to serializable fields for NDJSON telemetry. Option (a) chosen per engine-architect's Convergence Review finding. No second review round needed.*
