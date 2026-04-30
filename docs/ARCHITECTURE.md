# Architecture — Target Shape and Build State

*Status: **0.1.0** initial — pre-implementation. Updated continuously as systems land.*
*Owner: engine-architect. Updated at phase milestones and significant subsystem landings.*
*Created: 2026-05-01.*

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

| Subsystem | Target spec | Status | Version | Owner | Notes |
|-----------|-------------|--------|---------|-------|-------|
| **SimClock autoload** | [SIM 1.2.0 §1.2](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0 task |
| **SimNode base class** | [SIM 1.2.0 §1.3](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0 task |
| **EventBus autoload** | [SIM 1.2.0 §7](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0; telemetry sink shipped here too |
| **GameRNG autoload** | [SIM 1.2.0 §5](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0; 4 domains |
| **TimeProvider autoload** | [SIM 1.2.0 §1](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 0 |
| **SpatialIndex autoload** | [SIM 1.2.0 §3](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Phase 1; 8m uniform grid |
| **IPathScheduler** | [SIM 1.2.0 §4](SIMULATION_CONTRACT.md) | 📋 Planned | — | engine-architect | Real impl Phase 1; mock Phase 0 (qa-engineer) |
| **CI lint script** | [SIM 1.2.0 §1.4](SIMULATION_CONTRACT.md) | 📋 Planned | — | qa-engineer | `tools/lint_simulation.sh`, Phase 0 |
| **Pre-commit hook** | [TEST 1.4.0](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0; runs lint + GUT |
| **GUT framework** | [TEST 1.4.0](TESTING_CONTRACT.md) | 📋 Planned | — | qa-engineer | Phase 0 |
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

The simulation runs at 30 Hz. Every tick walks through seven phases in fixed order:

```
TICK N
  │
  ├─ input        → InputSystem drains queued commands from UI/AI for this tick
  ├─ ai           → AIControllerHost ticks every AI controller; controllers issue
  │                 commands into unit command queues (no direct unit mutation)
  ├─ movement     → MovementSystem ticks every MovementComponent; positions update,
  │                 path requests resolved (results land tick+1)
  ├─ spatial_rebuild → SpatialIndex rebuilds the uniform grid from current positions;
  │                    queries below this point see fresh state
  ├─ combat       → CombatSystem ticks every CombatComponent; damage applied,
  │                 deaths emit unit_died, AoE queries hit fresh SpatialIndex
  ├─ farr         → FarrSystem ticks; Atashkadeh/Dadgah/Barghah/Yadgar contributions
  │                 accrue, drain events from this tick applied via apply_farr_change,
  │                 Kaveh threshold checked
  └─ cleanup      → CleanupSystem ticks; deferred signals emit (resource_node_depleted,
                    farm_destroyed), dead units removed, transient flags reset
```

**Why this order:** AI sees previous-tick positions (acceptable heuristic), movement applies before spatial rebuild, combat queries see fresh positions, Farr applies after combat (so kill-driven drains see correct kills), cleanup runs last so deferred signals don't race in-tick state changes.

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

Empty for now. First entry expected during Phase 0 implementation.

---

*Read this doc at the start of any implementation session. Update it at every phase milestone. Keep the table in §2 honest — it's the project's mirror.*
