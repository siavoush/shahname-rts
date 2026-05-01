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
last_updated: 2026-04-30
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
