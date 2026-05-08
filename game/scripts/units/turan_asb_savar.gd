extends "res://scripts/units/unit.gd"
##
## TuranAsbSavar — the Turan horse-archer unit (mirror of Iran Asb-savar
## Kamandar).
##
## Source: 01_CORE_MECHANICS.md §6 (units, MVP — Iran roster) + §11 (Turan
## faction visual identity, "Turan-red palette"). Per
## 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4 (Turan mirror roster):
## Phase 2 session 2 ships a mirror unit for the Iran Asb-savar Kamandar —
## same archetype, different team color, identical stats. RPS effectiveness
## multipliers populate `BalanceData.combat_matrix` (balance-engineer wave
## 1B); the matrix lookup folds Turan keys to Iran rows via
## `_resolve_key`/`_turan_base_to_iran_key` in combat_matrix.gd.
##
## Why a separate class (vs. parameterizing AsbSavarKamandar with a team
## flag): faction-specific behaviors will diverge in later phases —
## Afrasiab / Garsivaz heroes per 01_CORE_MECHANICS.md §7, faction-specific
## tech upgrades, asymmetric balance from Phase 2 session 3+. Having
## TuranAsbSavar as a class_name lets faction-specific code use
## `is TuranAsbSavar` checks naturally rather than sprinkling
## `unit_type == &"turan_asb_savar"` (or worse,
## `team == TEAM_TURAN and is AsbSavarKamandar`) at every call site. Same
## locality-of-unit-specific-code argument as Kargar / Piyade / TuranPiyade.
##
## Why the SHORTENED unit_type key &"turan_asb_savar" (vs the compound
## &"turan_asb_savar_kamandar"): per balance.tres comment at line 184, the
## Iran side's "kamandar" suffix is understood from context for Turan units,
## and the shorter key keeps the BalanceData lookup readable. The RPS matrix
## lookup folds Turan keys to Iran rows in combat_matrix.gd:
##   _resolve_key("turan_asb_savar")
##     → strips "turan_" prefix → "asb_savar"
##     → _turan_base_to_iran_key("asb_savar") expands to "asb_savar_kamandar"
##     → looks up combat_matrix["asb_savar_kamandar"] row.
## This is documented in balance.tres line 187-189 + combat_matrix.gd's
## `_turan_base_to_iran_key` function.
##
## What this class deliberately does NOT do (per wave-1C brief):
##   - RPS effectiveness multipliers (balance-engineer wave 1B + gameplay
##     wave 2A populate / read combat_matrix in CombatComponent)
##   - Kiting AI (move-fire-move) — Phase 6's DummyAIController.
##   - Faction-specific abilities (later phases — asymmetric balance Phase 4+).
##   - Custom states beyond Idle / Moving / Attacking (registered by base Unit).
##
## Why `extends "res://scripts/units/unit.gd"` rather than `extends Unit`:
## class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0). Same pattern
## as Kargar / Piyade / TuranPiyade / Kamandar / Savar / AsbSavarKamandar.
class_name TuranAsbSavar


# Canonical unit_type for the TuranAsbSavar class — the BalanceData lookup
# key (game/data/balance.tres `unit_turan_asb_savar` entry, balance-engineer
# wave 1B). SHORTENED form per balance.tres line 184 — see class header for
# the matrix-folding rationale.
const UNIT_TYPE_TURAN_ASB_SAVAR: StringName = &"turan_asb_savar"


# Why _init AND _ready set unit_type:
#
# Scene-instantiation order in Godot 4:
#   1. The script's `_init()` runs.
#   2. The engine assigns @export defaults from the .tscn definition.
#      For turan_asb_savar.tscn (which inherits unit.tscn without overriding
#      the `unit_type` export), this means unit_type gets reset to the base
#      unit.gd default of &"" — clobbering anything _init wrote.
#   3. The script's `_ready()` runs.
#
# So _init alone is not enough for scene-loaded TuranAsbSavar instances. The
# _ready override (BEFORE super._ready, which is what reads unit_type to
# look up BalanceData) is the canonical fix. _init is kept so headless
# `TuranAsbSavar.new()` construction also reports the right type. Same
# dual-init pattern as every other concrete unit type.

func _init() -> void:
	unit_type = UNIT_TYPE_TURAN_ASB_SAVAR


func _ready() -> void:
	# Override unit_type BEFORE the base class _ready reads it.
	# _apply_balance_data_defaults uses unit_type as the BalanceData key.
	unit_type = UNIT_TYPE_TURAN_ASB_SAVAR
	super._ready()
