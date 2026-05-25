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
brief_version: v1.0.0
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
2. **`get_health() -> HealthComponent` method on each building's .gd** (or on `building.gd` base if cleaner) — returns the HealthComponent child node. Duck-typed match for combat_component.gd's call site.
3. **Local-signal subscription** — each building subscribes to its OWN HC's local `health_zero` signal at `_init_health_from_balance_data` (or equivalent init point). Mirrors throne.gd:402-403 canonical pattern. NO global EventBus.unit_health_zero subscription (per BUG-G1 architecture lesson — Building unit_ids collide with Unit unit_ids).
4. **Destruction handler `_on_health_zero(unit_id_in: int)` on each building.** Idempotent latch (only fires once). Steps:
   - Log destruction: `[<kind>] destroyed team=X unit_id=Y`.
   - Clean up state specific to that building (see §3.1.a per-building cleanup checklist below).
   - Emit destruction signal: either the existing per-building signal (e.g., `EventBus.throne_destroyed(team)` already exists for Throne) OR a generic `EventBus.building_destroyed(team: int, kind: StringName, unit_id: int)` for the other 7 — gp-sys's call.
   - `queue_free()`.
5. **BalanceData max_hp entries** for each building (`bldg_khaneh.max_hp`, `bldg_mazraeh.max_hp`, etc.). `bldg_throne.max_hp = 2000` exists. balance-engineer-p3s3 sets values for the others — see §4.3 Track 3.
6. **Tests:**
   - Per-building unit test: building takes damage via `HC.take_damage_x100` → at hp=0 the destruction signal fires once (latch) AND state cleanup ran.
   - Per-building unit test: Unit unit_id collision SHOULD NOT trigger building destruction (regression-lock — BUG-G1 pattern: global EventBus.unit_health_zero with matching int does NOT fire building's `_on_health_zero`).
   - Per-building unit test: cleanup happens (e.g., Ma'dan destruction unregisters from MineNode's modifier list; Mazra'eh destruction frees its gather slot; FogSystem vision source removed).
   - Integration test: Turan unit attacks Iran building → building HP decrements per tick → at hp=0 building queue_free'd from scene tree + group memberships cleared.

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

### §4.3 — Track 3 (balance-engineer-p3s3, light) — initial HP values

Pick initial max_hp values for the 7 buildings without one:
- `bldg_khaneh.max_hp` — proposed ~500 (small civic, low priority target, easy to raze)
- `bldg_mazraeh.max_hp` — proposed ~600 (productive but vulnerable; player rebuild expected)
- `bldg_madan.max_hp` — proposed ~700 (sturdier; mine staffing) — your call
- `bldg_sarbaz_khaneh.max_hp` — proposed ~1200 (military, defended posture)
- `bldg_atashkadeh.max_hp` — proposed ~1500 (sacral, high-value-target, Farr loss on destruction per spec §4.3 makes it expensive to lose)
- `bldg_sowari_khaneh.max_hp` — proposed ~1200 (Tier 2 military, parallel to Sarbaz-khaneh)
- `bldg_tirandazi.max_hp` — proposed ~1000 (Tier 2 military, slightly less than Sowari given archer-tradition lighter built)

These are LEAD-PROPOSED starting points per §9.L11 brief-drafting balance-audit (the rule we shipped session 8). **balance-engineer authoritative override expected per §9.L1.** Game-feel will tune in live-test.

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

- **v1.0.0 — 2026-05-25** — initial brief, lead-drafted. Targets architecture-reviewer brief-time review.
