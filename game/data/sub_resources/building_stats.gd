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
