---
title: Phase 4 — Wave 1 Kickoff — FarrSystem (the central mechanical innovation)
type: kickoff-brief
status: dispatch-ready (mirror-reviewed FIX-BRIEF-FIRST → fixes folded; scope ratified 2026-06-22)
version: 1.0.0
owner: team-lead → gameplay-systems
audience: gameplay-systems (implementer), balance-engineer (magnitudes), godot-code-reviewer / architecture-reviewer (pre-PR)
read_when: implementing Phase-4 Wave-1
prerequisites: [DECISIONS.md 2026-06-22 (Tier-1 rulings), 01_CORE_MECHANICS.md §4, docs/SIMULATION_CONTRACT.md §1.6/§2, CLAUDE.md conventions]
references: [DECISION_PACKET_2026-06-08.md §1.1/§1.2, docs/SHAHNAMEH_ECONOMY_RESEARCH.md §6.2]
tags: [phase-4, farr, kickoff, gameplay-systems]
created: 2026-06-22
---

# Phase 4 — Wave 1 — FarrSystem

## Why this wave

Farr is "the central mechanical innovation" (`01_CORE_MECHANICS.md` §4). The plumbing exists since Phase 0 — `apply_farr_change` (the single mutation chokepoint), the `FarrDrainDispatcher` (worker-death drains), and the `FarrGauge` HUD — but the meter today only moves on worker deaths and can only tick *down*. This wave makes the Farr **economy** complete: it moves for the right reasons (the §4.3 snowball-injustice drains), it can rise (building emitters), and the army exerts standing economic pressure (royal-largesse upkeep). 

**This wave makes the meter MOVE correctly. It does NOT yet make Farr load-bearing** — see Scope OUT. That is a deliberate, ratified staging call (2026-06-22): each mechanical consequence ships with its host system.

## Rulings this wave implements (DECISIONS.md 2026-06-22)

- **§1.1a** — snowball "3:1 army advantage" = **population cost**: `attacker_team_pop ≥ 3 × defender_team_pop`, summing each living unit's `population_cost`.
- **§1.1b** — "military is broken" = **zero living military units AND zero operational military-production buildings**.
- **§1.2** — economy staged; a **royal-largesse upkeep trickle ships WITH this core** as standing late-game pressure. **Ratified 2026-06-22: upkeep drains COIN** (treasury down-flow per economy research §6.2 — keeps the Farr meter "pure": Farr moves only for justice/legitimacy, never bookkeeping).
- **§1.3** — Turan non-mirror (no Turan-specific work this wave; just don't bake Iran assumptions into shared Farr code).

## Scope IN — three deliverables

### D1 — Snowball-injustice Farr drains (§4.3)
Hook the **`EventBus.unit_died(unit_id, killer_unit_id, cause, position)`** signal (`event_bus.gd:72`; emitted by `HealthComponent` at `health_component.gd:308`). Chosen over `unit_health_zero` because it carries the killer — the drains are about *who did the killing*. Two drains:

**(D1a) Outnumbered-kill drain.** When a unit dies, attribute the kill and test the 3:1 population ratio:
1. **Resolve the killer** via `_find_unit_by_id(killer_unit_id)`. If `killer_unit_id == -1` or the killer is unresolved → **bail** (attrition / environmental / Farr-drain death — no injustice). *(Fix F1: do NOT derive "attacker team" as the victim's opposite — read it off the killer. That also makes friendly-fire fall out correctly.)*
2. If `killer.team == victim.team` → **friendly-fire bail** (a separate later concern, not this drain).
3. `attacker_team = killer.team`, `defender_team = victim.team`. Compute each team's army population as the **sum of `BalanceData.units[u.unit_type].population_cost`** over living units of that team.
4. If `attacker_pop ≥ 3 × defender_pop` → `apply_farr_change(-<snowball_kill_outnumbered>, "snowball_kill_outnumbered", killer)`.

**(D1b) Kicking-them-while-down drain.** On the same `unit_died` hook, when the **victim is a worker (or a Ma'dan/mine is destroyed)** AND the victim's team is "military-broken" → `apply_farr_change(-<snowball_economy_when_broken>, "snowball_economy_when_broken", killer)`. "Military-broken" for team T = **zero living military units of T AND zero operational military-production buildings of T** (see Predicates).

**Living-unit / alive predicate (Fix F2 + F4 — get this exactly right):**
- Enumerate via `get_tree().get_nodes_in_group(&"units")` (every unit joins at `unit.gd:268`), filter by `u.team`.
- **"Alive" = `not u.is_dying()`** — NOT `u.get_health() != null` (that returns the HealthComponent *node*, always non-null — the draft's bug). Verify `is_dying()` exists on Unit; if the canonical predicate differs, use the one the Dying-state machine sets. Read HP off the component only as a secondary check.
- **The just-killed victim is still transiently in `&"units"`** during the combat phase (its `queue_free` is deferred). **Exclude from BOTH team sums any unit that `is_dying()` OR is the just-emitted `unit_id`** — so a same-tick multi-death resolves identically regardless of intra-phase handler order (determinism, Sim Contract §1.6). A same-tick multi-death test is required.

### D2 — Farr GAINS (building emitters)
Implement the **`FarrSystem.register_emitter(building: Node, farr_per_min: float)`** and **`unregister_emitter(building: Node)`** API — it does not exist yet (`atashkadeh.gd:389-390` already *calls* it; the call currently no-ops + logs). 
- Maintain an emitter registry; on each **`sim_phase(&"farr", tick)`** (`sim_clock.gd` PHASES index 6 — the designated Farr per-tick seam), accrue the aggregate per-minute rate into a **fixed-point accumulator** and flush whole-x100 increments through `apply_farr_change(+amount, "atashkadeh_emission", building)`. **Per-tick fixed-point accumulation, NOT per-minute rounding** (Sim Contract §1.6 determinism; rates already stored as `BuildingStats.farr_per_min_x100`, e.g. Atashkadeh `=100`).
- Wire Atashkadeh's existing `is_emitting_farr` flag to call `register_emitter(self, farr_per_min)` on construction-complete and `unregister_emitter(self)` on destruction.
- **Atashkadeh-LOSS drain (in scope, lead call):** wire the `building_destroyed` event so destroying an Atashkadeh fires `apply_farr_change(-<building_destroyed_atashkadeh>, "atashkadeh_lost", ...)` (key `building_destroyed_atashkadeh=5.0` already exists; §4.3-spec'd; thematically core — losing the sacred fire is a legitimacy blow).

### D3 — Royal-largesse upkeep-lite (COIN)
The standing late-game pressure (ruling §1.2). On a **periodic sim cadence** (per-minute or per-N-ticks — cadence is balance-engineer's), drain **Coin** per living military unit per team via **`ResourceSystem.change_resource(team, &"coin", -amount, "royal_largesse_upkeep")`** — NOT `apply_farr_change` (upkeep is treasury, not Farr). A stalled army slowly bleeds the treasury; this is what gives AI-vs-AI batch matches the variance the zero-variance finding showed they lack. Runs on the appropriate economy/Farr sim phase, on-tick by construction.

## Scope OUT — explicitly deferred (do NOT build this wave)
- **Tier-2 Farr≥40 gate enforcement** → ships with the **tech-tier sub-wave** (it needs a tier-up path to exist first). Today the gauge only *reads* `tier2_threshold` for display; leave it that way.
- **Kaveh Event** (trigger detection AND consequences) → **Phase 5** (per `farr_system.gd` header; ratified 2026-06-22). Do not wire `kaveh_*` thresholds.
- **Hero-death drains** (`hero_died`, honest/fleeing distinction) → the Rostam/hero wave (no hero exists yet).
- Tech tiers, production-queue depth, full T&T caravans / local-stores / escort.
- *(Fix F6: this is the intentional split of the DECISIONS §1.2 "Phase-4 core" bundle into sub-waves. Tech-tiers + production-queues are NAMED follow-on sub-waves, not dropped.)*

## Data & constants (no magic numbers — CLAUDE.md)
- **New `BalanceData.farr.drain_rates` keys** (balance-engineer confirms/tunes starting values; §4.3 starting points: outnumbered ≈ 0.5/kill, economy-when-broken ≈ 1.0/worker): `snowball_kill_outnumbered`, `snowball_economy_when_broken`. **Retire** the deprecated `drain_snowball_per_kill` / `drain_snowball_worker` @export fields (`farr_config.gd:88/91`) once the dict keys land.
- **New upkeep fields** in `EconomyConfig` (balance-engineer): upkeep coin-per-military-unit magnitude + cadence.
- Reason strings as `Constants` StringName tokens (structural): `&"snowball_kill_outnumbered"`, `&"snowball_economy_when_broken"`, `&"atashkadeh_emission"`, `&"atashkadeh_lost"`, `&"royal_largesse_upkeep"`.
- **All Farr movement through `apply_farr_change(amount, reason, source_unit)`** (`farr_system.gd:210` — the single non-negotiable chokepoint; asserts on-tick, fixed-point, clamps [0,10000], emits `farr_changed`). All coin movement through `ResourceSystem.change_resource`.

## Observability (N=8 incident rule — non-negotiable)
- Every Farr change already logs + emits `farr_changed` via the chokepoint. Every upkeep coin drain, emitter register/unregister, and snowball-drain decision (including the **bail branches** — log *why* no drain fired) must log.
- **Wire the reserved F2 debug overlay** (`debug_overlay_manager` — F2 = Farr log, currently a logged no-op) as a **floating on-screen Farr-change log** (CLAUDE.md: "every Farr change surfaces in the debug overlay"). Built once, used forever.

## Cultural rationale (CLAUDE.md — keep the setting in the code's bones)
The §4.3 drains encode a load-bearing Shahnameh moral axis: the just king does not crush a fallen foe, and *farr* (divine glory) abandons the ruler who rules through cruelty or excess (Jamshid's fall; the tyranny of Zahhak). Royal largesse = down-flow generosity, the just-king's obligation to sustain his people and army from the treasury. **Each drain/gain site gets a source-ref comment** citing the referent + the DECISIONS 2026-06-22 entry. (Loremaster review on the comment text if uncertain.)

## Tests (GUT — unit + integration; never run two suites concurrently)
- D1a: drain fires at exactly 3:1 pop boundary; does NOT fire at 2.99:1; bails on `killer_unit_id=-1`, on unresolved killer, on friendly-fire (same-team killer).
- D1a determinism: **same-tick multi-death** produces identical Farr regardless of handler order (the F4 exclusion contract).
- D1b: fires only when BOTH military-broken conditions hold; does not fire when a barracks still stands; worker-vs-mine scope per Predicates.
- D2: `register_emitter`/`unregister_emitter` lifecycle; Atashkadeh emission accrues correct whole-x100 increments over N ticks (fixed-point, no drift); Atashkadeh-loss drain fires on destruction.
- D3: upkeep drains coin per military unit per cadence; zero military units → zero drain.
- Discipline: `apply_farr_change` is the SOLE Farr mutation path (no direct `_farr_x100` writes); coin via `ResourceSystem` only.
- Extend `match_harness` farr helpers (`_test_set_farr`) as needed; reuse the `&"units"`/`&"buildings"` enumeration seams.

## Conventions checklist (pre-PR)
- [ ] `apply_farr_change` single seam; coin via `ResourceSystem.change_resource`.
- [ ] All magnitudes in balance.tres; structural tokens in constants.gd; no magic numbers.
- [ ] Observability on every mutation + bail branch; F2 overlay wired.
- [ ] §9.M7: no defensive-fallback/`has_method` masking guards (L7 lint will catch).
- [ ] Determinism: no wall-clock in sim; fixed-point accumulators; multi-death order-invariant.
- [ ] Cultural source-ref comments at each §4.3 site.
- [ ] Correct file:line seams (the codeMap in the wave workflow is the source of truth — re-verify any line that has drifted; seam-drift is the BUG-C1 failure mode).

## Open items for balance-engineer (parallel, non-blocking to start D1/D2 structure)
1. Snowball drain magnitudes (`snowball_kill_outnumbered`, `snowball_economy_when_broken`) — confirm/tune from §4.3 starting points.
2. Upkeep-lite magnitude + cadence (coin per military unit per interval) — this is the variance source the AI-vs-AI duration baseline needs, so size it early.
3. (Carry-forward) the upkeep number is the first real lever for the post-Phase-4-core fun-gate; coordinate with the duration-baseline batch once GameRNG-or-upkeep gives batches variance.
