---
title: Phase 2 Session 2 Kickoff — Broader Unit Roster + RPS Effectiveness Matrix
type: plan
status: living
version: 1.0.0
owner: team
summary: Phase 2 session-2 recipe — expand the combat roster from mirror combat (5v5 Piyade) to the full Phase-2-spec roster (Iran Kamandar / Savar / Asb-savar Kamandar + Turan mirrors) and ship the RPS effectiveness matrix that makes their interactions interesting. Includes Experiments 01, 02, 03 (the new commit-discipline trial).
audience: all
read_when: starting-phase-2-session-2
prerequisites: [MANIFESTO.md, CLAUDE.md, docs/ARCHITECTURE.md, 02_IMPLEMENTATION_PLAN.md, BUILD_LOG.md, 02d_PHASE_2_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md]
ssot_for:
  - Phase 2 session-2 reading order
  - Phase 2 session-2 scoped slice and per-deliverable owner mapping
  - Phase 2 session-2 wave breakdown and dependency order
  - Phase 2 session-2 Definition of Done
  - Experiment 03 application surface (per-TDD-cycle commits + serialized wave-close)
references: [02_IMPLEMENTATION_PLAN.md, 02d_PHASE_2_KICKOFF.md, docs/PROCESS_EXPERIMENTS.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, docs/SIMULATION_CONTRACT.md, docs/STATE_MACHINE_CONTRACT.md, docs/TESTING_CONTRACT.md, BUILD_LOG.md]
tags: [phase-2, session-2, combat, rps, roster, kamandar, savar, asb-savar, kickoff, recipe]
created: 2026-05-04
last_updated: 2026-05-04
---

# Phase 2 Session 2 Kickoff — Broader Unit Roster + RPS Matrix

> **Mode:** implementation. Per `docs/STUDIO_PROCESS.md` §12, the studio process (syncs, OST patterns, Convergence Review) is dormant during implementation. **Three active experiments:** Experiment 01 (live-game-broken-surface in agent briefs — kept), Experiment 02 (wave-close review by two reviewer agents — kept-with-refinement), and **Experiment 03 (per-TDD-cycle commits + serialized wave-close — first formal trial)**.

## 0. Why this doc exists

Phase 2 session 1 shipped the combat core: 5 Iran Piyade vs 5 Turan Piyade in mirror combat. Damage flows, units die, the first Farr drain wires Kargar deaths into the meter. Now session 2 makes combat **interesting** — three new Iran combat unit types (Kamandar archers, Savar cavalry, Asb-savar Kamandar horse archers), the Turan mirror set, and the rock-paper-scissors effectiveness matrix that makes "Piyade beats Savar, Savar beats Kamandar, Kamandar beats Piyade" load-bearing in actual battles.

This doc is **session-2-specific.** Subsequent Phase 2 sessions read `BUILD_LOG.md` for state.

## 1. Session-2 reading order (≈12 minutes)

1. **`MANIFESTO.md`** — principles. The architecture-reviewer will grade against these.
2. **`CLAUDE.md`** — project instructions, file ownership.
3. **`docs/ARCHITECTURE.md`** — orientation layer. After Phase 2 session 1 merge, the combat-core rows are `✅ Built`. **§7 LATER index** is your queue of known-deferred items — pick which apply to your wave.
4. **`docs/STUDIO_PROCESS.md`** §9 (active rules). **Three new entries from Phase 2 session 1 retro:** anti-loop brief language template, per-TDD-cycle commits, shared-doc `git diff` verification before staging. Read these in §9; they're the binding patterns for your dispatch workflow.
5. **`docs/PROCESS_EXPERIMENTS.md`** — three active experiments (01 + 02 + 03) and the **Known Godot Pitfalls list** at the top of the file. Pitfalls #1, #2, #3, #4, #5, #8 are now permanent — your code MUST pass against each, and your live-game-broken-surface answers should reference them where relevant.
6. **`02d_PHASE_2_KICKOFF.md`** — Phase 2 session 1's recipe. Scope and structure carry forward; you're extending it with the broader roster.
7. **`02_IMPLEMENTATION_PLAN.md`** §155–180 — Phase 2 task list. Session 2 picks up the rows session 1 left as out-of-scope.
8. **`docs/STATE_MACHINE_CONTRACT.md`** — interrupt levels, command queue. Ranged units (Kamandar, Asb-savar) introduce `&"ranged_attack"` cause strings; check Sim Contract §1.6 fixed-point conventions for projectile lifecycle if you ship one.
9. **`docs/SIMULATION_CONTRACT.md`** §3 (SpatialIndex — combat range queries), §4 (IPathScheduler — Asb-savar's kiting requires repath responsiveness).
10. **`BUILD_LOG.md`** — Phase 2 session 1 retros. Especially the BUG-01..BUG-06 sequence and the v0.17.3 / v0.17.5 §6 entries (drift in the `&"movement"` phase that L3's CombatSystem coordinator is queued to fix).
11. **This doc** for the scoped slice + Experiment 03's discipline.

## 2. The Session-2 scoped slice

### Session-2 deliverables

Per Experiment 01: every deliverable below includes a `Live-game-broken-surface` block. The owning agent must answer all three questions in their commit body or BUILD_LOG entry before declaring done. The Known Godot Pitfalls list (now at the top of `PROCESS_EXPERIMENTS.md`) is your additional checklist.

---

#### 1. Iran `Kamandar` (archer) unit type

Ranged infantry. Glass cannon — high damage at range, low HP, slow attack speed. Counters Piyade (range > Piyade's melee), countered by Savar (cavalry charge closes range fast).

**Owner:** gameplay-systems.

**Stats** (balance-engineer's call, but for orientation):
- max_hp: 60 (matches Kargar's 60 — fragile)
- move_speed: 2.5 (same as Piyade)
- attack_damage_x100: 1500 (15.0 — higher per-hit than Piyade)
- attack_speed_per_sec: 0.7 (slower than Piyade's 1.0 — bow draw)
- attack_range: 8.0 (real ranged vs Piyade's 1.5 melee)

**Reads:** session 1's `piyade.gd` / `piyade.tscn` for the inheritance pattern. `combat_component.gd` for cause-string augmentation.

**Writes:** new `game/scripts/units/kamandar.gd` + `game/scenes/units/kamandar.tscn` (inherits unit.tscn, overrides mesh + material). New cause string `&"ranged_attack"` in `health_component.gd::take_damage_x100` calls — coordinate with Pitfall #6 candidate's deferred status (cause-string suffix Constants land when 2nd suffix arrives).

**Live-game-broken-surface for this deliverable:**
1. *What state/behavior must work at runtime that no unit test exercises?* CombatComponent's range gate at 8.0 — the per-tick distance check needs to handle units at 6-7 unit distance correctly. SpatialIndex queries at 8m radius to find targets if a separate target-acquisition path emerges (it doesn't this session — UnitState_Attacking still reads `current_command.payload.target_unit_id` from explicit attack commands).
2. *What can a headless test not detect that the lead would notice in the editor?* Visual silhouette — Kamandar should read clearly as "the bow guy" vs Piyade's cube. Per CLAUDE.md placeholder visuals: maybe a tall narrow cylinder (height 0.9, radius 0.25) — taller and thinner than Piyade. Color: Iran-blue darker variant.
3. *What's the minimum interactive smoke test that catches it?* Lead spawns 5 Kamandar, right-clicks far-away Turan Piyade. Kamandar fires from 8m away, doesn't walk into melee. HP bar appears on target, decrements over time.

---

#### 2. Iran `Savar` (cavalry) unit type

Heavy mounted infantry. Counters Kamandar (charges through arrow range to melee), countered by Piyade (massed spears stop horses — modeled via the RPS matrix).

**Owner:** gameplay-systems.

**Stats:**
- max_hp: 150 (tankier than Piyade)
- move_speed: 4.5 (faster — cavalry charge)
- attack_damage_x100: 1200 (12.0 — higher than Piyade)
- attack_speed_per_sec: 0.9 (slightly slower than Piyade — heavier swings)
- attack_range: 1.8 (slightly longer than Piyade — mounted reach)

**Visual:** Iran-blue larger cube (0.7×0.8×0.7). Or a low-slung rectangle (cylinder/rectangle of horse + rider).

**Live-game-broken-surface:** as above for Kamandar — visual differentiation, stat reads, RPS effectiveness verification.

---

#### 3. Iran `Asb-savar Kamandar` (horse archer) unit type

Ranged + cavalry. The unit that makes kiting AI a real problem. Per `02_IMPLEMENTATION_PLAN.md` §169: ship now (Phase 2) so kiting affects combat math; rebalanced to Tier 2 in Phase 4 when their tech tier ships.

**Owner:** gameplay-systems + balance-engineer (kiting feel needs both).

**Stats** (Tier-1-equivalent for now):
- max_hp: 100 (Piyade-equal — the Tier 2 buff will boost this)
- move_speed: 4.0 (cavalry-fast but slightly slower than Savar)
- attack_damage_x100: 1300 (13.0 — between Piyade and Kamandar)
- attack_speed_per_sec: 0.6 (slower than Kamandar — drawing on horseback)
- attack_range: 7.0 (slightly less than Kamandar foot archers)

**Visual:** elongated cube/rectangle, slightly larger than Asb-savar (foot) but recognizable as ranged.

**Special — kiting AI is NOT in this session.** The unit ships; AI that uses kiting movement (move-fire-move) is Phase 6's `DummyAIController` work. Player-controlled Asb-savar still needs explicit move + attack commands. The unit existing now exposes the COMBAT MATH for kiting (range + speed combo) so balance-engineer can tune the RPS matrix without re-touching it in Phase 6.

---

#### 4. Turan mirror roster

Mirror unit types for each Iran new unit (`Turan_Kamandar`, `Turan_Savar`, `Turan_Asb_Savar`). Same stats Tier-1-equivalent (no asymmetric balance yet). Different team color (Turan-red palette).

**Owner:** gameplay-systems.

**Spawn integration:** extend `main.gd::_spawn_starting_units` to spawn at minimum 1-2 of each new Turan type at the opposite map corner so live-test can engage the full RPS roster.

---

#### 5. RPS effectiveness matrix

The combat coefficient applied to base damage based on attacker/target type pairs. Per `01_CORE_MECHANICS.md` and `02_IMPLEMENTATION_PLAN.md` §170:

| Attacker → Target | Piyade | Kamandar | Savar | Asb-savar Kamandar |
|---|---|---|---|---|
| Piyade | 1.0× | 1.0× | **1.5×** (anti-cav) | 1.0× |
| Kamandar | **1.5×** (anti-melee) | 1.0× | 0.7× (vs heavy) | 0.7× |
| Savar | 0.7× (vs spears) | **2.0×** (cav-charge-archer) | 1.0× | 1.0× |
| Asb-savar Kamandar | 1.2× | 1.0× | 0.5× (mid horseplay) | 1.0× |

(These are a starting point — balance-engineer's call to tune. The shape is RPS-with-asymmetries.)

**Owner:** balance-engineer + gameplay-systems.

**Implementation:** new `BalanceData.combat_matrix: Dictionary[StringName, Dictionary[StringName, float]]` (already a sub-resource per Phase 0 — populate it). `CombatComponent._sim_tick`'s damage-fire step looks up the multiplier `combat_matrix[attacker.unit_type][target.unit_type]` and multiplies into `attack_damage_x100`. Defaults to 1.0× when the pair is missing (forward-compat for new unit types).

**Live-game-broken-surface:**
1. *What state/behavior must work at runtime no unit test exercises?* The BalanceData lookup — `combat_matrix.get(attacker_type, {}).get(target_type, 1.0)`. Unit tests with stub units (no `unit_type`) need to either supply unit_types or rely on the default-1.0 fallback.
2. *What can a headless test not detect that the lead would notice in editor?* Battle feel — does Piyade vs Savar feel "decisive" at 1.5×, or does it need 1.7× / 2.0× to read as a clear win? Tunable via `balance.tres` without code change.
3. *What's the minimum interactive smoke test?* Lead pits 5 Iran Piyade vs 5 Turan Savar. Piyade should win (~1.5× damage advantage). Reverse: 5 Iran Savar vs 5 Turan Kamandar. Savar should win (charge-through-range + 2.0× cavalry-vs-archer multiplier). Five trials should converge on the spec ratios.

---

### Definition of Done for Phase 2 Session 2

A future-you (or any agent) opens the project on macOS Apple Silicon and:

1. Launches the game (F5).
2. Sees the expanded roster: 5 Iran Kargar + 5 Iran Piyade + N Iran Kamandar + N Iran Savar + N Asb-savar Kamandar + Turan mirrors of each combat type. (N counts balance-engineer's call — at least 1-2 of each.)
3. Box-selects 5 Iran Piyade, right-clicks Turan Savar → Iran Piyade win convincingly (RPS 1.5× anti-cavalry).
4. Pits 5 Iran Savar vs 5 Turan Kamandar → Savar win (charge + 2.0× anti-archer).
5. Pits 3 Iran Asb-savar Kamandar vs 5 Turan Piyade → Asb-savar kite-fire from range, Piyade can't close (no kiting AI yet, but the matrix favors Asb-savar at range).
6. F4 attack-range circles render at correct radii per type (1.5 Piyade, 1.8 Savar, 8.0 Kamandar, 7.0 Asb-savar).
7. Health bars decrement, killed units disappear, Farr stays stable when only combat units die (no Kargar idle deaths).
8. Tests pass headless (target ≥ 760 tests, +35 from session 1's 726). Lint clean. Pre-commit gate green.
9. **Wave-close review** by both reviewer agents produces APPROVE verdicts.
10. `docs/ARCHITECTURE.md` §2 reflects new build state (rows for Kamandar / Savar / Asb-savar / Turan mirrors + RPS matrix all → `✅ Built`).
11. **Experiment 03 verdict filled** in `docs/PROCESS_EXPERIMENTS.md` (commit-race incidents = 0 target).

If all of those work, **Phase 2 session 2 is done.** Phase 3 (economy + dummy AI + fog) is the next session.

### What's deliberately NOT in session 2

- Kiting AI (move-fire-move for Asb-savar) — Phase 6 with `DummyAIController`.
- Auto-attack / unit stances — Phase 6.
- Body-push collision — Phase 3+ polish (LATER L4).
- Formation engagement priority — Phase 3+ (LATER L5).
- Ranged projectile entities (visible arrow models) — Phase 5 polish.
- Hero units (Rostam) — Phase 5.
- Buildings (production, atashkadeh) — Phase 3.

## 3. Wave breakdown

**Wave 1 — independent foundations (parallel):**

- **gameplay-systems** wave 1A: Kamandar + Savar (deliverables 1 + 2) + Turan mirrors of those two. Single agent because all 4 inherit the same unit.gd / unit.tscn pattern; bundling reduces commit-coordination overhead. (Per Experiment 03's per-TDD-cycle rule: agent commits per unit type, not all 4 at end.)
- **balance-engineer** wave 1B: BalanceData population for all 4 new combat-unit-types + the RPS effectiveness matrix sub-resource population. Pure data work, no code.
- **gameplay-systems** wave 1C: Asb-savar Kamandar + Turan mirror (deliverable 3). Separate agent instance from 1A so the kiting-relevant tuning can run in parallel.

**Wave 2 — composition (depends on wave 1):**

- **gameplay-systems** wave 2A: RPS matrix integration in `CombatComponent._sim_tick` (deliverable 5). Reads from BalanceData populated in wave 1B; multiplies attack_damage_x100 at fire-time.
- **gameplay-systems** wave 2B: extend `main.gd::_spawn_starting_units` to spawn the new roster.

**Wave 3 — qa integration tests:**

- **qa-engineer** wave 3: cover RPS matrix outcomes (Piyade vs Savar, Savar vs Kamandar, etc.), kiting-relevant combat math (Asb-savar at range), per-type attack range gate verification, regression locks for each new unit type.

**Wave-close review (Experiment 02, second formal trial):**

After wave 3 lands, lead spawns BOTH reviewer agents in parallel against the wave's commit range. Reviews are read-only; blocking issues route back to original agents.

**Lead live-test:** after wave 3 + reviewer approval, before PR. Walks the DoD §1–11.

## 4. Anti-loop brief language (PERMANENT — STUDIO_PROCESS §9 2026-05-04)

EVERY agent dispatch brief includes the explicit cycle:

> "Cycle: implement → pre-commit gate → `git diff --staged --stat` shows ONLY your files → commit → `git log -1` confirms your SHA → THEN report back. Don't issue 'task already shipped, standing down' reports. If you think work exists, run `git log` and check author/SHA. Your task list is the authority on what YOU have done — but the SHA in `git log` is the authority on what's COMMITTED."

This is now load-bearing — four agents in a row at the end of Phase 2 session 1 used this exact language and shipped clean. Agents who got it earlier (or in different forms) hit the verification-loop pattern.

## 5. Per-TDD-cycle commits (Experiment 03 — under measurement this session)

Every agent dispatch brief includes the cycle:

> "Commit per TDD cycle: after each `red → green → refactor` sequence (one new test + implementation pair), run pre-commit gate, stage your specific files, commit. Do NOT batch commits at end-of-wave. End-of-wave should have at most a docs-only commit."

When wave-close coordination DOES require a batched commit (rare — only the docs aggregator), lead nominates the order: each agent commits in turn, signals done, next agent commits. No parallel wave-close commits.

This is **under measurement** as Experiment 03. Verdict at session close per the criteria in `docs/PROCESS_EXPERIMENTS.md` Experiment 03.

## 6. Shared-doc verification (PERMANENT — STUDIO_PROCESS §9 2026-05-04)

Before staging any shared append-only doc (`BUILD_LOG.md`, `docs/ARCHITECTURE.md`, `docs/PROCESS_EXPERIMENTS.md`, `docs/STUDIO_PROCESS.md`), agents run:

```
git diff <doc-file>
```

And confirm the diff contains ONLY their additions. If cross-agent content appears, FLAG before staging — don't `git add` it. Coordinate with lead.

## 7. Session ceremony

**Start of session:**
1. Read the orientation layer (this doc + §1).
2. Verify branch state — should be on `feat/phase-2-session-2`, not `main`.
3. Check `BUILD_LOG.md` for Phase 2 session 1 final state.
4. Read three active experiments + Known Godot Pitfalls list in `docs/PROCESS_EXPERIMENTS.md`.
5. Pick a task from §2 in your wave.

**During session (per-TDD-cycle commits):**
1. Read the relevant contract section.
2. Answer your deliverable's three live-game-broken-surface questions in a scratch buffer.
3. **Per cycle:** write a failing test → implement → refactor → pre-commit gate → stage your files → `git diff --staged --stat` → commit → `git log -1` → next cycle.
4. Update `docs/ARCHITECTURE.md` §2 + §6 incrementally as features ship.
5. Verify `git diff` of shared docs before staging each batch.

**End of wave (Experiment 02 active):**
1. All wave commits land.
2. Lead spawns BOTH reviewers in parallel.
3. Lead waits for both reviews. Blocking issues → route back to original agent.
4. Once both APPROVE, proceed to wave-3 qa OR (if final wave) lead live-test then PR.

**End of session:**
1. Lead live-test before PR — walk DoD §1–11.
2. Lead fills Experiment 01, 02, 03 verdicts in `docs/PROCESS_EXPERIMENTS.md`.
3. **Lead executes session-close retro** (STUDIO_PROCESS §9 2026-05-04 rule):
   - Promote Pitfall candidates from Experiment 01 verdict text → Known Godot Pitfalls list.
   - Update STUDIO_PROCESS §9 with new active rules.
   - Promote architectural LATER items into ARCHITECTURE.md §7 LATER index.
   - Close / extend / open experiments.
   - Draft next session's kickoff doc.
4. Push to remote; PR.

## 8. After Phase 2 session 2

When `docs/ARCHITECTURE.md` §2 shows the session-2 rows at `✅ Built` and the milestone test passes (DoD §1–11), session 2 is complete. Phase 2 is done; Phase 3 (economy + dummy AI + fog data layer per `02_IMPLEMENTATION_PLAN.md` §184) is the next session's scope.

---

*This doc is session-2-specific. After session 2, future sessions get their orientation from `BUILD_LOG.md` (state) + `docs/ARCHITECTURE.md` (build state + LATER index) + the implementation plan (Phase 3 task list).*
