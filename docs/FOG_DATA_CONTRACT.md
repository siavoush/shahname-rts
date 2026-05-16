---
title: Fog of War — Data Layer Contract
type: contract
status: ratified
version: 1.3.1
owner: world-builder
summary: FogSystem autoload — boolean visibility grid, per-team two-layer storage, is_visible_to / get_last_seen / get_scout_candidates API, vision source registration (static/dynamic), two-pass phase ordering, death-position freezing, determinism guarantees.
audience: all
read_when: working-on-fog-of-war, working-on-ai-scouting, working-on-kaveh-event-presentation
prerequisites: [MANIFESTO.md, SIMULATION_CONTRACT.md, ARCHITECTURE.md]
ssot_for:
  - FogSystem autoload API (is_visible_to, get_last_seen, get_scout_candidates)
  - fog grid schema (cell size in cells, per-team layers, PackedByteArray storage)
  - vision source registration/deregistration protocol (static vs dynamic sources)
  - building footprint reveal semantics (full footprint)
  - two-pass fog phase ordering (fog_update before AI + cleanup-pass for death-freeze)
  - entity-kind disambiguation for get_last_seen (unit vs building namespaces)
  - ever_seen lifetime policy (eternal for MVP)
  - determinism guarantees for the fog layer
  - BalanceData keys for fog (sight radii in cells, cell size)
references: [SIMULATION_CONTRACT.md, ARCHITECTURE.md, RESOURCE_NODE_CONTRACT.md, docs/AI_DIFFICULTY.md]
tags: [fog, visibility, world, ai-scouting, kaveh-event, phase-ordering, determinism]
created: 2026-05-14
last_updated: 2026-05-14
provenance: Room B — Open Space Pattern A (world-builder author, ai-engineer + gameplay-systems reviewers). Phase 3 session 2 pre-flight sync. v1.1.0 incorporates R1 review from gp-sys-p3s2 (blocking concerns resolved). v1.2.0 incorporates ai-engineer R1 ratification (tick-clarification for get_last_seen; Vector3 confirmed for get_scout_candidates). v1.3.0 incorporates gp-sys-p3s2 conditional-ratification surgical fixes: entity_id namespace prose clarified (Building field is unit_id not building_id; see building.gd:103); §3.2 footprint extraction updated to use Building.get_footprint_aabb() method (gameplay-systems adds to building.gd in wave 1A). Both reviewers ratified. Ratified 2026-05-14. See 02g_PHASE_3_SESSION_2_KICKOFF.md §2.1.
---

# Fog of War — Data Layer Contract

> This contract sits on top of `SIMULATION_CONTRACT.md`. The fog layer is part of the simulation layer — all visibility state mutates only during the `fog_update` sim phase (§1.3). The rendering layer (fog shader, minimap tint) reads FogSystem freely outside ticks and is NOT bound by this contract. Rendering ships in Phase 5; this contract covers the Phase 3 data layer only.

---

## 0. Why this document exists

Fog of war has three downstream consumers across three phases:

1. **Phase 3 — DummyAI (this session):** `is_visible_to` lets the AI know whether its probe-attack target is currently visible to Iran.
2. **Phase 5 — Kaveh Event presentation:** `get_last_seen` supplies "last seen enemy building positions" for the revolt's scripted targeting. Without fog memory, the Kaveh Event can only target buildings it can currently see — which may be none if the enemy has retreated behind fog.
3. **Phase 6 — Full AI scouting:** `get_scout_candidates` supplies unexplored region targets for the AI's scouting behavior without requiring the AI to grid-walk the entire map.

The schema must be right at Phase 3 because Phases 5 and 6 are downstream consumers. A retrofit at Phase 5 would touch the FogSystem autoload, the Sim Contract (phase ordering), BalanceData, and all existing consumers. Building the schema right now costs one extra day; retrofitting costs three.

**What this contract covers:** the `FogSystem` autoload, its grid schema, the consumer API, vision source registration, phase ordering, and determinism guarantees.

**What this contract does NOT cover:** the fog shader, the fog texture baking pipeline, the minimap fog tint — all Phase 5. Nothing in this contract requires a shader. The Phase 3 deliverable is data only.

---

## 1. Grid Schema

### 1.1 Cell size

```gdscript
# FogConfig in BalanceData (see §7)
@export var fog_cell_size_m: float = 4.0   # world metres per fog cell (read-only at runtime)
```

**4 metres per cell.** This is 2×2 navigation cells (WorldGrid.CELL_SIZE = 2.0 m). At 4m cells on the Khorasan map (estimated ~256m × 256m playing field):

- Grid dimensions: 64 × 64 = 4096 cells per team.
- `is_visible_to` is a two-integer divide + flat array index — O(1), no iteration.
- At 30 Hz with ~50 vision sources each revealing a 8-cell radius circle (≈200 cells), per-tick fog recompute is ≈50 × 200 = 10,000 cell-writes — within budget on M1.

**Sight radii are stored as integer cells in BalanceData** (see §7), not world units. This keeps the visibility computation fully integer — no float division in the per-tick hot path. The BalanceData keys carry a human-readable comment giving the world-unit equivalent. The conversion (`radius_cells = ceili(sight_radius_m / fog_cell_size_m)`) happens once offline (when the balance author sets the value) rather than at runtime. *Cites Sim Contract §1.6: determinism-critical arithmetic must stay integer.*

The cell size constant lives in `BalanceData.fog.fog_cell_size_m` for human reference only — it is never read in the per-tick path. Grid dimensions are computed once at `_ready` from the map bounds:

```gdscript
# FogSystem._ready() — init from map bounds
var bounds: Rect2 = WorldGrid.map_bounds   # Vector2(min_x, min_z) → Vector2(max_x, max_z)
_grid_w: int = ceili((bounds.size.x) / _cell_size_m)
_grid_h: int = ceili((bounds.size.y) / _cell_size_m)
_grid_origin: Vector2 = bounds.position    # world-space offset for cell ↔ position conversion
```

### 1.2 Per-team storage — two layers

Two `PackedByteArray` grids per team. Team 0 = Iran, Team 1 = Turan (matching `unit.team` field convention).

```gdscript
# FogSystem internal state. Arrays indexed by team_id.
var _currently_visible: Array[PackedByteArray] = []   # rebuilt every fog_update tick
var _ever_seen: Array[PackedByteArray] = []            # accumulates across the match
```

Each `PackedByteArray` has `_grid_w * _grid_h` bytes. Value is 0 (not visible/not seen) or 1 (visible/seen). `PackedByteArray` is chosen over `Array[bool]` for cache-friendliness and GDScript memory compactness at this scale — 4096 bytes per layer vs 4096 Variant-boxed booleans.

**`_currently_visible`** is cleared to 0 at the start of every `fog_update` phase and rebuilt from the registered vision sources. It answers "right now, can team T see this cell?"

**`_ever_seen`** only ever goes from 0 to 1. A cell flips to 1 the first time it enters `_currently_visible` for a team, and never flips back. It answers "has team T ever had visibility into this cell?" Phase 5's Kaveh Event reads `_ever_seen` to place "last seen" building proxies in cells the player has explored but can no longer see.

### 1.3 Cell ↔ world-position conversion

```gdscript
func world_to_cell(world_pos: Vector3) -> Vector2i:
    var rel: Vector2 = Vector2(world_pos.x, world_pos.z) - _grid_origin
    return Vector2i(
        clampi(int(rel.x / _cell_size_m), 0, _grid_w - 1),
        clampi(int(rel.y / _cell_size_m), 0, _grid_h - 1),
    )

func cell_to_world_center(cell: Vector2i) -> Vector3:
    return Vector3(
        _grid_origin.x + (cell.x + 0.5) * _cell_size_m,
        0.0,
        _grid_origin.y + (cell.y + 0.5) * _cell_size_m,
    )

func _cell_index(cell: Vector2i) -> int:
    return cell.y * _grid_w + cell.x
```

All arithmetic is integer division in cell space. No `sqrt`, no `sin/cos`, no floats in the visibility computation. Per Sim Contract §1.6 (integer arithmetic for accumulating state), this makes the fog layer deterministic across x86-64 and ARM64.

---

## 2. Vision Sources

### 2.1 Registration API

Vision sources (units and buildings) register through a single uniform interface. The `is_static` flag distinguishes sources that never move (buildings) from sources that move each tick (units). Static sources compute their visible cell set once at registration and cache it; dynamic sources recompute each `fog_update` tick.

```gdscript
# FogSystem autoload

## Register a node as a vision source. Returns an opaque handle used for
## deregistration (avoids storing the node ref in the caller after queue_free).
## sight_radius_cells: integer cells — read from BalanceData.fog.*_cells.
## is_static: true for buildings (cell set cached at registration);
##            false for units (cell set recomputed each fog_update).
func register_vision_source(
    node: Node3D,
    team_id: int,
    sight_radius_cells: int,
    is_static: bool = false
) -> int  # returns handle

## Remove a vision source by handle. Idempotent — safe to call on death,
## queue_free, or building destruction even if already deregistered.
func deregister_vision_source(handle: int) -> void
```

**Registration call site conventions:**
- **Units:** `register_vision_source` in `_ready` with `is_static = false`; `deregister_vision_source(handle)` in the death-preempt path (before `queue_free`). The unit stores its handle as a field.
- **Buildings:** `register_vision_source` in `_ready` with `is_static = true`; `deregister_vision_source(handle)` on destruction (HealthComponent fatal-damage path, before `queue_free`).
- Phase 5 Kaveh rebel units use `is_static = false` — they move, so their vision contribution recomputes each tick as normal.

**Internal storage:**

```gdscript
# Per vision source record. Keyed by opaque integer handle (not instance_id).
# Handle is a monotonically increasing counter, so deregistered handles never
# alias live ones.
var _sources: Dictionary = {}
# handle -> {
#   node: Node3D,       # weak ref — checked with is_instance_valid each tick
#   team: int,
#   radius_cells: int,
#   is_static: bool,
#   cached_cells: Array[int],  # flat cell indices; populated at reg for static, empty for dynamic
# }
var _next_handle: int = 1
```

Using an opaque integer handle avoids the "node freed before deregister" hazard. The node ref inside the record is checked with `is_instance_valid` on each fog_update; if the node was freed without calling deregister (a bug, but tolerated), the stale record is cleaned up lazily.

### 2.2 Vision source radius in BalanceData

All sight radii are stored as **integer cell counts** in BalanceData. Each key carries a comment giving the world-unit equivalent at 4m/cell for human reference.

| Source | BalanceData key | Default (cells) | ≈world metres |
|---|---|---|---|
| Kargar (worker) | `fog.sight_kargar_cells` | 3 | 12m |
| Piyade (infantry) | `fog.sight_piyade_cells` | 3 | 12m |
| Kamandar (archer) | `fog.sight_kamandar_cells` | 4 | 16m |
| Savar (cavalry) | `fog.sight_savar_cells` | 4 | 16m |
| Rostam (hero) | `fog.sight_rostam_cells` | 5 | 20m |
| Throne | `fog.sight_throne_cells` | 4 | 16m |
| Sarbaz-khaneh | `fog.sight_sarbazkhane_cells` | 3 | 12m |
| Atashkadeh | `fog.sight_atashkadeh_cells` | 2 | 8m |

Turan units use the same keys (symmetric by default). Balance-engineer tunes via `data/balance.tres`; no float math in the runtime path.

---

## 3. Visibility Computation

### 3.1 Per-tick recompute (fog_update phase)

Every `fog_update` tick (see §4 for phase ordering), `FogSystem` runs:

1. Clear `_currently_visible[team]` to all-zeros for all teams.
2. For each registered vision source, compute the set of cells within `radius_cells` using **integer circle** test:
   ```gdscript
   var cx: int = source_cell.x
   var cy: int = source_cell.y
   var r: int = source_record.radius_cells
   for dy in range(-r, r + 1):
       for dx in range(-r, r + 1):
           if dx * dx + dy * dy <= r * r:
               var cell: Vector2i = Vector2i(cx + dx, cy + dy)
               # bounds check omitted for brevity; clamp or skip
               var idx: int = _cell_index(cell)
               _currently_visible[team][idx] = 1
               _ever_seen[team][idx] = 1   # ever_seen only grows
   ```
3. The `dx*dx + dy*dy <= r*r` test uses only integer arithmetic — no `sqrt`, no float. Deterministic across platforms per Sim Contract §1.6.

### 3.2 Building footprint reveal

A building is considered **visible** to a team when **any cell of its footprint** is in `_currently_visible` for that team. A building is considered **ever seen** when **any cell of its footprint** has been in `_ever_seen`.

**Full footprint, not center-only.** This matches SC2/AoE2 convention and matters for the Phase 5 Kaveh Event: if a building's corner is in a scouted region but its center is not, the building should still be revealed. Center-only would produce buildings that "phase in" as the player approaches the far side — unintuitive.

Building footprint cells are computed once at registration time from `Building.get_footprint_aabb()` — a method on the Building base class (added in wave 1A alongside Mazra'eh, owned by gameplay-systems). This keeps the footprint contract on the Building side where it belongs; FogSystem doesn't need to know about CollisionShape3D node names:

```gdscript
func _footprint_cells(building: Node3D) -> Array[Vector2i]:
    var aabb: AABB = building.get_footprint_aabb()  # Building base class method
    var min_cell: Vector2i = world_to_cell(aabb.position)
    var max_cell: Vector2i = world_to_cell(aabb.position + aabb.size)
    var cells: Array[Vector2i] = []
    for cy in range(min_cell.y, max_cell.y + 1):
        for cx in range(min_cell.x, max_cell.x + 1):
            cells.append(Vector2i(cx, cy))
    return cells
```

`Building.get_footprint_aabb()` returns a world-aligned `AABB`. Shipped implementation (in `building.gd`) uses `find_child("MeshInstance3D", true, false)` + `mesh.mesh.get_aabb()` — the mesh defines the footprint for placeholder-art buildings; subclasses may override for non-rectangular footprints. Gameplay-systems owns this method. If wave 3A (FogSystem) ships before a building subclass overrides this, FogSystem falls back to a 2×2 default per the base implementation's fallback clause.

The footprint array is stored in the source record (alongside `team` and `radius_cells`) so it doesn't recompute every tick. For MVP buildings (2×2 to 4×4 grid footprints), this is 4–16 cells.

---

## 4. Phase Ordering — Two-Pass Design

### 4.1 Two fog passes per tick

The fog layer runs in **two passes** per tick to handle both vision-update and entity-death cleanly:

**Pass 1 — `fog_update` (before `ai`):** Recompute `_currently_visible` from current entity positions. AI phase queries `is_visible_to` on fresh data.

**Pass 2 — death freeze in `cleanup` (after `combat`):** After combat resolves this tick's deaths, FogSystem seals the `_last_seen` entry for any entity that died this tick, preventing "last known alive position" from becoming stale-forever after the entity is freed.

```
BEFORE (Sim Contract v1.4.0):
  input → ai → movement → spatial_rebuild → combat → farr → cleanup

AFTER (Sim Contract v1.5.0):
  input → fog_update → ai → movement → spatial_rebuild → combat → farr → cleanup
  │                                                                         │
  └─ Pass 1: recompute _currently_visible                    Pass 2: seal dead entity last_seen ┘
```

### 4.2 Pass 1: `fog_update` phase details

**Why before `ai`:** AI controllers query `is_visible_to` during the `ai` phase. The fog must be current before the AI runs. The one-tick stale position is acceptable — fog memory (`_ever_seen`) is permanent and `_currently_visible` from the prior tick's movements is the correct frame for AI decisions.

**Why before `movement`:** Movement updates positions; fog should reflect the world state AFTER the previous tick's movement. The `fog_update` → `movement` ordering ensures the fog the AI queries reflects where units ended their last movement, not where they're about to move.

**FarrDrainDispatcher interaction:** `FarrDrainDispatcher` listens on `unit_health_zero` (fires in `combat` phase) and reads `unit.fsm.current.id` to attribute the Farr drain. The fog state during combat reflects pre-combat visibility (fog ran before movement, before combat). This is correct semantics: "was this enemy worker visible to Iran when it was killed?" uses the pre-combat fog state, which is exactly what `is_visible_to` returns during the combat phase.

### 4.3 Pass 2: death-freeze in `cleanup` phase

FogSystem subscribes to `EventBus.unit_health_zero`. When it fires during `combat`, FogSystem captures the entity's final `global_position` and queues a freeze record. During `cleanup`, it seals each entry:

```gdscript
# FogSystem._on_unit_health_zero(unit: Node) — called during combat phase
_pending_death_freeze.append({
    entity_kind = &"unit",
    entity_id = unit.unit_id,
    final_position = unit.global_position,
})

# FogSystem._on_cleanup_phase() — seals the queued deaths
for entry in _pending_death_freeze:
    var key: int = _make_key(entry.entity_kind, entry.entity_id)
    for team_id in range(_num_teams):
        if _last_seen_by_team[team_id].has(key):
            _last_seen_by_team[team_id][key]["tick"] = SimClock.tick
            _last_seen_by_team[team_id][key]["sealed"] = true
_pending_death_freeze.clear()
```

The `sealed = true` flag prevents `fog_update` from overwriting this entry in future ticks (the node is gone, `is_instance_valid` would catch it anyway, but `sealed` is explicit documentation of intent). Buildings subscribe to the equivalent `building_destroyed` signal.

### 4.4 SimClock.PHASES patch

This contract requires a one-line patch to `game/scripts/autoload/sim_clock.gd`:

```gdscript
# BEFORE (sim_clock.gd line 24):
const PHASES: Array[StringName] = [
    &"input", &"ai", &"movement", &"spatial_rebuild",
    &"combat", &"farr", &"cleanup",
]

# AFTER:
const PHASES: Array[StringName] = [
    &"input", &"fog_update", &"ai", &"movement", &"spatial_rebuild",
    &"combat", &"farr", &"cleanup",
]
```

FogSystem connects to BOTH `&"fog_update"` (Pass 1) and `&"cleanup"` (Pass 2 death-freeze). No other existing phase coordinator is affected — each connects on its own StringName.

**Sim Contract addendum:** This change bumps `SIMULATION_CONTRACT.md` to v1.5.0. The addendum to §2 (Tick Order) reads:

> **(1.5.0 addendum — 2026-05-14):** Phase 2 is now `fog_update`. `FogSystem` runs in this phase (Pass 1), clearing and recomputing `_currently_visible` from registered vision sources. AI phase (now phase 3) queries `is_visible_to` after the fog update, seeing a fresh visibility state. `FogSystem` also runs a second time in `cleanup` (Pass 2) to seal `_last_seen` entries for entities that died this tick. See `docs/FOG_DATA_CONTRACT.md` for full specification.

---

## 5. Consumer API

### 5.1 `is_visible_to` — point visibility query

```gdscript
## Returns true if world_pos is currently visible to team_id this tick.
## O(1): two integer divides + flat array lookup.
## Safe to call from any sim phase at or after fog_update; reads only.
func is_visible_to(team_id: int, world_pos: Vector3) -> bool:
    var cell: Vector2i = world_to_cell(world_pos)
    return _currently_visible[team_id][_cell_index(cell)] == 1
```

**Call sites:** AI phase (DummyAI checking target visibility), combat phase (future ranged-attack line-of-sight), Phase 5 Kaveh Event scripting.

### 5.2 `get_last_seen` — fog memory query

```gdscript
## Returns the last known position + tick for a tracked entity (unit or building),
## from the perspective of team_id.
## entity_kind = &"unit" | &"building" — required because both sides use a field
##   named `unit_id` but draw from SEPARATE static counters (building.gd line 114:
##   `static var _next_building_id: int = 1`, distinct from unit.gd's counter).
##   Without entity_kind, a unit with unit_id=1 and a building with unit_id=1
##   would collide in the lookup table. Note: Building's identity field is named
##   `unit_id` (not `building_id`) — see building.gd:103.
## Returns {} if the entity has never been seen by team_id.
## The `tick` field enables staleness scoring (Phase 6 AI: fresh sightings beat stale).
func get_last_seen(team_id: int, entity_id: int, entity_kind: StringName) -> Dictionary:
    # Returns: { position: Vector3, tick: int }
    # or: {}
```

**Internal key:** `_make_key(entity_kind, entity_id) -> int` packs both into a single int: `hash(entity_kind) * MAX_ENTITY_ID + entity_id`. Collision probability is negligible at MVP entity counts (<1000 total).

**Internal storage:** `_last_seen_by_team: Array[Dictionary]` indexed by team_id, where each Dictionary maps `packed_key (int) -> { position: Vector3, tick: int, sealed: bool }`.

**Update rule:** During the `fog_update` phase, FogSystem iterates all tracked entities. For each entity visible to a team this tick (`_currently_visible[team][cell] == 1`), it records `{ position: entity.global_position, tick: SimClock.tick, sealed: false }`. The `tick` field is the sim-tick when the entity was **actually visible** — it is only written when `_currently_visible` contains the entity's cell, never on every fog_update run. An entity that went into fog on tick 200 retains `tick: 200` indefinitely until it becomes visible again. This is the semantically correct value for Phase 6 pursuit-freshness scoring: `stale_s = (SimClock.tick - sighting.tick) / SIM_HZ`.

**Consumer contract for Phase 5 Kaveh Event:**
```gdscript
# Find the last known position of the enemy throne even if it's fogged now.
var throne_pos: Dictionary = FogSystem.get_last_seen(TEAM_REBEL, enemy_throne_id, &"building")
if not throne_pos.is_empty():
    rebel_unit.command_attack(throne_pos.position)
```
An empty dict means "never seen" — Kaveh rebels should not reveal buildings Iran has never scouted.

**Consumer contract for Phase 6 AI pursuit:**
```gdscript
var sighting: Dictionary = FogSystem.get_last_seen(TEAM_TURAN, iran_unit_id, &"unit")
if sighting.is_empty():
    pass  # never spotted
else:
    var stale_s: float = (SimClock.tick - sighting.tick) / 30.0
    if stale_s < AI_PURSUIT_TIMEOUT_S:
        move_toward(sighting.position)
    else:
        seek_scout_candidate()
```

### 5.3 `get_scout_candidates` — unexplored region targets

```gdscript
## Returns up to max_results world-space positions (Y=0) of unexplored cells
## for team_id. "Unexplored" means _ever_seen[team_id][cell] == 0.
## Results are pre-cached as a sparse set; this call is O(max_results), not
## O(grid_size). Positions are cell centroids (cell_to_world_center output).
func get_scout_candidates(team_id: int, max_results: int) -> Array[Vector3]:
```

**Internal storage:** `_unexplored_cells: Array[Array]` indexed by team_id, where each entry is an `Array[Vector2i]` of cells still at 0 in `_ever_seen`. This sparse set is maintained incrementally: when a cell flips from 0 to 1 in `_ever_seen` (during `fog_update`), the cell is removed from `_unexplored_cells[team]`. The Array may have holes after removals; a compact step runs lazily when `get_scout_candidates` is called and the set is large (> 2× actual size).

**Return format:** world-space `Vector3` with `y = 0`. The AI caller issues movement commands using world-space positions directly — no translation step needed.

**`max_results` cap:** The caller specifies how many candidates it needs. For DummyAI (Phase 3), `max_results = 1` is sufficient (pick one target and scout it). For Phase 6's full AI, `max_results = 5` gives it a small candidate set to prioritize. The cap prevents the return from being O(all unexplored cells) even in edge cases.

---

## 6. Entity Registration for `get_last_seen`

`get_last_seen` requires FogSystem to know what entities exist and where they are each tick. FogSystem doesn't manage the entity registry itself — it subscribes to existing EventBus signals:

| EventBus signal | FogSystem action |
|---|---|
| `unit_spawned(unit: Node)` | Add unit to per-team tracking. On visibility: update `_last_seen_by_team`. |
| `unit_died(unit_id: int, ...)` | Remove from tracking on both teams. |
| `building_placed(building: Node)` | Add building to per-team tracking. |
| `building_destroyed(building: Node, ...)` | Remove from tracking. |

FogSystem does NOT replace or replicate the entity registry — it subscribes to existing signals and maintains only the `_last_seen_by_team` data structure.

If these EventBus signals don't yet exist (Phase 3 only has `unit_health_zero` and `resource_node_depleted`), FogSystem registers a fallback: it iterates `get_tree().get_nodes_in_group(&"units")` + `get_tree().get_nodes_in_group(&"buildings")` during the `fog_update` phase for the Phase 3 scope. This is O(entity_count) per tick — acceptable at Phase 3 scale (~20 total entities). When the proper EventBus signals land in a later phase, the iteration fallback is replaced.

**LATER-fog-3 (surfaced at Convergence Review 2026-05-14):** `EventBus.building_placed` payload mismatch for FogSystem's signal-driven registration path. The shipped signal signature is `(unit_id: int, kind: StringName, team: int, position: Vector3)` — the `unit_id` field is the **placer worker's** id, not the building's own `unit_id` (from `_next_building_id`). FogSystem's `get_last_seen` keys on the building's own `unit_id`. Wave 3A MUST use the group-iteration fallback (not the signal) for Phase 3 building registration — the fallback is already correct. For Phase 5 signal-driven registration, resolve via one of: (a) expand `building_placed` to carry `building_id: int` as an additional field, or (b) FogSystem does a one-time `find_in_group(&"buildings")` scan after each `building_placed` signal to locate the newly-added node and read its `unit_id`. Either option is a Phase 5 sub-deliverable, not a wave 3A blocker. **Wave 3A implementer (world-builder): use the group-iteration fallback; do NOT read `signal.unit_id` as the building identity.**

---

## 7. BalanceData Keys

All fog tunables live in a `FogConfig` sub-resource on `BalanceData`. **Sight radii are integer cell counts** — no float math in the runtime path. Human-readable world-metre equivalents are in comments only.

```gdscript
class_name FogConfig extends Resource

# Cell size — reference constant for balance-engineer; NOT read in the per-tick path.
@export var fog_cell_size_m: float = 4.0   # 4m per cell

# Sight radii in integer cells (at 4m/cell; multiply by 4 for world metres).
@export var sight_kargar_cells: int = 3    # 12m
@export var sight_piyade_cells: int = 3    # 12m
@export var sight_kamandar_cells: int = 4  # 16m
@export var sight_savar_cells: int = 4     # 16m
@export var sight_rostam_cells: int = 5    # 20m
@export var sight_throne_cells: int = 4    # 16m — always-on building vision
@export var sight_sarbazkhane_cells: int = 3  # 12m
@export var sight_atashkadeh_cells: int = 2   # 8m
```

Numbers are starting points. Balance-engineer tunes via `data/balance.tres`. The world-builder registers units and buildings with the correct radius by reading `BalanceData.fog.sight_<unit_type>_cells` at spawn / `_ready`.

### 7.1 `_ever_seen` lifetime policy

**Eternal memory for MVP.** Once a cell enters `_ever_seen` for a team, it stays for the entire match. Memory is bounded: 4096 bytes per layer × 2 layers × 2 teams = 16 KB — negligible for a 25-minute match. If post-MVP design adds fog-decay or "shrouding" mechanics, the `_ever_seen` layer can be extended with a per-cell tick timestamp; no API change required. This assumption is locked so Phase 5 Kaveh Event consumers can rely on `get_last_seen` returning valid positions for buildings seen early in the match even in late-game fog.

---

## 8. Determinism Guarantees

The fog layer is deterministic by construction:

1. **Integer arithmetic only** in visibility computation (`dx*dx + dy*dy <= r*r`). No `sqrt`, no `sin/cos`. Same result on x86-64 and ARM64.
2. **Recomputed from scratch** each `fog_update` tick — no accumulated float state, no drift.
3. **Deterministic source iteration order** — `_sources` Dictionary is iterated in insertion order (GDScript Dictionary iteration is stable). Vision sources register in `_ready` order, which is scene-tree order (sorted by node path). The same scene produces the same registration order across runs.
4. **`_ever_seen` is append-only** — cells only go from 0 to 1. No bits are ever cleared after being set.
5. **Phase ordering is fixed** — `fog_update` always runs before `ai`, always after `input`. The phase list in `SimClock.PHASES` is a constant, not runtime-mutable.

---

## 9. EventBus Signals (new, from FogSystem)

FogSystem adds two read-shaped signals to EventBus for UI consumers (minimap, fog shader — Phase 5):

| Signal | When emitted | Payload |
|---|---|---|
| `fog_visibility_changed(team_id: int, tick: int)` | End of each `fog_update` phase | `(team_id, tick)` — consumer re-queries `is_visible_to` as needed |
| `fog_cell_first_seen(team_id: int, cell: Vector2i)` | When `_ever_seen` first flips a cell for a team | `(team_id, cell)` — minimap can update its exploration overlay |

Both are **read-shaped** (they notify UI consumers to re-read state; they do not carry the full grid state). Per Sim Contract §1.5 UI consumers of write-shaped signals must defer visual changes; these read-shaped signals are exempt from that rule but UI consumers should still follow their own update discipline.

---

## 10. File Locations

| File | Owner | Notes |
|---|---|---|
| `game/scripts/autoload/fog_system.gd` | world-builder | FogSystem autoload |
| `game/scripts/world/fog_config.gd` | world-builder | FogConfig Resource subclass |
| `game/data/balance.tres` | balance-engineer | FogConfig values added under `.fog` |
| `game/scripts/autoload/sim_clock.gd` | engine-architect | One-line PHASES patch (world-builder commits as part of wave-3A) |
| `docs/SIMULATION_CONTRACT.md` | engine-architect | v1.5.0 addendum to §2 (world-builder writes the addendum text, engine-architect signs off) |

---

## 11. Out of Scope (this contract)

- **Fog rendering (shader, texture baking)** — Phase 5. This contract is data only.
- **Minimap fog tint** — Phase 5.
- **Building "last seen" proxy meshes** (grey ghost buildings in explored-but-fogged zones) — Phase 5, consumed from `get_last_seen`.
- **Line-of-sight blocking** (terrain elevation, buildings blocking sight lines) — post-MVP. Phase 3 fog is flat-plane visibility only: if the cell is within radius, it's visible, regardless of what's between source and target. Cite: `01_CORE_MECHANICS.md` §1 (MVP scope — one flat map).
- **Fog in multiplayer** — out of MVP scope.

---

*Status: v1.3.1 — RATIFIED 2026-05-14. Authored by world-builder. All three reviewers signed: gp-sys-p3s2 ratified v1.1.0 blocking concerns + v1.3.0 surgical fixes (entity_id prose + footprint method); ai-engineer ratified v1.2.0 (tick-clarification; Vector3 for scout candidates). Room B closed. See `02g_PHASE_3_SESSION_2_KICKOFF.md` §2.4. v1.3.1 patches §3.2 stale CollisionShape3D reference to match shipped MeshInstance3D path (world-builder + gp-sys + arch-reviewer convergent finding 2026-05-14). Cross-wave dependency: `Building.get_footprint_aabb()` (gameplay-systems, wave 1A) must exist before wave 3A FogSystem registration call. Sim Contract v1.5.0 addendum required alongside this doc (world-builder writes text, engine-architect signs off in wave 3A).*
