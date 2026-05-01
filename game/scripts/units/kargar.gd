extends "res://scripts/units/unit.gd"
##
## Kargar (کارگر) — the Iran worker unit.
##
## Source: 01_CORE_MECHANICS.md §6 (Iran units, MVP):
##     "Kargar (worker) — gathers resources, constructs buildings, repairs.
##      Combat: minimal. Fragile."
##
## Spawn doctrine: every match starts with three workers per player
## (01_CORE_MECHANICS.md §2 step 1) — Phase 1 session 1 wave 2 spawns five
## as a placeholder pre-economy fixture (so the player has something to
## click immediately; the canonical 3-worker start lands with the
## ResourceSystem in Phase 3). Until then, the count is a UX-of-testing
## value, not a balance value, and lives in the spawn script (main.gd)
## rather than constants.gd.
##
## Why this is its own class (vs. parameterizing Unit):
##   - The Kargar will eventually get gathering / construction / repair
##     behaviors that no other unit has (gather command states,
##     construction site routing, repair targeting). Those land in Phase 3.
##   - Even at MVP, having the type as a class_name lets selection,
##     command-binding, AI, and tests check "is this a worker?" with a
##     simple `is Kargar` rather than `unit_type == &"kargar"` — clearer
##     intent at the call site.
##   - The cost of a class_name + .tscn pair is two small files; the
##     payoff is locality of unit-specific code as features land. Same
##     pattern the State Machine Contract §5 expects for every unit type.
##
## What this class deliberately does NOT do (per wave-2 brief):
##   - Combat behavior (Phase 2)
##   - Gathering / construction / repair (Phase 3)
##   - Special abilities (Kargar has none in spec)
##   - Custom states beyond what the base Unit registers (ai-engineer
##     wave 2 owns Idle / Moving registration)
##
## Composition: this class extends Unit and only sets unit_type. The
## kargar.tscn scene inherits the unit.tscn template and overrides the
## MeshInstance3D mesh + material to give the worker a distinct silhouette
## (squat cylinder, sandy/brown — placeholder per CLAUDE.md "colored shapes
## only" policy). Stats (max_hp, move_speed, etc.) are read from
## BalanceData.units[&"kargar"] by Unit._apply_balance_data_defaults.
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## the project's class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0)
## means a script that's loaded during scene-tree warm-up may parse before
## the Unit class_name is in the global registry, producing a "Could not
## find base class 'Unit'" error. Path-string extends bypasses the registry
## entirely. The `class_name Kargar` declaration below still registers
## the type for runtime `is Kargar` checks at call sites where the
## registry has settled — same pattern as the components in
## scripts/units/components/.
class_name Kargar


# Canonical unit_type for the Kargar class. This is the BalanceData
# lookup key (see game/data/balance.tres `unit_kargar` entry). Kept as a
# const so subclasses (a future Tier-2 variant?) can refer to the value
# without re-typing the string.
const UNIT_TYPE_KARGAR: StringName = &"kargar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For kargar.tscn (which inherits unit.tscn without overriding the
#      `unit_type` export), this means unit_type gets set back to the
#      base unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded Kargar instances — the
# engine clobbers it between steps 1 and 3. _ready (BEFORE super._ready,
# which is what reads unit_type to look up BalanceData) is the canonical
# fix. _init is kept so `Kargar.new()` headless construction (no scene)
# also reports the right type — useful for tests and any future
# code-only spawn path.

func _init() -> void:
	unit_type = UNIT_TYPE_KARGAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it. The base's
	# _apply_balance_data_defaults uses unit_type as the BalanceData key;
	# if it sees an empty StringName it silently no-ops (defensive
	# fallback for the bare-base Unit instantiation pattern). We need
	# the lookup to actually fire for the Kargar.
	unit_type = UNIT_TYPE_KARGAR
	super._ready()
