---
title: Phase 3 Session 6 — Wave 2B Tier-2 Entry Kickoff
type: plan
status: draft
version: 1.0.0
owner: team-lead
summary: Wave 2B kickoff — Sowari-khaneh (cavalry stable) + Tirandazi (archery range) as Iran Tier-2 entry. First-exercise of dormant `BuildingStats.tier` schema field (H3 dogfood). Two clones of Sarbaz-khaneh's identity-bearing institutional anchor-category, with cavalry-tradition + archery-tradition cultural specializations. Loremaster brief-time review fires per J1 (Tirandazi naming-shape divergence is the trigger).
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, 01_CORE_MECHANICS.md, ARCHITECTURE.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, 01_CORE_MECHANICS.md, 00_SHAHNAMEH_RESEARCH.md, game/scripts/world/buildings/sarbaz_khaneh.gd, game/data/sub_resources/building_stats.gd]
ssot_for:
  - Wave 2B scope + per-track deliverables
  - Brief-time application of H3 + L6 + J4 (first dogfood of session-5 close rules)
  - Loremaster brief-time review prompt (anchor-category classification + Tirandazi naming-shape)
tags: [phase-3, session-6, wave-2b, tier-2, kickoff, H3-dogfood]
created: 2026-05-21
last_updated: 2026-05-21
---

# Phase 3 Session 6 — Wave 2B Tier-2 Entry Kickoff

## 0. Why this doc exists

Wave 2B ships **Sowari-khaneh** (سواری‌خانه, cavalry stable) + **Tirandazi** (تیراندازی, archery range) — the first two Iran Tier-2 buildings. Both produce specialized military: Sowari-khaneh → Savar (cavalry); Tirandazi → advanced Kamandar variants (canonically Asb-savar Kamandar / horse archer, the Parthian-shot tradition).

**This is the first wave under the H3/L6/J4 disciplines codified at session-5 close.** The kickoff brief is structured to apply those rules at brief-time — first dogfood opportunity. The Sarbaz-khaneh header (Wave 2A `8314a8a`) already predicted both buildings as inheritors of the identity-bearing institutional anchor-category (lines 82-104 of `game/scripts/world/buildings/sarbaz_khaneh.gd`) — that prediction gets validated or refined at brief-time loremaster review.

## 1. Reading order (≈10 minutes — same context as last session for persistent agents)

1. **`MANIFESTO.md`** — foundational principles (if your persistent context has rotated)
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: §9.D (Commit + Workspace), §9.G (Channel discipline), §9.M (Test discipline)
   - gp-sys + balance-engineer: §9.H (Cross-Cutting Verification — **especially H3 NEW**), §9.L (Implementation Patterns — **especially L4a/L4b + L5 + L6 NEW**)
   - loremaster: §9.J (Cultural / Loremaster Discipline — **especially J4 REFINED at session-5**)
   - world-builder + ui-developer: §9.F4 (Pitfall #15 regression test mandatory)
3. **`docs/ARCHITECTURE.md` §6 v0.27.0** — session-5 close retro entry covering H3 + L6 + J4 changes
4. **`docs/ARCHITECTURE.md` §6 v0.26.0** — Wave 2A.5 Atashkadeh close (Iran Tier-1 5/5 complete; sacral-emitter anchor; Tier-1→Tier-2 gateway STRUCTURALLY established but mechanical wiring deferred)
5. **`01_CORE_MECHANICS.md` §5** (lines 189-200) — Tier-2 building list spec + cost + prereqs
6. **`01_CORE_MECHANICS.md` §6** (lines 203-222) — Iran units (Savar, Asb-savar Kamandar = production targets)
7. **`game/scripts/world/buildings/sarbaz_khaneh.gd`** — your template (sibling anchor-category)
8. **`game/data/sub_resources/building_stats.gd`** — schema you'll extend with the `tier` field (H3 dogfood)
9. **`00_SHAHNAMEH_RESEARCH.md`** (only if working loremaster track) — §3 lines 161-165 (two-layer Iran military) + §4 lines 187-191 (Parthian-shot tradition) + cavalry references

## 2. Wave shape — dispatch mode SEQUENTIAL-SHARED-TREE (per §9.E1)

Wave 2B touches `balance.tres` (cross-cutting writes for two new BalanceData entries + BuildingStats schema extension) and `main.tscn` (no — wait, build menu is in `build_menu.tscn`/`.gd` only; main.tscn untouched). The shared surfaces are:
- `game/data/balance.tres` — two new SubResource entries + schema field add
- `game/data/sub_resources/building_stats.gd` — `tier` field added (one shipper, then read by all subsequent buildings)
- `game/scripts/units/states/unit_state_constructing.gd` — `_BUILDING_SCENE_PATHS` dictionary gains two new entries
- `game/scenes/ui/build_menu.tscn` + `build_menu.gd` — two new buttons + layout extension
- `game/translations/strings.csv` + `.translation` regen

Per §9.E1 boundary, **sequential-shared-tree is the right mode** (multiple buildings touching shared files; parallel-worktrees would race on balance.tres + UnitState_Constructing). Track-N owns sequencing.

## 3. Brief-time application of session-5 disciplines (DOGFOOD)

### 3.1 H3 first-exercise-of-dormant-schema call-out (§9.H3 NEW)

Wave 2B introduces **one new BuildingStats field** that will ship dormant at field-introduction time and first-populated by Sowari-khaneh + Tirandazi simultaneously:

| Field | Default | First-populated by | Dormant consumers (NOT shipping this wave) |
|---|---|---|---|
| `tier: int = 1` | `1` (all 5 existing Tier-1 buildings inherit default) | Sowari-khaneh + Tirandazi (`tier = 2`) | TechSystem.is_tier_2_unlocked, build_placement_validity gate (disable Tier-2 buttons when not unlocked), build_menu reads `tier` to filter buttons. **All deferred to Wave 2C / Phase 4.** |

**Brief-time named cross-track verifier for the dormant-schema first-exercise:** balance-engineer-p3s3 (adds the field) confirms with gp-sys-p3s3 (no current consumer to break) that the field can ship dormant with no callsite-absent bug — the **L6 forward-compat-guard-sweep** runs trivially because there are zero existing readers. The dormant infrastructure is named explicitly so the next wave (Wave 2C, gateway logic) knows to wire it.

**Explicit deferred consumer chain:**
- TechSystem (or equivalent) reads `building_stats.tier` to determine which Tier-2 buildings the player can place — DEFERRED to Wave 2C.
- BuildPlacementHandler / BuildMenu reads `tier` to disable buttons when prereqs not met — DEFERRED to Wave 2C.
- The Atashkadeh-built prereq check + Farr ≥ 40 check — DEFERRED to Wave 2C (already documented as Phase-4 scope in ARCHITECTURE §6 v0.26.0).

**This is the dogfood:** if any future wave first-populates this field's *consumers*, they'll trigger H3 + L6 at THAT moment. Wave 2B intentionally ships the producer side dormant + with named-deferred-consumers.

### 3.2 L6 forward-compat-guard-sweep at field-introduction (§9.L6 NEW)

balance-engineer-p3s3 runs the L6 sweep at field-introduction time:

```bash
# At the moment of BuildingStats.tier field addition, sweep readers:
git grep -n 'tier' game/scripts/ game/data/
# Expected: zero readers (the field is brand-new). If readers exist, they need
# to handle the new field's semantics — fix in the same commit.
```

balance-engineer reports the sweep result in their commit message. Zero-reader case is the cleanest L6 application: schema-only commit, no callsite work needed.

### 3.3 J4 claim → mechanism → reviewer triples (§9.J4 REFINED)

loremaster-p3s5 produces the cultural-note for BOTH Sowari-khaneh and Tirandazi using the refined J4 triples-checklist shape. For each cultural-claim asserted in the block:

```
<cultural assertion>
  → depends on: <list of mechanical dependencies>
  → reviewer: <named agent per dependency>
```

Lead (this brief) provides the seed triples below; loremaster refines + extends + flags any mechanical-dependency-without-named-reviewer.

**Sowari-khaneh seed triples (to be refined by loremaster):**
- *"The institutional building that makes mounted aristocracy" → depends on (a) `is_ready_to_produce` flag exposed for Phase-4 production queue [gp-sys], (b) BalanceData cost/HP/construction_ticks entry [balance-engineer], (c) cavalry-class unit (Savar) already exists [gp-sys, already shipped].*
- *"Specialized military arm distinct from infantry sepah" → depends on (d) anchor-category clone-vs-new-variant decision [loremaster brief-time], (e) Sarbaz-khaneh-as-template inheritance [gp-sys clones Sarbaz-khaneh structure].*
- *"Tier-2 progression: gated behind Qal'eh + Farr threshold" → depends on (f) `tier = 2` schema field populated [balance-engineer], (g) gateway logic consuming `tier` [DEFERRED, Wave 2C].*

**Tirandazi seed triples (to be refined by loremaster):**
- Same shape as Sowari-khaneh with the cavalry-tradition language replaced by archery-tradition language. **Tirandazi naming-shape divergence (Task #159):** Tirandazi is *practice/discipline* (تیراندازی = arrow-shooting *practice*), NOT *-khaneh* (house). The naming shape encodes the cultural distinction — archery is canonically about TRAINED SKILL transmission, not just the building. Loremaster flags this at brief-time per Sarbaz-khaneh header lines 93-99 prediction.

## 4. Pre-flight loremaster brief-time review (per §9.J1 — FIRES)

Brief-time review fires per J1 trigger condition: *"first variant of an existing template-family"* — Sowari-khaneh + Tirandazi are predicted-as-clones of Sarbaz-khaneh's identity-bearing institutional anchor-category, but the prediction needs validation. Plus J2 watchlist's trichotomy refinement (clone-check / slot-fit-verify / taxonomy-growth-required) applies here as its inaugural test case — fitting since Wave 2A's identity-bearing institutional anchor was Sarbaz-khaneh's session-4 invention.

**Loremaster-p3s5 dispatch prompt (lead will SendMessage after this brief is committed):**

> Sowari-khaneh + Tirandazi anchor-category brief-time review. Three questions:
>
> 1. **Clone-check / slot-fit-verify / taxonomy-growth-required?** Sarbaz-khaneh header (lines 82-104) predicts both as identity-bearing institutional clones. Validate or refine: are they (a) faithful clones (same anchor-category template, cultural specialization only), (b) fitting predicted-empty slots (sub-variants of the identity-bearing institutional category), OR (c) demanding a new anchor-category (e.g., "specialized-military-arm" or "cavalry-tradition" / "archery-tradition" as distinct anchors)?
> 2. **J4 triples checklist for both buildings.** Refine + extend the seed triples in §3.3 above. Surface any mechanical-dependency-without-named-reviewer.
> 3. **Tirandazi naming-shape divergence.** Per Task #159: *Tirandazi* (تیراندازی) is "arrow-shooting *practice/discipline*" not "*-khaneh* (house)". Sarbaz-khaneh header lines 93-99 predicted this distinction. Does the naming-shape divergence imply a different anchor-shape, or is it a surface-language difference with the same underlying institutional-oath shape? Lock the framing.
>
> **Deliverable:** SendMessage to lead with verdict + J4 triples + cultural-note prose (paste-ready for Commit 1.5 integration in both `sowari_khaneh.gd` and `tirandazi.gd` headers). Same shape as Sarbaz-khaneh's `a351869` integration.

## 5. Implementation tracks

Five tracks across five agents, sequential per E1. Track-1 starts after loremaster brief-time review completes.

### Track 0 — Loremaster brief-time review (PRE-IMPLEMENTATION)

**Owner:** shahnameh-loremaster-p3s5 (persistent — Atashkadeh authoring continuity).
**Deliverable:** SendMessage to lead with the three-question verdict from §4 above + J4 triples + paste-ready cultural-note prose.
**Output is consumed by:** gp-sys (Track 1.5 paste integration), all other tracks (anchor-category answer drives template-shape decisions).
**Blocking:** Track 1 implementation does NOT start until Track 0 closes (anchor-category answer drives `sowari_khaneh.gd` / `tirandazi.gd` template-shape).
**Time budget:** 1 dispatch round.

### Track 1 — gp-sys scaffolding (sowari_khaneh.gd + tirandazi.gd + tests + scene-paths)

**Owner:** gameplay-systems-p3s3 (persistent — Sarbaz-khaneh + Atashkadeh authoring continuity).
**Deliverable single commit:**
- `game/scripts/world/buildings/sowari_khaneh.gd` — clone of Sarbaz-khaneh structure, KIND = &"sowari_khaneh", `is_ready_to_produce` Stage-2 flip pattern. **L4a applied at authoring time:** `super._on_placement_complete()` and `super._on_construction_complete()` as FIRST LINE of each override (forward-compat per session-3 retro discipline).
- `game/scripts/world/buildings/tirandazi.gd` — same shape, KIND = &"tirandazi". Anchor-category framing may diverge per loremaster Track-0 verdict.
- `game/tests/unit/test_sowari_khaneh.gd` + `test_tirandazi.gd` — 12-14 tests each via `.new()` per M4 (decouples from scene ship-timing). Mirror `test_sarbaz_khaneh.gd` 14-test pattern.
- `game/scripts/units/states/unit_state_constructing.gd` `_BUILDING_SCENE_PATHS` — add `&"sowari_khaneh"` + `&"tirandazi"` entries pointing at `res://scenes/world/buildings/sowari_khaneh.tscn` + `tirandazi.tscn`. **At Commit 1, not as a follow-up** — per session-2 wave-1A `0d3f...` late-add lesson internalized.
- **D9 pre-commit self-review** mandatory per §9.D9. Step 2 sub-step (verb-claim grep): if this brief asserts anything about a downstream consumer ("X registered with Y"), grep before consuming.

### Track 1.5 — Loremaster cultural-note paste integration

**Owner:** gp-sys (paste integration; loremaster provides content via Track 0).
**Deliverable single commit:** `sowari_khaneh.gd` + `tirandazi.gd` headers receive loremaster's verbatim cultural-note block per the Sarbaz-khaneh `a351869` pattern. J4 triples embedded inline or in adjacent comment block per loremaster's verdict.

### Track 2 — world-builder scene authoring

**Owner:** world-builder-p3s2 (persistent — Sarbaz-khaneh + Atashkadeh scene authoring continuity).
**Deliverable single commit:**
- `game/scenes/world/buildings/sowari_khaneh.tscn` — inherits `building.tscn`. BoxMesh sized to convey "cavalry training facility" (likely WIDER than tall to read as a stable, contrasting with Sarbaz-khaneh's institutional shape). NavigationObstacle3D present (workers route around). Color: bronze / horse-leather brown (world-builder's call; reads as "the cavalry barn" from across map).
- `game/scenes/world/buildings/tirandazi.tscn` — inherits `building.tscn`. BoxMesh sized to convey "archery practice yard" (likely LONGER to read as a range, with the practice-yard semantic). Color: bow-wood brown or distinct-from-Sowari (world-builder's call).
- `game/tests/unit/test_sowari_khaneh_scene.gd` + `test_tirandazi_scene.gd` — **Pitfall #15 regression tests MANDATORY** per §9.F4 (first occurrence of subclass with nested-child overrides each time). Pattern: instantiate scene, walk to CollisionShape3D, assert overridden footprint matches mesh. Same shape as `test_sarbaz_khaneh_scene.gd:2f31b34`.
- **D9 pre-commit self-review** mandatory. Pitfall #15 trigger check applies; world-builder is the same agent who originated the canonical incident at Wave 2A `1ff3039` — pattern transfer expected to hold.

### Track 3 — balance-engineer BalanceData + tier schema field (H3 DOGFOOD)

**Owner:** balance-engineer-p3s3 (persistent — Atashkadeh + Sarbaz-khaneh authoring continuity).
**Deliverable single commit:**
- `game/data/sub_resources/building_stats.gd` — **add `@export var tier: int = 1` field** with documentation comment explaining the dormant-consumer chain + L6 sweep result (zero readers). **This is the H3-dogfood moment.** Comment must explicitly cite "H3 dormant-schema first-exercise — consumers in Wave 2C / Phase-4 gateway logic." L6 sweep documented in commit message: `git grep -n 'tier' game/scripts/ game/data/` returns zero non-test readers; new field has no consumer-side work this wave.
- `game/data/balance.tres` — two new SubResource entries:
  - `bldg_sowari_khaneh`: `max_hp` (TBD per ladder; should land between Sarbaz-khaneh's anchor and Tier-2 weight), `coin_cost = 200` (spec §5 line 194), `grain_cost = 0`, `construction_ticks` (Tier-2 timing-ladder per Atashkadeh's 900-anchor pattern — recommend ~1080 = 36s, between Atashkadeh 900 and Qal'eh 2700), **`tier = 2`** (first-non-default value of the new field).
  - `bldg_tirandazi`: same shape, `coin_cost = 175` (spec §5 line 195), `grain_cost = 0`, `construction_ticks` ~1020 (slightly less than Sowari-khaneh; the practice-discipline naming suggests it's slightly cheaper-to-train, also reflected in spec's 175<200 cost), **`tier = 2`**.
- **D9 pre-commit self-review** mandatory. Step 3 first-exercise self-check explicitly applies: balance-engineer is first-populating `tier`. Document the H3 trigger in commit message + cite L6 sweep result.
- **Spec-wins-over-lead lens (L1):** lead's recommended `construction_ticks` values above are starting points; verify against §5 + §8 timing-ladder. Lead may be wrong; cite spec if so.

### Track 4 — ui-developer build menu + strings + .translation regen

**Owner:** ui-developer-p3s3 (persistent — Atashkadeh build menu + verb-claim D9 contribution continuity).
**Deliverable single commit:**
- `game/scenes/ui/build_menu.tscn` — two new buttons (Sowari-khaneh + Tirandazi) below Atashkadeh. Panel `offset_top` extends from -306 → -386 (40px per button, matching Atashkadeh `-266 → -306` extension at Wave 2A.5).
- `game/scripts/ui/build_menu.gd` — extend `refresh_button_labels` to read both new buildings' `cost_coin()` static helpers. **No grain dual-cost substitution needed** — both Tier-2 entry buildings are coin-only per spec §5 (Sowari-khaneh 200 coin, Tirandazi 175 coin; no grain component).
- `game/translations/strings.csv` — 6 new keys (LABEL/COST/TOOLTIP for each). Persian-primary convention per existing rows. Tooltips: Sowari-khaneh = "Cavalry training stable. Produces Savar (heavy cavalry). Requires Tier 2." Tirandazi = "Archery range. Produces advanced Kamandar variants. Requires Tier 2." **"Requires Tier 2" framing** is intentional — surfaces the deferred gateway logic to the player even though the gating isn't wired yet. When Wave 2C ships the gate, the tooltip becomes self-documenting.
- **`strings.en.translation` binary regen via `godot --headless --import`** per §9.D2 wave-1B canonical lesson. `ls -la translations/` to confirm binary mtime > csv mtime (ui-developer's session-5 contribution to D9 Step 4 sub-step).
- 6+ new behavioral tests in `test_build_menu.gd` (mirror Atashkadeh pattern).
- **D9 pre-commit self-review** mandatory. Step 2 sub-step (verb-claim grep) — your own contribution at session-5 retro; apply rigorously here.

### Track 5 — Anchor-category taxonomy dedicated doc (Task #160)

**Owner:** shahnameh-loremaster-p3s5 (post-Track 0; can ship in parallel with Tracks 1-4 once the anchor-category verdict from Track 0 is locked).
**Deliverable single commit:** `docs/ANCHOR_CATEGORY_TAXONOMY.md` (new file, v1.0.0). Contents:
- Frontmatter per §9.C2 schema.
- Per-variant template-shape spec (civic-anchor, labor-organization, identity-bearing institutional, sacral-emitter, future). Each entry: cultural-truth-claim shape, mechanical-shape, canonical example, J4 triples-checklist pattern.
- Iran Tier-1 5/5 + Tier-2 Sowari-khaneh + Tirandazi assignments.
- Turan prediction notes (structural-mismatch hypothesis: khan-loyalty + steppe-mobile sworn-bond, NOT building-clone pattern).
- J2 watchlist refinement integration (clone-check / slot-fit-verify / taxonomy-growth-required trichotomy as the brief-time review classifier).
- **This doc is SSOT-owned by loremaster** (per §9.C2 frontmatter `owner: shahnameh-loremaster`); §9.J2 active rule's table becomes a "see ANCHOR_CATEGORY_TAXONOMY.md" pointer.

### Track 6 — Lead wave-close (ARCHITECTURE §6 v0.28.0 + §2 row updates + BUILD_LOG)

**Owner:** lead (this is the wave-close commit; lead authors per existing pattern).
**Deliverable single commit:** ARCHITECTURE.md v0.28.0 §6 wave-close entry + §2 building-row updates (Sowari-khaneh + Tirandazi rows added; 7 Iran buildings total now). BUILD_LOG entry.

## 6. Workflow per track — canonical anti-loop dispatch cycle (per §9.D2)

Every track follows the canonical cycle verbatim:

```
1. Read the relevant docs.
2. Write failing tests first (TDD red).
3. Implement.
4. Pre-commit gate (lint + GUT) must pass.
5. Stage your files explicitly: `git add` per file.
6. Run `git diff --staged --stat` — verify ONLY your files.
7. Verify `git diff BUILD_LOG.md docs/ARCHITECTURE.md` shows ONLY your additions (or untouched if you're not modifying them this track).
8. Commit (with the pathspec form from D4). Title: descriptive per project convention.
9. Run `git log -1 --oneline` — confirm your SHA at HEAD.
10. THEN report back via SendMessage.
```

## 7. Wave-close + live-test gate

After Tracks 1-5 ship: lead runs §9.M2 live-test cadence (start game, place Sowari-khaneh, place Tirandazi, verify scenes render + construction completes + `is_ready_to_produce` flips + build menu displays correctly + strings.csv binary in sync). Wave-close trio review (architecture-reviewer + godot-code-reviewer + loremaster) fires before PR. Headless tests + reviewer trio + live-test = three gates per §9.M2.

## 8. Open questions to flag at brief-time (NONE EXPECTED but listed for discipline)

- Anchor-category verdict from loremaster Track 0 — drives template-shape decisions for Tracks 1-2-3. If verdict is "taxonomy-growth-required (new anchor variant)", scope expands to include taxonomy doc updates (Track 5 already covers this).
- Tirandazi naming-shape: if loremaster's verdict is "different anchor-shape," Track 1 implementation may diverge from Sarbaz-khaneh clone pattern. Lock at brief-time.

## 9. Sign-off

This brief is the kickoff artifact. Lead commits this brief, then dispatches loremaster-p3s5 (Track 0 first). Once Track 0 closes, Tracks 1-5 dispatch sequentially per §9.E1 sequential-shared-tree mode.

— team-lead, Phase 3 session 6 kickoff (2026-05-21)
