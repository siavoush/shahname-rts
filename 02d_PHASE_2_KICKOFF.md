---
title: Phase 2 Kickoff — Combat Core (Sword Before The Story)
type: plan
status: living
version: 1.0.0
owner: team
summary: Phase 2 session-1 recipe — combat core. First cross-team fighting in the project. Mirror combat (Iran Piyade vs Turan Piyade) before the full RPS roster lands. Includes Experiment 01 (live-game-broken-surface section per deliverable, with Known Godot Pitfalls checklist) and Experiment 02 (wave-close review by godot-code-reviewer + architecture-reviewer before PR).
audience: all
read_when: starting-phase-2-session-1
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md, 02b_PHASE_1_KICKOFF.md, 02c_PHASE_1_SESSION_2_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md]
ssot_for:
  - Phase 2 session-1 reading order
  - Phase 2 session-1 scoped slice and per-deliverable owner mapping
  - Phase 2 session-1 wave breakdown and dependency order
  - Phase 2 session-1 Definition of Done
  - the combat-core scope (vs. multi-unit-type roster which is session 2)
  - Experiment 02 application surface (wave-close review)
references: [02_IMPLEMENTATION_PLAN.md, 02b_PHASE_1_KICKOFF.md, 02c_PHASE_1_SESSION_2_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, BUILD_LOG.md]
tags: [phase-2, session-1, combat, attack-move, health-bars, kickoff, recipe]
created: 2026-05-03
last_updated: 2026-05-03
---

# Phase 2 Kickoff — Combat Core

> **Mode:** implementation. Per `docs/STUDIO_PROCESS.md` §12, the studio process (syncs, OST patterns, Convergence Review) is dormant during implementation. Specialists work independently in their owned files using TDD discipline. **Two active experiments:** Experiment 01 (live-game-broken-surface section per deliverable, kept-with-refinement after session 2) and Experiment 02 (wave-close review by two reviewer agents).

## 0. Why this doc exists

Phase 2's theme is *"the sword before the story."* It's where the simulation gets a teeth-and-claws layer — units that take damage, units that die, hero death positions captured for Phase 5's Yadgar building. Combat is the first system that exercises the rock-paper-scissors design that defines the game's feel.

**Phase 2 is too big for one session.** Per `02_IMPLEMENTATION_PLAN.md` §155–180, the full Phase 2 milestone includes Piyade + Kamandar + Savar + Asb-savar Kamandar + Turan mirrors + the RPS matrix + control groups + multi-select panel + double-click select-of-type (the last three already shipped in Phase 1 session 2). That's a 2-session arc minimum.

**This doc is session-1 only.** Session 1 ships the **combat core** with a scoped milestone: 5 Iran Piyade vs 5 Turan Piyade — mirror combat, same stats both sides. Right-click an enemy, units fight, units die, health bars update, F4 shows attack ranges. The full RPS roster + 3 new Iran types + Turan mirrors + RPS effectiveness matrix lands in Phase 2 session 2.

**This doc is session-1-specific.** Subsequent Phase 2 sessions read `BUILD_LOG.md` for state and pick up from there.

## 1. Session-1 reading order (≈12 minutes)

1. **`MANIFESTO.md`** — principles. Constants behind every other rule. The architecture-reviewer will grade your work against these by name.
2. **`CLAUDE.md`** — project instructions, file ownership, escalation rules.
3. **`docs/ARCHITECTURE.md`** — orientation layer. After Phase 1 session 2 merge, the unit core / selection / multi-select / formation movement rows are `✅ Built`. Phase 2 rows still `📋 Planned` are what you're picking up.
4. **`docs/STUDIO_PROCESS.md`** §9 (active rules) and §12 (operating modes). **§9's most recent entry — wave-close review — is now in force. Read it.** It changes the workflow at end-of-wave: lead spawns `godot-code-reviewer` and `architecture-reviewer` before opening the PR.
5. **`docs/PROCESS_EXPERIMENTS.md`** — both experiments (01 live-game-broken-surface; 02 wave-close review). Your kickoff brief here includes the live-game-broken-surface section per deliverable (Experiment 01 active). Your wave's commits get reviewed by both agents at wave close (Experiment 02 active).
6. **`02_IMPLEMENTATION_PLAN.md`** §155–180 — Phase 2 task list and milestone test. The session-1 scope is a subset; the milestone test in this doc is ALSO a subset (mirror combat).
7. **`docs/STATE_MACHINE_CONTRACT.md`** — your unit-state framework. Session 1 adds `UnitState_Attacking` and the Moving → Attacking transition. Read §3.4 (transition_to_next + current_command) and §3.5 (interrupt levels — combat units' `interrupt_level = NONE` so a fresh attack command preempts current movement).
8. **`docs/SIMULATION_CONTRACT.md`** §1 (the rule), §1.5 (UI off-tick rule), §3 (SpatialIndex — combat queries enemies in attack range), §4 (IPathScheduler — Moving state still drives movement before Attacking takes over).
9. **`docs/TESTING_CONTRACT.md`** — `MatchHarness` API for combat integration tests. The harness already supports `spawn_unit` (Phase 1 session 1 unblocked it); use it.
10. **`BUILD_LOG.md`** — what shipped in Phase 1 session 2. Especially relevant: the `cb95d09` re-entrant signal recursion bug (Known Pitfall #4). Combat code that subscribes to `EventBus.unit_died` should NOT mutate the same emitter (or related state-holders that also have listeners) from inside the handler.
11. **This doc** — for the scoped slice, dependency order, wave breakdown, Experiment 01 surface, and Experiment 02 wave-close.
12. **(Optional, for the gameplay-systems agent only):** `01_CORE_MECHANICS.md` §2 (units) and §5 (combat) for the Shahnameh-rooted design intent.

## 2. The Session-1 scoped slice

Phase 2's full task list is too much for one session. Session 1 attacks **the combat core** — the smallest end-to-end RTS combat gesture: select a friendly, right-click an enemy, watch them fight, watch them die.

### Session-1 deliverables (with owners and live-game-broken-surface checklist)

Per Experiment 01 (now permanent until graduated): every deliverable below includes a `Live-game-broken-surface` block. The owning agent must answer all three questions in their commit body or BUILD_LOG entry before declaring done. Headless tests + this block are the agent's quality bar.

The **Known Godot Pitfalls** list (in `docs/PROCESS_EXPERIMENTS.md` Experiment 01's verdict section) is your additional checklist. Currently 4 entries: mouse_filter, FSM tick wiring, camera basis transform, re-entrant signal mutation. Each new pitfall surfaced this session gets appended to the list.

---

#### 1. `CombatComponent` — damage, attack speed, range

A new component on Unit (sibling to HealthComponent, MovementComponent, etc.). Holds:
- `attack_damage_x100: int` (fixed-point per Sim Contract §1.6)
- `attack_speed_per_sec: float` (attacks per second)
- `attack_range: float` (world units)
- `_attack_cooldown_x100: int` (fixed-point — ticks until next attack ready)
- `_target_unit_id: int` (-1 sentinel)
- Public method `set_target(unit_id: int)`.
- `_sim_tick(dt)` — if a target is set AND in range AND off cooldown, call `target.get_health().take_damage(attack_damage_x100)` and reset cooldown. Cooldown decrements via dt.

Reads stats from `BalanceData.units[unit_type]` at unit `_ready` (alongside HP and move_speed).

**Owner:** gameplay-systems.

**Reads:** `docs/STATE_MACHINE_CONTRACT.md` §3 (state lifecycle), `docs/SIMULATION_CONTRACT.md` §3 (SpatialIndex range queries — for finding targets), `game/scripts/units/components/health_component.gd` (existing damage path — verify it has `take_damage`; if not, you're adding it as part of this deliverable).

**Writes:** `game/scripts/units/components/combat_component.gd` (new), updates to `game/scenes/units/unit.tscn` (add CombatComponent child), `game/scripts/units/components/health_component.gd` (add `take_damage(damage_x100)` if missing — wraps `_apply_damage` chokepoint).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The combat component's `_sim_tick` must be called by the FSM tick driver (`Unit._on_sim_phase` from session 1). Verify CombatComponent extends SimNode and is reached by the unit's tick chain. Off-tick mutation of `_attack_cooldown_x100` would silently fail under headless determinism tests but show up as units that never actually attack.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Combat *feel* — does an attack at range = 5 look right at default zoom? Are the attack-cooldown values (set in BalanceData) appropriate so combat resolves in 5–15 seconds, not 2 or 60? Whether a unit "freezes" briefly mid-move when it transitions to Attacking.
3. *What's the minimum interactive smoke test that catches it?*
   Lead spawns 5 Iran Piyade and 5 Turan Piyade. Selects Iran. Right-clicks an enemy. Watches Iran approach, then attack. HP bars decrement. One side wins. Combat resolves in a sensible time window.

**Out of scope here:** attack animations (Phase 5 polish), damage numbers floating up (Phase 5 polish), critical hits (post-MVP).

---

#### 2. `UnitState_Attacking` + attack command

A new concrete UnitState. Triggered by:
- **Right-click on an enemy unit** (extending `click_handler.gd::_handle_right_click`): if the hit is a unit AND its team != active player's team, build an Attack command (`kind = &"attack"`, `payload = { &"target_unit_id": int }`) and push to selected units' command queues via `Unit.replace_command`.
- **AI panic-retreat or attack-target reassignment** (Phase 6 — out of scope here).

`UnitState_Attacking.enter(prev, ctx)` reads `ctx.current_command["payload"]["target_unit_id"]`. Looks up the target via SpatialIndex or a unit registry. If target invalid (freed, or not found): transition_to_next.

`_sim_tick(dt, ctx)` — if target is OUT of attack range, transition to Moving state with the target's current position as the move target (under-the-hood "move to attack range"). When in range, drive `combat.set_target(target.unit_id)` and let the CombatComponent fire on its own _sim_tick.

`exit()` clears `combat._target_unit_id` (defensive — prevent the unit from continuing to attack after the state ends).

**Interrupt level:** `NONE` — the unit is committed to combat; damage doesn't interrupt the combat itself (only player commands or death do). Confirmed by State Machine Contract §3.5.

**Owner:** ai-engineer.

**Reads:** `docs/STATE_MACHINE_CONTRACT.md` §3.4 + §3.5, `docs/SIMULATION_CONTRACT.md` §3 (SpatialIndex), session-1's `unit_state_moving.gd` for the pattern.

**Writes:** `game/scripts/units/states/unit_state_attacking.gd` (new), updates to `game/scripts/input/click_handler.gd` (add the enemy-right-click branch — currently it's a no-op per session 1's "Phase 2 attack-move case"), `game/scripts/units/unit.gd` (register the state in `_ready`).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The Moving → Attacking transition when target moves out of range. Headless tests fix the target's position; live game has the target moving (e.g., enemy retreating). Verify the Attacking state can re-enter Moving cleanly.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the unit "snaps" to face the target or smoothly walks to it. Whether interrupting an attack by selecting the unit and giving a Move command feels responsive. Whether attack-on-death (target dies mid-combat) feels right or jitters.
3. *What's the minimum interactive smoke test that catches it?*
   Lead selects a unit, right-clicks distant enemy → unit walks, then attacks. Lead right-clicks a different enemy mid-combat → unit retargets cleanly. Lead gives a move command mid-combat → combat interrupts, unit walks to new position.

**Out of scope here:** Attack-move (A+click) — separate deliverable below.

---

#### 3. `HealthComponent.last_death_position` capture + `unit_died` typed signal

When a unit's HP reaches zero, the HealthComponent must:
1. Capture the unit's `global_position` to a public field `last_death_position: Vector3` BEFORE the unit is freed.
2. Emit `EventBus.unit_died(unit_id: int, killer_unit_id: int, cause: StringName, position: Vector3)`.
3. Trigger the unit's StateMachine death-preempt (transition to a `Dying` state, or queue_free directly — your call, but document).

The position field is consumed by Phase 5's Yadgar building (where heroes died → memorial). Cause string is for telemetry/debug overlay (e.g., `&"melee_attack"`, `&"farr_drain"`).

**Owner:** gameplay-systems.

**Reads:** `docs/SIMULATION_CONTRACT.md` §1.6 (fixed-point HP), session-1's `health_component.gd`, `event_bus.gd` (for adding the typed signal).

**Writes:** `game/scripts/autoload/event_bus.gd` (declare `unit_died` signal), `game/scripts/units/components/health_component.gd` (capture position + emit signal), possibly `game/scripts/units/states/unit_state_dying.gd` (new — minimal stub that holds the unit briefly before queue_free, so the death animation has a frame to play in Phase 5+).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The signal listener order: SelectionManager listens to remove-from-selection, panel updates, etc. all on death. Verify the order isn't load-bearing — death emit shouldn't have to fire BEFORE any sim-state-mutating listener (per Sim Contract §1.5 + Known Pitfall #4 about re-entrant signal mutation). Use `call_deferred` if any consumer would mutate a state-holder mid-emit.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the death feels instant (queue_free now) or has a frame's pause for visual feedback. Whether the corpse disappears or fades out. Both are Phase 5 polish but the SHAPE of the deferral matters for now.
3. *What's the minimum interactive smoke test that catches it?*
   Lead's unit kills an enemy → corpse disappears, panel removes the entry, ring (if selected) clears, HP bar (if visible) gone. No errors in console.

**Out of scope here:** death animation (Phase 5), corpse persistence (post-MVP), Yadgar consumption (Phase 5).

---

#### 4. Attack-move command (A + click)

When the player presses `A` while units are selected, then clicks a target position, the Attack-Move command is issued to each unit. Behavior: unit walks toward target; if it encounters an enemy along the way (within an "engage" radius), it pauses to attack the enemy, then resumes the move once the enemy dies (or is out of range).

The command shape: `kind = &"attack_move"`, `payload = { &"target": Vector3 }`. New state OR an extension of `UnitState_Moving` — your call, but lean toward extension (the move logic is identical; the engage check is an addition).

Under the hood, attack-move ticks check `SpatialIndex.query_radius_team(self.position, ENGAGE_RADIUS, OPPOSING_TEAM)` each tick; if a result is found, transition to Attacking with that result as the target. When Attacking exits (target dead), transition_to_next, which dispatches the next queued command (the original `attack_move` payload), resuming movement.

**Owner:** ai-engineer.

**Reads:** session-1's `unit_state_moving.gd`, `docs/SIMULATION_CONTRACT.md` §3, your own `UnitState_Attacking` from deliverable 2.

**Writes:** `game/scripts/units/states/unit_state_attack_move.gd` (new — likely extends `UnitState_Moving`), `game/scripts/input/click_handler.gd` (add A-modifier detection on right-click? OR a dedicated A-click handler — pick whichever fits the existing input layer cleanest), `game/scripts/autoload/constants.gd` (add `ENGAGE_RADIUS` constant).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The "queue the original move under the attack" command-queue trick. Verify command-queue replay correctly works after Attacking ends — that the Moving (or AttackMove) state re-enters with the original target, not a stale value.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the engage radius (`ENGAGE_RADIUS`) feels right — too small and units run past enemies; too large and they engage off-path. Whether multiple units in formation engage the SAME enemy or split sensibly. The latter is subtle and hard to test headlessly.
3. *What's the minimum interactive smoke test that catches it?*
   Lead box-selects 5 Piyade, holds A, clicks across the map. Units walk, encounter 2 enemies en route, engage, kill, continue to original target.

**Out of scope here:** Hold-position command (`H`), patrol command (`P`), formation-aware engagement priority — all Phase 3+.

---

#### 5. First Iran combat unit type — `Piyade` (infantry)

A new concrete Unit type. Same composition pattern as `Kargar`. Stats from `BalanceData.units[&"piyade"]`. Visual: a colored cube (or vertical rectangle) — distinct silhouette from Kargar's cylinder. Iran-blue colored material.

`unit_type = &"piyade"`. Initial stats (final values balance-engineer's call, see deliverable 7):
- max_hp: 100 (1.7× Kargar's 60)
- move_speed: 2.5 (slower than Kargar's 3.5)
- attack_damage: 10 per hit
- attack_speed: 1.0 per second
- attack_range: 1.5 (melee)

**Owner:** gameplay-systems.

**Reads:** session-1's `kargar.gd` and `kargar.tscn` for the inheritance pattern.

**Writes:** `game/scripts/units/piyade.gd` (new), `game/scenes/units/piyade.tscn` (new — inherits unit.tscn, overrides MeshInstance3D + material + script).

**Live-game-broken-surface for this deliverable:** mostly a copy of Kargar's surface — see kargar.gd for the same pattern. Two new things:
1. The CombatComponent's stats must read from BalanceData at `_ready`. Verify the read seam works for a non-Kargar unit_type for the first time.
2. Iran-blue material vs. Kargar's sandy color must be visually distinct.
3. Smoke: lead spawns one of each, sees them as different colors and shapes.

**Out of scope here:** Kamandar, Savar, Asb-savar, Rostam — all Phase 2 session 2.

---

#### 6. First Turan unit type — `Turan_Piyade`

Mirror unit for the Iran Piyade. Same archetype, different team color (Turan-red palette per `01_CORE_MECHANICS.md` §11). Same stats — for session 1, mirror combat is enough to verify the loop. RPS effectiveness lands in session 2.

Place 5 spawned at the start of the match (extending `main.gd::_spawn_starting_kargars` to also spawn 5 Turan_Piyade at the opposite map corner). Match-start formation: Iran kargars + Iran Piyade at one side; Turan Piyade at the opposite side. Lead can right-click across the map to engage.

**Owner:** gameplay-systems.

**Writes:** `game/scripts/units/turan_piyade.gd` (new), `game/scenes/units/turan_piyade.tscn` (new), updates to `game/scripts/main.gd` (spawn 5 of these at opposite map corner with `team = Constants.TEAM_TURAN`).

**Live-game-broken-surface:** the team field plumbing — session 1's Kargars all set `team = Constants.TEAM_IRAN`. Verify a unit with `team = Constants.TEAM_TURAN` is correctly:
- Excluded from box-select (which currently filters Iran-only).
- Targeted by right-click (now that it's an enemy).
- Indexed in SpatialIndex with the right team filter so attack-move can find it.

---

#### 7. BalanceData additions for combat

Add the combat fields to existing UnitStats sub-resource: `attack_damage_x100: int`, `attack_speed_per_sec: float`, `attack_range: float`. Populate the Kargar entry (workers don't attack but the fields exist with attack_damage_x100 = 0), Piyade entry (per deliverable 5's defaults), and Turan_Piyade entry (mirror Iran Piyade).

Add `ENGAGE_RADIUS` to Constants (deliverable 4 also touches it — coordinate).

NO RPS effectiveness matrix in session 1 — it ships in session 2 with the wider unit roster. Document this gap in BalanceData with a TODO.

**Owner:** balance-engineer.

**Writes:** `game/data/sub_resources/unit_stats.gd` (add fields), `game/data/balance.tres` (populate fields for the 3 unit types).

**Live-game-broken-surface:** trivial — pure data. Verify `validate_hard()` and `validate_soft()` pass with the new fields.

---

#### 8. Floating health bars

A small horizontal bar above each unit, showing current/max HP. Subscribes to a per-unit health signal (or polls in `_process` with the existing pattern from `selected_unit_panel.gd`). The bar:
- Renders only when the unit is on screen (use the same `Camera3D.unproject_position` + visibility filter as `box_select_handler.gd`).
- Hidden when HP is full (clean visual default).
- Color-coded: green > 70%, yellow 30-70%, red < 30% (the convention session-2's selected-unit-panel SUGGESTED but didn't follow — close that loop here).
- Width scales with unit-size class (Kargar smaller, Piyade larger).

Implementation: `Sprite3D` with a `Viewport`-based bar texture, OR a `Control` overlay rendered on a per-unit basis with screen-space positioning. Pick whichever is cheaper and simpler.

**Owner:** ui-developer.

**Reads:** `game/scripts/ui/selected_unit_panel.gd` (HP read pattern), `game/scripts/units/components/health_component.gd`.

**Writes:** `game/scenes/ui/health_bar.tscn` (new), `game/scripts/ui/health_bar.gd` (new), updates to `game/scenes/units/unit.tscn` (instance the health bar).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The health bar's visibility flip on HP-full vs damaged. Headless tests can verify state but not visibility. Per-frame screen-projection cost when 50+ units exist.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the bar is readable at default zoom. Whether the green-to-red gradient is sufficiently graded. Whether the bar competes visually with the FarrGauge (top-right) or the SelectedUnitPanel (bottom-left).
3. *What's the minimum interactive smoke test that catches it?*
   Lead's Piyade attacks a Turan Piyade. HP bar fades from green to yellow to red as combat proceeds. Bar disappears when target dies.

**Out of scope here:** Floating damage numbers — Phase 5.

---

#### 9. F4 debug overlay — attack ranges

When F4 is pressed, an overlay renders attack-range circles at the ground around each selected unit. Reads `attack_range` from each unit's CombatComponent. The overlay subscribes to `EventBus.selection_changed` to know which units to render circles for. Toggles via `DebugOverlayManager.handle_function_key(KEY_F4)`.

**Owner:** ui-developer.

**Reads:** `game/scripts/autoload/debug_overlay_manager.gd` (existing F1-F4 framework), `game/scripts/autoload/selection_manager.gd`.

**Writes:** `game/scripts/ui/overlays/attack_range_overlay.gd` (new), `game/scenes/ui/overlays/attack_range_overlay.tscn` (new — likely a `Control` with `_draw` per unit, OR a 3D overlay with cylinders on the ground per unit).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The F4 toggle through the existing DebugOverlayManager. Verify the overlay key is `Constants.OVERLAY_KEY_F4` (already declared in Phase 0).
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the circles render at the right scale, color, and Y-position (visible above terrain but not floating awkwardly).
3. *What's the minimum interactive smoke test that catches it?*
   Lead selects 5 Piyade, hits F4, sees 5 attack-range circles. Hits F4 again, circles disappear.

**Out of scope here:** F1 (pathfinding), F2 (Farr log), F3 (AI state) — all in their owning systems' phases.

---

#### 10. First Farr drain — worker-killed-idle

Per `01_CORE_MECHANICS.md` §4 and the Phase 2 plan (§172), when a Kargar is killed while idle (not engaged in any work), Farr drops by 1.

Implementation: HealthComponent's death emit (deliverable 3) carries the `cause` field. If cause is `&"melee_attack"` AND the dying unit's `unit_type == &"kargar"` AND its `is_idle()`, FarrSystem subscribes to `unit_died` and calls `apply_farr_change(-1.0, "worker_killed_idle", killer_unit_node)`.

**Owner:** gameplay-systems.

**Reads:** `game/scripts/autoload/farr_system.gd`, `game/scripts/units/components/health_component.gd` (your own deliverable 3).

**Writes:** updates to `game/scripts/autoload/farr_system.gd` (add a listener for `unit_died` that conditionally drains).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?*
   The is_idle check at the moment of death (not after the unit is freed). The signal must carry enough info to make this decision without dereferencing the freed unit.
2. *What can a headless test not detect that the lead would notice in the editor?*
   Whether the Farr drop feels appropriate — does losing a worker feel impactful? Tuning is balance-engineer's call but the SHAPE of the feedback (gauge tween, log entry in F2 future-overlay) matters.
3. *What's the minimum interactive smoke test that catches it?*
   Lead's Piyade attacks an idle Kargar. Kargar dies. Farr gauge tweens from 50 to 49. Console log shows `apply_farr_change(-1.0, "worker_killed_idle", ...)`.

**Out of scope here:** Other Farr drains (warrior killed, building lost) — Phase 4. The Kaveh Event itself — Phase 5.

---

#### 11. Combat integration tests

qa-engineer wave-3 territory. Tests cover:
- Single attack → damage applied → HP decrements correctly.
- Cooldown — second attack only fires after `1/attack_speed` seconds.
- Range — attack does NOT fire when target is out of range.
- Death — HP reaches 0 → unit_died emits with correct payload (id, killer, cause, position) → unit is freed.
- `last_death_position` captured BEFORE free.
- Mid-combat retarget — Attacking state correctly handles new attack command.
- Attack-move engages enemies en route, then resumes.
- Worker-killed-idle Farr drain (-1 to FarrSystem).
- Cross-team interactions — Iran can attack Turan, vice versa, but not friendly fire.

**Owner:** qa-engineer (wave 3 separately dispatched after waves 1+2 land).

**Writes:** `game/tests/integration/test_combat_*.gd` files.

**Live-game-broken-surface:** the wave-3 brief explicitly includes the question "what bugs does the lead's live-test surface that your tests didn't?" The reviewers (Experiment 02) will grade test coverage of the live-property the lead would see.

---

### Definition of Done for Phase 2 session 1

A future-you (or any agent) opens the project on macOS Apple Silicon and:

1. Launches the game (F5 in editor).
2. Sees 5 Iran Kargars (sandy cylinders) + 5 Iran Piyade (blue cubes) on one side, 5 Turan Piyade (red cubes) on the other side.
3. Box-selects all 5 Iran Piyade (existing session-2 capability).
4. Right-clicks a Turan Piyade → all 5 walk to engage, then attack.
5. Health bars float above each unit, decrementing as they take damage.
6. Hits F4 → attack-range circles render around the selected Iran Piyade.
7. Iran Piyade kill the Turan Piyade (or vice versa — mirror combat). Death captures position.
8. Right-clicks a Turan Piyade with one Iran Piyade selected → that Piyade engages alone.
9. Box-selects 3 Iran Piyade, hits A, clicks across the map → all 3 walk; if they encounter an enemy en route, they engage; once the enemy dies, they resume to original target.
10. Iran Piyade attacks an idle Iran Kargar (friendly fire? — check this. If no friendly fire allowed, this is a no-op; otherwise the worker dies and Farr drops by 1). **Open question:** is friendly fire allowed in Phase 2 session 1, or is that explicitly disabled? Default to disabled — only attack enemies. Friendly fire (deliberate by a hero) is later phase.
11. A Turan Piyade attacks an idle Iran Kargar → Kargar dies → Farr drops 50 → 49 in the HUD gauge.
12. Tests pass headless (target: ≥600 tests, +60–80 from session 2's 542). Lint clean. Pre-commit gate green.
13. **Wave-close review** by `godot-code-reviewer` and `architecture-reviewer` produces APPROVE verdicts (or all blocking issues are fixed).
14. `docs/ARCHITECTURE.md` §2 reflects the new build state (rows for CombatComponent, UnitState_Attacking, UnitState_AttackMove, Piyade, Turan_Piyade, health bars, F4 overlay all → `✅ Built`).
15. **Experiment 01 verdict refined** with any new live-game-broken-surface findings or new Pitfalls list entries.
16. **Experiment 02 verdict (first formal trial)** filled in `docs/PROCESS_EXPERIMENTS.md`.

If all of those work, **Phase 2 session 1 is done.** Session 2 ships the broader unit roster (Kamandar, Savar, Asb-savar, Rostam) + Turan mirrors + RPS effectiveness matrix.

### What's deliberately NOT in session 1

- Kamandar, Savar, Asb-savar Kamandar, Rostam (heroes) — Phase 2 session 2.
- Full Turan unit roster (Turan_Kamandar, Turan_Savar, Turan_Asb-savar) — Phase 2 session 2.
- RPS effectiveness matrix — Phase 2 session 2.
- Kaveh Event trigger animation, below-Kaveh red-pulse — Phase 5.
- Floating damage numbers, attack animations, hit-flashes — Phase 5 polish.
- Hero abilities, Farr-of-the-warrior special effects — Phase 5+.
- Resource gathering and Mazra'eh / Mine — Phase 3.
- Buildings — Phase 3.
- Real Asb-savar Kamandar implementation requires kiting AI which would benefit from being in session 2 with the broader balance pass.

## 3. Wave breakdown

**Wave 1 — independent foundations (parallel agents):**

- **gameplay-systems** wave 1A: `CombatComponent` (deliverable 1) + `HealthComponent.last_death_position` + `unit_died` signal (deliverable 3). Both touch HealthComponent so same agent.
- **ai-engineer** wave 1B: `UnitState_Attacking` skeleton (deliverable 2 — implementation complete, but click_handler wiring lands in wave 2).
- **balance-engineer** wave 1C: BalanceData additions for combat (deliverable 7). Pure-data work, completes quickly. Returns availability for any cross-domain consult requests during wave 1.

**Wave 2 — composition (depends on wave 1):**

- **gameplay-systems** wave 2A: Iran `Piyade` (deliverable 5) + Turan `Turan_Piyade` (deliverable 6) + first Farr drain (deliverable 10). Three small deliverables, same agent, related domain.
- **ai-engineer** wave 2B: click_handler enemy-right-click branch wiring (the input side of deliverable 2) + attack-move (deliverable 4).
- **ui-developer** wave 2C: health bars (deliverable 8) + F4 attack-range overlay (deliverable 9).

**Wave 3 — qa integration tests (deliverable 11):**

- **qa-engineer** wave 3: cover all 9 production deliverables + cross-feature smoke test (the milestone test from §155).

**Wave-close review (Experiment 02):**

After wave 2 lands and qa wave 3 lands, before PR creation, the lead spawns BOTH `godot-code-reviewer` and `architecture-reviewer` in parallel against the wave's commit range. Reviews are read-only; blocking issues route back to original agents for fix; non-blocking findings surface in PR description.

**Lead live-test:** after wave 3, before PR. Walks DoD §1–11. Logs any live-game bugs found.

## 4. TDD discipline reminders

Same as session 2, plus:

1. **Read the contract section before writing code.** Especially the State Machine Contract for the new states.
2. **Write failing tests first.** Use `MatchHarness` for combat integration tests; spawn real units, advance ticks, assert on observable end state (HP value, position, signal emissions).
3. **Update `docs/ARCHITECTURE.md` §2** as each subsystem moves through 📋 → 🟡 → ✅. New §6 v0.X.X entry per non-trivial deliverable.
4. **Pre-commit gate is your safety net.**
5. **Tests should assert on the live property the lead would see.** Combat tests should verify HP after damage (not just that `take_damage` was called); death tests should verify the unit is freed and `unit_died` fired with correct payload (not just internal state). This is the lesson from session 2's `cb95d09` bug.
6. **Verify `git diff` of shared docs (BUILD_LOG.md, ARCHITECTURE.md) before staging.** Only your own additions should be in the diff. Cross-agent contamination is the canonical risk per session-2 incident.
7. **Wave-close review will catch what you missed.** Don't rely on it as a primary check — but know that two more eyes (one Godot-aware, one architecture-aware) will look at your work before merge.

## 5. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + the §1 reading order).
2. Verify branch state (`git status` — should be on `feat/phase-2-session-1` or similar, NOT `main`).
3. Check `BUILD_LOG.md` for Phase 1 session 2 final state.
4. Read `docs/PROCESS_EXPERIMENTS.md` Experiment 01 + Experiment 02 — understand the live-game-broken-surface section AND the wave-close-review pattern.
5. Pick a task from §2 in your wave.

**During session:**
1. Read the relevant contract section.
2. Answer your deliverable's three live-game-broken-surface questions in a scratch buffer.
3. Write a failing test.
4. Implement.
5. Refactor.
6. Update `docs/ARCHITECTURE.md` §2.
7. Commit on the feature branch with the live-game-broken-surface answers in the body. Verify `git diff` of shared docs before staging.

**End of wave (Experiment 02 active):**
1. All wave commits land on the feature branch.
2. **Lead spawns BOTH reviewers in parallel** (one Agent dispatch each, `run_in_background=true`) with the wave's commit range and known-context briefing including the latest Known Godot Pitfalls list.
3. Lead waits for both reviews.
4. Blocking issues → routed back to original agent for fix; non-blocking surface in PR description.
5. Once both verdicts are APPROVE (or all blockers fixed), proceed to wave-3 qa OR (if final wave) lead live-test then PR.

**End of session:**
1. All tests pass; pre-commit hook clean.
2. `docs/ARCHITECTURE.md` accurately reflects what was built.
3. Append entry to `BUILD_LOG.md`.
4. **Lead live-tests** before PR — runs DoD §1–11, logs any live-game bugs.
5. **Lead fills both Experiment 01 and Experiment 02 verdicts** in `docs/PROCESS_EXPERIMENTS.md`.
6. Push to remote; PR.

## 6. After Phase 2 session 1

When `docs/ARCHITECTURE.md` §2 shows the session-1 rows at `✅ Built` and the milestone test in §2 passes (DoD items 1–16), session 1 is complete. Plan Phase 2 session 2 (broader unit roster + RPS matrix) using `BUILD_LOG.md` for state.

If Phase 2 session 1 reveals an architectural gap that requires a contract revision (e.g., the State Machine Contract needs to specify command-queue replay semantics for attack-move's "resume after kill" pattern), mode-switch back to design (convene a sync) before continuing implementation.

---

*This doc is session-1-specific. After session 1, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state) + the implementation plan (Phase 2 session 2 task list).*
