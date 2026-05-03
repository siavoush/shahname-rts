extends "res://scripts/units/unit.gd"
##
## Piyade (پیاده) — the Iran foot-infantry unit.
##
## Source: 01_CORE_MECHANICS.md §6 (Iran units, MVP):
##     "Piyade (foot infantry) — cheap, slow, durable. Spear-and-shield.
##      Strong vs cavalry (> savar in RPS triangle)."
##
## And 01_CORE_MECHANICS.md §0 (rock-paper-scissors triangle):
##     "piyade > savar > kamandar > piyade"
## (RPS effectiveness multipliers ship in Phase 2 session 2 — session 1
## fields all-neutral for mirror combat.)
##
## Phase 2 session 1 wave 2A scope (per 02d_PHASE_2_KICKOFF.md §2 deliverable 5):
## first Iran combat unit type. Same composition pattern as Kargar; visual
## is a Iran-blue cube slightly taller than the Kargar cylinder so the two
## are silhouette-distinguishable on the terrain. Stats from
## BalanceData.units[&"piyade"] (max_hp 100, move_speed 2.5, attack_damage_x100
## 1000, attack_speed_per_sec 1.0, attack_range 1.5).
##
## Why this is its own class (vs. parameterizing Unit): same rationale as
## Kargar. Combat units will eventually grow role-specific behaviors (formation
## anchor, charge bonus, etc.) — having the type as a class_name lets selection
## / command / AI / tests check `is Piyade` directly.
##
## What this class deliberately does NOT do (per wave-2A brief):
##   - RPS effectiveness multipliers (Phase 2 session 2)
##   - Hero abilities (Piyade has none — they're rank-and-file)
##   - Custom states beyond Idle / Moving / Attacking (those are
##     registered by the base Unit; combat targeting flows through
##     UnitState_Attacking which ai-engineer wave 1B shipped)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## the project's class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0)
## means a script that's loaded during scene-tree warm-up may parse before
## the Unit class_name is in the global registry. Path-string extends
## bypasses that. The `class_name Piyade` declaration below registers
## the type for runtime `is Piyade` checks at call sites where the
## registry has settled.
class_name Piyade


# Canonical unit_type for the Piyade class — the BalanceData lookup key
# (game/data/balance.tres `unit_piyade` entry). Const so a future Tier-2
# variant can reference the value without re-typing the string.
const UNIT_TYPE_PIYADE: StringName = &"piyade"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For piyade.tscn (which inherits unit.tscn without overriding the
#      `unit_type` export), this means unit_type gets reset to the base
#      unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded Piyade instances — the
# engine clobbers it between steps 1 and 3. _ready (BEFORE super._ready,
# which is what reads unit_type to look up BalanceData) is the canonical
# fix. _init is kept so `Piyade.new()` headless construction (no scene)
# also reports the right type. Same pattern as Kargar.

func _init() -> void:
	unit_type = UNIT_TYPE_PIYADE


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it. The base's
	# _apply_balance_data_defaults uses unit_type as the BalanceData key;
	# if it sees an empty StringName it silently no-ops.
	unit_type = UNIT_TYPE_PIYADE
	super._ready()
