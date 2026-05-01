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
last_updated: 2026-05-01
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
