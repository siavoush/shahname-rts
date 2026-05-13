---
title: Phase 3 Kickoff — Economy, Dummy AI, Fog Data Layer
type: plan
status: living
version: 1.1.0
owner: team
summary: Phase 3 session-1 recipe — the full economic loop (Kargar gathering, Coin mines, Fertile fields, ResourceSystem, building placement) + a DummyAIController for the Turan side + fog-of-war data layer (boolean grid, no shader). Includes Experiments 01, 02 (permanent), 03 (sequential single-agent permanent; parallel-agent commit-race deferred to Experiment 04), and the L13 pre-flight blocker.
audience: all
read_when: starting-phase-3
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md, docs/RESOURCE_NODE_CONTRACT.md]
ssot_for:
  - Phase 3 session-1 reading order
  - Phase 3 scoped slice and per-deliverable owner mapping
  - Phase 3 wave breakdown
  - Phase 3 Definition of Done
  - L13 pre-flight blocker (MatchHarness migration) wave-0 scope
  - Open Space sync queue (Pitfall #7 mitigation, auto-attack stances, Farr drain rates, §1.3/§1.5 contract gaps)
references: [02_IMPLEMENTATION_PLAN.md, 02e_PHASE_2_SESSION_2_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, docs/RESOURCE_NODE_CONTRACT.md, BUILD_LOG.md]
tags: [phase-3, kickoff, economy, dummy-ai, fog, kargar, resource-nodes, buildings, recipe]
created: 2026-05-12
last_updated: 2026-05-13
---

# Phase 3 Kickoff — Economy, Dummy AI, Fog Data Layer

> **Mode:** implementation, with one design-mode sync block (Open Space) BEFORE wave 1. Per `docs/STUDIO_PROCESS.md` §12, implementation mode is dispatch-and-report. **Two permanent experiments now in §9 (Wave-close review, Per-TDD-cycle commits + anti-loop language). Two active experiments to track: Experiment 01 (live-game-broken-surface, second confirming session needed for graduation) and Experiment 04 (parallel-agent commit-race mitigation, first formal trial).**

## 0. Why this doc exists

Phase 2 shipped combat. Phase 3 ships the economy under it: workers gather Coin and Grain, deliver to the Throne, the player builds Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh, produces Piyade on a timer, and a `DummyAIController` does the same on the Turan side so the lead can solo-test. Plus a fog-of-war DATA layer (boolean visibility grid, no shader yet — that's Phase 5 art).

This doc is **Phase 3 session-1 specific.** Subsequent Phase 3 sessions read `BUILD_LOG.md` for state.

## 1. Phase 3 reading order (≈15 minutes — Phase 3 has more new contracts than Phase 2 did)

1. **`MANIFESTO.md`** — principles. Architecture-reviewer grades against these.
2. **`CLAUDE.md`** — file ownership, escalation, the Farr chokepoint (`apply_farr_change` is the only sanctioned Farr mutation; Phase 3 wires worker-killed-idle drain to it for the first time AT SCALE — every Kargar idle death now flows through).
3. **`docs/ARCHITECTURE.md`** — orientation layer.
   - §2 Build State — Phase 2 rows are ✅ Built. Phase 3 rows in `📋 Planned` are your wave-1 targets.
   - §7 LATER index — **L13 is now 🔴 Phase 3 pre-flight blocker.** L20 is 🔴 Open Space sync (Pitfall #7 SSOT). L1, L2, L3 (UnitRegistry, MovementSystem, CombatSystem coordinators) are still scale-blocking but DEFERRED until specific pressure points emerge.
4. **`docs/STUDIO_PROCESS.md`** §9 (active rules). Read the four 2026-05-12 entries first — they're the binding patterns for THIS session.
5. **`docs/PROCESS_EXPERIMENTS.md`** — Known Godot Pitfalls list (11 entries now, #11 is the queue_free + _test_run_tick interaction). Two graduated experiments (02 + 03 sequential portion). Two active (01 + 04).
6. **`docs/RESOURCE_NODE_CONTRACT.md`** (1.1.0) — Phase 3's foundational contract. ResourceNode hierarchy, dual-mode payload, navmesh bake at scene-load only, NavigationObstacle3D for runtime carving. Read in full.
7. **`02_IMPLEMENTATION_PLAN.md`** §184 — Phase 3 task list.
8. **`docs/STATE_MACHINE_CONTRACT.md`** — `Kargar` gets a `Gathering` state this phase. Plus `Constructing`. Read §3.4 (transition_to_next) and §6.2 (worked example).
9. **`docs/SIMULATION_CONTRACT.md`** §1 (the rule), §1.5 (UI off-tick), §1.6 (fixed-point — gather rates and resource counts both use this), §3 (SpatialIndex — gather-radius queries), §4 (IPathScheduler — Kargar pathing to resource nodes).
10. **`BUILD_LOG.md`** — Phase 2 session 2 final entries + retro entries (PR #10 if/when this retro merges).
11. **This doc** for the wave breakdown and Open Space sync agenda.

## 2. Open Space sync (RESOLVED 2026-05-13)

Per `STUDIO_PROCESS.md` §12 (operating-modes split), this was the design-mode window between Phase 2 close and Phase 3 wave 1. Five topics resolved via Constraint Negotiation / Open Consultation / lead-drafted addenda. Decisions captured in `docs/ARCHITECTURE.md` §6 v0.20.0 entry; this section summarizes them inline so a fresh Phase 3 agent doesn't need to cross-reference.

### Resolutions summary (all decisions live; wave-1 briefs reference these)

| Topic | Pattern | Decision | Lands in |
|---|---|---|---|
| Pitfall #7 mitigation | Constraint Negotiation (engine-architect + gameplay-systems) | **Option 1 hybrid:** `git worktree`-per-agent for parallel waves + sequential-shared-tree for single-deliverable / heavy-shared-doc waves. Option 2 (commit serialization) VETOED. | `STUDIO_PROCESS.md` §9 2026-05-13 + Experiment 04 (Phase 3 sess 2 first trial) |
| `Unit.stance` spec | Open Consultation (ai-engineer single authority) | Field on `Unit` base class (NOT CombatComponent). Phase 3: PASSIVE-only with DummyAIController reader. Phase 6: defensive/aggressive as AI/component glue (not FSM extension). | `Constants.STANCE_*` + `Unit.stance` field (Phase 3 sess 2 wave) |
| Farr drain rates | Constraint Negotiation (balance-engineer drafted, gameplay-systems agreed) | Positive-magnitude dict in `BalanceData.farr.drain_rates`; negative sign at call site. Phase 3 wires `worker_killed_idle` (1.0) + `worker_killed_during_gather` (0.5). Forward-compat entries for capital/buildings/hero. | `FarrConfig.drain_rates` schema (Phase 3 wave 1B) |
| Sim Contract §1.3 init-time carve-out | Lead-drafted addendum | Parent `_ready` writes to child component fields via plain `set()` pre-first-tick exempt from self-only-mutation. | `SIMULATION_CONTRACT.md` 1.4.0 §1.3 |
| Sim Contract §1.5 UI-local tween carve-out | Lead-drafted addendum | Tweens writing ONLY to UI-local state (sim never reads) exempt from queue-then-drain. Sim-state tweens still require deferral. | `SIMULATION_CONTRACT.md` 1.4.0 §1.5 |

**Critical implementation note for Phase 3 wave 1B (Farr-drain wiring):** the drain handler must read FSM `current.id` BEFORE the `Dying` state swap (State Machine §4.2). Subscribe to `EventBus.unit_health_zero` (pre-preempt) OR have the FSM stamp `last_alive_state_id` before swap. If the handler subscribes to `unit_died` (emitted from `Dying.enter()`), every death looks like state.id == `&"dying"` and the two drain keys collapse. gameplay-systems flagged this as the load-bearing implementation gotcha.

---

### Historical record of the queued topics (for archaeology)

The five topics, as originally queued before the sync:

### 2.1. **Pitfall #7 structural mitigation** (L20)

**Decision required.** Three confirmed cross-agent commit-staging race occurrences across two sessions. Two structural alternatives:

- **Worktree-per-agent.** Each parallel agent operates in `git worktree add <branch> ../<agent-name>` with its own working tree, sharing `.git`. Eliminates the race entirely. Cost: each worktree regenerates Godot .uid caches (~1 min); lead must create worktrees at dispatch time; per-worktree pre-commit gates run independently. Per arch-reviewer-p2s2 recommendation, preferred.
- **Lead-orchestrated commit serialization.** Agents finish working-tree changes, then SendMessage `team-lead` with "ready to commit." Lead grants commit-window-of-one to each agent in turn. Cost: extra round-trip per commit, ~5 min added per parallel-agent wave. No infrastructure change.
- **Sequential-only parallel-wave policy (cheapest).** Mandate that any wave touching shared docs (`BUILD_LOG.md`, `ARCHITECTURE.md`) is run as sequential single-agent dispatches, NEVER parallel. Phase 2 session 2's waves 2A / 2B / 3 (sequential) all shipped clean; wave 1 (parallel three) stomped twice. Discipline-only; no infrastructure or workflow change.

**Recommended discussion participants:** lead + engine-architect + gameplay-systems. ~30 min Constraint Negotiation. Output: decision committed to `STUDIO_PROCESS.md` §9 as a new permanent rule. **Becomes Experiment 04's intervention** if "worktree-per-agent" or "commit serialization" wins; closes Experiment 04 as "Modified — sequential-only" if option 3 wins.

### 2.2. **Auto-attack stances** (passive / defensive / aggressive)

**Decision required for Phase 3 because:** `DummyAIController` is in Phase 3's scope. Even a "passive" stance (Turan units don't auto-engage attackers) needs to be DEFINED for the AI controller to consume.

- Phase 3: implement **passive default ONLY** (units only attack on explicit command). The "defensive" and "aggressive" stances ship in Phase 6 alongside `DummyAIController`'s smarts. But the FIELD (`Unit.stance: StringName = &"passive"`) must exist in Phase 3 so the AI controller can read it.

**Recommended:** brief Open Consultation between ai-engineer + lead. ~15 min. Output: spec sketch for `Unit.stance` field + the `passive` semantic. Land as a §6 entry in `ARCHITECTURE.md`.

### 2.3. **Farr drain rates**

**Decision required for Phase 3 because:** Phase 3 ships the first worker economy AT SCALE. Phase 2 session 1's "worker killed idle → -1 Farr" was a single rate placeholder. Phase 3 has multiple drain triggers (worker killed idle, building destroyed, capital damaged, etc.).

**Recommended:** Constraint Negotiation between balance-engineer + lead + gameplay-systems. ~20 min. Output: drain-rate table in `BalanceData.farr_config.drain_rates: Dictionary[StringName, float]`. Lands in `balance.tres`.

### 2.4. **Sim Contract §1.3 init-time carve-out**

**Spec gap flagged by arch-reviewer-p2s2.** The pattern "parent Unit's `_apply_balance_data_defaults` sets fields on child components via plain `set()` during `_ready` BEFORE any tick begins" is precedent across multiple components but NOT formally carved out in the contract. Phase 3 adds at least 4 new init-time component wirings (Kargar's gathering state, building components, AI controller registration). Without a carve-out, agents will either re-derive the pattern OR over-engineer with proper `_set_sim` chokepoints.

**Recommended:** lead drafts a one-paragraph addendum to `docs/SIMULATION_CONTRACT.md` §1.3:

> "Init-time component wiring (parent `_ready` writes to child component fields via plain `set()` BEFORE any tick begins) is exempt from the self-only-mutation rule. The exemption applies ONLY before `SimClock` has run its first tick; runtime component-to-component writes still require method-call discipline."

Bump Sim Contract to 1.3.0. No discussion needed unless contract owners object.

### 2.5. **Sim Contract §1.5 tween-in-callback tension**

**Spec gap flagged by both reviewers in Phase 1 session 2 + arch-reviewer-p2s2 in Phase 2 session 2.** Tweens that write to UI-local state (e.g., FarrGauge `_displayed_farr`, SelectedUnitPanel HP bar interpolation) are started inside signal handlers. Strict §1.5 reading forbids this. Practical reading: UI-local tweens with no path back into sim state are allowed.

**Recommended:** lead drafts an addendum to `docs/SIMULATION_CONTRACT.md` §1.5:

> "Tweens that write ONLY to UI-local state (fields not read by any sim consumer) may be started inside signal handlers. Tweens writing to sim-state fields must use queue-then-drain (next-frame deferral via `call_deferred`)."

Bump Sim Contract to 1.4.0 (combining with §2.4 above for one revision). No discussion needed unless contract owners object.

## 3. The Phase 3 session-1 scoped slice

Phase 3's full task list (per `02_IMPLEMENTATION_PLAN.md` §184) is large — ~15 deliverables. Session-1 attacks the **economic loop's foundation**: workers can gather, return, deposit, and the player can place ONE building type (Throne is the trivial existing case; this session adds Khaneh) using the placement system. DummyAI and fog data layer ship in session 2.

### Session-1 deliverables (in dependency order)

**Wave 0 (PRE-FLIGHT — blocking): MatchHarness migration**

Per L13 escalation. Phase 2's two integration test files (`test_phase_2_session_1_combat.gd` + `test_phase_2_session_2_rps_combat.gd`) both bypass `MatchHarness` per Testing Contract §3.1. Drift is self-propagating: a third file will follow if not blocked.

**Owner:** qa-engineer (single agent, sequential).

**Scope:** migrate both integration files to use `MatchHarness`. The harness already exposes `start_match(seed, scenario)`, `advance_ticks(n)`, `snapshot()`, `_test_set_farr(value)`, `teardown()`. Replace manual `before_each` autoload reset with `harness.start_match(seed, scenario)`; replace manual tick driving with `harness.advance_ticks(n)`.

**Live-game-broken-surface:** harness `reset()` covers all autoloads (per TESTING_CONTRACT.md). If a test's manual setup wrote state the harness doesn't reset, migrating it would leak between tests. **Mitigation:** run the migrated suite three times in a row and verify no test-order-dependent failures.

**Done means:** both files use MatchHarness; all 896 tests still pass; no new failures; lint clean.

**Wave 1A — `Kargar` gathering state + `Coin` mine ResourceNode**

Two deliverables, one agent, sequential.

**Iran Kargar gathering state.** New `UnitState_Gathering` (FSM state) — Kargar walks to assigned resource node, dwells N ticks (per BalanceData), increments `_held_resource_x100`, transitions to returning state when held cap reached. New `UnitState_Returning` — Kargar walks back to Throne, dwells, deposits `_held_resource_x100` into `ResourceSystem`, transitions back to gathering. Loop forever or until interrupted.

**Coin mine ResourceNode.** New `MineNode` class extending the (still-to-build) `ResourceNode` base. Visual: yellow cylinder on the ground (placeholder per CLAUDE.md). Finite reserves per BalanceData. Vanishes via `queue_free.call_deferred()` (Pitfall #8/#11 awareness) when empty. Spawns 5-10 at known map positions in `main.gd::_spawn_starting_resources` (new method).

**Owner:** gameplay-systems + world-builder (gameplay-systems writes the state machine work; world-builder writes the MineNode visual + spawn helper). Per the new sequential-single-agent rule until Pitfall #7 is structurally resolved, ONE agent ships both. gameplay-systems drives, world-builder consulted for the spawn-position math + visual color.

**Live-game-broken-surface:**
1. Runtime: Kargar's FSM tick must drive both Gathering and Returning states correctly (`Unit._on_sim_phase` transitional driver — wave-1A inherits this). The new states must register in `Unit._ready` BEFORE `super._ready()` per the established pattern.
2. Headless-undetectable: visual readability — Coin mine yellow cylinder must distinguish from Kargar sandy cylinder. Worker animations during dwell (subtle pulse?) — Phase 5 polish; not session 1.
3. Min interactive smoke test: lead boots, 5 Coin mines spawn, 5 Kargar idle near Throne. Lead right-clicks a Coin mine with a selected Kargar → Kargar walks to mine, dwells, walks back to Throne, deposits, walks back to mine. Loop visible. Coin counter in HUD increments.

**Wave 1B — `ResourceSystem` autoload + HUD wire-up**

`ResourceSystem` (autoload) tracks `coin_x100: int`, `grain_x100: int`, `population: int`, `population_cap: int` per team. Exposes typed signals `EventBus.resource_changed(team, kind, delta_x100, new_total_x100)`. The new Throne `BuildingComponent`'s deposit method routes through here.

HUD wire-up: extend `resource_hud.tscn` Coin/Grain labels to read from `ResourceSystem.coin_x100 / 100.0` and `grain_x100 / 100.0`. The current placeholder labels read 0 — wire them to the live system.

**Owner:** gameplay-systems + ui-developer. Sequential single-agent (gameplay-systems writes the autoload + signal; ui-developer wires the HUD in a subsequent dispatch).

**Live-game-broken-surface:**
1. Runtime: the Farr chokepoint pattern repeats. ResourceSystem's `apply_resource_change(team, kind, amount, reason, source_unit)` is the single sanctioned write seam. NO other code writes `_coin_x100` directly. CLAUDE.md mandates this for Farr; project-consistency mandates the same for resources.
2. Headless-undetectable: HUD labels updating live — does the counter tick smoothly or pop in chunks? Should the change animate? Phase 5 polish.
3. Min interactive smoke test: lead deposits one Kargar's load → HUD Coin counter increments by the deposit amount. Counter shows fractional value per `_x100` fixed-point convention.

**Wave 1C — `Khaneh` building + placement system foundation**

The Khaneh (house) is the simplest building — flat cost, no production output, just contributes to `population_cap`. Phase 3 wants a worker selecting a build menu → ghost preview → click map → confirm → worker walks there and builds. Session 1 ships **only the placement-skeleton path** with Khaneh as the smoke-test target. Construction timer + progress bar lands in session 2.

**Owner:** gameplay-systems + ui-developer + world-builder. Three roles but sequential single-agent dispatch (per the sequential-only rule until Pitfall #7 resolves). Order: gameplay-systems (BuildingPlacement state machine + Khaneh class) → ui-developer (build menu UI) → world-builder (NavigationObstacle3D integration).

**Live-game-broken-surface:**
1. Runtime: NavigationObstacle3D dynamic carving on Khaneh placement is the critical runtime behavior. `RESOURCE_NODE_CONTRACT.md` §3.2 forbids navmesh rebake at runtime; obstacle carving is the sanctioned alternative. If misimplemented, units route THROUGH buildings.
2. Headless-undetectable: ghost preview color (green = valid, red = invalid) must read clearly against sandy terrain. Pitfall #1 (mouse_filter) for the build-menu Controls.
3. Min interactive smoke test: lead selects Kargar → build menu shows Khaneh with cost → lead clicks valid terrain → green ghost preview → click to confirm → Kargar walks to spot, dwells, Khaneh appears. Population cap increases.

**Wave 3 — qa integration tests** (after waves 1A/B/C all land)

Coverage targets:
- Full gather→deposit cycle (Kargar walks to MineNode, gathers, returns, deposits, repeats).
- ResourceSystem chokepoint correctness (apply_resource_change is sole write seam; direct writes forbidden).
- Building placement: ghost → confirm → construct → NavigationObstacle3D carved.
- Khaneh contribution to population_cap.
- Cross-feature smoke: Phase 2 combat + Phase 3 gather loop coexist (combat-units defending workers).

### Wave-close review (Experiment 02, now permanent)

After wave 3 lands: lead dispatches both reviewer agents in parallel, they post structured reviews via `gh pr review --comment`, blocking issues route back, lead live-tests, PR opens.

### Definition of Done

A future-you opens the project on macOS, F5, and:

1. Sees 33 Phase 2 units + 5-10 Coin mines + some Fertile zones (Fertile is Phase 3 session 2 if it slips). 5 Kargar workers idle near Throne.
2. Right-click Coin mine with selected Kargar → Kargar walks, dwells, returns, deposits. HUD Coin counter increments. Loop visible.
3. Select Kargar → build menu shows Khaneh → click valid terrain → ghost preview → confirm → Khaneh appears. Population cap increases.
4. F4 attack-range circles still work (Phase 2 regression).
5. Box-select + control groups + RPS combat all still work.
6. Tests pass headless: target ≥950 tests (+50 from Phase 2 sess 2's 896). Lint clean. Pre-commit gate green.
7. **Wave-close review** by both reviewer agents — APPROVE.
8. `docs/ARCHITECTURE.md` §2 reflects new build state.
9. Experiment 01 verdict filled (2nd confirming session — candidate for graduation).
10. Experiment 04 verdict filled (1st formal trial).

### What's deliberately NOT in session 1

- Mazra'eh (fertile-tile farms), Ma'dan (mine extraction efficiency), Sarbaz-khaneh (unit production) — Phase 3 session 2.
- `DummyAIController` — Phase 3 session 2.
- Fog-of-war data layer — Phase 3 session 2.
- Construction timer + progress bar — Phase 3 session 2.
- Real building art — until design chat green-lights.

## 4. Wave breakdown

Per the **sequential-only rule** for waves touching shared docs (until Pitfall #7 is structurally resolved):

- **Wave 0 (pre-flight):** qa-engineer migrates the two Phase 2 integration files to MatchHarness. ~30 min. Lead live-test of test suite (no game changes).
- **Wave 1A:** gameplay-systems ships Kargar gathering state + Coin MineNode. Single agent, ~60 min.
- **Wave 1B:** gameplay-systems ships ResourceSystem autoload. Then ui-developer wires HUD. Both single-agent, sequential.
- **Wave 1C:** gameplay-systems ships Khaneh + placement state. Then ui-developer ships build menu. Then world-builder wires NavigationObstacle3D. All single-agent, sequential.
- **Wave 3:** qa-engineer ships integration tests.
- **Wave-close review:** parallel (two reviewers are read-only; no commit race).
- **Lead live-test + PR.**

## 5. Anti-loop brief language (PERMANENT — STUDIO_PROCESS §9 2026-05-04, reconfirmed 2026-05-12)

EVERY agent dispatch brief includes the explicit cycle:

> "Cycle: implement → pre-commit gate → `git diff --staged --stat` shows ONLY your files → commit → `git log -1` confirms your SHA → THEN report back. Don't issue 'task already shipped, standing down' reports. If you think work exists, run `git log` and check author/SHA."

## 6. Per-TDD-cycle commits (PERMANENT — STUDIO_PROCESS §9 2026-05-12)

> "Commit per TDD cycle: after each `red → green → refactor` sequence, run pre-commit gate, stage your specific files, commit. Do NOT batch commits at end-of-wave."

## 7. Shared-doc `git diff` verification (PERMANENT — STUDIO_PROCESS §9 2026-05-04)

Before staging any shared append-only doc (`BUILD_LOG.md`, `docs/ARCHITECTURE.md`, `docs/PROCESS_EXPERIMENTS.md`, `docs/STUDIO_PROCESS.md`), agents run `git diff <doc-file>` and confirm only their additions.

## 8. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + §1 reading order).
2. **Run the Open Space sync** (§2). Decisions feed into wave-1 dispatch briefs.
3. Verify branch state — `feat/phase-3-session-1`.
4. Read `BUILD_LOG.md` for Phase 2 session 2 final state + retro entries.
5. Read 11 Known Godot Pitfalls in `PROCESS_EXPERIMENTS.md`.

**During session:**
1. Wave 0 (qa pre-flight) — first.
2. Waves 1A/B/C sequentially (sequential-only until Pitfall #7 resolves).
3. Per-TDD-cycle commits per the §9 rule.
4. Wave 3 qa integration.
5. Wave-close review (parallel; reviewers are read-only).
6. Lead live-test before PR.

**End of session:**
1. Lead live-test passes.
2. Lead fills Experiment 01 + 04 verdicts.
3. **Session-close retro** (the now-permanent structured task) before next session.
4. PR.

## 9. After Phase 3 session 1

Phase 3 session 2 picks up Mazra'eh / Ma'dan / Sarbaz-khaneh, DummyAIController, fog data layer, construction timers. Session 3 (if needed) adds polish. Phase 4 (mid-game + Tier 2 tech tree) starts when session 2 or 3 ships.

---

*This doc is Phase 3 session-1-specific. After session 1, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state + §7 LATER index) + the implementation plan (Phase 3 task list).*
