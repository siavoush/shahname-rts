# AI Difficulty Values

*Status: **1.1.0** ratified 2026-05-01.*
*Outcome of Sync 5 (Open Consultation, ai-engineer + balance-engineer).*
*Foundation: `01_CORE_MECHANICS.md` §12, `docs/TESTING_CONTRACT.md` §1.2 (AIConfig sub-resource).*

> Per `01_CORE_MECHANICS.md` §12: difficulty differs by **resource asymmetries + aggression timing**, not AI sophistication. Same FSM, same logic, different numbers.

---

## 1. The Values

| Difficulty | Wave cadence | AI gather multiplier | Turan tech-up time | AI attack army threshold |
|------------|--------------|----------------------|--------------------|--------------------------|
| **Easy**   | 180s (5400 ticks) | 0.75× | 6 min (10800 ticks) | 8 units |
| **Normal** | 120s (3600 ticks) | 1.00× | 5 min (9000 ticks)  | 12 units |
| **Hard**   | 90s (2700 ticks)  | 1.25× | 4 min (7200 ticks)  | 16 units |

Tick rate: 30Hz per Sim Contract. All values are starting points for Phase 6 AI-vs-AI simulation tuning.

## 2. Why these values

**Wave cadence (asymmetric AI aggression timing):** straightforward — slower waves on Easy give the player more time to build economy and respond; faster waves on Hard create real pressure.

**AI gather multiplier (asymmetric economy):** chosen over an alternate "player bonus" approach. Slowing AI economy directly delays AI army composition, which is what makes Easy *learnable* (the player can out-tech and out-produce the AI), not just *forgiving*. A player bonus would help the player but leave AI's wave timing intact, and the early-wave-arrival problem is the actual pain point on Easy.

**Tech-up timing:** more impactful than wave frequency for midgame feel (per balance-engineer). Normal is pinned at 5 minutes per `01_CORE_MECHANICS.md` §12. Easy is set to 6 minutes (±1 from Normal) rather than the originally proposed 8 — 8 minutes would keep Turan in Tier 1 for over half a 15-minute match, producing a boring matchup with no cavalry pressure for the player to face. 6 minutes gives the player a meaningful tech-up window without making the AI toothless. Hard at 4 minutes puts Turan cavalry on the field while the player is still in piyade-and-archer, creating genuine pressure.

**Attack army threshold (per ai-engineer):** prevents Hard's faster wave cadence from sending thinly-populated armies that die at the player's wall. Each wave is *bigger* on Hard, not just *more frequent*. The combination produces real pressure rather than spam-feel.

**What we deliberately did NOT change per difficulty:** scout aggressiveness, unit-composition ratios, retreat thresholds, target priorities, build-order tightness. All slip toward "smarter AI per difficulty" which §12 forbids. Tune once for Normal, leave alone. Sophistication arrives via tuning, not new dials.

## 3. Success Criteria

Two framings — one for human playtest, one for headless AI-vs-AI simulation. Both must pass before MVP ships.

### Human playtest (Phase 8 deliverable)
- **Easy:** novice player (Siavoush in his first 5 matches) wins ≥60% of matches.
- **Normal:** experienced RTS player (50+ matches in any RTS) wins ~50%, match length median 18-22 min.
- **Hard:** same experienced player wins <30%, losing to economic pressure rather than single-wave wipe.

### AI-vs-AI simulation (Phase 6 deliverable, runs nightly per Testing Contract §4)
- **Easy: median match length 20-28 minutes.** Slight overshoot of the 15-25 minute spec ceiling is acceptable — Easy is for novice players who need time to learn the loop. Shortening it requires increasing AI aggression, which defeats the purpose.
- **Normal: median match length 17-22 minutes** (centered in the 15-25 min spec target).
- **Hard: median match length 13-18 minutes, weighted toward Iran losses.** Hard should feel like economic pressure mounting until the player's position becomes untenable, not a single unstoppable wave.
- **Iran win-rate vs Normal AI:** 45-65% across 50 matches (genuinely contested, neither side dominant).
- **Kaveh Event trigger rate:** 20-40% of matches (Farr is meaningful but not deterministic).
- **Turan tier-advance tick (Normal):** 8000-10000 ticks (4.4-5.6 min, matches the 5-min spec).

If any criterion misses, the values get tuned — these are starting points, not contracts.

## 4. Tuning escape hatches

If after Phase 6 sim data:
- **Easy still feels too aggressive** → drop wave cadence to 240s before adding more dials (per ai-engineer's recommendation).
- **Hard feels like spam, not pressure** → increase `attack_army_threshold` to 20 before adjusting cadence.
- **Match length systematically too long across all difficulties** → indicates economy curve issue, not AI issue. Hand to balance-engineer for the economy retune, not this doc.
- **Match length systematically too short** → AI aggression too high; double check `attack_army_threshold` floor.

## 5. Implementation notes

Values land in `BalanceData.tres` `AIConfig` sub-resource (see Testing Contract §1.2). Format:

```gdscript
class_name AIConfig extends Resource

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

All values are exported so `BalanceData.tres` can edit them without code changes — supports Phase 5 hot-reload (per Testing Contract §1.4).

**Where the multiplier is applied.** `ai_gather_mult` is realized in `TuranController.EconomyState` as a dual-factor knob: a *target worker count* (primary dial) scales the AI's workforce directly; a *per-trip yield multiplier* is the residual fallback when worker count is capped by available mine slots. `ResourceNode.tick_extract` and `ResourceSystem.add` remain team-blind — only `TuranController` is difficulty-aware. The yield multiplier is `1.0` in the unsaturated case and only activates when `target_workers` exceeds `total_available_mine_slots`, preventing double-multiplication.

```gdscript
var target_workers := int(NORMAL_WORKER_COUNT * ai_gather_mult)
var actual_workers := mini(target_workers, total_available_mine_slots)
var yield_mult := 1.0 if actual_workers >= target_workers \
    else float(target_workers) / float(actual_workers)
```

The yield multiplier is applied at `TuranController`'s deposit handler before calling `dropoff.deposit(...)`. The player team always sees `worker_count = NORMAL_WORKER_COUNT` and `yield_mult = 1.0` regardless of difficulty. `NORMAL_WORKER_COUNT` is a code-side `const` in `TuranController` — it is the multiplier base, not a per-difficulty tunable, so it does not live in `AIConfig`.

---

*Synthesis decision by team-lead: balance-engineer's gather-penalty mechanism for Easy preferred over ai-engineer's player-bonus mechanism. Both made strong cases; the gather-penalty directly addresses the early-wave-composition problem that the player-bonus would leave intact. ai-engineer's `attack_army_threshold` insight independently correct and adopted as 4th dial. Per Manifesto Principle 4 (Lean Iteration), the dial set stays minimal — start with these four, expand only if playtest data demands it.*
