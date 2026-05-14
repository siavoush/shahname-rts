---
title: Phase 3 Session 2 — Kickoff
type: plan
status: ratified
version: 1.0.0
owner: team-lead
summary: Session-2 implementation recipe — completes Phase 3 with Tier-1 buildings (Mazra'eh, Ma'dan, Sarbaz-khaneh), construction-timer + progress-bar, DummyAIController, fog-of-war data layer. FIRST session under the persistent-agent architecture + decision-arc continuity rules (STUDIO_PROCESS.md §9 / §12.5).
audience: all
read_when: every-session
prerequisites: [02_IMPLEMENTATION_PLAN.md, 02f_PHASE_3_KICKOFF.md, 01_CORE_MECHANICS.md, STUDIO_PROCESS.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, RESOURCE_NODE_CONTRACT.md, SIMULATION_CONTRACT.md, TESTING_CONTRACT.md]
ssot_for:
  - phase 3 session 2 scope + wave breakdown
  - session-start ceremony under the persistent-agent architecture
  - pre-flight Open Space agenda for session 2
  - per-wave Live-game-broken-surface requirements (Experiment 01 ongoing)
tags: [phase-3, session-2, kickoff, persistence-trial, open-space]
created: 2026-05-14
last_updated: 2026-05-14
---

# Phase 3 Session 2 — Kickoff

## 0. Why this doc exists

Phase 3 session 2 ships the second half of the economic loop foundation + the first opponent the player can actually fight (`DummyAIController`) + the data layer that Phase 5's Kaveh Event and Phase 6's AI scouting will consume (fog-of-war data, no rendering yet).

It is also the **first session running under the new persistent-agent architecture and decision-arc continuity rules** that landed in `STUDIO_PROCESS.md` v1.5.0 (2026-05-14). Every session-start, dispatch, review, and retro discipline is different from session 1. **Read STUDIO_PROCESS.md §9 + §12.5 before starting any wave** — the new rules are load-bearing.

## 1. Reading order (≈15 minutes)

Same shape as session-1's kickoff §1, with two additions for the new architecture:

1. `MANIFESTO.md` (or directly https://github.com/peiman/manifesto for the canonical) — foundational principles
2. `DECISIONS.md` — chronological committed design decisions
3. **`STUDIO_PROCESS.md` §9 final 7 entries (all dated 2026-05-14) + §12.5 (NEW SUBSECTION)** — the persistent-agent architecture + decision-arc continuity. Without this, the rest of session 2 doesn't make sense.
4. `docs/ARCHITECTURE.md` §2 + §6 v0.20.7 / v0.20.8 / v0.20.9 — Phase 3 session 1 state at session-close + the post-live-test fix-wave outcomes (BUG-08 through BUG-11 + L22 closed + L23 / L24 NEW).
5. `01_CORE_MECHANICS.md` — the MVP spec, especially §3 (resources), §5 (buildings), §7 (AI specification, where the DummyAI scope is implicit).
6. `02_IMPLEMENTATION_PLAN.md` Phase 3 + Phase 3 deferred-to-session-2 list.
7. `02f_PHASE_3_KICKOFF.md` §2 (the Open Space sync resolutions that are still load-bearing this session) + §3 (the session-1 scoped slice — what shipped).
8. `docs/SIMULATION_CONTRACT.md` (v1.4.0 — §1.3 init-time carve-out + §1.5 UI-local tween carve-out remain in force).
9. `docs/RESOURCE_NODE_CONTRACT.md` (v1.1.1 — Mazra'eh's per-tick yield contract decision lands at Open Space, see §2 below).
10. `docs/TESTING_CONTRACT.md` (MatchHarness as sole integration harness).
11. `QUESTIONS_FOR_DESIGN.md` — the 3 escalations from session 1 (Q1 UI naming convention, Q2 Coin vs Sekkeh, Q3 Turan housing analogue) — **note** which are answered by design chat before session 2 begins.
12. `BUILD_LOG.md` — last ~6 entries (2026-05-14 cluster) for session-1 context the persistent reviewers already remember.

## 2. Pre-flight Open Space + Studio Sync (BEFORE waves start)

Three cross-cutting decisions need pre-resolution. Without them, parallel implementer specialists make incompatible choices. **This is the design-mode phase of session 2** — the agents who debate here ARE the implementers in subsequent waves AND the retro participants at session close (decision-arc continuity per §12.5).

### 2.1 Open Space sync — two rooms in parallel

**Room A — Mazra'eh per-tick yield contract.**
- **Format:** Constraint Negotiation (Pattern B, 2-party).
- **Participants:** `gameplay-systems`, `world-builder`. Both as PERSISTENT instances; they will later implement Mazra'eh + the contract patch.
- **The decision:** Mazra'eh's gameplay shape is "Kargar walks to fertile-tile farm; farm yields Grain over time while Kargar is engaged." This is fundamentally different from MineNode's "Kargar walks → dwells N ticks → extract payload → return." Two paths queued in `02f_PHASE_3_KICKOFF.md` § wave-1A v0.20.2 architectural-decision-1:
  - (a) **Extend Resource Node Contract** with a new `tick_extract` method on `ResourceNode` base. Mazra'eh implements `tick_extract`; MineNode keeps `complete_extract`. UnitState_Gathering branches on `node.has_method(&"tick_extract")` vs `&"complete_extract"`. Pros: clean conceptual model (per-tick vs per-trip yield); cons: contract expansion + branch in gather state.
  - (b) **Keep `complete_extract` shape**, ship Mazra'eh with a much shorter dwell (e.g., 6 ticks instead of 60). Each "tick" of yield is just a faster trip. Pros: no contract expansion; cons: Mazra'eh visually different from spec ("farm yields Grain over time while Kargar engaged" reads as continuous, not as bursty trips).
- **Output:** a decision-log entry (path chosen + rationale) committed to `BUILD_LOG.md` OR (if contract changes) a `docs/RESOURCE_NODE_CONTRACT.md` patch bumping to 1.2.0.
- **Round limit:** 3 (per existing §9 rule). Lead intervenes with tie-breaker if exceeded.

**Room B — Fog data layer schema.**
- **Format:** Author + Reviewers (Pattern A, 3-party).
- **Participants:** `world-builder` (author), `ai-engineer` (reviewer — Phase 6 scout consumer), `gameplay-systems` (reviewer — Phase 5 Kaveh Event consumer). All as PERSISTENT instances.
- **The decision:** schema for the boolean visibility grid + `is_visible_to(team, position)` API. Decisions to lock:
  - Grid resolution (1m² cells? Coarser per-region? Tied to navmesh?).
  - Per-team vs per-player (current MVP is 2 teams, but Phase 4+ may need per-player on team).
  - Building boundary semantics — does a building's center being visible reveal its full hitbox?
  - How vision sources register / deregister (combat units, scouts, buildings — all with their own ranges per `BalanceData`).
- **Output:** `docs/FOG_DATA_CONTRACT.md` (new doc, version 1.0.0) OR a section in `docs/SIMULATION_CONTRACT.md` if simpler. Includes API signature, schema, deterministic-by-default guarantees per Sim Contract §1.6.
- **Round limit:** 3.

### 2.2 Studio sync — DummyAI behavior specification

**Format:** Constraint Negotiation (Pattern B, 2-party). Locked at kickoff-review per lead's proportionality call — Phase 3 plan caps DummyAI at ~100 lines, so a 2-party negotiation between domain owner + balance is right-sized. qa-engineer's testability concerns surface via the wave-4 integration test brief, not at sync time.

**Participants:** `ai-engineer` (domain owner — what behavior shape), `balance-engineer` (reviewer — when does each beat fire, what are the timings). Both as PERSISTENT instances; they will later implement DummyAIController + the eventual Phase 4 Farr-curve modeling.

**The decision:** what does DummyAI DO?
- Plan baseline: "~100 lines, fixed-timer behavior. Turan side builds 3 workers, 1 Sarbaz-khaneh, produces Piyade on a timer. No combat AI."
- **Locked at kickoff-review (decision-arc continuity to be honored in the sync):** **DummyAI DOES attack** — a single scripted probe-attack at minute N (N to be negotiated). Rationale: if DummyAI never attacks, solo-test of the full economic loop doesn't include "an enemy showing up" — the player has nothing to FIGHT during the most important moment to verify the loop works. A single fixed-timer probe-attack stays within "fixed-timer, not AI" but produces meaningful solo-test coverage. The full FSM-driven Turan AI still ships in Phase 6.
- Decisions to lock in the sync:
  - Build order timing (worker spawn intervals, Sarbaz-khaneh build start, Piyade production timer).
  - Probe-attack timing — minute N (likely 5-8 minutes into match, balance-engineer's call).
  - Probe-attack composition — how many Piyade? Targets which Iran building / position?
  - Resource starvation behavior — what if DummyAI can't afford its build order?
  - Telemetry hooks — what's loggable so wave-4 qa can write smoke tests?
- **Output:** a `DummyAIController` spec inline in §2.4 of this doc.
- **Round limit:** 3.

### 2.3 Convergence Review (Pattern E) — reconvene all participants

After Rooms A + B + the DummyAI sync land their decision-logs, the lead reconvenes ALL participants (gameplay-systems + world-builder + ai-engineer + balance-engineer + optionally qa-engineer) for a brief **Convergence Review**: walk the three decision logs together. Surface cross-cutting concerns the in-room agents couldn't see (e.g., does Mazra'eh's chosen path interact with the fog data layer? Does DummyAI's build order assume Mazra'eh ships in time for it to gather grain?).

**Output:** ratification of all three decisions OR a flagged conflict that needs a second round.

The Convergence Review is the convergent moment of decision-arc continuity: the agents who debated are the same instances who will implement, and the convergence is THEIR shared commitment to the ratified shape, not the lead's pronouncement.

### 2.4 Resolved decisions (filled at sync close)

> **Room A — Mazra'eh per-tick yield:** *(awaiting sync)*
>
> **Room B — Fog data layer schema:** *(awaiting sync)*
>
> **DummyAI behavior:** *(awaiting sync)*

## 3. The Phase 3 session-2 scoped slice

Six deliverables. Order matters — the pre-resolution decisions in §2 unblock wave 1; wave 4 (qa) follows the implementer waves; wave-close + PR-time review wrap the session.

### Session-2 deliverables (in dependency order)

**Wave 1A — Mazra'eh + (possibly) Resource Node Contract patch**
- Owner: `gameplay-systems` + `world-builder` (sequential per the Room-A outcome's decision-arc continuity — both agents from Room A continue here).
- Deliverable: Mazra'eh class + scene, fertile-tile zone-detection (placement validity), gather state branch (if contract path (a) was chosen), tests.
- Anti-loop: per STUDIO_PROCESS §9 cycle.

**Wave 1B — Ma'dan (Coin extraction efficiency multiplier)**
- Owner: `gameplay-systems`.
- Deliverable: Ma'dan building + scene; when placed on a mine, multiplies the Kargar's `complete_extract` payload by a `BalanceData`-driven factor. Stacks-or-not is a balance call; default not-stacking until balance-engineer says otherwise.
- Anti-loop: per §9.

**Wave 1C — Construction timer + progress bar**
- Owner: `gameplay-systems` + `ui-developer` (sequential — gameplay-systems writes the timer logic in UnitState_Constructing, ui-developer writes the progress bar UI).
- Deliverable: replace session-1's instant-placement placeholder with a real construction-timer + visible progress bar. Worker stays engaged through the construct (decision: see §2.2 Topic 4 — implementer decides + brief comment).
- Anti-loop: per §9.

**Wave 2A — Sarbaz-khaneh + production queue**
- Owner: `gameplay-systems` + `ui-developer` (sequential).
- Deliverable: Sarbaz-khaneh (barracks) building. Production queue UI (single queue per building, cancel returns full resources, rally point via right-click). Pop cap enforcement (can't queue beyond cap).
- Anti-loop: per §9.

**Wave 2B — Build menu extension for multi-building roster**
- Owner: `ui-developer`.
- Deliverable: build menu now shows Khaneh + Mazra'eh + Ma'dan + Sarbaz-khaneh, with cost gating + tooltip-stub hooks. Selection-context filtering (Mazra'eh button greyed out on non-fertile terrain).
- Anti-loop: per §9.

**Wave 3A — Fog data layer**
- Owner: `world-builder`.
- Deliverable: per the Room-B outcome. Boolean visibility grid + `is_visible_to()` API + vision-source registration. No shader.
- Anti-loop: per §9.

**Wave 3B — DummyAIController**
- Owner: `ai-engineer`.
- Deliverable: per the §2.2 outcome. ~100 lines, fixed-timer behavior, telemetry hooks for testability.
- Anti-loop: per §9.

**Wave 4 — qa-engineer integration tests**
- Owner: `qa-engineer`.
- Deliverable: integration coverage of the full session-2 economic-plus-AI loop. New tests: multi-building cost+pop interactions, Mazra'eh per-tick yield correctness, Sarbaz-khaneh production queue + rally + cancel, fog data API determinism, DummyAI smoke (boot + basic build-order completes).
- Per §9 cross-cutting schema verification rule (2026-05-14): test the new participants (Mazra'eh, Ma'dan, Sarbaz-khaneh, DummyAI units) against EVERY existing consumer surface (click selection, box-select, double-click, right-click move/attack/gather, FarrDrainDispatcher reasons).

**Wave-close review (persistent reviewers — first trial of §9 persistence rule)**
- Per the new architecture: the persistent reviewer trio spawned at session start (architecture-reviewer, godot-code-reviewer, shahnameh-loremaster) receive a `SendMessage` from the lead at each wave-close with the wave's commit range. They reply with structured review carrying memory of prior waves AND of the session-1 reviews (their memory now spans both sessions).
- New rule trial: SSOT prose contradictions are BLOCKING (architecture-reviewer's priority 0.5).

**PR-time review (fresh-spawn — first trial of two-class architecture)**
- Lead spawns fresh-instance `architecture-reviewer` + `peiman-manifesto-reviewer` at PR creation time, in parallel.
- Both report independently. Persistent reviewers stay alive; fresh instances terminate after PR merges.

### Live-game-broken-surface (Experiment 01 ongoing)

Every wave brief still includes the 3-question Experiment 01 block:
1. Runtime state no unit test exercises?
2. What can headless not detect that lead would notice in editor?
3. Minimum interactive smoke test?

Per the new §9 rule (2026-05-14), wave-close reports also now include a **"Headless blindspots: what live-test must cover that these tests cannot"** paragraph AND a **"What tripped me up in this wave"** first-person section.

## 4. Wave breakdown — sequential-shared-tree default

Per L23 (Agent-tool `isolation: "worktree"` runtime gap, unresolved as of 2026-05-14): **all write-active waves are sequential single-agent for the duration of session 2**. Read-only reviewer dispatches remain parallel-safe.

Wave order: 1A → 1B → 1C → 2A → 2B → 3A → 3B → 4 → wave-close review (parallel via SendMessage to persistent reviewers) → lead live-test cadence → fresh-spawn PR-time review (parallel) → PR.

If a wave specialist's context overflows mid-session (per Tier-2 within-session persistence rule), cycle the instance with a brief handoff note.

## 5. Anti-loop brief language (PERMANENT — STUDIO_PROCESS.md §9 2026-05-04 + 2026-05-12)

Every agent dispatch brief includes:

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

Plus per-TDD-cycle commits (one commit per `red → green → refactor` pair).

## 6. Persistent-agent architecture — session-2 trial protocol

This is **what's different from session 1's kickoff §5/6/7**.

### 6.1 Session start

Lead spawns three persistent reviewers via `Agent` (one dispatch each, run_in_background=true):
- `architecture-reviewer` (Mode A — persistent wave-close per its agent definition's dual-mode docs)
- `godot-code-reviewer`
- `shahnameh-loremaster` (only invoke if the session has culturally-load-bearing surfaces — Mazra'eh's Persian framing qualifies, so YES this session)

These reviewers stay alive through the session. Each wave-close, lead `SendMessage`s them the wave's commit range; they reply with structured review.

### 6.2 Specialist dispatch

For each implementer wave, lead first checks whether the specialty already has a persistent instance from a prior session 2 wave OR from a session 2 Open Space sync (decision-arc continuity per §12.5). If yes: `SendMessage` to that instance. If no (first wave for that specialty): `Agent` spawn a new persistent instance.

Tier-3 ephemeral exception: if a wave is a one-shot surgical fix (e.g., a BUG-NN response mid-session), spawn fresh and stand-down at completion.

### 6.3 Wave-close

`SendMessage` to persistent reviewers (NOT new `Agent` dispatches). They reply with reviews. Their memory of prior waves makes wave-N's review more informed than wave-1's was.

### 6.4 PR-time

Lead spawns NEW `Agent` instances for `architecture-reviewer` (Mode B — fresh instance) and `peiman-manifesto-reviewer`. Both review the whole PR; both terminate after merge. Persistent instances stay alive for the next session.

### 6.5 Retro

Lead `SendMessage`s the SAME persistent instances who debated at the Open Space + shipped the waves. They reflect with full memory. This is the lived-experience-aggregation the new architecture promises. The "What tripped me up" wave-close section is BACKUP CAPTURE — primary signal is just asking the agents who remember.

### 6.6 Session close

Persistent instances stand down only when:
- The terminal will shut down (Claude Code update),
- Or the next session is genuinely far enough away that context staleness > persistence value,
- Or an agent's context has overflowed and must be cycled.

Default: leave them alive between sessions if the next session is days away. The lead's call.

## 7. Session ceremony

Per STUDIO_PROCESS.md §10 retro-then-edit discipline:
1. All waves ship.
2. PR-time review (fresh-spawn).
3. Live-test cadence until clean.
4. PR opens; merges to main.
5. **Multi-agent retro** — `SendMessage` the persistent reviewer trio AND specialists who shipped (decision-arc continuity!). Three questions: What worked / What broke / What edit would you ship.
6. Lead synthesizes + lands permanent edits in `STUDIO_PROCESS.md` §9 + §10. Per §8: "the retro is performative without the edit."

## 8. After Phase 3 session 2

Phase 3 is COMPLETE after this session. The economic loop foundation, all Tier-1 buildings, the first opponent (DummyAI), and the fog data layer are all shipped. **Tier 0 prototype delivery is Phase 6** — but Phase 3's completion is the foundation Phase 4 (Full Farr) builds on.

Pre-Phase-4 modeling step: balance-engineer's Farr curve spreadsheet (per `02_IMPLEMENTATION_PLAN.md` Phase 4 pre-phase activity). Don't dispatch Phase 4 wave 1 until that's complete.

---

*Ratified v1.0.0 — written by team-lead. Reviewed by Siavoush 2026-05-14: Open Space participants confirmed (Room A: gameplay-systems + world-builder; Room B: world-builder + ai-engineer + gameplay-systems). DummyAI sync locked to Pattern B (2-party, ai-engineer + balance-engineer). DummyAI probe-attack trade-off accepted — single scripted probe at minute N (negotiated in sync). Session 2 dispatches begin per §6 protocol.*
