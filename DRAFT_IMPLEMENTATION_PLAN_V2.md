---
title: DRAFT — Implementation Plan v2.0.0 (re-baseline proposal)
type: draft-proposal
status: awaiting-design-ratification
version: 2.0.0-draft.1
owner: team-lead (implementation side) — drafted under DECISION_PACKET_2026-06-08.md Tier 4.2 mandate offer
summary: Lead-drafted re-baseline of 02_IMPLEMENTATION_PLAN.md v1.2.0. Phases 0-3 closed with actuals; Phase 4 redefined as MVP core completion ending in the fun-gate playtest; Phases 5+ re-scoped as an explicit Trade & Transport fork; standing tooling lane; honest velocity note; §10 questions index deleted in favor of QUESTIONS_FOR_DESIGN.md + the decision packet.
audience: design chat (for ratification); all agents (read as preview only — NOT yet the plan of record)
read_when: design-chat ratification sitting; agents read after ratification lands
prerequisites: [MANIFESTO.md, DECISION_PACKET_2026-06-08.md]
references: [02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md, docs/ARCHITECTURE.md, 01_CORE_MECHANICS.md, QUESTIONS_FOR_DESIGN.md, docs/AGENT_HANDOFFS_PHASE3.md, DECISIONS.md]
tags: [plan, re-baseline, draft, phases, t-and-t-fork, fun-gate]
created: 2026-06-11
---

# DRAFT — Implementation Plan v2.0.0 (re-baseline proposal)

## 0. Status of this document

**This is a proposal, not the plan.** `02_IMPLEMENTATION_PLAN.md` is design-chat-owned; implementation does not modify `0X_*.md` docs (CLAUDE.md). The decision packet (Tier 4.2) offered a lead-drafted re-baseline for design ratification; this file is that draft.

- **Until ratified:** v1.2.0 remains the document of record. Where v1.2.0 contradicts shipped reality, `BUILD_LOG.md` + `docs/ARCHITECTURE.md` §2/§6 are the truth; this draft summarizes that truth.
- **On ratification:** the design chat (or a design-chat-authorized commit) replaces `02_IMPLEMENTATION_PLAN.md` with this content as v2.0.0, applying any rulings/edits from the sitting, and this draft file is deleted.
- **Open dependencies:** §4 binds on packet **Tier 1.1** (snowball definitions); §5's fork binds on **Tier 1.2** (T&T ruling); §4's end-gate binds on **Tier 4.3** (fun-gate proposal). The draft marks each.

---

## 1. What survives from v1.2.0 unchanged

The constants carry forward; restating them briefly so the re-baseline is self-contained:

- **Manifesto precedence.** This plan operates under `MANIFESTO.md`. When a tactical decision here conflicts with a principle, the principle wins. The plan is the hypothesis; the principles are the constants.
- **The cardinal rule of RTS prototyping:** get playable fast, iterate forever. Quality is determined by how many times we run the design → code → play → learn loop. Optimize for iteration speed above all else.
- **Target platform:** macOS (Apple Silicon), Godot 4.6.2 pinned, all local.
- **Team structure:** the virtual studio per `docs/AGENT_REGISTRY.md` v2.0.0 (gen-2 instances post the 2026-06-08 generational reboot; handoff state in `docs/AGENT_HANDOFFS_PHASE3.md`). Operating modes per `docs/STUDIO_PROCESS.md`.
- **Scope discipline:** v1.2.0 §11 ("What This Plan Does NOT Cover") carries forward verbatim — multiplayer, campaign, Divs, save/load, multiple heroes, real art (gated on the fun verdict), etc. remain post-MVP. One amendment: *whether* caravan/trade mechanics are post-MVP is exactly the §5 fork question, no longer settled by silence.
- **What changes:** per-phase task tables are gone — that granularity moved to wave-brief kickoff docs (`02a`–`02t`) long ago and this doc no longer competes with them. This is the strategic layer: phase goals, gates, fork points, and honest accounting.

---

## 2. Phases 0–3: CLOSED, with actuals

| Phase | Plan said (v1.2.0) | Shipped | Sessions |
|---|---|---|---|
| 0 — Foundation | 3 weeks, ~20 tasks, 3 contracts | ✅ Closed 2026-05-01 | 4 |
| 1 — Unit Core | select/move/formation, Farr gauge | ✅ Closed 2026-05-04 | 2 |
| 2 — Combat | RPS triangle, first Farr drain | ✅ Closed 2026-05-08 | 2 |
| 3 — Economy + Dummy AI + Fog data | econ loop, DummyAI, fog grid | ✅ Closed 2026-06-08 | 10 (+1 follow-on) |

**Phase 0 — delta.** Shipped essentially as designed (contracts-first paid off: SimClock 30Hz fixed-tick, fixed-point x100, typed EventBus, TimeProvider, component model, path-scheduler seam, BalanceData/constants split, MatchHarness, GUT + pre-commit gate). Two planned autoloads **still have not shipped**: `GameRNG` (MatchHarness seeds the global RNG with a TODO) and the `Telemetry` sink (observability went a different, arguably better route — §9.M6 structured stdout logging + the Phase-3 NDJSON batch schema). Both are tracked as foundation debt in §6; GameRNG becomes load-bearing the moment the Kaveh Event's seeded rolls ship (§4).

**Phase 1 — delta.** Shipped per plan in 2 sessions: unit scene + components, NavigationRegion3D, single/box selection, right-click move, Idle/Moving states, GroupMoveController formations, Farr gauge with color bands. Ahead of plan: control groups + double-click-select-of-type (deferred to Phase 2 in v1.2.0) landed in Phase 1 session 2.

**Phase 2 — delta.** Shipped per plan in 2 sessions: CombatComponent/HealthComponent with `last_death_position` capture, attack + attack-move, the full 9-type RPS roster including horse archers at Tier-1-equivalent stats (the plan's "expose kiting early" call — vindicated), 16-cell effectiveness matrix, first Farr drain end-to-end, health bars, F4 range overlay, multi-select panel. The §10.5 open question resolved itself by shipping.

**Phase 3 — delta (the big one).** Planned as a 2-week economy phase; became a 10-session phase (~50 PRs; suite grew 28 → 1659 tests) because it absorbed work from three plan-phases plus work the plan never imagined:
- **Absorbed from plan-Phase 4:** Atashkadeh, Sowari-khaneh, Tirandazi — all 8 Iran Tier-1/2 buildings shipped, with destructibility (HealthComponent + cleanup chains + `building_destroyed`), which no plan-phase explicitly owned.
- **Absorbed from plan-Phase 6:** the headless AI-vs-AI batch infrastructure (runner + `DummyIranController` reference AI that genuinely plays its build-order through the player's command path + canonical NDJSON result format + aggregator). The "DummyAI" of plan-Phase-3 became a real probing `TuranController`.
- **Unplanned but T&T-load-bearing:** Throne + win condition, local kind-matching dropoffs (`IDropoffTarget`, the `_local_stock_x100` caravan seam), fog data layer with per-tick recompute.
- **Reversals and misses:** the Phase-1 navmesh strategy (NavigationObstacle3D carve) **failed in practice** — 4 diagnostic rounds + a dedicated wave (1D) replaced it with an explicit source-geometry synchronous-rebake pipeline, now pinned by lint L6. Fertile-tile placement rejection never shipped (waits on a TerrainSystem no wave owns — owner assigned in §5). The §9.M6 observability discipline ("log everything except camera") was forged mid-phase by the BUG-C1/D1/D2/H1..H9 chains, not planned.
- The +1 is the session-11 review-driven follow-on (2026-06-08): two BLOCKER hotfixes (AI gating, unit/building id collision at the emitter root) + the data-validity wave that made the batch pipeline's data truthful.

---

## 3. Phase vocabulary fix

**"Phase 4" is hereby redefined.** In v1.2.0, Phase 4 meant "Production, Tech Tiers, Full Farr" with a building list — most of those buildings shipped in Phase 3. In current usage (decision packet, retros, briefs), **Phase 4 means: the phase after Phase 3 that completes the MVP core loop**, as specified in §4 below. This supersedes the v1.2.0 meaning everywhere; older docs citing "plan-Phase-4/5/6" should be read against the mapping:

| v1.2.0 phase | Where it actually lives now |
|---|---|
| 4 — Production/Tiers/Full Farr | Buildings → shipped (Phase 3). Tech-tier system, queues, full Farr → **new Phase 4** |
| 5 — Heroes & Kaveh | → **new Phase 4** (Rostam v1 + Kaveh v1; Yadgar/Dadgah ride with it) |
| 6 — Full AI + AI-vs-AI sim | Sim infra → shipped (Phase 3). Full Turan AI → **Phase 5+, branch-dependent** (§5) |
| 7 — Map/Fog render/Terrain | → **Phase 5+ shared backbone** (§5) |
| 8 — Integration/Polish/Playtest | Final integration → **Phase 5+**; the *first* fun playtest moves up to the **Phase 4 end-gate** (§4) |

---

## 4. Phase 4 (new) — MVP core completion

**Goal:** a complete core loop on the simple two-resource economy: gather → build → tech up → produce → fight → manage Farr → win/lose — with Rostam on the field and the Kaveh Event live. Everything `01_CORE_MECHANICS.md` §1 requires that isn't an opponent-AI or presentation concern.

**Theme:** *"Earn the divine glory — then find out if it's fun."*

Scope (wave briefs own the task-level detail):

1. **Full FarrSystem** — every §4.3 generator and drain through `apply_farr_change()`, snowball protection included. ⛔ **Gated on packet Tier 1.1 (a)+(b)** — the 3:1-ratio and broken-military definitions. This is the only hard design blocker in the phase.
2. **Tech tier advancement (Village → Fortress)** — the TechSystem consumer chain for the dormant `BuildingStats.tier` field. The Atashkadeh gateway building already shipped (Phase 3); Tier-2 production buildings (Sowari-khaneh, Tirandazi) already exist and get properly gated. Qal'eh/Barghah ship here only if tier-gating demands them; otherwise Phase 5+.
3. **Production queues** — replace the single-slot MVP queue (`is_ready_to_produce` flip at Stage 2 is the designed extension point) + queue/cancel/rally UI.
4. **Minimal royal-largesse upkeep trickle** — per packet 1.2 recommendation: ships WITH Phase-4 core as the late-game pressure mechanism, sized by balance-engineer, regardless of when/whether full T&T lands (binds on the Tier-1.2 ruling). Without it, match-duration data is invalid as a pacing signal (balance-engineer, pre-registered).
5. **Rostam v1** — hero unit, Cleaving Strike + Roar of Rakhsh, death/respawn with Farr penalties, hero portrait. Yadgar (consumes Phase-2's `last_death_position`) + Dadgah ride along.
6. **Kaveh Event v1** — trigger (Farr < 15 sustained), execution (Kaveh + rebels, worker defection via seeded rolls — **lands GameRNG**, the Phase-0 debt), resolution (defeat or restore), warning UI.
7. **Farr UX completion** — floating +/- change feed, F2 Farr-log overlay, tier indicator.

**End-gate: the structured fun-gate playtest (packet 4.3).** Immediately after Phase-4 core lands, Siavoush plays 3+ complete matches against the best available opponent (TuranController probes + DummyIran-class behavior — full AI is explicitly NOT a prerequisite for this gate). Recorded outcome: **"do you want to play it again?"** plus what was fun/frustrating/broken. This is the earliest moment the project's biggest scope decisions (real art per DECISIONS.md 2026-04-30; the T&T bet under packet Option 2) can get real signal — so the gate sits here, not at old-Phase-8.

**Estimate:** 8–12 sessions (see §7). FarrSystem briefs are unwritable until Tier 1.1 lands; items 2–5 and 7 are briefable today.

---

## 5. Phases 5+ — the Trade & Transport fork

⛔ **FORK POINT — awaiting packet Tier 1.2.** The phases after Phase 4 take one of two shapes. Under the recommended Option 2 (ratify thesis, gate implementation), Phase 4 ships first either way and **the branch decision executes at the fun-gate verdict**; under Option 1 the fork resolves to Branch A immediately; under Option 3, Branch B.

**Branch A — T&T ratified** (`docs/SHAHNAMEH_ECONOMY_RESEARCH.md` v1.0.0; wealth-flow IS the contest):
- **Phase 5A — T&T economy core (~6–10 sessions):** local stores (the `_local_stock_x100` seam goes live), caravans as physical attackable wealth-movers, escort automation, royal-largesse upkeep grown from the Phase-4 trickle into the full down-flow mechanic.
- **Phase 6A — Turan raid economy + full AI (~10–15 sessions):** raider AI as the T&T antagonist (the packet's Phase-5+ raider estimate), full Turan opponent FSM, Piran, difficulty levels per `docs/AI_DIFFICULTY.md` — the AI plays the asymmetric ruleset (tribute/raid/caravan frame per packet Tier 1.3, **not** mirror-buildings).
- **Phase 7A — world + presentation** (shared backbone below).
- **Phase 8A — integration, final balance, Tier-1 playtest.**

**Branch B — T&T declined:**
- **Phase 5B — full Turan AI opponent (~6–10 sessions):** FSM economy/army/attack-waves, Piran, difficulty levels; plain-upkeep tuning as the standing late-game pressure.
- **Phase 6B — world + presentation** (shared backbone below).
- **Phase 7B — integration, polish, final balance, Tier-1 playtest.** T&T research archives cleanly; `_local_stock_x100` stays as dormant seam.

**Shared backbone (both branches, order differs):** Plains of Khorasan map, terrain types + movement modifiers (and the TerrainSystem that owns fertile-tile placement rejection — the named Phase-3 miss gets its owner here), fog-of-war *rendering* on the shipped data layer, building memory, minimap, match flow (menu → victory/defeat → summary), sound placeholders, performance pass, final data-backed balance batches.

---

## 6. Standing tooling lane (not a phase)

Runs alongside content phases continuously; staffed opportunistically between waves. Current queue (from `docs/AGENT_HANDOFFS_PHASE3.md` + ARCHITECTURE §6 carry-forwards):

- **Calibration batches:** balance-engineer's tuning loop on AI-vs-AI aggregates (outcome distribution → duration p50 → first-piyade p95 → RPS); `placeholder → calibrated` promotion in balance.tres (4 anchored / 17 calibrated / 3 placeholder); affordability-table re-run on the new mine economics is first.
- **Sim-cost optimization triad:** spatial culling for AI scans, batched pathfinding, per-team FSM batching — plus the roster-as-knob flag. Target: batch wall-clock (~26 ticks/sec ≈ 28h per 50-match batch — overnight-viable, not iteration-viable).
- **Test/CI debt:** L7 lint (§9.M7 mechanical guard), subprocess-smoke test for `--headless-batch` boot, MatchHarness v2 (resets 5/13 autoloads; stubs stale), real-match determinism snapshot-hash test.
- **Foundation debt:** GameRNG (pulled forward by Kaveh, §4), Telemetry/MatchLogger decision (formalize the NDJSON+log route or build the planned sink — engine-architect recommendation due before Phase-5 briefs).

---

## 7. Velocity — an honest note

**The v1.2.0 21-week calendar is dead, and this draft does not replace it with a new one.** Observed actuals: Phase 0 = 4 sessions, Phase 1 = 2, Phase 2 = 2, Phase 3 = 10 (+1) — phase cost scales with integration surface, not task count, and Phase 3's surface (economy × combat × AI × fog × destructibility) is the honest preview of everything after it. Planning anchor: **~10 sessions for an integration-heavy phase**; Phase 4 estimated 8–12; Branch estimates in §5 are session-count ranges from the packet. No calendar-week commitments — sessions are the unit we can actually measure (a session ≈ one orchestrated working block; see BUILD_LOG for what one contains). Re-estimate at each phase close, from actuals only.

---

## 8. Open-questions index: DELETED

v1.2.0 §10 is deleted and not replaced. **Single SSOT for open design questions: `QUESTIONS_FOR_DESIGN.md` (+ `DECISION_PACKET_2026-06-08.md` while it is being processed).** Disposition of the old five rows: #1/#2 (snowball definitions) → packet Tier 1.1, still open, Phase-4-blocking; #3 (AI cadence) → resolved in `docs/AI_DIFFICULTY.md` v1.0.0, archival per packet 4.1; #4 (camera lock) → shipped Phase 0, resolved; #5 (horse-archer timing) → shipped Phase 2, resolved. A plan doc that mirrors the questions list goes stale (it did — twice); it now points instead.

---

## 9. Risk register — delta from v1.2.0

| Risk | Status |
|---|---|
| Architectural retrofits in Phase 4-8 | ✅ Largely retired — Phase-0 contracts held through Phase 3; navmesh was the one reversal and is re-pinned (L6) |
| Balance is guesswork without data | ✅ Mitigation shipped — batch pipeline + truthful NDJSON; risk shifts to batch wall-clock (§6) |
| Farr feels ignorable | ⏳ Still open — gauge + one drain shipped; the real test is the Phase-4 fun-gate |
| Kaveh too punishing/too weak | ⏳ Unchanged — seeded RNG + 3 tuning iterations still the mitigation |
| **NEW: design pipeline as binding constraint** | DECISIONS.md silent 2026-05-01 → 2026-06-08 while 18 questions queued; mitigation = decision packets + same-session DECISIONS entries (packet 4.4) |
| **NEW: fun-gate fails** | "No, I don't want to play again" → re-scope sitting before any Phase-5 brief; that is the gate working, not a schedule slip |
| Scope creep into Tier 2 | ⏳ Permanent — §1 scope list + the fork discipline are the fence |

---

## 10. Ratification asks (the design-chat checklist)

1. Ratify this re-baseline as `02_IMPLEMENTATION_PLAN.md` v2.0.0 (with edits as ruled), or return with changes.
2. Rule packet Tier 1.1 (a)+(b) — unblocks §4 item 1.
3. Rule packet Tier 1.2 — resolves the §5 fork mode (and binds §4 item 4's trickle).
4. Confirm packet 4.3 — the fun-gate playtest as the named Phase-4 end-gate milestone.
5. Land each ruling as a `DECISIONS.md` entry (packet 4.4 hygiene).

---

*Drafted by the implementation lead 2026-06-11 under the packet's Tier-4.2 offer. Everything in §2 is sourced from BUILD_LOG.md and ARCHITECTURE.md §2/§6; nothing in §4–§5 invents design — it stages already-specified mechanics behind already-posed design questions.*
