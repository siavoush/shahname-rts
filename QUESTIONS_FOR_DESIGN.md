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
last_updated: 2026-05-28 (Session 9 close retro — late-game economic pressure gap flagged + 3-voice convergence on T&T thesis commitment)
---

# Questions for Design

## 2026-06-22 — D1b "kicking-them-while-down" drain: double-drain with the base worker-killed drain, and the killer-attribution gate

**Context:** Phase 4 wave 1 wired the §4.3 snowball-injustice drains (DECISIONS.md 2026-06-22 §1.1). D1b (`snowball_economy_when_broken`, −1.0) fires when "a worker dies AND the victim's team is military-broken." The base worker-killed drain (`worker_killed_idle` −1.0 / `worker_killed_during_gather` −0.5) ALSO fires on the same worker death (it hooks `unit_health_zero`). A worker killed on a military-broken team would therefore drain Farr TWICE for one death (e.g. idle worker on a broken team = −1.0 base + −1.0 D1b = −2.0).

**Implementation choice made (simplest spec-faithful, documented in `farr_drain_dispatcher.gd`):** D1b now requires a **resolvable enemy killer** (mirrors D1a's Fix-F1 killer-attribution gate) — it bails when `killer_unit_id == -1` (attrition / Farr-drain / scripted death) or on friendly-fire. So the double-drain only happens when an **identified enemy** kills a worker on a broken team — which is exactly the "kicking them while down" injustice §4.3 describes. Deaths with no attacker drain only the base worker amount. This also keeps every existing worker-drain integration test green (they kill with a `null` attacker → D1b bails).

**Questions for design:**
1. **Is the double-drain intended?** When an enemy kills a worker on a military-broken team, is −2.0 Farr (base worker-loss + economy-when-broken) the desired total, or should D1b REPLACE the base drain (so it's −1.0 either way, just attributed differently)?
2. **Should D1b require that the team HAD military that was destroyed**, versus merely being in a zero-military state now? A brand-new economy that never built military is technically "military-broken" by the state predicate (§1.1b), but isn't "down" in the narrative sense (no one broke it). The current implementation uses the state predicate as written + the killer-attribution gate.

**Options considered for (1):**
- **(a) Additive (current):** −2.0. The two drains encode distinct injustices (you killed a worker AND you did it while they were defenseless). Highest anti-snowball pressure.
- **(b) Replace:** D1b suppresses the base worker drain → −1.0 total, logged as `snowball_economy_when_broken`. Avoids double-jeopardy; same magnitude, clearer attribution.
- **(c) D1b is strictly heavier:** the base worker drain is suppressed and D1b is tuned to a larger value (e.g. −1.5) to represent the compounded injustice in one number.

**Blocking:** No. MVP ships (a) additive with the killer-attribution + friendly-fire gates (matches the brief's literal D1b wording + the F1 attribution principle). Trivial to switch to (b)/(c) once design confirms — it's a guard in `_maybe_drain_economy_when_broken`.

---

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

> **2026-06-08 — DECISION PACKET AVAILABLE.** All open entries below (plus the 5 codex-lane questions, the plan-§10 index, and 4 housekeeping requests) are consolidated into **`DECISION_PACKET_2026-06-08.md`** at repo root — each with options, implementation-side recommendation, and cost-of-delay, ordered so one design-chat sitting (~1h) clears the whole backlog. Read the packet instead of the raw entries; the entries below remain the canonical full-context record.

## 2026-06-12 — View-only enemy selection? (input-layer P1 hotfix follow-on)

**Context:** The P1 input-layer hotfix (live playtest 2026-06-11; branch `fix/input-layer-playtest-bugs`) enforced player-team-only selection at the SelectionManager seam. The live bug was that an enemy unit could be *selected and then commanded* — the player right-clicked near their own worker and the game issued an attack order TO the enemy, which killed the player's worker. The fix makes enemy units non-selectable.

**Question:** Single-clicking an enemy unit now does **nothing** (it deselects, matching click-on-terrain). The genre convention (StarCraft 2, Age of Empires 2) is **view-only** enemy selection: clicking an enemy shows its stats in the unit panel (HP, type, abilities) without making it commandable. Do we want view-only enemy selection as a Phase-5 UI item?

**Options considered:**
- **(a) Keep current (no-op/deselect):** Simplest. No enemy info surfaced; player relies on health bars + visual read. Matches the hotfix as shipped.
- **(b) View-only enemy selection (SC2/AoE2 convention):** Left-click an enemy → unit panel shows its stats, ring drawn in a distinct "enemy" color, but right-click commands still apply to the player's *prior* selection (the enemy is never the commanded actor). Requires a "view target" concept in SelectionManager/SelectedUnitPanel distinct from the "command set."
- **(c) Hybrid:** view-only on a modifier (e.g. Alt+click) to keep plain click as deselect.

**Blocking:** No. The hotfix ships option (a). View-only is a pure UX enhancement; it does NOT reintroduce the P1 bug as long as the "view target" is kept separate from the commandable selection set.

## 2026-05-28 — Late-game economic pressure gap (balance-engineer flag, session 9 close retro)

**Context:** Wave 3-BuildingDestructibility (PR #42) closed the last structural blocker for an end-to-end match loop. Combined with the §9 retro convergence across gp-sys + balance-engineer that *"AI-vs-AI unattended runs is the most important balance tool we don't have yet,"* the next-question surfaces: when AI-vs-AI runs land, what will the match-pacing data actually show?

**The gap (balance-engineer-p3s3 retro reflection 2026-05-28):**

> *"The economy curve has no late-game pressure. Coin and grain accumulate indefinitely — no population ceiling pressure on resource consumption, no upkeep cost on units, no research cost. A player or AI that reaches mid-game in stable resource state has unlimited coin/grain and no reason to force engagement. The 'economic tension → forced engagement' loop that drives RTS pacing doesn't exist yet."*

**Why it matters now (not at Phase 4 only):**

- The "15-25 minute match" target from `01_CORE_MECHANICS.md §0` cannot be validated by AI-vs-AI data until the pacing-pressure loop exists. AI-vs-AI runs in Phase 3 will produce match-duration distributions that may misrepresent Phase 4 pacing — AI accumulates indefinitely rather than being forced to engage.
- The 3-voice convergence on Trade & Transport (loremaster + balance-engineer + user) lands precisely here: **upkeep is the missing pressure mechanism**, AND per loremaster's research, upkeep-as-royal-largesse (down-flow, royal duty) is BOTH the culturally-correct framing AND the structurally-correct pacing fix. Same lever, two angles.

**Design-chat questions:**

1. **Commit to Trade & Transport for Phase 4+ entry?** Loremaster verdict (2026-05-28): SHIP T&T. Cultural-fidelity gain + positioning gain outweigh implementation cost + design-iteration cost. The cultural-authenticity-as-load-bearing rule is the project's stated philosophy; SC2-with-Shahnameh-skin would be the moment shipped reality diverges from stated philosophy. Concrete proposal: ship T&T with **upkeep-as-royal-largesse framing** (not upkeep-as-tax).

2. **Bizhan-Manizheh as canonical caravan-mechanic anchor.** Rostam-disguised-as-caravan-master infiltrating Turan is the mechanic-meets-narrative beat that lets "the mechanic IS the theology" framing extend into Phase 4+. The caravan is both economic primitive AND literary form (cover-for-rescue; bridge-between-kingdoms; site-of-vulnerability-AND-craft).

3. **AI-vs-AI batch infrastructure as Wave 3-Sim (pre-Phase 4 prerequisite).** Joint task: balance-engineer specs result format (match duration, first-engagement tick, army size ratios, end-state resources); engine-architect implements headless batch runner; qa-engineer owns batch script. Wave 3-BD shipped the last structural blocker; the runner is the next missing infrastructure piece.

4. **Royal-largesse design surface (from prior 2026-05-24 entry, still open).** Refinement 2 from `docs/SHAHNAMEH_ECONOMY_RESEARCH.md`: royal largesse / down-flow is canonical and MISSING from current project framing. Where does it land — building-flavored (treasury), event-flavored (largesse-dispensing during festivals), or unit-flavored (royal-gift effects on unit production)?

**Cross-references:**
- `docs/SHAHNAMEH_ECONOMY_RESEARCH.md` (loremaster side-quest, 2026-05-24).
- §9.J5 watchlist (session 9 close retro codification of the side-quest dispatch pattern).
- balance-engineer-p3s3 retro reflection (2026-05-28).

**Status:** Open for design-chat. Lead awaits direction on whether Phase 4+ entry commits to T&T (with upkeep-as-royal-largesse framing) OR ships standard SC2-economy with explicit deferral of T&T to Phase 5+ pending market signal.

---

## 2026-05-24 — Shahnameh economy cross-check — two refinements + one needs-expert-input flag

**Context:** Loremaster cross-checked the Trade & Transport economic thesis (see entry below) against the Shahnameh + pre-Islamic Iran historical record. Output is `docs/SHAHNAMEH_ECONOMY_RESEARCH.md` v1.0.0 (451 lines, shipped at commit `07261a4`).

**Top-line:** thesis holds. "Wealth-flow IS the contest" is *more* culturally honest for a Shahnameh RTS than SC2-model is — pre-Islamic Iran's structural reality WAS tribute/tax administrative flows + frontier raiding. Positioning bet is sound.

**Two material refinements for Phase 4+ design chat to weigh:**

1. **Reframe upkeep as royal-largesse / down-flow, NOT cost+deficit.** Shahnameh battles are champion-combat-decisive, NOT supply-line-decisive. Caravan-attackable mechanic (Q3) IS canonical at frontier-raiding level — safe. But "armies degrade from upkeep-failure" overstates the epic. Reframe as "the just king sustains his sepah from the treasury (royal duty + down-flow as righteous rule)." Same mechanic, different cultural-framing; honors historical reality without claiming epic-narrative-decisiveness it doesn't have.

2. **Royal largesse / down-flow is canonical and MISSING from current project framing.** Kings dispensing treasure to heroes, soldiers, subjects is HALF the Shahnameh's economic-political picture. Just-king-as-generous-distributor is a load-bearing moral axis. Surfaces in future mechanic prose; not a structural change yet.

**One needs-expert-input flag:**

3. **The "dehqan-Throne reciprocity" framing the project has been saturating toward (Mazra'eh / Throne / Wave 3-LocalDropoffs addenda) is partially anachronistic.** The *dehqan* as institutional category is most strongly Sasanian-and-later; Kayanian-heroic-age content predates the technical institution by centuries. Ferdowsi himself reads it backward into the heroic age (his own dehqan-stock identity is the lens). Following his practice is defensible, but the project should ACKNOWLEDGE the compression at the discipline-doc layer rather than presenting it as Kayanian-era institutional fact.

   **Loremaster's recommendation:** one-paragraph clarification in `00_SHAHNAMEH_RESEARCH.md`. Existing cultural-notes (throne.gd, mazraeh.gd, madan.gd) **do not need editing** — they ship as-is.

   **Confidence-level:** loremaster explicitly flags Q6.3 (this dehqan-chronological-compression finding) as **LOWER confidence than the rest of the doc.** They are NOT an Iranist specialist on this specific question. Needs expert sanity-check before any `00_SHAHNAMEH_RESEARCH.md` edit lands. If a Shahnameh-khani scholar or Iranist consults and disagrees, the finding should be revised.

**Three framing-shifts (not refinements, just worth knowing):**

- **Bidirectional raiding is canonical.** Iran also raids Turan (Manuchehr, Kay Khosrow, Rostam, Esfandiyar). When raid mechanic ships, both factions should be capable; differ in cultural prose (Iran-as-retribution vs Turan-as-opportunism), not in mechanic.
- **Bizhan-Manizheh = canonical caravan-mechanic anchor.** Rostam disguises as a caravan-master to infiltrate Turan and rescue Bizhan. Validates caravans-with-armed-retinue as canonical-feeling game objects + provides a Phase 4+ campaign-mission anchor.
- **Turan's structural-mismatch hypothesis needs case-by-case evaluation per anchor-category** — Throne is the canonical NEAR-SYMMETRY exception (per ANCHOR_CATEGORY_TAXONOMY v1.1.0 §5). Future Turan-side building work should not assume all-structural-mismatch.

**What this question is asking:** review the research, decide which refinements to absorb at Phase 4+ kickoff time, and **specifically: route Q6.3 (dehqan-compression flag) to an Iranist-specialist if available** (Shahnameh-khani scholar, academic Iranist, anyone with deeper expertise on Achaemenid → Parthian → Sasanian institutional history). The fix prose at `00_SHAHNAMEH_RESEARCH.md` can wait until the expert-input lands.

**Blocking:** No. Wave 3-LocalDropoffs (current PR #41) is unaffected; addenda ship as queued. This question lives in the design-chat queue for Phase 4+ Trade & Transport kickoff time.

**Defer to:** Phase 4+ Trade & Transport wave kickoff brief, OR earlier if user has Iranist-specialist contact who can sanity-check Q6.3.


## 2026-05-24 — Trade & Transport economy — wealth-flow as the central contest (thesis-level positioning)

**Context:** Surfaced by Siavoush during Wave-3-Throne live-test (2026-05-24). The Throne wave shipped IDropoffTarget routing where workers deposit at the Throne. User immediately surfaced the natural follow-on: this design makes distant-mine expansion economically painful (workers walk great distances back to the Throne). Standard RTS fixes for this are well-known (AoE2 secondary drop-offs, StarCraft expansion bases, C&C mobile refineries). User then sketched a fundamentally bigger idea — make the wealth-flow itself a visible, attackable game surface. After back-and-forth refinement, the shape is now coherent enough to capture for the design chat.

**This is a thesis-level question, not a feature-level question.** The decision changes what kind of RTS this is.

---

### The thesis

Not "add a trade mechanic." A positioning shift:

| Axis | SC2 / AoE2 model | Proposed model |
|---|---|---|
| Economy's role | **Serves the army.** Build economy → build army → attack base. | **Is the contest.** Army shapes the flow; battles are intersection points. |
| Army's role | Decisive force. Battles end the game. | **Tool of economic disruption + protection.** Wealth-strangulation is a path to victory. |
| Win condition | Destroy base / dominate map | Destroy Throne **OR** collapse opponent's wealth-flow until they can't sustain |
| What you optimize | APM + build order | Route design + escort allocation + raid timing |
| Map chokepoints matter for | Armies | Trade AND armies (often different chokepoints) |

The market has plenty of "SC2 with a fresh skin." It does not have "raid-economy RTS where the wealth-flow IS the contest." That's a niche-but-loyal audience (AoE4-strategic, Manor Lords, Cossacks fans, Crusader Kings players curious about RTS).

---

### Core mechanics (the proposed system)

**1. Workers deposit at LOCAL stores, not the Throne.**
- Mazra'eh = grain depot. Ma'dan = coin depot. Workers route to nearest available depot of right kind.
- This is the foundation — solves the immediate "distant expansion is painful" problem AND is the foundation for everything below.
- **Cultural fit:** the dehqan's stewardship culminates in delivery to a *local* store (grain in the village granary, ore at the mine head). The local store is where wealth *accumulates* before tribute moves it up.

**2. Caravans transport local-store stockpiles to the Throne.**
- Local store fills → caravan launches automatically.
- Caravan is a **visible, attackable unit** on the map between depot and Throne.
- Loss of caravan = wealth never arrives. Capture is the raid mechanic.
- **Cultural fit:** *baj* / tax-flow-to-the-king made literally visible. The dehqan-Throne reciprocity that throne.gd's cultural-note already invokes becomes the actual gameplay loop.

**3. Escort automation solves the APM problem.**
- Player **assigns standing guards** to a transport route (not per-trip micromanagement).
- Unguarded route = easy raid target. Guarded route = better protected.
- Strategic decision: "5 Piyade on the south route OR in the frontline army?" — *meaningful* choice, not click-spam.

**4. Settlements + armies demand upkeep (Civilization-borrowed, era-accurate).**
- Historically grounded: Achaemenid satrap-tribute system, Sasanian army provisioning chains.
- Bigger army → more upkeep → more dependent on flow → more raidable.
- Settlements without grain delivery weaken or lose function.
- Creates a feedback loop: economic power and military power are not independent variables.

---

### Faction asymmetry as logical consequence (not bolted-on)

The economic system **structurally produces** the Shahnameh's lived dynamic:

| | Iran | Turan |
|---|---|---|
| Identity | Settled, agricultural, dehqan-tribute-to-takht | Nomadic, raid-economy, oath-of-loyalty-to-named-rulers |
| Output | Higher wealth-generation | Lower production, cheaper military |
| Posture | Structurally defensive (wealth + infrastructure to protect) | Structurally aggressive (cheap to launch raids, little to defend) |
| Hero role | Rostam = line-holder, raid-breaker, asymmetry-tilter | Turanian champions = raid leaders, route-cutters |
| Win path | Throne destruction OR economic strangulation (defensive variant) | Economic strangulation (preferred) OR Throne destruction |
| Special bonus | (TBD) Tribute-collection efficiency, settlement defense bonuses | (TBD) Faster intercepts, loot-conversion bonuses, no static-settlement upkeep |

**The asymmetry is emergent from one ruleset**, not from giving each side a different ruleset. That's the Manifesto-principled shape (Principle 6 — *systems over features*).

---

### What this implies for the rest of the project

This is the part that makes it thesis-level, not feature-level:

- **Rostam's role changes.** No longer "biggest stat-stick on the map." He becomes the line-holder, the raid-breaker, the asymmetry-tilter. Different hero design.
- **Turan AI bar goes up significantly.** Needs raid-planning, route-cutting, retreat-with-loot intent. Today's DummyAI (probe-attack toward nearest visible target) is nowhere near this. **Phase 6+ AI work becomes much larger.**
- **Maps become core design, not flavor.** Trade routes must exist; chokepoints-for-trade differ from chokepoints-for-armies; frontier zones; route geometry. Map design = design.
- **UI surfaces opponent's economy state.** Wealth meters; route status; raid alerts. "Economic collapse" win condition needs to be legible to both players.
- **Tutorial shape changes.** Players coming from SC2 need retraining: "don't just expand and attack — protect your routes, raid theirs."
- **Time-to-mastery goes up.** Higher ceiling, better retention, harder adoption. Trade-off.

---

### Comparable games (lessons-learned scan)

- **Cossacks 3** — closest parallel. Peasants → local depot → merchant wagons → capital. Wagons attackable. Steppe factions raid. Worth playing if not already.
- **Anno series** — best UX template. Ships visible, raidable, route-defined; auto-routing default, manual intervention on alerts. The "auto by default + alert intervention" pattern is the APM mitigator.
- **Total War (Medieval / Three Kingdoms)** — trade-route raids on the strategic map. Less direct because trade is abstracted, but the "trade as attack surface" idea is the same.
- **Settlers series** — caution case. Beautiful caravan logistics but the supply-chain micro overwhelmed strategic decisions; lost mass appeal. Lesson: keep the strategic layer central; don't drown players in supply-chain detail.

---

### Risks (named)

1. **APM burden.** Cossacks fans love micro-routing; mass audiences bounce. **Mitigation:** auto-routing default + escort-allocation as the strategic interface.
2. **Defender's dilemma.** Iran defends caravan + frontline + base; Turan attacks anywhere. **Mitigation:** Iran's wealth advantage absorbs raid losses; Turan's cheap army means raids cost little to launch. The asymmetry IS the design — but balance needs careful tuning.
3. **Pathing complexity.** Long-distance auto-routing across contested territory + threat detection + escort coordination is real engineering work.
4. **AI bar.** Turan raider intent (pick caravans, intercept at chokepoints, retreat with loot, weigh raid-vs-frontline) is much higher than today's DummyAI. Phase 6+ planning.
5. **Audience fit.** Alienates pure-SC2 fans; opens to currently-underserved strategic-RTS audience. Positioning bet, not a feature bet.

---

### Staging proposal

| Phase | Scope | Cost |
|---|---|---|
| **Now (post-MVP-validation playtest)** | Option 1 only — Mazra'eh = grain drop-off, Ma'dan = coin drop-off. Workers route to nearest available depot. ~1 wave. Doesn't preclude the bigger vision; **foundation** for it. | ~1 wave |
| **MVP-validation playtest gate** | Confirm the boxes-loop is fun with local drop-offs working. If yes, queue the Trade & Transport system. If no, the bigger system won't save it. | — |
| **Phase 4 (post-MVP)** | Trade & Transport major feature. Local stores accumulate; caravans auto-route to Throne; caravans are visible attackable units; settlement upkeep introduced. | ~6-10 sessions |
| **Phase 5+** | Turan raider AI; alert/interception UI; caravan auto-routing polish; full asymmetry tuning; map design pass for trade-chokepoint geometry. | ~10-15 sessions |

The "ship Option 1 now" decision is **non-throwaway** for the bigger vision — local stores must exist either way. So Option 1 is safe to commit to even before the thesis-level decision is made.

---

### What design chat is being asked to decide

Two distinct questions:

**Q1 (small, near-term):** Approve Option 1 — ship Mazra'eh-as-grain-drop-off + Ma'dan-as-coin-drop-off in a near-term wave (post-current-PR-merge). Solves the immediate distant-expansion friction. Estimated 1 wave.

**Q2 (large, positioning-level):** Commit to the Trade & Transport thesis for Phase 4+? This re-anchors Phase 4-8 around wealth-flow as the central mechanic, with cascading implications for AI, maps, UI, tutorial, hero design, and audience targeting. Estimated impact across the remaining MVP and post-MVP scope.

**Lead's recommendation:** Q1 = yes, do it now (Option 1 is non-throwaway foundation). Q2 = open a dedicated design-chat thread before MVP-validation playtest ends, so the next major-direction decision is queued when the time comes. Don't decide Q2 in passing; it's worth deliberate thinking.

**Cultural-fit assessment (lead):** Q2 is the *right thesis* for a Shahnameh adaptation specifically. The epic isn't a pitched-battle story; it's a contested-civilization story (raid-economy + sworn-loyalty vs farr-tribute). Making wealth-flow the central mechanic IS the Shahnameh adaptation. Making it pitched battles is just SC2-with-skin. But the commitment is bigger than the casual framing suggests; deserves the deliberate thinking.

**Pre-decision required for current PR:** none. PR #39 (Throne wave) ships as-is; Option 1 lands in a follow-on wave; Q2 stays open until design-chat time allows.

---

## 2026-05-24 — Resource economy expansion: mining ≠ coin direct path? Wood / stone / iron?

**Context:** Surfaced by Siavoush during Wave 3B live-test (2026-05-24). Current Phase 3 economy is intentionally simple — two resources (Coin from mines, Grain from farms). The "mine → coin directly" shortcut is RTS-idiomatic but feels anachronistic for the Kayanian / Heroic Age setting: a mine yielding "coins" skips the refining + minting + tribute chain that's culturally load-bearing in Iran's economy of that period.

**Question:** Should we expand the resource economy with intermediate refining stages and additional raw materials?

**Specific shapes considered:**

1. **Iron-ore → smelted iron → equipment (or coin via taxation):** Iron mined raw, refined at a Foundry/Forge, output gates military unit production (iron is the bottleneck on Tier 2+ units rather than just coin). Could thematically map to the dehqan-craftsperson-state value chain.
2. **Wood from forests:** Construction material for buildings + arrows for Kamandar/Tirandazi. Currently buildings cost coin+grain abstractly; wood would give construction physical-material grounding.
3. **Stone from quarries:** Tier-2 building material (Fortress / Atashkadeh-tier buildings cost stone; Tier-1 cost wood). Forces tech-up to feel like material upgrade.
4. **Coin via tribute / taxation / trade routes** instead of mining: more historically grounded — coinage emerges from concentrated authority (Throne), not from holes in the ground.

**Strategic implications for design chat:**

- **Economy depth vs scope creep.** Adding 2+ resources expands the gather loop, the build cost matrix, and the AI's economy state. Phase 4 already covers production queue + tech tiers; Phase 6+ would absorb the AI complexity.
- **Cultural authenticity vs RTS-idiomatic familiarity.** Players know SC2/AoE2 mineral+gas / wood+gold+stone+food patterns. The Shahnameh setting wants its own shape but shouldn't be alien.
- **Refining-chain pedagogy.** A Foundry that turns iron ore into smelted iron lets the game *teach* the historical refining mechanic — same shape as Ma'dan teaching about mining culture.
- **MVP risk.** Phases 3-8 are scoped for two resources. Expanding now adds 4-6 weeks. Better to defer to Tier 2 vertical slice (post-MVP) once the loop is proven.

**Lead's framing:** strongly recommend treating this as **post-MVP / Tier 2** scope. The current 2-resource economy is enough to prove the gameplay loop. Resource expansion is a natural Tier 2 enhancement that brings cultural authenticity once the foundation works. Phases 9+ candidate.

**Pre-decision required:** none for Phase 3-8. This question only blocks Tier 2 planning.

**Defer to:** post-Phase-8 playtest signal. If the 2-resource economy feels thin in playtest, Tier 2 picks this up. If it feels fine, the question can stay deferred.

---

## 2026-05-17 — Builder worker position during construction: inside vs outside footprint

**Context:** Phase 3 session 4 wave 2A live-test surfaced that the builder worker stands AT the target_position (building's center) and dwells there during construction. The building gets placed at that position, so visually the worker is INSIDE the building's footprint until construction completes. This has been the behavior for all four shipped Tier-1 buildings (Khaneh, Mazra'eh, Ma'dan, Sarbaz-khaneh) — only visually obvious with Sarbaz-khaneh's larger 3.0×2.0 footprint vs the 2.0×2.0 of others. Wave-1D's navmesh-carve correctly excludes the building's footprint from the navmesh, but the worker already-standing-inside isn't auto-evicted (the carve affects future path queries, not existing positions).

**Question:** Should the builder worker stand **inside** the building during construction (SC2 shape) or **outside the footprint at construction-edge** (AoE2 shape)?

**Strategic implications (Siavoush's framing, 2026-05-17 live-test):** This isn't an implementation detail — the choice has real gameplay consequence:

- **AoE2 shape (outside footprint):** worker visibly stands beside the building, exposed to enemy harassment. **Builder harassment becomes a viable tactic** — opposing armies can target unprotected builders mid-construction, forcing the player to garrison builders or defend with units. The economy-vs-military tension extends into construction itself.
- **SC2 shape (inside footprint):** worker is visually "inside" the construction site, NOT exposed to direct attack. Builder harassment in the AoE2 sense isn't possible; instead, you target the building itself (which the worker is constructing). The harassment vector moves from worker→building.

The two shapes produce **different early-game pacing** and **different defensive-vs-offensive economy doctrines**. AoE2 → keep eyes on every builder, scout-harass aggression rewarded. SC2 → economy is more "fire-and-forget" once builders dispatched, focus shifts to tech-rush vs army-tempo.

**Options considered:**
- **(a) AoE2 shape — outside footprint, exposed builder.** Worker stops at `target_position` offset by `building.footprint_half_extent + 0.5m`. Implementation: small edit to UnitState_Constructing's arrival logic. Combat: harassment-worker-targeting becomes part of the meta.
- **(b) SC2 shape — inside footprint, protected builder.** Current behavior. Worker is "in the construction zone," not targetable as a separate entity during construction. Combat: building-targeting is the only harassment vector.
- **(c) Hybrid — different per building category.** E.g., resource-producing buildings use AoE2 (workers stay at the site), institutional buildings use SC2 (multiple workers go inside). More complex, but could map to the anchor-category taxonomy.

**Blocking:** Not for Phase 3. Defer to Phase 4-5 when combat + harassment-meta design solidifies. The current behavior (option b, SC2 shape) is the no-decision default; revisiting requires explicit design choice. The Shahnameh frame (pahlavan/sepah two-layer split — hero exceptionalism + institutional ordinary) may inform: if hero-vs-sepah dynamics are the centerpiece, builder harassment might dilute the focus; if economy-pressure is central to the loop, builder harassment adds depth.

**Suggested decision shape:** ratify when combat + Phase 4 harassment doctrines are designed. The implementation cost is trivial in either direction; the design call is about what kind of RTS this wants to be.


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
