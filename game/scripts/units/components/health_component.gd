extends "res://scripts/core/sim_node.gd"
##
## HealthComponent — per-unit hit-point storage and damage/heal API.
##
## Per docs/STATE_MACHINE_CONTRACT.md §4 (death preempt) and
## docs/SIMULATION_CONTRACT.md §1.3 (SimNode discipline) + §1.6 (fixed-point
## numeric representation principle).
##
## Storage is fixed-point integer (hp × 100). 60.0 hp = 6000 stored.
## This is the same numeric-representation pattern FarrSystem uses, applied
## here so future regen / damage-over-time accumulators can mutate hp by
## fractional amounts without IEEE-754 platform divergence over a long match.
## Float conversion happens only at HUD/telemetry boundaries.
##
## Death signal: when hp reaches 0, the component emits
## EventBus.unit_health_zero(unit_id). The unit's StateMachine (already
## connected in Phase 0) force-transitions to Dying via the death-preempt
## handler in StateMachine._on_unit_health_zero (Contract §4.2).
##
## Why extend SimNode (via path-string preload, not class_name)?
## SimNode owns the on-tick mutation chokepoint (_set_sim with assert).
## Extending it means take_damage / heal inherit that discipline for free,
## and the runtime crash-in-debug fires on any off-tick mutation. The
## path-string base is the same workaround used by FarrSystem and the
## StateMachine framework (docs/ARCHITECTURE.md §6 v0.4.0): some consumers
## load this script from a context where the class_name registry isn't yet
## populated, so extending by class_name risks a resolution race.
##
## Per Contract §5.2: HealthComponent is the canonical example of the
## "real SimNode" pattern — gameplay state (hp) read by many systems must
## use _set_sim. Internal state on a State (e.g., a swing cooldown) does
## not, because it has no external write path.
##
## class_name retained because nothing extends this script inline in test
## scripts; the registry race that bites State / StateMachine doesn't apply
## here. Concrete unit scripts will declare typed `@onready var health: HealthComponent`
## fields against this class_name.
class_name HealthComponent

# Reference to the unit_id used by EventBus emissions. Set by the parent Unit
# in _ready (or by tests directly). Defaults to -1 ("no unit") so a freshly-
# constructed orphan component does not falsely claim unit_id 0.
@export var unit_id: int = -1

# Fixed-point storage for current hp. 100 = 1.0 hp. Default 0; set from
# BalanceData by the parent Unit's _ready (which knows the unit_type).
# Tests can construct a HealthComponent directly and set max_hp / hp_x100
# without going through BalanceData.
var hp_x100: int = 0

# Fixed-point storage for max hp. Same scaling as hp_x100. Set once at
# spawn; only mutated by tests or future "max-hp buff" gameplay (which
# would route through _set_sim).
var max_hp_x100: int = 0

# Latch so we only emit unit_health_zero once per zero-crossing. A zero-hp
# component that takes another damage tick (over-kill) must not re-emit.
# Reset only by heal() bringing hp back above 0 (which itself is a future
## edge case — for now, once dead, always dead until the unit is freed).
var _zero_emitted: bool = false


# Public read accessors. These are the boundary where fixed-point becomes
# float; consumers reading hp / max_hp see floats and can format them for
# the HUD without knowing about the fixed-point store.

var hp: float:
	get:
		return float(hp_x100) / 100.0

var max_hp: float:
	get:
		return float(max_hp_x100) / 100.0


## True iff the unit is still alive (hp > 0). Cheap predicate for AI / state
## decisions that don't care about exact hp.
var is_alive: bool:
	get:
		return hp_x100 > 0


# === Public API =============================================================

## Initialize hp from a float-typed max value. Called by the parent Unit
## after BalanceData lookup. Sets both max_hp_x100 and hp_x100 to the same
## fixed-point value (full health on spawn).
##
## Off-tick safe — initialization happens during _ready, before the first
## SimClock tick. Same pattern as FarrSystem._load_starting_value_from_balance_data.
func init_max_hp(max_hp_value: float) -> void:
	var v: int = max(0, roundi(max_hp_value * 100.0))
	max_hp_x100 = v
	hp_x100 = v
	_zero_emitted = false


## Apply damage. Decreases hp by `amount`, clamped to a non-negative floor.
## When hp reaches zero, emits EventBus.unit_health_zero(unit_id) exactly
## once (the latch prevents over-kill double-emit).
##
## On-tick: routes through _set_sim, which asserts SimClock.is_ticking().
## Off-tick callers crash with a clear stack trace in debug builds.
##
## Parameters:
##   amount — float, in hp units (e.g., 12.0). Negative values are silently
##            ignored (use heal() instead — no double-meaning of one method).
##   _source — the attacker Node, accepted for telemetry symmetry with
##             apply_farr_change (CLAUDE.md mandate). Currently unused at
##             this layer; the unit_died event downstream picks up killer
##             info when CombatSystem ships in Phase 2.
func take_damage(amount: float, _source: Node) -> void:
	if amount <= 0.0:
		return
	# Boundary conversion: float → fixed-point. Same rounding rule as
	# apply_farr_change (deterministic, half-away-from-zero).
	var delta_x100: int = roundi(amount * 100.0)
	var new_hp_x100: int = max(0, hp_x100 - delta_x100)
	_set_sim(&"hp_x100", new_hp_x100)
	if new_hp_x100 == 0 and not _zero_emitted:
		# Latch so over-kill ticks don't re-emit.
		_set_sim(&"_zero_emitted", true)
		EventBus.unit_health_zero.emit(unit_id)


## Apply healing. Increases hp by `amount`, clamped to max_hp_x100.
## Symmetric to take_damage; same on-tick assert via _set_sim.
##
## Parameter:
##   amount — float, in hp units. Negative values silently ignored.
func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	var delta_x100: int = roundi(amount * 100.0)
	var new_hp_x100: int = min(max_hp_x100, hp_x100 + delta_x100)
	_set_sim(&"hp_x100", new_hp_x100)
