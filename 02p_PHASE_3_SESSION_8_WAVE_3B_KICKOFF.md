---
title: Phase 3 Session 8 — Wave 3B DummyAIController Kickoff
type: plan
status: draft
version: 1.1.0
owner: team-lead
summary: Wave 3B — first Turan AI controller. Scaffold-shaped DummyAIController autoload that connects to the `&"ai"` sim_phase, periodically picks a visible-to-Turan Iran target via `FogSystem.is_visible_to`, and issues attack-move commands to Turan starter units. Reads AIConfig probe-cadence per difficulty. **Scope explicitly EXCLUDES** Turan economy / building placement / production-driving / tech-up / Kaveh Event — these depend on Turan-side buildings + production loops which haven't shipped. Wave 3B is the probe-attack scaffold; sophistication arrives in Phase 6 per AI_DIFFICULTY.md §2. **First wave to use mirror-reviewer agent at brief-time.** Lead drafts → mirror-reviewer brief-time review → address findings → implementer dispatch.
audience: all
read_when: every-session
prerequisites: [STUDIO_PROCESS.md, MANIFESTO.md, docs/ARCHITECTURE.md, docs/AI_DIFFICULTY.md, docs/SIMULATION_CONTRACT.md, docs/FOG_DATA_CONTRACT.md]
references: [STUDIO_PROCESS.md, ARCHITECTURE.md, AI_DIFFICULTY.md, SIMULATION_CONTRACT.md, FOG_DATA_CONTRACT.md, docs/AGENT_REGISTRY.md, 01_CORE_MECHANICS.md]
ssot_for:
  - Wave 3B scope (probe-attack scaffold; explicit exclusions per §1)
  - Per-track deliverables for Wave 3B
  - First mirror-reviewer brief-time review pass
tags: [phase-3, session-8, wave-3b, ai, dummy-ai, turan, kickoff]
created: 2026-05-23
last_updated: 2026-05-23
---

# Phase 3 Session 8 — Wave 3B DummyAIController Kickoff

## 0. Why this doc exists — first AI opponent

Wave 3B ships the **first Turan AI controller**. With Wave 3A.5's `FogSystem.is_visible_to` returning real data and Wave 3A.6's first playable production loop, the project now has both the visibility surface AND the producible-unit surface that AI consumers need. Wave 3B is the first such consumer.

**3B scope is deliberately narrow:** the project's design philosophy per `AI_DIFFICULTY.md` §2 is *"Tune once for Normal, leave alone. Sophistication arrives via tuning, not new dials."* DummyAIController is the scaffold; difficulty tuning + tech-up + economy management arrive at Phase 6. Wave 3B ships **probe-attack with starting units** — enough to make Iran-vs-Turan combat happen organically without player intervention.

## 1. Scope — what 3B SHIPS vs DEFERS

### What ships

| Surface | Wave 3B state |
|---|---|
| **TuranController autoload** | NEW. Reads `BalanceData.ai`. Subscribes to `&"ai"` sim_phase. Per-tick: state-machine step. |
| **Probe-attack state machine** | NEW. State = `&"idle"` or `&"probing"`. On `&"idle"` after probe-cadence ticks: pick a visible Iran unit/building target via `FogSystem.is_visible_to`, issue attack-move command to nearest Turan unit, transition to `&"probing"`. On `&"probing"`: monitor; transition back to `&"idle"` after attack resolves OR target lost. |
| **Difficulty-aware probe cadence** | Reads `BalanceData.ai.<difficulty>_wave_cadence_ticks`. MVP: hardcoded Normal at runtime; difficulty selection deferred to a future UI surface. |
| **Tests** | DummyAIController autoload smoke, probe-cadence timing, target selection via fog, attack-move command emission. |

### What explicitly DEFERS (do not scope in)

| Surface | Reason |
|---|---|
| **Turan economy** (workers + mines + deposit) | Turan has no starting buildings. No Mazra'eh / Ma'dan placed for Turan at match start. Economy is Phase 6 work per AI_DIFFICULTY.md §5. |
| **Turan building placement** | Build menu is player-only; no AI build-place flow exists. Deferred to dedicated wave (Wave 3C or Phase 4 candidate). |
| **Turan unit production** | Drives building.request_train on Turan-side producers. Turan has no Sowari-khaneh / Sarbaz-khaneh / Tirandazi placed. Deferred. |
| **Tech-up timing** | AIConfig has tech-up tunables but Tier-2 placement is gated by economy. Phase 6 scope. |
| **AI gather multiplier** | Depends on Turan economy. Phase 6 scope. |
| **Kaveh Event integration** | Phase 5 scope per `01_CORE_MECHANICS.md` §11. |
| **Easy/Normal/Hard difficulty UI selection** | Lead's call: 3B hardcodes Normal. Difficulty UI is a separate UX wave. |
| **`attack_army_threshold` enforcement** | Requires army-grouping logic + production-feeder. Phase 6 with rest of strategic AI. |

**Rationale for narrowing:** the wave-cadence + target-selection + attack-move-emission tuple is the irreducible scaffold for "AI opponent exists." Everything else is sophistication that AI_DIFFICULTY.md §2 explicitly forbids treating as a per-difficulty dial. 3B is the foundation; Phase 6 is the polish.

## 2. Reading order (≈10 min for active-context agents)

1. **`MANIFESTO.md`** — if your persistent context has rotated.
2. **`STUDIO_PROCESS.md` §9 clusters relevant to your track:**
   - All implementers: §9.D7(b) cross-track diagnostic, §9.E1 tier-precedence ladder (codified session-7 close — broadcast-and-wait default), **§9.L10 canonical-pattern grep (NEW session-7 close — read existing canonical patterns before implementing new ones, especially `FogSystem.is_visible_to` consumers and `BalanceData.ai` access pattern; this brief specifies access patterns but you should `git grep` for canonical existing consumers + use their shape if they exist).**
   - ai-engineer (first session in a while): §9.G channel discipline (SendMessage > assistant-text), §9.M test discipline.
   - balance-engineer: §9.L1 spec-wins (AIConfig values are spec-locked at AI_DIFFICULTY.md v1.1.0; no overrides expected).
3. **`docs/AI_DIFFICULTY.md` v1.1.0** — the SSOT for AIConfig schema + Easy/Normal/Hard values. Read §1 (values), §2 (rationale), §5 (implementation — focus on TuranController seam).
4. **`docs/FOG_DATA_CONTRACT.md` v1.3.1** — re-read §5.1 `is_visible_to` API. Wave 3B's target selection uses this directly.
5. **`docs/SIMULATION_CONTRACT.md` v1.5.0** — re-read §2 (phase order; AI runs phase 3 after `fog_update`).
6. **`game/scripts/autoload/fog_system.gd`** — the `is_visible_to(team_id, world_pos)` signature you're consuming.
7. **`game/scripts/main.gd` _spawn_starting_units** — see what Turan units exist at match start (5 Piyade + 3 Kamandar + 3 Savar + 3 AsbSavar = 14 starting Turan units).
8. **`game/scripts/units/unit.gd`** — `replace_command` API; how to issue an attack-move.
9. **`docs/AGENT_REGISTRY.md`** — addressable-name verification before any SendMessage.

## 3. Brief-time disciplines

### 3.1 §9.L10 canonical-pattern grep — MANDATORY pre-implementation step (zero-canonical-consumer fallback)

**Mirror-reviewer first-pass finding (1.1):** Wave 3B IS the first consumer of `BalanceData.ai`. `git grep "BalanceData.ai"` returns ZERO hits — the dormant-schema first-exercise is happening here. **§9.L10's zero-canonical-consumer fallback path:** when no canonical existing consumer exists, verify directly against the schema-declaration file.

- **Schema declaration:** `game/data/sub_resources/ai_config.gd` declares the 12 flat fields (verified at lines 23, 41, 59 — `easy_wave_cadence_ticks` / `normal_wave_cadence_ticks` / `hard_wave_cadence_ticks` + similar for the 3 other dials).
- **Access shape:** `BalanceData.ai.<field_name>` where `BalanceData.ai` is the AIConfig sub-resource per `game/data/balance_data.gd:65`.
- **Spec-lock:** AI_DIFFICULTY.md v1.1.0 §5 ratifies these values; no L1 overrides expected.

If brief and schema-declaration disagree, broadcast `[D7(b)] brief-vs-canonical-schema divergence: <field>` per §9.L1.b (codified session-7) AND §9.L10.

### 3.2 First mirror-reviewer dispatch

**Before this brief reaches implementer agents, lead dispatches `mirror-reviewer` for brief-time review.** Per the agent's role (`.claude/agents/mirror-reviewer.md`):
- Mirror grep-verifies schema claims (Class 1)
- Mirror web-research-verifies Godot 4 API surfaces if any are introduced (Class 2)
- Mirror flags cross-cutting schema introductions (Class 3) — should not apply this wave (no new schema; reads existing AIConfig)
- Mirror checks for project-history pattern conflicts (Class 4) — should check this brief against Pitfall #16 + #17 (relevant: any iteration over unit registries needs `is_instance_valid()` BEFORE `as Node3D` cast; any `await get_tree().process_frame` in tests should use `free()` instead)

Findings route back to lead before implementer dispatch.

### 3.3 §9.E1 tier-precedence

Wave 3B is single-track-effective (ai-engineer Track 1) with balance-engineer optional standby. Tier 1 [blocked]+broadcast applies if cross-track coupling surfaces (unlikely — pure AI logic shouldn't touch BalanceData schema, only read).

## 4. Per-track deliverables

### Track 1 — ai-engineer-p3s8 (fresh spawn) — DummyAIController autoload + probe-attack FSM

**Files (new):**
- `game/scripts/autoload/dummy_ai_controller.gd` (or `turan_controller.gd` — naming choice during brief-time review). Class extends Node (autoload pattern matching FogSystem / ResourceSystem / SimClock).
- `game/tests/unit/test_dummy_ai_controller.gd` — autoload smoke + state machine + target selection + command emission.
- `game/tests/integration/test_phase_3_dummy_ai_probe.gd` — match-harness driven integration: spawn match, advance probe-cadence ticks, assert Turan unit issued attack-move toward Iran.

**Public API (canonical patterns LOCKED post-mirror-review):**

```gdscript
class_name TuranController extends Node

# Read from BalanceData.ai at _ready
var _probe_cadence_ticks: int

# State machine
var _state: StringName = &"idle"  # or &"probing"
var _ticks_since_last_probe: int = 0

# Stored as untyped Variant per Pitfall #16 (cast-on-freed-Object). is_instance_valid()
# REQUIRED before any cast or property access. Target Node may be freed between
# probe-issue and probe-resolve ticks (Iran kills it; queue_free reaps).
var _current_probe_target: Variant = null   # target Iran Node3D OR null
var _current_probe_unit: Variant = null     # commanded Turan Node3D OR null

# CANONICAL sim_phase subscription pattern (BUG-D1 lesson — see fog_system.gd
# post-fix at `f855ec5`, also spatial_index.gd:43 / unit.gd:363 / building.gd:367).
# DO NOT attempt sc.<phase>.connect — SimClock has no per-phase method-signals.
func _ready() -> void:
    EventBus.sim_phase.connect(_on_sim_phase)
    # ... read BalanceData.ai.normal_wave_cadence_ticks ...

func _on_sim_phase(phase: StringName, _tick: int) -> void:
    if phase != Constants.PHASE_AI:
        return
    # ... per-tick AI step ...

# Internal:
func _step_idle() -> void:   # increment cadence counter; transition on threshold
func _step_probing() -> void: # monitor target/unit; transition back on resolution
func _pick_target() -> Node3D:  # query SpatialIndex; filter by FogSystem.is_visible_to(TURAN, pos)
func _issue_attack_move(unit: Node3D, target_position: Vector3) -> void:
    # Call Unit.replace_command(kind: StringName, payload: Dictionary).
    # Canonical signature: `game/scripts/units/unit.gd:522`.
    # Find existing attack-move call-sites: `git grep 'replace_command.*attack' game/scripts/`.
    # If no canonical attack-move kind exists yet, fall back to `&"move"` with
    # `{"world_position": target_position}` payload — Phase 6 will refine.
    pass
```

**Pattern citations (CANONICAL — mirror these, not freshly invented patterns):**
- **`EventBus.sim_phase.connect(_on_sim_phase)` + filter pattern:** `spatial_index.gd:43`, `unit.gd:363`, `building.gd:367`, `fog_system.gd` post-BUG-D1.
- **`Unit.replace_command(kind: StringName, payload: Dictionary)`:** `unit.gd:522`.
- **`FogSystem.is_visible_to(team_id: int, world_pos: Vector3) -> bool`:** `fog_system.gd:216`.
- **Target Node iteration with Pitfall #16 safety:** store as Variant, `is_instance_valid()` BEFORE cast.

**Decision points (LOCKED at v1.1.0 post-mirror-review):**

1. **Autoload name — `TuranController`** (per AI_DIFFICULTY.md §5 canonical nomenclature). Mirror-reviewer first-pass flagged this for lock before dispatch; lead locks `TuranController`.

2. **Target priority** — nearest Iran unit visible to Turan via `FogSystem.is_visible_to`. **Pitfall #16 safety MANDATORY:** store as Variant, `is_instance_valid()` BEFORE cast or property access. **Regression test required:** probe a target, free the target Node, advance one AI-phase tick, assert no crash. This becomes the SECOND canonical-incident anchor for Pitfall #16.

3. **Probe-cadence source** — `_probe_cadence_ticks = BalanceData.ai.normal_wave_cadence_ticks` at `_ready` (3600 ticks = 120s @ 30Hz). Verify field name at `ai_config.gd:41`.

4. **First-probe delay** — delayed by one full cadence. Iran establishes presence first.

5. **Pop-cap fallback if no Turan units alive** — log debug message, stay in `&"idle"`. No production-driving (deferred per §1 exclusions).

**Tests required (Pitfall #16 + #17 disciplines MANDATORY — mirror-reviewer findings 2.1 + 2.2):**

Structural surface:
- TuranController autoload registers cleanly
- `EventBus.sim_phase.connect(_on_sim_phase)` wired (NOT a per-phase SimClock method-signal — see BUG-D1)
- Probe-cadence countdown advances per tick
- Target selection via `FogSystem.is_visible_to` works
- `Unit.replace_command(&"<kind>", {<payload>})` emitted with correct args
- State machine transitions idle → probing → idle correctly
- Defensive paths: no visible target (stays idle), no alive Turan units (stays idle)

**MANDATORY Pitfall #16 regression test (target-Node-may-freed):**
- Spawn Iran Unit; TuranController picks it as probe target.
- `free()` the Iran Unit Node synchronously.
- Drive one AI-phase tick via `EventBus.sim_phase.emit(&"ai", 1)`.
- Assert no crash + TuranController transitions cleanly back to `&"idle"`.

**MANDATORY Pitfall #17 test-discipline:**
- Use `node.free()` not `queue_free()` + `await get_tree().process_frame` for assertion-immediate-after-spawn cases. The `await` leaks SimClock ticks; downstream tests fail.
- If a test legitimately needs a rendered frame, opt-in explicitly with `SimClock.tick` snapshot in `before_each` + bounded tick-leak assertion in `after_each`.

**MANDATORY wiring-path test (BUG-D1 lesson — defensive-guard-masking N=2 prevention):**
- Drive `EventBus.sim_phase.emit(&"ai", 1)` directly + assert TuranController state-machine step ran.
- DO NOT bypass with a direct call to `_on_sim_phase`. The test must exercise the actual signal-wiring path, not just the function body. This is exactly how BUG-D1's same shape would be caught at this wave's ship time.

**Cultural framing reminder:** Turan in the Shahnameh is the antagonist civilization across the Iran-Turan wars (Manuchehr, Kay Kavus, Kay Khosrow eras). The AI represents Afrasiyab's strategic mind — not raiders, but a kingdom-level opponent with sustained pressure. The probe-attack scaffold is the floor; the eventual Phase 6 TuranController per AI_DIFFICULTY.md will need to feel like a kingdom planning, not a horde rushing. **For 3B MVP: no cultural-note prose needed in code (mechanical scaffold layer); the framing is for future Phase 6 work.**

### Track 2 (standby) — balance-engineer-p3s3

No mandatory deliverables. Possible engagement:
- **AIConfig value sanity check.** Mirror-reviewer may grep BalanceData.ai schema and find divergence vs AI_DIFFICULTY.md §5 — if so, balance-engineer reconciles.
- **Tunable adjustment post-live-test.** If lead live-tests + probe cadence feels wrong, balance-engineer single-commit `.tres` edit.

### Standby — engine-architect-p3s2 + world-builder-p3s2 + ui-developer-p3s3 + gp-sys-p3s3

No mandatory deliverables. Engine-architect on standby for `&"ai"` phase verification if Track 1 surfaces issues. Others fully standby — no UI / world / gameplay changes expected.

## 5. Wave-close criteria

- [ ] Full headless test suite passes (1468+ baseline; expect ~10-15 new tests at +0 regressions).
- [ ] `git grep "TuranController\|DummyAIController"` returns positive hits (autoload registered).
- [ ] `&"ai"` phase subscription wired (verify via test or grep).
- [ ] Live-test (lead-driven): start match, observe Turan units begin probe-attacking Iran after ~120s (Normal cadence). Iran-vs-Turan combat now happens organically without player intervention. **First time the game looks alive without manual scripting.**
- [ ] ARCHITECTURE.md v0.33.0 → v0.34.0 close entry.
- [ ] BUILD_LOG session-8 wave 3B close entry.

## 6. Hand-off when this wave closes

- **Wave 3C candidate:** Turan starting building placement at match start (Sowari-khaneh + Sarbaz-khaneh + Tirandazi mirrored to Iran). Unblocks Wave 3D (Turan AI production-driving) — AI calls `building.request_train` on Turan producers + maintains army cycle. The Iran-vs-Turan AI-vs-AI loop becomes self-sustaining.
- **Phase 5 prep:** Kaveh Event needs FogSystem.get_last_seen real impl (Wave 3A.7 — deferred) + Farr-meter-zero detection.
- **Phase 6 prep:** Difficulty UI + TuranController economy state + tech-up + attack_army_threshold enforcement.

---

*Status: v1.0.0 — DRAFT 2026-05-23 by lead. Pending mirror-reviewer brief-time review per §3.2 before implementer dispatch.*
