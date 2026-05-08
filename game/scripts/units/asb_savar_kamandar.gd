extends "res://scripts/units/unit.gd"
##
## AsbSavarKamandar (اسب‌سوار کماندار) — the Iran horse-archer / mounted-ranged unit.
##
## Source: 01_CORE_MECHANICS.md §6 (Iran units, MVP):
##     "Asb-savar Kamandar (horse archer) — ranged + cavalry hybrid. Mobile
##      ranged unit. The unit that makes kiting AI a real problem."
##
## And 02_IMPLEMENTATION_PLAN.md §169:
##     "Ship now (Phase 2) so kiting affects combat math; rebalanced to Tier 2
##      in Phase 4 when their tech tier ships."
##
## And 01_CORE_MECHANICS.md §0 (rock-paper-scissors triangle):
##     "piyade > savar > kamandar > piyade"
## Strictly: Asb-savar's matrix row per balance-engineer wave 1B is 1.2× vs
## piyade (kiting bonus from range+speed combo), 0.5× vs savar (heavy cavalry
## outlasts horse archers in sustained engagements), neutral vs kamandar
## (mirror archer matchup). The RPS effectiveness multipliers populate
## `BalanceData.combat_matrix`; the damage-time lookup lands in
## `combat_component.gd` wave 2A.
##
## Phase 2 session 2 wave 1C scope (per 02e_PHASE_2_SESSION_2_KICKOFF.md §2
## deliverable 3): the first ranged + cavalry hybrid Iran unit. Same
## composition pattern as Piyade / Kamandar / Savar; visual is an elongated
## box (Vector3(0.6, 0.5, 0.9)) — the depth-axis (Z) is the longest dimension,
## reading as "horse-archer silhouette" rather than "wider square heavy
## cavalry" (Savar) or "tall narrow archer" (Kamandar). Stats from
## BalanceData.units[&"asb_savar_kamandar"] (max_hp ~100 — Tier-1-equivalent;
## Tier-2 buff Phase 4, move_speed ~4.0 — cavalry-fast but slightly slower
## than Savar's 4.5, attack_damage_x100 ~1300 — between Piyade's 1000 and
## Kamandar's 1500, attack_speed_per_sec ~0.6 — slower than Kamandar's 0.7
## because drawing a bow on horseback is harder, attack_range ~7.0 — ranged
## but slightly less than Kamandar's 8.0 because foot archers brace better).
## Numbers are balance-engineer's call; this class only declares the wiring.
##
## Why this is its own class (vs. parameterizing Unit): same rationale as
## Piyade / Kamandar / Savar. Asb-savar will eventually grow horse-archer-
## specific behaviors — kiting AI (move-fire-move; Phase 6's
## DummyAIController), cavalry charge bonus (Phase 2 polish), Tier-2 stat
## upgrades when their tech tier lands (Phase 4). Having the type as a
## class_name lets selection / command / AI / tests check
## `is AsbSavarKamandar` directly.
##
## Why the long compound class_name (vs. shortening to AsbSavar): the Iran
## name "اسب‌سوار کماندار" literally means "mounted archer" — the noun is
## "kamandar" (archer) modified by "asb-savar" (mounted). Dropping "Kamandar"
## from the class name would lose the cultural specificity that distinguishes
## these from generic "horse archers" in other Persian texts. The Turan
## mirror uses a SHORTER key (&"turan_asb_savar" — see balance.tres comment)
## because Turan unit names follow a different convention; balance.tres
## documents the per-side key choice. The class_name follows the unit_type
## key for the Iran side: AsbSavarKamandar matches &"asb_savar_kamandar".
##
## What this class deliberately does NOT do (per wave-1C brief):
##   - RPS effectiveness multipliers (balance-engineer wave 1B + gameplay
##     wave 2A populate / read combat_matrix in CombatComponent)
##   - Kiting AI (move-fire-move) — Phase 6's DummyAIController. Player-
##     controlled Asb-savar still need explicit Move + Attack commands.
##   - Tier-2 stat buffs (Phase 4 when tech tier ships).
##   - Hero abilities (Asb-savar are rank-and-file).
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit).
##   - Visible arrow projectile (Phase 5 polish — currently the damage just
##     applies to the target like Kamandar's ranged, only with mounted speed).
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## the project's class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0)
## means a script that's loaded during scene-tree warm-up may parse before
## the Unit class_name is in the global registry. Path-string extends
## bypasses that. Same pattern as Kargar / Piyade / Kamandar / Savar.
class_name AsbSavarKamandar


# Canonical unit_type for the AsbSavarKamandar class — the BalanceData
# lookup key (game/data/balance.tres `unit_asb_savar_kamandar` entry,
# balance-engineer wave 1B).
const UNIT_TYPE_ASB_SAVAR_KAMANDAR: StringName = &"asb_savar_kamandar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For asb_savar_kamandar.tscn (which inherits unit.tscn without
#      overriding the `unit_type` export), this means unit_type gets
#      reset to the base unit.gd default of &"" — clobbering anything
#      _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded AsbSavarKamandar instances —
# the engine clobbers it between steps 1 and 3. _ready (BEFORE super._ready,
# which is what reads unit_type to look up BalanceData) is the canonical
# fix. _init is kept so `AsbSavarKamandar.new()` headless construction
# (no scene) also reports the right type. Same dual-init pattern as
# Kargar / Piyade / Kamandar / Savar.

func _init() -> void:
	unit_type = UNIT_TYPE_ASB_SAVAR_KAMANDAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it. The base's
	# _apply_balance_data_defaults uses unit_type as the BalanceData key;
	# if it sees an empty StringName it silently no-ops.
	unit_type = UNIT_TYPE_ASB_SAVAR_KAMANDAR
	super._ready()
