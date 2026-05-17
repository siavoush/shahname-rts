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
last_updated: 2026-05-14
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


## 2026-05-17 — Dedicated navmesh-carve investigation wave: scope + timing

**Context:** Phase 3 session 3 wave 1C shipped construction-timer + UI progress bar + Ma'dan-over-mine placement validity cleanly. The wave's navmesh sub-track (originally a 2-track time-budget per WAVE_1C_NAVMESH_SPIKE.md) hit 4 rounds of diagnostic + implementation without producing a working carve. Lead decided 2026-05-17 to PUNT the navmesh problem to its own dedicated wave with proper time budget — wave 1C closes cleanly without it, with workers-walk-through-buildings documented as L25-still-open in ARCHITECTURE.md §7.

**Question:** When should the dedicated navmesh-investigation wave land in `02_IMPLEMENTATION_PLAN.md`? Three positions plausible:

(a) **Insert as wave 1D / 1.5 before wave 2A** — block military production (Sarbaz-khaneh, units, combat) until pathing-around-buildings works. Cleanest from a "movement gameplay should be correct before combat ships" perspective, but delays the dopamine-loop completion.

(b) **Run in parallel with wave 2A** — engine-architect-p3s2 dedicated to navmesh investigation (their persistent context inherits the 4-round diagnostic), while world-builder + gp-sys + ui-developer continue Sarbaz-khaneh + unit production on wave 2A. Risk: navmesh wave might still be open at Phase 4 boundary.

(c) **Defer to Phase 4 with Path B (NavigationAgent3D + RVO migration) as the planned scope** — accept walk-through for the remaining Phase 3 waves; commit to the multi-week Path B as part of Phase 4's broader engine work. Removes the "is this a 1-line fix or a multi-week fix?" uncertainty.

**Diagnostic carry-forward (inherited by the dedicated wave):**
- `docs/WAVE_1C_NAVMESH_SPIKE.md` v0.2.0 (post-Phase-2C close) contains the 4-round mechanism-correction archaeology.
- `docs/ARCHITECTURE.md` §7 L25 entry contains empirical findings (waypoint signature, nav map state, qa-engineer's probe data).
- Currently shipped scene-config + code-path are forward-investment (dual-flag + manual rebake + ROOT_NODE_CHILDREN parser-scope); the dedicated wave inherits this as starting state, not as a rollback obligation.

**Why this routes to design chat:** Implementation Plan ownership lives in the design chat per CLAUDE.md. Lead has scoping intuition but the priority ordering of "must-have-before-X" lives in design.

**Blocking scope:**
- NOT blocking for session 3 close — wave 1C closes with navmesh as known-issue.
- Possibly blocking for wave 2A (Sarbaz-khaneh + unit production) IF combat-positioning becomes a near-term design requirement.

**Suggested decision shape (lead's framing, not design directive):**
- Option (b) — parallel — preserves session momentum on military/combat while the navmesh wave runs.
- Option (c) — defer to Phase 4 with Path B — is the most honest scoping if the team's bandwidth and the design's tolerance for walk-through together support it.
- Option (a) — block 2A — is over-cautious unless combat positioning is imminent.


## 2026-05-17 — Turan economy shape: tribute + raid + caravan, NOT mirror-buildings

**Context:** Phase 3 session 2 waves 1A + 1B shipped Mazra'eh + Ma'dan with cross-faction caveats that lock leading-hypotheses for Turan's equivalents: *karavan* (کاروان, mobile caravan unit — wave 1A Mazra'eh's cross-faction caveat per loremaster-p3s2 brief-time review) and *baj* (باج, tribute-collection — wave 1B Ma'dan's cross-faction caveat per loremaster-p3s2 brief-time review + lead's 2026-05-15 ratification). Both shipped cultural-note blocks state explicitly: "Do not clone [Mazra'eh/Ma'dan] as a Turan building." Two waves of independent loremaster framing converge on the same architectural-frame: **Turan's economy ships through tribute + raid-acquisition + caravan-trade, NOT through mirror-buildings-of-Iran.**

**Question:** Ratify the Turan-economy-as-non-mirror architectural framing before Phase 4 Turan-buildings dispatch? Specifically:

(a) **Coin** — collected via *baj* (tribute) from subject / contested territory + raided from defeated Iranian armies. **NO Turan-side mine-building.** A Turan-side "Ma'dan-clone" would have no MineNode to multiply (Turan plausibly doesn't build mines either in the leading-hypothesis economy) — design-broken-by-template-inertia.

(b) **Grain** — acquired via *karavan* (mobile caravan units that travel between hubs carrying Grain payloads, vulnerable to interception). **NO Turan-side farm-building.** Caravans CAN carry tribute payments too — the two mechanisms (caravan-trade + baj-tribute) share mechanical surface.

(c) **Population housing** — *otaq* / *khargah* (tent-household). Different lifecycle from Iran's Khaneh — possibly mobile / relocatable / capacity-tied-to-herds. This is QUESTIONS_FOR_DESIGN.md's existing 2026-05-14 entry on Turan housing analogue, which now interacts with this broader Turan-economy question.

(d) **Military** — produced in mobile war-camps or via Khan's-loyalty / sworn-warrior mechanic, NOT a Sarbaz-khaneh-equivalent. Reserve detailed framing pending Sarbaz-khaneh's wave-2A close-review (the *first* identity-bearing institutional variant ships Iran-side; Turan's distinct shape becomes clearer after that anchor).

**Blocking scope:**
- NOT blocking for session 3 (Sarbaz-khaneh wave 2A ships Iran-side per spec; doesn't touch Turan).
- PARTIALLY blocking for Phase 4+ Turan economy waves: needs ratified framing before Turan-coin / Turan-grain / Turan-population dispatches.

**Loremaster's evidence base (per loremaster-p3s2 brief-time + close-review across wave 1A + 1B):**
- `00_SHAHNAMEH_RESEARCH.md §natural-core` — Turan as nomadic-steppe culture (livestock + tribute economy historically; metal economy via raid + tribute, never extraction).
- `00_SHAHNAMEH_RESEARCH.md §worthy-rivals` — design Turan as worthy rivals, not cartoon villains. Each faction's economy reflects its social organization; copy/paste produces hollow design.
- Two waves of cross-faction caveat language in shipped scripts (`game/scripts/world/buildings/mazraeh.gd` header + `game/scripts/world/buildings/madan.gd` header).
- Historical record: Xiongnu, Scythian, Hephthalite tribute systems all routed coin-equivalent revenue through tribute + raid + caravan, never through owned extraction sites.

**Why this is more than a single design question:** two waves of cultural review have already presupposed the framing in shipped code. The strings.csv + cultural-note blocks for Mazra'eh and Ma'dan both contain "Do not clone as Turan building" language. The architectural frame is *already operative* in the cross-faction caveats — design-chat ratification just makes it explicit + canonical, and prevents a future Phase-4 implementer from cloning Iran-side templates against the established convention. Cites Manifesto Principle 1 (Truth-Seeking — make the operative framing explicit) and Principle 7 (SSOT — the architectural frame lives in one canonical place).

**Suggested decision shape (loremaster's brief-time framing, not design directive):**
- Ratify the non-mirror architectural frame as a working hypothesis for Phase 4 dispatch.
- Defer specific mechanical shape (mobile caravan unit type? tribute as continuous-trickle or event-based? raid as primary or secondary?) to Phase 4 sync — the right time to design Turan's mechanics is in concert with Phase 4's Tier 2 + Kaveh Event + Farr-emitter waves, not as standalone decisions.
- Update strings.csv + future contract docs with the ratified frame as a referenced precedent.


## 2026-05-14 — UI primary-name convention: Persian word vs English gloss

**Context:** Phase 3 session 1 wave-close shahnameh-loremaster review. The spec (`01_CORE_MECHANICS.md` §5) names buildings as "Khaneh (house)", "Mazra'eh (farm)", "Sarbaz-khaneh (barracks)" — Persian word as primary, English as gloss. The existing strings.csv has both patterns: `UNIT_KARGAR,Kargar,` (Persian-primary, correct) and originally `BLDG_KHANEH,House,` (English-primary, anachronistic — fixed in commit `f0e79ce` to `BLDG_KHANEH,Khaneh,` per the loremaster's strong recommendation).

**Question:** Should the canonical en-side label for buildings (and other named-in-Persian gameplay surfaces) be the **Persian word** (e.g. "Khaneh", "Mazra'eh", "Sarbaz-khaneh") or the **English gloss** (e.g. "House", "Farm", "Barracks")? Make the rule explicit so session-2's build-menu extensions inherit one consistent convention.

**Options considered:**
- **Persian-primary** (what we just landed for Khaneh + Kargar). Teaches the player one Persian word per element. Matches the Persian-rooted-not-flavored stance from `MANIFESTO.md` + `00_SHAHNAMEH_RESEARCH.md` §7. Pairs naturally with an optional tooltip key (`UI_BUILDING_KHANEH_TOOLTIP`) carrying the English semantic in hover-text.
- **English-primary with Persian tooltip.** Easier first-impression for non-Persian speakers; loses the daily-vocabulary-teaching opportunity.
- **Mixed by element type.** E.g., units always Persian (Kargar), buildings always English (House). Hardest to justify; what the loremaster called "the worst-of-both."

**Blocking:** Partially. Session 2's wave 1 (Mazra'eh / Ma'dan / Sarbaz-khaneh / Atashkadeh build-menu extensions) needs a ruling here — they'll inherit whatever pattern lands.

---

## 2026-05-14 — Coin or Sekkeh? Resource name in en-side

**Context:** Phase 3 session 1 wave-close shahnameh-loremaster review. The spec (`01_CORE_MECHANICS.md` §3 line 103) names the resource "Coin (سکه, *sekkeh*)" — English "Coin" with the Persian root *sekkeh* in the spec. `Constants.KIND_COIN = &"coin"` matches. The Persian word *sekkeh* / *drahm* / *derham* is Kayanian/Sasanian-era authentic.

**Question:** Should the en-side stay "Coin" (current — spec-canonical and the loremaster's recommendation) or flip to "Sekkeh" to match the building / unit Persian-primary convention? Pair this ruling with Q1 above (UI primary-name convention) so both are answered together.

**Options considered:**
- **Keep "Coin"** (loremaster recommendation). Generic-enough English word that doesn't dilute setting; spec-canonical. `fa` column lands سکه at Tier 2.
- **"Sekkeh"** to match Persian-primary convention if Q1 chooses that path. Internally consistent at the cost of a slightly higher first-impression friction for non-Persian speakers.

**Blocking:** No. Session 1's `Coin` strings already shipped; either ruling is a one-line strings.csv edit when it lands.

---

## 2026-05-14 — Turan housing analogue: what's it called, when does it ship?

**Context:** Phase 3 session 1 wave-close shahnameh-loremaster review. Phase 3 is Iran-only per spec §1 (Turan is AI with simplified economy in MVP). The Building abstract base shipped in wave 1C is faction-neutral (place_at + _on_placement_complete hook works for any side). Khaneh — Iran's settled-household pop-cap building — is its first concrete subclass. The cultural-rationale header in `khaneh.gd` IS Iran-coded (settled life, dynastic builders Jamshid/Fereydun). When Turan housing ships it MUST carry parallel substantive cultural-rationale per `00_SHAHNAMEH_RESEARCH.md` §7 "worthy rivals" rule.

**Question:**
(a) What's the Turan housing equivalent called? Loremaster's candidates: ***Otag*** (Turkic-origin word for tent, attested in Persian sources) or ***Khargah*** (large royal tent, Shahnameh-attested for steppe encampments).
(b) Does the `Building` base class need a `cultural_idiom` field (Iran="settled", Turan="nomadic") before session-2 starts adding more Iran-only buildings that may bake in settled-only assumptions?
(c) Same Q for Mazra'eh — Turan's equivalent isn't "farm" (different gather-loop topology: grazing / animal husbandry, not soil-tied agriculture). Cultural framing for the Turan analogue should be settled NOW so session-2's Mazra'eh ships with the same shape.

**Options considered:**
- **Defer entirely** — Turan AI uses simplified economy in MVP per spec §1; never ships a parallel housing building. Cheapest path.
- **Otag for housing, Cherahgah ("grazing-ground") for Mazra'eh-analogue** — Turkic-rooted, dignified, parallels Iran's Khaneh + Mazra'eh shape.
- **Khargah for housing** — more royal-connotation; reserve for a Phase 4+ Turan-Court building, not a baseline pop-cap building.

**Blocking:** No for session 1; partially blocking for Phase 4 if MVP expands Turan's economy past "simplified AI." Worth answering before session 2 adds more Iran-only buildings whose abstraction surfaces bake in settled-only assumptions.

---

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
