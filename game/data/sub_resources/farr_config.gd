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

# --- Drain magnitudes (negative Farr deltas, expressed as negative floats) ---
# Reference: 01_CORE_MECHANICS.md §4.3 (Drains section).
# FarrSystem passes these to apply_farr_change(); sign is negative.

## Worker killed while idle and unarmed.
## "Worker killed while idle and unarmed: −1 Farr each" — §4.3.
@export var drain_idle_worker_killed: float = -1.0

## Hero attacks an ally unit (friendly fire).
## "Hero attacks an ally unit: −5 Farr" — §4.3.
@export var drain_hero_attack_ally: float = -5.0

## Hero killed while fleeing combat (facing away from enemy).
## "Hero killed while fleeing combat: −10 Farr" — §4.3.
@export var drain_hero_killed_fleeing: float = -10.0

## Hero killed in honest battle (facing the enemy).
## "−5 if killed in honest battle" — §7.3 Rostam death.
@export var drain_hero_killed_battle: float = -5.0

## Loss of an Atashkadeh building (sacred flame extinguished).
## "Loss of an Atashkadeh building: −5 Farr" — §4.3.
@export var drain_atashkadeh_lost: float = -5.0

## Per-kill drain when army outnumbers enemy by snowball_ratio:1 or more.
## "−0.5 Farr per kill" — §4.3 snowball protection.
@export var drain_snowball_per_kill: float = -0.5

## Per-worker drain when destroying enemy economy while their military is broken.
## "−1 Farr per worker" — §4.3 snowball protection.
@export var drain_snowball_worker: float = -1.0

## Army size ratio that triggers snowball protection (attacker:defender).
## 3:1 or more triggers per §4.3.
@export var snowball_ratio: float = 3.0

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
