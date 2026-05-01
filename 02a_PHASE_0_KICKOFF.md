---
title: Phase 0 Kickoff — First Implementation Session Recipe
type: plan
status: living
version: 1.0.0
owner: team
summary: Session-1 recipe for the first Phase 0 implementation session. Read order, scoped first-slice tasks, dependency order within Phase 0, TDD reminders.
audience: all
read_when: starting-phase-0-implementation
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md]
ssot_for:
  - first-implementation-session reading order
  - first-slice scoping (which Phase 0 tasks the first session attacks)
  - Phase 0 internal dependency order
  - implementation-mode session ceremony (start, work, end)
references: [02_IMPLEMENTATION_PLAN.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md]
tags: [phase-0, kickoff, implementation, tdd, recipe]
created: 2026-05-01
last_updated: 2026-05-01
---

# Phase 0 Kickoff — First Implementation Session Recipe

> **Mode:** implementation. Per `docs/STUDIO_PROCESS.md` §12, the studio process (syncs, OST patterns, Convergence Review) is dormant during implementation. Specialists work independently in their owned files using TDD discipline. The architecture document is the bridge that carries design into implementation; this kickoff is the bridge into *the first session*.

## 0. Why this doc exists

Phase 0 has 20+ tasks across 5 agents. Without a kickoff recipe, a fresh session has to reverse-engineer "what should I do first?" from the implementation plan's Phase 0 table. This doc cuts that to a 5-minute orient → start coding flow.

The doc is **session-1-specific.** Subsequent sessions read `BUILD_LOG.md` for state and pick up from there.

## 1. Session-1 reading order (≈10 minutes)

In order, on session start:

1. **`MANIFESTO.md`** — principles. Constants behind every other rule.
2. **`CLAUDE.md`** — project instructions, file ownership, escalation rules.
3. **`docs/ARCHITECTURE.md`** — orientation layer. Where things live. Subsystem build state (everything is `📋 Planned` at session 1).
4. **`docs/STUDIO_PROCESS.md` §12** — operating modes + TDD discipline. Critical: read the TDD section.
5. **`02_IMPLEMENTATION_PLAN.md` Phase 0 section** — the full task list.
6. **This doc (`02a_PHASE_0_KICKOFF.md`)** — for the scoped slice and dependency order below.

## 2. The Session-1 scoped slice

Phase 0 has too many tasks to ship in one session. Session-1 attacks **the load-bearing autoloads + the test harness** so that subsequent sessions can land code with passing tests. Specifically:

### Session-1 deliverables (in dependency order)

1. **Initialize Godot 4 project** in `game/` — `project.godot` exists, project opens on macOS Apple Silicon. Engine version pinned per `DECISIONS.md` (2026-05-01); record the exact patch version in both `project.godot` and `docs/ARCHITECTURE.md` §2 build-state. Owner: engine-architect.

2. **`SimClock` autoload skeleton** — per `docs/SIMULATION_CONTRACT.md` §1.2. 30Hz tick driver with `tick_started`/`tick_ended` emission via `EventBus`. No phase coordinators yet — those come session 2+. The `is_ticking()` helper must work. Owner: engine-architect.

3. **`EventBus` autoload (typed signals declaration)** — per `docs/SIMULATION_CONTRACT.md` §7. Single file with `tick_started`, `tick_ended`, `sim_phase` signals declared with typed args. Telemetry sink wiring is session 2+; for session 1, just the signal declarations. Owner: engine-architect.

4. **`TimeProvider` autoload** — per `docs/SIMULATION_CONTRACT.md` §1. Wrapper around `Time` singleton with mock-injection support for tests. Owner: engine-architect.

5. **`SimNode` base class** — per `docs/SIMULATION_CONTRACT.md` §1.3. The `_set_sim` assertion is the load-bearing piece. Owner: engine-architect.

6. **GUT framework installed** — per `docs/TESTING_CONTRACT.md` and `docs/SIMULATION_CONTRACT.md` §6. Hello-world test passes from the editor and from `godot --headless`. Owner: qa-engineer.

7. **Pre-commit hook running tests + lint** — per `docs/SIMULATION_CONTRACT.md` §1.4 and §6. `tools/lint_simulation.sh` with the 5 ripgrep patterns. Pre-commit hook calls lint + GUT runner. Owner: qa-engineer.

8. **First failing test landed** — a test for `SimClock.is_ticking()` that exercises the tick lifecycle. Should pass after the SimClock skeleton lands. Owner: qa-engineer.

9. **Update `docs/ARCHITECTURE.md` §2** — move SimClock, EventBus, TimeProvider, SimNode, GUT framework, pre-commit hook from `📋 Planned` to `✅ Built`. Add the Godot exact version. **This is part of every session** per the TDD discipline (§12.3 step 5). Owner: lands with whoever ships the subsystem.

10. **First entry in `BUILD_LOG.md`** — what shipped, what didn't, what session 2 should pick up. Owner: lead.

### What's deliberately NOT in session 1

- `SpatialIndex`, `GameRNG`, `MovementComponent`, `Constants` autoload, `BalanceData.tres`, `GameState`, `IPathScheduler`, `MockPathScheduler`, `MatchHarness`, `FarrSystem` skeleton, `DebugOverlayManager`, camera controller, terrain plane, translation infrastructure, Farr HUD readout — all session 2+. Phase 0 fits in 2-4 sessions; we don't try to land all of it at once.

The rule of thumb: session 1 ships the **simulation backbone** (SimClock + EventBus + SimNode + tests). Session 2 builds outward.

## 3. Phase 0 internal dependency order

Within Phase 0, some tasks must precede others:

```
project.godot init
       │
       ├── SimClock ── EventBus (declarations) ── TimeProvider ── SimNode
       │       │                                                    │
       │       └─────── GUT install ── pre-commit hook              │
       │                       │                                    │
       │                       └── first failing test ──────────────┤
       │                                                            │
       ├── Constants autoload ── BalanceData.tres                   │
       │                                                            │
       ├── GameState autoload                                       │
       │                                                            │
       ├── SpatialIndex (depends on SimClock for tick hook)         │
       │                                                            │
       ├── IPathScheduler (interface) ── MockPathScheduler          │
       │                                                            │
       ├── StateMachine + State + UnitState (extends SimNode) ──────┘
       │
       ├── Camera controller (independent)
       │
       ├── Terrain plane + map size constant (independent)
       │
       ├── DebugOverlayManager (independent)
       │
       └── Translation infrastructure (independent)
```

**Three independent branches** (camera, terrain, translation, debug overlay) can run in parallel with the simulation backbone. The dependency order is mostly within the simulation chain.

Suggested session breakdown:

- **Session 1:** simulation backbone start (project init, SimClock, EventBus declarations, TimeProvider, SimNode, GUT, pre-commit, first test)
- **Session 2:** simulation backbone finish (Constants, GameState, SpatialIndex, IPathScheduler + MockPathScheduler, StateMachine framework, more tests) + parallel start on independent tasks (Camera, terrain plane)
- **Session 3:** complete remaining Phase 0 tasks (BalanceData.tres, FarrSystem skeleton, DebugOverlayManager, translation, HUD readouts, MatchHarness)
- **Session 4 (if needed):** polish, integration tests, retro

## 4. TDD discipline reminders for implementation mode

From `docs/STUDIO_PROCESS.md` §12.3 — repeated here so they're top-of-mind for the very first session.

1. **Tests first.** Write a failing test that captures the expected behavior before writing the code that makes it pass.
2. **Read the contract before writing code.** For SimClock: `docs/SIMULATION_CONTRACT.md` §1.2 is canonical. Every line of code should trace to a contract clause.
3. **Update `docs/ARCHITECTURE.md` §2** when you move a subsystem from `📋 Planned` → `🟡 In progress` → `✅ Built`. Plan-vs-reality delta entries (§6) when the implementation diverges from the spec — Truth-Seeking.
4. **Pre-commit hook is your safety net.** It runs lint + GUT before every commit. Don't bypass on a failure — investigate.
5. **If the contract is wrong, escalate, don't silently invent.** A spec gap surfaces as either:
   - Append to `QUESTIONS_FOR_DESIGN.md` (design/feel/balance)
   - Convene a small sync (cross-system architectural gap)
   Per `docs/STUDIO_PROCESS.md` §12.4.

## 5. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + the §1 reading order).
2. Verify branch state (`git status` — should be on a `feat/<short>` branch, not `main`).
3. Check `BUILD_LOG.md` for prior session state if not session 1.
4. Pick a task from §2 (or from the next-session backlog in `BUILD_LOG.md`).

**During session:**
1. Read the relevant contract section.
2. Write a failing test.
3. Implement.
4. Refactor.
5. Update `docs/ARCHITECTURE.md` §2 (and §6 if delta).
6. Commit on the feature branch.

**End of session:**
1. All tests pass; pre-commit hook clean.
2. `docs/ARCHITECTURE.md` accurately reflects what was built.
3. Append entry to `BUILD_LOG.md` (what shipped, what didn't, state for next session).
4. Push to remote; PR if the slice is complete enough to merge.

## 6. After Phase 0

When `docs/ARCHITECTURE.md` §2 shows everything in the Phase 0 build-state table at `✅ Built`, Phase 0 is complete. Run a brief retro per `docs/STUDIO_PROCESS.md` §10 — append a Phase 0 retro entry. Then start Phase 1 against the existing implementation plan.

If Phase 0 reveals an architectural gap that requires a contract revision, mode-switch back to design (convene a sync) before continuing implementation. The contracts are agreements; reality changing them requires the agreement to be re-ratified.

---

*This doc is session-1-specific. After session 1, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state) + the implementation plan (next phase). This kickoff doc may be updated for Phase 1 kickoff or removed if it's no longer load-bearing.*
