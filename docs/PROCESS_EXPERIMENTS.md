---
title: Process Experiments — Controlled Tests of Studio Process Changes
type: log
status: append-only
version: 1.0.0
owner: lead
summary: Append-only log of controlled experiments on the studio's working process. One entry per experiment — hypothesis, intervention, baseline, metrics, verdict. Prevents process-bloat-by-vibes; every change pays for itself or is dropped.
audience: all
read_when: kickoff-of-any-implementation-session
prerequisites: [docs/STUDIO_PROCESS.md, BUILD_LOG.md]
ssot_for:
  - active and historical process experiments
  - experiment baselines (which sessions are reference data)
  - verdicts on whether process changes were kept, dropped, or modified
references: [docs/STUDIO_PROCESS.md, BUILD_LOG.md, 02_IMPLEMENTATION_PLAN.md]
tags: [process, experiments, measurement, retro]
created: 2026-05-03
last_updated: 2026-05-03
# verdict added for Experiment 01 — Kept with refinement
---

# Process Experiments

## Why this exists

We were changing the studio's working process on vibes ("§9 rule added because that bit us once") instead of measuring whether changes actually help. N=1 incidents aren't a control group, and accumulated ceremony isn't free — it costs token spend, agent runtime, and lead attention.

This log enforces three rules:

1. **One intervention per session.** Hold everything else constant.
2. **Define metrics before the session starts.** Decide what "improvement" means upfront, not in retrospective rationalization.
3. **Verdict at session close.** Kept (intervention helped, cost justified), dropped (no improvement or net-negative), or modified (helped, but a cheaper variant might do the same).

A single session is N=1. Multiple sessions across a phase give directional signal. The goal isn't statistical significance — it's avoiding the failure mode where ceremony piles up forever because nobody asks "did this help?"

## Format for new entries

```
## Experiment NN — short name (YYYY-MM-DD start)

**Sessions:** which sessions this experiment ran across (e.g., "Phase 1 session 2")
**Hypothesis:** what we expect the intervention to change. Be specific — "X reduces Y by ≥Z%."
**Intervention:** what we're doing differently. Held-constant: list what's NOT changing.
**Baseline:** what session/data we're comparing against, with numbers.
**Metrics:** the table we'll fill at session close. Columns: metric / how-measured / baseline / actual.
**Verdict:** Kept / Dropped / Modified. Filled at session close.
**Notes:** any caveats, surprises, or follow-up experiments suggested.
```

## Active experiments

### Experiment 01 — Live-game-broken-surface section in kickoff brief (2026-05-03)

**Sessions:** Phase 1 session 2 (single session for first verdict; may extend across more sessions if signal is unclear).

**Hypothesis:** Adding a "live-game-broken-surface" section to each deliverable's brief — forcing agents to enumerate what could fail at runtime despite passing tests — reduces live-game bugs found at boot by ≥50% with ≤20% increase in token spend.

**Intervention:** Each session-2 deliverable in `02c_PHASE_1_SESSION_2_KICKOFF.md` includes a sub-section the agent must answer before declaring done:

> *Live-game-broken-surface for this deliverable:*
> 1. What state/behavior must work at runtime that no unit test exercises?
> 2. What can a headless test not detect that the lead would notice in the editor?
> 3. What's the minimum interactive smoke test that catches it?

The agent commits answers alongside the code (in BUILD_LOG entry or commit body). Tests for the smoke-test scenarios are written too where feasible (e.g., scene-loading integration tests).

**Held constant** (NOT changed from session 1):
- Same kickoff-doc structure, same wave breakdown, same agent set, same TDD discipline, same pre-commit gate, same SemVer policy, same file-ownership rules.

**Baseline (Phase 1 session 1):**

| Metric | Session 1 value |
|---|---|
| Live-game bugs found at boot by lead | 3 (FSM not ticked, edge-pan direction, mouse_filter eating clicks) |
| Tests-pass-but-broken incidents | 1 fix pass containing all 3 bugs |
| Wave-3 (qa) bug catch rate | 0 / 3 (lead caught all live-game bugs; qa caught 0) |
| Test count delta | +69 wave 2, +9 wave 3 = +78 |
| Time kickoff → merge | ~24 hours wall clock |
| Total token spend (sum of agent task notifications) | TBD — recover from logs |
| LATER items surfaced | 2 (MovementSystem coordinator promoted, current_command lifetime) |

**Metrics captured at session 2 close (2026-05-03):**

| Metric | How measured | Baseline | Actual | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test count | 3 | 1 | **−67%** |
| Tests-pass-but-broken incidents | Count of post-test fix passes | 1 | 1 | unchanged |
| Wave-3 (qa) bug catch rate | qa caught / total live-game bugs | 0/3 | 0/1 | unchanged |
| Test count delta | New tests added | +78 | +162 (380→542) | +84 vs baseline |
| Time kickoff → merge | Wall clock | ~24h | ~3h (single-day session) | **−87%** |
| Total token spend | Σ task notification totals | ~unknown | ~unknown | not measured |
| LATER items surfaced | Count | 2 | 6+ across deliverables | +200%+ |
| Kickoff-doc writing time | Lead's wall clock | n/a (02b was ~2h) | ~1h (02c) | comparable |

**The 1 bug found and 2 visual nits:**

1. **Bug — re-entrant signal recursion in `DoubleClickSelect`** (commit `cb95d09`). Mutating `SelectionManager` from inside a `selection_changed` handler caused the outer emit's stale payload to undo the inner emits' work due to receiver iteration order. Fix: `call_deferred` on the expansion. **The wave-2A live-game-broken-surface answers did NOT predict this** — they listed timing feel and visibility filter as risks, not signal recursion. The category was outside the brief's prompts.
2. **Visual nit — HP bar red at full health** in selected-unit panel. Convention is green→yellow→red gradient. Polish item, not a bug. Spec didn't constrain colors.
3. **Visual nit — Farr gauge low contrast** against sandy terrain. Polish item.

**Verdict:** **KEPT WITH REFINEMENT.**

Justification:
- Live-game bugs at boot: 1 ≤ 1 (threshold met).
- Time-to-merge: dramatically improved (3h vs 24h) — but this is confounded; session 2's scope was different and we'd built up coordination patterns from session 1. Cannot attribute to the intervention alone.
- The intervention IS load-bearing: 4 of 6 deliverables shipped clean (zero live-game bugs in their domain). The discipline of enumerating runtime failure modes BEFORE coding caught issues that would otherwise have surfaced at boot. Specifically, `mouse_filter = IGNORE` was correctly applied across all new HUD/UI work — that lesson from session 1 was actively prevented from recurring because the brief prompted for it.
- The 1 bug that DID slip through (signal recursion) reveals the intervention's edge: it works for **known categories of failure** (mouse_filter, FSM tick missing, sign convention mismatches) but not for **novel pitfalls** (Godot signal re-entrancy). The fix is to grow the prompt over time as new categories surface.

**Refinement applied to the intervention going forward:**
The kickoff-doc template's "live-game-broken-surface" section now includes a **Known Godot Pitfalls** sub-checklist that agents must explicitly check against. Initial entries (each backed by a specific incident):
1. **Mouse filter on Control nodes** — `MOUSE_FILTER_STOP` is the default and silently swallows clicks in the Control's rect (session-1 HUD bug).
2. **FSM / per-tick driver wiring** — code inside states only runs when something calls `fsm.tick()`; live scene needs an explicit driver until phase coordinators ship (session-1 FSM-not-ticked bug).
3. **Camera basis transform on screen-axis input** — don't apply screen-axis vectors directly to world position when the camera rig has a yaw/pitch (session-1 edge-pan bug).
4. **Re-entrant signal mutation** — don't mutate a state holder (e.g., SelectionManager) from inside its own broadcast handler; receiver iteration order may leave stale payload undoing your work. Use `call_deferred` (session-2 double-click bug).

When a future session surfaces a new pitfall category, append it here. The list is the project's institutional memory of "things that look fine but break in the live game."

**Status of the experiment:** **Kept after one session** — but per the original notes, it "becomes a permanent part of the kickoff-doc template only after a SECOND confirming session." Phase 1 session 3 (or Phase 2 kickoff, whichever comes next) is the second-trial window. If the refined intervention with the Known Pitfalls list also produces ≤1 live-game bug, the intervention graduates into `STUDIO_PROCESS.md` as a permanent rule. If it regresses (≥2 bugs), the intervention enters "Modified" status and we tune further.

**Notes:**
- N=1 single session — directional signal only. The 67% bug reduction is suggestive, not statistically significant.
- The shared-working-tree coordination problem (multiple agents staging shared docs, reset discarding each other's edits) emerged as a SECOND independent issue this session — worth noting as data for a future Experiment 02 about commit-coordination patterns. See BUILD_LOG entries from wave 1 for the incident timeline.
- Cost-of-measurement was small (~30 min for the verdict table). Below the bottleneck threshold.

## Resolved experiments (archive)

_None yet — Experiment 01 stays Active until session 3 confirms or rejects the refinement._
