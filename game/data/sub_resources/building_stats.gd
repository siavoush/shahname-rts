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
