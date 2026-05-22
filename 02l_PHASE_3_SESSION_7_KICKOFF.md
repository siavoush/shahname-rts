---
title: Phase 3 Session 7 — Wave 3A.0 Fog Data Layer Kickoff
type: plan
status: draft
version: 1.0.0
owner: team-lead
summary: Wave 3A.0 kickoff — fog-of-war DATA LAYER (FogConfig + FogSystem autoload + grid + storage + consumer API stub returning static data + sim_clock.gd phase patch + SIM_CONTRACT v1.5.0 addendum). Wave 3A SPLIT into 3A.0 (this wave, data + consumer API stub) + 3A.5 (next wave, vision sources + per-tick recompute). Split rationale from world-builder-p3s2 pre-flight verdict — ships consumer-visible API surface now so gp-sys (Phase-5 Kaveh) + ai-engineer (Phase-6 scout / Wave 3B DummyAI) can write against it in parallel with 3A.5's source-side implementation.
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, docs/FOG_DATA_CONTRACT.md, docs/ARCHITECTURE.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, FOG_DATA_CONTRACT.md, SIMULATION_CONTRACT.md, docs/AGENT_REGISTRY.md, docs/ANCHOR_CATEGORY_TAXONOMY.md]
ssot_for:
  - Wave 3A.0 scope (data layer + consumer API stub; vision-source registration explicitly DEFERRED to Wave 3A.5)
  - Per-track deliverables for Wave 3A.0
  - Wave 3A.0 vs 3A.5 split decision-record
tags: [phase-3, session-7, wave-3a-0, fog-of-war, kickoff, data-layer]
created: 2026-05-22
last_updated: 2026-05-22
---

# Phase 3 Session 7 — Wave 3A.0 Fog Data Layer Kickoff

## 0. Why this doc exists

Wave 3A.0 ships the **fog-of-war data layer + consumer API stub** per `docs/FOG_DATA_CONTRACT.md` v1.3.1 (ratified Phase 3 session 2, holds clean at HEAD per world-builder-p3s2's session-7 pre-flight verdict). This is the FIRST half of a 2-wave split.

**Why split:** world-builder-p3s2's session-7 pre-flight verdict identified two naturally coherent ship-units:

- **Wave 3A.0 (this wave)** — DATA LAYER ONLY. FogConfig + FogSystem autoload grid init + `_currently_visible` / `_ever_seen` storage + `world_to_cell` / `cell_to_world_center` helpers + consumer API (`is_visible_to`, `get_last_seen`, `get_scout_candidates`) **returning static data** (always-false / empty / unexplored) + `_sources` registry structure (empty) + sim_clock.gd phase patch + SIM_CONTRACT v1.5.0 addendum.
- **Wave 3A.5 (next wave)** — VISION SOURCES + PER-TICK RECOMPUTE. `register_vision_source` / `deregister_vision_source` implementation + `fog_update` phase handler + `cleanup` death-freeze + replace 7-building `sight=0` forward-compat call-sites with BalanceData reads + unit-side registration + EventBus subscriptions.

**Blast-radius hedge:** if Wave 3A.5 hits phase-ordering complications, Wave 3A.0 is already shipped + consumer contracts are not blocked. gp-sys (Phase-5 Kaveh consumer) + ai-engineer (Phase-6 scout / Wave 3B DummyAI consumer) can start parallel development against the static-data API.

**Pre-flight verdict source:** world-builder-p3s2 SendMessage delivered at session-7 startup (2026-05-22). Single-author pre-flight per FOG_DATA_CONTRACT ownership; no consumer-side concerns raised that needed gp-sys / ai-engineer multi-agent escalation.

## 1. Reading order (≈8 minutes for active-context agents)

1. **`MANIFESTO.md`** — if your persistent context has rotated.
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: §9.D (Commit + Workspace — especially **§9.D9** pre-commit self-review + **§9.D7(b)** broadcast-on-observe-cross-track-WIP, NEW session-6), §9.G (Channel discipline + addressable-name registry), §9.M (Test discipline).
   - world-builder: §9.H1 (cross-cutting schema verification triangulated) + **§9.L8** (drift-proof UI numeric defaults — NEW session-6) + **§9.L9** (fallback-by-failure-visibility-shape — NEW session-6).
   - balance-engineer: **§9.H3** (first-exercise-of-dormant-schema) + **§9.L6** (forward-compat-guard-sweep) + **§9.L1** (multi-agent codification — NEW session-6).
   - engine-architect: §9.C1 (SSOT discipline) + §9.I1 (engine-feature runtime verification).
3. **`docs/FOG_DATA_CONTRACT.md` v1.3.1** — the source-of-truth for everything Wave 3A.0 ships. Pay attention to §1 (Grid schema), §2.1 (Registration API — the surface; implementation deferred to 3A.5), §5 (Consumer API — stub returns static data this wave), §6 (LATER-fog-N annotations — deferred items remain deferred).
4. **`docs/ARCHITECTURE.md` §6 v0.29.0** — session-6 close retro (covers H3/L6/L7/L8/L9/D7b/M3/E1/F4/G1/L1 changes you'll apply).
5. **`docs/SIMULATION_CONTRACT.md`** current version — engine-architect Track 3 patches this with v1.5.0 phase-array addendum.
6. **`docs/AGENT_REGISTRY.md` v1.0.0** — addressable-name verification before any SendMessage.

## 2. Wave shape — `sequential-shared-tree` mode (per §9.E1)

Wave 3A.0 touches the following shared surfaces:
- `game/scripts/autoload/fog_system.gd` (NEW file — world-builder)
- `game/data/sub_resources/fog_config.gd` (NEW file — world-builder OR balance-engineer; lead's call: **world-builder owns the class definition; balance-engineer owns the .tres values**).
- `game/data/balance_data.gd` (add `.fog` field — balance-engineer).
- `game/data/balance.tres` (add `fog_config` sub-resource — balance-engineer).
- `game/scripts/autoload/sim_clock.gd` (one-line PHASES patch — engine-architect).
- `docs/SIMULATION_CONTRACT.md` (v1.5.0 addendum — engine-architect).
- `project.godot` (FogSystem autoload registration — world-builder).

**3 implementation tracks across 3 agents.** Sequential-shared-tree mode per §9.E1; pre-commit-suite-gate-coupling race surface understood + §9.E1 parallel-WIP-addendum + §9.D7(b) workspace-observation discipline both apply.

## 3. Brief-time application of session-5+6 disciplines

### 3.1 §9.H3 first-exercise-of-dormant-schema call-outs

Wave 3A.0 introduces three dormant-schema surfaces that will be CONSUMED at Wave 3A.5:

| Surface | First-populated at Wave 3A.0 | Deferred consumer (Wave 3A.5) |
|---|---|---|
| `BalanceData.fog` sub-resource + `FogConfig` class | balance-engineer Track 2 + world-builder Track 1 (class definition + values) | FogSystem.register_vision_source reads `sight_<kind>_cells` from this surface at 3A.5 |
| `FogSystem._sources` dictionary | world-builder Track 1 (empty dict structure) | register/deregister populates at 3A.5 |
| `fog_update` SimClock phase | engine-architect Track 3 (phase added to array; no handler yet) | FogSystem connects on phase at 3A.5 |

**Brief-time call-out per §9.H3:** all 3 surfaces are intentionally-dormant first-exercises. **Named cross-track verifier:** lead synthesizes Wave 3A.5 kickoff brief against these 3 surfaces (each is a 3A.5 trigger condition). Wave 3A.0 ships the producer side; Wave 3A.5 ships the consumer side.

### 3.2 §9.L6 forward-compat-guard-sweep for FogSystem dormant API

The 7 existing Building subclasses (Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh / Atashkadeh / Sowari-khaneh / Tirandazi) all have `FogSystem.has_method(&"register_vision_source")` forward-compat guards in their `_on_placement_complete` hooks. These call-sites currently no-op (FogSystem doesn't exist).

**At Wave 3A.0 ship time:** FogSystem will autoload and `has_method(&"register_vision_source")` will return `true` (method exists in 3A.0 as a stub that does nothing OR is not-yet-implemented). **The 7 call-sites will start calling into a stub.** That's intentional — the stub returns silently; visibility is still all-false (consumer API stub) so no visible behavior change for the player.

**L6 sweep — world-builder Track 1 documents in commit message:** `git grep -n 'register_vision_source\|FogSystem' game/scripts/` enumerates the 7 existing readers + any others. Verify all readers handle the new-but-stubbed API correctly (callable, returns nothing observable).

### 3.3 §9.L8 + §9.L9 dogfood at FogConfig surface

balance-engineer Track 2 ships `FogConfig` sub-resource entry. Any UI surface displaying fog values (likely none at 3A.0; possibly a debug overlay at 3A.5) should follow **§9.L8 drift-proof default** (read from BalanceData, not hardcoded). FogConfig fallback constants in any static helpers follow **§9.L9 fallback-by-failure-visibility-shape** discipline.

For 3A.0: no UI surface yet, so L8/L9 are dormant-applies — flag in commit message that the discipline will apply at 3A.5 / debug-overlay time.

## 4. Per-track deliverables

### Track 1 — world-builder-p3s2 (FogSystem autoload + FogConfig class + project.godot)

**Single commit per §9.D3.** Files:

1. **`game/scripts/autoload/fog_system.gd`** (NEW) — FogSystem singleton class.
   - `_ready()`: grid init reading `WorldGrid.map_bounds` IF WorldGrid autoload exists; ELSE fallback `Rect2(Vector2.ZERO, Vector2(256, 256))` constant per FOG_DATA_CONTRACT §1 "~256m × 256m playing field". Cell size from `BalanceData.fog.cell_size_meters` (with `_FALLBACK_CELL_SIZE = 4.0` per §9.L9 — non-zero match-shipped fallback).
   - Storage: `_currently_visible: PackedByteArray` + `_ever_seen: PackedByteArray` (both per-team; size = grid_w × grid_h). Init all-false.
   - `_sources: Dictionary` — empty structure ready for 3A.5 population.
   - Helpers: `world_to_cell(world_pos: Vector3) -> Vector2i`, `cell_to_world_center(cell: Vector2i) -> Vector3`, `_cell_index(cell: Vector2i) -> int`. Boundary clamping per §1.3.
   - **Consumer API stubs (return static data):**
     - `is_visible_to(team_id: int, world_pos: Vector3) -> bool` — returns `false` at 3A.0 (no sources registered; cell never visible).
     - `get_last_seen(entity_id: int) -> Dictionary` — returns `{}` (empty) at 3A.0.
     - `get_scout_candidates(team_id: int, max_results: int) -> Array[Vector3]` — returns first `max_results` cells from grid as unexplored. At 3A.0 this returns the unexplored-cells slice since `_ever_seen` is all-false.
     - `register_vision_source(node, team, sight_radius_cells, is_static)` — stub method that exists (so `has_method` returns true) but no-ops. Document inline that 3A.5 implements; 3A.0 stub is intentional.
     - `deregister_vision_source(handle)` — same stub pattern.
   - Per §9.D9 pre-commit self-review + per §9.D7(b) workspace-observation if relevant + per §9.M4 `.new()` test discipline.

2. **`game/data/sub_resources/fog_config.gd`** (NEW) — FogConfig Resource class.
   - `@export var cell_size_meters: float = 4.0` (per FOG_DATA_CONTRACT §2.2; balance-engineer's call on actual value).
   - `@export var sight_khaneh_cells: int = 0` (placeholder; 3A.5 uses for register).
   - `@export var sight_mazraeh_cells: int = 0`, `sight_madan_cells: int = 0`, `sight_sarbazkhane_cells: int = 3`, `sight_atashkadeh_cells: int = 2`, `sight_sowari_khaneh_cells: int = 2`, `sight_tirandazi_cells: int = 2` (per FOG_DATA_CONTRACT §2.2 table + balance-engineer's call on Tier-2 building sights).
   - `@export var sight_kargar_cells: int = 4`, `sight_piyade_cells: int = 5`, `sight_kamandar_cells: int = 6`, etc. per §2.2 + balance-engineer's call.
   - **§9.L9 fallback semantics:** non-zero defaults match what 3A.5 + 7 buildings actually need; no silent-zero.

3. **`project.godot`** — add `FogSystem="*res://scripts/autoload/fog_system.gd"` to `[autoload]` section per the contract's §6 file location.

4. **Tests:**
   - `game/tests/unit/test_fog_system.gd` — grid init from BalanceData + fallback; `world_to_cell` / `cell_to_world_center` round-trips; `_cell_index` symmetry; boundary clamping; consumer API stubs (returns static data); `register_vision_source` / `deregister_vision_source` exist as callable stubs.
   - `game/tests/unit/test_fog_config.gd` — FogConfig resource loads; default values present.

**Per §9.D9:** Step 2 sub-step (verb-claim grep) — verify `WorldGrid` autoload existence at HEAD; if absent, fallback path triggers; document in commit. Step 3 H3 self-check — yes, FogSystem first-populates the dormant API surface; deferred-consumer chain (Wave 3A.5) documented per §3.1 above. Step 3 lens-walk N/A shorthand may apply to godot-code-reviewer + loremaster lenses (data-layer + no cultural surface).

### Track 2 — balance-engineer-p3s3 (FogConfig values in BalanceData)

**Single commit per §9.D3.** Files:

1. **`game/data/balance_data.gd`** — add `@export var fog: FogConfig` field after existing sub-resource exports (`farr`, `combat`, `economy`, `ai`). Documentation comment explains:
   - Wave 3A.0 ships the FogConfig sub-resource with PLACEHOLDER sight radii.
   - Wave 3A.5 consumers (register_vision_source call-sites in 7 buildings) read `BalanceData.fog.sight_<kind>_cells` to populate vision-source registrations.
   - **H3 dormant-schema first-exercise:** the field ships dormant at Wave 3A.0 (FogSystem stub no-ops register calls); first-populated by Wave 3A.5 consumers.

2. **`game/data/balance.tres`** — add `fog_config` sub-resource entry with FogConfig class binding + Wave-3A.0 placeholder values:
   - `cell_size_meters = 4.0` (per FOG_DATA_CONTRACT §1.1 + §2.2 table).
   - Per-kind sight radii per the contract's §2.2 table (Atashkadeh = 2; Sarbaz-khaneh = 3; Kargar = 4; Piyade = 5; Kamandar = 6; etc.). **L1 spec-wins applies**: verify §2.2 table at HEAD; cite if you override any value.
   - **`load_steps` counter** bump per the existing balance.tres pattern (the load_steps counter was flagged at session-6 retro as possibly-unnecessary busywork; until that investigation closes, maintain it per existing convention).

3. **Tests:** balance.tres-load test should pass (no separate file needed if existing test_balance_data.gd already covers SubResource load); add 2-3 sanity assertions for `bd.fog.cell_size_meters > 0` + `bd.fog.sight_atashkadeh_cells == 2` (or whatever you ratify) + `bd.fog.sight_sarbazkhane_cells == 3`.

**Per §9.D9:** Step 3 architecture-reviewer lens — H3 + L6 dogfood. Document `git grep -n 'fog_config\|BalanceData.fog' game/scripts/` sweep result in commit message (expect zero consumer-side readers at 3A.0 — they ship at 3A.5). L1 lens — verify §2.2 sight-radius table at HEAD; cite if any value diverges from spec.

### Track 3 — engine-architect-p3s2 (sim_clock.gd phase patch + SIM_CONTRACT v1.5.0 addendum)

**Single commit per §9.D3.** Files:

1. **`game/scripts/autoload/sim_clock.gd`** — one-line patch to `PHASES` const per FOG_DATA_CONTRACT §4.4:

```gdscript
const PHASES: Array[StringName] = [
    &"input", &"fog_update", &"ai", &"movement", &"spatial_rebuild",
    &"combat", &"farr", &"cleanup",
]
```

Insert `&"fog_update"` between `&"input"` and `&"ai"`. This adds the phase NAME to the phase array; no handler is wired at 3A.0 (FogSystem registers handler at 3A.5). The phase fires per tick but does nothing observable.

2. **`docs/SIMULATION_CONTRACT.md`** — v1.X → v1.5.0 MINOR bump. Add §X addendum documenting:
   - `fog_update` phase position in array (between `input` and `ai`).
   - Rationale: vision must be recomputed BEFORE AI sees the world (per FOG_DATA_CONTRACT §4 phase-ordering).
   - At Wave 3A.0: phase exists but no-ops (no handlers connected). At Wave 3A.5: FogSystem connects to phase + recomputes per tick.
   - Cross-reference FOG_DATA_CONTRACT §4 as canonical for phase-ordering.

3. **Test:** `test_sim_clock.gd` (if it exists) — add assertion that `&"fog_update"` is in `PHASES` array at index between `&"input"` and `&"ai"`. If file doesn't exist, ship a minimal new test.

**Per §9.D9:** Step 3 architecture-reviewer lens — C1 SSOT discipline applies (SIMULATION_CONTRACT.md is canonical for SimClock phase-array; FOG_DATA_CONTRACT.md references it). C1 BLOCKING-refinement: if there's any contradiction between FOG_DATA_CONTRACT §4.4 prose and the actual sim_clock.gd patch, resolve empirically (not deferred to LATER). Step 2 verb-claim grep sub-step: verify no existing handler currently expects pre-input fog state (none should exist; if any do, surface as blocker).

## 5. Workflow per track — canonical anti-loop dispatch cycle (per §9.D2)

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
10. THEN report back via SendMessage with SHA + delta summary.
```

## 6. Wave-close + live-test gate

After Tracks 1-3 ship: lead drafts wave-close commit (ARCHITECTURE.md §6 v0.30.0 entry + §2 row update for fog system + BUILD_LOG entry).

**§9.M2 live-test note:** Wave 3A.0 is data-layer-only. Live-test #1 verifies (a) game still launches with FogSystem autoload registered, (b) no crashes from sim_clock.gd phase array change, (c) no behavioral change visible to player (fog is invisible at 3A.0). Wave 3A.5 is when live-test actually exercises fog behavior (vision-cone reveals, building footprint reveals, death-freeze). Lead's live-test #1 at 3A.0 close is brief — just confirm nothing breaks.

## 7. Dispatch addresses (verified per `docs/AGENT_REGISTRY.md` v1.0.0)

- **world-builder-p3s2** — Track 1 (FogSystem + FogConfig class + project.godot autoload)
- **balance-engineer-p3s3** — Track 2 (FogConfig values + BalanceData.fog field)
- **engine-architect-p3s2** — Track 3 (sim_clock.gd phase + SIM_CONTRACT v1.5.0 addendum)

**No ai-engineer involvement at Wave 3A.0** — they're the Phase-6 scout consumer; they don't ship anything at 3A.0. ai-engineer Agent-spawn deferred to Wave 3B (DummyAIController) per session-7 prioritization queue.

**No gp-sys-p3s3 involvement at Wave 3A.0** — they're the Phase-5 Kaveh consumer; they don't ship anything at 3A.0. Wave 3A.5 will pull gp-sys in for unit-side FogSystem registration (`unit.gd` `_ready` registration + death-path deregister).

## 8. Open questions to flag at brief-time (NONE EXPECTED)

- **WorldGrid existence:** world-builder pre-flight flagged uncertainty. Track 1 ships fallback constant in `_ready` — covers either case.
- **`load_steps` counter:** flagged at session-6 retro as possibly-unnecessary busywork. balance-engineer maintains per existing convention at Wave 3A.0; investigation deferred to follow-up.

## 9. Sign-off

This brief is the kickoff artifact. Lead commits this brief, then dispatches Tracks 1-3 in parallel (zero file overlap between tracks; sequential-shared-tree mode per §9.E1; pathspec discipline + per-tick commits per §9.D3 + §9.D4 hold).

— team-lead, Phase 3 session 7 kickoff (2026-05-22)
