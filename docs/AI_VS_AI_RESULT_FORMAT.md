---
title: AI-vs-AI Match Result Format
type: contract
status: v1.1.1
version: 1.1.1
owner: balance-engineer
authored: 2026-06-03
authored_by: balance-engineer-wave-3sim
revised: 2026-06-08
revised_by: engine-architect-wave-b2 (v1.1.0) + lead wave-B integration fix-up (v1.1.1)
audience: engine-architect (Track 2 implementer), qa-engineer (Track 3 aggregator), balance-engineer (first human consumer)
read_when: before implementing HeadlessMatchRunner result emission; before writing aggregation scripts; before reading batch output
prerequisites: [02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §3 Q5, §4.1, §5]
ssot_for:
  - per-match NDJSON schema (field names, types, value ranges, semantics)
  - signal classification (calibration-relevant vs diagnostic-only)
  - aggregation conventions per signal
  - Iran build-order affordability table (§4 Q4 feasibility check)
references: [02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md, game/data/balance.tres, game/scripts/world/resource_nodes/mine_node.gd]
tags: [balance, ai-vs-ai, result-format, ndjson, headless-runner, affordability]
---

# AI-vs-AI Match Result Format

## §1 — Purpose + Authority

This document is the **canonical schema contract** for the per-match NDJSON line emitted by `HeadlessMatchRunner`. Track 2 (engine-architect) implements result-emission against this schema. Track 3 (qa-engineer) writes aggregation scripts against this schema. Balance-engineer is the first human consumer of batch output.

The §3 Q5 NDJSON proposal in the kickoff brief is this document's floor. Deviations from that proposal are noted and justified in §2 below.

---

## §2 — Definitive Signal List

### §2.1 Schema

One JSON object per line (NDJSON). Fields are grouped by category.

```json
{
  "match_id": "match_0042",
  "seed": 1234567890,
  "outcome": "iran_win",
  "winner_team": 1,
  "duration_ticks": 18432,
  "duration_seconds": 614.4,
  "first_engagement_tick": 3712,
  "timeout": false,
  "iran": {
    "throne_destroyed": false,
    "throne_hp_pct_at_end": 87.5,
    "workers_alive_at_end": 4,
    "combat_units_alive_at_end": 8,
    "buildings_alive_at_end": 6,
    "buildings_destroyed": 0,
    "coin_x100_at_end": 24500,
    "grain_x100_at_end": 13200,
    "farr_x100_at_end": 4700,
    "units_produced_total": 10,
    "buildings_constructed_total": 5
  },
  "turan": {
    "throne_destroyed": true,
    "throne_hp_pct_at_end": 0.0,
    "workers_alive_at_end": 1,
    "combat_units_alive_at_end": 0,
    "buildings_alive_at_end": 0,
    "buildings_destroyed": 1,
    "coin_x100_at_end": 8200,
    "grain_x100_at_end": 4100,
    "farr_x100_at_end": -1,
    "units_produced_total": 0,
    "buildings_constructed_total": 0
  },
  "events": {
    "turan_probes_fired": 5,
    "turan_units_deployed_total": 25,
    "buildings_destroyed_total": 2,
    "units_killed_total": 17,
    "farr_drain_events_total": 6,
    "kaveh_event_triggered": false,
    "iran_first_piyade_tick": 2400
  }
}
```

### §2.2 Field Definitions

#### Top-level fields

| Field | Type | Range | Description |
|---|---|---|---|
| `match_id` | string | `"match_NNNN"` | Zero-padded match index in the batch. `"match_0000"` for the first match. |
| `seed` | int | any | The seed used for this match (`seed(match_seed)` at match-start). |
| `outcome` | string | `"iran_win"`, `"turan_win"`, `"stalemate"` | `stalemate` = hit the 60,000-tick timeout without a throne falling. |
| `winner_team` | int | `1`, `2`, `-1` | `1` = Iran, `2` = Turan, `-1` = stalemate. Matches `Constants.TEAM_IRAN` / `Constants.TEAM_TURAN`. |
| `duration_ticks` | int | 1 – 60,000 | Ticks from match-start to **throne-fall** (or timeout). **v1.1.0:** the runner keeps the process alive for a post-throne-fall grace window (§2.3) so trailing events are counted, but `duration_ticks` records the THRONE-FALL tick — grace ticks are EXCLUDED. Pacing signals (§3.1) stay pure. |
| `duration_seconds` | float | 0.0 – 2000.0 | `duration_ticks / 30.0`. Convenience field — derivable, but saves aggregation effort. Inherits the grace-exclusion semantics of `duration_ticks`. |
| `first_engagement_tick` | int | 0 – 60,000; `-1` if none | First tick where any combat unit dealt damage to any other unit. `-1` if no combat occurred (stalemate with no contact). |
| `timeout` | bool | | `true` if match exited via the 60,000-tick ceiling. Redundant with `outcome == "stalemate"` but explicit — makes filter queries simpler. **v1.1.0:** the timeout boundary is checked in the tick-driven cleanup-phase path (§2.3), so the recorded boundary tick is run-reproducible (DET-3). |

#### Per-team fields (`iran.*` and `turan.*`)

Both teams emit identical field shapes. Turan fields reflect the AI's state, not a human player's.

| Field | Type | Description |
|---|---|---|
| `throne_destroyed` | bool | Whether this team's Throne reached HP=0. Exactly one team should have `true` in a non-stalemate match. |
| `throne_hp_pct_at_end` | float (0.0–100.0) | Throne HP as percentage of `bldg_throne.max_hp` at match end. For the losing team, this is 0.0. |
| `workers_alive_at_end` | int | Kargar units alive when match ends. |
| `combat_units_alive_at_end` | int | Non-worker combat units alive (Piyade, Kamandar, Savar, Asb-savar, Turan mirrors). |
| `buildings_alive_at_end` | int | Buildings alive excluding the Throne (Throne is captured in `throne_hp_pct_at_end`). |
| `buildings_destroyed` | int | Buildings destroyed during this match (not counting Throne — Throne is the win-condition). |
| `coin_x100_at_end` | int | `ResourceSystem` coin balance at match end in x100 fixed-point (per Sim Contract §1.6). |
| `grain_x100_at_end` | int | `ResourceSystem` grain balance at match end in x100 fixed-point. |
| `farr_x100_at_end` | int | `FarrSystem` Farr value at match end in x100 fixed-point. Starting Farr = 5000 (50.0 × 100). **v1.1.0:** `FarrSystem` tracks IRAN's single civilization meter only; `turan.farr_x100_at_end` emits the **`-1` sentinel** ("not separately tracked") — NOT Iran's value. Aggregators MUST exclude `-1` from Turan Farr statistics (a self-consistent-but-wrong proxy produces confident wrong conclusions — balance-engineer self-flag). |
| `units_produced_total` | int | Total units spawned from production buildings this match. Workers spawned at match-start are excluded (those are structural, not produced). |
| `buildings_constructed_total` | int | Total buildings completed (construction_finalized signal emitted) this match. Throne is excluded (pre-placed, not constructed). |

**Note on Turan fields:** TuranController (Wave 3B) operates as a timer-based probe attacker with no build queue, resource system, or construction system. For Turan: `workers_alive_at_end` = 0 (Turan has no workers in current implementation), `coin_x100_at_end` and `grain_x100_at_end` = 0 (Turan has no ResourceSystem economy), `buildings_constructed_total` = 0, `units_produced_total` = 0 (Turan units are spawned directly by TuranController, not via a production building). These fields are included for symmetry and forward-compatibility — when Turan gets a full economy (Phase 4+), the schema already supports it.

#### Events fields

| Field | Type | Description |
|---|---|---|
| `turan_probes_fired` | int | **v1.1.0:** number of probe waves LAUNCHED — TuranController FSM `idle → probing` transitions, read at match end via the documented `TuranController.get_probes_fired_total()` accessor. A probe still in flight when the match ends counts as fired. (v1.0.0 said `probing → idle` resolutions; the launch edge is what the `floor(duration_ticks / cadence)` diagnostic in §3.2 actually predicts.) |
| `turan_units_deployed_total` | int | Total Turan units that entered the match, counted via `unit_spawned` emits with `team == TEAM_TURAN`. **v1.1.0 semantic note:** the current TuranController COMMANDS pre-spawned roster units rather than spawning probe waves, so today this equals the Turan starting roster plus any future wave spawns. When Phase 6 Turan production lands, wave spawns flow through the same channel with no schema change. |
| `buildings_destroyed_total` | int | Sum across both teams of `buildings_destroyed`. **v1.1.0:** aggregated live from `EventBus.building_destroyed` (Throne kind excluded — the Throne is the win-condition, not a destruction stat). |
| `units_killed_total` | int | Total units that reached HP=0 across both teams. **v1.1.0:** aggregated live from `EventBus.unit_died` (post-ARCH-1 this channel is UNIT-only — building deaths are not units). |
| `farr_drain_events_total` | int | Number of `apply_farr_change()` calls with negative EFFECTIVE (post-clamp) delta during the match, counted via `EventBus.farr_changed`. A drain requested while Farr sits at the floor reports a 0.0 effective delta and is not counted. |
| `kaveh_event_triggered` | bool | Whether `FarrSystem` entered the Kaveh Event state (`farr < kaveh_trigger_threshold = 15` for `kaveh_grace_ticks = 900`). **Still deferred at v1.1.0** — FarrSystem has no Kaveh state to read (Phase 5); always `false`. |
| `iran_first_piyade_tick` | int | Tick when the first Iran Piyade was spawned from Sarbaz-khaneh. `-1` if no Piyade was produced. Key signal for build-order affordability validation. |

### §2.3 Match-End Semantics: Throne-Fall Grace Window + Tick-Driven Timeout (v1.1.0)

**Grace window.** With the event counters wired (v1.1.0), an immediate exit on `throne_destroyed` would drop same-tick and trailing events that fire after the runner's handler (death cascades, drain emits — the §9.B5 probe's concerns, empirically real once counters aggregate). The runner therefore:

1. On the FIRST `throne_destroyed`: latches `winner_team` / `outcome` / `duration_ticks` (= the throne-fall tick) and arms `grace_end_tick = SimClock.tick + Constants.SIM_THRONE_GRACE_TICKS` (structural constant, 30 ticks = 1s @ 30Hz).
2. Keeps ALL event subscriptions live through the grace — events during the grace window ARE counted in the `events` block and per-team `buildings_destroyed`.
3. Emits the NDJSON + quits from the sim_phase `&"cleanup"` handler on the first tick where `SimClock.tick >= grace_end_tick`.

Consequences for consumers:
- `duration_ticks` / `duration_seconds` record the **throne-fall tick** — grace ticks are excluded (pacing-signal purity). Wall-clock match length is `duration_ticks + ≤30` ticks; no field records the emit tick.
- Counter fields (`units_killed_total`, `buildings_destroyed*`, `farr_drain_events_total`, ...) include events from up to `SIM_THRONE_GRACE_TICKS` ticks after the throne fell. Alive-at-end fields (`*_alive_at_end`, `throne_hp_pct_at_end`, resources, Farr) are captured at grace-end — combat usually quiets within the 1s window, but a kill landing during grace IS reflected.
- A second `throne_destroyed` during the grace does NOT flip the result (first-throne-wins); it is logged as `throne_destroyed_during_grace` for match-shape forensics.

**Tick-driven timeout (DET-3).** The 60,000-tick timeout is checked in the same sim_phase `&"cleanup"` path (not `_process`), so the stalemate boundary tick is a function of `SimClock.tick` alone and identical across reruns of the same seed. Timeout exits take NO grace window — nothing decisive happened that trailing events would disambiguate.

---

## §3 — Signal Classification

### §3.1 Calibration-Relevant Signals

These signals directly drive tuning decisions in balance.tres. After a batch run, look at these first.

| Signal | Calibration use |
|---|---|
| `outcome` distribution | If Iran wins <40% or >70% of matches, the build-order or Turan probe cadence needs adjustment before drawing army-composition conclusions. |
| `duration_ticks` (+ `duration_seconds`) | Primary match-pacing signal. Target: p50 in the 27,000–45,000 tick range (15–25 min @ 30Hz). Stalemate rate (timeout hits) = late-game pressure gap evidence. |
| `first_engagement_tick` | If > 5,000 ticks, Iran has too long an uncontested economy window; Turan probe cadence may be too slow. If < 2,000 ticks, Iran can't build any defense before first contact. |
| `iran.throne_hp_pct_at_end` (when Turan wins) | How deep did Turan penetrate? If Throne is near-full when Turan wins, Iran lost by attrition rather than decisive assault — suggests probe army is too large or Iran recovery is too slow. |
| `turan.throne_hp_pct_at_end` (when Iran wins) | How damaged was Turan's Throne? If always near-zero, Iran's Piyade army is oversized relative to Turan defenses. If > 50%, Iran attack needs assistance. |
| `iran.combat_units_alive_at_end` | Army surplus at match end. > 5 alive = Iran was dominant; consider tuning Turan probe size up. |
| `events.iran_first_piyade_tick` | Build-order affordability validation. Should be ≤ 2,400 ticks for the schedule to produce a defender before first probe (tick 3,600). |
| `events.kaveh_event_triggered` | Farr system health signal. If this fires in > 20% of matches, something is systematically draining Farr — either the Turan probe is too effective at killing workers, or a drain rate is miscalibrated. |
| `iran.farr_x100_at_end` | End-of-match Farr. Starting Farr = 5000. If average end-Farr < 2000 in winning matches, the Kaveh threshold (1500) is at risk of being triggered in normal play; may need drain-rate adjustment. |

### §3.2 Diagnostic-Only Signals

These signals are useful when investigating an outlier or a failed match, but are not routinely read during calibration passes.

| Signal | Diagnostic use |
|---|---|
| `seed` | Reproduce a specific match for step-debugging. |
| `timeout` | Flag matches that need individual inspection (stalemates hide outcomes). |
| `iran.workers_alive_at_end` | Worker survivability check. If consistently 0–1 at match end, Turan is targeting workers — may be intentional or a pathfinding artifact. |
| `iran.buildings_alive_at_end` / `iran.buildings_destroyed` | Economy damage estimate. Useful for identifying whether Turan probes are winning by Throne assault vs. economic destruction. |
| `iran.coin_x100_at_end` / `iran.grain_x100_at_end` | Resource surplus or starvation. If `coin_x100_at_end` > 10,000 in a losing match, Iran had resources but couldn't convert them — production bottleneck or pop-cap issue. |
| `events.turan_probes_fired` | TuranController behavior check. Should be `floor(duration_ticks / 3600)` ± 1 for Normal cadence. Divergence = probe-firing bug. |
| `events.turan_units_deployed_total` | Turan military output sanity check. |
| `events.buildings_destroyed_total` | Engagement intensity marker. 0 = only Throne fell (decisive). > 5 = attritional match. |
| `events.farr_drain_events_total` | Drain frequency. If > 50 in a single match, something is emitting drain on every tick — points to a loop bug. |
| `iran.units_produced_total` | Total unit production. Cross-reference with `combat_units_alive_at_end` to estimate combat losses. |
| `iran.buildings_constructed_total` | Build-order execution depth. If = 1 (only Sarbaz-khaneh), DummyIranController's economy stalled early. |

---

## §4 — Aggregation Conventions

The aggregation script (Track 3) should produce summary statistics for each signal. Conventions:

### §4.1 Distributional signals (use percentiles, not mean)

These signals have non-normal distributions or are sensitive to outliers:

- `duration_ticks` → report p10, p25, p50, p75, p95, max
- `first_engagement_tick` → report p25, p50, p75, max (and count where `-1`)
- `iran.throne_hp_pct_at_end` → report p25, p50, p75 (separately for Iran-win and Turan-win matches)
- `turan.throne_hp_pct_at_end` → report p25, p50, p75
- `events.iran_first_piyade_tick` → report p50, p95, count-of-(-1)

### §4.2 Binary / categorical signals (use counts + rates)

- `outcome` → count and % of `iran_win`, `turan_win`, `stalemate`
- `timeout` → count and %
- `iran.throne_destroyed`, `turan.throne_destroyed` → implicit from `outcome`
- `events.kaveh_event_triggered` → count and %

### §4.3 Summable signals (use total + mean-per-match)

- `events.turan_probes_fired` → total and mean per match
- `events.turan_units_deployed_total` → total and mean per match
- `events.buildings_destroyed_total` → total and mean per match
- `events.units_killed_total` → total and mean per match
- `events.farr_drain_events_total` → total and mean per match
- `iran.units_produced_total` → total and mean per match
- `iran.buildings_constructed_total` → total and mean per match

### §4.4 End-state resource signals (use median, report by outcome)

Report median separately for Iran-win vs Turan-win matches:
- `iran.coin_x100_at_end`, `iran.grain_x100_at_end`, `iran.farr_x100_at_end`
- `iran.workers_alive_at_end`, `iran.combat_units_alive_at_end`, `iran.buildings_alive_at_end`

---

## §5 — Example Match JSON

### Example A: Iran decisive win

```json
{"match_id":"match_0001","seed":987654321,"outcome":"iran_win","winner_team":1,"duration_ticks":22140,"duration_seconds":738.0,"first_engagement_tick":3598,"timeout":false,"iran":{"throne_destroyed":false,"throne_hp_pct_at_end":91.2,"workers_alive_at_end":4,"combat_units_alive_at_end":6,"buildings_alive_at_end":4,"buildings_destroyed":0,"coin_x100_at_end":18400,"grain_x100_at_end":9500,"farr_x100_at_end":4820,"units_produced_total":8,"buildings_constructed_total":4},"turan":{"throne_destroyed":true,"throne_hp_pct_at_end":0.0,"workers_alive_at_end":0,"combat_units_alive_at_end":0,"buildings_alive_at_end":0,"buildings_destroyed":1,"coin_x100_at_end":0,"grain_x100_at_end":0,"farr_x100_at_end":-1,"units_produced_total":0,"buildings_constructed_total":0},"events":{"turan_probes_fired":6,"turan_units_deployed_total":30,"buildings_destroyed_total":1,"units_killed_total":28,"farr_drain_events_total":9,"kaveh_event_triggered":false,"iran_first_piyade_tick":2401}}
```

### Example B: Turan win (Iran overwhelmed)

```json
{"match_id":"match_0003","seed":111222333,"outcome":"turan_win","winner_team":2,"duration_ticks":8720,"duration_seconds":290.7,"first_engagement_tick":3601,"timeout":false,"iran":{"throne_destroyed":true,"throne_hp_pct_at_end":0.0,"workers_alive_at_end":0,"combat_units_alive_at_end":0,"buildings_alive_at_end":0,"buildings_destroyed":3,"coin_x100_at_end":2200,"grain_x100_at_end":0,"farr_x100_at_end":800,"units_produced_total":1,"buildings_constructed_total":2},"turan":{"throne_destroyed":false,"throne_hp_pct_at_end":100.0,"workers_alive_at_end":0,"combat_units_alive_at_end":4,"buildings_alive_at_end":0,"buildings_destroyed":0,"coin_x100_at_end":0,"grain_x100_at_end":0,"farr_x100_at_end":-1,"units_produced_total":0,"buildings_constructed_total":0},"events":{"turan_probes_fired":2,"turan_units_deployed_total":10,"buildings_destroyed_total":3,"units_killed_total":8,"farr_drain_events_total":14,"kaveh_event_triggered":true,"iran_first_piyade_tick":-1}}
```

**Diagnostic read on Example B:** `iran_first_piyade_tick = -1` — Iran never produced a Piyade before losing. This is the build-order infeasibility scenario the affordability table (§6) is designed to predict. If the schedule is structurally feasible, this should rarely occur.

### Example C: Stalemate (timeout)

```json
{"match_id":"match_0007","seed":555666777,"outcome":"stalemate","winner_team":-1,"duration_ticks":60000,"duration_seconds":2000.0,"first_engagement_tick":3602,"timeout":true,"iran":{"throne_destroyed":false,"throne_hp_pct_at_end":62.0,"workers_alive_at_end":3,"combat_units_alive_at_end":5,"buildings_alive_at_end":2,"buildings_destroyed":2,"coin_x100_at_end":44200,"grain_x100_at_end":28000,"farr_x100_at_end":3600,"units_produced_total":22,"buildings_constructed_total":4},"turan":{"throne_destroyed":false,"throne_hp_pct_at_end":45.0,"workers_alive_at_end":0,"combat_units_alive_at_end":3,"buildings_alive_at_end":0,"buildings_destroyed":0,"coin_x100_at_end":0,"grain_x100_at_end":0,"farr_x100_at_end":-1,"units_produced_total":0,"buildings_constructed_total":0},"events":{"turan_probes_fired":16,"turan_units_deployed_total":80,"buildings_destroyed_total":2,"units_killed_total":72,"farr_drain_events_total":38,"kaveh_event_triggered":false,"iran_first_piyade_tick":2402}}
```

**Diagnostic read on Example C:** `coin_x100_at_end = 44200` (442 coin banked) with no win = late-game economic stagnation. Iran accumulated coin but the Turan AI kept the Throne at 45% without a decisive push. This is the "late-game economic pressure gap" open design question from `QUESTIONS_FOR_DESIGN.md` 2026-05-28 entry made concrete.

---

## §6 — Iran Build-Order Affordability Table

**Purpose:** Cross-check the §3 Q4 build-order schedule against `balance.tres` costs and the current income model. Determines whether the DummyIranController's hardcoded schedule is structurally feasible (Iran can afford each step at the tick it's scheduled) or infeasible (Iran would need to wait).

### §6.1 Income model assumptions

From `balance.tres` and `game/scripts/world/resource_nodes/mine_node.gd`:

| Parameter | Source | Value |
|---|---|---|
| Starting coin | `economy_cfg.starting_coin` | 150 |
| Starting grain | `economy_cfg.starting_grain` | 50 |
| Coin per gather trip | `mine_node.gd _WAVE_1A_YIELD_PER_TRIP_X100 = 1000` (10 coin) | **10 coin/trip** |
| Dwell ticks at mine | `mine_node.gd _WAVE_1A_EXTRACT_TICKS = 60` | 60 ticks (2s) |
| Max workers per mine | `mine_node.gd max_slots = 1` (Phase 3 simplification) | **1 worker slot per mine** (not 2) |
| Worker move speed | `unit_kargar.move_speed = 3.5 m/s` | 3.5 m/s |
| SIM_HZ | constants | 30 Hz |

**Critical mismatch flag:** `balance.tres res_node_cfg.mine_max_workers = 2` but `mine_node.gd max_slots = 1`. The .tres value is not yet consumed by MineNode (wave-1A hardcoded). The effective limit is **1 worker per mine slot**, not 2. This is a known TODO in `mine_node.gd`.

**Round-trip model:** On a typical map, mines are ~15m from the Throne. At 3.5 m/s: one-way walk = ~4.3s = ~129 ticks. Round-trip = 2 × 129 + 60 dwell = **318 ticks** (~10.6s per gather cycle).

However, the map may have multiple mines. Assuming 5 workers and 3 nearby mines (2 have 1 slot filled, 3rd available, 4th and 5th workers queue at occupied mines):
- 3 workers gather in parallel (1 per mine slot) → ~3 trips per 318 ticks cycle
- 2 workers queue/wait → contributes delayed gather once a slot frees
- Net coin income with 5 workers, 3 mine slots: approximately **3 trips per 318 ticks = ~0.094 coin/tick**

Using the round number **~10 coin per 320 ticks from 3 active workers** (conservative), and adding the 2 queued workers at reduced effective rate (~5 coin per 320 ticks from queued pair):

**Effective income rate with 5 workers, 3 mines:** approximately **15 coin per 320 ticks ≈ 0.047 coin/tick**

This is a conservative lower bound. The DummyIranController should maximize mine occupancy by sending workers to different mines. For the feasibility table, a range is shown.

### §6.2 Feasibility table

| Tick | Action | Cost (coin / grain) | Cumulative income (low / high) | Total coin available (low / high) | Grain available | Feasible? | Notes |
|---|---|---|---|---|---|---|---|
| 0 | Match start — 5 workers dispatched to mines | — | 0 | **150** / **150** | 50 | n/a | Starting resources. Workers begin walking to nearest mines. |
| ~200 | First gather trips completing (workers arrive + dwell) | — | 30 / 50 | 180 / 200 | 50 | n/a | First coin from mines begins arriving at ~tick 190-200. |
| 300 | Build **Khaneh #1** | 50 coin / 0 grain | +14 / +24 | **164** / **174** | 50 | **YES** | 150 + ~14-24 income ≈ 164-174 coin. Cost = 50. Surplus: 114-124 coin. One worker pulled from gathering for 90-tick construction window. Worker loss during build: ~0-3 coin. Negligible. |
| 390 | Khaneh #1 complete (`construction_ticks = 90`) | — | — | ~220 / ~250 | 50 | n/a | Worker returns to gathering. Pop cap now 10 (5 start workers within it). |
| 1200 | Build **Sarbaz-khaneh #1** | 100 coin / 0 grain | +112 / +188 | **~262** / **~338** | 50 | **YES** | By tick 1200: 150 + (1200 × 0.047 low) ≈ 206 low, or (1200 × 0.094 high → but capped by 3 slots) = up to 338. Even low estimate: 206 − 50 (Khaneh) = 156 + ~56 more = ~212 at tick 1200 before Sarbaz cost. After 100 coin build: **~112 surplus**. |
| 1200 | Sarbaz-khaneh construction begins (`construction_ticks = 780`) | — | — | ~112 / ~188 surplus | 50 | n/a | Worker pulled from gathering for 780 ticks. Income drops by ~0.009-0.016 coin/tick during this window. |
| 1980 | Sarbaz-khaneh complete | — | +55 / +88 in construction window | ~167 / ~276 | 50 | n/a | Worker returns to gathering. First unit can be queued. |
| 2400 | **Piyade #1 trained** | `train_piyade_cost_coin = 50` / `train_piyade_cost_grain = 10`, `train_piyade_dwell_ticks = 90` | +~19 / +32 in window | ~186 / ~308 | **40** | **YES** | Sarbaz-khaneh completes at ~1980. Piyade training dwell = 90 ticks → spawn at tick ~2070, not 2400. The brief's tick 2400 is *conservative* — first Piyade can emerge as early as tick **~2070**. Grain cost = 10. Grain remaining: 40. |
| 3600 | **First Turan probe arrives** (Normal cadence) | — | — | ~250+ / ~400+ | ~35 | n/a | Iran should have ≥1 Piyade (produced at ~2070-2400). Threshold met. |
| 3600 | Build **Khaneh #2** | 50 coin / 0 grain | — | ~200+ / ~350+ | ~35 | **YES** | Ample surplus by this point. |
| 4800 | **Piyade #2 trained** | 50 coin / 10 grain | — | ~180+ | ~25 | **YES** | Third training cycle assuming Sarbaz-khaneh is producing continuously from tick ~1980. |

**Tick reference for Sarbaz-khaneh training cadence:**
- `train_piyade_dwell_ticks = 90` (from balance.tres bldg_sarbaz_khaneh, Wave 3A.6 training schema)
- If Sarbaz-khaneh completes at tick ~1980, training begins immediately: Piyade #1 at tick ~2070, Piyade #2 at ~2160, etc.
- Brief says "Piyade #1 at tick 2400" — this is conservatively late. The schedule has margin.

### §6.3 Feasibility verdict

**The §3 Q4 build-order is FEASIBLE** against current balance.tres values. No step is infeasible at the scheduled tick.

Key findings:

1. **First Piyade emerges earlier than the brief assumes.** Sarbaz-khaneh completes at tick ~1980 (not 2400). Piyade #1 exits at tick ~2070 under continuous queue. The brief's "tick 2400" is a conservative estimate that adds ~330 ticks of buffer. This is **good** — it means DummyIranController has a defender ready ~90s before the first Turan probe.

2. **Income is mine-layout-sensitive.** The feasibility depends on how many unique mine slots are accessible. With 3+ mines near the Iran Throne, 5 workers generate ~15 coin per ~320 ticks. With only 1-2 mines, workers queue and income drops significantly. **The headless runner's map layout must place at least 3 accessible mines within ~20m of the Iran Throne** for the build-order to work as intended.

3. **Grain is tight but not blocking.** Starting grain = 50. Khaneh costs 0 grain. Sarbaz-khaneh costs 0 grain. Piyade training costs 10 grain each. By first probe (tick ~3600), Iran has spent 10-20 grain on Piyades with 30-40 grain remaining. No grain-generating building (Mazra'eh) is in the MVP build-order. If Piyade production accelerates beyond 3-4 units, grain will run out. **Recommendation: cap DummyIranController Piyade production at 4 units before adding a Mazra'eh step**, or accept that later training rounds pause due to grain starvation. Flag this in `QUESTIONS_FOR_DESIGN.md` if it becomes observable in batch data.

4. **Mine depletion risk.** The balance.tres value `mine_initial_stock = 1500` is **not consumed by the current MineNode implementation** — MineNode uses hardcoded `_WAVE_1A_RESERVES_X100 = 10000` (100 coin). This means mines hold 100 coin each (not 1500), and with 5 workers at 10 coin/trip, each mine exhausts in **10 trips**. At ~3 trips per mine per minute from the occupying worker, that's ~3-4 minutes per mine. On a typical 15-25 min match, early mines will be depleted; **DummyIranController must be written to retarget workers when their mine runs dry**. This is a Track 2 (engine-architect) implementation concern, but the balance-engineer flags it here because it affects income sustainability assumptions in the feasibility table.

### §6.4 Proposed adjusted schedule (balance-engineer recommendation)

The §3 Q4 schedule is feasible. The only proposed refinement is making tick annotations accurate:

```
Tick 0       : 5 workers → nearest coin mines
Tick 300     : 1 worker → Khaneh #1 (pops: +5 = 10 total cap)
Tick 390     : Khaneh #1 complete; worker returns to gather
Tick 1200    : 1 worker → Sarbaz-khaneh #1
Tick 1980    : Sarbaz-khaneh complete; queue Piyade #1 immediately
Tick ~2070   : Piyade #1 spawns (dwell_ticks = 90) — NOT tick 2400
Tick 2400    : [keep as schedule checkpoint] — by this point Iran has 1-2 Piyades
Tick 3600    : Turan probe 1 arrives; Iran has ≥1 defender (feasible, confirmed)
Tick 3600    : 1 worker → Khaneh #2 (to support further military production)
Tick 4800    : Continue Piyade production (Piyade #3 or #4 in queue)
```

The brief's `tick 2400 = "Piyade #1"` annotation can remain in the brief as a conservative worst-case checkpoint; DummyIranController may produce the unit earlier.

### §6.5 — 2026-06-08 SSOT fix note

**Status of §6.1–§6.4 above: income model now conservative/stale.** The `wave/b1-mine-ssot` fix (review ARCH-5 / GP-3, Track-1 Findings A+B) wired MineNode to `balance.tres economy.resource_nodes.*` — the wave-1A hardcodes this table was built on are gone:

- **Mine reserves: 100 → 1500 coin per mine** (`mine_initial_stock` is now live). The §6.3 finding 4 "mines hold 100 coin / exhaust in 10 trips / depleted in ~3-4 minutes" math no longer applies — a mine now sustains 150 trips at 10 coin/trip.
- **Worker slots per mine: 1 → 2** (`mine_max_workers` is now live). The §6.1 "1 worker slot per mine (not 2)" row and the **Critical mismatch flag** are resolved; with 3 mines near the Throne, 5 workers no longer queue — parallel income is higher than every estimate above.
- Unchanged values: `coin_yield_per_trip = 10` and dwell `trip_full_load_ticks = 60` (also now read from the .tres rather than hardcoded — same numbers, now designer-tunable).

Net effect: every income figure in §6.1–§6.2 is now a **lower bound**; the §6.3 FEASIBLE verdict still holds (income only went up), but the depletion-risk finding and the slot-contention assumptions are stale. **Table re-run is queued for the next balance pass** — balance-engineer owns the §6 rewrite; this subsection is the implementation-side flag, not a table revision.

---

## §7 — Implementation Notes for Engine-Architect (Track 2)

### §7.1 Field capture points

| Field | Where to capture |
|---|---|
| `duration_ticks` | `SimClock.tick` at `EventBus.throne_destroyed` (latched at throne-fall — grace ticks excluded, §2.3) or at the tick-driven timeout boundary |
| `first_engagement_tick` | Subscribe to `EventBus.unit_health_zero` or CombatComponent first-hit event; latch on first emission |
| `iran.throne_hp_pct_at_end` | Read from Iran Throne node's HealthComponent at match end |
| `iran.coin_x100_at_end` | `ResourceSystem.get_coin_x100(Constants.TEAM_IRAN)` |
| `iran.grain_x100_at_end` | `ResourceSystem.get_grain_x100(Constants.TEAM_IRAN)` |
| `iran.farr_x100_at_end` | `FarrSystem.get_farr_x100()` (single Farr value for Iran). `turan.farr_x100_at_end` = `-1` sentinel, §7.3 |
| `iran.buildings_destroyed` / `turan.buildings_destroyed` | Count `EventBus.building_destroyed` emits per team, Throne kind excluded (v1.1.0) |
| `events.units_killed_total` | Count `EventBus.unit_died` emits (UNIT-only channel post-ARCH-1) (v1.1.0) |
| `events.farr_drain_events_total` | Count `EventBus.farr_changed` emits with negative effective delta (v1.1.0) |
| `events.turan_units_deployed_total` | Count `EventBus.unit_spawned` emits with `team == Constants.TEAM_TURAN` (v1.1.0; see §2.2 semantic note) |
| `events.turan_probes_fired` | Read `TuranController.get_probes_fired_total()` at match end (documented accessor; counts `idle → probing` launches) (v1.1.0) |
| `events.kaveh_event_triggered` | Deferred — FarrSystem has no Kaveh state to read until Phase 5; emit `false` |
| `events.iran_first_piyade_tick` | Subscribe to `EventBus.unit_spawned`; latch first emission with `unit_type == &"piyade"`, `team == Constants.TEAM_IRAN`, **and `SimClock.tick > 0`** (tick-0 roster spawns are structural, not trained — v1.1.1) |
| `iran.units_produced_total` / `turan.units_produced_total` | Count `EventBus.unit_spawned` emits per team with `SimClock.tick > 0` (the production-source discriminator: tick-0 = match-start roster, excluded per §2.2) (v1.1.1) |
| `iran.buildings_constructed_total` / `turan.buildings_constructed_total` | Count `EventBus.building_constructed(team, kind, unit_id)` emits per team (typed Stage-2 completion channel; emitted by UnitState_Constructing after the local `construction_finalized`) (v1.1.1) |

### §7.2 Fixed-point convention

All `_x100` fields follow the Sim Contract §1.6 fixed-point convention: the integer value equals the actual value × 100. For example, 50 Farr = `farr_x100_at_end = 5000`.

### §7.3 Turan field notes

`turan.coin_x100_at_end`, `turan.grain_x100_at_end`: set to `0` — TuranController does not use `ResourceSystem`. Emit `0` rather than omitting the field (schema symmetry matters for aggregation scripts that assume identical field sets for both teams).

`turan.farr_x100_at_end`: `FarrSystem` tracks a single Farr value for Iran; Turan Farr is not separately tracked. **v1.1.0:** emit the **`-1` sentinel** ("not separately tracked"). The v1.0.0 instruction to emit Iran's value as a proxy is REVOKED per balance-engineer's self-flag: self-consistent-but-wrong proxy data produces confident wrong conclusions (e.g., "Turan Farr correlates with Iran wins" — trivially true when it IS Iran's Farr). Aggregation scripts MUST exclude `-1` from Turan Farr statistics. The `// TODO: separate per-team Farr when Phase 5 campaign adds Turan Farr drain` comment stays in the runner.

---

## §8 — Known Gaps + Forward-Watch

| Gap | Impact | Resolution path |
|---|---|---|
| ~~`mine_node.gd` hardcoded reserves/slots~~ **RESOLVED 2026-06-08 (wave B1)** | Mine tunables (reserves, max_slots, yield, extract_ticks) now read from balance.tres with §9.L9 visible fallbacks — see §6.5 | §6 affordability table re-run queued for the next balance pass (the income model is now stale-conservative) |
| Turan Farr not separately tracked | `turan.farr_x100_at_end` emits the `-1` sentinel (v1.1.0; the v1.0.0 Iran-value proxy is revoked) | Revisit at Phase 5+ campaign design |
| `kaveh_event_triggered` always `false` | FarrSystem has no Kaveh state to read | Wire when the Kaveh Event ships (Phase 5) |
| `units_produced_total` tick>0 rule vs §2.2 definition (forward-watch, v1.1.1) | The discriminator counts ANY post-start spawn as "produced". Equivalent to the §2.2 "spawned from production buildings" definition today (only buildings spawn after tick 0). **Phase-6 watch:** if TuranController gains direct wave-spawning, `turan.units_produced_total` silently diverges from its definition | When Phase-6 Turan production lands, either route wave-spawns through production buildings or add a `source` field to the `unit_spawned` payload — trip over this row deliberately |
| No `grain_yield` signals in current per-match output | Grain economy is invisible in batch data | Add `iran.grain_gathered_total` as a future field if grain bottlenecks emerge in batch data |
| `first_engagement_tick` proxies on `unit_health_zero` | First HP-zero may lag first-hit by several ticks; AND post-ARCH-1 (session-11) the channel is Unit-namespace only, so **building-only engagements don't move the latch** (closer to the §2.2 "combat unit dealt damage" semantic, but a building-rush opening reads as `-1` until a unit dies) | Promote the existing `[combat] fire` log site to an `EventBus.damage_applied` signal if first-hit precision becomes calibration-relevant |

---

## §9 — Revision History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0.0 | 2026-06-03 | balance-engineer | Initial contract: NDJSON schema, signal classification, aggregation conventions, affordability table. |
| 1.1.0 | 2026-06-08 | engine-architect (Track B2) | Event counters wired live (review finding GP-6): `units_killed_total` (unit_died), per-team `buildings_destroyed` + total (building_destroyed, Throne excluded), `farr_drain_events_total` (farr_changed negative delta), `turan_units_deployed_total` (unit_spawned team==TURAN), `turan_probes_fired` (TuranController accessor; semantics changed probing→idle ⇒ idle→probing launch edge). `turan.farr_x100_at_end` ⇒ `-1` sentinel (balance-engineer farr-proxy self-flag; v1.0.0 Iran-value proxy revoked; aggregator excludes `-1`). New §2.3: throne-fall grace window (`Constants.SIM_THRONE_GRACE_TICKS` = 30 ticks; `duration_ticks` records throne-fall tick, grace excluded) + tick-driven timeout (DET-3). §5 examples updated to match. |
| 1.1.1 | 2026-06-08 | lead (wave-B integration fix-up) | Last two GP-6 zero-fields wired live: `units_produced_total` ← `unit_spawned` with **SimClock.tick > 0** as the production-source discriminator (tick-0 roster spawns are structural, per the §2.2 definition that always required this); `buildings_constructed_total` ← new typed `EventBus.building_constructed(team, kind, unit_id)` Stage-2 completion channel (mirrors `building_destroyed` shape; emitted by UnitState_Constructing after the local `construction_finalized`). Same tick>0 rule now guards the `iran_first_piyade_tick` latch — observation smoke showed it latching pre-spawned roster piyades at tick 0, making the build-order-validation signal dead-at-0 every match. Also noted: post-ARCH-1 the `first_engagement_tick` proxy is Unit-namespace only (building-only engagements don't move the latch — closer to the §2.2 "combat unit dealt damage" semantic). |

---

*End of AI_VS_AI_RESULT_FORMAT.md v1.1.1*
