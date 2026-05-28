---
title: Phase 3 Session 9 — Wave 3-BuildingDestructibility Kickoff
type: brief
status: draft
owner: lead
summary: Wire HealthComponent into all 8 Iran building scenes; each building subscribes to its OWN HC.health_zero local signal per BUG-G1 fix-pattern; building dies on hp=0 with state cleanup. Closes live-test "Ma'dan invulnerable to Turan attack" gap + unblocks future combat-on-buildings + economy-strangulation win paths.
audience: gp-sys-p3s3 (implementer), architecture-reviewer (brief-time review)
read_when: at-kickoff
prerequisites: [throne.gd (BUG-G1 local-signal-subscription canonical pattern), health_component.gd (local health_zero signal shipped session 8)]
ssot_for:
  - Wave 3-BuildingDestructibility scope + acceptance gates
references: [throne.gd, health_component.gd, combat_component.gd, building.gd]
tags: [wave-kickoff, phase-3, building-destructibility, combat]
created: 2026-05-25
last_updated: 2026-05-25
brief_version: v1.0.1
---

# Wave 3-BuildingDestructibility — All buildings get HP + destruction

## §1 — Wave goal (one sentence)

Wire `HealthComponent` into all 8 shipped Iran building scenes (Khaneh, Mazra'eh, Ma'dan, Sarbaz-khaneh, Atashkadeh, Throne, Sowari-khaneh, Tirandazi); each subscribes to its OWN HC's local `health_zero` signal per the BUG-G1 fix-pattern; on hp=0 the building cleans up registry state (Ma'dan modifier, Mazra'eh gather slot, FogSystem vision source, group memberships, etc.), emits a per-building destruction signal where one exists or `EventBus.building_destroyed(team, kind, unit_id)` generically, and queue_free's itself.

## §2 — Context

### Why now

User live-test of Wave 3-LocalDropoffs (PR #41) surfaced the gap: *"tried ordering turan units to attack [Ma'dan] but no visible damage or health going down."* Buildings have no `HealthComponent` in their `.tscn` files, so the duck-typed `get_health()` call at `combat_component.gd:195-199` returns null and the damage path silently bails (the defensive fallback at lines 196-198 clears the target). All 8 buildings are currently invulnerable.

This is consistent with the BUG-G1 architecture-reviewer finding: Throne's destruction signal subscription was wired up but no HC node in the scene yet — same gap, ALL buildings, not just Throne.

### Why it's small

- **The protocol exists** — `combat_component.gd:192-220` duck-types `get_health() -> HealthComponent` on any target. Adding HC to a building makes it attackable for free.
- **The pattern exists** — `throne.gd:_init_health_from_balance_data` wires the local `HC.health_zero` subscription correctly per BUG-G1. Mirror this in 7 other buildings.
- **No new combat logic needed.** Just scene-edits + the subscription wire-up.
- **No balance numbers needed** for most buildings — `bldg_throne.max_hp = 2000` exists; need similar entries for the others. balance-engineer's call on values.

### What it unblocks

- Combat-on-buildings (Turan can actually attack Iran's Ma'dan / Mazra'eh / Sarbaz-khaneh).
- Economy-strangulation win-condition (Phase 4+ Trade & Transport thesis Q2 requires destroyable depots).
- Throne destruction → match-end seam (Phase 8 win-screen will consume — currently the seam exists but can't fire because no HC).
- Visible HP bars on damaged buildings (UI follow-on, NOT this wave).

## §3 — Scope

### §3.1 — In scope

For each of the **8 shipped Iran buildings** (`khaneh.gd`, `mazraeh.gd`, `madan.gd`, `sarbaz_khaneh.gd`, `atashkadeh.gd`, `throne.gd`, `sowari_khaneh.gd`, `tirandazi.gd`):

1. **Scene edit:** add `[node name="HealthComponent" type="Node" parent="."]` to each `.tscn`, with `script = ExtResource("...health_component.gd...")`. Mirrors unit.tscn:68 pattern.
2. **`get_health() -> HealthComponent` method on `building.gd` BASE CLASS** (per architecture-reviewer C4.3 — adopted explicitly). All 8 subclasses inherit. Implementation: `return get_node_or_null(^"HealthComponent")`. Future Phase 4+ buildings (Dadgah, Barghah, Yadgar, Qal'eh) inherit for free.
3. **`_init_health_from_balance_data()` factored to `building.gd` BASE CLASS** (per architecture-reviewer C4.4 — adopted explicitly). All 8 subclasses inherit the local-signal subscription + max_hp wiring; only `_on_health_zero()` is subclass-specific. Throne's existing implementation at throne.gd:393-435 is the canonical body — promote to base. The HC subscription is to its OWN HC's local `health_zero` signal per BUG-G1 pattern. NO global EventBus.unit_health_zero subscription (Building unit_ids collide with Unit unit_ids).
4. **Per-subclass `_on_health_zero(unit_id_in: int)` override.** Idempotent latch (only fires once). Steps:
   - Log destruction: `[<kind>] destroyed team=X unit_id=Y`.
   - Clean up state specific to that building (see §3.1.a per-building cleanup checklist below).
   - Emit `EventBus.building_destroyed(team: int, kind: StringName, unit_id: int)` (the generic signal — see §3.1.b for the 3-place EventBus change). **Plus** for Throne specifically, ALSO emit existing `EventBus.throne_destroyed(team)` since that signal is already named and Phase 8 win-screen will consume.
   - `queue_free()`.
5. **`_exit_tree()` super-call sweep (architecture-reviewer C1.2 BLOCKER fix-up).** 7 of 8 building `_exit_tree()` overrides currently DON'T call `super._exit_tree()` — pre-existing bug. Today it's silent because buildings only `_exit_tree()` on scene shutdown. THIS WAVE makes destruction routine, exposing the bug. Each building's `_exit_tree()` MUST call `super._exit_tree()` first. Audit + fix:
   - `khaneh.gd:246`, `mazraeh.gd:382`, `madan.gd:479`, `sarbaz_khaneh.gd:350`, `atashkadeh.gd:467`, `sowari_khaneh.gd:365`, `tirandazi.gd:364` — add `super._exit_tree()` as first line. Throne (throne.gd:315) already does this correctly.
6. **BalanceData max_hp — ALREADY SHIPPED for ALL 8 buildings** (architecture-reviewer C1.1 BLOCKER catch). Values at balance.tres lines 215 (throne=2000), 233 (khaneh=200), 257 (mazraeh=300), 307 (madan=300), 352 (sarbaz_khaneh=400), 392 (atashkadeh=600), 426 (sowari_khaneh=750), 464 (tirandazi=650). **Brief v1.0.0 was WRONG** — Track 3 dispatch is unnecessary. gp-sys reads existing values via `BalanceData.buildings[<kind>].max_hp` per the BUG-C1 canonical Dictionary lookup pattern. NO new balance.tres entries.
7. **Tests:**
   - ONE parameterized integration test (Ma'dan canonical — per architecture-reviewer C4.2): full combat→HC→destruction→cleanup→signal chain via MatchHarness. Turan unit attacks Iran Ma'dan → HP decrements per tick → destroyed at hp=0 → modifier-registry release verified.
   - Per-building unit test: BUG-G1 regression — emit `EventBus.unit_health_zero(building.unit_id)` and assert no destruction (parameterized across 8).
   - Per-building unit test: per-building cleanup specifics (8 small tests; each verifies its own §3.1.a cleanup actions).

### §3.1.a — Per-building cleanup checklist

Each building has different state to clean up on destruction. **The pre-existing `_exit_tree()` cleanup IS ALREADY in place for fog deregistration** (because all 8 currently override `_exit_tree`). The destruction handler MAY duplicate fog deregister or trust `_exit_tree` to fire post-`queue_free()`. The brief's recommendation: have `_on_health_zero` call `queue_free()` and let `_exit_tree()` (with proper super-call per §3.1 item 5) handle fog + base-class sim_phase disconnect. Per-building cleanup ABOVE `_exit_tree` covers the registry / signal-emit / group-specific work:

- **Throne:** `&"thrones"` group (auto-removed on queue_free); `EventBus.throne_destroyed(team)` emit. Existing pattern at throne.gd:435-442 — verified.
- **Khaneh:** `ResourceSystem.change_population_cap(team, -POP_CAP_DELTA, &"khaneh_destroyed", self)` (architecture-reviewer C2.4 — API is `change_population_cap` at resource_system.gd:296, NOT `adjust_pop_cap`). Per spec §5: Khaneh contributes +5 pop cap (POP_CAP_DELTA=5); destruction decrements. Over-cap state (existing pop > new cap) is acceptable per existing change_population_cap semantics — workers persist; production blocks. No further action.
- **Mazra'eh:** `ResourceSystem.unregister_node(self)` (since Mazra'eh is registered as a gather node). Group memberships (`&"buildings"`, `&"grain_depots"`, `&"resource_nodes"`) auto-removed on queue_free. Active gather workers handle dead-target via existing `is_instance_valid(_target_node)` check in UnitState_Gathering:162-164.
- **Ma'dan:** `_registered_mine` field caches the mine ref at Stage 2 registration (architecture-reviewer C2.2 — add this field). On destruction: `if _registered_mine and is_instance_valid(_registered_mine): _registered_mine.unregister_extraction_modifier(self)`. Groups (`&"buildings"`, `&"coin_depots"`) auto-removed.
- **Sarbaz-khaneh / Sowari-khaneh / Tirandazi:** Production cancel (architecture-reviewer C2.5 — explicit field-clearing required). If `_production_state == &"training"`:
  ```
  var canceled_unit: StringName = _production_unit
  _production_state = &"idle"
  _production_unit = &""
  _production_progress_ticks = 0
  _production_total_ticks = 0
  # Emit one final signal so UI consumers hide the progress bar (else freed-building errors on subscribers).
  production_state_changed.emit(unit_id, &"idle", canceled_unit, 0.0)
  ```
  Costs are NOT refunded (drop policy per lead). Brief v1.0.0's "design call; gp-sys's call" is RESOLVED: drop, with explicit field-clearing + signal emit per architecture-reviewer C2.5.
- **Atashkadeh:** `&"buildings"` group (auto-removed). FarrSystem.unregister_emitter (forward-compat seam) — likely a no-op today since FarrSystem registration is wave-1B forward-compat.

### §3.1.b — EventBus.building_destroyed (the generic signal, architecture-reviewer R4 resolution)

Brief v1.0.0 left "per-building signals vs generic" ambiguous. Resolved: **GENERIC** `EventBus.building_destroyed(team: int, kind: StringName, unit_id: int)`. Lead's reasoning:
- 7 per-building signals would dwarf the existing `throne_destroyed` (1 signal at v0.34.0). Single generic scales cleanly.
- Throne keeps `throne_destroyed` (Phase 8 win-screen consumer; already named) AND also emits the generic. Other 7 emit generic only.
- AI consumers (future Phase 6+ raid-mechanic) need a uniform signal to drive "target weak buildings" logic; per-building dispatch table is anti-pattern.

The 3-place EventBus change (architecture-reviewer C2.1 — explicit enumeration):
1. **Declare the signal** in event_bus.gd near line 168 (next to `throne_destroyed`): `@warning_ignore("unused_signal") signal building_destroyed(team: int, kind: StringName, unit_id: int)`.
2. **Add to `_SINK_SIGNALS` array** at event_bus.gd:219 — telemetry should track destruction events (write-shaped).
3. **Add forwarder branch** in `_make_forwarder` switch — match the 3-int-arg shape pattern.

### §3.1.a — Per-building cleanup checklist

Each building has different state to clean up on destruction. gp-sys should walk each building's `_ready` / `_on_placement_complete` / `_on_construction_complete` paths to identify what it registers, then mirror an UN-register in `_on_health_zero`:

- **Throne:** group `&"thrones"`, FogSystem vision source. Already handled in throne.gd:286-308 — verify cleanup path on destruction.
- **Khaneh:** group `&"buildings"` (base class), pop_cap contribution. Pop cap must decrement on destruction (existing ResourceSystem.adjust_pop_cap or equivalent).
- **Mazra'eh:** groups `&"buildings"` + `&"grain_depots"`, ResourceSystem.unregister_node (since Mazra'eh is registered as a gather node). Gather slot release if mid-gather.
- **Ma'dan:** groups `&"buildings"` + `&"coin_depots"`, `MineNode.unregister_extraction_modifier(self)` on adjacent mine.
- **Sarbaz-khaneh:** group `&"buildings"`. Production queue cancel (refund or drop in-flight production per spec — design call; lead leans drop, balance-engineer can refine).
- **Atashkadeh:** group `&"buildings"`. FarrSystem.unregister_emitter (forward-compat seam) — likely a no-op today since FarrSystem registration is wave-1B forward-compat.
- **Sowari-khaneh:** group `&"buildings"`. Production queue cancel.
- **Tirandazi:** group `&"buildings"`. Production queue cancel.

### §3.2 — Out of scope (explicit)

- **HP bar UI on damaged buildings.** UI polish; ui-developer-track in a future wave. Today the only feedback is the HP-numeric in debug overlay (if at all) + the destruction event.
- **Visual destruction effects.** Placeholder shapes; no particle / smoke / rubble. Building just disappears via `queue_free()`.
- **Repair mechanic.** Workers don't repair buildings yet. Phase 4+ if at all.
- **Throne destruction → match-end seam.** The signal will FIRE correctly post-wave, but the win-screen consumer is Phase 8 per ARCHITECTURE §6 v0.34.0 + v0.35.0 entries. This wave makes the signal fire-able; consuming it is downstream.
- **Combat unit selection for "attack this building" UX.** Currently TuranController auto-targets via `_pick_target` (Wave 3B). Player-driven "attack this building" right-click routing is a UX item not exercised in this wave.
- **Balance tuning of building HP values.** balance-engineer-p3s3 picks initial values per building role (smaller buildings = lower HP; military = medium; HQ = high). Live-test or AI-vs-AI sim will refine.

### §3.3 — Forward-compat seams

- **EventBus.building_destroyed signal** (if gp-sys picks the generic shape over per-building signals) becomes the source of truth for future win-condition wiring, raid-mechanic accounting (Trade & Transport thesis Q2), and AI's "attack the economy" target-selection.
- **Per-building destruction-cleanup pattern** becomes the canonical hook for future buildings (Dadgah, Barghah, Yadgar, Qal'eh — Phase 4+).

## §4 — Tracks

### §4.1 — Track 1 (gp-sys-p3s3, implementer) — primary

8 buildings × (scene edit + .gd code + cleanup) + balance.tres entries + tests. Anticipated commit shape:

**Commit 1:** Scene edits — add HealthComponent node to all 8 .tscn files (mirror unit.tscn:68 pattern). One commit, atomic.

**Commit 2:** Building base — add `get_health() -> HealthComponent` method on `building.gd` (DRY, all subclasses inherit). Add base `_init_health_from_balance_data()` if not present (or factor out the Throne pattern at throne.gd:411-415 to base).

**Commit 3:** Per-building `_on_health_zero` handlers + cleanup. Mirror Throne's destruction handler. Each building extends with its specific state cleanup (per §3.1.a checklist). Emit destruction signal — gp-sys's call: per-building signals OR generic `EventBus.building_destroyed(team, kind, unit_id)`.

**Commit 4:** balance.tres max_hp entries for the 7 buildings that don't have one yet. balance-engineer-p3s3 nominally owns this but it's a small change; gp-sys can include unless balance-engineer pushes back.

**Commit 5:** Tests — unit + integration per §3.1 item 6.

### §4.2 — Track 2 (architecture-reviewer, brief-time review) — light

Same lens as Wave-3-LocalDropoffs brief-time review:
- §9.L12 canonical-pattern grep (does the brief's prescription match throne.gd's pattern?)
- BUG-G1 lesson absorbed (no global EventBus subscription)
- Mirror C1.4-style only-one-path discipline preserved
- Forward-compat for Trade & Transport caravan-raid mechanic
- Anything obvious missed.

### §4.3 — Track 3 (balance-engineer-p3s3, OPTIONAL audit) — verify shipped values

**Architecture-reviewer C1.1 BLOCKER catch**: max_hp values are ALREADY shipped for all 8 buildings. Brief v1.0.0's "set values for the others" prescription was a BUG-C1-shape brief-vs-shipped-schema mismatch. v1.0.1 corrects this.

Shipped values (balance.tres):
- throne=2000 (line 215)
- khaneh=200 (line 233)
- mazraeh=300 (line 257)
- madan=300 (line 307)
- sarbaz_khaneh=400 (line 352)
- atashkadeh=600 (line 392)
- sowari_khaneh=750 (line 426)
- tirandazi=650 (line 464)

**Track 3 is OPTIONAL** — balance-engineer-p3s3 has authoritative ownership per §9.L1; they may audit the shipped values vs gameplay-feel intuition and retune. But the brief does not BLOCK gp-sys on Track 3 — the wave proceeds with shipped values; balance tuning is post-live-test follow-on.

Lead's note for context: the §9.L11 brief-drafting balance-audit codified at session 8 close (the rule against exactly this kind of brief-vs-shipped mismatch) was ignored at brief v1.0.0 drafting time. Lead failed to grep `balance.tres` for existing entries before proposing new values. The architecture-reviewer caught this — adding to the §9.L11 incident-list as instance #7 (or whatever count is current). Worth flagging in session 9 close retro: §9.L11 was new; lead has not yet internalized the discipline.

### §4.4 — Track 4 (loremaster, N/A) — likely no cultural-note work

The HP-adding pattern is mechanical, not cultural-shape-touching. J2 trichotomy = (a) clone-check (no new anchor-categories, no new sub-slots, no new buildings). Skip dispatch unless brief-time review surfaces a cultural framing question.

## §5 — Acceptance gates

- [ ] All 8 buildings have HealthComponent node in their .tscn.
- [ ] All 8 buildings expose `get_health() -> HealthComponent` method (duck-typed match for `combat_component.gd:199`).
- [ ] All 8 buildings subscribe to LOCAL HC.health_zero signal (BUG-G1 pattern).
- [ ] None of the buildings subscribe to global `EventBus.unit_health_zero` channel.
- [ ] All 8 buildings have max_hp BalanceData entry.
- [ ] Per-building destruction cleans up registry/group/Subsystem state per §3.1.a checklist.
- [ ] Per-building destruction emits destruction signal once (latch — repeated emit blocked).
- [ ] Per-building destruction `queue_free`s the node.
- [ ] §9.M6 log instrumentation: `[<kind>] destroyed team=X unit_id=Y` for each building's destruction.
- [ ] §9.D10 cross-track diagnostic discipline applied (post-stage full-suite run, broadcast non-self failures).
- [ ] §9.F5 producer-stub-consumer-integration-test discipline applied (integration test fires destruction through the COMBAT path, not by direct take_damage_x100 calls).
- [ ] BUG-G1 regression test for each building (per the Throne pattern): emit global `EventBus.unit_health_zero(building.unit_id)` and assert no destruction signal fires.
- [ ] Full headless suite passes (1564+).
- [ ] Live-test gate: lead lives-tests Turan attacks Iran Ma'dan + Mazra'eh → both take visible damage → both destroyed at hp=0 → cleanup verified (Ma'dan's mine modifier release; Mazra'eh's gather slot release).

## §6 — Canonical references gp-sys should grep before implementing (§9.L10)

- `throne.gd:386-448` — canonical BUG-G1 local-signal-subscription pattern. Mirror for 7 other buildings.
- `health_component.gd:42-56` — local `health_zero` signal declaration + Building-subclass-specific rationale in header.
- `health_component.gd:243-264` — emit-order discipline (local signal before global, both before unit_died).
- `combat_component.gd:192-220` — duck-typed `get_health()` call path. Verify your `get_health()` impl matches the expected shape.
- `unit.tscn:68-71` — canonical `[node name="HealthComponent" type="Node" parent="."]` scene-edit pattern. Mirror in each building's .tscn.
- `game/data/balance.tres:213-219` — `bldg_throne` BalanceData entry shape (max_hp + cost fields). Mirror for the other 7 buildings' max_hp.
- `madan.gd:_on_construction_complete` / `mazraeh.gd:_on_construction_complete` — where state is REGISTERED. Mirror the unregister in `_on_health_zero` per §3.1.a.

## §7 — Risks

- **R1 — Per-building cleanup is N=7 different things.** Each building registers different state (group memberships, registry entries, vision sources, etc.). Risk: gp-sys misses one and a registry entry leaks → orphaned references → potential Pitfall #16 freed-Object surface in future. *Mitigation:* §3.1.a checklist is the explicit enumeration. gp-sys should walk EACH building's _ready / _on_construction_complete and mirror the un-register.
- **R2 — Mazra'eh gather-slot release on destruction.** If a worker is mid-gather at the Mazra'eh when it's destroyed, the worker has an active extraction with a slot held. The Mazra'eh's release path needs to free that slot AND signal the worker (the worker should transition to Idle via the existing dead-target handling in UnitState_Gathering at lines 162-164 — `is_instance_valid(_target_node)` check). Should "just work" via existing patterns, but worth verifying.
- **R3 — Throne destruction is fully wired but balance-engineer's max_hp = 2000 may be wrong** for actual combat balance. Live-test will surface this. Phase 4 / playtest can tune.
- **R4 — Choice of per-building signals vs generic EventBus.building_destroyed.** Both shapes have merit. Per-building (e.g., `EventBus.mazraeh_destroyed(team)`) is explicit but proliferates signals; generic `EventBus.building_destroyed(team, kind, unit_id)` is uniform but consumers need to filter. **gp-sys's call.** Lead leans generic for the 7 non-Throne buildings (the Throne signal already exists and is named; keep it; add generic for the others).
- **R5 — Combat range vs building footprint.** Combat range is point-based (combat_component.gd:181-186 uses XZ-only distance to target.global_position). Buildings have footprints (4x4 BoxMesh for Throne; smaller for others). A unit attacking the Throne with attack_range=2 from the EDGE of the Throne might be considered out-of-range because the distance is measured to the Throne's center (~2 units from the edge). Live-test will show whether this matters; for now units close to attack-range and try; if out-of-range, they move closer. Acceptable per MVP scope.

## §8 — Coordination

- **§9.E1 mode:** single-track (gp-sys), Track 2 (architecture-reviewer) is parallel + light, Track 3 (balance-engineer) is small numeric input (HP values), Track 4 (loremaster) likely N/A.
- **Brief-time review:** dispatch architecture-reviewer in parallel. Wait before dispatching gp-sys.
- **Live-test gate:** lead-driven on user return.
- **Wave-close → session 9 close retro:** after this wave merges, kick off session 9 close retro (3 waves shipped this session: Throne, LocalDropoffs, BuildingDestructibility — rich material per user).

## §9 — Revision history

- **v1.0.1 — 2026-05-25** — architecture-reviewer brief-time review findings folded in (4th consecutive empirical brief-time review validation N=4):
  - **C1.1 BLOCKER** — max_hp values were ALREADY shipped for ALL 8 buildings (lines 215, 233, 257, 307, 352, 392, 426, 464 of balance.tres). Brief v1.0.0's §3.1 item 5 + §4.3 Track 3 dispatch were based on false premise (BUG-C1-shape brief-vs-shipped mismatch). Fixed: §3.1 item 6 acknowledges shipped values; §4.3 Track 3 reframed as OPTIONAL audit, not blocking dispatch. **Same §9.L11 shape we codified at session 8 close — lead failed to apply own discipline; retro candidate.**
  - **C1.2 BLOCKER** — 7 of 8 building `_exit_tree()` overrides don't call `super._exit_tree()` — pre-existing silent bug that this wave amplifies. Fixed: §3.1 item 5 NEW global checklist item — each building's _exit_tree MUST call super._exit_tree (audit + fix all 7).
  - **C2.1** — R4 resolved (per-building vs generic): GENERIC `EventBus.building_destroyed(team, kind, unit_id)`. §3.1.b explicit 3-place EventBus change enumeration.
  - **C2.2** — Ma'dan `_registered_mine` field added to spec (cache the mine ref at Stage 2; unregister via cache on destruction).
  - **C2.4** — Fixed API name: `change_population_cap(team, delta, reason, source_unit)` not `adjust_pop_cap`.
  - **C2.5** — Production-cancel field-clearing + `production_state_changed.emit(unit_id, &"idle", canceled_unit, 0.0)` made explicit for 3 producer buildings.
  - **C4.3 + C4.4** — Centralize `get_health()` AND `_init_health_from_balance_data()` on building.gd base class. Adopted explicitly per Manifesto SSOT principle.

- **v1.0.0 — 2026-05-25** — initial brief, lead-drafted. Targets architecture-reviewer brief-time review.
