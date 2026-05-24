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
brief_version: v1.0.2
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

### Non-throwaway property (honest framing per architecture-reviewer C2.4)

The IDropoffTarget protocol + group-join pattern + `dropoff_for_team_by_kind` lookup shape are **platform-shape — preserved-not-rewritten** when Q2 lands.

The deposit-INTERNALS, however, **will be refactored** when Q2 lands: today's Mazra'eh/Ma'dan are deposit-RELAYS (they call `ResourceSystem.change_resource` directly, no local accumulation); Q2's version will be deposit-ACCUMULATORS (track `_local_stock_x100`, emit caravans on full). The protocol method signatures stay; the bodies change.

Net forward-compat: ~70% of this wave's work survives Q2 unchanged (protocol, groups, lookup, tests). ~30% (the in-method bodies) will be re-implemented. This is acceptable per the "ship Option 1 now" framing — the platform-shape work is what's load-bearing.

Optionally (per architecture-reviewer C4.3) we could scaffold a `_local_stock_x100: int = 0` field on Mazra'eh + Ma'dan now (declared but unused) to signal Q2 intent and avoid Property-Schema-Change-In-Phase-4 ripple. **Decision: scaffold the field; cheap; signals Q2 intent.**

## §3 — Scope

### §3.1 — In scope

1. **`mazraeh.gd`** implements RNC §5.2 IDropoffTarget for grain. Accepts grain deposits; rejects coin (or routes them to fallback).
2. **`madan.gd`** implements RNC §5.2 IDropoffTarget for coin. Mirror shape to Mazra'eh; accepts coin; rejects grain.
3. **`ResourceSystem.dropoff_for_team_by_kind(team, kind)`** (NEW autoload method) — finds nearest kind-matching depot for team, falling back to Throne when none exist. Per-tick memoization (per architecture-reviewer C2.3: **nested Dictionary** `_dropoff_memo_by_kind: Dictionary` where keys are `team` and values are `Dictionary[StringName, Node3D]` — enables per-(team, kind) eviction). Throttled `[resource]` log key MUST also be `(team, kind)` — separate throttle per kind so grain-lookups and coin-lookups on same team don't throttle each other. Pitfall #16 `is_instance_valid()` guard before return (mirror Wave-3-Throne `dropoff_for_team` pattern). EventBus.throne_destroyed eviction: evicts ALL kinds for that team (Throne is the universal fallback). **REPLACE decision (per C1.2):** the existing `ResourceSystem.dropoff_for_team(team)` is REPLACED by `dropoff_for_team_by_kind` — call-site sweep targets are listed in §6 and explicitly include the two `unit_state_returning.gd` sites (lines 152 + 274). Existing `dropoff_for_team` method body becomes a thin wrapper `return dropoff_for_team_by_kind(team, &"")` for any legacy/test path that doesn't have a kind in scope (defensive; we don't expect any such path post-sweep).
4. **`UnitState_Returning` BOTH call sites Tier-2 query swap** (per architecture-reviewer C1.1 — TWO sites, not one):
   - **`enter()` line ~152** — walk-target resolution. Swap `ResourceSystem.dropoff_for_team(team)` → `dropoff_for_team_by_kind(team, _carry_kind_at_enter)`. `_carry_kind_at_enter` reads `ctx._carry_kind` at the same point the payload `deposit_target` Vector3 is checked (Tier-1).
   - **`_perform_deposit()` line ~274** — deposit-routing decision. Swap `ResourceSystem.dropoff_for_team(team)` → `dropoff_for_team_by_kind(team, kind)` where `kind` is the local `kind` variable already in scope from line 255 read.
   - **Critical:** if these two queries return DIFFERENT depots (e.g., depot destroyed mid-walk), the worker may walk to position A but try to deposit at position B. Log this divergence loudly (`[resource] dropoff_for_team_by_kind enter→deposit divergence team=X kind=Y enter=<refA> deposit=<refB>`) and route the deposit through whichever target `_perform_deposit` query returned. The cached `_deposit_target_pos` is stale but the C1.4 invariant (deposit credits exactly once) still holds via the second query's target.
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

**Commit 1:** `mazraeh.gd` + `madan.gd` IDropoffTarget protocol implementation. Both implement `deposit(resource_kind, amount, worker)` + `get_deposit_position()`. Each declares `const ACCEPTED_KIND: StringName = Constants.KIND_GRAIN` (Mazra'eh) or `KIND_COIN` (Ma'dan) — note this is the RESOURCE kind (per RNC §4.6 vs the BUILDING `kind = &"mazraeh"`/`&"madan"`). Kind-filter behavior on mismatch (per architecture-reviewer C2.1):
- **Loud log** (`[mazraeh] deposit_rejected kind_mismatch got=X expected=Y worker=Z` / same for Ma'dan).
- **Zero the worker's carry** (set `worker._carry_kind = &""` + `worker._carry_amount_x100 = 0`) so the stale carry doesn't survive to next gather cycle. Per BUG-C1/D1/D2 defensive-fallback-masking lesson: rejection without carry-zero is a silent-loss bug. Loud log + zero, NOT loud log + no-op.
- **No fallback to Throne** from inside the building (preserves mirror C1.4 only-one-path-per-cycle).
- Authoritative invariant (per architecture-reviewer C2.1 mitigation): `dropoff_for_team_by_kind` MUST NEVER return a kind-mismatched depot in the first place. Building-side kind-filter is the double-check assertion (defense in depth); the lookup-side filter is the canonical gate. If building-side ever fires, it's a bug signal — the loud log enables diagnosis.

**No deposit-slot mechanic** (per architecture-reviewer C2.5) — Mazra'eh and Ma'dan accept arbitrarily many deposits per tick, same as Throne. AoE2-style deposit-slot queuing is out of scope.

**Commit 2:** `ResourceSystem.dropoff_for_team_by_kind(team, kind)` — new autoload method. Per-tick memo keyed by `(team, kind)`. Pitfall #16 `is_instance_valid()` guard before return. Eviction subscriptions: `EventBus.throne_destroyed` (existing) + any future per-depot-destroyed signals.

**Commit 3:** `UnitState_Returning.enter()` Tier-2 query swap — `dropoff_for_team_by_kind(team, _carry_kind)`. Tier-3 self-position fallback preserved for tests without any depot.

**Commit 4:** Tests (mazraeh + madan extensions + resource_system extension + new integration test).

### §4.2 — Track 2 (loremaster-p3s5, brief-time cultural review) — light

**Outcome of brief-time review (delivered 2026-05-24):**

- **§9.J2 trichotomy classification: (b) slot-fit-verify, NOT (a) clone-check** (loremaster reclassified the lead's pre-assignment per the J2 graduated form's lead-pre-classifies / loremaster-validates contract). Reasoning: this wave isn't a new building cloning an existing template — it's a *protocol-role* (IDropoffTarget) being distributed across multiple anchor-categories. Mazra'eh fills the *grain-depot* sub-slot of the IDropoffTarget role; Ma'dan fills *coin-depot*; Throne (existing) fills *fallback / catch-all*. **Loremaster flags this as a J2 refinement candidate (N=1):** the trichotomy concept generalizes from *anchor-category-level* to *protocol-role-level* classification. Not graduating yet (N=1 at the protocol-role variant); will graduate if a 4th building acquires a new protocol-role in future waves. Track as retro candidate.
- **J3 (Persian-term gloss): N/A — no gloss-drift.** Existing *dehqan* (Mazra'eh) and *ma'dan-e elm* (Ma'dan) glosses cover the local-accumulation register cleanly. No high-baggage tricky-gloss correction needed.
- **J4 (claim-mechanism-reviewer triples): 9 mechanical dependencies routed across 3 cultural claims**; 1 explicit DEFERRED (caravan mechanic, Phase 4+). All Track-1-side dependencies owned by gp-sys; loremaster-side dependencies are the addenda below.
- **Paste-ready addenda for `mazraeh.gd` + `madan.gd` headers** delivered by loremaster (each ~12-14 lines, mirrors Sarbaz-khaneh forward-compat note structural pattern). Lands at **Commit 1.5 (lead-paste)** per established Wave 2A.5 / 2B / Wave-3-Throne pattern. Addenda surface: (a) dehqan-Throne reciprocity made spatially explicit; (b) Ma'dan-as-staging-yard for ore; (c) forward-compat seam for Phase 4+ Trade & Transport caravan-origin.

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

- `throne.gd:344-380` — RNC §5.2 IDropoffTarget signature shape. Mazra'eh + Ma'dan should mirror. **Note: Throne does NOT kind-filter** (accepts all kinds); Mazra'eh + Ma'dan WILL differ via `ACCEPTED_KIND` constant.
- `resource_system.gd:493-565` — existing `dropoff_for_team(team)` + memoization + Pitfall #16 guard + EventBus.throne_destroyed eviction. New `dropoff_for_team_by_kind` REPLACES (per §3.1 item 3); the existing method becomes a thin wrapper.
- `unit_state_returning.gd:130-160` — three-tier resolution in `enter()` (BUG-E1 fix shape). **Tier-2 query swap site #1** — `dropoff_for_team(team)` → `dropoff_for_team_by_kind(team, _carry_kind_at_enter)`.
- `unit_state_returning.gd:248-290` — `_perform_deposit()` method. **Tier-2 query swap site #2** — `dropoff_for_team(team)` → `dropoff_for_team_by_kind(team, kind)` (kind already in scope from line 255 read). Per architecture-reviewer C1.1: missing this site would produce the worker-walks-to-Mazra'eh-but-deposits-at-Throne bug.
- `mazraeh.gd` + `madan.gd` headers — existing structure for cultural-note + group-join pattern. New protocol methods slot into the same shape. Add `&"grain_depots"` / `&"coin_depots"` group join.
- `constants.gd:91-92` — `KIND_COIN = &"coin"` + `KIND_GRAIN = &"grain"` StringName values. These are what `_carry_kind` holds and what Mazra'eh/Ma'dan's `ACCEPTED_KIND` must equal.
- `unit.gd:202` — `var _carry_kind: StringName = &""` field declaration.
- `unit_state_gathering.gd:258-264` — where `_carry_kind` is written (by `complete_extract` payload). Doesn't need changes; understanding the source helps gp-sys verify the kind-StringName flow.
- `docs/RESOURCE_NODE_CONTRACT.md:556-594` — IDropoffTarget protocol SSOT. §4.6 distinguishes Building.kind vs resource_kind (avoid confusing them).

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
- **v1.0.2 — 2026-05-24** — loremaster brief-time cultural review delivered (Track 2):
  - §9.J2 reclassified from (a) clone-check (lead's pre-assignment) to **(b) slot-fit-verify** at the *protocol-role* level (Mazra'eh fills grain-depot sub-slot, Ma'dan fills coin-depot sub-slot of the IDropoffTarget protocol-role). Loremaster authoritative per J2 graduated form.
  - **J2 refinement candidate flagged (N=1):** trichotomy generalizes from anchor-category-level to protocol-role-level classification. Track as retro candidate; graduates if 4th building gains new protocol-role in future waves.
  - J3 N/A — no Persian-term gloss-drift. J4 9 dependencies routed across 3 cultural claims, 1 DEFERRED (caravan, Phase 4+).
  - Paste-ready addenda for `mazraeh.gd` + `madan.gd` headers delivered (loremaster-verbatim, ~12-14 lines each). Lands at Commit 1.5 (lead-paste) per established Wave 2A.5 / 2B / Wave-3-Throne pattern. Surfaces dehqan-Throne reciprocity made spatially explicit + Phase 4+ Trade & Transport forward-compat seam.

- **v1.0.1 — 2026-05-24** — architecture-reviewer brief-time review findings folded in:
  - **C1.1 BLOCKER** — second `unit_state_returning.gd` call site (`_perform_deposit:274`) added to §3.1 #4 + §6 canonical references. Without this fix the worker would walk to Mazra'eh but deposit at Throne anyway (C1.4 silent violation).
  - **C1.2 BLOCKER** — `dropoff_for_team` vs `dropoff_for_team_by_kind` coexistence resolved as **REPLACE** (existing becomes thin wrapper); call-site sweep targets listed in §6.
  - **C2.1 RISK** — kind-filter rejection on Mazra'eh/Ma'dan now zeroes worker carry (not just logs + no-op) — prevents stale-carry-survives-across-cycles bug. Plus authoritative-invariant clarification: lookup-side filter is the canonical gate; building-side is defense-in-depth.
  - **C2.3 RISK** — memo shape pinned: nested Dictionary `_dropoff_memo_by_kind[team][kind]`. Throttle log key also `(team, kind)`. EventBus.throne_destroyed evicts all kinds for that team.
  - **C2.4 RISK / C4.3 SUGGEST** — non-throwaway-property honestly reframed (platform-shape preserved; deposit-internals refactor at Q2). Plus `_local_stock_x100: int = 0` field scaffold decision.
  - **C2.5 RISK** — explicit "no deposit-slot mechanic" on Mazra'eh/Ma'dan; accepts arbitrarily many deposits per tick.
  - **C2.6 RISK** — depot-destroyed-mid-walk case explicitly handled: `_perform_deposit` re-queries `dropoff_for_team_by_kind`; if result differs from `enter()`'s cached target, log divergence loudly and route through the second query's target (preserves C1.4 invariant via fresh query).
  - **C2.7 / §6 LOW** — canonical-reference list expanded with second call site (`_perform_deposit:248-290`) + Constants.KIND_* references + unit.gd:202 carry field declaration + unit_state_gathering.gd:258-264 carry-write source + RNC §5.2 protocol SSOT.
  - **C2.2 LOW** — `ACCEPTED_KIND` constant naming pinned: `Constants.KIND_GRAIN` / `KIND_COIN` (the resource kind, distinct from Building.kind per RNC §4.6).
  - Acceptance gates §5: implicit pass on architecture-reviewer C4.1 (test the kind-matched local depot's `deposit()` is what fires, observable via `[mazraeh] deposit_received` / `[madan] deposit_received` log).
