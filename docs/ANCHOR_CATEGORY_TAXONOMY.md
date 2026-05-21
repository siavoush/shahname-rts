---
title: Anchor-Category Taxonomy for Building Subclasses
type: spec
status: living
version: 1.0.0
owner: shahnameh-loremaster
summary: Per-variant template-shape specification for Building anchor-categories. Iran Tier-1 5/5 + Tier-2 sub-slot taxonomy + Turan prediction notes + brief-time-review trichotomy classifier. SSOT for loremaster brief-time review classifications.
audience: all
read_when: building-cultural-review, anchor-category-classification-questions
prerequisites: [STUDIO_PROCESS.md, 00_SHAHNAMEH_RESEARCH.md, 01_CORE_MECHANICS.md]
ssot_for:
  - anchor-category template-shapes (civic-anchor, labor-organization, identity-bearing institutional, sacral-emitter / divine-source)
  - sub-slot taxonomy within each anchor-category
  - J2 brief-time-review trichotomy classifier (clone-check / slot-fit-verify / taxonomy-growth-required)
  - naming-shape-vs-anchor-shape discipline
  - Iran Tier-1 + Tier-2 building-to-variant assignments
  - Turan prediction notes (structural-mismatch hypothesis)
references: [STUDIO_PROCESS.md §9.J, 00_SHAHNAMEH_RESEARCH.md, 01_CORE_MECHANICS.md §5]
tags: [taxonomy, cultural-authenticity, building, loremaster, ssot]
created: 2026-05-21
last_updated: 2026-05-21
---

# Anchor-Category Taxonomy for Building Subclasses

## 0. What this doc is

The single source of truth for **anchor-category classifications** of `Building` subclasses in Shahnameh RTS. Consumed by loremaster brief-time cultural review (§9.J cluster) and by every agent who writes or reviews a `Building` subclass `.gd` header.

Each `Building` subclass belongs to exactly one **anchor-category** — a cultural-mechanical archetype that determines the shape of its cultural-note block, its mechanical template, and its cross-faction prediction. Anchor-categories may have **sub-slots** when the category permits specialization along a known axis (e.g., identity-bearing institutional specializes by *military-arm*).

This doc replaces the inline anchor-category table that previously lived in `STUDIO_PROCESS.md §9.J2` per §9.C1 SSOT discipline. §9.J2 retains the rule prose and now points here for the enumeration.

**When to read this:**
- Authoring or reviewing a new `Building` subclass cultural-note.
- Authoring or reviewing a kickoff brief that introduces a new building (lead dispatch).
- Brief-time cultural review (loremaster lens — J2 anchor-category match).
- Cross-faction design discussions involving Building-side mechanics.
- Sub-slot taxonomy questions for sibling buildings.

**When NOT to read this:**
- Authoring or reviewing non-Building cultural surfaces (unit states, hero abilities, narrative events, UI strings). Anchor-category is a Building-side taxonomy specifically.

---

## 1. Anchor-category variants — enumeration + template-shape

Four anchor-category variants currently enumerated for Iran-side buildings. Each variant has a **mechanical shape** (what the building mechanically does in code), a **cultural shape** (what cultural-truth the mechanic surfaces), a **canonical example** (Iran's first-shipped instance), and a **sub-slot axis** when the variant permits specialization.

### 1.1 Civic-anchor

**Persian/Shahnameh anchor.** Settled-life continuity; the household and the cultivated land as the social units that *anchor* civilization. The Shahnameh's Iran-side identity rests on settled cultivation in opposition to Turan's nomadic-steppe mobility (`00_SHAHNAMEH_RESEARCH.md §3 lines 161-165`). The civic-anchor building IS the player-mechanical surface of "the people who stay here, and the place where they stay."

**Mechanical shape.**
- Resource-producer (Mazra'eh: Grain via duck-typed `request_extract` / `complete_extract` / `release_extract` API), OR
- Pop-cap modifier (Khaneh: +N population to the empire-level cap)
- Two-stage lifecycle: Stage 1 placement (structural footprint + fog vision-source registration + `EventBus.building_placed`), Stage 2 operational flip (`is_gatherable = true` or pop-cap raised) — see `STUDIO_PROCESS.md §9.L5`
- NavigationObstacle3D presence varies by sub-slot (Khaneh-as-structure has one; Mazra'eh-as-field does not — workers walk ONTO Mazra'eh)
- BalanceData entry under `buildings.<kind>` with cost + HP + construction_ticks

**Cultural shape.**
- The mechanic *patient stewardship* (Mazra'eh's long dwell time 90 ticks @ SIM_HZ=30 vs Ma'dan's 60 ticks expresses the dehqan tradition — see `game/scripts/world/buildings/mazraeh.gd` lines 14-40)
- The mechanic *household continuity* (Khaneh raises pop-cap because the household IS the social unit that absorbs new lives)
- No oath-register; no skill-transmission-register; just "settled people, settled land, settled life."

**Canonical examples.**
- **Khaneh** (خانه, "house") — household pop-cap. Iran Tier-1.
- **Mazra'eh** (مزرعه, "cultivated field") — Grain resource-producer. Iran Tier-1.

**Sub-slot axis.** Loosely *what-the-anchor-anchors*: household (Khaneh) vs cultivated-land (Mazra'eh). Not formally axed yet; the two examples are distinct enough that further civic-anchor buildings (if any) would slot by what social unit they anchor. Not expected to grow significantly post-MVP.

**J4 triples pattern (template for cultural-note authors).**
```
"Resource flows from patient stewardship of land/people, not extraction"
  → depends on (a) extract API (Mazra'eh) or pop-cap (Khaneh) shipped [gp-sys]
  → depends on (b) BalanceData entry [balance-engineer]
  → depends on (c) construction_ticks tuned to convey patience [balance-engineer]
"Civic-anchor distinct from labor-organization / sacral / institutional"
  → depends on (d) NO oath, skill-transmission, or sacral-emit shape in code [gp-sys]
```

### 1.2 Labor-organization

**Persian/Shahnameh anchor.** Practice-of-craft transmitted across generations. Anchored in the Pishdadian-age civilizational-invention triad — Hushang (discovers fire), Tahmuras (binds divs, learns writing/weaving), Jamshid (discovers iron, founds metallurgy) — per `00_SHAHNAMEH_RESEARCH.md §1 lines 86-88`. The labor-organization building does NOT mark the moment-of-discovery; it surfaces the *inherited practice* — how organized labor at an ore body extracts more than scattered effort would, carrying techniques bequeathed by mythic-age kings.

**Mechanical shape.**
- Modifier-emitter on an existing producer (Ma'dan: extraction-efficiency multiplier on adjacent MineNode via `mine.register_extraction_modifier(self)`)
- NOT itself a resource-producer; does NOT register with `ResourceSystem.register_node`
- Stage-2 modifier-registration gating (registered on construction-complete, not placement)
- See `docs/RESOURCE_NODE_CONTRACT.md §4.7` for the modifier-emitter contract pattern

**Cultural shape.**
- The mechanic IS the *organized-labor-amplification* — Ma'dan does NOT add a new mine; it multiplies the yield of an existing one. The cultural-truth is that the *technique* of mining is what makes ore extractable at scale, not the existence of ore.
- Register is *craft-transmission*, not oath or sacral-flame or civic-stewardship.
- Cross-faction: Turan's coin economy routes through *baj* (tribute) — extraction-via-demand, NOT organized-labor-at-ore-body. Structural mismatch (Ma'dan-clone would be design-broken-by-template-inertia).

**Canonical example.**
- **Ma'dan** (معدن, "ore-source / generative place") — Coin extraction efficiency multiplier on adjacent MineNode. Iran Tier-1.

**Sub-slot axis.** Currently *type-of-craft-amplified*. Ma'dan amplifies metallurgical extraction. Future labor-organization buildings (if any) would slot by craft-type (e.g., a workshop amplifying smithing throughput, a tannery amplifying leather production). Not expected to be densely populated; the Shahnameh anchors a small set of named craft-disciplines.

**J4 triples pattern.**
```
"Building amplifies the practice, not produces the resource"
  → depends on (a) modifier-registry API on the target producer [engine-architect, gp-sys]
  → depends on (b) NO resource_kind / NO ResourceNode-shape fields [gp-sys]
  → depends on (c) Stage-2 modifier-registration gating [gp-sys]
"Cross-faction structural-mismatch — do not clone for Turan"
  → depends on (d) cultural-note caveat present + design-chat routing [loremaster, lead]
```

### 1.3 Identity-bearing institutional

**Persian/Shahnameh anchor.** The Iran-as-faction self-conception: a *standing institution* that transforms civilian role into named military arm via formal oath + trained skill. Iran's military identity (per `00_SHAHNAMEH_RESEARCH.md §3 lines 161-165 + §4 lines 187-192`) is two-layered: pahlavan-class hero-exceptionalism (Rostam, Esfandiyar) on one layer; *sepah* (سپاه) — named-but-collective institutional-ordinary forces — on the other. The institutional-ordinary layer is what identity-bearing institutional buildings produce; the pahlavan-class lives outside this category (hero progression, post-MVP).

**Mechanical shape.**
- Unit-production-queue (Phase-4 path, currently dormant)
- `is_ready_to_produce: bool` public surface flipped at Stage 2 (`_on_construction_complete`); gates queue acceptance
- NO `resource_kind`, NO `ResourceNode`-shape fields, NO modifier-registry — the building's effect is the *units it produces*, not a per-tick or per-trip resource flow
- NavigationObstacle3D present (workers route AROUND — these are structural buildings, not walkable fields)
- BalanceData entry typically *coin-only* (no grain) — the king's purse maintains the sepah-institution, not peasant levy
- Construction_ticks longer than civic-anchor buildings (e.g., Sarbaz-khaneh's 780 ticks = 26s @ SIM_HZ=30 vs Khaneh's shorter raise-time) — institutional-build is a deliberate commitment

**Cultural shape.**
- The mechanic IS the *institutional role-transformation*: civilian/untrained → named-military-arm specialist
- Register is *oath + trained-skill transmission* (sarbaz = "head-staked", one who pledges; trained Kamandar carries the Parthian-shot tradition; Savar carries Iranian noble-class cavalry tradition)
- Two-layer-military discipline: production is institutional-ordinary, NOT hero pahlavan-class

**Canonical examples.**
- **Sarbaz-khaneh** (سربازخانه, "soldier-house") — produces Piyade + Kamandar infantry. Iran Tier-1.
- **Sowari-khaneh** (سواری‌خانه, "rider-house") — produces Savar cavalry. Iran Tier-2.
- **Tirandazi** (تیراندازی, "arrow-shooting practice-place") — produces advanced Kamandar variants including Asb-savar Kamandar. Iran Tier-2.

**Sub-slot axis. *Military-arm.*** Each sub-slot specializes the institutional building by the arm it trains + the cultural register of that arm. Sub-slots currently filled:

| Sub-slot | Building | Tier | Cultural register |
|---|---|---|---|
| generic-infantry sepah | Sarbaz-khaneh | 1 | Iran's *named-but-collective* backbone — piyade-and-kamandar holding the line while pahlavans decide single combat (*mard-o-mard*, `00_SHAHNAMEH_RESEARCH.md §226-227`) |
| cavalry-tradition | Sowari-khaneh | 2 | Iranian noble-class mounted-aristocracy — heavy Savar archetype, Rostam-on-Rakhsh as the pahlavan-and-warhorse pair; institutional-ordinary Savar is the *trained-class* version |
| archery-tradition | Tirandazi | 2 | Parthian-shot tradition — TRAINED SKILL transmitted master-to-apprentice; Kamandar collective, NOT Arash-the-Archer (hero-class, outside this sub-slot) |

**Predicted future sub-slots (post-MVP).**
- **pil-khaneh / war-elephant institution** (per `00_SHAHNAMEH_RESEARCH.md §4 line 191` — Sasanian-era war elephants attested). Likely post-MVP.
- Other named arms from the Iran unit-type table that are not pahlavan-class (Atashban siege specialist, etc.) — case-by-case loremaster review at template-clone time.

**J4 triples pattern.** See `game/scripts/world/buildings/sarbaz_khaneh.gd` header for the full template. Abbreviated:
```
"Institution transforms civilian into named-military-arm via oath + trained skill"
  → depends on (a) is_ready_to_produce flag exposed for Phase-4 queue [gp-sys]
  → depends on (b) BalanceData entry, coin-only no grain [balance-engineer]
  → depends on (c) unit class produced exists at HEAD [gp-sys — first-exercise check]
  → depends on (d) Stage-2 operational flip via super-call [gp-sys, L5 seam]
"Sub-slot fills military-arm specialization, not new anchor-category"
  → depends on (e) Sarbaz-khaneh template-shape cloned faithfully [gp-sys]
  → depends on (f) NavigationObstacle3D + FogSystem registration [world-builder, gp-sys]
"Two-layer-military: institutional-ordinary, NOT hero pahlavan-class"
  → depends on (g) unit class is not hero-flagged [gp-sys VERIFY at HEAD]
  → depends on (h) production-queue cannot queue heroes from this building [DEFERRED Phase 4]
```

### 1.4 Sacral-emitter / divine-source

**Persian/Shahnameh anchor.** The continuity-of-sacred-substance that legitimizes Iranian kingship. The Shahnameh's theological-political claim: *Farr-ī Yazdān* (فرّ ایزدی, divine glory) flows through legitimate rulers and departs unjust ones (`00_SHAHNAMEH_RESEARCH.md §229-231` + §1 line 88 Jamshid's fall). Sacral-emitter buildings are the player-mechanical surface of the *sources-of-legitimacy* that sustain Farr — the sacred flame, the just judgment, the legitimate audience-court, the remembrance of fallen heroes. Their mere existence (while tended) emits the legitimizing substance.

**Mechanical shape.**
- Continuous passive emit per tick — NO worker dwell, NO trip, NO action required; the building's *existence-while-tended* IS the mechanic
- Registers with FarrSystem (or analogous emitter-system) at Stage 2 (`_on_construction_complete`) — the sacred fire is NOT "burning" until construction completes; mirrors L5 two-stage gating discipline
- BalanceData entry with emit-rate (Farr/min → ticks at SIM_HZ=30)
- Drain on destruction: explicit Farr penalty when a sacral-emitter is lost (Atashkadeh: −5 Farr per `01_CORE_MECHANICS.md §4.3`)
- Atashkadeh additionally serves as Tier-1→Tier-2 gateway prerequisite (unique to Atashkadeh among sacral-emitters)

**Cultural shape.**
- The mechanic IS the theology, not a metaphor laid over it. Farr does NOT flow because something is HARVESTED (civic-anchor) or PRODUCED (institutional) or BUFFED (labor-organization); it flows because the legitimating substance is being KEPT, continuously, the way fire-priests keep the sacred flame.
- Register varies by sub-slot: sacred-flame continuity (Atashkadeh), justice-as-Farr-source (Dadgah), sovereignty-as-Farr-source (Barghah), remembrance-as-Farr-source (Yadgar).
- Loss-of-building is a *discontinuity-of-the-sacred*, not just building-lost damage.

**Canonical example.**
- **Atashkadeh** (آتشکده, "fire-house") — +1 Farr/min continuous passive emit + Tier-1→Tier-2 gateway prerequisite + −5 Farr drain on loss. Iran Tier-1. See `game/scripts/world/buildings/atashkadeh.gd` for the canonical sacral-emitter cultural-note.

**Sub-slot axis. *Source-of-legitimacy.*** Each sub-slot specializes by *which Shahnameh source-of-legitimacy* the building surfaces. Sub-slots currently filled and predicted:

| Sub-slot | Building | Tier | Emit rate | Source-of-legitimacy |
|---|---|---|---|---|
| sacred-flame continuity | Atashkadeh | 1 | +1 Farr/min | Hushang's fire + Farr-ī Yazdān's theological anchor |
| justice-source *(predicted, Phase 4+)* | Dadgah | 2 | +0.5 Farr/min | Right judgment sustains legitimacy (Kay Khosrow as ideal just king) |
| sovereignty-source *(predicted, Phase 4+)* | Barghah | 2 | +0.5 Farr/min | Legitimate king holding audience-court IS Farr-generating |
| memorial-source *(predicted, Phase 4+)* | Yadgar | 2 | +0.25 Farr/min, only after hero-death | Remembrance-of-fallen-heroes sustains civilization's moral substance |

**Sub-variant distinctness rule.** Future sacral-emitter clones MUST explicitly frame WHICH source-of-legitimacy the sub-slot surfaces. The four sub-slots are NOT interchangeable; flame ≠ justice ≠ sovereignty ≠ remembrance. A cultural-note block that elides the distinction collapses the taxonomy into "generic Farr-building" and loses the project's load-bearing cultural-authenticity rule.

**Tier-1→Tier-2 gateway asymmetry.** Atashkadeh alone serves as the Tier-1→Tier-2 gateway prerequisite. Dadgah / Barghah / Yadgar inherit the sacral-emitter mechanical shape but do NOT gate tier-up. This asymmetry IS the Shahnameh's claim that legitimate rule must be theologically anchored *first* (sacred-flame continuity is the source-of-sources) before specializing into justice / sovereignty / memorial sustenance.

**J4 triples pattern.** See `game/scripts/world/buildings/atashkadeh.gd` header for the full template. Abbreviated:
```
"Building emits +N Farr/min CONTINUOUSLY while standing"
  → depends on (a) FarrSystem registration [engine-architect]
  → depends on (b) per-tick emit pattern [gp-sys]
  → depends on (c) Stage-2 operational flip [gp-sys, L5 seam]
  → depends on (d) BalanceData entry [balance-engineer]
"Cost-deduction wiring (coin + grain if applicable)"
  → depends on (e) UnitState_Constructing deduction path [gp-sys]
  → depends on (f) BalanceData cost entry [balance-engineer]
  → depends on (g) cross-track integration verified at first-exercise [lead's named verifier]
"Loss-of-building is sacral-discontinuity, not just damage"
  → depends on (h) HealthComponent + apply_farr_change() chokepoint wired [gp-sys]
  → depends on (i) drain magnitude per 01_CORE_MECHANICS.md §4.3 [balance-engineer]
"Sub-slot specializes source-of-legitimacy, not generic Farr-building"
  → depends on (j) cultural-note block names WHICH legitimacy-source [loremaster]
```

---

## 2. Brief-time review trichotomy (J2 refinement)

When a kickoff brief introduces a new `Building` subclass, the loremaster's brief-time review classifies the outcome as exactly one of three:

### (a) Clone-check

**The new building is a same-as-existing same-sub-slot clone.** Verify the clone is faithful to the existing template.

**Verification shape.**
- Cultural-note prose mirrors the canonical example's 4-part structure (Persian etymology + Shahnameh anchor + how-the-mechanic-surfaces-cultural-truth + cross-faction caveat + forward-compat).
- Mechanical template clones faithfully (kind StringName + dual-init + lifecycle hooks + autoload-guard + cost helper + Stage-2 flip).
- BalanceData entry follows the established economy-framing for the variant (coin-only for identity-bearing institutional; coin+grain for sacral-emitter; etc.).

**Verdict tendency.** APPROVE with minor stylistic SUGGESTs. Drift risk is low because the template is established.

**Worked examples.** No clone-check outcomes shipped yet for Iran-side (each Tier-1 building introduced a new variant; Tier-2 buildings filled predicted-empty sub-slots). The first Iran-side clone-check would be (e.g.) a hypothetical *fourth civic-anchor building* — not currently planned for MVP.

### (b) Slot-fit-verify

**The new building fills a predicted-empty sub-slot within an existing anchor-category.** Verify the slot-fit matches the prediction.

**Verification shape.**
- Anchor-category invariant holds: mechanical shape (same template) + cultural-shape register (same family of cultural-truth)
- Sub-slot axis specialization is consistent with the existing sub-slot taxonomy
- Cultural-note prose explicitly *names the sub-slot* and explains how this concrete fills it
- Any naming-shape divergence (per §4 below) is flagged as surface-language, NOT taxonomy-growth

**Verdict tendency.** SUGGEST with sub-slot-specific cultural-note prose. Drift risk is moderate — easy to accidentally collapse sub-slot distinctness into "same as the canonical example."

**Worked examples.**

*Sowari-khaneh + Tirandazi (Wave 2B, 2026-05-21).* Both classified as slot-fit-verify under identity-bearing institutional. Sub-slot axis: military-arm. Sowari-khaneh fills cavalry-tradition; Tirandazi fills archery-tradition. Anchor-shape (institutional role-transformation via oath + trained skill) invariant; sub-slot specializes the arm + cultural register. Tirandazi's *-dazi* suffix (vs Sarbaz-khaneh / Sowari-khaneh *-khaneh*) is naming-shape divergence, NOT anchor-shape divergence — see §4.

### (c) Taxonomy-growth-required

**The new building demands a new anchor-category** (or in rare cases a new sub-slot axis within an existing category). Surfaces a taxonomy gap that must be discussed before shipping.

**Verification shape.**
- Mechanical shape does NOT cleanly fit any existing anchor-category template
- Cultural-shape register is structurally distinct from existing anchor-categories
- Sub-slot extension is insufficient (the difference is at the *anchor-category* level, not the *specialization* level)
- Loremaster proposes the new anchor-category with its template-shape sketch; lead routes to design chat for ratification before specialist tracks dispatch

**Verdict tendency.** NEEDS-DESIGN-CHAT verdict. Drift risk is high — without explicit taxonomy growth, the new building inherits a wrong template-shape and the cultural-truth-claim becomes incoherent.

**Worked examples.**

*Each of the four current anchor-categories was a first-instance taxonomy-growth event in its time:*
- Khaneh / Mazra'eh established civic-anchor (early waves).
- Ma'dan established labor-organization at Wave 1B brief-time review (2026-05-15). This was the first explicit application — lead's initial framing was "civic-anchor clone"; loremaster correctly surfaced taxonomy-growth-required and proposed labor-organization with citation to `00_SHAHNAMEH_RESEARCH.md §1 lines 86-88` (Pishdadian triad).
- Sarbaz-khaneh established identity-bearing institutional at Wave 2A brief-time review (2026-05-18).
- Atashkadeh established sacral-emitter / divine-source at Wave 2A.5 brief-time review (2026-05-18).

*Expected next taxonomy-growth: Turan-side first building.* The leading hypothesis (per §6 below) is that Turan's social organization demands at least one structurally-distinct anchor-category (mobile-war-camp emitter? otaq-cluster aggregator? sworn-bond-to-khan accumulator?). Turan's first building should default-fire taxonomy-growth-required at brief-time.

### Decision flow

```
Brief introduces new Building subclass
    │
    ├─ Same anchor-category + same sub-slot as an existing building?  ──── YES ──► (a) clone-check
    │                                                                              verify faithful clone
    │
    ├─ Same anchor-category + predicted-empty sub-slot?                ──── YES ──► (b) slot-fit-verify
    │                                                                              verify slot-fit per prediction
    │
    └─ Mechanical shape OR cultural register structurally distinct?    ──── YES ──► (c) taxonomy-growth-required
                                                                                   NEEDS-DESIGN-CHAT
```

**J2 trichotomy graduation status.** N=2 as of Wave 2B (2026-05-21). Sowari-khaneh + Tirandazi were the inaugural slot-fit-verify applications. N=3 graduation expected at Phase-4 first sacral-emitter sub-variant brief-time (Dadgah or Barghah). Until N=3, the trichotomy is documented here but its codification in `STUDIO_PROCESS.md §9.J2` remains as "watchlist refinement awaiting graduation."

---

## 3. Naming-shape vs anchor-shape discipline

**Locked at Wave 2B Track 0 brief-time review (2026-05-21).**

Persian morphology marks cultural register through a variety of compound suffixes. These suffixes encode meaningful cultural distinctions in the language but do NOT determine the anchor-category of the building. **Naming-shape is one input to brief-time anchor-category classification, but mechanical + cultural-load criteria are the decisive inputs.**

**Persian morphological forms encountered or anticipated:**

| Suffix | Persian | Literal | Examples |
|---|---|---|---|
| *-khaneh* | خانه | house / hall | Sarbaz-khaneh, Sowari-khaneh |
| *-kadeh* | کده | place / dwelling | Atashkadeh, dehkadeh, meykadeh |
| *-gah* | گاه | place-where-X-happens | Dadgah, jangah (battlefield) |
| *-dazi* | دازی | practice / discipline-of-X | Tirandazi |
| *-gar* | گر | doer / practitioner | (potential future building) |
| *-zar* | زار | place-of-X (often plant/material) | (potential future building) |
| (no suffix — independent noun) | — | — | Mazra'eh, Ma'dan, Barghah, Yadgar |

**The rule.** The suffix tells the player something *culturally true* — Persian-speakers carry the register cue intuitively. But that register cue does NOT cleanly map to our anchor-category axis. Three concrete examples:

1. **Sarbaz-khaneh vs Tirandazi** — different suffixes (*-khaneh* "house" vs *-dazi* "practice"), SAME anchor-category (identity-bearing institutional). The difference is cultural register (the *building* IS the institution vs the *practice* IS the institution-and-the-building-hosts-it), NOT structural anchor-shape.
2. **Atashkadeh vs Dadgah (predicted)** — different suffixes (*-kadeh* "dwelling" vs *-gah* "place-where-X-happens"), SAME anchor-category (sacral-emitter), DIFFERENT sub-slot (sacred-flame vs justice-source). Suffix difference correlates with sub-slot difference but does not determine it.
3. **Mazra'eh vs Ma'dan** — both independent nouns without compound suffix, DIFFERENT anchor-categories (civic-anchor vs labor-organization). Naming-shape provides no signal here at all; the anchor-category is decided entirely by mechanical + cultural-load criteria.

**How to use this discipline at brief-time review:**

1. **Surface the suffix in the cultural-note header.** If the building's name uses a morphological form, explain what the suffix encodes culturally — register, practice-vs-place, source-of-legitimacy nuance — in the etymology sub-block.
2. **Do NOT use the suffix as anchor-category signal.** When classifying the anchor-category (J2 lens), reason from mechanical shape + cultural-truth-the-mechanic-surfaces, NOT from suffix-pattern-matching.
3. **If the suffix diverges from sibling buildings in the same anchor-category, flag the divergence as surface-language explicitly in the cultural-note prose.** This prevents future readers from mistaking surface-language divergence for structural divergence at template-clone time. Tirandazi's header (per Wave 2B Track 1.5) explicitly does this.

**Why this discipline exists.** At Wave 2B Track 0, the question arose: "Tirandazi is *-dazi* (practice) not *-khaneh* (house); does that mean it's a different anchor-shape from Sarbaz-khaneh / Sowari-khaneh?" Answer: no. The suffix encodes a real cultural register difference (archery as TRAINED SKILL transmission emphasizes the practice; cavalry/infantry as INSTITUTIONAL ROLE emphasizes the place). But the mechanical shape (footprint + production-queue + Stage-2 gating + Tier-2 prereqs) is identical, and the anchor-shape (institution that transforms civilian into named military arm) is identical. Surface-language divergence within same-anchor-category sub-slots is *expected* and *culturally meaningful*; it does not signal taxonomy growth.

---

## 4. Iran building assignments

All Iran-side `Building` subclasses currently shipped or predicted, with their anchor-category + sub-slot + Wave shipping reference + cultural-note citation.

### 4.1 Tier 1 (5/5 shipped, complete)

| Building | Persian | Anchor-category | Sub-slot | Wave | Cultural-note source |
|---|---|---|---|---|---|
| Khaneh | خانه | Civic-anchor | household-anchor | Pre-Phase-3 / wave 1A scaffolding | `game/scripts/world/buildings/khaneh.gd` |
| Mazra'eh | مزرعه | Civic-anchor | cultivated-land-anchor | Wave 1A | `game/scripts/world/buildings/mazraeh.gd` lines 14-52 |
| Ma'dan | معدن | Labor-organization | metallurgical-craft amplifier | Wave 1B | `game/scripts/world/buildings/madan.gd` lines 21-82 |
| Sarbaz-khaneh | سربازخانه | Identity-bearing institutional | generic-infantry sepah | Wave 2A | `game/scripts/world/buildings/sarbaz_khaneh.gd` lines 25-104 |
| Atashkadeh | آتشکده | Sacral-emitter / divine-source | sacred-flame continuity | Wave 2A.5 | `game/scripts/world/buildings/atashkadeh.gd` header |

**Tier-1 closure observation.** Iran Tier-1 5/5 shipped 4-for-4 in their predicted anchor-categories without retrofit. This validates the taxonomy's predictive power at the easy case (Iran-side, settled-faction). The harder case is Turan (see §6).

### 4.2 Tier 2 (2/5 currently being shipped by Wave 2B)

| Building | Persian | Anchor-category | Sub-slot | Wave | Cultural-note source |
|---|---|---|---|---|---|
| Qal'eh | قلعه | (gateway/tier-up — anchor-category TBD) | — | Wave 2C / Phase 4 | not yet authored |
| Sowari-khaneh | سواری‌خانه | Identity-bearing institutional | cavalry-tradition | Wave 2B (in-flight) | `game/scripts/world/buildings/sowari_khaneh.gd` (pending Track 1.5) |
| Tirandazi | تیراندازی | Identity-bearing institutional | archery-tradition | Wave 2B (in-flight) | `game/scripts/world/buildings/tirandazi.gd` (pending Track 1.5) |
| Barghah | بارگاه | Sacral-emitter / divine-source | sovereignty-source *(predicted)* | Phase 4+ | not yet authored |
| Yadgar | یادگار | Sacral-emitter / divine-source | memorial-source *(predicted)* | Phase 4+ | not yet authored |

**Qal'eh open question.** Qal'eh's anchor-category is not yet locked. The mechanical role (Tier-1→Tier-2 conversion of the Throne building per `01_CORE_MECHANICS.md §5 line 193`) is a *tier-gateway* mechanic distinct from the four enumerated anchor-categories. May demand a fifth anchor-category (something like *sovereignty-gateway* or *tier-transformation*) OR may sit outside the anchor-category taxonomy entirely (it's a conversion of an existing building, not a new building-instance). Loremaster brief-time review at Wave 2C will resolve.

**Dadgah is Tier-1 in spec but ships Phase-4.** Per `01_CORE_MECHANICS.md §5 line 187`, Dadgah is listed under Tier-1 buildings, but Phase 3 scope only ships Khaneh + Mazra'eh + Ma'dan + Sarbaz-khaneh + Atashkadeh as Tier-1. Dadgah is deferred to Phase 4. When it ships, it will be the first Phase-4 sacral-emitter sub-variant and an expected J2 trichotomy N=3 graduation candidate.

---

## 5. Turan prediction notes (structural-mismatch hypothesis)

**Status:** all predictions below are loremaster leading hypotheses pending design-chat ratification. Turan economy is currently flagged in `QUESTIONS_FOR_DESIGN.md` (Turan-economy entry) as pending.

### 5.1 The structural-mismatch claim

The Shahnameh's Iran-Turan asymmetry is NOT cosmetic. Iran is *settled, agrarian, kingly*; Turan is *nomadic-steppe, mobile, raid-based* (per `00_SHAHNAMEH_RESEARCH.md §3 lines 161-165`). This is a structural difference in *what social organization looks like* — and that difference flows up into the building-mechanics layer.

**The hypothesis:** Turan's economy and military do NOT route through fixed-building infrastructure at all (or do so to a much smaller degree). Turan's analogues to Iran's buildings are *not building-clones* but structurally different shapes:

| Iran building | Turan analogue (leading hypothesis) | Structural mismatch |
|---|---|---|
| Mazra'eh (Grain via cultivation) | *karavan* (کاروان) — mobile caravan unit traveling between hubs with Grain payloads | Iran's grain comes from settled cultivation; Turan's comes from trade-route mobility. **Mazra'eh-as-fixed-resource-node is structurally wrong for Turan.** |
| Ma'dan (Coin via organized labor at ore body) | *baj* (باج) — tribute extraction from subject peoples + raid-spoils | Iran's coin comes from organized-labor-on-ore; Turan's comes from extraction-by-demand. **Ma'dan-as-modifier-emitter is structurally wrong for Turan.** |
| Sarbaz-khaneh / Sowari-khaneh / Tirandazi (institutional military training) | *otaq*-cluster (otaq = mobile-tent-household) + sworn-warrior-to-khan loyalty bond | Iran's military identity lives in institutional buildings; Turan's lives in the loyalty bond between named ruler (Afrasiyab, Piran) and named warrior. **Identity-bearing institutional clone is structurally wrong for Turan.** |
| Atashkadeh / Dadgah / Barghah / Yadgar (sacral-emitter Farr-source) | Khan-loyalty + steppe-mobile sworn-bond rituals (if any equivalent) | Iran's legitimacy is theological-fixed (Farr-ī Yazdān in sacred-flame continuity); Turan's is relational-mobile (sworn bond, named rulership). **Sacral-emitter clone is structurally wrong for Turan.** |

### 5.2 What this means for taxonomy growth

When Turan first-building ships (post-MVP), brief-time review should default-fire **(c) taxonomy-growth-required**. The expected outcomes:

- At least one new anchor-category for Turan-side mobile-emitter mechanics (working name: *mobile-emitter* or *traveling-aggregator*).
- Possible second new anchor-category for sworn-bond / relational legitimacy (working name: *relational-legitimacy* or *loyalty-aggregator*).
- The four existing anchor-categories may continue to exist as *Iran-specific* (sub-typing by faction-applicability becomes a useful axis).

**Cross-faction caveat shape (loremaster discipline).** Every cultural-note for an Iran building should include a *cross-faction caveat* sub-block stating the structural-mismatch hypothesis for the Turan analogue. The caveat is singular (NOT a three-option list) and explicit ("Do not clone X as a Turan building"). Examples already in shipped headers:
- `mazraeh.gd` lines 42-52 (karavan)
- `madan.gd` lines 60-82 (baj)
- `sarbaz_khaneh.gd` lines 64-80 (otaq-cluster + sworn-warrior)
- `atashkadeh.gd` header (khan-loyalty + steppe-mobile sworn-bond)
- `sowari_khaneh.gd` (pending Track 1.5; otaq + sworn-warrior shape)
- `tirandazi.gd` (pending Track 1.5; steppe-horse-archer daily-practice shape)

### 5.3 Re-examine at Turan kickoff

This section is a *prediction artifact*. When Turan economy ships and the first Turan building enters brief-time review, this section is the starting hypothesis the loremaster validates or refines. The taxonomy will evolve based on what Turan-side mechanics actually demand.

Cite Manifesto Principle 10 (Feedback Cycle — specifications are hypotheses; the taxonomy is one). The current doc is v1.0.0 of the taxonomy. v2.0.0 is expected when Turan kicks off.

---

## 6. Active rules cross-reference

The discipline rules that consume this doc live in `STUDIO_PROCESS.md §9.J`:

- **§9.J1 — Brief-time review formalization.** When loremaster brief-time review fires (first-instance template / template-variant) vs when it doesn't (sibling clone).
- **§9.J2 — Anchor-category enumeration for Building subclasses.** The rule prose. The enumeration itself is here — §9.J2 should point to this doc per SSOT discipline (handled by lead at Track 6 wave-close).
- **§9.J3 — Literal-then-tricky-gloss discipline.** Persian-term pattern for cultural-note prose. Watchlist with baggage-intensity annotations (N=2 graduation pending).
- **§9.J4 — Intent-vs-implementation split — claim → mechanism → reviewer triples.** Cultural-note J4 triples format. Each anchor-category in §1 above includes an abbreviated J4 triples pattern; full templates live in the canonical-example `.gd` headers.

The discipline that produces this doc lives in:

- **§9.J1** decides *whether* loremaster brief-time review fires.
- **§9.J2 + this doc** decide *how* the anchor-category classification works.
- **§9.J3** decides *how Persian terminology is framed* in the cultural-note prose.
- **§9.J4** decides *how mechanical-dependency claims are surfaced* in the cultural-note prose.

The discipline that consumes this doc:

- **Loremaster brief-time dispatch** — read §1 for variant template-shapes; read §2 for trichotomy classification; read §3 for naming-shape vs anchor-shape; read §4 for sibling-building cross-reference; read §5 for Turan cross-faction caveat shape.
- **Lead kickoff brief authoring** — read §4 for which anchor-category sub-slot to dispatch the loremaster against; read §5 for Turan-side scoping cautions.
- **Any agent writing a `Building` subclass cultural-note** — read §1 for the canonical-example reference; read §3 for naming-shape vs anchor-shape discipline; read §5 for cross-faction caveat shape.

---

## 7. Version history

- **v1.0.0** (2026-05-21) — Initial ratification. Iran Tier-1 5/5 + Tier-2 2/5 in-flight assignments locked. J2 trichotomy + naming-shape-vs-anchor-shape discipline + Turan prediction notes consolidated from prior Building `.gd` headers and `STUDIO_PROCESS.md §9.J2`. Per Wave 2B Track 5 dispatch.

**Next version triggers:**
- Tier-2 closure (Qal'eh + Barghah + Yadgar ship + anchor-category locked) → v1.1.0 likely PATCH-MINOR depending on whether Qal'eh demands a fifth category.
- Phase-4 Dadgah brief-time → J2 trichotomy N=3 graduation candidate; if it graduates, this doc moves from "watchlist refinement awaiting" to "ratified active rule" cross-reference. PATCH bump likely.
- Turan first-building kickoff → v2.0.0 MAJOR; structural-mismatch hypothesis becomes empirical artifact.

---

*Skynda långsamt. The taxonomy grows as the project grows; it does not grow ahead of the project.*
