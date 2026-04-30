# Resource Node Schema Contract

*Outcome of Sync 4 between world-builder and gameplay-systems.*
*Status: **1.1.0** ratified 2026-04-30. Path 2 (workers gather grain) ratified by design chat 2026-04-30.*
*Created: 2026-04-30*

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

### 4.1 The contract from the consumer's side

The worker's `Gathering` state holds two refs: a `ResourceNode` (target) and nothing else. Carry state lives on the worker. The state issues exactly three calls into the node across its lifetime:

1. `node.begin_extract(self) -> bool` from `enter()`. Returns false if the node is depleted, full, or invalid — state immediately transitions to `Idle` (or design-defined retarget; see §9 #1).
2. `node.tick_extract(self, dt) -> ExtractResult` once per `_sim_tick`. Branch on the enum, never on the subclass type.
3. `node.release_extract(self)` from `exit()`. Single deterministic cleanup point. Always called, even on death.

The `Gathering` state has no knowledge of mines, farms, depletion semantics, fertile zones, or building lifecycles. All that lives behind the three method calls.

### 4.2 Gathering state skeleton

```gdscript
# units/states/gathering.gd
class_name Gathering extends State

const id: StringName = &"gathering"
const interrupt_level: int = InterruptLevel.COMBAT  # damage interrupts gathering

var _node: ResourceNode = null

func enter(prev: State, ctx: Unit) -> void:
    _ctx = ctx
    var payload: Dictionary = ctx.command_queue.peek().payload
    _node = payload.get(&"node")
    if _node == null or not _node.begin_extract(ctx):
        ctx.fsm.transition_to(&"idle")   # see §9 #1 (retarget policy)

func _sim_tick(dt: float, ctx: Unit) -> void:
    match _node.tick_extract(ctx, dt):
        ResourceNode.ExtractResult.GATHERING:
            pass   # node has called ctx.set_carry(...) if progress was made
        ResourceNode.ExtractResult.YIELD_READY:
            var dropoff := _node.get_dropoff_target(ctx)
            ctx.append_command(&"deposit", { target: dropoff })
            ctx.fsm.transition_to_next()
        ResourceNode.ExtractResult.NODE_DEPLETED, ResourceNode.ExtractResult.INVALID:
            ctx.fsm.transition_to(&"idle")   # see §9 #1
        ResourceNode.ExtractResult.NODE_FULL:
            ctx.fsm.transition_to(&"idle")   # rare; another worker took the slot first

var _ctx: Unit = null   # stored in enter(), cleared in exit()

func exit() -> void:
    if _node != null and is_instance_valid(_node) and _ctx != null:
        _node.release_extract(_ctx)
    _node = null
    _ctx = null
```

What this demonstrates, in order:
- One polymorphic call surface — the state has no idea whether `_node` is a mine or a farm-building.
- All gather-progress mutation happens inside `tick_extract` (which calls `ctx.set_carry(...)` per §1.2 and §4.3). The state never directly mutates carry.
- Dropoff target obtained via `_node.get_dropoff_target(ctx)` — no `Throne` reference in the state.
- State machine completion uses `transition_to_next()` and `append_command` per State Machine Contract §2.5 / §3.4.
- `exit()` is the single cleanup point — releases the slot deterministically. Per State Machine Contract §3.2, `exit` is called on every leave path including death (handled by §4 of that contract).

### 4.3 Worker carry mutation rule

The node calls `worker.set_carry(kind: StringName, amount: int)`. This is a sanctioned cross-component method call per Simulation Contract §1.3 — the *worker* exposes the method, the worker's `set_carry` internally calls `_set_sim(&"_carry_kind", kind)` and `_set_sim(&"_carry_amount", amount)`. The node never reaches into worker fields directly.

```gdscript
# units/worker.gd  (gameplay-systems)
func set_carry(kind: StringName, amount: int) -> void:
    _set_sim(&"_carry_kind", kind)
    _set_sim(&"_carry_amount", amount)
```

The worker's `Deposit` state (a sibling state, not specified in this contract — lives in the worker's state set) reads `_carry_kind` and `_carry_amount` after the `move-to-dropoff` step completes, calls `dropoff.deposit(_carry_kind, _carry_amount)`, then resets carry to zero via its own `set_carry(&"", 0)` and transitions onward.

### 4.4 What the state does NOT do

- Does not call `ctx.set_carry()` itself. That's the node's job through `tick_extract`.
- Does not look up the next node when one depletes. Auto-retarget is escalated to design (§9 #1) and lives in `ResourceSystem` if/when it ships, not in this state.
- Does not validate the dropoff. It trusts `get_dropoff_target` to return a live `Node3D` implementing the deposit protocol.

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

| Signal | Emitter | Tick phase | Payload |
|---|---|---|---|
| `extract_started` | `MineNode` or `Mazra'eh` from `begin_extract` | called within worker's `_sim_tick` ⇒ `combat` phase | `(worker_id: int, node_id: int, tick: int)` |
| `extract_completed` | `ResourceNode._sim_tick` when worker hits YIELD_READY | `combat` phase | `(worker_id: int, node_id: int, yield_amount: int, tick: int)` |
| `resources_deposited` | `IDropoffTarget.deposit` | `combat` phase | `(worker_id: int, resource_kind: StringName, amount: int, tick: int)` |
| `resource_node_depleted` | `ResourceNode._sim_tick` (deferred via flag, see §3.3) | `cleanup` phase | `(node: ResourceNode)` |

All four are write-shaped. They are added to `EventBus._SINK_SIGNALS` per Simulation Contract §7 so `MatchLogger` (Phase 6) sinks them automatically — flagging this as a one-line follow-up patch on `event_bus.gd` for engine-architect at sign-off.

The `resource_node_depleted` payload is the node ref itself rather than an id because consumers (UI, AI threat assessment, balance telemetry) typically need to query the node's `resource_kind` and position immediately. World-builder owns this signal; payload shape locked by world-builder in §3.

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

The example below traces a full gather→deposit cycle for a coin mine, mirroring State Machine Contract §8. The grain path is identical except for `resource_kind = &"grain"`, the `Mazra'eh` target node, and the BalanceData yield/capacity numbers — same EventBus emissions, same state transitions, same dropoff. World-builder to extend with mine-side or farm-side visual/proxy specifics if needed.

```
tick T0    Player right-clicks coin mine M1 with one kargar selected.
             Input layer: unit.replace_command(&"gather", { node: M1 }).
             FSM transition_to_next() pops Gather → routes to Moving (path to M1).

tick T1    Moving.enter() issues request_move(M1.position). Path arrives next tick.

tick T7    Path consumed. Moving completes, calls transition_to_next().
             Pops residual Gather command → transitions to Gathering.
             Gathering.enter():
               M1.begin_extract(kargar) -> true (slot 1/2 occupied).
               EventBus.extract_started.emit(kargar.unit_id, M1.node_id, 7).

tick T8-T67  Each tick: M1.tick_extract(kargar, dt) returns GATHERING.
              M1 calls kargar.set_carry(&"coin", carry+1). M1 decrements
              current_stock via _set_sim. (60 ticks = 2s = full load
              of 10 if BalanceData.coin_yield_per_tick=1 with rounding.)

tick T68    M1.tick_extract returns YIELD_READY.
              EventBus.extract_completed.emit(kargar.unit_id, M1.node_id, 10, 68).
              Gathering: ctx.append_command(&"deposit", { target: throne }),
                         ctx.fsm.transition_to_next() → routes to Moving.
              Gathering.exit(): M1.release_extract(kargar). Slot freed.

tick T75    Arrival at Throne. Moving completes, transition_to_next() pops
              Deposit → transitions to Deposit state (worker-owned, not in this contract).
              Deposit calls throne.deposit(&"coin", 10, kargar).
              ResourceSystem.add(&"coin", 10).
              EventBus.resources_deposited.emit(kargar.unit_id, &"coin", 10, 75).
              kargar.set_carry(&"", 0).
              Deposit.transition_to_next() — queue empty, Idle.

[loop: kargar would normally have a follow-up gather queued via Shift-click,
 or auto-return logic per §9 #1 once design resolves it]
```

---

## 9. Open Questions / Design-Chat Escalations

1. **Auto-retarget policy when a worker's gather node depletes mid-cycle.** Spec doesn't say. Should the worker (a) idle, (b) auto-find the nearest same-resource node, (c) return any half-load to dropoff first then idle? Modern RTS QoL says (b); strict-determinism preference says (a). Default in this contract: (a) idle. Same default applies when `begin_extract` returns false at `enter` (§4.2). Flagged for design.

2. **Ruins clearing:** Do depleted `MineNode` ruins stay permanently, or can workers later clear them (removing the `NavigationObstacle3D` and reclaiming the cell for building)? Escalated to `QUESTIONS_FOR_DESIGN.md`. This affects map control decisions and late-game expansion strategy — a design call, not an implementation choice.

3. **Multi-worker mine slots:** `MineNode.max_workers = 2` is a starting value. Does the design want saturation (diminishing returns per extra worker after some threshold) or hard caps? Currently hard cap — second worker is simply rejected if both slots occupied. Escalated if the design chat wants saturation mechanics.

4. **Snowball protection clarification (carry-over from Sync 4 R1 critique).** Not directly resource-node, but `EventBus.resource_node_depleted` is the signal we'd wire snowball "destroying enemy economy" Farr drains to. Design chat needs to define "broken economy" before that wiring is real.

---

### 9.X Resolved

- *(2026-04-30, design chat)* **Grain mechanic — Path 2 ratified.** Workers gather grain from `Mazra'eh` farms via the standard `ResourceNode` API. Reasoning: workers are foundational to the RTS archetype; passive grain would have stripped that role for one resource type and broken the worker's centrality. Div faction may receive different economics post-MVP — separate research track. Patch applied in v1.1: §1.1 (two MVP subclasses), §1.4 (Mazra'eh extends `ResourceNode`), §1.5 (rationale for `current_stock = -1`), §2.3 (Mazra'eh self-registration), §3.4 (lifecycle restored), §6 (EventBus emitter language), §7 (`grain_yield_per_trip`, `grain_yield_per_tick`, `farm_max_workers` keys added).

---

*Status: v1.1 ratified. §1–§3 by world-builder; §4–§7 by gameplay-systems; §8 by gameplay-systems; §9 shared. v1 signed off by both authors 2026-04-30. v1.1 patch applied 2026-04-30 in response to design chat resolving §9 #4 to Path 2 (workers gather grain). v1.1 patch is mechanical per §1.4's documented escape hatch — no fresh review round needed per `STUDIO_PROCESS.md` §5 conditional sign-off rule.*
