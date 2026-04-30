# Studio Process — How the Virtual Studio Operates

*Living document. Updated after every sync retro.*
*Created: 2026-04-30*

> This process operates under the principles in [`MANIFESTO.md`](../MANIFESTO.md). When the principles and the rules below conflict, the principles win.

## 0. Purpose

This document is the operating contract for how Claude Code agents collaborate on the Shahnameh RTS project. It covers:

1. The **discussion format** — how multi-agent coordination syncs are structured.
2. The **team-lead role** — how the lead facilitates without bottlenecking.
3. The **retro practice** — how we improve this document over time.

The principle behind everything below: **a real discussion only happens when there's a specific question, a bounded scope, a forced tradeoff, and a written artifact at the end.** Without those four, agents drift into restating their priors and produce parallel monologue.

**Inspiration.** This format draws on [Open Space Technology](https://en.wikipedia.org/wiki/Open_space_technology) (Harrison Owen, 1980s) — particularly the marketplace-of-topics, parallel rooms, Law of Two Feet, and convergence/harvest gathering. Several practices below are explicit OST equivalents (parallel syncs, peer-DM self-organization, Convergence Review). Naming the lineage makes the rules grep-able for future readers.

---

## 1. When to Run a Sync

Run a multi-agent sync when **2+ specialties have overlapping authority on a decision that's expensive to retrofit.** These are "gray zones" — places where building each agent's piece in isolation guarantees rework.

**Don't run a sync when:**
- One agent owns the decision unambiguously (just have them do it)
- The decision is reversible in <1 day's work (just decide, iterate later)
- The question is a design/feel/balance call (escalate to design chat via `QUESTIONS_FOR_DESIGN.md`)
- The agents would converge on their own with a brief async exchange

A sync costs ~2.5x the agent turns of solo reviews. Use the budget for foundational decisions, not for every decision.

---

## 2. The Four Discussion Patterns

Different gray zones have different shapes. Pick the pattern that fits.

### Pattern A: Author + Reviewers
**When to use:** One agent owns the artifact; others are constrained consumers.
**Examples:** Most contracts (the `SIMULATION_CONTRACT.md` was this).
**How it runs:**
- **Round 1:** Each participant declares hard constraints + soft preferences + initial lean. No proposals yet.
- **Round 2:** Lead names tensions explicitly. Each agent posts a position with steel-manning of others. Peer DMs encouraged.
- **Round 3:** Author drafts the artifact. Reviewers sign off or list specific fixes. One bundled revision pass allowed.
- **Max rounds:** 3.

### Pattern B: Constraint Negotiation
**When to use:** 2 agents with overlapping authority. No clear "owner."
**Examples:** State Machine Contract (engine + AI), Resource Node Schema (world + gameplay).
**How it runs:**
- **Round 1:** Each posts hard constraints upfront.
- **Round 2:** Joint proposal that satisfies both. Drafted collaboratively via DMs.
- **Round 3:** Both sign off, or lead breaks ties.
- **Max rounds:** 2-3.

### Pattern C: Devil's Advocate
**When to use:** A binary decision with real tradeoffs. Risk that agents converge too quickly without surfacing real costs.
**Examples:** "Horse archers in Phase 2 vs Phase 4."
**How it runs:**
- Lead assigns one agent to argue option X, another to argue option Y. Third agent (or lead) synthesizes.
- **Round 1:** Each side argues their position.
- **Round 2:** Synthesis or decision.
- **Max rounds:** 2.

### Pattern D: Open Consultation
**When to use:** Mostly numerical/parameter decisions. Low ambiguity.
**Examples:** Difficulty tuning numbers, balance constants.
**How it runs:**
- Lead poses question. Agents respond once each. Lead decides.
- **Max rounds:** 1.

### Pattern E: Convergence Review
**When to use:** After a series of related syncs ship. Catches cross-sync inconsistencies, domain blind spots, and decisions ratified only by their authors' shadows.
**Origin:** OST's harvest/convergence gathering — the whole group reviews what was decided across the parallel rooms.
**Examples:** After Phase 0 prep syncs all ship, before Phase 0 implementation begins.
**How it runs:**
- **All relevant agents in one virtual room.** Not just the participants of any single sync — everyone whose work the consolidated decisions affect.
- **Lead posts the full reading list:** every contract, the sync log, the implementation plan. Plus the question: *"From your domain, flag any objection, blind spot, or cross-sync inconsistency. If you have nothing, say so."*
- **One message per agent.** Either "no objection from X domain" OR a numbered list of specific objections with rationale.
- **Cross-domain reactions encouraged.** Agents who see another agent's concern that affects their own work say so. Peer DMs welcome.
- **Bundled revision passes.** Lead consolidates objections, routes fixes to the relevant contract authors. One revision pass per affected contract. Original review patterns govern revisions.
- **Ratification.** Lead closes when no unresolved objections remain.
- **Max rounds:** 1 + revision passes per affected contract (typically 0-2).

**Why this works:** Decisions ratified only by sync participants miss the agents who weren't in the room but feel the consequences downstream. Convergence forces the whole team to see the whole stack.

**The trap:** if everyone says "no objection" too quickly, that's not consensus — it's bystander mode. Lead should explicitly prompt skeptical reads: *"What would break if you were wrong about your no-objection?"*

---

## 3. The Agenda Template

Every sync brief I send must contain:

1. **The question** — one sentence. *Not* "discuss X" but "should X be A or B, and why?"
2. **Why now** — what does this block?
3. **Pre-seeded options** — 2-3 plausible answers to anchor debate. Prevents bikeshedding from zero.
4. **Hard constraints declared first** — before debate, each agent says what they cannot give up. Prevents goalpost-moving mid-discussion.
5. **Cross-pollination prompts** — explicit tension questions ("AI engineer, what does engine-architect's proposal cost you in Phase 6?")
6. **Deliverable format** — markdown contract / code skeleton / decision matrix. Concrete.
7. **Exit criteria** — sign-off message from each, or lead intervenes after round limit.

If any of these are missing, the discussion will drift.

---

## 4. Cross-Pollination Enforcement (Gray-Zone Tools)

The whole point of a sync is that agents step outside their domain. Three tools the lead uses:

- **Steel-man requirement:** before disagreeing, each agent must articulate the *strongest* version of the other's concern. Prevents strawmanning.
- **"What would they worry about?" prompt:** at end of Round 1, ask each agent to predict what the *other* specialty will push back on. Surfaces blind spots.
- **Forced trade-off:** lead names the likely tension explicitly ("X wants A for testability, Y wants B for performance — resolve") rather than letting them dance around it.
- **Implementation sketch deliverable:** every contract ends with a 5-10 line code skeleton showing how each consumer uses the API. If they can't agree on the skeleton, they haven't agreed.

---

## 5. Flow Control

- **One message per agent per round.** Not threads of micro-replies.
- **Round limit enforced.** 3 rounds max for most patterns. After that, lead decides.
- **Tie-breaker rule.** If two specialists disagree past round 3, lead picks the option that minimizes downstream rework, documents the choice, and moves on.
- **Off-topic intervention.** If discussion drifts from agenda, lead pulls it back with a single message: "back to question X."
- **No broadcast spam.** Direct messages only between the agents in the sync. Agents not in the sync don't get pinged.
- **Conditional sign-off.** Reviewers can sign off "with these specific fixes" — author bundles all fixes into one revision pass and ships. Lead ratifies on reviewers' behalf if no new architectural objections arise.

---

## 6. Team-Lead Role — Servant-Leader, Not Bottleneck

The lead's job is to **enable productive discussion**, not to be a switchboard for it. Drawn from agile servant-leader principles.

### When the lead speaks

- **Round openers:** focused prompts that anchor each round.
- **Tension naming:** when two agents are talking past each other, name what they're each actually saying differently.
- **Forced trade-offs:** when agents are dancing around a real disagreement, name it.
- **Time-keeping:** gentle nudge if a round drags.
- **Checkpoint summaries:** after each round, summarize "here's what we have, here's what's open." Makes the implicit explicit.
- **Tie-breaking:** only when round limit hit. Document the rationale.

### When the lead steps back

- When two agents are productively negotiating peer-to-peer (they have `SendMessage` to each other — *encourage* this).
- When the deliverable is taking shape and revisions are happening.
- When an agent is mid-thought.
- When a reviewer is verifying a claim against the actual artifact.

### The trap to avoid

**Facilitator-as-bottleneck.** If every message routes through the lead, the discussion becomes individual reviews again — exactly what fails. The lead must trust the format and trust the agents.

### The trust principle

Agents have specialized expertise the lead does not. The lead does *not* substitute their judgment for the specialists'. The lead structures the conversation, surfaces tensions, and ratifies outcomes. Substantive technical decisions belong to the specialists.

---

## 7. Artifacts and Where They Live

| Artifact | Location | Owner | Lifecycle |
|----------|----------|-------|-----------|
| Sync contracts (e.g., `SIMULATION_CONTRACT.md`) | `docs/` | The author agent of the sync | Versioned in git. Revised via formal sync only. |
| This process doc (`STUDIO_PROCESS.md`) | `docs/` | Lead | Updated after every retro. Append-only at the bottom (Section 9). |
| Sync log | This file, §10 | Lead | One entry per sync. Append-only. |
| Open design questions | `QUESTIONS_FOR_DESIGN.md` | Any agent that surfaces one | Resolved by design chat. |

**The artifact is the file on disk. Messages are notification only.** This must be explicit when a sync produces a deliverable: "the file is the source of truth, the message just announces it's ready."

---

## 8. Retro Practice — How This Document Improves

After every sync ships, the lead writes a one-paragraph retro entry in §10 covering:

1. **What worked** — patterns that produced clarity, behaviors worth repeating.
2. **What broke or felt wrong** — moments where the format friction was high, or where the lead's role was unclear.
3. **What we'll change** — concrete additions or revisions to §1-7 of this doc.

**Then the lead actually edits §1-7.** The retro is performative without the edit. If the change is non-trivial, mark it inline with `<!-- updated YYYY-MM-DD per Sync N retro -->` so future readers see the lineage.

Retros are short. They're a forcing function for documenting the change, not a debrief.

---

## 9. Active Format Rules (Edits Made via Retros)

This section accumulates rules added/modified through retros. Each entry is dated.

- *(2026-04-30, post-Sync-1)* The artifact = the file on disk; the message = notification only. Be explicit about this in Round 3 prompts. **Why added:** in Sync 1, engine-architect first posted the contract draft in chat without committing the file. Caused a one-round-trip delay. ([Sync 1 retro](#sync-1--simulation-architecture))

- *(2026-04-30, post-Sync-1)* Conditional sign-off + bundled revision pass is the default close. Reviewers can sign off "with fixes" — author bundles them into one pass — lead ratifies without a full second review round. **Why added:** Sync 1 ratified efficiently this way. Saves a round of agent turns when the fixes are surgical, not architectural. ([Sync 1 retro](#sync-1--simulation-architecture))

- *(2026-04-30, post-Sync-1)* Some peer DMs will be opaque to the lead. Accept it. Lead reads outcomes from the artifact (file diff or sign-off summary), not from intercepting the conversation. **Why added:** in Sync 1, qa-engineer raised a fourth fix in direct DM with engine-architect; the lead only learned of it from the sign-off message. Forcing CC-to-lead would suppress freer peer discussion. Tradeoff accepted. ([Sync 1 retro](#sync-1--simulation-architecture))

- *(2026-04-30, post-Sync-2)* Length caps on artifacts are guidelines, not contracts. If all authors agree density earns the lines, the cap is waived. **Why added:** Sync 2 deliverable came in 70 lines over the 350-line target. Both authors argued density was load-bearing; compressing would damage signal. Manifesto Principle 5 (Platforms not features) supports this: foundation contracts must be thorough. ([Sync 2 retro](#sync-2--state-machine-contract))

- *(2026-04-30, post-Sync-2)* For 2-agent decisions with strong shared authority, default to Constraint Negotiation, not Author + Reviewers. **Why added:** Sync 2 ran ~50% the cost of Sync 1 with comparable artifact quality. The peer-DM drafting model surfaces resolutions neither agent would have arrived at alone (Sync 2 produced 2 such resolutions: RefCounted states, INTERRUPT_NEVER semantics). Reserve Author + Reviewers for 3+ participants or where one agent has clear ownership. ([Sync 2 retro](#sync-2--state-machine-contract))

- *(2026-04-30, mid-Sync-3-4)* Constraint Negotiation Round 1 constraints can go peer-to-peer or to lead — agent's choice. Lead doesn't need to gatekeep the constraint declaration. **Why added:** in Sync 4, world-builder posted Round 1 constraints directly to gameplay-systems. This is consistent with the OST principle that participants self-organize within rooms. The lead reads outcomes from artifacts, not by intercepting upstream messages. ([no individual sync retro yet — observed mid-flight])

- *(2026-04-30, framework expansion)* **Pattern E (Convergence Review) added** — adapted from Open Space Technology's harvest/convergence gathering. After a series of syncs ships, all affected agents review the consolidated decision log together to catch cross-sync inconsistencies and domain blind spots. **Why added:** without it, decisions get ratified only by their authors' shadows. The agents who weren't in a sync but feel its consequences need a way to surface concerns before implementation begins.

- *(2026-04-30, post-Sync-4)* **Lead must verify the actual file diff against the latest design decisions before ratifying. Trust but verify.** **Why added:** in Sync 4, both authors signed off on v1 before the design decision (Path 2 grain) had been processed in the file. The lead's "Path 2 confirmed" message and the agents' sign-off crossed in time. Lead caught it via file inspection. Without verification, the wrong version would have been ratified. Cites Manifesto Principle 1 (Truth-Seeking): observe, trace, verify — every conclusion rests on evidence, not on agents' sincere claims of state. ([Sync 4 retro](#sync-4--resource-node-schema))

- *(2026-05-01, post-foundation-work)* **Always work on a feature branch. Never commit directly to main.** Every session begins by creating a `feat/<short>` or `proto/<short>` branch (per `CLAUDE.md`). Work lands as logical commits on the branch. Merge to main happens via PR with review. **Why added:** the entire studio-foundation work (manifesto, contracts, syncs, retros) was done on `main` without a branch, requiring retroactive cleanup. The rule was already in CLAUDE.md but wasn't enforced as session-zero behavior. Lead must verify branch state before doing any work that produces an artifact. Cites Manifesto Principle 9 (Automated Enforcement): rules that aren't enforced erode.

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
- New §12 added: **SemVer policy for all contracts and the game project itself.**

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

## 11. Future Sync Templates (To Be Filled)

- **Convergence Review (Pattern E):** All 7 agents review the full decision stack before Phase 0 implementation begins. Replaces the originally proposed standalone Engine Constraints sync — engine concerns surface naturally when all agents look across the whole stack.

---

*Read this doc before facilitating a sync. Update it after every retro. The process improves only as fast as the document does.*

---

## 12. Versioning — Strict SemVer 2.0.0

Every artifact in this project (contracts, the game itself, any release) follows [SemVer 2.0.0](https://semver.org). The lead is the keeper of versions — meaning the lead is responsible for ensuring agents bump versions correctly, recording release tags, and preventing drift.

### The format

`MAJOR.MINOR.PATCH[-prerelease][+build]`

- **MAJOR** (X.0.0): breaking change — consumers must adapt. API signature change, removed feature, changed semantics.
- **MINOR** (X.Y.0): backwards-compatible addition — new functionality, new fields, new sections. Consumers can adopt at will.
- **PATCH** (X.Y.Z): backwards-compatible fix — clarification, typo, surgical correction with no behavioral change.
- **Prerelease**: `-alpha.1`, `-beta.2`, `-rc.1` for unstable / pre-release builds.
- **Build metadata**: `+sha.abc123` for build identity. Optional, ignored for precedence.

### What gets versioned

| Artifact | Versioning approach |
|----------|---------------------|
| Contract files in `docs/*.md` | SemVer in the file's status line (e.g., "Status: v1.1.0 ratified 2026-04-30"). Each ratified version bumps. |
| The game project itself | SemVer in `project.godot` config/version. Pre-MVP scheme below. |
| Releases (when shipping) | Git tags following SemVer (e.g., `v0.5.0-rc.1`, `v1.0.0`). Tags signed if the project later requires it. |

### Pre-MVP versioning scheme for the game

The game starts at `0.0.0` and walks through the implementation plan phases. **Phase number maps to MINOR version when that phase milestone ships:**

- `0.0.x` — Phase 0 in progress (foundations, contracts being implemented)
- `0.1.0` — Phase 1 milestone hit (units select, move, formation)
- `0.2.0` — Phase 2 milestone (combat triangle works)
- `0.3.0` — Phase 3 (economy + DummyAI + fog data)
- `0.4.0` — Phase 4 (full Farr system, tech tiers)
- `0.5.0` — Phase 5 (Rostam, Kaveh Event) — **Tier 0 prototype**
- `0.6.0` — Phase 6 (full AI, AI-vs-AI sim infra)
- `0.7.0` — Phase 7 (Khorasan map, fog rendering)
- `0.8.0` — Phase 8 polish — **Tier 1 vertical slice**
- `0.9.0` — Tier 2 demo (Steam page, both factions)
- `1.0.0` — **Public release** (Steam launch)

PATCH bumps within a phase track bug-fix iterations. Prerelease tags (`-alpha.N`, `-beta.N`, `-rc.N`) for testing builds.

### When to bump

For a contract:
- Author proposes the version bump in their commit message ("v1.1.0 — added section §X for new feature Y")
- Lead verifies the bump category is correct (per the rules above) before ratifying
- File status line updates with the new version

For the game project:
- Lead bumps when a Phase milestone ships (per the table)
- Bug-fix patches between milestones bump PATCH
- Test/internal builds use prerelease tags

### Strictness

- **Never reuse a version number.** Once `1.2.3` is published, `1.2.3` means that exact artifact forever.
- **Never bump MAJOR retroactively.** If you realized a minor bump was actually breaking, the next version is MAJOR — don't rewrite the past.
- **Initial version of every new contract is `1.0.0`** unless explicitly drafted as pre-release (`0.x.y`). Pre-release indicates "not yet stable enough to commit consumers to it."
- **Version state lives in the file**, not in commit messages alone. The artifact must self-identify its version.

### Retroactive normalization (one-time, 2026-04-30)

Existing contracts ratified before this policy landed are normalized:
- `docs/SIMULATION_CONTRACT.md` → 1.1.0 (was "v1.1")
- `docs/STATE_MACHINE_CONTRACT.md` → 1.0.0 (was "v1")
- `docs/TESTING_CONTRACT.md` → 1.3.0 (was "v1.3" — three patches were minor sections added, treated as MINOR for honest history)
- `docs/RESOURCE_NODE_CONTRACT.md` → 1.1.0 (was "v1.1")

Future contracts open at `1.0.0` and bump per these rules.
