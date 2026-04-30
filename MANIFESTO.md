---
title: Manifesto — Foundational Principles
type: manifesto
status: stable
owner: team
summary: References Peiman Khorramshahi's manifesto as the project's foundational principles. Each principle is mapped to a specific application in this project. Principles override tactical rules.
audience: all
read_when: every-session
prerequisites: []
ssot_for:
  - the ten foundational principles (named) and their application to this project
  - the principle-over-tactical-rule precedence rule
references: []
tags: [principles, manifesto, foundation]
created: 2026-04-30
last_updated: 2026-04-30
provenance: References https://github.com/peiman/manifesto by Peiman Khorramshahi as the canonical source.
---

# Manifesto — Foundational Principles

**پندارِ نیک، گفتارِ نیک، کردارِ نیک**
*Good thoughts, good words, good deeds.*

---

This project operates under the principles of [Peiman Khorramshahi's Manifesto](https://github.com/peiman/manifesto) — *Principles for building things that last, in a world moving too fast.*

Read the full manifesto at the source. **It is the canonical version.** The summary below names each principle and how it applies to *this* project. Per Principle 7 (Single Source of Truth), we reference rather than duplicate.

The principles themselves were not designed — they were discovered through space hardware engineering, agile coaching, AI systems work, and the Zoroastrian and Swedish traditions that frame the project's roots.

That the project source material is the *Shahnameh* and the manifesto's opening invocation is the central tenet of Zoroastrianism is not coincidence. It's continuity.

---

## The Ten Principles

### 1. Truth-Seeking
*Observe, trace, verify. Every conclusion rests on evidence.*

**Applied here:** When something breaks, read the source — not the assumption. Telemetry from Phase 0 onward. Lint enforcement. AI-vs-AI simulations as evidence, not opinion. Every Farr change traceable through `apply_farr_change()`.

### 2. Curiosity Over Certainty
*Failure is a signal to understand, not a problem to fix.*

**Applied here:** When the Kaveh Event "doesn't feel right" in playtesting, we don't paper-fix the numbers — we ask what the failure is telling us about the design. The retro practice in `STUDIO_PROCESS.md` is built on this.

### 3. Good Will
*Capabilities are accelerating; the infrastructure around them is fragile. Build anchors.*

**Applied here:** Every contract document, every assertion, every CI rule is an anchor. The `SIMULATION_CONTRACT.md` exists precisely because we knew the alternative was drift.

### 4. Lean Iteration
*Reality is the specification. Build the smallest thing that produces real data.*

**Applied here:** "Get playable fast, iterate forever." Phase 0 ships with a Farr stub before Farr does anything. Phase 3 ships a DummyAI before the real AI exists. Numbers in `BalanceData.tres` are starting points, not contracts.

### 5. Platforms, Not Features
*Each step is a platform for the next. Build heavy enough to support what comes after.*

**Applied here:** Phase 0 expanded from 2 weeks to 3 because the studio review showed the foundations were thin. Every retrofit avoided in Phases 4-8 is paid for here. Cited explicitly in the manifesto: *"The Achaemenids built roads, postal systems, and governance structures designed to endure for generations."*

### 6. Partnership
*Built by a team of different minds. We take care of each other.*

**Applied here:** The seven specialist agents are partners, not subordinates. The discussion format in `STUDIO_PROCESS.md` is designed to elevate their judgment, not bypass it. The lead is a servant-leader, not a router.

### 7. Single Source of Truth
*Every piece of information has one authoritative location. Reference, don't duplicate.*

**Applied here:** This document references the manifesto rather than copying it. `02_IMPLEMENTATION_PLAN.md` §9 references `STUDIO_PROCESS.md` rather than restating the rules. `BalanceData.tres` is the only place tunable numbers live. The artifact is the file on disk; messages are notification only.

### 8. Separation of Concerns
*Different responsibilities live in different places. Each separation prevents a specific kind of drift.*

**Applied here:** Design (`01_CORE_MECHANICS.md`) and implementation (`game/`) split. Structural constants (`constants.gd`) and tunable balance (`BalanceData.tres`) split. Each agent has owned files. Components are composed, not inherited.

### 9. Automated Enforcement
*Rules that aren't enforced erode. Compile-time over linting, linting over scripts, scripts over CI, CI over honor system.*

**Applied here:** `SimNode._set_sim()` asserts at runtime (compile-adjacent). `tools/lint_simulation.sh` catches `_process()` calls into `apply_*` and `*_tick`. Pre-commit hook runs GUT. `apply_farr_change()` is the chokepoint. Off-tick mutation crashes loudly in dev.

### 10. Feedback Cycle
*Specifications and implementations learn from each other. A specification is a hypothesis.*

**Applied here:** Every contract document is a hypothesis. The retro practice in `STUDIO_PROCESS.md` updates the rules based on what each sync teaches us. `01_CORE_MECHANICS.md` numbers are tuned through `BalanceData.tres` based on AI-vs-AI sim data. The plan revises as we build.

---

## How This Document Operates

- **All agents read this file** as part of their session-start sequence, alongside `CLAUDE.md` and the relevant spec docs.
- **When a principle and a tactical decision conflict**, the principle wins. Document the conflict in `QUESTIONS_FOR_DESIGN.md` if it warrants design-chat attention.
- **When a new principle proves itself** through repeated experience, propose it for the canonical manifesto upstream. Don't fork the principles silently.
- **Origin attribution is permanent.** This file does not paraphrase the manifesto into our own words. The principles belong to Peiman; this file just points home.

---

*Skynda långsamt. Hurry slowly.*

— *Source: [github.com/peiman/manifesto](https://github.com/peiman/manifesto) by Peiman Khorramshahi*
