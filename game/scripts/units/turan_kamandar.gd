extends "res://scripts/units/unit.gd"
##
## TuranKamandar — the Turan archer / ranged-infantry unit (mirror of Iran
## Kamandar).
##
## Source: 01_CORE_MECHANICS.md §6 (units, archer archetype) + §11 (Turan
## faction visual identity, "Turan-red palette"). Per
## 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4: same archetype as
## Iran Kamandar, different team color, identical stats. Mirror combat
## means symmetric RPS multipliers — TuranKamandar inherits the kamandar
## row of `BalanceData.combat_matrix` (see balance-engineer wave 1B).
##
## Why a separate class (vs. parameterizing Kamandar with a team flag): the
## RPS triangle is symmetric across factions for now, but Turan-specific
## behaviors (e.g., Afrasiab as a Turan-only hero per 01_CORE_MECHANICS.md
## §7, faction-specific tech upgrades) ship in later phases. Having
## TuranKamandar as a class_name lets faction-specific code use
## `is TuranKamandar` checks naturally rather than `unit_type ==
## &"turan_kamandar"` (or worse, `team == TEAM_TURAN and unit_type ==
## &"kamandar"`) at every call site. Same locality-of-unit-specific-code
## argument as Kargar / Piyade / Kamandar / TuranPiyade.
##
## What this class deliberately does NOT do (per wave-1A brief):
##   - Faction-specific abilities (later phases)
##   - Faction-asymmetric RPS multipliers (combat_matrix uses unit_type
##     keys; balance-engineer can map turan_kamandar → kamandar row for
##     mirror combat or ship asymmetric Turan-tuned values when the
##     design chat green-lights asymmetric balance)
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0). Same pattern
## as every other concrete unit type.
class_name TuranKamandar


# Canonical unit_type for the TuranKamandar class — the BalanceData lookup
# key (game/data/balance.tres `unit_turan_kamandar` entry, balance-engineer
# wave 1B).
const UNIT_TYPE_TURAN_KAMANDAR: StringName = &"turan_kamandar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For turan_kamandar.tscn (which inherits unit.tscn without
#      overriding the `unit_type` export), this means unit_type gets
#      reset to the base unit.gd default of &"" — clobbering anything
#      _init wrote.
#   3. The script's `_ready()` runs.
#
# Same dual-init pattern as every other concrete unit type. _init is kept
# so headless `TuranKamandar.new()` construction also reports the right
# type.

func _init() -> void:
	unit_type = UNIT_TYPE_TURAN_KAMANDAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it.
	# _apply_balance_data_defaults uses unit_type as the BalanceData key.
	unit_type = UNIT_TYPE_TURAN_KAMANDAR
	super._ready()
