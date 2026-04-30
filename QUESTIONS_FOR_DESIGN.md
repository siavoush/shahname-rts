---
title: Questions for Design Chat
type: log
status: append-only
owner: team
summary: Upward channel from Claude Code (implementation) to the design chat. Open questions that affect gameplay/feel/balance/narrative and exceed implementation authority. Resolved questions move to the archive section.
audience: all
read_when: every-session
prerequisites: []
ssot_for:
  - open design questions awaiting design-chat resolution
  - resolved design questions (archive)
references: [01_CORE_MECHANICS.md, DECISIONS.md]
tags: [log, questions, design-chat, escalations]
created: 2026-04-23
last_updated: 2026-05-01
---

# Questions for Design

This file is the upward channel from Claude Code (implementation) to the design chat (Siavoush + design Cowork session).

When a Claude Code session hits a question it cannot resolve from the specs — and the question affects gameplay, feel, balance, or narrative — it appends an entry here and continues with other unblocked work. Siavoush brings the file to the design chat, decisions get made, the relevant spec doc gets updated, and the question is removed from this file (or struck through and archived at the bottom).

## Format for new entries

```
## YYYY-MM-DD — short question title

**Context:** what you were building when this came up, which doc/section it relates to.
**Question:** the actual question, phrased so a fresh reader can answer it cold.
**Options considered (optional):** if you've thought through alternatives, list them — saves the design chat time.
**Blocking:** yes / no / partially. (If yes, you stopped working on this; if no, you noted it and continued.)
```

Keep entries terse. Long questions fragment the design chat's attention.

## Open questions


## 2026-04-30 — Do depleted mine ruins stay permanently or can they be cleared?

**Context:** `MineNode` depletion design in `docs/RESOURCE_NODE_SCHEMA.md` §3.2. Depleted mines keep their `NavigationObstacle3D` active — they remain physical blockers on the map. This is a map-control and late-game question.

**Question:** Can workers later clear depleted mine ruins (removing the obstacle, reclaiming the cell for building placement), or do ruins stay permanently for the match?

**Options considered:**
- **Permanent ruins:** Simpler. Depleted areas become semi-impassable terrain features. Encourages early mine contest.
- **Clearable ruins:** Workers spend time/resources to clear. Creates late-game expansion decisions. Adds a new worker command.

**Blocking:** No. Ruins are permanent for MVP implementation. This only matters if clearable ruins ship — it would require a contract revision and a new worker state.

---

## 2026-04-30 — Auto-retarget policy when a worker's gather node depletes

**Context:** `docs/RESOURCE_NODE_SCHEMA.md` §9. When a worker's coin mine depletes mid-loop, what does the worker do next? This is a quality-of-life decision that affects how much micro-management the player must do.

**Question:** When a Kargar worker's mine node returns `NODE_DEPLETED`, should the worker (a) auto-target the nearest other mine of the same resource, (b) auto-target the nearest mine of any resource, (c) return to the Throne and idle, or (d) something else?

**Options considered:**
- **(a) Nearest same-resource:** Standard RTS QoL. AoE2 default. Workers keep gathering coin without re-tasking.
- **(b) Nearest any-resource:** Simpler logic, but may grab grain when player wanted coin.
- **(c) Idle at Throne:** Forces player attention, more "manageable" feel but more clicks.
- **(d) Idle at depletion site:** Lazy — preserves player intent without auto-decisions.

**Blocking:** No. MVP implements (c) — idle at Throne — as the safest default. Easy to swap to (a) once design confirms.

---

## 2026-04-30 — Snowball protection: "3:1 army ratio" and "broken economy" definitions

**Context:** `01_CORE_MECHANICS.md` §4.3 specifies snowball-protection Farr drains: "Killing a unit when your army outnumbers theirs by 3:1 or more: −0.5 Farr per kill" and "Destroying enemy economy (workers, mines) when their military is broken: −1 Farr per worker." Both terms need precise definitions for implementation.

**Question:** What exactly counts as (a) "3:1 army ratio" — by unit count, by population cost, or by combat power? And (b) "broken economy / military broken" — what threshold defines a broken state (no production buildings? no workers? no military units? all three?)?

**Options considered:**
- **(a) Unit count:** Simplest. 30 spearmen vs. 10 archers = 3:1 even if archers cost more.
- **(a) Population cost:** Accounts for unit-class differences. 30 piyade (30 pop) vs. 10 cavalry (20 pop) = 3:2, not 3:1.
- **(a) Combat power:** Most accurate but requires a per-unit "power index" — opens new tuning surface.
- **(b) Military broken:** thresholds could be "no military units alive" OR "no military production buildings" OR "less than 10% of recent peak army strength."

**Blocking:** Yes for Phase 4 (FarrSystem full implementation). Surfaced in original studio review and again in Sync 4.

---

## Resolved (archive)

### 2026-04-30 — Grain: worker-gathered (RESOLVED)
**Resolution:** Workers gather grain. Path 2 in `docs/RESOURCE_NODE_SCHEMA.md` §1.4 is the chosen path. **Reasoning (Siavoush, design chat):** Workers are foundational to the RTS concept — every major franchise (AoE, SC2, C&C) has gathering workers. Stripping that for grain breaks the gameplay archetype. Note: the Div faction may have alternate economic mechanics — see open research item below; for Iran and Turan, workers gather all resources. Spec `01_CORE_MECHANICS.md` §3/§5 to be clarified by design chat. Resource Node Schema contract requires Path 2 patch (surgical per §1.4).
