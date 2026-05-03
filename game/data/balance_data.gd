##
## BalanceData — top-level Resource holding every tunable gameplay number.
##
## Canonical shape: docs/TESTING_CONTRACT.md §1.1 and §1.2
## Loaded once at match start from Constants.PATH_BALANCE_DATA ("res://data/balance.tres").
## All tunable numbers live here; structural constants live in constants.gd.
##
## Sub-resources:
##   units    Dictionary[StringName -> UnitStats]
##   buildings  Dictionary[StringName -> BuildingStats]
##   farr       FarrConfig
##   combat     CombatMatrix
##   economy    EconomyConfig (contains ResourceNodeConfig)
##   ai         AIConfig
##
## Validation:
##   validate_hard() -> Array[String]  — call at match start; non-empty = refuse to load
##   validate_soft() -> Array[String]  — call at match start; non-empty = log warnings only
##
## constants_version is a manual stamp for now ("YYYY-MM-DD-label").
## qa-engineer will wire file-hash auto-derivation in wave 2 (MatchHarness).
## See: TESTING_CONTRACT.md §2.3 for the hash-of-file-content spec.
##
## Hot-reload:
##   Phase 5: FarrConfig-only hot-reload wired in FarrSystem.
##   Phase 8: Full sub-resource hot-reload if Phase 5 cost is low.
##   Until then: load once at match start, edit and re-run.
class_name BalanceData extends Resource

## Manual version stamp. Format: "YYYY-MM-DD-label" or git hash substring.
## qa-engineer will replace this with a file-hash auto-derivation in wave 2
## when MatchHarness ships. Per TESTING_CONTRACT.md §2.3.
@export var constants_version: String = ""

## Unit stat dictionary. Keys are unit-type StringNames matching the unit
## type identifiers used throughout the codebase (e.g., &"kargar", &"piyade").
## Values are UnitStats Resources.
## Consumed by: ProductionSystem, CombatSystem, HealthComponent.
@export var units: Dictionary = {}

## Building stat dictionary. Keys are building-type StringNames
## (e.g., &"throne", &"khaneh", &"atashkadeh").
## Values are BuildingStats Resources.
## Consumed by: BuildingSystem, FarrSystem (for farr_per_tick).
@export var buildings: Dictionary = {}

## Farr threshold, drain, and generation config.
## Consumed by: FarrSystem, KavehEventSystem, TechSystem (tier2_threshold).
@export var farr: FarrConfig = FarrConfig.new()

## Combat effectiveness multipliers (rock-paper-scissors triangle).
## Consumed by: CombatSystem.
@export var combat: CombatMatrix = CombatMatrix.new()

## Economy starting values and resource-node yield tuning.
## Consumed by: ResourceSystem, MineNode, Mazra'eh.
@export var economy: EconomyConfig = EconomyConfig.new()

## Turan AI difficulty parameters (flat fields × 3 difficulties).
## Consumed by: TuranAIController (Phase 6).
@export var ai: AIConfig = AIConfig.new()


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## validate_hard() -> Array[String]
##
## Called at match start by MatchHarness (and future GameManager).
## Returns an empty array on success.
## Returns a list of human-readable violation strings on failure.
## A non-empty return REFUSES the match load — the caller must halt.
##
## Four invariants checked (per TESTING_CONTRACT.md §1.3):
##   1. Any HP or cost value < 0
##   2. farr.kaveh_trigger_threshold >= farr.tier2_threshold (incoherent order)
##   3. farr.kaveh_grace_ticks == 0 (removes player response window)
##   4. Any CombatMatrix effectiveness value outside [0.0, 5.0]
func validate_hard() -> Array[String]:
	var errors: Array[String] = []

	# --- Invariant 1: No negative HP or costs ---
	for unit_key: Variant in units:
		var us: UnitStats = units[unit_key]
		if us.max_hp < 0.0:
			errors.append("units[%s].max_hp is negative (%s)" % [unit_key, us.max_hp])
		if us.coin_cost < 0:
			errors.append("units[%s].coin_cost is negative (%s)" % [unit_key, us.coin_cost])
		if us.grain_cost < 0:
			errors.append("units[%s].grain_cost is negative (%s)" % [unit_key, us.grain_cost])
		if us.damage < 0.0:
			errors.append("units[%s].damage is negative (%s)" % [unit_key, us.damage])
		# Fixed-point combat fields (Phase 2 — Sim Contract §1.6)
		if us.attack_damage_x100 < 0:
			errors.append("units[%s].attack_damage_x100 is negative (%s)" % [unit_key, us.attack_damage_x100])
		if us.attack_speed_per_sec <= 0.0:
			errors.append("units[%s].attack_speed_per_sec is <= 0 (%s) — divide-by-zero in cooldown calc" % [unit_key, us.attack_speed_per_sec])
		if us.attack_range < 0.0:
			errors.append("units[%s].attack_range is negative (%s)" % [unit_key, us.attack_range])

	for bld_key: Variant in buildings:
		var bs: BuildingStats = buildings[bld_key]
		if bs.max_hp < 0.0:
			errors.append("buildings[%s].max_hp is negative (%s)" % [bld_key, bs.max_hp])
		if bs.coin_cost < 0:
			errors.append("buildings[%s].coin_cost is negative (%s)" % [bld_key, bs.coin_cost])
		if bs.grain_cost < 0:
			errors.append("buildings[%s].grain_cost is negative (%s)" % [bld_key, bs.grain_cost])

	# --- Invariant 2: Kaveh threshold must be below Tier 2 threshold ---
	# If kaveh_trigger_threshold >= tier2_threshold, the Kaveh Event can fire
	# before the player has even been able to attempt Tier 2 — logically incoherent.
	if farr.kaveh_trigger_threshold >= farr.tier2_threshold:
		errors.append(
			"farr.kaveh_trigger_threshold (%.1f) >= farr.tier2_threshold (%.1f): "
			% [farr.kaveh_trigger_threshold, farr.tier2_threshold]
			+ "Kaveh Event would fire before Tier 2 is reachable — logically incoherent."
		)

	# --- Invariant 3: Grace ticks must be > 0 ---
	# Zero removes the player's response window entirely. Design invariant from
	# 01_CORE_MECHANICS.md §9.1 ("30-second grace period exists so the player
	# has a chance to recover").
	if farr.kaveh_grace_ticks == 0:
		errors.append(
			"farr.kaveh_grace_ticks == 0: removes player response window. "
			+ "Must be >= 1 tick. Design invariant per 01_CORE_MECHANICS.md §9.1."
		)

	# --- Invariant 4: All CombatMatrix effectiveness values in [0.0, 5.0] ---
	# Values above 5× or below 0 are almost certainly data entry errors and
	# will produce nonsensical combat outcomes.
	for attacker_key: Variant in combat.effectiveness:
		var defender_dict: Variant = combat.effectiveness[attacker_key]
		if typeof(defender_dict) != TYPE_DICTIONARY:
			errors.append(
				"combat.effectiveness[%s] is not a Dictionary (got %s)"
				% [attacker_key, typeof(defender_dict)]
			)
			continue
		for defender_key: Variant in defender_dict:
			var mult: Variant = defender_dict[defender_key]
			if typeof(mult) != TYPE_FLOAT and typeof(mult) != TYPE_INT:
				errors.append(
					"combat.effectiveness[%s][%s] is not numeric"
					% [attacker_key, defender_key]
				)
				continue
			var mult_f: float = float(mult)
			if mult_f < 0.0 or mult_f > 5.0:
				errors.append(
					"combat.effectiveness[%s][%s] = %.2f is outside [0.0, 5.0]"
					% [attacker_key, defender_key, mult_f]
				)

	return errors


## validate_soft() -> Array[String]
##
## Called at match start alongside validate_hard(). Non-blocking — a non-empty
## return logs warnings to the F2 Farr overlay (per TESTING_CONTRACT.md §1.3)
## but does not refuse the match load.
##
## Catches economic nonsense and suspicious values without hard-blocking.
func validate_soft() -> Array[String]:
	var warnings: Array[String] = []

	# Warn if starting Farr is not within the valid meter range
	if farr.starting_value < 0.0 or farr.starting_value > 100.0:
		warnings.append(
			"farr.starting_value (%.1f) is outside normal Farr range [0, 100]."
			% farr.starting_value
		)

	# Warn if economy starting resources are extremely high or zero
	if economy.starting_coin == 0:
		warnings.append("economy.starting_coin is 0 — match will start resource-locked.")
	if economy.starting_coin > 10000:
		warnings.append(
			"economy.starting_coin (%d) is unusually high — may trivialize early economy."
			% economy.starting_coin
		)

	# Warn if Farr drain magnitudes seem extreme (>20 is surprising, not impossible)
	var large_drain_threshold: float = 20.0
	if absf(farr.drain_hero_killed_fleeing) > large_drain_threshold:
		warnings.append(
			"farr.drain_hero_killed_fleeing (%.1f) exceeds -%.0f — very punishing."
			% [farr.drain_hero_killed_fleeing, large_drain_threshold]
		)

	# Warn if Farr kaveh_grace_ticks is very short (under 3 seconds = 90 ticks)
	# Doesn't trip the hard check (> 0) but may be too short in practice
	if farr.kaveh_grace_ticks > 0 and farr.kaveh_grace_ticks < 90:
		warnings.append(
			"farr.kaveh_grace_ticks (%d) is under 90 ticks (3s) — "
			% farr.kaveh_grace_ticks
			+ "player response window may be too short to be meaningful."
		)

	# Warn if any unit has suspiciously extreme combat stats (Phase 2 fields)
	for unit_key: Variant in units:
		var us: UnitStats = units[unit_key]
		if us.attack_damage_x100 > 10000:
			warnings.append(
				"units[%s].attack_damage_x100 (%d) > 10000 — likely a data entry error (= %.1f damage per hit)."
				% [unit_key, us.attack_damage_x100, us.attack_damage_x100 / 100.0]
			)
		if us.attack_speed_per_sec > 100.0:
			warnings.append(
				"units[%s].attack_speed_per_sec (%.1f) > 100 — unreasonably fast attack rate."
				% [unit_key, us.attack_speed_per_sec]
			)
		if us.attack_range > 50.0:
			warnings.append(
				"units[%s].attack_range (%.1f) > 50 world units — beyond typical screen distance."
				% [unit_key, us.attack_range]
			)

	# Warn if combat matrix is completely empty (no matchups defined)
	if combat.effectiveness.is_empty():
		warnings.append(
			"combat.effectiveness dictionary is empty — all combat will use base damage "
			+ "with no type advantages. Intended only for early Phase 0 testing."
		)

	# Warn if constants_version is unset (log will be unidentifiable post-hoc)
	if constants_version.is_empty():
		warnings.append(
			"constants_version is empty — match logs will not be identifiable "
			+ "to a specific tuning state."
		)

	return warnings
