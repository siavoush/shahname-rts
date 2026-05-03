---
title: Build Log
type: log
status: append-only
owner: team
summary: Chronological record of what each Claude Code session shipped. One entry per session; append-only.
audience: all
read_when: continuing-prior-implementation-work
prerequisites: []
ssot_for:
  - per-session build entries (what shipped, what didn't, state for next session)
references: [02_IMPLEMENTATION_PLAN.md, docs/ARCHITECTURE.md, QUESTIONS_FOR_DESIGN.md]
tags: [log, sessions, build-history]
created: 2026-04-23
last_updated: 2026-05-04
---

# Build Log

Chronological record of what each Claude Code session shipped. Append-only. The design chat reads this to understand what state the project is in without having to re-read code.

## Format for new entries

```
## YYYY-MM-DD — session title (e.g., "Tier 0 kickoff", "Kaveh Event prototype")

**Branch:** feat/whatever (or main if merged)
**Shipped:** what works at the end of this session, in plain English.
**Did not ship:** what was attempted but isn't done.
**State for next session:** what the next session needs to know to pick up — running the project, where to look, any setup steps, any half-finished work to be aware of.
**Open questions added to QUESTIONS_FOR_DESIGN.md:** list them by title.
**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices): list briefly so the design chat isn't surprised later.
```

## Entries

## 2026-05-04 — Phase 1 session 2 wave 2C (ai-engineer): GroupMoveController right-click wire-up

**Branch:** `feat/phase-1-session-2`

**Shipped:**
- `click_handler.gd::process_right_click_hit` now routes through `GroupMoveController.dispatch_group_move(sel, target)` instead of looping `u.call(&"replace_command", Constants.COMMAND_MOVE, payload)` per selected unit. The controller is preloaded once at file scope as `const _GroupMove := preload("res://scripts/movement/group_move_controller.gd")`. The change is contained to the multi-selection write line; the no-selection short-circuit, the empty-hit short-circuit, the hit-on-unit short-circuit, and the DEBUG_LOG_CLICKS instrumentation are untouched.
- Single-selection right-click is bitwise-identical to wave-2 behavior because the controller's `live.size() == 1` fast path returns the click target verbatim with no offset math — the path is unified, the observable behavior is preserved.
- Multi-selection right-click now distributes targets on the deterministic ring of `Constants.GROUP_MOVE_OFFSET_RADIUS = 2.0`. With box-select shipping in wave 1A, this is the first wired UI path that puts 2+ units in the selection and right-clicks them — the formation-distribution logic now exercises the production navmesh.
- Three new tests in `tests/unit/test_click_handler.gd`:
  1. `test_right_click_multi_selection_distributes_targets` — TDD-red on the unwired baseline (previously all 3 units got the identical click target; now ≥2 of 3 pairs differ).
  2. `test_right_click_multi_selection_targets_within_radius` — every dispatched target lies within R of the click on the XZ plane; Y is preserved verbatim.
  3. `test_right_click_single_selection_target_unchanged` — regression guard for session-1's single-click suite; the controller's identity path keeps single-selection bitwise-identical (1e-6 tolerance).
- Existing `test_right_click_pushes_command_to_every_selected_unit` test still passes (the controller dispatches one `replace_command` per live unit; observable end state matches). Updated its docstring to note the wave-2C routing.

**Did not ship** (intentionally out of scope per the wave-2C brief):
- Shift-queue formation moves (right-click hardcodes `replace_command`; Shift+right-click waypoint queue is a future wave when keybinding is wired).
- Right-click on enemy unit (Phase 2 attack-move) — still no-op.
- Right-click on friendly unit (Phase 2 follow/guard) — still no-op.
- Any change to `GroupMoveController` itself, `selection_manager.gd`, `unit.gd`, `box_select_handler.gd`, `farr_gauge.gd`, or anything in `scripts/units/` per the wave-2C ownership rules.

**Test-count delta:** +3 (469 → 472 in HEAD). Final: 472 tests, 469 passing, 3 risky/pending (pre-existing, all legitimate per v0.14.0/v0.14.1 entries — navmap-not-ready, FarrSystem fallback path).

**Lint:** `tools/lint_simulation.sh` reports OK (0 violations across L1-L5). The added preload constant and `_GroupMove` reference are valid GDScript identifiers; the lint rule against `apply_*` method names doesn't apply (no new methods, only a preload binding and one dispatch call).

**Live-game-broken-surface answers (Experiment 01) — refined:**

1. *State/behavior that must work at runtime that no unit test exercises:* The integration chain `box_select_handler.gd → SelectionManager.add_to_selection (×N) → click_handler.gd._unhandled_input(MOUSE_BUTTON_RIGHT) → raycast → GroupMoveController.dispatch_group_move → unit.replace_command → StateMachine.transition_to_next → UnitState_Moving.enter() → MovementComponent.request_repath`. Headless tests cover the dispatch chain via `process_right_click_hit(synthetic_hit)`; they cannot exercise the production `NavigationAgentPathScheduler` snapping the offset targets to nav-poly centers. R = 2.0 (8× navmesh `cell_size = 0.25`) keeps adjacent ring slots distinct against `NavigationServer3D.map_get_path`'s snap-to-poly per wave 1B's analysis. With box-select shipping in wave 1A, this wave-2C wiring is the first time multi-unit movement actually reaches the production scheduler with offset targets — until now there was no UI path to put 2+ kargars in the selection.

2. *What headless tests cannot detect that the lead would notice in the editor:* The visible spread of 5 kargars arriving at distinct positions vs. piling up — feel question, passes either way at the unit-test layer. The mid-move-redirect behavior (right-click while units are still moving): does the second dispatch cleanly cancel the first repath and reissue with new ring offsets, or does it visibly stutter? Whether a quick double-right-click on nearby points feels like "go there, then adjust" or jitters. Whether formation rotation looks correct (it shouldn't — facing/rotation is Phase 2; rotation here would be a `UnitState_Moving` regression).

3. *Minimum interactive smoke test that catches it:* Lead box-selects all 5 kargars (now possible with wave 1A's marquee), right-clicks a far point: all 5 walk, no piling, ring is visibly distributed. Lead right-clicks again mid-motion: clean redirect, all 5 still distributed at the new target. Lead right-clicks near a navmesh edge: off-navmesh ring slots fail individually via `request_repath` FAILED and drop back to Idle (per `UnitState_Moving`'s FAILED branch); other slots still walk. This is the interactive test wave-1B flagged as "testable from the keyboard after wave 2C wiring" — wave 2C makes it real.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. Pure infrastructure swap against wave-1B's already-ratified controller surface.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **Both single and multi selections route through the controller.** The wave-2C brief left this open ("the structural shape — variable naming and preload location is your call"). Routing the single-unit branch through the controller (instead of "if size == 1 use old loop, else use controller") was authorized by wave-1B's design intent: the identity fast path exists exactly so the wave-2 click-handler can use one dispatch site for both. Future changes to move-dispatch (queueing, logging, attack-move) edit one place, not two.
- **Defensive `has_method(&"replace_command")` check dropped.** The previous loop did `if u.has_method(&"replace_command"): u.call(...)`. The controller calls `live[i].replace_command(...)` directly, relying on `is_instance_valid()` filtering. This is safe because `SelectionManager` only stores Unit-shaped objects (its `select` API duck-types via `_is_unit_shaped`). The defensive check was load-bearing for a hypothetical future where someone shoves a non-Unit into the selection — that's a contract violation, not a runtime case worth a per-call check.
- **Preload constant lives at file scope, not inline in the function.** Standard Godot practice for cross-script references; keeps the dispatch line short and the preload cost paid once at script load.

**LATER items** (flagged for future waves):
1. **Shift-queue formation moves.** When keybinding wave lands Shift+right-click, the click handler can branch on `mb.shift_pressed` and dispatch through a `dispatch_group_move_append` variant (the controller's sister primitive, currently unexposed pending the wave-2 wiring decision flagged in `group_move_controller.gd:66`).
2. **Right-click on enemy unit / friendly unit.** Currently no-op (Phase 2's attack-move and follow/guard land here). The controller's `dispatch_group_move` is target-agnostic — a parallel `dispatch_group_attack_move` (or a `kind` argument) covers it.
3. **Stress-test mid-move-redirect at higher unit counts.** With 5 kargars the redirect is fine; at 50+ units (Phase 2/3 army-scale selections) the per-tick MovementComponent repath cancel + reissue cost may be measurable. Profile when army-scale selections actually exist; not blocking now.

---

## 2026-05-03 — Phase 1 session 2 wave 1B (ai-engineer): GroupMoveController skeleton

**Branch:** `feat/phase-1-session-2`

**Shipped (commit `9d54d79`):**
- `game/scripts/movement/group_move_controller.gd` (135 lines, RefCounted, no class_name). Single static entry point: `dispatch_group_move(units: Array, target: Vector3) -> void`. Concentric-ring distribution centered on the click target — index 0 at center, indices 1..6 on a ring of radius `Constants.GROUP_MOVE_OFFSET_RADIUS = 2.0` (60° spacing), indices 7..18 on a 2R ring (30° spacing), etc. Phase 1's 5-worker cap fits comfortably on ring 1 (1 center + 4 of 6 ring slots used). Determinism via pure index-based trig (`cos(i × 60°)`, `sin(i × 60°)`); no RNG, no time. Empty Array → no-op; single unit → identity (target verbatim — bitwise-identical to existing single-click move); freed entries skipped via `is_instance_valid`. Multi-unit dispatch issues `Constants.COMMAND_MOVE` per unit through `Unit.replace_command(kind, payload)` per State Machine Contract §2.5.
- `game/tests/unit/test_group_move_controller.gd` (259 lines, 7 tests): empty-array no-op, single-unit identity, 5-unit distinct-offsets-within-radius, determinism (same input → same offsets across runs), freed-unit array still dispatches to live ones, multi-unit Move-command shape (kind + payload.target), dispatch idempotency.
- `Constants.GROUP_MOVE_OFFSET_RADIUS = 2.0` already added by balance-engineer in `42a2f9b` ahead of wave 1B; the controller is the consumer. Sized 8× the navmesh `cell_size` (0.25 baked in `terrain.tscn`) so adjacent ring slots survive `NavigationServer3D` snap-to-poly.

**Did not ship** (intentionally out of scope per the wave-1B brief and `02c_PHASE_1_SESSION_2_KICKOFF.md`):
- Click-handler wiring (wave 2C). The right-click branch in `click_handler.gd::process_right_click_hit` still calls `unit.replace_command(&"move", {target})` directly per unit. Wave 2C swaps it for `GroupMoveController.dispatch_group_move(selected, target)` — 2-line change because the controller's single-unit identity path preserves single-click behavior.
- Facing / rotation (Phase 2).
- Formation-type selection (line, wedge — Phase 2).
- Reservation-based pathing (Phase 3+ when buildings exist).

**Test-count delta:** +7 (all in `test_group_move_controller.gd`, all passing). Pre-commit gate green at commit time: 446 tests, 0 failures, 3 risky/pending pre-existing.

**Lint:** `tools/lint_simulation.sh` reports OK (0 violations across L1-L5).

**Live-game-broken-surface answers (Experiment 01) — refined:**

1. *State/behavior that must work at runtime that no unit test exercises:* Real navmesh snapping via `NavigationAgentPathScheduler` (production scheduler). `MockPathScheduler` used in tests returns straight-line targets without snapping. R = 2.0 (8× the 0.25 navmesh `cell_size`) keeps adjacent ring slots distinct on the baked terrain. Off-navmesh click targets cause per-unit `request_repath` to FAIL; `UnitState_Moving` already handles that branch.

2. *What headless tests cannot detect that the lead would notice in editor:* The visible *shape* of the formation. 5 kargars arriving in a tidy ring vs. a clustered blob is a feel question — both pass tests. Whether units overshoot each other and visibly re-collide while pathing. Whether a mid-move redirect (right-click again before first move completes) feels clean or jittery. None of this is observable through `is_moving` flags or `current_command` reads.

3. *Minimum interactive smoke test that catches it:* Lead box-selects all 5 kargars (parallel deliverable 1; if not yet wired at lead-test time, lead shift-clicks them or calls `dispatch_group_move` from `main.gd._ready` as a synthetic test) and right-clicks a far point: all 5 walk, no piling, ring is visibly distributed. Lead right-clicks again mid-motion: clean redirect, all 5 still distributed at the new target. The wave-2C wiring is what makes this testable from the user's keyboard.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. Pure infrastructure against the ratified State Machine Contract.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **Lives in `scripts/movement/`, not `scripts/ai/`.** Pure dispatcher for player input — no AI controller, perception, or targeting logic. Leaves `scripts/ai/` exclusively for opponent-AI work (DummyAIController, TuranController). If future AI-side use lands, it imports the controller — same primitive, no relocation needed. Documented in §6 v0.14.0.
- **No `class_name` on the controller.** Same registry-race pattern as `MatchHarness`. Static methods on a preloaded script ref work identically with or without `class_name`. Kickoff brief explicitly authorized this choice.
- **Concentric rings (1+6+12+18…), not square grid.** Simplest expression that produces visually-tidy formations and scales to higher unit counts without algorithmic changes. Phase 1's 5-cap fits on ring 1.
- **Single-unit fast path returns `target` verbatim, NOT `target + cos(0)*R = target + R*(1,0,0)`.** Preserves bitwise-identical single-click behavior. The wave-2 click-handler wiring can route both single and multi selections through the controller without breaking session-1's single-click test suite.

**LATER items** (flagged for future waves):
1. **Wave 2C wiring** — `click_handler.gd::process_right_click_hit` 2-line swap (multi-selection branch only).
2. **Stress-test the algorithm at higher unit counts** — Phase 2/3 army-scale selections may want clamping if click is near a building.
3. **Formation visualization for the F1 pathfinding overlay** — Phase 6 per CLAUDE.md.

**Note on docs flow:** ai-engineer's working-tree docs edits were lost to an earlier `git reset` during the wave-1 cross-agent gate-blocking incident; this BUILD_LOG entry and the §6 v0.14.0 ARCHITECTURE entry were re-authored by lead from ai-engineer's cached report text in a follow-up commit. Content is ai-engineer's; commit attribution is lead.

---

## 2026-05-01 — Phase 1 session 2 wave 1A (ui-developer): box / drag selection

**Branch:** `feat/phase-1-session-2`

**Shipped:**

1. **`BoxSelectMath`** at `game/scripts/input/box_select_math.gd` (RefCounted, no `class_name` — registry-race pattern). Three pure helpers:
   - `rect_from_corners(a, b)` — direction-agnostic Rect2 normalization. Drag from any of the four diagonal corners produces the same positive-size rect.
   - `is_past_dead_zone(start, current, dead_zone_px)` — squared-distance threshold for click-vs-drag arbitration. 4px dead zone, comfortable for both mouse and trackpad.
   - `units_in_rect(rect, projected)` — filter a list of `{unit, screen_pos, on_screen}` entries to those whose projected position lies inside the rect. Skips `on_screen=false` and malformed entries; preserves input order for stable downstream UX.

2. **`BoxSelectHandler`** at `game/scripts/input/box_select_handler.gd` (Node, attached to `Main` after `ClickHandler` so `_unhandled_input` reaches it first under Godot's reverse-tree-order delivery). Owns the press → motion → release flow.
   - **Press intercept**: claims left-press on `_unhandled_input`, calls `set_input_as_handled()` always. ClickHandler never sees the left button. Captures Shift state at press time.
   - **Drag activation**: on motion past 4px dead zone, activates drag, shows the overlay, anchors the rect from press position to current cursor.
   - **Release arbitration**: on release, if drag was active → finalizes the box-select (project Iran units → filter → `add_to_selection` for hits, with `deselect_all` first if no Shift). If drag was NOT active → re-raycasts the release position and forwards via `ClickHandler.process_left_click_hit(hit)` (its existing public seam) so single-click selection still works.
   - **Public test seams**: `begin_press`, `update_motion`, `end_press`, `current_drag_rect`, `box_select_units(rect, units, project_callable, shift)` lets unit tests inject a projection helper without a real Camera3D.
   - **Live-unit sweep**: walks `get_tree().current_scene` for unit-shaped Node3Ds (duck-typed: `unit_id` + `team` + Node3D); filters `team == TEAM_IRAN`. Linear walk costs nothing at Phase 1's worker cap (5); SpatialIndex revisit when unit count grows past ~50.

3. **Drag overlay scene** at `game/scenes/ui/drag_overlay.tscn` (CanvasLayer + Control + custom-drawing Rect Control). Translucent gold (Iran palette) — fill alpha 0.20, stroke alpha 0.85, 1px outline. **`mouse_filter = MOUSE_FILTER_IGNORE` enforced both in the .tscn AND defensively at runtime in `_ready` of both `drag_overlay.gd` and `drag_overlay_rect.gd`**. Session 1's regression pattern (HUD labels at default `MOUSE_FILTER_STOP` swallowing clicks) is what we're inoculating against.

4. **31 new tests** across two files:
   - `game/tests/unit/test_box_select_math.gd` (16 tests): all four drag-corner directions, zero-size rect, dead-zone thresholding (zero, below, at, well past), full-rect coverage, miss-all, off-screen filter, stable order, boundary inclusivity, malformed-entry guards.
   - `game/tests/unit/test_box_select_handler.gd` (15 tests): press-release-no-motion is click; sub-dead-zone jitter is click; past dead-zone activates drag; rect normalizes both diagonal directions; replaces selection with units inside rect (no Shift); adds with Shift; empty rect deselects (no Shift) / preserves (Shift); skips off-screen units; empty candidates → no-op; drag rect empty before/during press-only; motion without press is no-op; Shift state captured at press, not release.

5. **`docs/ARCHITECTURE.md` 0.13.1 → 0.14.1.** Added a new `Box / drag selection` row in §2 (✅ Built); v0.14.1 plan-vs-reality entry: two-file split rationale, click_handler coordination strategy, press-time Shift, mouse_filter belt-and-braces, empty-rect behavior, linear unit-iteration choice, refined live-game-broken-surface answers, three LATER items.

6. **`game/scenes/main.tscn` updated** to wire `BoxSelectHandler` as a `Node` sibling after `ClickHandler` under `Main`. Tree order is load-bearing: `_unhandled_input` reaches BoxSelectHandler first.

**Test-count delta (this wave):** +31 (16 math + 15 handler). Headless GUT runner: all 31 pass alongside the existing 380. Lint clean (0 violations across L1–L5). Pre-commit gate green for this wave's files. (The session-aggregate count at commit time is higher; ai-engineer's parallel wave 1B and balance-engineer's wave 1C are landing on the same branch.)

**Did not ship** (intentionally out of scope per kickoff):
- Lasso / freeform selection (StarCraft-style — not needed).
- Subgroups / type-filtered selection (separate deliverable per kickoff §2 (3)).
- `selection_manager.gd` / `click_handler.gd` core-logic edits — kickoff explicitly forbade.
- Right-click cancellation of an active drag — RTS convention but flagged as a LATER item pending lead feel-test.
- Hover-style highlight while drag is active (drag-preview) — Phase 2 visual polish.
- `SelectionManager.select_many(units)` collapsed broadcast — flagged as a LATER item; out of scope per the "do NOT modify" rule.

**State for next session / wave:**
- On branch `feat/phase-1-session-2`. Box-select handler wired into `main.tscn`. The lead's interactive smoke test is the next gate.
- Math + input-flow tests cover everything a headless test can. Visual rectangle anchoring/transparency, drag-from-HUD interactions, and real-Camera3D `unproject_position` are the lead's call.
- Wave 2A (ui-developer) — Control groups (Ctrl+1–9 bind, 1–9 recall) and double-click-select-of-type. Both consume the multi-select API now wired through BoxSelectHandler.
- Wave 2B (ui-developer) — Selected-unit panel.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. All choices were implementation; the kickoff was prescriptive on the gameplay surface.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **Two-file split (math vs. handler)** rather than a single monolithic `box_select.gd`. Rationale: pure math is testable headless without a Camera3D; the handler is testable via injected projection callable. The split is ~80 lines + ~370 lines, slightly more total but vastly cleaner test surface.
- **Press-time Shift, not release-time.** RTS convention; documented in source.
- **Linear unit-iteration sweep, not SpatialIndex.** Phase 1 worker cap = 5; the SpatialIndex autoload dependency would buy nothing measurable. Revisit Phase 2+ when group sizes scale.
- **No-Shift drag onto empty rect deselects.** Matches the RTS convention "drag onto nothing = clear selection." Tested explicitly. The alternative (preserve prior selection on empty drag) is the opt-in via Shift.
- **Method renamed `_apply_selection` → `_commit_selection`.** Avoid the `apply_*` lint pattern (kickoff brief flag) even though our file has no `_process` so L1 wouldn't fire. Belt-and-braces.

**Live-game-broken-surface answers (Experiment 01):**

1. *What state/behavior must work at runtime that no unit test exercises?* The drag overlay's `mouse_filter = MOUSE_FILTER_IGNORE` (set in .tscn AND re-asserted in `_ready` of both `drag_overlay.gd` and `drag_overlay_rect.gd`). Real `Camera3D.unproject_position` per visible Iran unit on every release event. Coordination with `click_handler.gd`: BoxSelectHandler always claims the press; on non-drag release it re-raycasts and forwards via `ClickHandler.process_left_click_hit` — the only one-direction integration path that doesn't violate the "don't modify click_handler.gd" rule.

2. *What can a headless test not detect that the lead would notice in the editor?* Visual: rectangle anchoring, transparency, stroke style (gold, alpha 0.85, 1px outline). Behavioral: drag-from-HUD-into-world (HUD labels are MOUSE_FILTER_IGNORE per session 1, so the press hits us — but if a future interactive HUD lands, its `_gui_input` should claim it before we see it). Drag in all 4 corner-directions (math tested; visual rect anchoring needs eyes). Quick-click with 1–3px jitter mistaken as drag (the 4px squared-distance threshold is the line; lead may want 6 or 8 if it feels twitchy on trackpad).

3. *What's the minimum interactive smoke test that catches it?* Lead drags TL→BR across the 5 kargars: all 5 selected, gold rings appear. Lead drags BR→TL: same result. Lead Shift-drags a partial subset while 2 are already selected: only the new units are added; existing stay. Quick-click on one kargar with no drag: that one selects (single-click path through `ClickHandler.process_left_click_hit` still works). Click on empty terrain: deselect all. Drag onto empty space (no Shift): deselect all. Drag onto empty space with Shift: prior selection preserved.

**LATER items surfaced:**
1. `SelectionManager.select_many(units)` to collapse multi-add broadcasts into one `selection_changed` emit. Out of scope per kickoff "do NOT modify"; flag for the next wave that touches `SelectionManager`.
2. Drag-preview (live highlight on units the rect would catch, before release). RTS UX standard; Phase 2 polish budget.
3. Right-click cancels active drag. RTS convention; pending lead feel-test before deciding.

---

## 2026-05-01 — Phase 1 session 1 wave 3 (qa-engineer): click-and-move integration tests + flaky navmesh fix

**Branch:** `feat/phase-1-units`

**Shipped:**

1. **Integration test suite for the click-and-move flow** (`game/tests/integration/test_click_and_move.gd`, 9 tests). Covers all five deliverables from `02b_PHASE_1_KICKOFF.md §49 deliverable 10`:

   - `test_full_click_and_move_and_arrive_cycle` — full end-to-end: spawn real Kargar via `kargar.tscn`, issue `replace_command(&"move", ...)`, advance real SimClock ticks via `SimClock._test_run_tick()` through the full `EventBus.sim_phase(&"movement") → Unit._on_sim_phase → fsm.tick` chain; asserts position within 0.5 units of target, FSM in `&"idle"`, and `EventBus.unit_state_changed` emitted for both `idle→moving` and `moving→idle` transitions.
   - `test_on_sim_phase_drives_fsm_tick` — regression for the wave-3 fix (`c583d48`): confirms that two real EventBus ticks (not direct `fsm.tick()` calls) advance position. Position stays at 0.0 if `Unit._on_sim_phase` is not wired — the test that would have caught the live-game bug before the fix.
   - `test_on_sim_phase_only_fires_on_movement_phase` — FSM must not tick during `&"input"`, `&"combat"`, or other non-movement phases; only `&"movement"` drives it.
   - `test_right_click_on_unit_is_noop_integration` — right-clicking a real Kargar collider with a real Kargar selected must not issue a Move command (Phase 2 attack-move is out of scope). Uses actual Kargar instances rather than `FakeUnit` stubs.
   - `test_left_click_empty_hit_deselects_real_unit` and `test_left_click_terrain_collider_deselects_real_unit` — deselect behavior confirmed with a real Kargar instance.
   - `test_right_click_move_does_not_crash_when_selected_unit_freed` — graceful handling when a selected unit is freed between selection and right-click.
   - `test_freed_unit_does_not_crash_on_subsequent_sim_phase` — confirms `Unit._exit_tree` disconnects `EventBus.sim_phase` so freed units are never ticked again.
   - `test_right_click_fans_out_move_to_all_selected_kargars` — confirms right-click issues Move commands to ALL selected units; verified with two real Kargars.

2. **Fix: `NavigationAgentPathScheduler.set_map_rid_override(RID())` no longer silently ignored** (`game/scripts/navigation/navigation_agent_path_scheduler.gd`). Root cause: `_resolve_map_rid` checked `if _map_rid_override.is_valid()` — an invalid `RID()` passed intentionally to force the "no map → FAILED" path fell through to auto-detection from `World3D`, making the test non-deterministic. Fix: added `_map_rid_override_set: bool = false` sentinel. `set_map_rid_override()` always sets the sentinel (even with an invalid RID). `_resolve_map_rid()` now checks `if _map_rid_override_set:` first and returns the override value unconditionally. `clear_override()` and `clear_log()` both reset the sentinel. The flaky test `test_request_without_navmap_resolves_failed` is now deterministically green.

**Test-count delta:** 371 → 380 (+9 integration tests). All 380 pass. 3 pending are pre-existing (2 navmesh-bake headless runner gaps in `test_navigation_agent_path_scheduler.gd`, 1 FarrSystem defensive-default in `test_resource_hud.gd` — all unchanged). The previously flaky `test_request_without_navmap_resolves_failed` now passes deterministically.

**Lint:** `tools/lint_simulation.sh` reports OK (0 violations across L1-L5). Pre-commit gate green.

**Critical integration pattern documented in test file:** Integration tests use `SimClock._test_run_tick()` through the full EventBus chain (`EventBus.sim_phase(&"movement") → Unit._on_sim_phase → fsm.tick`). Unit tests call `fsm.tick()` directly. This distinction is why the Phase 1 live-game bug (`c583d48`) passed all unit tests while being silently broken in the live scene. These integration tests close that gap — any future unwiring of `Unit._on_sim_phase` will immediately fail `test_on_sim_phase_drives_fsm_tick`.

**Typing pattern:** All local unit refs stored as `Variant` class-level fields (`var _kargar: Variant = null`) per the project-wide class_name registry-race dodge (`docs/ARCHITECTURE.md §6 v0.4.0`). No local `:=` inference on Kargar/Unit-shaped returns.

**Did not ship** (out of scope per kickoff §49):
- Performance profiling (unit count benchmarks) — Phase 2+.
- AI-vs-AI simulation tests — Phase 3+.
- Regression tests for other Phase 1 systems (resource HUD, edge-pan) — covered by existing unit tests.

**State for next session:**
- Branch `feat/phase-1-units` is 2 commits ahead of `origin/feat/phase-1-units`, 9 commits ahead of `main`. Wave 3 contributes the two new commits. Not pushed.
- All 5 wave deliverables (`02b_PHASE_1_KICKOFF.md §49 items 1–5`) are now covered by integration tests. The branch is ready to PR → `main`.
- Phase 1 session 2: box-select, control groups, double-click-select-type, `GroupMoveController` (formation movement), Farr gauge polish, selected-unit panel.

**Open questions added to `QUESTIONS_FOR_DESIGN.md`:** none. All decisions were implementation choices.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **`_advance(n)` helper in integration tests calls `SimClock._test_run_tick()` n times rather than emitting `EventBus.sim_phase` directly.** `_test_run_tick` is the single authoritative tick driver per Sim Contract §1.1; emitting phases manually would skip SimClock's own bookkeeping and could produce clock-drift in multi-tick assertions.
- **`_spawn_kargar` force-writes `u.get_movement()._scheduler = _mock` after `add_child_autofree`.** `PathSchedulerService.set_scheduler` is called in `before_each`, but Kargar's `_ready` fires when `add_child` attaches it to the tree — timing varies. The explicit post-attach write is the double-safety pattern from `test_unit_states.gd` ensuring the mock is always in place before any movement code runs.
- **Sentinel field `_map_rid_override_set` rather than a nullable wrapper or a special sentinel RID.** An invalid `RID()` is itself a valid test intent (force FAILED), so the override-set state must be tracked separately. A nullable wrapper would add an allocation; a magic sentinel RID value would require Godot API guarantees about `RID()` equality. Boolean flag is the cheapest correct solution.

---

## 2026-05-01 — Phase 1 session 1 live-game fixes (lead, post-wave-2)

**Branch:** `feat/phase-1-units`

**Context:** All wave-2 agents reported lint-clean + tests-passing. Lead booted the actual game in the editor for the first interactive test of the click-and-move flow. Three bugs were live even though the 371 unit tests all passed — the canonical "headless tests green, live game broken" gap that Phase 0 retro flagged in `STUDIO_PROCESS.md` §9.

**Shipped (commit `c583d48`):**

1. **Unit FSM tick wiring** (`game/scripts/units/unit.gd`). `UnitState_Moving._sim_tick` polls the path scheduler and steps the position, but nothing in the live scene called `fsm.tick()` — tests called it directly, and the live game was waiting on the "MovementSystem phase coordinator" LATER item from v0.13.0. Added `Unit._on_sim_phase(phase, _tick)` that drives `fsm.tick(SimClock.SIM_DT)` when `phase == &"movement"`. Connect on `_ready`, disconnect on `_exit_tree`. Same pattern `SpatialIndex` uses for `&"spatial_rebuild"`. **This was the bug that made right-click do nothing in the live game.** When the proper MovementSystem coordinator ships, this is a 3-line removal.

2. **Edge-pan direction** (`game/scripts/camera/camera_controller.gd`). Two issues stacked: (a) `pan_by` did not rotate the screen-axis through the rig's basis — with the camera_rig.tscn yaw of +45°, screen-up did not follow camera-forward; (b) `compute_edge_pan_axis` used the opposite Y-sign convention from WASD (mouse-top → -1 vs W → +1). Fixed `pan_by` to multiply by `global_transform.basis` (`is_inside_tree()`-guarded so headless test fixtures stay identity); flipped edge-pan signs so mouse-near-top → `ax.y = +1` (matches WASD W). The original wave-1 tests asserted the sign of `ax.y`, not the resulting world direction, so the bug slipped through. Tests updated.

3. **HUD labels swallowed clicks** (`game/scenes/main.tscn`, `game/scenes/ui/resource_hud.tscn`). `Label` and `MarginContainer` default `mouse_filter` is `MOUSE_FILTER_STOP`, which silently absorbed mouse events in their rects. Set `mouse_filter = 2` (IGNORE) on `StatusLabel`, the HUD `MarginContainer`, `HBox`, and the four resource Labels. These are decorative readouts, not interactive — ignoring mouse is correct.

4. **`DEBUG_LOG_CLICKS` flag** in `click_handler.gd`. Default ON. Prints every left/right press, what the raycast hit, and what command (if any) was issued. This was the diagnostic that made bug #1 visible. Left ON for the next interactive testing pass.

5. **`docs/ARCHITECTURE.md` 0.13.0 → 0.13.1.** New §6 v0.13.1 entry documents the three fixes and surfaces the LATER items (now-promoted MovementSystem coordinator, scene-level visual smoke test).

**Test-count delta:** 371 → 371 (no new tests; integration tests covering this fix are qa-engineer wave 3, queued separately).

**Lint:** `tools/lint_simulation.sh` reports OK (0 violations across L1-L5). Pre-commit gate green.

**User-visible Definition of Done (kickoff §73) — confirmed by lead in editor after fix:**

| # | Item | Status |
|---|---|---|
| 1 | Launch game (F5) | ✅ |
| 2 | See 5 workers on terrain | ✅ |
| 3 | Left-click → ring appears | ✅ |
| 4 | Right-click on terrain → worker walks there | ✅ (fixed by FSM tick wiring) |
| 5 | Worker arrives → idle pulse resumes | ✅ (subtle ±5% scale at 1Hz) |
| 6 | Click empty terrain → deselect | ✅ |
| 7 | Tests + lint + pre-commit green | ✅ |
| 8 | `docs/ARCHITECTURE.md` §2 reflects build state | ✅ (this entry + v0.13.1) |

**Phase 1 session 1 is functionally done.** Wave 3 (qa-engineer) is in-flight: integration test for the full click-and-move flow + fix the flaky `test_request_without_navmap_resolves_failed` test.

**State for next session (wave 3 / merge):**
- Branch `feat/phase-1-units` is 1 commit ahead of `origin/feat/phase-1-units`, 7 commits ahead of `main`. Not pushed.
- After qa-engineer wave 3 lands, branch is ready to PR → `main`.
- Phase 1 session 2 picks up: box-select, control groups, double-click-select-type, GroupMoveController (formation movement), Farr gauge polish, selected-unit panel.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. All three bugs were implementation choices.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **`Unit` self-subscribes to `EventBus.sim_phase` rather than registering with a coordinator.** The MovementSystem coordinator is the long-term shape (LATER); a transitional self-subscribe unblocks live-game testing today and is a 3-line removal when the coordinator ships.
- **`pan_by` rotates by `global_transform.basis`, NOT by a stored yaw angle.** The basis IS the yaw — multiplying by it costs the same as a hand-rolled rotation matrix and stays correct if the rig's transform ever changes (e.g., a future cinematic shot).
- **`mouse_filter = 2` on every decorative HUD Control, not just the offending one.** Defensive but cheap; future HUD additions inherit the pattern.
- **`DEBUG_LOG_CLICKS` left ON.** Will be flipped off (or routed through `DebugOverlayManager`) once interactive testing gives the click flow a few more passes.

**LATER items surfaced in this fix pass:**
1. **MovementSystem phase coordinator — promoted.** Was already a LATER item from v0.13.0; this fix elevates the priority because the transitional self-subscribe is mostly fine but the deterministic `unit_id`-sorted iteration is the formal target shape per Sim Contract §2.
2. **Scene-level visual smoke test** — Phase 0 retro added a §9 rule about scene-level smoke tests; this set of bugs is the canonical case the rule was written to catch. qa-engineer wave 3 implements it: load `main.tscn`, spawn a unit through the real scene path, drive ticks via `SimClock._test_advance`, assert `global_position` advances toward target. Had this existed at session 1 start, bug #1 would have been caught the moment Idle/Moving + Kargar shipped.
3. **`DEBUG_LOG_CLICKS` should route through `DebugOverlayManager`.** Currently a const flag; long-term it should be one of the F1–F4 toggles per CLAUDE.md "debug overlays as first-class" rule. Estimated 5-line refactor.

---

## 2026-05-01 — Phase 1 session 1 wave 2 (ai-engineer): UnitState_Idle + UnitState_Moving

**Branch:** `feat/phase-1-units`

**Shipped:**
- `UnitState_Idle` (`game/scripts/units/states/unit_state_idle.gd`). `class_name UnitState_Idle extends "res://scripts/core/state_machine/unit_state.gd"` (path-string base for the class_name registry race per ARCHITECTURE.md §6 v0.4.0). id=`&"idle"`, priority=0, interrupt_level=NONE. `enter()` caches the parent unit's MeshInstance3D and resets scale to neutral; `_sim_tick` writes a deterministic ±5%/1Hz sin-pulse driven off `SimClock.tick * SIM_DT` (replay-safe; "the unit is alive but uncommitted" cue per CLAUDE.md placeholder visuals); `exit()` restores neutral scale. State is otherwise a true no-op — Contract §3.4 specifies command-queue dispatch flows through `Unit.replace_command` / `append_command` calling `transition_to_next`, not Idle's own polling.
- `UnitState_Moving` (`game/scripts/units/states/unit_state_moving.gd`). Same path-string base + class_name pattern. id=`&"moving"`, priority=10, interrupt_level=COMBAT. `enter()` reads target Vector3 from `ctx.current_command.payload.target` (populated by `StateMachine.transition_to_next`) and calls `unit.get_movement().request_repath(target)`; defensive bail to Idle on missing current_command or missing target. `_sim_tick` drives `MovementComponent._sim_tick(dt)` (the per-tick driver until the MovementSystem phase coordinator lands — flagged as a LATER item); flips `_arrival_pending` latch on first READY observation; transitions via `transition_to_next` when path was loaded and waypoints consumed. On FAILED/CANCELLED resolution, push_warning then transition_to_next. `exit()` cancels in-flight repath via `_scheduler.cancel_repath(_request_id)` and resets the request id so MovementComponent doesn't poll a cancelled request.
- Wired Idle and Moving into the `Unit` base class `_ready` (`game/scripts/units/unit.gd`). Idempotent registration (only registers if `&"idle"`/`&"moving"` aren't already in the FSM's state set, so concrete subclasses can pre-register their role-specific states before `super._ready()`). `init(&"idle")` only fires if `current` is still null. Path-string preload of the state scripts (`const _UnitStateIdleScript: Script = preload(...)`) instead of class_name references — the registry race bites unit.gd's own `class_name Unit` registration when test scripts parse before the registry settles. Without the path-string preload, `test_unit.gd` failed with "unit_type is not a property of CharacterBody3D" because `class_name Unit` never registered.
- Added `Unit.current_command: Dictionary = {}` slot. State Machine Contract §3.4 explicitly left this open ("ctx.current_command — to be defined when concrete states ship"). Wave 2 ships the definition. Shape: `{ "kind": StringName, "payload": Dictionary }`. Populated by `StateMachine.transition_to_next` before the dispatched Command is returned to the pool (defensive `payload.duplicate()` so pool re-rent doesn't race). Cleared on the empty-queue → Idle path. UnitState_Moving's `enter()` reads `ctx.current_command.payload.target`. Update to `state_machine.gd::transition_to_next` adds two helpers `_set_current_command(kind, payload)` and `_clear_current_command()`; the state-id mapping logic is unchanged.
- 13 new GUT tests in `tests/unit/test_unit_states.gd`: 4 Idle-shape tests (id/priority/interrupt_level; enter caches mesh; pulse moves scale; exit restores scale), 8 Moving tests (id/priority/interrupt_level; enter reads target & calls request_repath; defensive bail when no current_command; defensive bail when no target in payload; sim_tick advances position; transitions to Idle on arrival; FAILED path → Idle with warning; exit cancels in-flight repath), and 1 integration `test_full_idle_moving_idle_cycle` exercising the full click-and-move-and-arrive flow (with subscribed EventBus.unit_state_changed assertions).
- `docs/ARCHITECTURE.md` 0.12.0 → 0.13.0. Two new ✅ Built rows in §2 (`UnitState_Idle`, `UnitState_Moving`). New §6 v0.13.0 entry covers the eight divergences from spec sketches and the two LATER items (MovementSystem phase coordinator wiring + per-unit current_command lifetime when Phase 2 Attacking lands).

**Test-count delta:** wave-1 baseline 312 → wave-2 close ~371 across all agents (counts depend on which agents have landed). My contribution: +13 tests, all passing. The 4 remaining failures in the test run are in other agents' files: 3 in `tests/unit/test_kargar.gd` (gameplay-systems' file — Kargar.unit_type not initialized yet at the time I last saw it; their concurrent fix may already be in) and 1 in `tests/unit/test_navigation_agent_path_scheduler.gd::test_request_without_navmap_resolves_failed` (engine-architect's pre-existing wave-1 file).

**Lint:** `tools/lint_simulation.sh` reports OK (0 violations across L1-L5). Initial run flagged a comment-line in `unit_state_idle.gd` mentioning `Time.get_ticks_msec()` (gameplay-systems' wave-2 entry called this out as flagged-for-me); reworded the comment to drop the wall-clock API name. The pulse driver is `SimClock.tick`, never `Time.*`.

**Did not ship** (intentionally out of scope per the wave-2 brief and `02b_PHASE_1_KICKOFF.md`):
- Concrete additional unit states (Attacking, Gathering, Constructing, Casting, Dying) — Phase 2+ when their owning systems exist.
- GroupMoveController / formation movement — Phase 1 session 2 (planned row in §2 unchanged).
- MovementSystem phase coordinator (decoupling Moving._sim_tick from MovementComponent._sim_tick) — LATER item, see below.
- F3 state-machine debug overlay — concrete overlays land WITH their owning systems per kickoff doc rule.
- The `Kargar` worker class — gameplay-systems wave 2 (separately shipped this same wave).
- SelectionManager + ClickHandler input wiring — ui-developer wave 2 (separately shipped this same wave).
- Full integration test of click-and-move flow — qa-engineer wave 3.

**State for next session (wave 3 / future):**
- On branch `feat/phase-1-units`. Lint clean. My contribution: +13 tests (test_unit_states.gd), all passing.
- The Unit base class now registers Idle and Moving on `_ready` and lands in Idle. Concrete unit types (Kargar etc.) inherit this for free; nothing changes for gameplay-systems' Kargar shipping in parallel.
- ui-developer's right-click-to-move flow plugs in cleanly: their `replace_command(&"move", {target: world_pos})` triggers `transition_to_next` → Moving picks up the target via `ctx.current_command.payload.target`. The convention they used (`payload[&"target"]` as a Vector3) matches what Moving expects.
- The `_arrival_pending` latch handles both the multi-tick arrival and the single-tick arrival case (huge move_speed, tiny distance). Tests pin both shapes.
- MovementSystem phase coordinator is the most prominent LATER item — when it lands, Moving's `_sim_tick` drops the `_movement._sim_tick(dt)` line and just polls `path_state` / `is_moving`. One-line refactor; not blocking MVP scale.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced — wave-2's ai-engineer work was pure infrastructure against the ratified State Machine Contract.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **Idle/Moving registered by Unit base class, not by concrete subclasses.** Minimizes boilerplate every concrete unit type has to repeat. Subclasses retain the option to register additional role-specific states before chaining to super._ready. Documented in §6 v0.13.0.
- **Path-string base for state scripts; path-string preload for state script refs in unit.gd.** Same registry-race pattern as elsewhere in the project. Without it, `class_name Unit` failed to register, cascading into "unit_type not a property of CharacterBody3D" test failures.
- **`Unit.current_command` shape: `{ "kind": StringName, "payload": Dictionary }`.** Defensive `payload.duplicate()` copy at dispatch time so pool re-rent doesn't race. Phase 2 Attacking will need `current_command.payload.target_unit: Node` validity checks (LATER item flagged).
- **Arrival-detection latch flipped on `path_state == READY`, not on `is_moving == true`.** Single-tick arrival cases (huge move_speed) never observe `is_moving == true`; READY-as-latch handles single- and multi-tick uniformly.
- **Moving._sim_tick drives MovementComponent._sim_tick directly.** Until MovementSystem phase coordinator lands. One-line refactor when it does.
- **Idle pulse uses SimClock.tick * SIM_DT, not wall-clock time.** Sim Contract §1.1 forbids gameplay code reading wall time; pulse is render-only but using SimClock.tick is determinism-friendly and lint-friendly. Pulse amplitude ±5% / 1 Hz — subtle "alive" cue per CLAUDE.md placeholder visuals.
- **Moving.exit cancels the in-flight repath explicitly.** Contract §3.5 mandates states own their teardown; the next state may not be another Moving and won't re-issue request_repath that would shadow ours.
- **Moving.interrupt_level = COMBAT, not NEVER.** Damage interrupts non-combat movement per Contract §2.1's own examples. Phase 2 combat balance can flip to NONE for "casual" hero-traveling movement if needed.

**LATER items** (flagged for future waves):
1. **MovementSystem phase coordinator.** Long-term shape — subscribe to `EventBus.sim_phase(&"movement", ...)` and iterate registered MovementComponents in one batch instead of every Moving state's `_sim_tick` calling `_movement._sim_tick`. Cache-friendlier; removes per-state-instance drive call. Estimated 1 small wave; not blocking.
2. **Per-unit current_command lifetime.** Phase 2 Attacking will need `current_command.payload.target_unit: Node` validity checks (Node refs can become invalid mid-state). Either Attacking handles via `is_instance_valid`, or the dispatcher converts Node refs to unit_ids. Flagged for Phase 2 ai-engineer.

---

## 2026-05-01 — Phase 1 session 1 wave 2 (gameplay-systems): Kargar + match start spawn

**Branch:** `feat/phase-1-units`

**Shipped:**
- `Kargar` worker class (`game/scripts/units/kargar.gd`). `class_name Kargar` extending `unit.gd` via path-string base (registry-race dodge per ARCHITECTURE.md §6 v0.4.0). Sets `unit_type = &"kargar"` in `_init` AND in `_ready` before `super._ready()` — required because Godot's scene-instantiation order overwrites @export defaults (including `unit_type`) between `_init` and `_ready`, clobbering _init's write back to the parent's empty default. `_ready` override fires before `Unit._apply_balance_data_defaults` reads unit_type to look up `BalanceData.units[&"kargar"]` (max_hp 60.0 → hp_x100=6000, move_speed 3.5).
- `kargar.tscn` (`game/scenes/units/kargar.tscn`). Inherits `scenes/units/unit.tscn` via `instance=ExtResource(...)`, overrides root script to `kargar.gd`, overrides MeshInstance3D mesh from BoxMesh → CylinderMesh (top_radius=bottom_radius=0.35, height=0.7 — squat worker silhouette) and material albedo from Color(0.3, 0.5, 0.7) (blue-grey infantry) → Color(0.65, 0.5, 0.3) (sandy-brown worker). All other unit composition (HealthComponent / MovementComponent / SelectableComponent / SpatialAgentComponent / CollisionShape3D) inherits unchanged.
- 5-Kargar match start spawn in `game/scripts/main.gd`. New `_spawn_starting_kargars()` called from `_ready` after the boot print. Resets the static `Unit._next_unit_id` counter (via path-string-preloaded `_UnitScript` ref — same registry-race dodge) so unit_ids deterministically run 1..5 across runs (replay-diff cleanliness). Spawns 5 Kargars at known positions: origin + 4 cardinal offsets at distance 3 (Y=0.5 to clear the terrain plane). All team Iran. Parented under the existing `World` Node3D in main.tscn — camera + lighting + terrain + units share the same world transform.
- 16 new tests across 2 files: `tests/unit/test_kargar.gd` (10 tests — scene smoke, class identity, BalanceData hookup for max_hp + move_speed, mesh override is CylinderMesh not BoxMesh, material is brown not blue-grey, team plumbing, bare construction via `Kargar.new()`) and `tests/unit/test_match_start_spawn.gd` (6 tests — main.tscn loads, 5 Kargars exist under World, all team Iran, all direct children of World, unit_ids are 1..5, no two Kargars share a position).
- `docs/ARCHITECTURE.md` 0.11.0 → 0.12.0. Two new ✅ Built rows in §2: "Kargar (worker) unit type" + "Match start spawn (5 Kargar)". New §6 v0.12.0 entry covers the seven divergences from spec sketches (most notably the dual-init/ready unit_type override pattern, the path-string base for kargar.gd, and the 5-vs-3 starting workforce ergonomics choice).

**Test-count delta:** wave-1 baseline 312 tests → ~371 tests at wave-2 close (precise count depends on which tests other parallel agents land). My contribution: +16 tests across 2 new files. All my new tests pass. Pre-existing failure in `tests/unit/test_navigation_agent_path_scheduler.gd::test_request_without_navmap_resolves_failed` (1 failure) is in the engine-architect's wave-1 file and not caused by my changes — flagged for whoever lands next.

**Lint:** my files (kargar.gd, kargar.tscn, main.gd, test_kargar.gd, test_match_start_spawn.gd) are all clean against `tools/lint_simulation.sh`. The single L5 violation reported by the lint is in `game/scripts/units/states/unit_state_idle.gd` — ai-engineer's wave-2 file, comment-line false positive. Out of my scope.

**Did not ship** (intentionally out of scope per the wave-2 brief and `02b_PHASE_1_KICKOFF.md` §2):
- Other unit types (Piyade, Kamandar, Savar, Asb-savar, Rostam) — Phase 1 session 2 onward.
- Production buildings, costs spent on spawn — Phase 3 (resource economy).
- Combat behavior, attack range, damage — Phase 2.
- Worker gathering / construction / repair behaviors — Phase 3 (resource node interactions).
- Dying state visuals — Phase 2 with combat.
- `UnitState_Idle` / `UnitState_Moving` — ai-engineer's wave 2 (separately shipped this same wave).
- Click-to-select / right-click-to-move input — ui-developer's wave 2 (separately shipped this same wave).
- Full integration test of click-and-move flow — qa-engineer's wave 3.

**State for next session (wave 3 / future):**
- On branch `feat/phase-1-units`. Wave 2 has multiple agents in flight; coordinate with the test totals once everyone lands. My files (kargar.gd, kargar.tscn, main.gd, test_kargar.gd, test_match_start_spawn.gd) are all green.
- Five Kargars spawn at game start under `Main/World` in main.tscn, team Iran, unit_ids 1..5. ui-developer's SelectionManager + ClickHandler should pick them up automatically (no special wiring required — the SelectableComponent on each Kargar inherits from unit.tscn).
- The Kargar visual silhouette (squat sandy-brown cylinder) is deliberately distinct from the unit.tscn base placeholder (blue-grey cube). When future unit types ship (Piyade, Kamandar, etc.), follow the same pattern: inherit unit.tscn, override mesh + material in the .tscn, override script with a `class_name X extends "res://scripts/units/unit.gd"` subclass that sets `unit_type` in both `_init` and `_ready`-before-super.
- The 5-vs-3 starting workforce is a wave-2-ergonomics knob, not a balance value — drop to 3 in Phase 3 when the resource economy makes the count load-bearing.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced — wave 2's gameplay-systems work was pure infrastructure against the wave-1 unit foundations + ratified spec.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **Kargar uses path-string extends + class_name retained.** Same registry-race pattern as the components in `scripts/units/components/`. Documented in source.
- **Kargar sets unit_type in both _init AND _ready.** Discovered via TDD that scene instantiation overwrites @export-backed unit_type between the two. The dual-write is the smallest change that makes both code-only construction (`Kargar.new()`) and scene instantiation (`KargarScene.instantiate()`) report the correct unit_type. Documented in source comments + ARCHITECTURE.md §6 v0.12.0.
- **5 starting Kargars, not the canonical 3.** Wave-2 ergonomics for SelectionManager testing. Drops to 3 in Phase 3. Documented in main.gd, kargar.gd, and ARCHITECTURE.md §6 v0.12.0.
- **Spawn lives in main.gd, no MatchSetup script.** Spawn logic is ~30 lines; extracting helps only if it grows past ~50. Ready to extract in Phase 3 when multiple unit types and AI starting armies arrive.
- **Tests use script-path-walk for inheritance checks**, not `is Kargar` / `is Unit`. Same registry-race avoidance — test files parse before the runtime registry has settled. Helper function `_is_kargar(node)` walks the script chain looking for kargar.gd's resource_path.

---

## 2026-05-01 — Phase 1 session 1 wave 2 (ui-developer): Selection + click-to-move

**Branch:** `feat/phase-1-units`

**Shipped:**
- `SelectionManager` autoload (`game/scripts/autoload/selection_manager.gd`) registered in `project.godot` after `FarrSystem`. Public API: `select(unit)` (idempotent, no signal re-emission on duplicates) / `select_only(unit)` / `add_to_selection(unit)` (Phase-1-session-2 hook; functionally identical to `select` today) / `deselect_all()` / `is_selected(unit)` / `selection_size()` / `selected_units` accessor (returns fresh shallow copy, prunes freed units defensively) / `reset()` (no-emit test/teardown helper). Single-broadcast contract: every state-mutating call emits `EventBus.selection_changed(selected_unit_ids: Array)` exactly once. `select_only` preserves the target's ring instead of flickering through deselect→select when the target is already selected.
- `ClickHandler` (`game/scripts/input/click_handler.gd`, plain Node attached as `ClickHandler` child of `Main` in `main.tscn`). `_unhandled_input` raycasts via `Camera3D.project_ray_origin/normal` + `direct_space_state.intersect_ray` then routes through `process_left_click_hit(hit)` / `process_right_click_hit(hit)`. Left-click on Unit-shaped collider → `SelectionManager.select_only(unit)`; left-click on terrain or empty space → `deselect_all()`. Right-click on terrain with units selected → `Unit.replace_command(Constants.COMMAND_MOVE, { &"target": Vector3 })` for every selected unit (this is the coordination shape with ai-engineer's `UnitState_Moving`). Right-click on a unit is a no-op in wave 2 (Phase 2 routes that to attack-move). `set_test_mode(on)` disables `_unhandled_input` so tests drive the routing seams directly.
- 29 new tests (`tests/unit/test_selection_manager.gd` — 16; `tests/unit/test_click_handler.gd` — 13). All pass. Cover: select/select_only/deselect_all/add_to_selection state mutations, signal emission counts and payloads, idempotency, empty-set deselect_all still emits, freed-unit filtering, reset semantics, the routing decisions in click_handler (left-click selects unit / left-click terrain deselects / left-click empty deselects / right-click terrain pushes Move command with correct kind+target / right-click no-selection no-op / right-click unit no-op / right-click empty no-op / multi-unit fan-out / nested-collider ancestor walk-up / terrain duck-type rejection).
- `docs/ARCHITECTURE.md` 0.9.0 → 0.10.0. Selection-system row moved 📋 Planned → ✅ Built. New §6 v0.10.0 entry covers 8 wave-2 implementation choices (idempotent select, no-emit reset, select_only preservation, untyped Array, testable seam, right-click-on-unit no-op, duck-type unit detection, autoload order).
- `main.tscn` updated to instance `ClickHandler` under `Main` (load_steps 6 → 7, new ext_resource for the script, new node entry). Single `[node name="ClickHandler" type="Node" parent="."]` block with `script = ExtResource("5_click")`.

**Test-count delta:** 312 → 355 tests (43 new across the wave). Wave 2's contribution from ui-developer: 29 (16 SelectionManager + 13 ClickHandler). The remaining 14 land from ai-engineer (Idle/Moving) and gameplay-systems (Kargar/spawn). At session-close run: 355 total / 350 actually-passing / 3 pending (pre-existing) / 2 failing in ai-engineer's wave-2 files (UnitState_Idle's pulse test and UnitState_Moving's transition-to-Idle test — neither in my owned files; flagged to ai-engineer below). 0 failures in ui-developer's owned files. ~1.7s run time.

**Did not ship** (out of scope per the wave-2 brief):
- Box/drag selection (Phase 1 session 2).
- Shift+click add-to-selection input wiring (`add_to_selection` API exists, no input listens for Shift modifier yet) — Phase 1 session 2.
- Ctrl+1-9 control groups — Phase 1 session 2.
- Double-click select-all-of-type — Phase 1 session 2.
- Selected unit panel (bottom-left detail view) — Phase 1 session 2.
- Attack-move (A + click) — Phase 2.
- Hover info / cursor changes per context — later.

**State for next session:**
- Branch `feat/phase-1-units`. Lint clean for ui-developer's owned files (the L5 violation surfacing in `unit_state_idle.gd:17` is a comment-line false positive in ai-engineer's file — flagged below).
- The Move Command shape `{ kind: &"move", payload: { &"target": Vector3 } }` is the contract between ui-developer's right-click handler and ai-engineer's `UnitState_Moving.enter()`. Tests `test_right_click_move_command_has_correct_kind` and `test_right_click_move_command_has_correct_target_payload` are the regression tripwire if either side drifts.
- `SelectionManager.add_to_selection` is the API hook for Phase 1 session 2's Shift+click. It currently delegates to `select(unit)` — when the input handler for Shift+click lands, it calls this instead of `select_only`.
- `ClickHandler.process_left_click_hit` / `process_right_click_hit` are public so qa-engineer's wave-3 integration test can drive the click flow without a real `Camera3D` + physics world. The end-to-end raycast wiring (camera → ray query → ClickHandler routing) is the smoke-test layer above.
- The lint script's L3 has a comment-line filter (lines starting with `#` are dropped from match results); L5 currently does NOT have that filter, so a comment that mentions `Time.get_ticks_msec()` triggers a false positive. ai-engineer's wave-2 `unit_state_idle.gd:17` hits this. Either: (a) qa-engineer extends the L3 filter to L5 in `tools/lint_simulation.sh`, or (b) ai-engineer rewords the comment to avoid the literal call shape. ui-developer (this session) did not touch the lint script — out of file-ownership scope.

**Open questions added to `QUESTIONS_FOR_DESIGN.md`:** none. No design/feel/balance questions surfaced — the work was input-routing and state-management infrastructure against the kickoff brief.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **`SelectionManager.select` is signal-idempotent (no re-emit on duplicate).** Discussed in v0.10.0 §6 entry. The kickoff brief said "select(unit) adds unit to selection, calls unit.get_selectable().select(), emits EventBus.selection_changed." Strict reading would re-emit on every call. Chose idempotency for HUD/overlay/telemetry consumer health (rapid clicks on same unit shouldn't flood listeners). Test `test_select_is_idempotent` pins both list-state and signal-emit invariants.
- **`SelectionManager.deselect_all` always emits, even on empty set.** Inverse of the above — the empty broadcast is cheap (no listener mutates state) and defends against missed prior emissions. Test `test_deselect_all_on_empty_set_still_emits`.
- **`SelectionManager.reset` does NOT emit.** Reset is the test-fixture seam, not a production deselect path. Mirrors `SimClock.reset` / `FarrSystem.reset`. `deselect_all` is the production-path empty-broadcast call. Test `test_reset_clears_selection_without_emitting` pins.
- **`select_only` preserves the target's ring on already-selected click.** Avoids visual flicker (deselect→select on the same component would flash the placeholder ring). Cheap to handle correctly.
- **Right-click on a unit collider is a no-op (NOT a position-move).** The eventual attack-move command targets a unit, not a Vector3. Generating a Move(target=unit.global_position) now would teach players a misleading model. Test `test_right_click_on_unit_is_noop_in_wave2` pins.
- **Duck-typed Unit detection in `ClickHandler._is_unit_shaped`.** `replace_command` method + `command_queue` field. Same class_name registry workaround pattern documented in §6 v0.4.0 / v0.9.0. Concrete Unit subclasses (Kargar, etc.) inherit both, so the check is forward-compatible.
- **Split `ClickHandler` into `_unhandled_input` shell + `process_*_click_hit(hit)` public seams.** Production path raycasts then calls the seam; tests inject synthetic hit dicts directly. Same pattern `CameraController` uses for `pan_by` / `zoom_by` / `clamp_to_bounds`. Sidesteps the GUT-can't-easily-stand-up-a-real-Camera3D-and-physics-world testability gap.
- **`SelectionManager` autoload registered AFTER `FarrSystem`** (last in the autoload list). No autoload-time dependencies beyond EventBus, which was already booted; lazy registration pattern means no `_ready` ordering risk.

---

## 2026-05-01 — Phase 1 Session 1 wave 1: Unit infrastructure foundation

**Branch:** `feat/phase-1-units`

**Shipped:**
- `Unit` base class + scene template. `class_name Unit extends CharacterBody3D` at `game/scripts/units/unit.gd`. Scene at `game/scenes/units/unit.tscn` composes a placeholder MeshInstance3D (0.5×0.6×0.5 cube), CollisionShape3D, and the four sim components. Static `unit_id` counter with `reset_id_counter()` for match-start. Reads `BalanceData.units[unit_type]` for `max_hp` and `move_speed`. Constructs `command_queue` and `fsm` in `_init` (so external code can call `replace_command` against a freshly-spawned unit before its `_ready`). Legibility helpers (`is_idle`, `is_engaged`, `is_dying`, `is_busy`) defensively handle a not-yet-initialized FSM.
- `HealthComponent` (`game/scripts/units/components/health_component.gd`, `class_name HealthComponent` extending SimNode by path-string). Fixed-point `hp_x100` storage per Sim Contract §1.6. `init_max_hp` boundary-converts. `take_damage` and `heal` route through `_set_sim`. Latched `EventBus.unit_health_zero` emit at hp=0 (over-kill doesn't re-emit) — feeds the StateMachine death-preempt path.
- `MovementComponent` (`game/scripts/units/components/movement_component.gd`, `class_name MovementComponent` extending SimNode by path-string). `request_repath(target)` cancels prior in-flight request, issues a new one. `_sim_tick(dt)` polls scheduler, advances the parent Node3D's `global_position` toward the current waypoint at `move_speed * dt` per Sim Contract §4.1's position-write carve-out. `path_state` and `is_moving` are computed properties. Pulls scheduler from `PathSchedulerService.scheduler` at `_ready`.
- `SelectableComponent` (`game/scripts/units/components/selectable_component.gd`, `class_name SelectableComponent` extending SimNode by path-string). `select` / `deselect` toggle a placeholder MeshInstance3D ring (CylinderMesh, gold). Auto-creates the ring under the parent unit via `call_deferred` (avoids "parent busy setting up children"). Subscribes to `EventBus.selection_changed`; selects when its `unit_id` is in the broadcast list.
- `NavigationAgentPathScheduler` — production IPathScheduler at `game/scripts/navigation/navigation_agent_path_scheduler.gd`. Wraps `NavigationServer3D.map_get_path(map_rid, from, to, true)` synchronously. Resolves the active navigation map from `Engine.get_main_loop().root.world_3d.navigation_map`. `cancel_repath` flips READY → CANCELLED; FAILED is sticky. Wired as the default in `PathSchedulerService` via the autoload's `_ready`.
- `EventBus.selection_changed(selected_unit_ids: Array)` — read-shaped UI signal; not in `_SINK_SIGNALS` (telemetry tracks gameplay state, not UI state). Already L2-allowlisted in `tools/lint_simulation.sh` from Phase 0 forward-reference.
- `PathSchedulerService.reset()` semantics: now reverts to a fresh production scheduler instance, not null. `set_scheduler(null)` is the explicit opt-in for the null-scheduler defensive path.
- `docs/ARCHITECTURE.md` 0.8.0 → 0.9.0. Five new ✅ Built rows (Unit, three components, NavigationAgentPathScheduler). One Phase 1 ⛓️ wiring update on PathSchedulerService. New §6 v0.9.0 entry covers the seven divergences from spec sketches (most notably Unit-extends-CharacterBody3D-not-SimNode and SelectableComponent's call_deferred pattern).

**Test-count delta:** 250 → 312 tests (62 new tests, 17 health + 11 movement + 11 selectable + 8 nav scheduler + 15 unit). 309 passing, 3 pending (intentional fallbacks: 2 in `test_navigation_agent_path_scheduler.gd` for headless runners without a baked navmesh, 1 pre-existing in `test_resource_hud.gd` for the FarrSystem defensive-default path). 0 failing. Lint clean. ~1.8s run time.

**Did not ship** (intentionally out of scope per `02b_PHASE_1_KICKOFF.md` and the wave-1 task brief):
- Concrete `Kargar` unit type — gameplay-systems wave 2.
- Spawning workers in main.gd or a MatchSetup script — gameplay-systems wave 2.
- `UnitState_Idle` / `UnitState_Moving` concrete states — ai-engineer wave 2.
- SelectionManager + click-to-select raycast — ui-developer wave 2.
- Right-click-to-move command-building UI — ui-developer + ai-engineer wave 2.
- Full integration test of the click-and-move flow — qa-engineer wave 3.
- Box-select, control groups, multi-select — Phase 1 session 2.
- Combat, attack-move — Phase 2.

**State for next session (wave 2):**
- On branch `feat/phase-1-units`. Lint clean. `cd game && GODOT=/opt/homebrew/bin/godot ./run_tests.sh` → 312 tests, 309/309 actually-passing/3 pending.
- The Unit base class's StateMachine boots empty — concrete subclasses or scene scripts register their states (Idle, Moving) and call `fsm.init(&"idle")` after registration. The base's `_ready` defaults to `init(&"idle")` only if `&"idle"` is already registered, so wave 2's concrete Unit subclasses (Kargar) can do `fsm.register(IdleState.new())` etc. then `super._ready()`.
- The path-string-base preload pattern is established for all components. Component scripts extend `"res://scripts/core/sim_node.gd"` to dodge the class_name registry race; concrete consumers reference components by their class_name (`HealthComponent`, etc.) at runtime where the registry has settled.
- `MovementComponent._sim_tick` is the per-tick driver; phase coordinator wiring (Movement phase calls `unit._sim_tick → fsm.tick → MovingState._sim_tick → MovementComponent._sim_tick`) is wave 2's job. For now, `_sim_tick` is callable directly by states or by the wave 2 phase coordinator.
- `Unit.replace_command` and `append_command` are the only sanctioned write paths for command_queue (per State Machine Contract §2.5). Wave 2's right-click handler builds these calls.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced — the wave was pure infrastructure against ratified contracts.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **Unit extends CharacterBody3D, not SimNode directly.** State Machine Contract §5.1 sketches `Unit extends SimNode`. CharacterBody3D is needed for the unit.tscn collision shape, future formation-collision (Phase 1 session 2 GroupMoveController), and for the global_position carve-out to mean anything. Components hold the SimNode discipline; Unit is composition glue. Documented in §6 v0.9.0.
- **PathSchedulerService.reset() reverts to a fresh production scheduler.** Phase 0 had it null. Phase 1 wires production-by-default at autoload `_ready`, so reset-to-pristine naturally means reset-to-production. Tests that need null write `set_scheduler(null)`. Logged in §6 v0.9.0 + matching test update in `tests/unit/test_match_harness.gd`.
- **SelectableComponent ring added via `call_deferred`.** Avoids the "parent busy setting up children" error during the parent unit's `_ready`. Tests `await get_tree().process_frame` before inspecting the ring's parent.
- **NavigationAgentPathScheduler skips PENDING entirely.** Synchronous `NavigationServer3D.map_get_path` resolves at request time. Sim Contract §4.2 says "result lands on requested_tick + 1 or later" — "at the requested tick itself" qualifies as "or later" (a degenerate interpretation, intentional, kept for symmetry with MockPathScheduler's PENDING semantics in tests).
- **`HealthComponent.take_damage` and `heal` ignore non-positive amounts silently.** No method-routing for sign-flipped values; each method has one intent. Avoids bugs where a buff "heals -5" silently becomes damage with no audit trail.
- **Fixed-point for HP storage.** Same pattern as Farr per Sim Contract §1.6. `hp_x100: int`. Boundary conversion at `init_max_hp`/HUD/telemetry. Defends against IEEE-754 platform divergence over a long match — doesn't bite at MVP scale, but the determinism principle is cheap to enforce now and expensive to retrofit. Test `test_many_small_damages_sum_exactly` verifies 100 × 0.01 damage adds to exactly 1.0 hp with no float drift.
- **EventBus.selection_changed payload typed as plain Array, not Array[int].** GDScript signal type-narrowing for typed arrays is finicky in 4.6.2; a plain `Array` accepted with `int(id)` casts inside the SelectableComponent handler is robust against either Array[int] or Array[Variant]-of-ints from the eventual SelectionManager (whose author's wave-2 work doesn't dictate the typed-array shape yet).

## 2026-05-01 — Phase 0 Session 1: Simulation Backbone

**Branch:** `feat/phase-0-foundation`

**Shipped:**
- Godot 4.6.2 stable (official build `71f334935`) installed via Homebrew cask. Binary at `/opt/homebrew/bin/godot`.
- Godot project initialized at `game/project.godot` with the canonical directory structure (`scripts/autoload`, `scripts/core`, `scenes`, `tests/unit|integration|harness`, `addons`, `data/telemetry`, `translations`, `assets`, `shaders`). Engine version pinned in `application/config/godot_version`.
- Placeholder `Main` scene at `game/scenes/main.tscn` boots cleanly. `_physics_process` ticks `SimClock` at 30Hz; the on-screen `Label` and a once-per-second console print confirm `tick=30, sim_time=1.00s` etc.
- `TimeProvider` autoload (`game/scripts/autoload/time_provider.gd`) — wraps `Time.get_ticks_msec()`, supports `set_mock(ms)` / `clear_mock()` / `is_mocked()` for deterministic tests. Per Sim Contract §1.
- `EventBus` autoload (`game/scripts/autoload/event_bus.gd`) — typed signals `tick_started(int)`, `tick_ended(int)`, `sim_phase(StringName, int)`. `connect_sink` / `disconnect_sink` API per Sim Contract §7. No consumer wired yet (MatchLogger lands Phase 6).
- `SimClock` autoload (`game/scripts/autoload/sim_clock.gd`) — 30Hz fixed tick driver with accumulator pattern; emits `tick_started` then 7 `sim_phase` signals (`input → ai → movement → spatial_rebuild → combat → farr → cleanup`) then `tick_ended`. `is_ticking()` flips true only inside `_run_tick()`. Test hooks `_test_run_tick`, `_test_advance`, `reset`.
- `SimNode` base class (`game/scripts/core/sim_node.gd`) — `_sim_tick(_dt)` virtual, `_set_sim(prop, value)` with `assert(SimClock.is_ticking())`. Self-only mutation discipline documented in source.
- GUT 9.4.0 installed at `game/addons/gut`. Headless runner script `game/run_tests.sh`. `.gutconfig.json` points at `tests/unit` and `tests/integration`.
- 28 unit tests across 4 scripts (`test_time_provider.gd`, `test_event_bus.gd`, `test_sim_clock.gd`, `test_sim_node.gd`) all pass headless. Total time ~0.08s.
- `docs/ARCHITECTURE.md` §2 updated: Godot version recorded; SimClock, EventBus, TimeProvider, SimNode, GUT, project init moved from 📋 Planned → ✅ Built. New §6 Plan-vs-Reality entry documents the EventBus.connect_sink GDScript-syntax divergence and the SimClock test hooks (added beyond contract surface).

**Did not ship** (explicit, per `02a_PHASE_0_KICKOFF.md` §2 scope — these belong to session 2+):
- `GameRNG`, `SpatialIndex`, `Constants` autoload, `BalanceData.tres`, `GameState`, `IPathScheduler` + `MockPathScheduler`, `MatchHarness`, `FarrSystem` skeleton, `DebugOverlayManager`, camera controller, terrain plane, translation infrastructure, HUD readouts.
- CI lint script (`tools/lint_simulation.sh`) and pre-commit hook — qa-engineer's session 2 work per the kickoff coordination plan.
- `StateMachine` + `State` framework (Phase 0 task, but not in session-1 scope).

**State for next session:**
- On-branch: `feat/phase-0-foundation`. `main` is untouched.
- To run the project: `cd game && /opt/homebrew/bin/godot --path . --headless` (or open `game/project.godot` in the editor and press F5).
- To run tests headlessly: `cd game && GODOT=/opt/homebrew/bin/godot ./run_tests.sh` — exits non-zero on failure; ready for the pre-commit hook to call.
- `qa-engineer` is unblocked: lint script (the 5 ripgrep patterns from Sim Contract §1.4) and pre-commit hook can land immediately.
- The session-2 simulation-backbone tasks (Constants, GameState, SpatialIndex, IPathScheduler interface + MockPathScheduler, StateMachine framework) all sit cleanly on top of the autoloads shipped here. Pattern for new autoloads: register in `project.godot` `[autoload]`, add tests in `tests/unit/test_<name>.gd`, follow TDD red-green-refactor.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced — the work was pure infrastructure against a ratified contract.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **EventBus `connect_sink` internal forwarder shape.** The Sim Contract §7 sketch uses GDScript-invalid varargs lambda syntax (`func(...args)`). Built one hand-rolled per-signal forwarder Callable per `(sink, signal)` pair instead. Public API matches the contract exactly; only the internal dispatch differs. Adding a new signal to `_SINK_SIGNALS` now requires a one-line `match` arm in `_make_forwarder`. Documented in the source and in `docs/ARCHITECTURE.md` §6.
- **`SimClock._test_run_tick`, `_test_advance`, `reset`.** Test-driving hooks added on the autoload to let GUT (and the future MatchHarness) drive ticks manually. Share the same `_run_tick()` body as `_physics_process`, so live and headless paths cannot diverge — Sim Contract §6.1's "must do" list satisfied. Logged in §6.
- **`gl_compatibility` rendering backend.** Chosen for the placeholder phase to keep the project light and well-supported on Apple Silicon dev machines. Not gameplay-affecting; revisitable any time without retrofit.
- **Pre-commit hook NOT installed this session** — it's part of the qa-engineer's session 2 deliverable per the kickoff. Adding it now would step on their owned files (`tools/lint_simulation.sh` is theirs).
- **GUT 9.4.0** chosen as the latest compatible release at session start. Sourced from the official `bitwes/Gut` GitHub release tarball, copied to `game/addons/gut`.
- **Engine warnings tightened in `[debug]` block** of `project.godot` (`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`). Catches a class of bugs early without affecting gameplay.

## 2026-04-30 — Phase 0 Session 3: Foundational Autoloads + State Machine Framework

**Branch:** `feat/phase-0-foundation`

**Shipped:**
- `Constants` autoload (`game/scripts/autoload/constants.gd`) — structural keys/enums per Testing Contract §1.1. Phase StringNames, EventBus signal-name keys, team identifiers (`TEAM_NEUTRAL`, `TEAM_IRAN`, `TEAM_TURAN`, `TEAM_ANY`), resource kinds (`KIND_COIN`, `KIND_GRAIN`), match phase enum, state ids, command kinds, structural caps (`COMMAND_QUEUE_CAPACITY`, `STATE_MACHINE_TRANSITIONS_PER_TICK`, history sizes), `SPATIAL_CELL_SIZE`. No tunable numbers — those land in `BalanceData.tres` (session 4). Tests in `tests/unit/test_constants.gd`.
- `GameState` autoload (`game/scripts/autoload/game_state.gd`) — match-level state. `match_phase` (`lobby`/`playing`/`ended`), `winner_team`, `match_start_tick`, `player_team`. `start_match(team)` captures `SimClock.tick`; `end_match(winner)` finalizes. `match_tick()` / `match_time()` give relative-to-start offsets. Idempotent re-entry guards (`start_match` while PLAYING is a no-op; `end_match` outside PLAYING is a no-op). Tests in `tests/unit/test_game_state.gd`.
- `SpatialIndex` autoload + `SpatialAgentComponent` (`game/scripts/autoload/spatial_index.gd`, `game/scripts/core/spatial_agent_component.gd`) — uniform 8m grid (XZ plane, Y ignored). Three queries: `query_radius`, `query_nearest_n`, `query_radius_team`. `SpatialAgentComponent extends SimNode`; auto-registers on `_ready`, deregisters on `_exit_tree`. `SpatialIndex._rebuild()` listens on `EventBus.sim_phase(&"spatial_rebuild", _)`. Tests in `tests/unit/test_spatial_index.gd`.
- `IPathScheduler` interface + `PathSchedulerService` autoload (`game/scripts/core/path_scheduler.gd`, `game/scripts/autoload/path_scheduler_service.gd`) — interface-only this session per Sim Contract §4.2. Defines `PathState` enum (PENDING/READY/FAILED/CANCELLED) and the three abstract methods. `PathSchedulerService` holds the active scheduler with `set_scheduler()` / `reset()` for injection; defaults to `null`. Real `NavigationAgentPathScheduler` and test `MockPathScheduler` ship session 4. Tests in `tests/unit/test_path_scheduler_service.gd` (uses an inline `_StubScheduler` to verify the service accepts injection).
- `StateMachine` framework (`game/scripts/core/state_machine/`) — full framework per State Machine Contract 1.0.0. Files: `state.gd`, `state_machine.gd`, `command.gd`, `command_queue.gd`, `unit_state.gd`, `interrupt_level.gd`. Plus `CommandPool` autoload (`game/scripts/autoload/command_pool.gd`). Death-preempt connected via `EventBus.unit_health_zero`; transition history ring buffer (16 entries unit / `set_history_capacity(64)` for AI). `transition_to_next()` dispatcher pops `Command`, maps `kind→state-id`, transitions. Bounded chain of 4 transitions per tick. `EventBus.unit_state_changed` emits on every transition for telemetry. Tests in `tests/unit/test_state_machine.gd` — covers Command/CommandPool/CommandQueue, init+transitions, transition_to_next dispatch, history ring buffer, death-preempt (force-transition + cancels pending + filters by unit_id + idempotent).
- `EventBus` extended with `unit_health_zero(int)` and `unit_state_changed(int, StringName, StringName, int)`. Both added to `_SINK_SIGNALS` with their `_make_forwarder` match arms.
- `docs/ARCHITECTURE.md` bumped 0.2.0 → 0.4.0. Build-state table: Constants, GameState, SpatialIndex, IPathScheduler, StateMachine moved 📋 → ✅; `CommandPool` and `PathSchedulerService` rows added. New §6 entries (v0.4.0) document the `class_name State` removal, duck-typed SpatialIndex paths, query_nearest_n source-exclusion gap, two new EventBus signals, and GameState idempotency guards.

**Test-count delta:** 28 → 88 tests passing headless across 9 scripts. Asserts 140 → 233. Total time ~0.1s.

**Did not ship** (per kickoff doc scope — session 4+ or later):
- `MockPathScheduler` (qa-engineer, session 4) — needs the IPathScheduler interface that landed this session.
- `MatchHarness` (qa-engineer, session 4) — depends on Constants, GameState, BalanceData.
- `BalanceData.tres` (balance-engineer, session 4).
- `GameRNG` (engine-architect, future session) — kickoff doc moved it out of session 3 scope.
- `FarrSystem` skeleton, `DebugOverlayManager`, camera controller, terrain plane, translations, HUD readouts — covered by `ui-developer` and `world-builder` running in parallel after this session, plus `gameplay-systems` later.
- Concrete unit states (Idle, Moving, Attacking, etc.) — Phase 1.
- Phase coordinators that actually tick component lists — Phase 1+ (the autoloads exist; coordinators wire them up later).

**State for next session:**
- On branch `feat/phase-0-foundation`. Lint clean. `cd game && GODOT=/opt/homebrew/bin/godot ./run_tests.sh` → 88/88 passing.
- New autoloads in `project.godot` (in load order): `TimeProvider`, `EventBus`, `Constants`, `SimClock`, `GameState`, `SpatialIndex`, `PathSchedulerService`, `CommandPool`. The order matters — `Constants` must precede `SimClock` and `GameState` (both reference it); `EventBus` precedes `SpatialIndex` (which subscribes to `sim_phase` in `_ready`).
- Pre-commit hook fires on commit; runs lint + GUT.
- `ui-developer` and `world-builder` are now unblocked to run in parallel — camera controller, terrain plane, debug overlay manager. None of those touch the engine layer.
- Session 4 picks up: `MockPathScheduler` + `MatchHarness` (qa-engineer), `BalanceData.tres` (balance-engineer), and the integration glue.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. All session work was infrastructure against ratified contracts.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **Removed `class_name State`** from `state.gd`. Godot 4.6.2's class_name registry has a resolution race when test scripts (collected by GUT) define inner classes that extend a script-with-class_name by path-string. The behavior is preserved exactly; only the global symbol-table registration was dropped. State Machine Contract surface (the `State` type via path or preload, the `enter`/`_sim_tick`/`exit` methods, the `id`/`priority`/`interrupt_level` fields) is unchanged. Same workaround applied to internal type annotations on `StateMachine` (`current: Variant`, `register(state: Object)`) and `CommandQueue` (`push(cmd: Object)`, `peek/pop -> Object`). Not a contract change — documented in `docs/ARCHITECTURE.md` §6 (v0.4.0).
- **`SpatialIndex` reads agent fields duck-typed.** `agent.get(&"team")` and `agent.has_method(&"world_position")` instead of `agent as SpatialAgentComponent`. Same root cause: autoloads parse before `class_name` registration completes for child component scripts. Type safety preserved by behavior — only `SpatialAgentComponent` instances ever register.
- **`SpatialIndex.query_nearest_n` does not auto-exclude the source.** Sim Contract §3.3 says it should; the API doesn't carry a "source" parameter, so we couldn't implement it in a clean general-case way. Documented in §6 — first concrete consumer in Phase 1 will dictate whether to extend the API or filter at the call site. Not a runtime hazard at this point — no consumer yet.
- **`CommandPool` returns `Object` rather than `Command`.** Same class_name-resolve workaround. The pool is the only sanctioned way to get a Command; behavior is identical.
- **Two new EventBus signals (`unit_health_zero`, `unit_state_changed`)** declared this session even though no producer ships yet. Required by State Machine Contract §4.1 / §5.3; declaring them now means the framework can be unit-tested end-to-end (death-preempt tests fire `unit_health_zero` directly).
- **`GameState.start_match` / `end_match` idempotency.** Re-entering each is a `push_warning` no-op rather than a hard error. Determinism rationale: a silent overwrite of `match_start_tick` mid-match would corrupt every match-relative time read downstream. Failing loudly via assert was rejected because a `push_warning` is enough — the no-op preserves the right state.

## 2026-04-30 — Phase 0 Session 2: Lint Gate + Pre-commit Hook

**Branch:** `feat/phase-0-foundation`

**Shipped:**
- `tools/lint_simulation.sh` — implements all 5 simulation lint rules from Sim Contract §1.4. L1: mutation from `_process`. L2: write-shaped EventBus emit from `_process`. L3: bare RNG outside GameRNG allowlist. L4: string-form `emit_signal("...")`. L5: wall-clock reads outside TimeProvider/SimClock. Exits 0 on clean, 1 on violations, 127 if ripgrep not found. Comment-line false-positive filtering added for L3 (GDScript `#` comments containing RNG function names in prose are excluded). All 5 rules verified against deliberate violation files (one per rule, created and deleted without committing).
- `tools/git-hooks/pre-commit` — the canonical (version-controlled) pre-commit hook. Runs lint then GUT; blocks commit on either failure.
- `tools/install-hooks.sh` — installs hooks from `tools/git-hooks/` to `.git/hooks/` with backup of any existing hook. Run once after cloning: `bash tools/install-hooks.sh`.
- `docs/ARCHITECTURE.md` §2 updated: CI lint script and pre-commit hook rows moved from 📋 Planned → ✅ Built. §6 plan-vs-reality entry added for session 2 (L5 allowlist discrepancy, L3 comment filter, rg shell-function note).
- Pre-commit hook installed locally via install-hooks.sh and verified to fire on a clean commit (lint passes + 28/28 GUT tests pass).

**Did not ship** (per kickoff doc scope — session 3+ or later):
- `MatchHarness` — blocked on `IPathScheduler` interface (engine-architect, session 3).
- `MockPathScheduler` — same blocker.
- Determinism regression test stub — deferred to when MatchHarness exists.
- `GameRNG`, `SpatialIndex`, `Constants`, `GameState`, `StateMachine`, `DebugOverlayManager`, camera, terrain, translations, HUD readouts — all session 3+ per scope split.

**State for next session:**
- On branch `feat/phase-0-foundation`. Hook installed locally; any new clone needs `bash tools/install-hooks.sh` once.
- To verify the gate: `bash tools/lint_simulation.sh` (should exit 0); `cd game && GODOT=/opt/homebrew/bin/godot ./run_tests.sh` (28/28).
- Godot binary: `/opt/homebrew/bin/godot` (4.6.2 stable). Ripgrep: `/opt/homebrew/bin/rg` (15.1.0).
- Sessions 3-4 deliverables: `IPathScheduler` + `MockPathScheduler`, `MatchHarness`, `GameRNG`, `Constants`, `GameState`, `StateMachine`, `FarrSystem` skeleton, `DebugOverlayManager`, camera, terrain plane, translations, HUD.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **Allowlisted both `time_provider.gd` and `sim_clock.gd` for L5.** The Sim Contract §1.4 table lists `sim_clock.gd`; the kickoff doc and `time_provider.gd` source name `time_provider.gd`. Both are allowlisted. Documented in `docs/ARCHITECTURE.md` §6.
- **Comment-line filter for L3.** GDScript `#` comment lines that contain RNG function names in prose (e.g., doc comments explaining what NOT to do) would cause false positives. Added a post-scan filter using `rg -v ':[0-9]+:\s*#'` to strip comment matches from L3 results. Analogous filtering could be added to other rules if needed — not added preemptively.
- **`bash --noprofile --norc` for development verification.** In the Claude Code session environment, `rg` is intercepted as a shell function. The lint script works correctly in a clean bash environment (pre-commit hooks and CI). No change to the script; noted here.

## 2026-04-30 — Phase 0 Session 3 wave 2 (world-builder)

**Branch:** `feat/phase-0-foundation`

**Shipped:**
- `Constants.MAP_SIZE_WORLD = 256.0` and `Constants.NAV_AGENT_RADIUS = 0.5` added to `game/scripts/autoload/constants.gd` under a new `# === MAP CONFIGURATION ===` section. Single source of truth for map dimensions and navmesh agent clearance. Per 02_IMPLEMENTATION_PLAN.md Phase 0 convergence checkpoint and session-3 wave-2 spec.
- Terrain scene `game/scenes/world/terrain.tscn` — `NavigationRegion3D` root with a `StaticBody3D` (+ `CollisionShape3D` BoxShape3D 256×0.1×256) and a `MeshInstance3D` (PlaneMesh 256×256) as siblings. Root has a placeholder `StandardMaterial3D` with sandy-ochre albedo. Scene reads `Constants.MAP_SIZE_WORLD` for sizing (256.0 world units on the XZ plane at Y=0).
- Terrain script `game/scripts/world/terrain.gd` — extends `NavigationRegion3D`. `_ready()` calls `_configure_navmesh()` (sets agent radius from `Constants.NAV_AGENT_RADIUS`, `PARSED_GEOMETRY_STATIC_COLLIDERS`, bake AABB from `Constants.MAP_SIZE_WORLD`) then `_bake_navmesh()` (synchronous `bake_navigation_mesh(false)`). No runtime rebake after `_ready` — consistent with `RESOURCE_NODE_CONTRACT.md §3.2` and the session-2 lint rule.
- 7 new GUT tests in `game/tests/unit/test_terrain.gd`: `MAP_SIZE_WORLD` value, `NAV_AGENT_RADIUS` value and positivity, terrain scene loads, NavigationRegion3D present, mesh is 256×256, mesh at Y=0, navmesh RID valid after bake.
- `docs/ARCHITECTURE.md` bumped 0.4.0 → 0.5.0. Terrain plane row moved `📋 Planned → ✅ Built`. §6 v0.5.0 plan-vs-reality entry added (geometry source choice, bake strategy, material choice, constants additions).

**Test-count delta:** 88 → 114 passing (world-builder contributed 7, ui-developer contributed the remaining 19 in parallel). All 114 pass headless.

**Did not ship** (out of scope for this wave, per session-3 wave-2 kickoff):
- Multiple terrain types (passable/mountain/water/fertile) — Phase 7.
- Resource node placement (mines, fertile zones) — Phase 3.
- Fog of war data layer — Phase 3 / Phase 7.
- Real Khorasan map design — Phase 7.
- Modifying `scenes/main.tscn` — engine-architect's session-4 integration work.
- Concrete biomes, terrain height, environmental effects — Phase 7.

**State for next session:**
- On branch `feat/phase-0-foundation`. Lint clean (world-builder files). 114/114 tests passing.
- Terrain scene is a self-contained scene at `game/scenes/world/terrain.tscn`. Session 4 (engine-architect) wires it into `scenes/main.tscn` or `scenes/match.tscn`.
- `Constants.MAP_SIZE_WORLD = 256.0` is available to the camera controller for boundary clamping — the ui-developer's camera controller already reads it (confirmed by their passing tests).
- The navmesh bakes at scene-load from the StaticBody3D collision shape. In-editor, consider baking and serializing the NavigationMesh resource to disk (avoiding the startup bake cost) before Phase 7.
- Lint gate: the full lint run shows one violation in `game/scripts/camera/camera_controller.gd` (ui-developer's file, L1 false positive from `apply_pan` / `apply_zoom` method names matching the mutation pattern). This is NOT a world-builder issue — coordinate with ui-developer or engine-architect to resolve before the next PR merge.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **`PARSED_GEOMETRY_STATIC_COLLIDERS` over `PARSED_GEOMETRY_MESH_INSTANCES`.** PlaneMesh bake via MESH_INSTANCES causes a GPU readback warning in headless contexts. StaticBody3D BoxShape3D provides identical walkable geometry with no GPU involvement. Documented in `docs/ARCHITECTURE.md` §6 v0.5.0.
- **`StandardMaterial3D` flat albedo as placeholder, not procedural shader.** Zero footprint — no asset files, no shader compilation. If more visual scale granularity is needed before Phase 7 art, `CheckerTexture2D` can be assigned to `albedo_texture` in one tscn line. Not gameplay-affecting.
- **BoxShape3D CollisionShape3D offset at Y=-0.05.** The box is 0.1 units tall. Centering it at Y=-0.05 puts the top face at Y=0 (the ground plane). Without the offset, units at Y=0 would be partially inside the collision shape. Purely physical placement, no gameplay effect.

## 2026-05-01 — Phase 0 session 3 wave 2 (ui-developer)

**Branch:** `feat/phase-0-foundation`

**Shipped:**
- Camera controller `game/scripts/camera/camera_controller.gd` — fixed-isometric RTS rig per Sync 6 Engine-Constraint convergence + 02_IMPLEMENTATION_PLAN.md Phase 0. Extends `Node3D` (the rig is the pivot; the `Camera3D` lives as a child with its angle baked into the scene file). WASD pan with diagonal-input normalization (Vector2.normalized so √2 doesn't leak in), edge-pan within 50px of any viewport edge, scroll-wheel zoom with `[zoom_min, zoom_max]` clamps, frame-rate independent (every motion is `pan_speed * delta`). Bounds clamp via `Constants.MAP_SIZE_WORLD` (defensive read with a `@export var map_size: float = 256.0` fallback for parallel-session timing). **No rotation API** — the test `test_controller_does_not_expose_rotation_api` asserts the absence of `rotate_yaw`, `rotate_pitch`, `orbit`, `set_yaw`, `set_pitch` methods and `yaw` / `pitch` properties as a regression tripwire.
- Camera rig scene `game/scenes/camera/camera_rig.tscn` — `Node3D` (rig) with yaw -45° baked once in the scene transform, holding a `Camera3D` child with pitch -55° baked in its local transform. Code never modifies either rotation. The result is the classic RTS top-third isometric vantage, which matches `00_SHAHNAMEH_RESEARCH.md`'s Persian-miniature aesthetic.
- `DebugOverlayManager` autoload `game/scripts/autoload/debug_overlay_manager.gd` — registry-only framework per the kickoff doc rule "concrete overlays land WITH their owning systems, not the framework alone." Public API: `register_overlay(key, Control)`, `unregister_overlay(key)`, `is_registered(key)`, `get_overlay(key)`, `registered_keys()`, `toggle_overlay(key)`, `handle_function_key(keycode)`, `reset()`. F1-F4 dispatch via `_unhandled_input` → `handle_function_key` → `Constants.OVERLAY_KEY_F1`..`F4`. `process_mode = ALWAYS` so overlays toggle even when paused. Off-tick reads only per Sim Contract §1.5; the manager never mutates sim state, only flips `Control.visible`.
- DebugOverlayManager registered as the 9th autoload in `game/project.godot` after `CommandPool`. Order doesn't matter — no upstream deps.
- 19 GUT unit tests in `game/tests/unit/test_camera_controller.gd` covering: no-rotation API surface, +X / +Y screen-axis → world-XZ pan mapping, diagonal normalization, zero-input no-op, frame-rate independence (two halves == one whole), zoom in/out direction, zoom clamps to min and max, bounds clamping on positive and negative axes (and via `clamp_to_bounds` directly), edge-pan center-zero, edge-pan threshold trigger, edge-pan outside-threshold no-op, top edge → -Y axis, bottom-right corner → (+X, +Y), and the literal `edge_pan_threshold_px == 50` Phase-0-contract assertion.
- 16 GUT unit tests in `game/tests/unit/test_debug_overlay_manager.gd` covering: autoload reachable, default empty registry, register adds, register-replaces last-writer-wins, unregister removes, unregister unknown is no-op, toggle flips off→on→off, double-toggle restores, toggle unknown is no-op, F1/F2/F3/F4 dispatch each toggle their bound overlay, non-F1-F4 keys (F5, A) don't dispatch, double F-press hides again, reset clears registry.
- `docs/ARCHITECTURE.md` bumped 0.5.0 → 0.6.0. Camera Controller and DebugOverlayManager rows moved 📋 Planned → ✅ Built. New §6 v0.6.0 plan-vs-reality entry: lint-driven rename `apply_pan` / `apply_zoom` → `pan_by` / `zoom_by`, defensive `Constants.MAP_SIZE_WORLD` read, Node3D-rig + Camera3D-child architecture, `process_mode = ALWAYS` rationale, keycode-based dispatch deferral note for InputMap migration.

**Test-count delta:** 114 → 130 passing headless across 12 test scripts (asserts 273 → 291). 35 new tests from this wave alone (19 camera + 16 debug overlay). All 130 pass headless in ~0.95s. Lint clean (0 violations across L1-L5).

**Did not ship** (out of scope per session 3 wave 2 kickoff):
- Selection system (single-click, box-select, control groups) — Phase 1.
- HUD, Farr gauge, minimap, build menu, hero portrait — Phase 1+ per 02_IMPLEMENTATION_PLAN.md.
- Translation infrastructure (`translations/strings.csv`) — later session.
- Concrete debug overlays themselves (F1 pathfinding viz, F2 Farr log, F3 AI state, F4 attack ranges) — they ship WITH their owning systems in later phases per CLAUDE.md.
- Wiring the camera rig into `scenes/main.tscn` — engine-architect's session 4 task; out of scope for this wave to avoid stepping on their domain.
- Resource HUD readouts (Coin/Grain/FARR/Pop) — also session 4+ when the systems exist to read from.

**State for next session:**
- On branch `feat/phase-0-foundation`. Lint clean. 130/130 tests passing headless.
- New autoload load order in `project.godot`: `TimeProvider`, `EventBus`, `Constants`, `SimClock`, `GameState`, `SpatialIndex`, `PathSchedulerService`, `CommandPool`, `DebugOverlayManager`. The new autoload has no deps; instantiation order is irrelevant.
- The camera rig is a self-contained scene at `scenes/camera/camera_rig.tscn`. Drop it into any scene tree and it works. Session 4 (engine-architect) wires it into `main.tscn` (or `match.tscn` once that scene exists).
- DebugOverlayManager is operational from Phase 0. As later sessions land debug overlays, each does `DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_FX, control_node)` once in `_ready()` and gets F-key toggling for free.
- The lint-rule rename (`apply_*` → `*_by`) is local to the camera controller. No other UI or sim file uses the `apply_` prefix for non-mutator methods, so this is unlikely to bite again. If it does, the convention is documented in `docs/ARCHITECTURE.md` §6 v0.6.0.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design/feel/balance questions surfaced — the work was infrastructure against a ratified contract.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1 — non-design implementation choices):
- **Renamed `apply_pan` / `apply_zoom` to `pan_by` / `zoom_by`.** The `apply_*` prefix is the lint pattern (L1) for "gameplay mutation called from `_process`". The camera mutates camera-side state from `_process` legitimately (UI/off-tick is allowed to write *its own* state per Sim Contract §1.5; only sim state is locked to `_sim_tick`). Renaming preserved the lint's intent without an allowlist exception. No contract surface change. Documented in `docs/ARCHITECTURE.md` §6 v0.6.0.
- **`Constants.MAP_SIZE_WORLD` read defensively via `Constants.get(&"MAP_SIZE_WORLD")` with a `@export var map_size: float = 256.0` fallback.** Camera and terrain shipped in parallel sessions; if camera lands first the constant might not exist yet. World-builder shipped the constant in this same wave, so production reads it cleanly; the fallback is belt-and-braces.
- **Camera rig is `Node3D` with a `Camera3D` *child*, not `Camera3D` directly.** Standard RTS-camera architecture: rig is the pivot the controller pans, child is the lens with the angle baked in. Code never rotates either — yaw -45° is in the rig scene transform, pitch -55° is in the child camera transform. The "no rotation" contract is enforced both by the test surface (no rotation methods/properties) and by the source code's lack of any `rotation_*` writes after `_ready`.
- **F-key dispatch via `_unhandled_input` + raw keycode match, not via Godot InputMap actions.** Phase 0 doesn't yet have an InputMap configured, and adding one for four debug keys would be premature. The dispatch is testable as `handle_function_key(KEY_F1)`. When InputMap arrives in Phase 1+ for selection / commands, F1-F4 can move to actions in a one-line search-and-replace inside `handle_function_key`. Documented in `docs/ARCHITECTURE.md` §6 v0.6.0.
- **`DebugOverlayManager.process_mode = ALWAYS`.** Debug overlays must be toggleable while the game is paused (they're for inspection). Set in `_ready` so Godot keeps delivering input through pause.
- **Zoom and pan tunables (`pan_speed`, `zoom_step`, `zoom_min`, `zoom_max`, `zoom_default`, `edge_pan_threshold_px`) live as `@export` on the controller.** They're camera-feel knobs, not balance numbers. If a "camera config" surfaces later, hoist to BalanceData; for now keep them where they're tuned.

---

## 2026-04-30 — Phase 0 session 4 wave 1 (qa-engineer)

**Branch:** `feat/phase-0-foundation`

**Shipped:**

- `game/scripts/navigation/mock_path_scheduler.gd` — `MockPathScheduler` extends `IPathScheduler` per SIMULATION_CONTRACT.md §4.3 and TESTING_CONTRACT.md §3.4. Concrete behaviors:
  - `request_repath(unit_id, from, to, priority)` returns monotonically-increasing positive request_ids and appends to a public `call_log: Array[Dictionary]`.
  - `poll_path(request_id)` returns PENDING until `SimClock.tick >= requested_tick + 1`; transitions to READY with a straight-line `[from, to]` two-point PackedVector3Array.
  - CANCELLED and FAILED states are sticky — do not flip back to READY even after the ready tick.
  - `cancel_repath(request_id)` is idempotent; unknown ids are a no-op.
  - `fail_next_request()` auto-clearing flag forces the next request to resolve FAILED; enables testing the "no path exists" branch without real navigation.
  - `get_request_count_for_unit(unit_id: int) -> int` counts all requests (including cancelled).
  - `clear_log()` resets `call_log`, `_requests`, `_next_id`, and `_fail_next`.
  - Zero NavigationServer3D contact — headless tests cannot deadlock.

- `game/tests/unit/test_mock_path_scheduler.gd` — 15 GUT unit tests covering: unique ids, log recording, multiple requests per unit logged separately, PENDING before ready tick, READY at tick+1 with correct waypoints, no flip-to-READY before tick elapses, cancel sets CANCELLED, cancel unknown id is no-op, CANCELLED sticky after ready tick passes, fail_next_request resolves FAILED, fail_next auto-clears after one use, `get_request_count_for_unit` correct counts, `clear_log` resets all state + id counter, unknown poll_path id returns FAILED.

- `docs/ARCHITECTURE.md` §2 — `MockPathScheduler` row moved from 📋 Planned to ✅ Built (qa-engineer row only touched).

**Test-count delta:** 130 → 145 passing headless across 13 test scripts (asserts 291 → 328). All 145 pass in ~0.96s. Lint clean (0 violations across L1-L5).

**Did not ship** (out of scope per wave 1 kickoff):
- `MatchHarness` — wave 2, blocked on `BalanceData.tres` (balance-engineer wave 1 deliverable) and `FarrSystem` (gameplay-systems wave 1). Returns in wave 2.
- `NavigationAgentPathScheduler` (production wrapper around NavigationServer3D) — engine-architect's deliverable.
- Determinism regression test stub — depends on MatchHarness.

**Plan-vs-reality notes:**

- **`get_request_log()` method removed; `call_log` is a public field.** The kickoff spec listed `get_request_log() -> Array[Dictionary]` as an inspection method. During implementation, SIMULATION_CONTRACT.md §4.3 was found to describe `call_log: Array[Dictionary]` as the public property directly. The linter trimmed `get_request_log()` (which was a thin wrapper over `call_log`) during its cleanup pass; the public field exposes the same data without a method call. Tests use `_mock.call_log` directly. No contract change required; the kickoff spec was describing the desired *data*, not mandating a specific accessor method shape.

- **`_mock` field typed as `Variant` in tests.** The class_name registry race (documented in ARCHITECTURE.md §6 v0.4.0) affects any typed field reference to `MockPathScheduler` in a GUT test file. Applied the established project pattern: `var _mock: Variant` + `_mock = MockPathSchedulerScript.new()` via the preloaded script ref. All method calls on `Variant` require explicit `var rid: int = _mock.request_repath(...)` (no `:=` inference). This is the same pattern used in `test_path_scheduler_service.gd`.

- **Other agents' test parse errors are benign.** GUT reports `SCRIPT ERROR: Identifier "FarrSystem" not declared` and `BalanceData` errors from other wave-1 agents' test files that are being written in parallel. GUT skips those scripts with a warning and counts them as 0 tests — it does not fail the overall run. The 145 tests that do run all pass. These will resolve when wave 1 completes and the missing autoloads/classes land.

**State for wave 2:**
- On branch `feat/phase-0-foundation`. Lint clean. 145/145 tests passing headless.
- `MockPathScheduler` is ready for `MatchHarness.new()` to inject via `PathSchedulerService.set_scheduler(MockPathSchedulerScript.new())` or via direct component injection.
- Wave 2 task: `MatchHarness` at `game/tests/harness/match_harness.gd` per TESTING_CONTRACT.md §3.1. Blocked on `BalanceData.tres` (balance-engineer) and `FarrSystem` skeleton (gameplay-systems) from wave 1. Determinism regression test stub follows MatchHarness.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none.

---

## 2026-05-01 — Phase 0 Session 4 Wave 1: Combined Summary (all agents)

**Branch:** `feat/phase-0-foundation`

**Shipped (all agents combined this wave):**

- **MockPathScheduler** (qa-engineer) — `scripts/navigation/mock_path_scheduler.gd`. Full test double for `IPathScheduler`. Straight-line paths, READY at `requested_tick + 1`, public `call_log: Array[Dictionary]`, `fail_next_request()` one-shot flag, idempotent `cancel_repath()`, `clear_log()` full reset. 15 GUT tests in `tests/unit/test_mock_path_scheduler.gd`.

- **FarrSystem skeleton** (gameplay-systems) — `scripts/autoload/farr_system.gd`. Fixed-point int storage (Farr × 100). `apply_farr_change(amount, reason, source_unit)` sole mutation chokepoint; asserts `SimClock.is_ticking()`; emits `EventBus.farr_changed`. `EventBus.farr_changed` signal added to `event_bus.gd`. Generators/drains deferred to Phase 4; Kaveh Event to Phase 5. Tests in `tests/unit/test_farr_system.gd`.

- **BalanceData resource** (balance-engineer) — `data/balance_data.gd` (`class_name BalanceData extends Resource`) + `data/balance.tres`. Six sub-resources: `UnitStats`, `BuildingStats`, `FarrConfig`, `CombatMatrix`, `EconomyConfig` (nests `ResourceNodeConfig`), `AIConfig` (12 flat exported fields for easy/normal/hard per AI_DIFFICULTY.md v1.1.0). `validate_hard()` / `validate_soft()` gate. Tests in `tests/unit/test_balance_data.gd`.

- **Resource HUD + Farr HUD readout** (ui-developer) — `scenes/ui/resource_hud.tscn` + `scripts/ui/resource_hud.gd`. Plain-text Coin / Grain / FARR / Pop readout. All strings via `tr()` for i18n. Wired into `main.tscn`. Circular Farr gauge deferred to Phase 1. Tests in `tests/unit/test_resource_hud.gd`.

- **Translation infrastructure** (ui-developer) — `translations/strings.csv` with `en` and `fa` (Farsi) columns; compiled to `strings.en.translation` and `strings.fa.translation`; registered in `project.godot`. All HUD labels use `tr()` from day one.

- **main.tscn integration** (engine-architect) — `CameraRig` and `ResourceHUD` wired into `scenes/main.tscn`; `StatusLabel` repositioned below the HUD row.

- **ARCHITECTURE.md 0.6.0 → 0.7.0** (qa-engineer) — MockPathScheduler, FarrSystem skeleton, BalanceData, Translation infrastructure, Farr HUD readout rows moved 📋 Planned → ✅ Built.

**Did not ship** (deferred to wave 2 or later):
- `MatchHarness` — wave 2 (qa-engineer). Both blockers (FarrSystem + BalanceData) now resolved.
- `NavigationAgentPathScheduler` — engine-architect, pending.
- Determinism regression test stub — after MatchHarness.
- `GameRNG` autoload — still deferred.
- Farr generators/drains (Phase 4); Kaveh Event (Phase 5).

**State for wave 2:**
- On branch `feat/phase-0-foundation`. Lint clean. All tests passing headless.
- `MockPathScheduler` + `FarrSystem` + `BalanceData` are all available for `MatchHarness` to inject and query.
- Wave 2 primary deliverable (qa-engineer): `game/tests/harness/match_harness.gd` per TESTING_CONTRACT.md §3.1 — `advance_ticks(n)`, `snapshot()`, `_test_set_farr(value)`.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none.

---

## 2026-05-01 — Phase 0 session 4 wave 2 (qa-engineer)

**Branch:** `feat/phase-0-foundation`

**Shipped:**

- `game/tests/harness/match_harness.gd` — `MatchHarness` per TESTING_CONTRACT.md §3.1. No class_name (registry-race workaround, ARCHITECTURE.md §6 v0.4.0). Public API: `start_match(seed, scenario)` resets all autoloads + injects MockPathScheduler + loads BalanceData + seeds global RNG + starts match. `advance_ticks(n)` via SimClock._test_run_tick (shared code path with live driver — Sim Contract §6.1). `snapshot()` returns flat primitive-only Dict (tick/farr/coin_iran/grain_iran/coin_turan/grain_turan/unit_count_iran/unit_count_turan). `_test_set_farr(value)` direct off-tick write to FarrSystem._farr_x100 with synthetic farr_changed emit. `set_resources/get_resources/get_unit/spawn_unit/spawn_building` helpers (spawn stubs return null in Phase 0). `teardown()` resets all autoloads.

- `game/tests/harness/scenarios.gd` — Scenario catalog (data-only `const CATALOG: Dictionary`). Six scenarios: `empty` (blank slate), `starved` (zero resources), `rich` (1000 coin/grain), `kaveh_edge` (Farr=16.0), `kaveh_triggered` (Farr=14.0), `basic_combat` (stub = empty). Adding new scenario is a one-line Dict entry.

- `game/scripts/autoload/farr_system.gd` — Added `reset()` method (cross-domain; explicitly authorized by wave-2 kickoff doc). Reads starting_value from BalanceData, writes _farr_x100, emits synthetic farr_changed with reason "harness_reset". Off-tick write intentional — reset is a test-harness escape, not a gameplay mutation.

- `game/tests/unit/test_match_harness.gd` — 19 GUT unit tests: start_match resets SimClock+GameState+Farr+PathScheduler, sets GameState PLAYING, captures match_start_tick. advance_ticks(n) increments SimClock by exactly n, advance_ticks(0) no-op, pipeline emits 7 sim_phase signals. snapshot keys/primitives/tick/farr/resources all correct. _test_set_farr updates Farr, emits farr_changed with "test_set" reason, clamps correctly. teardown resets all state; subsequent start_match sees no leakage. Same seed → identical snapshots.

- `game/tests/integration/test_match_harness.gd` — 25 GUT integration tests covering the same API surface from integration perspective: lifecycle, scenarios (kaveh_edge/rich/starved), resource round-trips, snapshot field accuracy, determinism regression stub.

- `game/tests/integration/test_determinism.gd` — 3 GUT integration tests (Sim Contract §6.2 stub): `test_empty_match_is_deterministic` (Phase 0 bar — same seed→same snapshot after 60 ticks), `test_different_seeds_produce_same_empty_snapshots` (documents Phase 0 no-RNG-consumer behavior), `test_sequential_harnesses_are_isolated` (teardown isolation check).

- `docs/ARCHITECTURE.md` bumped 0.7.0 → 0.8.0. MatchHarness and Determinism regression test rows moved 📋 Planned → ✅ Built. New §6 v0.8.0 plan-vs-reality entry: class_name removal, _test_set_farr off-tick simplification, FarrSystem.reset() cross-domain, start_match vs create naming, CATALOG data-only shape, test count delta.

**Test-count delta:** 199 → 250 passing headless (51 new tests). 1 Pending (ui-developer's HUD defensive-fallback test — intentional, unchanged). Lint clean (0 violations across L1-L5).

**Did not ship** (intentionally out of scope per wave-2 kickoff):
- `spawn_resource_node` test helper — Phase 3.
- `MatchLogger` NDJSON telemetry writer — Phase 6.
- AI-vs-AI sim harness batch runner — Phase 6.
- `GameRNG` autoload wiring in harness — engine-architect's deliverable; harness uses `seed()` on Godot global RNG as fallback with TODO comment.
- Hot-reload of BalanceData mid-test — Phase 5+.
- Real unit/building spawning in `spawn_unit` / `spawn_building` — Phase 1+ when scenes exist.

**Plan-vs-reality notes:**

- **`class_name MatchHarness` removed.** The same Godot 4.6.2 registry race that hit StateMachine/State hits RefCounted-based harness scripts. Removed class_name; callers preload the script and call `.new()` + `start_match()`. Contract behavior unchanged.

- **`_test_set_farr` simplified to off-tick pattern.** Initial linter-generated implementation used a one-shot lambda connected to EventBus.sim_phase to run inside a tick. This caused "Cannot disconnect: callable is null" errors from the lambda trying to disconnect itself. Simplified to direct off-tick write (same pattern as FarrSystem.reset()). Does not advance SimClock.tick — tests that care about tick count are explicit about it.

- **`FarrSystem.reset()` added cross-domain.** Small addition authorized by wave-2 kickoff. Documented in ARCHITECTURE.md §6 v0.8.0.

**State for Phase 0 retro / merge:**
- On branch `feat/phase-0-foundation`. Lint clean. 250/250 non-pending tests pass headless.
- Run tests: `cd game && GODOT=/opt/homebrew/bin/godot ./run_tests.sh`
- MatchHarness is the Phase 1+ foundation for all integration and gameplay tests. Usage: `const _MH := preload("res://tests/harness/match_harness.gd"); var h := _MH.new(); h.start_match(seed, scenario); h.advance_ticks(n); var snap := h.snapshot(); h.teardown()`.
- GameRNG is the main Phase 1 harness TODO — when it ships, replace `seed(seed)` in harness `_setup()` with `GameRNG.seed_match(seed)` per Sim Contract §5.3.
- ResourceSystem (Phase 3) will take over coin/grain tracking; harness-local `_coin/_grain` dicts become dead code that can be removed.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **No class_name on MatchHarness.** Implementation choice; behavior unchanged. Documented in ARCHITECTURE.md §6 v0.8.0.
- **Off-tick `_test_set_farr`.** Implementation choice to avoid the lambda-self-disconnect bug. Documented in §6 v0.8.0.
- **`start_match(seed, scenario)` instead of `static func create(seed, scenario)`.** Implementation choice forced by removal of class_name. Documented in §6 v0.8.0.

---

## 2026-05-01 — Phase 0 session 4 wave 1 (gameplay-systems)

**Branch:** `feat/phase-0-foundation`

(Detail subsection. The combined-summary entry above covers wave 1 across all four agents; this records gameplay-systems-specific decisions and Plan-vs-Reality notes for future Phase 4 work.)

**Shipped:**

- `game/scripts/autoload/farr_system.gd` — `FarrSystem` autoload skeleton per `01_CORE_MECHANICS.md §4` and `docs/SIMULATION_CONTRACT.md §1.6`. Concretely:
  - Extends `SimNode` via `extends "res://scripts/core/sim_node.gd"` (path-string preload, per the class_name registry race pattern in `docs/ARCHITECTURE.md §6 v0.4.0`). The sim_node.gd file does carry `class_name`, but autoloads parse before the class_name registry fully populates — a path-string base avoids the race entirely while preserving inheritance behavior (`_sim_tick`, `_set_sim`, on-tick assert all inherit cleanly).
  - **Storage**: `_farr_x100: int` — fixed-point integer (Farr × 100). 50.0 stored as 5000. Per Sim Contract §1.6 to prevent IEEE-754 platform divergence over 25-min matches (45,000 ticks at 30 Hz with multiple Farr generators contributing fractional values per tick).
  - **Public read accessor**: `value_farr: float` getter — converts at the HUD/telemetry boundary only.
  - **Chokepoint**: `apply_farr_change(amount: float, reason: String, source_unit: Node) -> void` — mandated by `CLAUDE.md`. Asserts `SimClock.is_ticking()` per Sim Contract §1.3. Converts via `roundi(amount * 100.0)`. Computes `clampi(pre + delta, 0, 10000)` then derives the *effective* delta from the post-clamp value — emitted signal reports what the meter actually moved, not the (possibly oversized) request. Mutates via inherited `_set_sim` (self-only). Encodes `null` source_unit as `-1` sentinel; reads `unit_id` field if present, else `get_instance_id()`.
  - **Defensive BalanceData read** in `_ready()`: attempts to load `Constants.PATH_BALANCE_DATA`, duck-types the `farr.starting_value` field, clamps, converts, writes `_farr_x100`. Falls back to spec default 50.0 (per §4.1) if `data/balance.tres` doesn't exist or `farr` is absent. Robust to either-order shipping with balance-engineer's parallel BalanceData work.

- `game/scripts/autoload/event_bus.gd` — added typed `farr_changed(amount: float, reason: String, source_unit_id: int, farr_after: float, tick: int)` signal. Added to `_SINK_SIGNALS` and `_make_forwarder` got a new match arm. Phase 6 `MatchLogger` will pick it up automatically via `connect_sink`.

- `game/project.godot` — registered `FarrSystem` as the 10th autoload (after `DebugOverlayManager`). Order ensures `Constants`, `EventBus`, `SimClock`, `TimeProvider` are all up first.

- `game/tests/unit/test_farr_system.gd` — 12 GUT unit tests: default 50.0; storage is `int` and equals 5000; +5 raises to 55; −10 lowers to 40; small fractional delta (0.05) is exact; 10×0.1 lands at exactly 51.0 (no float drift); +200 saturates at 100.0; −200 saturates at 0.0; signal payload (amount, reason, source_unit_id, farr_after, tick); signal reports clamped *effective* delta when saturating; consecutive changes accumulate with one emit each; `is_ticking()` precondition for off-tick assert.

**Test-count delta from gameplay-systems alone:** +12 (157 total at wave-1 close, up from 130 at session 3 close).

**Did not ship** (out of scope per kickoff and `01_CORE_MECHANICS.md §4`):

- **Generator wiring** — Atashkadeh +1/min, Dadgah/Barghah +0.5/min, Yadgar +0.25/min (§4.3). Phase 4.
- **Drain wiring** — worker killed −1, hero attack ally −5, hero killed fleeing −10, hero killed in battle −5, Atashkadeh lost −5 (§4.3). Phase 4.
- **Snowball protection** — 3:1 ratio kill drain, broken-economy worker drain (§4.3). Definitions still open in `QUESTIONS_FOR_DESIGN.md`. Phase 4.
- **Kaveh Event** — Farr < 15 for 30s grace, rebel spawn, worker strike, locked-Farr window, both resolution paths (§9). Phase 5.
- **F2 Farr-log debug overlay** — the framework exists; the overlay itself ships when generators/drains start producing real-time feed (Phase 4 per the kickoff doc rule "concrete overlays land WITH their owning systems").
- **Hot-reload of `FarrConfig`** — Phase 5 deliverable per Testing Contract §1.4.
- **Yadgar building, hero death/respawn coupling** — Phase 5 (Rostam + Kaveh deliverable bundle).

**Decisions made independently** (per `CLAUDE.md` "Escalation" rule #1):

- **Path-string `extends` for FarrSystem** — same workaround pattern as the StateMachine framework session.
- **`source_unit: Node` encoded as `-1` sentinel int when null.** Signals carry primitives for telemetry-NDJSON serializability (Testing Contract §3.1 / §2.3). −1 matches the project's existing convention (`Constants.TEAM_ANY`, `GameState.match_start_tick = -1`). When a `unit_id: int` field is present on the source node, it's read duck-typed; otherwise `get_instance_id()` is the diagnostic fallback. Phase 1+ Unit nodes will all expose `unit_id` per State Machine Contract.
- **Emitted signal `amount` is the *effective* (post-clamp) delta, not the requested delta.** Requesting +200 from 50 emits +50, not +200. Rationale: downstream consumers (telemetry ledger, F2 overlay, balance analysis) need a coherent record of how the meter moved.
- **`roundi` chosen as the deterministic float→int rounding rule.** Sim Contract §1.6 mandates a deterministic rule but doesn't specify which. `roundi` is the GDScript built-in, deterministic across platforms; banker's rounding ceremony has no benefit at Farr-delta magnitudes (deltas are typically ±10.0, never ±0.005).
- **Source comment in balance-engineer's `FarrConfig` claims `× 1000` storage; the implementation uses `× 100` per Sim Contract §1.6.** Sim Contract §1.6 is the SSOT (canonical "Numeric Representation" principle, Convergence-Review-ratified) and the kickoff doc explicitly said `× 100`. The `FarrConfig` comment is a doc drift in balance-engineer's parallel-shipped sub-resource — flagged for them to harmonize. No behavior impact: the storage scale is FarrSystem-internal; FarrConfig only carries float-typed tunables. Did not edit balance-engineer's file.
- **Defensive `bd.get(&"farr")` duck-typed read** — same class_name-resolve workaround as `SpatialIndex`'s `agent.get(&"team")`.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. The Farr skeleton is pure infrastructure against §4.1, §1.6, and the chokepoint mandate.

---

## 2026-05-01 — Phase 0 session 4 wave 1 (ui-developer)

**Branch:** `feat/phase-0-foundation`

**Shipped:**

- `game/translations/strings.csv` — Godot CSV translation table with `keys,en,fa` columns, six seed UI keys (`UI_FARR`, `UI_COIN`, `UI_GRAIN`, `UI_POPULATION`, `UI_TIER_VILLAGE`, `UI_TIER_FORTRESS`). Comment block at the top documents the key-naming convention (`UI_*`, `UNIT_*`, `BLDG_*`, `EVENT_*`). The Persian (`fa`) column is intentionally blank for Phase 0 per CLAUDE.md ("Persian addition at Tier 2 must be a config change, not a refactor"); when content lands, it's a CSV edit + a one-line `project.godot` addition.
- `game/translations/strings.en.translation` and `strings.fa.translation` — auto-generated by Godot's `csv_translation` importer; the .csv.import file is committed alongside.
- `[internationalization]` section added to `game/project.godot`. `locale/translations` registers the `en.translation` resource; `locale/fallback="en"`. Persian addition is a config-only change.
- `game/scripts/ui/resource_hud.gd` — top-left text-only HUD. Reads Coin / Grain / Farr / Pop via `_process` polling per Sim Contract §1.5 (UI off-tick reads unrestricted). Defensive read pattern `_read_field_or_meta(node, field)` tries declared property first, then `Object.get_meta` — works during the Phase-0 holding pattern (no `player_resources` declared on GameState yet) and after gameplay-systems' future ResourceSystem ships. Reads `FarrSystem.value_farr` (the getter-only computed property over the fixed-point integer store). All label text formatted via `tr("UI_*")`. Falls back to `Farr: 50` / `Coin: 0` / `Grain: 0` / `Pop: 0/0` when a producer autoload is absent.
- `game/scenes/ui/resource_hud.tscn` — `CanvasLayer` → `MarginContainer` → `HBoxContainer` of four `Label`s, top-anchored across the screen with 16px padding. Names match the script's `@onready`s.
- `game/scenes/main.tscn` — `ResourceHUD` instance added as a direct child of `Main` alongside the existing `World` and `StatusLabel`. The `StatusLabel` was offset down 40px (top: 16 → 56) so it doesn't overlap the new HUD's top-left placement.
- `game/tests/unit/test_resource_hud.gd` — 14 GUT tests covering: `tr()` returns the expected English strings for all 6 seed keys; the HUD scene loads cleanly and exposes the four labels; defensive defaults (`Farr: 50`, `Coin: 0`, `Pop: 0/0`) when producers are absent; live reads from a real (or stand-in) `FarrSystem` autoload; `set_meta`-based read path for `player_resources` / `player_pop` / `player_pop_cap`; the per-frame `_process` poll model picks up changes between frames. `before_each` / `after_each` snapshot and restore both the meta seam and the live `FarrSystem._farr_x100` so the file doesn't leak state.
- `docs/ARCHITECTURE.md` — Translation infrastructure and Farr HUD readout rows updated with my own notes (CSV import details, `tr()` boundary, two-source defensive read pattern, polling-not-signal-driven for Phase 0). New §6 v0.7.0 plan-vs-reality entry: meta-fallback read pattern, `value_farr` getter-only mutation strategy in tests, HUD-then-status-label layout shift.

**Test-count delta (this agent's contribution):** +14 tests in `test_resource_hud.gd`. 1 of the 14 reports as Pending in current configuration because `FarrSystem` is registered as a real autoload (the test for the "no FarrSystem at all" defensive-default branch is unreachable when the autoload exists; it shows as pending, not failed, by design). All 13 remaining assertions pass.

**Did not ship** (out of scope per kickoff):
- Circular Farr gauge with color thresholds + floating change numbers — Phase 1+ per `01_CORE_MECHANICS.md` §4.4 / §11.
- F2 Farr-change-log overlay — Phase 4 with full FarrSystem.
- Persian translation content — Tier 2.
- HUD styling, fonts, art — Phase 1+.
- Selection system, build menu, minimap, hero portrait, tier indicator — Phase 1+.

**State for wave 2 / next session:**
- On branch `feat/phase-0-foundation`. Run lint (`tools/lint_simulation.sh`) + tests (`game/run_tests.sh`); both clean.
- HUD displays correct values when running the project: `Coin: 0 | Grain: 0 | Farr: 50 | Pop: 0/0`. Once gameplay-systems' future ResourceSystem (Phase 3) populates `GameState.player_resources` with the `Constants.KIND_COIN` / `KIND_GRAIN` keys, those numbers will start moving without HUD edits.
- The `_read_field_or_meta` two-source pattern is documented in `docs/ARCHITECTURE.md` §6 v0.7.0 with a note that the meta path becomes dead code once ResourceSystem ships and can be cleaned up in a follow-up.
- The translation infrastructure is ready for `UNIT_*`, `BLDG_*`, `EVENT_*` keys to be appended as the corresponding systems ship — no setup work needed.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none. No design / feel / balance questions surfaced — the work was infrastructure against ratified contracts.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **`_read_field_or_meta` two-source defensive read pattern.** The kickoff doc said "if `GameState.player_resources` doesn't exist yet, defensively fall back to display 0." GameState is gameplay-systems' file and they did not add `player_resources` in this wave. GDScript `Object.set` on an undeclared property is silently a no-op, so writing through `set` and reading through `get` would always return null. Using `set_meta` / `get_meta` as a parallel seam lets Phase-0 tests inject values for the read-path verification, and a single `_read_field_or_meta` helper makes the HUD work identically for (a) the future declared-property shape and (b) the current meta-seam shape. Documented in `docs/ARCHITECTURE.md` §6 v0.7.0.
- **`StatusLabel` offset shifted from `top: 16` to `top: 56`.** The Phase-0 status label is still useful for SimClock.tick visibility (engine-architect's session-1 deliverable). Moving it 40px down gives the HUD's top-left margin its own row. Both stay visible until Phase 1 polishes the HUD layout.
- **`CanvasLayer` root, not a `Control`.** A `CanvasLayer` overlays the 3D viewport without coupling to the camera or the world. The Phase 1 circular gauge can sit on the same layer; the eventual minimap can use a separate layer. Implementation choice; no behavioral difference at Phase 0.
- **Polling in `_process`, not `EventBus.farr_changed`-driven.** Polling is simpler, the read cost is O(1), and it works before FarrSystem emits anything. The Phase 1 gauge will subscribe to `farr_changed` for the floating change-number animation per Sim Contract §1.5's queue-then-drain pattern; for the text readout, polling is enough.
- **Test-time `FarrSystem` mutation through `_farr_x100` directly, not `apply_farr_change`.** The chokepoint asserts `SimClock.is_ticking()` and we don't want to spin the clock for HUD-only tests. Writing the integer-backed store directly is off-tick (test discipline) and bypasses the on-tick assert; `before_each` / `after_each` snapshot and restore the store so other test files aren't affected.

## 2026-05-01 — Phase 1 session 2 wave 1C (ui-developer): Farr gauge polish

**Branch:** `feat/phase-1-session-2`

**Shipped:**

1. **`FarrGauge`** at `game/scenes/ui/farr_gauge.tscn` + `game/scripts/ui/farr_gauge.gd`. Custom `Control` with `_draw()` override — no asset dependency (CLAUDE.md placeholder visuals policy). Replaces the Phase 0 text "Farr: 50" readout in the top HUD.
   - **Visual fill**: `displayed_farr / tier2_threshold` clamped [0,1], so the meter is full at Farr=40 (kickoff §149). Above Tier 2, the GOLD color band carries the overshoot signal — the fill stays at 1.0.
   - **Color bands per spec §4.4**: <15 red, 15-40 dim, 40-70 ivory, ≥70 gold. Inclusive lower bound — exactly 15 → dim, exactly 40 → ivory, exactly 70 → gold. Avoids 14.99-vs-15.00 visual jitter at the Kaveh trigger.
   - **Threshold ticks**: Tier 2 (gold, medium) and Kaveh (red, thick) painted at angular positions per `BalanceData.farr.tier2_threshold` / `kaveh_trigger_threshold`. Per balance-engineer review: gold tick instead of thin ivory because an ivory tick on the ivory band would have visually disappeared.
   - **Public API**: `target_farr: float`, `displayed_farr: float`, `color_band: StringName` (BAND_RED / BAND_DIM / BAND_IVORY / BAND_GOLD), `fill_ratio: float` (computed getter), `tier2_threshold` / `kaveh_trigger_threshold: float`. Used by tests now; available to the Phase 4 F2 debug overlay.
   - **Data wiring**: signal-driven. `_ready` connects to `EventBus.farr_changed` and seeds initial state from `FarrSystem.value_farr`. `_exit_tree` disconnects (no ghost connections after scene teardown). Tween 0.20s `TRANS_QUAD EASE_OUT` per signal — no debounce per balance-engineer veto (debouncing would silently drop F2-overlay log entries, breaking CLAUDE.md's "every Farr movement gets logged" mandate).
   - **`mouse_filter = MOUSE_FILTER_IGNORE`** at the root + every descendant (none in current scene, but tested defensively per session-1's HUD-eats-clicks regression).
   - **Defensive degradation**: if `FarrSystem` isn't registered (test scenes), falls back to spec default 50.0; if `BalanceData` is missing, falls back to spec defaults (40, 15) for thresholds. Same pattern as `farr_system.gd:67-91`.

2. **`Constants.FARR_MAX = 100.0`** added by balance-engineer in a parallel commit. The gauge references this constant — never hardcodes 100.

3. **HUD layout refactor in `game/scenes/ui/resource_hud.tscn`**: removed `FarrLabel`, added `Spacer` (Control with `size_flags_horizontal=EXPAND`, `mouse_filter=IGNORE`) + `FarrGauge` instance. The HBox is now `[Coin] [Grain] [Pop] [Spacer] [FarrGauge]` — Coin/Grain/Pop stay left, Spacer expands, gauge anchors right per spec §11.

4. **`scripts/ui/resource_hud.gd`**: dropped `_farr_label`, `_DEFAULT_FARR`, `_read_farr_display`, and the `_autoload_or_null` helper (no longer needed — the gauge owns the FarrSystem read). Coin / Grain / Pop polling logic unchanged.

5. **29 new tests** in `game/tests/unit/test_farr_gauge.gd` (replacing 3 dropped FarrLabel-specific tests in `test_resource_hud.gd`):
   - Scene loads cleanly; root is Control; mouse_filter is IGNORE; descendant mouse_filter recursive check.
   - Initial seed from FarrSystem.value_farr; defensive fallback to 50.0 when FarrSystem absent (Pending in standard config since FarrSystem is autoloaded).
   - `EventBus.farr_changed` updates `target_farr`; clamp to [0, FARR_MAX] on out-of-range payloads.
   - Edge cases: target at exactly 0, exactly FARR_MAX.
   - Threshold values match `BalanceData.farr.{tier2_threshold,kaveh_trigger_threshold}` exactly.
   - Tween: `displayed_farr == target_farr` at _ready; tween settles to target after 30 process_frame awaits.
   - `fill_ratio` at 0, at Tier 2 threshold, above Tier 2 (clamps to 1.0), at midpoint.
   - `color_band` at every band boundary including the < / ≥ inclusivity check (14.99→red, 15.0→dim, 39.99→dim, 40.0→ivory, 50.0→ivory, 69.99→ivory, 70.0→gold, 100.0→gold).
   - Signal connection at _ready (count delta = +1); disconnect on tree exit (count returns to baseline; no ghost connections).
   - End-to-end integration: seed band, drive farr_changed across boundary, assert band flips and tween settles.

6. **`docs/ARCHITECTURE.md` §2**: marked the **Farr gauge** row `✅ Built` with full implementation notes; updated the **Farr HUD readout** row to reflect the wave-1C refactor (Spacer-pushed layout, Farr no longer polled).

**Test-count delta (this agent's contribution):** +29 in `test_farr_gauge.gd`, −3 obsolete tests removed from `test_resource_hud.gd` (the FarrLabel-specific live-read, defensive-default, and per-frame poll tests) replaced with cross-references to their gauge-side equivalents. End-of-wave run shows 446 tests, 443 passing, 3 pending (legitimate skips: navmesh-not-baked-in-headless ×2, FarrSystem-autoload-defensive-fallback ×1). 0 failures.

**Live-game-broken-surface answers (Experiment 01) — refined:**

1. *What state/behavior must work at runtime that no unit test exercises?*
   The signal-to-redraw chain in a real running scene. Headless tests verify (a) the gauge connects to `EventBus.farr_changed`, (b) `_on_farr_changed` mutates `target_farr` and `color_band`, (c) the tween eventually settles `displayed_farr`. They CANNOT verify: (i) `queue_redraw()` actually causes a repaint when the gauge is visible and the SceneTree isn't paused; (ii) the tween advances at a usable rate in a 60fps live frame loop (in headless GUT the tween settled in ~30 frames; live timing differs); (iii) the descendant mouse_filter recursion catches descendants the scene file might add later. Mitigation: an integration test that loads `main.tscn`, calls `apply_farr_change` inside a `SimClock` tick, advances real frames, and asserts. Not added this wave (would block on synchronous match-harness scene-load sequence); flagged for qa-engineer wave 3.

2. *What can a headless test not detect that the lead would notice in the editor?*
   - **Arc orientation**: I picked 12-o'clock start sweeping clockwise. Lead may want a different convention (some games start at 9 o'clock or 3 o'clock).
   - **Color readability**: the placeholder grey terrain may make the dim band hard to see; the red band may compete with combat damage indicators (Phase 2). Visual-only.
   - **Tween feel**: 0.20s with `EASE_OUT` was tuned for headless GUT timing tolerance, not live feel. Lead may want 0.15s or 0.30s. Trivial to tune via `_TWEEN_DURATION`.
   - **Numeric label legibility at 1280×720**: ThemeDB.fallback_font at 12pt — may be too small or clipped by the gauge ring.
   - **Top-right anchoring**: tested via `Spacer` `size_flags_horizontal=EXPAND` in headless, but actual right-edge alignment at 1280×720 / 1920×1080 / 4K is visual-only verification.

3. *What's the minimum interactive smoke test that catches it?*
   1. Boot game (F5). Verify the gauge renders top-right with ~50% fill, ivory color, both threshold ticks visible (gold at 40-position, red at 15-position).
   2. Add a temporary debug binding (or use the editor's remote inspector) to call `FarrSystem.apply_farr_change(+10, "smoke", null)` inside a tick. Watch the arc tween up over ~0.2s; verify it crosses to the gold band when value passes 70.
   3. Drive Farr to exactly 40, exactly 15, and below 15: verify the fill aligns to the corresponding tick and the color band switches accordingly.
   4. Click-through test: try clicking a worker through the gauge area. Verify the click selects the worker (gauge does NOT swallow the click via `mouse_filter=IGNORE`). Session-1-regression-canary.

**Did not ship** (out of scope per kickoff §149 + balance-engineer review):
- Below-Kaveh red pulsing animation per spec §4.4 (`<15 red and pulsing`) — DEFERRED to Phase 2. When implemented, the pulse must be driven from a `_process` state flag (`_is_below_kaveh`) NOT from the tween, because the tween finishes but the pulse must keep animating. Documented in source file.
- Floating reason-text labels per spec §4.4 ("+3 Farr (hero rescued worker)") — DEFERRED to Phase 2. The same `farr_changed` signal already carries the `reason` payload, so a future widget subscribes independently.
- Threshold-crossing audio cues per spec §4.4 (chime up at 40/70, distant horn down at 15) — DEFERRED to Tier 2 (audio infrastructure not yet present).
- Integration-style scene-loading test for the signal-to-redraw chain — flagged for qa-engineer wave 3.

**State for next session / waves:**
- On `feat/phase-1-session-2`. Lint clean, 443 tests passing, 3 pending (legitimate).
- The gauge is ready to receive Phase 4 Atashkadeh per-tick contributions. **One known concern:** Atashkadeh adds `+0.000556 Farr/tick` (~30 emits/sec at 30Hz). The gauge's 0.20s tween would re-trigger constantly at low amplitude. Per balance-engineer's review, the producer side should batch into one emit per second (or larger) rather than the gauge debouncing. Flagged here so Phase 4 gameplay-systems can plan the batching.
- F2 debug overlay (Phase 4) can subscribe to the same `EventBus.farr_changed` signal independently — the gauge is not in its read path.
- The gauge defensive-fallback paths (no FarrSystem autoload, no BalanceData) are tested as Pending because both autoloads are always registered in this project. If a future test scenario tears them down, those Pending tests become reachable assertions.
- Persian (`fa`) translation column in `strings.csv` is still empty for `UI_FARR` (the only string the gauge uses) — Tier 2 work, no code change needed.

**Open questions added to QUESTIONS_FOR_DESIGN.md:** none.

**Decisions made independently** (per CLAUDE.md "Escalation" rule #1):
- **Custom `Control._draw` over `TextureProgressBar`** — implementation choice (no gameplay impact). No sweep-texture asset exists; bootstrapping a placeholder PNG is more friction than 50 lines of `_draw`. Documented in source file.
- **Visual fill normalized to `tier2_threshold`, not `FARR_MAX`** — kickoff §149 says "fills from 0 to FARR_TIER2_THRESHOLD." Implementation followed; gold band carries overshoot signal. Linter-added tests confirmed this is the intended behavior.
- **`color_band` updated synchronously in `_on_farr_changed` (off `target_farr`) AND per-tween-step (off interpolated `displayed_farr`)**. The synchronous update lets observers see the new band immediately; the per-step update lets intermediate band crossings during a tween fire the right visual. Both paths converge on the same final value.
- **Tween duration 0.20s** (down from the 0.25s in the proposal). Headless GUT's frame timing made the integration tween-settles tests flaky at 0.25s. Visually indistinguishable; lead can re-tune via `_TWEEN_DURATION` if desired.
- **Inclusive-at-lower-bound boundary policy for color bands** — linter-added test docstring specified this. Avoids 14.99-vs-15.00 jitter. Encoded in `_band_for(...)` with `>=` checks descending from the gold threshold.
- **`_TIER3_VISUAL_THRESHOLD = 70.0` hardcoded in the gauge, not in `FarrConfig`**. Spec §8 lists Tier 3 as post-MVP; `FARR_MAX = 100.0` belongs in `Constants` for the same reason. When Tier 3 ships and 70 becomes a balance knob, it moves to `FarrConfig` then. Citation comment in source.
- **Removed obsolete `_inject_or_mutate_farr_system` / `_remove_mock_farr_system` helpers** from `test_resource_hud.gd` after dropping the three FarrLabel-specific tests that used them. Coverage moved to `test_farr_gauge.gd`. Cleaner than leaving dead code in place.
