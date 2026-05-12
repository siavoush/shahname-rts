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
##
## NOTE: Only Iran base-type rows are stored (piyade, kamandar, savar,
## asb_savar_kamandar). Turan mirror types are folded at lookup time by
## get_multiplier() stripping the "turan_" prefix. This keeps the data
## at 16 cells (4×4) rather than duplicating to 36+ cells.
## Wave 2A CombatComponent MUST call get_multiplier() — NOT raw dict access.
@export var effectiveness: Dictionary = {}


## get_multiplier(attacker_type, target_type) -> float
##
## Canonical lookup for combat effectiveness. Returns the damage multiplier
## for an attacker_type vs target_type pair.
##
## Turan mirror folding: unit types with a "turan_" prefix are looked up
## by their base counterpart. E.g. "turan_piyade" resolves to "piyade",
## "turan_asb_savar" resolves to "asb_savar_kamandar".
## This means Iran and Turan units of the same archetype have identical
## RPS behavior — asymmetric balance can be added later by giving Turan
## types their own rows in the effectiveness dict (the prefix-strip only
## fires when the key is absent from the dict).
##
## Default: returns 1.0 (neutral) when the pair is not in the dict.
## This makes the lookup forward-compatible: new unit types added in later
## phases will not break existing combat until their rows are added.
##
## Called by: CombatComponent._sim_tick (Phase 2 wave 2A)
func get_multiplier(attacker_type: StringName, target_type: StringName) -> float:
	# Resolve attacker: try exact key first, then strip "turan_" prefix.
	var atk_key: StringName = _resolve_key(attacker_type)
	if not effectiveness.has(atk_key):
		return 1.0

	var row: Variant = effectiveness[atk_key]
	if typeof(row) != TYPE_DICTIONARY:
		return 1.0

	# Resolve target: try exact key first, then strip "turan_" prefix.
	var def_key: StringName = _resolve_key(target_type)
	if not row.has(def_key):
		return 1.0

	return float(row[def_key])


## _resolve_key — strips the "turan_" prefix when the exact key is absent
## from the effectiveness dict. Falls back to the exact key if no base key
## exists either (caller then returns 1.0 via the normal missing-key path).
func _resolve_key(unit_type: StringName) -> StringName:
	if effectiveness.has(unit_type):
		return unit_type
	# Strip "turan_" prefix and try the base type.
	# Special case: "turan_asb_savar" → "asb_savar_kamandar" (Turan naming
	# convention drops the "_kamandar" suffix; Iran uses the full compound name).
	var s: String = String(unit_type)
	if s.begins_with("turan_"):
		var base: String = s.substr(6)  # len("turan_") == 6
		# Map known Turan suffix variants to their Iran base-type keys
		var mapped: StringName = _turan_base_to_iran_key(base)
		return mapped
	return unit_type


## _turan_base_to_iran_key — maps a stripped Turan base name to its Iran key.
## Handles the "asb_savar" → "asb_savar_kamandar" rename difference.
func _turan_base_to_iran_key(base: String) -> StringName:
	# "asb_savar" is the Turan-side short form; Iran side is "asb_savar_kamandar"
	if base == "asb_savar":
		return &"asb_savar_kamandar"
	# All other base names match directly (piyade, kamandar, savar)
	return StringName(base)
