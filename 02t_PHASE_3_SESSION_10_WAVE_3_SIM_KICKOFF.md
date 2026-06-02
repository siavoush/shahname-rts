---
title: Wave 3-Sim — Headless AI-vs-AI Batch Runner (Session 10 Kickoff)
type: kickoff
status: brief-v1.0.1-design-questions-resolved-pending-mirror-review
version: 1.0.1
owner: lead
session: phase-3-session-10
wave: 3-sim
authored: 2026-05-28
authored_by: team-lead (autonomous draft post-session-9-close)
audience: gp-sys / balance-engineer / engine-architect / qa-engineer / mirror-reviewer
read_when: session-10-kickoff
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md (v0.36.0+), docs/STUDIO_PROCESS.md (§9.D11 + §9.B4 + §9.M6.3 + §9.M6.4 + §9.L11.1 from session 9 retro), 01_CORE_MECHANICS.md §0 (15-25 min match target)]
references: [BUILD_LOG.md session-9-close-retro entry, QUESTIONS_FOR_DESIGN.md "Late-game economic pressure gap" entry, balance-engineer-p3s3 + gp-sys-p3s3 session-9 retro reflections]
tags: [wave-kickoff, session-10, headless, batch-runner, ai-vs-ai, infrastructure, pre-phase-4]
---

# Wave 3-Sim — Headless AI-vs-AI Batch Runner

## §0 — TL;DR

Ship a **headless AI-vs-AI batch runner** that executes N matches without user attendance, captures match-level signals (duration, first-engagement, end-state resources, winner), and produces an aggregated report. This unblocks **balance-engineer's AI-vs-AI tuning cycle** and gives **gp-sys an automated integration-test surface** that catches BUG-H-class latent bugs at CI-time rather than user-driven live-test-time.

**Joint task across 3 agents:**
- **balance-engineer**: result-format spec + balance-signal list + classification of which signals are calibration-relevant.
- **engine-architect**: headless runner implementation (Godot `--headless --quit-after`) + match-orchestration loop + result-emission pipeline.
- **qa-engineer**: batch-shell script (N-match runner) + result-aggregation script + CI-integration shape.

**Wave-mode:** `parallel-worktrees` (3 agents on distinct surfaces) per §9.E1. Lead pre-creates worktrees at dispatch time.

**This is the LAST structural prerequisite for Phase 4+ entry.** Per gp-sys retro reflection: *"User is currently the integration-test harness; that's a missing-CI-stage artifact."* Per balance-engineer retro reflection: *"AI-vs-AI unattended runs is the most important balance tool we don't have yet."* Same gap, two angles. This wave fills it.

---

## §1 — Context + Why Now

### What session 9 closed

Session 9 shipped Wave 3-BuildingDestructibility (PR #42 merged at `ce9c5b4`). The end-to-end match loop is now structurally complete:
- Match start spawns Iran + Turan Thrones + 5 workers each + 5 Turan combat units.
- Iran player builds economy via Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh / Atashkadeh.
- Turan AI fires probe attacks every 3600 ticks (120s @ 30Hz Normal cadence).
- Combat is buildings-aware (Wave 3-BD edge-distance + target_node ref + namespace-collision bypass).
- Throne destruction emits `EventBus.throne_destroyed(team)` → Phase 8 win-screen consumer.

**Match END-TO-END IS NOW PLAYABLE.** A complete loop exists from spawn to victory.

### What's missing

**No automated way to run a match without user attendance.** Every live-test consumes ~2-3 minutes of user wall-clock just for the first Turan probe to fire. Each session's BUG-H chain (N=8 across the project lifetime) required 5-15 user-driven live-tests to diagnose. The user is the integration-test harness because no CI-stage exists for "run a full match, report what happened."

This wave fixes that.

### Concrete pain points the wave addresses

1. **AI-vs-AI tuning data missing.** balance-engineer cannot calibrate `placeholder` → `calibrated` numbers without empirical match data. Khaneh hp=200 felt right at single-attacker live-test; multi-attacker behavior is untested. The `; status: placeholder | calibrated | anchored` convention shipped at session-9-retro follow-up needs the batch-runner's data to begin promoting `placeholder` entries.

2. **Latent-bug-discovery loop is user-driven.** BUG-H1..H8 each required: hypothesize → add log → ship → user live-test → read /tmp/shahnameh.log → next hypothesis. Six iterations to find BUG-H8. With headless batch runs in CI, the same chain would have surfaced bugs in <30 seconds of unattended sim-time per match.

3. **Match-pacing validation blocked.** The "15-25 minute match" target from `01_CORE_MECHANICS.md §0` cannot be validated without unattended match-duration distributions. Currently every match-duration estimate is anecdotal from single user live-tests.

4. **Late-game economic pressure gap data missing.** balance-engineer's open question (`QUESTIONS_FOR_DESIGN.md` 2026-05-28 entry): the economy curve has no late-game pressure; AI may accumulate indefinitely. Batch runner data would empirically confirm or refute this — does the AI-vs-AI loop terminate in <25 min, or does it stall?

### Why now (not after Phase 4 lands)

Three converging signals:
- **gp-sys** retro reflection: missing CI-stage artifact (user-as-harness).
- **balance-engineer** retro reflection: AI-vs-AI is the most-important-balance-tool-not-yet-shipped.
- **Wave 3-BD's structural closure** of the destruction chain unblocks the last gameplay primitive needed for an end-to-end match.

The retro identified this as a **Wave 3-Sim joint-task candidate**. Session 10 is the moment.

---

## §2 — Scope

### In scope

1. **Headless Godot launch path.** Project loads with `godot --headless --quit-after <N-ticks>` or similar, runs N ticks of simulation, exits cleanly.

2. **Match-orchestration loop.** A "match" is one Iran-vs-Turan game from match-start to win-condition or timeout. The runner:
   - Initializes a clean match state (SimClock reset, GameState reset, ResourceSystem reset, FarrSystem reset, SpatialIndex reset, TuranController reset, FogSystem reset).
   - Sets a deterministic seed (per §3 open question).
   - Runs the sim phase loop until win-condition OR max-tick timeout.
   - Captures match-result data (winner, duration, signal aggregates).
   - Emits result to stdout / log file in machine-parseable format.

3. **Player-side AI (Iran).** Player normally plays Iran; for AI-vs-AI we need a "dummy Iran AI" that plays a fixed strategy (e.g., 5-Khaneh build-up → 5 Sarbaz training → attack-move toward Turan throne). MVP scope = ONE Iran build-order, hardcoded. Variety is a follow-up wave concern.

4. **Match-result format.** Specified by balance-engineer (Track 1). Output shape: NDJSON one line per match (canonical), aggregable via standard JSON tooling.

5. **Batch-shell script.** Run N matches sequentially (parallel comes later if needed). Aggregate to a summary report.

6. **Tests for the runner itself.** Headless runner is a TESTABLE system; tests verify:
   - One-match runner produces valid result JSON.
   - Match terminates within max-tick timeout.
   - Win-condition detection fires correctly on Throne destruction.
   - Reset discipline holds across N consecutive matches (no workspace bleed).

### Out of scope (deferred to follow-up waves)

- **Multiple Iran AI strategies.** MVP = 1 build-order. Strategy library = Phase 4+ work.
- **Multiple Turan AI difficulties.** Wave 3B Normal cadence only; Easy/Hard ships at Phase 6.
- **Parallel batch execution.** N matches sequentially is fine for MVP. Process-parallel comes later if wall-clock becomes the bottleneck.
- **Replay file format / determinism guarantees.** Reproducibility via seed is in scope; full replay-file format is Phase 6 territory.
- **AI-vs-AI tournament infrastructure.** Multiple AI variants playing round-robin = Phase 6+.
- **CI integration (GitHub Actions etc.).** The batch script needs to RUN; integrating into CI is a follow-up after the local-machine workflow is proven.

---

## §3 — Open Design Questions (resolve at brief-review time)

### Q1: Win-condition resolution — RESOLVED v1.0.1 (loremaster cultural verdict 2026-06-02)

**Current state:** `EventBus.throne_destroyed(team)` fires when a Throne reaches HP=0. No "match end" handler exists.

**Question (was):** When the runner sees `throne_destroyed(team=X)`, does it: (a) terminate immediately, (b) continue until mutual annihilation, or (c) grace period?

**RESOLUTION: (a) immediate termination on first throne destruction.** Winner = the OTHER team. Match ends, runner emits result NDJSON, exits cleanly.

**Cultural framing (loremaster-p3s5 verdict, dispatched 2026-06-02):** *"Match-level (a) and campaign-level continuation are compatible, not in tension."* The Shahnameh's pattern is throne-falls-but-realm-typically-continues across generations (Iraj → Manuchehr revenge; Siavoush → Kay Khosrow vengeance; Afrasiyab as climactic kingdom-fall conclusion). BUT that continuation is **narrative time** (generations, mission-to-mission, campaign-arc-scale), NOT **match time** (single tick-loop, deterministic, NDJSON-emit-and-exit). The headless runner operates at match time; campaign continuation is Phase 5+ scope.

The Throne's sovereignty-bearing-institutional anchor-category classification commits the project culturally to "destruction = end-of-realm" at the building-class level (per `docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.1.0 §1.5), and (a) ships that semantic at the match-resolution layer.

**Bonus loremaster guidance — engineering grace period is acceptable as polish, not cultural concession.** If engine-architect (Track 2) wants ~30 ticks of grace for animation-settling / deterministic-state-stabilization (last attacks resolving, deaths settling), ship it as engineering discipline, NOT framed as cultural homage. The match-termination signal is still "first throne falls = match end"; the ~30-tick wind-down is just clean-shutdown polish.

**Future-narrative seam (Phase 5+):** When campaign-mode work lands, the Iraj→Manuchehr and Siavoush→Kay Khosrow beats become the canonical narrative anchors for "what happens AFTER a throne falls" — these are mission-to-mission seams, not single-match seams. Forward-watch for Phase 5+ campaign-mode kickoff briefs.

**J4 honest-confidence-disclosure (loremaster):** HIGH confidence on the textual claim (Iraj/Siavoush/Afrasiyab beats are unambiguous in the source). HIGH confidence on the match-time-vs-narrative-time distinction. No lower-confidence flags on this Q.

**Implementation note for Track 2 (engine-architect):** runner subscribes to `EventBus.throne_destroyed`; on first emit, capture winner_team = other_team, optionally wait ≤30 ticks for state-settling, emit NDJSON, exit cleanly. Cultural framing pre-validated; engineering polish at engineer's discretion.

### Q2: Timeout

**01_CORE_MECHANICS.md §0** target: 15-25 minute matches. At 30Hz: 27,000-45,000 sim ticks.

**Question:** What's the runner's hard timeout?

**Lead lean:** 60,000 ticks (33 minutes @ 30Hz). Buffer above the upper target. Matches that hit timeout are flagged as `outcome=stalemate` with full state captured — this is itself a balance signal (late-game pressure gap empirical evidence).

### Q3: RNG seed strategy — RESOLVED v1.0.1 (user 2026-06-02)

**RESOLUTION: Defer GameRNG. Engine-architect (Track 2) inventories existing randomness sources + threads seeds through ad-hoc randomness for MVP.**

- **Seed-at-batch-level:** master-seed → per-match-seed via deterministic derivation (e.g., `match_seed = master_seed XOR match_index`). Batch is reproducible.
- **Match-level reproducibility:** seeded ad-hoc randomness (existing `randf` / `randi` / `randf_range` call-sites in production code, called via `seed(match_seed)` at match-start).
- **NOT in scope:** shipping `GameRNG` autoload as a co-resident deliverable. That's deferred to a later wave when the project has multiple consumers of deterministic randomness + the schema-design cost makes sense.
- **Engine-architect (Track 2) deliverable:** inventory the randomness sources in production code (`git grep -nE "randf|randi|randf_range|seed\(" game/scripts/`), document them in a comment block in the headless runner source, verify `seed(N)` produces deterministic match-internal randomness. If any randomness source is non-seedable (e.g., wall-clock-derived), flag for ad-hoc fix-up.

**Why defer GameRNG:** scope-control. Wave 3-Sim is already a 3-track joint task; adding a 4th deliverable (GameRNG autoload schema + tests + integration) puts the wave at risk of over-scoping. The MVP runner doesn't NEED `GameRNG` — it needs deterministic-given-seed match-internal randomness, which `seed()` provides today.

**Default seed behavior:** `--seed random` (each match uses a fresh seed) for statistical sampling. `--seed N` flag produces a deterministic match for replay / debugging.

### Q4: Iran AI build-order (MVP-1) — RESOLVED v1.0.1 (user 2026-06-02)

**RESOLUTION: Lead proposal stands.** Balance-engineer (Track 1) may refine the tick-schedule in their result-format spec doc if they want; the structural shape is locked.

```
Tick 0       : 5 starting workers, send to nearest coin mines
Tick 300     : 1 worker → build Khaneh #1 near throne
Tick 1200    : 1 worker → build Sarbaz-khaneh #1 near throne
Tick 2400    : Sarbaz-khaneh produces Piyade #1
Tick 3600    : 1 worker → build Khaneh #2
Tick 4800    : Sarbaz-khaneh produces Piyade #2
... etc.
```

The build-order is mechanical, hardcoded, deterministic-given-seed. The point isn't to be a GOOD AI — the point is to be a REFERENCE AI that produces stable comparisons across batch runs.

**Balance-engineer (Track 1) latitude:** if your result-format spec analysis suggests the schedule above produces unviable matches (e.g., Iran is always overwhelmed by Turan's single-probe before any Piyade trains), propose adjusted tick-schedule + cite the analysis. Lead acknowledges balance-engineer ownership of the canonical reference; this is a starting point, not a contract.

### Q5: Output format

**Lead proposal:** NDJSON (one JSON object per line), matching the existing Phase 0 `MatchLogger` convention. Per match, one object:

```json
{
  "match_id": "match_0042",
  "seed": 1234567890,
  "outcome": "iran_win",
  "winner_team": 1,
  "duration_ticks": 18432,
  "duration_seconds": 614.4,
  "first_engagement_tick": 3712,
  "iran": {
    "throne_destroyed": false,
    "throne_hp_pct_at_end": 87.5,
    "workers_alive_at_end": 4,
    "units_alive_at_end": 8,
    "buildings_alive_at_end": 6,
    "buildings_destroyed": 0,
    "coin_x100_at_end": 24500,
    "grain_x100_at_end": 13200,
    "farr_x100_at_end": 4700
  },
  "turan": {
    "throne_destroyed": true,
    "throne_hp_pct_at_end": 0.0,
    "workers_alive_at_end": 1,
    "units_alive_at_end": 0,
    "buildings_alive_at_end": 0,
    "buildings_destroyed": 1,
    "coin_x100_at_end": 8200,
    "grain_x100_at_end": 4100,
    "farr_x100_at_end": 1200
  },
  "events_summary": {
    "turan_probes_fired": 5,
    "buildings_destroyed_total": 2,
    "units_killed_total": 17
  }
}
```

balance-engineer Track 1 owns the canonical signal list — this is a starting proposal.

---

## §4 — Tracks (3 parallel)

### §4.1 Track 1 — balance-engineer: result-format spec + signal classification

**Wave-mode declaration (per §9.B4):** `must-ship` — new artifact (result-format spec doc).

**Deliverable:** `docs/AI_VS_AI_RESULT_FORMAT.md` — canonical schema for the per-match NDJSON.

**Sub-deliverables:**
1. Definitive signal list — every field that gets emitted per match. Group by category: `outcome`, `duration`, `economy`, `military`, `events`. Each signal has: name, type, value range, what it tells balance-engineer at calibration time.
2. Classification: which signals are **calibration-relevant** (drive tuning decisions) vs. **diagnostic-only** (useful when investigating an outlier but not for routine analysis).
3. Aggregation conventions: which signals are summable across matches (e.g., `units_killed_total`); which are distributional (e.g., `duration_ticks` → percentiles); which are binary (e.g., `iran.throne_destroyed`).
4. Concrete `<example_match.json>` files in the doc.

**Estimated effort:** 60-90 minutes wall-clock for the spec doc.

**Coordination:** Tracks 2 + 3 read this spec to implement against. Track 1 should ship FIRST (or at least the schema sketch ships first; iteration on classification happens in parallel).

### §4.2 Track 2 — engine-architect: headless runner implementation

**Wave-mode declaration (per §9.B4):** `must-ship` — new infrastructure (headless match runner).

**Deliverable:** `game/scripts/sim/headless_match_runner.gd` (autoload OR scene script — engine-architect picks the cleaner shape) + integration with existing autoloads (SimClock, GameState, ResourceSystem, etc.) for clean per-match reset.

**Sub-deliverables:**
1. **Headless boot path.** Godot launch command produces a running sim instance with no UI, exits cleanly when match ends or timeout fires.
2. **Iran dummy-AI implementation.** Per §3 Q4 spec — a "DummyIranController" autoload (mirroring TuranController structure) that executes the canonical build-order from match-start.
3. **Match orchestration loop.** Detects win-condition via `EventBus.throne_destroyed`; on match end, captures state from existing autoloads (Game state, Resource state, etc.) and emits the result NDJSON per Track 1's spec.
4. **Reset discipline.** Verify ALL autoload `reset()` methods are idempotent + complete (no state leaks across consecutive matches in the same Godot process). Existing reset methods at: SimClock, GameState, ResourceSystem, FarrSystem, SpatialIndex, TuranController, FogSystem. Audit pass + extend any that aren't complete.
5. **GameRNG decision** (per §3 Q3). Either ship GameRNG autoload as co-resident OR document the randomness-source inventory + how seeds propagate today.

**§9.M6 observability:** Runner must emit `[runner]` logs at every state-change (match_start, match_end, throne_destroyed, timeout). State-change-gated discipline per §9.M6.4 — no per-tick spam.

**Estimated effort:** 4-6 hours wall-clock (the largest track in this wave).

### §4.3 Track 3 — qa-engineer: batch-shell script + aggregation

**Wave-mode declaration (per §9.B4):** `must-ship` — new tooling script.

**Deliverable:** `tools/run_ai_vs_ai_batch.sh` + `tools/aggregate_match_results.py` (or `.gd` if we keep tooling all-Godot — qa-engineer's call).

**Sub-deliverables:**
1. **Batch runner script.** Takes `N` (number of matches) + `--master-seed` (deterministic-batch reproducibility) + `--output <dir>` (where NDJSON lands). Runs N consecutive Godot headless invocations. Each match writes one NDJSON line to a per-batch results file.
2. **Aggregation script.** Reads NDJSON, produces a summary:
   - Match outcomes (Iran wins / Turan wins / stalemates)
   - Duration percentiles (p25 / p50 / p75 / p95)
   - Resource state at end-of-match (medians by faction)
   - Per-signal distributions for balance-relevant signals
3. **Tests for the batch runner.** Test fixture: 3-match dry-run produces valid NDJSON + valid aggregate report.
4. **Integration test verification.** Existing test suite (1576 tests) MUST continue to pass; batch runner doesn't break headless test mode.

**Estimated effort:** 2-3 hours wall-clock.

### §4.4 Coordination

- **Track 1 (spec) ships first or in parallel with Tracks 2+3.** Tracks 2+3 can start with the v1.0 starting-proposal spec from §3 Q5 while Track 1 refines.
- **Tracks 2 + 3 are independent surfaces** — `game/scripts/sim/` vs `tools/` directories.
- **Wave-mode `parallel-worktrees`** per §9.E1. Lead pre-creates 3 worktrees at dispatch time: `gp-sys-wave-3sim` (if any gp-sys carry-over for engine-architect's work), `engine-architect-wave-3sim`, `balance-engineer-wave-3sim`, `qa-engineer-wave-3sim`. Each agent receives their worktree path in the dispatch message.
- **mirror-reviewer dispatched at brief-time** before track work begins (per §9.D11 + §9.B4 + §9.M6.3 brief-time discipline triad). Mirror catches integration-surface gaps, balance.tres staleness, observability gaps, missing track-mode declarations. Brief v1.0.0 → v1.0.1 lands the mirror's findings.

---

## §5 — First-Consumer Trace (per §9.D11)

**First consumer:** balance-engineer's AI-vs-AI tuning cycle, which reads the per-batch aggregated reports to prioritize `placeholder → calibrated` promotions in balance.tres.

**First-fire tick:** Not in-game tick. Consumer fires at human-tuning time, immediately after the wave ships — balance-engineer runs the batch (e.g., 50 matches), reads the aggregate report, identifies the top-3 `placeholder` entries by impact, ships balance.tres revisions in a follow-up balance-tuning wave.

**Gate that would prevent first fire:**
- Runner doesn't terminate (matches hit timeout indefinitely) → no usable duration data.
- NDJSON format is parse-error-prone → no aggregation possible.
- Reset discipline gap (workspace bleed between consecutive matches) → match results corrupted; data unreliable.

If any of these gates closes the integration loop, the wave's value-prop fails at first-consumer time. Track 2 (engine-architect) owns gate 1 + gate 3; Track 1 (balance-engineer) owns gate 2.

**Co-resident verifiability:** YES — Track 1's tests + Track 3's tests verify the format + reset discipline within the wave itself. balance-engineer's first real consumption happens immediately post-merge; no wait for downstream waves.

---

## §6 — §9.M6 Observability Touch List

Per §9.M6.3, the brief enumerates pre-rule files touched by this wave AND verifies §9.M6 compliance on the paths the wave exercises.

**New files (greenfield, day-1 §9.M6 compliance applies):**

| File | New events to log |
|---|---|
| `game/scripts/sim/headless_match_runner.gd` | `[runner] match_start match_id=N seed=N`, `[runner] match_end outcome=X winner=N duration_ticks=N`, `[runner] timeout match_id=N duration_ticks=60000`, `[runner] reset autoloads_reset=N` |
| `game/scripts/sim/dummy_iran_controller.gd` | `[dummy-iran] _ready`, `[dummy-iran] build_order_step step=N kind=X tick=N`, `[dummy-iran] stalled reason=X` |
| `tools/run_ai_vs_ai_batch.sh` | `echo` lines for batch progress; bash-native, no `[<system>]` tag prefix required for shell tools |
| `tools/aggregate_match_results.py` (or .gd) | Aggregation script — diagnostic only, no per-match logs needed |

**Modified pre-rule files (§9.M6.3 back-fill audit):**

| File | Modification | §9.M6 status |
|---|---|---|
| `game/scripts/autoload/sim_clock.gd` | Verify `reset()` is complete | EXISTING — verify log on reset event |
| `game/scripts/autoload/game_state.gd` | Verify `reset()` is complete | EXISTING — verify log on reset event |
| `game/scripts/autoload/resource_system.gd` | Verify `reset()` is complete | EXISTING — `[resource]` logs added in session 9 sweep; verify reset emits |
| `game/scripts/autoload/spatial_index.gd` | Verify `reset()` is complete | EXISTING — verify log on reset event |
| `game/scripts/autoload/turan_controller.gd` | Verify `reset()` is complete | EXISTING — `[turan]` logs solid post-Wave 3-BD; verify reset emits `[turan] reset` |
| `game/scripts/autoload/fog_system.gd` | Verify `reset()` is complete | EXISTING — `[fog]` logs added in session 9 sweep; verify reset emits |
| `game/scripts/autoload/farr_system.gd` | Verify `reset()` is complete | EXISTING — verify log on reset event |
| `game/data/balance.tres` | No modification expected | UNAFFECTED |
| `game/main.tscn` | May need a headless-mode-toggle | TBD by engine-architect |

**Mechanical brief-time grep (per §9.M6.3):**

```bash
# Verify every autoload's reset() emits a log line:
for autoload in sim_clock game_state resource_system spatial_index turan_controller fog_system farr_system; do
    grep -A 5 "^func reset" "game/scripts/autoload/${autoload}.gd" | grep -E "print|\\[${autoload%_*}\\]" || echo "MISSING: ${autoload}.gd reset() log"
done
```

Track 2 (engine-architect) runs this grep + ships any missing reset() logs as part of the wave's §9.M6 back-fill obligation per §9.M6.3.

---

## §7 — Test Discipline

Per §9.M:

1. **Track 1 (balance-engineer):** unit tests for any helpers (probably minimal — spec doc is mostly prose). Schema validation: a test fixture loads an example NDJSON line and verifies it matches the documented schema.

2. **Track 2 (engine-architect):** integration tests for the runner:
   - `test_headless_runner_one_match.gd` — run one match, verify NDJSON emit + clean termination.
   - `test_headless_runner_reset_discipline.gd` — run N=3 matches consecutively, verify no state leak (e.g., SimClock.tick reset to 0 each match; ResourceSystem coin starts at canonical starting value each match).
   - `test_headless_runner_win_condition.gd` — synthesize Throne destruction, verify runner detects + emits `outcome=X_win`.
   - `test_headless_runner_timeout.gd` — synthesize a sim that never terminates, verify runner times out at 60,000 ticks + emits `outcome=stalemate`.

3. **Track 3 (qa-engineer):** integration test:
   - `test_batch_runner_dry_run.gd` — run the bash script with N=3 in a test fixture, verify 3 NDJSON lines emitted + aggregator produces valid summary.

4. **Pitfall #16 / #17 vigilance.** Runner code creates + destroys per-match state. Reset discipline gaps surface as Pitfall #16 (`as Node3D` cast on freed Object across match boundaries) or workspace-bleed shape. Add per-track regression tests if either surface is hit.

5. **Pre-commit GUT suite (1576+ tests) MUST stay green.** This wave doesn't change gameplay behavior; suite is the canary.

---

## §8 — Wave-Close Criteria

The wave closes when:

1. ✅ Track 1 ships `docs/AI_VS_AI_RESULT_FORMAT.md` with schema + classification.
2. ✅ Track 2 ships headless runner + DummyIranController + reset audit.
3. ✅ Track 3 ships batch script + aggregator + 3-match dry-run validation.
4. ✅ Pre-commit GUT suite green (1576+ tests, 0 failures).
5. ✅ Lead runs a 10-match smoke batch + verifies aggregate report is reasonable (matches terminate within timeout, NDJSON parses cleanly, no obvious data corruption).
6. ✅ ARCHITECTURE.md §2 row added for `Headless AI-vs-AI Batch Runner` + §6 v0.37.0 wave-close entry.
7. ✅ BUILD_LOG.md dated entry.

**No user-driven live-test required** for wave-close — this is a headless infrastructure deliverable; correctness is validated by the test suite + the 10-match smoke run.

---

## §9 — Risks + Mitigations

**Risk 1: Reset discipline gap surfaces mid-batch.** SimClock or ResourceSystem state leaks across matches → all subsequent match data is corrupt.
- **Mitigation:** Track 2's reset audit + `test_headless_runner_reset_discipline.gd` regression. If discovered mid-implementation, dedicate a fix-up cycle before merge.

**Risk 2: Iran dummy AI can't actually win matches.** If Iran-side AI is too weak, every match ends in Turan victory or stalemate — no balance signal on Iran-side performance.
- **Mitigation:** Track 2's build-order is calibrated for a baseline "Iran can defeat Normal Turan ~60% of the time" target. balance-engineer (Track 1) provides calibration target. If first 10-match smoke shows wildly skewed outcomes (e.g., 100% one side), the dummy-AI needs revision before wave-close.

**Risk 3: Match duration exceeds 60,000 tick timeout.** Late-game economic pressure gap (open design question) manifests as stalemate-by-timeout.
- **Mitigation:** This is itself the empirical evidence for `QUESTIONS_FOR_DESIGN.md` "late-game pressure" entry. Flag in aggregate report; don't try to fix this wave. Surface as Phase 4+ design question.

**Risk 4: GameRNG not shipped.** Per §3 Q3 — randomness in production code may be ad-hoc, hard to seed.
- **Mitigation:** engine-architect decides at implementation time whether to ship GameRNG co-resident OR document the inventory + accept per-call randomness for MVP. Either path is acceptable.

**Risk 5: Phantom-inbox dispatch.** Session 9 retro flagged: world-builder + ai-engineer instances don't exist in addressable form. engine-architect may have same issue.
- **Mitigation:** Lead verifies instance addressability via short-form name confirmation BEFORE composing the long dispatch message. If `engine-arch-p3s4` (or whatever the correct short-form is) doesn't exist, lead either spawns fresh OR pulls engine-architect work into gp-sys's surface for this wave.

---

## §10 — Brief Metadata + Mirror-Reviewer Review Targets

**Brief version:** v1.0.0 (initial draft pending mirror-reviewer brief-time review per §9.D11 + §9.B4 + §9.M6.3 brief-time discipline triad).

**Mirror-reviewer findings target v1.0.1.** Expected findings categories:
- **C1 (schema / canonical-pattern grep):** Track 2's autoload reset() patterns against canonical project autoload reset() patterns at SimClock / GameState etc.
- **C2 (consumer trace):** §5 First-Consumer Trace verification.
- **C3 (observability):** §6 §9.M6 touch list verification + mechanical grep.
- **C4 (track-mode):** §9.B4 named-track-mode verification per Track.
- **C5 (open questions resolved):** §3 Q1-Q5 may need explicit resolution before track dispatch.

**Lead-side §9.L11 grep verification:** Brief proposes NO numeric values that already exist in balance.tres (this is infrastructure; no balance.tres changes). PASS.

**Lead-side §9.L12 grep verification:** Brief cites canonical patterns where they exist (existing autoload reset() pattern; existing `[<system>]` log convention; existing test fixture pattern). PASS.

---

## §11 — What to Broadcast When Ready

Per §9.E1 + the established broadcast pattern:

- **Lead-side dispatch:** at session-10 startup, lead dispatches Tracks 1+2+3 in parallel after brief v1.0.1 lands.
- **Track-side broadcast:** each Track broadcasts `[ready] <track_name> <commit_sha>` when their deliverable lands.
- **Lead-side wave-close:** lead runs 10-match smoke + ARCHITECTURE.md + BUILD_LOG updates + opens PR.
- **Live-test gate:** N/A — this is a headless infrastructure wave. Pre-commit suite + smoke batch are the gates.

**Standing dispatch template (lead sends to each track on session-10 startup):**

```
[wave-3-sim Track <N>] dispatch — see 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md
Your worktree: ../shahnameh-rts-<dispatch-id>
Your deliverable: §4.<N> in the brief
Wave-mode: parallel-worktrees per §9.E1
Track-mode: must-ship per §9.B4
Observability: §9.M6.3 + §9.M6.4 per the wave's §6 touch list
First-Consumer: balance-engineer tuning cycle (§5)
Standing by for [ready] broadcast.
```

---

## §12 — End-of-Brief Notes

**This is the first brief drafted under the new session-9 retro rules** (§9.D11 First-Consumer Trace, §9.B4 named track-modes, §9.M6.3 observability-as-wave-time-gate, §9.M6.4 state-change-gated logging, §9.L11.1 two-actor framing). Mirror-reviewer's brief-time review of this brief is itself a meta-validation of the new rules — does the brief's shape produce mirror findings of the kind the new rules are designed to surface?

**Drafted autonomously post-session-9-close.** User went to bed ~21:00 2026-05-28 with the directive *"you have full authority to push on up until you need a live test."* This wave's deliverables (headless runner + result format + batch script) don't need user-driven live-test; the smoke batch + pre-commit suite are the gates. Brief is ready for mirror-review at session-10 startup. Implementation work begins post-mirror-findings-folded-in.

**If user reads this brief on session-10 startup:** the open design questions in §3 are the explicit user-input gates. Q1 (win-condition) + Q3 (RNG seed strategy) + Q4 (Iran build-order) benefit from user judgment before track dispatch. Q2 (timeout) + Q5 (NDJSON output format) are lead-recommendations; user-override welcomed but not required.

---

## §13 — Revision History

**v1.0.0 (2026-05-28):** initial draft post-session-9-close. Lead-authored autonomously per user "full authority" directive. Open design questions Q1-Q5 surfaced for resolution at brief-review time.

**v1.0.1 (2026-06-02):** open design questions resolved.
- **Q1 (win-condition):** RESOLVED (a) immediate termination + optional ≤30-tick engineering grace period for state-settling. Loremaster cultural verdict (2026-06-02): cultural framing maps cleanly to (a) at match time; revenge-arc / succession continuation are campaign-mode (Phase 5+) scope. Future-narrative anchors: Iraj→Manuchehr, Siavoush→Kay Khosrow.
- **Q2 (timeout):** RESOLVED — 60,000 ticks (33 min @ 30Hz). Lead-default; unchanged.
- **Q3 (RNG seed):** RESOLVED — defer GameRNG. Engine-architect inventories existing randomness sources + threads seeds through ad-hoc `seed(N)`. Master-seed → per-match-seed deterministic derivation for batch reproducibility.
- **Q4 (Iran build-order):** RESOLVED — lead proposal stands. Balance-engineer latitude to refine in result-format spec if analysis warrants.
- **Q5 (output format):** RESOLVED — NDJSON proposal stands.

**Pending: v1.0.2 mirror-reviewer brief-time review** per §9.D11 + §9.B4 + §9.M6.3 + §9.M6.4 + §9.L11.1 (the new session-9 retro brief-time discipline triad). Mirror's findings will land v1.0.2. Track dispatch begins post-v1.0.2.

---

**End brief v1.0.1.**
