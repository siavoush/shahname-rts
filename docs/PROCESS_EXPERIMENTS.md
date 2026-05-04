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

### Experiment 02 — Wave-close code review by godot-code-reviewer + architecture-reviewer (2026-05-03)

**Sessions:** Phase 2 session 1 (first formal trial); PR #4 (Phase 1 session 2) was an informal trial run after the wave had already shipped — its findings inform but don't count as the experiment's data point.

**Hypothesis:** Spawning `godot-code-reviewer` and `architecture-reviewer` in parallel at the end of each wave, BEFORE PR creation, catches at least one issue per session that the lead's live-test would otherwise miss OR significantly improves the structural quality of merged code (Manifesto principle adherence, contract fit, layer separation). The intervention is worth its token cost if either condition holds.

**Intervention:** Per `docs/STUDIO_PROCESS.md` §9 wave-close-review rule. After all wave commits land, lead spawns both reviewers in parallel (one Agent dispatch each, `run_in_background=true`). Reviewers produce structured output per their agent definitions (verdict, blocking issues, non-blocking suggestions, nits, what's clean). Blocking issues route back to the original agent for fix; non-blocking suggestions surface in PR description.

**Held constant** (from Experiment 01's intervention which is now baseline):
- Live-game-broken-surface section in every kickoff brief, including the Known Godot Pitfalls list (Experiment 01 refinement).
- Same kickoff-doc structure, wave breakdown, agent set, TDD discipline, pre-commit gate.

**Trial run data (PR #4, Phase 1 session 2 — post-merge informal trial):**

Both reviewers ran against PR #4 after the lead had already live-tested and the cb95d09 fix had landed. Findings:

| Reviewer | Verdict | Blocking | Non-blocking suggestions | Nits | New pitfalls candidates |
|---|---|---|---|---|---|
| godot-code-reviewer | APPROVE | 0 | 4 (S1 staleness window, S2 N+1 broadcast, S3 tree-order, S4 PASS-vs-IGNORE coverage) | 4 | 2 (N+1 broadcast pattern, MOUSE_FILTER_PASS coverage gap) |
| architecture-reviewer | APPROVE | 0 | 6 LATER follow-ups | — | 0 (no Manifesto/contract violations) |

**Trial-run signal:** the reviewers caught **0 bugs the lead's live-test had missed** in this small N=1 post-fix sample. They DID surface high-leverage refactor candidates (godot's S2 `select_many(units)` primitive closes 3 issues at once) and validated the cb95d09 fix's correctness across the codebase (godot-reviewer affirmatively checked the re-entrant pattern across all `selection_changed` subscribers). The architecture-reviewer's Manifesto-principle-grading lens is structural value the lead's live-test cannot provide.

**Trial run is suggestive but inconclusive.** The reviewers ran AFTER the bug was found and fixed. We don't know whether they would have caught the cb95d09 bug at write-time (i.e., reviewing the original wave-2A commit before cb95d09 existed). The Phase 2 session 1 formal trial is the first real test.

**Baseline (Experiment 01's session-2 result):**

| Metric | Session 2 value (with Experiment 01 intervention only) |
|---|---|
| Live-game bugs found at boot by lead | 1 (re-entrant signal recursion, cb95d09) |
| Tests-pass-but-broken incidents | 1 |
| Wave-3 (qa) bug catch rate | 0/1 |
| Manifesto/contract violations caught at merge | not measured (no reviewer existed) |
| Test count delta | +162 (380→542) |
| Time kickoff → merge | ~3h |
| LATER items surfaced | 6+ |

**Metrics to capture at Phase 2 session 1 close:**

| Metric | How measured | Baseline (session 2) | Actual | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test count | 1 | _TBD_ | _TBD_ |
| Bugs caught at wave-close review (BEFORE lead live-test) | Reviewers' blocking + actionable non-blocking findings | n/a (reviewers didn't exist) | _TBD_ | _TBD_ |
| Tests-pass-but-broken incidents | Count of post-test fix passes | 1 | _TBD_ | _TBD_ |
| Wave-3 (qa) bug catch rate | qa caught / total live-game bugs | 0/1 | _TBD_ | _TBD_ |
| Manifesto/contract violations caught | architecture-reviewer findings + lead-validated routes | n/a | _TBD_ | _TBD_ |
| Refactor candidates surfaced | reviewers' "next-session priority" list | 0 | _TBD_ (wave-3 PR #4 trial: 2) | _TBD_ |
| Reviewer token cost (sum of two agents per wave × N waves) | Σ task notification totals for review-only dispatches | n/a | _TBD_ | _TBD_ |
| Lead's review-processing time | Wall clock to read both reviews + route fixes | n/a | _TBD_ | _TBD_ |

**Verdict criteria:**

- **Kept** if: AT LEAST ONE of the following holds:
  - Reviewers caught ≥1 bug at write-time that the lead's live-test would have missed (causal lift, not correlation), OR
  - Reviewers found ≥2 actionable refactor candidates per session that subsequently paid off in cleaner Phase 3+ code, OR
  - Reviewers surfaced ≥1 Manifesto/contract violation per session that would have caused future drift.

  AND the reviewer token cost is ≤ 25% of total session token spend.

- **Modified** if: reviewers add value but the cost is high. Find a cheaper variant — e.g., one reviewer per wave instead of two, or only on highest-risk waves, or only at session-close instead of wave-close.

- **Dropped** if: reviewers consistently produce zero actionable findings AND token cost exceeds 25% of session spend, OR they produce noise that wastes lead time without preventing drift.

**Verdict:** **KEPT WITH REFINEMENT.**

Filled at Phase 2 session 1 wave-close (2026-05-03), post-reviewer-dispatch, pre-merge.

**Metrics captured:**

| Metric | How measured | Baseline (sess. 2) | Actual (Phase 2 sess. 1) | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test | 1 | 0 (qa caught 4 first) | −100% |
| Bugs caught at wave-close review | Reviewer findings flagged blocking/actionable | n/a | 0 blocking + 5 actionable docs/contract findings | new metric |
| Bugs caught by qa wave 3 (BEFORE reviewers) | qa report bug count | 0 (caught nothing lead missed) | 4 (BUG-01..04 — 3 production, 1 derivative) | +400% |
| Manifesto/contract findings | architecture-reviewer findings | 0 | 6 (F-1..F-6 in architecture-reviewer's review) | new metric |
| Refactor candidates surfaced | reviewers' "next-session priority" list | 2 | 5 (UnitRegistry triple-LATER, CombatSystem coordinator, suffix Constants, encapsulation helper, MatchHarness migration) | +150% |
| Test count delta | Σ tests added | +37 | +176 (542→718) | +376% |
| Time kickoff → merge | Wall clock | ~3h | ~5h+ (multiple bug-fix cycles + 2 deviations) | +67% |
| Reviewer token cost | Σ task notification totals (review-only dispatches) | n/a (informal trial) | TBD — recover from logs | new metric |
| Lead's review-processing time | Wall clock to read both reviews + route fixes | n/a | ~30 min | new metric |

**Verdict justification:**

The wave-close review **did** add structural value the lead's live-test wouldn't surface — specifically:
1. **arch-reviewer's F-1 + F-2** (missing §6 entries for BUG-01+03 and BUG-04 fixes) preserve archaeology that future sessions need. The lead noticed the v0.17.3 hole during commit history audits but the architecture-reviewer's structured grade caught BOTH F-1 and F-2 before merge.
2. **godot-code-reviewer's BUG-04 verification** (three-trace audit: same-target / new-target / freed-target) confirmed the fix didn't introduce a new bug — that's a level of static-analysis rigor the lead's live-test cannot match.
3. **5 candidate Pitfalls evaluated with calibrated KEEP/DEFER/REJECT decisions** — godot-code-reviewer correctly distinguished engine pitfalls (#5 sibling tree-order, #8 double-deferred queue_free) from process patterns (#7 commit-race) and rejected unsupported claims (#9 lambda capture). This is exactly the lens the wave-close review was designed to provide.
4. **arch-reviewer's contract-fit findings** caught the §2 phase-order drift (combat in movement phase) explicitly — a real but acknowledged-as-LATER architectural deviation.

The intervention's value comes from **structural drift detection**, not from "catching a bug the lead would have missed at boot." Phase 2 session 1's bugs (BUG-01..04) were caught by qa wave 3's integration tests, not by either reviewer. But the reviewers caught the v0.17.3/v0.17.5 §6 documentation holes that would have rotted the project's archaeology over multiple phases.

**Refinement applied to the intervention going forward:**

- **Reviewer briefs must include the explicit §6 entry checklist.** The reviewer-brief-side checklist works; the agent-brief-side reminder ("write a §6 entry per non-trivial deliverable") is observably insufficient when agents fall into the verification-loop pattern. The reviewer should be the second line of defense for archaeology.
- **`SendMessage` in reviewer tool list confirmed working.** Both reviewers proactively returned their structured output via SendMessage; no idle-without-content failures repeated from the informal trial. Mitigation from Experiment 02's setup is validated.

**Status:** **Kept after one formal session.** Per the original notes, graduates to permanent rule in `STUDIO_PROCESS.md` only after a SECOND confirming session (Phase 2 session 2). The session-2 trial will measure: do the reviewers continue to surface ≥1 actionable archaeological/contract finding per session?

**Notes:**
- Like Experiment 01, N=1 single session is directional only. Graduates to permanent rule after second confirming session.
- The trial run revealed a **process bug to fix before the formal trial:** the original `arch-reviewer-pr4` instance went idle for ~10 minutes without producing review content; required a direct nudge from the lead via Claude Code's agent-message UI. Hypothesis: read-only reviewer agents (no `SendMessage` in tools) may have ambiguous return-output mechanics. **Mitigation for Phase 2:** add `SendMessage` to both reviewer agents' tool list so they can proactively report.
- The trial run also revealed the reviewers' value compounds when given the Known Godot Pitfalls list as their checklist. Phase 2's wave-close briefs should include the latest pitfalls list as part of the briefing, not just by reference.
- Cost-of-measurement: ~20 min lead time per wave (write the briefs, read the reviews, route fixes). Tracked in the metrics table.

## Mid-flight deviations log

Per the discipline rule, deviations from the documented studio process (kickoff doc, STUDIO_PROCESS §9, ongoing experiments) are allowed when running into a known wall, but must be explicit and logged.

### Deviation 01 — lead committed wave-1A + wave-1B on behalf of stuck agents (2026-05-03, Phase 2 session 1)

**Trigger:** `gameplay-combat-core` (subagent_type=gameplay-systems, name=gameplay-combat-core) entered a verification loop after completing implementation work in the shared working tree. Each subsequent task on their list looked at the file already in the tree and reported "task already shipped by another agent, standing down" — when in fact the work was theirs from earlier in the same session, just uncommitted. Three rounds of explicit lead messaging ("this is YOUR work, please commit") failed to break the loop. `ai-eng-attacking-state` had similar behavior (work in tree, never reached the commit step).

**Process expectation violated:** kickoff doc §5 "End of session: Lead live-tests before PR" — but agents are supposed to commit their own work first. STUDIO_PROCESS §9 (2026-05-01) "verify git tree at session close" requires a tree to verify — agents weren't producing one.

**Deviation:** lead manually staged and committed wave-1A's gameplay-combat-core work and wave-1B's ai-eng-attacking-state work as a bundled commit (`81cf42a`), with body crediting both agents for authorship and tagging the commit as a mid-flight deviation. balance-engineer's wave-1C work (`a2b444f`) was committed by the agent themselves cleanly — no deviation there.

**Cost avoided:** continued waste of conversation rounds messaging stuck agents. Each "task already shipped, standing down" message + lead nudge cycle was costing ~5 turns. Without the deviation, work in the tree would have been blocked indefinitely or required a fresh agent spawn (which costs more tokens than just committing).

**Cost paid:**
- **Cleaner attribution loss:** the `81cf42a` commit credits two agents in one commit body, not the standard one-agent-per-commit shape. Future archaeologists reading `git log` see "lead committed two agents' work" as an outlier vs. the standard pattern. Mitigated by explicit body documentation.
- **Experiment 01 (live-game-broken-surface) data quality dent:** the deviation may correlate with the agent verification-loop bug in some way — was the loop a side effect of agents trying to apply the live-game-broken-surface section to too many tasks and getting confused about state? Need to verify in the session-close retro. Don't conflate the symptoms.
- **Experiment 02 (wave-close review) trial setup:** the wave-close review is supposed to happen AFTER all wave commits land, BEFORE PR. The lead-deviation commits land on the branch normally; wave-close review still runs against the branch. So this doesn't break Experiment 02's setup, but it does muddy the "agents are responsible for their own commits" assumption built into the agent dispatch process.

**Resolution / mitigation for future:**
- **Fold into the next agent-dispatch brief**: explicitly tell each agent that they are responsible for committing their own work BEFORE standing down. Add "if you find work in the tree that you don't recognize, run `git diff` to verify whether it's yours from earlier in the session — your task list is the authority on what you've done."
- **Investigate root cause**: the verification loop pattern is likely a fundamental Claude Code agent confusion about session continuity. May be worth a separate Experiment 03 on commit-discipline patterns once the current Experiments 01 and 02 close.
- **Recurring problem:** session 2 had a similar shared-tree-coordination problem (different mechanism: agents stepped on each other's docs). This is the second session this class of issue has surfaced. Tagging as a recurring pattern worth its own study.

**Verdict on the deviation itself:** appropriate for the situation but indicative of a process gap that should be closed in Phase 2 session 2's kickoff brief.

### Deviation 02 — parallel-agent commit-staging race produced a misattributed commit (2026-05-03, Phase 2 session 1 wave 2)

**Trigger:** three wave-2 agents (`gameplay-piyade-and-drain`, `ai-eng-attack-input`, `ui-dev-health-and-overlay`) running in parallel each modified shared files (`main.tscn`, `BUILD_LOG.md`, `docs/ARCHITECTURE.md`) AND wrote their own files. Each agent's editor / linter kept re-asserting their changes into the working tree. ui-dev-health-and-overlay was first to attempt commit:
1. Staged 9 of their own files. Verified `git diff --staged --stat` showed only theirs.
2. Between the verification and the actual commit, parallel agents' background writes restored more files into the index.
3. The pre-commit hook committed what was in the index at commit-time — which included gameplay-piyade-and-drain's wave-2A files AND ai-eng-attack-input's wave-2B files alongside / instead of ui-dev's wave-2C.
4. Result: commit `aa429ef` has the title `feat(ui): floating health bars + F4 attack-range overlay — Phase 2 session 1 wave 2C` but its content is the wave 2A + 2B work (Piyade, Turan_Piyade, Farr drain, attack-move handler, UnitState_AttackMove, click_handler enemy-right-click branch).
5. ui-dev-health-and-overlay caught the discrepancy post-commit, made a corrective commit `c203dfe` with their actual wave-2C deliverables and a clear note in the body explaining what happened. They tried `git reset --soft HEAD~1` to amend the misattributed commit but the action was sandbox-denied as destructive.

**Process expectation violated:**
- STUDIO_PROCESS §9 (2026-05-01) "verify git tree at session close, not just lint + tests" — the lead-side equivalent of `git diff --staged --stat` JUST BEFORE commit was not enforceable across parallel-agent boundaries. The tree changes between verification and commit.
- STUDIO_PROCESS §9 (2026-05-01) "Pre-commit gate must filter to tracked files when N agents run in parallel" — was already a known LATER item; this incident is the second occurrence (first was Phase 0 session 4 wave 1). Still not implemented.
- Implicit but unstated rule: "atomic commits per agent." The race violates this even though no agent intended to.

**Deviation:** lead is logging the issue and standing down agents whose work landed in the misattributed commit. NOT rewriting history (would require destructive `git reset` / `git rebase` and is contained to local branch — but per discipline rule, deviations are painful and serious; we don't compound by adding history rewrite). The commit log will permanently show the misattribution; the corrective commit `c203dfe` documents it in its body. Future readers of `git log` will see both commits and understand the race.

**Cost avoided:**
- Avoided destructive `git reset --hard` / `git rebase -i` operations that could have lost wave-2C work entirely under tooling error.
- Avoided multi-round agent coordination ("you commit first, no you commit first") which was already the failure mode.

**Cost paid:**
- Permanent ugly archaeology in `git log` — `aa429ef`'s commit message lies about its content. Mitigated by `c203dfe`'s body explanation, but a future agent reading just `git log --oneline` will be confused.
- The wave 2A and wave 2B agents have ambiguous "did I commit or not" state — needs explicit lead messaging to release them. Adds ~5 turns of cleanup messaging.
- `BUILD_LOG.md` and `docs/ARCHITECTURE.md` entries from wave 2A and 2B are NOT in `aa429ef` — they were in the working tree at commit time but didn't make it into the index. They're shipped via `c203dfe` (which had the wave-2C agent's docs additions only). The wave 2A and 2B retro entries are LOST FROM HISTORY unless reconstructed.

**Resolution / mitigation for future:**
- **Implement the LATER item from STUDIO_PROCESS §9 (2026-05-01):** pre-commit gate must filter to tracked files via `git diff --cached --name-only`. Already documented; long overdue.
- **Add to wave brief template:** "before staging, freeze the working tree by signaling other agents to pause. After staging, run `git diff --staged --stat` AND `git diff --stat` (the unstaged-but-modified set should not include any of YOUR files). Commit immediately."
- **Better: serialize wave-end commits.** Instead of N agents committing in parallel, lead nominates an order at wave-close. Each agent commits, signals done, next agent commits. Costs a few turns of coordination but eliminates the race entirely.
- **Best (long-term):** each agent commits IMMEDIATELY after completing each TDD red→green cycle, not at end-of-wave. By the time wave-close happens, only docs need committing. The agent gameplay-combat-core's own retrospective from Deviation 01 made this exact point.

**Pattern recognition:** this is the THIRD session this class of cross-agent shared-tree issue has surfaced (session 2 had docs-stomp; this session has Deviation 01 verification-loop AND Deviation 02 commit-race). The pattern is now load-bearing enough to warrant its own experiment in a future session — Experiment 03: incremental commits + serialized wave-close. Promote when current Experiments 01/02 close.

**Verdict on the deviation itself:** appropriate. Rewriting history would have introduced more risk than the misattribution itself. The commit log will live with the lie; the in-line body of `c203dfe` and this Deviation 02 entry are the explanatory record.

## Resolved experiments (archive)

_None yet — Experiment 01 stays Active until session 3 confirms or rejects the refinement, and Experiment 02 stays Active until Phase 2 session 1 produces its first verdict._
