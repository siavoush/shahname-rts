---
title: Decision Packet — Phase 3 → Phase 4 boundary
type: decision-request
status: awaiting-design-chat
version: 1.0.0
owner: team-lead (implementation side)
audience: design chat (Siavoush + design context)
read_when: one-sitting design session — this packet is built to clear the whole backlog in one pass
prerequisites: [none — written to be read cold]
references: [QUESTIONS_FOR_DESIGN.md, codex/QUESTIONS_FOR_DESIGN.md, DECISIONS.md, 01_CORE_MECHANICS.md, 02_IMPLEMENTATION_PLAN.md §10, docs/SHAHNAMEH_ECONOMY_RESEARCH.md, BUILD_LOG.md]
tags: [decision-packet, phase-4-gate, design-routing]
created: 2026-06-08
---

# Decision Packet — 2026-06-08

## Why this packet exists

Phase 3 closed on 2026-06-08 (10 sessions, ~50 PRs, 1643 tests, end-to-end match loop + headless AI-vs-AI batch infrastructure). A comprehensive engineering review found the implementation side ready for Phase 4 — and found that **the binding constraint is now the design pipeline**: DECISIONS.md has had zero entries since 2026-05-01, while 13 root + 5 codex design questions accumulated, one of them explicitly Phase-4-blocking since 2026-04-30.

This packet is every open question in one place, each with options, an implementation-side recommendation, and the cost of further delay. It is sized so one design-chat sitting clears the backlog. **Each ruling should land as a DECISIONS.md entry** — several past rulings (Khaneh +5 pop cap, half-built-buildings-targetable) were made inline during live-tests and never recorded; the "what is settled" log is currently ~5 weeks behind operative reality.

Tiers: **Tier 1 must be answered before Phase 4 content work can be briefed.** Tier 2 is cheap naming/convention calls. Tier 3 is ratify-the-default. Tier 4 is housekeeping the packet discovered.

---

## Tier 1 — Phase-4 blocking (3 decisions)

### 1.1 Snowball-protection definitions (open since 2026-04-30 — THE blocker for full FarrSystem)

`01_CORE_MECHANICS.md` §4.3 specifies Farr drains for "killing when your army outnumbers theirs 3:1" and "destroying economy when their military is broken." Both terms need precise definitions before the Phase-4 FarrSystem can be implemented.

**(a) What is "3:1 army ratio"?**
- Option 1: unit count (simplest; 30 spearmen vs 10 cavalry = 3:1 despite cost difference).
- Option 2: population cost (accounts for unit-class weight; no new tuning surface — pop costs already exist in balance.tres).
- Option 3: combat-power index (most accurate; opens a whole new per-unit tuning surface).

**Implementation-side recommendation: Option 2 (population cost).** It reuses an existing, already-tuned number, can't be gamed by unit-count spam the way Option 1 can, and avoids Option 3's new tuning surface. One-line check at kill time: `attacker_team_pop >= 3 * defender_team_pop`.

**(b) What is "military is broken"?**
- Option 1: zero military units alive.
- Option 2: zero military units alive AND zero operational military-production buildings.
- Option 3: army strength below X% of recent peak (requires history tracking).

**Implementation-side recommendation: Option 2.** It captures "they cannot fight back AND cannot rebuild" — which is the moral shape §4.3 is encoding (kicking someone who is down). Option 1 fires during ordinary army-trade moments; Option 3 adds state-history machinery for marginal gain.

**Cost of delay:** Full FarrSystem — "the central mechanical innovation" per `01_CORE_MECHANICS.md` — cannot ship. Everything behind it (Kaveh Event, tech-tier Farr gating, the fun-gate playtest) slips with it.

### 1.2 Trade & Transport thesis — commit, stage, or decline (open since 2026-05-24)

The full case is `QUESTIONS_FOR_DESIGN.md` 2026-05-24 + `docs/SHAHNAMEH_ECONOMY_RESEARCH.md` v1.0.0. Compressed: shift from "economy serves the army" (SC2/AoE2) to "wealth-flow IS the contest" — local stores, attackable caravans, escort automation, upkeep reframed as **royal largesse** (loremaster verdict: historically authentic AND structurally correct; down-flow generosity is the just-king's load-bearing moral axis in the Shahnameh). Emergent Iran/Turan asymmetry from one ruleset. Re-anchors Phases 4-8.

- Option 1: **Commit now** — Phase 4 is briefed around T&T (~6-10 sessions) + Phase 5+ raider AI (~10-15 sessions).
- Option 2: **Ratify thesis, gate implementation** — adopt T&T + royal-largesse as the project's economy direction NOW (so Phase-4 briefs stop hedging and forward-compat seams like Mazra'eh's `_local_stock_x100` become committed paths), but ship Phase-4 core (full Farr, tech tiers, production) first and gate T&T implementation start on the fun-gate playtest verdict.
- Option 3: **Decline** — standard SC2-shaped economy; late-game pressure via a plain upkeep mechanic; T&T archived.

**Implementation-side recommendation: Option 2.** It matches the staging already proposed in the original entry, resolves the late-game-pressure design question's DIRECTION without betting 6-10 sessions before the loop is proven fun, and lets the first AI-vs-AI balance pass run on the simpler economy (cleaner baseline data). The one thing Option 2 must include: a ratified one-line answer to "does MVP-validation happen WITH or WITHOUT upkeep-lite?" — balance-engineer has pre-registered that match-duration data is invalid as a pacing signal until SOME late-game pressure exists. Recommend: a minimal royal-largesse upkeep trickle ships WITH Phase-4 core as the pressure mechanism, sized by balance-engineer, regardless of when full T&T lands.

**Cost of delay:** every Phase-4 economy brief is unwritable; the late-game-pressure gap stays open; the 28h-per-batch AI-vs-AI runs produce duration data we already know is invalid.

### 1.3 Turan economy frame — ratify non-mirror (open since 2026-05-17)

Two waves of loremaster review converged: Turan's economy is tribute (*baj*) + raid + caravan (*karavan*) + tent-household (*otaq*/*khargah*) — NOT mirror-buildings of Iran. The frame is **already operative** in shipped code (mazraeh.gd + madan.gd cultural-note headers say "do not clone as Turan building"). Ratification makes it canonical before any Phase-4 Turan work; the specific mechanical shapes stay deferred to their waves.

**Implementation-side recommendation: ratify as stated.** Zero implementation cost now; prevents a future implementer from cloning against the established convention. Pairs naturally with a 1.2 Option-2 ruling (Turan raid-economy is half the T&T asymmetry).

**Cost of delay:** low until Turan economy work begins — but ratifying costs one sentence.

---

## Tier 2 — Naming & convention (one sitting, low stakes individually, compounding consistency value)

### 2.1 UI primary-name convention (open since 2026-05-14)
Persian-primary ("Khaneh", "Mazra'eh") vs English-primary ("House", "Farm"). Persian-primary is already the de-facto shipped state (fixed at `f0e79ce` per loremaster's strong recommendation). **Recommendation: ratify Persian-primary** + optional English gloss in tooltips. It teaches one Persian word per element and matches the Persian-rooted-not-flavored stance.

### 2.2 Coin vs Sekkeh (pairs with 2.1)
**Recommendation: keep "Coin"** (loremaster's own call — generic enough not to dilute the setting; سکه lands in the fa column at Tier 2). Consistent Persian-primary for *named cultural objects*, English for *generic resource abstractions* is a defensible line; ratify it explicitly so future resources (wood? stone?) inherit a rule, not a vibe.

### 2.3 Turan housing analogue naming (open since 2026-05-14)
*Otaq* (tent) vs *Khargah* (royal tent) for the future pop-cap analogue; *Cherahgah* (grazing-ground) floated for the Mazra'eh-analogue. **Recommendation: reserve Khargah for a Phase-4+ Turan-court building; pencil Otaq + Cherahgah as working names** — they only bind when Turan economy ships, but answering now prevents settled-only assumptions baking into shared abstractions.

### 2.4 Codex naming cluster (5 items, `codex/QUESTIONS_FOR_DESIGN.md`)
- **Siavash vs Siavoush** as entry id (the other becomes `aka`). This is personally yours — the scholarly standard is Siyāvaš; your own name is the project's preferred form. Pure id-stability call.
- **Simorgh vs Simurgh** (currently stubbed `simorgh`).
- **Haft Khan vs Haft Khwan** (simplest id `haft-khan`).
- **Sekandar register**: legend | history.
- **farr.md primary text**: which canonical Jamshid farr-departure passage from Ganjoor (the fetcher tooling is built; needs only the verse selection).

**Recommendation:** rule all five in one batch; they're id-stability decisions that get more expensive every session the codex grows.

---

## Tier 3 — Ratify-the-default (defaults already shipped; one-word confirmations)

| # | Question | Shipped default | Recommendation |
|---|---|---|---|
| 3.1 | Builder worker inside vs outside footprint during construction (2026-05-17) | Inside (SC2 shape — protected builder) | Keep default until Phase-4/5 harassment doctrine design; revisit alongside combat design, not before |
| 3.2 | Depleted mine ruins clearable? (2026-04-30) | Permanent for MVP | Confirm permanent; revisit at Tier 2 |
| 3.3 | Worker auto-retarget on depletion (2026-04-30) | (c) idle at Throne | Confirm for MVP. Note: the 2026-06-08 mine SSOT fix raised reserves 100→1500, so depletion is now ~15× rarer — pressure to upgrade to (a) nearest-same-resource dropped accordingly |
| 3.4 | Resource economy expansion — wood/stone/iron refining chains (2026-05-24) | Two-resource MVP | Confirm post-Phase-8 / Tier-2 scope |

### 3.5 Dehqan-compression expert flag (2026-05-24, lower-confidence loremaster finding)
The acknowledgment paragraph already shipped in `00_SHAHNAMEH_RESEARCH.md` (PR #45). Standing watch: route to an Iranist / Shahnameh-khani contact when one is identified. **No action needed; confirming the watch stands.**

---

## Tier 4 — Housekeeping the packet's preparation discovered

### 4.1 Two stale entries should be ARCHIVED as resolved
- **Navmesh-carve investigation timing (2026-05-17):** resolved by Wave 1D's explicit source-geometry pipeline (BUILD_LOG 2026-05-17+, ARCHITECTURE.md §7 L25/L26 RESOLVED, spike doc v1.0.0). The QUESTIONS entry was never closed.
- **AI difficulty wave cadence (plan §10.3):** ratified in `docs/AI_DIFFICULTY.md` v1.0.0 (2026-05-01). Index row never closed.

**Request:** confirm both archivals; lead will move them to the resolved section.

### 4.2 02_IMPLEMENTATION_PLAN.md re-baseline (v1.2.0 → v2.0.0)
The plan doc froze 2026-05-01 while reality moved three phases: Phase 3 absorbed plan-Phase-4 buildings (Atashkadeh, Sowari-khaneh, Tirandazi) and plan-Phase-6 infrastructure (AI-vs-AI harness); "Phase 4" in current usage no longer means any of plan-Phase-4's tasks; the §10 question index is stale (see 4.1); the 21-week calendar is dead and un-re-estimated. The doc is design-chat-owned, so this is a request, not an action: **lead offers to draft v2.0.0** (phases 0-3 closed with actuals; 4-8 re-scoped with the T&T fork from 1.2 as explicit branch-points; §10 folded into QUESTIONS_FOR_DESIGN.md as single SSOT) **for design-chat ratification.**

### 4.3 Early fun-gate checkpoint (new proposal)
`DECISIONS.md` 2026-04-30 gates real art on "the MVP loop is fun as boxes," but the only scheduled human playtest is plan-Phase-8 — months out. **Proposal: schedule a structured Siavoush playtest immediately after Phase-4 core (full Farr + tech tier + production queues) lands, with "do you want to play it again?" as the recorded outcome.** The gate that controls the project's biggest scope decision should sit at the earliest moment it can produce signal. If ratified, lead adds it as a named milestone in the v2.0.0 re-baseline.

### 4.4 DECISIONS.md hygiene
Inline rulings made during live-tests that never landed as entries (at minimum: Khaneh +5 pop cap revert "per user explicit direction"; half-built-buildings-targetable "per user design intent"; the Q1 win-condition match-time ruling from Wave 3-Sim). **Request:** lead drafts the backfill entries; design chat ratifies. Going forward, any inline ruling gets an entry the same session — that's what keeps "what is settled" trustworthy.

---

## Suggested processing order for the sitting

1. **1.1 snowball definitions** (5 min — two multiple-choice picks; unblocks FarrSystem).
2. **1.2 T&T ruling** (the big one — 20-30 min if Option 2; the staging is pre-designed).
3. **1.3 Turan frame ratification** (1 min).
4. **Tier 2 naming batch** (10 min for all seven).
5. **Tier 3 confirmations** (2 min — table above is yes/no).
6. **Tier 4 housekeeping approvals** (5 min — archivals + re-baseline mandate + fun-gate milestone + backfill mandate).

Total: well under an hour for the entire design backlog. Every ruling lands as a DECISIONS.md entry; lead executes the follow-through (plan re-baseline draft, archivals, backfill drafts) in the implementation lane.
