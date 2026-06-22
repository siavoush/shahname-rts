---
title: Design Routing Brief — Tier-1 is now the critical path
type: decision-request
status: tier-1-RULED-2026-06-22 (Siavoush, implementation session) — entries below await ratification into DECISIONS.md
version: 1.0.0
owner: team-lead (implementation side)
audience: design chat (Siavoush + design context)
read_when: before the next design-chat sitting — this is the 5-minute cover for DECISION_PACKET_2026-06-08.md
supersedes: nothing (companion to the packet — adds 2 weeks of evidence, does not replace it)
references: [DECISION_PACKET_2026-06-08.md, BUILD_LOG.md, docs/AI_VS_AI_RESULT_FORMAT.md §8, DECISIONS.md]
created: 2026-06-22
---

# Design Routing Brief — 2026-06-22

## The one ask

**Rule on the 3 Tier-1 decisions in `DECISION_PACKET_2026-06-08.md`.** They are now the single binding constraint on the project — nothing substantive can be *correctly* built until they land. The packet is still accurate; this brief adds the two weeks of evidence since it was written and reports that **all three Tier-1 recommendations have been adversarially re-validated against the shipped code at HEAD** (2026-06-22) — they are implementable exactly as written, with no blockers.

Tier 2–4 (naming, ratify-the-defaults, housekeeping) are in the packet and can ride the same sitting, but they don't gate anything. **If the sitting is short, answer only Tier 1.**

## Why this is now urgent (it wasn't merely "open" — it's the bottleneck)

- **`DECISIONS.md` is frozen at 2026-05-01 — 7+ weeks.** Verified this week. Meanwhile the implementation side closed Phase 3, shipped the first decisive AI-vs-AI match, and put the loop in front of a human. The "what is settled" log no longer describes reality.
- **The implementation side is out of unblocked Phase-4 work.** Every Phase-4 content brief (full FarrSystem, tech tiers, production depth) is unwritable until 1.1 and 1.2 are ruled. Building anything now means guessing on the economy — i.e. building the wrong thing.
- **Your own playtest verdict points straight here.** After the first human play-through (you defeated the Turan throne end-to-end), the recorded read was: *"the basics of any RTS — what makes it fun is economics, tactics, strategy. Too early to say."* That is the correct, honest answer **at the table-stakes layer** — and the differentiators it names (the Farr economy, the economic contest, an opponent that pressures) are exactly what 1.1 and 1.2 unlock. The fun-gate can't give a real signal until they're in.

## Tier 1 — the three rulings (each: ask · recommendation · what's new since 2026-06-08)

### 1.1 — Snowball-protection definitions (THE blocker for full FarrSystem; open since 2026-04-30)
Two precise definitions are needed before the Farr drains in `01_CORE_MECHANICS.md` §4.3 can be coded.
- **(a) "3:1 army ratio" → recommend Option 2: population cost** (`attacker_pop ≥ 3 × defender_pop`). Reuses an already-tuned number; can't be gamed by unit-count spam.
- **(b) "military is broken" → recommend Option 2: zero military units alive AND zero operational military-production buildings.** Captures "can't fight back AND can't rebuild" without firing during ordinary army trades.
- **NEW / validated:** A real concern was checked and cleared — the playtest found the population *counter* is dead code (`change_population` has zero callers; HUD shows "Pop 0/0" forever). It does **not** block 1.1(a): the ratio is computed on demand by summing per-unit `population_cost` over living units (the `&"units"` group + team filter already ships), never by reading that counter. Both (a) and (b) are implementable today as written. *(The counter being dead is a separate small fix, not a design question.)*

### 1.2 — Trade & Transport economy thesis: commit / stage / decline (open since 2026-05-24)
The shift from "economy serves the army" to "wealth-flow IS the contest" — local stores, raidable caravans, upkeep reframed as **royal largesse** (loremaster: authentic *and* structurally correct).
- **Recommend Option 2: ratify the thesis as the project's economy direction now, gate the full implementation on the fun-gate verdict.** Phase-4 briefs stop hedging; the dormant forward-compat seams become committed paths; Phase-4 *core* (full Farr, tech tiers, production) still ships first on the simpler economy.
- **The one rider:** a minimal royal-largesse **upkeep trickle ships WITH Phase-4 core**, as the standing late-game pressure — regardless of when full T&T lands.
- **NEW / strongly strengthens:** the upkeep rider just stopped being a precaution and became a measured requirement. The first AI-vs-AI batches came back **byte-identical across 10 different seeds** — zero variance, because there is no production randomness *and no late-game pressure* to differentiate outcomes. Balance-engineer had pre-registered "duration data is invalid until pressure exists"; that's now empirically confirmed. **Until some late-game pressure exists, every balance batch is one match run N times.** The mine-economics SSOT fix (reserves 100→1500, now read truthfully from balance.tres) means the income curve is finally trustworthy to tune *against* — so the only missing ingredient for meaningful balance data is the pressure mechanism this rider supplies.
- The execution plan for this exact ruling is already drafted (`DRAFT_IMPLEMENTATION_PLAN_V2.md`, with explicit T&T branch-points) and waiting on go/no-go.

### 1.3 — Turan economy frame: ratify non-mirror (open since 2026-05-17)
Turan = tribute (*baj*) + raid + caravan + tent-household, **not** mirrored Iran buildings.
- **Recommend: ratify as stated.** Costs one sentence; the frame is *already operative* in shipped code.
- **NEW / validated:** the "do not clone as a Turan building" cultural-note headers are confirmed still present and load-bearing in both `mazraeh.gd` and `madan.gd`. Ratifying makes canonical what the code already assumes; pairs naturally with a 1.2-Option-2 ruling (Turan's raid economy is half the asymmetry).

## Order of operations this evidence clarifies

The 100%-Iran-win matchup is **expected and fine** — the MVP baseline is deliberately asymmetric to isolate control flow, and Turan AI improvement is Phase-6 scope. So the sequence is: **ship Phase-4 core asymmetrical → run the early fun-gate with the differentiators in place (packet §4.3, now de-risked by this week's informal dry-run) → only then invest in full balance and the T&T build-out.** Balancing or large batch runs *before* Phase-4 core would burn effort on data we already know is degenerate.

## Everything else

Tier 2 (naming: Persian-primary, Coin-vs-Sekkeh, Turan housing, codex id batch), Tier 3 (ratify-the-shipped-defaults table), Tier 4 (two stale-entry archivals, the `02_IMPLEMENTATION_PLAN.md` v2.0.0 re-baseline offer, the fun-gate milestone, the `DECISIONS.md` backfill) are all in the packet with recommendations. One new non-blocking question has accrued since: **view-only enemy selection** (`QUESTIONS_FOR_DESIGN.md` 2026-06-12, a Phase-5 UI candidate from the input hotfix) — safe to defer.

**Every ruling should land as a `DECISIONS.md` entry.** The lead executes all follow-through (plan re-baseline draft, archivals, backfill drafts) in the implementation lane once the rulings exist.


---

# RULINGS — Tier 1 cleared 2026-06-22 (Siavoush, implementation session)

All three Tier-1 decisions ruled in one sitting; every implementation-side recommendation accepted. **The entries below are formatted ready to paste into `DECISIONS.md`** (design-chat-owned — lead drafts, design chat ratifies; precedent: the 2026-05-01 Godot pin was authorized inline by Siavoush and recorded the same way). Phase-4 content is now unblocked.

## 2026-06-22

- **Economy direction — Trade & Transport / royal-largesse, staged (Packet §1.2, Option 2).** Ratified as the project's committed economy direction: wealth-flow IS the contest (local stores, raidable caravans, escort automation, upkeep reframed as royal largesse), with emergent Iran/Turan asymmetry from one ruleset. **Staging:** Phase-4 *core* (full FarrSystem + tech tiers + production queues) ships first on the simpler economy WITH a minimal royal-largesse upkeep trickle as the standing late-game pressure (sized by balance-engineer); the full T&T build (caravans / local stores / escort) is gated on the post-Phase-4-core fun-gate playtest. Forward-compat seams (Mazra'eh/Ma'dan `_local_stock_x100`) become committed paths. → `QUESTIONS_FOR_DESIGN.md` 2026-05-24, `docs/SHAHNAMEH_ECONOMY_RESEARCH.md`, `DECISION_PACKET_2026-06-08.md` §1.2. Authorized 2026-06-22 by Siavoush in the implementation session.
- **Snowball-protection: "3:1 army advantage" = population cost (Packet §1.1a, Option 2).** The Farr snowball drain triggers when `attacker_team_pop >= 3 * defender_team_pop`, summing each living unit's `population_cost` (balance.tres) over the team — enumerated on demand from the `&"units"` group (NOT the dead `change_population` counter). Chosen over unit-count (gameable by cheap-unit spam) and combat-power-index (new tuning surface). → `01_CORE_MECHANICS.md` §4.3, `DECISION_PACKET_2026-06-08.md` §1.1. Authorized 2026-06-22 by Siavoush.
- **Snowball-protection: "military is broken" = no military units alive AND no operational military-production buildings (Packet §1.1b, Option 2).** The "destroy-their-economy-when-they're-down" Farr drain triggers only when a team has zero living military units (unit_type != `kargar`) AND zero complete/operational military-production buildings (`produces` non-empty + `is_complete`) — "can't fight back AND can't rebuild." Chosen over zero-units-alive (misfires during ordinary army trades) and below-%-of-peak (needs history machinery). → `01_CORE_MECHANICS.md` §4.3, `DECISION_PACKET_2026-06-08.md` §1.1. Authorized 2026-06-22 by Siavoush.
- **Turan economy frame — non-mirror, ratified (Packet §1.3).** Turan's economy is tribute (*baj*) + raid + caravan (*karavan*) + tent-household (*otaq*/*khargah*), NOT mirror-clones of Iran buildings. Makes canonical the frame already operative in shipped code (mazraeh.gd / madan.gd cultural-note headers); specific mechanical shapes stay deferred to their Phase-4+ waves. Pairs with the §1.2 T&T direction — Turan's raid economy is half the asymmetry. → `00_SHAHNAMEH_RESEARCH.md`, `DECISION_PACKET_2026-06-08.md` §1.3. Authorized 2026-06-22 by Siavoush.

**Still open (NOT ruled this sitting — Tier 2-4 in the packet):** naming batch (2.1-2.4), ratify-the-defaults (3.x), housekeeping (4.x incl. the plan v2.0.0 re-baseline offer, the early-fun-gate milestone, and the DECISIONS.md backfill). None block Phase-4 core.
