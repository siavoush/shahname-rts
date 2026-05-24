---
title: Phase 3 Session 9 — Wave 3-LocalDropoffs Kickoff
type: brief
status: draft
owner: lead
summary: Mazra'eh + Ma'dan implement RNC §5.2 IDropoffTarget; workers route to nearest kind-matching depot; Throne becomes fallback. Completes the MVP economy expansion loop foundation for Trade & Transport (Q1 from QUESTIONS_FOR_DESIGN 2026-05-24 entry).
audience: gp-sys-p3s3 (implementer), mirror-reviewer (brief-time review), shahnameh-loremaster (cultural framing N/A or minor)
read_when: at-kickoff
prerequisites: [docs/RESOURCE_NODE_CONTRACT.md §5.2, throne.gd (Wave-3-Throne reference), QUESTIONS_FOR_DESIGN.md 2026-05-24 Trade & Transport entry]
ssot_for:
  - Wave 3-LocalDropoffs scope + acceptance gates
references: [QUESTIONS_FOR_DESIGN.md, docs/RESOURCE_NODE_CONTRACT.md, docs/ANCHOR_CATEGORY_TAXONOMY.md, throne.gd]
tags: [wave-kickoff, phase-3, local-dropoffs, economy]
created: 2026-05-24
last_updated: 2026-05-24
brief_version: v1.0.0
---

# Wave 3-LocalDropoffs — Local resource drop-offs (Mazra'eh + Ma'dan)

## §1 — Wave goal (one sentence)

Workers depositing resources route to the **nearest kind-matching depot** (Mazra'eh for grain, Ma'dan for coin), falling back to the Throne when no kind-matching depot exists for the worker's team — solving the "long walk back to Throne from distant expansion mines" problem and laying the foundation for the Trade & Transport thesis (Phase 4+).

## §2 — Context

### Why now

Wave-3-Throne (just merged at session-8 close) shipped Throne-as-only-IDropoffTarget. Live-test surfaced the immediate friction: a worker gathering coin from a mine 60+ units away from the Throne walks the full distance back every cycle. RTS-idiomatic fix (AoE2 secondary drop-offs, StarCraft expansion bases) is to let players build secondary drop-offs near distant resources.

### Why this scope

Per `QUESTIONS_FOR_DESIGN.md` 2026-05-24 "Trade & Transport economy" entry:
- **Q1 (small, near-term)**: Ship local drop-offs as the MVP economy completion. Workers route to nearest kind-matching depot. Estimated 1 wave.
- **Q2 (large, positioning-level)**: Trade & Transport major feature (caravans + escort + upkeep + faction asymmetry). Phase 4+ design-chat thread.

This wave addresses Q1 only. Q2 stays open in design-chat queue.

### Non-throwaway property

Local drop-offs are the *foundation* for Trade & Transport. The local-store accumulation point (Mazra'eh/Ma'dan) becomes the caravan-origin in the bigger system. So even if the design chat eventually green-lights Q2, this wave's work is preserved-not-rewritten.

## §3 — Scope

### §3.1 — In scope

1. **`mazraeh.gd`** implements RNC §5.2 IDropoffTarget for grain. Accepts grain deposits; rejects coin (or routes them to fallback).
2. **`madan.gd`** implements RNC §5.2 IDropoffTarget for coin. Mirror shape to Mazra'eh; accepts coin; rejects grain.
3. **`ResourceSystem.dropoff_for_team_by_kind(team, kind)`** (NEW autoload method) — finds nearest kind-matching depot for team, falling back to Throne when none exist. Per-tick memoization + Pitfall #16 guards (mirror Wave-3-Throne `dropoff_for_team` pattern).
4. **`UnitState_Returning.enter()` Tier-2 query** — replaces the current `ResourceSystem.dropoff_for_team(team)` call with `dropoff_for_team_by_kind(team, _carry_kind)`. Worker's carry-kind drives the lookup.
5. **`Mazra'eh._ready` group-join** — adds `&"grain_depots"` group join (mirror Throne's `&"thrones"` group pattern).
6. **`Ma'dan._ready` group-join** — adds `&"coin_depots"` group join.
7. **Test surface:**
   - `test_mazraeh.gd` extension — IDropoffTarget protocol conformance, kind-filter (grain accepted, coin rejected), group membership.
   - `test_madan.gd` extension — same for coin.
   - `test_resource_system.gd` extension — `dropoff_for_team_by_kind` nearest-selection, kind-filter, Throne fallback, Pitfall #16 freed-Object handling.
   - `test_phase_3_local_dropoff.gd` (NEW integration) — Kargar gathers coin from Mine, deposits at NEAREST Ma'dan (not Throne) when Ma'dan exists; falls back to Throne when no Ma'dan.

### §3.2 — Out of scope (explicit)

- **Caravan / transport mechanic** — Trade & Transport Q2 territory. Local depot is the END point for now; no flow from depot to Throne yet.
- **Settlement / army upkeep** — Q2 territory.
- **Auto-distribute multi-select gather** — multi-select still queues all workers on one node (BUG-F1 wait-for-slot behavior preserved). The right UX is AoE2-style auto-distribute across nearest available kind-matching nodes, but that's a click_handler change and adjacent to the deposit-routing question. Defer to next wave or include if scope allows without bloat.
- **Visible HUD wealth-flow indicator** — Q2 territory.
- **Faction-specific drop-off semantics** — Iran and Turan both get the same kind-matching depot logic for now. Faction asymmetry is Q2.

### §3.3 — Forward-compat seams

The `dropoff_for_team_by_kind` method shape is forward-compat for:
- Adding more depot kinds (wood / stone / iron — see QUESTIONS_FOR_DESIGN 2026-05-24 "Resource economy expansion" entry).
- Adding **caravan source** to the depot (Trade & Transport Q2 — depot becomes the spawn point for the wagon).

The `&"grain_depots"` / `&"coin_depots"` group names are forward-compat for:
- Multi-purpose drop-off buildings that join multiple groups (a future Caravanserai might join both groups).

## §4 — Tracks

### §4.1 — Track 1 (gp-sys-p3s3, implementer) — primary

Surfaces 1-6 above. Anticipated commit shape:

**Commit 1:** `mazraeh.gd` + `madan.gd` IDropoffTarget protocol implementation. Both implement `deposit(resource_kind, amount, worker)` + `get_deposit_position()`. Kind-filter rejects non-matching deposits (loud log + no-op, no fallback to Throne to preserve mirror C1.4 only-one-path-per-cycle).

**Commit 2:** `ResourceSystem.dropoff_for_team_by_kind(team, kind)` — new autoload method. Per-tick memo keyed by `(team, kind)`. Pitfall #16 `is_instance_valid()` guard before return. Eviction subscriptions: `EventBus.throne_destroyed` (existing) + any future per-depot-destroyed signals.

**Commit 3:** `UnitState_Returning.enter()` Tier-2 query swap — `dropoff_for_team_by_kind(team, _carry_kind)`. Tier-3 self-position fallback preserved for tests without any depot.

**Commit 4:** Tests (mazraeh + madan extensions + resource_system extension + new integration test).

### §4.2 — Track 2 (loremaster-p3s5, brief-time cultural review) — light

Anticipated outputs:
- §9.J2 trichotomy classification: this wave is NOT introducing a new building, so trichotomy fires as **(a) clone-check** for Mazra'eh + Ma'dan implementing a duck-typed protocol. The buildings themselves are unchanged anchor-categories (civic-anchor / labor-organization respectively per ANCHOR_CATEGORY_TAXONOMY v1.1.0).
- Cultural-note framing for the **local-accumulation pattern**: should mazraeh.gd / madan.gd headers get a small forward-compat note? Per the user's design framing (QUESTIONS_FOR_DESIGN 2026-05-24): "the farm IS where the grain is stored before it goes to the king's seat; the mine IS where ore is processed." This is the dehqan-Throne reciprocity made spatially explicit. Loremaster can decide if a 3-5 line addendum is warranted.

Scope: ≤30min. May be N/A entirely if the loremaster judges the existing cultural-notes already cover the local-accumulation case implicitly.

### §4.3 — Track 3 (balance-engineer-p3s3, NO-OP expected)

No new balance numbers. Carry capacity / extract amounts unchanged. Confirmation only — likely a one-line "verified no balance changes."

## §5 — Acceptance gates

- [ ] Mazra'eh + Ma'dan both expose `deposit()` + `get_deposit_position()` per RNC §5.2.
- [ ] `ResourceSystem.dropoff_for_team_by_kind(team, KIND_GRAIN)` returns nearest Mazra'eh for team, falls back to Throne, returns null when nothing exists.
- [ ] Same for `KIND_COIN` → nearest Ma'dan → Throne fallback.
- [ ] Workers with `_carry_kind = KIND_COIN` walk to nearest Ma'dan (or Throne if none).
- [ ] Workers with `_carry_kind = KIND_GRAIN` walk to nearest Mazra'eh (or Throne if none).
- [ ] Mirror C1.4 only-one-path-per-cycle preserved (deposit credits exactly once per gather cycle — observable via test assertion).
- [ ] Pitfall #16 `is_instance_valid()` guard on memo cache entries.
- [ ] §9.M6 log instrumentation: `[resource] dropoff_for_team_by_kind(team=X, kind=Y) → <depot>` throttled 1/3sec.
- [ ] `[mazraeh] deposit_received` + `[madan] deposit_received` logs (similar to `[throne]`).
- [ ] Full headless suite green.
- [ ] Live-test gate: lead lives-tests grain + coin gather/deposit at local depots; verifies Throne fallback when local depot absent.

## §6 — Canonical references gp-sys should grep before implementing (§9.L10)

- `throne.gd:344-380` — RNC §5.2 IDropoffTarget signature shape + kind-filter pattern. Mazra'eh + Ma'dan should mirror.
- `resource_system.gd:493-565` — existing `dropoff_for_team(team)` + memoization + Pitfall #16 guard + EventBus.throne_destroyed eviction. New `dropoff_for_team_by_kind` extends this pattern.
- `unit_state_returning.gd:130-160` — three-tier resolution in `enter()` (BUG-E1 fix shape). Tier-2 query changes from `dropoff_for_team(team)` to `dropoff_for_team_by_kind(team, carry_kind)`.
- `mazraeh.gd` + `madan.gd` headers — existing structure for cultural-note + group-join pattern. New protocol methods slot into the same shape.

## §7 — Risks

- **R1 — Mazra'eh as both gather-source AND drop-off creates a degenerate case.** Workers gathering at Mazra'eh A and depositing at Mazra'eh A — zero-distance walk. Not visually distinguishable from the pre-fix Throne-only behavior in some cases. *Mitigation:* This is fine — the Mazra'eh case proves the protocol shape works; the gameplay payoff is mostly on Ma'dan side (mine far from Throne, Ma'dan built near mine, short walk).
- **R2 — Memo cache (team, kind) keying complexity.** `dropoff_for_team` was keyed by team alone; `dropoff_for_team_by_kind` is keyed by (team, kind). Pitfall #18 (PackedByteArray copy-on-write) is **N/A** because the memo is a regular Dictionary with Node3D values — no value-type-collection trap. But the eviction subscription needs to invalidate the right (team, kind) entry, not the whole cache.
- **R3 — Kind-filter false-rejects.** If a worker's `_carry_kind` is mis-set (e.g., a Kargar gathering from a future wood-tree resource that doesn't have a depot yet), the lookup returns null → falls back to Throne. This is correct (don't lose the deposit) but might mask schema bugs. Log clearly when a `dropoff_for_team_by_kind` falls back to Throne, so live-test catches the mismatch.
- **R4 — Test fixture timing.** The Wave-3-Throne BUG-E1 regression test was deferred (couldn't reliably exercise the MovementComponent scheduler in the test fixture). Same pattern may apply here. Smoke tests + live-test gate are acceptable; deep behavioral integration tests are nice-to-have.

## §8 — Coordination

- **§9.E1 mode:** single-track (gp-sys), Track 2 (loremaster) is parallel + light, Track 3 (balance-engineer) is no-op confirm.
- **Brief-time review:** dispatch mirror-reviewer + loremaster in parallel. Wait for both before dispatching gp-sys.
- **Live-test gate:** lead-driven on user return.

## §9 — Revision history

- **v1.0.0 — 2026-05-24** — initial brief, lead-drafted. Targets mirror-reviewer + loremaster brief-time review.
