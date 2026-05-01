---
title: Implementation Plan — Shahnameh RTS MVP
type: plan
status: living
version: 1.2.0
owner: team
summary: Phased build plan from Phase 0 foundation through Phase 8 vertical slice. Phase task lists, agent assignments, milestones, parallelism guide, risk register, sync history.
audience: all
read_when: every-session
prerequisites: [MANIFESTO.md, 01_CORE_MECHANICS.md]
ssot_for:
  - 8-phase build plan (Phase 0 through Phase 8)
  - per-phase task lists, milestones, and "done means" criteria
  - phase parallelism guide
  - risk register
  - milestone calendar (~21 weeks to Tier 1)
  - sync history table (§9)
  - open design questions index (§10)
references: [docs/ARCHITECTURE.md, docs/STUDIO_PROCESS.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, docs/RESOURCE_NODE_CONTRACT.md, docs/AI_DIFFICULTY.md, 01_CORE_MECHANICS.md]
tags: [plan, phases, milestones, risks, agent-assignments]
created: 2026-04-30
last_updated: 2026-05-01
---

# Implementation Plan — Shahnameh RTS MVP

*Living document. Updated as we learn from prototyping.*
*Revised: 2026-04-30 — incorporating studio review feedback from all 7 specialist agents*

> This plan operates under the principles in [`MANIFESTO.md`](MANIFESTO.md). When a tactical decision in this document conflicts with a principle, the principle wins. The plan is the hypothesis; the principles are the constants.

---

## 0. How to Read This Plan

This plan covers **Tier 0 (technical prototype)** and **Tier 1 (vertical slice)** as defined in `00_SHAHNAMEH_RESEARCH.md` §10 and `01_CORE_MECHANICS.md` §1. It is structured as **8 phases** with clear deliverables, agent assignments, and "done means" criteria.

**The cardinal rule of RTS prototyping** (from every postmortem we studied — Age of Empires, Rise of Nations, Offworld Trading Company, Stormgate's failures): **get playable fast, iterate forever.** The quality of this game will be determined by how many times we go through the design → code → play → learn loop. Optimize for iteration speed above all else.

**Target platform:** macOS (Apple Silicon). Godot 4 runs natively on ARM64 Macs. All development and testing happens locally.

---

## 1. Agent Team — The Virtual Studio

A 7-person virtual indie studio. Siavoush is **Creative Director + Producer** (vision, schedule, design authority via Cowork design chat). Each specialist has a canonical definition file:

| Agent | Role | Definition |
|-------|------|-----------|
| `engine-architect` | Engine Architect | [`.claude/agents/engine-architect.md`](.claude/agents/engine-architect.md) |
| `ai-engineer` | AI & Pathfinding | [`.claude/agents/ai-engineer.md`](.claude/agents/ai-engineer.md) |
| `gameplay-systems` | Gameplay Programmer | [`.claude/agents/gameplay-systems.md`](.claude/agents/gameplay-systems.md) |
| `ui-developer` | UI/UX Developer | [`.claude/agents/ui-developer.md`](.claude/agents/ui-developer.md) |
| `world-builder` | Map & World | [`.claude/agents/world-builder.md`](.claude/agents/world-builder.md) |
| `balance-engineer` | Balance & Data | [`.claude/agents/balance-engineer.md`](.claude/agents/balance-engineer.md) |
| `qa-engineer` | QA & Testing | [`.claude/agents/qa-engineer.md`](.claude/agents/qa-engineer.md) |

The agent definition files are the **single source of truth** for each role's domain, owned files, model assignment, and key constraints. Don't restate that information here — read the definition.

Operating modes (design-mode syncs, implementation-mode TDD, mode switches) are documented in [`docs/STUDIO_PROCESS.md`](docs/STUDIO_PROCESS.md) §12.

---

## 2. Project Directory Structure

The directory layout, the rationale for each folder, and the build state of every subsystem live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §4 (directory map) and §2 (subsystem state). That document is the orientation layer; this plan describes *what to build by phase*, not *where things live*.

The constants split (`constants.gd` for structural keys vs `data/balance.tres` for tunable numbers) is documented in `docs/TESTING_CONTRACT.md` §1.

---

## 3. The Phases

### Phase 0 — Foundation (Week 1-3)

**Goal:** A running Godot project with the architectural skeleton AND the foundational contracts that prevent expensive retrofits later. You can open it, see a colored plane on a defined map, and a camera that moves over it on a fixed 30Hz simulation tick with telemetry logging every event.

**Theme:** *"Get the contracts right. Everything else builds on this."*

**Phase 0 expanded based on team review.** The reviews converged on a hard truth: ~10 architectural decisions are cheap to make now and weeks-expensive to retrofit later. We build them all in Phase 0.

> **Starting Phase 0?** See [`02a_PHASE_0_KICKOFF.md`](02a_PHASE_0_KICKOFF.md) for the first-implementation-session recipe — read order, scoped session-1 slice, internal dependency order between Phase 0 tasks, TDD reminders, and the session ceremony.

#### Pre-Phase 0 Coordination Sync (REQUIRED before tasks start)

| Sync | Participants | Deliverable | Why |
|------|-------------|-------------|-----|
| **Simulation Architecture Contract** | engine-architect + ai-engineer + qa-engineer | `docs/SIMULATION_CONTRACT.md` — locks SimClock, SpatialIndex, MovementComponent.request_repath signature, frame-budget rules | These three contracts touch all three domains. Building each agent's piece without alignment guarantees rework. |
| **State Machine Contract** | engine-architect + ai-engineer | `docs/STATE_MACHINE_CONTRACT.md` — UnitState base, enter/exit/interrupt hooks, command queue, death-from-any-state | Engine architect builds it; AI engineer is primary consumer. Edge cases (Shift+queue, attack-interrupts-gather, death) must be designed in, not bolted on. |
| **Testing Contract** | qa-engineer + engine-architect + balance-engineer | `docs/TESTING_CONTRACT.md` — TimeProvider abstraction, seeded RNG strategy, telemetry event schema | Determines whether Farr/Kaveh logic is testable. |

#### Phase 0 Tasks

| Task | Agent | Done Means |
|------|-------|------------|
| Initialize Godot 4 project in `game/` | engine-architect | `project.godot` exists, project opens in Godot editor on macOS Apple Silicon |
| **Fixed 30Hz `SimClock` autoload** | engine-architect | All gameplay state mutates on `_sim_tick()` only; rendering interpolates on `_process()`. Documented in `SIMULATION_CONTRACT.md`. |
| **`TimeProvider` autoload** (testable clock wrapper) | engine-architect | `TimeProvider.now_ms()` and `TimeProvider.set_mock(ms)` for test injection. All time-dependent code routes through this — never `Time.get_ticks_msec()` directly. |
| **Typed `EventBus` autoload** with telemetry sink | engine-architect | Every signal declared in one file with typed args. Adding a signal requires editing this file. EventBus also writes structured events to `Telemetry` autoload. |
| **`Telemetry` autoload** (in-memory event log → JSON dump) | balance-engineer + engine-architect | Captures every Farr change, unit kill, resource transaction, match start/end. Dumps to `data/telemetry/match_<timestamp>.json` at match end. |
| **`Constants` autoload + `BalanceData.tres` Resource** | gameplay-systems (constants) + balance-engineer (balance.tres) | `constants.gd` holds structural keys/enums. `BalanceData` Resource holds all tunable numbers with unit annotations (`# Farr/min`, `# HP`, `# seconds`). Constants reads BalanceData at boot. |
| **`GameState` autoload** | engine-architect | Centralized match state: phase (lobby/playing/ended), winner, current player, etc. |
| **`StateMachine` + `State` + `UnitState` base classes** (per State Machine Contract) | engine-architect | Includes `enter(prev_state, context)`, `exit()`, command queue support, death-interrupt path. Tested with one example. |
| **Component model locked: child-node pattern** | engine-architect | `HealthComponent extends Node`, units expose typed `get_health() -> HealthComponent`. Documented pattern with example. |
| **Path-update scheduler scaffolding** | engine-architect + ai-engineer | `MovementComponent.request_repath()` routes through a central scheduler that buckets units by `unit_id % 4` per frame. No direct `set_target_position` calls in unit code. |
| **`FarrSystem` autoload skeleton** with `apply_farr_change()` chokepoint | gameplay-systems | Function exists, value at 50, no generators/drains wired yet. Every call logs to Telemetry. |
| **Camera controller — fixed isometric, no rotation** | ui-developer | WASD pan, edge scroll (50px trigger), scroll zoom with clamps. **Rotation explicitly out of scope** for MVP. |
| **Flat terrain plane** at locked `MAP_SIZE_WORLD = 256.0` | world-builder | Visible ground, sized per `BalanceData.tres`. Camera bounds match. |
| **Map size constant locked** in `BalanceData.tres` | balance-engineer + world-builder | `map_size = 256` (world units). Single point of change. |
| **Godot CSV translation infrastructure** | ui-developer | `translations/strings.csv` with `keys,en,fa` columns. `tr("UI_FARR")` works. Key naming convention documented (`UI_*`, `UNIT_*`, `BLDG_*`, `EVENT_*`). |
| **Farr HUD readout** (text-only, shows "FARR: 50") | ui-developer | Displays `FarrSystem.value`. No gauge yet — that's Phase 1. |
| **Resource HUD readouts** (Coin: 0, Grain: 0, Pop: 0/0) | ui-developer | Live text labels reading from systems that don't exist yet (defaults to 0). |
| **`DebugOverlayManager` autoload** (registry + toggle keys) | ui-developer | Framework only — overlays register themselves. F1-F4 toggle their visibility. Empty until later phases. |
| **GUT test framework installed** | qa-engineer | `gut` runs from editor and command line headless. Hello-world test passes. |
| **Pre-commit hook running tests** | qa-engineer | `.git/hooks/pre-commit` runs `godot --headless --script gut_runner.gd`. Commit blocked on test failure. |
| **`SIMULATION_CONTRACT.md`, `STATE_MACHINE_CONTRACT.md`, `TESTING_CONTRACT.md`** | participants of each sync | Written deliverables from the pre-phase syncs, committed to `docs/`. |

**Milestone test:** Open the project on macOS. Camera moves over a 256×256 ground plane (no rotation). HUD shows "Coin: 0 | Grain: 0 | FARR: 50 | Pop: 0/0". F1-F4 toggle empty debug panels. Run `git commit` on a broken test — commit fails. Run `apply_farr_change(5, "test", null)` from the debugger — HUD updates to "FARR: 55", and a JSON event appears in `data/telemetry/`. Three contract docs exist in `docs/`.

**Parallelism after sync:** engine-architect, ui-developer, world-builder, balance-engineer, qa-engineer can all work simultaneously. gameplay-systems depends on engine-architect finishing the autoload structure first.

**Why Phase 0 grew from 2 to 3 weeks:** the team review revealed that the original "skeleton" was missing the contracts that downstream phases assume. Every item added here was flagged as "expensive to retrofit" by at least one specialist. Better to spend an extra week now than 4-6 weeks of rework over Phases 4-8.

---

### Phase 1 — Unit Core (Week 3-5)

**Goal:** You can click a colored box and tell it where to go. Multiple boxes group-move in proper formation, not a clumped blob. The Farr gauge has visual presence even though Farr isn't doing anything yet.

**Theme:** *"Command one unit. Then command many — properly."*

| Task | Agent | Done Means |
|------|-------|------------|
| Basic unit scene (CharacterBody3D + components) | engine-architect + gameplay-systems | A unit exists as a colored cube with HealthComponent, SelectableComponent, MovementComponent, SpatialAgentComponent |
| **`SpatialIndex` autoload** (uniform 8m grid) | engine-architect | Units register on spawn, deregister on death, queries return units in radius/region in O(1)-ish. Used by selection, AoE, range checks, fog reveals. |
| **Navmesh strategy locked: NavigationObstacle3D per building** | world-builder + ai-engineer | Decision documented: buildings carve navmesh via NavigationObstacle3D (cheaper than rebake). Both agents code against this. |
| `NavigationRegion3D` setup on terrain | world-builder | Navmesh covers the 256×256 playable area, units pathfind correctly |
| Single-click unit selection (raycast + SelectableComponent) | ui-developer | Click a unit → selection ring appears, unit info shows in panel |
| Box/drag selection | ui-developer | Drag rectangle → uses SpatialIndex query → all units inside selected |
| Right-click-to-move (commands route through CommandManager) | ui-developer + ai-engineer | Selected unit(s) move to clicked position via MovementComponent.request_repath() |
| Unit state machine: Idle, Moving (extends UnitState contract) | ai-engineer | Transitions clean, idle animation placeholder (pulsing scale), enter/exit hooks tested |
| **`GroupMoveController`** — formation slots from selection centroid | ai-engineer | Selected units assigned offset slots in a loose grid, arrival propagation (80% reach → others stop). 10+ units move as a coherent group. |
| **Farr circular gauge** (visual, top-right HUD) | ui-developer | Renders 0-100 from `FarrSystem.value`, color thresholds (gold ≥70, ivory 40-70, dim 15-40, red <15) — even though Farr is locked at 50 for now. Layout decision happens here, not Phase 4. |
| **Selected unit panel** (bottom-left, placeholder) | ui-developer | Shows portrait box + name + HP for selected unit (single only — multi-select panel comes Phase 2) |
| Unit tests: state transitions, selection, SpatialIndex | qa-engineer | Tests pass headless. SpatialIndex correctness tested with synthetic spawns. |

**Deferred from original Phase 1** (explicit, not lost):
- **Control groups (Ctrl+1-9)** → Phase 2 (per ui-developer: matters when combat exists)
- **Double-click-select-all-of-type** → Phase 2 (requires unit-type registry)

**Milestone test:** 10 colored cubes on the ground. Click one — selected. Box-select 8 — all selected, formation visualization implied by their positions when commanded. Right-click far away — they move as a group, arrive in formation, no visible clumping. Farr gauge renders at 50, gold-ivory color. HUD shows placeholder counters.

---

### Phase 2 — Combat (Week 5-7)

**Goal:** Two colored armies fight each other. Units attack, take damage, and die. The rock-paper-scissors triangle works. Hero death position is captured for Phase 5's Yadgar building.

**Theme:** *"The sword before the story."*

| Task | Agent | Done Means |
|------|-------|------------|
| Attack command (right-click enemy unit) | ai-engineer | Unit moves into range, then attacks. State transitions Moving → Attacking via UnitState contract |
| `CombatComponent`: damage, attack speed, range | gameplay-systems | Configurable per unit type via `BalanceData.tres` |
| `HealthComponent` with **`last_death_position` capture** | gameplay-systems | Units lose HP, die, position stored on death event. Yadgar building (Phase 5) consumes this. |
| Death event published via EventBus | gameplay-systems | Typed signal `unit_died(unit, killer, cause, position)` — Telemetry logs every death |
| Attack-move command (A + click) | ai-engineer | Units move to position, engaging enemies encountered en route |
| Three Iran unit types: Piyade, Kamandar, Savar | gameplay-systems | Different colored shapes/sizes, stats from `BalanceData.tres` |
| **Asb-savar Kamandar (horse archer) at Tier-1-equivalent stats** | gameplay-systems + balance-engineer | Per gameplay-systems' review: kiting affects combat math. Ship horse archers in Phase 2 to expose the case early. Stats temporarily Tier-1-equivalent; rebalanced in Phase 4 when properly Tier 2. |
| Rock-paper-scissors effectiveness matrix | gameplay-systems | 2D effectiveness dict in `BalanceData.tres`, multipliers applied in CombatComponent |
| Turan mirror units (same archetypes, different team color) | gameplay-systems | Enemy units exist with matching stats |
| **First Farr drain wired**: worker killed idle = -1 Farr | gameplay-systems | Per studio review: prove `apply_farr_change()` end-to-end with one drain, even though full system is Phase 4 |
| Health bars above units | ui-developer | Floating health bars from SpatialIndex query, color-coded |
| **F4 debug overlay: attack ranges** (ships WITH combat, not as empty Phase 0 placeholder) | ui-developer | F4 shows attack range circles for selected units |
| **Multi-select unit panel** (defer from Phase 1) | ui-developer | When multiple selected: panel shows summary (count by type, total HP) |
| **Control groups (Ctrl+1-9 assign, 1-9 recall)** (deferred from Phase 1) | ui-developer | Standard RTS control groups now that combat makes them matter |
| **Double-click-select-all-of-type** (deferred from Phase 1) | ui-developer | Double-click a unit → selects all of that type on screen |
| Combat math unit tests | qa-engineer | Tests for damage, effectiveness, death triggers, last_death_position capture, Farr drain on worker death |

**Milestone test:** 5 Piyade (blue cubes) vs 5 Turan Savar (red cylinders). Select Piyade, right-click enemy Savar — they fight, Piyade win. Reverse: Savar vs Kamandar — Savar wins. Add 3 Asb-savar Kamandar — they kite enemy infantry. Triangle holds. Kill an idle worker — Farr drops to 49 in HUD, telemetry logs the drain with reason "worker_killed_idle". F4 shows attack ranges.

---

### Phase 3 — Economy + Dummy AI + Fog Data Layer (Week 7-9)

**Goal:** Full economic loop works. A `DummyAI` opponent exists so you can solo-test without controlling both sides. Fog-of-war data layer tracks visibility (no shader yet).

**Theme:** *"Gold from the earth, grain from the field — and an opponent across the map."*

#### Pre-Phase 3 Coordination Sync

| Sync | Participants | Deliverable |
|------|-------------|-------------|
| **Resource Node Schema** | world-builder + gameplay-systems | A small interface spec: what properties a `ResourceNode` exposes, how depletion is tracked, how fertile-tile differs from mine, the gather API. Either lands as a comment block on the base class or as a section in the contracts doc. |

| Task | Agent | Done Means |
|------|-------|------------|
| Kargar (worker) unit with Gathering state | ai-engineer + gameplay-systems | Worker moves to resource node, gathers, returns to Throne, deposits |
| Resource nodes: Coin mines (yellow dots) — depletable | world-builder | Mine nodes visible, finite reserves, vanish when empty |
| Resource nodes: Fertile tile zones (green areas) — passive (player builds farms here) | world-builder | Fertile zones visible, accept farm-building placement, reject elsewhere |
| `ResourceSystem`: track Coin, Grain, population | gameplay-systems | Resources increment/decrement correctly, population vs cap, Telemetry logs every transaction |
| Building placement system (ghost → confirm → construct) | gameplay-systems | Worker → build menu → click map → ghost preview (with valid/invalid color) → confirm → worker walks there and builds |
| Building placement uses NavigationObstacle3D | world-builder + gameplay-systems | Per Phase 1 decision: completed buildings carve navmesh via NavigationObstacle3D, units route around |
| Construction timer with progress bar | gameplay-systems + ui-developer | Building shows progress bar during construction, completes per `BalanceData.tres` time |
| Tier 1 Iran buildings: Throne, Khaneh, Mazra'eh, Ma'dan, Sarbaz-khaneh | gameplay-systems | All 5 buildings placeable, functional (pop cap, grain generation, coin extraction, unit production) |
| Build menu UI (bottom-right, contextual) | ui-developer | Select worker → build menu shows available buildings with costs and tooltips |
| Resource counter live updates | ui-developer | HUD updates each tick |
| Worker auto-return to gathering after delivery | ai-engineer | Workers loop: gather → deliver → return to same node |
| **`DummyAIController`** (~100 lines, fixed-timer behavior) | ai-engineer | Turan side builds 3 workers, 1 Sarbaz-khaneh, produces Piyade on a timer. No combat AI. Just enough to make solo testing meaningful. |
| **Fog-of-war DATA layer** (boolean visibility grid, no shader) | world-builder | Per-team visibility tracked on a grid; `is_visible_to(team, position)` API exposed. AI Engineer's scouting (Phase 6) and Kaveh Event presentation (Phase 5) consume this. |
| **Hard rule enforced**: phase sign-off requires integration tests pass | qa-engineer | Each gameplay-systems task's "done means" includes "integration test passes." Not optional. |
| Economy unit + integration tests | qa-engineer | Tests for gather rates, resource costs, build prerequisites, full gather→build→produce cycle |

**Milestone test:** Start with Throne + 3 workers. Send workers to mine. Watch Coin accumulate. Build Khaneh (pop +5). Build Mazra'eh on fertile tile (grain generates; rejected on non-fertile tile). Build Sarbaz-khaneh. Produce a Piyade. Across the map, the DummyAI is doing the same thing — you can scout it. Visibility data layer says "AI base is fogged" until your worker walks near. The loop works *and* you have an opponent.

---

### Phase 4 — Production, Tech Tiers, Full Farr (Week 9-11)

**Goal:** Full production pipeline. Tier advancement (Village → Fortress). Farr system completes — every generator, every drain, snowball protection. All Iran Tier 1 + Tier 2 buildings and units.

**Theme:** *"From village to fortress, from archer to cavalier — earning the divine glory."*

#### Pre-Phase 4 Modeling Step

| Activity | Owner | Deliverable |
|----------|-------|-------------|
| **Farr curve modeling** | balance-engineer | Spreadsheet: given realistic drain events and building timelines, what does the Farr curve look like in a 20-minute match? Catches obviously broken numbers (e.g., "Atashkadeh at +1/min means 40 minutes to reach Fortress threshold") before they ship. |

| Task | Agent | Done Means |
|------|-------|------------|
| Unit production from buildings with queues | gameplay-systems | Select Sarbaz-khaneh → click unit → resources spent → timer → unit spawns at rally point |
| Production queue UI with cancel | ui-developer | Queue visible, cancel returns resources, rally point setting via right-click |
| Population cap system | gameplay-systems | Can't produce beyond cap; Khaneh increases cap by 5 |
| **All Farr generators wired** (§4.3) | gameplay-systems | Atashkadeh +1/min, Dadgah +0.5/min, Barghah +0.5/min, Yadgar +0.25/min (gated on hero death), one-time event generators |
| **All Farr drains wired** (§4.3) | gameplay-systems | Worker killed idle (-1), hero friendly fire (-5), Atashkadeh lost (-5), all per spec |
| **Snowball protection** | gameplay-systems | 3:1 army-ratio kills drain -0.5; broken-economy kills drain -1. **DEFINITION ESCALATED to design chat** — see Open Questions section. |
| Atashkadeh building: passive Farr generation | gameplay-systems | Building registers with FarrSystem, ticks contribute via SimClock |
| Dadgah building: Farr gen + hero respawn site | gameplay-systems | Both functions wired |
| **Farr gauge polish** (animations, color transitions, threshold audio cues) | ui-developer | Polish on top of Phase 1's gauge: smooth transitions, threshold chimes (placeholder), pulse below 15 |
| **Floating +/- Farr change feed** (per §4.4) | ui-developer | Each `apply_farr_change()` call shows a floating number from the gauge with reason text |
| **F2 debug overlay: Farr change log** (ships WITH FarrSystem completion) | ui-developer | F2 shows real-time Farr change log with timestamps, reasons, and source units |
| Tech tier advancement: Village → Fortress | gameplay-systems | Requires Atashkadeh built + Farr ≥ 40 + cost. 90s build time. |
| Tier 2 buildings: Qal'eh, Sowari-khaneh, Tirandazi, Barghah | gameplay-systems | All functional, gated behind Fortress tier |
| Tier 2 units (full stats): Savar, **Asb-savar Kamandar rebalanced** | gameplay-systems + balance-engineer | Cavalry and horse archer at proper Tier 2 stats (rebalanced from Phase 2's temporary Tier-1-equivalent values) |
| Tier indicator in HUD | ui-developer | Shows current tier with visual distinction |
| Tech + Farr unit tests with **TimeProvider mock** | qa-engineer | Tests for tier prerequisites, all Farr generators/drains tested with mock clock (no wall-time waits) |

**Milestone test:** Play from Village start. Build economy. Construct Atashkadeh — Farr climbs visibly. Research Fortress when Farr ≥ 40. Build Sowari-khaneh. Produce Savar cavalry. Trigger every Farr drain in the spec via console — gauge updates with floating reason text, F2 overlay logs them all, telemetry captures every event. Run Farr tests headless — pass in <100ms thanks to mock clock.

---

### Phase 5 — Heroes & Special Mechanics (Week 11-13)

**Goal:** Rostam is on the field. His abilities work. Farr has real consequences. The Kaveh Event can fire and be resolved.

**Theme:** *"The hero stands. The empire trembles."*

| Task | Agent | Done Means |
|------|-------|------------|
| Rostam hero unit: spawns at game start | gameplay-systems | Largest colored shape, golden outline, mounted (Rakhsh). 10× Savar HP, 5× damage, AoE melee |
| Cleaving Strike ability (30s cooldown) | gameplay-systems | Manual activation, charges forward, damages all enemies in wide arc |
| Roar of Rakhsh ability (60s cooldown) | gameplay-systems | Nearby allies gain +25% attack speed for 8s |
| Hero portrait in HUD (always visible) | ui-developer | Shows Rostam health, ability cooldowns, click-to-center-camera |
| Hero death and respawn | gameplay-systems | Death: Farr penalty (-5/-10), dramatic pause. Respawn at Dadgah/Barghah after 120s + resource cost |
| Yadgar building (post-hero-death, at death site) | gameplay-systems | +0.25 Farr/min, only buildable after Rostam has died, placed using `last_death_position` captured in Phase 2 |
| **Kaveh Event uses seeded RNG** (per qa-engineer review) | gameplay-systems | Rebel spawn count, worker defection rolls accept a `seed` parameter for deterministic tests |
| Farr drain events: worker killed idle, hero fleeing | gameplay-systems | All drain triggers from §4.3 implemented and tested |
| Snowball protection: 3:1 army ratio penalty | gameplay-systems | Farr drains when overwhelming a weaker enemy |
| Kaveh Event trigger (Farr < 15 for 30s) | gameplay-systems | Warning at 25, urgent at 20, countdown at 15, event fires after 30s |
| Kaveh Event execution: rebel spawn, worker strike | gameplay-systems | Kaveh hero spawns hostile, 4-6 rebel units, 25% worker defection, Farr locked 60s |
| Kaveh Event resolution: defeat or restore Farr > 30 | gameplay-systems | Both paths work. Defeat kills rebels. Farr restoration disbands them peacefully. |
| Kaveh Event warning UI | ui-developer | Progressive warnings in HUD as Farr drops through thresholds |
| Hero and Kaveh unit tests | qa-engineer | Tests for abilities, death/respawn, Farr thresholds, Kaveh Event trigger/resolution |

**Milestone test:** Rostam spawns with the Throne. Use Cleaving Strike to wipe an enemy squad. Use Roar of Rakhsh to buff allies. Let Rostam die — watch Farr drop, respawn timer starts. Now: intentionally tank Farr below 15. Watch the 30-second countdown. Kaveh Event fires — rebels spawn, workers strike. Fight off the rebels (or build an Atashkadeh to claw Farr back). This is the moment you know the game has a soul.

---

### Phase 6 — Full AI Opponent + AI-vs-AI Simulation (Week 13-15)

**Goal:** Turan plays a full game against you with proper FSM-driven behavior. AI-vs-AI headless simulation infrastructure exists — we can run 50 matches overnight and look at distributions.

**Theme:** *"Across the steppe, Afrasiyab gathers his riders. And we begin to measure."*

| Task | Agent | Done Means |
|------|-------|------------|
| Turan AI controller: full FSM (replaces DummyAI) | ai-engineer | AI builds workers, gathers resources, constructs buildings, tech-ups, produces army, attacks |
| AI build order: fixed sequence for MVP | ai-engineer | Predictable and testable. Throne → workers → mine → barracks → army |
| AI tech-up at ~5 minutes | ai-engineer | AI advances to Fortress at fixed time threshold |
| AI army production: mixed composition | ai-engineer | AI produces Piyade, Kamandar, Savar in reasonable ratios |
| AI attack waves: early skirmish, mid-game push, late-game assault | ai-engineer | AI sends probing attacks early, larger armies later, tries to destroy Throne |
| AI scouting uses fog-of-war data layer | ai-engineer | AI sends scout units, queries `is_visible_to(turan, position)` |
| Piran hero unit for Turan | gameplay-systems | Turan hero with Rostam-equivalent stats (tuned), joins AI army |
| **Three difficulty levels with TIMING differentiation, not just resource bonuses** | ai-engineer + balance-engineer | Easy: wave every 180s, +0% resources. Normal: wave every 120s, +0%. Hard: wave every 90s, +25% resources. (Per ai-engineer's review: pure resource bonus alone feels boring.) |
| Terrain movement modifier hook (returns 1.0 for now) | ai-engineer + gameplay-systems | `get_terrain_movement_modifier(position)` exists, called by MovementComponent. Real terrain types land Phase 7 — this hook prevents retrofit. |
| F3 debug overlay: AI state | ui-developer | Shows current AI phase, resources, army size, next attack timer |
| F1 debug overlay: pathfinding routes | ui-developer | Shows path lines for selected (or all) units |
| **AI-vs-AI headless simulation harness** (moved from Phase 8) | qa-engineer + balance-engineer | `tools/run_simulation.gd` runs N matches headless, dumps Telemetry JSONs to `data/telemetry/sim_<id>/`. Cleared randomization seed per match. |
| **First simulation batch: 50 AI-vs-AI matches** | balance-engineer | Win-rate distribution by difficulty, match-length distribution, Farr-trajectory shapes. First real balance data. |
| **Nightly regression batch** wiring | qa-engineer | Cron-style or manual trigger. 20 matches per run. Alerts on >15% shift in win rate or median match length vs. last green run. |
| AI integration + simulation tests | qa-engineer | AI completes full game loop without crashing. Simulation harness produces deterministic outputs given fixed seeds. |

**Milestone test:** Start a match on Normal. AI builds across the map. Around minute 3-4, a small Turan scouting party appears. By minute 7-8, a real army pushes. By minute 12-15, it's a full assault. You can beat it if you play well. Run `godot --headless tools/run_simulation.gd --matches 10` — 10 matches complete, JSONs land in `data/telemetry/`. **This is the Tier 0 prototype delivery.**

---

### Phase 7 — Map, Minimap, Fog Rendering, Terrain Types (Week 15-17)

**Goal:** The full Plains of Khorasan map. Fog of war RENDERED (data layer already exists from Phase 3). Terrain types active with movement modifiers. The game looks like an RTS.

**Theme:** *"The plains of Khorasan stretch before you."*

| Task | Agent | Done Means |
|------|-------|------------|
| Full MVP battle map: "Plains of Khorasan" | world-builder | 256×256 map with mixed terrain, balanced spawns, choke points, expansions |
| Terrain types: passable, impassable (mountains), water, fertile | world-builder | Different colored zones, fertile zone for farm placement (already in Phase 3, polished here) |
| **Terrain movement modifiers wired** to existing hook | world-builder + ai-engineer | The `get_terrain_movement_modifier()` hook from Phase 6 now returns real values: 0.7 on rough, 1.0 on plains, etc. |
| **Fog of war RENDERING** (shader on top of data layer) | world-builder | Visual fog: unexplored = black, explored = grey, visible = clear. Data layer from Phase 3 unchanged — just rendered. |
| Building memory ("last seen" proxies) | world-builder | When buildings move out of sight, dummy visual proxies persist at last-known position |
| Minimap rendering | ui-developer | Bottom-corner minimap shows terrain, unit dots (blue/red), fog state, click-to-move |
| Resource node strategic placement | world-builder | Mines at expansions, fertile land near bases, secondary resources in contested areas |
| Map boundaries (camera + unit) | world-builder + ui-developer | Can't scroll or walk off the map |
| Full HUD polish pass | ui-developer | All §11 requirements met |
| Fog rendering + terrain tests | qa-engineer | Visibility renders correctly, proxy buildings persist, terrain modifiers apply |

**Milestone test:** The game looks like a real RTS. Map through fog. Units reveal as they explore. Minimap shows everything you can see. Cavalry slows visibly when crossing rough terrain. You play a full match start to finish on Khorasan.

---

### Phase 8 — Integration, Polish & Playtesting (Week 17-21)

**Goal:** A complete, playable MVP. Start the game, play a match, win or lose, understand what happened, want to play again.

**Theme:** *"Is it fun? That is the only question that matters."*

| Task | Agent | Done Means |
|------|-------|------------|
| Main menu → match → victory/defeat → back to menu flow | ui-developer + engine-architect | Complete game loop with menu screens |
| Victory/defeat screen with match summary | ui-developer | Shows: time elapsed, units produced/lost, Farr trajectory, buildings constructed |
| Match start sequence: camera sweep, placement | ui-developer | Brief cinematic-style opening (camera moves from overview to base), then play |
| Sound placeholders: UI clicks, attack, death, selection acknowledgements | ui-developer | Basic sound feedback (free CC0 sounds from Kenney.nl) |
| Balance pass: economy curve tuning | balance-engineer | 15-25 minute average match length on Normal. Economy feels neither too fast nor too slow. |
| Balance pass: unit effectiveness | balance-engineer | Rock-paper-scissors triangle produces meaningful army composition choices |
| Balance pass: Farr tuning | balance-engineer | Farr changes are noticeable and meaningful. Kaveh Event is reachable but not trivial. |
| Performance optimization | engine-architect | Stable 60 FPS on M1 Mac with full match (2× ~50 units, all buildings, fog of war) |
| Full regression test suite | qa-engineer | All unit tests pass. All integration tests pass. No crash scenarios. |
| **Final AI-vs-AI batch** (200 matches across difficulties) | qa-engineer + balance-engineer | Build on Phase 6 infra. Final balance distributions captured. Used to back final tuning decisions. |
| Playtest session with Siavoush | ALL | Siavoush plays 3+ complete matches. Notes what's fun, what's frustrating, what's broken. |

**Milestone test:** You sit down. You click "New Game." You choose Normal difficulty. You play a 20-minute match against Turan. You manage your economy, build your army, watch your Farr, field Rostam, survive (or trigger) a Kaveh Event, and destroy the enemy Throne. Or you lose trying. Either way, you want to play again. **This is the Tier 1 vertical slice delivery.**

---

## 4. System Dependency Graph

```
                    ┌──────────────────┐
                    │  Engine Architect │
                    │  (Foundation)     │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
    │ UI Developer│  │ AI Engineer │  │   Gameplay   │
    │ (Camera,    │  │ (Pathfind,  │  │   Systems    │
    │  Selection) │  │  States)    │  │ (Resources,  │
    └──────┬──────┘  └──────┬──────┘  │  Combat,     │
           │                │         │  Farr)       │
           │                │         └──────┬───────┘
           │                │                │
           │         ┌──────┴───────┐        │
           │         │ World Builder│        │
           │         │ (Terrain,    │        │
           │         │  NavMesh,    │        │
           │         │  Fog)        │        │
           │         └──────┬───────┘        │
           │                │                │
           ▼                ▼                ▼
    ┌──────────────────────────────────────────────┐
    │              Integration Layer               │
    │  (Everything connects through EventBus)      │
    └──────────────────┬───────────────────────────┘
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
    ┌──────────────┐     ┌──────────────┐
    │   Balance    │     │  QA Engineer │
    │   Engineer   │     │  (Tests,     │
    │  (Tuning)    │     │   Sims)      │
    └──────────────┘     └──────────────┘
```

---

## 5. Phase-by-Phase Parallelism Guide

For each phase, this is how to assign agents to work in parallel:

### Phase 0 — Full Parallel
```
engine-architect ──→ project init, autoloads, state machine, components
ui-developer     ──→ camera controller, debug overlay framework
world-builder    ──→ terrain plane, navigation region
gameplay-systems ──→ constants.gd skeleton, translation setup
qa-engineer      ──→ GUT installation, test infrastructure
```
All 5 agents work independently. No blocking dependencies.

### Phase 1 — Mostly Parallel (one dependency)
```
engine-architect ──→ unit scene template (FIRST, others depend on this)
    then parallel:
    ai-engineer      ──→ movement, pathfinding, state machine
    ui-developer     ──→ selection system, HUD placeholder
    world-builder    ──→ navigation mesh, resource nodes
    gameplay-systems ──→ unit stats, health/damage components
    qa-engineer      ──→ movement/selection tests
```

### Phase 2-4 — Staged Parallel
```
gameplay-systems builds the mechanics ──→ ai-engineer wires behaviors ──→ ui-developer displays state
                                     ──→ qa-engineer tests each system as it lands
```

### Phase 5-6 — Synthesis Required
Kaveh Event and AI opponent are cross-cutting. Use **discussion mode** (agent teams) for integration planning, then split back to isolation for implementation.

### Phase 7-8 — Full Team
All agents contribute. Coordinate via shared task list.

---

## 6. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pathfinding breaks with 50+ units | Medium | High | Path-update scheduler from Phase 0 (buckets units by ID). NavigationAgent3D for MVP, flowfield escape hatch only if Phase 8 perf shows >5ms/frame in nav. |
| Farr mechanic feels ignorable | Medium | Critical | Stub gauge in Phase 1, first drain in Phase 2, full system Phase 4. Players see Farr present from week 5, not week 11. F2 debug overlay shipped with FarrSystem. |
| Balance is guesswork without data | High | High | **Telemetry from Phase 0**, AI-vs-AI sim from Phase 6 (was Phase 8). Every match logs JSON; we tune from distributions, not vibes. |
| AI opponent is too dumb or too cheaty | High | High | DummyAI in Phase 3 unblocks solo testing. Full FSM in Phase 6. Difficulty differs by *timing* + resources, not just resources. |
| Scope creep into Tier 2 features | High | Medium | This plan is the scope. If something isn't listed here, it's post-MVP. Enforce ruthlessly. |
| Performance on M1 Mac | Low | Medium | CharacterBody3D fine for ~100 units/side. SpatialIndex from Phase 1 keeps queries O(1). Profile in Phase 6, optimize in Phase 8. |
| Kaveh Event too punishing or too weak | Medium | High | Seeded RNG enables deterministic tests. Curve modeling in Phase 4 catches obvious-broken before code lands. Plan for 3+ tuning iterations. |
| Time-dependent code is untestable | High | High | TimeProvider abstraction from Phase 0. All Farr/Kaveh logic uses mock clocks in tests. |
| Stringly-typed signals become a junk drawer | Medium | High | Typed EventBus from Phase 0 — every signal declared in one file with typed args. |
| Agent coordination overhead | Medium | Medium | Default to isolation mode. Discussions are scheduled (see §10), not ad-hoc. Strict file ownership. |
| Architectural retrofits in Phase 4-8 | Was high → now low | High | Phase 0 expanded to lock 9 contracts (SimClock, SpatialIndex, EventBus, components, path scheduler, TimeProvider, BalanceData split, camera, map size). |

---

## 7. Where to Start — The First Sessions

**Session 1 — Pre-Phase 0 Architecture Sync** (lead-facilitated discussion)

Before any code is written, run the three Phase 0 coordination syncs as multi-agent discussions:

1. **Simulation Architecture Contract** (engine-architect + ai-engineer + qa-engineer) → produces `docs/SIMULATION_CONTRACT.md`
2. **State Machine Contract** (engine-architect + ai-engineer) → produces `docs/STATE_MACHINE_CONTRACT.md`
3. **Testing Contract** (qa-engineer + engine-architect + balance-engineer) → produces `docs/TESTING_CONTRACT.md`

These are the gray-zone decisions where multiple specialties touch. Run them as discussions (see §10), not solo agent work.

**Session 2 — Phase 0 kickoff**

> Initialize Godot 4 project. Implement the three contracts written in Session 1. Build all 20 Phase 0 tasks in parallel where possible.

Lead spawns engine-architect (foundation), ui-developer (camera + HUD), world-builder (terrain + map size), balance-engineer (BalanceData.tres + Telemetry), qa-engineer (GUT + pre-commit), gameplay-systems (FarrSystem skeleton + constants split). Six agents in parallel, each on their owned files.

**Session 3+ — Phase 1 onwards**

Follow the plan. Each phase begins with any required pre-phase syncs, then parallel implementation.

---

## 8. Milestone Calendar (Estimated)

Estimates, not commitments. Adjusted for the expanded Phase 0.

| Phase | Target | Deliverable |
|-------|--------|-------------|
| Phase 0 | Week 3 | Foundation + 3 contract docs. HUD reads "FARR: 50". Telemetry working. |
| Phase 1 | Week 5 | Units select, move in formation, no clumping. Farr gauge visible. |
| Phase 2 | Week 7 | Two armies fight. Combat triangle works. First Farr drain wired. |
| Phase 3 | Week 9 | Economy loop. DummyAI opponent. Fog data layer. |
| Phase 4 | Week 11 | Full Farr system. Tech tiers. All units producible. |
| Phase 5 | Week 13 | Rostam on field. Kaveh Event fires. **Tier 0 prototype.** |
| Phase 6 | Week 15 | Full Turan AI + AI-vs-AI sim infra. First balance data. |
| Phase 7 | Week 17 | Khorasan map. Fog rendering. Terrain types. |
| Phase 8 | Week 21 | Polish. Final balance pass (data-backed). **Tier 1 vertical slice.** |

**Total: ~21 weeks (5 months)** for the vertical slice. The expanded Phase 0 (+1 week) should be more than recouped in saved retrofits across Phases 4-8.

---

## 9. Cross-Team Coordination Protocol

The team review revealed several "gray zone" decisions that span multiple specialties — places where building each agent's piece in isolation guarantees rework. These get **scheduled discussions** rather than ad-hoc messaging.

**The full process — discussion patterns, agenda template, facilitator role, retro practice — is documented in [`docs/STUDIO_PROCESS.md`](docs/STUDIO_PROCESS.md).** That doc is the source of truth for *how* syncs are run; this section just lists *which* syncs are planned.

### Scheduled Pre-Phase Syncs

| # | When | Sync | Participants | Pattern | Status | Deliverable |
|---|------|------|-------------|---------|--------|-------------|
| 1 | **Before Phase 0** | Simulation Architecture | engine-architect + ai-engineer + qa-engineer | Author + Reviewers | ✅ Ratified 2026-04-30 | [`docs/SIMULATION_CONTRACT.md`](docs/SIMULATION_CONTRACT.md) |
| 2 | **Before Phase 0** | State Machine Contract | engine-architect + ai-engineer | Constraint Negotiation | ✅ Ratified 2026-04-30 | [`docs/STATE_MACHINE_CONTRACT.md`](docs/STATE_MACHINE_CONTRACT.md) |
| 3 | **Before Phase 0** | Testing Contract | qa-engineer + engine-architect + balance-engineer | Author + Reviewers | ✅ Ratified 2026-04-30 | [`docs/TESTING_CONTRACT.md`](docs/TESTING_CONTRACT.md) |
| 4 | **Before Phase 3** | Resource Node Schema | world-builder + gameplay-systems | Constraint Negotiation | ✅ Ratified 2026-04-30 (v1.1) | [`docs/RESOURCE_NODE_CONTRACT.md`](docs/RESOURCE_NODE_CONTRACT.md) |
| 5 | **Before Phase 6** | Difficulty Tuning | ai-engineer + balance-engineer | Open Consultation | ✅ Ratified 2026-05-01 | [`docs/AI_DIFFICULTY.md`](docs/AI_DIFFICULTY.md) (1.0.0) |
| **C** | **Before Phase 0 implementation** | **Convergence Review** | **All 7 agents** | **Convergence Review (Pattern E)** | ✅ **Ratified 2026-05-01** | **12 P0 items resolved across 5 revision passes. Sim 1.2.0, Testing 1.4.0, RNC 1.1.1, AI Difficulty 1.1.0. State Machine 1.0.0 unchanged.** |

The full sync log with retros lives in `STUDIO_PROCESS.md` §10.

### Day-to-Day Coordination (Outside Scheduled Syncs)

- Default to **isolation mode** — agents work on owned files in parallel
- Cross-agent requests via `SendMessage` (point-to-point, not broadcast)
- For unblocked questions, agent makes the call and documents in code
- For design questions (gameplay/feel/balance/narrative), append to `QUESTIONS_FOR_DESIGN.md`

---

## 10. Open Questions for the Design Chat

The team review surfaced several questions that affect gameplay/feel/balance and exceed implementation authority. These should be appended to `QUESTIONS_FOR_DESIGN.md` when each phase touches them:

| # | Question | Surfaced By | Affects | Timing |
|---|----------|-------------|---------|--------|
| 1 | **Snowball protection definition (§4.3)**: "3:1 army ratio" by unit count, population cost, or combat power? | gameplay-systems | Phase 4 implementation | Before Phase 4 |
| 2 | **Snowball protection: "broken economy" threshold** — what state qualifies (no production buildings? no workers? both?) | gameplay-systems | Phase 4 implementation | Before Phase 4 |
| 3 | **AI difficulty wave cadence** — confirm Easy/Normal/Hard cadences (180s/120s/90s proposed by ai-engineer) | ai-engineer | Phase 6 | Before Phase 6 |
| 4 | **Camera lock confirmation** — confirm fixed isometric (no rotation) for MVP | ui-developer | Phase 0 | Before Phase 0 (urgent) |
| 5 | **Horse archers in Phase 2 vs 4** — should Asb-savar Kamandar ship in Phase 2 at Tier-1-equivalent stats (kiting case exposed early) or stay Tier 2 (combat math gets revisited)? | gameplay-systems | Phase 2 vs Phase 4 | Before Phase 2 |

---

## 11. What This Plan Does NOT Cover

These are explicitly post-MVP and should not be started until Phase 8 is complete:

- Multiple maps
- Multiplayer / networking
- Campaign missions
- Pahlavan duels
- Turan as playable (Zur system)
- Divs faction
- Persian-language UI (infrastructure is built in Phase 0, content is Tier 2)
- Sound design beyond placeholders
- Save/load
- Multiple heroes
- Simurgh summon, Derafsh-e-Kaviani banner, war elephants
- Real art assets (everything stays as colored shapes until the loop is fun)

---

*This plan is a living document. Update it as we learn. The numbers will change. The order might shift. The scope will not expand.*
