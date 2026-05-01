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
