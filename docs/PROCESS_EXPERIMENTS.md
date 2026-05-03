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

**Metrics to capture at session 2 close:**

| Metric | How measured | Baseline | Actual | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead booth-test count | 3 | _TBD_ | _TBD_ |
| Tests-pass-but-broken incidents | Count of post-test fix passes | 1 | _TBD_ | _TBD_ |
| Wave-3 (qa) bug catch rate | qa caught / total live-game bugs | 0/3 = 0% | _TBD_ | _TBD_ |
| Test count delta | New tests added | +78 | _TBD_ | _TBD_ |
| Time kickoff → merge | Wall clock | ~24h | _TBD_ | _TBD_ |
| Total token spend | Σ task notification totals | _TBD_ | _TBD_ | _TBD_ |
| LATER items surfaced | Count | 2 | _TBD_ | _TBD_ |
| Kickoff-doc writing time | Lead's wall clock writing 02c | n/a (02b was ~2h) | _TBD_ | _TBD_ |

**Verdict criteria:**

- **Kept** if: live-game bugs at boot ≤ 1, AND token spend ≤ 1.2× baseline, AND no other regression in metrics.
- **Modified** if: live-game bugs at boot reduced but token spend > 1.2× baseline. Find a cheaper variant (e.g., shorter live-game-broken-surface section, or only on highest-risk deliverables).
- **Dropped** if: live-game bugs at boot unchanged or worse, OR token spend > 1.5× baseline with no quality improvement.

**Verdict:** _TBD — fill at session 2 merge._

**Notes:**
- N=1 single session. If verdict is "Modified," the modification runs as Experiment 02 with its own baseline (this session's data).
- If verdict is "Kept," the intervention becomes a permanent part of the kickoff-doc template (folded into `STUDIO_PROCESS.md`) only after a SECOND confirming session — N=2 directional signal.
- Cost-of-measurement is itself a cost. Tracking these metrics adds ~10 min lead time per session. If we end up with >5 active experiments concurrently, this log itself becomes the bottleneck — re-evaluate.

## Resolved experiments (archive)

_None yet._
