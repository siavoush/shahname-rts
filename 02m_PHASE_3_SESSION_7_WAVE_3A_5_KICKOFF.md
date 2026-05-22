---
title: Phase 3 Session 7 — Wave 3A.5 Fog Vision Sources + Per-Tick Recompute Kickoff
type: plan
status: draft
version: 1.0.0
owner: team-lead
summary: Wave 3A.5 kickoff — the consumer half of the Wave 3A SPLIT. Implements the producer side that Wave 3A.0's stubs left dangling — vision-source registration (`register_vision_source` / `deregister_vision_source`), the `fog_update` Pass 1 per-tick recompute, real `is_visible_to`, and the 7-building + unit-side call-site sweep replacing the forward-compat `sight=0` stubs with `BalanceData.fog.sight_<kind>_cells` reads. Memory-side features (`get_last_seen` real impl + cleanup-phase death-freeze + `get_scout_candidates` real impl + new EventBus signals) are explicitly deferred to a follow-up (3A.7) since Wave 3A.0's API stubs already unblock Wave 3B DummyAI consumers.
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, docs/FOG_DATA_CONTRACT.md, docs/ARCHITECTURE.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, FOG_DATA_CONTRACT.md, SIMULATION_CONTRACT.md, docs/AGENT_REGISTRY.md, 02l_PHASE_3_SESSION_7_KICKOFF.md]
ssot_for:
  - Wave 3A.5 scope (vision sources + Pass 1 fog_update recompute + is_visible_to real + 7-building + unit call-site sweep; memory features explicitly DEFERRED to 3A.7)
  - Per-track deliverables for Wave 3A.5
  - Joint-commit-by-default expectation per world-builder-p3s2's §9.E1 ordering refinement (3A.0 close-retro carry-forward)
tags: [phase-3, session-7, wave-3a-5, fog-of-war, kickoff, vision-sources, per-tick-recompute]
created: 2026-05-22
last_updated: 2026-05-22
---

# Phase 3 Session 7 — Wave 3A.5 Fog Vision Sources + Per-Tick Recompute Kickoff

## 0. Why this doc exists

Wave 3A.5 ships the **vision sources + per-tick recompute** half of the Wave 3A SPLIT per `02l_PHASE_3_SESSION_7_KICKOFF.md` §0. Wave 3A.0 (PR #32, merged at `fe01373`) shipped the data layer + consumer API stubs returning static data; this wave wires the producers (units + buildings) and implements the real `fog_update` Pass 1 recompute so `is_visible_to` returns truth instead of always-false.

### What 3A.5 SHIPS (MVP scope)

| Surface | Wave 3A.0 state | Wave 3A.5 state |
|---|---|---|
| `FogSystem.register_vision_source` | no-op stub | **real impl** — populates `_sources[handle]` with team + radius + (for static) cached footprint cells |
| `FogSystem.deregister_vision_source` | no-op stub | **real impl** — idempotent removal from `_sources` |
| `FogSystem._sources` | empty `{}` | live registry |
| `fog_update` phase handler | unwired | **wired** — Pass 1: clear `_currently_visible`, integer-circle visibility computation for each source, write `_currently_visible` + `_ever_seen` |
| `FogSystem.is_visible_to` | returns `false` | **returns from real `_currently_visible[team][cell]`** |
| 6 building call-sites (atashkadeh, mazra'eh, madan, sarbaz_khaneh, sowari_khaneh, tirandazi) | `register_vision_source(self, team, 0, true)` (sight=0 placeholder) | **`BalanceData.fog.sight_<kind>_cells`** read per kind |
| Khaneh call-site | **missing entirely** | **added** — register on `_on_placement_complete` per other 6 |
| `unit.gd` `_ready` | no FogSystem call | **register_vision_source(self, team, BalanceData.fog.sight_<kind>_cells, false)** + store handle |
| `unit.gd` death path | no FogSystem call | **deregister_vision_source(handle)** before `queue_free` |

### What 3A.5 EXPLICITLY DEFERS (to a possible 3A.7 follow-up)

- **`cleanup` phase Pass 2 — death-freeze** (`unit_health_zero` subscription + `_last_seen_by_team` sealing). Phase 5 Kaveh consumer; not blocking Wave 3B.
- **`get_last_seen` real impl** + `_last_seen_by_team` population during fog_update. Still returns `{}` stub. Phase 5 consumer; not blocking Wave 3B.
- **`get_scout_candidates` real impl** + `_unexplored_cells` sparse set maintenance. Phase 6 consumer; Wave 3B DummyAI is fine with stub (returns unexplored slice already).
- **New EventBus signals** (`fog_visibility_changed`, `fog_cell_first_seen`). UI consumers are Phase 5.

**Rationale for the further split:** the MVP scope above is what's actually needed to unblock Wave 3B (DummyAI uses `is_visible_to` only). Memory-side features are downstream consumers in Phase 5 + Phase 6 — they should land when those phases land, not speculatively now. Per MANIFESTO principle 6 (build what's needed, not what's elegant).

## 1. Reading order (≈10 minutes for active-context agents)

1. **`MANIFESTO.md`** — if your persistent context has rotated.
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: §9.D7(b) broadcast-on-observe-cross-track-WIP, §9.E1 sequential-shared-tree mode, §9.M3 retry-once-before-broadcasting, §9.L9 fallback-by-failure-visibility-shape.
   - world-builder: §9.H1 cross-cutting schema verification, §9.L8 drift-proof defaults, **§9.E1 carry-forward — joint-commit-first per your own post-3A.0 framing** (see §3.1 below).
   - gameplay-systems: §9.H3 first-exercise-of-dormant-schema (unit-side register is the FIRST consumer of `BalanceData.fog.sight_<kind>_cells`).
   - balance-engineer: §9.L1 multi-domain codification, optional cycle-tune at wave-close if numbers feel off.
3. **`docs/FOG_DATA_CONTRACT.md` v1.3.1** — re-read **§2.1** (Registration API), **§3.1** (Per-tick recompute — the integer-circle formula), **§3.2** (Building footprint reveal — uses `Building.get_footprint_aabb()` already shipped), **§4.2** (Pass 1 phase semantics), **§5.1** (is_visible_to real impl), **§6 LATER-fog-3** (Phase 3 building registration uses **group-iteration fallback**, NOT `building_placed` signal — the signal's `unit_id` is the placer worker, not the building).
4. **`docs/ARCHITECTURE.md` §6 v0.30.0** — Wave 3A.0 close (covers what's already shipped on the producer side).
5. **`game/scripts/autoload/fog_system.gd`** — read the stub structure shipped in Wave 3A.0; you're filling in the bodies.
6. **`docs/AGENT_REGISTRY.md` v1.0.0** — addressable-name verification before any SendMessage.

## 2. Wave shape — `sequential-shared-tree` mode (per §9.E1)

Wave 3A.5 touches the following shared surfaces:

- `game/scripts/autoload/fog_system.gd` (world-builder — fill in registration + fog_update handler + real `is_visible_to`).
- `game/scripts/world/buildings/{atashkadeh,madan,mazraeh,sarbaz_khaneh,sowari_khaneh,tirandazi}.gd` (world-builder — replace `0` with BalanceData reads).
- `game/scripts/world/buildings/khaneh.gd` (world-builder — ADD the missing call-site).
- `game/scripts/units/unit.gd` (gameplay-systems — add `_ready` register + death-path deregister).
- 7 building tests + unit tests + new fog_update integration tests (joint with above).

**2 implementation tracks across 2 agents** — world-builder owns the FogSystem internals + building call-site sweep; gameplay-systems owns the unit-side. **Coupled test gate:** Track 2's unit.gd will exercise FogSystem.register_vision_source real impl on every spawned unit; once Track 1 lands, Track 2 cannot ship in isolation if Track 1 isn't ready. **Joint-commit-by-default expectation per §3.1.**

## 3. Brief-time application of session-7 carry-forwards

### 3.1 §9.E1 ordering refinement — joint-commit first (world-builder's 3A.0 post-delivery framing)

**Carry-forward from Wave 3A.0 retro candidates (Task #195):** world-builder-p3s2's post-delivery framing — *"§9.E1 [blocked]-broadcast + State-3 surface are correct signaling behaviors, but they're load-bearing only when the joint-commit path isn't available. Ordering precedence is: (1) can I resolve via joint commit? (2) if not, broadcast [blocked] and wait."*

**For Wave 3A.5:** **default expectation is joint commit.** Track 1 (FogSystem real impl + 6 building call-site rewrites + Khaneh add) and Track 2 (unit.gd register/deregister) share the coupled `is_visible_to` test gate — any FogSystem behavior test that spawns a unit goes through both tracks. The pre-commit hook will catch incomplete coupling.

**Coordination:** both agents announce `[ready]` when their changes are staged + locally tested. Then **whichever ships first joint-commits both** (mirroring balance-engineer's da3dc75 pattern from 3A.0). The non-shipping track's branch state is captured in the joint commit body — attribution-via-commit-trailer.

**Fallback:** if the agents cannot coordinate within ~30 min of both-ready, fall back to lead-mediated joint commit. Lead is responsible for the merge.

### 3.2 §9.H3 first-exercise-of-dormant-schema

Wave 3A.5 is the **first exercise** of 3 dormant-schema surfaces shipped in 3A.0:

| Surface | First exercised at 3A.5 by |
|---|---|
| `BalanceData.fog.sight_<kind>_cells` per-kind read | unit.gd `_ready` (gameplay-systems) — first runtime read |
| `FogSystem.register_vision_source` real impl | building call-sites (world-builder) + unit.gd `_ready` (gameplay-systems) — first real call |
| `fog_update` phase handler | FogSystem `_ready` connection to SimClock (world-builder) — first phase consumer |

**H3 dogfood:** if any of these surfaces silently fails (mistyped key, missing connection, wrong tick context), the test suite must catch it. **Tests are mandatory for each first-exercise.**

### 3.3 §9.L9 fallback-by-failure-visibility-shape — applied to 3 non-military buildings

Khaneh / Mazra'eh / Ma'dan currently default to `sight_<kind>_cells = 0` in FogConfig (per `fog_config.gd:51-59`). Per the FogConfig file header comment (lines 21-26): *"These are non-military buildings that the pre-flight explicitly flagged as 'footprint-only placeholder' — balance-engineer sets the tuned value via balance.tres at Wave 3A.5 brief-time."*

**3A.5 decision — defer to balance-engineer brief-time call, but unblock by accepting `0` as the shipped value:** Khaneh / Mazra'eh / Ma'dan register with `sight=0` (footprint-only reveal). This is the semantically-correct placeholder — they reveal their own footprint via the §3.2 footprint pass, nothing more. Balance-engineer may later raise these in `balance.tres` if playtest signal demands; that's a one-line `.tres` edit, no code change.

**Implementer's job in 3A.5:** read `BalanceData.fog.sight_<kind>_cells` for **all 7** buildings uniformly. The `0` value for the 3 non-military buildings is intentional — no special-case branch in the call-site.

### 3.4 Group-iteration fallback for entity tracking (per FOG_DATA_CONTRACT §6 LATER-fog-3)

**CRITICAL — world-builder:** Wave 3A.5 does NOT subscribe to `EventBus.building_placed` for entity tracking. The shipped signal's `unit_id` field is the **placer worker's** id, not the building's `unit_id` (from `_next_building_id`). Per FOG_DATA_CONTRACT §6 line 408: *"Wave 3A implementer (world-builder): use the group-iteration fallback; do NOT read `signal.unit_id` as the building identity."*

**For 3A.5's MVP scope (memory features deferred):** the entity-tracking question is dormant. `is_visible_to` doesn't need entity tracking — it queries `_currently_visible` by world position. Skip the entity-tracking question entirely until the 3A.7 follow-up addresses `get_last_seen` real impl.

## 4. Per-track deliverables

### Track 1 — world-builder-p3s2 (FogSystem internals + 7-building call-site sweep)

**Files:**
- `game/scripts/autoload/fog_system.gd` — implement:
  - `register_vision_source(node, team, sight_radius_cells, is_static)` returns monotonic handle; populates `_sources[handle]` dict with team/radius/is_static/(for static)`cached_cells`. For static buildings: compute footprint cells via `Building.get_footprint_aabb()` once at registration.
  - `deregister_vision_source(handle)` — idempotent removal.
  - `_on_fog_update_phase()` — Pass 1: clear `_currently_visible[team]` to zeros, then iterate `_sources` and run the integer-circle visibility computation (`dx*dx + dy*dy <= r*r`) per §3.1, writing `_currently_visible` + `_ever_seen`. For static sources, write their cached footprint cells (no per-tick recompute of footprint).
  - SimClock connection in `_ready`: connect to the `fog_update` phase signal (same pattern as `_on_*_phase` in other autoloads — see how `farr_system.gd` or `resource_system.gd` connect).
  - `is_visible_to(team_id, world_pos)` — real return from `_currently_visible[team_id][_cell_index(world_to_cell(world_pos))]`.
  - Add `is_instance_valid` lazy cleanup in `_on_fog_update_phase` for stale source records (node freed without deregister).

- `game/scripts/world/buildings/{atashkadeh,madan,mazraeh,sarbaz_khaneh,sowari_khaneh,tirandazi}.gd`:
  - Replace `0` in `register_vision_source(self, team, 0, true)` with `BalanceData.fog.sight_<kind>_cells`. Use the kind-specific field per `fog_config.gd:49-79`.
  - Add a `_fog_handle: int = 0` field; store the returned handle.
  - Add a deregister call in `_exit_tree` or building-destroyed path (whatever the base class uses for death).

- `game/scripts/world/buildings/khaneh.gd`:
  - **Add the missing call-site** — match the pattern of the other 6, reading `BalanceData.fog.sight_khaneh_cells` (currently 0 in FogConfig, that's fine).

- Tests:
  - `game/tests/unit/test_fog_system.gd` — extend with real register/deregister/fog_update assertions (the 34 existing tests cover the stubs; add ~10–15 more for the real path).
  - Update the 7 building test files where they assert FogSystem interaction (test_atashkadeh, test_madan, test_mazraeh, test_sarbaz_khaneh, test_sowari_khaneh, test_tirandazi — all assert sight=0 currently; flip them to assert BalanceData read).
  - Add `test_khaneh.gd` assertion that Khaneh registers.

**Cultural framing reminder:** the fog mechanic is a **knowledge asymmetry** in the heroic-age sense — the war between Iran and Turan is won as much by intelligence (Bizhan in Manizheh's lands, Tus surveying enemy approaches) as by force. Vision is information, and information is precious. No cultural-note prose needed in code for this wave (mechanical layer), but keep the lens for future Kaveh Event integration.

### Track 2 — gameplay-systems-p3s3 (unit.gd vision-source register/deregister)

**Files:**
- `game/scripts/units/unit.gd`:
  - In `_ready` (AFTER `_init` sets `kind`): if `FogSystem` autoload available, store `_fog_handle = FogSystem.register_vision_source(self, team, BalanceData.fog.sight_<kind>_cells, false)`. Read by kind (kargar/piyade/kamandar/savar/rostam). **All current Unit kinds.**
  - Add `_fog_handle: int = 0` field.
  - In the death-preempt path (wherever `unit_died` is emitted before `queue_free`): call `FogSystem.deregister_vision_source(_fog_handle)`. Idempotent — safe even if `_fog_handle == 0` (FogSystem.deregister is a no-op for 0).
  - Per `unit.gd`'s established `BalanceData` access pattern — use the same pattern that the rest of `unit.gd` uses for stat reads.

- Tests:
  - `game/tests/unit/test_unit.gd` — extend with assertions: spawning a Unit calls register; killing it calls deregister.
  - If `test_unit_states.gd` or `test_unit_state_dying.gd` exists for the dying flow, verify deregister-before-free ordering.

**H3 dogfood mandate:** since this is the first runtime read of `BalanceData.fog.sight_<kind>_cells`, your test must validate the per-kind read returns the right value (typo-bait surface).

**Coordination with Track 1:** stage your unit.gd changes + tests. Announce `[ready]` to world-builder-p3s2 + lead. Wait for world-builder's `[ready]` on Track 1. Then joint commit per §3.1.

### Track 3 (standby) — balance-engineer-p3s3

No mandatory deliverables this wave. **Standby for:**

- **Live-test tuning round:** if the user reports vision feels too narrow / too wide for a unit kind, you tune `balance.tres` only. This is a `.tres` edit + maybe a tests touch — single-commit follow-on.
- **3 non-military building default reconsideration:** if the user reports Khaneh / Mazra'eh / Ma'dan footprint-only reveal feels insufficient, you may raise their `sight_<kind>_cells` values. This is also a `.tres`-only edit.
- **3A.7 follow-up brief-time consult:** when 3A.5 ships and the question of memory-features comes up, your input on tunables for `get_scout_candidates` cap + `_ever_seen` lifetime policy is wanted.

### Track 4 (standby) — engine-architect-p3s2

No mandatory deliverables this wave. **Standby for:**

- **Phase ordering verification:** confirm that `fog_update` phase emission in `sim_clock.gd` (already shipped at 3A.0) is the only emission needed for Track 1's wiring; no additional SimClock changes required.
- **Pass 2 death-freeze design (3A.7 prep):** when 3A.7 surfaces, you'll consult on the `unit_health_zero` → cleanup-phase timing semantics.

## 5. Risk + escalation

### 5.1 Coupled-test-gate race (high probability)

Wave 3A.0's joint-commit at `da3dc75` was the resolution for this exact race shape. The race recurs at 3A.5 because Track 1 and Track 2 both touch `FogSystem.register_vision_source`'s real surface. **Default to joint commit per §3.1.**

### 5.2 BalanceData per-kind read typo surface

`BalanceData.fog.sight_<kind>_cells` requires the right `<kind>` string. Both tracks read this; a typo in unit.gd's kind-→key lookup will silently fall back to 0 (because `Resource` returns 0 for missing `int` properties, AFAIK). **Mitigation:** Track 2 writes a test that asserts each kind's lookup returns the correct value from `fog_config.gd`'s defaults. If the test fails, the typo is caught.

### 5.3 Building.get_footprint_aabb() fallback path

Per FOG_DATA_CONTRACT §3.2 line 230: *"If wave 3A (FogSystem) ships before a building subclass overrides this, FogSystem falls back to a 2×2 default per the base implementation's fallback clause."* The 2×2 fallback is already in `building.gd:444-445`. Track 1's footprint-computation code should rely on this fallback existing; don't reimplement it.

## 6. Wave-close criteria

- [ ] All 45+ pre-existing FogSystem tests still pass.
- [ ] New tests added per Track 1 + Track 2 (~15–20 additional tests).
- [ ] Pre-commit hook green on the joint commit.
- [ ] `git grep "register_vision_source(self, team, 0," game/scripts/world/buildings/` returns ZERO hits (the `0` placeholder is gone everywhere).
- [ ] Khaneh.gd has a `register_vision_source` call-site (the missing-7th gap is closed).
- [ ] unit.gd reads `BalanceData.fog.sight_<kind>_cells` for all 5 kinds + registers/deregisters cleanly.
- [ ] Live-test (lead-driven): start match, spawn workers + train infantry/cavalry/archer, walk around — fog memory not visible (no shader yet), but `FogSystem.is_visible_to` debug overlay shows real visibility cell-toggling as units move (if such debug overlay exists, else verified via unit tests).
- [ ] ARCHITECTURE.md v0.30.0 → v0.31.0 close entry.
- [ ] BUILD_LOG.md session 7 wave 3A.5 close entry.

## 7. Hand-off when this wave closes

- Wave 3B (DummyAIController) is the immediate next wave per user prioritization (2B → 3A → 3B). 3A.5's `is_visible_to` real impl is the dependency Wave 3B needs.
- 3A.7 (memory features — `get_last_seen` real impl + cleanup death-freeze + `get_scout_candidates` real impl + new EventBus signals) is a Phase 5 prep candidate; not yet scheduled. Surface as Phase-4-prep or Phase-5-prep depending on what playtest shows.

---

*Status: v1.0.0 — DRAFT 2026-05-22 by lead. Pending agent acknowledgment + joint commit per §3.1.*
