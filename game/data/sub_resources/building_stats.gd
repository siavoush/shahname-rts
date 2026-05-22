##
## BuildingStats — per-building tunable numbers.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.2
## All values are starting points to be tuned through playtesting per
## 01_CORE_MECHANICS.md §0. balance-engineer sets values; gameplay-systems
## consumes them.
##
## Reference: 01_CORE_MECHANICS.md §5 (building list, costs, purposes).
class_name BuildingStats extends Resource

## Maximum hit points for this building.
@export var max_hp: float = 0.0

## Coin cost to construct this building.
@export var coin_cost: int = 0

## Grain cost to construct this building.
@export var grain_cost: int = 0

## Ticks for a worker to complete construction.
## At 30 Hz: 900 ticks = 30s. Qal'eh is 2700 ticks = 90s per spec.
@export var construction_ticks: int = 900

## Farr generated passively per tick (positive float).
## 0.0 for buildings that do not generate Farr.
## Atashkadeh target: +1 Farr/min = 1/1800 Farr/tick ≈ 0.000556 Farr/tick.
## FarrSystem reads this field; apply_farr_change() is the chokepoint per CLAUDE.md.
@export var farr_per_tick: float = 0.0

## Farr generated passively per minute in x100 fixed-point (integer arithmetic).
## 0 for buildings that do not generate Farr (the default for all non-sacral buildings).
## Atashkadeh: +1 Farr/min = 100. Dadgah/Barghah: +0.5 Farr/min = 50.
## Yadgar: +0.25 Farr/min = 25. Per 01_CORE_MECHANICS.md §4.3 Farr generators list.
## Fixed-point scale per Sim Contract §1.6. FarrSystem may read farr_per_tick
## (float path) or this field (integer path) — both represent the same source value.
@export var farr_per_min_x100: int = 0

## Population cap contribution. Khaneh (house) adds +K to its owner team's
## population_cap when construction completes. Phase 3 session 1 wave 1C
## ships Khaneh first; future cap-contributing buildings (Sarbaz-khaneh?)
## set their own value here. 0 for non-housing buildings (Atashkadeh,
## Mazra'eh, Throne, etc.).
##
## Spec reference: 01_CORE_MECHANICS.md §5 — "Khaneh (house) — Population
## cap +5 per building. 50 coin." Session-6 close retro (2026-05-22):
## reverted from session-1 wave-1C placeholder (+10) back to spec value
## (+5). The +10 placeholder ("give workers more headroom while production
## queues pending") was a workaround that's no longer needed; defer to
## spec until AI-vs-AI playtest surfaces real balance signal.
## balance-engineer tunes via balance.tres going forward.
@export var population_capacity: int = 0

## Building's tier in the tech progression (1 = Tier 1 baseline, 2 = Tier 2,
## etc.). Used by future TechSystem to gate placement on tier prereqs.
##
## H3 dormant-schema first-exercise (per §9.H3, Wave 2B Track 3):
## All 5 existing Tier-1 buildings (Khaneh, Mazra'eh, Ma'dan, Sarbaz-khaneh,
## Atashkadeh) inherit the default `tier = 1`. Sowari-khaneh + Tirandazi
## (Wave 2B) first-populate this field with `tier = 2` — the H3-trigger
## moment. Consumers DEFERRED to Wave 2C / Phase 4: TechSystem.is_tier_2_
## unlocked, BuildPlacementHandler / BuildMenu gating reads, Atashkadeh-
## built + Farr >= 40 prereq checks. Zero existing readers at field-intro
## time (L6 sweep result documented in commit message).
##
## When Wave 2C ships the gateway logic, that wave will first-populate the
## CONSUMER side of this field — triggering its own H3 + L6 sweep at THAT
## moment for the new consumer callsites.
##
## Spec reference: 01_CORE_MECHANICS.md §5 lines 189-199 (Tier-2 buildings).
@export var tier: int = 1


# === Modifier-emitter fields (wave 1B — Ma'dan) =============================
#
# Ma'dan is the first non-resource-producing Building subclass that
# modifies adjacent ResourceNodes' extraction yield. Per Open Space Room A
# Option B (2026-05-14): Ma'dan does NOT register as a resource source;
# instead it registers as an `extraction_modifier` on the nearest MineNode
# within `modifier_radius_m`, and MineNode.effective_yield_per_trip_x100
# composes the base yield with the modifier's value.
#
# These three fields are zero/false for non-modifier buildings (Khaneh,
# Mazra'eh, Atashkadeh, Throne, etc.) — they're only read by code that
# specifically queries them on a Building. Balance-engineer's d798e78
# ships `bldg_madan` with modifier_value_x100 = 150 / modifier_radius_m
# = 4.0 / modifier_stacks = false. RNC v1.3.0 (wave-1B Commit 4) documents
# the modifier-emitter pattern.

## Yield multiplier in x100 fixed-point applied by this modifier-emitter
## to the bonded ResourceNode's yield_per_trip_x100. 150 = 1.5x. 0 means
## "not a modifier-emitter" (the default — Khaneh / Mazra'eh / etc.).
##
## When a registered modifier exists on a MineNode, its
## effective_yield_per_trip_x100() returns:
##   base_yield_x100 * modifier_value_x100 / 100
## per design Q2 (1.5x default).
@export var modifier_value_x100: int = 0

## Search radius in world metres for the modifier-emitter to discover its
## target ResourceNode. The Ma'dan finds the nearest MineNode within
## modifier_radius_m and registers as that mine's extraction modifier.
## 0 means "not a modifier-emitter" (the default).
@export var modifier_radius_m: float = 0.0

## Whether multiple modifier-emitters can compound their effects on the
## same target. Per kickoff design Q3 (2026-05-14): default false
## (first-registered-wins). When true, modifiers compound multiplicatively
## (1.5x × 1.5x = 2.25x for two Ma'dans on one mine).
@export var modifier_stacks: bool = false


# === Training-production fields (Wave 3A.6) ===================================
#
# H3 dormant-schema first-exercise (per §9.H3, Wave 3A.6 Track 3):
# These 9 fields ship with zero defaults on all BuildingStats instances.
# First-populated by the 3 producer sub-resources in balance.tres at Wave 3A.6.
# First runtime read lives in Building.request_train() — the H3-trigger moment.
#
# Per §9.L9 fallback-by-failure-visibility-shape: zero defaults produce
# instant-free training if BalanceData read fails — visibly wrong (free units
# pop out instantly) but diagnosable.
#
# Naming convention locked by lead (§3.4): train_<unit_kind>_<field>
# where field ∈ {cost_coin, cost_grain, dwell_ticks}.
# Reads happen via BalanceData.bldg_<producer>.train_<unit>_<field>.
#
# §9.L6 forward-compat-guard-sweep (at Wave 3A.6 field-intro time):
# Zero readers exist on BuildingStats.train_* at this commit — all consumer
# call-sites deferred to Track 1 (Building.request_train) shipping this wave.
#
# Balance rationale: training costs align with UnitStats.coin_cost / grain_cost
# (the original per-unit cost intent). Building-level fields enable future
# per-producer differentiation (Tier-2 barracks could train Piyade cheaper).
# Dwell times set to brief §1 values (90/120/150 ticks = 3/4/5s) for MVP
# feedback loop — shorter than UnitStats.production_ticks (600/720/900) to
# keep live-test iteration fast.

## Coin cost for Sarbaz-khaneh to train one Piyade.
@export var train_piyade_cost_coin: int = 0

## Grain cost for Sarbaz-khaneh to train one Piyade.
@export var train_piyade_cost_grain: int = 0

## Ticks for Sarbaz-khaneh to complete training one Piyade.
@export var train_piyade_dwell_ticks: int = 0

## Coin cost for Sowari-khaneh to train one Savar.
@export var train_savar_cost_coin: int = 0

## Grain cost for Sowari-khaneh to train one Savar.
@export var train_savar_cost_grain: int = 0

## Ticks for Sowari-khaneh to complete training one Savar.
@export var train_savar_dwell_ticks: int = 0

## Coin cost for Tirandazi to train one Kamandar.
@export var train_kamandar_cost_coin: int = 0

## Grain cost for Tirandazi to train one Kamandar.
@export var train_kamandar_cost_grain: int = 0

## Ticks for Tirandazi to complete training one Kamandar.
@export var train_kamandar_dwell_ticks: int = 0
