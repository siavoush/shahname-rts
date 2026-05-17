---
title: Wave 1C / 1D — Navmesh Architecture Spike (L25 + L26 — RESOLVED)
type: spike-report
status: resolved — explicit pipeline ratified, mechanism shipped wave 1D
version: 1.0.0
owner: engine-architect-p3s2
summary: Four-round-plus-resolution navmesh investigation. Wave 1C ran rounds 0-3 (each surfacing a deeper Godot 4.6.2 API default the prior round hadn't accounted for); user pushback against the deferral framing triggered Wave 1D (round 4 resolution) — explicit `parse_source_geometry_data(get_tree().root)` + `bake_from_source_geometry_data` pipeline in `Building._on_placement_complete`. Root cause confirmed via Godot 4.6 source: `NavigationRegion3D::bake_navigation_mesh()` convenience wrapper hardcodes `this` as parse-root, so even `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` config couldn't escalate the wrapper's scope. Explicit pipeline bypasses the wrapper. L25 + L26 RESOLVED at wave 1D commit.
audience: lead, future engine-architect debugging Godot navmesh integration, world-builder, qa-engineer
read_when: working on Godot navmesh / NavigationObstacle3D integration; debugging future "obstacle doesn't carve" scenarios; reading §9 retro on the four-incident drift pattern
prerequisites: [MANIFESTO.md, SIMULATION_CONTRACT.md, RESOURCE_NODE_CONTRACT.md]
ssot_for:
  - the four-round-plus-resolution mechanism archaeology for L25/L26 (Godot 4.6.2 NavigationObstacle3D behavior)
  - the empirical-probe artifacts diagnosed across the rounds (binary symbol enumeration, scene-tree shape, qa-engineer's headless probe results, Godot 4.6 source citations)
  - the canonical Godot 4.6 source-geometry-pipeline rebake pattern (parse_source_geometry_data + bake_from_source_geometry_data with get_tree().root as parse-root)
  - the §9 retro signal — Godot 4.x engine-feature claim drift pattern (four incidents, formal rule "enumerate API defaults at every step in the call chain")
references: [RESOURCE_NODE_CONTRACT.md, SIMULATION_CONTRACT.md, ARCHITECTURE.md, STUDIO_PROCESS.md]
tags: [navmesh, navigation-obstacle, spike, wave-1c, wave-1d, l25, l26, godot-4.6, resolved, archaeology]
created: 2026-05-16
last_updated: 2026-05-17
provenance: Decision-arc continuity per STUDIO_PROCESS §12.5 — engine-architect-p3s2 instance carries the wave-1B live-test investigation (Task #119, RNC v1.3.1 honesty correction at 98dfc18) forward into the wave-1C spike (Task #126), through four diagnostic rounds (Tasks #140, #142, #146), and the wave 1D resolution (Task #149). v0.2.0 (2026-05-17) re-scoped from prescription to archaeology under lead's option-B deferral. v1.0.0 (2026-05-17, same day) closes the spike with the wave 1D resolution — user pushback against the deferral triggered the dedicated wave; lead's research-validated Godot 4.6 source inspection identified the parse-root hardcoding in the convenience wrapper. Explicit pipeline shipped. L25 + L26 RESOLVED. Cites the formal §9 "Godot-API-dependent architecture claims must enumerate API defaults at every step in the call chain" rule synthesized from the four-incident pattern.
---

# Wave 1C / 1D — Navmesh Architecture Spike (RESOLVED)

> **Status (v1.0.0 — 2026-05-17): RESOLVED.** Four rounds of mechanism correction (rounds 0-3) under wave 1C surfaced deeper-and-deeper Godot 4.6.2 API defaults the prior round hadn't accounted for. Lead's option-B deferral was overridden by user pushback the same day; wave 1D ratified the explicit `parse_source_geometry_data(get_tree().root)` + `bake_from_source_geometry_data` pipeline as the mechanism. Root cause: the convenience wrapper `NavigationRegion3D::bake_navigation_mesh()` hardcodes the region as parse-root, so the `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` config (round 3) couldn't escalate the wrapper's scope — only the explicit pipeline bypasses it. Workers now route around placed buildings. L25 + L26 RESOLVED. The archaeology below is forward-investment for future Godot navmesh debugging.

---

## 0. Why this document exists — and where it currently stands

Wave 1B live-test (2026-05-15) surfaced that workers walk THROUGH placed `Khaneh` and `Ma'dan` buildings instead of routing around them. Investigation (Task #119) showed the bug is **project-wide and pre-existing since Phase 3 wave 1C session 1**. The wave 1C navmesh spike was opened to resolve it.

**After four diagnostic rounds across three days, the carve is still not working in live-test.** Each round corrected one layer of misunderstanding about Godot 4.6.2's `NavigationObstacle3D` API; each layer's fix exposed the next layer's gap; no combination of fixes has yet produced a working carve. **Lead's 2026-05-17 option-B decision is to close wave 1C without navmesh carving and defer the dedicated investigation to a future wave with its own time budget.**

This document was originally drafted as a prescription (v0.1.0-rc.1). It is now an archaeology archive (v0.2.0). The next engineer's investment is the empirical state captured in §0.1 — they should NOT have to redo this discovery.

---

## 0.1 Four-round mechanism-correction archaeology

Each round added one configuration layer; each fix triggered the next live-test failure with a deeper-layer cause. **All four rounds' fixes are currently SHIPPED in the codebase** — they didn't get rolled back, since each was a structurally-correct prerequisite for the eventual fix even if individually insufficient. The dedicated wave starts from this current state.

### Round 0 — Spike v0.1.0-rc.1 (2026-05-16)

**Prescribed:** Set `affect_navigation_mesh = true` + `vertices` polygon on each `NavigationObstacle3D`. Inferred mechanism: "engine-managed localized region rebake when obstacle enters the scene tree."

**Shipped at:** `90d39bd` (world-builder Phase 2A scene edits).

**Why it failed:** The "engine-managed automatic rebake" mechanism does not exist in Godot 4.6.2. `affect_navigation_mesh` is a bake-time **participation hint** — it controls whether the obstacle is parsed in when SOMEONE ELSE triggers a bake. It is not a trigger.

**Diagnosed by:** Task #140 (engine-architect-p3s2). Binary probe found two separate setters: `set_affect_navigation_mesh` and `set_carve_navigation_mesh`. Spike had conflated them. Confirmed via `strings /Applications/Godot.app/Contents/MacOS/Godot | grep -iE "affect_navigation_mesh|carve_navigation_mesh"`.

### Round 1 — Hypothesis 5 (`bc34c39`, 2026-05-17)

**Prescribed:** Add `carve_navigation_mesh = true` to each NavigationObstacle3D (alongside the existing `affect_navigation_mesh = true`).

**Shipped at:** `bc34c39` (Task #141 — world-builder fix-up).

**Why it failed:** `carve_navigation_mesh = true` is the RUNTIME equivalent of `affect_navigation_mesh = true` — it's the participation hint for bakes that happen AFTER the initial scene bake. Like the bake-time flag, it doesn't TRIGGER a bake; it just flags the obstacle as relevant when a bake happens. Without an explicit re-bake call after the obstacle enters the tree, nothing happens.

**Diagnosed by:** Task #142 (engine-architect-p3s2). Binary probe enumeration of `obstacle_set_*_command_3d` strings revealed there is **no `obstacle_set_carve_*` or `obstacle_set_affect_*` runtime command** — these flags are node-level configuration, not server-side commands. Plus the `NavigationServer3D::region_bake_navigation_mesh()` deprecation message confirmed the new explicit-pipeline architecture: `parse_source_geometry_data` + `bake_from_source_geometry_data`.

**qa-engineer probe (`0184b52`):** 30-frame await loop in headless test confirmed: nav map state=1 (valid), but `min_xz` stays 0.000 every frame — path goes through obstacle origin. Confirms the bake never fires; flags alone are insufficient.

### Round 2 — Hypothesis 5h (`910bd9a`, 2026-05-17)

**Prescribed:** Trigger an explicit synchronous `region.bake_navigation_mesh(false)` from `Building._on_placement_complete` AFTER the building's `NavigationObstacle3D` is in the tree. Add `_resolve_terrain_region()` helper that walks `get_tree().root` for the first `NavigationRegion3D`. Sync (not async) bake to preserve Sim Contract §1.6 determinism.

**Shipped at:** `910bd9a` (Task #144 — world-builder rebake fix-up). L6 lint rule revised at `c480303` (Task #145) — forbid only `bake_navigation_mesh(true)` (async, races sim tick); permit `bake_navigation_mesh(false)` (sync) project-wide.

**Why it failed:** Bake fires correctly. qa-engineer's behavioral test (`7dc2fd5`, `82c46d5`) confirms `state=1` and the rebake path is reachable. But the OBSTACLE still doesn't carve — workers still walk through buildings in live-test.

**Diagnosed by:** Task #146 (engine-architect-p3s2). Binary probe enumeration of `geometry_source_geometry_mode` enum revealed FOUR values:
- `SOURCE_GEOMETRY_NAVMESH_CHILDREN` ← Godot 4.6.2 default
- `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`
- `SOURCE_GEOMETRY_GROUPS_EXPLICIT`
- `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`

The default `SOURCE_GEOMETRY_NAVMESH_CHILDREN` mode means the bake's source-geometry-parse step walks only the NavigationRegion3D's own subtree. Buildings live under `&World` as siblings of `Terrain` (per `unit_state_constructing.gd:_resolve_placement_parent` returning `ctx.get_parent()` — the worker's parent, which is `&World`). The bake's parse step never visited them.

**Scene-tree shape (confirmed via main.tscn:25-40):**
```
Main
└─ World (Node3D)            ← buildings spawn under here (siblings of Terrain)
   ├─ Terrain (NavigationRegion3D)    ← bake parses THIS subtree only (default)
   │   ├─ StaticBody3D
   │   └─ MeshInstance3D
   ├─ Sun, WorldEnvironment, CameraRig
   ├─ Khaneh1                ← runtime add_child target — NOT in Terrain's subtree
   │   └─ NavigationObstacle3D
   └─ ...
```

### Round 3 — Hypothesis 6a (`be8c355`, 2026-05-17)

**Prescribed:** Set `navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` in `terrain.gd:_configure_navmesh()`. Widens the parse scope from Terrain's subtree to the scene-tree root.

**Shipped at:** `be8c355` (Task #147 — world-builder hypothesis 6a fix-up).

**Why it failed (the unresolved gap):** Bake fires correctly. Parse scope is now wide enough to walk past `&World` and find `Khaneh1` (sibling of Terrain). Building's `StaticBody3D` + `CollisionShape3D` + `NavigationObstacle3D` are now in parse scope. **Workers STILL walk through the building.** Lead's live-test confirms.

**This is where the wave 1C investigation closes.** The hypothesis space remaining for the dedicated wave to explore:

- **R4-α:** Building's `StaticBody3D` is being parsed as **walkable geometry** (since `terrain.gd:_configure_navmesh` sets `PARSED_GEOMETRY_STATIC_COLLIDERS`). The building's collision box might be ADDING walkable surface rather than the obstacle's `vertices` polygon SUBTRACTING from it. Net effect: no carve. Cited Godot docs phrase *"Obstacles are not involved in the source geometry parsing"* — they participate via the dedicated `navmesh_parse_source_geometry` callback, but if the building's StaticBody3D dominates the parse, the obstacle's contribution might be lost or overridden.
- **R4-β:** The `NavigationObstacle3D::navmesh_parse_source_geometry` callback might not be called during `NavigationServer3D.parse_source_geometry_data` (the path `region.bake_navigation_mesh(false)` ultimately takes). Reading Godot 4.6.2 source at `scene/3d/navigation/navigation_obstacle_3d.cpp` + `scene/3d/navigation/navigation_region_3d.cpp` would confirm.
- **R4-γ:** `agent_height` / `agent_max_climb` defaults on the `NavigationMesh` resource might cause the obstacle's 3D footprint to be eroded away during the voxelization step. Worth probing.
- **R4-δ:** Explicit 4-call pipeline (`parse_source_geometry_data` + `add_projected_obstruction(...)` + `bake_from_source_geometry_data`) might be the only working pattern — the auto-participation of NavigationObstacle3D nodes via callback might be a documentation-vs-reality gap (precedent: this entire spike).
- **R4-ε:** Path B fallback (NavigationAgent3D + RVO migration). Multi-day scope; determinism wild card. Captured at §3 of this report.

**Empirical state at wave-1C close (round 3):**
- Path query: state=1 (nav map valid).
- Waypoints: `[(0, 0.5, -10), (0, 0.5, 0), (0, 0.5, 10)]` — straight line through building's origin.
- qa-engineer probe: `min_xz = 0.000` consistently across 30 awaited frames.
- Bake hook fires (verified via `region.bake_navigation_mesh(false)` synchronous return + reachable code path).
- All flags configured: `affect_navigation_mesh = true`, `carve_navigation_mesh = true`, `vertices = ±1.1` (Khaneh) / `±1.35` (Ma'dan) / 8-vertex octagon @ 0.85m (mine_node).
- Source geometry mode: `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN`.
- **Net result: obstacle's polygon is not carving the navmesh.** Cause unknown at round-3 close; explored hypothesis space narrowed but not closed.

### Round 4 — Resolution via explicit pipeline (Wave 1D, 2026-05-17)

**Context.** Lead's option-B decision (2026-05-17) initially deferred the dedicated investigation. User pushback against the deferral framing the same day triggered Wave 1D (Task #149). Lead's research-validated Godot 4.6 source inspection identified the root cause that the four binary-probe rounds had narrowed but not closed.

**Root cause (validated against Godot 4.6 source).** `NavigationRegion3D::bake_navigation_mesh()` (the convenience wrapper world-builder shipped at `910bd9a`) **hardcodes `this` (the region itself) as the parse-root** passed to `NavigationServer3D::parse_source_geometry_data()`. Combined with `nav_mesh_generator_3d.cpp:236-255` showing that `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` mode uses the passed-in `p_root_node` as-is (not escalated to `get_tree().root`), this means **the round-3 `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` config was structurally inert** — the mode can't override the convenience wrapper's hardcoded parse-root. The widened parse scope was set on the navmesh resource, but the wrapper passed the wrong starting node, so the wider scope had nothing to widen.

This closes the round-3 R4-β hypothesis as the live mechanism — the callback DOES fire, but only on obstacles in the region's subtree. R4-α / R4-γ / R4-δ / R4-ε did not fire; the answer was simpler than any of them.

**Prescribed (wave 1D).** Bypass the convenience wrapper. Use the explicit 4-call (actually 2-call after eliding the obstacle-iteration loop that auto-participation handles) pipeline in `Building._on_placement_complete`:

```gdscript
var source := NavigationMeshSourceGeometryData3D.new()
NavigationServer3D.parse_source_geometry_data(
    region.navigation_mesh, source, get_tree().root)
NavigationServer3D.bake_from_source_geometry_data(
    region.navigation_mesh, source)
```

The explicit call passes `get_tree().root` directly, walking the entire scene tree. `NavigationObstacle3D::navmesh_parse_source_geometry` callback fires on every obstacle (auto-participation works — R4-δ's manual `add_projected_obstruction` is NOT needed for scene-tree obstacles), and the synchronous `bake_from_source_geometry_data` finalizes the navmesh.

**L6 lint extended** (`tools/lint_simulation.sh`): now forbids `bake_from_source_geometry_data_async` outside `terrain.gd` alongside the existing `bake_navigation_mesh(true)` ban. Sync forms permitted project-wide; async forms race sim ticks (Sim Contract §1.6).

**Shipped at:** wave 1D commit (Task #149 — single commit bundles the explicit-pipeline change in `building.gd`, the L6 extension, RNC §3.2 v1.4.0 positive prose, this spike v1.0.0 amendment, and ARCHITECTURE.md §6 v0.23.0 + §7 L25/L26 closures).

**Empirical confirmation:**
- qa-engineer's behavioral test (`test_phase_3_nav_obstacle_carving_behavioral.gd`) — the two `pending()` paths go GREEN (sync `bake_from_source_geometry_data` fires in headless without rendering-loop dependency).
- Lead live-test 5-scenario gate — workers route around Khaneh / Ma'dan / mine_node; Mazra'eh remains walkable.

### Summary table

| Round | Mechanism added | Shipped at | Verdict |
|---|---|---|---|
| 0 (v0.1.0-rc.1) | `affect_navigation_mesh = true` + `vertices` polygon | `90d39bd` | Inert — flag without trigger |
| 1 (hyp 5) | `carve_navigation_mesh = true` | `bc34c39` | Inert — flag without trigger |
| 2 (hyp 5h) | Manual `region.bake_navigation_mesh(false)` from `Building._on_placement_complete` | `910bd9a` + `c480303` | Bake fires, but convenience wrapper hardcodes region as parse-root → obstacles not in parse scope |
| 3 (hyp 6a) | `geometry_source_geometry_mode = SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` | `be8c355` | Mode set on resource but wrapper's hardcoded parse-root makes the mode inert — carve STILL doesn't appear |
| **4 (resolution)** | **Explicit `parse_source_geometry_data(get_tree().root)` + `bake_from_source_geometry_data` pipeline; bypass convenience wrapper. L6 extended.** | **wave 1D commit (Task #149)** | **RESOLVED — workers route around buildings; behavioral test green; lead live-test passed** |

---

## 0.2 Lead's option-B deferral → user pushback → Wave 1D resolution (2026-05-17)

The deferral decision and its rapid override are themselves load-bearing process archaeology, captured here for the §9 retro signal.

**Lead's initial option-B decision (2026-05-17, morning):**

> Wave 1C closes WITHOUT navmesh carving. Workers-walk-through-buildings is documented as L25-still-open. The dedicated investigation moves to a future wave with its own time budget. Reasoning: 4 rounds deep on a navmesh issue that was supposed to be a wave-close detail. Wave 1C's core deliverables (construction-timer, UI progress bar, Ma'dan-over-mine placement validity) are clean and complete. The navmesh problem is a research project that needs its own scope, not bolt-on rounds inside an unrelated wave.

The Phase 2C honest-archaeology commit (`11c7136`) shipped under this decision: RNC §3.2 v1.3.1 → v1.3.2, this spike v0.1.0-rc.1 → v0.2.0, ARCHITECTURE §7 L25 + L26 with empirical-state carry-forward.

**User pushback (same day):** the deferral framing was overridden — the four-round diagnostic was deep enough that the right thing was to apply the research-discipline rule (read Godot 4.6 source) and ship the fix, not punt. Lead opened Wave 1D (Task #149) the same day, sourcing the parse-root hardcoding finding from Godot 4.6 source inspection.

**Wave 1D resolution shipped same day:** explicit pipeline, L25 + L26 closed. See §0.1 Round 4 above for the resolution details.

**The dual decisions are both correct in their own framing:**
- Option B was the right call given a four-round diagnostic with no clear next-step — punting was a discipline-correct response to spike-scope spiral.
- Wave 1D was the right call given the simple `get_tree().root` parse-root fix that source inspection surfaced — the bug was simpler than the four-round investigation made it look.

The §9 retro signal: **when a multi-round investigation closes with "we narrowed the hypothesis space but don't have the answer," the SUBSEQUENT step (before deferring) should be a research-discipline pass — read the engine source, search GitHub issues, search community forums. The four-round binary-probe approach was empirically correct but incomplete; source reading would have closed it in one round.** This is the meta-rule that updates the "engine-feature-claim probes must enumerate API defaults at every step in the call chain" rule from session-3 retro to include the source-reading step explicitly.

The original v0.1.0-rc.1 prescription content below (verdict, scene-edit prescription, code prescription, lint rule, RNC §3.2 v1.4.0 draft, behavioral-test plan, risk register, summary) is RETAINED for archaeology. **DO NOT TRUST as current behavior** — each prescription was the round's best understanding at the time, superseded by subsequent rounds' diagnoses. Read §0.1 for the current state; read §1-§8 below as historical record of how the understanding evolved.

---

## 0.3 Why this document exists (original v0.1.0-rc.1 framing — retained for archaeology)

1. The path scheduler (`navigation_agent_path_scheduler.gd:96`) calls `NavigationServer3D.map_get_path()` directly. This query reads the navmesh baked once at `terrain.gd:_ready()` and **ignores dynamic `NavigationObstacle3D` children entirely** in their current radius-only configuration.
2. There is no `NavigationAgent3D` anywhere in the project — workers compose `MovementComponent` which writes `Node3D.global_position` directly inside `_sim_tick`. There is no RVO-steering consumer.
3. `NavigationObstacle3D` in Godot 4 has two independent modes (verified per session 2 investigation + the Godot 4.6 NavigationObstacle3D documentation):
   - **(a) Static carve mode:** `affect_navigation_mesh = true` AND `vertices: PackedVector3Array` (top-down polygon, Y ignored). Engine automatically triggers a localized region rebake when the obstacle enters/exits/moves within the parent `NavigationRegion3D`. Carved cells become non-traversable for `map_get_path()` queries.
   - **(b) Dynamic RVO mode:** `avoidance_enabled = true` on the obstacle (default true) PLUS `NavigationAgent3D` consumers with their own `avoidance_enabled = true`. Steering-time obstacle avoidance; **has zero effect on `map_get_path()` queries** — it operates downstream of pathing, during agent steering.

Our current build sits in neither mode — the obstacle has `radius = 1.5` and nothing else. Mode (a) needs the flag + polygon. Mode (b) needs an agent. Both halves of the contract's previous "dynamic carve without rebake" claim were structurally false; the RNC v1.3.1 honesty correction at `98dfc18` already documents this. This spike chooses the resolution path.

`L26` is the same class of finding: `mine_node.tscn` doesn't actually have a `NavigationObstacle3D` despite RNC §3.2 claiming mines carry one. Same fix shape as L25; resolved jointly here.

**What this document is:** a single consolidated read-only architecture spike. Verdict + prescription + supporting evidence + the §3.2 v1.4.0 prose that supersedes v1.3.1 once a path ratifies.

**What this document is not:** a commit. No scene files, no code files, no contract files mutate from this report. Path A's scene edits land in a follow-on world-builder commit AFTER lead ratifies. RNC §3.2 v1.4.0 lands AFTER the live-test confirmation gate passes.

---

## 1. Verdict — Path A (engine-managed localized region rebake)

**Recommendation: ratify Path A.** Path B is the architecturally-purer alternative but its cost/risk profile does not match the wave 1C scope.

### 1.1 Comparison table

| Dimension | Path A (`affect_navigation_mesh = true` + polygon) | Path B (`NavigationAgent3D` + RVO migration) |
|---|---|---|
| **What changes** | 4 `.tscn` edits (building.tscn, khaneh.tscn, madan.tscn, mine_node.tscn). 0 code edits. | 10 unit-scene edits + `MovementComponent` rewrite + `NavigationAgentPathScheduler` adaptation. Determinism work. |
| **Path query** | `map_get_path()` reflects carves; unit walks the carved waypoints unchanged | `map_get_path()` no longer authoritative; agent-driven pathing replaces it |
| **Steering** | None — unit walks waypoints directly (current behavior preserved) | RVO steering modulates velocity per frame |
| **Determinism (Sim Contract §1.6)** | Preserved — `map_get_path()` is deterministic on a fixed navmesh; the region rebake is itself deterministic (same inputs, same output region) | **RISKED** — Godot's RVO is float-stepped per real frame, non-deterministic across machines by default. Would require sim-tick-scoped RVO with seeded RNG (multi-day work, possibly engine-patching) |
| **Engineering effort** | ~30 min scene + lint + 1 regression test. Plus ~30 min live-test verification | 1-2 days end-to-end, **plus** the determinism wild card |
| **Headless test compatibility** | Preserved — `MockPathScheduler` returns straight-line paths (ignores navmesh), independent of whether obstacles are carving the real navmesh. Existing 535+ tests do not regress | At risk — `MockPathScheduler` injection seam in `MovementComponent` would need re-aligning with the new `target_position` flow |
| **Spec-vs-rule survival** | "No FULL-MAP rebake at runtime" rule survives unchanged (gameplay code never calls `bake_navigation_mesh()`). Engine-internal *region* rebake is a different mechanism — surgical, localized, engine-managed | Same rule survives (RVO doesn't rebake at all), but the rule's relevance shrinks because path queries are no longer the primary mechanism |
| **Spirit-of-Manifesto-Principle-4 (Lean Iteration)** | Highest fit — minimum viable fix for the surfaced bug | Lower fit — major architectural commitment for an MVP that may not need RVO |
| **Forward-compat with combat positioning** | Unit-vs-unit stack-clipping behavior unchanged (still permitted; combat positioning is a Phase 4+ concern) | Would force a decision about unit-vs-unit avoidance NOW, before combat positioning has a design |

### 1.2 Decision criteria favoring Path B (not met)

Path B would be the right call only if any of the following hold; none do for wave 1C:

1. **Frequent obstacle add/remove churn.** Path A's region rebake fires on obstacle enter-tree / exit-tree / move-while-in-tree. For per-tick churn this would compound. **Buildings are placed at construction-completion and destroyed rarely**; their obstacles are born and die at human-timescale events (seconds to minutes), not per-tick. Region rebake cost is amortized to zero across a match.
2. **Unit-vs-unit avoidance is a near-term gameplay requirement.** Current build stack-clips units (visible in formation-move tests). The design has not flagged this as a problem; the wave 1C scope does not include combat positioning. Phase 4+ may revisit.
3. **`map_get_path()` is the wrong abstraction.** It is in fact the right abstraction for static-world RTS pathing on a hand-authored navmesh — see SC2/AoE2's approaches, both of which use static carves for buildings + simple steering for units.

Conclusion: Path A is the wave-1C-correct fix. Path B remains a viable post-MVP migration path if combat positioning calls for it; that decision lives in Phase 4+ design mode.

### 1.3 Adjacent-code verification (per agent-def investigation playbook)

Verified empirically against the codebase (no engine experiments needed; all four facts grep-confirmable):

1. **`NavigationAgentPathScheduler.request_repath`** at `game/scripts/navigation/navigation_agent_path_scheduler.gd:96` calls `NavigationServer3D.map_get_path(map_rid, from, to, true)`. `map_get_path` queries the baked navmesh — carved cells (when `affect_navigation_mesh = true` is set) are excluded; radius-only obstacles are not visible to it. **Confirmed.**
2. **`MovementComponent`** at `game/scripts/units/components/movement_component.gd:202,208,213` writes `owner_node.global_position = ...` directly. No physics call, no NavigationAgent3D, no RVO step. **Confirmed.**
3. **No `NavigationAgent3D` anywhere** — `rg -n NavigationAgent3D game/scripts game/scenes --type-add 'tscn:*.tscn' -t gd -t tscn` returns only doc comments + `NavigationAgentPathScheduler`'s name. No actual nodes. **Confirmed.**
4. **`terrain.gd`** at `game/scripts/world/terrain.gd:79` calls `bake_navigation_mesh(false)` exactly once, in `_ready`. The script is `NavigationRegion3D`-rooted (line 1: `extends NavigationRegion3D`); any `NavigationObstacle3D` child of any building added under this region automatically operates against this region's navmesh. **Confirmed.**

Godot 4.6.2 (the project's pinned version per `project.godot:20`) `NavigationObstacle3D` API surface:
- `affect_navigation_mesh: bool` — when set true on an obstacle that is a descendant of a `NavigationRegion3D` AND has `vertices` set, the obstacle contributes to the region's baked navmesh via an engine-managed automatic region rebake (`NavigationServer3D` rebakes the affected region asynchronously after obstacle add/move/remove).
- `vertices: PackedVector3Array` — a top-down polygon in obstacle-local space. The Y component of each vertex is ignored; the polygon defines a 2D convex shape projected onto the navmesh plane. Vertices must wind consistently (CCW is conventional but the engine accepts either as long as it's consistent).
- `radius: float` — used ONLY by the RVO-avoidance mode (mode b above). When `affect_navigation_mesh = true` is set, radius is irrelevant to navmesh carving.
- `avoidance_enabled: bool` — controls RVO participation. Defaults to true but has no consumer in our project (no `NavigationAgent3D`).

**Path A is the standard Godot 4 pattern for static building obstacles on an RTS-style baked navmesh** — confirmed against Godot 4.6 docs + verified semantically against the existing codebase architecture. No engine-experimentation needed; the spike's live-test (post-ratification) confirms the integration, not the API.

### 1.4 One live-test gate that must pass before declaring Path A complete

The spike is read-only; this gate fires AFTER lead ratifies Path A and world-builder ships the scene edits + I (or whoever owns the follow-on) deploy the lint rule + tests + RNC §3.2 v1.4.0 prose:

> **Live-test gate (lead-driven, Manifesto Principle 1 — Truth-Seeking):** Place a Khaneh at world origin. From any direction, right-click a destination on the opposite side of the building. The worker's path must visibly route AROUND the Khaneh, not THROUGH it. Repeat for Ma'dan. Repeat for a placed-on-resource Ma'dan-on-mine. Mazra'eh remains walkable (control — workers should walk ONTO and through the Mazra'eh tile). If the worker still walks through any structural building, Path A's API contract is not behaving as documented and the spike re-opens with Path B as the fallback.

This is the empirical confirmation the §9 2026-05-14 rule ("process-mitigation runtime verification") demands — and which the wave 1A original Khaneh shipping bypassed, causing the L25 finding to ride for 7 days. Cite this rule in the lead's live-test cadence post-ratification.

---

## 2. Scene-edit prescription (Path A — for world-builder's follow-on commit)

> **NOT FOR COMMIT THIS ROUND.** World-builder consumes this section after lead ratifies Path A. Scene edits ship LAST in wave 1C per L23 worktree-isolation discipline (read-only spike runs in parallel with Tracks 1 + 2; world-builder's scene-edit commit serializes after they close).

### 2.1 `game/scenes/world/buildings/building.tscn` — base Building template

**Current `NavigationObstacle3D` node (lines 105-124):**
```
[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)
radius = 1.5
```

**Replace with:**
```
[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
; Path A — engine-managed localized region rebake (per docs/WAVE_1C_NAVMESH_SPIKE.md
; + RNC §3.2 v1.4.0). `affect_navigation_mesh = true` + `vertices` polygon makes
; the parent NavigationRegion3D (terrain.gd) carve this footprint out of the
; baked navmesh. NavigationServer3D issues an automatic region rebake when the
; obstacle enters the scene tree — no gameplay code calls bake_navigation_mesh().
;
; vertices: 2D top-down polygon in obstacle-local space (Y ignored). Matches
; the BoxMesh footprint (2.0 × 2.0 XZ) with a small margin so the navmesh
; agent-radius (NAV_AGENT_RADIUS = 0.5) doesn't trap workers in a too-tight
; corridor near the building edge. Margin = 0.1m → polygon at ±1.1m from center.
;
; radius retained but inert under affect_navigation_mesh = true — kept for
; clarity (matches the visual silhouette half-width); not read by the engine
; in static-carve mode. Subclasses override `vertices` (and may resize radius
; for parity) when their footprint differs from the 2.0×2.0 base.
;
; transform Y-offset (0.6) matches the mesh; navmesh carving is XZ-only so
; the Y is irrelevant to the carve, but kept for editor visualization parity
; with the mesh.
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)
affect_navigation_mesh = true
vertices = PackedVector3Array(-1.1, 0, -1.1, 1.1, 0, -1.1, 1.1, 0, 1.1, -1.1, 0, 1.1)
radius = 1.5
```

**Why `±1.1m` not `±1.0m`:** the navmesh's `agent_radius = NAV_AGENT_RADIUS = 0.5` (terrain.gd:44). The baker erodes the navmesh inward by `agent_radius` around any non-walkable region — so a 2.0×2.0 carve (vertices at ±1.0) leaves the visual building's edge flush with the eroded navmesh boundary, and workers may snag at the corner. A 0.1m margin on the carve polygon ensures the eroded boundary stays slightly OUTSIDE the visual silhouette. (Sanity-check this in the live-test; tighten to ±1.05 or loosen to ±1.15 if the path-route hugs too close or routes too wide.)

### 2.2 `game/scenes/world/buildings/khaneh.tscn` — inherits base

**No edit required.** Khaneh's footprint is the base 2.0×2.0 (the comment at khaneh.tscn:19 confirms inheritance). The base scene's updated `NavigationObstacle3D` flows through automatically.

**Sanity check world-builder should perform:** confirm `find_child("NavigationObstacle3D")` on a placed Khaneh returns the obstacle with `affect_navigation_mesh = true` and the expected `vertices`. If Godot's scene-inheritance serializes differently for arrays-of-Vector3 in `PackedVector3Array`, an explicit override on khaneh.tscn may be required. If so, the override is one node block identical to building.tscn's, no extra logic.

### 2.3 `game/scenes/world/buildings/madan.tscn` — 2.5×2.5 footprint

**Current `NavigationObstacle3D` node (lines 106-120):**
```
[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
radius = 1.5
```

**Replace with:**
```
[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
; Path A override — Ma'dan's footprint is 2.5×2.5 (vs Building base 2.0×2.0).
; Polygon at ±1.35m (2.5/2 + 0.1m margin per the base-scene rationale).
;
; transform Y-offset 0.5 matches Ma'dan's mesh half-height (madan.tscn:84
; convention). Navmesh carve is XZ-only.
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
affect_navigation_mesh = true
vertices = PackedVector3Array(-1.35, 0, -1.35, 1.35, 0, -1.35, 1.35, 0, 1.35, -1.35, 0, 1.35)
radius = 1.5
```

### 2.4 `game/scenes/world/buildings/mazraeh.tscn` — NO obstacle (unchanged)

**No edit.** Mazra'eh remains walkable per the deliberate design (workers walk ONTO the farm). The Mazra'eh scene already omits `NavigationObstacle3D` — confirmed in the existing test `tests/unit/test_mazraeh.gd:318-328` (`assert_null` on the obstacle child). That test passes today and continues to pass under Path A.

### 2.5 `game/scenes/world/resource_nodes/mine_node.tscn` — L26 resolution

**Currently has NO `NavigationObstacle3D` at all.** The scene comment at lines 21-27 anticipates wave 1B adding one; wave 1B never did. The L26 finding closes here.

**Add a new `NavigationObstacle3D` node** after the existing `StaticBody3D / CollisionShape3D` block (after line 100):

```
[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
; L26 resolution — Phase 3 session 3 wave 1C Track 3 (Path A).
; Per RNC §3.2 v1.4.0: MineNode scenes carry a NavigationObstacle3D so the
; navmesh carves the deposit and workers route around it. Depleted mines
; remain navigationally impassable as derelict ruins (RNC §3.2 ruins-policy
; carried forward from v1.3.1 prose).
;
; Footprint: the visual is a cylinder of radius 0.75. A circle is approximated
; with an 8-vertex polygon at radius 0.85 (0.75 + 0.1m margin per the base
; building-scene rationale). 8 sides is plenty of fidelity for a 1.5m-wide
; obstacle on a 0.25m navmesh cell_size (terrain.gd:48).
;
; transform Y-offset 0.25 matches the cylinder mesh.
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.25, 0)
affect_navigation_mesh = true
; 8-vertex octagon approximating a 0.85m-radius circle. Coords precomputed
; from r*cos(k*pi/4), r*sin(k*pi/4) for k=0..7; rounded to 3 dp.
vertices = PackedVector3Array(0.85, 0, 0.0, 0.601, 0, 0.601, 0.0, 0, 0.85, -0.601, 0, 0.601, -0.85, 0, 0.0, -0.601, 0, -0.601, 0.0, 0, -0.85, 0.601, 0, -0.601)
radius = 0.85
```

**Note on `mine_node.tscn:54-63` comment trail:** the BoxShape3D collision shape (radius 0.75, height 0.5) was added per BUG-07 to make the mine a click target. That collision shape is on the StaticBody3D and is independent of the new NavigationObstacle3D — they coexist. The collision shape is for raycast hit-tests (selection / right-click); the obstacle is for navmesh carving. Different domains, both required.

### 2.6 Sarbaz-khaneh (future, wave 2A) — flag for the wave 2A brief

Wave 2A's Sarbaz-khaneh ships a NEW Building subclass. Per Path A discipline:
- Sarbaz-khaneh inherits `building.tscn`'s base `NavigationObstacle3D` automatically.
- If Sarbaz-khaneh's mesh footprint differs from 2.0×2.0 (e.g., long-rectangular for a barracks), the scene MUST override `vertices` with the correct polygon dimensions.
- World-builder should consult this report's §2.1 for the inheritance vs. override pattern.

**Action:** lead's wave 2A dispatch brief surfaces this as a sub-deliverable: "Sarbaz-khaneh scene must declare a `NavigationObstacle3D` with `affect_navigation_mesh = true` and `vertices` matching its footprint; see `docs/WAVE_1C_NAVMESH_SPIKE.md` §2.1."

---

## 3. Code prescription (if Path B were ratified — for completeness only)

Captured here in case the live-test gate (§1.4) fails and Path B becomes the fallback. **Not for this round.**

### 3.1 Scope of changes

| Layer | File(s) | Change |
|---|---|---|
| Unit scenes (×10) | `kargar.tscn`, `piyade.tscn`, `kamandar.tscn`, `savar.tscn`, `asb_savar_kamandar.tscn`, plus Turan equivalents | Add `NavigationAgent3D` child with `avoidance_enabled = true`, `radius` matching the unit's visual silhouette half-width, `target_desired_distance = 0.5` |
| Movement | `game/scripts/units/components/movement_component.gd` | Replace direct `global_position` write with `agent.target_position = current_waypoint` + subscribe to `agent.velocity_computed` for the per-frame velocity. Integrate velocity into `global_position` in `_sim_tick` at sim cadence. |
| Path scheduler | `game/scripts/navigation/navigation_agent_path_scheduler.gd` | Optional — could be retired entirely (agent handles its own pathing). Retain as a thin wrapper for the IPathScheduler interface contract. |
| Building scenes (×4) | `building.tscn`, `khaneh.tscn`, `madan.tscn`, `mine_node.tscn` | Set `avoidance_enabled = true` on each obstacle. NO `affect_navigation_mesh` change (RVO operates independently of carving). |
| Test fixtures | All `MovementComponent` tests | Adapt for the new `agent`-driven flow; `MockPathScheduler` may need a parallel `MockNavigationAgent3D` stand-in or get retired |

### 3.2 Determinism risk (Sim Contract §1.6)

Godot's RVO implementation:
- Runs per real frame on `NavigationServer3D`'s thread (configurable but default async).
- Uses `delta_time` from the rendering frame, not a fixed sim tick.
- Float-arithmetic-based — non-deterministic across CPU architectures (x86-64 vs ARM64 will diverge on identical seeds).

**Two sub-options, both with caveats:**
- **B.1:** Accept non-determinism for RENDER-position-only modulation; freeze sim-position to the un-modulated waypoint. Steering becomes a visual smoothing layer, not a gameplay layer. Determinism preserved. Drift risk: visual position diverges from sim position; UI overlays (selection ring, health bar) anchor to visual position and may flicker.
- **B.2:** Run RVO inside `_sim_tick` with a custom implementation seeded by `GameRNG`. Multi-day work; may require shadowing Godot's `NavigationServer3D` with a custom service. Not realistic for wave 1C.

**Path B's determinism question is a design-mode escalation, not an implementation choice.** The Sim Contract §1.6 rule and `MatchHarness` determinism regression test (TESTING_CONTRACT §6.2) both demand bitwise-equal endpoints across runs; B.1 risks visual drift, B.2 is a multi-week project. **Path A is unaffected by this question** — `map_get_path()` on a deterministic navmesh produces deterministic waypoints; the region rebake itself is deterministic.

### 3.3 Migration impact

- ~500-700 line diff across 10 scenes + 1 component rewrite + path scheduler.
- Existing 535+ tests at risk: any test that injects `MockPathScheduler` and asserts on `_waypoints` semantics will need adaptation.
- 1-2 days end-to-end, **plus** the determinism work which is the wild card.

**If lead pivots to Path B,** request a dedicated design-mode sync first to ratify the determinism approach (B.1 visual-smoothing vs B.2 custom RVO). Implementation is unblocked only AFTER that ratifies.

---

## 4. Lint rule L6 readiness (Path A — for qa-engineer's deployment)

> **NOT FOR DEPLOYMENT THIS ROUND.** qa-engineer adds this to `tools/lint_simulation.sh` after lead ratifies Path A. The rule deploys alongside the scene edits.

### 4.1 Rule specification

| ID | Pattern (ripgrep) | Scope | Rationale |
|---|---|---|---|
| L6 | `\bbake_navigation_mesh\s*\(` | `game/scripts/**/*.gd` minus `game/scripts/world/terrain.gd` | Full-map navmesh rebake forbidden outside terrain bootstrap. |

### 4.2 Why this is the right pattern (not over-broad, not under-broad)

- **`\bbake_navigation_mesh\s*\(` catches direct method calls.** This is the full-map rebake API on `NavigationRegion3D` — the operation we deliberately forbid because of cost and determinism concerns.
- **It does NOT match `region_bake_navigation_mesh`** — that's a `NavigationServer3D` method, lowercase, called by the engine internally when an obstacle with `affect_navigation_mesh = true` enters the tree. Gameplay code calling it directly would be a different forbidden pattern; the engine's automatic call is unconcerned.
- **It does NOT match `.tscn` property assignments** like `affect_navigation_mesh = true`. Those are static scene-author declarations, not runtime mutations — they configure the engine's automatic carve once at scene load. No `.gd` code is invoking the carve.
- **The `\s*\(` enforces "method call" shape** — protects against false positives on comments mentioning the method name in prose.

### 4.3 Deployment shape in `tools/lint_simulation.sh`

Append after L5 (line 239) as a new block following the existing pattern:

```bash
# ---------------------------------------------------------------------------
# L6 — Manual full-map navmesh rebake outside terrain bootstrap
#
# Rationale: the navmesh is baked ONCE at terrain.gd:_ready() (Sim Contract /
# RESOURCE_NODE_CONTRACT.md §3.2). Localized region rebakes triggered by
# NavigationObstacle3D children with affect_navigation_mesh = true are
# permitted (engine-managed, automatic). What is forbidden is gameplay code
# calling bake_navigation_mesh() directly — that's a full-map rebuild and
# breaks both the cost discipline and the determinism contract for
# AI-vs-AI sims.
#
# Allowlist (files exempt from L6):
#   game/scripts/world/terrain.gd — the canonical bootstrap site
#
# Scope: game/scripts/**/*.gd minus the allowlist
# ---------------------------------------------------------------------------

L6_PATTERN='\bbake_navigation_mesh\s*\('
L6_ALLOWLIST_TERRAIN="${SCRIPTS_DIR}/world/terrain.gd"

L6_HITS="$(rg --with-filename --line-number "${L6_PATTERN}" \
  --glob '*.gd' \
  "${SCRIPTS_DIR}" 2>/dev/null || true)"

# Remove allowlisted file from results.
if [[ -n "${L6_HITS}" ]]; then
  L6_HITS="$(echo "${L6_HITS}" | grep -v "^${L6_ALLOWLIST_TERRAIN}:" || true)"
fi

# Filter out comment lines (defensive — same rationale as L3).
if [[ -n "${L6_HITS}" ]]; then
  L6_HITS="$(echo "${L6_HITS}" | rg -v ':[0-9]+:\s*#' || true)"
fi

if [[ -n "${L6_HITS}" ]]; then
  _fail_header "L6" "Manual full-map bake_navigation_mesh() call outside terrain bootstrap"
  echo "│    Allowed only in: ${L6_ALLOWLIST_TERRAIN}"
  echo "│    Localized region rebakes via NavigationObstacle3D"
  echo "│    affect_navigation_mesh = true are engine-managed and permitted."
  echo "${L6_HITS}" | sed 's/^/│    /'
  _fail_footer
fi
```

### 4.4 Canonical violation example (for the lint script's header comment)

```gdscript
# Forbidden — gameplay code triggering full-map navmesh rebake at runtime.
# L6 catches this. The cost (O(map_area)) and determinism risk make this
# operation acceptable ONLY at terrain.gd:_ready() bootstrap.
func _on_placement_complete() -> void:
    var nav: NavigationRegion3D = get_tree().root.find_child("Terrain", true, false)
    nav.bake_navigation_mesh(false)   # ← L6 catches this

# Permitted — declarative obstacle in .tscn. Engine handles the localized
# region rebake automatically when the obstacle enters the scene tree.
# (.tscn property assignment, not a method call — L6 regex doesn't match.)
#   [node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
#   affect_navigation_mesh = true
#   vertices = PackedVector3Array(...)
```

### 4.5 Pre-deployment validation

Before deploying L6, qa-engineer runs `tools/lint_simulation.sh` against the current main branch. Expected: 0 violations (no gameplay code currently calls `bake_navigation_mesh()` — verified via `grep -rn "bake_navigation_mesh" game/scripts/`). If a hit surfaces in a non-terrain.gd file, that's a pre-existing violation that wave 1C Track 3 must resolve before L6 ratifies. (Per a quick session-3 grep: only `terrain.gd:79` matches. Clean.)

---

## 5. RNC §3.2 v1.4.0 prose proposal (supersedes v1.3.1)

> **NOT FOR COMMIT THIS ROUND.** Lands AFTER Path A's live-test gate passes. The v1.3.1 honesty correction stays in place until v1.4.0 supersedes it.

### 5.1 What this version does

RNC §3.2 currently (v1.3.1, commit `98dfc18`) contains the honesty correction documenting that obstacles are inert and the wave 1C spike will ratify a resolution path. The v1.4.0 patch:

1. **Replaces** the v1.3.1 honesty-correction block (lines 211-218) with positive prose describing the ratified Path A mechanism.
2. **Preserves** the pre-v1.3.1 archaeology block (lines 220-227) — historical record per §9 retro discipline.
3. **Updates** §3.2's depleted-mine ruins-policy prose to reflect that under Path A, depletion does not auto-remove the obstacle (the obstacle is a `_ready`-time child; nothing in the depletion path removes it).
4. **Bumps** the contract version to 1.4.0 (MINOR per SemVer 2.0.0 §13 — additive correction, no breaking API change; consumers of the §3.2 fact-pattern adopt seamlessly).
5. **Adds** a cross-reference to `docs/WAVE_1C_NAVMESH_SPIKE.md` (this report) for the spike's full evidence base.

### 5.2 Draft prose (v1.4.0 §3.2)

```markdown
### 3.2 `NavigationObstacle3D` ownership (v1.4.0)

Each `MineNode` and structural `Building` scene includes a `NavigationObstacle3D` child configured at authoring time with `affect_navigation_mesh = true` and a `vertices: PackedVector3Array` polygon matching the building footprint. When the obstacle enters the scene tree, the parent `NavigationRegion3D` (`terrain.gd`) automatically issues a **localized region rebake** via `NavigationServer3D` — the rebake is bounded by the obstacle's AABB plus a small margin, NOT a full-map rebuild. The rebake is engine-managed and asynchronous; gameplay code never calls `bake_navigation_mesh()`. The single sanctioned full-map bake remains `terrain.gd:_ready` at scene load.

**CI lint rule L6** (`tools/lint_simulation.sh`) enforces this: any call to `bake_navigation_mesh\(` in `game/scripts/**/*.gd` outside `terrain.gd` fails the pre-commit gate.

**Why this works in Godot 4.6:** `NavigationObstacle3D` operates in two independent modes. The mode used here is the **static-carve mode** (`affect_navigation_mesh = true` + `vertices` polygon), which contributes to `NavigationServer3D.map_get_path()` queries by carving the navmesh region. The alternative **dynamic-RVO mode** (radius-only obstacles + `NavigationAgent3D` consumers with `avoidance_enabled = true`) does not affect path queries and is NOT used in this project — workers' `MovementComponent` invokes `NavigationServer3D.map_get_path()` directly without a `NavigationAgent3D` intermediary. See `docs/WAVE_1C_NAVMESH_SPIKE.md` for the full ratification evidence base.

**Polygon sizing rule.** The carve polygon should be `(footprint_half_width + 0.1)` from the obstacle center in each XZ direction. The 0.1m margin compensates for the navmesh `agent_radius = NAV_AGENT_RADIUS = 0.5` erosion — without it, the eroded navmesh edge flushes with the visual silhouette and workers may snag at corners. Footprint dimensions per concrete subclass:

| Scene | Footprint (X × Z) | Polygon (vertices, ±) |
|---|---|---|
| `building.tscn` (Khaneh base) | 2.0 × 2.0 | ±1.1 |
| `madan.tscn` | 2.5 × 2.5 | ±1.35 |
| `mazraeh.tscn` | 4.0 × 4.0 | **NONE — walkable** |
| `mine_node.tscn` (Coin deposit) | r = 0.75 cylinder | 8-vertex octagon at r = 0.85 |
| `sarbazkhane.tscn` (wave 2A) | TBD | Override base when wave 2A scope sizes the mesh |

**Depleted mine policy.** When a `MineNode` depletes (`is_gatherable = false`), the `NavigationObstacle3D` stays active — the engine continues carving the navmesh, and workers continue routing around the derelict deposit. This matches the Shahnameh intent (mining sites leave navigationally impassable ruins) and Path A naturally supports it: the obstacle is a `_ready`-time child of the mine, not depletion-state-dependent. No code path removes the obstacle. If post-MVP design adds a "clear ruins" mechanic (escalated to `QUESTIONS_FOR_DESIGN.md`), the cleanup path would set `affect_navigation_mesh = false` (or `queue_free` the obstacle node) and the engine would revert the localized navmesh region.

**Behavioral test discipline.** Tests of structural elements whose purpose is to cause an effect on adjacent systems (NavigationObstacle3D, CollisionShape3D, signal subscriptions, etc.) MUST assert the EFFECT, not just the presence — see `docs/STUDIO_PROCESS.md` §9 "Cross-cutting structural claims require behavioral assertions" rule (2026-05-15 — added in direct response to the L25 finding). The `test_phase_3_nav_obstacle_carving.gd` integration test backfills this for navmesh obstacles: it places a building, queries `NavigationServer3D.map_get_path()` from a worker's spawn point to a target on the opposite side, and asserts the returned waypoints route AROUND the building's footprint (no waypoint inside the carved region). Headless-test compatibility is preserved because the test uses the REAL `NavigationAgentPathScheduler`, not `MockPathScheduler` (the mock returns straight-line paths and would not exercise the carve).

---

**Pre-v1.4.0 prose retained below for archaeology — DO NOT TRUST as current behavior:**

[... v1.3.1 honesty correction block + pre-v1.3.1 historical prose retained verbatim ...]
```

### 5.3 Version bump rationale (per §13 SemVer 2.0.0)

- v1.3.0 → v1.3.1: PATCH — surgical honesty correction (no behavior change; doc-only diagnostic).
- **v1.3.1 → v1.4.0: MINOR** — additive content (positive Path A mechanism prose, L6 lint rule cross-reference, polygon sizing table, depletion policy, behavioral-test discipline). Consumers (world-builder, qa-engineer, future Sarbaz-khaneh implementer) adopt without breakage. No removed APIs, no changed semantics for existing in-flight code.

### 5.4 Provenance line for the v1.4.0 frontmatter

```
provenance: ... v1.3.1 (2026-05-15, 98dfc18): honesty correction for the NavigationObstacle3D inert finding (L25). v1.4.0 (post-spike-ratification-date): resolves L25 + L26 with Path A — engine-managed localized region rebake via affect_navigation_mesh + vertices polygon. Lint rule L6 deployed. Behavioral-test backfill for nav-obstacle behavior. See docs/WAVE_1C_NAVMESH_SPIKE.md for full spike report.
```

---

## 6. Behavioral-vs-structural test backfill plan

Per the §9 2026-05-15 rule (added in response to L25): "Cross-cutting structural claims require behavioral assertions, not presence assertions." The existing NavigationObstacle3D tests assert presence; they must be supplemented with behavioral assertions verifying the obstacle actually blocks pathing.

### 6.1 Inventory of existing presence-only assertions (the gap)

| Test file | Line(s) | Asserts |
|---|---|---|
| `tests/unit/test_building_base.gd` | 82-91 | `_building.get_node_or_null(^"NavigationObstacle3D")` is not null AND is the right type. **No behavioral check.** |
| `tests/unit/test_khaneh.gd` | 61-62 | Same — presence-only. |
| `tests/unit/test_madan.gd` | 299-310 | Same — presence-only. Comments hint at "workers route AROUND" but no assertion verifies it. |
| `tests/unit/test_mazraeh.gd` | 322-328 | **CORRECT** — asserts ABSENCE for Mazra'eh (workers walk onto). Mazra'eh's case doesn't need the backfill; ABSENCE is itself a behavioral claim verifiable by inspection. Keep as-is. |
| `tests/integration/test_phase_3_khaneh_placement.gd` | 247-276 | Asserts placed Khaneh has the obstacle. Presence-only. |
| `tests/integration/test_phase_3_nav_obstacle_carving.gd` | Various flows | **Mixed.** Flow 4 (lines 241-291) explicitly disclaims: *"MockPathScheduler ignores the navmesh — actual avoidance is a LIVE-GAME F5 test, not headless."* This is the spike's load-bearing gap — headless-mode tests deliberately do NOT exercise carving because the existing harness uses the mock. |

The disclaimer at `test_phase_3_nav_obstacle_carving.gd:285-291` is honest about the gap. Backfill closes it.

### 6.2 Backfill prescription (one new integration test)

**File:** `game/tests/integration/test_phase_3_nav_obstacle_carving_behavioral.gd`

**Owner:** qa-engineer (post-Path-A ratification; this test ratifies the live-test gate from §1.4 into a headless regression).

**Shape:**

```gdscript
# Integration test — verifies NavigationObstacle3D + affect_navigation_mesh + vertices
# actually causes NavigationServer3D.map_get_path() to route around carved obstacles.
#
# This is the BEHAVIORAL backfill for the existing presence-only nav-obstacle tests
# (test_building_base.gd, test_khaneh.gd, test_madan.gd, test_phase_3_nav_obstacle_carving.gd).
# It uses the REAL NavigationAgentPathScheduler, not MockPathScheduler — the mock
# returns straight-line paths and would not exercise the carve.
#
# Per docs/STUDIO_PROCESS.md §9 (2026-05-15 rule): cross-cutting structural claims
# require behavioral assertions, not presence assertions. Cite the L25 finding.

extends "res://addons/gut/test.gd"

const KhanehScene := preload("res://scenes/world/buildings/khaneh.tscn")
const MadanScene := preload("res://scenes/world/buildings/madan.tscn")
const TerrainScene := preload("res://scenes/world/terrain.tscn")
const RealScheduler := preload("res://scripts/navigation/navigation_agent_path_scheduler.gd")

var _terrain: Node3D


func before_each() -> void:
    _terrain = TerrainScene.instantiate()
    add_child_autofree(_terrain)
    # Terrain bakes in _ready; wait one frame for the bake to settle.
    await get_tree().process_frame


# ---------------------------------------------------------------------------
# Khaneh — placed at world origin must carve the navmesh.
# Worker pathing from (0, 0, -10) to (0, 0, 10) should route AROUND it.
# ---------------------------------------------------------------------------
func test_khaneh_carves_navmesh_path_routes_around() -> void:
    var khaneh: Node3D = KhanehScene.instantiate()
    add_child_autofree(khaneh)
    khaneh.global_position = Vector3.ZERO
    # Wait one frame for the localized region rebake to complete.
    await get_tree().process_frame

    var scheduler: RealScheduler = RealScheduler.new()
    var req_id: int = scheduler.request_repath(
        99, Vector3(0, 0, -10), Vector3(0, 0, 10), 0
    )
    var result: Dictionary = scheduler.poll_path(req_id)
    assert_eq(int(result.state), 1, "Path must resolve to READY (1)")
    var waypoints: PackedVector3Array = result.waypoints
    assert_gt(waypoints.size(), 2,
        "Carved path should produce intermediate waypoints (route around), "
        + "not a straight line of 2 waypoints. Actual: " + str(waypoints.size()))

    # Behavioral assertion: no waypoint sits inside the carved footprint.
    # Khaneh footprint half-width = 1.0; carve polygon is ±1.1; any waypoint
    # whose XZ distance from origin is < 1.1 indicates the carve failed.
    for wp in waypoints:
        var xz_dist: float = Vector2(wp.x, wp.z).length()
        assert_gte(xz_dist, 1.0,
            "Waypoint at " + str(wp) + " (XZ dist " + str(xz_dist) + ") "
            + "must route around Khaneh's 2x2 footprint (≥ 1.0 from origin)")


# ---------------------------------------------------------------------------
# Ma'dan — same behavioral check, larger footprint (2.5×2.5).
# ---------------------------------------------------------------------------
func test_madan_carves_navmesh_path_routes_around() -> void:
    var madan: Node3D = MadanScene.instantiate()
    add_child_autofree(madan)
    madan.global_position = Vector3.ZERO
    await get_tree().process_frame

    var scheduler: RealScheduler = RealScheduler.new()
    var req_id: int = scheduler.request_repath(
        99, Vector3(0, 0, -10), Vector3(0, 0, 10), 0
    )
    var result: Dictionary = scheduler.poll_path(req_id)
    var waypoints: PackedVector3Array = result.waypoints
    for wp in waypoints:
        var xz_dist: float = Vector2(wp.x, wp.z).length()
        assert_gte(xz_dist, 1.25,
            "Waypoint at " + str(wp) + " must route around Ma'dan's "
            + "2.5x2.5 footprint (≥ 1.25 from origin)")


# ---------------------------------------------------------------------------
# Mazra'eh — control case. Workers walk THROUGH (footprint is walkable per
# RNC §3.2 — Mazra'eh has no NavigationObstacle3D). Straight-line path
# should resolve through the origin.
# ---------------------------------------------------------------------------
func test_mazraeh_does_not_carve_path_goes_through() -> void:
    var MazraehScene := preload("res://scenes/world/buildings/mazraeh.tscn")
    var mazraeh: Node3D = MazraehScene.instantiate()
    add_child_autofree(mazraeh)
    mazraeh.global_position = Vector3.ZERO
    await get_tree().process_frame

    var scheduler: RealScheduler = RealScheduler.new()
    var req_id: int = scheduler.request_repath(
        99, Vector3(0, 0, -10), Vector3(0, 0, 10), 0
    )
    var result: Dictionary = scheduler.poll_path(req_id)
    var waypoints: PackedVector3Array = result.waypoints
    # Straight-line path: should be exactly 2 waypoints (start, end) on the
    # flat plane. If the optimizer collapses colinear segments, the path
    # passes through the origin.
    assert_eq(waypoints.size(), 2,
        "Walkable Mazra'eh must allow a straight-line 2-waypoint path "
        + "(no carve). Actual waypoints: " + str(waypoints.size()))
```

### 6.3 Optional: enrich existing presence-only tests with a behavioral assertion

For each of `test_building_base.gd`, `test_khaneh.gd`, `test_madan.gd`, add a small assertion to the existing nav-obstacle test:

```gdscript
# Behavioral discipline — per docs/STUDIO_PROCESS.md §9 (2026-05-15 rule):
# presence alone is insufficient. The obstacle must declare it carves the
# navmesh (affect_navigation_mesh = true) and provide a non-empty polygon.
assert_true(nav.affect_navigation_mesh,
    "NavigationObstacle3D must have affect_navigation_mesh = true "
    + "(per RNC §3.2 v1.4.0). Without this, the obstacle is inert.")
assert_gt(nav.vertices.size(), 2,
    "NavigationObstacle3D must declare a vertices polygon "
    + "(at least 3 vertices). Without vertices, affect_navigation_mesh "
    + "has no shape to carve.")
```

This is a unit-level guard — cheaper than the integration test but only verifies the CONFIG, not the effect. The integration test from §6.2 verifies the effect. Both layers complement each other.

### 6.4 Test count delta

- New integration tests: 3 (Khaneh blocks, Ma'dan blocks, Mazra'eh-walkable control).
- Augmented unit tests: 4 (`test_building_base.gd` +1 assertion, `test_khaneh.gd` +2, `test_madan.gd` +2, `test_phase_3_nav_obstacle_carving.gd` augmented to assert `affect_navigation_mesh` on each obstacle).
- Net: +3 integration tests, +5-8 unit-test assertions.

Test count goes from current ~535+ to ~538+ (within session 3 wave 1C scope; well under the 100-line wave-cap implied for individual scope).

---

## 7. Risks and what could go wrong

### 7.1 Risk: Godot 4.6.2 `affect_navigation_mesh` doesn't behave as docs claim

**Likelihood: low.** The pattern is widely documented in Godot 4.x community examples + the official `NavigationObstacle3D` documentation. The session 2 investigation is consistent with that documentation.

**Mitigation:** the live-test gate in §1.4 is the empirical confirmation. If it fails, the spike re-opens with Path B as the fallback. The decision memo (this report) is structured so that flipping to Path B requires only §3 to ratify, not a re-write.

### 7.2 Risk: scene-inheritance doesn't propagate `vertices` from base to subclass

**Likelihood: medium-low.** Godot 4's scene-inheritance handles `PackedVector3Array` properties correctly in most cases, but `format=3` scenes can occasionally serialize array overrides differently from primitive overrides.

**Mitigation:** §2.2 (Khaneh) explicitly flags this as a sanity-check item for world-builder. If inheritance doesn't propagate cleanly, the override is one node block — trivial to add explicitly.

### 7.3 Risk: localized region rebake fires async and the test-frame timing is brittle

**Likelihood: medium.** Godot's `NavigationServer3D` rebake is async by default; the `await get_tree().process_frame` in the test fixtures may need to be `await get_tree().process_frame` twice or three times depending on the engine's batching.

**Mitigation:** the test prescription in §6.2 uses `await` to yield once; if flakiness surfaces during the qa-engineer's TDD cycle, the await count expands until stable. Cite the technique from existing `test_phase_3_nav_obstacle_carving.gd` if needed.

### 7.4 Risk: per-tick region rebake cost compounds at Phase 6 AI scale

**Likelihood: low for MVP.** Phase 3-6 sees ≤20 buildings per side; rebakes fire once per building lifetime. Phase 6+ AI may spam building placement, but the rebake cost is proportional to the obstacle's AABB area (small for ~2×2 buildings).

**Mitigation:** §1.4's measurement plan logs perf numbers post-ratification. If Phase 6 surfaces cost spikes, fallback options include (a) building-placement queueing (one per tick instead of all-at-once) or (b) Path B migration if the cost is structural rather than batch-able.

### 7.5 Risk: depleted mines' obstacles cause unintended pathfinding deadlocks

**Likelihood: low.** Workers seek the nearest non-depleted mine via `ResourceSystem`; depleted ones are deprioritized. The only deadlock surface is if depleted mines cluster and trap a worker — but the navmesh agent_radius of 0.5 + 0.1m carve margin ensures there's always at least one waypoint slot between adjacent obstacles unless they're placed within 0.6m of each other (which the placement validity check should prevent at higher layers).

**Mitigation:** the design-mode escalation about "ruins clearing" already in `QUESTIONS_FOR_DESIGN.md` is the long-term answer if cluster-trapping surfaces.

---

## 8. Summary — what lead ratifies, what world-builder ships

### 8.1 Lead's decision gate

**Ratify: Path A (engine-managed localized region rebake via `affect_navigation_mesh = true` + `vertices` polygon).**

Or: re-open the spike with Path B if you disagree with the determinism / scope tradeoffs in §1.

### 8.2 If Path A ratifies, the follow-on commits are (in this order):

1. **World-builder commits the 4 scene edits** per §2 — Track 3's only mutation. (Sequential after Tracks 1 + 2 close per L23.)
2. **qa-engineer adds L6 to `tools/lint_simulation.sh`** per §4. (Bundled with #1 or its own commit; either works.)
3. **qa-engineer ships `test_phase_3_nav_obstacle_carving_behavioral.gd` + augments the 4 unit tests** per §6.
4. **engine-architect (me, or whoever) ships RNC §3.2 v1.4.0** per §5.
5. **Lead live-tests** per §1.4 (drive a worker through Khaneh + Ma'dan + Ma'dan-on-mine; control vs Mazra'eh). If it passes, declares L25 + L26 resolved. ARCHITECTURE.md §6 v0.22.0 entry follows.

### 8.3 What this report does NOT prescribe

- No timeline. Wave 1C's other tracks (Construction-timer state machine, UI progress bar, Building signal) sequence independently; Track 3 commits LAST per L23.
- No re-litigation of the v1.3.1 honesty correction. That commit (`98dfc18`) stays in history.
- No Sarbaz-khaneh implementation. Wave 2A's brief surfaces the requirement; this spike's prescription informs it.

---

*End of spike report. Awaiting lead ratification.*

— engine-architect-p3s2
