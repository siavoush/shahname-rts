---
title: Studio Process — Sync Log (chronological run record)
type: log
status: append-only
version: 1.0.0
owner: team
summary: Chronological record of every multi-agent sync run + session-close log entries. Split out of STUDIO_PROCESS.md at the 2026-05-18 audit to keep the active operating contract focused on currently-binding rules.
audience: all
read_when: retro-time, when-investigating-session-shape, when-onboarding-to-prior-syncs
prerequisites: [STUDIO_PROCESS.md]
ssot_for:
  - per-sync entries (date, pattern, participants, outcome, retro)
  - per-session-close entries (wave shape, retro inputs, strongest signals, §9 cluster shipped, agent-def updates, carry-forwards)
references: [STUDIO_PROCESS.md, STUDIO_PROCESS_HISTORY.md, ARCHITECTURE.md]
tags: [process, sync-log, history, retros]
created: 2026-05-18
last_updated: 2026-05-21
---

# Studio Process — Sync Log

> Append-only chronological record of every multi-agent sync run + session-close log. Extracted from STUDIO_PROCESS.md §10 at the 2026-05-18 audit to keep the active operating contract focused on currently-binding rules. **At retro time, append a new entry here.** **At session-start, you do NOT need to read this file** — read the active STUDIO_PROCESS.md instead.

## Format

Each entry: one section. Sync entries follow the original §10 sync template (Pattern / Participants / Question / Outcome / Cost / Retro). Session-close entries follow the session-N template (Date / Sync pattern N/A / Persistent agents / PR / Wave shape / Retro inputs / Strongest signal / Wave quality signal / §9 cluster shipped / Pitfall promotions / Agent-def updates / Carry-forwards / Closing observation).

Append-only. Older entries are NOT edited. Newer entries supersede older claims structurally (the active doc carries currently-binding state).

---

## 10. Sync Log

Append-only log of every sync run. One entry per sync.

### Sync 1 — Simulation Architecture
**Date:** 2026-04-30
**Pattern:** Author + Reviewers
**Participants:** engine-architect (author), ai-engineer, qa-engineer
**Question:** What's the contract for `SimClock`, `SpatialIndex`, and `MovementComponent.request_repath()` that all three can build against?
**Outcome:** Ratified. `docs/SIMULATION_CONTRACT.md` v1.1 (440 lines).
**Cost:** 3 rounds + 1 revision pass. ~16 agent turns total.

**Retro:**

*Worked:*
- Round 1 constraint-only declarations forced agents to separate "must have" from "would like" before debate
- Pre-seeded A/B/C options anchored the discussion vs. starting from a blank canvas
- Round 2's steel-manning + DM-encouragement dissolved the apparent A-vs-B disagreement (was actually narrower than it looked) and produced direct peer negotiation on tick order + SpatialIndex query shapes
- Convergence checkpoint between Round 2 and Round 3 made implicit explicit — author drafted from clear inputs
- Conditional sign-off + bundled revision pass: 3 fixes, one round-trip, ratified without a second full review round

*Broke or felt wrong:*
- Author first posted draft in chat without committing the file. Lead checked file too early; clarification needed. Fixed in §9 rule #1.
- Some peer DMs (qa-engineer → engine-architect, +1 fix) were opaque to the lead. Caught only via sign-off summary. Acceptable tradeoff vs. suppressing peer discussion. Captured in §9 rule #3.

*Changed in this doc:* §9 rules #1, #2, #3 added.

---

### Sync 2 — State Machine Contract
**Date:** 2026-04-30
**Pattern:** Constraint Negotiation
**Participants:** engine-architect, ai-engineer
**Question:** What's the contract for `UnitState` and `StateMachine` that handles command queueing, interrupt priority, death-from-any-state, and AI-controller-level state machines without forcing rewrites in Phase 2-6?
**Outcome:** Ratified. `docs/STATE_MACHINE_CONTRACT.md` v1 (420 lines, joint authorship).
**Cost:** 2 rounds. ~8-10 agent turns total (lower than Sync 1's 16).

**Retro:**

*Worked:*
- **Constraint Negotiation pattern was the right call.** No third-party reviewer needed; both agents had authority, both did the work. Round 2 collapsed into peer DM drafting with no team-lead routing.
- **Round 1 constraint-only declarations** showed ~90% convergence in their first messages — the pattern's value is partly in surfacing how aligned agents already are. Saved a Round 3 entirely.
- **Joint authorship via DMs** produced two unprompted resolutions worth more than either constraint declaration alone:
  - States as `RefCounted` instead of `SimNode` (saves ~1000 Nodes in 100-unit battle)
  - `INTERRUPT_NEVER` semantics (blocks damage preemption, allows player commands)
- **Brief team-lead role** — sent 2 messages total during the sync (Round 1 prompt + Round 2 prompt). All substantive negotiation happened peer-to-peer. Servant-leader principle held: when agents can do the work, get out of the way.

*Broke or felt wrong:*
- One brief "crossed wires" moment when both authors started writing simultaneously, but they self-corrected within one message. No facilitator intervention needed.
- Doc came in 70 lines over the 350-line target. Ratified anyway — Manifesto Principle 5 says foundation contracts shouldn't be arbitrarily compressed. Caps are guidelines, not constraints.

*Changed in this doc:*
- §9 rule added: **Caps on artifact length are guidelines. If both authors agree density earns the lines, the cap is waived.**

*Pattern validation:*
Constraint Negotiation cost ~50% of Sync 1's Author + Reviewers cost. For 2-agent decisions with strong shared authority, it's the right pattern. Reserve Author + Reviewers for 3+ participants or where one agent has clear ownership.

---

### Sync 3 — Testing Contract
**Date:** 2026-04-30
**Pattern:** Author + Reviewers
**Participants:** qa-engineer (author), engine-architect, balance-engineer
**Question:** What's the testing infrastructure beyond the Sim Contract — BalanceData.tres structure, telemetry event schema, MatchHarness API, AI-vs-AI sim harness output, coverage guidance?
**Outcome:** Ratified. `docs/TESTING_CONTRACT.md` v1.3 (346 lines).
**Cost:** 1 round + 2 revision passes (one per reviewer's input wave). ~12 agent turns total.

**Retro:**

*Worked:*
- **Iterative drafting beat batched review.** qa-engineer drafted v1, balance-engineer DM'd informal input → v1.1, balance-engineer's formal R1 input arrived → v1.2, engine-architect's review → v1.3. Each iteration was small and focused. Total artifact churn was lower than waiting for both formal reviews to land before any revisions.
- **Cross-validation moment:** balance-engineer praised qa-engineer's automatic `constants_version` hash as "strictly better than my proposed manual string." That's the format earning its keep — when reviewer praise is unprompted on choices the author made independently, the draft has the right voice.
- **Sim Contract absorption was real.** The originally-proposed Testing Contract overlapped heavily with Sync 1's deliverable. Narrowing Sync 3 to "what Sim Contract didn't cover" meant the doc landed at 346 lines with no waste. Lesson: when later syncs build on earlier ones, scope down explicitly to avoid redundancy.

*Broke or felt wrong:*
- The "draft committed → my prompts to reviewers → reviewer revisions → second draft" sequence had a small race condition: balance-engineer's formal R1 message arrived after I'd already prompted them to review v1.1. qa-engineer correctly merged the formal input into v1.2, but the review-prompt to balance-engineer became stale before they could act on it. Net cost: one redundant message. Acceptable.

*Changed in this doc:*
- No new rules. The patterns held.

*Pattern validation:*
Author + Reviewers with 3 participants worked well when one reviewer (balance-engineer) was a heavy domain consumer who could feed input upstream during drafting, and the other (engine-architect) was a constraint-checker reviewing for consistency with prior contracts. Different reviewer roles within the same sync is fine — and probably desirable.

---

### Sync 4 — Resource Node Schema
**Date:** 2026-04-30
**Pattern:** Constraint Negotiation
**Participants:** world-builder, gameplay-systems
**Question:** What's the `ResourceNode` interface for depletable mines and player-built farms, and the gather/deplete API workers consume?
**Outcome:** Ratified. `docs/RESOURCE_NODE_CONTRACT.md` v1.1.0 (430 lines).
**Cost:** 2 rounds + 1 design-driven revision pass. ~14 agent turns.

**Retro:**

*Worked:*
- **Filename autonomy.** Agents renamed the file from `RESOURCE_NODE_SCHEMA.md` to `RESOURCE_NODE_CONTRACT.md` for consistency with Sync 1/2/3 contracts. Lead didn't impose; agents recognized the convention and applied it. Naming consistency emerged from peer alignment.
- **Path 2 escape hatch design** — both authors anticipated the worker-gathered grain branch and wrote §1.4 specifically as a "surgical patch" target. When the design call came back, the patch landed mechanically without re-architecture. Manifesto Principle 5 (Platforms not features) made flesh.
- **Multiple work splits negotiated peer-to-peer.** "you take §1.4 and §7, I take §2.3 and §3.4" — clean handoffs without lead routing.

*Broke or felt wrong:*
- **Premature ratification.** Both authors signed off on v1 *before* the design decision (Path 2) had been processed in the file. The lead's own message and the agents' ratification crossed in time. Lead caught it via file inspection — but only because it was checked. **This is the single biggest learning of Sync 4: trust but verify.**
- **Filename confusion mid-sync.** Two files briefly existed (`RESOURCE_NODE_SCHEMA.md` + `RESOURCE_NODE_CONTRACT.md`) before agents converged. Brief friction; self-resolved.

*Changed in this doc:*
- §9 rule added: **Lead must read the actual file diff against the latest design decisions before ratifying.** Agents can sincerely sign off on a stale state. Verify, don't assume. Cited Manifesto Principle 1 (Truth-Seeking).
- New §13 added: **SemVer policy for all contracts and the game project itself** (was §12 before §12 Operating Modes was inserted).

*Pattern validation:*
Constraint Negotiation continues to deliver — ~14 turns for a well-architected 430-line contract with two design escalations cleanly logged. Better cost than Author + Reviewers for 2-agent decisions.

---

### Sync 5 — Difficulty Tuning
**Date:** 2026-05-01
**Pattern:** Open Consultation
**Participants:** ai-engineer, balance-engineer
**Question:** What are the concrete Easy/Normal/Hard parameters for Turan AI?
**Outcome:** Ratified. `docs/AI_DIFFICULTY.md` v1.0.0 (~140 lines). Lead synthesized the disagreement.
**Cost:** 1 round + facilitator synthesis. ~3 agent turns total.

**Retro:**

*Worked:*
- **Single-round Open Consultation produced a real disagreement that needed facilitator decision** — ai-engineer wanted "Easy = player gets bonus" framing, balance-engineer wanted "Easy = AI gets penalty" framing. Both made strong cases. Lead made the call (gather-penalty primary, per Manifesto Principle 4 lean iteration — pick one mechanism and iterate, don't stack).
- **Cross-domain validation surfaced a 4th dial that wasn't in the prompt** — ai-engineer's `attack_army_threshold` insight was independently correct (Hard with thin spam armies = spam not pressure). The format makes room for "yes, and also..." inputs.
- **Cheapest sync yet** — 3 agent turns, ratified deliverable, complete in minutes.

*Broke or felt wrong:*
- Nothing — the pattern fit the question.

*Changed in this doc:*
- No new rules. Open Consultation works as specified for low-ambiguity, parameter-shaped decisions even when the lead has to break a tie.

*Pattern validation:*
Open Consultation is the right pattern for parameter-tuning where multiple agents have judgment but no clear ownership. Cost is minimal (~3 turns), the deliverable is concrete (a values table + rationale + criteria), and lead synthesis is honest (the choice rationale is in the doc, not hidden).

---

### Phase 0 Implementation — Foundation Built
**Date:** 2026-05-01
**Pattern:** Implementation mode (per §12) across 4 sessions
**Participants:** All 7 agents through 4 sessions
**Outcome:** Phase 0 foundation built. 26 subsystems ✅ Built. 250 unit/integration tests (249 passing + 1 intentional Pending). Lint clean. 16 commits on `feat/phase-0-foundation`.

**Sessions:**
- **Session 1:** engine-architect — Godot 4.6.2 init + GUT 9.4.0 + 4 autoloads (TimeProvider, EventBus, SimClock) + SimNode + 28 tests
- **Session 2:** qa-engineer + engine-architect (parallel) — lint script + pre-commit hook + Sim Contract 1.2.1 PATCH
- **Session 3 wave 1:** engine-architect — Constants, GameState, SpatialIndex, IPathScheduler, StateMachine framework + 60 tests
- **Session 3 wave 2:** ui-developer + world-builder (parallel) — camera (fixed iso), DebugOverlayManager, terrain plane + nav + 42 tests
- **Session 3 wiring:** main.tscn integration — terrain + camera visible
- **Session 3 fix:** camera elevation bug caught by visual inspection
- **Session 4 wave 1:** balance-engineer + qa-engineer + ui-developer + gameplay-systems (parallel) — BalanceData, MockPathScheduler, HUD + translations, FarrSystem skeleton + 66 tests
- **Session 4 wave 2:** qa-engineer — MatchHarness + determinism stub + 51 tests

**Retro:**

*What worked:*
- **The studio process paid off in implementation.** Six syncs of contract-first work produced contracts that agents could read and implement against directly. Zero major architectural surprises during implementation; only small clarifications needed (Sim Contract 1.2.1 patch). The cost of design-mode pays back during implementation-mode through reduced backtracking.
- **TDD discipline held.** 250 tests across 4 sessions, with each subsystem getting unit tests as it landed. Pre-commit hook caught issues before they reached the branch. The structural enforcement layer (SimNode assertion + lint rules + pre-commit) actually does what it's designed to do.
- **Parallel waves worked cleanly with file-ownership discipline.** Wave 1 of session 4 ran 4 agents in parallel touching different file domains; cross-agent file conflicts surfaced once (ARCHITECTURE.md merge contention during simultaneous edits) but resolved automatically by git's line-level merging. The "ONLY touch your rows" rule held.
- **Live coordination via build log.** world-builder cited ui-developer's camera tests as confirming `MAP_SIZE_WORLD` reads cleanly during their parallel work. Truth-Seeking working through artifacts rather than synchronous coordination.
- **The "trust but verify" rule (Sync 4 retro) saved us again.** ARCHITECTURE.md had been pre-populated by parallel agents with rows describing not-yet-built work. balance-engineer noticed and called it out. Lead's verification habit caught it. Without that rule, the doc would have lied.
- **Lean Iteration discipline held.** No gold-plating. Every agent shipped minimum viable per their session brief. Camera doesn't have rotation/follow/cinematic modes. Debug overlay framework doesn't have actual overlays. FarrSystem is just the chokepoint, no generators/drains. The point was scaffolding; behavior comes in the phases that need it.

*What broke or felt wrong:*
- **Camera elevation bug missed by all 130 unit tests.** The bug was geometrically subtle: Camera3D at `(0, 0, zoom_distance)` in rig-local → at world Y=0 (ground level) after the rig's yaw → looking down through the terrain plane. Tests checked `zoom_distance` clamps and `target_position` math but no test verified the camera position would actually frame the scene. **Caught only by visual eyeball.** This is a class of bug that headless unit tests structurally cannot catch.
- **Pre-commit hook running against untracked test files from parallel agents created non-determinism.** qa-engineer's commit needed multiple attempts because their lint/test gate sometimes saw incomplete tests from parallel agents that weren't yet staged. Acceptable for a 4-agent parallel wave; would compound if more agents ran simultaneously.
- **Doc drift between contracts.** FarrConfig comment in `balance.tres` claims `× 1000` storage but Sim Contract §1.6 (the SSOT) specifies `× 100`. Two contracts that should agree, drifted. SSOT discipline (§9 rule) is the long-term protection but didn't prevent this one. Worth a cleanup pass.
- **Testing Contract §1.3 self-contradiction.** "Returns false and refuses to load" (implies bool return) AND "returns list of invariant violations (empty array = pass)" (implies Array[String]). balance-engineer chose Array[String] and flagged the inconsistency. A future PATCH should resolve.
- **`class_name State` registration race in GUT** (Sync 3 retro re-iterated). RefCounted classes used by GUT-collected test scripts can fail to resolve `class_name` due to test-script parse order vs. class_name registry population order. Workaround: path-based references (`preload(...)` instead of `class_name`). This added verbosity that will accumulate across more tests.

*Changed in this doc:*
- §9 rule added: **Scenes need visual smoke tests beyond unit tests.** A scene-level test that loads the scene, renders one frame, and verifies expected visual elements (e.g., terrain pixel in framebuffer center) catches the class of bug that elevation/framing/visibility errors fall into. Headless rendering capable; image comparison possible. Phase 1+ work — too thin to ship for Phase 0 alone.
- §9 rule added: **Doc cross-validation.** When a fact is referenced in two contracts (e.g., FarrSystem storage scale in both Sim Contract §1.6 and FarrConfig comment), at least one of them must explicitly link to the other as the SSOT. The link is the binding; the duplicate becomes a "see X" pointer. SSOT discipline (existing rule) addresses the principle; this new rule operationalizes the cross-link mechanism.
- §9 rule added: **Pre-commit gate stability under parallel agents.** When N agents run in parallel against the same branch, the pre-commit hook can race on staged-vs-untracked test files. Mitigation: pre-commit should only run lint+tests against tracked files (`git diff --cached --name-only` filter). LATER work; documented for the next session that runs N>2 agents in parallel.

*Pattern validation:*
- **Implementation mode (TDD-driven, async, per §12.2) works as designed.** No syncs needed during Phase 0. Agents read contracts, wrote tests, implemented, committed. The mode separation (§12) is the right shape.
- **Sequential waves (wave 1 in parallel, then wave 2) is a good model for dependency-respecting parallelism.** Worked for session 4. Wave 1 agents share no dependencies; wave 2 depends on wave 1's output.
- **Architecture document earned its keep.** Every agent reported reading it for orientation, and the build-state table in §2 became the source of truth for "what's done vs planned" through the phase. The plan-vs-reality §6 captured 8 honest divergences across the phase.

---

### Convergence Review — Phase 0 Foundation Ratification
**Date:** 2026-04-30 — 2026-05-01
**Pattern:** Convergence Review (Pattern E) — first run
**Participants:** All 7 agents (engine-architect, ai-engineer, gameplay-systems, ui-developer, world-builder, balance-engineer, qa-engineer)
**Question:** Does the consolidated decision stack (5 contracts + studio process + plan + manifesto) hold up to cross-domain scrutiny? What seams have been missed?
**Outcome:** Ratified. 12 P0 items found and resolved across 5 revision passes. Contract version bumps:
- Sim Contract 1.1.0 → 1.2.0 (UI off-tick rule, SpatialIndex read-safety, cleanup-phase coordinator note, Numeric Representation §1.6 — fixed-point integer arithmetic for Farr)
- Testing Contract 1.3.0 → 1.4.0 (EconomyConfig nests ResourceNodeConfig, AIConfig flat-fields, snapshot() primitive-only, _test_set_farr emits farr_changed, 4 resource signals in NDJSON catalog)
- Resource Node Contract 1.1.0 → 1.1.1 (dual-mode signal payload — API ref / telemetry destructures into serializable fields)
- AI Difficulty 1.0.0 → 1.1.0 (tech-up 6/5/4, match-length targets all difficulties, gather-multiplier dual-factor addendum §5)

**Cost:** ~25 agent turns total (one round of 7 reviews + 5 parallel revision passes + 1 joint addendum + ratifications). Approximately the cost of two regular syncs, with the value of catching issues that all five regular syncs could not.

**Retro:**

*What the format caught that the original syncs didn't:*
- Cross-sync schema drift: Testing Contract was authored before RNC and AI_DIFFICULTY ratified, so its EconomyConfig and AIConfig had become stale. **Six P0 patches in one contract** — five separate agents flagged variations of this. Pattern E surfaces "this contract aged out of date because later contracts moved" — a class of bug that single-sync review can't see.
- Implicit rules that nobody wrote down: Sim Contract had two implicit rules (UI off-tick discipline, SpatialIndex read-safety) that never got written because they felt obvious to the author. ui-developer (who wasn't in Sync 1) caught both in the Convergence by asking "from my domain, where does this break?"
- Convergent insight: gameplay-systems and balance-engineer independently flagged that Farr should be stored as fixed-point integer to avoid IEEE-754 platform divergence. Two specialists from different domains arriving at the same engine-implementation insight is a strong signal — this got promoted from a Farr-specific note to a general Numeric Representation principle in Sim Contract §1.6.
- Cross-system handshakes that weren't specified: AI gather multiplier application point was unspecified across all 5 contracts. balance-engineer caught it; ai-engineer + gameplay-systems then negotiated a peer-to-peer solution (dual-factor) that lands cleanly without modifying contracts they don't own.

*What worked:*
- **OST framing was load-bearing.** Treating the Convergence as a "harvest gathering" of all parallel rooms — not a final review session — gave agents permission to raise concerns from their domain without seeming to second-guess the original sync participants. ui-developer's three P0 finds came from an agent who'd been on standby through five syncs.
- **Skeptical prompt anchored the review.** The "ask yourself what would break if I'm wrong about my no-objection" line in the convergence prompt prevented bystander mode. Six of seven agents found at least one issue.
- **Bundled revision passes scaled cleanly.** Five parallel revision passes ran simultaneously, with peer DMs handling cross-contract coordination (qa-engineer ↔ world-builder on field naming, ai-engineer ↔ gameplay-systems on the addendum). No central routing bottleneck.

*What broke or felt wrong:*
- The joint addendum (ai-engineer + gameplay-systems on gather multiplier) bounced between options three times before landing on a stable dual-factor design. Took ~7 messages of negotiation. Probably acceptable for genuine design ambiguity, but the lead could have stepped in around message 5 with a tie-breaker proposal. Lesson: facilitator should set a "round limit" for joint addenda too, not just for syncs proper.
- One agent (engine-architect) committed their revision but didn't send a "v1.x.x committed" notification. Lead caught it via file inspection. **The "trust but verify" rule from Sync 4 retro held perfectly here** — verification doesn't depend on agents remembering to notify.

*Changed in this doc:*
- §9 rule added: **Joint addenda (peer-negotiated cross-contract additions) should also have a round limit.** Three options bouncing more than 3 rounds = lead intervenes with a tie-breaker proposal. Otherwise the negotiation can spin.

*Pattern validation:*
**Pattern E (Convergence Review) is essential for any project with 4+ ratified contracts.** The cost (~2 syncs' worth of turns) is worth it for the issue density caught. Recommend running Convergence Review whenever a logically-grouped set of contracts ships — not just at end-of-foundation. Could be re-run before Tier 1 vertical slice (after Phase 5-6 systems contracts ship), and again before Tier 2 demo.

---

### Phase 3 session 1 — economic loop foundation
**Date:** 2026-05-08 — 2026-05-14
**Pattern:** Implementation session (waves 0 → 1A → 1B → 1C → 3) + reviewer-trio wave-close + 2 lead live-test rounds + multi-agent retro
**Participants (shipping):** qa-engineer (waves 0, 3), gameplay-systems (waves 1A/1B/1C + BUG-08), ui-developer (build menu, BUG-09 attack-range, Farr gauge polish), world-builder (Khaneh visual). Plus reviewer-trio: godot-code-reviewer + architecture-reviewer + shahnameh-loremaster (first session for the latter as a formal review role).
**Outcome:** Phase 3 session 1 merged to main at `1466d15` (PR #12). 49 commits, 1105 tests passing, 0 failures.

**What shipped:**
- Economic loop foundation: ResourceSystem autoload + chokepoint, MineNode + ResourceNode base, Kargar gather FSM, Building base + Khaneh, BuildPlacementHandler + build menu, FarrDrainDispatcher, drain_rates table, F4 overlay live-tracking, Farr gauge fractional precision, dark HUD shelf, `tools/run_game.sh` log piping infrastructure.
- 5 bugs surfaced + closed at lead live-test: BUG-07 (MineNode collision) → BUG-08 (BPH selection desync) → BUG-09 (F4 not tracking) → BUG-10 (`_unhandled_input` sibling-order convention reversal) → BUG-11 (buildings leaked into box-select).
- 3 design-chat escalations queued in `QUESTIONS_FOR_DESIGN.md`: Q1 UI naming convention, Q2 Coin vs Sekkeh, Q3 Turan housing analogue.

**Cost:** ~9 waves total (0 + 1A + 1B + 1C + 3 + reviewer-trio + post-live-test-1 fix-wave + BUG-10 surgical + BUG-11 surgical), 7 dispatched agents at retro time (4 retros + 3 cleanup).

**Retro:**

*Convergent finding (3 of 4 agent retros, three different layers):* when a wave introduces a new participant in a shared classification surface, the participant must be verified against EVERY existing consumer of that surface — not just the new node's own flow. qa-engineer proposed test-coverage-disclosure (blindspot declaration); gameplay-systems proposed test-design (cross-feature regression matrix); architecture-reviewer proposed code-review (cross-cutting schema check, BLOCKING). All three land in §9 as a triangulated rule.

*Architecture-reviewer self-reflection (load-bearing):* "I had the evidence in hand and deferred." L22 was Pitfall #5 prose ("reverse-tree-order") vs. project headers ("tree-document order") — flagged as future LATER instead of resolved empirically before wave-close approval. BUG-10 shipped because of that deferral. Resolution: SSOT prose contradictions across docs are BLOCKING, not LATER. Lands in §9.

*Shahnameh-loremaster first-session feedback:* the four findings caught at wave-close were all template seeds (strings.csv pattern, abstract base class header, cultural-note block in state script). Brief-time review for template-cloning surfaces would compress the loop and prevent follow-up-commit accumulation. Lands in the agent definition as a new dispatch context.

*Lead's facilitator-with-continuity contribution (initial LLM adaptation framing):* subagents are ephemeral; at retro time, specialist personas are FRESH instances reading post-hoc artifacts. They do post-hoc review well but cannot reconstruct in-the-moment lived friction. The LLM adaptation of "invite the people who lived it" is **capture the lived experience at peak-fresh in the wave-close report** — new mandatory "What tripped me up in this wave" section, first-person, ~1 paragraph. The lead is the ONLY continuous-lived-experience participant across waves; lead's facilitator contribution isn't optional flavor, it's the only inter-wave-friction signal the room has. Lands in §9.

> ⚠️ **Refinement (2026-05-14, same-day follow-up):** the "subagents are ephemeral" framing above turned out to be a CHOICE I'd been making by reflex, not an inherent runtime constraint. The runtime supports persistent agents via `SendMessage`-resume. Siavoush flagged this and pushed the framing further: persistence must hold across the **decision-arc** (Open Space → implementation waves → retro), not just within a session. The lead is therefore NOT the only continuity participant in the persistent world — persistent specialists and reviewers are also continuity participants for their slice of the arc. Lead retains BROADER continuity (cross-agent, cross-session) but isn't unique. The "What tripped me up" wave-close section is now BACKUP CAPTURE (in case an agent has to be cycled mid-session), not primary signal. Primary signal is: ask the agent who lived the wave; they remember. See §9 rules: Agent persistence + Two-class review architecture + Decision-arc instance continuity, plus §12.5.

*Inter-wave patterns (lead-only signal):*
- **Compound-bug discipline.** BUG-08's fix didn't actually close the user-visible bug; BUG-10 was the real root cause. Reviewer trio shipped 4 commits on the wrong hypothesis. Defense-in-depth without verified prime mover means the next live-test IS the diagnostic.
- **Live-test cadence is the real acceptance funnel.** ship → live-test #N → diagnose → fix → live-test #N+1 → … → clean → PR. Lands in §9.
- **`tools/run_game.sh` paid off immediately on first deployment.** BUG-10 in one log round-trip vs. 3+ copy-paste rounds. Lands in §9 as project standard.
- **Process-mitigation confidence calibration.** L23 (the unimplemented `isolation: "worktree"` runtime gap) showed document claims ≠ runtime behavior. Lands in §9 as a verification-before-ratification rule.
- **Per-TDD-cycle commits at scale.** 49 commits, surgical cherry-picks worked cleanly even through the Pitfall #7 race. Positive reinforcement of existing graduated rule; no edit needed.

*Changed in this doc (initial six rules):*
- §9 rule added: **Cross-cutting schema verification at wave-close — triangulated rule covering three layers** (code-review BLOCKING grep + test-design crossover matrix + qa-side blindspot declaration). Convergent across 3 retros.
- §9 rule added: **SSOT prose contradictions across docs are BLOCKING at wave-close review, not LATER.**
- §9 rule added: **Wave-close reports include a "What tripped me up in this wave" first-person section.** LLM-adaptation of human-retro "invite the people who lived it" pattern. (NOTE: refined by subsequent rules to BACKUP CAPTURE — primary signal is asking the persistent agent.)
- §9 rule added: **Live-test cadence is the real acceptance funnel; PR opens after live-test reaches clean state.**
- §9 rule added: **Process-mitigation claims that promise "structural fix" must include runtime verification before the §9 entry can land as ratified.**
- §9 rule added: **`tools/run_game.sh` is the project's standard interactive-launch path.**
- `.claude/agents/architecture-reviewer.md` updated: cross-cutting schema check elevated to BLOCKING priority-1; SSOT prose contradictions BLOCKING.
- `.claude/agents/shahnameh-loremaster.md` updated: new section "Template-cloning surfaces — review at brief-time, not wave-close" added.
- ARCHITECTURE.md §7 LATER index: L22 closed (Pitfall #5 prose was right — see §6 v0.20.8); L23 NEW (Agent-tool worktree-isolation runtime gap); L24 NEW (AttackMoveHandler same-issue-as-BUG-10 verification pending).

*Changed in this doc (follow-up — same-day, in response to Siavoush's gap-finding on retro-time-agent ephemerality):*
- §9 rule added: **Agent persistence — three tiers** (Tier-1 session-persistent reviewers, Tier-2 within-session specialist persistence, Tier-3 ephemeral one-shot).
- §9 rule added: **Two-class review architecture — persistent in-team reviewers + ephemeral fresh-spawn PR-time external-audit reviewers.**
- §9 rule added: **Decision-arc instance continuity** — SAME agent instances persist from Open Space → implementation waves → retro. Documents are not substitutes for agents-who-remember-arguing-the-rule.
- §12.5 new subsection added: **"Mode separation is COGNITIVE, not INSTANCE separation"** — clarifies that the design/implementation mode boundary is about the kind of thinking the agents do, not about whether they're the same instances.
- §6 new subsection added: **"Dispatch judgment — SendMessage-resume vs. fresh Agent spawn"** — lead's new routing responsibility in the persistent world.
- NEW agent definition: `.claude/agents/peiman-manifesto-reviewer.md` — fresh-spawn at PR-time, audits against the canonical [Peiman Khorramshahi manifesto](https://github.com/peiman/manifesto). Deliberately project-context-naive.
- `.claude/agents/architecture-reviewer.md` updated: dual-mode documented (Mode A persistent wave-close; Mode B fresh-instance PR-time).

*Changed in this doc (consistency audit — Siavoush's request to check for surgical-change conflicts):*
- Historical §9 entries (2026-05-03, 2026-05-12, 2026-05-13) annotated with ⚠️ inline cross-references to the 2026-05-14 persistence + two-class architecture rules. Archaeology preserved; current state signaled.
- 2026-05-13 worktree-per-agent entry annotated: "RESOLVED" softened to "RATIFIED (NOT YET RUNTIME-VERIFIED)" with a ⚠️ status update pointing to LATER L23 + the 2026-05-14 "Process-mitigation runtime verification" rule.
- §12.4 mode-switch wording clarified: "stand down from the team channel" now reads "shift OUT of deliberative team-channel participation INTO async implementation work" — they are NOT terminated, only their participation mode shifts. The instance persists across the mode boundary per §12.5.
- Doc version bumped to 1.5.0 (per §13 SemVer policy — MINOR for additive rules + the §12.5 clarification; no breaking changes to prior workflow).

*Pattern validation:*
**Multi-agent retro with parallel-dispatched specialist agents works, BUT with the LLM-adaptation caveat: retro-time agents are fresh instances doing post-hoc review, not lived-experience memoir.** The convergent-finding pattern (3 of 4 agents triangulating from different layers) is strong evidence the format produces value, but the lived-experience component must be captured upstream at wave-close (new rule) rather than reconstructed at retro time. Lead's facilitator-with-contribution is load-bearing in LLM retros because lead is the only continuity-of-experience participant. Confirmed worth running at end of every implementation session.

### Phase 3 session 2 — Mazra'eh, Ma'dan, Building taxonomy

**Pattern:** Implementation mode (per §12) with persistent-agent architecture (§12.5 within-session decision-arc continuity in operational shape for the first full session).

**Composition:**
- Open Space session-start: three Open Space rooms (Room A — Mazra'eh-as-Building duck-type vs ResourceNode subclass; Room B — fog data schema; Room C — DummyAI Pattern B sync with balance-engineer). Convergence Review synthesized cross-cutting concerns; ai-engineer's CC-3 pre-sign-off propagated through carry-forward state.
- Wave 1A: Mazra'eh class+scene + Building.get_footprint_aabb + ResourceSystem.register_node signature evolution + FOG_DATA_CONTRACT v1.3.0 + RNC v1.2.0→v1.2.3 (4 minor patches across the wave). 15 commits including 2 misattribution incidents (Pitfall #7) and 3 clean discipline trials.
- Wave 1B: Ma'dan class+scene (buff-emitter Building, Option B locked from arch-reviewer + loremaster carry-forward) + ResourceNode modifier-registry API + RNC v1.3.0 §4.7 + brief-time cultural review (loremaster canonical case #2) + balance-engineer BalanceData entry. 10 commits, 4 contributors, 0 Pitfall #7 incidents (down from 3 in wave 1A — strong evidence the §9 anti-loop discipline works bilaterally).
- Live-test cadence: wave-1B live-test surfaced UI translation regen gap (fixed at `d61eb79`) + NavigationObstacle3D inert reality (captured as L25 + wave 1C architecture spike Task #120).
- PR #14 merged to main at `6c72c6a` (31 commits).
- Session-close retro: 9 persistent agents dispatched in parallel; 5 inputs landed (world-builder, godot-code-reviewer, architecture-reviewer, shahnameh-loremaster, engine-architect); 4 asleep (gp-sys, balance-engineer, ai-engineer, qa-engineer — state preserved per §12.5.1 cross-session persistence rule for session-3 surface).

**Outcomes — §9 cluster (2026-05-17):**
- 15 new rules + refinements landing as a coherent cluster. Anti-loop staging discipline finalized (4 proposals from session 1+2 retros all ratified). SSOT prose discipline refined for retroactive-staleness case. Spec-wins pattern formalized with citation-density corollary. Distribution-discipline ("ownership beats warmth") + mid-wave rebalance discipline codified. Intent-vs-implementation cultural-claim split (loremaster's discipline-correction from Observation 3). Contract-prose hedging for engine-feature claims (engine-architect's finding). Behavioral-vs-structural test discipline (engine-architect's finding, godot-code-reviewer's domain). Lead-takes-work-when-specialist-unresponsive carve-out. strings.csv → .translation binary regen rule. Pre-commit self-review pattern. Layer 1.5 enumeration discipline standardized. Brief-time loremaster review formalized + anchor-category taxonomy enumerated + literal-then-tricky-gloss discipline pinned + watch-list. Single-report-per-investigation discipline. Cross-session persistence (§12.5.1 extension).

**Outcomes — Pitfall #12 + #13 thematic cluster promoted to permanent Known Pitfalls list:**
- "GDScript class-identity asymmetry: engine reflection APIs ignore the class_name registry layer."
- Pitfall #12 (parse-time + runtime): `Engine.has_singleton`/`get_singleton` mis-API for script autoloads + bare-identifier parse failure for forward-declared autoloads.
- Pitfall #13 (runtime): `Node.get_class()` returns C++ base type for path-string-extends GDScript classes; use `Script.get_global_name()` instead.
- Third surface (`is <ClassName>` operator) flagged for post-promotion probe test.

**Outcomes — Agent definition updates:**
- 5 agent files updated with session-2 retro discipline additions (architecture-reviewer: Proposals A-D; godot-code-reviewer: Layer 1.5 + scaffold-inheritance + behavioral-vs-structural + Pitfall #12/#13 + probe-test discipline; shahnameh-loremaster: 8-point brief-time-review checklist + anchor-category taxonomy + literal-then-tricky-gloss + citation-density + intent-vs-implementation split; engine-architect: single-report + adjacent-code-verification + contract-prose hedging + ARCHITECTURE.md co-authorship; world-builder: pre-commit self-review + cultural-note template + unconditional pathspec).

**Outcomes — QUESTIONS_FOR_DESIGN.md:**
- Turan-economy entry routed (2026-05-17): two waves of cross-faction caveats (Mazra'eh's karavan + Ma'dan's baj) converge on tribute + raid + caravan framing for Turan, NOT mirror-buildings-of-Iran. Routes to design chat for ratification before Phase 4 Turan-buildings dispatch.

**Outcomes — STUDIO_PROCESS.md:**
- §12.5.1 cross-session persistence rule added.
- §9 2026-05-17 cluster appended (15 new rules + refinements).
- §6 dispatch-judgment section cross-references §12.5.1 + §9 2026-05-17 cluster for lead-discipline operational rules.
- Doc version bumped to 1.6.0 (MINOR — additive rules + §12.5.1 extension; no breaking changes to prior workflow).

**Outcomes — ARCHITECTURE.md:**
- §6 v0.21.0 (wave 1A close), v0.21.1 (wave 1B close), v0.21.2 (session-close retro) entries shipped during the session.
- §7 LATER: L25 (NavigationObstacle3D inert) + L26 (mine_node.tscn missing NavigationObstacle3D) added; both resolve at wave 1C spike (Task #120).

*Pattern validation:*
**Persistent-instance retro produces substantively different content than fresh-spawn retro.** Cross-agent self-criticism (loremaster's Observation 3: "I praised §4.7.5 as form-follows-source; engine-architect's later finding showed the mechanical half is inert"); automaticity-threshold timing (godot-reviewer's Layer 1.5 5-min→4-min); held-end-to-end decision-arc tracking (arch-reviewer's verbatim wave-1A → wave-1B carry-forward citations); contract-confidence-override introspection (engine-architect); mechanical self-debug from lived friction memory (world-builder's `1e8a213` self-diagnosis). NONE of these observations would surface from fresh-spawn retro agents — they require lived process memory + cross-agent observation. The §12.5.1 cross-session persistence rule preserves this quality going forward.

**The cost is real:** persistent retro outputs are longer (each agent weighs more context — session memory + cross-agent observations); lead synthesis workload is higher (richer / more interlinked inputs); aggregation surface is bigger. The benefit-cost asymmetry favors persistence at the depth-tier the project's reached, but the operational cost is captured as expected shape, not unexpected friction.

**The asleep-agents shape:** 4 of 9 retro inputs were asleep at retro-aggregation time. Synthesis proceeded with 5/9 + lead's drafting. Two substantive losses: ai-engineer's persistent-instance-value-from-IDLE perspective; qa-engineer's NEW-member-onboarding-discipline perspective. Per §12.5.1, their state is preserved — observations surface in session 3 if substantive. Asleep-agents is the operational reality of persistent-instance architecture; the doc captures the shape rather than mourning the data.

---

### Phase 3 session 3 — Wave 1C construction-timer + UI progress + placement validity (navmesh deferred)

**Date:** 2026-05-17 (same calendar date as session 2 close — long working day, two sessions back-to-back)
**Sync pattern:** N/A — this was an implementation session, not an Open Space sync. Logged here per §10's "one entry per session-close" extension.
**Persistent agents active:** gp-sys-p3s3, ui-developer-p3s3, world-builder-p3s2, engine-architect-p3s2, qa-engineer-p3s3, balance-engineer-p3s3. (Session 2's silent -p3s2 instances for gp-sys / ui-developer / balance-engineer / qa-engineer succeeded by fresh -p3s3 instances per §12.5.1 reboot clause; world-builder-p3s2 + engine-architect-p3s2 persisted directly.)
**PR:** [#16](https://github.com/siavoush/shahname-rts/pull/16) — squash-merged at `a0265da`. 20 commits clean, 1247 tests passing (+67 from session start), 0 failures, 5 pending, Pitfall #7 count = 0.

**Wave shape:**

Three working tracks shipped + one navmesh sub-track deferred per lead's option-B decision (2026-05-17):
- **Track 1 — construction-timer state machine (gp-sys-p3s3).** Two-stage Building lifecycle (`_on_placement_complete` = structural, `_on_construction_complete` = operational). Per-kind `construction_ticks` from BalanceData. `construction_finalized(placer_unit_id: int)` signal as the canonical post-Stage-2 observable. SHA chain: `2cedf81` + `a507512` + `e58d55c` + `3fbce2b` (signal follow-on after ui-developer-p3s3 caught the integration gap).
- **Track 2A — UI construction progress bar overlay (ui-developer-p3s3).** Control overlay renders above each building under construction. Hide-on-Stage-2 via `construction_finalized` signal. 16 behavioral tests including regression-locking poll-loop test. SHA chain: `a023242` + `280d27a` (fix-up after live-test surfaced overlay double-connect bug).
- **Track 2B — Building base `construction_progress_updated` signal seam (world-builder-p3s2).** SHA: `82bf198`. Clean separation of concerns: emit-from-state (gp-sys) → declared signal (world-builder) → consumed UI (ui-developer).
- **Ma'dan-over-mine placement validity (gp-sys-p3s3).** Generalized to ANY building over ANY resource node. SHA: `d078fd3`. Live-test confirmed by lead.
- **Open Consultation — construction_ticks values (balance-engineer-p3s3).** 540/660 anchored to Atashkadeh's 900-tick Tier-2 baseline with citation-density rationale. SHA: `cc449e5`.
- **Navmesh carving sub-track — DEFERRED.** Four implementation rounds (`affect_navigation_mesh` alone → `+ carve_navigation_mesh` → `+ manual region.bake_navigation_mesh(false)` → `+ SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`) failed to produce a working carve in live-test. Lead's option-B decision (2026-05-17): close wave 1C with the three working deliverables; punt navmesh to dedicated wave with proper time budget. Honest archaeology shipped in `docs/WAVE_1C_NAVMESH_SPIKE.md` v0.2.0 + RNC §3.2 v1.3.2 + ARCHITECTURE §7 L25/L26 with full 4-round diagnostic carry-forward. Engine-architect-p3s2's three diagnostic reports (binary-string probe technique) produced the canonical mechanism-correction archaeology.

**Retro inputs:** 2 substantive responses (ui-developer-p3s3, world-builder-p3s2) + 4 silent agents (gp-sys-p3s3, engine-architect-p3s2, qa-engineer-p3s3, balance-engineer-p3s3 — received the prompt, sent idle-pings, no substantive reflection). Plus 2 fresh-instance PR reviewer reports on PR #16 (architecture-reviewer + godot-code-reviewer; both verdict APPROVE-WITH-FIXES, no blockers, 9 SUGGEST carry-forwards). Per §12.5.1 the silent 4's state is preserved; observations surface in session 4 if substantive. Compared to session 2's 5/9 retro response rate, session 3's 2/6 is lower — the wave was substantially longer (~12 hours wall-clock) and persistent-agent compaction may have driven more of them into idle-state. Pattern documented; not yet a problem.

**Strongest single retro signal:** the **research-discipline rule** (engine-feature-verification cluster, rule 2). Four rounds of binary-symbol probing on the Godot 4.6 NavigationObstacle3D was ~90 minutes of cumulative diagnostic when ~5 minutes of docs lookup at round 0 would have surfaced the dual-flag distinction + no-auto-rebake reality + SOURCE_GEOMETRY_ROOT_NODE_CHILDREN default. The probing technique is correct discipline; the SEQUENCING is new — research before probing, every time. This is a meta-rule with high leverage for future engine-feature investigations.

**The wave's quality signal:** Pitfall #7 count = 0 across 20 commits (vs session-2 wave-1A = 3); 67 net new tests with behavioral-vs-structural discipline; the §9 anti-loop staging cluster from session 2 operationally validated. Multi-agent coordination DID produce one workspace incident (world-builder-p3s2's stash captured ui-developer-p3s3's WIP without broadcast) that surfaced the broadcast-before-stash rule — minor friction, fully recovered, captured as §9.

**§9 cluster shipped (2026-05-17, 14 rules):** 3 engine-feature-verification + 4 multi-agent-staging-coordination + 3 consumer-side-integration + 3 implementation-pattern (including Pitfall #14 promotion) + 1 meta-process-cluster (3 rules: lead-brief-as-review-surface, agent-def-self-update-verification, single-report-per-investigation refinement).

**Pitfall #14 promoted to permanent Known Pitfalls** in `docs/PROCESS_EXPERIMENTS.md`: GDScript lambda capture of reassigned locals is unreliable. Three operational mitigations documented (post-await SceneTree readout / signal-watching introspection / sentinel-append).

**Agent-def updates shipped:** world-builder-p3s2 self-edited (broadcast-before-stash + scene-config-as-forward-investment + super()-call discipline on Building virtuals — plus lead's correction of one factual error on L25 status, which itself surfaced the agent-def-self-update-verification rule). Lead-authored updates for engine-architect, ui-developer, qa-engineer, gp-sys agent-defs per the cluster.

**Carry-forwards routed to session 4:** 9 SUGGEST items from fresh PR reviewers (madan.tscn comment cleanup done pre-merge; BalanceData.placement_overlap_radius_m lift → wave 2A; `_resolve_terrain_region` multi-region docstring done pre-merge; `_run_inside_tick` helper adoption → incremental; `_resolve_terrain_region` caching → performance later; `_BUILDING_SCENE_PATHS` autoload promotion → at 4th-5th subclass; BUILDING_CONTRACT.md promotion → when contract-shape question surfaces; `_perform_placement` failed-parent test → LATER; L6 lint scope to test code → future audit). Dedicated navmesh wave scope + timing routed to design chat via `QUESTIONS_FOR_DESIGN.md` (2026-05-17 entry with three positions a/b/c).

**The session validates the persistent-instance architecture under stress.** Despite 4 rounds of navmesh diagnostic + workspace incident + ui-developer fix-up rounds + scope-revision pivot, all agents stayed coherent, picked up where they left off, brought lived memory of prior rounds to bear. §12.5.1 is empirically load-bearing.

---

### Phase 3 session 4 — Wave 2A Sarbaz-khaneh + Iran Tier-1 roster completion

**Date:** 2026-05-17 (continuation of the same-calendar-day arc that produced sessions 1+2+3; long working day; three coherent units shipped — Wave 1D navmesh resolution, Wave 2A Sarbaz-khaneh, session-4 close retro).
**Sync pattern:** N/A — implementation session with close retro. Logged here per §10's "one entry per session-close" extension.
**Persistent agents active:** gp-sys-p3s3, world-builder-p3s2, engine-architect-p3s2, shahnameh-loremaster-p3s4 (loremaster respawned mid-session after ~60min silent-channel-mismatch — see meta-process cluster). Other persistent instances (ui-developer-p3s3, balance-engineer-p3s3, qa-engineer-p3s3, ai-engineer) addressable but not substantively engaged in Wave 2A.
**PRs:** [#18](https://github.com/siavoush/shahname-rts/pull/18) (Wave 1D navmesh) merged at `7e4c365`; [#19](https://github.com/siavoush/shahname-rts/pull/19) (Wave 2A Sarbaz-khaneh) merged at `5a223fe`.

**Wave shape:**

**Wave 1D — Navmesh dedicated wave (closed earlier in the session day).** Closed Wave 1C's 4-round navmesh drift via the explicit four-call pipeline (`parse_source_geometry_data(nav_mesh, source, get_tree().root)` + `bake_from_source_geometry_data(nav_mesh, source)`) in `building.gd`. Root cause: the `region.bake_navigation_mesh()` convenience wrapper hardcodes `this` as the parse root, defeating `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` source-geometry-mode. Validated against Godot 4.6 source. L25 + L26 RESOLVED in ARCHITECTURE §7. L6 lint guards async-variant only (allows the sync `bake_navigation_mesh(false)` form used by building.gd). Workers route correctly around all Building subclasses in live-test. Honest archaeology via `docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0 Round 4 resolution.

**Wave 2A — Sarbaz-khaneh (5th Tier-1 Iran building, first identity-bearing-institutional anchor):**
- **Commit 1 — sarbaz_khaneh.tscn (world-builder-p3s2, `1ff3039`).** Inherits building.tscn; wider-than-square footprint (3.0×1.2×2.0); desaturated iron-red placeholder. Subsequent fix at `2f31b34` corrected inherited-scene nested-child override syntax (Pitfall #15 first incidence — see PROCESS_EXPERIMENTS.md).
- **Commit 1 — sarbaz_khaneh.gd class + 14 tests (gp-sys-p3s3, `8314a8a`).** `is_ready_to_produce` operational marker mirroring Mazra'eh's `is_gatherable`; flips at Stage 2 `_on_construction_complete`. Production-queue mechanics deferred to Phase 4.
- **Commit 1.5 — loremaster cultural-note integration (`a351869`).** Pahlavan/sepah two-layer framing (hero exceptionalism via Rostam vs. institutional ordinary via Piyade/Kamandar); cross-faction Turan caveat (steppe-mobile war-camps, not Sarbaz-khaneh clones).
- **Commit — build menu + strings (`2658405`).** UI wiring for the 5th Tier-1 button.
- **ARCHITECTURE.md §6 v0.24.0 wave-close entry (`812cdc9`).**
- **Pitfall #15 fix (`2f31b34`).** Inherited-scene nested-child override syntax — `parent="StaticBody3D"` + bare `name="CollisionShape3D"`, not slash in `name=`.
- **builder-position-during-construction routed to QUESTIONS_FOR_DESIGN (`9f94a3c`).** User observed worker stands inside building; strategic implications (AoE2 harassment-target vs SC2 protected) deferred to design chat.
- **PR #19 fix-up commits (`128af9f` gp-sys super-call sweep + SSOT citation cleanup; `0f986ff` lead Pitfall #15 promotion + ARCHITECTURE §2 row; `07c6ca8` world-builder TODO + test-header cleanup).**

**Retro inputs (final tally — all six substantive):** 3 fresh-spawn `-retro` responses (gp-sys-p3s4-retro, world-builder-p3s4-retro, engine-architect-p3s4-retro — process drift; lead spawned fresh agents instead of SendMessage-routing; user caught mid-retro; corrected via re-dispatch + memory save). 3 persistent-instance responses (gp-sys-p3s3, world-builder-p3s2, engine-architect-p3s2 — all responded after re-dispatch, world-builder-p3s2 after second ping due to channel-mismatch). **All three persistent responses arrived AFTER the fresh-spawn responses**, providing convergent confirmation + load-bearing additions that fresh-spawn could not produce. Critical example: engine-architect-p3s4-retro proposed narrow L7 lint for Pitfall #15; engine-architect-p3s2 (persistent) **rejected** it as wrong-layer (lint is for `.gd`, not `.tscn`) — the rejection only emerges from lived memory of L1-L6 lint architecture. **This retro produced the strongest empirical evidence yet that persistent-instance reflection is categorically more valuable than fresh-spawn reflection on the same artifacts.**

**Strongest single retro signal:** the **super-call sweep rule** (implementation-pattern cluster, rule 1). Captures the meta-pattern from session-3's super()-call-on-placement-complete discipline — when a base virtual ships with non-trivial future-additions surface, prior-shipped subclasses inherit a silent lock. Same-commit retrofit by the base-class shipper is the discipline. Wave 2A's `128af9f` was the canonical incident: base is currently `pass`, but the forward-compat lock-in is the point. gp-sys-p3s3's refinement: "the comment is the load-bearing artifact, NOT the super call itself" — without the future-failure-mode reasoning, a future reader sees identical-looking code and may remove the "redundant" super. **Second strongest signal:** the dispatch-channel + agent-channel discipline pair, captured live with two canonical incidents (lead's `-retro` mis-spawn + world-builder-p3s2's assistant-text response). The retro topic codified the rule the retro itself violated, twice. Dark comedy aside, the empirical anchor pair is the strongest possible evidence the rule is load-bearing.

**The wave's quality signal:** Wave 2A shipped clean — 5 commits Wave 2A scope + 3 fix-up commits Wave 2A wave-close cleanup; 0 broken-merge incidents; 0 Pitfall #7 occurrences. Pitfall #15 surfaced + fixed within the same wave (first incidence → live-test diagnosis → fix → regression-test → project-wide audit → permanent promotion, all in one wave). Two-stage Building lifecycle seam now load-bearing across 4 subclasses with 4 distinct Stage-2 shapes (pop cap, gatherable, modifier registration, production-readiness). The persistent-instance architecture continues to validate; channel-discipline gaps emerged but are recovered + codified.

**§9 cluster shipped (2026-05-17 session-4, 8 rules):** 4 implementation-pattern (super-call sweep + SSOT citation discipline + Pitfall #15 paired regression-test rule + two-stage Building lifecycle named pattern) + 1 test-discipline (hook-as-authoritative-gate) + 3 meta-process (dispatch-channel-discipline + agent-channel-discipline + heartbeat protocol). Pitfall #15 promotion ratified; mechanism-section addendum (silent-override signature) added to PROCESS_EXPERIMENTS.md.

**§12.6 Agent-Liveness Protocol shipped** as new subsection — heartbeat protocol with three-strike escalation, ping/response shapes, when-not-to-apply carve-outs.

**Agent-def updates shipped:** all `.claude/agents/*.md` get first-class SendMessage-as-channel discipline line. gp-sys: super-call sweep + SSOT citation rules. world-builder: Pitfall #15 awareness + inherited-scene regression-test pattern. engine-architect: heartbeat protocol references. Loremaster: cultural-note 4-part template formalized in agent-def (Sarbaz-khaneh canonical structure).

**Carry-forwards routed to session 5:**
- L7 lint rule for Pitfall #15 detection (`parent="."` + `name="X/Y"` malformed-override pattern) — qa-engineer scope at session 5 / Wave 2B.
- Tirandazi naming-shape forward-compat flag (Task #159) — Wave 2B kickoff.
- Anchor-category taxonomy dedicated doc (Task #160) — Wave 2B kickoff.
- BUILDING_CONTRACT.md authoring before Phase 4 starts (NICE-TO-HAVE per PR #19 architecture-reviewer).
- Wave 3A (fog-of-war data layer — world-builder) or Wave 3B (DummyAIController — ai-engineer, Task #71) per lead's call at session-5 kickoff.

**Open questions added to QUESTIONS_FOR_DESIGN.md:**
- Builder worker position during construction (inside vs outside the structure) — strategic implication for harassment-vulnerability balance. (Added at `9f94a3c`.)

**The session validates the persistent-instance architecture AND surfaces its failure modes.** Channel-discipline gaps (loremaster silent ~60min; world-builder-p3s2 summary-only response) are real and recoverable when caught quickly. Heartbeat protocol + agent-def first-class SendMessage line are the structural defenses. Persistence + lived memory remain load-bearing — fresh-spawn `-retro` agents produced substantive content that converged with persistent reflections directionally, but the lived-memory layer is irreplaceable for the friction-points that didn't make it into commits.

---

### Phase 3 session 5 — Cross-doc audit + Wave 2A.5 Atashkadeh + BUG-A retro convergence

**Date:** 2026-05-18 (cross-doc audit, PRs #21 → #24) → 2026-05-20 (Wave 2A.5 Atashkadeh, PR #28) → 2026-05-21 (session-5 close retro).
**Sync pattern:** N/A — multi-arc implementation session with close retro. Three coherent arcs: cross-doc audit (process work), Wave 2A.5 Atashkadeh (Iran Tier-1 closure 5/5), session-5 close retro (BUG-A learnings).
**Persistent agents active:** gp-sys-p3s3, world-builder-p3s2, balance-engineer-p3s3, ui-developer-p3s3, engine-architect-p3s2, shahnameh-loremaster-p3s5 (loremaster-p3s5 spawned at session-5 for Atashkadeh cultural-note work — first session with this loremaster instance carrying lived memory of a building cultural-note delivery).
**PRs (this session):** [#21](https://github.com/siavoush/shahnameh-rts/pull/21) (audit PR A — quick fixes), [#22](https://github.com/siavoush/shahnameh-rts/pull/22) (audit PR B — STUDIO_PROCESS active/history/sync-log split v2.0.0 MAJOR), [#23](https://github.com/siavoush/shahnameh-rts/pull/23) (Task #117 carry-forward — has_method guard removal + Mazra'eh/Ma'dan adjacency test), [#24](https://github.com/siavoush/shahnameh-rts/pull/24) (audit PR C — D9 pre-commit self-review checklist), [#27](https://github.com/siavoush/shahnameh-rts/pull/27) (L24 fix — AMH sibling-order + Shift modifier), [#28](https://github.com/siavoush/shahnameh-rts/pull/28) (Wave 2A.5 Atashkadeh), session-5 close retro PR (this PR).

**Wave shape:**

**Cross-doc audit (PRs #21 + #22 + #24).** User-flagged at session-4 close: *"the concern is discipline-followability, not budget."* Two-phase audit: PR #21 quick fixes (ARCHITECTURE §2 row fixes, agent-def path corrections, BUILD_LOG L24 carry-forward); PR #22 STUDIO_PROCESS v1.8.0 → v2.0.0 MAJOR (active/history/sync-log split + cluster TOC + §0.5 Session Start Checklist + §0.7 Project Glossary + 52 currently-binding rules across 14 clusters); PR #24 D9 pre-commit self-review checklist operationalized as 4-step concrete form. Test 1 (4 reviewers — 3 persistent + 1 fresh-spawn cold-read) ratified PR #22 unanimously before merge. **Test 2 hypothesis:** if D9 operationalization works, FG3-class incidents drop toward zero in Wave 2A.5.

**Wave 2A.5 — Atashkadeh (PR #28).** Iran Tier-1 closure 5/5; first sacral-emitter / divine-source anchor variant (4th and final variant in loremaster's anchor-category taxonomy). 5 commits across 4 implementation tracks + lead wave-close. **Wave-quality signal:** 0 FG3-class incidents from per-agent perspective; 6 D9 walkthroughs reported with substantive findings each; spec-wins-over-lead's-casual-reading caught at D9 Step 2 (balance-engineer max_hp = 600 retained vs lead's mis-suggested 400); Pitfall #15 trigger fires + correctly handled by world-builder (same agent who originated the canonical incident at session-4 wave 2A — pattern transfer worked). **Test 2 result: holds.**

**BUG-A — grain not deducted on Atashkadeh placement (lead live-test surface).** Atashkadeh first building with `grain_cost > 0`; `BuildingStats.grain_cost` schema field had existed since Phase 2 but `UnitState_Constructing` had no `_resolve_cost_grain` callsite. Lead's brief asserted "grain deducted at placement time in UnitState_Constructing (gp-sys's atashkadeh entry)" — claim was structurally false. Per-agent D9 walkthroughs were clean WITHIN scope; the seam BETWEEN scopes was nobody's named responsibility. Fix at `dfa9a33` (gp-sys-p3s3) added `_resolve_cost_grain` + both-or-neither affordability + parallel `change_resource(GRAIN, ...)` + 3 regression tests. User's directive at BUG-A retrospective (2026-05-20): *"in no team, ever, no where, human or AI, do we get to that goal of 'self organization' if the members of the team blindly trusts the leader. So sure, you made a mistake, won't be your last. The team should have pushed back. This should be brought to the retro and let the agents SEE this properly... DON'T give them the answer right away, let them discuss and think for themselves first on why it happened."*

**L24 fix (PR #27, lead-direct under §9.B2 carve-out).** Pre-Atashkadeh hygiene work surfaced L24 as broken via live-test. Three coordinated bugs: (a) AMH sibling-order at idx 0 fired LAST under reverse-tree-order — moved to idx 4 (highest sibling, fires FIRST); (b) AMH KEY_A had no Shift modifier check — `if not ek.shift_pressed: return` guard added; (c) Camera A/D polling bypassed event-dispatch — short-circuits on KEY_SHIFT held. ARCHITECTURE §7 L24 marked CLOSED.

**Retro inputs (5/5 substantive, all via SendMessage to persistent instances):** gp-sys-p3s3, world-builder-p3s2, balance-engineer-p3s3, ui-developer-p3s3, shahnameh-loremaster-p3s5 (heartbeat ping required after initial idle-only response; substantive reflection landed post-heartbeat). **Dispatch discipline:** zero `-retro` fresh-spawn agents this retro (corrective vs session-4 process drift; lesson internalized; saved to `feedback_retro_dispatch_via_sendmessage.md` memory file at session-4 close). **Facts-not-diagnosis dispatch discipline:** lead's retro prompts surfaced only FACTS (brief asserted X, path didn't exist, agents shipped, bug surfaced at live-test) without pre-framing the failure layer. **First empirical validation:** all 5 agents independently landed on "missing-rule failure, not existing-rule failure" with no "lead's fault" framing. Saved to `feedback_retro_facts_not_diagnosis.md` memory file.

**Strongest single retro signal:** 5-agent convergence on the **first-exercise-of-dormant-X** trigger condition. Five different vocabularies (schema-present-but-never-populated / first-non-zero-value alarm / dual-field coexistence / first-exercise-of-dormant-schema/contract-surface / first-exercise-of-dormant-schema-or-integration-or-taxonomy-slot) describing the same structural shape. Convergence emerged independently across 5 agents working from independent dispatch prompts; no agent saw another's reflection before drafting their own. The convergence-without-pre-framing is itself the artifact validating the facts-not-diagnosis dispatch discipline.

**§9 cluster shipped (2026-05-21 session-5 close, 2 new rules + 1 modification + 1 restructure + 3 watchlist additions):**
- **H3 (NEW, §9.H +1)** — First-exercise-of-dormant-schema integration verification — brief-time call-out + agent D9 self-check.
- **L6 (NEW, §9.L +1)** — Forward-compat-guard-sweep at field-default-change.
- **D9 modification** — Step 2 sub-step (brief-asserted infrastructure verb-claim grep) + Step 3 first-exercise self-check + N=3 lens-walk N/A shorthand codified.
- **J4 restructure** — Claim → mechanism → reviewer triples checklist replaces single "defer mechanical to technical" sentence.
- **J2/J3/J4 watchlist additions (3, N=1, awaiting N=3 trigger)** — Brief-time outcome trichotomy / J3 baggage-intensity annotation / Player-visible cultural-claim surfaces sub-section.

Total active rules: 52 → 54 across 14 clusters. STUDIO_PROCESS.md v2.0.0 → v2.1.0 (MINOR, additive).

**§9 cluster shipped (2026-05-18, audit PRs, retroactively logged):**
- STUDIO_PROCESS v1.8.0 → v2.0.0 (MAJOR — read-path break) at PR #22: 81 dated bullets → 52 currently-binding rules in 14 topical clusters with TOC + §0.5 Session Start Checklist + §0.7 Project Glossary. STUDIO_PROCESS_HISTORY.md (~440 lines chronological archaeology) + STUDIO_PROCESS_SYNC_LOG.md (this file, ~440 lines extracted from §10) created.
- D9 operationalized as 4-step concrete checklist at PR #24 (vs prior vague "read the contracts your changes write against as the trio reviewer would"). Mirrored to 6 implementer agent-defs as first-class "Pre-commit self-review checklist" section.

**Pitfall promotions:** None this session. Pitfall #15 already promoted at session-4; no new Godot pitfalls surfaced.

**Agent-def updates routed for retro PR:** D9 checklist mirroring already shipped at PR #24 for all 6 implementer agent-defs (gp-sys / world-builder / ui-developer / qa-engineer / balance-engineer / engine-architect). H3 first-exercise self-check + L6 forward-compat-guard-sweep + J4 triples will be added to relevant agent-defs in this retro PR.

**Carry-forwards routed to session 6:**
- Wave 2B (Tier-2 Sowari-khaneh + Tirandazi entry) — Tasks #159 + #160 still pending.
- Wave 3A (fog-of-war data layer — world-builder) or Wave 3B (DummyAIController — ai-engineer, Task #71) per lead's call at session-6 kickoff.
- BUILDING_CONTRACT.md authoring before Phase 4 starts (NICE-TO-HAVE per PR #19 architecture-reviewer).
- Anchor-category taxonomy dedicated doc (Task #160) — Wave 2B kickoff.
- 3 single-agent watchlist proposals (J2 trichotomy + J3 baggage-intensity + J4 player-visible-surfaces) — codify if N=3 trigger lands at session 6+.
- N=1 empirical-validation of facts-not-diagnosis retro discipline → memory file `feedback_retro_facts_not_diagnosis.md` carries forward; codification candidate at next session where retro discipline applies.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** None this session.

**Closing observation:** Phase 3 session 5 is the third session in a row where the persistent-instance + SendMessage architecture compounded value rather than degraded. **The user's discipline-followability concern at session-4 close motivated the cross-doc audit, which motivated the D9 operationalization, which motivated Wave 2A.5's 0-FG3 wave-quality signal, which surfaced BUG-A as the ONE remaining structural gap, which produced 5-agent convergent diagnosis of H3 + L6 + J4 refinements.** Each step's output became the next step's input. **Phase 3 ships clean with Iran Tier-1 complete (5/5).** Phase 4 entry conditions satisfied.

---

