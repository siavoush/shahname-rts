extends "res://scripts/units/unit.gd"
##
## TuranPiyade — the Turan foot-infantry unit (mirror of Iran Piyade).
##
## Source: 01_CORE_MECHANICS.md §6 (units, MVP — Iran roster) + §11
## (Turan faction visual identity, "Turan-red palette"). Per
## 02d_PHASE_2_KICKOFF.md §2 deliverable 6: Phase 2 session 1 ships a
## mirror unit for the Iran Piyade — same archetype, different team
## color, identical stats. RPS effectiveness multipliers ship in Phase 2
## session 2 with the wider unit roster; until then mirror combat is the
## simplest verification surface for the combat loop.
##
## Why a separate class (vs. parameterizing Piyade with a team flag): the
## piyade > savar > kamandar > piyade RPS triangle is symmetric across
## factions for now, but Turan-specific behaviors (e.g., Afrasiab as a
## Turan-only hero per 01_CORE_MECHANICS.md §7, faction-specific tech
## upgrades) ship in later phases. Having TuranPiyade as a class_name lets
## faction-specific code use `is TuranPiyade` checks naturally rather than
## sprinkling `unit_type == &"turan_piyade"` (or worse, `team == TEAM_TURAN
## and unit_type == &"piyade"`) checks at every call site. Same locality-
## of-unit-specific-code argument as Kargar / Piyade.
##
## What this class deliberately does NOT do (per wave-2A brief):
##   - RPS effectiveness multipliers (Phase 2 session 2)
##   - Faction-specific abilities (later phases)
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0). Same pattern
## as Kargar and Piyade.
class_name TuranPiyade


# Canonical unit_type for the TuranPiyade class — the BalanceData lookup
# key (game/data/balance.tres `unit_turan_piyade` entry, balance-engineer
# wave 1C `a2b444f`).
const UNIT_TYPE_TURAN_PIYADE: StringName = &"turan_piyade"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For turan_piyade.tscn (which inherits unit.tscn without overriding
#      the `unit_type` export), this means unit_type gets reset to the
#      base unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded TuranPiyade instances. The
# _ready override (BEFORE super._ready, which is what reads unit_type to
# look up BalanceData) is the canonical fix. _init is kept so headless
# `TuranPiyade.new()` construction also reports the right type.

func _init() -> void:
	unit_type = UNIT_TYPE_TURAN_PIYADE


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it.
	# _apply_balance_data_defaults uses unit_type as the BalanceData key.
	unit_type = UNIT_TYPE_TURAN_PIYADE
	super._ready()
