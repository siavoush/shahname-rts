---
title: Phase 1 Kickoff — First Implementation Session Recipe
type: plan
status: living
version: 1.0.0
owner: team
summary: Session-1 recipe for the first Phase 1 implementation session. Read order, scoped first-slice tasks, dependency order, TDD reminders. Phase 1 is "click on a unit, watch it move" — the first visually-meaningful gameplay milestone.
audience: all
read_when: starting-phase-1-implementation
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md]
ssot_for:
  - first-implementation-session reading order for Phase 1
  - first-slice scoping (which Phase 1 tasks the first session attacks)
  - Phase 1 internal dependency order
  - implementation-mode session ceremony (start, work, end)
references: [02_IMPLEMENTATION_PLAN.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, BUILD_LOG.md]
tags: [phase-1, kickoff, units, selection, movement, recipe]
created: 2026-05-01
last_updated: 2026-05-01
---

# Phase 1 Kickoff — First Implementation Session Recipe

> **Mode:** implementation. Per `docs/STUDIO_PROCESS.md` §12, the studio process (syncs, OST patterns, Convergence Review) is dormant during implementation. Specialists work independently in their owned files using TDD discipline. The architecture document is the bridge that carries design into implementation; this kickoff is the bridge into *the first Phase 1 session*.

## 0. Why this doc exists

Phase 1 is where Phase 0's foundations become visibly alive. Phase 0 shipped a terrain plane and a camera; Phase 1 ships **selectable units that move where you click** — the first gameplay milestone that feels like an RTS. Without a kickoff recipe, a fresh session has to reverse-engineer "what should I do first?" from the implementation plan's Phase 1 table. This doc cuts that to a 5-minute orient → start coding flow.

The doc is **session-1-specific.** Subsequent Phase 1 sessions read `BUILD_LOG.md` for state and pick up from there.

## 1. Session-1 reading order (≈10 minutes)

1. **`MANIFESTO.md`** — principles. Constants behind every other rule.
2. **`CLAUDE.md`** — project instructions, file ownership, escalation rules.
3. **`docs/ARCHITECTURE.md`** — orientation layer. After Phase 0 merge, see §2 build state — most foundation rows are now `✅ Built`. Phase 1 rows still `📋 Planned` are what you're picking up.
4. **`docs/STUDIO_PROCESS.md`** §12 — operating modes + TDD discipline. Critical for the discipline.
5. **`02_IMPLEMENTATION_PLAN.md` Phase 1 section** — the full task list.
6. **`docs/STATE_MACHINE_CONTRACT.md`** (1.0.0) — your unit-state framework. Every concrete unit state extends `UnitState` per §2.2.
7. **`docs/SIMULATION_CONTRACT.md`** §1 (the rule), §1.3 (SimNode), §3 (SpatialIndex), §4 (IPathScheduler) — the engine layer your units sit on.
8. **`docs/RESOURCE_NODE_CONTRACT.md`** — even though resources don't ship until Phase 3, units need to know that gathering interactions are ahead. Skim §1.1 and §4.
9. **`BUILD_LOG.md`** — what shipped in Phase 0; especially session 4 wave 1+2 entries (BalanceData, MockPathScheduler, FarrSystem, MatchHarness).
10. **This doc (`02b_PHASE_1_KICKOFF.md`)** — for the scoped slice and dependency order below.

## 2. The Session-1 scoped slice

Phase 1's full task list (per `02_IMPLEMENTATION_PLAN.md` §3 Phase 1) is too much for one session. Session-1 attacks **the unit core** — one type of unit that exists, can be selected, can be commanded to move, with the state machine actually transitioning.

### Session-1 deliverables (in dependency order)

1. **`Unit` scene template** — `CharacterBody3D` root with composed components: `HealthComponent`, `MovementComponent`, `SpatialAgentComponent`, `SelectableComponent`. One scene file at `game/scenes/units/unit.tscn` that's the parent of all concrete unit types. **Owner: engine-architect + gameplay-systems.**

2. **`HealthComponent`** — extends `SimNode`. Tracks `hp: int` (or fixed-point if needed for accumulating regen later). On HP zero, emits `EventBus.unit_health_zero(unit_id)` (signal already declared in Phase 0). Per `docs/STATE_MACHINE_CONTRACT.md` §4, this is the trigger for death-preempt. **Owner: gameplay-systems.**

3. **`MovementComponent`** — extends `SimNode`. Wraps `IPathScheduler` integration per `docs/SIMULATION_CONTRACT.md` §4. Holds `_request_id`, `_waypoints`, `_current_target`. `request_repath(target)` method routes through `PathSchedulerService`. `_sim_tick(dt)` advances the unit along waypoints if a path is ready. **Owner: ai-engineer + engine-architect.**

4. **`SelectableComponent`** — extends `SimNode`. Tracks `is_selected: bool`. Renders a selection ring (placeholder MeshInstance3D — colored circle on the ground). Listens to `EventBus.selection_changed` (declare this signal in Phase 1 if not already done). **Owner: ui-developer.**

5. **`Kargar` (worker) — first concrete unit type** — `extends Unit`. Sets unit-specific stats from `BalanceData.units[&"kargar"]` (already populated in Phase 0). Just a placeholder colored cube/cylinder for now (small worker silhouette). **Owner: gameplay-systems.**

6. **`UnitState_Idle` and `UnitState_Moving`** — concrete `UnitState` subclasses per `docs/STATE_MACHINE_CONTRACT.md`. **Owner: ai-engineer.**
   - **Idle**: pulses scale slightly so you can see it's "alive." Listens for command queue dispatch via `transition_to_next()` per §3.4.
   - **Moving**: takes a target `Vector3` from the command's payload. Calls `MovementComponent.request_repath(target)` in `enter()`. In `_sim_tick`, polls `MovementComponent.path_state`; when waypoints ready, advances along them; on arrival, transitions to Idle.

7. **Click-to-select (single click)** — left-click on a `SelectableComponent` selects it; click on empty terrain deselects. `SelectionManager` autoload (or single class) tracks current selection. Emits `EventBus.selection_changed`. **Owner: ui-developer.** Use `SpatialIndex.query_radius` from a screen-to-world raycast for hit-testing.

8. **Right-click-to-move** — right-click on terrain enqueues a Move command on the selected unit's command queue. Command is consumed by the StateMachine, which dispatches to `Moving` state. **Owner: ui-developer + ai-engineer (Command shape lives in StateMachine framework; UI builds the Command and pushes to queue).**

9. **Spawn 5 Kargar at game start** — placeholder spawn logic in `main.gd` or a small `MatchSetup` script. Workers placed at known positions on the terrain so you can immediately click them. **Owner: gameplay-systems.**

10. **Tests** — for each component, each state, the selection logic, and the move-command flow. `MatchHarness` (Phase 0) is your fixture. **Owner: qa-engineer (writes integration tests after components ship).**

### Definition of Done for Session 1

A future-you (or any agent) opens the project on macOS Apple Silicon and:

1. Launches the game (F5 in editor).
2. Sees 5 small colored cubes (workers) on the terrain plane.
3. Left-clicks one → selection ring appears under that unit. (Camera + selection working together.)
4. Right-clicks somewhere on the terrain → selected worker moves there in a straight line (MockPathScheduler returns straight-line paths in headless tests; production NavigationAgent does proper navmesh routing).
5. Worker arrives → idle animation (scale pulse) resumes.
6. Click empty terrain → deselect.
7. Tests pass headless. Lint clean. Pre-commit gate green.
8. `docs/ARCHITECTURE.md` §2 reflects the new build state.

If all of those work, **Phase 1 session 1 is done.** Session 2 onward adds box-select, control groups, multiple unit types, formation movement, attack-move.

### What's deliberately NOT in session 1

- Box/drag selection (Phase 1 session 2)
- Control groups (Ctrl+1-9) (Phase 1 session 2)
- Double-click-select-all-of-type (Phase 1 session 2)
- Attack-move (Phase 2 — combat phase)
- Combat itself (Phase 2)
- Multiple unit types (Piyade, Kamandar, Savar, Asb-savar, Rostam) — session 2 onward
- Formation movement / GroupMoveController (session 2)
- Farr circular gauge polish (session 2 — text readout from Phase 0 is enough for now)
- Selected-unit panel (bottom-left detail panel) — session 2

The rule of thumb: session 1 ships **the smallest E2E flow that produces "click → move."** Everything else builds on this.

## 3. Phase 1 internal dependency order

```
Phase 0 foundation (✅ already merged)
  │
  ├── Unit scene + components (HealthComponent, MovementComponent,
  │   SpatialAgentComponent (already exists from P0), SelectableComponent)
  │       │
  │       ├── Kargar (concrete unit type, extends Unit)
  │       │       │
  │       │       └── Spawn 5 in main.gd
  │       │
  │       ├── UnitState_Idle (extends UnitState framework)
  │       └── UnitState_Moving (extends UnitState framework, uses MovementComponent)
  │
  ├── SelectionManager (uses SpatialIndex for hit-testing)
  │       │
  │       └── Click-to-select wires to SelectableComponent on hit unit
  │
  └── Right-click-to-move (builds Command, pushes to selected unit's queue)
          │
          └── StateMachine dispatches Moving state, which uses MovementComponent
              which uses PathSchedulerService (MockPathScheduler in tests,
              NavigationAgentPathScheduler in production — wait, the latter
              doesn't exist yet, so production also uses MockPathScheduler-
              like straight-line for now; or the engine-architect ships
              NavigationAgentPathScheduler as part of session 1)
```

**Dependency note:** `NavigationAgentPathScheduler` (the production path scheduler that wraps `NavigationServer3D`) does **not yet exist**. Phase 0 shipped the `IPathScheduler` interface and `MockPathScheduler` only. Production code that wants real pathfinding needs the production scheduler. Session 1 has two options:
- **(a)** Ship `NavigationAgentPathScheduler` as part of session 1 (engine-architect's deliverable). Production path = real NavigationServer3D routing.
- **(b)** Use `MockPathScheduler` in production too for now (straight-line everywhere). Defer real navmesh routing to session 2 or Phase 2.

I lean **(a)** — the terrain is flat with no obstacles, so even basic NavigationAgent3D works. Routing around buildings comes Phase 3 with NavigationObstacle3D. Spec to engine-architect for session 1.

### Suggested session breakdown for Phase 1

- **Session 1:** Unit core (Unit + components + Kargar + Idle/Moving + click-select + right-click-to-move + production path scheduler). 5 visible workers; click-and-move works.
- **Session 2:** Box-select, control groups, double-click-select-type, GroupMoveController (formation movement), Farr gauge polish, selected-unit panel.
- **Session 3 (if needed):** Multiple unit types (Piyade, Kamandar, Savar, Asb-savar — all just colored shapes with different stats reading from BalanceData). Multi-unit group commands.

## 4. TDD discipline reminders for implementation mode

Same as Phase 0 (per `docs/STUDIO_PROCESS.md` §12.3). Worth re-stating the points that bit us in Phase 0:

1. **Read the contract section before writing code.** State Machine Contract is your spec for unit states. Sim Contract is your spec for SimNode discipline. Don't guess.
2. **Write failing tests first.** Use `MatchHarness` (Phase 0 deliverable) for integration tests. Spawn a unit in the harness, advance ticks, assert end state.
3. **Update `docs/ARCHITECTURE.md` §2** as each subsystem moves through 📋 → 🟡 → ✅. Add §6 plan-vs-reality entries for any divergences.
4. **Pre-commit gate is your safety net.** It runs lint + GUT before every commit.
5. **If the contract is wrong, escalate, don't silently invent.** A spec gap surfaces as either:
   - Append to `QUESTIONS_FOR_DESIGN.md` (design/feel/balance question)
   - Convene a brief sync (cross-system architectural gap)
   Per `docs/STUDIO_PROCESS.md` §12.4. **Phase 0 retro added a §9 rule about visual smoke tests** — apply it here. A scene-level test that loads a unit scene, renders one frame, and verifies the unit is on screen catches bugs that pure unit tests miss.

## 5. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + the §1 reading order).
2. Verify branch state (`git status` — should be on `feat/phase-1-units`, not `main`).
3. Check `BUILD_LOG.md` for Phase 0 final state.
4. Pick a task from §2 (or from the next-session backlog if you're not session 1).

**During session:**
1. Read the relevant contract section.
2. Write a failing test.
3. Implement.
4. Refactor.
5. Update `docs/ARCHITECTURE.md` §2.
6. Commit on the feature branch.

**End of session:**
1. All tests pass; pre-commit hook clean.
2. `docs/ARCHITECTURE.md` accurately reflects what was built.
3. Append entry to `BUILD_LOG.md` (what shipped, what didn't, state for next session).
4. Push to remote; PR if the slice is complete enough to merge.

## 6. After Phase 1

When `docs/ARCHITECTURE.md` §2 shows the Phase 1 rows at `✅ Built` and the milestone test in §2 passes (5 workers visible, selectable, commandable), Phase 1 is complete. Run a brief retro per `docs/STUDIO_PROCESS.md` §10. Then start Phase 2 (combat — units that fight when commanded to attack each other).

If Phase 1 reveals an architectural gap that requires a contract revision, mode-switch back to design (convene a sync) before continuing implementation.

---

*This doc is session-1-specific. After session 1, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state) + the implementation plan (next phase). This kickoff doc may be updated for Phase 2 kickoff or removed if it's no longer load-bearing.*
