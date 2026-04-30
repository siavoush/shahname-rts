# Testing Contract

*Outcome of Sync 3. Companion to `docs/SIMULATION_CONTRACT.md` (Sync 1).*
*Authors: qa-engineer. Reviewers: engine-architect, balance-engineer.*
*Status: **1.4.0** ratified 2026-04-30.*
*Created: 2026-04-30*

---

## 0. Scope

The Simulation Contract specifies *when* and *how* state changes, `advance_ticks(n)`, `MockPathScheduler`, the CI lint rule, EventBus telemetry sink, and the determinism regression test. **Do not restate those here.** This document covers only what's left: BalanceData structure, telemetry event schema, test fixture conventions, AI-vs-AI sim harness, and coverage guidance.

---

## 1. `BalanceData.tres` Structure

### 1.1 Shape

`BalanceData` is a top-level `Resource` that holds typed sub-resources. All gameplay numbers that appear in `constants.gd` as tuneable values live here instead when balance-engineer owns the number. The split: gameplay-systems creates the property, balance-engineer sets the value.

```gdscript
# resources/balance_data.gd
class_name BalanceData extends Resource

@export var constants_version: String = ""  # set manually: git hash or ISO timestamp
@export var units: Dictionary = {}          # StringName -> UnitStats
@export var buildings: Dictionary = {}      # StringName -> BuildingStats
@export var farr: FarrConfig = FarrConfig.new()
@export var combat: CombatMatrix = CombatMatrix.new()
@export var economy: EconomyConfig = EconomyConfig.new()
@export var ai: AIConfig = AIConfig.new()
```

### 1.2 Sub-resources

```gdscript
class_name UnitStats extends Resource
@export var max_hp: float
@export var damage: float
@export var attack_speed_ticks: int   # ticks between attacks
@export var attack_range: float
@export var move_speed: float
@export var population_cost: int
@export var coin_cost: int
@export var grain_cost: int
@export var production_ticks: int

class_name BuildingStats extends Resource
@export var max_hp: float
@export var coin_cost: int
@export var grain_cost: int
@export var construction_ticks: int
@export var farr_per_tick: float      # 0.0 if not a Farr generator

class_name FarrConfig extends Resource
# Thresholds
@export var starting_value: float = 50.0
@export var tier2_threshold: float = 40.0
@export var kaveh_trigger_threshold: float = 15.0
@export var kaveh_grace_ticks: int = 900       # 30s at 30Hz
@export var kaveh_farr_lock_ticks: int = 1800  # 60s
@export var kaveh_resolve_threshold: float = 30.0
@export var kaveh_resolve_window_ticks: int = 2700  # 90s
# Drain amounts (§01_CORE_MECHANICS.md §4.3) — one property per event
@export var drain_idle_worker_killed: float = -1.0
@export var drain_hero_attack_ally: float = -5.0
@export var drain_hero_killed_fleeing: float = -10.0
@export var drain_hero_killed_battle: float = -5.0
@export var drain_atashkadeh_lost: float = -5.0
@export var drain_snowball_per_kill: float = -0.5
@export var drain_snowball_worker: float = -1.0
@export var snowball_ratio: float = 3.0
# Generation rates — per tick (building farr_per_tick lives in BuildingStats)
@export var gain_hero_rescue: float = 3.0
@export var gain_hero_spares_enemy: float = 5.0   # post-MVP

class_name CombatMatrix extends Resource
# effectiveness[attacker_type][defender_type] -> float multiplier
# 1.0 = neutral, >1.0 = advantage, <1.0 = disadvantage
@export var effectiveness: Dictionary = {}

class_name EconomyConfig extends Resource
@export var starting_coin: int = 150
@export var starting_grain: int = 50
@export var resource_nodes: ResourceNodeConfig = ResourceNodeConfig.new()
# ResourceNodeConfig schema is canonical in RESOURCE_NODE_CONTRACT.md §7.
# Fields: mine_initial_stock, mine_max_workers, coin_yield_per_trip, coin_yield_per_tick,
#         grain_yield_per_trip, grain_yield_per_tick, farm_max_workers, trip_full_load_ticks.

class_name AIConfig extends Resource
# Flat fields per AI_DIFFICULTY.md §5 — Godot's Resource editor doesn't edit nested Dicts cleanly.
@export var easy_wave_cadence_ticks: int = 5400
@export var easy_ai_gather_mult: float = 0.75
@export var easy_techup_ticks: int = 10800
@export var easy_attack_army_threshold: int = 8
@export var normal_wave_cadence_ticks: int = 3600
@export var normal_ai_gather_mult: float = 1.00
@export var normal_techup_ticks: int = 9000
@export var normal_attack_army_threshold: int = 12
@export var hard_wave_cadence_ticks: int = 2700
@export var hard_ai_gather_mult: float = 1.25
@export var hard_techup_ticks: int = 7200
@export var hard_attack_army_threshold: int = 16
```

### 1.3 Validation

`BalanceData` exposes two methods:

- `validate_hard() -> bool` — called at match start. Returns false and refuses to load on invariant violations. These four conditions are invariants, not tuning errors:
  - Any HP or cost value < 0
  - `farr.kaveh_trigger_threshold >= farr.tier2_threshold` (Kaveh fires before Tier 2 is reachable — logically incoherent)
  - `farr.kaveh_grace_ticks == 0` (removes player response window — design invariant from `01_CORE_MECHANICS.md` §9.1)
  - Any `CombatMatrix` effectiveness value outside [0.0, 5.0] (above 5× is almost certainly a data entry error)

- `validate_soft() -> Array[String]` — called at match start alongside the hard check. Non-empty return logs warnings to the F2 Farr overlay (same channel as Farr change events — visible during tuning without opening the Godot console). Does not block match start. Examples: unit costs that make no economic sense, Farr drain magnitudes that are extreme but not impossible.

The rationale: balance-engineer tunes numbers during running sessions. A crash-on-odd-value breaks iteration flow. But incoherent invariants (Kaveh before Tier 2, zero grace period) produce confusing results and must be caught before simulation begins.

### 1.4 Hot-reload

**Phase 5** (when Farr tuning begins): `FarrConfig` hot-reload only. balance-engineer edits `balance_data.tres`, saves, and the Farr gauge reflects the new thresholds and deltas within 2 seconds without restarting Godot. Implementation: `FarrSystem` watches for `ResourceLoader` file-change signal on `FarrConfig` and re-reads on change.

**Phase 8** (balance pass): hot-reload for all sub-resources if the Phase 5 implementation cost is low. Not required earlier — unit stat changes mid-combat are lower iteration priority than Farr threshold tuning.

`BalanceData.tres` is loaded once at match start before Phase 5. balance-engineer edits and re-runs the simulation.

### 1.5 Balance diff tool

`tests/balance/diff_balance.gd` — authored by balance-engineer, blocked on stable sub-resource schema. Loads two `.tres` files, compares fields recursively, prints structured diff (field name, old value, new value) to stdout. Needed because `.tres` binary diffs in git are unreadable. Schema must not add or rename sub-resource fields after Phase 3 sign-off without a migration note in this document.

---

## 2. Telemetry Event Schema

`MatchLogger` (Phase 6, qa-engineer owns) subscribes via `EventBus.connect_sink()` (see Sim Contract §7) and writes one NDJSON line per event to a match log file.

### 2.1 File naming

```
logs/match_<seed>_<timestamp_unix>.ndjson
```

Each line is a self-contained JSON object with a `type` field. Readers filter by `type`; unknown types are skipped (forward-compatible by design).

### 2.2 Envelope (all events)

```json
{"type": "...", "tick": 1234, "sim_time": 41.13}
```

All events carry `type`, `tick`, and `sim_time`. Additional fields are event-specific.

### 2.3 Event catalog

| type | Additional fields | Trigger |
|---|---|---|
| `match_start` | `seed`, `difficulty`, `map_id`, `constants_version` | Match begins |
| `match_end` | `outcome` ("iran_win"/"turan_win"/"draw"), `duration_ticks` | Throne destroyed or all units eliminated |
| `farr_changed` | `amount`, `reason`, `source_unit_id`, `farr_after`, `tick` | Every `apply_farr_change()` call |
| `unit_died` | `unit_id`, `unit_type`, `team`, `killer_id`, `cause` | Unit HP reaches 0 |
| `unit_produced` | `unit_id`, `unit_type`, `team`, `building_id` | Unit spawns from building |
| `building_constructed` | `building_id`, `building_type`, `team`, `position` | Construction completes |
| `building_destroyed` | `building_id`, `building_type`, `team`, `destroyer_id` | Building HP reaches 0 |
| `resource_transaction` | `team`, `coin_delta`, `grain_delta`, `reason` | Any resource spend/gain |
| `tier_advance` | `team`, `from_tier`, `to_tier` | Tech tier upgrade completes |
| `kaveh_warning` | `farr_value`, `threshold` | Farr crosses 25, 20, 15 |
| `kaveh_triggered` | `farr_value` | 30s grace period expires |
| `kaveh_resolved` | `path` ("combat"/"farr_restore"), `farr_value` | Event ends |
| `hero_died` | `hero_id`, `hero_type`, `team`, `killer_id`, `fleeing` | Hero death |
| `hero_respawned` | `hero_id`, `hero_type`, `respawn_site_id` | Hero respawn completes |
| `ability_cast` | `unit_id`, `ability_name` | Already in Sim Contract §7; included in sink |
| `extract_started` | `worker_id`, `node_id` | Worker begins gather cycle at a resource node |
| `extract_completed` | `worker_id`, `node_id`, `yield_amount` | Worker completes a full load |
| `resources_deposited` | `worker_id`, `resource_kind`, `amount` | Worker deposits at Throne |
| `resource_node_depleted` | `node_id`, `resource_kind` | Mine exhausted or farm destroyed (node_id not Node ref — serializable) |

Schemas for the four resource signals are canonical in `RESOURCE_NODE_CONTRACT.md` §6. The `resource_node_depleted` payload uses `node_id: int` (not the Node ref) for NDJSON serializability — engine-architect coordinates with world-builder on the id-vs-ref split.

`constants_version` is `hash(FileAccess.get_file_as_string("res://resources/balance_data.tres"))` — lets post-hoc analysis confirm which tuning version produced each log. Use this field to group or filter batch runs when correlating outcomes to specific tuning states.

---

## 3. Test Fixture Conventions

### 3.1 `MatchHarness`

All GUT tests that exercise gameplay state use `MatchHarness`. It is the only approved way to create a deterministic mini-match in a test.

```gdscript
# tests/harness/match_harness.gd
class_name MatchHarness extends RefCounted

static func new(seed: int, scenario: StringName) -> MatchHarness: ...

func advance_ticks(n: int) -> void: ...   # See Sim Contract §6.1

func snapshot() -> Dictionary:
    # Returns a FLAT Dictionary of primitive values only (int, float, String, PackedArray).
    # No nested Dicts, no Node refs. GDScript's == operator compares nested Dicts by
    # reference, not value — nested Dicts break the determinism regression test silently.
    # Shape: { farr: float, coin_iran: int, grain_iran: int, coin_turan: int,
    #          grain_turan: int, unit_count_iran: int, unit_count_turan: int, tick: int }

func spawn_unit(type: StringName, team: int, position: Vector3) -> Node: ...
func spawn_building(type: StringName, team: int, position: Vector3) -> Node: ...
func _test_set_farr(value: float) -> void: ...    # test-only: bypasses apply_farr_change but MUST
                                                   # emit EventBus.farr_changed(delta, &"test_set", -1,
                                                   # new_value, SimClock.tick) so F2 overlay stays consistent.
                                                   # Must be called inside advance_ticks so _is_ticking is set.
func set_resources(team: int, coin: int, grain: int) -> void: ...

func get_farr() -> float: ...
func get_resources(team: int) -> Dictionary: ...  # {coin, grain}
func get_unit(unit_id: int) -> Node: ...
```

`MatchHarness.new()` injects `MockPathScheduler`, seeds `GameRNG` with `seed`, loads the canonical `BalanceData.tres`, and starts `SimClock` in manual-advance mode (no `_physics_process`).

`scenario` is a `StringName` key into a dictionary of pre-defined setups (e.g., `&"empty"`, `&"basic_combat"`, `&"kaveh_edge"`). Scenarios live in `tests/harness/scenarios.gd`. Adding a new scenario = adding one entry to that dictionary.

### 3.2 Assertion patterns

```gdscript
# Preferred: assert on snapshot fields
assert_eq(harness.get_farr(), 49.0)
assert_eq(harness.get_resources(Team.IRAN).coin, 200)

# Preferred: assert on EventBus events via a captured list
var farr_events := []
EventBus.farr_changed.connect(func(amt, reason, src, farr_after, tick): farr_events.append(amt))
harness.advance_ticks(1)
assert_eq(farr_events.size(), 1)
assert_eq(farr_events[0], -1.0)   # idle worker killed

# Avoid: reaching into scene-tree internals. Test through the public API.
```

### 3.3 Worked example

```gdscript
# tests/unit/test_farr_idle_worker_drain.gd
func test_killing_idle_worker_drains_farr_by_one():
    var h := MatchHarness.new(seed=1, scenario=&"empty")
    var worker := h.spawn_unit(&"kargar", Team.IRAN, Vector3.ZERO)
    h.advance_ticks(1)   # _test_set_farr must run inside a tick
    h._test_set_farr(50.0)
    worker.get_health().apply_damage(9999, null)   # kill instantly
    h.advance_ticks(1)
    assert_almost_eq(h.get_farr(), 49.0, 1e-4)
```

Five lines. No wall-clock. No scene-tree reaching. State set up via harness API, asserted on harness snapshot.

### 3.4 File layout

```
tests/
├── unit/             # Pure math, single-component. No MatchHarness needed.
├── integration/      # Multi-system interactions. Uses MatchHarness.
├── simulation/       # AI-vs-AI batch runs. Uses run_simulation.gd.
├── harness/
│   ├── match_harness.gd
│   └── scenarios.gd
└── balance/          # balance-engineer's analysis scripts (read-only output).
```

---

## 4. AI-vs-AI Sim Harness

Phase 6 deliverable. qa-engineer owns implementation; balance-engineer is the primary consumer.

### 4.1 `tools/run_simulation.gd`

Invoked headless:

```bash
godot --headless --script tools/run_simulation.gd -- \
    --seed 42 --count 50 --difficulty normal \
    --map plains_of_khorasan --out logs/batch_run_001/
```

Runs `count` matches sequentially (same seed incremented per match: `seed + i`). Each match produces one NDJSON log file (§2.1 naming). Prints a summary to stdout: total matches, Iran/Turan win rates, mean duration, Kaveh trigger rate.

### 4.2 Per-match output row (summary, not full log)

In addition to the full NDJSON log, the batch runner appends one summary row to `logs/batch_run_001/summary.ndjson`:

```json
{
  "match_index": 0,
  "seed": 42,
  "constants_version": "a3f9c12b",
  "outcome": "iran_win",
  "duration_ticks": 27000,
  "farr_trajectory": [[0, 50.0], [1800, 52.5], [3600, 48.0], "..."],
  "economy_snapshots": {
    "iran": [[0, 150, 50], [1800, 340, 120], "..."],
    "turan": [[0, 150, 50], [1800, 290, 95], "..."]
  },
  "unit_production_log": {
    "iran": {"kargar": 5, "piyade": 12, "kamandar": 8, "savar": 6},
    "turan": {"kargar": 5, "piyade": 18, "kamandar": 14, "savar": 2}
  },
  "kaveh_events": [
    {
      "triggered_at_tick": 18000,
      "farr_at_trigger": 14.2,
      "resolved_at_tick": 19800,
      "resolution": "combat",
      "resolution_ticks": 1800
    }
  ],
  "tier_advance_tick_iran": 4500,
  "tier_advance_tick_turan": 4800,
  "iran_units_lost": 23,
  "turan_units_lost": 41
}
```

`farr_trajectory` and `economy_snapshots` are sampled every 60 ticks (2 seconds at 30Hz) — sufficient for trend analysis, cheaper than 30-tick resolution. `kaveh_events` is an array (a match can trigger multiple times); each entry carries trigger Farr, resolution path, and resolution duration. `unit_production_log` is the full-match per-side count by type — detects degenerate AI compositions without parsing the full event log.

### 4.3 Regression use

After any gameplay change, run 20 matches with seed=0. Compare `summary.ndjson` win rates and mean duration against the baseline from the prior session. A shift of >15% in either metric is flagged and treated as a regression candidate — not automatically a bug, but requires explanation before merging.

---

## 5. Test Categories and Coverage Guidance

### 5.1 Categories

| Category | What it covers | Framework | When to write |
|---|---|---|---|
| **Unit** | Single function or component in isolation. No MatchHarness. | GUT | Same session the function ships. |
| **Integration** | Multi-system interaction. Uses MatchHarness + advance_ticks. | GUT | Same phase the system ships. |
| **Simulation** | AI-vs-AI full-match batch. Uses run_simulation.gd. | Shell + GUT | Phase 6+. |
| **Build verification** | Project opens, loads, and runs one tick headless without error. | Shell script | Every session. |

### 5.2 What must have unit tests (Priority 1)

Every function in `constants.gd` that returns a computed value. Every Farr generator and drain in §4.3 of `01_CORE_MECHANICS.md`. Every state machine transition (valid and invalid). Combat damage formula and rock-paper-scissors multipliers. Tech tier prerequisite checks.

### 5.3 What integration tests cover (Priority 2)

Full gather cycle (worker → node → deposit → resource increments). Full build cycle (placement → construction timer → building functional). Full production cycle (building → queue → unit spawns). Kaveh Event end-to-end (Farr drop → trigger → both resolution paths).

### 5.4 What is intentionally not unit-tested

Rendering, visual interpolation, UI layout, audio. Pathfinding correctness (tested indirectly through integration; real NavMesh not available headless). Fog-of-war shader output.

### 5.5 Realistic coverage targets per phase

| Phase | Target | What's realistic |
|---|---|---|
| 0 | Lint + build verification + determinism skeleton | Harness doesn't exist yet; skeleton only. |
| 1–2 | Unit tests for movement states, combat math | ~80% of written gameplay functions have a unit test. |
| 3–4 | Integration tests for gather, build, production, Farr | Full cycles covered; edge cases deferred. |
| 5 | Hero, Kaveh Event integration tests | Both resolution paths exercised. |
| 6+ | Simulation batch runs, MatchLogger | 50-match batches establish baseline. |

These are guidance, not mandates. A function that's trivially a pass-through doesn't need a test. A function that touches Farr or combat math does.

---

*v1.4.0 — Convergence Review revision pass. EconomyConfig nests ResourceNodeConfig; farm_grain_rate_per_tick removed (Path 2 cleanup); AIConfig adopts flat-field shape per AI_DIFFICULTY.md §5; snapshot() constrained to primitive-only Dict; _test_set_farr emits farr_changed; four resource-node signals added to event catalog.*
