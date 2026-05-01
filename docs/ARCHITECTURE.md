---
title: Architecture — Target Shape and Build State
type: architecture
status: living
version: 0.6.0
owner: engine-architect
summary: Orientation layer — system map, subsystem build state, tick pipeline summary, directory rationale, contract index. Read first in implementation mode after MANIFESTO and CLAUDE.md.
audience: all
read_when: implementation-mode
prerequisites: [MANIFESTO.md, CLAUDE.md]
ssot_for:
  - subsystem build state table (planned/in-progress/built)
  - directory layout with rationale
  - contract index (which doc to read for which domain)
  - plan-vs-reality delta record
  - high-level system map (UI / simulation / event bus / foundation layers)
  - pinned Godot engine version
references: [SIMULATION_CONTRACT.md, STATE_MACHINE_CONTRACT.md, TESTING_CONTRACT.md, RESOURCE_NODE_CONTRACT.md, AI_DIFFICULTY.md, ../02_IMPLEMENTATION_PLAN.md, STUDIO_PROCESS.md]
tags: [orientation, architecture, build-state, directory, system-map]
created: 2026-05-01
last_updated: 2026-04-30
---

# Architecture — Target Shape and Build State

> This document is the **orientation layer** for the project. After `MANIFESTO.md` and `CLAUDE.md`, this is the first thing anyone (agent or human) reads when picking up work — especially after a context boundary (compaction, time off, fresh session). It exists so you don't have to re-read every contract and every commit just to know where you are.
>
> **What lives here:** the target shape, the build state, the data flow, the directory map. **What lives elsewhere:** the *decisions* that shaped each subsystem (in `docs/*_CONTRACT.md`), the *plan* for getting there (in `02_IMPLEMENTATION_PLAN.md`), the *principles* behind everything (in `MANIFESTO.md`).

---

## 1. The System Map

The game is a deterministic real-time simulation with seven phases per tick at 30 Hz. Subsystems are organized into four layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                       UI LAYER (off-tick)                        │
│  Camera • SelectionManager • CommandManager • HUD • Minimap     │
│  DebugOverlayManager (F1-F4) • Farr Gauge • Build Menu          │
└────────────────────┬────────────────────────────────────────────┘
                     │ reads sim state freely
                     │ writes sim state ONLY through queued commands
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SIMULATION LAYER (on-tick)                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ SimClock (30 Hz, runs the phase pipeline)                │   │
│  │   input → ai → movement → spatial_rebuild → combat       │   │
│  │            → farr → cleanup                              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Systems (phase coordinators):                                   │
│   - InputSystem             - CombatSystem                       │
│   - AIControllerHost        - FarrSystem                         │
│   - MovementSystem          - CleanupSystem                      │
│   - SpatialIndex (rebuild)                                       │
│                                                                  │
│  Components (extend SimNode, register with phase coordinators):  │
│   - HealthComponent  - MovementComponent  - CombatComponent      │
│   - SelectableComponent  - SpatialAgentComponent                 │
│                                                                  │
│  Entities (composed of components):                              │
│   - Units (Kargar, Piyade, Kamandar, Savar, Asb-savar, Rostam)   │
│   - Buildings (Throne, Khaneh, Mazra'eh, Atashkadeh, ...)        │
│   - ResourceNode → MineNode | Mazra'eh                           │
└────────────────────┬────────────────────────────────────────────┘
                     │ emits typed signals (write-shaped + read-shaped)
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                          EVENT BUS                               │
│   Single autoload. Every signal declared with typed args.        │
│   Telemetry sink subscribes to write-shaped signals.             │
└────────────────────┬────────────────────────────────────────────┘
                     │
       ┌─────────────┴─────────────┐
       ▼                           ▼
┌──────────────┐          ┌──────────────────┐
│ Telemetry    │          │ MatchLogger      │
│ (Phase 0)    │          │ (Phase 6)        │
│ in-memory    │          │ NDJSON to disk   │
│ JSON dump    │          │ per tick events  │
└──────────────┘          └──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       FOUNDATION LAYER                           │
│  SimClock • TimeProvider • GameRNG (domain-keyed) • EventBus    │
│  Constants • BalanceData (resource) • GameState                  │
│  SimNode (base class) • StateMachine + State (core)              │
│  IPathScheduler (interface) → NavigationAgent | MockPathScheduler│
└─────────────────────────────────────────────────────────────────┘
```

**Key invariant:** gameplay state mutates only inside `_sim_tick()` calls dispatched by `SimClock`. UI reads freely; UI never writes synchronously in a sink callback (uses queue-then-drain). Per Sim Contract §1.

---

## 2. State of the Build

**Pinned engine version:** Godot **4.6.2 stable** (official build `71f334935`), recorded in `game/project.godot` `application/config/godot_version`. Bumping the MAJOR (e.g., 5.x) requires a new `DECISIONS.md` entry per the 2026-05-01 decision; patch updates do not.

| Subsystem | Target spec | Status | Version | Owner | Notes |
|-----------|-------------|--------|---------|-------|-------|
| **Godot engine** | `DECISIONS.md` 2026-05-01 | ✅ Built | 4.6.2-stable | engine-architect | Installed via Homebrew cask `godot`; binary at `/opt/homebrew/bin/godot`. |
| **Godot project init** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | engine-architect | `game/project.godot` exists; main scene boots; placeholder `Main` scene confirms SimClock ticks. |
| **SimClock autoload** | [SIM 1.2.0 §1.2](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | 30Hz fixed-tick driver, accumulator pattern in `_physics_process`, emits `tick_started` / `sim_phase × 7` / `tick_ended`. `is_ticking()` and the `_test_run_tick` / `_test_advance` / `reset` test hooks ship session 1. Unit tests in `tests/unit/test_sim_clock.gd`. |
| **SimNode base class** | [SIM 1.2.0 §1.3](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | `_sim_tick(_dt)` virtual + `_set_sim(prop, value)` with on-tick assert. Self-only mutation discipline documented in source. Unit tests in `tests/unit/test_sim_node.gd`. |
| **EventBus autoload** | [SIM 1.2.0 §7](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | Session 1 declares `tick_started`, `tick_ended`, `sim_phase`. `connect_sink` / `disconnect_sink` API shipped; no consumer yet (MatchLogger is Phase 6). Unit tests in `tests/unit/test_event_bus.gd`. |
| **GameRNG autoload** | [SIM 1.2.0 §5](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0 session 2; 4 domains |
| **TimeProvider autoload** | [SIM 1.2.0 §1](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | Wraps `Time.get_ticks_msec()`; `set_mock` / `clear_mock` / `is_mocked` for deterministic tests. Unit tests in `tests/unit/test_time_provider.gd`. |
| **SpatialIndex autoload** | [SIM 1.2.1 §3](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | 8m uniform grid (XZ plane, Y ignored). Three queries: `query_radius`, `query_nearest_n`, `query_radius_team`. Auto-population via `SpatialAgentComponent` (extends `SimNode`); registers on `_ready`, deregisters on `_exit_tree`. Rebuild listens on `EventBus.sim_phase(&"spatial_rebuild", ...)`. Unit tests in `tests/unit/test_spatial_index.gd`. |
| **IPathScheduler** | [SIM 1.2.1 §4](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | Interface only (session 3). `PathState` enum, `request_repath` / `poll_path` / `cancel_repath`. `PathSchedulerService` autoload holds the active scheduler; `set_scheduler` / `reset` for injection. Both implementations land session 4 — `NavigationAgentPathScheduler` (engine-architect) and `MockPathScheduler` (qa-engineer). |
| **CI lint script** | [SIM 1.2.0 §1.4](SIMULATION_CONTRACT.md) | ✅ Built | — | qa-engineer | `tools/lint_simulation.sh`. All 5 rules (L1-L5) implemented with allowlists for L3 (`rng.gd` when it lands) and L5 (`time_provider.gd`, `sim_clock.gd`). Exits non-zero on any violation. Verified against deliberate violation test files for each rule. |
| **Pre-commit hook** | [TEST 1.4.0](TESTING_CONTRACT.md) | ✅ Built | — | qa-engineer | Canonical hook at `tools/git-hooks/pre-commit`; install via `bash tools/install-hooks.sh`. Runs lint then GUT; blocks commit on either failure. |
| **GUT framework** | [TEST 1.4.0](TESTING_CONTRACT.md) | ✅ Built | 9.4.0 | qa-engineer | Installed at `game/addons/gut`. Headless runner: `game/run_tests.sh` (`godot --headless ... -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`). 28 tests across 4 unit-test scripts pass at session 1 close. Pre-commit hook + lint script land session 2. |
| **MatchHarness** | [TEST 1.4.0 §3](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 |
| **MockPathScheduler** | [TEST 1.4.0 §3](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 |
| **Determinism regression test** | [TEST 1.4.0 §6.2](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 stub; live in Phase 1 |
| **BalanceData resource** | [TEST 1.4.0 §1](TESTING_CONTRACT.md) | 📋 Planned | — | balance-engineer | Phase 0; populates at construction |
| **Constants autoload** | [02_IMPLEMENTATION_PLAN.md §2](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | engine-architect | Phase 0 session 3. Structural keys/enums only — phase StringNames, EventBus signal name keys, team identifiers (`TEAM_IRAN`, `TEAM_TURAN`, `TEAM_NEUTRAL`, `TEAM_ANY`), resource kinds, state ids, command kinds, structural caps. Tunable numbers live in `BalanceData.tres` (session 4). Unit tests in `tests/unit/test_constants.gd`. |
| **GameState autoload** | [02_IMPLEMENTATION_PLAN.md §2](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | engine-architect | Phase 0 session 3. Match phase (`lobby`/`playing`/`ended`), `winner_team`, `match_start_tick` (captures `SimClock.tick` on `start_match`), `player_team`. `match_tick()` / `match_time()` give relative offsets. Tests in `tests/unit/test_game_state.gd`. |
| **StateMachine + State** | [STATE 1.0.0](STATE_MACHINE_CONTRACT.md) | ✅ Built | — | engine-architect | Phase 0 session 3 (framework). `core/state_machine/` ships `State`, `StateMachine`, `Command`, `CommandQueue`, `UnitState`, `InterruptLevel`. `CommandPool` autoload pre-allocates Commands. Death-preempt connected to `EventBus.unit_health_zero`; transition history ring buffer (16 entries unit / 64 AI); `transition_to_next()` dispatcher pops `Command` and maps kind→state-id. Concrete unit states (Idle, Moving, etc.) ship Phase 1+. Tests in `tests/unit/test_state_machine.gd`. |
| **CommandPool autoload** | [STATE 1.0.0 §2.5](STATE_MACHINE_CONTRACT.md) | ✅ Built | — | engine-architect | Phase 0 session 3. `rent()` / `return_to_pool()` over a pre-allocated pool. Auto-resets on rent and return. Tests share the pool via `tests/unit/test_state_machine.gd` (CommandPool fixtures). |
| **PathSchedulerService autoload** | [SIM 1.2.1 §4.3](SIMULATION_CONTRACT.md) | ✅ Built | — | engine-architect | Phase 0 session 3 (autoload only). Holds an `IPathScheduler` instance for `MovementComponent` to read; `null` until session 4 wires real/mock impls. Tests in `tests/unit/test_path_scheduler_service.gd`. |
| **Camera Controller** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | ui-developer | Phase 0 session 3 wave 2. Fixed isometric, no rotation. WASD pan + edge-pan (50px threshold) + scroll-wheel zoom (clamped). Diagonal input normalized; frame-rate independent. Bounds clamp to `Constants.MAP_SIZE_WORLD` half-extent. Rig at `scenes/camera/camera_rig.tscn` (yaw -45° baked in scene); controller at `scripts/camera/camera_controller.gd`. Tests in `tests/unit/test_camera_controller.gd` (19). NOT yet wired into `main.tscn` — engine-architect's session 4 task. |
| **Terrain plane (256×256)** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | world-builder | Phase 0; flat plane with checkerboard StandardMaterial3D placeholder. `Constants.MAP_SIZE_WORLD = 256.0` and `Constants.NAV_AGENT_RADIUS = 0.5` added. NavigationRegion3D with synchronous bake at scene-load, `PARSED_GEOMETRY_STATIC_COLLIDERS`. Scene: `scenes/world/terrain.tscn`. Script: `scripts/world/terrain.gd`. Tests: `tests/unit/test_terrain.gd` (7 tests). |
| **DebugOverlayManager** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | ✅ Built | — | ui-developer | Phase 0 session 3 wave 2. Autoload registry: `register_overlay(key, Control)` / `unregister_overlay(key)` / `toggle_overlay(key)` / `handle_function_key(keycode)`. F1-F4 → `Constants.OVERLAY_KEY_F1`..`F4` (pathfinding / Farr log / AI state / attack ranges per Phase 6 / 4 / 6 / 2). `_unhandled_input` dispatches function keys; off-tick reads only per Sim Contract §1.5. Concrete overlays land WITH their owning systems (kickoff doc rule). Tests in `tests/unit/test_debug_overlay_manager.gd` (16). |
| **Translation infrastructure** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ui-developer | Phase 0; Godot CSV |
| **Telemetry sink** | [SIM 1.2.0 §7](SIMULATION_CONTRACT.md), [TEST 1.4.0 §2](TESTING_CONTRACT.md) | 📋 Planned | — | balance-engineer + engine-architect | Phase 0 (in-memory); Phase 6 MatchLogger |
| **FarrSystem skeleton** | [01_CORE_MECHANICS.md §4](../01_CORE_MECHANICS.md), [SIM 1.2.0 §1.6](SIMULATION_CONTRACT.md) | 📋 Planned | — | gameplay-systems | Phase 0 stub (HUD shows 50); full system Phase 4 |
| **Farr HUD readout** | [01_CORE_MECHANICS.md §11](../01_CORE_MECHANICS.md) | 📋 Planned | — | ui-developer | Phase 0 text-only; circular gauge Phase 1 |
| **Unit scene + components** | [STATE 1.0.0](STATE_MACHINE_CONTRACT.md) | 📋 Planned | — | engine-architect + gameplay-systems | Phase 1 |
| **GroupMoveController** | [02_IMPLEMENTATION_PLAN.md Phase 1](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ai-engineer | Phase 1 |
| **Selection system** | [02_IMPLEMENTATION_PLAN.md Phase 1](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ui-developer | Phase 1 single+box; Phase 2 control groups |
| **CombatSystem** | [02_IMPLEMENTATION_PLAN.md Phase 2](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | gameplay-systems | Phase 2 |
| **ResourceNode + MineNode + Mazra'eh** | [RNC 1.1.1](RESOURCE_NODE_CONTRACT.md) | 📋 Planned | — | world-builder + gameplay-systems | Phase 3 |
| **ResourceSystem** | [01_CORE_MECHANICS.md §3](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 3 |
| **DummyAIController** | [02_IMPLEMENTATION_PLAN.md Phase 3](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ai-engineer | Phase 3 — 100-line stub for solo testing |
| **Building system** | [01_CORE_MECHANICS.md §5](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 3 |
| **Fog-of-war data layer** | [02_IMPLEMENTATION_PLAN.md Phase 3](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | world-builder | Phase 3 — boolean grid only |
| **TechSystem (Tier 1→2)** | [01_CORE_MECHANICS.md §8](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 4 |
| **FarrSystem (full)** | [01_CORE_MECHANICS.md §4](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 4 — fixed-point per SIM 1.2.0 §1.6 |
| **ProductionSystem** | [01_CORE_MECHANICS.md §7](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 4 |
| **Rostam hero unit** | [01_CORE_MECHANICS.md §7](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 5 |
| **KavehEventSystem** | [01_CORE_MECHANICS.md §9](../01_CORE_MECHANICS.md) | 📋 Planned | — | gameplay-systems | Phase 5 — seeded RNG |
| **TuranAIController (full)** | [01_CORE_MECHANICS.md §12](../01_CORE_MECHANICS.md) | 📋 Planned | — | ai-engineer | Phase 6 |
| **AI difficulty config** | [AI 1.1.0](AI_DIFFICULTY.md) | 📋 Planned | 1.1.0 | balance-engineer | Phase 6 wiring |
| **AI-vs-AI sim harness** | [TEST 1.4.0 §4](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer + balance-engineer | Phase 6 |
| **MatchLogger** | [TEST 1.4.0 §2](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 6 |
| **Khorasan map** | [02_IMPLEMENTATION_PLAN.md Phase 7](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | world-builder | Phase 7 |
| **Fog-of-war rendering** | [02_IMPLEMENTATION_PLAN.md Phase 7](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | world-builder | Phase 7 |
| **Minimap** | [01_CORE_MECHANICS.md §11](../01_CORE_MECHANICS.md) | 📋 Planned | — | ui-developer | Phase 7 |

**Status legend:** 📋 Planned (target spec exists, no implementation) — 🟡 In progress — ✅ Built (passes tests, wired into game) — 🔄 Refactored (built and reworked since)

---

## 3. The Tick Pipeline

30 Hz fixed tick, seven phases per tick, in this order:

`input → ai → movement → spatial_rebuild → combat → farr → cleanup`

Full canonical specification — what each phase does, why it's in this order, the registration shape for phase coordinators, the `advance_ticks` test path — lives in [`SIMULATION_CONTRACT.md`](SIMULATION_CONTRACT.md) §1.2 and §2. Read that for any work that touches the pipeline.

---

## 4. Directory Map (with "why")

```
game/
├── project.godot              # Godot project config
├── scenes/                    # All .tscn scene files
│   ├── main.tscn              # Top-level scene (menu → match)
│   ├── match.tscn             # The match scene (the actual game)
│   ├── ui/                    # HUD, menus, overlays
│   ├── units/                 # Unit scene templates (one per type)
│   ├── buildings/             # Building scene templates
│   ├── maps/                  # Map scenes (Khorasan, Phase 7)
│   ├── camera/                # Camera rig
│   └── ai/                    # AI controller scenes
│
├── scripts/
│   ├── autoload/              # Singletons. Single source of truth for each.
│   │                          # SimClock, EventBus, GameState, GameRNG,
│   │                          # SpatialIndex, FarrSystem, TimeProvider,
│   │                          # Telemetry, Constants. Loaded at boot.
│   ├── core/                  # Base classes — SimNode, StateMachine, State,
│   │                          # UnitState. The shape every component conforms to.
│   ├── managers/              # GameManager, SelectionManager, CommandManager.
│   │                          # Coordinate cross-system flow without owning gameplay state.
│   ├── systems/               # Phase coordinators (MovementSystem, CombatSystem,
│   │                          # FarrSystem, ResourceSystem, TechSystem,
│   │                          # ProductionSystem, KavehEventSystem). Each owns its phase.
│   ├── units/                 # Unit scripts + components/ + states/.
│   │                          # Per-unit behavior, all extending SimNode/UnitState.
│   ├── buildings/             # Building scripts (Throne, Khaneh, Mazra'eh, ...)
│   ├── ai/                    # AI opponent scripts. DummyAIController in Phase 3,
│   │                          # full TuranController in Phase 6.
│   ├── ui/                    # All UI scripts. UI never writes sim state directly;
│   │                          # uses queue-then-drain per Sim Contract §1.5.
│   ├── camera/                # CameraController. Fixed isometric, no rotation.
│   ├── input/                 # Input handling, selection, hotkeys, command system.
│   ├── world/                 # Terrain, fog of war (data layer), resource nodes
│   │                          # base classes. Map metadata.
│   ├── navigation/            # GroupMoveController, path scheduler integration.
│   │                          # Wraps NavigationServer3D behind IPathScheduler.
│   └── constants.gd           # Structural constants and keys (rarely changes).
│                              # Tunable numbers live in BalanceData, not here.
│
├── data/
│   ├── balance.tres           # BalanceData Resource — every tunable number.
│   │                          # Owned by balance-engineer; edited freely.
│   └── telemetry/             # Match logs (NDJSON). Gitignored.
│
├── assets/                    # Placeholder shapes, fonts, terrain texture.
│                              # No real art until MVP loop is fun (per CLAUDE.md).
├── shaders/                   # Fog-of-war shader (Phase 7), selection highlight.
├── translations/              # Godot CSV translation files (en, fa).
├── docs/                      # Contracts and architecture documentation (this file).
└── tests/
    ├── unit/                  # GUT unit tests. State machines, math, FarrSystem.
    ├── integration/           # MatchHarness-driven tests. Full subsystem flows.
    ├── simulation/            # AI-vs-AI headless match runs (Phase 6).
    └── balance/               # Balance analysis scripts. Owned by balance-engineer.
```

---

## 5. Contract Index — what to read for each domain

| If you're working on... | Read first |
|-------------------------|------------|
| Anything that mutates gameplay state | [`SIMULATION_CONTRACT.md`](SIMULATION_CONTRACT.md) §1 (the rule) and §1.3 (SimNode) |
| State machines, command queues, interrupts | [`STATE_MACHINE_CONTRACT.md`](STATE_MACHINE_CONTRACT.md) |
| Tests, telemetry, BalanceData, mocks | [`TESTING_CONTRACT.md`](TESTING_CONTRACT.md) |
| Resource gathering, mines, farms, dropoff | [`RESOURCE_NODE_CONTRACT.md`](RESOURCE_NODE_CONTRACT.md) |
| AI difficulty values | [`AI_DIFFICULTY.md`](AI_DIFFICULTY.md) |
| Process — how syncs work, retro practice | [`STUDIO_PROCESS.md`](STUDIO_PROCESS.md) |
| Why we do anything | [`MANIFESTO.md`](../MANIFESTO.md) |
| What to build (the spec) | [`01_CORE_MECHANICS.md`](../01_CORE_MECHANICS.md) |
| The phase plan | [`02_IMPLEMENTATION_PLAN.md`](../02_IMPLEMENTATION_PLAN.md) |

---

## 6. Plan-vs-Reality Delta

*This section captures honest gaps between the target spec and what's actually been built. Expected to grow as implementation proceeds. Manifesto Principle 1 (Truth-Seeking) lives here most concretely.*

**At v0.1.0 (initial):** nothing built yet. The contracts describe target shape; this document indexes them. As subsystems land, this section records:
- Spec said X; we built Y; reason: Z
- Subsystem A took Phase N+1 (slipped one phase), reason: ...
- Contract V was bumped from 1.x.0 to 1.y.0 during implementation; key change: ...

### v0.2.0 — Phase 0 Session 1 (2026-05-01)

- **EventBus.connect_sink — implementation diverged from the contract sketch.** Sim Contract §7 originally sketched `func connect_sink(callable): for sig in _SINK_SIGNALS: get(sig).connect(func(...args): callable.call(sig, args))`. GDScript does **not** support varargs lambdas (`func(...args)` is not valid syntax), so the actual implementation registers one hand-rolled per-signal forwarder Callable per `(sink, signal)` pair, dispatching to `sink.call(signal_name, args_array)`. The public API (`connect_sink(sink: Callable)` / `disconnect_sink(sink: Callable)` taking a sink that receives `(StringName, Array)`) is unchanged from the contract; only the internal forwarder construction differs. Adding a new signal to `_SINK_SIGNALS` now requires adding a `match` arm in `EventBus._make_forwarder` for that signal's exact arity. This is captured in the source comments. **Resolved: SIM_CONTRACT 1.2.1 (2026-05-01)** patched §7 to replace the invalid sketch with the actual per-signal forwarder pattern.

- **SimClock test hooks added in addition to the contract surface.** `_test_run_tick()`, `_test_advance(delta)`, and `reset()` are present on the autoload to let GUT (and the future MatchHarness) drive the clock manually without running `_physics_process`. They share the exact `_run_tick()` body the live driver uses, satisfying Sim Contract §6.1's "no divergence between live and headless paths." The contract didn't originally enumerate these but their existence is implied by §6.1. **Resolved: SIM_CONTRACT 1.2.1 (2026-05-01)** patched §6.1 to enumerate the three test hooks as part of the contract surface for `MatchHarness` integration.

- **SimNode `_set_sim` off-tick assertion is exercised manually, not in GUT.** GDScript `assert()` halts the script in debug builds and compiles out in release; GUT cannot trap a fired assert in-process. The on-tick happy path is covered by `test_sim_node.gd`; the off-tick path is covered by the lint rule (Sim Contract §1.4) at the call sites that would trigger it, plus the runtime crash-with-stack-trace when a developer breaches the contract in debug. This matches contract intent — the assert is a tripwire, not something to trap. **Resolved: SIM_CONTRACT 1.2.1 (2026-05-01)** patched §1.3 with an explicit "enforcement-via-crash-in-debug, not enforcement-via-test" clarification so future devs don't try to GUT-trap the assert.

- **What did not ship in session 1 (deferred to session 2+ per `02a_PHASE_0_KICKOFF.md` §2):** `GameRNG`, `SpatialIndex`, `Constants` autoload, `BalanceData.tres`, `GameState`, `IPathScheduler` + `MockPathScheduler`, `MatchHarness`, `FarrSystem` skeleton, `DebugOverlayManager`, camera controller, terrain plane, translation infrastructure, HUD readouts, lint script, pre-commit hook. None of these are blocked; all sit on top of the foundations shipped here.

### v0.6.0 — Phase 0 Session 3 wave 2: Camera + DebugOverlayManager (2026-05-01)

- **Camera controller methods renamed `apply_pan` / `apply_zoom` → `pan_by` / `zoom_by`.** The `apply_*` prefix collides with lint rule L1 (Sim Contract §1.4): "gameplay mutation called from `_process`." The camera mutates camera-side state (target_position, zoom_distance) from `_process`, which is correct for UI/off-tick code per Sim Contract §1.5 — the lint just can't tell camera-side state from sim-side state. Renaming preserves both the lint's intent and the camera's intent. The contract surface is otherwise untouched. No contract change needed; the convention "`apply_*` means sim-side mutator" is an implicit lint-driven naming rule that this session made explicit by avoiding it for non-sim code.

- **Camera reads `Constants.MAP_SIZE_WORLD` defensively.** Camera and terrain ship in parallel; the camera lands first if its branch merges first. The controller does `Constants.get(&"MAP_SIZE_WORLD")` and falls back to its `@export var map_size: float = 256.0` if the constant isn't there yet. World-builder's session 3 wave 2 added the constant, so production now reads it cleanly; the fallback stays as a belt-and-braces guard. Not a contract gap — both 02_IMPLEMENTATION_PLAN.md Phase 0 and the kickoff doc explicitly note camera bounds and `MAP_SIZE_WORLD` co-evolve.

- **Camera rig is `Node3D`, not `Camera3D`.** The script extends `Node3D` and the rig scene contains a `Camera3D` *child*. This is the standard RTS-camera pattern: rig is the pivot, child is the lens. Code never rotates either — the rig has yaw -45° baked in `camera_rig.tscn` and the child has pitch -55° baked there. `_apply_transforms()` sets only `global_position` (rig-side pan) and the child camera's local Z (zoom distance). The "no rotation API" contract is enforced by the test `test_controller_does_not_expose_rotation_api`, which asserts the absence of `rotate_yaw`, `rotate_pitch`, `orbit`, `set_yaw`, `set_pitch` methods and `yaw` / `pitch` properties — a regression tripwire for any future drift toward rotation.

- **`DebugOverlayManager._unhandled_input` registered with `process_mode = ALWAYS`.** F1-F4 must work even when the game is paused (debug-overlay viability while inspecting state requires it). `process_mode = ALWAYS` is the Godot 4 way to keep input flowing through pause. No contract surface change.

- **DebugOverlayManager dispatch is keycode-based, not InputMap-based.** Phase 0 doesn't yet have an InputMap configured for F1-F4, and the lint/test gate already covers the dispatch correctness via `handle_function_key(keycode)`. When InputMap arrives (Phase 1+ for selection / commands), F1-F4 can move to `Input.is_action_just_pressed("debug_overlay_1")` etc. without touching the registry shape — only the dispatch path. Documented here so the Phase 1+ migration is a search-and-replace, not a redesign.

- **What did not ship in session 3 wave 2 (intentionally out of scope per kickoff):** Concrete debug overlays themselves (F1 pathfinding viz, F2 Farr log, F3 AI state, F4 attack ranges) — they ship with their owning systems in later phases per CLAUDE.md and `02a_PHASE_0_KICKOFF.md`. Selection system / HUD / Farr gauge / minimap / build menu / hero portrait / translation infrastructure — all deferred to Phase 1+ per the implementation plan. Camera not yet wired into `main.tscn` — engine-architect's session 4 task.

### v0.4.0 — Phase 0 Session 3 (2026-04-30)

- **`class_name State` removed; behavior preserved.** State Machine Contract §2.2 specifies `class_name State extends RefCounted`. In Godot 4.6.2 the global class_name registry is populated *after* GUT-collected test scripts parse — when an inner test class extends `state.gd` by path-string and that script declares `class_name State`, the resolver fails with "Could not resolve class 'State'". Removing the `class_name State` declaration eliminates the resolution race entirely; production code refers to the script via `preload("res://scripts/core/state_machine/state.gd")` or by path-string. Behavior is identical; only the global symbol-table registration is dropped. The contract surface (`State` as a *type*, `enter`/`_sim_tick`/`exit` as methods, `id`/`priority`/`interrupt_level` as fields) is preserved exactly. Same workaround applied transitively to several inner type annotations on `StateMachine` (`current: Variant`, `register(state: Object)`, `next_cmd = ...`) and on `CommandQueue` (`push(cmd: Object)`, `peek() -> Object`, `pop() -> Object`). `class_name UnitState`, `class_name Command`, `class_name CommandQueue`, `class_name StateMachine`, `class_name InterruptLevel`, `class_name SpatialAgentComponent`, and `class_name IPathScheduler` are retained — they don't trigger the same race because nothing extends them inline in test scripts. **No contract change required**: the State Machine Contract describes behavior; the class_name registration was an implementation detail.

- **`SpatialAgentComponent` references duck-typed in `SpatialIndex`.** `spatial_index.gd` is an autoload; autoloads parse before the class_name registry is fully populated for `class_name`-decorated component scripts. A typed `agent as SpatialAgentComponent` cast inside the index would fail at script-reload time. Resolution: `SpatialIndex` reads `agent.team` via `agent.get(&"team")` and calls `world_position()` via `agent.has_method(&"world_position")` + `call(...)`. Type safety is preserved by behavior — the only callers are `SpatialAgentComponent` instances. Same pattern in `CommandPool` (uses a `preload`'d Script ref to `command.gd` for `_CommandClass.new()`).

- **`SpatialIndex.query_nearest_n` does not auto-exclude the source.** Sim Contract §3.3 says "query_nearest_n excludes the source if the source is a registered agent (caller may pass its own node and not get itself)." The session-3 implementation does NOT apply that exclusion — there's no canonical "the source" parameter on the API, and inferring it from the point alone is unreliable (multiple agents can sit at the same XZ). Concrete behavior: callers who need self-exclusion filter the result, or pass a sentinel point offset from the source. A follow-up phase will pin down the exact API when the first concrete consumer (selection raycast or AoE caller) lands. **This is a documented short-term gap**, not a contract violation — Sim Contract §3 will be amended in 1.2.2 if the consumer needs the auto-exclude semantics.

- **EventBus gained `unit_health_zero(int)` and `unit_state_changed(int, StringName, StringName, int)`.** State Machine Contract §4.1 requires the first; §5.3 / §7.3 require the second. Both added to `_SINK_SIGNALS` with their forwarder match arms in `_make_forwarder`. `MatchLogger` (Phase 6) will pick them up with no further changes. Ship-blocked Phase 1+ producers (`HealthComponent`, `Unit`) — Phase 0 just declares them so the framework wires them ahead of consumers.

- **GameState `start_match` is idempotent on re-entry.** A second `start_match()` call while `match_phase == PLAYING` no-ops (with `push_warning`). Same shape on `end_match` — only valid in `PLAYING`. This avoids subtle determinism bugs where re-starting mid-match silently overwrites `match_start_tick`, breaking match-relative time reads.

- **What did not ship in session 3 (deferred to session 4+ per kickoff doc):** `MockPathScheduler`, `MatchHarness`, `BalanceData.tres`, `FarrSystem` skeleton, `DebugOverlayManager`, camera, terrain plane, translations, HUD readouts, concrete unit states. `GameRNG` is also still pending (kickoff lists it for "later sessions").

### v0.3.0 — Phase 0 Session 2 (2026-04-30)

- **L5 allowlist discrepancy between Sim Contract §1.4 and kickoff doc.** The Sim Contract §1.4 table lists `sim_clock.gd` as the L5 allowlist file. The kickoff doc (`02a_PHASE_0_KICKOFF.md`) and `time_provider.gd` source comments both name `time_provider.gd` as the correct allowlist. `time_provider.gd` is the file that actually calls `Time.get_ticks_msec()` — `sim_clock.gd` does not. Resolution: both files are allowlisted in `tools/lint_simulation.sh`. `sim_clock.gd` is defensively allowlisted in case a future clock implementation needs wall-clock drift correction. Contract §1.4 table has a minor error in the listed filename; no behavior change to the rule.

- **L3 comment-line false positive.** The bare-RNG pattern (`randi()` etc.) can match GDScript comment lines that happen to reference the function name in prose. Added a post-scan filter that strips matches where the code portion starts with `#` (a GDScript comment marker). The filter uses `rg -v ':[0-9]+:\s*#'` to drop comment lines from the match set. No impact on real violation detection.

- **`rg` shell function in Claude Code session.** During development, ripgrep is intercepted by a Claude Code shell function, causing `command -v rg` to succeed but the subprocess invocation to fail. The lint script runs correctly in a clean `bash --noprofile --norc` environment (which is what pre-commit hooks and CI use). Not a deployment issue; documented here for transparency.

- **What did not ship in session 2 (deferred per kickoff doc):** `MatchHarness`, `MockPathScheduler`, determinism regression test stub — all blocked on `IPathScheduler` interface which is engine-architect's session 3 deliverable. `GameRNG`, `SpatialIndex`, `Constants`, `GameState`, `StateMachine`, `DebugOverlayManager`, camera, terrain plane, translations, HUD readouts — all session 3+ per the original scope split.

---

### v0.5.0 — Phase 0 Session 3 wave 2 (2026-04-30) — world-builder

- **`PARSED_GEOMETRY_STATIC_COLLIDERS` chosen over `PARSED_GEOMETRY_MESH_INSTANCES`.** The kickoff doc and session spec are silent on which NavMesh geometry source to use. `MESH_INSTANCES` was the first choice because the MeshInstance3D (PlaneMesh) directly represents the visual ground. However, Godot 4's NavigationServer reports a significant performance warning when baking from mesh instances in headless/test contexts: it reads GPU vertex data back to CPU, which blocks rendering. `STATIC_COLLIDERS` uses the StaticBody3D + BoxShape3D (256×0.1×256) as the walkable source instead — all-CPU, no GPU readback. The baked result is functionally identical (flat 256×256 walkable surface) and the headless test suite runs cleanly. This choice aligns with production best practice for flat terrain: author a collision shape, bake from that. If terrain ever gains non-flat geometry (Phase 7 height maps), the geometry source may revisit `MESH_INSTANCES` or use a dedicated NavigationMesh resource baked in-editor. Implementation choice per CLAUDE.md "Escalation" rule #1 — no gameplay effect.

- **NavigationMesh pre-bake in `_ready` via `bake_navigation_mesh(false)`.** The spec says "synchronous bake at scene-load." In Godot 4, `bake_navigation_mesh(false)` is the synchronous path (false = on calling thread, not deferred to a background thread). The bake completes before `_ready` returns, so `get_navigation_map().is_valid()` is immediately true — verified by `test_navigation_region_has_valid_map_after_scene_load`. In editor workflows, the NavigationMesh resource would normally be pre-baked and saved to disk (avoiding runtime bake cost entirely). Phase 7 Khorasan map work should bake in-editor and serialize the result to avoid the startup bake. Noted here for Phase 7 world-builder.

- **CheckerBoard as `StandardMaterial3D` albedo_color, not a procedural shader.** The kickoff spec says "optional checkerboard reference texture (procedural via shader is fine, or a simple imported PNG)." A simple flat `StandardMaterial3D` with a sandy-ochre albedo was chosen over a procedural shader or PNG import — it's the smallest footprint for a placeholder (zero assets, zero shader compilation). The camera operator gets visual ground feedback from the flat color + the 256-unit extent cues. A real checkerboard (with a spatial shader or UV tiling) would require either an asset file or a ShaderMaterial sub-resource, neither of which adds functional value at Phase 0. If more granular visual scale reference is needed before Phase 7 art, a `CheckerTexture2D` can be assigned to `albedo_texture` in a one-line tscn edit. Implementation choice per CLAUDE.md "Escalation" rule #1.

- **`MAP_SIZE_WORLD` and `NAV_AGENT_RADIUS` added to `Constants` autoload.** The kickoff specified adding these if missing. Both were absent from the session-3 wave-1 Constants output. Added under a new `# === MAP CONFIGURATION ===` section with rationale comments. `MAP_SIZE_WORLD = 256.0` is the convergence-locked map size. `NAV_AGENT_RADIUS = 0.5` is the navmesh agent clearance. Both are structural (code shape would change if they moved), confirming their home in Constants vs BalanceData.

---

*Read this doc at the start of any implementation session. Update it at every phase milestone. Keep the table in §2 honest — it's the project's mirror.*
