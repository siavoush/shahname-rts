---
title: Phase 3 Session 8 — Throne Wave Kickoff (Iran + Turan HQ + game-goal landmark)
type: plan
status: draft
version: 1.0.2
owner: team-lead
summary: Throne wave — ships the Iran + Turan HQ buildings that close Phase 3's economic loop AND seed the Phase 8 win condition. Currently the Kargar deposit path is inline (no walk-back, dead RNC §5 IDropoffTarget protocol); the Throne becomes the canonical drop-off target. Both factions get a Throne spawned at match start. High HP + golden visual accent + "destroyed = lose" forward-compat seam (Phase 8 win-screen consumer). Wave 3B's TuranController gets a natural high-priority target. **First wave to use §9.M6 log-instrumentation-from-day-1 + mirror-reviewer brief-time review as MANDATORY discipline gates.** Closes Phase 3.
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, docs/ARCHITECTURE.md, 01_CORE_MECHANICS.md, docs/RESOURCE_NODE_CONTRACT.md, docs/FOG_DATA_CONTRACT.md, docs/ANCHOR_CATEGORY_TAXONOMY.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, RESOURCE_NODE_CONTRACT.md, FOG_DATA_CONTRACT.md, AI_DIFFICULTY.md, ANCHOR_CATEGORY_TAXONOMY.md, docs/AGENT_REGISTRY.md, 01_CORE_MECHANICS.md, 00_SHAHNAMEH_RESEARCH.md]
ssot_for:
  - Throne wave scope (Iran + Turan HQ; RNC §5 IDropoffTarget activation; game-goal seam)
  - Per-track deliverables for Throne wave
  - First brief explicitly mandating §9.M6 log instrumentation as Track deliverable
  - First brief routed through mirror-reviewer pre-flight before implementer dispatch
tags: [phase-3, session-8, throne, iran-turan-hq, kickoff, win-condition]
created: 2026-05-24
last_updated: 2026-05-24
---

# Phase 3 Session 8 — Throne Wave Kickoff

## 0. Why this doc exists — the building that gives the game stakes

The Shahnameh's central conflict is the war between Iran and Turan — between civilizations. **Civilizations have thrones; thrones have kings; kings command the realm.** The Throne is the project's load-bearing piece of furniture from a design-soul perspective.

Before this wave, the project has:
- Workers gathering resources + depositing — **HUD coin/grain counter already increments** today via wave-1B's inline-deposit at `unit_state_returning.gd:235` calling `ResourceSystem.change_resource(team, kind, amount_x100, "gather_deposit", ctx)` directly. The economy chokepoint is wired; the deposit *accounting* works.
- **What's missing is the WALK-BACK geometry + the RNC §5 IDropoffTarget routing** wrapping the chokepoint. Workers currently deposit at their gather location (distance-zero return). RNC §5 IDropoffTarget protocol exists but has zero consumer; the contract has been dormant for months.
- Buildings constructed by workers; AI probe-attacking starter units; no win condition.

After this wave, the project has:
- **Iran Throne + Turan Throne** spawned at match start; both factions have a visible royal seat. **The Throne is the FIRST cross-faction-symmetric anchor-category** — Turan ships an identical `throne.gd extends Building` instance (different team-id + visual accent), DIFFERENT cultural register (Iran: Farr-legitimized theological kingship; Turan: sworn-loyalty named-rulership), SAME anchor-shape (singular seat, terminal-stakes, IDropoffTarget, destruction = end-of-realm). This is the **opposite of the structural-mismatch pattern** that governs the other four anchor-categories per loremaster brief-time review.
- **Workers walk back to the Throne** to deposit resources — the `change_resource` chokepoint call MOVES from `unit_state_returning._perform_deposit` to `Throne.deposit(resource_kind, amount, worker)` per RNC §5.2 canonical pattern. UnitState_Returning delegates by calling `target.deposit(...)`. (Mirror-reviewer C1.4 disambiguation: deposit-accounting moves into Throne; Returning becomes a routing layer.) **The dehqan-Throne reciprocity (tribute-to-the-king) is the mechanical realization of the Shahnameh's attested economic-political relationship.**
- **TuranController has a natural high-priority target** (the Iran Throne) — combat acquires stakes
- **Throne destruction = forward-compat win-condition seam** for Phase 8 (`EventBus.throne_destroyed(team_id)` signal; UI screen lands in Phase 8)
- **NEW fifth anchor-category established**: `sovereignty-bearing institution` per `docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.1.0. Sub-slot axis is *tier-progression of the seat*: Throne (Tier 1 base-royal-seat) → Qal'eh (Tier 2 fortified-royal-seat, Phase 4 conversion-not-replacement) → Royal Court (Tier 3 imperial-court-seat, post-MVP). **Qal'eh's anchor-category question from session-6 retro Q3 Gap 1 is RESOLVED at this wave.**
- The cultural lore the project has been carrying (`unit_state_returning.gd` "tribute to the king" prose, `fog_config.gd:77` "always-on building vision anchoring the Iran start area") finally has a real referent in code

**This wave closes Phase 3.** Phase 4 then opens with proper production-queue UI, tech-tier advancement, and the full Farr generator/drain set per `02_IMPLEMENTATION_PLAN.md` §3.4.

## 1. Scope — what SHIPS vs DEFERS

### What SHIPS

| Surface | Wave state |
|---|---|
| **`throne.gd` Building subclass** | NEW class extends `building.gd`. `kind = &"throne"`. **`max_hp = 2000` per existing `balance.tres:213` `bldg_throne.max_hp = 2000.0`** (lead deferring to balance-engineer's wave-prior authoring per §9.L1; original brief's 5000 was lead-invention without spec basis). 4×4 cell footprint. **Implements RNC §5.2 canonical IDropoffTarget protocol: `deposit(resource_kind: StringName, amount: int, worker: Unit) -> void` + `get_deposit_position() -> Vector3`** (mirror C1.1 — the contract's actual method signatures). **Anchor-category: `sovereignty-bearing institution`** (NEW fifth category proposed by loremaster Track 4 brief-time review 2026-05-24; resolves mirror C3.1 + session-6 retro Q3 Gap 1 Qal'eh open question; J2 trichotomy taxonomy-growth-required outcome #3). See `docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.1.0 §1.5 for category definition. |
| **`throne.tscn` scene** | NEW scene inheriting `building.tscn`. Mesh: large box ~4×3×4 m (visibly larger than Khaneh/Sarbaz-khaneh). Material: gold accent (e.g., `Color(0.85, 0.7, 0.3)`); contrasts both Iran-blue + Turan-red palettes — kingship transcends faction color. |
| **Match-start spawn** | `main.gd:_spawn_starting_buildings` (NEW function or extension of existing): spawn Iran Throne at Iran-side HQ position (Z<0, far south, near the Kargar spawn cluster). Spawn Turan Throne at Turan-side mirror position (Z>0, far north). |
| **Worker-deposit routing** | `unit_state_returning.gd:_perform_deposit` (lines 214-243; already wired to economy chokepoint at line 235) REFACTORS: query for the team's Throne via `ResourceSystem.dropoff_for_team(team)`; if Throne exists, call `throne.deposit(kind, amount, worker_node)` instead of `ResourceSystem.change_resource(...)` directly. The Throne owns the chokepoint call internally (per RNC §5.2 canonical pattern). **If no Throne** (test fixtures, pre-Throne-spawn): fall back to current inline `change_resource` call. **Critical mirror C1.4 disambiguation: only ONE path calls change_resource per deposit — either Throne.deposit (when Throne exists) OR Returning (fallback). NEVER both.** Update Returning's existing call to translate `ResourceSystem.add(...)` per RNC §5.2 stale example into the canonical `ResourceSystem.change_resource(...)` name (Track 1 acknowledges RNC §5.2 has stale `.add` reference; not in scope to fix the contract this wave). |
| **`ResourceSystem.dropoff_for_team(team) -> Node3D` API** | NEW autoload method per RNC §5.2. Looks up via SceneTree group `&"thrones"` + filters by team. Returns null if no Throne present (e.g., destroyed). **Pitfall #16 safety MANDATORY** (mirror C2.1): the memoized return MUST `is_instance_valid()` BEFORE returning OR before the caller dereferences. Memo invalidation on `EventBus.throne_destroyed` signal (or `building_destroyed` if exists) to prevent freed-Node cache between ticks. Memoized per-team per-tick. |
| **Throne destruction signal** | NEW `EventBus.throne_destroyed(team_id: int)` signal **with `@warning_ignore("unused_signal")` annotation** per existing EventBus convention at `event_bus.gd:22-185` (mirror C2.2). Emitted on Throne HealthComponent fatal-damage path. Phase 8 win-screen consumer will subscribe; for this wave only the emit happens — no consumer yet. |
| **Vision source registration** | Throne registers via `FogSystem.register_vision_source(self, team, sight_throne_cells, true)` at `_on_placement_complete`. `sight_throne_cells = 4` already exists in FogConfig (forward-compat schema from 3A.0). |
| **TuranController target priority refinement** | **CORRECTED per mirror C1.2:** SpatialIndex tracks UNITS (SpatialAgentComponent), NOT buildings. To find Iran's Throne, query via `get_tree().get_nodes_in_group(&"thrones")` filtered by team — NOT SpatialIndex.query_radius_team. Brief priority: (1) query Throne via SceneTree group → if Iran Throne visible to Turan via FogSystem.is_visible_to, prefer; (2) else fall back to current Wave 3B "nearest visible unit." Same logic mirrors at Iran-AI shape for Phase 6. |
| **§9.M6 log instrumentation** | `[throne]` tag-prefix on: spawn, deposit-received, damage-taken, destroyed. Every major event emits. |
| **Tests** | `test_throne.gd` (smoke + RNC §5 conformance + spawn + dropoff_for_team + destruction signal). `test_resource_system.gd` extension for `dropoff_for_team`. `test_match_start_spawn.gd` extension for Throne spawn position. `test_unit_state_returning.gd` extension for canonical-dropoff-target path. |

### What EXPLICITLY DEFERS

| Surface | Reason |
|---|---|
| Win/lose UI screen + game-end flow | Phase 8 scope. This wave emits the signal; Phase 8 consumes. |
| Throne click-to-produce Kargar | Phase 4 (Throne becomes producer building when production queue ships). |
| Kaveh Event Throne-targeting | Phase 5 scope. Wave 3A.7 fog memory + Phase 5 Kaveh ship together. |
| Throne real art (gold textures, banners, throne-room geometry) | Post-MVP / Tier 2. Placeholder colored shape per CLAUDE.md visual discipline. |
| Multiple HQs per faction | Out of MVP — both factions have exactly one Throne. |
| Throne repair / rebuilding | Out of scope; destroying a Throne is terminal for this wave. |
| Difficulty-scaled Throne HP | Phase 6 with AI_DIFFICULTY.md tunables. |

**Rationale for narrowing:** the wave's job is to make the Throne EXIST and have CORRECT semantics. Mechanic polish (production, art, multi-base, repair) lives in later phases that pivot on the Throne's existence. Per MANIFESTO principle 6: build what's needed now, not what's elegant later.

## 2. Reading order (~12 min for active agents)

1. **`MANIFESTO.md`** if persistent context has rotated.
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: **§9.M6 log-instrumentation-from-day-1 (NEW just-codified — MANDATORY for this wave)**; §9.D7(b) cross-track diagnostic; §9.E1 tier-precedence; §9.L10 canonical-pattern grep.
   - gameplay-systems: §9.H3 first-exercise-of-dormant-schema (RNC §5 IDropoffTarget activation is the first exercise after months of dormant-schema); §9.H1 cross-cutting schema verification.
   - world-builder: §9.L7 affordability-sweep N/A here (Throne not player-buildable); scene inheritance + Pitfall #15 nested-child override discipline.
   - balance-engineer: §9.L1 spec-wins; §9.L9 fallback-by-failure-visibility-shape.
   - loremaster: §9.J cluster (cultural notes + claim/mechanism/reviewer triples).
3. **`docs/ARCHITECTURE.md` §6 v0.33.2** — latest state (post-BUG-D2 + PR #38 merge).
4. **`docs/RESOURCE_NODE_CONTRACT.md` §5** — the IDropoffTarget protocol; load-bearing for Throne's deposit role.
5. **`docs/FOG_DATA_CONTRACT.md` §2.2** — `sight_throne_cells = 4` schema already present (3A.0 forward-compat); this wave is the first runtime consumer.
6. **`01_CORE_MECHANICS.md` §1, §2, §5** (mirror C4.3 correction — NOT §3): §1 win-condition prose; §2 match-loop "each player starts with one Throne"; §5 Throne row "Capital. Loss = defeat. Spawns workers." §3 is resources (Coin/Grain/Farr listing); does NOT doctrine Throne-as-deposit.
7. **`docs/ANCHOR_CATEGORY_TAXONOMY.md`** — Throne is `civic-anchor` (lead's preliminary call). Loremaster may need to add this category if not present; or refine.
8. **`game/scripts/units/states/unit_state_returning.gd:31-58`** — the existing seam doc explaining "when the Throne ships, deposit target switches to the Throne's position via..."
9. **`docs/AGENT_REGISTRY.md` v1.0.0** — verify addressable names before any SendMessage.

## 3. Brief-time disciplines

### 3.1 §9.M6 log-instrumentation-from-day-1 (NEW — MANDATORY)

Every track that ships new code MUST include `[<system>]` log lines for:
- System initialization (`_ready`)
- Major state transitions / events
- Defensive-guard paths (so failures aren't silent)

Required for THIS wave specifically:
- `[throne]` — spawn, deposit-received, damage-taken, destroyed
- `[resource]` — `dropoff_for_team` lookup result (once per few seconds; throttle)
- `[turan]` (extension) — when target priority shifts to Throne vs unit

**Reviewers (godot-code-reviewer + architecture-reviewer) treat missing log instrumentation as a BLOCKER.** Mirror-reviewer flags it at brief-time review.

### 3.2 Mirror-reviewer brief-time review (MANDATORY before dispatch)

Lead dispatches `mirror-reviewer` agent with this brief BEFORE implementer dispatch. Mirror's 4-class review applies:
- **Class 1 schema/canonical-pattern grep** — verify all spec citations (RNC §5, FogConfig sight_throne, anchor-category)
- **Class 2 Godot 4 footgun** — Pitfall #15 (nested-child override) since throne.tscn inherits building.tscn; Pitfall #16/#17 audit on any iteration over registries
- **Class 3 cross-cutting schema** — `EventBus.throne_destroyed` is new; both factions consume; brief-time-verify the consumer set
- **Class 4 project-history pattern conflict** — check `01_CORE_MECHANICS.md §3` deposit-target doctrine; check `unit_state_returning.gd:31-46` seam doc; check ANCHOR_CATEGORY_TAXONOMY for civic-anchor row

Lead addresses any blockers → brief v1.0.0 → v1.1.0 → implementer dispatch.

### 3.3 §9.H3 dormant-schema first-exercise — multiple at this wave

Three dormant surfaces first-exercised:
- **RNC §5 IDropoffTarget** — Throne is the first consumer of the protocol (Wave 1A wrote the spec; Wave 1A's MineNode declined to implement; nothing has implemented it until now).
- **`sight_throne_cells = 4`** — forward-compat schema from 3A.0; Throne is first vision-source consumer.
- **`EventBus.throne_destroyed`** — entirely new signal; tested at this wave + Phase 8 consumer planned.

H3 mandates tests at each first-exercise. Track 1 + Track 3 + Track 4 all touch one or more.

### 3.4 §9.L10 canonical-pattern grep — RNC §5 dropoff lookup

Track 1 (gameplay-systems) implementing `ResourceSystem.dropoff_for_team` should `git grep "dropoff_for_team\|IDropoffTarget"` to find any existing or stub patterns. Expected: zero hits (this is the first instance). Per §9.L10 zero-canonical-consumer fallback: verify directly against RNC §5 schema declaration.

## 4. Per-track deliverables

### Track 1 — gameplay-systems-p3s3 — Throne class + RNC §5 IDropoffTarget + ResourceSystem.dropoff_for_team

**Files:**

- **`game/scripts/world/buildings/throne.gd`** (NEW) — `class_name Throne extends Building`. `kind = &"throne"`. `max_hp` read from `BalanceData.buildings[&"throne"]` per canonical pattern (existing `bldg_throne` entry at `balance.tres:213` provides `max_hp=2000.0`; no override). **RNC §5.2 canonical protocol — NOT lead's original brief:**
  - `func deposit(resource_kind: StringName, amount: int, worker: Unit) -> void` — performs the chokepoint call internally: `ResourceSystem.change_resource(team, resource_kind, amount * 100, "gather_deposit", worker)`. The amount is fixed-point internal — Throne consumes the canonical x100 form (Returning passes already-multiplied amount per existing `unit_state_returning.gd:235` pattern; Throne unwraps as-needed OR brief-team-decides at impl-time).
  - `func get_deposit_position() -> Vector3` — returns the Throne's footprint-edge position where workers visually arrive to deposit (probably `global_position + Vector3.UP * 0.5` or footprint-front midpoint; Track 1 picks the geometry).
- Joins `&"thrones"` group on `_ready` (so `ResourceSystem.dropoff_for_team` can find it).
- Emits `EventBus.throne_destroyed(team)` on HealthComponent fatal-damage path. **Signal declared at `event_bus.gd` with `@warning_ignore("unused_signal")`** per existing pattern.
- **`game/scripts/autoload/resource_system.gd`** — extend with `dropoff_for_team(team: int) -> Node3D`. Lookup via `get_tree().get_nodes_in_group(&"thrones")` filtered by team. Memoize per-team per-tick to avoid scene-tree scan every gather-deposit cycle. **Pitfall #16 MANDATORY (mirror C2.1):** the memoized return MUST `is_instance_valid()` BEFORE returning; invalidate memo on `EventBus.throne_destroyed` signal subscription. The `building_destroyed` signal does not exist yet — `throne_destroyed` is the canonical invalidation hook for this wave.
- **`game/scripts/units/states/unit_state_returning.gd`** — modify `_perform_deposit` (lines 214-243):
  - Query `ResourceSystem.dropoff_for_team(team)` → if Throne exists, call `throne.deposit(carry_kind, carry_amount, ctx.unit)` and STOP (no direct `change_resource` call this path).
  - Else fall back to current `ResourceSystem.change_resource(team, kind, amount_x100, "gather_deposit", ctx)` at line 235 (preserves test-fixture path that doesn't spawn a Throne).
  - **Walk-back geometry**: when Throne exists, the move target becomes `throne.get_deposit_position()` (not the unit's current position). Returning state's enter() / sim_tick() may need adjustment depending on existing implementation — Track 1 reads `unit_state_returning.gd:31-58` doc-block which already anticipates this seam.
  - **Critical: only ONE path calls change_resource per deposit cycle**. Mirror C1.4 explicit ask.
- **`game/scripts/autoload/event_bus.gd`** — add:
  ```gdscript
  @warning_ignore("unused_signal")
  signal throne_destroyed(team_id: int)
  ```
  per existing EventBus convention (line 22-185 — every Phase-0/1 signal has the annotation since its consumer landed later).
- **`game/scripts/main.gd`** — `_spawn_starting_buildings` (NEW) called BEFORE `_spawn_starting_units` at match start. Spawns Iran Throne at Iran-side HQ position (e.g., `Vector3(0, 0, -32)`); Turan Throne at Z=+32. Workers spawn nearby.
- **`game/scripts/autoload/turan_controller.gd`** — refine `_pick_target` per mirror C1.2:
  - **First**, query `get_tree().get_nodes_in_group(&"thrones")` filtered by `TEAM_IRAN`. If Iran Throne found AND visible to Turan via `FogSystem.is_visible_to(TEAM_TURAN, throne_pos)` → return it.
  - **Else** fall back to the existing Wave 3B "nearest visible unit" code path (`SpatialIndex.query_radius_team` + fog filter).
  - **Do NOT use `SpatialIndex.query_radius_team` for Throne lookup** — SpatialIndex tracks units only, buildings register via SceneTree groups instead. Misuse would silently return zero Thrones (the BUG-D2 shape recapitulated).

**§9.M6 log instrumentation MANDATORY:**
- `[throne] _ready team=<X> position=<pos>` at construction-complete
- `[throne] deposit_received from=<unit_id> kind=<kind> amount=<n>` (if practical to log)
- `[throne] damage_taken hp=<n>/<max>` on HealthComponent damage
- `[throne] destroyed team=<X>` on fatal damage → signal emit
- `[resource] dropoff_for_team(team=<X>) → <throne_node OR null>` (throttled, once per few seconds)
- `[turan] target_switch unit → throne` when target priority changes (only on the transition, not every tick)

**Tests:**
- `test_throne.gd` (NEW) — smoke + kind + max_hp + group membership + RNC §5 conformance + destruction signal
- `test_resource_system.gd` — `dropoff_for_team(team)` returns correct Throne / null
- `test_unit_state_returning.gd` — canonical-path uses dropoff_for_team result
- `test_match_start_spawn.gd` — Throne spawn positions correct, both factions
- Integration: `test_phase_3_throne_deposit.gd` — Kargar gathers, walks back to Throne, deposits, HUD coin counter increments

### Track 2 — world-builder-p3s2 — Throne scene + visual differentiation + footprint

**Files:**

- **`game/scenes/world/buildings/throne.tscn`** (NEW) — inherits `building.tscn`. **Pitfall #15 mandatory regression test required.** Override:
  - `MeshInstance3D.mesh` → BoxMesh `4.0 × 3.0 × 4.0` (visibly larger than Sarbaz-khaneh's 3.0×2.0×2.0)
  - Material → `StandardMaterial3D` with `albedo_color = Color(0.85, 0.7, 0.3)` (gold accent)
  - `CollisionShape3D.shape` → BoxShape3D matching the new mesh footprint (Pitfall #15 regression test target)
  - `NavigationObstacle3D` → match new footprint (workers can't path through)
- **`game/scripts/world/buildings/ghost_placement_preview.gd`** (if relevant) — Throne is NOT player-buildable, so build-menu probably doesn't list it; verify the ghost-preview system handles "no Throne placement" cleanly.
- **`game/data/text/strings.csv`** — add `BLDG_THRONE_NAME` (English: "Throne"; Persian later per UI primary-name convention).

**§9.M6 log instrumentation:**
- Scene loads silently; no scene-level log needed. (Throne's class is the log surface.)

**Tests:**
- `test_throne_scene.gd` (NEW per Pitfall #15 + §9.F4 in-either-direction-discipline) — instantiate scene + walk to override targets + assert mesh size (e.g., `box.size.x == 4.0` — diverges from base `2.0` in both directions catch both wrong-syntax failure modes) + CollisionShape match + NavigationObstacle3D presence + material gold-accent assertion.

### Track 3 — balance-engineer-p3s3 — BalanceData throne acknowledgment + tuning

**Mirror C1.3 finding:** `bldg_throne` ALREADY EXISTS at `balance.tres:213-219` with `max_hp=2000.0, coin_cost=0, grain_cost=0, construction_ticks=0, farr_per_tick=0.0` AND is already wired into the `buildings` dict at `balance.tres:698`. **Track 3's job is verification + acknowledgment, not new-entry.**

**Files:**

- **`game/data/balance.tres`** — VERIFY existing `bldg_throne` entry holds. **No changes expected unless balance-engineer determines max_hp 2000 is wrong** (lead defers to balance-engineer's judgment; brief's original 5000 was lead-invention). If a tuning change IS warranted, balance-engineer ships a single-line tres edit with rationale comment.
- **`game/data/balance_data.gd`** — VERIFY `bldg_throne` is consumable from `BalanceData.buildings[&"throne"]` lookup. No changes expected.
- **No new fields needed** — existing schema covers the wave's needs (max_hp, coin_cost=0, grain_cost=0, construction_ticks=0).

**§9.M6 log instrumentation:** none (data-only file).

**Tests:**
- `test_balance_data.gd` — assert `bldg_throne.max_hp == 5000`, costs == 0.

### Track 4 — shahnameh-loremaster-p3s5 — anchor-category classification + cultural-note prose (ALREADY SHIPPED at brief-time review 2026-05-24)

**Status: COMPLETE pre-implementation.** Loremaster's brief-time review (2026-05-24) delivered both deliverables. Lead green-lit; loremaster ships taxonomy doc as separate Track 4 commit on this branch before gp-sys's Track 1 dispatch.

**Outcomes:**

- **Anchor-category resolution:** loremaster walked through each of the four existing anchor-categories and rejected each (civic-anchor: Throne not replicable + not productive-stewardship-shaped; labor-organization: Throne not a buff-emitter; identity-bearing-institutional: Throne does NOT produce named-arm units + at different level of abstraction; sacral-emitter: Throne is *terminus* of legitimacy, NOT *source-emitter*; sacral-emitter has continuous passive emit, Throne has none).
- **NEW fifth anchor-category proposed: `sovereignty-bearing institution`.** Mechanical shape: singular per faction + terminal-stakes + IDropoffTarget + high HP + spawns workers + tier-transition convertible. Cultural shape: institutional CENTER of the realm; condition-of-possibility for institutions; loss = civilizational defeat.
- **Sub-slot axis: tier-progression of the seat (CONVERSION, not new-instance placement)** — Throne → Qal'eh → Royal Court. This is structurally distinct from sub-slot specialization in other anchor-categories.
- **Cross-faction NEAR-symmetry hypothesis** — the ONE anchor-category where Iran and Turan share structurally-symmetric building (different cultural register, same anchor-shape). OPPOSITE of structural-mismatch pattern of other four categories.
- **J2 trichotomy graduates** — 3-of-3 outcomes empirically produced (clone-check×0, slot-fit-verify×2, taxonomy-growth-required×3). Lead codifies graduation in STUDIO_PROCESS §9.J at session-8 retro PR.

**Files (loremaster ships as separate Track 4 commit):**

- **`docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.0.0 → v1.1.0**: 5 edits (§1.5 new category, §4.1 row, §4.2 Qal'eh row + RESOLVED prose, §5 Turan near-symmetry exception, §7 changelog + frontmatter version bump).
- **Cultural-note 4-part prose** (delivered in SendMessage; lead pastes at gp-sys's Track 1 Commit-1.5 per established Wave 2A.5 / 2B pattern; verbatim).

**Track 1 (gp-sys) gets cultural-note paste at Commit-1.5 — same pattern as Wave 2A.5 / 2B.**

**§9.M6 log instrumentation:** none (no code shipped by this track).

**Tests:** N/A (cultural-note prose; reviewed by other reviewers, not code-tested).

### Standby — engine-architect-p3s2, ui-developer-p3s3

Engine-architect: standby for `throne_destroyed` signal-emission timing verification (it's combat-phase emit; combat is phase 6 of 8; want to confirm emit-ordering doesn't conflict with cleanup phase fog-freeze when Wave 3A.7 ships).

UI-developer: standby for HUD-side Throne health bar (probably defer to Phase 4 polish; flag if it's a brief-add).

## 5. Wave-shape — sequential-shared-tree per §9.E1

Shared surfaces touched:
- `event_bus.gd` (Track 1 adds signal)
- `resource_system.gd` (Track 1 extends)
- `main.gd` (Track 1 extends spawn)
- `unit_state_returning.gd` (Track 1 modifies)
- `balance.tres` (Track 3 extends)
- `balance_data.gd` (Track 3 extends)

**Coordination shape:** §9.E1 Tier 1 default — sequenced commits on same branch. Tracks 1+2+3 dispatch in parallel; Track 1 likely ships first (largest scope + gates Track 2's scene tests that may reference Track 1 class). Track 4 (loremaster) writes prose to be pasted at Track 1 commit-1.5 time per established Wave 2A.5/2B pattern. **Coupled-test-gate expected** — joint or sequenced commit per gp-sys / world-builder / balance-engineer's tier-1 default.

## 6. Wave-close criteria

- [ ] `throne.gd` + `throne.tscn` shipped; visibly larger + gold accent
- [ ] Both factions spawn a Throne at match start (positions per main.gd)
- [ ] Workers walk back to Iran Throne to deposit; HUD coin/grain counter increments
- [ ] `ResourceSystem.dropoff_for_team(team)` returns correct Throne / null
- [ ] `EventBus.throne_destroyed(team_id)` signal emits on Throne death
- [ ] TuranController prioritizes Iran Throne over units when both visible
- [ ] FogSystem registers Throne as static vision source with sight_throne_cells=4
- [ ] **§9.M6 log instrumentation present**: `[throne]` spawn/deposit/damage/destroyed; `[resource]` dropoff_for_team; `[turan]` target_switch
- [ ] Full headless test suite passes (~1499 baseline + 15-25 new tests)
- [ ] Pre-commit gate green
- [ ] Live-test (lead-driven): start match → see Iran + Turan Thrones spawn → workers gather + walk to Throne + deposit → HUD updates → wait 120s+ → Turan probe-attacks the Iran Throne, not random units → can the player destroy the Turan Throne? (yes, by manual unit commands)
- [ ] ARCHITECTURE.md v0.33.2 → v0.34.0 close entry
- [ ] BUILD_LOG session-8 entry

## 7. Hand-off after Throne wave

- **Phase 3 closes.** Major scope: Economy + Dummy AI + Fog Data Layer all shipped.
- **Phase 4 opens.** First wave candidates: production queue UI; tech-tier advancement; full Farr generator/drain set; Khaneh population_cap fully wired through ResourceSystem.
- **Phase 5 prep:** Throne becomes the natural target of Kaveh Event rebels (their goal is destabilizing the Iran king's authority — destroying the Throne is the extreme expression).
- **Phase 8 prep:** `EventBus.throne_destroyed` consumer = win/lose screen. Forward-compat seam ready.

---

## 8. Brief revision history

**v1.0.0 → v1.0.1 (2026-05-24)** — mirror-reviewer brief-time review (second dispatch of agent shipped at session-7 close) surfaced 4 blockers + 5 risks + 4 verified surfaces. All 9 substantive findings folded into this revision:

| Finding | Disposition |
|---|---|
| **C1.1** RNC §5 protocol shape — `deposit()` + `get_deposit_position()` canonical (NOT lead's invented `is_dropoff_target_for` / `get_dropoff_position`) | §1 + §4 Track 1 corrected to canonical API. |
| **C1.2** TuranController target-pick via SceneTree group `&"thrones"`, NOT SpatialIndex.query_radius_team (buildings aren't agents) | §1 + §4 Track 1 corrected. Anti-misuse warning added. |
| **C1.3** `bldg_throne` ALREADY exists at `balance.tres:213` with `max_hp=2000` (lead's `5000` was unsupported override) | §1 + §4 Track 3 corrected — Track 3 is verification not new-entry. max_hp=2000 honored per §9.L1 spec-wins. |
| **C1.4** Deposit-routing ambiguity (who calls `change_resource`) | §1 + §4 Track 1 disambiguated: Throne.deposit() owns the chokepoint call internally per RNC §5.2 canonical pattern; Returning delegates by calling `throne.deposit(...)`. ONLY ONE path per cycle. |
| **C2.1** Pitfall #16 `is_instance_valid` guard on `dropoff_for_team` memoized return | §1 + §4 Track 1 mandated. Memo invalidation on `throne_destroyed` signal. |
| **C2.2** `@warning_ignore("unused_signal")` annotation on `throne_destroyed` signal declaration | §4 Track 1 code snippet shows full annotation per EventBus convention. |
| **C3.1** Anchor-category — lead does NOT pre-assign; loremaster classifies | §1 + §4 Track 4 corrected. civic-anchor recognized as occupied (Khaneh/Mazra'eh); Throne likely sacral-emitter or identity-bearing-institutional. |
| **C4.1** Prose: HUD increments already fire today; what changes is walk geometry + RNC §5 routing | §0 prose rewritten to accurately distinguish "wired-but-inline" from "walk-back-via-Throne." |
| **C4.3** Reading-order pointer: §3 doesn't doctrine Throne-deposit; §1 + §2 + §5 do | §2 reading order corrected. |

**Mirror's 4 verified surfaces** (no change): FogSystem.register_vision_source 4-arg signature; EventBus.sim_phase signal canonical; sight_throne_cells=4 schema; Building base hooks.

*Status: v1.0.2 — POST-MIRROR + POST-LOREMASTER 2026-05-24 by lead. Both brief-time reviews complete. Ready for implementer dispatch (gp-sys Track 1 + world-builder Track 2 + balance-engineer Track 3) immediately upon loremaster's taxonomy doc commit landing. Throne wave is the **second wave to use mirror-reviewer + first wave to use loremaster-classification-blocking-implementer-dispatch** — both disciplines empirically validated this session.*
