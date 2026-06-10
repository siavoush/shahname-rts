---
title: Studio Process — How the Virtual Studio Operates
type: process
status: living
version: 2.3.0
owner: team
summary: Operating contract for multi-agent collaboration — currently-binding active rules + facilitation patterns + mode separation. Chronological archaeology in STUDIO_PROCESS_HISTORY.md; sync log in STUDIO_PROCESS_SYNC_LOG.md.
audience: all
read_when: every-session
prerequisites: [MANIFESTO.md]
ssot_for:
  - five discussion patterns (Author+Reviewers, Constraint Negotiation, Devil's Advocate, Open Consultation, Convergence Review)
  - servant-leader facilitator role
  - design-mode vs implementation-mode separation
  - TDD discipline for implementation mode
  - retro practice (must update this doc, not just debrief)
  - SemVer 2.0.0 versioning policy
  - active format rules (§9, currently-binding form per topical cluster)
  - frontmatter schema for project documentation
  - agent-liveness protocol (§12.6, heartbeat + three-strike escalation)
references: [MANIFESTO.md, ARCHITECTURE.md, STUDIO_PROCESS_HISTORY.md, STUDIO_PROCESS_SYNC_LOG.md]
tags: [process, syncs, retros, ssot, modes, semver, frontmatter]
created: 2026-04-30
last_updated: 2026-05-23
---

# Studio Process — How the Virtual Studio Operates

> This process operates under the principles in [`MANIFESTO.md`](../MANIFESTO.md). When the principles and the rules below conflict, the principles win.

## 0. Purpose

This document is the operating contract for how Claude Code agents collaborate on the Shahnameh RTS project. It covers:

1. The **discussion format** — how multi-agent coordination syncs are structured.
2. The **team-lead role** — how the lead facilitates without bottlenecking.
3. The **retro practice** — how we improve this document over time.

The principle behind everything below: **a real discussion only happens when there's a specific question, a bounded scope, a forced tradeoff, and a written artifact at the end.** Without those four, agents drift into restating their priors and produce parallel monologue.

**Inspiration.** This format draws on [Open Space Technology](https://en.wikipedia.org/wiki/Open_space_technology) (Harrison Owen, 1980s) — particularly the marketplace-of-topics, parallel rooms, Law of Two Feet, and convergence/harvest gathering. Several practices below are explicit OST equivalents (parallel syncs, peer-DM self-organization, Convergence Review). Naming the lineage makes the rules grep-able for future readers.

---

## 0.5 Session Start Checklist (read this if you're about to do work)

The tactical entry path for any agent starting work in a fresh session. The rest of §0 sets context; this section sets action.

1. **Verify branch** — `git status` shows you on `feat/<name>` or `proto/<name>`, NEVER `main` (per §9.D1).
2. **Read the kickoff brief** — identify which §9 cluster(s) govern your task.
3. **Skim that cluster's rules** — NOT all 50 rules; just the ones in your domain. Use the §9 cluster TOC to jump.
4. **Begin TDD cycle** per the canonical anti-loop dispatch cycle in §9.D2 (read docs → write failing tests → implement → pre-commit gate → stage your files → verify diff → commit → confirm SHA → SendMessage).
5. **Commit per §9.D4** — unconditional `git commit -- <pathspec>` form, even when you believe you're alone.
6. **Broadcast via SendMessage** per §9.G3 — assistant-text is invisible to lead; SendMessage with `to: team-lead` is the only authoritative channel.
7. **Lead-only — verify addressable name before SendMessage to a persistent instance** (per §9.G1). Check `docs/AGENT_REGISTRY.md` for the live addressable name; cross-check against the most recent `<teammate-message teammate_id="X">` block. Agent-def file names are NOT addressable names.

This is the runbook for the first 90 seconds of a session. If you remember nothing else from this document, remember these seven steps.

---

## 0.7 Project Glossary (read this if a term in §9 looked unfamiliar)

Project-shared vocabulary used throughout §9 and agent-defs. Definitions for terms a fresh-spawn agent (or you, post-context-rotation) might not recognize from the active doc alone.

- **Pitfall #N** — A Godot 4 / GDScript bug-pattern promoted to the permanent Known Pitfalls list in `docs/PROCESS_EXPERIMENTS.md`. Each entry has: mechanism, rule, canonical incident commit, regression test. Currently #1 through #15 promoted. The godot-code-reviewer's primary checklist. **Cited as "Pitfall #N" inline; see PROCESS_EXPERIMENTS.md for the full content.**
- **Deviation #N** — A measured process deviation (Experiment 01). Tracks incidents like "verification loop" or "commit race" that recurred across sessions. Each deviation has a count and a target reduction. Currently #01 (verification-loop) and #02 (commit-race-via-staging-contamination) are the canonical examples. **See `docs/PROCESS_EXPERIMENTS.md` Experiment section.**
- **Layer 1.5** — A reviewer-verdict enumeration discipline (§9.F2). When a wave introduces a new shared classification surface (SceneTree group, duck-type method, base-class field, EventBus signal), the reviewer outputs an explicit enumeration TABLE listing publishers / consumers / per-entity-type membership status. The "1.5" naming comes from the original Phase 3 session 2 retro where it was inserted between Layer 1 (structural checks) and Layer 2 (cross-cutting behavioral checks).
- **L<N>** (e.g., L1, L6, L25) — An entry in `docs/ARCHITECTURE.md §7` LATER ledger. Outstanding architectural items: deferred decisions, known gaps, open spikes. Status markers: 🟡 in-progress, ✅ resolved (with strike-through), 📋 deferred. L25 + L26 are the canonical resolved-via-Wave-1D examples; L24 is currently open.
- **Wave N<letter>** (e.g., Wave 1C, Wave 2A) — Implementation work-unit within a session. A "wave" is a coherent dispatchable scope (one building shipped, one system migrated, one bug fixed). Multiple waves per session; waves can be sequential-shared-tree or parallel-worktrees (§9.E1).
- **Track N** (e.g., Track 1, Track 2A) — A sub-component within a parallel-worktrees wave. Each track has a distinct agent owner + distinct code surface. E.g., Wave 1C had Track 1 (state machine), Track 2A (UI overlay), Track 2B (signal seam), Track 3 (navmesh spike).
- **§N.X** (e.g., §9.C1, §12.5.1) — In-doc anchor. The first digit/letter is the major section; subsequent digits/letters are subsections. §9.X are active rule clusters; §12.X are operating-mode subsections; §X.Y.Z is fine-grained.
- **Persistent instance** — An agent instance that survives across waves (Tier 2 per §12.5) or across sessions (per §12.5.1). Addressable via SendMessage by ID (e.g., `gp-sys-p3s3`, `world-builder-p3s2`). Carries lived memory.
- **Fresh-spawn** — A new agent instance with zero session memory. Used for PR-time external-audit reviewers (F1 Stage 2) and bias-check validation tests. Agent-tool spawn, not SendMessage.
- **`-pNsN-<suffix>` naming convention** — Persistent agent ID format. `p3s3` = Phase 3 session 3. Suffix optional (`-retro`, `-fix-up`, etc.). Naming convention started Phase 3 session 1; older agents may use other shapes.
- **PR #N** — GitHub pull request. The project uses PRs for all merges to main. PR numbers grow monotonically; recent ones (#14 through #22+) are project-internal references.
- **SHA `<7-char>`** (e.g., `8314a8a`, `df25033`) — Git commit hash (7-char short form). Used as canonical-incident citations throughout active rules. Resolve via `git show <SHA>` for full context.

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

## 2. The Five Discussion Patterns

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

### Dispatch judgment — SendMessage-resume vs. fresh Agent spawn (2026-05-14)

Per §12.5 and the §9 Decision-arc instance continuity rule, the lead has an additional routing responsibility in the persistent world: deciding when to **resume an existing persistent agent** vs. when to **spawn a fresh instance.** Defaults:

- **Default: `SendMessage` to existing persistent instance.** For any specialist work that derives from a prior Open Space sync the agent participated in, or that builds on prior waves the agent shipped, OR for any wave-close review by the in-team reviewer trio. Continuity is the default because lived memory of debates / prior work is load-bearing.
- **Exception: fresh `Agent` spawn.** For Tier-3 ephemeral one-shots (fix-wave / surgical bug-fix); for PR-time external-audit reviewers (where project-context-naivety is the value, per Two-class review architecture rule); when an agent's context has overflowed and must be cycled; when a role's domain shifts substantially mid-session.

The judgment is the lead's. The bias is toward continuity unless there's a specific reason to break it. Per Manifesto Principle 6 (Partnership — take care of each other across time).

**Per §12.5.1 (2026-05-17 extension):** This continuity default extends across session boundaries — persistent agents stay alive across sessions, not just within session. See §12.5.1 for the cross-session persistence rule.

**Additional lead-discipline rules from §9 2026-05-17 cluster:** distribution-discipline (ownership beats warmth at dispatch time); mid-wave rebalance discipline (explicit scenario-enumeration when reassigning task scope mid-wave); lead-takes-work-when-specialist-unresponsive carve-out (three-criteria conjunctive exception). See §9 2026-05-17 cluster for operational details.

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

## 9. Active Format Rules

This section is the **currently-binding form** of every accumulated process rule. Each rule has its current shape, its operational form, its canonical incident(s), its manifesto citations, and a pointer to the chronological archaeology in `STUDIO_PROCESS_HISTORY.md` where the rule's evolution is preserved.

**Read this section before any session.** Read `STUDIO_PROCESS_HISTORY.md` only when you want to understand why a rule has its current form, or to look up a superseded version for archaeological reasons.

### Cluster TOC — jump to the topic that matches what you're about to do

| Cluster | Topic | Rules |
|---|---|---|
| §9.A | Discussion & Sync Patterns | 4 |
| §9.B | Lead Role & Facilitation | 3 |
| §9.C | SSOT Discipline | 3 |
| §9.D | Commit & Workspace Coordination | 9 |
| §9.E | Wave-Mode & Worktree | 2 |
| §9.F | Wave-Close Review & Reviewer Architecture | 4 |
| §9.G | Agent Persistence & Dispatch Channel | 3 |
| §9.H | Cross-Cutting Verification | 3 |
| §9.I | Engine-Feature Verification | 3 |
| §9.J | Cultural / Loremaster Discipline | 4 |
| §9.K | Retro Practice | 3 |
| §9.L | Implementation Patterns | 11 |
| §9.M | Test Discipline | 6 |
| §9.N | Investigation Reports | 1 |

**Total: 61 active rules across 14 clusters.** Down from 81 dated entries in v1.8.0 — same load-bearing content, restructured to currently-binding form. (L4 split into L4a/L4b at validation-test fix-up; D9 pre-commit self-review checklist added at PR C; H3 first-exercise-of-dormant-schema + L6 forward-compat-guard-sweep + J4 claim→mechanism→reviewer-triples refinement + D9 lens-walk N/A shorthand added at session-5 close retro; L7 affordability-sweep + L8 drift-proof-UI-numeric-defaults + L9 fallback-by-failure-visibility-shape + D7 split (D7a + D7b workspace-observation) + M3 error-specificity-disclaimer + E1 parallel-WIP-addendum + F4 value-choice-footnote + G1 idle-availability-heartbeat-addendum + L1 multi-agent codification added at session-6 close retro — all with provenance notes in their respective entries.)

---

### §9.A — Discussion & Sync Patterns

#### A1. Artifact-vs-message distinction

**Rule.** The artifact = the file on disk; the message = notification only. Be explicit about this in Round 3 prompts.

**Why.** In Sync 1, engine-architect first posted the contract draft in chat without committing the file. Caused a one-round-trip delay.

**Canonical incident.** Sync 1 (2026-04-30) — Simulation Architecture contract draft posted as chat-only.

Cites Manifesto Principle 7 (Single Source of Truth — the file is the binding artifact, not the prose-in-flight).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-04-30 post-Sync-1]

#### A2. Conditional sign-off + bundled revision pass = default close

**Rule.** Reviewers can sign off "with fixes" — author bundles them into one pass — lead ratifies without a full second review round. Saves a round of agent turns when the fixes are surgical, not architectural.

**Canonical incident.** Sync 1 (2026-04-30) — ratified efficiently this way.

Cites Manifesto Principle 4 (Lean Iteration).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-04-30 post-Sync-1]

#### A3. Peer DM opacity acceptance

**Rule.** Some peer DMs will be opaque to the lead. Accept it. Lead reads outcomes from the artifact (file diff or sign-off summary), not from intercepting the conversation.

**Why.** In Sync 1, qa-engineer raised a fourth fix in direct DM with engine-architect; the lead only learned of it from the sign-off message. Forcing CC-to-lead would suppress freer peer discussion. Tradeoff accepted.

**Operational form.** Lead's information surface is artifacts (commits, diffs, SendMessage status reports) + sign-off messages, NOT peer-to-peer conversation logs. When peer agents resolve something in DM, lead learns about it when the artifact ships.

Cites Manifesto Principle 6 (Partnership — trust the partners to coordinate).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-04-30 post-Sync-1]

#### A4. Joint addenda — round-3 limit before lead intervenes

**Rule.** If a peer-to-peer negotiation bounces between options for more than 3 rounds, the lead intervenes with a tie-breaker proposal.

**Why.** The Convergence Review's joint addendum (AI gather multiplier application point) bounced between (a)/(b)/(a-modified)/(b-with-tweak)/(dual-factor) across ~7 messages before landing. The final design (dual-factor) was good — genuine design ambiguity, peer negotiation found a creative solution neither agent had pre-staged — but ~2 of those rounds were avoidable with earlier facilitator intervention.

**Canonical incident.** Convergence Review post-Phase-0 (2026-05-01) — 7-message AI-multiplier negotiation.

Cites Manifesto Principle 4 (Lean Iteration — cap unbounded back-and-forth).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 post-Convergence-Review]

---

### §9.B — Lead Role & Facilitation

#### B1. Lead verifies the actual file diff against the latest design decisions before ratifying

**Rule.** Trust but verify — after agents sign off on an artifact, the lead reads the actual file diff to confirm the artifact reflects the latest design decision, NOT a stale version drafted before the decision landed.

**Why.** In Sync 4, both authors signed off on v1 before the design decision (Path 2 grain) had been processed in the file. The lead's "Path 2 confirmed" message and the agents' sign-off crossed in time. Lead caught it via file inspection. Without verification, the wrong version would have been ratified.

**Canonical incident.** Sync 4 (2026-04-30) — Resource Node Schema sign-off crossed with Path 2 decision in time.

Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify; every conclusion rests on evidence, not on agents' sincere claims of state).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-04-30 post-Sync-4]

#### B2. Lead-takes-work-when-specialist-unresponsive carve-out (§6 extension)

**Rule.** When a specialist agent is non-responsive on a dispatched task AND the work is fully specified (no design decisions remaining) AND it blocks downstream session progress, the lead may take the work directly as an exception to ownership-lane discipline. Three criteria are **conjunctive** — all three must hold.

**Why this isn't license to override ownership.** If the work has remaining design decisions, the lead's direct execution risks "warmest-agent" anti-pattern recurrence (lead becomes the warmest agent and bypasses domain-depth). If the work isn't blocking, waiting for the specialist preserves their session continuity. If the specialist is responsive, the carve-out doesn't apply at all.

**Operational form.** Lead's commit message + retro note explicitly cites the carve-out: "Lead authored this commit as exception to ownership-lane discipline: <specialist> was non-responsive on <task> despite multiple dispatches. The doc-only, fully-specified-by-other-specialists nature of the patch made lead-direct acceptable." Visible to team for cross-session awareness.

**Canonical incident.** Phase 3 session 2 wave 1B SUGGEST-MEDIUM RNC v1.3.1 patch — gp-sys-p3s2 non-responsive after multiple dispatches; doc-only patch with content fully specified by arch-reviewer (ssot_for completeness) + engine-architect (§3.2 prose-honesty correction); lead authored directly at `98dfc18`.

Cites Manifesto Principle 6 (Partnership — partnership includes acting when a partner is unreachable, with transparency).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2]

#### B3. Lead-brief sequencing errors as a legitimate specialist review surface

**Rule.** When the lead's dispatch brief contains a sequencing error (task A blocked-by task B when it should be blocked-by task C), the specialist receiving the brief is empowered to push back via SendMessage citing the relevant discipline.

**Why.** Specialists' domain reading of the dispatch brief is a legitimate review surface; lead errors are not unfalsifiable. The persistent-instance architecture enables peer review of the lead BY the specialists — that's the partnership the architecture is built for.

**Canonical incident.** Phase 3 session 3 — engine-architect-p3s2 caught lead's Task #137 (RNC v1.4.0 commit) premature sequencing — lead had it blocked-by Phase 2A scene-edits when it should be blocked-by Phase 3 live-test gate. Engine-architect directly applied their own L25 "SSOT-prose-ahead-of-runtime-verification" discipline to lead's dispatch. Lead's response: "your discipline reading is sharper than my initial sequencing of #137." Re-sequenced #137 to be blocked-by #138.

Cites Manifesto Principle 1 (Truth-Seeking — observable error in dispatch is observable error) and Principle 6 (Partnership — peer review of the lead by the specialists is what the persistent-instance architecture enables).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3]

#### B4. Named track-modes in brief drafting — `must-ship` / `audit-only` / `verify-existing`

**Actor.** Lead at brief-drafting time + mirror-reviewer at brief-time review (verifies the track-mode declaration matches the wave's actual surface).

**Trigger.** Drafting any Track section in a wave brief that dispatches a specialist agent (balance-engineer, world-builder, loremaster, ui-developer, etc.).

**Rule.** Every Track explicitly declares its track-mode at the head of the section. Three named modes:

- **`must-ship`** — Track delivers code/data that doesn't exist canonically yet. Specialist is dispatched, produces deliverable, ships in PR.
- **`audit-only`** — Track examines existing code/data for compliance with the wave's needs; ONLY ships changes if the audit surfaces a real gap. Specialist runs the audit, broadcasts findings, ships only if needed.
- **`verify-existing`** — Track confirms existing code/data is correct for the wave's needs; ships ONLY a single-field correction if anything is wrong. Specialist runs a short grep/read; expected effort is <5 minutes. Often no dispatch needed (lead does the verify inline).

**Why.** Wave 3-BD evidence: Track 3 (balance-engineer) was initially briefed as "add max_hp entries" (`must-ship` shape). Architecture-reviewer caught that all 8 entries already existed at balance.tres lines 215, 233, 257, 307, 352, 392, 426, 464. Brief was patched v1.0.0 → v1.0.1 with Track 3 marked "OPTIONAL audit." Three steps where one would do: if the brief had declared `verify-existing` from v1.0.0, balance-engineer would have done a 30-second grep, broadcast "verified," and the round-trip cost would be near-zero.

**balance-engineer-p3s3 retro reflection 2026-05-28:** *"The most efficient Track 3 dispatches are where the brief correctly scopes 'confirm X holds; if wrong, single-field edit' rather than 'add X.'"*

**Relationship to §9.L11.** §9.L11 codifies the lead's brief-drafting balance.tres grep. The named-track-mode is the **downstream consequence** of that grep:
- If grep finds NO canonical → Track is `must-ship`.
- If grep finds canonical but the wave needs a different value → Track is `must-ship` + explicit override justification.
- If grep finds canonical matching the wave's needs → Track is `verify-existing` (lead pre-verified; backstop check).
- If the wave needs to confirm existing values hold (e.g., max_hp readable via `BalanceData.buildings[<kind>].max_hp` Dictionary lookup) → Track is `audit-only` (specialist confirms the read-path works, no edits needed unless broken).

**Operational form.** Brief Track section opens with a `**Track-mode:**` declaration:

```markdown
### Track 3 — balance-engineer

**Track-mode:** `verify-existing` — `bldg_throne` entry expected at balance.tres:213
with `max_hp = 2000.0` per Wave-3-Throne v1.0.1 (architecture-reviewer C1.3 catch).
Track confirms the entry is still present + readable via canonical Dictionary
lookup `BalanceData.buildings[&"throne"].max_hp`. If verification passes,
broadcast `[verified]` + no PR commit. If verification fails, single-field
correction + commit.
```

**Where reviewers enforce.**

- **Mirror-reviewer brief-time review** verifies every Track has a `**Track-mode:**` declaration AND the declaration matches the wave's actual surface (per the §9.L11 brief-drafting balance.tres grep result). Missing track-mode = SUGGEST → BLOCKER if scope ambiguity would cause unnecessary specialist dispatch.

**Where authors apply.**

- **Lead (brief author)** runs the §9.L11 grep first; sets track-mode based on grep result; writes the explicit declaration. The declaration is the brief's contract with the specialist: "here's what I expect you to do; here's why I think it's that scope."

Cites Manifesto Principle 4 (Lean Iteration — eliminate the 3-step round-trip when 1 step suffices) + Principle 7 (SSOT — the grep result IS the canonical source for which track-mode applies). Companion rule to §9.L11 (balance.tres grep) + §9.L11.1 (two-actor framing).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; balance-engineer-p3s3 retro reflection → lead codification]

#### B5. Tractability-probe before deferral acceptance — claimed-deferred items owe a 15-min probe OR a "what I tried" disclosure before lead accepts the deferral

**Rule.** When a track agent declares "X is deferred to follow-up wave / carry-forward / next session," the deferral acceptance requires either:
1. **"What I tried" disclosure**: 1-2 sentence summary of the investigation that led to the deferral judgment, OR
2. **Disclosure of non-investigation**: explicit "I didn't probe tractability" admission, in which case the agent owes a 15-minute tractability probe BEFORE the deferral becomes binding.

The probe outcome gets logged in the deferral note: "probed — confirmed deferral / probed — found tractable seam X / probed — unclear, deferring for now with re-check trigger Y."

**Actor.** Track agent at deferral-declaration time. Lead at deferral-acceptance time.

**Trigger.** Any of:
- Track agent commit message includes "deferred to" / "carry-forward" / "Phase X+" / "follow-up wave."
- Track agent's [ready] broadcast names an item as out-of-scope-for-this-wave.
- Brief proposes a deliverable that lands as "deferred" in the wave-close summary.

**Why (N=2 session-10 evidence):**

1. **Wave 3-Sim Step 5 (4 integration tests, fix-up-1 `a5f5f21`).** engine-architect-p3s2 initially shipped runner without 4 originally-spec'd integration tests, citing in commit message: *"the runner extends SceneTree; testing it from inside GUT requires subprocess invocation (no idiomatic in-process path). Track 3's `test_batch_runner_dry_run.gd` handles the end-to-end smoke. My focused tests cover the load-bearing surfaces without subprocess overhead."* Lead read the framing as confident-and-investigated, accepted the deferral.

   The framing was framed-as-investigated but the investigation hadn't actually found the seam. ~15 minutes later (at `a75b68d`), engine-architect went back, found the testability seam (`_test_skip_emit` + `_assemble_result_dict` extract, mirroring MatchHarness `_test_set_farr` precedent), and shipped all 27 tests. The deferral was framed-as-genuine but was actually accept-pressure-driven; the probe revealed the seam in minutes.

2. **Wave 3-Sim BLOCKER C1.2 (Path A vs Path B reasoning).** engine-architect-p3s2's path-A vs path-B analysis on the DummyIranController unit-discovery fix (counted 61 autoload references for path B; identified path A as net SHRINK) IS the canonical example of the F7 reasoning chain working as designed. This is the GOOD version: explicit cost/benefit accounting before picking. F6 (the Step 5 deferral) is the FAILURE version where the cost/benefit wasn't done.

**The "deferrals get locked in by acceptance pressure" failure mode (engine-architect-p3s2 retro framing).** A track agent reads scope pressure, frames an item as deferred with confident reasoning, and submits. Lead reads the confident framing + judges it reasonable + accepts. Now the deferred item carries lead-blessing, making it psychologically harder for the agent to revisit. The Step 5 case escaped the lock-in because explicit dispatch directive forced re-evaluation; the rule prevents the lock-in upstream by requiring evidence-of-investigation at deferral-declaration time.

**Distinguishes from `feedback_action_items_dont_defer.md` (lead memory).** That memory addresses retro action items going stale (deferred-from-retro items not getting picked up in subsequent sessions). B5 addresses deferred-from-wave items getting locked-in by acceptance pressure at wave-close. Different failure modes, sibling discipline.

**Operational form (track agent at deferral-declaration).** In commit message OR [ready] broadcast, include:

```
DEFERRAL — <item>:
  Probe outcome: [investigated 15 min — found <seam X> | investigated 15 min — confirmed truly deferred | did not probe — deferral is convenience-framed, lead may override]
  Reasoning: <1-2 sentences>
  Re-check trigger: <condition that would re-open the question, e.g., "if Track Y ships before this wave closes" / "if smoke surfaces gap"> 
```

**Operational form (lead at deferral-acceptance).** Lead reads the probe-outcome line:
- "investigated — found seam X" → genuine deferral, accept with carry-forward note.
- "investigated — confirmed deferred" → accept.
- "did not probe" → reply with explicit dispatch directive to probe OR override the deferral with lead-judgment.

**Where reviewers enforce.**

- **Lead at wave-close**: deferred items without probe-outcome line in commit/broadcast = reply requesting the probe before accepting.
- **Mirror-reviewer integration-time**: deferrals that masked actual bugs (Wave 3-Sim's "DummyIranController build-commands deferred" framing masked the C1.2 unit-discovery bug) surface as findings.

**Where authors apply.**

- **Track agents** at deferral-declaration time: write the probe-outcome line as part of the commit-message template. The line is the agent's contract with the lead about evidence-of-investigation.
- **Lead** at wave-close: scan for deferral language; verify each has a probe-outcome line; reply with directive if missing.

**Anti-patterns to flag.**

- "Deferred for scope-control" (no probe) — convenience framing; demand the probe.
- "Deferred to follow-up wave" (no probe + no re-check trigger) — locks in indefinitely; demand the trigger condition.
- "I considered it but it seemed hard" — that's "didn't probe"; demand the actual 15-min investigation.
- "Other agents are blocked on something else; I'll defer this" — different failure mode (blocking), not a deferral; surface the actual blocker explicitly.

Cites Manifesto Principle 1 (Truth-Seeking — investigated-and-deferred is honest; presumed-and-deferred is not) + Principle 6 (Honest-tools-not-magic-tricks — "deferral framing as a magic trick that papers over not-investigating") + Principle 10 (Feedback Cycle — the probe IS the feedback before commitment, not after).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; engine-architect-p3s2 retro reflection (drafted rule + Step 5 self-flag as evidence) → lead codification. Sister discipline to `feedback_action_items_dont_defer.md` memory (covers retro action-item deferral); together they cover both upstream + downstream deferral-lock-in failure modes.]

---

### §9.C — SSOT Discipline

#### C1. SSOT canonical — one fact, one file, BLOCKING at review, re-verify against current shipped state

Each project fact has exactly one canonical home. Other files reference, never restate. When writing or editing markdown, ask: *"if this fact changes, how many files would I need to update?"* If the answer is more than one, refactor: pick a single owner, replace duplicates with links or one-line summaries pointing at the owner. Indexes and orientation summaries are allowed only if (a) clearly framed as "see X for full content" AND (b) cannot drift independently — a change to X cannot leave the summary stale.

**Cross-link mechanism (operationalization).** When a fact lives in one contract canonically and is mentioned in another (e.g., FarrSystem storage scale in both Sim Contract §1.6 and FarrConfig.gd comment), the duplicate MUST be a "see X" pointer with explicit link to the SSOT. The link is the binding.

**Wave-close + re-review enforcement (BLOCKING, not LATER).** When a reviewer finds that two SSOT-tagged docs (or a doc and a project header / regression test) contradict each other on the same fact, the reviewer MUST resolve it empirically (probe test, read engine source, ask lead) BEFORE approving the wave. Deferring the contradiction to a LATER index entry is INSUFFICIENT and DOES NOT meet the bar. Architecture-reviewer's own retro framing at the canonical incident: *"I had the evidence in hand and deferred. That was a discipline failure, not a scope failure."*

**Retroactive-staleness re-verify rule.** For every contract review pass (wave-close, re-review, fix-up close), re-verify prose against current `git show HEAD` shipped code for every fact the prose claims. The authoring-time correctness verdict is NOT inherited by later passes; shipped state can shift between authoring and review, making the authored prose retroactively stale.

**Canonical incidents:**
- **Original (2026-05-01):** post-Phase-0 cleanup audit. Created `ARCHITECTURE.md` by duplicating the directory map and agent table from `02_IMPLEMENTATION_PLAN.md`. Silent contradictions emerged within a few revision cycles. Refactored to "see X" pointers.
- **BLOCKING refinement (2026-05-14):** Phase 3 session 1 BUG-10 (Godot `_unhandled_input` sibling-order reversal). PROCESS_EXPERIMENTS.md Pitfall #5 prose said "reverse-tree-order"; `attack_move_handler.gd` header said the opposite. Architecture-reviewer flagged the contradiction as future LATER L22 instead of resolving it empirically before approval. Live-test caught it.
- **Retroactive-staleness (2026-05-17 session-2):** Phase 3 session 2 wave 1B BLOCK-C. RNC v1.2.2 §4.5's `is_gatherable = true` example was correct at v1.2.2 authoring (against shipped state from `6d73889`); world-builder's `3183c7c` subsequently flipped shipped state to `is_gatherable = false`; v1.2.2 prose went stale ~30 minutes after authoring. Arch-reviewer caught the retroactive staleness at re-review.

Cites Manifesto Principle 1 (Truth-Seeking — verify, don't trust prior verification) and Principle 7 (Single Source of Truth — reference the source rather than copying it).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 post-cleanup-audit + 2026-05-01 post-Phase-0 + 2026-05-14 post-Phase-3-session-1 + 2026-05-17 session-2]

#### C2. Doc frontmatter discipline — every project markdown carries YAML frontmatter per the schema

*Specialization of C1 — frontmatter is how facts become machine-greppable to their canonical owner.*

**Rule.** Every project markdown doc carries YAML frontmatter per the schema below. New docs ship with frontmatter from creation. Existing docs without frontmatter are added on first edit. The frontmatter is the doc's machine-readable contract; the body is the human-readable content. The frontmatter is the SSOT for: title, type, status, version, owner, audience, read_when, prerequisites, references, ssot_for, tags. Any of those facts appearing in the body without a frontmatter source is a SSOT violation.

**Why.** Without frontmatter, an agent scanning N docs has to ingest each one to decide if it's relevant, drifting attention and filling context with noise. The schema lets an agent make a read/skip decision in <30 lines. The `ssot_for` field directly operationalizes the SSOT discipline rule (C1) — facts become machine-greppable to their canonical owner.

**The schema:**

```yaml
---
# REQUIRED — every doc
title: Human-readable title
type: contract | process | spec | plan | log | research | architecture | manifesto | exploration
status: draft | ratified | living | stable | append-only | superseded | experimental
summary: One-sentence elevator pitch — what this is and why it exists.
audience: all | <comma-separated agent names>
read_when: every-session | implementation-mode | design-mode | phase-<N> | working-on-<topic>

# REQUIRED for versioned docs (contracts, plans, process docs)
version: 1.2.0           # SemVer per §13
owner: <agent-name> | "design-chat" | "team" | "siavoush"

# RECOMMENDED — fills the orientation gap
ssot_for:                # facts THIS doc canonically owns
  - <facts>
prerequisites:           # read these first
  - <other docs>
references:              # other docs this points at
  - <other docs>

# LIFECYCLE
created: YYYY-MM-DD
last_updated: YYYY-MM-DD

# OPTIONAL
tags: [topic, topic, topic]
superseded_by: null      # path to replacement if deprecated
phase: [0, 1]            # which phase(s) this concerns
provenance: <free text>  # how/when/where this came from, if useful
---
```

**`read_when` taxonomy is intentionally loose for now.** Constrain it later if values proliferate inconsistently. **`.claude/agents/*.md`** files keep their existing Claude Code agent schema (name, description, model, tools) and do *not* take this frontmatter — different consumer (the CC harness), different schema, no dual-frontmatter mess. **A lint validator for the schema is deferred** per Manifesto Principle 4 (Lean Iteration) — we'll build it after a few revision cycles produce real signal on which fields drift and need automated checks.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 frontmatter-rollout]

#### C3. Code citation SSOT — kickoff docs are NOT permissible code citations

*Specialization of C1 for code/test header citations — the broken-pointer failure mode has its own grep-pattern enforcement.*

**Rule.** Code header citations and test header citations must reference **only** permanent on-disk SSOT sources.

**Permitted citation targets:**
- `01_CORE_MECHANICS.md §X` (the spec — permanent)
- `00_SHAHNAMEH_RESEARCH.md §X` (research — permanent)
- `DECISIONS.md` entries (append-only permanent)
- `docs/ARCHITECTURE.md §6 vX.Y.Z` (wave-close entries — permanent, versioned)
- `docs/<X>_CONTRACT.md §X` (engineering contracts — permanent, versioned)
- Prior `.gd` file headers when citing a sibling pattern (the file is the authority)

**Forbidden citation targets:**
- `02h_*KICKOFF.md`, `02f_*KICKOFF.md`, or any `02X_*KICKOFF.md` (ephemeral; deleted post-wave or post-session)
- Sync logs, retro briefs, in-flight Linear ticket IDs

**Pre-commit check.** Before merging a new subclass commit, grep the new file's header + test header for any `02[a-z]_.*KICKOFF` pattern. If hit, replace with on-disk equivalent before commit.

**Scope statement.** Rule applies to ALL files committed under `game/` — `.gd`, `.gd`-test, `.tscn`, shader headers, BalanceData entries.

**Why.** Citation pointing at a deleted file is a broken SSOT pointer; the code outlives the kickoff doc by months/years.

**Canonical incident.** Wave 2A `sarbaz_khaneh.gd:7` + `test_sarbaz_khaneh.gd:3` initially cited `02h_PHASE_3_SESSION_4_KICKOFF.md`; fixed at `128af9f` to point at `01_CORE_MECHANICS.md §5 + docs/ARCHITECTURE.md §6 v0.24.0`. World-builder's parallel .tscn cleanup (`07c6ca8`) confirmed the rule extends to scene-file comments.

Cites Manifesto Principle 7 (Single Source of Truth) + the "setting is load-bearing; keep it visible in the code's bones" principle (per CLAUDE.md).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4]

---

### §9.D — Commit & Workspace Coordination

#### D1. Always work on a feature branch; never commit directly to main

**Rule.** Every session begins by creating a `feat/<short>` or `proto/<short>` branch (per `CLAUDE.md`). Work lands as logical commits on the branch. Merge to main happens via PR with review.

**Why.** The entire studio-foundation work (manifesto, contracts, syncs, retros) was originally done on `main` without a branch, requiring retroactive cleanup. The rule was already in CLAUDE.md but wasn't enforced as session-zero behavior. Lead must verify branch state before doing any work that produces an artifact.

Cites Manifesto Principle 9 (Automated Enforcement — rules that aren't enforced erode).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 post-foundation-work]

#### D2. Anti-loop dispatch cycle — every agent brief includes the explicit commit-discipline cycle

**Rule.** Every agent dispatch brief (and any kickoff doc that describes per-deliverable workflow) MUST include the cycle verbatim, in the brief's "Workflow" section:

```
### Workflow (anti-loop)
1. Read the relevant docs.
2. Write failing tests first (TDD red).
3. Implement.
4. Pre-commit gate (lint + GUT) must pass.
5. Stage your files explicitly: `git add` per file.
6. Run `git diff --staged --stat` — verify ONLY your files.
7. Verify `git diff BUILD_LOG.md docs/ARCHITECTURE.md` shows ONLY your additions.
8. Commit (with the pathspec form from D4). Title: descriptive per project convention.
9. Run `git log -1 --oneline` — confirm your SHA at HEAD.
10. THEN report back via SendMessage.
```

**This is the canonical commit cycle referenced from every other commit-discipline rule.** When other rules say "re-run the canonical staging discipline" they refer to steps 4-9 of this cycle.

**Why.** The verification-loop pattern (Deviation 01) — agents reading their own work in the working tree as "shipped by another agent" and standing down without committing — hit FIVE TIMES in Phase 2 session 1 alone. The four agents who broke the pattern at end-of-session all had this exact language baked into their brief. The language is observably load-bearing.

**Permanent (Experiment 03 graduated 2026-05-12).** Verification-loop occurrences dropped from 2+ to 0 across Phase 2 session 2; lead-proxy commits dropped from 3 to 0. The cycle is observably load-bearing for sequential single-agent dispatches.

Cites Manifesto Principle 9 (Automated Enforcement — rules that aren't enforced erode; the discipline must be in the brief, not in folklore).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-04 + 2026-05-12 graduation]

#### D3. Per-TDD-cycle commits, not end-of-wave batches

**Rule.** Each agent commits IMMEDIATELY after each `red → green → refactor` cycle (one new test + implementation pair = one commit), NOT at end-of-wave. The end-of-wave coordination commit, if any, is docs-only.

**Why.** Phase 2 session 1's `aa429ef` commit-race (Deviation 02) was caused by three agents each holding ~10 file modifications uncommitted in the shared working tree at end-of-wave; one agent's `git add` swept the others' files into a misattributed commit. Per-TDD commits keep each agent's working set small; cross-agent contamination becomes mathematically harder.

**Permanent (Experiment 03 graduated 2026-05-12) for sequential single-agent waves.**

**Note on parallel waves.** Per-TDD discipline did NOT suppress Pitfall #7 commit-race in Phase 2 session 2's parallel-3 wave (`cac29cc` swept TuranKamandar; `3fefeea` swept TuranSavar). For parallel waves, the worktree-per-agent rule (E1) is the structural fix; per-TDD discipline alone is insufficient.

Cites Manifesto Principle 9 (Automated Enforcement).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-04 + 2026-05-12 graduation]

#### D4. Unconditional `git commit -- <pathspec>` form for every commit

**Rule.** Every `git commit` uses `git commit -m "..." -- <named-file-list>` form regardless of whether the committer believes they're the only active committer. The "I'm alone right now" assumption was empirically wrong multiple times.

**Why.** The defensive form is now the canonical default, not an opt-in defense. The pathspec is a **structural** lock; the index `--stat` verification step is *observer-dependent* and momentum-defeatable.

**Operational form (subsumes the prior "shared docs git diff verified" rule).** Before staging any shared doc file (`BUILD_LOG.md`, `ARCHITECTURE.md`, etc.), run `git diff <doc-file>` and confirm the diff contains ONLY your additions. The pathspec form on commit is the structural backstop if the diff verification missed anything.

**Canonical incidents (three Pitfall #7 occurrences across phases 2-3):**
- Wave-1A `61d891f` and wave-1B `1e8a213` (Phase 3 session 2) — committer read the stat correctly and committed anyway without pathspec ringfencing.
- Phase 2 session 2's `cac29cc` + `3fefeea` — parallel-3 wave swept TuranKamandar / TuranSavar into wrong commits.

World-builder's wave-1B retro self-diagnosis: *"I read the stat correctly and committed anyway without pathspec ringfencing. The pathspec form is a physical lock, not just a verification step."*

Cites Manifesto Principle 9 (Automated Enforcement).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-04 + 2026-05-17 session-2]

#### D5. Stash-on-pre-commit-block — clean recovery when the hook fires

**Rule.** When the pre-commit hook blocks, `git stash` immediately. Leaving staged state in the working tree creates the contamination surface for the next agent's commit. The blocked committer's verification cycle (`git diff --staged --stat` twice + pathspec form) doesn't help if a parallel agent commits before the block clears — their commit pulls in the still-staged files. Stash closes the race window from the blocked-committer's side.

**Operational sequence:**
1. Pre-commit hook fails.
2. Verify the failure is in someone else's WIP (not your own logic): `bash tools/lint_simulation.sh` + targeted test rerun on your files only.
3. `git stash push --staged -m "WIP-<wave>-<task>-blocked-on-<otheragent>"`.
4. Wait for the unblocking commit to land (poll `git log -1 --oneline` periodically; or DM the other agent for ETA).
5. `git stash pop`.
6. Re-run the dispatch cycle from D2 (steps 4-9); commit cleanly with D4 pathspec form.

**Canonical incident.** Phase 3 session 2 wave 1B Commit 4 (gp-sys-p3s2) — first operational instance of the stash-on-block pattern (clean recovery + no contamination).

Cites Manifesto Principle 1 (Truth-Seeking — observe the race, don't deny it).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2]

#### D6. Broadcast `[blocked]` to lead via SendMessage when pre-commit hook fires

**Mechanism (vocabulary).** "Broadcast" in this rule = **SendMessage with `to: team-lead`** (per channel-discipline G3). Not all-team-DM, not assistant-text, not a status-marker on a Task. SendMessage to lead is the authoritative channel.

**Rule.** When the pre-commit hook blocks (regardless of cause), the blocked agent immediately sends `to: team-lead, summary: "[blocked] on <reason>", message: "..."`. The block is otherwise invisible to lead until the next commit attempt races. The `[blocked]` SendMessage produces a visible artifact in lead's inbox; lead can serialize commits across agents when needed.

**Why.** Closes the asymmetric-discipline gap that single-agent staging discipline cannot close on its own.

**See also: M3.** D6 says WHEN to broadcast `[blocked]` (after the hook actually fires). M3 says NOT to broadcast speculatively on out-of-hook test output (the hook is the authoritative gate). The canonical incident in M3 (Wave 2A PR #19 — world-builder's "33/34 farr_gauge" false-positive pre-block) is the canonical example of D6 triggered incorrectly. Both rules together: only broadcast `[blocked]` after the hook fires, never on speculative out-of-hook signal.

**Operational corollary (local-safety-vs-pipeline-integrity tension).** When an agent's commit is at risk from race contamination (parallel work mutating shared scope), the temptation to "land before another race buries it" is a LOCAL OPTIMIZATION that the wave-mode rule (E1) explicitly forbids. The right move is to broadcast `[blocked]` and request explicit unblock from lead, NOT to ship out of order. The sequencing rule exists precisely to prevent agents making those local calls unilaterally.

**Canonical incident.** Arch-reviewer-p3s2 proposed the rule at wave-1A retro; gp-sys-p3s2's wave-1B Commit 4 stash-on-block was the first operational instance, validating the discipline. Wave 1C L23 violation by world-builder-p3s2 (`90d39bd`) — shipped Phase 2A scene edits before Tracks 1+2 closed despite the park directive, justified locally as "land before another race buries it"; corrected and rolled into the rule.

Cites Manifesto Principle 6 (Partnership — coordinate explicitly across the team) + Principle 8 (Separation of Concerns — sequencing is a coordination property, not a per-agent property).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2 + 2026-05-17 session-3]

#### D7. No-silent-coexistence with cross-track WIP — two complementary triggers

*Parent rule: "no silent coexistence with cross-track WIP in your working tree." Two trigger conditions, both require SendMessage broadcast to lead BEFORE acting.*

##### D7(a). Broadcast-before-stash — any stash touching another agent's WIP requires explicit notification

**Rule.** Before ANY `git stash push -u` (or scoped `git stash push -- <files>` that touches files modified by another agent in the current wave), the stashing agent MUST broadcast `[stashing: <files>]` to lead via SendMessage so affected parallel agents know their working-tree state is parked, not lost. Non-optional even when the stash feels local and you intend to restore immediately.

**Operational corollary (inter-agent stash visibility).** Multi-agent git operations create reflog + stash state opaque to participating agents. When multiple agents run parallel git operations (especially stash + reset), the resulting reflog + stash entries can be misread by ALL participants including the lead. Documentation of stash purpose + cross-references in commit messages + explicit stash titles (`git stash push -m "<descriptive>"`) become load-bearing. When investigating multi-agent git incidents, read `git stash list --date=iso` + `git reflog --date=iso` together, never one in isolation.

**Canonical incident.** Wave-1C workspace incident (2026-05-17 ~10:35-10:38) — world-builder-p3s2 stashed parallel agents' WIP without broadcast as part of `90d39bd` prep. From ui-developer-p3s3's view, their working-tree state vanished unexpectedly; they correctly stopped-and-reported but lost ~30 minutes to diagnostic confusion. The system-reminder telling them the change was "intentional" was actively misleading. Lead's forensic-narrative initially misread `reset: moving to HEAD` reflog entry as a destructive `git reset --hard` when it was `git stash push`'s internal mechanism — apologized + withdrew accusation.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3]

##### D7(b). Broadcast-on-observe-cross-track-WIP — observing without acting still requires explicit notification (NEW session-6)

**Rule.** When you observe modified-unstaged files in your working tree that are NOT in your own track scope, broadcast the observation to lead via SendMessage **BEFORE proceeding with any action that interacts with shared infrastructure** (commit attempt, test run, stash). Surface what you see; let lead route. Do NOT:
- Stash the cross-track files (would destroy their owner's WIP — D7(a) covers this from the action side).
- Revert them.
- Message the file's owner directly (cross-agent coordination routes through lead per §9.G2).
- Silently assume the coexistence is intentional or by design.

**Refinement — descriptive not interpretive (world-builder-p3s2 contribution).** The broadcast should state **WHAT YOU OBSERVE**, NOT YOUR DIAGNOSIS:
- ✅ *"I see `build_menu.gd` modified-unstaged in my working tree by another agent; nodes referenced in @onready not yet staged."*
- ❌ *"I think ui-developer's Track 4 isn't landed yet."*

The agent may not know which track owns which file. Broadcast-what-you-observe keeps the broadcast accurate under uncertainty; broadcast-your-diagnosis compounds one misattribution with another.

**Canonical incidents (N=2 in Wave 2B alone):**
- **Wave 2B Track 2** — world-builder-p3s2 observed ui-developer's pre-commit @onready refs in working tree before Track 4 staged the matched .tscn nodes. Misattributed initial diagnosis as a build_menu.gd parse error; recovered via lead's correction at retro framing.
- **Wave 2B BUG-B1 fix-wave** — ui-developer-p3s3 observed gp-sys's modified-unstaged test (expecting new 3-arg signal signature) in working tree while gp-sys's BUG-B2 was still in flight. Applied D7(a) discipline (no stash, no revert) + correctly held until gp-sys's commit landed.

ui-developer-p3s3's framing at session-6 retro: *"The cost of a 30-second routing broadcast is much lower than the cost of acting on a wrong assumption about another agent's WIP."*

**Cost ROI observation.** Recovery after blocker resolution (gp-sys's BUG-B2 ship) was literally `git pull && retry commit` — 30 seconds. The discipline cost was wall-clock wait, not work-redo. Sequential coordination expensive in latency; not expensive in actual work.

Cites Manifesto Principle 1 (Truth-Seeking — observe, don't diagnose) + Principle 6 (Partnership — coordinate explicitly).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 (D7a) + 2026-05-22 session-6 close (D7b)]

#### D8. Verify git tree at session close — not just lint + tests

**Rule.** After an agent reports "shipped X," the lead runs `git ls-tree HEAD -- <expected paths>` to verify the files are actually in version control. Lint and tests pass locally because they read from disk; if the agent forgot to `git add` new files (especially in new directories), the commit ships with only the existing modifications and the new files remain untracked.

**Why.** The merged branch silently loses untracked files. Local tests pass because Godot reads from the working tree, not the index.

**Canonical incident.** Phase 1 wave 2 — `game/data/balance.tres` (and 6 sub-resources + balance_data.gd) was authored by balance-engineer in Phase 0 commit `81ed6e5` but never staged. The commit shipped with only doc updates; the data files lived on disk uncommitted through Phase 0 merge to main and into Phase 1 work. Recovered as part of `a82e0ac`.

**Related sub-rule (pre-commit gate filter for parallel agents).** Pre-commit hook must filter to tracked files when N agents run in parallel — otherwise the hook races on staged-vs-untracked test files from concurrent agents. Mitigation: `git diff --cached --name-only` filter on the lint and GUT scope. Documented Phase 0 session 4 wave 1; observed flakiness with 4 parallel agents.

Cites Manifesto Principle 1 (Truth-Seeking — the index is the binding state).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 post-Phase-0 + post-Phase-1-wave-2]

#### D9. Pre-commit self-review checklist — read your own contract delta as the trio reviewer would, BEFORE the pre-commit hook fires

**Rule.** Before any wave-close commit on files you own, execute this checklist. The cost is 5-10 minutes; the savings is one fix-up wave cycle. **This is the operational form of the rule the audit's FG3 finding flagged as too-vague.** The original prose ("read the contracts your changes write against as the trio reviewer would") existed since session-2 close but had two failures in Wave 2A alone — the rule was known, not followed. The checklist below is the concrete form designed to actually be executable at commit time.

**Step 1 — List your contract surfaces (1 minute).** Which contract docs does your commit touch? Run `git diff --name-only HEAD~N..HEAD docs/ 01_CORE_MECHANICS.md` and enumerate the affected files + sections. Common surfaces: `docs/<X>_CONTRACT.md §<N>`, `01_CORE_MECHANICS.md §<N>`, `docs/ARCHITECTURE.md §2/§6/§7`, `MANIFESTO.md`.

**Step 2 — Read each contract section at its current `HEAD` (3-5 minutes).** NOT the version you remember; the version on disk RIGHT NOW. `git show HEAD:docs/<X>_CONTRACT.md` if you want a clean read. The retroactive-staleness failure mode (C1) is real — shipped state can shift between authoring and your commit.

**Step 2 sub-step — brief-asserted infrastructure verification (added session-5 close, BUG-A canonical).** If your dispatch brief contains a **verb-claim** about a downstream consumer file ("grain deducted at placement time in UnitState_Constructing", "X registered with Y", "Z fires when W happens") — meaning the brief asserts a piece of code or wiring exists in another agent's scope that your work consumes — `grep` the named consumer file for the verb's implementation BEFORE consuming the claim. If the path doesn't exist at HEAD, escalate before commit. Brief-claims about already-shipped state are reviewable like contract sections; the grep takes seconds and catches first-exercise gaps (H3) the brief author may not have verified. Pattern: brief sentence uses passive voice about a downstream effect → grep the verb's actor file before trusting the sentence.

**Step 3 — Apply the three reviewer lenses to your own commit (3-5 minutes).** Self-execute each role's question:
- **godot-code-reviewer lens:** does this code avoid the [Known Pitfalls list](../docs/PROCESS_EXPERIMENTS.md)? Does it pass behavioral-vs-structural test discipline (F3)? Pitfall #14 mitigations applied if lambda captures? Pitfall #15 regression test mandatory if inherited-scene with nested override (F4)?
- **architecture-reviewer lens:** does this fit the target architecture? Does the prose match shipped state (C1 SSOT canonical)? Are SSOT contradictions resolved empirically NOT deferred to LATER (C1 BLOCKING refinement)? Cross-cutting schema verification triangulated if new shared classification surface (H1)? **First-exercise-of-dormant-schema / dormant-integration / dormant-taxonomy-slot (H3) — does my work first-populate a previously-dormant surface? If yes, what cross-track verification did I do?**
- **shahnameh-loremaster lens (if cultural surface):** does the framing match the anchor-category template (J2)? Persian-term gloss accurate per literal-then-tricky-gloss (J3)? Intent-vs-implementation split honest if claim depends on mechanical behavior (J4 — and if so, are mechanical dependencies enumerated as claim→mechanism→reviewer triples)?

**Step 3 — Lens-walk N/A shorthand (codified session-5 close, N=3 met).** A lens that genuinely does not apply to your commit may be marked `<Lens>: N/A — <one-line reason>` instead of boilerplate-prose-walking it. Distinguishes "lens walked, no finding" (a substantive walk produced no finding) from "lens not applicable" (the commit type doesn't touch this lens at all) — two epistemically different states that boilerplate previously conflated. **Trigger:** if walking the lens would produce only "no relevant code touched" or similar tautological prose, use N/A form. If you find ANYTHING worth noting (even a no-finding observation about adjacent risk), use the prose form. N=3 met by: gp-sys-p3s3 Task #117 carry-forward + loremaster-p3s5 session-5 wave-2A.5 reflection + Task #166 explicit watchlist entry → graduated to active at session-5 close.

**Step 4 — Surface gaps BEFORE the trio review fires (1-2 minutes per gap).** For each gap surfaced, file a `QUESTIONS_FOR_DESIGN.md` entry (for design decisions) OR ship a pre-emptive fix-up commit (for SSOT corrections). **Not after.** The trio reviewer catching your gap means you've already failed this rule.

**Trigger condition.** Mandatory before EVERY wave-close commit on files you own. NOT optional based on commit size, NOT optional based on confidence level, NOT optional based on "I'm pretty sure this is clean." The hook for "is this clean?" is this checklist, NOT your self-assessment.

**Time budget.** 7-12 minutes per wave-close commit. If it takes longer, your commit is probably too large; split it.

**Followability mechanism.** This rule lives in each implementer's agent-def (gp-sys / world-builder / ui-developer / qa-engineer / balance-engineer / engine-architect) as a "Pre-commit self-review checklist" first-class section — so agents read it at every dispatch, not just at session start (the original FG3 failure mode was "agents don't re-read §9 each wave").

**Canonical incidents.**
- **Original (session-2, world-builder `91f48ad`):** caught own contract gaps pre-trio-review — `§1.4/§3.4` corrections to RNC. 5-10 minute pre-emptive read saved a fix-up wave cycle. Rule born.
- **FG3 failure modes (session-4 wave-2A):** TWO violations of the (then-vague) rule in one wave: (a) `sarbaz_khaneh.gd:7` + `test_sarbaz_khaneh.gd:3` cited `02h_PHASE_3_SESSION_4_KICKOFF.md` — would have been caught by step 2 (read citation targets at HEAD); (b) `sarbaz_khaneh.tscn` `1ff3039` shipped with Pitfall #15 silent-override syntax — would have been caught by step 3 godot-code-reviewer lens applied. Both surfaced at PR review; both should have been caught pre-commit by the implementer.
- **BUG-A first-exercise-of-dormant-schema (session-5 wave-2A.5):** the per-agent D9s were ALL clean within scope (every implementer ran D9, reported substantive findings each — 6 D9 walkthroughs total). The seam BETWEEN scopes — the brief's verb-claim "grain deducted at placement time in UnitState_Constructing" — was nobody's named D9 surface. The grain-deduction path didn't exist at HEAD. Five-agent retro converged independently: Step 2 brief-asserted-infrastructure verification sub-step + Step 3 first-exercise-of-dormant-schema self-check (H3) added to close this gap-class. **Not a D9-was-followed-and-failed instance; a D9-coverage-gap instance.** D9 covers WITHIN-SCOPE; H3 + Step 2 sub-step cover BRIEF-ASSERTED-INFRASTRUCTURE-ACROSS-SCOPES.

Cites Manifesto Principle 1 (Truth-Seeking — verify your own work before others have to) + Principle 9 (Automated Enforcement — discipline in agent-def at every-dispatch read-cadence > discipline in §9 at session-start read-cadence).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2 pre-commit-self-review (original prose); operationalized to checklist 2026-05-18 PR C; Step 2 sub-step + Step 3 first-exercise self-check + lens-walk N/A shorthand added 2026-05-21 session-5 close]

#### D10. Cross-track first-consumer diagnostic — broadcast non-self failures

**Actor:** Implementer staging a track's changes for joint or sequenced commit. Most commonly the first downstream consumer of a new producer surface.

**Trigger:** After staging own-track changes locally, before joint-commit or [ready] broadcast. The full headless test suite is run; the implementer parses the results.

**Rule:** When the post-staging full-suite run shows failures in surfaces NOT owned by the implementer's track, **the implementer MUST broadcast a diagnosis to the owning track's implementer (or to lead for lead-side surfaces) before proceeding to commit**. Non-self failures are signal, not noise — they indicate that the implementer's track is the first runtime witness of a producer-side contract bug.

This rule formalizes the structural property: producer surfaces are written with assumed-correct invariants; consumer surfaces are written with assumed-correct producer behavior. Bugs accumulate at the boundary as mismatched assumptions. Static type-checking equates types only; semantic invariants (is_instance_valid before cast, dict-key vs field-name, signal payload shape, tick-context) are not type-equated. **The first runtime consumer is the first witness to producer-side invariant bugs.**

The rule applies regardless of who is "the gating track" — a downstream-consumer implementer running the suite after the producer-track's stage is the canonical execution point. When the consumer IS the gating track (shipping first), they can't benefit from this discipline by definition; in that case §9.L10 / §9.L12 (canonical-pattern grep) is the upstream complement.

**Why (N=4 successful applications + 1 missed-opportunity exhibit):**

1. **Wave 3A.5 — gp-sys catches world-builder's `as Node3D` cast bug.** Staging unit.gd Track 2 (FogSystem vision-source register/deregister), gp-sys ran the full suite and observed a failure in `test_fog_system.gd:test_fog_update_stale_source_cleanup`. Root cause was world-builder's Track 1 `_on_fog_update_phase` casting `rec[&"node"] as Node3D` BEFORE checking `is_instance_valid()`, causing a script error on freed Object before reaching the lazy-cleanup branch. gp-sys broadcast diagnosis + suggested fix to world-builder before commit. Fix folded into Track 1's first commit. **Bug never shipped.**

2. **Wave 3A.6 — gp-sys catches ui-developer's ProductionPanel `close_clears_rows` failure.** Staging Track 1 (Building production state machine), gp-sys observed a failure in `test_production_panel.gd:test_close_clears_rows` (UnitRows children count expected 0, got 1). Not in gp-sys's surface but visible from suite run. Broadcast to ui-developer at [ready] time. Fix landed before Track 2 ship. **Bug never shipped.**

3. **Wave 3A.5 — mirror-reviewer catches FogSystem.sim_phase wiring bug (BUG-D1).** Mirror-reviewer running brief-time review caught that fog_system.gd was wiring to `SimClock.fog_update.connect(...)` instead of `EventBus.sim_phase.connect(...)` per canonical pattern. First-runtime-consumer here was the brief-reviewer rather than an implementer; same shape, different actor. Lead fixed in dedicated BUG-D1 fix-wave commit.

4. **Wave 3A.5 — ai-engineer catches FogSystem team-id bounds bug (BUG-D2).** First runtime consumer of `FogSystem.is_visible_to(TEAM_TURAN, ...)` at TuranController scaffold time. team_id=2 was out of bounds vs hardcoded NUM_TEAMS=2 (TEAM_IRAN=1, TEAM_TURAN=2 — exclusive bound rejects valid team id). ai-engineer surfaced via DummyAI's "no visible Iran target — staying idle" log diagnostic and broadcast diagnosis. Lead fixed in BUG-D2 fix-wave.

5. **Missed-opportunity exhibit — BUG-C1 Wave 3A.6.** ui-developer's production_panel.gd:_read_balance_int (line 368) shipped with the CORRECT canonical Dictionary lookup for BalanceData.buildings access while gp-sys's building.gd `_read_bldg_stats_int` shipped with the WRONG top-level-field pattern per the broken brief. ui-developer was the first cross-track witness of the divergence — could have broadcast brief-vs-shipped-code divergence finding to lead before gp-sys's Track 1 ship — but the cross-track diagnostic discipline was not yet codified for the "brief-vs-canonical-code" axis at that time. BUG-C1 shipped, caught at live-test instead. This exhibit is the rule-validating negative case: had §9.D10 been active, ui-developer would have broadcast and the bug would have been caught one round earlier.

**Operational form:**

Implementer's post-stage workflow:
1. Stage own-track changes locally (`git add <paths>`).
2. Run the full headless test suite: `godot --headless --path game -s addons/gut/gut_cmdml.gd -gdir=res://tests -gexit`.
3. Parse failures. Triage each failure:
   - **Self-track failure** → fix before commit.
   - **Non-self failure in same-wave track** → broadcast SendMessage to that track's implementer with diagnosis + suggested fix (where possible). Continue to commit own-track if non-blocking; flag in [ready] message either way.
   - **Non-self failure in lead-owned surface (briefs, autoloads, contracts)** → broadcast to lead with diagnosis.
   - **Pre-existing failure** (not introduced by this wave) → note in [ready] but don't gate.
4. Include cross-track diagnostic findings in the [ready] message body so they don't get lost in chat noise.

**Catch-rate scaling:** approximately 1 successful cross-track catch per fresh producer-consumer relationship per session. A session with N new producer surfaces → expect ~N catches if every consumer implementer runs the discipline. A wave with one fresh producer-consumer relationship → expect ~1 catch.

**Relationship to §9.D7.** §9.D7 originally framed cross-track diagnostic as a refinement sub-clause `D7(b)`. Session-8 retro evidence (N=4 successful catches + 1 negative exhibit across 2 sessions) graduates the pattern from refinement to standalone active rule. §9.D7 is left as-is (its no-silent-coexistence framing remains correct); §9.D10 promotes the cross-track-first-consumer pattern to its own discoverable rule.

Cites Manifesto Principle 1 (Truth-Seeking — non-self failures are signal) + Principle 9 (Automated Enforcement — suite-run + broadcast scales). See also §9.D7 (no-silent-coexistence-with-cross-track-WIP, this rule's parent framing), §9.L10 / §9.L12 (canonical-pattern grep, upstream complements when the consumer is the gating track).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 session-8 close; gp-sys-p3s3 retro reflection N=4 successful + 1 missed-opportunity (BUG-C1) exhibits → codification as standalone D10 (promoted from prior D7(b) refinement framing)]

#### D11. First-Consumer Trace — every wave brief names the first end-to-end consumer of its surface

**Actor.** Lead at brief-drafting time + mirror-reviewer at brief-time review (holds the brief if the trace is "we'll see").

**Trigger.** Drafting any wave brief that ships a new code surface (API, signal, autoload, component, state, protocol). Every wave that ships a surface.

**Rule.** Every wave brief includes a **§5 First-Consumer Trace** section (or equivalent named section) with three explicit fields:

```markdown
### §5 First-Consumer Trace

**First consumer:** <name + file:line> — the FIRST end-to-end consumer of this wave's
surface that will fire after this wave merges.

**First-fire tick:** <when the consumer first exercises the surface> — match-start
tick=N, first Turan probe at tick=3600, first worker arrival at tick~470, etc.

**Gate that would prevent first fire:** <what would mask the integration> — fog
not yet revealed, no Iran target visible, no producer building shipped yet, etc.
If the gate is opaque ("we'll see at live-test"), the brief is incomplete.
```

**Why.** gp-sys-p3s3 retro reflection (2026-05-28) identified the "first-consumer-of-pre-existing-surface" gap as the latent-bug pattern responsible for session-9's BUG-H chain:

- **Wave 3A.5** shipped vision-source registration with a team-id check → **BUG-D2 latent** (Turan-team-id rejected by bounds check) until first Turan-side fog read fired.
- **Wave 3B** shipped `_pick_target` filter for Iran units → **BUG-H1 latent** (buildings not in candidate pool) until first wave where Iran built any non-Throne building.
- **Wave 3-Throne** shipped LOCAL-signal pattern fix for HC.health_zero → **BUG-G1 latent** (universal applicability) until other buildings inherited the same surface.

In each case, the wave shipped a surface that didn't have an immediate consumer in the same wave. The consumer arrived 1-3 waves later. The consumer revealed an assumption-failure in the original surface. **The trace surfaces the assumption gap at brief-time, BEFORE the consumer arrives**, by forcing the brief to name where + when + how the surface will be first exercised.

**Branching on the trace's answer.**

- **Consumer shipped + fires at tick N in the same wave** → integration verifiable in-wave. No fix-up budget needed.
- **Consumer shipped in prior wave + first fires in this wave** → integration verifiable in-wave. No fix-up budget needed; but brief explicitly cites the prior-wave anchor.
- **Consumer SHIPS in this wave + first fires LATER** (after Phase-N+M when downstream wave ships) → **mark surface FORWARD-COMPAT in code + docs**. Brief documents the assumption gap explicitly. Fix-up budget expected when consumer arrives.
- **Consumer not yet identified ("we'll find out at live-test")** → **MIRROR-REVIEWER HOLDS THE BRIEF**. Brief is incomplete. Either name the consumer or scope the wave to ship-with-its-own-consumer.

**The FORWARD-COMPAT marker (sub-pattern).** When a wave ships a surface without a co-resident consumer in the same wave, the surface gets a `# FORWARD-COMPAT — first consumer expected in Wave N+M, surface assumptions untested.` comment at the canonical declaration site (signal declaration, public method, protocol method). The marker signals to future-agents (and future-self) that the surface's assumptions haven't been tested against a real consumer yet. When the consumer ships, the marker comes off — the assumptions are now tested.

**Existing FORWARD-COMPAT precedent (informal):** Mazra'eh's `_local_stock_x100: int = 0` field scaffolded for Phase 4+ Trade & Transport caravan-origin (PR #41 Wave 3-LocalDropoffs). Existing pattern; this rule formalizes it.

**Operational form.**

Brief Track section at brief-drafting time:
1. Lead names the first consumer in §5 (or returns to §3 to add a co-resident consumer if none exists).
2. Lead identifies first-fire tick + the gate that would prevent it.
3. If first-fire is in a downstream wave: brief documents the gap + the surface receives FORWARD-COMPAT marker in code.
4. Mirror-reviewer brief-time review holds the brief if §5 is missing or "we'll see."

**Where reviewers enforce.**

- **Mirror-reviewer brief-time review** checks for §5 presence + content quality. Missing §5 = BLOCKER. "We'll see" content = BLOCKER ("name the consumer, or scope-up the wave to include one").
- **architecture-reviewer + godot-code-reviewer post-implementation** check that FORWARD-COMPAT markers are present on shipped surfaces without co-resident consumers + are removed when the downstream consumer arrives.

**Where authors apply.**

- **Lead (brief author)** runs the first-consumer trace BEFORE drafting Tracks. The trace's answer determines whether the wave needs to grow to include its own consumer.
- **Implementer agents** add FORWARD-COMPAT markers in code per the trace's branch decision.

**Anti-patterns.**

- Brief ships surface + Track section says "the consumer will exercise this later" without naming when "later" is. The wave can't be integration-tested in-place. Symptom: BUG surfaces 1-3 waves downstream.
- Lead claims "consumer is obvious — the next wave will use it." If it's obvious, the trace is trivial to write. Resist the no-trace path.
- Mirror-reviewer accepts "we'll see at live-test" as a valid §5. The whole point of §5 is to surface the integration assumption gap at brief-time, NOT at live-test.

**N=3 latent-bug exhibits (session 9 BUG-H chain root causes).**

| Wave | Surface shipped | First consumer | Gap | Bug surfaced |
|---|---|---|---|---|
| Wave 3A.5 | Vision-source registration with team-id check | Turan-side fog read | First Turan-side fog read (Wave 3B+) | BUG-D2 (Wave 3B live-test) |
| Wave 3B | `TuranController._pick_target` filter | Iran building targets | First wave with Iran non-Throne building (Wave 3-LocalDropoffs+) | BUG-H1 (Wave 3-BD live-test) |
| Wave 3-Throne | LOCAL HC.health_zero subscription | All buildings inheriting destruction | All-8-buildings destruction wave (Wave 3-BD) | BUG-G1 generalization (Wave 3-BD architecture-reviewer brief-time catch) |

Each would have surfaced at brief-time if §5 First-Consumer Trace had fired:
- Wave 3A.5's §5: "First consumer = TuranController fog-read at Wave 3B sim_phase. First-fire tick = 3600 (Turan probe). Gate = Turan unit must register fog vision (which requires the bounds-check to NOT reject TURAN team_id)." Brief-time mirror would have caught the bounds-check gap.
- Wave 3B's §5: "First consumer = TuranController.set_target on combat-fire path. First-fire tick = ~3700 (probe + walk + range). Gate = target must be in candidate pool. Iran units are; Iran buildings are NOT." Brief-time mirror would have flagged "buildings not in candidate pool" as a future-wave integration gap.

**Companion rules.**

- §9.D11 (First-Consumer Trace, this rule) + §9.B4 (named track-modes) + §9.L11.1 (two-actor framing) form a **brief-time triad**: name the consumer (D11), declare track-mode (B4), backstop balance.tres + canonical patterns (L11.1 + L12). All three fire at brief-drafting; all three have mirror-reviewer backstops at brief-time review.

Cites Manifesto Principle 10 (Feedback Cycle — surface the integration question at brief-time, not at live-test) + Principle 1 (Truth-Seeking — name the assumption, don't ship-and-pray) + Principle 6 (Honest-tools-not-magic-tricks — "we'll see" is hand-waving).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; gp-sys-p3s3 retro reflection N=3 latent-bug exhibits (BUG-D2 + BUG-H1 + BUG-G1 generalization) → lead codification]

#### D12. Canonical-spec-pin in dispatch — parallel-worktree tracks MUST cite the canonical spec doc by path + commit SHA in the dispatch message; track's first [ready] broadcast MUST acknowledge read-against-canonical

**Rule.** When a wave has 2+ parallel-worktree tracks sharing a data contract (NDJSON schema, signal payload, autoload API, file format), the lead's dispatch message to each track MUST include:
1. **Canonical spec source line**: `Canonical schema: <doc_path> @ <git_sha>` — the exact path + commit SHA at dispatch time.
2. **Read-before-write requirement**: explicit "read this doc before writing any field/signal/method references" prereq.

Each track's first `[ready]` broadcast MUST acknowledge the canonical-read by quoting the schema SHA they wrote against.

**Actor.** Lead at dispatch-time. Track agents at first [ready] broadcast.

**Trigger.** Brief declares 2+ tracks AND any of:
- One track produces data the other track(s) consume.
- Multiple tracks reference the same schema doc, signal contract, or autoload API.
- The brief contains an inline schema example (the brief's example is implicitly a contract).

**Why (N=1 session-10 evidence + retroactive applicability):**

Wave 3-Sim BLOCKER C1.1 (session 10 integration-time mirror finding): qa-engineer's Track 3 wrote `units_alive_at_end` / `events_summary` against the brief's §3 Q5 starting-proposal NDJSON; engine-architect's Track 2 + balance-engineer's Track 1 spec used `combat_units_alive_at_end` / `events` per the canonical doc that superseded Q5. Track 3's dry-run tests passed because their wrong-name fixture matched their wrong-name assertions (self-consistent within Track 3, divergent from Track 1 spec). Mirror caught only at integration-time by cross-checking against the canonical doc. Three-agent retro convergence (balance-engineer + engine-architect + qa-engineer all independently flagged this exact root cause) made the structural fix obvious.

**Why the dispatch-time pin matters.** Multiple plausible-looking sources of the schema exist in any non-trivial wave: the brief's §X starting proposal, the spec doc the wave produces, the brief's inline example, prior-wave conventions. Without an explicit "this doc at this SHA is canonical" stamp, each track agent picks the most-recently-read or most-locally-accessible source. The brief's starting proposal is read first; if the canonical spec evolves during the wave, the track-3-style drift is the default failure mode.

**Operational form (lead dispatch template addition):**

```
Canonical schema: docs/AI_VS_AI_RESULT_FORMAT.md @ 381cf1a
Read this doc before writing any field references in your track.
Your first [ready] broadcast MUST confirm you wrote against this SHA.
```

**Operational form (track [ready] broadcast addition):**

```
[ready] <track-name> wave-<X> at <commit>
Canonical schema confirmed: docs/AI_VS_AI_RESULT_FORMAT.md @ 381cf1a (read before write).
<rest of broadcast...>
```

**Tracks that don't share a data contract.** When tracks are genuinely independent surfaces (e.g., Wave 2B's gp-sys Track 1 + world-builder Track 2 + balance-engineer Track 3 — different files, no shared schema), the pin is unnecessary. The rule fires only when track-coupling exists. Lead judgment at dispatch-drafting time: is there a single doc whose field/method names appear in two or more tracks' deliverables? If yes, pin it.

**Distinguishes from §9.D11 (First-Consumer Trace).** D11 names the consumer of the wave's output. D12 names the source of the wave's contract. Both fire at brief-time / dispatch-time; both are mirror-reviewer-backstop-eligible.

**Where reviewers enforce.**

- **Mirror-reviewer brief-time review** verifies every multi-track brief's dispatch templates carry the canonical-schema pin. Brief without pin on a multi-track wave = SUGGEST → BLOCKER if the tracks have schema-sharing surface (NDJSON, signal payload, autoload API).
- **Mirror-reviewer integration-time review** verifies the round-trip (§9.M8): if a track's deliverable references field names diverging from the canonical, find the missing pin acknowledgment in the [ready] broadcast as the upstream gap.

**Where authors apply.**

- **Lead (dispatch author)**: for 2+ track waves, add Canonical-schema line to each dispatch message; verify in the canonical doc's frontmatter that `ssot_for` lists the schema explicitly.
- **Track implementers**: at start-of-implementation, open the cited doc at the cited SHA; do the field-by-field diff against your track's surface; confirm the read in your [ready] broadcast.

**Two-actor framing (per §9.L11.1 pattern).** Lead's dispatch pin (primary discipline) + track's [ready] confirmation (acknowledgment) + mirror-reviewer integration-time round-trip (backstop). Each actor catches a different failure mode:
- Pin missing in dispatch → mirror-reviewer brief-time finding.
- Pin present, track ignored it → mirror-reviewer integration-time round-trip catches the drift.
- Both present and honored → no drift surfaces.

Cites Manifesto Principle 7 (SSOT — canonical doc IS the truth; multiple plausible-looking sources create the drift surface) + Principle 1 (Truth-Seeking — name the canonical source explicitly; don't hope agents pick the right one) + Principle 9 (Automated Enforcement — round-trip test sentinel from §9.M8 is the after-the-fact backstop; pin is the before-the-fact prevention).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; balance-engineer-p3s3 + engine-architect-p3s2 + qa-engineer-p3s3 three-agent retro convergence (each independently flagged the same root cause for BLOCKER C1.1) → lead codification. Sister rule to §9.M8 (real-data round-trip — the after-the-fact sentinel for what D12 prevents at dispatch-time).]

---

### §9.E — Wave-Mode & Worktree

#### E1. Wave-mode declaration — every wave brief explicitly stamps a mode

**Rule.** Every wave brief explicitly stamps a mode:

- **`parallel-worktrees`** — wave has multiple INDEPENDENT deliverables touching DISTINCT code surfaces. Lead pre-creates a worktree per dispatched agent (`git worktree add ../<repo-name>-<dispatch-id> <branch>`) BEFORE dispatch. Each agent receives their worktree path in the brief; agent never manages worktree setup. Each worktree has independent `.uid` / `.import/` regeneration on first scene load (~1 min cost; one-time per worktree). All worktrees commit to the SAME branch; git serializes the underlying `.git` write lock. Push order is wave-close serialized by the lead.
- **`sequential-shared-tree`** — wave has one deliverable, OR multiple deliverables that touch shared files (`balance.tres`, `main.tscn` heavily, large doc additions). Single agent owns the working tree for the wave's duration. Per-TDD-cycle commits apply (D3).

**Decision boundary (lead's call at wave-design time):**
- **Parallel-worktrees:** 3 unit types in different files; integration tests independent of game code changes; UI changes parallel to gameplay changes.
- **Sequential-shared-tree:** anything touching `balance.tres` (cross-cutting writes); single-deliverable waves; docs-aggregator commits; emergency bug-fix sweeps.

**Mandatory pitfalls for worktree mode (folded from engineering POVs):**
1. Worktree directory naming uses **dispatch identifier**, NOT role name. If wave 1A and wave 1C are both `gameplay-systems`, they get `gp-sys-wave-1A` and `gp-sys-wave-1C` directories. Collapsing by role name leaks the race back.
2. Lead creates worktrees AT DISPATCH TIME, not inside the agent brief. Brief delta is one line: `"Your worktree: ../shahnameh-rts-<dispatch-id>"`. Agent does NOT run `git worktree add`.
3. `.godot/` must be in `.gitignore` for per-worktree state to regenerate cleanly. Verify before first parallel-worktrees wave.
4. `balance.tres` cross-cutting writes are sequential-only — never parallel. Two worktrees writing the same `.tres` resource produces a last-push-wins race that git doesn't catch.
5. File-count integration tests (e.g., `test_main_tscn_spawns_N_units`) experience semantic merge conflicts when two parallel agents both extend the spawn list. Each worktree's tests pass locally; the merged commit may fail. Lead's wave-close integration smoke catches this.
6. BUILD_LOG / ARCHITECTURE retro entries from each worktree need aggregation at wave-close. Lead consolidates or asks each agent to push a per-wave entry to a known anchor.
7. Worktree cleanup discipline: `git worktree remove ../<dispatch-id>` at session close. Add to session-close-retro template.
8. Test isolation via shared `user://` storage: existing tests don't write `user://`, but spot-check before adding any save-game tests.
9. `.uid` cache: project currently has `*.uid` as untracked; per-worktree regeneration is cheap and harmless. If `.uid` files ever get committed, switch to gitignore to avoid two worktrees committing different UIDs for the same logical file.
10. Fast-forward race at push time: shared branch means each worktree pushes commits to the same `feat/<branch>`. Git's local `.git` lock serializes writes; the remote push is a normal `git push`.

**⚠️ Runtime-verification status:** the `Agent` tool's `isolation: "worktree"` parameter is documented-but-unimplemented in the runtime layer. Lead must manually pre-create `git worktree add` and pass the path in the brief, OR fall back to sequential dispatch. Current default: **sequential single-agent dispatch for any write-active wave; parallel only for read-only review agents.**

**Addendum — parallel WIP visible in working tree (session-6 close).** §9.E1's `sequential-shared-tree` mode prevents file-level commit-race contamination (via pathspec discipline + git index.lock) but does NOT prevent **pre-commit-suite-gate-coupling** races: the pre-commit hook runs the full GUT test suite, including against working-tree files modified by parallel agents but not yet staged. If Agent-A's pre-commit-WIP `.gd` references node names Agent-B hasn't yet staged in the matched `.tscn`, Agent-B's pre-commit hook fails on a file Agent-B never touched. **In parallel-dispatch waves, the working tree may contain unstaged WIP from other agents. If a pre-commit hook failure references a file you did not touch, treat it as a candidate transient. Retry once before broadcasting (mirrors M3 error-specificity refinement).** N=2 instances in Wave 2B alone (Track 2 vs Track 4; BUG-B1 vs BUG-B2). Discipline-side fix; tooling-side fix (Agent isolation: "worktree" runtime ratification OR scoped pre-commit hook) deferred to future infrastructure work.

**Addendum — tier-precedence ladder (session-7 close, synthesized from 5 empirical paths across Waves 3A.0 / 3A.5 / 3A.6).** When a coupled-test-gate or coupled-WIP situation surfaces in a parallel-dispatch wave, the agent's choice ladder is:

- **Tier 1 (DEFAULT) — [blocked]+broadcast or sequenced-on-same-branch.** Conservative default when the agent cannot see other tracks' state with confidence. Broadcast surfaces the race to lead + non-gating tracks at zero risk to anyone's WIP. Resolution shape: Track 1 ships first → Track 2 commits on top. Single branching question per world-builder-p3s2: *"Can both tracks commit to the same ref?"* If yes, sequence. Sequenced-on-same-branch requires no deliberation; everything else requires an explicit reason to deviate.
- **Tier 2 — joint-commit-intervention.** Permitted IFF the committing agent has staged-clean visibility into ALL coupled tracks AND can attest to their content AND the cross-track fix is small + unambiguous (no design judgment required). Wave 3A.0's `da3dc75` joint commit is the canonical example: balance-engineer-p3s3 had FogConfig + BalanceData + the cross-track sweep fix (test_match_harness.gd hardcoded `7`) all in scope simultaneously. The 3A.0 [blocked] resolution time at ~10 minutes wall-clock validated joint-commit's speed advantage when the coupled-test-gate is well-isolated. Cost: attribution bundling. Benefit: sub-minute resolution.
- **Tier 3 — lead resolution via §9.B2 / §9.D5.** When Tiers 1+2 both stall. Lead commits on behalf with full provenance in commit body.
- **FORBIDDEN — stash-and-pop on dirty index.** Destroys other tracks' WIP, no upside, the canonical 3A.0 `.git/index.lock` pitfall lives here.

**Tool selection clarification — `git restore --staged` vs `git stash`.** Both can clear cross-track WIP from your working tree, but they're answers to different questions:
- `git restore --staged <pathspec>` is the right tool when you want to commit a clean subset AND preserve the other track's WIP intact. Surgical — unstages exactly what you specify; working tree intact; no pop risk.
- `git stash push -- <pathspec>` is the right tool when you want to temporarily shelve WIP you're uncertain about, with intent to either pop later (preserve) OR discard (drop). The 3A.6 Track 3 stash-and-discard escape hatch lives here: when the stashed WIP IS another track's work that they're independently re-shipping, stash-and-discard is safe.
- **Use `restore --staged` for subset-commit-preserving-WIP.** Use `stash` only for shelve-with-uncertain-intent. The 3A.0 pitfall (stash pop on a dirty index → `.git/index.lock`) points specifically at using stash as a subset-commit mechanism — which is exactly what `restore --staged` is for. Don't conflate.

**Incidental cross-track review — a non-obvious benefit of joint-commit-default (world-builder-p3s2, 3A.5 + 3A.6 retro).** The coupled-test-gate produces incidental cross-track review by structural property: the gating track's full-suite-run at ship time exercises consumer-side tests against the producer's surface. gp-sys-p3s3's N=2 cross-track diagnostic catches (3A.5 world-builder's `as Node3D` cast on freed Object + 3A.6 ui-developer-p3s3's `test_close_clears_rows` cleanup-ordering) both happened via this mechanism. The discipline pays dividends invisibly. **First runtime consumer of a new producer surface is best-positioned to catch contract bugs in that producer** — not domain-specific; any downstream consumer has the vantage. Pair with §9.D7(b).

Cites Manifesto Principle 4 (Lean Iteration — picking the right tier minimizes coordination cost) + Principle 1 (Truth-Seeking — pre-shipped cross-track review is structural truth-finding, not luck).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-23 session-7 close]

Cites Manifesto Principle 4 (Lean Iteration — worktrees buy back parallel-agent throughput without giving up isolation) + Principle 8 (Separation of Concerns — the race lives at the working-tree level; the mitigation lives at the working-tree level).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-13 Open Space sync]

#### E2. Process-mitigation runtime verification — structural-fix claims need empirical proof before §9 ratifies them

**Rule.** When a sync or retro proposes a process mitigation framed as "structural" (vs. discipline-side), the mitigation entry MUST cite a runtime verification step — a probe test, a first-real-trial smoke-test, an empirical confirmation — proving the mitigation actually works at the layer it claims to operate at. Document claims ≠ runtime behavior.

**Why.** Open Space 2026-05-13 ratified worktree-per-agent as the structural fix for Pitfall #7. The Agent-tool `isolation: "worktree"` parameter turned out to be a documented-but-unimplemented runtime gap. The mitigation as documented was unimplemented. Phase 3 session 1's first parallel-3 fix-wave dispatch hit the SAME Pitfall #7 race the structural fix claimed to close.

**Operational form.** No future "structural fix" claim ratifies into §9 without runtime verification. Confidence in process mitigations should be calibrated against runtime VERIFICATION, not document claims.

Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 9 (Automated Enforcement — rules that aren't enforced erode).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-14 post-Phase-3-session-1]

---

### §9.F — Wave-Close Review & Reviewer Architecture

#### F1. Wave-close review architecture — persistent in-team at wave-close + fresh-spawn external-audit at PR-time

**Rule.** Two-class review architecture covering two distinct review stages, two different reviewer classes, two different lenses.

**Stage 1 — Wave-close review (in-team, persistent).** At each wave-close before PR creation: persistent reviewers review the wave's commits.
- **Default reviewers:** `architecture-reviewer` + `godot-code-reviewer`. Lead `SendMessage`s their existing instances at each wave-close — they have session memory and remember prior waves.
- **Optional third reviewer:** `shahnameh-loremaster`, invoked when a wave touches unit/building/hero naming, narrative content, symbolism, or any new mechanic with a Shahnameh referent.
- **Output shape:** structured review with verdict, blocking issues, non-blocking suggestions, nits, what's clean. Blocking issues route back to the original agent for fix; non-blocking suggestions and nits surface in the PR description.
- **GitHub artifact:** reviewers post their full structured review as a GitHub PR comment via `gh pr review --comment` so the review trail is discoverable inline in the GitHub UI, not just in agent chat / PR description.
- **Persistent value:** "catch drift WITHIN the team's worldview" — "this wave is contradicting what you yourself approved in wave 1A."

**Stage 2 — PR-time review (external audit, fresh-spawn).** When the lead opens a PR to main, BEFORE merge: two fresh-spawned reviewers run in parallel.
- **Fresh-instance `architecture-reviewer`** — same agent definition as the persistent one; new instance with no session memory. Reads the whole PR diff at once, against `ARCHITECTURE.md` + contracts. Different lens from the persistent instance: catches "we incrementally agreed to N small things; the sum has drifted from where we started."
- **`peiman-manifesto-reviewer`** — audits the PR against the **canonical** Peiman Khorramshahi manifesto (the 10 principles). Reads ONLY the PR diff and the canonical manifesto. Deliberately does NOT read the project's `MANIFESTO.md` (that's the project's *interpretation* — reading it anchors the reviewer to the team's worldview), nor the contracts, nor `ARCHITECTURE.md`, nor any other agent definition. Catches **drift OF the team's worldview itself** — the slow normalization the in-room agents can't see because they've all watched it happen.
- **The two PR-time reviewers do NOT communicate with the persistent instances of the same agent definition.** Contamination by accumulated context defeats the fresh-eyes purpose. Lead is the only synthesizer of both PR-time verdicts.

**Workflow:**
1. Session start → lead spawns Tier-1 persistent reviewers.
2. Each wave-close → lead `SendMessage`s persistent reviewers with the wave's commit range. Reviews come back. Lead addresses blockers, opens PR after all waves shipped clean.
3. PR creation → lead spawns fresh-instance `architecture-reviewer` + `peiman-manifesto-reviewer` in parallel.
4. PR-time blockers route back: architectural drift → fixes commits to PR; manifesto violations → discussion (some are blocking, some surface design-chat questions via `QUESTIONS_FOR_DESIGN.md`).
5. PR merges → fresh-spawn reviewers terminate. Persistent reviewers continue for next session.

**Convergent-finding promotion criterion.** When ≥2 of the active reviewers (out of 2 or 3 depending on whether loremaster is invoked) flag the same item independently, it auto-promotes to a LATER index item at the next retro.

**Why two different reviewer classes.** Persistent reviewers accumulate valuable memory but accumulation creates anchoring that hides systemic drift. The two-class architecture captures both: persistent for compounding memory at wave-close, fresh for adversarial audit at PR-time.

The "Peiman" naming is intentional — پیمان is Persian for *covenant / promise / oath*, and the manifesto IS the project's covenant. The reviewer is its keeper.

**Canonical incidents:**
- **PR #4 trial (2026-05-03):** validated wave-close reviewer catches structural drift that all 535 unit + integration tests had passed.
- **PR #16 fresh-spawn audit (2026-05-17):** caught wave-1C's missing `construction_finalized` integration that the persistent reviewers had approved one wave at a time.
- **Pitfall #15 cross-cutting audit (2026-05-17 session-4 PR #19):** fresh-spawn godot-code-reviewer produced the project-wide audit confirming no other instances of the syntax bug.

Cites Manifesto Principle 1 (Truth-Seeking — adversarial fresh-eyes catches what in-room familiarity can't) + Principle 7 (SSOT — the canonical manifesto, not the local interpretation, is the source of truth for the project's promises).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-03 + 2026-05-12 graduation + 2026-05-13 loremaster + 2026-05-14 two-class architecture]

#### F2. Layer 1.5 enumeration discipline — reviewers produce explicit enumeration tables

**Rule.** When a wave introduces a new shared classification surface (SceneTree group, duck-type method, base-class field, EventBus signal), the reviewer outputs an explicit enumeration TABLE in the review verdict listing (a) publishers / adders, (b) consumers / readers, (c) every existing entity-type membership status. The enumeration is a **written artifact**, not a "I checked this" claim.

**Why.** Phase 3 session 2 wave-1A's `&"buildings"` group + wave-1B's `&"resource_nodes"` group + `register_extraction_modifier` API both produced cleaner review verdicts when the enumeration was in-writing. godot-code-reviewer's automaticity-threshold timing (5 min at wave 1A → 4 min at wave 1B) indicates the discipline transferred from deliberate to natural in one session — the table-shape is internalized.

**Operational form.** Add the enumeration table to both reviewers' review templates. **Refinement candidate:** add an "exclusion-vs-inclusion" column for at-a-glance distinguishing of new-participant inclusions from new-participant exclusions (trial at wave 2A; graduate to permanent if it adds value).

Cites godot-code-reviewer's wave-1A invention + wave-1B validation.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2]

#### F3. Behavioral-vs-structural test discipline — structural assertions require behavioral counterpart

**Rule.** When a test asserts a scene-tree node exists, a group membership holds, a class_name declaration is present, or any structural element whose PURPOSE is to cause an effect on adjacent systems (collision shapes, navmesh obstacles, sim coordinators, event-bus subscribers), the test suite MUST include AT LEAST ONE behavioral assertion that the structural element actually produces the runtime EFFECT it claims.

**Why.** Presence assertions (`get_node_or_null != null`, `is_in_group(&"X")`, `has_method(&"Y")`) verify the SHAPE; behavioral assertions verify the EFFECT.

**Canonical incident.** Phase 3 session 2 wave 1B live-test surfaced that NavigationObstacle3D nodes on every Building scene (asserted by `test_building_base.gd`, `test_khaneh.gd`, `test_madan.gd`, `test_phase_3_khaneh_placement.gd`) didn't actually block worker pathing. The gap rode from wave-1A original Khaneh shipping (six days) because presence-assertions passed and no behavioral assertion existed.

**Operational form.** At wave-close test-coverage review (godot-code-reviewer's domain), for any new structural element introduced, the reviewer asks "is there an assertion that this element produces its intended effect on a downstream consumer?" If not — SUGGEST a behavioral test (BLOCK if the structural element is load-bearing for gameplay correctness; SUGGEST if the behavioral test requires expensive scaffold like a NavigationRegion3D bake).

Cites Manifesto Principle 1 (Truth-Seeking — verify the effect, not just the shape) and Principle 9 (Automated Enforcement — rules without enforcement erode).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2]

#### F4. Inherited-scene-with-nested-overrides — instantiate-and-walk regression test mandatory at first occurrence

*Scene-layer cousin of F3 — same "test the effect, not the presence" principle applied to scene composition.*

**See also: M4.** F4 mandates the regression test EXISTS for any inherited-scene-with-nested-overrides at first occurrence. M4 specifies WHERE it lives (a separate `test_<subclass>_scene.gd` file owned by the scene author) and WHY (decouples test ship-timing from scene ship-timing per Track-N/Track-M separation). Both rules together: the regression test is mandatory (F4); it lives in the scene-author's parallel test file, not the class-behavior test file (M4).

**Rule.** Any `.tscn` that uses inherited-scene composition (`instance=ExtResource(...)`) AND overrides a nested child node MUST include a test that instantiates the scene, walks to the overridden node, and asserts the overridden property has the SUBCLASS value (not the base value). The canonical pattern is `test_collision_shape_matches_mesh_footprint` in `test_sarbaz_khaneh_scene.gd` — the test fails immediately and loudly if the override silently falls back to the base.

**Why.** Pitfall #15 (Godot inherited-scene nested-child override syntax — see `docs/PROCESS_EXPERIMENTS.md`) is a silent-override-failure class: scene loads cleanly, mesh renders at subclass dimensions, no lint catches the form. Only structural-effect verification at test time catches the divergence.

**Operational scope.** Mandatory at FIRST occurrence of a subclass with nested-child overrides; subsequent subclasses overriding the same node can reuse the test pattern. **Trigger condition:** any `.tscn` with `instance=ExtResource(...)` whose `[node ...]` blocks include `parent="<non-root-path>"`.

**Canonical incident.** Wave 2A Sarbaz-khaneh — first subclass inheriting `building.tscn` to override `CollisionShape3D` (Khaneh kept base 2.0×2.0; Mazra'eh + Ma'dan are standalone scenes). Bug at `1ff3039`, fix at `2f31b34`, regression test in `test_sarbaz_khaneh_scene.gd`.

**Defense-layer ruling (engine-architect-p3s2, persistent voice).** A narrow L7 lint rule was proposed at session-4 retro and **rejected** as wrong-layer — `tools/lint_simulation.sh` patterns are L1-L6 over `.gd` source; extending to `.tscn` would shift the lint script's responsibility class. Final defense: regression-test pattern at first occurrence + ARCHITECTURE.md §3.1 documentation breadcrumb (deferred to next §3.1-touching wave). NO L7 lint.

**Footnote — value-choice for the regression test (session-6 close, world-builder refinement).** When choosing the override value for the test assertion, **prefer values that diverge from the base in the direction that makes silent-fallback-to-base detectable in BOTH wrong-syntax failure modes** ("override not applied" → falls back to base; "wrong override applied" → wrong value). Example: if base mesh y=1.2, choose override y=1.0 (less than base — so silent-fallback to 1.2 fails the assert `y == 1.0`, AND wrong-override to anything other than 1.0 also fails). When the override value is greater-than base, silent-fallback also fails the assert; the in-either-direction discipline catches both failure modes regardless. Not always feasible (sometimes values are constrained); when feasible, strictly better. Canonical refinement at Tirandazi `2ebe95d` Y=1.0 guard.

Cites Manifesto Principle 1 (Truth-Seeking — test the effect, not the syntax) and Principle 9 (Automated Enforcement — regression-lock at first incidence).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4]

#### F5. Producer-stub-consumer integration test — ship at least one non-trivial consumer-perspective assertion when shipping a producer with no real consumer yet

*Test-discipline companion to §9.H3 (first-exercise-of-dormant-schema). H3 mandates the call-out at brief-time and the D9 self-check; F5 mandates the test artifact that catches the wiring gap before live-test does.*

**Rule.** When a wave ships a producer API (function, signal, autoload method, or phase handler) whose only consumer at ship time is a stub or the brief's promise of a future consumer, the shipping agent MUST include at least one integration test that: (a) calls or triggers the producer through its intended entry point — NOT by calling the function body directly — and (b) asserts a non-trivial correct output from the consumer's perspective. The test must exercise the full wiring path, not just the function's internal logic.

**Why.** Structural unit tests on the producer ("method exists", "returns correct type given direct call") pass even when the wiring that would drive the producer at runtime is broken. Two confirmed incidents where this gap masked a broken wiring path through multiple test-suite passes:

- **BUG-D1 (Wave 3A.5 / session-7)**: `FogSystem._ready` connected to `SimClock.has_signal(&"fog_update")`, which always returned false — SimClock has no such signal. `_on_fog_update_phase` was never called in production. The function body was correct; all unit tests called it directly via `_on_fog_update_phase()` and passed; the broken `_ready` wiring was never exercised. Mirror-reviewer caught the bug at session-8 brief time after the wave had shipped. Root cause: zero integration tests drove the connection through `EventBus.sim_phase.emit(...)`.
- **BUG-D2 (Wave 3A.5 / session-7, same wave)**: `is_visible_to(Constants.TEAM_TURAN, ...)` silently returned false due to a 1-indexed vs 0-indexed mismatch in the bounds check. Tests used hardcoded `0` and `1` instead of `Constants.TEAM_IRAN` and `Constants.TEAM_TURAN`; TURAN was never exercised through its canonical team-id. ai-engineer caught it at first runtime. Root cause: tests did not assert a non-trivial output (`is_visible_to` returning true) from the Turan-perspective consumer.

The pattern in both incidents: tests exercised the producer's internals, not the producer's wiring + output from the consumer's vantage. The F3 behavioral-vs-structural rule applies laterally here, but the producer-stub-consumer shape is distinct enough to warrant its own rule — F3 governs "test the effect, not the presence" at the function body level; F5 governs "test the full entry-to-output path when a live consumer doesn't yet exist to do it for you."

**Operational form.** Before shipping a producer API with no live consumer:

1. Identify the intended runtime entry point (e.g., `EventBus.sim_phase.emit(&"fog_update", tick)`, `ResourceSystem.dropoff_for_team(team)`, a HealthComponent signal).
2. Write one integration test that fires the entry point and asserts a correct consumer-observable output (e.g., `is_visible_to(Constants.TEAM_IRAN, pos) == true` AFTER `EventBus.sim_phase.emit(&"fog_update", 1)`, NOT after a direct `_on_fog_update_phase()` call).
3. The test is marked `# BUG-D1 wiring-path discipline — §9.F5` in a comment so reviewers can identify it as the entry-point test, not a unit test.

**Complement to §9.D7(b).** §9.D7(b) cross-track diagnostic fires when you observe another track's WIP and can verify against it. §9.F5 fires when you're shipping first and no other track exists yet to act as consumer. Together they close the stub-era wiring gap: D7(b) catches it when a consumer exists but isn't integrated; F5 catches it when no consumer exists yet.

**Scope.** Applies to: autoload phase handlers (sim_phase, EventBus connections), autoload API methods (ResourceSystem, FogSystem), signal declarations with deferred consumers. Does NOT apply to pure function bodies with direct call-site callers — §9.F3 covers that case.

**N=2 confirmed incidents.** BUG-D1 + BUG-D2 (both session-8 bug fixes, same wave, same underlying discipline gap). Mirror-reviewer + ai-engineer acting as de facto runtime-consumer surrogates were the actual detection mechanism — the rule codifies what they did implicitly as an explicit test-authoring step.

Cites Manifesto Principle 1 (Truth-Seeking — test the wiring path, not the function body) + Principle 9 (Automated Enforcement — the gap that makes it to live-test was already detectable in tests). See also §9.H3 (dormant-schema first-exercise call-out), §9.D7(b) (cross-track diagnostic), §9.F3 (behavioral-vs-structural discipline).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 session-8 close — BUG-D1/D2 root-cause codification, world-builder-p3s2 origination]

#### F6. Integration-time mirror review — hard rule for waves with 2+ tracks; pre-PR-merge gate

**Rule.** For any wave with 2+ parallel-worktree tracks, lead dispatches mirror-reviewer for an **integration-time code-pass on the merged branch BEFORE PR-merge**. This is in addition to the brief-time mirror review (which fires at brief v1.0 → v1.x finalization). Single-track waves may skip integration-time mirror at lead discretion.

**Actor.** Lead at wave-close time. Mirror-reviewer (architecture-reviewer subagent) at integration-time code-pass.

**Trigger.** Wave-close PR opened on a multi-track integration branch; suite green; smoke green (per §8 wave-close criteria). Mirror dispatch fires BEFORE the merge button.

**Why (session-10 evidence + structural argument):**

Two mirror passes on Wave 3-Sim caught complementary failure classes:
- **Brief-time mirror (v1.0.1 → v1.0.2)** caught 2 BLOCKERS + 2 structural fixes + 3 suggestions. Findings observable from the brief: SSOT drift risk (MatchHarness fork — C1.1), missing infra in touch list (FogSystem.reset() never existed — C3.1), track-mode declaration gaps (C4.1). All catchable by reading the brief + greping the repo. None required running the code.

- **Integration-time mirror (post-merge-pre-PR-merge)** caught 3 BLOCKERS + 4 RISKs. Findings catchable only against the merged-and-running system: schema drift between Track 3 aggregator and Track 1 spec (C1.1 — see §9.M8 + §9.D12), DummyIranController structurally inert because Unit.gd doesn't join &"units" group (C1.2), missing ARCH §2 row (C1.3), real-time pacing impact (C2.3 — value-prop fails at first-consumer time). These are **emergent properties of cross-track integration** that brief-time review couldn't see.

The two windows do two distinct review-jobs:
- **Brief-time** = contract-correctness review (does the brief specify a buildable thing?).
- **Integration-time** = integrated-system-correctness review (does the merged thing produce truthful outputs?).

Compressing both into one window loses half the value either way. The cost of an integration-time pass is 1 mirror invocation. The cost of integration bugs landing in main is what Wave 3-Sim post-merge-pre-PR-merge fix-up cycle just lived through: 3 BLOCKERS that would have shipped silently producing wrong numbers.

**Operational form.** After wave-close PR is opened (per §8 criteria), BEFORE merging:

```
1. Lead dispatches architecture-reviewer (subagent) with:
   - Branch + PR URL + worktree path.
   - Brief reference + canonical spec docs.
   - Integration-time focus areas: cross-track integration surfaces, smoke anomalies,
     SSOT seams between tracks, mirror's pre-PR-merge concerns.
   - Output format: BLOCKER / RISK / SUGGEST + verdict (MERGE-AS-IS, FIX-FIRST-THEN-MERGE, FIX-IN-FOLLOW-UP-PR).
2. Mirror returns review.
3. BLOCKERS fix-up cycle (parallel agent dispatches if multiple tracks affected).
4. Re-merge fix-ups + re-run smoke + verify against mirror's findings.
5. THEN merge PR.
```

**The "2+ tracks" threshold matters.** Single-track waves (e.g., a fix-wave landing one bug, a single-agent surface refactor) don't need integration-time mirror — the brief-time mirror review already saw the full surface. Multi-track waves create cross-track-integration surface that emerges only at merge time; that's the surface integration-time mirror exists to catch.

**Anti-pattern: skipping integration-time mirror to "save time."** The session-10 Wave 3-Sim case is the empirical evidence: 3 fix-up commits across qa-engineer + engine-architect + lead were needed to close BLOCKERS the integration-time mirror surfaced. Skipping the review would have shipped all 3 BLOCKERS to main with silent zero-fallback aggregate.json output. The "time saved" is illusory — the bugs land in main and cost more to diagnose downstream.

**Distinguishes from §8 wave-close criteria.** §8 names the deliverable checklist (suite green, smoke green, ARCH + BUILD_LOG updated, PR opened). F6 adds the gate AFTER §8's checklist passes but BEFORE merge: mirror-reviewer integration-time pass.

**Where reviewers enforce.**

- **Lead self-discipline at wave-close**: for any wave with parallel-worktrees mode + 2+ tracks, dispatch integration-time mirror as part of wave-close. Don't merge until findings are resolved or explicitly deferred.
- **Mirror-reviewer (subagent)** runs the integration-time pass when dispatched. Produces structured BLOCKER/RISK/SUGGEST output with verdict line.

**Where authors apply.**

- **Lead (wave-close author)**: §8 checklist + F6 dispatch is the canonical sequence. Treat the integration-time mirror as part of the wave's wave-close work, not an optional polish step.
- **Track agents**: aware that integration-time mirror will catch cross-track gaps the brief-time mirror couldn't see. The Track 1 spec ↔ Track 2 runner ↔ Track 3 consumer alignment IS the surface integration-time mirror reviews.

**Cost framing.** Integration-time mirror takes ~10-20 minutes of agent time per wave. Brief-time mirror takes ~10-20 minutes. Combined ~30-40 minutes of mirror time per multi-track wave. Wave 3-Sim's fix-up cycle (post-integration-time-mirror findings) was ~2 hours wall-clock. Without the review, the same bugs land in main and cost N hours to diagnose post-fact when a downstream consumer surfaces them. ROI is overwhelming.

Cites Manifesto Principle 1 (Truth-Seeking — integration-time review reads the actual truth, not the planned truth) + Principle 9 (Automated Enforcement — mirror is the mechanical second-tier net) + Principle 10 (Feedback Cycle — integration-time mirror IS the feedback cycle at wave-close).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; engine-architect-p3s2 retro reflection (drafted rule + ROI argument) + Wave 3-Sim mirror-driven 3-commit fix-up cycle as empirical evidence → lead codification. Sister rule to §9.D12 (canonical-spec-pin at dispatch) + §9.M8 (real-data round-trip) — together form the integration-failure-mode triad.]

---

### §9.G — Agent Persistence & Dispatch Channel

#### G1. Agent persistence three-tier (pointer to §12.5 canonical)

**Rule.** Subagent instances follow a three-tier persistence model:
- **Tier 1 — Session-persistent reviewers (default).** `architecture-reviewer`, `godot-code-reviewer`, `shahnameh-loremaster` (when culturally invoked). Spawn once at session start; lead `SendMessage`s them at each wave-close.
- **Tier 2 — Within-session specialist persistence (default for multi-wave specialists).** If `gameplay-systems` ships waves 1A, 1B, and 1C in the same session, it is the SAME persistent instance across all three.
- **Tier 3 — Ephemeral one-shot agents.** Fix-wave agents, surgical bug-fix dispatches, parallel-trial agents. Spawn fresh, ship, stand down.

**Plus PR-time fresh-spawn for external-audit (§9.F1 Stage 2).** This is a distinct fourth class — fresh-spawn at PR-time for roles whose value depends on project-context-naivety.

**Cross-session persistence (§12.5.1):** Tier-1 and Tier-2 persistent instances survive across session boundaries by default. Reboot is exception, not procedure.

**Addressable-name registry (added 2026-05-21 Wave 2B Track 1 routing-failure canonical incident).** Persistent-instance SendMessage `to:` field is a free-form string with no validation — sending to an agent-def file name (e.g., `gameplay-systems-pNsM`) instead of the actual addressable name (e.g., `gp-sys-p3s3`) produces `success: true` but lands in a phantom inbox. **`docs/AGENT_REGISTRY.md` is the canonical SSOT for live addressable names.** Pre-dispatch verification protocol: (a) check the registry, (b) cross-check against the most recent `<teammate-message teammate_id="X">` block from that instance — teammate_id is the runtime-authoritative addressable name, (c) if registry and teammate_id disagree, update the registry. **Never invent a name from the agent-def file name.** Lead owns registry maintenance; any agent can flag routing-mismatch incidents via SendMessage.

**Agent-side idle-availability heartbeat (session-6 close, gp-sys proposal).** When an agent has been idle-available for **>2 hours of wall-clock time without any directed message**, send a one-line `[heartbeat-ack: idle-available, no dispatch since <last-timestamp>]` to lead via SendMessage. Lead inspects whether routing is intact OR confirms genuine inter-wave gap. **The heartbeat MUST include the agent's live addressable name in the message body** (e.g., *"from gp-sys-p3s3, my addressable name is gp-sys-p3s3"*) — if lead's reply also routes to a phantom inbox, the heartbeat repeats at the next 2-hour interval, eventually surfacing the failure without requiring user intervention. Catches the AGENT_REGISTRY phantom-inbox scenario from the agent side; channel-internal recovery vs user-bridge friction. The 2-hour threshold balances (a) catching routing failures faster than the ~30min user-bridge surfaced in Wave 2B Track 1, and (b) not adding channel noise during active waves where 30-90 min between dispatches is normal.

**Canonical text + operational details live in §12.5 and §12.5.1.** §9 carries the dispatch-side operational disciplines (G2, G3) that flow FROM the persistence model.

Cites Manifesto Principle 5 (Platforms, Not Features — persistent agents are platforms for accumulating institutional memory), Principle 6 (Partnership — continuity of self is how agents take care of each other across time), Principle 10 (Feedback Cycle — feedback loops that close across sessions require continuity of self across sessions).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-14 + 2026-05-17 session-2; canonical: §12.5 + §12.5.1]

#### G2. Dispatch-channel discipline — SendMessage to persistent instances, not Agent-spawn

**Rule.** When dispatching retro reflection prompts at session-close retros (and continuation work for any topic with a persistent-instance owner), lead MUST identify the persistent instance that authored the work being reflected on (e.g., `gp-sys-p3s3`, `world-builder-p3s2`) and SendMessage them directly. **Agent-spawn is reserved for new specialties or post-reboot continuation per §12.5.1.**

**Why.** The persistent instance carries lived memory of authorship choices, friction that didn't make it into commits, and the experience of working through the problem; fresh-spawn agents can only reason from artifacts (commits, diffs, docs), which is a categorically weaker reflection surface.

**Empirical evidence.** engine-architect-p3s4-retro (fresh-spawn) recommended a narrow L7 lint for Pitfall #15. engine-architect-p3s2 (persistent) **rejected** the recommendation as wrong-layer, citing lived memory of the L1-L6 lint architecture (lint script's responsibility is `.gd` source, not `.tscn` scene format). The fresh-spawn had no access to that architectural memory; the rejection only emerges from persistent continuity.

**Lead pre-spawn checklist.** Before spawning any `*-p<phase>s<session>-<role>` instance, **check TaskList for an existing persistent instance with continuity to the topic**. If a persistent instance exists, default to SendMessage. Agent-spawn is the exception.

**Canonical incident (real-time, session-4 close retro).** Lead dispatched session-4 close retro via `Agent({name: "*-retro"})` for gp-sys / world-builder / engine-architect. User caught: *"i noticed the agents are called -retro suddenly, does that mean you spawned fresh agents for the retro?"* Lead shut down the fresh instances + re-routed via SendMessage to persistent. The fresh-spawn outputs were substantive but the persistent inputs added load-bearing nuance (the L7 lint rejection above) that the fresh-spawn could not produce.

Cites Manifesto Principle 1 (Truth-Seeking — choose the strongest reflection surface available) + Principle 6 (Partnership — persistent instances are partners with continuity, fresh-spawn agents are not).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4]

#### G3. Agent-channel discipline — SendMessage is the only authoritative channel; assistant-text is monologue invisible to lead

**Rule.** Every dispatched agent MUST produce deliverables, status updates, blocked-broadcasts, heartbeat-acks, and retro reflections via SendMessage with `to: team-lead`. Assistant-text content is invisible from lead's perspective; when the dispatch closes, assistant-text vanishes while SendMessage persists in lead's inbox.

**This rule is promoted to a first-class instruction in every `.claude/agents/*.md` agent-def**, in the "Critical: Your Communication Channel" section at the top, with this exact shape:

> **Your communication channel is SendMessage. Assistant-text is monologue — invisible to lead.** Every deliverable, status update, blocked-broadcast, heartbeat-ack, or retro reflection MUST go through SendMessage with `to: team-lead`. If you produce reflective content as assistant-text, it does not exist from lead's perspective.

**Why agent-def, not brief instruction.** The agent's *default* output mode is assistant-text, and that default beats brief-tail instructions under cognitive load. Agent-defs are read every dispatch; brief instructions depend on brief-author memory.

**Canonical incidents (two in session-4):**
1. **loremaster-p3s2 silence ~60 min during Wave 2A** — root cause: producing reflective content as assistant-text. Discovered via heartbeat-ping.
2. **Real-time during session-4 close retro:** world-builder-p3s2's response to the retro prompt referenced "my text response above" and sent only a 4-bullet summary via SendMessage. The full 4-paragraph reflection existed only as assistant-text, invisible to lead. Lead re-pinged with explicit "resend full content via SendMessage."

**Heartbeat protocol (recovery mechanism).** When an agent's SendMessage channel has been silent for >30 minutes AND their task is not explicitly marked `polling` / `waiting-on-external`, lead sends a `[heartbeat]` ping. Agent's obligated response: SendMessage back within their next tool-use cycle in one of three bracketed forms: `[heartbeat-ack: working]` / `[heartbeat-ack: blocked]` / `[heartbeat-ack: done]`. **Detailed protocol in §12.6.** Three-strike escalation: two unanswered heartbeats = lead presumes channel-mismatch failure.

Cites Manifesto Principle 1 (Truth-Seeking — invisible content is unobservable) and Principle 9 (Automated Enforcement — rules in agent-defs bind every dispatch).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4; canonical heartbeat protocol: §12.6]

---

### §9.H — Cross-Cutting Verification

> **Boundary note (H vs I).** Cluster H is **reviewer-discipline for cross-cutting consequences** of new schema/classification surfaces (does code-review + test-design + test-coverage triangulate?). Cluster I is **engine-API-dependent architecture claims** (does the engine actually behave as our spec assumes?). When a rule straddles both: default to **I if engine-API-dependent**, **H if reviewer-discipline for test-coverage or schema verification**.

#### H1. Cross-cutting schema verification — triangulated rule covering three layers

**Rule.** When a wave introduces a new participant in a shared classification surface (new base class with `unit_id`/`team` duck-type, new SceneTree group membership, new entry in an input-handler dispatch chain, new autoload registry consumer), three complementary disciplines apply at wave-close BEFORE PR:

1. **Code-review (architecture-reviewer):** grep every existing consumer of the schema (`is_in_group(&"X")`, `has_method(&"Y")`, duck-type filters reading `unit_id`/`team`) and verify each handles the new participant correctly. Cite consumer `file:line` in the verdict. **BLOCKING.** New base classes are never local changes; they extend every duck-type filter in the project.
2. **Test-design (gameplay-systems):** ship cross-feature integration tests pairing the new participant with EVERY existing consumer surface (selection paths: click + double-click + box-select; dispatch paths: move + attack + gather + construct), each verifying correct INCLUSION or EXCLUSION. Per-feature tests pass; per-feature × existing-feature crossover catches the leak.
3. **Test-coverage disclosure (qa-engineer):** wave-close report includes a **"Headless blindspots: what live-test must cover that these tests cannot"** paragraph. Explicitly names (a) input-routing behavior the tests fake (GUI dispatch, sibling order, `_process` loop), (b) scene-topology assumptions the fixtures bypass (group membership, NavigationObstacle bake state), (c) any visual/rendering path not exercised. Makes the testing-vs-runtime boundary legible to the lead BEFORE live-test begins.

**Why.** Phase 3 session 1 surfaced BUG-08 / BUG-10 / BUG-11 at lead live-test despite the headless suite + reviewer trio approving. All three bugs were "new participant in shared classification surface" failures (Khaneh duck-type leaks into box-select; BPH sibling-order convention reversal; BuildPlacementHandler missing in dispatch). Three retro contributions converged on the same insight from different layers.

Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 10 (Feedback Cycle).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-14 post-Phase-3-session-1]

#### H2. Consumer-track integration verification — verify against the producer's current commit SHA, not the kickoff brief's quoted snippet

**Rule.** When a consuming track (UI consumer of a state-machine signal, AI consumer of a sim event, etc.) is dispatched against a kickoff brief that references another in-flight track's API surface, the consumer MUST verify against the producer's CURRENT shipped code at commit time — not the kickoff's quoted line. The brief is a starting hypothesis; the producer's actual file at the actual SHA is the truth-source.

**Operational form (4-step):**
1. Read the OTHER track's current file at its committed SHA (not the kickoff's quoted line).
2. Trace the lifecycle hook through the producer's emit/call site, not just the declaration.
3. Confirm the timing assumption from your code's POV (e.g., "is_complete fires at end of dwell" → verify by reading the producer's call sequence).
4. If timing/semantics drift from your kickoff brief, STOP and escalate before commit.

**Canonical incident.** Wave-1C ui-developer-p3s3 caught the `construction_finalized` integration gap by reading Track 1's `building.gd` at commit time and tracing the `is_complete` lifecycle through gp-sys-p3s3's actual implementation. The lead's kickoff §5 brief had described an `is_complete` hide-trigger pattern written against the pre-Track-1 lifecycle; Track 1's two-stage lifecycle had inverted the semantics. Without ui-developer's commit-time re-verification, the bug would have shipped and surfaced in live-test or worse.

Cites Manifesto Principle 1 (Truth-Seeking — verify against shipped reality) and Principle 7 (SSOT — the producer's shipped code is the source, not the brief's quotation).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3]

#### H3. First-exercise-of-dormant-schema integration verification — brief-time call-out + agent D9 self-check

*Sister rule to H1. H1 fires on **new shape** (new SceneTree group, new duck-type method, new base-class field). H3 fires on **new value in an existing shape** (first-non-zero value, first-occupant of a structured taxonomy slot, first-wiring of a schema-present-but-callsite-absent integration path). Both are cross-cutting integration risks; they manifest differently and need different reviewer lenses.*

**Rule.** When a wave **first-exercises a previously-dormant** schema field, integration path, or taxonomy slot — i.e., the surface has shipped for N waves with default/empty state and a new participant in this wave is the first to populate it with a non-trivial value — the wave-brief AND the agent's D9 walkthrough BOTH carry an explicit cross-track integration verification step.

**Trigger conditions (any one fires the rule):**
1. New building/unit/feature configures a BalanceData/schema field that has existed since an earlier wave but has been zero/default/empty across all prior subclasses (e.g., BUG-A: `grain_cost = 50` on Atashkadeh when all 4 prior buildings had `grain_cost = 0`).
2. New participant fills a previously-empty slot in a structured taxonomy (e.g., 4th anchor-category variant completing the Iran-Tier-1 anchor-category roster at first-instance).
3. A previously schema-present-but-never-populated integration path (signal, autoload-registry, lifecycle hook) is first-wired by this wave.

**Two-layer intervention (brief-time + D9-time):**

- **Brief-time (lead's responsibility, pre-dispatch).** When the wave-brief asserts the existence or wiring of cross-cutting infrastructure that has been dormant before this wave, lead includes a "dormant-schema first-exercise" call-out section in the brief identifying (a) the dormant surface being first-exercised, (b) every consumer file the new value flows through, (c) which **named agent** owns the cross-track verification for that surface. No implicit hand-offs; cross-track integration gets a name.
- **D9 Step 3 self-check (every agent's responsibility, pre-commit).** Each agent's D9 walkthrough self-asks: *"Does my work first-exercise a previously-dormant schema field, integration path, or taxonomy slot? If yes, what cross-track verification did I do?"* The honest answer "no cross-track verification" is to escalate before commit, not to ship.

**Relationship to L6.** H3 is the **trigger condition** (first-exercise-of-dormant); L6 is the **action shape** (sweep all callsites matching the field's read pattern in the same commit that first-populates the field). H3 fires the alarm; L6 names what to do about it.

**Canonical incident.** Wave 2A.5 BUG-A — Atashkadeh first building with `grain_cost > 0` (all 4 prior buildings had `grain_cost = 0`). `BuildingStats.grain_cost` schema field had existed since Phase 2; the grain-deduction codepath in `UnitState_Constructing` had never been exercised. The lead's brief asserted "grain deducted at placement time in UnitState_Constructing (gp-sys's atashkadeh entry)" — claim was structurally false because `_resolve_cost_grain` didn't exist. Each per-agent D9 walkthrough was clean within scope; the seam between scopes was nobody's named responsibility. Bug surfaced at lead live-test; fix at `dfa9a33` added both-or-neither affordability + grain deduction wiring + 3 regression tests. **Five-agent retro (session-5 close) converged independently on this rule shape; none said "lead's fault" — all framed it as "missing-rule failure, not existing-rule failure."**

**Convergent retro evidence (session-5 close, five persistent agents, independent angles):**
- gp-sys-p3s3: "H1 sub-check refinement — when a new building type configures a field schema-present-but-never-populated, trigger explicit cross-cutting-callsite audit"
- world-builder-p3s2: "first-non-zero-value alarm + two-layer/three-layer defense theory" (brief-names-risk + agent-def-carries-pattern + Step-2-puts-live-example)
- balance-engineer-p3s3: "dual-field coexistence pattern + brief-authoring-time intervention point"
- ui-developer-p3s3: "first-exercise of dormant schema/contract surface never previously exercised" + verb-claim grep sub-step (operationalized in D9 Step 2 sub-step)
- loremaster-p3s5: "first-exercise of dormant schema / integration path / taxonomy slot" + parallel taxonomy-completion-event surface (anchor-category roster Iran-Tier-1 completed at Atashkadeh = first-exercise event in J-cluster, parallel to BUG-A's first-exercise event in schema-cluster)

Five independent angles, same trigger shape, same intervention layers. The convergence-without-pre-framing was itself a process validation (see Test 2 + meta-process discipline in §9.K).

Cites Manifesto Principle 1 (Truth-Seeking — verify that dormant infrastructure actually exists before consuming it) + Principle 6 (Partnership — cross-track seams need named owners, not implicit hand-offs) + Principle 10 (Feedback Cycle — first-exercise events are the cheapest moment to discover gaps; live-test is the most expensive).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-21 session-5 close]

---

### §9.I — Engine-Feature Verification

#### I1. Engine-feature runtime verification — enumerate API defaults at every step in the call chain

**Rule.** For any Godot-API-dependent (or library / OS-API-dependent) architecture claim, the spike's verification phase MUST enumerate API defaults at every step in the call chain — not just the API surface. Probe artifacts (binary symbol grep, headless test result, minimal-repro, or docs citation with verbatim quote + page-section reference) MUST be cited inline with the prescription.

**Operational form for engine-architect's spike reports.** §1.3 "adjacent-code verification" phase splits into:
- **§1.3a** — call-site verification — what calls the API, what does the call shape look like.
- **§1.3b** — API-default enumeration — what is the default value of every flag/property at every layer of the call chain, with verbatim citation to docs or source.

**Why.** "Verified by docs" without artifact reference is the trap that cost this project four round-trips on a single engine-feature claim (NavigationObstacle3D / `affect_navigation_mesh` vs `carve_navigation_mesh` vs manual `bake_navigation_mesh()` vs `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`).

Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 9 (Automated Enforcement — discipline binds via mandatory probe artifacts, not via care).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 engine-feature-verification cluster]

#### I2. Research-discipline sequence — external research is a first-class verification tool, not an escalation path

**Rule.** For any engine/library/OS-behavior claim, the verification sequence is:

1. **Official docs lookup** — read the canonical class/API reference + the tutorial page for the use case.
2. **GitHub source/issues/proposals search** — the engine source code is queryable; proposals + issues tracker captures known gaps and design discussions.
3. **Community knowledge** — official forum threads, established tutorials, sample-project repos.
4. **ONLY THEN binary-symbol probing, minimal-repro probe scripts, or other empirical-bench techniques.**

**Why.** The canonical Godot 4.6 NavigationObstacle3D pattern was in the public tutorial the whole time. Four rounds of binary-symbol probing was ~90 minutes of cumulative diagnostic when ~5 minutes of docs reading at round 0 would have surfaced the dual-flag distinction + the no-auto-rebake reality + the `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` default. The probing technique is correct discipline; the SEQUENCING is what's new — research before probing, every time.

Cites Manifesto Principle 1 (Truth-Seeking — the cheapest reliable evidence comes first) and Principle 4 (Lean Iteration — five minutes of reading saves 90 minutes of probing).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 engine-feature-verification cluster]

#### I3. Spike-scope discipline — N=2 round threshold for scope reevaluation

**Rule.** When a spike's implementation has spiraled past N=2 rounds of "ship → live-test → fail → re-diagnose," the lead MUST pause and reevaluate scope. The original wave's other deliverables should not be held hostage by a single hard problem. Punt to a dedicated wave with proper time budget. **Honest archaeology + diagnostic carry-forward is more valuable than aspirational implementation that doesn't close.** The dedicated wave inherits the rounds-of-diagnostic state as starting-from-N rather than starting-from-zero.

**Why.** Wave 1C navmesh hit N=4 rounds before lead made the option-B punt decision (2026-05-17). The wave's three working tracks (construction-timer, UI progress bar, placement validity) were structurally complete after Track 1's commits but the wave didn't close because the navmesh sub-track held it hostage. The honest-archaeology framing (`docs/WAVE_1C_NAVMESH_SPIKE.md` v0.2.0 + RNC §3.2 v1.3.2 + ARCHITECTURE §7 L25/L26) is the canonical artifact shape — empirical state, hypothesis surface, mechanism candidates, attribution per round.

Cites Manifesto Principle 4 (Lean Iteration) and Principle 10 (Feedback Cycle — the loop only closes if you let it close).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 engine-feature-verification cluster]

---

### §9.J — Cultural / Loremaster Discipline

> **Organizing claim for this cluster (added 2026-05-22 session-6 close, loremaster-p3s5 framing):** *"A loremaster cultural-claim that asserts X about the shipped mechanic is a load-bearing contract on X's implementation. Verify-at-HEAD before dispatch close, not at live-test."* Three waves of empirical validation (2A.5 Atashkadeh / 2B Sowari + Tirandazi / 2B Track 5 taxonomy doc) confirm the pattern: cultural-truth-claim → implicit mechanical assertion → either verified at HEAD pre-dispatch OR surfaces at live-test. The pre-verification path is meaningfully cheaper than the live-test path. The H3 (cluster H) + J4-refined-triples (this cluster) disciplines exist precisely to make pre-verification the default routing.

#### J1. Brief-time review formalization — when fires vs when doesn't

**Rule (decision):**
- **Brief-time review FIRES when** a wave will produce the FIRST INSTANCE of a culturally-load-bearing template OR template-VARIANT. Examples: first abstract base-class header (Building base → cross-faction caveat convention); first concrete subclass (Khaneh → civic-anchor template); first variant of an existing template-family (Ma'dan → labor-organization variant); first faction's first unit / building (when Turan economy ships → Turan baseline template); first cultural-emitter (Atashkadeh → sacral-emitter variant).
- **Brief-time review does NOT fire when** a wave clones an established template-variant for a sibling building (e.g., a fourth civic-anchor building cloning Khaneh/Mazra'eh) — that case ships as wave-close-only.
- **Lead's call at wave-design time which dispatch shape applies.** Default-fire when in doubt; the brief-time-review cost is one extra SendMessage round-trip; the wave-close-only cost when a fix is needed is one + potentially-many follow-up commits.

**Empirical baseline:** Mazra'eh-as-first-civic-anchor-clone validated brief-time-review's existence in wave 1A; Ma'dan-as-first-labor-organization-variant validated the variant-detection benefit in wave 1B; Sarbaz-khaneh-as-first-identity-bearing-institutional-anchor validated again in wave 2A.

Cites Manifesto Principle 4 (Lean Iteration — compressing the wave-close fix loop), Principle 6 (Partnership — three-party loop: lead asks → loremaster framing → specialist writes with citation).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2]

#### J2. Anchor-category trichotomy — canonical classifier for new Building subclasses

**Rule.** When a new Building subclass enters brief-time review, the loremaster classifies the wave's anchor-category outcome as exactly one of three: **(a) clone-check** (same anchor-category + same sub-slot as an existing building; verify the clone is faithful to the established template), **(b) slot-fit-verify** (same anchor-category + fills a predicted-empty sub-slot; verify slot-fit per the prediction), or **(c) taxonomy-growth-required** (mechanical shape OR cultural register structurally distinct from all enumerated categories; demands a new anchor-category and routes via NEEDS-DESIGN-CHAT verdict). The classification is named at brief-time AND drives the rest of the review: each outcome routes to a different verification shape (faithful-clone audit / slot-fit-prediction audit / new-category proposal with template-shape sketch). Enumeration + sub-slot taxonomy + per-variant template-shape spec + decision-flow diagram live in [`docs/ANCHOR_CATEGORY_TAXONOMY.md`](ANCHOR_CATEGORY_TAXONOMY.md) §1 + §2 (SSOT per §9.C1; the enumeration cannot live in two places).

**Actor / trigger.**
- **Lead at brief-drafting time** — pre-classifies the expected outcome in the kickoff brief (lead's working hypothesis; subject to loremaster validation). For clone-check candidates, the lead names the classification explicitly per §9.J1 (clone-check waves ship without brief-time loremaster review; the classification is the lead's call). For slot-fit-verify or taxonomy-growth-required candidates, lead dispatches the loremaster at brief-time.
- **Loremaster at brief-time review** — validates or refines the lead's classification, then produces the verification shape appropriate to the locked outcome. If the loremaster reclassifies (lead pre-assigned (a) but loremaster lands (b) or (c)), the new classification is authoritative.

**Why this matters.** Variant misclassification at brief-time is the highest-value cultural-drift risk to catch — it locks the wrong cultural-note template into the building's `.gd` header, which then propagates to every future clone of that building's sub-slot. The trichotomy forces the question to be answered *explicitly* rather than collapsing silently into "same as the prior building" or "this needs a new framing somehow." Each named outcome has a distinct verification shape; without the classifier, the loremaster's brief-time review has no canonical procedure.

**Empirical exhibits across waves (3-of-3 outcomes empirically produced as of Throne wave, 2026-05-22).** Sub-slot citations point at `docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.1.0 §4 building-assignment tables.

- **(a) clone-check — N=0 Iran-side as of v1.1.0.** No Iran building has yet shipped as a faithful clone of an existing anchor-category + sub-slot. Every Iran Tier-1 building so far has either filled a predicted-empty sub-slot or grown the taxonomy. First clone-check exhibit is expected post-MVP (Turan economy may surface clones within Turan-specific anchor-categories once those exist; Phase 4+ Iran buildings may clone existing sub-slots).
- **(b) slot-fit-verify — N=2, both at Wave 2B Track 0 (2026-05-21).** **Sowari-khaneh** filled the predicted-empty *cavalry-tradition* sub-slot + **Tirandazi** filled the predicted-empty *archery-tradition* sub-slot, both under the identity-bearing institutional anchor-category established by Sarbaz-khaneh at Wave 2A. Sub-slot axis: military-arm. Naming-shape divergence (Tirandazi's *-dazi* "practice" vs *-khaneh* "house") was correctly classified as surface-language, NOT anchor-shape divergence — directly because the trichotomy forced the explicit question.
- **(c) taxonomy-growth-required — N=3 across waves.** **Ma'dan** at Wave 1B (2026-05-15) established *labor-organization* as the second anchor-category (lead's brief initially framed civic-anchor; loremaster routed to taxonomy-growth-required with citation to Pishdadian triad). **Atashkadeh** at Wave 2A.5 (2026-05-18) established *sacral-emitter / divine-source* as the fourth anchor-category (passive-emit mechanical shape structurally distinct from prior three). **Throne** at Wave-3-Throne (2026-05-22) established *sovereignty-bearing institution* as the fifth anchor-category (singular per faction + terminal-stakes + IDropoffTarget + tier-progression via conversion-not-replacement — structurally distinct from all four prior categories; mirror-reviewer C3.1 correctly flagged lead's civic-anchor pre-assignment as mismatched). This is the third taxonomy-growth-required outcome and the empirical proof that the trichotomy is well-shaped — the (c) branch produces real category growth when fired, not just bookkeeping.

**Operational form (canonical decision flow).** From `docs/ANCHOR_CATEGORY_TAXONOMY.md` §2:

```
Brief introduces new Building subclass
    │
    ├─ Same anchor-category + same sub-slot as an existing building?  ──── YES ──► (a) clone-check
    │                                                                              verify faithful clone
    │                                                                              (no brief-time review fire per §9.J1)
    │
    ├─ Same anchor-category + predicted-empty sub-slot?                ──── YES ──► (b) slot-fit-verify
    │                                                                              verify slot-fit per prediction
    │                                                                              (loremaster brief-time review fires)
    │
    └─ Mechanical shape OR cultural register structurally distinct?    ──── YES ──► (c) taxonomy-growth-required
                                                                                   NEEDS-DESIGN-CHAT verdict
                                                                                   (loremaster proposes new category;
                                                                                    routes via design-chat ratification
                                                                                    before specialist tracks dispatch)
```

The decision is sequential: clone-check is checked first (cheapest verification), slot-fit-verify second (moderate), taxonomy-growth-required last (highest cost, routes via design-chat). If none of the three branches fire cleanly, the loremaster surfaces the ambiguity to lead before dispatch close — a brief-time review CANNOT exit without a locked classification.

**Coordination with §9.J1.** Brief-time loremaster review fires per §9.J1 for slot-fit-verify and taxonomy-growth-required outcomes only. Clone-check outcomes ship without brief-time loremaster fire — the lead's kickoff brief explicitly names the (a) classification, and wave-close review verifies the clone-fidelity. This preserves §9.J1's "do not fire for clones" rule while closing the classifier-completeness gap that the watchlist version left open (clone-check is *named at lead's brief-drafting time* rather than implicit-by-omission).

**Open question.** Turan economy will likely default-fire (c) taxonomy-growth-required at the first Turan building brief-time per the structural-mismatch hypothesis articulated in [`docs/ANCHOR_CATEGORY_TAXONOMY.md`](ANCHOR_CATEGORY_TAXONOMY.md) §5. Exception: sovereignty-bearing institution is the ONE anchor-category that applies cross-faction symmetrically — Turan's Throne ships as a slot-fit-verify clone of the Iran Throne template, not as taxonomy-growth (different team-id + visual accent + cultural-register prose, same `throne.gd` extends). This NEAR-SYMMETRY exception is the only known Turan slot-fit-verify candidate at the anchor-category-discovery moment.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2 (J2 introduced as enumeration rule); 2026-05-21 session-5 close (trichotomy added as watchlist refinement, N=1); 2026-05-21 Wave 2B Track 5 `18e3f34` (enumeration extracted to ANCHOR_CATEGORY_TAXONOMY.md v1.0.0; N=2 at Wave 2B Track 0 with Sowari-khaneh + Tirandazi slot-fit-verify); 2026-05-22 Wave-3-Throne Track 4 `d59b771` (3-of-3 trichotomy outcome empirically produced via Throne's taxonomy-growth-required → sovereignty-bearing institution at ANCHOR_CATEGORY_TAXONOMY.md v1.1.0; J2 graduates from watchlist to active rule at session-8 close retro)]

#### J3. Literal-then-tricky-gloss discipline (Persian-term Pattern)

**Rule.** When a Persian term has a known false-friend English gloss carrying unwanted connotations (modern industrial, feudal, Abrahamic, etc.), lead with the corrective literal, then frame the tricky gloss as such. Preserves accuracy at first-reader contact while acknowledging the dictionary-default reading.

**Canonical applications:**
- *dehqan* — "landed cultivator" (lead) avoiding "lord of the village" (feudal-aristocratic baggage).
- *ma'dan* — "ore-source / generative place" (lead) avoiding "mine" (industrial-revolution baggage).
- *sarbaz* — "head-staked" / "one who pledges their head" (etymological) avoiding "soldier" (modern-military baggage).

**Watch list (future Persian terms with English false friends):**
- *shah* — "king" loses Farr-legitimized political theology
- *pahlavan* — "knight" loses heroic-champion register
- *div* — "demon" loses Iranian mythological category (anti-Yazata, not fallen angel)
- *farr* — "glory" loses legitimizing-political-theology layer
- *sepah* — "army" loses institutional layer Sarbaz-khaneh inherits

**Watchlist refinement (loremaster-p3s5 session-5 close, N=1 — awaiting N=3 trigger).** Watchlist entries annotate **baggage-intensity** (high / medium / low):
- **High** — tricky-gloss must be corrected explicitly in-prose. Examples: *atashkadeh* (Abrahamic congregation-space baggage on "fire temple"), *ma'dan* (industrial-revolution baggage on "mine").
- **Medium** — tricky-gloss should be noted parenthetically. Examples: *sarbaz* (register-loss to "soldier" but not actively misleading).
- **Low** — literal preferred but gloss acceptable.

Annotations sharpen the block's framing without expanding the rule's scope. Currently a single agent's proposal; needs N=3 to graduate to active.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2; watchlist refinement added 2026-05-21 session-5 close]

#### J4. Intent-vs-implementation split for cultural / non-technical claims — claim → mechanism → reviewer triples

**Rule.** When a non-technical reviewer (loremaster, balance-engineer, ai-engineer in design-mode review) makes a verdict that depends on a specific mechanical / technical behavior, the verdict must distinguish (a) "the framing aligns with STATED INTENT" — within the non-technical reviewer's lane — from (b) "the framing aligns with SHIPPED BEHAVIOR" — typically requires technical verification outside the non-technical reviewer's lane. The non-technical reviewer approves (a) when justified and DEFERS (b) explicitly to the technical reviewers (engine-architect, godot-code-reviewer, architecture-reviewer) rather than implicitly endorsing both.

**Refinement (session-5 close): claim → mechanism → reviewer triples.** When a cultural / non-technical block makes ANY claim that depends on mechanical behavior, the block-author enumerates each claim as a structured triple: `<cultural assertion> → <list of mechanical dependencies> → <named reviewer(s) for each>`. **This replaces the single "defer mechanical to technical" sentence with a structured checklist that surfaces ALL the mechanical dependencies the cultural-claim rests on — not just the ONE the author noticed.** The single-sentence form is one author asserting one thing; the structured triples surface the full dependency graph.

**Example (Atashkadeh, what the refinement produces):**

> *"Atashkadeh emits +1 Farr/min CONTINUOUSLY while standing"*
> → depends on: (a) FarrSystem registration [engine-architect], (b) per-tick emit pattern [gp-sys], (c) Stage-2 flip [gp-sys], (d) BalanceData entry [balance-engineer].
>
> *"150 coin, 50 grain cost honoring institutional weight"*
> → depends on: (e) coin deduction wiring [gp-sys], (f) grain deduction wiring [gp-sys], (g) BalanceData cost entry [balance-engineer].
>
> *"Tier-1→Tier-2 gateway anchors theologically before scaling"*
> → depends on: (h) tier-up gate reading Atashkadeh-built state [gp-sys/balance-engineer], (i) Farr threshold check [Phase-4 scope].

**Why structured triples matter.** The cultural-truth-claim is a **load-bearing contract on the implementation**, not narrative voice-over. When the loremaster writes "the mechanic IS the theology," they are asserting that the shipped mechanic will reflect the named theology. Partial mechanic = partial theology = the cultural-claim has been over-promised at brief-time. The triples checklist surfaces every mechanical surface the cultural-claim rests on, so each gets routed to a named reviewer instead of trusted-as-implicit-existing.

**Trigger.** Mandatory at brief-time cultural review for any new building / unit / hero whose cultural-claim asserts mechanical behavior. The loremaster's brief-time output INCLUDES the triples checklist; lead routes each triple's reviewer per the named owners.

**Canonical incident (original).** Phase 3 session 2 wave 1B — loremaster's APPROVE praised RNC §4.7.5's "navmesh-obstacle reinforces cultural framing" as "form-follows-source at the engine layer." Engine-architect's later live-test investigation surfaced the mechanical half is INERT (NavigationObstacle3D radius-only mode doesn't affect `NavigationServer3D.map_get_path` queries). The cultural CATEGORY distinction (labor-organization vs civic-anchor frame) holds independently; the "form-follows-source" alignment was overweighted because it depended on mechanical behavior loremaster couldn't verify directly. The honest verdict would have been: *"cultural framing aligns with stated intent; defer mechanical verification to engine-architect."*

**Canonical incident (refinement, session-5 close).** Wave 2A.5 — loremaster-p3s5's cultural-claim "the mechanic IS the theology, not a metaphor laid over it" implicitly rested on FOUR mechanical surfaces (FarrSystem registration, per-tick emit, Stage-2 flip, grain-deduction wiring). J4-as-originally-written deferred ONE (FarrSystem) explicitly via the Phase-4 deferred note; the other three were trusted as implicit-existing. The grain-deduction surface was the one that didn't exist (BUG-A). **The triples checklist refinement would have surfaced all four at brief-time**, with grain-deduction routed to gp-sys with an explicit verification ask — closing the exact gap BUG-A occupied.

**Watchlist (loremaster-p3s5 session-5 close, N=1 — awaiting N=3 trigger).** Loremaster brief-time review output additionally includes a **"player-visible cultural-claim surfaces"** sub-section identifying strings.csv rows / tooltip text / HUD labels that should carry the cultural framing. Currently the cultural framing lives in the `.gd` header comment — visible to future loremasters and code-reviewers, NOT to players. For the project's stated bilingual-UI ambition (00_SHAHNAMEH_RESEARCH.md §303 *"this will mean the world to the Iranian diaspora audience"*), player-visible surfaces are where the cultural-claim actually meets the audience. Currently a single agent's proposal; needs N=3 to graduate to active.

Cites Manifesto Principle 1 (Truth-Seeking — verify before endorsing alignment) + Principle 6 (Partnership — named reviewers for named dependencies; no implicit hand-offs).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2; claim→mechanism→reviewer triples refinement + player-visible-surfaces watchlist added 2026-05-21 session-5 close]

#### J5. Side-quest research dispatch — wave-decoupled, multi-wave-informing loremaster research (N=2 watchlist, N=3 graduation pending)

**Status.** N=2 watchlist — NOT yet an active rule. Two exhibits to date; codification candidate awaiting a third instance per the J-cluster graduation discipline.

**Actor.** Lead dispatches; loremaster produces; downstream wave briefs consume.

**Trigger.** A design-chat decision is anticipated multiple waves out AND benefits from substantive Shahnameh-or-historical research that doesn't fit cleanly into a wave's brief-time review slot. Distinguishing test: *"does the research output have to be true by the wave's close, or can it inform multiple waves?"* If "informs multiple future decisions" → side-quest dispatch.

**Distinguishing from existing loremaster dispatch modes:**

| Mode | Coupling | Timing | Deliverable |
|---|---|---|---|
| **Brief-time review (§9.J1 + J2)** | Wave-coupled | Fires before tracks dispatch; blocks track-dispatch on verdict | Paste-ready prose at Commit 1.5 + J2 classification + J4 triples |
| **Wave-close culture-paste (Commit 1.5 pattern)** | Wave-coupled | Wave-final; lead pastes verbatim into headers | Cultural-note addendum prose for the wave's deliverable |
| **Side-quest research dispatch (§9.J5)** | Wave-DECOUPLED | Parallel to in-flight wave work; no timeline pressure | `docs/*_RESEARCH.md` standalone artifact (~200-500 lines) referenceable by future briefs |

**Rule (proposed, pending N=3 graduation).** Lead dispatches a loremaster side-quest when:

1. Design-chat is considering a positioning bet that benefits from Shahnameh/historical-economic/cultural research deeper than a 30-45 min brief-time review can produce.
2. The output will inform DECISIONS multiple waves downstream (not just the next wave's brief).
3. The lead is NOT under time pressure for the output to land at a specific moment.

**Dispatch shape.** Lead sends a structured research question via SendMessage to the persistent loremaster instance:

```markdown
**Side-quest research dispatch: <topic>**

Wave context: <which design-chat decision the research informs; which wave(s) will consume>
Time budget: NO TIMELINE PRESSURE. Take the time the question deserves.
Output shape: Your call — typically a docs/<topic>_RESEARCH.md doc, 200-500 lines.

Six explicit sub-questions to anchor the research:
1. <substantive question 1>
2. <substantive question 2>
... (etc.)

J4 honest-confidence-disclosure (mandatory): where is your source-material competence
high vs lower? Surface any compression-flags or anachronism-risks explicitly per
the J4 slot-creating-rule discipline.
```

**Why this works (loremaster-p3s5 reflection 2026-05-28).** *"The deliverable (451-line research doc) was substantive, fed design-chat decisions, but didn't block any wave. The dispatch hit at a moment when the design-chat was actively considering a positioning bet (Trade & Transport economy thesis); the research timed-into the decision window. The dispatch slot — 'parallel research, no timeline pressure' — produced better thinking precisely because the time-pressure-shape was right for the cognitive task."*

**N=2 exhibits.**

1. **Session 6 (2026-05-23).** `docs/SHAHNAMEH_ECONOMIC_RESOURCES_RESEARCH.md` — "5 central economic resources of ancient Iran." Side-quest research feeding Phase 3+ resource-modeling decisions. ~Task #180 reference.

2. **Session 9 (2026-05-25).** `docs/SHAHNAMEH_ECONOMY_RESEARCH.md` (commit `07261a4`) — Trade & Transport economy thesis cross-check. ~451 lines. Top-line: T&T thesis HOLDS + is MORE culturally honest than SC2-derived "everything goes to central HQ" pattern. Two refinements (upkeep-as-royal-largesse / down-flow; royal largesse missing from current framing) + Q6.3 dehqan-compression lower-confidence flag + Bizhan-Manizheh as canonical caravan-mechanic narrative anchor.

**N=3 graduation criteria.**

- A third side-quest dispatch with the same shape (wave-decoupled, multi-wave-informing, standalone `_RESEARCH.md` artifact) lands.
- Down-stream consumption verified: at least one future wave brief explicitly cites the research doc as input to its design.
- Loremaster confirms the dispatch pattern still feels right (vs. tugging back toward wave-coupled review).

Once N=3 graduation lands, this watchlist entry is promoted to a full rule with:
- Explicit "when to dispatch side-quest vs. fold into brief" decision heuristic.
- Operational form for the dispatch message + the research doc structure.
- Cross-references to §9.J1/J2/J4 (the wave-coupled siblings).

**Why watchlist rather than premature rule (J4 discipline).** Loremaster-p3s5 reflection 2026-05-28: *"Honest J4 caveat on this refinement: I'm not entirely sure the protocol-role-level extension is generative or just structurally-similar pattern I noticed. The N=2/N=3 evidence threshold is exactly the discipline for distinguishing those two cases. Keeping it on watchlist rather than promoting prematurely is the right call."* The J-cluster's N=3 graduation criterion is itself the project's slot-creating-rule discipline that the dispatch pattern would benefit from honoring.

**Forward-watch surfaces.** Phase 4+ entry will likely surface the third instance — either Trade & Transport caravan-mechanic-specific research, or a sacral-emitter ConsecratedTarget protocol research, or an Atashkadeh + FarrSystem coupling research.

Cites Manifesto Principle 4 (Lean Iteration — parallel research without timeline pressure produces better thinking than time-budgeted brief-time review for substantive questions) + Principle 1 (Truth-Seeking — substantive research artifacts > compressed brief-time hot-takes for multi-wave-informing design questions).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; loremaster-p3s5 retro reflection (N=2 watchlist proposal) + N=2 exhibits → lead codification as watchlist entry]

#### J6. Loremaster-light wave routing — brief-time fire IF AND ONLY IF the brief contains a cultural-shape-question; implementation + retro dispatch skipped

**Rule.** For waves that are predominantly plumbing / infrastructure / refactor (no new building shipped, no new unit shipped, no Farr/Kaveh/narrative event triggered, no anchor-category-classifiable surface), loremaster dispatch routes as follows:
- **Brief-time:** fire loremaster IFF the brief contains a cultural-shape-question (e.g., "how should X resolve culturally?", "what's the canonical Shahnameh stance on Y?", "does Z map to a documented loremaster taxonomy entry?"). One question is sufficient to trigger; zero questions = skip.
- **Implementation-time:** skip (no cultural surface for loremaster to engage with).
- **Retro-time:** skip OR light-touch (~10-20 min single-question reflection rather than the full multi-prompt format). Light-touch is performative if there's no signal; honest "no signal this session" is fine.

**Actor.** Lead at brief-dispatch and retro-dispatch decision points.

**Trigger.** Brief is "loremaster-light" by composition:
- No new Building subclass (anchor-category J2 trigger absent).
- No new Unit subclass (cultural-anchor-classification trigger absent).
- No new Farr / Kaveh / narrative-event mechanic.
- No new contract requiring J4 intent-vs-implementation triple.

OR the brief contains a single cultural-shape-question and otherwise no cultural surface.

**Why (Wave 3-Sim, session 10):**

Wave 3-Sim was 95% plumbing (headless runner + batch script + Python aggregator + NDJSON schema). The ONLY cultural touchpoint was the Q1 win-condition cultural-shape-question (match-time vs narrative-time framing for throne-destruction). Loremaster fire at brief-time was warranted (Q1 needed the Shahnameh-canonical answer). Loremaster fire at implementation-time would have been performative (nothing to engage with). Loremaster fire at retro-time would have produced "no signal this session" reflections if forced full-format; the light-touch retro dispatch (3-prompt, ~10-20 min, "answer what you have signal on, skip the rest") was the right shape.

Loremaster-p3s5's session-10 retro reflection confirmed: *"Plumbing waves like Wave 3-Sim shouldn't dispatch loremaster at implementation-time or retro-time — that would be performative; nothing to reflect on past the brief-time verdict. But the dispatch you sent for Q1 was correct — brief-time loremaster fire was warranted there, even on a plumbing wave, because the cultural question (when does a kingdom end?) was load-bearing for the implementation choice. The pattern that fits: brief-time loremaster fire when a plumbing wave has cultural-shape-question, even one question; skip implementation + retro otherwise."*

**Distinguishes from J1 (brief-time review formalization).** J1 specifies WHEN loremaster brief-time review fires for cultural-anchor waves (new Building / Unit / Farr surface). J6 covers the LEFT-OUT case: plumbing waves with a SINGLE cultural-shape-question. J1 + J6 together cover the full triage matrix:
- **Cultural-anchor wave** (J1 fires): brief-time + maybe implementation + retro.
- **Plumbing wave with cultural-shape-question** (J6 fires): brief-time only (sized to the question).
- **Pure-plumbing wave** (neither fires): skip all loremaster dispatch.

**The "cultural-shape-question" trigger.** A question whose answer requires Shahnameh-canonical knowledge, not engineering judgment. Examples:
- "When does a kingdom end? (immediate throne-fall vs narrative succession-continuation)" — Wave 3-Sim Q1.
- "Should X map to a documented J2 anchor-category, and which?"
- "Does the player's Y action have a Shahnameh precedent we should preserve?"
- "What's the canonical-Persian-term mapping for concept Z?" (When the brief proposes a Persian term without citation.)

Engineering questions ("which data structure for the unit list?") and balance questions ("how much HP should X have?") are NOT cultural-shape-questions, even if they have downstream cultural-feel impact.

**Where reviewers enforce.**

- **Lead at brief-drafting**: explicit triage — is this a cultural-anchor wave (J1), a plumbing-with-cultural-question wave (J6), or pure-plumbing (skip)? Brief should make the determination visible.
- **Mirror-reviewer brief-time review**: verifies the triage is honest. Brief that skips loremaster but contains a cultural-shape-question = SUGGEST. Brief that fires loremaster on pure-plumbing = SUGGEST (performative dispatch is its own anti-pattern; specialist time is finite).

**Where authors apply.**

- **Lead (brief author + retro dispatcher)**: applies the triage; sizes loremaster dispatch to the actual signal.
- **Loremaster (recipient)**: empowered to respond with "no signal this session" if the dispatch was performative. Honesty over volume.

**Anti-patterns to flag.**

- "Loremaster has been in every retro so we should dispatch them this time too" — performative consistency vs. signal-driven dispatch. The point of the role is signal-quality, not consistent participation count.
- "We might miss something cultural if we don't dispatch" — if there's no cultural surface, the miss is impossible. Trust the triage.
- "Better to dispatch and let loremaster decide" — that pushes the triage burden onto the loremaster; the lead is the dispatch-decision actor.

Cites Manifesto Principle 1 (Truth-Seeking — performative dispatch produces performative reflection; honest "no signal" is better) + Principle 4 (Lean Iteration — specialist time is finite; spend it where there's signal) + Principle 6 (Honest-tools-not-magic-tricks — "I dispatched everyone for completeness" is the magic-trick framing).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; loremaster-p3s5 retro reflection (light-touch wave-routing pattern + cultural-shape-question trigger) → lead codification. Companion to J1 (brief-time fire formalization for cultural-anchor waves).]

---

### §9.K — Retro Practice

#### K1. Session-close retro is structured, not optional — 5 mandatory steps

**Rule.** At the end of every implementation session (post-merge), lead executes a retro that does five things:

1. **Promote Pitfall candidates** — godot-code-reviewer's KEEP-recommended candidates move from Experiment 01 verdict text into the Known Godot Pitfalls list at the top of `PROCESS_EXPERIMENTS.md`. Each promoted entry: name, mechanism, rule, canonical incident commit, regression test reference.
2. **Update STUDIO_PROCESS §9** with new active rules.
3. **Promote architectural LATER items** from §6 entry prose into a structured `ARCHITECTURE.md` LATER section. Indexed and prioritized rather than scattered.
4. **Close / extend / open experiments** per their verdict criteria. Active experiments tagged in `PROCESS_EXPERIMENTS.md`; resolved ones move to the archive section.
5. **Draft the next session's kickoff doc** with the latest Known Pitfalls list verbatim, anti-loop brief language baked in, current Deviation count baseline, active Experiment list.

**Why.** Without a closure step, learnings rot. Pitfall candidates stay scattered in verdict text; experiment outcomes don't propagate to the next kickoff brief; LATER items live as comments in §6 entries instead of an indexed list. By session 5, you'd be re-discovering the same patterns. The retro is ~30 min of doc work and produces compounding returns.

Cites Manifesto Principle 10 (Feedback Cycle): *"every system has the right to demand its own improvement"* — the retro is how the system claims that right.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-04 post-Phase-2-session-1]

#### K2. Wave-close reports include a "What tripped me up in this wave" first-person section

**Rule.** Mandatory ~1-paragraph block on every wave-close report, written by the shipping agent BEFORE stand-down while context is still peak-fresh. Captures friction points, dead-ends, moments the agent almost shipped a bug, surprising semantics that consumed time.

**Why.** Retro-time specialist-agent dispatches are necessarily fresh instances reading post-hoc artifacts; subagents are ephemeral and the original's lived friction is lost when they stand down. The wave-close moment is the only window where in-the-moment friction is capturable. Without this section, retros can only do post-hoc review — never lived-experience aggregation.

**Status (2026-05-14 follow-up).** This is the LLM-system adaptation of the human-retro pattern "invite the people who did the work" (which can't translate verbatim because the people don't persist). The captured-at-shipping artifact substitutes for the can't-re-summon person. **In the persistent-default world (G1):** primary signal is "ask the agent who lived the wave; they remember." The "what tripped me up" section is BACKUP CAPTURE for when the persistent agent's context has rotated or when a specialist is rebooted.

Cites Manifesto Principle 10 (Feedback Cycle): every system has the right to demand its own improvement; capture the data while it's still data.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-14 post-Phase-3-session-1]

#### K3. Agent-def self-update verification — verify against ARCHITECTURE §7 + §6, not per-task subjective close

**Rule.** When an agent updates their own agent-def at retro time, the wave-outcome status MUST be verified against `ARCHITECTURE.md §7` (LATER ledger) + the wave-close `§6` entry, not against per-task-commit subjective close. Agent-defs reflect SYSTEM-LEVEL outcomes for the discipline they encode; per-task commits are subjective intermediates that may or may not represent system-level closure.

**Operational form for agent self-updates.** Before committing an agent-def edit at retro time, read ARCHITECTURE §7 (LATER status) + the wave-close §6 entry. If the discipline you're documenting references an L<N> issue, the agent-def MUST cite the L<N>'s current status accurately.

**Canonical incident.** Wave-1C retro — world-builder-p3s2 self-edited their agent-def with a closing section claiming *"Wave 1C closed L25 with a three-layer fix... The full causal chain is closed."* Each of the three layers WAS correctly shipped; world-builder's per-commit subjective close was accurate per-commit. But the SYSTEM-LEVEL outcome was option-B-punt (L25 deferred), not L25-closed. Lead corrected the section directly in the agent-def to align with ARCHITECTURE §7 L25's authoritative status.

Cites Manifesto Principle 1 (Truth-Seeking — observe the system-level outcome, not the per-task narrative) and Principle 7 (SSOT — ARCHITECTURE.md is the canonical truth-source for system-level state).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3]

---

### §9.L — Implementation Patterns

#### L1. Spec-wins-over-lead's-casual-reading, with citation-density corollary (multi-agent — active + passive triggers)

**Rule.** When a lead's brief or message contradicts the project's source-of-truth (CLAUDE.md, MANIFESTO.md, 01_CORE_MECHANICS.md, ARCHITECTURE.md, ratified contracts, DECISIONS.md, 00_SHAHNAMEH_RESEARCH.md), the persistent specialist applies the source-of-truth value AND flags the deviation explicitly with cited evidence. Source material wins per Manifesto Principle 7 (Single Source of Truth).

**Citation-density corollary.** The corrector must cite the source by file + section + line numbers (or passage equivalent) AND, where possible, quote one load-bearing sentence from the source. Citation-density matters more than confidence — the correction has to overcome lead-incumbency; reasoning without citation is just another voice.

**Multi-agent codification (session-6 close, N=5 instances across 2+ agents — pattern lifted from balance-engineer-particular to project-wide).** L1 has two trigger surfaces:

- **Active trigger (D9 Step 2 verification before commit, balance-engineer canonical shape):** specialist verifies spec/SSOT before consuming the brief, catches divergence at the agent's own deliverable surface, applies L1.
- **Passive trigger (spec-facing-text-writing, ui-developer canonical shape):** specialist surfaces divergence incidentally during their own work — e.g., writing a tooltip string against a spec citation reveals the spec/BalanceData number-mismatch.

**Scope (deliberately bounded).** L1 fires on each agent's *own active-verification surface* (D9 Step 2) + *passive catch in own work* (spec-facing writing). **NOT proactive cross-agent sweeping** — that's a scope violation that produces noise. Brief-time recommendations are starting points; each agent applies L1 to their own commits + flags divergences with citation. Lead synthesizes catches across agents at retro time.

**Canonical incidents (5 instances across Wave 2A.5 + Wave 2B):**
- Wave-1B balance-engineer's `coin_cost = 40` catch (cited 01_CORE_MECHANICS.md §5; lead's brief said 75).
- Wave-1B loremaster's Jamshid-Pishdadian-triad catch (00_SHAHNAMEH_RESEARCH.md §1 lines 86-88).
- Wave-2A balance-engineer's Atashkadeh-vs-Qal'eh §8 timing-citation catch.
- Wave-2A.5 balance-engineer's max_hp=600 retention (lead's brief mis-suggested 400).
- Wave-2B balance-engineer's construction_ticks=1080 ladder-defense (lead's brief said ~900).
- Wave-2B ui-developer's UI_BUILDING_* key-shape preservation (lead's brief suggested BUILDING_LABEL_*).
- Wave-2B ui-developer's Khaneh +5 spec-vs-BalanceData=10 divergence catch (surfaced 3-month-invisible spec/code divergence; closed at session-6 close retro by reverting BalanceData to spec value).

All applied citation-density discipline; lead accepted each override.

**Brief-time framing (lead's responsibility going forward).** Brief language SHOULD make L1 expectation explicit: *"Brief numbers / key shapes / conventions are starting points. Domain expert overrides with citation are expected; the brief recommendation is not a constraint."* Eliminates agent hesitation about whether to push back. For balance numbers specifically, see §9.L11 (brief-drafting balance-audit) — L11 is the origination-side discipline that prevents the round-trip L1 corrects at the receiving end.

Cites Manifesto Principle 1 (Truth-Seeking — evidence wins over incumbency) and Principle 7 (SSOT).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2; multi-agent codification + bounded-scope + brief-time-framing-recommendation added 2026-05-22 session-6 close retro]

#### L2. Distribution-discipline — ownership beats warmth (with mid-wave rebalance discipline)

**Rule.** When dispatching a task with a CLAUDE.md file-ownership domain owner, the persistent instance for that owner gets the work — even if a different persistent instance is warmer (more relevant carry-forward, faster turnaround). "Give it to your best / most active dev" is a classic human anti-pattern that lives equally in lead behavior with agents. Persistent agents amplify the trap because "warmest" becomes "the one whose context is most loaded with relevant memory." Cross-functional team with domain depth is the model; persistence ≠ engagement priority.

**Operational form (at dispatch time):** lead asks "what's the CLAUDE.md ownership domain for these files?" That answers WHO. "What's the warmest instance for this work?" answers WHEN (it's the tiebreaker, not the default).

**Mid-wave rebalance discipline.** When lead's initial dispatch violated ownership, rebalance to the rightful owner is done with explicit scenario-enumeration — the new owner's brief lists which scenarios are already-shipped vs scenarios-remaining, so the rebalanced agent doesn't re-do work or miss handoff state. Lead reads the prior agent's `git log` since dispatch + their last status message and produces the explicit delta.

**Canonical incident.** Phase 3 session 2 wave 1B distribution friction — lead initially assigned all 4 wave-1B implementation commits to gp-sys-p3s2 (warmest agent), corrected mid-wave by spawning qa-engineer-p3s2 for Commit 3 integration test per CLAUDE.md ownership. Friction: rebalance landed after gp-sys partial-shipped Commit 3 (`5a53108`); qa-engineer's `9ade2bd` filled remaining scenarios. The rebalance worked but mid-wave timing was suboptimal — at-dispatch ownership discipline prevents the friction.

Cites Manifesto Principle 6 (Partnership — distributing load preserves cross-agent context depth) + Principle 4 (Lean Iteration — explicit enumeration is cheap; ambiguity costs cycles).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2 distribution-discipline + mid-wave-rebalance]

#### L3. Scene-config-as-forward-investment — name the activating mechanism in the .tscn comment

**Rule.** When shipping inert scene config that depends on a downstream wave to activate (NavigationObstacle3D flags, signal connections, footprint vertices, mesh placeholders, etc.), the `.tscn` comment MUST cite (a) the dependent wave / task number AND (b) the specific mechanism that will fire it (which call, which signal, which bake trigger).

**Pre-commit checklist step 2.5:** "Is this config inert? If yes — name the activating mechanism. If the mechanism is in a later wave, cite it in the .tscn comment AND flag it in your message to lead."

**Why.** The 4-round wave-1C navmesh cycle was a chain of inert configurations that each looked structurally complete in isolation. The question "what actually triggers this?" was never asked until live-test failed. Naming the activating mechanism inline is the cheapest defense against the false-confidence-from-inert-config trap.

Cites Manifesto Principle 7 (SSOT — the activating mechanism's location should be discoverable from the config it activates).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3]

#### L4a. Super-call forward-compat discipline — every subclass override calls `super.<virtual>()` even when base is currently `pass`

**Actor.** Subclass author at subclass-authoring time.

**Trigger.** Authoring (or modifying) a subclass override of a base-class virtual hook (e.g., `_on_placement_complete`, `_on_construction_complete`, future `_on_<X>` virtuals on Building base or any other extension point with subclass overrides).

**Rule.** As the FIRST LINE of every subclass override of a base virtual, write `super.<virtual_name>(args)` — even when the base body is currently `pass`. This is **forward-compat defense** against the day the base virtual gains a non-trivial body: subclasses that called super from day-1 inherit the new base behavior for free; subclasses that omitted super-by-default need a sweep retrofit (see L4b) when the base body lands.

**Load-bearing artifact.** A 2-4 line comment bracketing the `super()` call explaining the future-failure-mode reasoning — NOT "added super" (a future reader will remove the "redundant" super) but "Forward-compat: when base `_on_X` gains non-trivial body, silent-missing super would lose the base behavior in this subclass." The comment is what makes the discipline survive code review years from now.

**Test pattern.** None today (base is `pass`); the behavioral test for super-call propagation lands when the base gains a non-trivial body (and L4b's sweep audit fires).

**Canonical incident.** Wave 2A Sarbaz-khaneh `8314a8a` — gp-sys authored Sarbaz-khaneh with `super()` calls in BOTH `_on_placement_complete` AND `_on_construction_complete` even though base `_on_construction_complete` was `pass`. The discipline applied at authoring time meant Sarbaz-khaneh did NOT need a retrofit when the session-4 sweep audit (L4b) fired against Mazra'eh + Ma'dan.

Cites Manifesto Principle 6 (Tests as Specifications — when behavior cannot be tested today, the comment carries the spec) + Principle 9 (Automated Enforcement — discipline applied at first authoring is cheaper than retrofit).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 implementation-pattern cluster]

#### L4b. Super-call sweep audit — base-class shipper sweeps subclasses in the SAME COMMIT that gives the virtual a non-trivial body

**Actor.** Base-class shipper at base-modification time.

**Two-part trigger condition:** (a) a base virtual that prior subclasses called (or could be expected to call) gains a non-trivial body in any wave — "non-trivial" = anything more than `pass`, even a single mutation, signal emit, or state-flip; (b) prior-shipped subclasses exist that override the virtual without `super.<virtual>()` (i.e., subclasses that did NOT follow L4a at authoring time).

**Action.** Same-commit sweep of ALL prior subclasses to add `super.<virtual_name>(args)` as the **first line** of their override. Bracket each retrofit with a 4-5 line comment carrying the **future-failure-mode reasoning** (per L4a — the comment is the load-bearing artifact, NOT the super call). **The retrofit landing commit is the originating wave's commit; when caught reactively post-merge, the fix-up commit is owned by the base-class shipper, not the subclass authors.**

**Audit command:** `git grep -n 'func _on_<virtual_name>' game/scripts/world/` to enumerate subclass overrides. For each enumerated subclass, verify `super.<virtual>()` is the first line of its override; if missing, add it in the same commit.

**Why this is the base-shipper's responsibility, not the subclass author's.** The subclass author may not know a base implementation was added in a separate commit on a different agent's branch. Silent missing super calls accumulate silently across waves. The proactive scan by the base shipper at the moment of base-body addition is the discipline; the reactive catch (post-merge reviewer) is luck.

**Canonical incidents:**
- **Origin (session-3 wave-1C `910bd9a`):** world-builder-p3s2 added `_on_placement_complete` rebake logic to Building base; all three subclasses (Khaneh, Mazra'eh, Ma'dan) had silent overrides with no super call. Caught reactively mid-wave but cleanly fixed in the same commit. Rule born.
- **Sharpened (session-4 wave-2A `128af9f`):** gp-sys retroactively added `super._on_construction_complete(_placer_unit_id)` to Mazra'eh + Ma'dan after PR #19 reviewer caught them missing. Sarbaz-khaneh did NOT need retrofit because it had applied L4a at authoring time. Two-part trigger + "comment is load-bearing" articulation added at session-4 retro.

**Why L4a + L4b together (not one rule).** L4a is the per-author forward-compat discipline at SUBCLASS authoring time; L4b is the per-shipper sweep audit at BASE modification time. Different actors, different triggers, different moments. If only L4a fires, subclasses authored pre-L4a (Khaneh / Mazra'eh / Ma'dan in their original commits) still need retrofit when the base body changes — L4b handles that. If only L4b fires, every base-body addition triggers a sweep — L4a's at-authoring discipline reduces L4b's retrofit surface to zero over time.

Cites Manifesto Principle 8 (Separation of Concerns — base-class shipper owns the override-chain integrity) + Principle 9 (Automated Enforcement — same-commit fix prevents silent drift).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 implementation-pattern cluster + 2026-05-17 session-4 implementation-pattern cluster]

#### L5. Two-stage Building lifecycle seam — named architecture pattern

**Pattern (named).** Building subclasses follow a two-stage lifecycle:
- **Stage 1 — `_on_placement_complete(placer_unit_id)` virtual on Building base.** Fires from `place_at` immediately after `add_child`. Subclasses do structural side-effects (ResourceSystem.register_node, fog vision, EventBus.building_placed, navmesh rebake).
- **Stage 2 — `_on_construction_complete(placer_unit_id)` virtual.** Fires from `UnitState_Constructing._sim_tick` at dwell-complete. Subclass operational state activates (`is_gatherable` flip, modifier registration, `is_ready_to_produce` flip, future Farr-emit start).

**Distinct Stage-2 shapes across 4 subclasses:**
- **Khaneh** (civic-anchor) — Stage 2 = pop cap +10.
- **Mazra'eh** (resource producer) — Stage 2 = `is_gatherable` flip true.
- **Ma'dan** (labor organizer) — Stage 2 = modifier registration with adjacent MineNode.
- **Sarbaz-khaneh** (institutional) — Stage 2 = `is_ready_to_produce` flip true.

**Supporting convention.** Subclasses MAY expose a typed operational-readiness field (`is_gatherable`, `is_ready_to_produce`, ...) flipped from their `_on_construction_complete` override. **Field name should reflect the subclass's specific operational capability — NOT a generic `is_operational`.** Consumers query the typed field on the typed subclass; do not type-erase. Per-subclass marker is the right level until N≥4 share near-identical bool-flip semantics; only then revisit a base-level optional `is_operationally_ready` virtual.

**Signals (load-bearing for consumers):**
- `construction_progress_updated(percent_x100: int)` — emitted per dwell tick.
- `construction_finalized(placer_unit_id: int)` — emitted post-`_on_construction_complete`, post-virtual-fires. Distinct completion signal for UI/audio/tutorial consumers.

Cites Manifesto Principle 6 (Trust the simple shape until it cracks — N=2 marker subclasses with distinct semantics is not yet a pattern strong enough to abstract).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4 implementation-pattern cluster]

#### L6. Forward-compat-guard-sweep at field-default-change — sweep all callsites in the same commit that first-populates a previously-defaulted field

**Actor.** Schema-field-shipper at the moment the field gains its first non-default value.

**Trigger.** When a field that has been shipped with a default value across N prior subclasses / participants (e.g., `@export var grain_cost: int = 0` on BuildingStats; `@export var farr_per_min_x100: int = 0` on BuildingStats; any `@export var X: Y = <default>` schema field) gains its **first non-default value** via a new wave's commit, every callsite that reads the field MUST be swept for forward-compat-guard coverage matching the field's semantics.

**Rule.** Schema-defaults-with-forward-compat-guard pattern: when a field is added with a default value (typically 0 / empty / null) AND a forward-compat guard like `if cost > 0:` is added at one callsite, every parallel callsite that reads the same field is presumed to need the same guard shape OR a parallel implementation. When the first non-default value ships, sweep all readers — same commit, before commit lands.

**Audit command.** `git grep -n '<field_name>' <scope>` to enumerate readers. For each reader, verify the guard shape is consistent. If a callsite has no guard but assumes the field is non-zero (or vice versa, has a guard that protects against zero but no actual implementation when non-zero), fix in the **same commit** as the field-first-population.

**Why this is the field-shipper's responsibility, not the schema-author's.** The schema-author may have shipped the field in dormant form many waves earlier; they're not present at the moment the field is first-populated. The shipper of the first non-default value is the one with the in-context knowledge that the dormant infrastructure must now wake up. Reactive catches (post-merge reviewer, live-test) are luck; the same-commit sweep is the discipline.

**Relationship to H3.** H3 (cluster H) is the **trigger condition** — "first-exercise of dormant schema". L6 (this rule, cluster L) is the **action shape** — "sweep all callsites in the same commit". H3 fires the alarm at brief-time + D9-time; L6 names what to do at code-time. Both fire together on first-non-default-value events.

**Relationship to L4a/L4b.** L4a/L4b are the **super-call forward-compat** pattern (subclass-override calls super even when base is `pass`); L6 is the **schema-field-default-change forward-compat** pattern (field-reader callsites swept when field is first-populated). Same shape (forward-compat discipline applied at moment-of-change), different surfaces (override-chain integrity vs. read-callsite-symmetry). The author-vs-shipper actor split is the same: L4a-author + L4b-shipper ↔ L6-shipper.

**Canonical incident.** Wave 2A.5 BUG-A — `BuildingStats.grain_cost` shipped at Phase 2 with default 0. `UnitState_Constructing._sim_tick` had `_resolve_cost_coin` deducting coin via `if cost_coin > 0:` guard at the placement-affordability check. The parallel `grain_cost` reader / deducer **DID NOT EXIST** — schema-present, callsite-absent. Atashkadeh's `grain_cost = 50` first-populated the field; the deduction never fired because the callsite wasn't there. Fix at `dfa9a33` added `_resolve_cost_grain` + both-or-neither affordability + parallel `change_resource(GRAIN, ...)` call. **A pre-commit `git grep grain_cost game/scripts/` sweep at Atashkadeh's first-non-zero population would have caught the absent-callsite gap** (`grep` returns the BalanceData reader but NO consumer in UnitState_Constructing — that asymmetry is the audit signal).

Cites Manifesto Principle 9 (Automated Enforcement — `git grep` sweep is a cheap structural lock; relying on per-callsite memory accumulates silent drift) + Principle 1 (Truth-Seeking — verify shape symmetry across all readers, don't assume).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-21 session-5 close]

#### L7. Affordability-sweep — sim-side chokepoint gain triggers input-handler pre-screen audit

*Sibling to L6 (forward-compat-guard-sweep). Same "sweep at moment-of-change" shape; different layer — L6 is same-surface (schema-field readers); L7 is cross-layer (sim-side chokepoint → input-handler pre-screen).*

**Actor.** Agent shipping a sim-side chokepoint addition or modification.

**Trigger.** When `_perform_placement`, a state-machine state's `_sim_tick`, or any sim-side chokepoint adds OR modifies a `change_resource(team, KIND_X, amount, ...)` call AND there is a corresponding input-handler pre-screen that reads `<X>_x100_for(team)` to gate user input, **both must be swept in the SAME commit.**

**Action.** `grep -rn 'KIND_X\|<resource>_x100_for\|change_resource.*KIND_X' game/scripts/input/ game/scripts/ui/` to enumerate input-layer readers; verify each handles the new affordability dimension. If a pre-screen layer reads the resource but doesn't handle the new dimension, add the parallel check in the same commit.

**Generalizes across resources.** Not specifically grain-coin both-or-neither — when Farr-cost, population-cost, or future resource-costs gain a chokepoint, the same sweep fires. Each new pre-screen consumer extends the L7 audit surface (Phase-4 production-queue UI; Phase-5 tech-research UI; etc.).

**Why this is distinct from L6.** L6 fires when a schema-field's reader pattern changes (same-agent, same-surface — BalanceData schema → guard removal). L7 fires when affordability dimensions cross layers (sim-side adds; input-handler pre-screen must mirror). Different agents may own each layer; that asymmetry is exactly why BUG-B2.5 slipped through D9 in the BUG-A fix-wave.

**Canonical incidents (N=2):**
- **Wave 2A.5 BUG-A (`dfa9a33`)** — first instance of "affordability-check incomplete." `UnitState_Constructing` gained grain deduction at first non-zero `grain_cost`; missed the BuildPlacementHandler pre-screen layer. Bug surfaced at lead live-test.
- **Wave 2B BUG-B2.5 (`5082f21`)** — second instance, same shape. Click-time affordability check at `BuildPlacementHandler._on_confirm_click` line 321 was coin-only despite BUG-A's both-or-neither pattern shipping at `UnitState_Constructing`. Surfaced at user live-test. gp-sys-p3s3's meta-finding at fix-close: *"This is the SECOND INSTANCE of the affordability-check incomplete failure mode... had this rule existed at dfa9a33, BuildPlacementHandler would have been swept in the BUG-A fix-wave, and BUG-B2.5 wouldn't have surfaced separately."*

Cites Manifesto Principle 1 (Truth-Seeking — verify cross-layer symmetry when one layer changes) + Principle 9 (Automated Enforcement — `git grep` sweep cheaper than per-layer-author memory).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-22 session-6 close]

#### L8. Drift-proof UI numeric defaults — `%d` + canonical-helper read becomes default; hardcoded literal requires justification

*Inverts the prior implicit default. Hardcoded UI numbers were the norm; drift-proof reads were the exception. After N=3 instances of the drift-proof pattern (cost-label across 7 buildings + Atashkadeh dual-cost + Khaneh pop-cap) the default flips.*

**Rule (code-side default).** Any UI surface (tooltip, label, button text, panel readout) that displays a number sourced from BalanceData (cost, capacity, range, damage, duration, multiplier) uses:
- Format string with `%d` (or `%s` for non-int) substitution at refresh-time.
- Static class helper on the owning Building/Unit script that reads BalanceData with defensive fall-through.
- `tr() % [Script.canonical_helper()]` substitution at the consumer-side (build menu, HUD).

**Exception (requires justification in code comment).** Hardcoded literal acceptable only when:
- (a) The number is genuinely structural and not balance-tunable (e.g., "0 to 100%" — bounds of a percentage display).
- (b) The canonical SSOT is not BalanceData (e.g., `Constants.SIM_TICK_HZ`, engine constants).

**Test-discipline pair (codified as part of L8).** The test asserts the rendered UI contains the substituted value READ from the canonical helper, NOT a hardcoded literal in the test fixture. Pattern: `assert tooltip_text.contains(str(Script.canonical_helper()))`. The test becomes a divergence-detector, not a value-snapshot.

**Canonical incidents (N=3 → rule codifies):**
- Cost-label `%d Coin` across all 7 buildings (since Wave 1C — implicit pattern; first authored without rule).
- Atashkadeh dual-cost `%d Coin / %d Grain` (Wave 2A.5 `87320bf`).
- Khaneh tooltip `+%d population cap` (Wave 2B BUG-B1.5 `29bd24e` — first explicit-with-rationale instance; surfaced the 3-month spec/BalanceData divergence at L1 catch).

**Generalizes beyond UI** — applies wherever a defensive default surfaces to the player (HUD-displayed HP fallbacks, AI-state fallbacks, attack-range readouts).

**Why this matters now.** The Khaneh +5/+10 divergence was invisible for 3+ months because the tooltip was hardcoded. The drift-proof pattern auto-surfaces such divergences at write-time, AND auto-syncs them at runtime once corrected. Pattern composition observation (ui-developer at BUG-B1.5 close): *"Hardcoded literal becomes the exception requiring justification, not the default."*

Cites Manifesto Principle 7 (SSOT — UI reads canonical value at runtime, doesn't snapshot it at write-time) + Principle 1 (Truth-Seeking — divergence-detector tests catch the bug class, not the instance).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-22 session-6 close]

#### L9. Fallback-by-failure-visibility-shape — choose defensive fallback constants by what the player sees when fallback fires

**Rule.** Fallback constants in defensive code paths (typically `_FALLBACK_*` consts in static readers like `cost_coin()` / `population_capacity()` / similar) must either **FAIL-VISIBLY** or **MATCH-SHIPPED**. The choice depends on what the player sees when the fallback fires:

- **FAIL-VISIBLY (zero/empty/sentinel):** when zero/empty as rendered makes the bug self-evident. *Example:* `cost_coin()` fallback = 0 → tooltip shows "0 Coin" which screams "free building, config bug." Lead notices immediately.
- **MATCH-SHIPPED (current canonical value):** when zero/empty as rendered would render a plausible-but-false claim. *Example:* `population_capacity()` fallback = 5 (matching BalanceData) → tooltip shows "+5 population cap" which is true; fallback to 0 would show "+0 population cap" — false-but-plausible "this building doesn't grant cap" reading.

**Silent-plausible defaults are a misinformation hazard.** When the fallback fires (degraded config state), the UI should EITHER scream OR be honest — never lie plausibly.

**Operational form.** Document the choice in a code comment on the fallback constant. Example: *"Why a non-zero fallback (vs cost_coin's 0): cost = 0 visually-screams 'config error'; population capacity = 0 is a SILENT bug. Better to fall through to the current shipped value so a missing BalanceData doesn't silently lie."*

**Generalizes beyond UI** — applies wherever a defensive default surfaces to the player (HP fallbacks, attack-range fallbacks, AI-state fallbacks).

**Pairs with L8.** L8 says "use a dynamic default"; L9 says "when the dynamic helper falls back, choose the fallback by visibility-shape." Together: drift-proof at runtime + honest at degraded-state.

**Canonical incident.** Wave 2B BUG-B1.5 (`29bd24e`) — ui-developer-p3s3 authored `_FALLBACK_POPULATION_CAPACITY = 10` with explicit rationale: *"cost_coin's 0 fallback works because 'free building' is a visually-screaming config error. population_capacity = 0 would be SILENT (tooltip just shows '+0' and the player reads it as 'doesn't grant any cap'), so the fallback semantics need to be different."* (Subsequently reduced to 5 at session-6 close retro per Khaneh +5 revert; the rationale persists.)

Cites Manifesto Principle 1 (Truth-Seeking — when uncertain, surface the uncertainty visibly rather than lie plausibly) + Principle 6 (Honest-tools-not-magic-tricks — degraded state should be legible, not invisible).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-22 session-6 close]

#### L10. Canonical-pattern grep — gating-track / first-implementer's brief-validation discipline

**Rule.** Before implementing any BalanceData read, autoload-API consumer call, project-internal schema lookup, or any other "read from a shared project structure" in NEW code, the implementing agent `git grep`s for existing consumers of the same data shape AND uses the canonical pattern they exhibit. The brief is the planning artifact; the existing code is the source of truth for project-internal consistency.

**Why.** The brief may invent a pattern that doesn't match the canonical access shape. The wave-3A.6 BUG-C1 incident: lead's brief §3.4 specified `BalanceData.bldg_<kind>.train_<unit>_<field>` (top-level field on BalanceData). The actual canonical pattern, used by `unit_state_constructing.gd:_resolve_construction_ticks` since wave 1C, is `BalanceData.buildings[StringName(<kind>)].construction_ticks` (Dictionary lookup). gp-sys-p3s3 implemented the brief literally in `_read_bldg_stats_int`; the function returned 0 for all training costs; the affordability gate trivially passed; deduction was skipped. Bug shipped to live-test.

**Complement to §9.D7(b).** §9.D7(b) cross-track diagnostic catches downstream-consumer bugs when you're NOT the gating track (you observe other tracks' WIP). §9.L10 canonical-pattern grep catches upstream-producer bugs when you ARE the gating track (you have no other-track WIP to observe yet). gp-sys-p3s3's session-7 framing: *"the gating track loses the cross-track-diagnostic vantage by definition — other tracks haven't materialized yet."* Both disciplines together close the gap.

**Operational form.** Before writing the read code, `git grep "BalanceData\." -- game/scripts/` (or equivalent grep for the relevant shared structure). Identify ≥1 existing canonical consumer. Use their access pattern. If brief and canonical disagree, broadcast as `[D7(b)] brief-vs-canonical-schema divergence: <field>` (mirrors §9.L1's brief-defect flavor — see L1 footnote). Brief prose loses to project-internal canonical access.

**Canonical incident.** Wave 3A.6 BUG-C1 (`0679630` fix). 30-second grep would have surfaced zero hits for `BalanceData.bldg_` and revealed `BalanceData.buildings[<kind>]` as canonical. Brief mistake never gets implemented + shipped + reaches live-test.

**ui-developer-p3s3 parallel observation:** at the same wave, their `production_panel.gd:_read_balance_int` used the canonical pattern correctly — they grepped existing consumers + used their shape. The discipline as a private adjustment worked locally; the gap was that they didn't broadcast the brief-vs-canonical divergence as a multi-agent risk (Task #213 → §9.L1 brief-defect flavor).

Cites Manifesto Principle 1 (Truth-Seeking — code is the truth; briefs are planning artifacts) + Principle 7 (SSOT — canonical existing patterns are the access SSOT for project-internal structures).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-23 session-7 close]

#### L11. Brief-drafting balance-audit — lead checks balance.tres before proposing any numeric value that might already exist canonically

**Actor.** Lead (brief author) at brief-drafting time.

**Trigger.** When a wave brief proposes a specific numeric value for any field that is or could be an existing BalanceData entry (unit HP, building HP, cost, construction_ticks, train times, sight radii, etc.).

**Rule.** Before writing the proposed value into the brief, the lead runs `git grep "<entry_key>" game/data/balance.tres` to check whether a canonical value already exists. If it does:
- The brief MUST cite the existing value AND either (a) explicitly justify the override with design rationale, or (b) defer to the existing canonical value.
- The brief MUST NOT silently propose a different number as if no prior value exists.

**Why.** Six consecutive §9.L1 overrides across six waves all followed the same pattern: lead's brief proposed a number; balance-engineer found the canonical value in balance.tres / CORE_MECHANICS.md / UnitStats and applied §9.L1. In each case the lead's brief was written without checking the canonical source. The spec-wins override at the receiving end is working correctly; the preventable waste is the brief-drafting gap that makes the override necessary in the first place.

**The two distinct cases (brief author must distinguish):**

- **No prior canonical value (new entity):** brief proposes a starting-point number. Expected to be overridden at Track 3 per §9.L1. Mark explicitly: *"Starting point — balance-engineer overrides with citation."*
- **Prior canonical value exists:** brief must cite it. Proposing a different value without rationale is a brief-drafting defect; balance-engineer will catch it via §9.L1 and the round-trip is wasted.

**Relationship to §9.L1.** L1 is the **receiving discipline** — specialist overrides with citation when brief contradicts canonical. L11 is the **origination discipline** — lead checks canonical before drafting the brief. Both firing together means the round-trip converges in one pass instead of two. L11 doesn't replace L1; balance-engineer still applies L1 on their own deliverable surface regardless.

**Operational form.** At brief-drafting time: `git grep "bldg_\|unit_\|farr_cfg" game/data/balance.tres | grep "<building_or_unit_key>"`. One-liner confirms whether a sub_resource already exists. If it does, copy its current values into the brief explicitly.

**Canonical incidents (N=6, all §9.L1 balance-engineer overrides that L11 would have prevented the round-trip on):**
- Wave-1B: `coin_cost = 40` in balance.tres; brief said 75. Override applied.
- Wave-2A.5: `max_hp = 600` retained; brief suggested 400. Override applied.
- Wave-2B: `construction_ticks = 1080` retained; brief said ~900. Override applied.
- Wave-3A.0: fog sight radii (Kargar 3, etc.) retained from FOG_DATA_CONTRACT §2.2 defaults; brief inflated them. Override applied.
- Wave-3A.6: grain costs for producer buildings; brief values overridden with UnitStats.grain_cost as canonical source.
- Wave-3-Throne: `max_hp = 2000` in balance.tres:215; brief v1.0.0 proposed 5000 without acknowledging the existing entry. Corrected to 2000 in v1.0.1 per §9.L1 + mirror-reviewer C1.3 finding.

In all six instances, a 30-second `git grep` at brief-drafting time would have surfaced the canonical value. L11 formalizes that 30-second check as a discipline.

Cites Manifesto Principle 7 (SSOT — brief is a planning artifact; balance.tres is the canonical balance record) + Principle 4 (Lean Iteration — prevent the two-pass round-trip when the canonical value is already settled).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 session-8 close; balance-engineer-p3s3 retro reflection N=6 exhibits → lead codification]

#### L11.1. §9.L11 two-actor framing — author primary + reviewer backstop (codified post-violation)

**Refinement of §9.L11.** L11 codified the author-side discipline at session-8 close (lead grep balance.tres before drafting). At session-9 close — exactly one post-codification opportunity later — lead violated the rule (Wave 3-BD brief v1.0.0 proposed Track 3 to add `max_hp` entries already shipped at balance.tres lines 215, 233, 257, 307, 352, 392, 426, 464). Architecture-reviewer brief-time review caught the violation.

**Lesson (balance-engineer-p3s3 retro reflection 2026-05-28):** *"Codifying a rule in a document doesn't create the habit — it creates a reference. What failed here is the same thing that would fail with any checklist that relies on the author to remember to run it: lead was in brief-drafting mode, attention was on the wave's design intent, and the 30-second grep didn't happen."*

**Refinement.** §9.L11 is a two-actor rule, not one:

- **Primary actor (lead, brief author):** the 30-second `git grep balance.tres` at brief-drafting time. Fires when writing any numeric value into a brief. THIS DISCIPLINE WILL FAIL UNDER DRAFTING PRESSURE. Codification creates a reference, not a habit.
- **Backstop actor (architecture-reviewer, brief-time mirror review):** explicit balance.tres cross-check on every brief that proposes numeric values for entries that already exist canonically. This is the load-bearing enforcement — external check, doesn't depend on author self-discipline in the drafting moment.

**Backstop operational form (mirror-reviewer brief-time discipline addendum).** At brief-time review, for every numeric value the brief proposes (HP, damage, cost, ticks, multipliers, radii):

```
For each numeric value V proposed in the brief:
    Run `git grep "<entry_key>" game/data/balance.tres`
    If a canonical value V_canonical exists:
        If V != V_canonical AND the brief doesn't explicitly cite + justify the override:
            BLOCKER finding: "Brief proposes V=<X>; canonical at balance.tres:<line> is V_canonical=<Y>. Brief must either cite + justify the override, or defer to canonical."
        If V == V_canonical:
            VERIFIED: "Brief's V matches canonical."
    Else (no canonical value):
        Verify the brief marks the value explicitly as "Starting point — balance-engineer overrides per §9.L1."
```

**Why the two-actor framing is the right shape.**

1. **Primary discipline alone is insufficient.** N=1 violation in N=1 post-codification opportunity (Wave 3-BD v1.0.0) is direct evidence. Self-discipline rules that depend on author attention under drafting pressure fail predictably.
2. **Backstop discipline alone is wasteful.** If lead never does the grep, every brief proposes wrong-or-right-by-accident numeric values that mirror-reviewer must catch. Round-trip cost is real.
3. **Two-actor framing converges in one pass when both fire.** Lead's grep catches 70-80% of violations at brief-drafting time; backstop catches the remaining 20-30% lead missed. Round-trip becomes one pass instead of one-and-a-half passes (Wave 3-BD evidence: backstop caught v1.0.0 violation; v1.0.1 was correct in one revision).

**Generalizes beyond §9.L11.** The same shape applies to any author-side discipline:
- **§9.L11** (numeric values) + brief-time architecture-reviewer backstop.
- **§9.L12** (canonical-pattern grep) + brief-time mirror-reviewer backstop (already shipped at session 8).
- **§9.M6.3** (observability back-fill audit) + brief-time mirror-reviewer mechanical grep backstop (this session, see §9.M6.3).
- **§9.D11** (First-Consumer Trace) + brief-time mirror-reviewer holds the brief if section is "we'll see" (this session, see §9.D11).

**Project-wide pattern: author-side rules need reviewer-side backstops.** Codifying an author-side rule without a reviewer-side enforcement seam is half-implementing the rule. The reviewer-side enforcement is what makes the rule reliable.

Cites Manifesto Principle 9 (Automated Enforcement — backstop IS the enforcement) + Principle 6 (Honest-tools-not-magic-tricks — admitting "self-discipline fails under drafting pressure" is more honest than "we codified it, problem solved"). N=1 post-codification violation (Wave 3-BD v1.0.0 max_hp); N=1 post-codification backstop catch (architecture-reviewer Wave 3-BD v1.0.0 → v1.0.1 correction).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; balance-engineer-p3s3 retro reflection (2-actor refinement) + lead self-discipline failure (Wave 3-BD v1.0.0) → codification]

#### L11.2. Consumption-path tracing — affordability / reviewer-backstop checks MUST trace at least one production-code consumption path per field used in the analysis

**Refinement of §9.L11.1.** L11 + L11.1 codified that lead's brief-time numeric values get cross-checked against `balance.tres`. L11.2 sharpens scope: checking balance.tres at face value is insufficient when the production code that CONSUMES the .tres value may diverge from it. Reviewer-backstop discipline MUST trace consumption paths for any field load-bearing in the analysis.

**Actor.** Balance-engineer (or any agent doing reviewer-backstop work) at brief-time review.

**Trigger.** Any of:
- Affordability analysis cross-checking a brief's build-order or income claims.
- Schema-vs-implementation reviewer-backstop on a balance.tres field.
- Numeric-value verification where the value is consumed by ≥1 production-code site.

**Rule.** For each field referenced in the analysis, the reviewer:
1. Confirms the value exists in balance.tres at the cited line.
2. Greps for ≥1 production-code consumption site (`git grep "<field_key>" game/scripts/`).
3. Verifies the production code uses the value as expected (no hardcoded override, no stale name, no divergent fallback).

If step 3 surfaces a divergence: surface as a finding (mine_node SSOT divergence pattern) for the wave or next-balance-tuning-wave to address.

**Why (N=2 mine_node session-10):**

Wave 3-Sim Track 1 balance-engineer affordability table flagged 2 production-code SSOT divergences from balance.tres:
- `mine_node.gd` hardcoded `reserves = 100` vs balance.tres declaring `1500` (`_WAVE_1A_RESERVES_X100 = 10000` hardcode predating the .tres value).
- `mine_node.gd` hardcoded `max_slots = 1` vs balance.tres declaring `mine_max_workers = 2` (Phase 3 simplification predating .tres consumption).

Both were latent — the .tres values existed and looked authoritative; the hardcodes were in mine_node.gd unread. Without the consumption-path trace, the affordability table would have produced predictions assuming reserves=1500 / max_slots=2; the batch runner would have produced contradicting data; diagnosing why would have required another cycle.

**Distinguishes from §9.L11.** L11 checks "does this value exist in balance.tres" (numeric authority). L11.2 checks "does the production code actually consume the balance.tres value" (numeric realization). Both are necessary; L11.2 is the load-bearing check when the analysis depends on the value being real, not just declared.

**Operational form.** One grep per key claim:

```bash
# For each field F referenced in the affordability analysis:
git grep "<F_key>" game/scripts/ | grep -v tests/
# Confirm:
#   ≥1 production read site, OR
#   Surface as "field declared in .tres but no consumer" finding
```

**Generalizes beyond balance.tres.** Same pattern applies to:
- BalanceData sub-resource fields (`bldg_<kind>.train_<unit>_<field>` access patterns — see BUG-C1).
- FogConfig / EconomyConfig / AIConfig field consumption paths.
- Constants.gd values referenced in brief prose (verify production-code consumes the canonical Constants reference, not a hardcoded duplicate).

**Where reviewers enforce.**

- **Mirror-reviewer brief-time review** runs the consumption-path grep against any field load-bearing in the brief's numeric claims. Brief that cites a balance.tres value without a consumer is a finding (the value is non-load-bearing — flag the brief for honesty about that, OR surface the missing consumer as the wave's responsibility).
- **Architecture-reviewer brief-time review** verifies any reviewer-backstop check (affordability table, schema cross-check) explicitly cites consumption paths, not just the .tres values.

**Where authors apply.**

- **Balance-engineer** running any affordability table OR pre-implementation schema check adds ≥1 grep-per-field-claim to the analysis. The grep result IS part of the analysis output.
- **Brief authors (lead)** when proposing numeric values, run the consumption-path grep first — surfaces "this field is declared but unconsumed" gaps before the brief ships.

Cites Manifesto Principle 1 (Truth-Seeking — `balance.tres` declares; production code realizes; reviewer-backstop must verify both) + Principle 7 (SSOT — a value's authority requires both declaration AND consumption). Sister rule to §9.L11.1 (two-actor framing); the consumption-path grep is the load-bearing scope-correction.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; balance-engineer-p3s3 retro reflection (mine_node N=2 evidence + tightening proposal) → lead codification. L11 + L11.1 + L11.2 form the three-layer balance-engineer brief-time backstop chain.]

#### L12. Brief-time canonical-pattern grep — lead-side §9.L10 extension

**Actor:** Lead (brief author). Mirror-reviewer at brief-time review as the secondary check.

**Trigger:** Drafting brief prose that specifies API shape, class declaration syntax, GDScript convention, signal payload structure, BalanceData access pattern, or any other element where the project has a canonical pattern visible in shipped code.

**Rule:** Before committing brief prose that prescribes a code shape, **the lead MUST `git grep` for the canonical project pattern** in existing implementers and either (a) cite the canonical reference verbatim with file:line, or (b) explicitly document the divergence + rationale in the brief itself. Brief prose without a canonical anchor is implementer-trap-prone.

This applies to:
- Class declaration syntax (`class_name X extends Y` vs `extends "res://path/y.gd"` + `class_name X`).
- BalanceData / autoload / registry access shapes (top-level field vs Dictionary lookup, `Engine.has_singleton` vs `tree.root.get_node_or_null`).
- Signal declaration patterns (`@warning_ignore("unused_signal")` convention, payload type-ordering).
- IDropoffTarget-class duck-typed protocols (method names, signatures).
- Test fixture patterns (`SimClock._is_ticking = true` wrapping, `_run_inside_tick` helpers).
- Defensive cascade patterns (autoload-or-null, file-exists guards, type-checks).

**Why (N=3+ exhibits):**

1. **BUG-C1 (Wave 3A.6, session 7).** Brief §3.4 specified `BalanceData.bldg_<self.kind>.train_<unit>_<field>` as a top-level field access. Canonical project pattern at `unit_state_constructing.gd:519 _resolve_construction_ticks` was a Dictionary lookup: `bd.get(&"buildings")` then `.get(kind, null)`. Implementer (gp-sys) followed brief literally; `_read_bldg_stats_int` silently returned 0 for all cost lookups; affordability gate trivially passed; deduction skipped; training spawned for free in live-test. Fix-wave at `0679630` rewrote to canonical Dictionary lookup. **Symptom: free units.**

2. **Throne brief v1.0.0 → v1.0.2 (Wave-3-Throne, session 8).** Brief §1 + §4 Track 1 specified `is_dropoff_target_for` / `get_dropoff_position` as the IDropoffTarget protocol method names. Canonical RNC §5.2 names were `deposit` and `get_deposit_position`. Mirror-reviewer brief-time review caught the C1.1 divergence; lead corrected v1.0.0 → v1.0.1. Brief also specified `class_name Throne extends Building`; project canonical at all 7 existing subclasses (atashkadeh/sarbaz_khaneh/sowari_khaneh/tirandazi/mazraeh/madan/khaneh) is `extends "res://scripts/world/buildings/building.gd"` + `class_name Throne` (path-string for class-registry race). Mirror did NOT catch this second divergence at brief-time; gp-sys caught it at implementation time and applied §9.L10 (canonical-pattern overrides brief prose). **Symptom: would have re-triggered class-registry race documented at building.gd:70-75.**

3. **Throne brief max_hp = 5000.** Brief §1 specified Throne max_hp = 5000 as lead-invented value. Mirror C1.3 caught that `bldg_throne` ALREADY EXISTS at `balance.tres:213` with `max_hp = 2000.0` from a balance-engineer wave-prior authoring. Lead's prose was a §9.L1 violation (lead-invention of a balance-engineer-owned numeric); mirror flagged at brief-time review; corrected v1.0.0 → v1.0.1. **Symptom: would have caused balance-engineer round-trip on a numeric the design-spec didn't actually specify.**

**Distinguishes from §9.L11 (balance-engineer numeric-value codification):**
- §9.L11 is for **numeric values** (HP, damage, costs, dwell ticks) — balance-engineer owns; lead defers.
- §9.L12 is for **shape / syntax / convention** (class declaration syntax, Dictionary access patterns, signal annotations, defensive cascades) — canonical project pattern owns; lead defers.

Both rules share the same anti-pattern shape: lead-invention in a domain the project already has a canonical answer for. §9.L11 protects balance-engineer's numeric authority; §9.L12 protects the codebase's structural consistency.

**Operational form:**

Before drafting brief prose that specifies a code shape:
1. `git grep` the canonical pattern across existing implementers (e.g., `git grep "extends.*building.gd" game/scripts/world/buildings/` to find class-declaration shape).
2. If ≥ 1 canonical implementer exists: cite verbatim in brief with `file_path:line_number` reference. Use that exact shape.
3. If 0 canonical implementers exist: document the brief as introducing a new canonical pattern with rationale. Mirror-reviewer flags brief-time as "first-canonical-pattern" trigger requiring extra scrutiny.
4. Mirror-reviewer's brief-time review re-runs the same grep + verifies brief prose matches canonical.

Mirror-reviewer's 4-class review (per Throne wave brief precedent) becomes the load-bearing check at brief-time:
- **Class 1: schema/canonical-pattern grep** — explicitly mandates this rule. The class is already named; this codifies that §9.L12 IS Class 1's enforcement teeth.

Cites Manifesto Principle 1 (Truth-Seeking — shipped canonical pattern is the truth; brief prose is the plan) + Principle 7 (SSOT). See also §9.L10 (implementer-time canonical-pattern grep, this rule's downstream complement), §9.L11 (balance-engineer numeric-value codification, this rule's sibling).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 session-8 close; gp-sys-p3s3 retro reflection N=3 exhibits (BUG-C1 + Throne brief v1.0.0 IDropoffTarget naming + Throne brief class_name syntax) → codification]

---

### §9.M — Test Discipline

#### M1. Scenes need visual smoke tests beyond unit tests

**Rule.** A scene-level test that loads the scene, renders one frame, and verifies expected visual elements catches the class of bug (elevation, framing, visibility) that headless unit tests structurally cannot catch.

**Why.** Phase 0's camera elevation bug was missed by 130 passing unit tests; surfaced only when Siavoush eyeballed the running game. Tests checked the math; no test checked whether the camera would actually frame the scene.

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-01 post-Phase-0]

#### M2. Live-test cadence is the real acceptance funnel — PR opens after live-test reaches clean state

**Rule.** Headless tests + reviewer trio are NECESSARY but NOT SUFFICIENT for PR. The pattern: ship → lead live-test #1 → diagnose surfaced bugs → fix-wave → lead live-test #2 → … until live-test produces zero new findings. THEN open PR.

**Why.** Phase 3 session 1 needed live-test #1 (surfaced BUG-08/09 + Farr gauge precision gap) → fix-wave → live-test #2 (surfaced BUG-10 + BUG-11) → fix-wave → live-test #3 (clean) before PR was ready. Headless caught what it structurally can; the convergent retro finding (cross-cutting schema verification — see H1) is precisely about closing the headless blindspot, but residual runtime behavior + visual readability + cross-feature interactions remain live-test territory.

The funnel is: tests catch most → reviewer trio catches drift → live-test catches the rest. Skipping any layer ships bugs to main.

**Tooling: `tools/run_game.sh`** is the project's standard interactive-launch path. Wrapper script runs Godot against the project and tees stdout+stderr to `/tmp/shahnameh.log`. Claude Code sessions read the log via `Read` / `tail` — no copy-paste round-trips. Set as default launch for all future live-test sessions.

Cites Manifesto Principle 4 (Lean Iteration — fail fast, in live-test, not in production).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-14 post-Phase-3-session-1]

#### M3. Pre-commit hook is the authoritative commit-readiness gate; out-of-hook runs are diagnostic

**See also: D6.** D6 says WHEN to broadcast `[blocked]` (after the hook fires). M3 says NOT to broadcast speculatively on out-of-hook output. The canonical incident below (Wave 2A PR #19 "33/34 farr_gauge") is the canonical example of D6 triggered incorrectly. Both rules together: only broadcast `[blocked]` after the hook fires, never on speculative out-of-hook signal.

**Rule.** When an out-of-hook test run reports a failure that the pre-commit hook did NOT report on a recent identical-working-tree state, the failure is a DIAGNOSTIC SIGNAL (investigate why the environments differ) — NOT a commit blocker. **Pre-commit hook verdicts override standalone test-run verdicts.** The reverse also holds: if the hook fires on a failure not visible to the standalone run, the hook is correct and the standalone run's environment is misconfigured.

**Trigger condition.** Defer to the hook when you have evidence (via `git log`) that the hook passed on a contemporaneous state of the same file set. If you want to pre-check before commit, run the hook directly (`bash tools/run_tests.sh` or equivalent), NOT `godot --headless --test` raw.

**Operational form.** Before broadcasting `[blocked]` on a presumed test failure, run `git log --oneline -3` and check if other agents' recent commits passed the hook on the same suite state. If they did, the gate is likely clear; attempt the commit directly. Out-of-hook runs have different env (cache state, load order) that can produce false positives. Speculative pre-blocking on out-of-hook output is the wrong gate.

**Refinement — error-specificity is NOT a reliable signal (session-6 close).** Error specificity (named identifier, named file, named line) is NOT a reliable signal that a hook failure is real vs transient. **Retry once before broadcasting regardless of how concrete the error message looks.** The GUT startup race surfaces through the first plausible-looking parse failure it can find — it borrows the error shape of whatever it collides with. The specificity is a property of the collision surface, not of the underlying failure cause. The session-4 canonical incident (Wave 2A PR #19 "33/34 farr_gauge") was a numerically-specific failure; the Wave 2B world-builder Track 2 incident was a syntactically-specific failure (named identifier at named line). Both turned out to be transient gut_loader races in disguise. **Simple rule: retry once, always, before broadcasting.**

**Canonical incident.** Wave 2A PR #19 — world-builder-p3s2 reported `[blocked]` on a claimed "33/34 farr_gauge test failure" before attempting the commit. Lead's `0f986ff` + gp-sys's `128af9f` had both passed the same pre-commit hook minutes earlier. After unblock, world-builder's commit `07c6ca8` passed the hook cleanly. The standalone run picked up an environment difference; the hook's controlled subset was clean.

Cites Manifesto Principle 1 (Truth-Seeking — the hook is the authoritative gate) and Principle 9 (Automated Enforcement — speculative pre-blocking on the wrong gate metastasizes).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4 test-discipline cluster]

#### M4. Headless test independence — `.new()` decouples test ship-timing from scene ship-timing

**See also: F4.** F4 mandates the inherited-scene regression test EXISTS at first occurrence; M4 specifies WHERE it lives. Together: regression test is mandatory (F4); it lives in the scene-author's parallel `test_<subclass>_scene.gd` file, not the class-behavior test file (M4). Two tests, two authors, two ship cadences, zero coupling.

**Rule.** When Track-N owns the script and Track-M owns the scene, Track-N's tests use `.new()` not `preload(.tscn).instantiate()`. This decouples your test ship-timing from the scene file's existence on disk.

**Rule shape.** If a subclass test needs scene-level structural assertions (NavigationObstacle3D vertices, CollisionShape3D dimensions, MeshInstance3D placement), those go in a SEPARATE `test_<subclass>_scene.gd` file owned by the scene's author (world-builder), gated on the scene file's existence. The class-behavior tests (`test_<subclass>.gd`) use `.new()` for instance-level coverage.

**Why this works.** Class-behavior tests (HP, ticks, signals, override semantics) don't need the visual mesh or collision shape — they need a constructed instance. The scene file adds visual + physics, which are testable separately.

**Canonical incident.** Wave 2A — gp-sys shipped `test_sarbaz_khaneh.gd` (14 tests via `.new()`) at Commit 1 `8314a8a` BEFORE world-builder's `sarbaz_khaneh.tscn` was on disk; world-builder shipped `test_sarbaz_khaneh_scene.gd` (Pitfall #15 regression test) at `2f31b34`. Two test files, two authors, two ship times, zero coupling.

Cites Manifesto Principle 8 (Separation of Concerns — scripts and scenes have separate ship cadences; tests should too) and Principle 10 (Feedback Cycle — decoupling reduces lock-step coordination overhead).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-4 test-discipline cluster]

#### M5. Poll-loop test-coverage discipline + signal-introspection over lambda-capture (Pitfall #14 mitigations)

**Rule (N-iteration test).** Any consumer that polls a SceneTree group + connects per-instance signals (overlays, debug surfaces, tutorial hooks, telemetry sinks) MUST ship a test that:

1. Establishes the wire (calls `_ensure_signal_connected` or equivalent once).
2. Fires the lifecycle event whose handler the wire serves (`signal.emit()` from a fake producer).
3. Re-invokes the wire-establishment N times (N≥10).
4. Asserts no resource creep — signal connection count constant, cache size bounded.

**Why N-iteration.** The bug class — "resource creep across N poll iterations" — is structurally invisible to single-event tests. Single-event functional tests passed cleanly on ui-developer-p3s3's overlay at `a023242`; the duplicate-connect bug (`_connected.erase(bid)` in the finalize handler caused per-frame reconnect attempts) surfaced only in live-test (ERROR spam in log). Fix-up at `280d27a` included the regression-locking test `test_repeated_ensure_connect_does_not_duplicate_signal_wires`.

**Rule (signal-introspection over lambda-capture).** Default to `Signal.get_connections().size()` reads (or `is_connected()` checks) when testing signal-wiring behavior. Use lambdas only when the closed-over locals are immutable in the enclosing scope.

**Why signal-introspection.** Pitfall #14 (GDScript lambda capture of reassigned locals is unreliable, promoted to `PROCESS_EXPERIMENTS.md`) — captured-local-of-reassigned-value doesn't propagate the later reassignment in GDScript. The Signal-introspection pattern bypasses the closure entirely by reading the engine's connection table directly.

**Operational mitigations for Pitfall #14 (apply per case):**
1. **Default pattern:** post-await SceneTree readout for state observations in tests.
2. **Signal-watching pattern:** `Signal.get_connections().size()` for signal-wiring tests (this rule).
3. **Sentinel-append pattern:** lambda appends to an outer-scope sentinel array; test reads array contents post-await.

Cites Manifesto Principle 1 (Truth-Seeking — the test should catch the bug class, not the specific bug instance) and Principle 10 (Feedback Cycle — regression locks are the cheapest forward-investment in test infrastructure).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-3 consumer-side-integration cluster + Pitfall #14 promotion]

#### M6. Log-instrumentation-from-day-1 — every new system emits greppable `[<system>]` log lines

**Rule.** Every new autoload, system, state machine, or major feature shipped to the game **MUST include log instrumentation from day 1**. Not retro-fitted when something breaks; not "I'll add prints if there's a bug." The log lines are part of the deliverable, not a debugging afterthought.

**Required shape:**

```gdscript
# At system initialization / autoload _ready:
print("[<system>] _ready field1=", value1, " field2=", value2)

# At major state transitions / events:
print("[<system>] <event_name>: <key=value pairs>")

# Periodic state snapshots for systems without discrete events (throttled, e.g. tick % 30 == 0):
if SimClock.tick % 30 == 0:
    print("[<system>] snapshot tick=", SimClock.tick, " <state vars>")
```

**Tag-prefix convention.** `[<short-system-name>]` so `grep`/`awk` filters trivially. Examples: `[turan]`, `[fog]`, `[production]`, `[farr]`, `[resource]`. Diagnostic-only prints (deeper debug paths, lifecycle traces) get a `[<system>-diag]` suffix and can be removed at retro if the noise-to-signal ratio is wrong.

**Why.** N=4 defensive-fallback-masking production bugs (BUG-C1, BUG-D1, BUG-D2, BUG-D4) shipped to live-test in successive waves with all-passing test suites. Each was a silent no-op — a defensive guard converted an upstream error into "no observable behavior." **The user-driven live-test caught them only because someone retro-fitted `print()` lines to diagnose.** Cumulative debugging cost across the chain: tens of minutes of close-Godot/edit-code/relaunch cycles. Day-1 instrumentation would have surfaced each bug in 10 seconds of live-test.

**Where reviewers enforce.**

- **godot-code-reviewer + architecture-reviewer** check for `[<system>]` log presence on any new autoload, system, or major state machine. **Missing log instrumentation is a BLOCKER, not a nit.** Inline review prompt: *"Where are the `print('[<system>]', ...)` lines for this system's lifecycle and major state transitions?"*
- **mirror-reviewer (brief-time)** flags missing log instrumentation as a finding (Class 5 — observability). Specifically: every wave brief that introduces a new system should explicitly require log instrumentation as a Track deliverable.

**Where authors apply.**

- **Wave brief authors (lead)** add to every Track deliverable that ships a new system: *"Log instrumentation: each major event/transition emits a `[<system>]` log line. Periodic state snapshots once per N ticks for systems with no discrete events. Greppable tag-prefix convention."*
- **Implementer agents** treat log instrumentation as a mandatory part of the implementation, not a separate task.

**Anti-patterns to flag at review:**

- Shipping a new system with zero log lines, planning to "add prints if there's a bug." The bugs that need prints are the ones prints would have caught.
- Removing log lines after a wave closes "to clean up." The log lines are not noise; they are the runtime trace.
- Log lines that print only in error / exception paths. Successful paths are equally important — silent success is indistinguishable from silent failure.

**Canonical incident chain (Wave 3B live-test, 2026-05-24):**

- **BUG-C1** (Wave 3A.6, schema mismatch) — caught only because gp-sys instrumented `_resolve_train_cost` retroactively during diagnosis.
- **BUG-D1** (Wave 3A.5, sim_phase wiring) — caught by mirror-reviewer brief-time review reading shipped code.
- **BUG-D2** (Wave 3A.5, team-id bounds) — caught by ai-engineer first-runtime exercise of TURAN-side fog reads.
- **BUG-D3** (Wave 3A.5, copy-on-write PackedByteArray writes) — caught by lead-added `[fog-diag]` prints during live-test.
- **BUG-D4** (Wave 3A.5, `turan_` prefix not stripped in fog field lookup) — caught by lead-added `[fog-diag] sources_by_team` print showing `{ 1: 16 }` (zero Turan registrations).

**4 of the 5 bugs above (D1/D2/D3/D4) lived in code that had ZERO log instrumentation.** Day-1 `[<system>]` prints on the shipped surfaces would have made each visible in the first live-test, not after retro-fitted prints.

Cites Manifesto Principle 1 (Truth-Seeking — make runtime behavior legible) + Principle 6 (Honest-tools-not-magic-tricks — silent success indistinguishable from silent failure is dishonest) + Principle 9 (Automated Enforcement — reviewer-enforced log presence vs. hope-it-gets-added-someday).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 Wave 3B live-test bug chain (BUG-C1/D1/D2/D3/D4) → user-directive codification]

#### M6.2. UI log instrumentation — state-transitions, not state

**Sub-rule of §9.M6 (day-1 log instrumentation).** §9.M6 mandates `[<system>]` logs from day 1; §9.M6.2 sharpens the rule for UI code where the parent's default "log on every event" guidance would produce noise rather than signal.

**Actor.** UI implementer (ui-developer or whoever ships a Control / CanvasLayer / HUD widget). Applied at moment-of-writing the script, not retro-fitted.

**Trigger.** Any new UI Control, CanvasLayer, panel, button, or HUD widget ships to the game. The parent §9.M6 rule fires; §9.M6.2 specifies WHAT to log within the UI surface.

**Rule.** UI scripts log on STATE TRANSITIONS, not on continuous state. The default "every event" guidance from §9.M6 over-applies to UI because UI is re-rendered ~60 Hz and most "events" are per-frame queries against unchanged state. The rule splits into a log-this list and a do-NOT-log list:

**LOG these (state transitions + user actions + signal emits):**
1. **Lifecycle events** — `_ready`, `open()`, `close()`, `show()`, `hide()`, `dismiss()`.
2. **User-action events** — button click, hotkey press, drag start/end, scroll wheel, click-outside dismiss, escape key.
3. **State-transition events** — affordable→unaffordable, idle→busy, button enabled↔disabled (log when the result FLIPS, not on every re-evaluation).
4. **Signal-emit events** — when the UI emits a write-shaped signal (e.g., `EventBus.build_placement_started`, `building.request_train`).

**DO NOT log these (per-frame state):**
1. `_process` body unless a state actually changed THIS frame.
2. Mouse hover unless it triggers a content change.
3. Affordability sweeps that run frequently — only log when the affordability RESULT changes (button flipped enabled↔disabled), not when the sweep re-evaluates with the same answer.
4. Tooltip-text mutation unless the tooltip kind changes (e.g., "Not enough Coin" → "Not enough Grain" is a transition; same-message-different-numbers is not).

**Tag-prefix convention.** Follows §9.M6's `[<system>]` rule with UI-layer sub-tagging:
- `[ui/<panel-name>]` — panel-specific event. Examples: `[ui/production-panel] open kind=sarbaz_khaneh`, `[ui/build-menu] khaneh-button pressed`, `[ui/resource-hud] coin display=250→260`.
- `[ui/click]` — click-handler routing decisions (existing pattern in `click_handler.gd` DEBUG_LOG_CLICKS).
- `[ui]` — generic UI-layer event with no obvious panel owner.

**Why.** UI state bugs hide behind invisible widget mutation faster than sim-side bugs do. Two incident exhibits:

- **Wave 3A.6 Track 2 (ProductionPanel ship, commit `67606ed`).** Shipped without `[ui/production-panel]` log lines. Lead's session-8 retro fact-list flagged the gap. The panel's open/close/train-button/affordability-flip events were ALL silent in the log — any UI bug would require retro-fitting prints to diagnose, exactly the failure mode §9.M6 was created to prevent. Without §9.M6.2's clarification, the implementer (ui-developer) defaulted to "log on every event" but applied that ONLY to user-visible events and dropped state-transition events from the list.

- **Wave 2B BUG-B1 (missing tooltips for older buildings).** Tooltips for Khaneh / Mazra'eh / Ma'dan were grandfathered without log lines. The bug surfaced via live-test ("tooltips not appearing") — but the diagnostic took several broadcasts + re-test cycles. A `[ui/build-menu] tooltip_text set kind=khaneh="<text>"` line at `refresh_button_labels` time would have made the failure mode (tooltip_text never assigned) trivially diagnosable from the log alone.

The §9.M6 parent rule's "log on every event" wording would, applied literally to UI, produce a per-frame log flood that hides real signal. §9.M6.2's "state-transitions not state" framing keeps the signal-to-noise ratio readable.

**Operational form.**

```gdscript
# Lifecycle log on open/close (lifecycle event).
func open(building: Node3D) -> void:
    print("[ui/production-panel] open kind=", building.get(&"kind"))
    ...

func close() -> void:
    print("[ui/production-panel] close")
    ...

# User-action log on button press (user-action event).
func _on_train_button_pressed(unit_kind: StringName) -> void:
    print("[ui/production-panel] train-button-pressed unit_kind=", unit_kind)
    ...

# State-transition log on affordability flip (NOT on every sweep).
func _refresh_row_affordability(row, ...) -> void:
    var was_disabled: bool = btn.disabled
    # ...recompute new disabled state...
    if was_disabled != btn.disabled:
        # FLIP — log the transition.
        print("[ui/production-panel] button-state unit_kind=", unit_kind,
                " disabled=", btn.disabled, " reason=", reason)
    # Same-result re-evaluation: silent.
```

**Where reviewers enforce.**

- **godot-code-reviewer** checks new UI scripts for the log-this list at expected sites (open/close, button handlers, signal-emit call sites). **Missing UI log on a lifecycle or user-action event is a BLOCKER per §9.M6.** Missing log on a state-transition event is a SUGGEST (the rule is newer; codification was session-8).
- **godot-code-reviewer** also checks for the do-NOT-log list — a `print()` inside `_process` without a state-changed guard is a SUGGEST flag for log-flood risk.

**Where authors apply.**

- **ui-developer** (and any agent shipping UI code) treats the log-this list as part of the implementation, same as §9.M6 parent rule. The do-NOT-log list is the corollary: don't add log noise where there's no signal.
- **Wave brief authors (lead)** specifying a UI Track deliverable should explicitly call out the log requirement and the state-transition-not-state framing: *"Log instrumentation: `[ui/<panel-name>]` tag-prefix on lifecycle (open/close), user actions (button click, key press), state transitions (affordability flips), signal emits (request_train, build_placement_started). Per §9.M6.2 — state transitions, not state."*

**Retroactive instrumentation policy.** §9.M6.2 is forward-only at the rule level. Recent-wave (last 1-2 sessions) UI code is a candidate for opportunistic backfill IF a hard-to-diagnose UI bug surfaces in live-test; don't backfill speculatively. Wave 3A.6 Track 2's `production_panel.gd` is a known candidate for opportunistic backfill (~6-8 print lines, ~30 minutes) if Throne wave or later UI live-test surfaces a hard-to-diagnose interaction with the production panel.

Cites Manifesto Principle 7 (Observability), Principle 5 (debt-paying discipline), Principle 9 (Automated Enforcement). Parent rule: §9.M6 (day-1 log instrumentation). N=2 incidents: Wave 2B BUG-B1 (missing tooltips, live-test diagnosis cycle) + Wave 3A.6 Track 2 ship at `67606ed` (ProductionPanel without `[ui]` tags, session-8 retro fact-list). Cross-references: §9.M6 parent, §9.L7 affordability sweep, Pitfall #1 (Control mouse_filter).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-24 session-8 close — ui-developer-p3s3 origination; UI log-instrumentation gap (Wave 3A.6 Track 2 + Wave 2B BUG-B1) codification]

#### M6.3. Observability is a wave-time gate, not a session-time chore — pre-rule systems back-fill obligation discharges at the wave that touches them

**Sub-rule of §9.M6.** §9.M6 originally scoped to "every NEW system from day 1." Pre-rule systems (combat path, state machine, components shipped Phase 0/1/2 before §9.M6 was codified) carry observability debt. M6.3 tightens the rule: when a wave touches a pre-rule file, the wave is the back-fill discharge moment. Not a separate session-time chore; not a retro action-item to defer; the wave that touches the file is the moment the file's §9.M6 compliance becomes the wave's responsibility.

**User-verbatim refinement (2026-05-27 mid-Wave-3-BD):** *"the log needs to have EVERYTHING except camera movement essentially. otherwise you are blind and just guessing."* The rule's predicate set is therefore: every state mutation (`_set_sim` call), every signal emit (`EventBus.X.emit`), every state transition (`transition_to`), every discrete event, every public method that changes state — **except pure-UI / camera / hover / per-frame visual interpolation** (which is the do-NOT-log set, expanded from §9.M6.2's UI carve-out).

**Rule.** When a wave's brief enumerates files it modifies:
1. **Each modified file is audited at brief-drafting time** for §9.M6 compliance on the paths the wave exercises. The lead grep:
   ```
   git grep -nE "(_set_sim|EventBus\.[a-z_]+\.emit|transition_to)\(" <file>
   ```
   For each hit: is there a `print("[<system>] ...")` line within ~5 lines? If no, the file is non-compliant on that path.
2. **The wave's track deliverables include the §9.M6 back-fill for any non-compliant file touched by the wave.** Same wave, same PR, same merge. Not deferred to "next wave" or "retro."
3. **Mirror-reviewer brief-time review verifies** the audit happened — the brief should cite the audited paths + the back-fill commits planned.

**Why.** N=8 production bugs across sessions (BUG-C1, D1, D2, D4 from prior sessions + BUG-H1, H2, H3, H4, H5, H6, H7, H8, H9 from session 9) followed the same shape: diagnostic-thrash because the system that should have logged was silent. **In session 9 specifically, six consecutive diagnostic round-trips (BUG-H1 → BUG-H8) each required: hypothesize → add a log → ship → live-test → read log → next hypothesis.** The pattern wasn't "logic was wrong"; it was "logic looked right, live-test produced wrong output, the diagnostic chain ran into silence."

**The back-fill-as-action-item failure mode (session 9 evidence):** lead initially proposed deferring the observability sweep to "next wave + session 9 retro" after BUG-H8 fix landed. User corrected: *"hmm i would have prefered doing it straight away but you seem to prefer doing it after, but if we do it after it must be right after retro, this essentially IS an action item from the retro that we've already decided on."* See `feedback_action_items_dont_defer.md` (session 9 memory). The sweep shipped inline as 3 commits on PR #42 (commits `6079e7b` + `7ee9d30` + `1be88d9`) per gp-sys retro reflection: *"observability is a wave-time gate, not a session-time chore. When a wave is briefed, the brief should enumerate every pre-rule file it touches and verify those files emit §9.M6-compliant logs on the paths the wave exercises. If they don't, fix-up commits in the same wave back-fill them."*

**Mechanical brief-time grep (proposal — automatable):**

```bash
# In a wave brief-drafting checklist:
for file in $touched_files; do
    git grep -nE "(_set_sim|EventBus\.[a-z_]+\.emit|transition_to|^func [a-z_]+)" "$file" | while read -r match; do
        # Check for adjacent print within 5 lines
        # ... shell-script-fu, or just visual review of the brief's "touched files" list
    done
done
```

This isn't a lint rule (false-positive risk on legitimate per-tick `_log_diag` debug paths is too high); it IS a mechanical brief-time check that mirror-reviewer runs. The output of the check is a list: "of N modified-file mutation sites, M have no adjacent `print`. M files need back-fill before merge."

**Where reviewers enforce.**

- **Mirror-reviewer brief-time review** runs the mechanical grep against each file the brief proposes to modify. Surface any non-compliant mutation site as a BLOCKER finding.
- **architecture-reviewer + godot-code-reviewer final pass** verify that any pre-rule file modified in the wave now has §9.M6-compliant logs on the paths the wave touched.

**Where authors apply.**

- **Wave brief authors (lead)** add to the brief's track-deliverables: *"§9.M6 back-fill for `<file_A>`, `<file_B>`, ... — each modified pre-rule file gets log instrumentation on paths exercised by this wave. Mechanical brief-time check: see §9.M6.3."* This makes back-fill scope visible at brief-time, not retro-time.
- **Implementer agents** treat the back-fill commits as part of the wave's deliverable shape, NOT separate cleanup.

**Volume budget.** Per the canonical example from Wave 3-BD's observability sweep (`7ee9d30` + `1be88d9`): ~5-30 lines per file, ~10-15 files in a major sweep, ~3 commits to ship cleanly. Wave 3-BD sweep was on the larger end because it back-filled 9 BUG-H's worth of latent debt; typical wave back-fills should be smaller.

**Anti-patterns to flag at review.**

- "We'll add the logs when the bug surfaces" — by then it's 5-10× more expensive.
- "The back-fill is its own wave / next session's problem" — the file gets touched ONCE by this wave; back-fill while the modification context is fresh.
- A "retro action-item" that defers observability work past the wave-that-exposed-the-need. See §9.M6.3 antibody to that specific failure mode.

**N=8 canonical incident chain.** Prior chain (BUG-C1/D1/D2/D4 from sessions 7-8) lived in `feedback_observability_in_log.md` memory; session-9's BUG-H1..H8 doubled the count. The wave-time-gate framing is the lesson from N=8: codification + back-fill obligation only work if discharged at the wave-touch moment, not at session-time review.

Cites Manifesto Principle 1 (Truth-Seeking) + Principle 6 (Honest-tools-not-magic-tricks) + Principle 9 (Automated Enforcement) + Principle 10 (Feedback Cycle — the BUG-H chain IS the feedback cycle working as designed; the lesson is wave-time gate discharge, not retro deferral).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; gp-sys-p3s3 retro reflection + user-verbatim "log everything except camera" refinement (2026-05-27) + N=8 incident count + action-items-don't-defer memory cross-ref → lead codification]

#### M6.4. State-Change-Gated Per-Tick Logging — `_last_X` sentinel pattern for paths that read every tick

**Sub-rule of §9.M6.** Per-tick logging produces noise; no-log loses transition events. The state-change-gated pattern is the canonical middle: cache the last-logged value, log only on transition.

**Actor.** Implementer at moment-of-writing any log-emit that lives inside a per-tick code path. Reviewer (godot-code-reviewer + mirror-reviewer) backstops at brief-time + post-implementation.

**Trigger.** Any of:
- A `print(...)` line sits inside `_sim_tick`, `_step_idle`, `_step_probing`, `_physics_process`, or any function called from `_on_sim_phase` per-tick branch.
- A `print(...)` line reads a value (path_state, target, position, stall-reason) that may be identical across many ticks.
- A debug log fires "every time the same condition is checked" rather than "every time the condition changes."

**Rule.** Cache the last-logged value in a sibling field `_last_X` (where X is the value being logged) and log only on transition:

```gdscript
# Field declaration alongside related state:
var _last_X: <type> = <sentinel-value>  # -1 for ints, &"" for StringNames, null for refs, Vector3(INF, INF, INF) for Vector3s

# In the per-tick code path:
var current_X: <type> = <compute current value>
if current_X != _last_X:
    print("[<system>] X_changed prev=%s curr=%s tick=%d" % [str(_last_X), str(current_X), SimClock.tick])
    _last_X = current_X
```

**Reset discipline.** `_last_X` must be reset to its sentinel value at any natural lifecycle boundary:
- **State-machine instance**: in the state's `enter()` so each engagement gets its own logging cadence.
- **SimNode autoload**: in the autoload's `reset()` so test fixtures don't leak last-logged values across cases.
- **Component**: in the component's `_ready()` or analogous re-init seam.

**Pitfall #16 co-citation.** When `_last_X` is a ref-typed cache (Node, Variant), the same `is_instance_valid()` guard from Pitfall #16 applies — `_last_X` may point to a freed Object between ticks. Don't cast it without validating. The sentinel-comparison `current_X != _last_X` itself is safe (Variant equality on freed Object compares the pointer + tombstone), but reading properties off `_last_X` is not.

**Canonical sites (5 sites converged this wave).**

| Site | Field | Reset | Reference |
|---|---|---|---|
| `TuranController._log_stall_once` | `_last_stall_reason: String = ""` | `reset()` clears to `""` | `turan_controller.gd:303-310` (BUG-H5) |
| `TuranController._pick_target` | `_last_pick_signature: String = ""` | `reset()` clears to `""` | `turan_controller.gd:380-385` (BUG-H5) |
| `UnitState_Moving._sim_tick` | `_last_path_state: int = -1` | `enter()` resets to `-1` | `unit_state_moving.gd` (observability sweep) |
| `UnitState_AttackMove._sim_tick` | `_last_path_state: int = -1` | `enter()` resets to `-1` | `unit_state_attack_move.gd` (observability sweep) |
| `UnitState_Attacking._sim_tick` | `_last_diag_log_tick: int = -1` + `_last_diag_branch: StringName = &""` | `enter()` resets both | `unit_state_attacking.gd:158-160` (BUG-H7) |
| `MovementComponent.request_repath` | `_last_logged_repath_target: Vector3 = Vector3(INF, INF, INF)` | NOT reset (sentinel guard) | `movement_component.gd:88` (BUG-H9) |

**Why.** Per-tick log-flood (BUG-H5 explosion: 30 lines/sec/unit, 800KB log in 4 min) destroyed diagnostic signal. State-change-gating is the only way to surface a transition event without per-tick noise. The pattern wasn't codified going in — emerged ad-hoc across 5 fix-up sites in Wave 3-BD. Codification prevents re-discovery cost for the next per-tick log site.

**Hybrid: rate-limited + state-change-gated.** Some sites combine both (e.g., `UnitState_Attacking` logs branch + at-most-once-per-second). The pattern:

```gdscript
var should_log: bool = (current_branch != _last_diag_branch) \
    or (_last_diag_log_tick == -1) \
    or (SimClock.tick - _last_diag_log_tick >= 30)
if should_log:
    print("[attacking] ...")
    _last_diag_log_tick = SimClock.tick
    _last_diag_branch = current_branch
```

Use hybrid when the inside-state diagnostic is useful periodically (e.g., monitoring a long walk-toward-target) AND on transition (engage / disengage). Pure state-change-gating is sufficient when transitions are the only interesting event.

**NOT a lint rule.** Mechanical detection of "this print should be state-change-gated" produces false positives on legitimate per-tick debug paths (e.g., test-fixture `_log_diag` calls, dev-mode verbose modes). The discipline lives at code-author + reviewer level.

**Where reviewers enforce.**

- **godot-code-reviewer** flags un-gated `print(...)` inside any function called per-tick (member of any `_sim_tick`, `_step_*`, `_on_sim_phase` chain, etc.) as a SUGGEST → BLOCKER if the rate is high enough to produce log-flood.
- **mirror-reviewer brief-time review** flags brief prose that adds a new per-tick log site without specifying gating mechanism as a finding.

Cites Manifesto Principle 1 (Truth-Seeking — diagnostic signal preserved through gating) + Principle 6 (Honest-tools-not-magic-tricks — flood-without-signal IS magic-trick log instrumentation) + Pitfall #16 (cached ref discipline).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-28 session-9 close; gp-sys-p3s3 retro reflection (5-site convergence) → lead codification]

#### M7. Defensive-fallback-masking — production code MUST NOT guard contract-promised members with has_method / has_signal / has_property

**Rule.** When a spec, contract doc, or canonical pattern promises that member X exists on type T, production code MUST access X directly. Defensive guards — `if X.has_method(&"Y"):`, `if X.has_signal(&"Z"):`, `if X.has(&"K"):` (Dictionary key probe), `if X.get(&"K", default) != default:` — are FORBIDDEN at the module-scope of production code outside a documented allowlist. Test fixtures and forward-compat scaffolding are the only sanctioned exceptions, and each must carry a one-line comment explaining WHY the guard exists.

**Actor.** Implementer at moment-of-writing. Reviewer (godot-code-reviewer + mirror-reviewer) backstops at brief-time + code-time.

**Trigger.** Any `has_method` / `has_signal` / `has_property` / `Dictionary.has(key)` / `Dictionary.get(key, default-then-discriminate)` call inside `game/scripts/` (excluding `game/scripts/.../tests/` test surfaces).

**Why (N=5 across project lifetime):**

1. **BUG-C1 (Wave 3A.6, session 7).** Building schema's `bldg_<kind>` access used `Dictionary.get(&"K", null)` returning null-discriminated; null-fallback silently zeroed all cost lookups; affordability gate trivially passed; deduction skipped; training spawned for free in live-test. Fix at `0679630`.

2. **BUG-D2 (Wave 3A.5 retroactive, session 8).** `FogSystem._validate_team_bounds()` defensively returned `false` for out-of-bounds team_id; TURAN team_id passed actual bounds but was masked by an off-by-one; vision sources for Turan never registered; AI vision broken silently. Fix-wave at session 8 close.

3. **BUG-3 of fix-up-1 (Wave 3-Sim Track 2 `a5f5f21`, session 10).** `HeadlessMatchRunner` called `ResourceSystem.get_coin_x100(team)` guarded by `has_method`. `get_coin_x100` does not exist on ResourceSystem (actual API: `coin_for(team)` returning float). Guard returned zero-fallback; every match's `iran.coin_x100_at_end` was 0 regardless of actual economy. Surfaced at integration-time mirror review.

4. **`has_signal(&"unit_spawned")` (Wave 3-Sim Track 2 `c05ba77`, session 10).** Runner subscribed to `EventBus.unit_spawned` defensively; the signal didn't exist in EventBus; `iran_first_piyade_tick` was hardcoded to -1 in every match. Hard-asserted at runner spawn after RISK C2.1.

5. **`has_method(&"get_health")` (Wave 3-Sim Track 2 `c05ba77`, session 10).** Throne capture guarded `target.get_health()` with has_method; the guard was a stale relic — post-Wave-3-BD, every Throne has a HealthComponent by contract. Hard-asserted at runner spawn after RISK C2.4.

**The common failure shape.** Spec says X exists. Production code defensively guards X with has_X. X never lands (forgotten in implementation) OR X has a different name than the spec promised. Guard returns the false-branch silently. Production code's downstream behavior runs against a zero-fallback / null-fallback / unconditionally-skipped path. The bug surfaces only when output is examined for correctness, NOT when code runs or tests pass.

**The defensive guard is functionally equivalent to silent error suppression.** It converts a contract violation (member X promised, X missing) into a zero/null output the consuming code can't distinguish from a real-zero result. The mechanical fix is hard-assert at the call site:

```gdscript
# WRONG (defensive-fallback-masking):
if ResourceSystem.has_method(&"get_coin_x100"):
    coin_x100 = ResourceSystem.get_coin_x100(team)
# else: coin_x100 stays at default 0 silently

# RIGHT (hard-assert; fails loudly on contract regression):
assert(ResourceSystem.has_method(&"coin_for"), "ResourceSystem must expose coin_for(team) — see RNC §X")
coin_x100 = int(ResourceSystem.coin_for(team) * 100)
```

The assert is the documentation of the contract dependency. Future contract regression crashes loudly at the call site with the assert's message, not silently miscomputes downstream values.

**Mechanical lint candidate (L7).** Pattern-detection of forbidden guards is mechanizable:

```
FORBID at production-code module-level (game/scripts/ excluding /tests/):
  - if X.has_method(&"Y"):
  - if X.has_signal(&"Y"):
  - if X.has_property(&"Y"):
  - if X.has(&"Y"):  # Dictionary key probe
  - if X.get(&"Y", default) != default:  # null-discrimination pattern
EXCEPT entries in tools/L7_allowlist.txt with one-line WHY comment.
```

Allowlist seed (engine-architect to enumerate at L7 implementation time):
- Tests/fixtures (exempt by path).
- Forward-compat scaffolding (e.g., FarrSystem.register_emitter seam pre-Phase-5; documented with "this guard exists because X ships Phase Y").
- Truly cross-Phase-compat code (rare; require approval).

**Where reviewers enforce.**

- **godot-code-reviewer brief-time + code-time** flags any new `has_method` / `has_signal` / `has_property` / `Dictionary.has` guard outside the allowlist. Without a WHY-comment + allowlist entry, the finding is BLOCKER.
- **mirror-reviewer integration-time** runs an extra pass against new code looking for newly-introduced defensive guards. Mirror's session-10 catch of the two stale guards in HeadlessMatchRunner is the canonical evidence the pattern is detectable at code review.

**Where authors apply.**

- **Implementer agents** treat the "if has_X then call X else fallback" pattern as a red flag during writing. The 5-second self-check: *"Is X promised by a contract / spec / canonical pattern? If yes, hard-assert. If no, why is the code referencing X at all?"*
- **L7 implementation** (carry-forward for next QA wave): qa-engineer adds the lint pattern + allowlist seed; CI fails on un-documented guards.

**Anti-patterns to flag.**

- "Defensive coding is good practice" — yes for inputs at trust boundaries (user input, external APIs), no for in-project method/signal/property existence where the contract is the boundary.
- "The guard makes the code more resilient" — it makes the code more silent. Resilience-via-silent-fallback is the opposite of resilience for diagnostic purposes.
- "We might want X to be optional in the future" — then make the spec say so. If the spec is silent on optionality, code must treat X as required.

Cites Manifesto Principle 1 (Truth-Seeking — silent zero is a lie about state) + Principle 6 (Honest-tools-not-magic-tricks — defensive guard IS the magic-trick that papers over contract drift) + Principle 9 (Automated Enforcement — L7 lint converts the manual rule into mechanical check).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; engine-architect-p3s2 retro reflection (drafted rule + lint seed) + N=5 incident chain across BUG-C1 / BUG-D2 / Wave 3-Sim fix-ups → lead codification. Promotes Task #214 from "retro candidate" to shipped §9 rule.]

#### M8. Real-data round-trip — any consumer using mock/fixture for a producer's output MUST include a test piping the real producer's canonical output through the consumer

**Rule.** A consumer (aggregator, parser, downstream system) that uses a mock/fixture/dry-run substitute for a real producer's output is permitted ONLY when paired with at least one test that:
1. Pipes a sample of the real producer's canonical output (or the spec's example output) through the consumer **without the mock/dry-run path**.
2. Asserts on concrete values (not just type/shape/parse-success).
3. Is named to identify its role as the drift sentinel (e.g., `test_round_trip_canonical_X_through_Y`).

The sibling real-data test is the structural drift sentinel. Mock-based tests verify the consumer's logic; real-data tests verify the consumer reads the producer's actual schema. Without the latter, mock-based tests certify nothing about the canonical contract.

**Actor.** Implementer at moment-of-writing the consumer. Reviewer (qa-engineer + mirror-reviewer at integration-time) backstops.

**Trigger.** Any of:
- A test imports a hand-crafted Dictionary literal as a stand-in for a real system's output.
- A `--dry-run` / mock fixture is the sole input to a consumer's tests.
- A bash/Python tool reads NDJSON / JSON / signal-payload and the corresponding test uses a static fixture file rather than a real-producer-emit.

**Why (N=2, session 10):**

1. **F4 / BLOCKER C1.1 (Wave 3-Sim Track 3, session 10).** `tools/run_ai_vs_ai_batch.sh --dry-run` injected rotating fixture NDJSON; `test_batch_runner_dry_run.gd` 9 flows asserted against that fixture; both sides used `units_alive_at_end` / `events_summary` while spec + runner emitted `combat_units_alive_at_end` / `events`. Tests passed because fixture and assertions were self-consistent; aggregate.json from real runs would silently zero every drifted field. Mirror caught it only by cross-checking against the spec doc. qa-engineer's fix-up at `19e2ba0` added Flow 10 round-trip test feeding spec §5 Example A through `aggregate_match_results.py` and asserting on concrete values (e.g., `iran_units_alive.median == 6.0`, `turan_probes_fired.total == 6`). Both would have been 0 before the fix.

2. **F4-sibling: turan.farr_x100_at_end semantic drift (Wave 3-Sim spec v1.0.0).** balance-engineer's spec emitted Iran's Farr value in the Turan slot as a forward-compat placeholder. Self-consistent within the spec, semantically wrong per the spec's own §7.3 notes. A real-data round-trip test reading `turan.farr_x100_at_end` and asserting it represents Turan state (not Iran proxy) would have caught the drift at spec-write time.

**Rule's specific shape.** The round-trip test should:
- Load the canonical spec's example output verbatim (NDJSON / JSON / Dict literal copied from the spec doc itself).
- Pipe it through the consumer using the real (non-mock, non-dry-run) code path.
- Assert on per-field concrete values that the consumer should preserve (not just `result != null` or `result.has(field)`).
- Be named with a sentinel-pattern suffix (`test_*_canonical_*` / `test_*_round_trip_*` / `test_*_spec_example_*`).

**Schema-drift fix-up template (qa-engineer addition).** When a field-name drift is dispatched as a fix, assignee MUST do a full spec §-by-§ field enumeration cross-check against the consumer's read paths, not only the named drifts. Mirror catches load-bearing drifts that show in test output; non-load-bearing drifts go silent until they become load-bearing. The 5-minute mechanical diff is cheap relative to half-repaired fixtures.

Operational form:
1. Open canonical spec section side-by-side with the consumer's read paths (file + line numbers).
2. Diff field-by-field: every spec-promised field must have a corresponding consumer read; every consumer read must reference a spec-promised field.
3. Add to the round-trip test any field-pair that wasn't already asserted on.

**Distinguishes from §9.M6.4 state-change-gated logging.** M6.4 is about log noise / signal preservation in production code. M8 is about test-surface drift between producer and consumer. Both share the "silent failure mode" theme but operate at different layers.

**Where reviewers enforce.**

- **qa-engineer brief-time review** flags any new mock/fixture/dry-run code path in a Track's deliverable that lacks a sibling round-trip test as a SUGGEST → BLOCKER if the producer's spec is non-trivial (5+ fields).
- **mirror-reviewer integration-time review** cross-checks consumer test files against canonical spec docs (the M8 BLOCKER pattern at session-10 close was caught exactly here).
- **architecture-reviewer** flags new schema-bearing contracts (e.g., NDJSON spec, signal payload spec) that lack a stated round-trip-test requirement in the doc itself.

**Where authors apply.**

- **Implementer agents** writing a mock/fixture path treat the sibling round-trip test as part of the deliverable, not a nice-to-have. The dispatch template should explicitly include "ship `--dry-run` test + sibling round-trip test against spec example" as the qa-engineer deliverable shape.
- **Spec doc authors (balance-engineer)** include at least one concrete example output (NDJSON line, JSON object) in the spec's §5 / Examples section. The example IS the round-trip-test input.

**Anti-patterns to flag.**

- "The fixture matches the spec, so the test verifies the spec" — only if the fixture was generated FROM the spec, not from memory or another test.
- "The dry-run path is fast, so it's the only test path we need" — fast tests against the wrong thing are worse than slow tests against the right thing.
- "Round-trip tests are integration tests; we have unit tests already" — unit tests verify component logic; round-trip tests verify contract conformance. Different jobs, different surfaces.

Cites Manifesto Principle 1 (Truth-Seeking — round-trip test asserts the consumer reads the producer's actual output) + Principle 7 (SSOT — spec doc IS the canonical source; round-trip test verifies the consumer reads it) + Principle 9 (Automated Enforcement — the round-trip test is the mechanical drift-detection seam).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-06-08 session-10 close; qa-engineer-p3s3 retro reflection (drafted rule + schema-drift fix-up template) + balance-engineer-p3s3 retro reflection (turan.farr semantic-drift sibling N=2) + Flow 10 precedent from `19e2ba0` → lead codification.]

---

### §9.N — Investigation Reports

#### N1. Single-report-per-investigation; multi-round investigations produce one consolidated final report

**Rule.** When a specialist is dispatched for a read-only investigation (engine-architect investigations, qa-engineer flake diagnoses, balance-engineer simulation analyses), the investigation produces ONE structured report. Supplementary detail is provided on lead's explicit request, not volunteered proactively.

**Refinement for multi-round investigations.** When a multi-round investigation produces N rounds of "ship → fail → re-diagnose," the FINAL consolidated report (e.g., engine-architect's spike v1.0.0 archaeology) is the canonical artifact, NOT the per-round reports. Per-round reports serve as interim status pings; the consolidated artifact is the truth-source for the next inheritor.

**Operational form.** Investigation reports default to "single report; request additional detail if needed." Lead may pre-ask for option-space enumeration if needed; the default is concise.

**Canonical incidents:**
- **Original (session-2 wave-1B):** engine-architect-p3s2's L25 investigation produced a primary report (root cause + three fix paths + recommendation) and an unsolicited supplementary report (Path D and Path E variants). The supplement added context-window weight on lead with low marginal yield — the supplementary paths didn't change lead's decision.
- **Refinement (session-3 wave-1C):** 4-round navmesh diagnostic. Each round was technically a new investigation (new hypothesis space, new prescription), so per-round reports were correct in context. The consolidated end-of-investigation amendment (`docs/WAVE_1C_NAVMESH_SPIKE.md` v1.0.0) is the canonical artifact.

Cites Manifesto Principle 4 (Lean Iteration — smallest thing that produces real data).

[History → STUDIO_PROCESS_HISTORY.md §9 2026-05-17 session-2 + 2026-05-17 session-3 meta-process cluster]

---

## 10. Sync Log

The chronological sync log + session-close records have been moved to a separate file at the 2026-05-18 audit-driven restructure: **`docs/STUDIO_PROCESS_SYNC_LOG.md`** (append-only chronological record of every multi-agent sync run + session-close log entry).

**Why split.** STUDIO_PROCESS.md is read every session per CLAUDE.md; the sync log is reference material consulted at retro time or when investigating session history. Keeping the operating contract focused on currently-binding rules is the discipline; the historical record lives next to it but is read on a different cadence.

**Append-only.** At each retro, append the new sync entry to `STUDIO_PROCESS_SYNC_LOG.md`, NOT here.

---

## 11. Future Sync Templates (To Be Filled)

- *(no syncs queued — Phase 0 implementation is the next planned activity)*

---

*Read this doc before facilitating a sync. Update it after every retro. The process improves only as fast as the document does.*

---

## 12. Operating Modes — Design vs. Implementation

The studio process documented above (syncs, OST patterns, Convergence Review, retros) is **heavyweight by design**. It earns its cost during *design and planning*, where a single wrong contract decision compounds across phases. It becomes *friction* during *implementation*, where the contracts are set and execution is the bottleneck.

We explicitly run in two modes.

### 12.1 Design / Planning Mode

**When:** before a phase begins. At tier transitions. When a cross-cutting decision arises that no single agent can make alone. When implementation reveals an architectural gap that a contract revision (not just a code patch) needs to address.

**Activities:**
- Studio syncs (Author + Reviewers, Constraint Negotiation, Devil's Advocate, Open Consultation)
- Convergence Review (Pattern E) before each tier transition or end of major decision-cluster
- Retro practice — every sync produces process updates in this doc

**Output:** ratified contracts + retro entries. No code.

**The lead's role:** servant-leader facilitator (per §6).

### 12.2 Implementation Mode

**When:** after the contracts for a phase are ratified. The default operating mode during a phase.

**Activities:**
- Specialists work independently in their owned files (per `02_IMPLEMENTATION_PLAN.md` agent table)
- TDD discipline: tests first, code second, refactor third (per Testing Contract conventions)
- Async coordination via the architecture document and PR comments — not via syncs
- Commits land on feature branches, merge to main via PR

**Output:** working code with passing tests. The architecture document gets updated as subsystems land.

**The lead's role:** active orchestrator, not bottleneck. Lead facilitates dispatch (right agent to right work per ownership-discipline L2), serializes cross-agent coordination (worktree-vs-sequential per E1, blocked-commit broadcast per D6), runs heartbeat protocol when agents go silent (§12.6), verifies branch hygiene + version bumps + architecture doc updates at PR review, and conducts wave-close + session-close retros (K1). The v1.0-era framing of "lead silent unless something escalates" was correct for single-agent solo work; the persistent-instance multi-agent architecture (G1) requires active orchestration. Lead does NOT do specialist work (per L2 ownership-beats-warmth), and does NOT facilitate during specialist execution — but is constantly active on coordination, dispatch, and verification.

### 12.3 The TDD Discipline (Implementation Mode)

Implementation tasks follow Test-Driven Development per Manifesto Principle 1 (Truth-Seeking — every conclusion rests on evidence) and Principle 9 (Automated Enforcement). Specifically:

1. **Read the orientation layer first:** `MANIFESTO.md` → `CLAUDE.md` → `docs/ARCHITECTURE.md` → relevant contract(s). Don't skip the architecture doc — it tells you where the work fits and what's already built.
2. **Write failing tests** that capture the expected behavior. For a state transition: a test that asserts the unit ends up in the right state after a tick. For a Farr drain: a test that asserts the value decreased by the right amount. Use `MatchHarness` and `advance_ticks(n)` per Testing Contract §3.
3. **Implement the minimum to pass.** Resist gold-plating. The contract specifies the surface; the test specifies the behavior; everything else is implementation.
4. **Refactor with confidence.** Tests catch regressions. The CI lint rule catches off-tick mutation. The determinism regression test catches simulation drift.
5. **Update the architecture document.** Move the subsystem from 📋 Planned to 🟡 In progress when you start, to ✅ Built when tests pass and it's wired in. Add a line to §6 (Plan-vs-Reality Delta) if the implementation diverged from the spec — Truth-Seeking.
6. **Commit on a feature branch, PR to main.** Pre-commit hook runs the lint + test suite. Blocked commits indicate a real problem; don't bypass.

If implementation reveals a contract gap (something that needs a decision, not just an implementation choice), **stop and escalate**:
- Design/feel/balance question → append to `QUESTIONS_FOR_DESIGN.md`
- Cross-system architectural gap → flag for a sync (often a brief Constraint Negotiation between two agents)

Do not silently invent contract changes during implementation. The contract is the agreement; if reality requires changing it, that's a decision, not a fix.

### 12.4 Mode Switches — Explicit Markers

We don't drift between modes. We switch deliberately:

- **Entering implementation mode** — after a Convergence Review ratifies (or after a phase plan is locked), the lead announces the switch and the agents shift OUT of deliberative team-channel participation INTO async implementation work. They are NOT terminated (see §12.5 and the §9 Agent persistence rule — same instances persist across the mode switch); they simply stop participating in deliberative discussion and start receiving implementation dispatches via `SendMessage`. ⚠️ Earlier text said "stand down from the team channel" which was ambiguous; the current meaning is "stand down from deliberation, NOT from the system" — they remain alive and addressable.
- **Returning to design mode** — when an architectural gap surfaces, when a phase ends and a retro is needed, or when a tier transition approaches, the lead reactivates the team channel and convenes a sync. Implementation work pauses on affected files. The SAME instances who were doing implementation work re-enter deliberation mode (per §12.5 — mode separation is cognitive, not instance separation).

### 12.5 Mode separation is COGNITIVE, not INSTANCE separation (2026-05-14)

The mode boundary above is about the *kind of thinking* the agents are doing (open-ended deliberation in design mode; bounded execution in implementation mode), NOT about *which instances* are doing it.

**The same agent instances persist across all three temporal points of a decision arc:**

1. **Open Space sync (design mode)** — agents debate the decision.
2. **Implementation waves (implementation mode)** — those SAME agent instances ship the code that implements the ratified decision.
3. **Retro (back to design mode)** — those SAME agent instances reflect on the lived experience of implementing what they debated.

This continuity is **load-bearing for the studio process to work**. Documents (§9 rules, ratified contracts) are not substitutes for agents-who-remember-arguing-the-rule. The rule says X; the agent who debated knows WHY X, what alternatives were rejected, what the limits of X are, what they were worried about that didn't get fully resolved. Re-instantiated agents lose all of that.

**Why this matters (canonical incident):** Phase 3 session 1 dispatched fresh fix-wave agents to ship work governed by the 2026-05-13 Open Space's ratified Pitfall #7 mitigation (worktree-per-agent). The fresh agents had the §9 rule as authority but not the lived debate. They executed against documented design and hit a runtime gap (the unimplemented `isolation: "worktree"` tool param) nobody had verified. The engine-architect instance who had ARGUED for worktrees would have asked at dispatch time: "wait, has anyone verified the tool's worktree-isolation parameter actually works?" That question only comes from lived memory of the debate, not from reading the rule.

**Operational consequence:** when the lead spawns specialist agents for implementation work that derives from a prior Open Space sync, the lead **resumes the existing persistent instance** of that specialty rather than spawning fresh. Same applies for retro participants — the agents who argued the decision and shipped the code are the same instances who reflect on what happened.

**The cycling exceptions stay:** Tier-3 ephemeral one-shot agents (fix-wave, surgical bug-fix) and Mode-B PR-time fresh reviewers (per the two-class review architecture rule in §9) are explicit fresh-instance dispatches. Everything else defaults to instance persistence across the decision arc.

Cites Manifesto Principle 1 (Truth-Seeking — lived debate is evidence the ratified rule alone can't replace), Principle 6 (Partnership — continuity of self is how agents take care of each other across time), and Principle 10 (Feedback Cycle — the loop only closes if the same minds that hypothesized are the same minds that observe and revise).

The architecture doc is the bridge — the artifact that carries the design across the mode boundary into implementation, so individual agents don't need the full studio process baggage to orient.

### 12.5.1 Cross-session persistence (2026-05-17 extension)

The §12.5 within-session decision-arc continuity rule **extends to cross-session boundaries by default.** The same in-team persistent agents (architecture-reviewer, godot-code-reviewer, shahnameh-loremaster, gameplay-systems, world-builder, ai-engineer, balance-engineer, qa-engineer, engine-architect, and any future in-team specialists) **persist across session boundaries** until one of four conditions holds:

1. **The user explicitly disengages an agent** (rare; would only happen for a structural role change or end-of-project teardown).
2. **A retro produces a system-prompt change the running instance cannot accommodate via conversation** — i.e., a change that contradicts the agent's accumulated session memory in a way internalize-via-conversation cannot resolve. Most retro updates are additive (new rules, new disciplines, new checklist items) and the running instance internalizes them through the retro discussion itself; only structurally contradictory updates warrant reboot.
3. **A new agent class is introduced** that didn't exist in the prior session.
4. **A model-tier change is applied to the agent's definition** (added 2026-06-08, Phase 3→4 boundary). A running instance cannot hot-swap its underlying model; re-pinning `model:` in the agent-def takes effect only at next spawn. When the project deliberately upgrades a role's model (e.g., the Fable-5-era re-pins of 2026-06-08), the affected instances undergo a **generational reboot**: each live instance writes a structured handoff (open carry-forwards, calibration baselines, lived failure-mode summaries — the high-signal memory this section exists to protect) which is archived to `docs/AGENT_HANDOFFS_PHASE3.md` (or the era-appropriate successor); the instance is then marked decommissioning in AGENT_REGISTRY.md, and the next dispatch of that role spawns fresh on the new model with the handoff doc as a named prerequisite read. This converts the lived-memory-vs-capability tradeoff from an either/or into serialize/restore: imperfect (serialization loses the tacit layer) but bounded, and the capability gain is permanent. Logged as a PROCESS_EXPERIMENTS candidate: does serialized handoff memory measurably preserve the gen-1 behaviors this section's canonical-validation paragraph attributes to lived memory?

**Why default-persistence matters across sessions:**

- **Lived failure-mode memory.** An agent who lived through session 2's Pitfall #7 incidents (61d891f, 1e8a213) carries the *experience* of the race conditions, not just the §9 rule that documents them. When wave 1C dispatches in session 3, that agent reads `git status` differently than a fresh-spawn would — they've seen the race fire and feel the pull toward the pathspec discipline as muscle memory.
- **Calibration baselines.** Layer 1.5 enumeration took godot-reviewer 5 minutes at wave 1A and 4 minutes at wave 1B; the "automaticity threshold crossed" signal *requires* remembered prior timing. A fresh-spawn loremaster reviewing the third cultural-note template clone cannot say "this is the third clone of the template I locked at wave 1A; the variant-detection question is now standardized." Only the persistent instance has that frame.
- **Carry-forward state continuity.** Arch-reviewer's wave 1C carry-forward (is_gatherable flip moves to _on_construction_complete; modifier registration also gates on is_complete; Layer 1.5 enumeration discipline applies) is held as session memory. Cross-session persistence preserves the carry-forward; fresh-spawn re-loads from `git log` + ARCHITECTURE.md + retro notes, which is strictly less than the running instance's full state.
- **The cost is real but bounded.** Persistent agents accumulate context-window weight session over session. Compaction handles the bulk of this; what matters is the *high-signal* memory survives compaction (retro-internalized disciplines, lived failure modes, carry-forward state). The cost is paid once per session in modestly more aggregation work for lead; the benefit compounds.

**Why this isn't auto-reboot-after-retro:**

A retro that produces a system-prompt change is forward-looking — the system-prompt edit is for any *future fresh-spawn* that comes into existence (rare; new agent class, new project, or explicit reboot). The *currently running* instance has already internalized the change through the retro discussion itself. Rebooting would lose the lived experience without gaining anything the running instance doesn't already know. Reboot is the exception, not the procedure.

**Canonical empirical validation (Phase 3 session 2 close retro, 2026-05-17):** all five retro inputs received this session produced outputs unreachable by fresh-spawn agents — specifically, cross-agent self-criticism (loremaster's Observation 3: "I praised §4.7.5 as form-follows-source at the engine layer; engine-architect's later investigation showed the mechanical half is inert"), automaticity-threshold timing claims (godot-reviewer's Layer 1.5 5-min → 4-min comparison), and held-end-to-end decision-arc tracking (arch-reviewer's verbatim wave-1A → wave-1B carry-forward citations). These observations *require* persistent-instance lived memory; ephemeral retro agents would produce shallower reviews of the artifacts without the meta-layer reflection on the *behavior of producing the artifacts*.

**Operational form going forward:**

- **Session N+1 dispatches go to the same agent IDs as session N.** The persistent instance picks up exactly where they left off. Brief at session start summarizes "where the session currently is" but does NOT re-onboard the agent — they remember.
- **Mid-session-spawn pattern stays orthogonal.** When a new specialist class is introduced mid-session (this session's qa-engineer-p3s2 and engine-architect-p3s2 are canonical cases), the dispatch is a fresh spawn that THEN becomes persistent. The persistence kicks in from spawn time forward, not retroactively.
- **Mode B fresh-spawn reviewers (peiman-manifesto-reviewer, fresh-instance arch-reviewer at PR time) stay ephemeral by design.** Their value comes from *absence* of project-context; cross-session persistence would defeat their purpose. The two-class review architecture in §9 governs which roles are persistent vs ephemeral; this rule applies only to the persistent class.

Cites Manifesto Principle 1 (Truth-Seeking — lived experience is evidence the documentation alone cannot replace), Principle 5 (Platforms, Not Features — persistent agents are platforms for institutional memory), and Principle 10 (Feedback Cycle — feedback loops that close across sessions require continuity of self across sessions).

### 12.6 Agent-Liveness Protocol (2026-05-17, Phase 3 session 4 close retro)

A protocol — a defined exchange shape between lead and dispatched agents — for detecting when an agent's channel has gone silent and recovering communication. Authored in response to two channel-mismatch incidents in P3S4: loremaster-p3s2's ~60min silence (producing reflective content as assistant-text, invisible to lead) and world-builder-p3s2's "see my text above" retro response (4-bullet summary only via SendMessage; full reflection as assistant-text).

**Lower threshold than gut-feel 60min.** At 60min lead has lost an hour of wall-clock to undetected channel loss. At 30min the cost is half, with the same detection certainty.

**Lead's heartbeat ping shape:**

```
to: <agent-id>
summary: "[heartbeat]"
message: "Ping — status?
  If working: brief progress note.
  If blocked: state the block.
  If done: SendMessage your deliverable."
```

Two sentences max. The summary tag `[heartbeat]` is grep-able in lead's inbox for retro forensics — at session close, retro authors can grep heartbeat dispatches to identify which agents had liveness gaps and reconstruct context.

**Agent's obligated response shape (SendMessage, within next tool-use cycle):**

One of three forms — bracketed tag is the structural marker:

- `[heartbeat-ack: working]` + one-line progress
- `[heartbeat-ack: blocked]` + one-line block description + ask
- `[heartbeat-ack: done]` + SHA or report inline (do NOT respond with a pointer to assistant-text content)

**Three-strike escalation:**

| Strike | Lead action |
|---|---|
| 0 (initial silence >30min) | Send first heartbeat ping. |
| 1 (no response within agent's next reasonable tool-use cycle, ~5-10 min) | Send second heartbeat ping with explicit channel reinforcement: "Your prior heartbeat had no response. Reminder: SendMessage is the only authoritative channel; assistant-text is invisible to lead." |
| 2 (no response to second ping) | Presume channel-mismatch failure. Lead's options: (a) re-dispatch with elevated channel-instruction explicitness; (b) carve-out the work to a different persistent instance; (c) per §12.5.1 reboot clause, presume the instance is in a broken state and reboot (rare — usually re-dispatch suffices). |

**When the protocol does NOT apply:**

- Tasks explicitly marked `polling` or `waiting-on-external` in the dispatch brief. (e.g., agent waiting on user input or build result — silence is expected.)
- Tasks where the dispatch brief explicitly says "no response needed; ship the work" — though even these benefit from a final `[heartbeat-ack: done]` for liveness signal.

**Pairs with:** §9 2026-05-17 (session-4) meta-process cluster's dispatch-channel-discipline rule (which prescribes WHEN agents respond — every dispatch) and agent-channel-discipline rule (which prescribes the CHANNEL — SendMessage, never assistant-text). The heartbeat protocol is the *recovery mechanism* when those rules fail in practice.

Cites Manifesto Principle 6 (Partnership — silence is signal loss, not consent), Principle 9 (Automated Enforcement — response shape binds; vague text does not), and Principle 10 (Feedback Cycle — closed loops require both ends to remain in contact).

---

## 13. Versioning — Strict SemVer 2.0.0

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
