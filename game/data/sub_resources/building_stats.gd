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
## cap +5 per building. 50 coin." Phase 3 session 1 wave 1C kickoff
## (02f_PHASE_3_KICKOFF.md §3) opted for +10 as the placeholder starting
## point pending playtest; balance-engineer tunes via balance.tres.
@export var population_capacity: int = 0


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
