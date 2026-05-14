##
## FarrConfig — all tunable Farr-meter parameters.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.2
## Reference mechanic: 01_CORE_MECHANICS.md §4 (Farr full spec) and §9 (Kaveh Event).
##
## Farr range: 0.0–100.0. Starting value 50 (neutral).
## Stored as float; FarrSystem stores internally as fixed-point int per
## docs/SIMULATION_CONTRACT.md §1.6 (× 1000, so Farr 50.0 = 50000 internally).
##
## All changes flow through apply_farr_change(amount, reason, source_unit)
## per CLAUDE.md and docs/TESTING_CONTRACT.md §1.1. This class holds the
## magnitudes; the chokepoint is in FarrSystem.
##
## Kaveh Event reference: Shahnameh epic — Kaveh the Blacksmith's revolt
## against Zahhak's unjust rule. If Iran's Farr collapses, the people revolt.
class_name FarrConfig extends Resource

# --- Thresholds ---

## Farr value at match start. 0–100 range.
## Starting value 50 = neutral; player must work to maintain or raise it.
## Reference: 01_CORE_MECHANICS.md §4.1.
@export var starting_value: float = 50.0

## Farr must be >= this to advance from Tier 1 (Village) to Tier 2 (Fortress).
## Reference: 01_CORE_MECHANICS.md §4.2 and §8.
@export var tier2_threshold: float = 40.0

## Farr below this value for kaveh_grace_ticks triggers the Kaveh Event.
## Must be < tier2_threshold (validate_hard enforces this).
## Reference: 01_CORE_MECHANICS.md §9.1.
@export var kaveh_trigger_threshold: float = 15.0

## Grace period in ticks before Kaveh Event fires after Farr drops below
## kaveh_trigger_threshold. At 30 Hz: 900 ticks = 30 seconds.
## Must be > 0 (validate_hard enforces this — zero removes player response window).
## Reference: 01_CORE_MECHANICS.md §9.1.
@export var kaveh_grace_ticks: int = 900

## Ticks Farr is locked after the Kaveh Event triggers (cannot be restored).
## At 30 Hz: 1800 ticks = 60 seconds.
## Reference: 01_CORE_MECHANICS.md §9.2.
@export var kaveh_farr_lock_ticks: int = 1800

## Farr must recover above this within kaveh_resolve_window_ticks to resolve
## the Kaveh Event via the "just path" (Kaveh disbands peacefully).
## Reference: 01_CORE_MECHANICS.md §9.3.
@export var kaveh_resolve_threshold: float = 30.0

## Window in ticks to resolve the Kaveh Event via Farr recovery.
## At 30 Hz: 2700 ticks = 90 seconds.
## Reference: 01_CORE_MECHANICS.md §9.3.
@export var kaveh_resolve_window_ticks: int = 2700

# --- DEPRECATED individual drain magnitudes (superseded by `drain_rates` dict below) ---
# Reference: 01_CORE_MECHANICS.md §4.3 (Drains section).
#
# DEPRECATED — Phase 3 wave-close (2026-05-14).
# Superseded by the `drain_rates: Dictionary` field below. The Phase 3
# Farr-drain dispatcher (`scripts/autoload/farr_drain_dispatcher.gd`)
# reads ONLY from `drain_rates` — none of the @export fields in this
# block are live in the runtime. They're retained on the resource only
# so old saved `balance.tres` files don't fail validation; they may be
# removed in a Phase 4 cleanup pass alongside the cause-string-suffix
# retirement noted in §6 v0.20.3. Do not add new triggers here — add
# a new key to `drain_rates` and emit it from the relevant dispatcher.

## DEPRECATED. See `drain_rates[&"worker_killed_idle"]` (= 1.0; positive magnitude).
@export var drain_idle_worker_killed: float = -1.0

## DEPRECATED. See `drain_rates[&"hero_died"]` (= 5.0) — friendly-fire variant
## will land as a separate key when Rostam ships in Phase 4.
@export var drain_hero_attack_ally: float = -5.0

## DEPRECATED. See `drain_rates[&"hero_died"]` (= 5.0) — flee/honest-battle
## distinction will land as separate keys when Rostam death-trigger ships.
@export var drain_hero_killed_fleeing: float = -10.0

## DEPRECATED. See `drain_rates[&"hero_died"]` (= 5.0).
@export var drain_hero_killed_battle: float = -5.0

## DEPRECATED. See `drain_rates[&"building_destroyed_atashkadeh"]` (= 5.0).
@export var drain_atashkadeh_lost: float = -5.0

## DEPRECATED. Snowball protection lands in Phase 4 with its own
## `snowball_*` keys in `drain_rates`.
@export var drain_snowball_per_kill: float = -0.5

## DEPRECATED. Snowball protection — see note above.
@export var drain_snowball_worker: float = -1.0

## Army size ratio that triggers snowball protection (attacker:defender).
## 3:1 or more triggers per §4.3.
@export var snowball_ratio: float = 3.0

# --- Drain-rate table (Phase 3 wave 1B + forward-compat keys) ---
# Reference: 02f_PHASE_3_KICKOFF.md §2 Open Space resolution; canonical Farr
# drain rates table per the Constraint Negotiation between balance-engineer
# and gameplay-systems.
#
# Convention:
#   - POSITIVE magnitudes here. The Farr-drain dispatcher applies the negative
#     sign at the call site: FarrSystem.apply_farr_change(-magnitude, ...).
#   - StringName keys match the reasons recorded in the F2 overlay log so
#     post-hoc analysis can trace every Farr movement back to its trigger.
#
# Phase 3 wired keys (the drain dispatcher subscribes to unit_health_zero and
# reads fsm.current.id PRE-Dying-swap to pick one of these):
#   worker_killed_idle              — Kargar killed while in &"idle" state
#   worker_killed_during_gather     — Kargar killed while gathering / returning
#
# Forward-compat keys (Phase 4+; the dispatcher fires zero drain if absent):
#   capital_damaged                 — Throne HP loss event (per-hit trigger)
#   capital_lost                    — Throne destroyed (game-ending drain)
#   building_destroyed_civilian     — Khaneh / Mazra'eh lost
#   building_destroyed_military     — Sarbaz-khaneh lost
#   building_destroyed_atashkadeh   — sacred-flame loss (heavy drain per §4.3)
#   hero_died                       — Rostam dies (per §7.3)
#
# Why a dict instead of @export fields per key:
#   The drain dispatcher looks up by StringName at runtime. A dict makes the
#   "what reasons trigger drains?" surface explicit (the keys present == the
#   reasons honored). New drain triggers add a key here + an emit site;
#   no schema migration needed.
@export var drain_rates: Dictionary = {
	&"worker_killed_idle": 1.0,
	&"worker_killed_during_gather": 0.5,
	&"capital_damaged": 2.0,
	&"capital_lost": 12.0,
	&"building_destroyed_civilian": 1.5,
	&"building_destroyed_military": 2.5,
	&"building_destroyed_atashkadeh": 5.0,
	&"hero_died": 5.0,
}

# --- Generation magnitudes (positive Farr deltas) ---
# Reference: 01_CORE_MECHANICS.md §4.3 (Generators section).
# Building Farr generation (Atashkadeh, Dadgah, Barghah, Yadgar) is per-tick
# and lives in BuildingStats.farr_per_tick, not here.

## Farr gained when hero rescues another unit from death (last-second save).
## "Hero rescues another unit from death (last-second save): +3 Farr" — §4.3.
@export var gain_hero_rescue: float = 3.0

## Farr gained when hero spares a defeated enemy hero (post-MVP).
## "Hero spares a defeated enemy hero: +5 Farr (post-MVP)" — §4.3.
@export var gain_hero_spares_enemy: float = 5.0
