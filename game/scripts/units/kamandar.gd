extends "res://scripts/units/unit.gd"
##
## Kamandar (کماندار) — the Iran archer / ranged-infantry unit.
##
## Source: 01_CORE_MECHANICS.md §6 (Iran units, MVP):
##     "Kamandar (archer) — ranged infantry. Glass cannon: high damage at
##      range, low HP, slow attack speed. Counters Piyade (range > Piyade's
##      melee), countered by Savar (cavalry charge closes range fast)."
##
## And 01_CORE_MECHANICS.md §0 (rock-paper-scissors triangle):
##     "piyade > savar > kamandar > piyade"
## (Strictly: Kamandar wins vs. Piyade (1.5×) and loses vs. Savar (0.7×); the
## RPS effectiveness multipliers populate `BalanceData.combat_matrix` under
## balance-engineer wave 1B, the ranged-attack damage path lives in
## `combat_component.gd` from wave 2A.)
##
## Phase 2 session 2 wave 1A scope (per 02e_PHASE_2_SESSION_2_KICKOFF.md §2
## deliverable 1): the first Iran ranged unit. Same composition pattern as
## Piyade and Kargar; visual is a tall-narrow cylinder (height 0.9, radius
## 0.25) so the silhouette reads "the bow guy" against the cube Piyade and
## the squat Kargar cylinder. Stats from BalanceData.units[&"kamandar"]
## (max_hp ~60, move_speed ~2.5, attack_damage_x100 ~1500,
## attack_speed_per_sec ~0.7, attack_range ~8.0). Numbers are
## balance-engineer's call; this class only declares the wiring.
##
## Why this is its own class (vs. parameterizing Unit): same rationale as
## Piyade. Kamandar may eventually grow ranged-specific behaviors — kiting
## AI (move-fire-move; Phase 6's DummyAIController), arrow projectile
## entities (Phase 5 polish), volley-fire formation. Having the type as a
## class_name lets selection / command / AI / tests check `is Kamandar`
## directly.
##
## What this class deliberately does NOT do (per wave-1A brief):
##   - RPS effectiveness multipliers (balance-engineer wave 1B + gameplay
##     wave 2A populate / read combat_matrix in CombatComponent)
##   - Hero abilities (Kamandar has none — they're rank-and-file)
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit)
##   - Kiting AI (Phase 6's DummyAIController)
##   - Visible arrow projectile (Phase 5 polish — currently the damage just
##     applies to the target like Piyade's melee, only with longer reach)
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## the project's class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0)
## means a script that's loaded during scene-tree warm-up may parse before
## the Unit class_name is in the global registry. Path-string extends
## bypasses that. Same pattern as Kargar / Piyade.
class_name Kamandar


# Canonical unit_type for the Kamandar class — the BalanceData lookup key
# (game/data/balance.tres `unit_kamandar` entry, balance-engineer wave 1B).
const UNIT_TYPE_KAMANDAR: StringName = &"kamandar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For kamandar.tscn (which inherits unit.tscn without overriding the
#      `unit_type` export), this means unit_type gets reset to the base
#      unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded Kamandar instances — the
# engine clobbers it between steps 1 and 3. _ready (BEFORE super._ready,
# which is what reads unit_type to look up BalanceData) is the canonical
# fix. _init is kept so `Kamandar.new()` headless construction (no scene)
# also reports the right type. Same pattern as Kargar / Piyade.

func _init() -> void:
	unit_type = UNIT_TYPE_KAMANDAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it. The base's
	# _apply_balance_data_defaults uses unit_type as the BalanceData key;
	# if it sees an empty StringName it silently no-ops.
	unit_type = UNIT_TYPE_KAMANDAR
	super._ready()
