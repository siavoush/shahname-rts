---
title: Architecture — Target Shape and Build State
type: architecture
status: living
version: 0.2.0
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
last_updated: 2026-05-01
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
| **SpatialIndex autoload** | [SIM 1.2.0 §3](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 1; 8m uniform grid |
| **IPathScheduler** | [SIM 1.2.0 §4](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Real impl Phase 1; mock Phase 0 (qa-engineer) |
| **CI lint script** | [SIM 1.2.0 §1.4](SIMULATION_CONTRACT.md) | 📋 Planned | — | qa-engineer | `tools/lint_simulation.sh`, Phase 0 |
| **Pre-commit hook** | [TEST 1.4.0](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0; runs lint + GUT |
| **GUT framework** | [TEST 1.4.0](TESTING_CONTRACT.md) | ✅ Built | 9.4.0 | qa-engineer | Installed at `game/addons/gut`. Headless runner: `game/run_tests.sh` (`godot --headless ... -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`). 28 tests across 4 unit-test scripts pass at session 1 close. Pre-commit hook + lint script land session 2. |
| **MatchHarness** | [TEST 1.4.0 §3](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 |
| **MockPathScheduler** | [TEST 1.4.0 §3](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 |
| **Determinism regression test** | [TEST 1.4.0 §6.2](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 stub; live in Phase 1 |
| **BalanceData resource** | [TEST 1.4.0 §1](TESTING_CONTRACT.md) | 📋 Planned | — | balance-engineer | Phase 0; populates at construction |
| **Constants autoload** | [02_IMPLEMENTATION_PLAN.md §2](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | gameplay-systems | Phase 0; structural keys |
| **GameState autoload** | [02_IMPLEMENTATION_PLAN.md §2](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | engine-architect | Phase 0 |
| **StateMachine + State** | [STATE 1.0.0](STATE_MACHINE_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0 (framework); UnitStates Phase 1 |
| **Camera Controller** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ui-developer | Phase 0; fixed isometric |
| **Terrain plane (256×256)** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | world-builder | Phase 0; flat checkerboard |
| **DebugOverlayManager** | [02_IMPLEMENTATION_PLAN.md Phase 0](../02_IMPLEMENTATION_PLAN.md) | 📋 Planned | — | ui-developer | Phase 0; F1-F4 toggles + registry |
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

---

*Read this doc at the start of any implementation session. Update it at every phase milestone. Keep the table in §2 honest — it's the project's mirror.*
