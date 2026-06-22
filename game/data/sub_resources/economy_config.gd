##
## EconomyConfig — top-level economy parameters not covered by ResourceNodeConfig.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.2 (post-1.4.0 patch).
## Resource node gather rates live in the nested resource_nodes sub-resource
## (ResourceNodeConfig); this class holds economy-wide starting conditions.
##
## Reference: 01_CORE_MECHANICS.md §3 (Resources).
class_name EconomyConfig extends Resource

## Coin each side starts with at match begin.
## Reference: 01_CORE_MECHANICS.md §2 (spawn conditions).
@export var starting_coin: int = 150

## Grain each side starts with at match begin.
@export var starting_grain: int = 50

## All resource node gather/yield tuning lives here.
## Schema is canonical in docs/RESOURCE_NODE_CONTRACT.md §7.
@export var resource_nodes: ResourceNodeConfig = ResourceNodeConfig.new()


# === Royal-largesse upkeep (Phase 4 wave 1 — D3) ============================
#
# Standing late-game COIN pressure: every living military unit costs Coin from
# the treasury per game-minute. A stalled army slowly bleeds the treasury;
# this is the AI-vs-AI batch-duration variance source the zero-variance finding
# called for. Drains TREASURY, NOT Farr (DECISIONS.md 2026-06-22 §1.2 — keeps
# the Farr meter pure for justice/legitimacy; economy down-flow per
# docs/SHAHNAMEH_ECONOMY_RESEARCH.md §6.2).
#
# Reference: 01_CORE_MECHANICS.md §4 (economy staging) + DECISIONS.md
# 2026-06-22 §1.2. Cultural referent: the just king's obligation to sustain
# his army from the royal treasury (royal largesse = down-flow generosity).
#
# These are STARTING values to recalibrate once AI-vs-AI batches have
# duration variance (balance-engineer carry-forward — the first real
# post-Phase-4-core fun-gate lever; calibration band 5-10 coin/unit).

## Coin drained per living military unit per upkeep interval. Workers (Kargar)
## do NOT count — upkeep is a standing-ARMY cost. balance-engineer ratified
## 2026-06-22: 8 coin/unit (midpoint of the 5-10 calibration band; bites at
## the 8/12/16-unit army sizes AIs field without starving normal economies).
## Whole Coin units (NOT fixed-point); the upkeep system multiplies by 100 at
## the change_resource boundary per Sim Contract §1.6.
@export var royal_largesse_upkeep_coin_per_military_unit: int = 8

## Interval in sim ticks between upkeep drains. balance-engineer ratified
## 2026-06-22: 1800 ticks = 1 game-minute @ SIM_HZ=30. Per-minute integer
## cadence = no fixed-point accumulator needed for the cadence itself
## (deterministic tick comparison). The first drain fires at t=60s (tick
## 1800), not turn-1 — delaying past workers-reach-mines so a 14-unit starting
## army's first 112-coin drain lands after the economy has begun producing,
## avoiding turn-1 starvation off 150 starting Coin.
@export var royal_largesse_upkeep_interval_ticks: int = 1800
