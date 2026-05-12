extends "res://scripts/units/unit.gd"
##
## Savar (سوار) — the Iran heavy mounted-infantry / cavalry unit.
##
## Source: 01_CORE_MECHANICS.md §6 (Iran units, MVP):
##     "Savar (cavalry) — heavy mounted infantry. Counters Kamandar (charges
##      through arrow range to melee), countered by Piyade (massed spears
##      stop horses — modeled via the RPS matrix)."
##
## And 01_CORE_MECHANICS.md §0 (rock-paper-scissors triangle):
##     "piyade > savar > kamandar > piyade"
## Strictly: Savar wins vs. Kamandar (2.0× cavalry-charge-vs-archer) and
## loses vs. Piyade (0.7× vs anti-cavalry spears). RPS effectiveness
## multipliers populate `BalanceData.combat_matrix` (balance-engineer
## wave 1B). Damage-time lookup lands in `combat_component.gd` wave 2A.
##
## Phase 2 session 2 wave 1A scope (per 02e_PHASE_2_SESSION_2_KICKOFF.md §2
## deliverable 2): the first Iran cavalry unit. Same composition pattern as
## Piyade and Kamandar; visual is a larger box (Vector3(0.7, 0.6, 0.7)) so
## the silhouette reads as a wider, heavier figure than the cube Piyade and
## the tall-narrow Kamandar. The horse-plus-rider footprint occupies more
## ground than foot infantry. Stats from BalanceData.units[&"savar"]
## (max_hp ~150, move_speed ~4.5 — cavalry-fast, attack_damage_x100 ~1200,
## attack_speed_per_sec ~0.9, attack_range ~1.8 — slightly longer than
## Piyade's melee for mounted reach). Numbers are balance-engineer's call;
## this class only declares the wiring.
##
## Why this is its own class (vs. parameterizing Unit): same rationale as
## Piyade / Kamandar. Savar may eventually grow cavalry-specific behaviors —
## charge bonus on first contact (Phase 2 polish), heavy-stance immunity to
## stagger (Phase 4), formation-anchor for shock charges. Having the type
## as a class_name lets selection / command / AI / tests check `is Savar`
## directly.
##
## What this class deliberately does NOT do (per wave-1A brief):
##   - RPS effectiveness multipliers (balance-engineer wave 1B + gameplay
##     wave 2A populate / read combat_matrix in CombatComponent)
##   - Charge bonus mechanic (Phase 2 polish — not in session 2)
##   - Hero abilities (Savar are rank-and-file; heroes per §7 ship Phase 5)
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## the project's class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0)
## means a script that's loaded during scene-tree warm-up may parse before
## the Unit class_name is in the global registry. Path-string extends
## bypasses that. Same pattern as Kargar / Piyade / Kamandar.
class_name Savar


# Canonical unit_type for the Savar class — the BalanceData lookup key
# (game/data/balance.tres `unit_savar` entry, balance-engineer wave 1B).
const UNIT_TYPE_SAVAR: StringName = &"savar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For savar.tscn (which inherits unit.tscn without overriding the
#      `unit_type` export), this means unit_type gets reset to the base
#      unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded Savar instances. Same
# dual-init pattern as Kargar / Piyade / Kamandar.

func _init() -> void:
	unit_type = UNIT_TYPE_SAVAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it. The base's
	# _apply_balance_data_defaults uses unit_type as the BalanceData key.
	unit_type = UNIT_TYPE_SAVAR
	super._ready()
