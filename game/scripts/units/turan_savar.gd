extends "res://scripts/units/unit.gd"
##
## TuranSavar — the Turan cavalry unit (mirror of Iran Savar).
##
## Source: 01_CORE_MECHANICS.md §6 (cavalry archetype) + §11 (Turan faction
## visual identity, "Turan-red palette"). Per
## 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4: same archetype as
## Iran Savar, different team color, identical stats. Mirror combat means
## symmetric RPS multipliers — TuranSavar inherits the savar row of
## `BalanceData.combat_matrix` (see balance-engineer wave 1B). Counters
## archers (charges through arrow range), countered by Piyade (massed
## spears stop horses).
##
## Why a separate class (vs. parameterizing Savar with a team flag): same
## locality-of-unit-specific-code argument as TuranPiyade / TuranKamandar.
## Future Turan-specific cavalry behaviors (e.g., faction-specific charge
## bonuses, Afrasiab as a hero per §7, Turan tech upgrades) ship in later
## phases; having TuranSavar as a class_name lets `is TuranSavar` checks
## work naturally rather than `team == TEAM_TURAN and unit_type ==
## &"savar"` checks at every call site.
##
## What this class deliberately does NOT do (per wave-1A brief):
##   - Faction-specific abilities (later phases)
##   - Faction-asymmetric RPS multipliers (combat_matrix uses unit_type
##     keys; balance-engineer can map turan_savar → savar row for mirror
##     combat or ship asymmetric Turan-tuned values when the design chat
##     green-lights asymmetric balance)
##   - Charge bonus mechanic (Phase 2 polish — not in session 2)
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0). Same pattern
## as every other concrete unit type.
class_name TuranSavar


# Canonical unit_type for the TuranSavar class — the BalanceData lookup
# key (game/data/balance.tres `unit_turan_savar` entry, balance-engineer
# wave 1B).
const UNIT_TYPE_TURAN_SAVAR: StringName = &"turan_savar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For turan_savar.tscn (which inherits unit.tscn without overriding
#      the `unit_type` export), this means unit_type gets reset to the
#      base unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# Same dual-init pattern as every other concrete unit type.

func _init() -> void:
	unit_type = UNIT_TYPE_TURAN_SAVAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it.
	# _apply_balance_data_defaults uses unit_type as the BalanceData key.
	unit_type = UNIT_TYPE_TURAN_SAVAR
	super._ready()
