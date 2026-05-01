##
## ResourceNodeConfig — tunable numbers for resource nodes (mines and farms).
##
## Canonical shape: docs/RESOURCE_NODE_CONTRACT.md §7
## Lives nested under EconomyConfig.resource_nodes.
##
## Reference: 01_CORE_MECHANICS.md §3 (Resources), RESOURCE_NODE_CONTRACT.md §7.
##
## MineNode reads mine_initial_stock, mine_max_workers, coin_yield_per_trip,
## coin_yield_per_tick at construction and per extract tick.
## Mazra'eh reads grain_yield_per_trip, grain_yield_per_tick, farm_max_workers.
## Both use trip_full_load_ticks.
class_name ResourceNodeConfig extends Resource

## Starting coin stock for a MineNode. Depleted by worker extraction.
## "MineNode.current_stock initialized from BalanceData.mine_initial_stock" — RNC §7.
@export var mine_initial_stock: int = 1500

## Maximum simultaneous workers at a single mine.
## "MineNode.max_workers = 2 (two kargar can share a mine)" — RNC §1.3.
@export var mine_max_workers: int = 2

## Coin carried by worker per full trip (YIELD_READY result).
## "coin_yield_per_trip: 10 — carried per full load" — RNC §7.
@export var coin_yield_per_trip: int = 10

## Mine stock decremented each tick per active worker.
## "coin_yield_per_tick: 1 — decrement applied during tick_extract" — RNC §7.
@export var coin_yield_per_tick: int = 1

## Grain carried by worker per full trip from Mazra'eh.
## "grain_yield_per_trip: 8 — carried per full load (Mazra'eh)" — RNC §7.
@export var grain_yield_per_trip: int = 8

## Grain accumulated per tick of farm gathering.
## "grain_yield_per_tick: 1 — accumulated per tick of gathering" — RNC §7.
@export var grain_yield_per_tick: int = 1

## Maximum simultaneous workers at a single farm.
## "tend the field" model: one farmer per farm. Balance-engineer can raise.
## "farm_max_workers = 1 default reflects tend the field mental model" — RNC §7.
@export var farm_max_workers: int = 1

## Ticks for a worker to fill a full load at a resource node.
## At 30 Hz: 60 ticks = 2.0 seconds.
## "trip_full_load_ticks: 60 — 2s at 30Hz; capacity equivalent" — RNC §7.
@export var trip_full_load_ticks: int = 60
