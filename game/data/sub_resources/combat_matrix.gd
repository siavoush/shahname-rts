##
## CombatMatrix — attacker vs defender effectiveness multipliers.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.2
##
## effectiveness[attacker_type][defender_type] -> float multiplier
##   1.0 = neutral damage
##   > 1.0 = attacker has advantage against that defender type
##   < 1.0 = attacker is at a disadvantage against that defender type
##
## The rock-paper-scissors triangle from 01_CORE_MECHANICS.md §6:
##   piyade > savar > kamandar > piyade
## i.e.:
##   piyade is strong vs savar (spear vs horse)
##   savar is strong vs kamandar (cavalry charges archers)
##   kamandar is strong vs piyade (archers shred slow infantry)
##
## validate_hard() in BalanceData enforces all values in [0.0, 5.0].
## Values above 5× are almost certainly data entry errors.
##
## The effectiveness dict is nested: outer key = attacker StringName,
## inner key = defender StringName, value = float multiplier.
## Example: effectiveness[&"kamandar"][&"piyade"] = 1.5
##
## Consumed by CombatSystem (Phase 2) when computing damage.
class_name CombatMatrix extends Resource

## Nested Dictionary: effectiveness[attacker_type][defender_type] -> float
## StringName keys match the unit type keys in BalanceData.units.
## Populated in balance.tres with values derived from the RPS triangle above.
@export var effectiveness: Dictionary = {}
