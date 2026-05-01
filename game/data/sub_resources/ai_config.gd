##
## AIConfig — Turan AI difficulty tuning parameters (flat fields × 3 difficulties).
##
## Canonical shape: docs/AI_DIFFICULTY.md §5 and docs/TESTING_CONTRACT.md §1.2
##
## Flat fields per difficulty, not nested Dicts, because Godot's Resource editor
## does not edit nested Dicts cleanly (per Testing Contract §1.2 rationale).
##
## Reference: 01_CORE_MECHANICS.md §12 (AI opponent) and docs/AI_DIFFICULTY.md §1.
## All values are starting points for Phase 6 AI-vs-AI simulation tuning.
##
## Application: TuranController (Phase 6) reads these. The gather multiplier is
## applied as dual-factor (target_workers + per-trip yield fallback) inside
## TuranController.EconomyState per AI_DIFFICULTY.md §5.
class_name AIConfig extends Resource

# --- Easy difficulty ---
# Slow waves, lower economy, tech-up delayed to 6 min.
# Target: novice player wins >= 60% of matches (AI_DIFFICULTY.md §3).
# Median match length: 20-28 min (acceptable overshoot of the 15-25 min spec).

## Ticks between Turan attack waves on Easy. 5400 ticks = 180s = 3 min.
@export var easy_wave_cadence_ticks: int = 5400

## Economy multiplier for Easy AI (applied in TuranController.EconomyState).
## 0.75× = AI gathers at 75% of normal worker rate per AI_DIFFICULTY.md §2.
@export var easy_ai_gather_mult: float = 0.75

## Ticks before Turan advances to Tier 2 (Fortress) on Easy. 10800 ticks = 360s = 6 min.
@export var easy_techup_ticks: int = 10800

## Minimum army size before Turan attacks on Easy.
## Prevents thinly-populated waves; each wave is meaningful.
@export var easy_attack_army_threshold: int = 8

# --- Normal difficulty ---
# Standard experience. Target: 50% win rate for experienced RTS player.
# Median match length: 17-22 min (within 15-25 min spec).

## Ticks between Turan attack waves on Normal. 3600 ticks = 120s = 2 min.
@export var normal_wave_cadence_ticks: int = 3600

## Economy multiplier for Normal AI. 1.0× = same as player base rate.
@export var normal_ai_gather_mult: float = 1.00

## Ticks before Turan tech-up on Normal. 9000 ticks = 300s = 5 min.
## Pinned at 5 min per 01_CORE_MECHANICS.md §12.
@export var normal_techup_ticks: int = 9000

## Minimum army size before Turan attacks on Normal.
@export var normal_attack_army_threshold: int = 12

# --- Hard difficulty ---
# Fast waves, boosted economy, early tech-up to 4 min.
# Target: experienced player wins < 30%, losing to economic pressure.
# Median match length: 13-18 min (weighted toward Iran losses).

## Ticks between Turan attack waves on Hard. 2700 ticks = 90s = 1.5 min.
@export var hard_wave_cadence_ticks: int = 2700

## Economy multiplier for Hard AI. 1.25× = 25% faster economy than player.
@export var hard_ai_gather_mult: float = 1.25

## Ticks before Turan tech-up on Hard. 7200 ticks = 240s = 4 min.
@export var hard_techup_ticks: int = 7200

## Minimum army size before Turan attacks on Hard.
## Larger threshold so each Hard wave is a serious push, not spam.
@export var hard_attack_army_threshold: int = 16
