##
## UnitStats — per-unit tunable numbers.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.2
## All values are starting points to be tuned through playtesting per
## 01_CORE_MECHANICS.md §0. balance-engineer sets values; gameplay-systems
## consumes them.
##
## Reference: 01_CORE_MECHANICS.md §6 (unit roster and archetypes).
##
## Fixed-point convention (Sim Contract §1.6):
##   attack_damage_x100 stores damage × 100 as int to avoid float precision
##   drift in the 30Hz sim tick. E.g., 10.0 damage → attack_damage_x100 = 1000.
##   CombatComponent divides by 100 when applying to HealthComponent (also x100).
class_name UnitStats extends Resource

## Maximum hit points for this unit type.
@export var max_hp: float = 0.0

## Base damage per attack.
@export var damage: float = 0.0

## Ticks between attacks (at 30 Hz: 30 ticks = 1.0s cooldown).
@export var attack_speed_ticks: int = 30

## Attack range in world units.
@export var attack_range: float = 1.5

## Fixed-point damage per attack (Sim Contract §1.6). Store as int × 100.
## E.g. 10.0 damage → 1000. Kargar = 0 (workers cannot attack effectively).
## CombatComponent reads this field; the legacy `damage` field is unused by Phase 2+.
@export var attack_damage_x100: int = 0

## Attacks per second. Clamped to >= 0.1 to prevent divide-by-zero in cooldown calc.
## E.g. 1.0 = one attack per second; 2.0 = two attacks per second.
@export var attack_speed_per_sec: float = 1.0

## Movement speed in world units per second.
@export var move_speed: float = 3.0

## Population slots consumed when this unit is alive.
## Heroes have population_cost = 0 per 01_CORE_MECHANICS.md §7.
@export var population_cost: int = 1

## Coin cost to produce this unit.
@export var coin_cost: int = 0

## Grain cost to produce this unit.
@export var grain_cost: int = 0

## Ticks to produce one of this unit from a building.
## At 30 Hz: 900 ticks = 30s.
@export var production_ticks: int = 900
