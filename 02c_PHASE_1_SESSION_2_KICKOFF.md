---
title: Phase 1 Session 2 Kickoff — Multi-Select, Formation Movement, HUD Polish
type: plan
status: living
version: 1.0.0
owner: team
summary: Session-2 recipe for Phase 1's second implementation session. Builds on session 1's single-click-and-move foundation: box-select, control groups, double-click-select-of-type, GroupMoveController for formation movement, Farr gauge polish, selected-unit panel. Includes Experiment 01 from PROCESS_EXPERIMENTS.md — live-game-broken-surface section per deliverable.
audience: all
read_when: starting-phase-1-session-2
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md, 02b_PHASE_1_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md]
ssot_for:
  - session-2 reading order
  - session-2 scoped slice and per-deliverable owner mapping
  - session-2 wave breakdown and dependency order
  - session-2 Definition of Done
  - Experiment 01 application surface (live-game-broken-surface section, per deliverable)
references: [02_IMPLEMENTATION_PLAN.md, 02b_PHASE_1_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, BUILD_LOG.md]
tags: [phase-1, session-2, multi-select, formation, hud, kickoff, recipe]
created: 2026-05-03
last_updated: 2026-05-03
---

# Phase 1 Session 2 Kickoff — Multi-Select, Formation Movement, HUD Polish

> **Mode:** implementation. Per `docs/STUDIO_PROCESS.md` §12, the studio process (syncs, OST patterns, Convergence Review) is dormant during implementation. Specialists work independently in their owned files using TDD discipline.

## 0. Why this doc exists

Session 1 shipped the smallest end-to-end RTS gesture: click a worker, right-click the ground, watch it walk. Session 2's job is to make that gesture *playable at scale* — multi-select, control groups, formation movement, HUD polish — the QoL features that turn "five boxes you can click one at a time" into something that feels like a real RTS.

This doc is **session-2-specific.** Subsequent Phase 1 sessions read `BUILD_LOG.md` for state and pick up from there.

This kickoff also runs **Experiment 01** from `docs/PROCESS_EXPERIMENTS.md` — the "live-game-broken-surface" intervention. See §6 for what that means and how it flows through every deliverable below.

## 1. Session-2 reading order (≈10 minutes)

1. **`MANIFESTO.md`** — principles. Constants behind every other rule.
2. **`CLAUDE.md`** — project instructions, file ownership, escalation rules.
3. **`docs/ARCHITECTURE.md`** — orientation layer. After session-1 merge, the unit core, selection, and click input rows are `✅ Built`. Session 2 picks up the `📋 Planned` rows in §2 for multi-select, GroupMoveController, Farr gauge, selected-unit panel.
4. **`docs/STUDIO_PROCESS.md`** §12 — operating modes + TDD discipline.
5. **`docs/PROCESS_EXPERIMENTS.md` Experiment 01** — what we're measuring this session and why every brief has a "live-game-broken-surface" section. **Critical reading.**
6. **`02b_PHASE_1_KICKOFF.md`** — session 1's recipe, especially the Definition of Done (§73) and the LATER items that bit us (FSM tick wiring, edge-pan, mouse_filter). Session 2 must not regress any of these.
7. **`02_IMPLEMENTATION_PLAN.md` Phase 1 section** — the full task list.
8. **`docs/STATE_MACHINE_CONTRACT.md`** — your unit-state framework. Session 2 doesn't add new states but `GroupMoveController` interacts with command queues and dispatch.
9. **`docs/SIMULATION_CONTRACT.md`** §1.5 (UI off-tick rule), §3 (SpatialIndex), §4 (IPathScheduler) — the engine layer everything sits on. The `&"input"` phase is finally going to have meaningful work this session (control-group hotkey resolution).
10. **`BUILD_LOG.md`** — session 1's three live-game bugs (FSM tick, edge-pan, mouse_filter) and the patterns that caught them. Read the LATER items list — one of them (`MovementSystem` phase coordinator) is now session-3 candidate, not session-2.
11. **This doc** — for the scoped slice, dependency order, wave breakdown, and Experiment 01 surface below.

## 2. The Session-2 scoped slice

Session 2 attacks **multi-unit interaction**: how the player commands more than one unit at a time, and how those units behave together.

### Session-2 deliverables (with owners and live-game-broken-surface checklist)

Per Experiment 01: every deliverable below includes a `Live-game-broken-surface` block. The owning agent must answer all three questions in their commit body or BUILD_LOG entry before declaring done. Headless tests + this block are the agent's quality bar.

---

#### 1. Box / drag selection

Left-click-drag draws a screen-space rectangle. On release, every `SelectableComponent` whose unit's projected screen position falls inside the rect is selected. Standard RTS marquee select. Shift-modified drag *adds* to selection rather than replacing.

**Owner:** ui-developer.

**Reads:** `docs/SIMULATION_CONTRACT.md` §3 (SpatialIndex projection), `game/scripts/autoload/selection_manager.gd` (existing API: `select`, `select_only`, `add_to_selection`, `deselect_all`).

**Writes:** New script under `game/scripts/input/box_select_handler.gd`. Updates to `game/scenes/main.tscn` if a top-level overlay node is needed for the rectangle visual.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The drag overlay (a `Control` or `CanvasItem` drawing the rectangle) must NOT swallow click events that pass through it during drag — see session 1's `mouse_filter` bug. Test mode can mock the screen-to-world projection; live mode runs through real `Camera3D.unproject_position` per-frame on every selectable, and the cost of that scales with unit count.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Visual: rectangle alignment with cursor, snap behavior on release, transparency choice. Behavioral: drag-from-HUD-into-world should not select units (HUD must catch click on press); drag from one corner to the diagonal opposite must work in all four directions.
3. *What's the minimum interactive smoke test that catches it?*
   Lead drags from top-left to bottom-right across the kargars: all 5 selected, gold rings appear. Lead drags from bottom-right to top-left: same result (axis-agnostic). Lead Shift-drags a partial subset: only those added.

**Out of scope here:** Lasso / freeform selection (StarCraft-style — not needed). Subgroups (one selection contains multiple types — handled by selected-unit panel, deliverable 6).

---

#### 2. Control groups (Ctrl+1–9 to bind, 1–9 to recall)

Pressing `Ctrl+N` (where N ∈ 1..9) binds the current selection to control group N. Pressing `N` alone replaces the current selection with the contents of control group N. Pressing `N` twice in quick succession (≤350ms) centers the camera on the group's centroid.

**Owner:** ui-developer.

**Reads:** `selection_manager.gd`, `camera_controller.gd` (for centering).

**Writes:** New script under `game/scripts/input/control_groups.gd` (probably an autoload — control groups outlive any single scene). Updates to `game/project.godot` if InputMap actions are added.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   `Input.is_action_pressed` requires the action to exist in `project.godot` `[input]` section. Headless test fixtures bypass this entirely. Modifier-key state (Ctrl held vs. not) interacts with OS-level key repeat differently in test vs. live.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Double-tap timing feel — 350ms is a guess; lead may want 250ms or 500ms based on muscle memory. Whether the camera centering is instant (snap) or animated (lerp). Whether `Ctrl+1` accidentally fires `Ctrl+1+2` if the player is sloppy.
3. *What's the minimum interactive smoke test that catches it?*
   Lead boxes 3 kargars, hits Ctrl+1, deselects, hits 1, sees the same 3 selected. Hits 1 again quickly, camera centers on them. Binds a different selection to Ctrl+2. Toggles between 1 and 2 — both work, neither corrupts the other.

**Out of scope here:** Control group append (Shift+N to add). Control group display in HUD (the row of numbered icons at screen-bottom — Phase 2+).

---

#### 3. Double-click-select-of-type

Double-clicking a unit (≤300ms between clicks) selects all visible-on-screen units of the same `unit_type` (currently only `&"kargar"`).

**Owner:** ui-developer.

**Reads:** `selection_manager.gd`, `click_handler.gd` (existing single-click flow), `Camera3D.unproject_position` for "visible on screen" filter.

**Writes:** Updates to `click_handler.gd` to detect double-click. May extract a "type-select" helper into a small utility script.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   Visibility test — `unproject_position` returns world coords as 2D screen coords; we need to clip against viewport rect AND check the unit isn't behind the camera (z<0). Headless test can fake this; live game can break it.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Double-click timing feel (300ms guess — same questions as control groups). Whether the visible-filter actually does the right thing when the player is zoomed out and most kargars are off-screen.
3. *What's the minimum interactive smoke test that catches it?*
   Lead double-clicks one kargar with all 5 visible: all 5 selected. Lead pans so only 2 are on screen, double-clicks one of them: only those 2 selected.

**Out of scope here:** Right-click double-click semantics (no special meaning). Triple-click (no special meaning).

---

#### 4. `GroupMoveController` (formation movement)

When N units are selected and the player right-clicks a target, the units do NOT all path to the same exact point (which causes them to pile up and shove each other). Instead, the controller distributes the target across an offset pattern (small grid or ring around the click), and each unit gets a slightly different target. Phase 1 ships the simplest distribution that prevents pile-up; Phase 2 may add facing/rotation.

**Owner:** ai-engineer.

**Reads:** `docs/SIMULATION_CONTRACT.md` §4 (IPathScheduler), `game/scripts/units/components/movement_component.gd`, `game/scripts/units/unit.gd::replace_command`.

**Writes:** New script under `game/scripts/ai/group_move_controller.gd` (or `game/scripts/movement/`). Probably a static class or RefCounted with one public method `dispatch_group_move(units: Array, target: Vector3) -> void`.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   Real navmesh + real `NavigationAgentPathScheduler` may snap each unit's offset target to the nearest navmesh point — depending on offset distance, multiple units could end up snapping to the same point anyway, defeating the purpose. Test fixtures use MockPathScheduler which just returns straight-line targets.
2. *What can a headless test not detect that the lead would notice in the editor?*
   The shape of the formation — does a 5-unit move look like a tidy ring, a wedge, or a chaotic blob? Whether units overshoot each other and re-collide visibly. Whether the formation rotates to face the move direction (it shouldn't yet — that's Phase 2).
3. *What's the minimum interactive smoke test that catches it?*
   Lead box-selects all 5 kargars and right-clicks a far point: all 5 walk there and arrive at slightly-different spots, no visible piling. Lead right-clicks while they're still moving: they redirect cleanly with new offsets.

**Out of scope here:** Facing / rotation. Formation type selection (line, wedge, etc. — Phase 2). Reservation-based pathing (Phase 3+ when buildings exist).

---

#### 5. Farr gauge polish (circular gauge replacing text readout)

Phase 0 / session 1 shipped Farr as a text readout in the HUD ("Farr: 50"). Session 2 replaces it with a circular gauge — a `TextureProgressBar` or hand-drawn `Polygon2D` arc — that fills from 0 to `FARR_TIER2_THRESHOLD` (per `BalanceData.farr_config`). The Kaveh-trigger threshold is marked with a tick or color band.

**Owner:** ui-developer (split candidate: balance-engineer does the data wiring and threshold reads; ui-developer does the visual). Lead's call which one owns it.

**Reads:** `game/scripts/autoload/farr_system.gd`, `game/data/balance.tres` (Farr config sub-resource).

**Writes:** Updates to `game/scenes/ui/resource_hud.tscn` — likely a new sub-scene `farr_gauge.tscn`.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The gauge listens to `EventBus.farr_changed` and updates visually. Headless tests can verify the listener fires; live game can show a stale gauge if the redraw is missed (e.g., the property setter doesn't trigger `queue_redraw`).
2. *What can a headless test not detect that the lead would notice in the editor?*
   Visual: anchor in the HUD, scale, color choice, animation on change (snap vs. tween), readability at default zoom. Whether the gauge's anchor preset works at non-1280×720 viewport sizes.
3. *What's the minimum interactive smoke test that catches it?*
   Lead boots, sees the gauge filled to ~50/100 default. Lead enables a debug shortcut to bump Farr by ±10 (or uses an existing test hook): gauge updates smoothly. Lead hits the Tier 2 threshold: visual cue fires.

**Out of scope here:** Kaveh Event trigger animation (Phase 2+). Multi-Farr-tier color stages beyond the threshold tick.

---

#### 6. Selected-unit panel

Bottom-left detail panel that shows the currently-selected unit's portrait (placeholder rect), HP bar, type name, and an abilities row (placeholder buttons for now). When a multi-selection is active, the panel switches to a small icon grid showing each selected unit; clicking an icon narrows the selection to just that one unit.

**Owner:** ui-developer.

**Reads:** `selection_manager.gd`, `EventBus.selection_changed`, `Unit.get_health()`, `Unit.unit_type`.

**Writes:** New scene `game/scenes/ui/selected_unit_panel.tscn` + script.

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The panel listens to `EventBus.selection_changed` and to each selected unit's `EventBus.unit_health_changed` (or similar — verify). When a unit dies (queue_free), the panel must drop the icon without crashing — defensive `is_instance_valid` check needed.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Visual layout in HUD bottom-left, anchor presets, sizing at different viewport sizes. Whether the placeholder portrait looks bad enough to distract from the gameplay test. Multi-select icon grid layout — overflows past 9? 12?
3. *What's the minimum interactive smoke test that catches it?*
   Lead selects 1 kargar: panel shows portrait + HP + type. Lead box-selects all 5: panel shows 5 icons. Lead clicks one of the 5 icons: selection narrows to that one. Lead deselects: panel goes blank or shows "no selection."

**Out of scope here:** Real portraits (placeholder rects only — design chat hasn't approved art). Real ability buttons (placeholder rects). Build menu in the panel (Phase 3 — when buildings exist).

---

### Definition of Done for Session 2

A future-you (or any agent) opens the project on macOS Apple Silicon and:

1. Launches the game (F5 in editor).
2. Sees 5 kargars on the terrain (session-1 baseline).
3. Box-drags a rectangle around 3 of them → those 3 are selected (gold rings on those 3, none on the others).
4. Hits `Ctrl+1` → those 3 are bound to control group 1.
5. Clicks elsewhere to deselect → no rings.
6. Hits `1` → the same 3 are re-selected.
7. Hits `1` again within ~350ms → camera centers on the group.
8. Right-clicks a far point with the 3 selected → all 3 walk there in a small offset pattern, no visible piling.
9. Double-clicks one kargar → all visible kargars on screen are selected.
10. Selected-unit panel shows the right info for single and multi selection.
11. Farr gauge is the new circular shape, not the text readout.
12. Tests pass headless (target: ≥430 tests, +50 from session 1's 380). Lint clean. Pre-commit gate green.
13. `docs/ARCHITECTURE.md` §2 reflects the new build state (rows for box-select, control groups, GroupMoveController, Farr gauge, selected-unit panel all → `✅ Built`).
14. **Experiment 01 verdict filled** in `docs/PROCESS_EXPERIMENTS.md`.

If all of those work, **Phase 1 session 2 is done.** Session 3 (if any) adds multiple unit types or jumps to Phase 2 combat.

### What's deliberately NOT in session 2

- Multiple unit types beyond Kargar (Piyade, Kamandar, Savar, Asb-savar, Rostam) — Phase 2 onward.
- Combat / damage / death — Phase 2.
- Resource gathering — Phase 3.
- Building placement — Phase 3.
- Real art assets — until design chat green-lights.
- `MovementSystem` phase coordinator — still LATER. Session 1's transitional `Unit._on_sim_phase` works fine for ≤100 units.
- Subgroups beyond the panel-icon-narrowing UX — Phase 2+.

## 3. Wave breakdown

**Wave 1 — independent foundations (parallel agents):**

- **ui-developer** wave 1A: Box-select (deliverable 1). The selection-broadcast API exists; box-select adds a new caller. No coordination needed with other agents.
- **ai-engineer** wave 1B: `GroupMoveController` skeleton (deliverable 4). Builds the dispatch logic in isolation; wires to right-click in wave 2.
- **balance-engineer** wave 1C: Farr gauge data plumbing + initial visual (deliverable 5). Pure data + visual work; doesn't touch selection or movement.

**Wave 2 — composition (depends on wave 1):**

- **ui-developer** wave 2A: Control groups (deliverable 2) + double-click-select-of-type (deliverable 3). Both consume the multi-select API from wave 1A.
- **ui-developer** wave 2B: Selected-unit panel (deliverable 6). Consumes `EventBus.selection_changed` (already shipped session 1).
- **ai-engineer** wave 2C: Wire `GroupMoveController` into the right-click path so multi-selected workers spread out instead of piling.

**Wave 3 — qa-engineer integration tests:**

- Box-select drag flow (synthetic InputEventMouseMotion + Button events).
- Control group bind/recall/center round-trip.
- Group-move pile-prevention (5-unit move to point, assert ≥4 distinct arrival positions within ε).
- Farr gauge listener fires on `apply_farr_change`.
- Selected-unit panel content correctness on selection / multi-select / death.

Wave 3 ships once waves 1+2 are merged on the session-2 branch. Lead live-tests after wave 2 ships, before wave 3.

## 4. TDD discipline reminders for implementation mode

Same as session 1, plus the Experiment-01 surface below (§6).

1. **Read the contract section before writing code.**
2. **Write failing tests first.** Use `MatchHarness` for integration tests.
3. **Update `docs/ARCHITECTURE.md` §2** as each subsystem moves through 📋 → 🟡 → ✅.
4. **Pre-commit gate is your safety net.**
5. **If the contract is wrong, escalate, don't silently invent.**

## 5. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + the §1 reading order).
2. Verify branch state (`git status` — should be on `feat/phase-1-session-2`, not `main`).
3. Check `BUILD_LOG.md` for Phase 1 session 1 final state.
4. Read `docs/PROCESS_EXPERIMENTS.md` Experiment 01 — understand the live-game-broken-surface section your brief includes.
5. Pick a task from §2 in your wave.

**During session:**
1. Read the relevant contract section.
2. Answer your deliverable's three live-game-broken-surface questions in a scratch buffer (commit body / BUILD_LOG draft).
3. Write a failing test.
4. Implement.
5. Refactor.
6. Update `docs/ARCHITECTURE.md` §2.
7. Commit on the feature branch with the live-game-broken-surface answers in the body.

**End of session:**
1. All tests pass; pre-commit hook clean.
2. `docs/ARCHITECTURE.md` accurately reflects what was built.
3. Append entry to `BUILD_LOG.md` (what shipped, what didn't, state for next session, live-game-broken-surface answers if not in commit).
4. **Lead live-tests** before merge — runs through DoD §73 items 3–11 in the editor, logs any live-game bugs found.
5. **Lead fills Experiment 01 verdict** in `docs/PROCESS_EXPERIMENTS.md` after merge.
6. Push to remote; PR.

## 6. Experiment 01 — Live-game-broken-surface intervention

**What:** Per `docs/PROCESS_EXPERIMENTS.md` Experiment 01, every deliverable in §2 above includes three questions the owning agent must answer:

1. What state/behavior must work at runtime that no unit test exercises?
2. What can a headless test not detect that the lead would notice in the editor?
3. What's the minimum interactive smoke test that catches it?

**Why:** Session 1 had three live-game bugs (FSM not ticked, edge-pan direction, mouse_filter eating clicks) that all passed every unit test. The hypothesis is that forcing agents to enumerate this surface BEFORE coding catches more of them at write-time.

**How agents apply it:**
- Read your deliverable's three answers (already pre-filled in §2 above as the lead's best guess; refine them as you understand the deliverable).
- Where feasible, write tests for the smoke-test scenarios — e.g., scene-loading integration tests that exercise the full live path, not just the unit's logic in isolation.
- Where not feasible (e.g., visual bugs), document clearly in the BUILD_LOG entry that the lead's live-test is the only catch.
- Commit the answers (with any refinements) in the commit body. They become part of the archaeological record alongside the code.

**Verdict:** Lead fills `docs/PROCESS_EXPERIMENTS.md` Experiment 01's metric table at session-2 merge.

## 7. After session 2

When `docs/ARCHITECTURE.md` §2 shows the session-2 rows at `✅ Built` and the milestone test in §2 passes (DoD items 1–14), session 2 is complete. Run a brief retro per `docs/STUDIO_PROCESS.md` §10. Then either:

- Plan session 3 (multiple unit types as colored variants of Kargar, with different stats reading from BalanceData), OR
- Jump to Phase 2 (combat — units that fight when commanded to attack each other).

Lead's call which path. The plan-vs-reality delta from this session may also surface contract gaps that need a brief design-mode sync.

---

*This doc is session-2-specific. After session 2, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state) + the implementation plan (next phase). This kickoff doc may be updated for Phase 2 kickoff or removed if it's no longer load-bearing.*
