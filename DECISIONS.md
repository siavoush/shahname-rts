---
title: Project Decisions Log
type: log
status: append-only
owner: design-chat
summary: Chronological log of every committed design decision. One line per entry, append-only.
audience: all
read_when: every-session
prerequisites: []
ssot_for:
  - committed design decisions (chronological)
references: [00_SHAHNAMEH_RESEARCH.md, 01_CORE_MECHANICS.md]
tags: [decisions, history, design-chat]
created: 2026-04-22
last_updated: 2026-06-22
---

# Project Decisions Log

One line per committed design decision. Append-only — never rewrite history. Each entry: date, the decision, and the doc that owns the rationale.

This file is maintained by the **design chat** (the Cowork chat with Siavoush). Claude Code sessions read it but do not write to it. To propose a new decision, raise it in the design chat.

---

## 2026-04-22

- Project source pivoted from Dune to Ferdowsi's Shahnameh. Dune research archived. Reason: deep personal/cultural connection, public domain source. → `00_SHAHNAMEH_RESEARCH.md`, `project_shahnameh_rts_decisions` (memory)
- Engine: **Godot 4** with GDScript. MIT license, text-file-native, ideal for Claude Code workflow. Ruled out Unreal (heavy C++); Unity is upgrade path only if 3D performance hits a wall later. → `00_SHAHNAMEH_RESEARCH.md`
- Setting era: **Kayanian / Heroic Age** (Iran vs. Turan two-faction structure). Earlier Pishdadian and later Sasanian eras out of scope. → `00_SHAHNAMEH_RESEARCH.md`
- Source canon: Ferdowsi original. English: Dick Davis translation. Persian: Khaleghi-Motlagh critical edition. → `00_SHAHNAMEH_RESEARCH.md`
- Match structure: **faction-locked**, SC2/C&C-style, with 2–3 internal tech tiers per faction. NOT AoE-style age progression (the era arc happens at *campaign* level, not within a match). → `01_CORE_MECHANICS.md`
- Farr implementation: **civilization-level meter** with stable HUD readout. NOT hero-attached. Ruler-action-driven, with the Kaveh Event as the consequence of Farr collapse. → `01_CORE_MECHANICS.md` §4
- Three-resource asymmetry plan: Iran=Farr, Turan=Zur, Divs=Shar. Phased rollout — MVP implements Farr only. → `01_CORE_MECHANICS.md`
- MVP scope: Iran playable, Turan as AI (no Zur), Rostam as only hero, 2 tech tiers, 1 map, single-player skirmish. Pahlavan duels and Persian-language UI deferred to Tier 2. → `01_CORE_MECHANICS.md` §1
- MVP heroes: **Rostam** for Iran, **Piran Viseh** for Turan when added. Afrasiyab and Garsivaz available as later additions. → `01_CORE_MECHANICS.md` §7
- Cultural authenticity rules: standard transliteration only (Rostam not Rustam); Turan portrayed as worthy rivals not cartoon villains; cartoon evil reserved for divs and Zahhak; Zoroastrian imagery handled with respect; English UI first but all strings externalized so Persian addition (Tier 2) is cheap. → `00_SHAHNAMEH_RESEARCH.md`
- Visual direction: stylized, Persian miniature aesthetic. 2.5D isometric vs. stylized 3D decided at prototype stage. NOT photorealism. → `00_SHAHNAMEH_RESEARCH.md`

## 2026-04-23

- **Workflow split locked**: this Cowork chat is design/PM only. Implementation happens in separate Claude Code sessions. Design chat owns `00_*.md`, `01_*.md`, `DECISIONS.md`; Claude Code owns `game/`. Bidirectional handoff via `QUESTIONS_FOR_DESIGN.md` (Claude Code → design chat) and `BUILD_LOG.md` (Claude Code → design chat). → `CLAUDE.md`, `project_shahnameh_rts_workflow` (memory)
- Project folder structure: design docs at `<project_root>/`, Godot project at `<project_root>/game/`. → `CLAUDE.md`
- **Prototype graphics policy**: placeholder shapes only (colored rectangles for buildings, colored triangles for units, text labels for IDs, plain text HUD). No real art until the MVP loop is *fun* as boxes. Free to use Kenney.nl CC0 placeholders or Claude-generated SVG icons if pure shapes start to grate. → `CLAUDE.md`

## 2026-05-01

- **Godot version pinned**: Godot 4 stable line. Specific patch version recorded in `project.godot` and `docs/ARCHITECTURE.md` build-state table at the moment of project initialization (Phase 0). Any future major-version bump (e.g., 4 → 5, or breaking 4.x → 4.y change) is itself a design decision that lands here. Day-to-day patch updates (4.x.0 → 4.x.1) do not require new entries. → `02_IMPLEMENTATION_PLAN.md` Phase 0, `02a_PHASE_0_KICKOFF.md`. Authorized inline 2026-05-01 by Siavoush during the Phase 0 kickoff session.

## 2026-06-22

- **Economy direction — Trade & Transport / royal-largesse, staged (Decision Packet §1.2, Option 2).** Wealth-flow IS the contest (local stores, raidable caravans, escort, upkeep reframed as royal largesse), with emergent Iran/Turan asymmetry — ratified as the committed economy direction. **Staging:** Phase-4 *core* (full FarrSystem + tech tiers + production queues) ships first WITH a minimal royal-largesse upkeep trickle (balance-engineer-sized) as standing late-game pressure; the full caravan/local-store/escort build is gated on the post-core fun-gate playtest. Forward-compat seams (Mazra'eh/Ma'dan `_local_stock_x100`) become committed paths. → `docs/SHAHNAMEH_ECONOMY_RESEARCH.md`, `DECISION_PACKET_2026-06-08.md` §1.2. Authorized 2026-06-22 by Siavoush in the implementation session.
- **Snowball-protection — "3:1 army advantage" = population cost (Packet §1.1a, Option 2).** The Farr snowball drain triggers when `attacker_team_pop >= 3 × defender_team_pop`, summing each living unit's `population_cost` (balance.tres) over the team. Chosen over unit-count (gameable) and combat-power-index (new tuning surface). → `01_CORE_MECHANICS.md` §4.3, `DECISION_PACKET_2026-06-08.md` §1.1. Authorized 2026-06-22 by Siavoush.
- **Snowball-protection — "military is broken" = no military units alive AND no operational military-production buildings (Packet §1.1b, Option 2).** The "destroy-their-economy-when-they're-down" drain fires only when a team has zero living military units AND zero complete/operational military-production buildings ("can't fight back AND can't rebuild"). Chosen over zero-units-alive (misfires mid-trade) and below-%-of-peak (needs history tracking). → `01_CORE_MECHANICS.md` §4.3, `DECISION_PACKET_2026-06-08.md` §1.1. Authorized 2026-06-22 by Siavoush.
- **Turan economy frame — non-mirror, ratified (Packet §1.3).** Turan's economy is tribute (*baj*) + raid + caravan (*karavan*) + tent-household (*otaq*/*khargah*), NOT mirror-clones of Iran buildings. Makes canonical the frame already operative in shipped code (mazraeh.gd / madan.gd cultural-note headers); mechanical shapes stay deferred to their Phase-4+ waves. → `00_SHAHNAMEH_RESEARCH.md`, `DECISION_PACKET_2026-06-08.md` §1.3. Authorized 2026-06-22 by Siavoush.

---

*Format reminder: when adding a new entry, keep it to one or two sentences. The doc the decision points to carries the depth; this log is just the index.*
