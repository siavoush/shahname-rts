---
title: Phase 3 Session 7 — Wave 3A.6 Building-Click-To-Train Kickoff
type: plan
status: draft
version: 1.0.0
owner: team-lead
summary: Wave 3A.6 — first playable production loop. Click a Sarbaz-khaneh / Sowari-khaneh / Tirandazi → opens production panel → click "Train Piyade/Savar/Kamandar" → resources deducted + pop check + unit spawned at building's rally point after dwell ticks. AsbSavarKamandar production deferred to a follow-up (single 2nd-cavalry-from-Sowari-khaneh option adds scope without unblocking the playable loop). Kargar production deferred to whenever the Throne building ships (not a 3A.6 problem). Restores visible playable-feel after 3A.0/3A.5's invisible plumbing waves AND sets up Wave 3B to drive a Turan opponent that actually produces units.
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, docs/ARCHITECTURE.md, 01_CORE_MECHANICS.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, 01_CORE_MECHANICS.md, docs/AGENT_REGISTRY.md]
ssot_for:
  - Wave 3A.6 scope (3 producer buildings → 3 unit kinds; AsbSavarKamandar + Kargar production explicitly DEFERRED)
  - Per-track deliverables for Wave 3A.6
  - Production-state machine on Building base + click-handler routing decision
tags: [phase-3, session-7, wave-3a-6, building-production, gameplay, kickoff]
created: 2026-05-23
last_updated: 2026-05-23
---

# Phase 3 Session 7 — Wave 3A.6 Building-Click-To-Train Kickoff

## 0. Why this doc exists — restoring playable feel + unblocking Wave 3B

Waves 3A.0 + 3A.5 shipped the fog data layer + vision sources. Neither wave produced a visible change for the player (fog rendering is Phase 5). Lead live-tested Wave 3A.5 and confirmed: "didn't notice anything." That's by design for the plumbing waves but it means the **next wave needs to be visible-playable** to maintain the test-cadence the project relies on.

**Wave 3A.6 = building-click-to-train.** It's both:
1. **A meaningful playable-feel restoration** — you can actually build an army from your buildings instead of just placing them.
2. **The unblocker for Wave 3B** (DummyAIController). A Turan AI that can only fight with starting units is a thin demo; a Turan AI that *produces* Savar and Kamandar from its own Sowari-khaneh + Tirandazi and attacks with them is a real opponent. Wave 3A.6 wires the production surface that Wave 3B's AI will drive.

## 1. Wave shape — scope-tight, 3 producer-unit pairs only

| Producer building | Produces (this wave) | Train cost (rough; balance-engineer locks final values) | Dwell ticks (rough; same) |
|---|---|---|---|
| Sarbaz-khaneh | Piyade | 50 Coin + 25 Grain | 90 (3s) |
| Sowari-khaneh | Savar | 80 Coin + 30 Grain | 150 (5s) |
| Tirandazi | Kamandar | 60 Coin + 30 Grain | 120 (4s) |

**Explicit deferrals — do NOT scope in:**

- **AsbSavarKamandar production** — Iran's horse-archer is a Tier-2 unit per the spec; production locus is ambiguous (Sowari-khaneh as 2nd-option vs new building). Defer to Phase 4 / Tier-2-polish wave. 3A.6 ships 3 producer-unit pairs cleanly.
- **Kargar production** — Kargars are produced by the Throne. The Throne building does not exist yet (deferred to a future wave). 3A.6 does not address this — the 5 starting Kargars + future Khaneh-vs-Throne decision is out of scope.
- **Train queue depth > 1** — start with single-slot production (clicking train while training-in-progress refuses + plays a deny sound, OR queues to depth 1 max). Defer multi-slot queue to polish.
- **Rally point UI (right-click building → set rally)** — start with a fixed offset rally (units spawn at `building.global_position + Vector3(0, 0, building.footprint_z_radius + spawn_margin)` toward the Iran-side direction). Defer user-settable rally to polish.
- **Production-progress UI on the building itself** — defer to polish. Production panel shows progress while open; that's sufficient for live-test feel.
- **Turan-side production** — 3A.6 ships the production *system*. Wave 3B (DummyAI) is what drives Turan to actually use it. 3A.6 only verifies Iran can produce; the system is symmetric so Turan production gets exercised by Wave 3B.

## 2. Reading order (≈10 min for active agents)

1. **`MANIFESTO.md`** — if your persistent context has rotated.
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: §9.D7(b) broadcast-on-observe-cross-track-WIP, §9.E1 sequential-shared-tree mode + 3A.5's sequenced-commit refinement (see §3.1 below), §9.M3 retry-once-before-broadcasting.
   - gp-sys: §9.H1 cross-cutting schema verification (production state machine touches Building + BalanceData + spawn API), §9.H3 first-exercise discipline (this wave is first exercise of `BalanceData.bldg_<name>.train_<unit>_cost_coin/grain/dwell` schema entries).
   - ui-developer: §9.L7 affordability-sweep (production panel buttons must reflect "can-afford" state, same as build menu), §9.L8 drift-proof defaults (read all costs from BalanceData, never hardcode), §9.G channel discipline.
   - balance-engineer: §9.L1 multi-domain spec-wins, §9.H3 first-exercise schema design.
3. **`docs/ARCHITECTURE.md` §6 v0.31.0** — Wave 3A.5 close (covers vision-source surface that producers will now register on at spawn-complete).
4. **`01_CORE_MECHANICS.md` §6 + §7** — Unit production costs (if specified) + tech tier gating. Read for grounding; if costs are unspecified, balance-engineer picks reasonable starting numbers (the table in §1 above is a starting point).
5. **`game/scripts/world/buildings/building.gd`** — base class you'll extend with the production state machine.
6. **`game/scripts/world/buildings/{sarbaz_khaneh,sowari_khaneh,tirandazi}.gd`** — the 3 producers; you'll wire production_kind tag + (optional) cultural-note hook.
7. **`game/scripts/ui/build_menu.gd`** — pattern to mirror for the production panel.
8. **`game/scripts/input/click_handler.gd`** — line 162-164 is the "non-unit collider → deselect" branch you'll route around for clicks on owned producer buildings.
9. **`docs/AGENT_REGISTRY.md` v1.0.0** — verify addressable names before any SendMessage.

## 3. Brief-time disciplines

### 3.1 §9.E1 sequenced-commit refinement (3A.5 retro carry-forward — codified here)

Wave 3A.5 validated: "joint commit" can mean 2-commit-on-same-branch when one track's ship is the gate for the other's test path. **For Wave 3A.6: same expectation.** Track 1 (gp-sys production state machine) is the gate; Track 2 (ui-developer panel) and Track 3 (balance-engineer schema) write against Track 1's API.

**Coordination pattern:**
- Track 1 ships first OR all 3 ship simultaneously via joint commit (if Track 3's BalanceData fields land at the same time as Track 1's reads, joint is cleaner).
- Track 2 commits on top of Track 1 + Track 3 (whichever shape they take).
- All on same branch. Single PR.

### 3.2 §9.D7(b) cross-track diagnostic loop empirical pattern (3A.5 success carry-forward)

3A.5 surfaced N=1 successful cross-track diagnostic loop — gp-sys flagged a bug in world-builder's Track 1 BEFORE world-builder committed. Both bugfixes landed in Track 1's first commit. **Replicate the pattern for 3A.6:** when staging your track, briefly verify your tests against another in-flight track's staged work; broadcast diagnoses sideways before lead-escalation.

### 3.3 §9.L7 affordability-sweep — mandatory for production panel

Production panel buttons must reflect "can-afford" state per §9.L7. Mirror the build menu's affordability sweep: button enabled = "have enough coin AND enough grain AND pop cap room"; button disabled = grey + tooltip explaining which resource is short. Click-time both-or-neither: click an affordable button → deducts BOTH resources atomically OR shows "insufficient" error and deducts nothing.

### 3.4 §9.H3 first-exercise — BalanceData production schema

Wave 3A.6 introduces new BalanceData schema:
```gdscript
# Per-building BuildingStats entries (extending existing bldg_<name>):
@export var train_<unit_kind>_cost_coin: int = 0
@export var train_<unit_kind>_cost_grain: int = 0
@export var train_<unit_kind>_dwell_ticks: int = 0
```

Per §9.H3: first runtime read of these fields lives in the production state machine. Track 3's tests MUST validate per-producer-per-unit composition correct (the 3 producer-unit pairs each have 3 fields = 9 new tunables). Typo surface: `train_savar_cost_coin` vs `train_savar_coin_cost` — lock the naming convention before writing.

**Lead's call on naming convention:** `train_<unit_kind>_<field>` (verb_object_attribute). Field names: `cost_coin`, `cost_grain`, `dwell_ticks`.

## 4. Per-track deliverables

### Track 1 — gameplay-systems-p3s3 (Building production state machine + spawn API)

**Files:**

- `game/scripts/world/buildings/building.gd` (base) — extend with:
  - `@export var produces: Array[StringName] = []` — which unit kinds this building can produce. Empty = non-producer.
  - `_production_state: StringName = &"idle"` — `&"idle"` or `&"training"`.
  - `_production_unit: StringName = &""` — the kind currently being trained.
  - `_production_progress_ticks: int = 0` — countdown to spawn (decrements per `_sim_tick` or via a similar mechanism in line with existing construction state).
  - `_production_total_ticks: int = 0` — for progress fraction queries.
  - `request_train(unit_kind: StringName) -> bool` — public API. Validates: (a) `produces.has(unit_kind)`, (b) `_production_state == &"idle"`, (c) ResourceSystem can afford coin + grain cost, (d) pop cap has room. On success: deduct resources, set `_production_state = &"training"`, set `_production_unit`, read dwell from BalanceData. Return bool.
  - `_sim_tick` (or equivalent existing per-tick hook): if `_production_state == &"training"`, decrement `_production_progress_ticks`. On reaching 0: spawn the unit at the building's rally-point offset, transition back to `&"idle"`, emit signal.
  - `production_state_changed(building_id: int, state: StringName, unit_kind: StringName, progress_fraction: float)` signal for UI consumers.

- `game/scripts/world/buildings/sarbaz_khaneh.gd`: override `produces = [&"piyade"]`.
- `game/scripts/world/buildings/sowari_khaneh.gd`: override `produces = [&"savar"]`. (NOT `[&"savar", &"asb_savar_kamandar"]` — AsbSavarKamandar deferred.)
- `game/scripts/world/buildings/tirandazi.gd`: override `produces = [&"kamandar"]`.

- **Rally point logic** — fixed offset for MVP. Pick a sensible side-relative offset (e.g., for Iran buildings spawn unit at `global_position + Vector3(0, 0, footprint_radius + 2.0)` — south-side spawn, away from the building's footprint).

- **Spawn integration** — reuse `main.gd:_spawn_unit` pattern, OR if that pattern is awkward to call from the building, add a public `MatchSystem.spawn_trained_unit(kind, team, world_pos)` autoload or equivalent. Lead's call: simplest path.

- **Tests:**
  - `test_building_base.gd` extensions: `produces` field, `request_train` validates, dwell countdown, spawn-on-complete.
  - `test_sarbaz_khaneh.gd` / `test_sowari_khaneh.gd` / `test_tirandazi.gd`: each asserts `produces` is correct, request_train deducts resources, spawn happens.
  - Integration test: place Sarbaz-khaneh → request_train(&"piyade") → tick dwell forward → assert Piyade exists in scene with correct team.

### Track 2 — ui-developer-p3s3 (ProductionPanel UI + click-handler routing)

**Files:**

- `game/scenes/ui/production_panel.tscn` (NEW) — modal-ish floating Control. Shows the producer building's name, a list of train buttons (one per `produces` entry), each with: unit name + cost + dwell time + "Train" button. While training is in progress: button row replaced with progress bar + "Training Piyade — 2.4s remaining" label.

- `game/scripts/ui/production_panel.gd` (NEW) — `class_name ProductionPanel`. Subscribes to `building.production_state_changed`. Reads `BalanceData.bldg_<name>.train_<unit>_cost_coin/grain` for button labels. Per §9.L7 affordability sweep: button enabled/disabled per "can-afford + pop-cap" state, updates on `ResourceSystem.resource_changed` signal. Closes on: escape key, click elsewhere, building destroyed.

- `game/scripts/input/click_handler.gd` — modify the "non-unit collider → deselect_all" branch (line 162-164):
  - If the collider belongs to a building (test: walk up the scene tree from the collider to find an ancestor with `produces` field non-empty), open ProductionPanel for that building.
  - Else: keep current deselect behavior.

- **`game/text/strings/strings.en.translation` regen** — new strings for production panel labels (PRODUCTION_PANEL_TITLE, TRAIN_PIYADE_LABEL, INSUFFICIENT_COIN, INSUFFICIENT_GRAIN, POP_CAP_FULL, etc.).

- **Tests:**
  - `test_production_panel.gd` (NEW): panel opens on building click, shows correct unit options per producer kind, affordability state correct, train button click invokes `building.request_train(unit_kind)`.
  - `test_click_handler.gd` extensions: building-collider routes to ProductionPanel-open, not deselect.

### Track 3 — balance-engineer-p3s3 (BalanceData training schema)

**Files:**

- `game/data/sub_resources/building_stats.gd` — extend with the 9 new fields per the §3.4 naming convention:
  ```gdscript
  # Sarbaz-khaneh trains Piyade
  @export var train_piyade_cost_coin: int = 0
  @export var train_piyade_cost_grain: int = 0
  @export var train_piyade_dwell_ticks: int = 0
  # Sowari-khaneh trains Savar
  @export var train_savar_cost_coin: int = 0
  @export var train_savar_cost_grain: int = 0
  @export var train_savar_dwell_ticks: int = 0
  # Tirandazi trains Kamandar
  @export var train_kamandar_cost_coin: int = 0
  @export var train_kamandar_cost_grain: int = 0
  @export var train_kamandar_dwell_ticks: int = 0
  ```
  Note: fields live on BuildingStats so they can be set per-producer in `balance.tres`. Reads happen via `BalanceData.bldg_<producer>.train_<unit>_<field>`.

  Per §9.L9 fallback-by-failure-visibility-shape: zero defaults will produce instant-free training if BalanceData read fails. That's a visibly-wrong fallback (free units pop out instantly) — diagnosable. Acceptable.

- `game/data/balance.tres` — populate the values per the §1 table (final values are balance-engineer's call; the §1 table is a starting point):
  - `bldg_sarbaz_khaneh.train_piyade_cost_coin = 50`
  - `bldg_sarbaz_khaneh.train_piyade_cost_grain = 25`
  - `bldg_sarbaz_khaneh.train_piyade_dwell_ticks = 90`
  - (same shape for Sowari-khaneh + Tirandazi)

- **Tests:**
  - `test_balance_data.gd` extensions: assert all 9 new fields exist, validate per-producer-per-unit cross-composition (Sarbaz-khaneh has Piyade-train fields populated but not Savar fields, etc.).

### Standby — world-builder-p3s2 + engine-architect-p3s2

No mandatory deliverables. Possible triggers:
- **world-builder:** if rally-point visualization needs a placeholder mesh (small marker where unit will spawn). Lead's call to add OR defer.
- **engine-architect:** if production-state machine needs a new sim phase or interacts with existing phase ordering in a non-obvious way. Likely none — production can hook into the existing `_sim_tick` path that construction uses.

## 5. Wave-close criteria

- [ ] All 3 producer buildings have `produces` populated.
- [ ] Clicking a producer building opens ProductionPanel; clicking a non-producer building deselects (current behavior preserved).
- [ ] Train button affordability sweep working (greyed + tooltip when can't afford).
- [ ] Train click deducts resources atomically; dwell countdown observable in UI.
- [ ] Trained unit spawns at rally-point offset after dwell; counts toward population cap.
- [ ] Pre-commit hook green; full headless suite green at wave-close commit.
- [ ] ARCHITECTURE.md v0.31.0 → v0.32.0 close entry.
- [ ] BUILD_LOG session 7 wave 3A.6 close entry.

## 6. Hand-off when this wave closes

- **Wave 3B (DummyAIController)** — immediate next. Turan AI uses `building.request_train(unit_kind)` to produce + `is_visible_to` to target. Production system from 3A.6 + vision system from 3A.5 are the two prerequisites it consumes.
- **Wave 3A.7 (memory features)** — still unscheduled; surface when Phase 5 prep opens.
- **Production polish carry-forwards** (Phase 4 candidates): train queue depth > 1, user-settable rally point, AsbSavarKamandar production locus decision, Throne building + Kargar production.

---

*Status: v1.0.0 — DRAFT 2026-05-23 by lead. Pending agent acknowledgment.*
