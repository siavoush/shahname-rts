---
title: Studio Process — How the Virtual Studio Operates
type: process
status: living
version: 1.7.0
owner: team
summary: Operating contract for multi-agent collaboration — discussion patterns, facilitator role, retro practice, SemVer policy, mode separation, sync log.
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
  - active format rules (§9, accumulating from retros)
  - frontmatter schema for project documentation
  - sync log (chronological record of every sync run)
references: [MANIFESTO.md, ARCHITECTURE.md]
tags: [process, syncs, retros, ssot, modes, semver, frontmatter]
created: 2026-04-30
last_updated: 2026-05-17
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

- *(2026-05-01, post-Convergence-Review)* **Joint addenda (peer-negotiated cross-contract additions) have a round limit.** If a peer-to-peer negotiation bounces between options for more than 3 rounds, the lead intervenes with a tie-breaker proposal. **Why added:** the Convergence Review's joint addendum (AI gather multiplier application point) bounced between (a)/(b)/(a-modified)/(b-with-tweak)/(dual-factor) across ~7 messages before landing. The final design (dual-factor) was good — genuine design ambiguity, peer negotiation found a creative solution neither agent had pre-staged — but ~2 of those rounds were avoidable with earlier facilitator intervention. ([Convergence Review retro](#convergence-review--phase-0-foundation-ratification))

- *(2026-05-01, post-cleanup-audit)* **SSOT discipline: each fact lives in exactly one file. Other files reference, never restate.** When writing or editing markdown, ask: *"if this fact changes, how many files would I need to update?"* If the answer is more than one, refactor: pick a single owner, replace the duplicate with a link or a one-line summary that points at the owner. Indexes and orientation summaries are allowed only if (a) they're clearly framed as "see X for full content" and (b) they cannot drift independently — i.e., a change to X cannot leave the summary stale. **Why added:** LLMs (this agent included) tend to over-explicate, restating canonical content across multiple docs. In a project this size, that produces silent contradictions within a few revision cycles. Caught and refactored after creating ARCHITECTURE.md by duplicating the directory map and agent table from 02_IMPLEMENTATION_PLAN.md. Cites Manifesto Principle 7 (Single Source of Truth) — "reference the source rather than copying it. When you need information in a second place, point to the original."

- *(2026-05-01, post-Phase-0)* **Scenes need visual smoke tests beyond unit tests.** A scene-level test that loads the scene, renders one frame, and verifies expected visual elements catches the class of bug (elevation, framing, visibility) that headless unit tests structurally cannot catch. **Why added:** Phase 0's camera elevation bug was missed by 130 passing unit tests; surfaced only when Siavoush eyeballed the running game. Tests checked the math; no test checked whether the camera would actually frame the scene. ([Phase 0 retro](#phase-0-implementation--foundation-built))

- *(2026-05-01, post-Phase-0)* **Doc cross-validation: facts referenced in two contracts must explicitly link to the SSOT.** When a fact lives in one contract canonically and is mentioned in another (e.g., FarrSystem storage scale in both Sim Contract §1.6 and FarrConfig.gd comment), the duplicate must be a "see X" pointer with explicit link to the SSOT. The link is the binding. **Why added:** in Phase 0 wave 1, FarrConfig comment claimed ×1000 storage while Sim Contract §1.6 says ×100. SSOT discipline (existing rule) addresses the principle; this rule operationalizes the cross-link mechanism. ([Phase 0 retro](#phase-0-implementation--foundation-built))

- *(2026-05-01, post-Phase-1-wave-2)* **Verify git tree at session close, not just lint + tests.** After an agent reports "shipped X," the lead runs `git ls-tree HEAD -- <expected paths>` to verify the files are actually in version control. Lint and tests pass locally because they read from disk; if the agent forgot to `git add` new files (especially in new directories), the commit ships with only the existing modifications and the new files remain untracked. The merged branch silently loses them. **Why added:** caught during Phase 1 wave 2 commit that `game/data/balance.tres` (and 6 sub-resources + balance_data.gd) was authored by balance-engineer in Phase 0 commit `81ed6e5` but never staged. The commit shipped with only doc updates; the data files lived on disk uncommitted through Phase 0 merge to main and into Phase 1 work. Local tests passed because Godot reads from the working tree. Recovered as part of `a82e0ac`. ([Phase 1 wave 2](#phase-0-implementation--foundation-built))

- *(2026-05-01, post-Phase-0)* **Pre-commit gate must filter to tracked files when N agents run in parallel.** Otherwise the hook races on staged-vs-untracked test files from concurrent agents and produces non-deterministic gate results. Mitigation: `git diff --cached --name-only` filter on the lint and GUT scope. **Why added:** Phase 0 session 4 wave 1 had 4 agents committing in parallel; pre-commit hook produced flaky results until all agents had pushed. LATER work documented for the next session that runs N>2 agents. ([Phase 0 retro](#phase-0-implementation--foundation-built))

- *(2026-05-01, frontmatter-rollout)* **Every project markdown doc carries YAML frontmatter per the schema below.** New docs ship with frontmatter from creation. Existing docs without frontmatter are added on first edit. The frontmatter is the doc's machine-readable contract; the body is the human-readable content. The frontmatter is the SSOT for: title, type, status, version, owner, audience, read_when, prerequisites, references, ssot_for, tags. Any of those facts appearing in the body without a frontmatter source is a SSOT violation. **Why added:** without frontmatter, an agent scanning N docs has to ingest each one to decide if it's relevant, drifting attention and filling context with noise. The schema lets an agent make a read/skip decision in <30 lines. The `ssot_for` field directly operationalizes the SSOT discipline rule above — facts become machine-greppable to their canonical owner.

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

- *(2026-05-03, post-Phase-1-session-2)* **Wave-close review: at the end of each wave, BEFORE PR creation, the lead spawns `godot-code-reviewer` and `architecture-reviewer` in parallel against the wave's commit range.** Both produce structured review output (verdict, blocking issues, non-blocking suggestions, nits, what's clean). Blocking issues route back to the original agent for fix; non-blocking suggestions and nits surface in the PR description. The reviewers are read-only — they do not write code, do not push commits, do not modify the project beyond their review text. **Why added:** Phase 1 session 2 surfaced one bug at the lead's live-test (re-entrant signal recursion in `DoubleClickSelect`) that all 535 unit + integration tests had passed. Static review by an agent with Godot expertise OR architectural awareness would have caught it earlier. The trial run on PR #4 validated both agents catch real structural drift (Manifesto principle grading, contract-fit checks, layer-leak detection) even when the live-test surfaces nothing. The intervention is now under measurement as Experiment 02 in `docs/PROCESS_EXPERIMENTS.md`. Cites Manifesto Principle 1 (Truth-Seeking): trust but verify — peer review of code BEFORE merge is the test-side mirror of "lead verifies file diff against design decisions." The two agent definitions live in `.claude/agents/godot-code-reviewer.md` and `.claude/agents/architecture-reviewer.md`. ([Phase 1 session 2 retro](#phase-1-session-2--multi-select-formation-movement-hud-polish))

  > ⚠️ **Note (2026-05-14, post-Phase-3-session-1):** the "lead spawns ... in parallel" wording above refers to historical fresh-dispatch mechanics. **Current mechanism** per the Agent persistence rule + Two-class review architecture rule (both 2026-05-14, below): reviewers are SESSION-PERSISTENT (lead `SendMessage`s existing instances at each wave-close), and a SECOND set of FRESH-spawn reviewers runs separately at PR-time. The wave-close review intent is unchanged; the dispatch shape evolved.

  **Lead workflow at wave close:**
  1. All wave commits land on the feature branch.
  2. Lead spawns BOTH reviewers in parallel (one Agent dispatch each, run_in_background=true) with the wave's commit range and known-context briefing.
  3. Lead waits for BOTH to return. Reviews are independent — reviewers don't coordinate.
  4. Lead reads both reviews. If either has blocking issues, lead routes the fix back to the original agent (or fixes inline if trivial).
  5. Once both verdicts are APPROVE (or all blockers fixed), lead opens the PR with the review summaries in the description.

  **The Known Godot Pitfalls list** in `docs/PROCESS_EXPERIMENTS.md` (top section, promoted from Experiment 01's growing-list) is the godot-code-reviewer's primary checklist. Each entry is backed by a specific commit. New pitfalls discovered in future sessions get appended; the list is the project's institutional memory of "things that look fine but break in the live game."

  **Why two agents, not one:** their lenses are different. `godot-code-reviewer` asks "is this code correct? does it avoid Godot-engine pitfalls?" `architecture-reviewer` asks "does this code fit the target architecture? does it honor manifesto principles? does it respect the contracts?" The first finds bugs the second wouldn't notice; the second finds drift the first wouldn't notice. Confirmed in the PR #4 + Phase 2 session 1 trials — convergent on a few items, but each agent surfaced things the other did not.

- *(2026-05-04, post-Phase-2-session-1)* **Anti-loop brief language: every agent dispatch brief includes the explicit commit-discipline cycle.** The verification-loop pattern (Deviation 01) — agents reading their own work in the working tree as "shipped by another agent" and standing down without committing — hit FIVE TIMES in Phase 2 session 1 alone. The four agents who broke the pattern at end-of-session all had this exact language baked into their brief:

  > "Cycle: implement → pre-commit gate → `git diff --staged --stat` shows ONLY your files → commit → `git log -1` confirms your SHA → THEN report back. Don't issue 'task already shipped, standing down' reports. If you think work exists, run `git log` and check author/SHA. Your task list is the authority on what YOU have done — but the SHA in `git log` is the authority on what's COMMITTED."

  **Why added:** the language is observably load-bearing. The first three agents in Phase 2 session 1 wave 1 (gameplay-combat-core, ai-eng-attacking-state, balance-eng-combat-data) all hit the pattern. Adding the explicit cycle to subsequent dispatch briefs (BUG-02 fix, click-tolerance, BUG-06, Farr contrast) produced four clean ships in a row. Cites Manifesto Principle 9 (Automated Enforcement): rules that aren't enforced erode — the discipline must be in the brief, not in folklore.

  **What this rule mandates:** lead's agent dispatch templates (and any kickoff doc that describes per-deliverable workflow) must include the cycle verbatim. New brief shape:

  ```
  ### Workflow (anti-loop)
  1. Read the relevant docs.
  2. Write failing tests first (TDD red).
  3. Implement.
  4. Pre-commit gate (lint + GUT) must pass.
  5. Stage your files explicitly: `git add` per file.
  6. Run `git diff --staged --stat` — verify ONLY your files.
  7. Verify `git diff BUILD_LOG.md docs/ARCHITECTURE.md` shows ONLY your additions.
  8. Commit. Title: descriptive per project convention.
  9. Run `git log -1 --oneline` — confirm your SHA at HEAD.
  10. THEN report back.
  ```

- *(2026-05-04, post-Phase-2-session-1)* **Per-TDD-cycle commits, not end-of-wave batches** (under measurement as Experiment 03). Each agent commits IMMEDIATELY after each `red → green → refactor` cycle (one new test + implementation pair = one commit), NOT at end-of-wave. The end-of-wave coordination commit, if any, is docs-only. **Why added:** Phase 2 session 1's `aa429ef` commit-race (Deviation 02) was caused by three agents each holding ~10 file modifications uncommitted in the shared working tree at end-of-wave; one agent's `git add` swept the others' files into a misattributed commit. Per-TDD commits keep each agent's working set small; cross-agent contamination becomes mathematically harder. **Status:** under controlled measurement as Experiment 03 in `docs/PROCESS_EXPERIMENTS.md`. Graduates to permanent rule after Phase 2 session 2's verdict.

- *(2026-05-04, post-Phase-2-session-1)* **Shared append-only docs (BUILD_LOG.md, ARCHITECTURE.md, etc.) get `git diff` verified before staging.** Before staging any shared doc file, run `git diff <doc-file>` and confirm the diff contains ONLY your additions — no stray text from other agents in flight. If you see cross-agent content in the diff, flag it BEFORE staging (don't `git add` it; coordinate with the lead). **Why added:** in Phase 2 session 1, multiple agents independently observed the cross-contamination pattern (`aa429ef` swept up wave 2A + 2B files because the index contained more than the agent's intent at commit-time). The verification step is cheap (~5 sec); the misattribution is expensive (corrective commits, archaeology rot, manual re-attribution).

- *(2026-05-04, post-Phase-2-session-1)* **Session-close retro is now a structured task, not optional.** At the end of every implementation session (post-merge), lead executes a retro that does five things:
  1. **Promote Pitfall candidates** — godot-code-reviewer's KEEP-recommended candidates move from Experiment 01 verdict text into the Known Godot Pitfalls list at the top of `PROCESS_EXPERIMENTS.md`. Each promoted entry: name, mechanism, rule, canonical incident commit, regression test reference.
  2. **Update STUDIO_PROCESS §9** with new active rules (this section).
  3. **Promote architectural LATER items** from §6 entry prose into a structured `ARCHITECTURE.md` LATER section. Indexed and prioritized rather than scattered.
  4. **Close / extend / open experiments** per their verdict criteria. Active experiments tagged in `PROCESS_EXPERIMENTS.md`; resolved ones move to the archive section.
  5. **Draft the next session's kickoff doc** with the latest Known Pitfalls list verbatim, anti-loop brief language baked in, current Deviation count baseline, active Experiment list.

  **Why added:** without a closure step, learnings rot. Pitfall candidates stay scattered in verdict text; experiment outcomes don't propagate to the next kickoff brief; LATER items live as comments in §6 entries instead of an indexed list. By session 5, you'd be re-discovering the same patterns. The retro is ~30 min of doc work and produces compounding returns. Cites Manifesto Principle 10 (Feedback Cycle): "every system has the right to demand its own improvement" — the retro is how the system claims that right.

- *(2026-05-12, post-Phase-2-session-2)* **Wave-close review is now PERMANENT (Experiment 02 graduated).** Two confirming sessions (Phase 1 sess 2 + Phase 2 sess 2). Every wave-close, lead dispatches `godot-code-reviewer` and `architecture-reviewer` in parallel BEFORE PR creation. Both produce structured review output. Blocking issues route back to original agents; non-blocking suggestions and nits go in the PR description. **Reviewers also post their full structured review as a GitHub PR comment via `gh pr review --comment` so the review trail is discoverable inline in the GitHub UI**, not just in agent chat / PR description. **Convergent findings — items flagged independently by both reviewers — auto-promote to LATER index items at the next retro.** Cites Manifesto Principle 1 (Truth-Seeking) and Principle 10 (Feedback Cycle).

  > ⚠️ **Note (2026-05-14, post-Phase-3-session-1):** "lead dispatches ... in parallel" describes the historical fresh-spawn mechanic. Current mechanic is `SendMessage`-resume to persistent reviewers (see Agent persistence rule below). Reviewer count also evolved: the 2026-05-13 entry adds `shahnameh-loremaster` as a third reviewer when culturally invoked. **Convergent-finding promotion criterion** clarified: when ≥2 of the active reviewers (out of 2 or 3 depending on whether loremaster is invoked) flag the same item independently, it auto-promotes to a LATER index item at the next retro.

- *(2026-05-12, post-Phase-2-session-2)* **Per-TDD-cycle commits + anti-loop brief language are PERMANENT (Experiment 03 graduated for sequential single-agent waves).** Verification-loop occurrences dropped from 2+ to 0 across Phase 2 session 2; lead-proxy commits dropped from 3 to 0. The anti-loop cycle (implement → pre-commit gate → `git diff --staged --stat` confirms only your files → commit → `git log -1` confirms SHA → THEN report back) is observably load-bearing for sequential single-agent dispatches. **All agent briefs include the cycle verbatim.** Per-TDD-cycle commits (commit per `red → green → refactor` pair, NOT batched at end-of-wave) suppress cross-agent contamination for sequential waves.

- *(2026-05-12, post-Phase-2-session-2)* **Parallel-agent wave-close commit serialization is INSUFFICIENT and needs a structural fix (Experiment 04 forthcoming).** Phase 2 session 2's wave 1 had three parallel agents staging concurrently; the per-TDD-cycle discipline did NOT suppress the commit-race (`cac29cc` swept TuranKamandar; `3fefeea` swept TuranSavar — Pitfall #7's 2nd and 3rd occurrences). The race occurs at commit-write time when one agent's pre-commit gate (~2 min test runner) lets another agent's working-tree state mature into the commit. **Discipline-side mitigation alone is insufficient for parallel-agent waves.** Two structural alternatives queued for Open Space sync between Phase 2 close and Phase 3 kickoff:
  1. **Worktree-per-agent** (preferred per arch-reviewer-p2s2) — each parallel agent operates in `git worktree add` directory, sharing `.git` but with independent working trees. Eliminates the race.
  2. **Lead-orchestrated commit serialization** — agents request a commit-window-of-one from lead before staging; lead grants windows sequentially. No infrastructure change.

  Until Open Space resolves: **prefer sequential single-agent waves over parallel-agent waves when wave deliverables would otherwise share docs (`BUILD_LOG.md`, `ARCHITECTURE.md`)**. Phase 2 session 2's waves 2A / 2B / 3 (sequential) all shipped clean; wave 1's parallel-three stomped twice.

- *(2026-05-13, Open Space sync, Phase 2 close → Phase 3 kickoff)* **Pitfall #7 mitigation RATIFIED (NOT YET RUNTIME-VERIFIED — see ⚠️ note below): parallel-wave dispatches use `git worktree`-per-agent isolation. Option 2 (lead-orchestrated commit serialization) is VETOED.**

  > ⚠️ **Status update (2026-05-14, post-Phase-3-session-1):** the worktree-per-agent design is sound at the layer it targets (working-tree race), but the Agent-tool's `isolation: "worktree"` parameter turned out to be **documented-but-unimplemented at the runtime layer.** Three parallel fix-wave agents dispatched with the parameter in Phase 3 session 1 shared the same working tree and hit the same Pitfall #7 race the resolution was supposed to close. See LATER L23 in `docs/ARCHITECTURE.md` §7. **Current working pattern:** sequential single-agent dispatch for any write-active wave; parallel only for read-only review agents. The design below remains correct *if* a real worktree is created (either by the runtime fixing the parameter, or by the lead manually pre-creating `git worktree add <path>` and passing the path in the brief). The 2026-05-14 "Process-mitigation runtime verification" rule was added in direct response to this incident — no future "structural fix" claim ratifies into §9 without runtime verification. Both engineering POVs (engine-architect on technical-foundation lens; gameplay-systems on DX lens) converge on Option 1 hybrid. Option 2 is rejected on two independent grounds: (a) wrong-layer — race is at working-tree level, not index level, so serializing the commit window doesn't close it; (b) fights the just-graduated per-TDD-cycle rule by incentivizing batched commits at wave-close. **The new permanent rule:**

  **Wave-mode declaration.** Every wave brief explicitly stamps a mode:
  - **`parallel-worktrees`** — wave has multiple INDEPENDENT deliverables touching DISTINCT code surfaces. Lead pre-creates a worktree per dispatched agent (`git worktree add ../<repo-name>-<dispatch-id> <branch>`) BEFORE dispatch. Each agent receives their worktree path in the brief; agent never manages worktree setup. Each worktree has independent `.uid` / `.import/` regeneration on first scene load (~1 min cost; one-time per worktree). All worktrees commit to the SAME branch; git serializes the underlying `.git` write lock. Push order is wave-close serialized by the lead.
  - **`sequential-shared-tree`** — wave has one deliverable, OR multiple deliverables that touch shared files (`balance.tres`, `main.tscn` heavily, large doc additions). Single agent owns the working tree for the wave's duration. Per-TDD-cycle commits apply.

  **Decision boundary** (lead's call at wave-design time):
  - Parallel-worktrees: 3 unit types in different files; integration tests independent of game code changes; UI changes parallel to gameplay changes.
  - Sequential-shared-tree: anything touching `balance.tres` (cross-cutting writes); single-deliverable waves; docs-aggregator commits; emergency bug-fix sweeps.

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
  10. Fast-forward race at push time: shared branch means each worktree pushes commits to the same `feat/<branch>`. Git's local `.git` lock serializes writes; the remote push is a normal `git push` (with the same fast-forward rules we already follow at PR time). No new mechanism needed.

  **Cites Manifesto Principle 4 (Lean Iteration):** worktrees buy back parallel-agent throughput without giving up isolation; Option 3 (sequential-only forever) gives up parallelism categorically. **Cites Principle 8 (Separation of Concerns):** the race lives at the working-tree level; the mitigation lives at the working-tree level. Wrong-layer mitigations (Option 2) are rejected on architectural grounds. The decision lands as Experiment 04's intervention; first formal trial in Phase 3 session 2's parallel-3+ wave. Validation marker: **zero Pitfall #7 incidents in Phase 3 session 2** if intervention works.

- *(2026-05-13, Open Space sync, Phase 2 close → Phase 3 kickoff)* **Sim Contract amended to 1.4.0** with two paragraph-length addenda. **§1.3 init-time carve-out:** parent `_ready` writes to child component fields via plain `set()` BEFORE `SimClock` has run its first tick are exempt from the self-only-mutation rule. The exemption applies ONLY pre-first-tick; runtime component-to-component writes still require method-call discipline. **§1.5 tween-in-callback addendum:** tweens that write ONLY to UI-local state (fields not read by any sim consumer) may be started inside signal handlers. Tweens writing to sim-state fields must use queue-then-drain (next-frame deferral via `call_deferred`). Both addenda close spec-gaps flagged by reviewers in Phase 1 session 2 + Phase 2 session 2. See `docs/SIMULATION_CONTRACT.md` 1.4.0 for full text.

- *(2026-05-13, post-Open-Space-sync)* **`shahnameh-loremaster` agent available for wave-close review trio on culturally-load-bearing surfaces.** Third reviewer agent (alongside `godot-code-reviewer` + `architecture-reviewer`) for waves that touch unit/building/hero naming, narrative content, symbolism, or any new mechanic with a Shahnameh referent. Definition: `.claude/agents/shahnameh-loremaster.md`. **Read-only; produces APPROVE / SUGGEST / FLAG / NEEDS-DESIGN-CHAT verdicts via SendMessage.** Does NOT invent design (gaps route via `QUESTIONS_FOR_DESIGN.md`). Does NOT hold unilateral veto (lead arbitrates conflicts with implementation constraints). **Dispatch judgment is lead's:** invoke when a wave touches culturally-resonant territory (new unit types in Phase 5+ roster, hero abilities, building thematic work, Kaveh Event presentation, campaign scenarios). Skip when work is purely technical (test infrastructure, pathfinding tuning, performance). Cites the CLAUDE.md rule "cultural authenticity and the Persian epic's themes treated as load-bearing design constraints, not flavor." First likely dispatch context: Phase 5 hero work (Rostam / Sohrab / Esfandiyar arcs).

  > ⚠️ **Note (2026-05-14, post-Phase-3-session-1):** loremaster is also SESSION-PERSISTENT when invoked (Tier-1 per Agent persistence rule below). Lead `SendMessage`s existing instance at each culturally-relevant wave-close. Loremaster also has a NEW second dispatch context — **brief-time review for template-cloning surfaces** (first instance of a culturally-load-bearing template: first strings.csv pattern, first abstract base class header, first cultural-note block in a state script). See updated agent definition at `.claude/agents/shahnameh-loremaster.md`.

- *(2026-05-14, post-Phase-3-session-1)* **Cross-cutting schema verification at wave-close — triangulated rule covering three layers.** When a wave introduces a new participant in a shared classification surface (new base class with `unit_id`/`team` duck-type, new SceneTree group membership, new entry in an input-handler dispatch chain, new autoload registry consumer), three complementary disciplines apply at wave-close BEFORE PR:
  1. **Code-review (architecture-reviewer):** grep every existing consumer of the schema (`is_in_group(&"X")`, `has_method(&"Y")`, duck-type filters reading `unit_id`/`team`) and verify each handles the new participant correctly. Cite consumer `file:line` in the verdict. **BLOCKING.** New base classes are never local changes; they extend every duck-type filter in the project.
  2. **Test-design (gameplay-systems):** ship cross-feature integration tests pairing the new participant with EVERY existing consumer surface (selection paths: click + double-click + box-select; dispatch paths: move + attack + gather + construct), each verifying correct INCLUSION or EXCLUSION. Per-feature tests pass; per-feature × existing-feature crossover catches the leak.
  3. **Test-coverage disclosure (qa-engineer):** wave-close report includes a **"Headless blindspots: what live-test must cover that these tests cannot"** paragraph. Explicitly names (a) input-routing behavior the tests fake (GUI dispatch, sibling order, `_process` loop), (b) scene-topology assumptions the fixtures bypass (group membership, NavigationObstacle bake state), (c) any visual/rendering path not exercised. Makes the testing-vs-runtime boundary legible to the lead BEFORE live-test begins.

  **Why added:** Phase 3 session 1 surfaced BUG-08 / BUG-10 / BUG-11 at lead live-test despite the headless suite + reviewer trio approving. All three bugs were "new participant in shared classification surface" failures (Khaneh duck-type leaks into box-select; BPH sibling-order convention reversal; BuildPlacementHandler missing in dispatch). Three retro contributions converged on the same insight from different layers. Per Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 10 (Feedback Cycle). [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1)* **SSOT prose contradictions across docs are BLOCKING at wave-close review, not LATER.** When a reviewer finds that two SSOT-tagged docs (or a doc and a project header / regression test) contradict each other on the same fact, the reviewer MUST resolve it empirically (write a probe test, read the engine source, ask the lead) BEFORE approving the wave. Deferring the contradiction to a LATER index entry is INSUFFICIENT and DOES NOT meet the bar. **Why added:** Phase 3 session 1 BUG-10 (Godot `_unhandled_input` sibling-order reversal) shipped because `docs/PROCESS_EXPERIMENTS.md` Pitfall #5 prose said "reverse-tree-order" and `attack_move_handler.gd` header said the opposite, and the architecture-reviewer flagged the contradiction as future LATER L22 instead of resolving it empirically before approval. Live-test caught it; could and should have been a wave-close catch. Architecture-reviewer's own retro framing: "I had the evidence in hand and deferred. That was a discipline failure, not a scope failure." Cites Manifesto Principle 1 (Truth-Seeking) and Principle 7 (Single Source of Truth). [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1)* **Wave-close reports include a "What tripped me up in this wave" first-person section.** Mandatory ~1-paragraph block on every wave-close report, written by the shipping agent BEFORE stand-down while context is still peak-fresh. Captures friction points, dead-ends, moments the agent almost shipped a bug, surprising semantics that consumed time. **Why added:** retro-time specialist-agent dispatches are necessarily fresh instances reading post-hoc artifacts; subagents are ephemeral and the original's lived friction is lost when they stand down. The wave-close moment is the only window where in-the-moment friction is capturable. Without this section, retros can only do post-hoc review — never lived-experience aggregation. This is the LLM-system adaptation of the human-retro pattern "invite the people who did the work" (which can't translate verbatim because the people don't persist). The captured-at-shipping artifact substitutes for the can't-re-summon person. Cites Manifesto Principle 10 (Feedback Cycle): every system has the right to demand its own improvement; capture the data while it's still data. [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1)* **Live-test cadence is the real acceptance funnel; "PR opens after live-test reaches clean state," not after wave-close review approves.** Headless tests + reviewer trio are NECESSARY but NOT SUFFICIENT for PR. The pattern: ship → lead live-test #1 → diagnose surfaced bugs → fix-wave → lead live-test #2 → … until live-test produces zero new findings. THEN open PR. **Why added:** Phase 3 session 1 needed live-test #1 (surfaced BUG-08/09 + Farr gauge precision gap) → fix-wave → live-test #2 (surfaced BUG-10 + BUG-11) → fix-wave → live-test #3 (clean) before PR was ready. Headless caught what it structurally can; the convergent retro finding above ("new participant in shared classification surface") is precisely about closing the headless blindspot, but residual runtime behavior + visual readability + cross-feature interactions remain live-test territory. The funnel is: tests catch most → reviewer trio catches drift → live-test catches the rest. Skipping any layer ships bugs to main. Cites Manifesto Principle 4 (Lean Iteration — fail fast, in live-test, not in production) and §9's existing "scenes need visual smoke tests beyond unit tests" rule (operationalized into a cadence here). [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1)* **Process-mitigation claims that promise "structural fix" must include runtime verification before the §9 entry can land as ratified.** When a sync or retro proposes a process mitigation framed as "structural" (vs. discipline-side), the mitigation entry MUST cite a runtime verification step — a probe test, a first-real-trial smoke-test, an empirical confirmation — proving the mitigation actually works at the layer it claims to operate at. Document claims ≠ runtime behavior. **Why added:** Open Space 2026-05-13 ratified worktree-per-agent as the structural fix for Pitfall #7. The Agent-tool `isolation: "worktree"` parameter turned out to be a documented-but-unimplemented runtime gap. The mitigation as documented was unimplemented. Phase 3 session 1's first parallel-3 fix-wave dispatch hit the SAME Pitfall #7 race the structural fix claimed to close. LATER L23 captures the gap; sequential dispatch is the working pattern until it closes. Confidence in process mitigations should be calibrated against runtime VERIFICATION, not document claims. Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 9 (Automated Enforcement — rules that aren't enforced erode). [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1)* **`tools/run_game.sh` is the project's standard interactive-launch path.** Wrapper script in `tools/` runs Godot against the project and tees stdout+stderr to `/tmp/shahnameh.log`. Claude Code sessions read the log via `Read` / `tail` — no copy-paste round-trips. **Why added:** Phase 3 session 1's BUG-10 diagnosis (Godot `_unhandled_input` reverse-sibling-order) took one round-trip via log piping vs. the 3+ rounds it would have taken via copy-paste. The infra paid off on first deployment. Set as default launch for all future live-test sessions. Lead's kickoff docs should mention `tools/run_game.sh` as the canonical launch command. Cites Manifesto Principle 4 (Lean Iteration — cheap infra, compounding returns). [Phase 3 session 1 retro](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1 follow-up)* **Agent persistence: persistent-by-default for in-team reviewers and within-session specialists; ephemeral for fix-wave / one-shot agents; fresh-spawn for PR-time external-audit reviewers.** Subagent runtimes support both ephemeral (one dispatch + stand-down) and persistent (SendMessage resumes with full context) lifecycles. The lead's prior pattern was reflexive-shutdown after each wave; the new default is persistence for roles where institutional memory compounds. Three tiers:

  - **Tier 1 — Session-persistent reviewers (default).** `architecture-reviewer`, `godot-code-reviewer`, `shahnameh-loremaster` (when culturally invoked). Spawn once at session start; the lead `SendMessage`s them at each wave-close; they reply with structured review carrying memory of prior waves. Their pattern-recognition compounds — wave 1B's review benefits from wave 1A's context. Stand down only at session close.
  - **Tier 2 — Within-session specialist persistence (default for multi-wave specialists).** If `gameplay-systems` ships waves 1A, 1B, and 1C in the same session, it is the SAME persistent instance across all three — not three fresh dispatches. Wave 1B's implementation benefits from wave 1A's lived friction. Cycle the instance (stand down + fresh spawn) only when context overflows or when the role's domain shifts substantially mid-session.
  - **Tier 3 — Ephemeral one-shot agents (no change).** Fix-wave agents, surgical bug-fix dispatches, parallel-trial agents that ship one specific deliverable. Spawn fresh, ship, stand down. No persistence value.

  **Why added:** Phase 3 session 1's retro surfaced a "lived experience gap" between agents that shipped work and agents dispatched at retro time. The gap was framed as inherent ephemerality, but a closer reading of the runtime confirms persistence is supported — the lead was choosing ephemerality by reflex. Siavoush flagged this directly: terminal lifespan is weeks (using `claude --resume` to skip auto-compact on updates), so session-persistent agents accumulate real institutional memory across many waves. The §9 rule about "What tripped me up in this wave" (2026-05-14 batch) becomes BACKUP CAPTURE rather than primary signal in the persistent-default world — primary signal is "ask the agent who lived the wave; they remember."

  **Note on PR-time fresh instances:** there is a distinct fourth class — **fresh-spawn at PR-time** — for roles whose value depends on project-context-naivety. See the next §9 rule (Persistent/fresh review architecture) for details.

  Cites Manifesto Principle 5 (Platforms, Not Features — persistent agents are platforms for accumulating institutional memory) and Principle 10 (Feedback Cycle — agents that remember can compound their own learning). [Phase 3 session 1 retro follow-up](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1 follow-up)* **Two-class review architecture: persistent in-team reviewers + ephemeral fresh-spawn PR-time external-audit reviewers.** Two different review stages, two different reviewer classes, two different lenses.

  **Stage 1 — Wave-close review (in-team, persistent).** At each wave-close before PR creation: persistent reviewers (`architecture-reviewer`, `godot-code-reviewer`, `shahnameh-loremaster` if invoked) review the wave's commits. They have session memory — they remember prior waves, prior decisions, prior verdicts. Their value: **catch drift WITHIN the team's worldview** — "this wave is contradicting what you yourself approved in wave 1A."

  **Stage 2 — PR-time review (external audit, fresh-spawn).** When the lead opens a PR to main, BEFORE merge: two fresh-spawned reviewers run in parallel.
   - **Fresh-instance `architecture-reviewer`** (same agent definition as the persistent one; new instance with no session memory). Reads the whole PR diff at once, against `ARCHITECTURE.md` + contracts. Different lens from the persistent instance: catches "we incrementally agreed to N small things; the sum has drifted from where we started." The persistent instance approves each wave one at a time, in context; the fresh instance asks "considered as one merged change, does this PR's full shape match the target architecture?"
   - **`peiman-manifesto-reviewer`** (new role, agent definition at `.claude/agents/peiman-manifesto-reviewer.md`). Audits the PR against the **canonical** [Peiman Khorramshahi manifesto](https://github.com/peiman/manifesto) — the 10 principles for building things that last. Reads ONLY the PR diff and the canonical manifesto. Deliberately does NOT read the project's `MANIFESTO.md` (that's the project's *interpretation* — reading it anchors the reviewer to the team's worldview), nor the contracts, nor `ARCHITECTURE.md`, nor any other agent definition. Catches **drift OF the team's worldview itself** — the slow normalization the in-room agents can't see because they've all watched it happen.

  Both PR-time reviewers terminate after the PR merges (or closes). The persistent wave-close reviewers stay alive for the next session.

  **The two PR-time reviewers do not communicate with the persistent instances of the same agent definition.** Contamination by accumulated context defeats the fresh-eyes purpose. Lead is the only synthesizer of both PR-time verdicts.

  **Why added:** Phase 3 session 1's retro made two structural observations: (a) persistent reviewers accumulate valuable memory but (b) accumulation creates anchoring that hides systemic drift. The two-class architecture captures both: persistent for compounding memory at wave-close, fresh for adversarial audit at PR-time. The "Peiman" naming is intentional — پیمان is Persian for *covenant / promise / oath*, and the manifesto IS the project's covenant. The reviewer is its keeper.

  **Workflow:**
  1. Session start → lead spawns Tier-1 persistent reviewers.
  2. Each wave-close → lead `SendMessage`s persistent reviewers with the wave's commit range. Reviews come back. Lead addresses blockers, opens PR after all waves shipped clean.
  3. PR creation → lead spawns fresh-instance `architecture-reviewer` + `peiman-manifesto-reviewer` in parallel. They review the whole PR against architecture+contracts and canonical manifesto respectively.
  4. PR-time blockers route back: architectural drift → fixes commits to PR; manifesto violations → discussion (some are blocking, some surface design-chat questions via `QUESTIONS_FOR_DESIGN.md`).
  5. PR merges → fresh-spawn reviewers terminate. Persistent reviewers continue for next session.
  6. Session close (only when terminal will shut down for Claude Code update or end-of-project) → persistent reviewers stand down.

  Cites Manifesto Principle 1 (Truth-Seeking — adversarial fresh-eyes catches what in-room familiarity can't) and Principle 7 (SSOT — the canonical manifesto, not the local interpretation, is the source of truth for the project's promises). [Phase 3 session 1 retro follow-up](#phase-3-session-1--economic-loop-foundation)

- *(2026-05-14, post-Phase-3-session-1 follow-up)* **Decision-arc instance continuity: the SAME agent instances persist from Open Space → implementation waves → retro.** Not just "session-persistent" but "continuous across the temporal arc of a single decision." When an Open Space sync ratifies a design, the agents who argued for it are the SAME instances dispatched to implement it in subsequent waves, and the SAME instances who reflect on it at retro. Documents are not substitutes for agents-who-remember-arguing-the-rule; the rule says what, but only the agent who debated knows *why*, what was rejected, what the unresolved worries were. See §12.5 for the canonical incident (Phase 3 session 1's L23 verification gap, which the engine-architect-who-argued-for-worktrees would have caught at dispatch time if they'd been the dispatched instance). **Operational form:** when the lead dispatches a specialist for work derived from a prior Open Space sync, the lead uses `SendMessage to <existing-persistent-instance>` rather than `Agent({subagent_type: ...})`. Same for retro participants — the agents who lived the arc are the ones who reflect. The cycling exceptions (Tier-3 ephemeral one-shot + PR-time fresh reviewers) remain as documented. Cites Manifesto Principle 1, Principle 6 (Partnership — continuity of self is how agents take care of each other across time), Principle 10 (Feedback Cycle — the loop only closes if the same minds that hypothesized are the same minds that observe and revise). [Phase 3 session 1 retro follow-up](#phase-3-session-1--economic-loop-foundation)

### 2026-05-17 cluster (Phase 3 session 2 close retro)

The following rules land as a single coherent cluster from Phase 3 session 2's close retro. They were extracted from five persistent-agent retro inputs (world-builder, godot-code-reviewer, architecture-reviewer, shahnameh-loremaster, engine-architect) plus lead's own self-reflection. Most are refinements of existing §9 rules; a few are net-new. Each carries its own citation back to the canonical incident that produced it.

- *(2026-05-17, anti-loop staging discipline cluster)* **Unconditional `git commit -- <pathspec>` form for every commit.** The defensive form is now the canonical default, not an opt-in defense. Every `git commit` uses `git commit -m "..." -- <named-file-list>` form regardless of whether the committer believes they're the only active committer. The "I'm alone right now" assumption was empirically wrong twice this session (61d891f, 1e8a213). The pathspec is a *structural* lock; the index `--stat` verification step is *observer-dependent* and momentum-defeatable. **Why added:** wave-1A Pitfall #7 incident 61d891f and wave-1B Pitfall #7 incident 1e8a213 both demonstrated that committer-discipline must close the race window structurally, not aspirationally. World-builder's wave-1B retro self-diagnosis: "I read the stat correctly and committed anyway without pathspec ringfencing. The pathspec form is a physical lock, not just a verification step." Cites Manifesto Principle 9 (Automated Enforcement). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17, anti-loop staging discipline cluster)* **Stash-on-pre-commit-block: when the hook blocks, `git stash` immediately.** Leaving staged state in the working tree creates the contamination surface for the next agent's commit. The blocked committer's verification cycle (`git diff --staged --stat` twice + pathspec form) doesn't help if a parallel agent commits before the block clears — their commit pulls in the still-staged files. Stash closes the race window from the blocked-committer's side. **Operational sequence:**
  1. Pre-commit hook fails.
  2. Verify the failure is in someone else's WIP (not your own logic): `bash tools/lint_simulation.sh` + targeted test rerun on your files only.
  3. `git stash push --staged -m "WIP-<wave>-<task>-blocked-on-<otheragent>"`.
  4. Wait for the unblocking commit to land (poll `git log -1 --oneline` periodically; or DM the other agent for ETA).
  5. `git stash pop`.
  6. Re-run the canonical 5-step staging discipline; commit cleanly.
  **Why added:** wave-1A and wave-1B both had pre-commit-hook flake events where the blocked committer left staged state during recovery. gp-sys-p3s2's wave-1B Commit 4 was the first operational instance of the stash-on-block pattern (clean recovery + no contamination). Cites Manifesto Principle 1 (Truth-Seeking — observe the race, don't deny it). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17, anti-loop staging discipline cluster)* **Broadcast `[blocked]` to lead via SendMessage when pre-commit hook fires.** The block is otherwise invisible to lead until the next commit attempt races. A `[blocked]` SendMessage produces a visible artifact in lead's inbox; lead can serialize commits across agents when needed. **Operational form:** when pre-commit hook fails (regardless of cause), the blocked agent immediately sends `to: team-lead, summary: "[blocked] on <reason>", message: "..."`. Lead reads, decides routing (serialize / wait / lead-takes-over). Closes the asymmetric-discipline gap that single-agent staging discipline cannot close on its own. **Why added:** arch-reviewer-p3s2 proposed the rule at wave-1A retro; gp-sys-p3s2's wave-1B Commit 4 stash-on-block was the first operational instance, validating the discipline. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **SSOT prose re-verifies against CURRENT shipped state at every wave-close + re-review pass — not just at authoring time.** The 2026-05-14 §9 SSOT-prose-vs-shipped-code rule covered the "stale spec at authoring" case but not the "retroactively-stale spec" case. When a contract patch is authored against shipped state at moment T, then shipped state shifts at moment T+1 (a separate commit landing fresh changes), the prose that was correct at authoring is now stale. Wave-close and re-review passes must re-verify prose against the CURRENT shipped state, not trust the authoring-time verdict. **Canonical incident:** Phase 3 session 2 wave 1B BLOCK-C — RNC v1.2.2 §4.5's `is_gatherable = true` example was correct at v1.2.2 authoring (against shipped state from 6d73889); world-builder's 3183c7c subsequently flipped shipped state to `is_gatherable = false`; v1.2.2 prose went stale ~30 minutes after authoring. Arch-reviewer caught the retroactive staleness at re-review. **Operational form:** for every contract review pass (wave-close, re-review, fix-up close), re-verify prose against current `git show HEAD` shipped code for every fact the prose claims. Cites Manifesto Principle 1 (Truth-Seeking — verify, don't trust prior verification). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Spec-wins-over-lead's-casual-reading, with citation-density requirement.** When a lead's brief or message contradicts the project's source-of-truth (CLAUDE.md, MANIFESTO.md, 01_CORE_MECHANICS.md, ARCHITECTURE.md, ratified contracts, DECISIONS.md, 00_SHAHNAMEH_RESEARCH.md), the persistent specialist applies the source-of-truth value AND flags the deviation explicitly with cited evidence. Source material wins per Manifesto Principle 7 (Single Source of Truth). **Citation-density corollary:** the corrector must cite the source by file + section + line numbers (or passage equivalent) AND, where possible, quote one load-bearing sentence from the source. Citation-density matters more than confidence — the correction has to overcome lead-incumbency; reasoning without citation is just another voice. **Canonical incidents:** wave-1B balance-engineer's `coin_cost = 40` catch (cited 01_CORE_MECHANICS.md §5; lead's casual brief said 75); wave-1B loremaster's Jamshid-Pishdadian-triad catch (cited 00_SHAHNAMEH_RESEARCH.md §1 lines 86-88; lead's brief said Jamshid was "tangential"). Both corrections landed because of citation density; neither would have landed on confidence alone. Cites Manifesto Principle 1 (Truth-Seeking — evidence wins over incumbency) and Principle 7 (SSOT). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Distribution-discipline: ownership beats warmth.** When dispatching a task with a CLAUDE.md file-ownership domain owner, the persistent instance for that owner gets the work — even if a different persistent instance is warmer (more relevant carry-forward, faster turnaround). "Give it to your best / most active dev" is a classic human anti-pattern that lives equally in lead behavior with agents. Persistent agents amplify the trap because "warmest" becomes "the one whose context is most loaded with relevant memory." Cross-functional team with domain depth is the model; persistence ≠ engagement priority. **Operational form:** at dispatch time, lead asks: "what's the CLAUDE.md ownership domain for these files?" That answers WHO. "What's the warmest instance for this work?" answers WHEN (it's the tiebreaker, not the default). **Mid-wave rebalance discipline:** when lead's initial dispatch violated ownership, rebalance to the rightful owner is done with explicit scenario-enumeration — the new owner's brief lists which scenarios are already-shipped vs scenarios-remaining, so the rebalanced agent doesn't re-do work or miss handoff state. **Canonical incident:** Phase 3 session 2 wave 1B distribution friction — lead initially assigned all 4 wave-1B implementation commits to gp-sys-p3s2 (warmest agent), corrected mid-wave by spawning qa-engineer-p3s2 for Commit 3 integration test per CLAUDE.md ownership. Friction: rebalance landed after gp-sys partial-shipped Commit 3 (5a53108); qa-engineer's 9ade2bd filled remaining scenarios. The rebalance worked but mid-wave timing was suboptimal — at-dispatch ownership discipline prevents the friction. Cites Manifesto Principle 6 (Partnership — distributing load preserves cross-agent context depth). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Intent-vs-implementation split for cultural / non-technical claims.** When a non-technical reviewer (loremaster, balance-engineer, ai-engineer in design-mode review) makes a verdict that depends on a specific mechanical / technical behavior, the verdict must distinguish (a) "the framing aligns with STATED INTENT" — within the non-technical reviewer's lane — from (b) "the framing aligns with SHIPPED BEHAVIOR" — typically requires technical verification outside the non-technical reviewer's lane. The non-technical reviewer approves (a) when justified and DEFERS (b) explicitly to the technical reviewers (engine-architect, godot-code-reviewer, architecture-reviewer) rather than implicitly endorsing both. **Canonical incident:** Phase 3 session 2 wave 1B — loremaster's APPROVE praised RNC §4.7.5's "navmesh-obstacle reinforces cultural framing" as "form-follows-source at the engine layer." Engine-architect's later live-test investigation surfaced the mechanical half is INERT (NavigationObstacle3D radius-only mode doesn't affect `NavigationServer3D.map_get_path` queries). The cultural CATEGORY distinction (labor-organization vs civic-anchor frame) holds independently; the "form-follows-source" alignment was overweighted because it depended on mechanical behavior loremaster couldn't verify directly. The honest verdict would have been: "cultural framing aligns with stated intent; defer mechanical verification to engine-architect." Cites Manifesto Principle 1 (Truth-Seeking — verify before endorsing alignment). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Contract-prose hedging for engine-feature claims.** SSOT-tagged contract prose making Godot engine-feature claims must be hedged-by-default and ratified-only-after-runtime-verification. Unhedged confident prose ("X carves dynamically — no runtime rebake") is HARDER to disbelieve than hedged prose ("X is INTENDED to carve dynamically — verify against Godot 4 runtime before relying"); the unhedged form anchors later readers (and later reviewers) in the contract's assertion rather than running their own verification. **Canonical incident:** Phase 3 session 2 wave 1B engine-architect's L25 investigation — RNC v1.0.0–v1.3.0 §3.2 wrote "NavigationObstacle3D children carve dynamically — no runtime rebake" as unhedged shipped-truth. The actual Godot 4 behavior never matched (the static-carve mode requires `affect_navigation_mesh = true` + `vertices` and is unset in the project; the dynamic-RVO mode requires NavigationAgent3D which doesn't exist in the project). The unhedged prose anchored loremaster's cultural-framing approval AND survived three review passes without challenge until live-test surfaced the gap. Hedged prose ("INTENDED to carve dynamically; verify against shipped behavior before relying") would have invited the verification that closed the gap. **Operational form:** any contract claim about Godot engine APIs is hedged at authoring; the hedge lifts only when a probe test or live-test empirically verifies the claim against the running engine, with the verification artifact cited in the contract prose. RNC §3.2 v1.4.0 (post wave-1C spike) is the canonical worked example: prose specifies "verified behavior: `affect_navigation_mesh = true` + `vertices` triggers localized region rebake per spike verification at `<commit-SHA>`." Cites Manifesto Principle 1 (Truth-Seeking — the engine, not the spec, is the ground truth for engine-feature claims). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Behavioral-vs-structural test discipline: cross-cutting structural claims require behavioral assertions.** When a test asserts a scene-tree node exists, a group membership holds, a class_name declaration is present, or any structural element whose PURPOSE is to cause an effect on adjacent systems (collision shapes, navmesh obstacles, sim coordinators, event-bus subscribers), the test suite must include AT LEAST ONE behavioral assertion that the structural element actually produces the runtime EFFECT it claims. Presence assertions (`get_node_or_null != null`, `is_in_group(&"X")`, `has_method(&"Y")`) verify the SHAPE; behavioral assertions verify the EFFECT. **Canonical incident:** Phase 3 session 2 wave 1B live-test surfaced that NavigationObstacle3D nodes on every Building scene (asserted by `test_building_base.gd`, `test_khaneh.gd`, `test_madan.gd`, `test_phase_3_khaneh_placement.gd`) didn't actually block worker pathing. The gap rode from wave-1A original Khaneh shipping (six days) because presence-assertions passed and no behavioral assertion existed. **Operational form:** at wave-close test-coverage review (godot-code-reviewer's domain), for any new structural element introduced, the reviewer asks "is there an assertion that this element produces its intended effect on a downstream consumer?" If not — SUGGEST a behavioral test (BLOCK if the structural element is load-bearing for gameplay correctness; SUGGEST if the behavioral test requires expensive scaffold like a NavigationRegion3D bake). Cites Manifesto Principle 1 (Truth-Seeking — verify the effect, not just the shape) and Principle 9 (Automated Enforcement — rules without enforcement erode). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Lead-takes-work-when-specialist-unresponsive carve-out (§6 extension).** When a specialist agent is non-responsive on a dispatched task AND the work is fully specified (no design decisions remaining) AND it blocks downstream session progress, the lead may take the work directly as an exception to ownership-lane discipline. Three criteria are conjunctive — all three must hold for the carve-out to apply. **Why this isn't license to override ownership:** if the work has remaining design decisions, the lead's direct execution risks "warmest-agent" anti-pattern recurrence (lead becomes the warmest agent and bypasses domain-depth). If the work isn't blocking, waiting for the specialist preserves their session continuity. If the specialist is responsive, the carve-out doesn't apply at all. **Operational form:** lead's commit message + retro note explicitly cites the carve-out: "Lead authored this commit as exception to ownership-lane discipline: <specialist> was non-responsive on <task> despite multiple dispatches. The doc-only, fully-specified-by-other-specialists nature of the patch made lead-direct acceptable." Visible to team for cross-session awareness. **Canonical incident:** Phase 3 session 2 wave 1B SUGGEST-MEDIUM RNC v1.3.1 patch — gp-sys-p3s2 non-responsive after multiple dispatches; doc-only patch with content fully specified by arch-reviewer (ssot_for completeness) + engine-architect (§3.2 prose-honesty correction); lead authored directly at `98dfc18`. Cites Manifesto Principle 6 (Partnership — partnership includes acting when a partner is unreachable, with transparency). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **strings.csv → strings.\*.translation binary regen rule.** Any change to `game/translations/strings.csv` requires regenerating the per-locale `.translation` binary files before commit, OR having Godot editor open during the work so the reimport fires automatically. The headless regen path: `cd game && godot --headless --import` from the project root regenerates the binaries; commit both `strings.csv` and the regenerated `strings.*.translation` files together. **Why added:** Phase 3 session 2 wave 1B gp-sys-p3s2's wave-1B Commit 1 (2adc35d) updated strings.csv with the Ma'dan rows but didn't include the regenerated binary. Live-test surfaced literal `UI_BUILDING_MADAN_COST` rendered in the build menu instead of "Ma'dan (40 Coin)" — `build_menu.gd:200`'s `tr() % [cost]` format expression failed because the .translation binary didn't have the new keys, `tr()` returned the literal key, the key has no `%d` placeholder. Lead fixed at `d61eb79` via headless regen. **Operational form:** pre-commit hook could be extended to detect `strings.csv` modification and require the corresponding `.translation` binary to also be staged (Manifesto Principle 9). Until then, the rule lives as committer discipline. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Mid-wave rebalance discipline: brief explicitly enumerates shipped-vs-remaining scenarios.** When lead reassigns a task scope mid-wave (the rebalance from "warmest-agent assignment to ownership-domain assignment" per the distribution-discipline rule above), the new owner's brief must explicitly enumerate (a) which scenarios are ALREADY SHIPPED by the prior agent, and (b) which scenarios REMAIN for the new owner. Lead reads the prior agent's `git log` since dispatch + their last status message and produces the explicit delta. **Why added:** wave-1B mid-wave rebalance from gp-sys to qa-engineer landed AFTER gp-sys had partial-shipped Commit 3 (5a53108 — happy path + no-buff path). qa-engineer's brief didn't enumerate "happy path and no-buff path ALREADY SHIPPED; non-stacking + cross-cutting exclusion + class_name still needed" explicitly. qa-engineer figured it out from reading 5a53108 themselves (one extra minute of work) but the friction is avoidable with explicit delta-enumeration in the brief. Cites Manifesto Principle 6 (Partnership — when rebalancing, take care of the new owner's onboarding) and Principle 4 (Lean Iteration — explicit enumeration is cheap; ambiguity costs cycles). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Single-report-per-investigation discipline (engine-architect, applies to all read-only investigation roles).** When a specialist is dispatched for a read-only investigation (engine-architect investigations, qa-engineer flake diagnoses, balance-engineer simulation analyses), the investigation produces ONE structured report. Supplementary detail is provided on lead's explicit request, not volunteered proactively. **Why added:** Phase 3 session 2 wave 1B engine-architect-p3s2's L25 investigation produced a primary report (root cause + three fix paths + recommendation) and an unsolicited supplementary report (Path D and Path E variants). The supplement added context-window weight on lead with low marginal yield — the supplementary paths didn't change lead's decision. **Operational form:** investigation reports default to "single report; request additional detail if needed." Lead may pre-ask for option-space enumeration if needed; the default is concise. Cites Manifesto Principle 4 (Lean Iteration — smallest thing that produces real data; the second report had near-zero marginal data). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Anchor-category enumeration for Building subclasses (loremaster brief-time review extension).** Building subclasses fall into one of several cultural-anchor categories, each requiring a distinct template-shape in the cultural-note block. Currently enumerated:
  1. **Civic-anchor** (Khaneh, Mazra'eh) — resource-producer or pop-cap; settled-life continuity; household + land anchors.
  2. **Labor-organization** (Ma'dan) — modifier-emitter on existing producer; practice-of-craft transmitted across generations.
  3. **Sacral-emitter / divine-source** *(predicted, not yet shipped — Atashkadeh, Phase 4+)* — continuous-emit-of-resource (Farr per tick); sacred-fire continuity; divine legitimacy.
  4. **Identity-bearing institutional** *(predicted, wave 2A pending — Sarbaz-khaneh)* — unit-production-queue; Iran-as-faction self-conception; pahlavan + sepah traditions.

  **Brief-time review uses anchor-category classification as the first-pass question:** "which variant does this building belong to? Same-as-existing or new variant?" Variant misclassification at brief-time is the highest-value risk to catch (per Ma'dan's wave-1B brief-time exchange where lead initially framed Jamshid as "tangential" — a sign that loremaster needed to refine to "this is a labor-organization variant, not a civic-anchor clone"). **Open question:** the taxonomy may be exhaustive for Iran-side at MVP scope; Turan economy will likely surface a fifth-or-sixth variant when it ships. Re-examine at Phase 4 retro. Cites loremaster's wave-1B retro Proposal 3.2 and the canonical anchor-category emergence across waves 1A + 1B. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Brief-time review formalization (loremaster + future cultural / domain reviewers).** Brief-time review is now a ratified §9 dispatch context (graduating from "trial-with-2-canonical-cases" to permanent rule). **Decision rule:**
  - **Brief-time review FIRES when** a wave will produce the FIRST INSTANCE of a culturally-load-bearing template OR template-VARIANT. Examples: first abstract base-class header (Building base → cross-faction caveat convention); first concrete subclass (Khaneh → civic-anchor template); first variant of an existing template-family (Ma'dan → labor-organization variant); first faction's first unit / building (when Turan economy ships → Turan baseline template); first cultural-emitter (Atashkadeh → sacral-emitter variant).
  - **Brief-time review does NOT fire when** a wave clones an established template-variant for a sibling building (e.g., a fourth civic-anchor building cloning Khaneh/Mazra'eh) — that case ships as wave-close-only.
  - **Lead's call at wave-design time which dispatch shape applies.** Default-fire when in doubt; the brief-time-review cost is one extra SendMessage round-trip; the wave-close-only cost when a fix is needed is one + potentially-many follow-up commits.

  **Two-canonical-case empirical baseline:** Mazra'eh-as-first-civic-anchor-clone validated brief-time-review's existence in wave 1A; Ma'dan-as-first-labor-organization-variant validated the variant-detection benefit in wave 1B. Cites Manifesto Principle 4 (Lean Iteration — compressing the wave-close fix loop), Principle 6 (Partnership — three-party loop: lead asks → loremaster framing → specialist writes with citation). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Literal-then-tricky-gloss discipline (loremaster Persian-term Pattern, pinned).** When a Persian term has a known false-friend English gloss carrying unwanted connotations (modern industrial, feudal, Abrahamic, etc.), lead with the corrective literal, then frame the tricky gloss as such. Preserves accuracy at first-reader contact while acknowledging the dictionary-default reading. **Canonical applications:**
  - *dehqan* — "landed cultivator" (lead) avoiding "lord of the village" (feudal-aristocratic baggage).
  - *ma'dan* — "ore-source / generative place" (lead) avoiding "mine" (industrial-revolution baggage).

  **Watch list (future Persian terms with English false friends):** *shah* ("king" loses Farr-legitimized political theology); *pahlavan* ("knight" loses heroic-champion register); *div* ("demon" loses Iranian mythological category — anti-Yazata, not fallen angel); *farr* ("glory" loses legitimizing-political-theology layer); *sepah* ("army" loses institutional layer Sarbaz-khaneh inherits). Cites loremaster's wave-1A + wave-1B refinements and Proposal 3.3 from wave-1B close retro. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Pre-commit self-review pattern (world-builder Proposal, applies to all implementers).** Before any wave-close commit on files you own, read the contracts your changes write against as the trio reviewer would. File QUESTIONS_FOR_DESIGN.md entries or pre-emptive fix-up commits BEFORE the trio review fires — not after. **Why added:** Phase 3 session 2 world-builder caught their own contract gaps pre-trio-review at 91f48ad (§1.4/§3.4 corrections to RNC) — 5-10 minute pre-emptive read saved a fix-up wave cycle. The discipline transfers to all implementers; the cost is small and the savings compound. Cites Manifesto Principle 1 (Truth-Seeking — verify your own work before others have to). [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Layer 1.5 enumeration discipline (godot-code-reviewer + architecture-reviewer, standardize across both reviewers).** When a wave introduces a new shared classification surface (SceneTree group, duck-type method, base-class field, EventBus signal), the reviewer outputs an explicit enumeration TABLE in the review verdict listing (a) publishers / adders, (b) consumers / readers, (c) every existing entity-type membership status. The enumeration is a *written artifact*, not a "I checked this" claim. **Why added:** Phase 3 session 2 wave-1A's `&"buildings"` group + wave-1B's `&"resource_nodes"` group + `register_extraction_modifier` API both produced cleaner review verdicts when the enumeration was in-writing. godot-code-reviewer's automaticity-threshold timing (5 min at wave 1A → 4 min at wave 1B) indicates the discipline transferred from deliberate to natural in one session — the table-shape is internalized. **Operational form:** add the enumeration table to both reviewers' review templates. Refinement candidate: add an "exclusion-vs-inclusion" column for at-a-glance distinguishing of new-participant inclusions from new-participant exclusions (trial at wave 2A; graduate to permanent if it adds value). Cites godot-code-reviewer's wave-1A invention + wave-1B validation. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

- *(2026-05-17)* **Cross-session persistence (operational extension of §12.5 — see §12.5.1).** The persistent in-team agent instances survive across session boundaries by default, not just within session. New rule lives in §12.5.1; cross-referenced here for §9 completeness. [Phase 3 session 2 retro](#phase-3-session-2--mazraeh-madan-building-taxonomy)

### 2026-05-17 cluster (Phase 3 session 3 close retro)

The following rules land as a single coherent cluster from Phase 3 session 3's close retro. They were extracted from substantive retro inputs (ui-developer-p3s3, world-builder-p3s2; gp-sys-p3s3 / engine-architect-p3s2 / qa-engineer-p3s3 / balance-engineer-p3s3 received the retro prompt but produced only idle-pings — per §12.5.1 their state is preserved for future surfacing), plus the two fresh-instance PR reviewers' findings on PR #16, plus lead's own self-reflection across the wave-1C arc. The cluster is dominated by **engine-feature verification discipline** (the wave-1C navmesh 4-round drift produced 3 stacked rules), with a secondary cluster on **multi-agent staging coordination** (the workspace incident produced 4 sharp rules) and a tertiary cluster on **consumer-side integration discipline** (ui-developer's pre-commit catch produced 3 cross-cutting rules).

**Engine-feature verification cluster (3 rules — direct response to the wave-1C navmesh 4-round drift):**

- *(2026-05-17, engine-feature-verification cluster)* **Engine-feature runtime verification — enumerate API defaults at every step in the call chain.** For any Godot-API-dependent (or library / OS-API-dependent) architecture claim, the spike's verification phase MUST enumerate API defaults at every step in the call chain — not just the API surface. Probe artifacts (binary symbol grep, headless test result, minimal-repro, or docs citation with verbatim quote + page-section reference) MUST be cited inline with the prescription. "Verified by docs" without artifact reference is the trap that cost this project four round-trips on a single engine-feature claim (NavigationObstacle3D / `affect_navigation_mesh` vs `carve_navigation_mesh` vs manual `bake_navigation_mesh()` vs `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`). **Operational form for engine-architect's spike reports:** §1.3 "adjacent-code verification" phase splits into §1.3a (call-site verification — what calls the API, what does the call shape look like) and §1.3b (API-default enumeration — what is the default value of every flag/property at every layer of the call chain, with verbatim citation to docs or source). Authored by engine-architect-p3s2 across rounds 1-3 of the L25 diagnostic; sharpened to current form at round 3. Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify) and Principle 9 (Automated Enforcement — discipline binds via mandatory probe artifacts, not via care). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, engine-feature-verification cluster, NEW)* **Research-discipline rule — external research is a first-class verification tool, not an escalation path.** For any engine/library/OS-behavior claim, the verification sequence is:
  1. **Official docs lookup** (read the canonical class/API reference + the tutorial page for the use case).
  2. **GitHub source/issues/proposals search** (the engine source code itself is queryable; the proposals + issues tracker captures known gaps and design discussions).
  3. **Community knowledge** (official forum threads, established tutorials, sample-project repos).
  4. **ONLY THEN binary-symbol probing, minimal-repro probe scripts, or other empirical-bench techniques.**

  **Why:** the canonical Godot 4.6 NavigationObstacle3D pattern was in the public tutorial the whole time. Four rounds of binary-symbol probing was ~90 minutes of cumulative diagnostic when ~5 minutes of docs reading at round 0 would have surfaced the dual-flag distinction + the no-auto-rebake reality + the SOURCE_GEOMETRY_ROOT_NODE_CHILDREN default. The probing technique is correct discipline; the SEQUENCING is what's new — research before probing, every time. Authored by lead 2026-05-17 (in response to user's "do they ever research online?" question mid-session). Cites Manifesto Principle 1 (Truth-Seeking — the cheapest reliable evidence comes first) and Principle 4 (Lean Iteration — five minutes of reading saves 90 minutes of probing). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, engine-feature-verification cluster, NEW)* **Spike-scope discipline — N=2 round threshold for scope reevaluation.** When a spike's implementation has spiraled past N=2 rounds of "ship → live-test → fail → re-diagnose," the lead MUST pause and reevaluate scope. The original wave's other deliverables should not be held hostage by a single hard problem. Punt to a dedicated wave with proper time budget. **Honest archaeology + diagnostic carry-forward is more valuable than aspirational implementation that doesn't close.** The dedicated wave inherits the rounds-of-diagnostic state as starting-from-N rather than starting-from-zero. **Why:** Wave 1C navmesh hit N=4 rounds before lead made the option-B punt decision (2026-05-17). The wave's three working tracks (construction-timer, UI progress bar, placement validity) were structurally complete after Track 1's commits but the wave didn't close because the navmesh sub-track held it hostage. The honest-archaeology framing (`docs/WAVE_1C_NAVMESH_SPIKE.md` v0.2.0 + RNC §3.2 v1.3.2 + ARCHITECTURE §7 L25/L26) is the canonical artifact shape — empirical state, hypothesis surface, mechanism candidates, attribution per round. Authored by lead 2026-05-17. Cites Manifesto Principle 4 (Lean Iteration) and Principle 10 (Feedback Cycle — the loop only closes if you let it close). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

**Multi-agent staging coordination cluster (4 rules — direct response to the wave-1C workspace incident):**

- *(2026-05-17, multi-agent staging cluster, NEW)* **Broadcast-before-stash rule.** Before ANY `git stash push -u` (or scoped `git stash push -- <files>` that touches files modified by another agent in the current wave), the stashing agent MUST broadcast `[stashing: <files>]` to lead via SendMessage so affected parallel agents know their working-tree state is parked, not lost. Non-optional even when the stash feels local and you intend to restore immediately. **Why:** Wave-1C workspace incident (2026-05-17 ~10:35-10:38) — world-builder-p3s2 stashed parallel agents' WIP without broadcast as part of `90d39bd` prep. From ui-developer-p3s3's view, their working-tree state vanished unexpectedly; they correctly stopped-and-reported but lost ~30 minutes to diagnostic confusion. The system-reminder telling them the change was "intentional" was actively misleading. Authored by world-builder-p3s2 (self-criticism + agent-def self-update) + ui-developer-p3s3 (escalation framing). Same unconditional shape as the pathspec discipline rule from session-2 cluster. Cites Manifesto Principle 6 (Partnership — coordinate explicitly across the team). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, multi-agent staging cluster, NEW)* **Local-safety-vs-pipeline-integrity tension.** When an agent's commit is at risk from race contamination (parallel work mutating shared scope), the temptation to "land before another race buries it" is a LOCAL OPTIMIZATION that the L23 sequencing rule + the wave-dispatch discipline explicitly forbid. The right move is to broadcast `[blocked]` to lead via SendMessage and request explicit unblock, NOT to ship out of order. **Why:** Wave 1C L23 violation by world-builder-p3s2 (`90d39bd`) — shipped Phase 2A scene edits before Tracks 1+2 closed despite the park directive, justified locally as "land before another race buries it." The local optimization broke pipeline integrity. Self-criticism: "I prioritized my commit's safety over pipeline integrity. The sequencing rule exists precisely to prevent agents making those local calls unilaterally." Authored by world-builder-p3s2. Cites Manifesto Principle 6 (Partnership) and Principle 8 (Separation of Concerns — sequencing is a coordination property, not a per-agent property). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, multi-agent staging cluster, NEW)* **Inter-agent stash visibility — multi-agent git operations create reflog + stash state opaque to participating agents.** When multiple agents run parallel git operations (especially stash + reset), the resulting reflog + stash entries can be misread by ALL participants including the lead. Documentation of stash purpose + cross-references in commit messages + explicit stash titles (`git stash push -m "<descriptive>"`) become load-bearing. **Why:** Wave-1C workspace-incident forensic confusion — lead initially misread `reset: moving to HEAD` reflog entry as a destructive `git reset --hard` when it was `git stash push`'s internal mechanism. Apologized + withdrew accusation against world-builder-p3s2. The reflog-vs-stash semantics distinction was invisible without careful reading. Lead's discipline correction: when investigating multi-agent git incidents, read `git stash list --date=iso` + `git reflog --date=iso` together, never one in isolation. Authored by lead + world-builder-p3s2 (the forensic-reconstruction exchange). Cites Manifesto Principle 1 (Truth-Seeking — observe, trace, verify; including verifying your own forensic narrative). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, multi-agent staging cluster, NEW)* **Persistent-instance architecture working correctly under stress (validation, not new rule).** Despite 4 rounds of navmesh diagnostic + workspace incident + ui-developer fix-up rounds + scope-revision pivot, all persistent agents stayed coherent, picked up where they left off, brought lived memory of prior rounds to bear. The §12.5.1 cross-session persistence rule is empirically load-bearing for the studio process to function under multi-round friction. The contrast with session 2 ("5/9 alive, 4/9 asleep") shows the architecture's normal operational shape — some agents respond promptly, some are quieter, persistent-instance dispatch picks up the live ones each time. No new rule; this entry exists to mark the validation as canonical evidence. [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

**Consumer-side integration discipline cluster (3 rules — ui-developer-p3s3's pre-commit catch):**

- *(2026-05-17, consumer-side-integration cluster, NEW)* **Consumer-track integration verification — verify against the producer's current commit SHA, not the kickoff brief's quoted snippet.** When a consuming track (UI consumer of a state-machine signal, AI consumer of a sim event, etc.) is dispatched against a kickoff brief that references another in-flight track's API surface, the consumer MUST verify against the producer's CURRENT shipped code at commit time — not the kickoff's quoted line. The brief is a starting hypothesis; the producer's actual file at the actual SHA is the truth-source. **Why:** Wave-1C ui-developer-p3s3 caught the construction_finalized integration gap by reading Track 1's `building.gd` at commit time and tracing the `is_complete` lifecycle through gp-sys-p3s3's actual implementation. The lead's kickoff §5 brief had described an `is_complete` hide-trigger pattern written against the pre-Track-1 lifecycle; Track 1's two-stage lifecycle had inverted the semantics. Without ui-developer's commit-time re-verification, the bug would have shipped and surfaced in live-test or worse. **Operational form for consumer-track agents:**
  1. Read the OTHER track's current file at its committed SHA (not the kickoff's quoted line).
  2. Trace the lifecycle hook through the producer's emit/call site, not just the declaration.
  3. Confirm the timing assumption from your code's POV (e.g., "is_complete fires at end of dwell" → verify by reading the producer's call sequence).
  4. If timing/semantics drift from your kickoff brief, STOP and escalate before commit.

  Authored by ui-developer-p3s3. Cites Manifesto Principle 1 (Truth-Seeking — verify against shipped reality) and Principle 7 (SSOT — the producer's shipped code is the source, not the brief's quotation). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, consumer-side-integration cluster, NEW)* **Poll-loop test-coverage discipline — N-iteration post-lifecycle-event tests for any consumer that polls-and-binds.** Any consumer that polls a SceneTree group + connects per-instance signals (overlays, debug surfaces, tutorial hooks, telemetry sinks) MUST ship a test that:
  1. Establishes the wire (calls `_ensure_signal_connected` or equivalent once).
  2. Fires the lifecycle event whose handler the wire serves (`signal.emit()` from a fake producer).
  3. Re-invokes the wire-establishment N times (N≥10).
  4. Asserts no resource creep — signal connection count constant, cache size bounded.

  **Why:** ui-developer-p3s3's overlay shipped at `a023242` with a hidden duplicate-connect bug — `_connected.erase(bid)` in the finalize handler caused per-frame reconnect attempts. Single-event functional tests passed cleanly. The bug surfaced only in live-test (ERROR spam in log). Fix-up at `280d27a` included the regression-locking test `test_repeated_ensure_connect_does_not_duplicate_signal_wires`. **The bug class — "resource creep across N poll iterations" — is structurally invisible to single-event tests.** Authored by ui-developer-p3s3. Cites Manifesto Principle 1 (Truth-Seeking — the test should catch the bug class, not the specific bug instance) and Principle 10 (Feedback Cycle — regression locks are the cheapest forward-investment in test infrastructure). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, consumer-side-integration cluster, NEW)* **Signal-introspection over lambda-capture for signal-wiring tests.** Default to `Signal.get_connections().size()` reads (or `is_connected()` checks) when testing signal-wiring behavior. Use lambdas only when the closed-over locals are immutable in the enclosing scope. **Why:** Carry-forward from gp-sys-p3s3's session-2 lambda-capture surprise (test_unit_state_constructing.gd) — captured-local-of-reassigned-value doesn't propagate the later reassignment in GDScript. The Signal-introspection pattern bypasses the closure entirely by reading the engine's connection table directly. Authored by ui-developer-p3s3 + gp-sys-p3s3 (carry-forward from session-2). Pairs with Pitfall #14 promotion (see below). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

**Implementation pattern cluster (3 rules — surfaced across multiple agents):**

- *(2026-05-17, implementation-pattern cluster, NEW)* **Scene-config-as-forward-investment discipline — name the activating mechanism in the .tscn comment.** When shipping inert scene config that depends on a downstream wave to activate (NavigationObstacle3D flags, signal connections, footprint vertices, mesh placeholders, etc.), the `.tscn` comment MUST cite (a) the dependent wave / task number AND (b) the specific mechanism that will fire it (which call, which signal, which bake trigger). Pre-commit checklist step 2.5: "Is this config inert? If yes — name the activating mechanism. If the mechanism is in a later wave, cite it in the .tscn comment AND flag it in your message to lead." **Why:** The 4-round wave-1C navmesh cycle was a chain of inert configurations that each looked structurally complete in isolation. The question "what actually triggers this?" was never asked until live-test failed. Naming the activating mechanism inline is the cheapest defense against the false-confidence-from-inert-config trap. Authored by world-builder-p3s2. Cites Manifesto Principle 7 (SSOT — the activating mechanism's location should be discoverable from the config it activates). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, implementation-pattern cluster, NEW)* **super()-call discipline on Building virtuals — base-class owner ships subclass override updates in same commit.** When adding a new virtual hook to a base class with subclasses (e.g., `_on_placement_complete` on Building, with Khaneh/Mazra'eh/Ma'dan overrides), the base-class owner MUST scan ALL existing subclasses for overrides of that method in the same commit and add `super.<hook>()` as their first line. This is the BASE-CLASS owner's responsibility, not the override-author's responsibility — the override-author may not know a base implementation was added, and silent missing super calls accumulate silently. **Why:** Wave-1C `910bd9a` — world-builder-p3s2 added `_on_placement_complete` rebake logic to Building base; all three subclasses (Khaneh, Mazra'eh, Ma'dan) had silent overrides with no super call. Caught reactively mid-wave but cleanly fixed in the same commit. The reactive catch is luck; the proactive scan is the discipline. Authored by world-builder-p3s2. Cites Manifesto Principle 8 (Separation of Concerns — base-class owner owns the override-chain integrity) and Principle 9 (Automated Enforcement — same-commit fix prevents silent drift). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, implementation-pattern cluster — Pitfall #14 promotion)* **Pitfall #14: GDScript lambda capture of reassigned locals is unreliable — promoted to permanent Known Pitfalls list.** Lambda closures in GDScript capture locals by value at lambda-creation time. If the captured local is reassigned in the enclosing scope AFTER lambda creation, the closure does NOT see the reassignment cleanly — the lambda holds its capture-time copy and the test's assertion against the lambda's view diverges from the SceneTree's actual state. **Canonical incident:** gp-sys-p3s3's emit-ordering test for `construction_finalized` (session-3 wave-1C); first version used a lambda closing over `mazraeh.is_gatherable` for the post-emit readout; the captured local was `null` at lambda-creation and didn't propagate the later reassignment in the enclosing scope. Restructured to post-loop SceneTree readout (`mazraeh.is_gatherable` read directly after the await) which propagates correctly. **Operational mitigations** (apply per case):
  1. **Default pattern:** post-await SceneTree readout for state observations in tests.
  2. **Signal-watching pattern:** `Signal.get_connections().size()` for signal-wiring tests (see consumer-side-integration cluster above).
  3. **Sentinel-append pattern:** lambda appends to an outer-scope sentinel array; test reads array contents post-await.

  Full pitfall entry lands in `docs/PROCESS_EXPERIMENTS.md` Known Pitfalls list per the standard promotion template. Surfaced by gp-sys-p3s3 (session-2 emit-ordering test) + ui-developer-p3s3 (session-3 signal-wiring test, applied carry-forward). Cites Manifesto Principle 1 (Truth-Seeking — the test must actually read the engine's state, not a stale closure-snapshot of it). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

**Meta-process cluster (3 rules — surfaced about the retro/dispatch process itself):**

- *(2026-05-17, meta-process cluster, NEW)* **Lead-brief sequencing errors as a legitimate specialist review surface.** When the lead's dispatch brief contains a sequencing error (task A blocked-by task B when it should be blocked-by task C), the specialist receiving the brief is empowered to push back via SendMessage citing the relevant discipline. **Why:** engine-architect-p3s2 caught lead's Task #137 (RNC v1.4.0 commit) premature sequencing — lead had it blocked-by Phase 2A scene-edits when it should be blocked-by Phase 3 live-test gate. Engine-architect directly applied their own L25 "SSOT-prose-ahead-of-runtime-verification" discipline to lead's dispatch. Lead's response: "your discipline reading is sharper than my initial sequencing of #137." Re-sequenced #137 to be blocked-by #138. **The specialist's domain reading of the dispatch brief is a legitimate review surface; lead errors are not unfalsifiable.** Authored by engine-architect-p3s2 + lead. Cites Manifesto Principle 1 (Truth-Seeking — observable error in dispatch is observable error) and Principle 6 (Partnership — peer review of the lead by the specialists is what the persistent-instance architecture enables). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, meta-process cluster, NEW)* **Agent-def self-update verification rule — when an agent updates their own agent-def at retro time, the wave-outcome status MUST be verified against `ARCHITECTURE.md §7` + the wave-close `§6` entry, not against per-task-commit subjective close.** Agent-defs reflect SYSTEM-LEVEL outcomes for the discipline they encode; per-task commits are subjective intermediates that may or may not represent system-level closure. **Why:** Wave-1C retro — world-builder-p3s2 self-edited their agent-def with a closing section claiming "Wave 1C closed L25 with a three-layer fix... The full causal chain is closed." Each of the three layers WAS correctly shipped; world-builder's per-commit subjective close was accurate per-commit. But the SYSTEM-LEVEL outcome was option-B-punt (L25 deferred), not L25-closed. Lead corrected the section directly in the agent-def to align with ARCHITECTURE §7 L25's authoritative status. The shipped layers are forward-investment, not closed mechanism. **Operational form for agent self-updates:** before committing an agent-def edit at retro time, read ARCHITECTURE §7 (LATER status) + the wave-close §6 entry. If the discipline you're documenting references an L<N> issue, the agent-def MUST cite the L<N>'s current status accurately. Authored by lead. Cites Manifesto Principle 1 (Truth-Seeking — observe the system-level outcome, not the per-task narrative) and Principle 7 (SSOT — ARCHITECTURE.md is the canonical truth-source for system-level state). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

- *(2026-05-17, meta-process cluster)* **Single-report-per-investigation discipline holds across multi-round investigations — refine to "one consolidated report at investigation close, plus interim status pings."** During wave-1C's 4-round navmesh diagnostic, engine-architect-p3s2 produced one report per round. This was acceptable because each round was technically a NEW investigation (new hypothesis space, new prescription). The single-report-per-investigation discipline (session-2 §9 cluster) held in spirit — one report per investigation cycle. **Refinement:** when a multi-round investigation produces N rounds of "ship → fail → re-diagnose," the final consolidated report (engine-architect's spike v0.2.0 archaeology) is the canonical artifact, NOT the per-round reports. Per-round reports serve as interim status pings; the consolidated artifact is the truth-source for the next inheritor. Authored by engine-architect-p3s2 (the v0.2.0 amendment IS the consolidated report). [Phase 3 session 3 retro](#phase-3-session-3--wave-1c-construction-timer--ui-progress--placement-validity-navmesh-deferred)

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

**The lead's role:** silent unless something escalates. Verifies branch hygiene, version bumps, and architecture doc updates at PR review. Does not facilitate during implementation — the agents are working.

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

The §12.5 within-session decision-arc continuity rule **extends to cross-session boundaries by default.** The same in-team persistent agents (architecture-reviewer, godot-code-reviewer, shahnameh-loremaster, gameplay-systems, world-builder, ai-engineer, balance-engineer, qa-engineer, engine-architect, and any future in-team specialists) **persist across session boundaries** until one of three conditions holds:

1. **The user explicitly disengages an agent** (rare; would only happen for a structural role change or end-of-project teardown).
2. **A retro produces a system-prompt change the running instance cannot accommodate via conversation** — i.e., a change that contradicts the agent's accumulated session memory in a way internalize-via-conversation cannot resolve. Most retro updates are additive (new rules, new disciplines, new checklist items) and the running instance internalizes them through the retro discussion itself; only structurally contradictory updates warrant reboot.
3. **A new agent class is introduced** that didn't exist in the prior session.

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
