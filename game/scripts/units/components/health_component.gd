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

# Captured at the moment hp first reaches 0 (BEFORE the unit is freed). Read
# by Phase 5's Yadgar building (where heroes died → memorial) per
# 01_CORE_MECHANICS.md §7. Stays at the death position even after the parent
# unit is queue_free'd; the Yadgar consumer reads this off the listener-side
# payload of EventBus.unit_died, not by calling back into the freed component.
##
## Default Vector3.ZERO has no special meaning — `_zero_emitted` is the
## "death has happened" gate that should be checked before treating
## last_death_position as authoritative.
var last_death_position: Vector3 = Vector3.ZERO


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


## Apply damage. Float-typed convenience wrapper; converts to fixed-point
## at the boundary and routes through _apply_damage_x100. Existing callers
## and tests that work in float units stay on this entry point.
##
## On-tick: routes through _set_sim (via _apply_damage_x100), which asserts
## SimClock.is_ticking(). Off-tick callers crash with a clear stack trace
## in debug builds.
##
## Parameters:
##   amount — float, in hp units (e.g., 12.0). Negative values silently
##            ignored (use heal() instead — no double-meaning of one method).
##   source — the attacker Node, accepted for telemetry symmetry with
##            apply_farr_change (CLAUDE.md mandate). Used downstream to
##            populate killer_unit_id in the unit_died emit.
func take_damage(amount: float, source: Node) -> void:
	if amount <= 0.0:
		return
	# Boundary conversion: float → fixed-point. Same rounding rule as
	# apply_farr_change (deterministic, half-away-from-zero).
	var delta_x100: int = roundi(amount * 100.0)
	_apply_damage_x100(delta_x100, source, &"unspecified")


## Apply damage in fixed-point hp units (hp × 100). The CombatComponent's
## hot path: skips the float→fixed-point conversion the float wrapper does,
## so the per-attack arithmetic is integer-only.
##
## Parameters:
##   amount_x100 — int, fixed-point. 1000 = 10.0 hp. Non-positive values
##                 silently ignored.
##   source — attacker Node (CombatComponent's parent Unit). Used to
##            populate killer_unit_id on the unit_died emit. May be null.
##   cause — StringName tag for telemetry / Farr-drain conditional
##           (e.g. &"melee_attack", &"ranged_attack", &"farr_drain").
##           Default &"unspecified" lets sites that don't care omit it.
func take_damage_x100(
		amount_x100: int,
		source: Node = null,
		cause: StringName = &"unspecified"
) -> void:
	if amount_x100 <= 0:
		return
	_apply_damage_x100(amount_x100, source, cause)


# Internal damage chokepoint. All damage paths end here. The death-emit
# discipline (capture position before emit; emit unit_died LAST) lives
# here so float and fixed-point callers behave identically.
#
# Listener-order discipline (per the cb95d09 lesson, BUILD_LOG 2026-05-04):
# the unit_died emit fires AFTER all internal mutation completes —
# hp_x100 is at 0, _zero_emitted is latched, last_death_position is
# captured. Listeners observe a fully-quiesced HealthComponent state and
# can safely mutate their own systems. unit_health_zero (the StateMachine
# death-preempt signal) fires BEFORE unit_died so the FSM transitions
# to Dying first; unit_died is the broader telemetry/Farr-drain channel.
func _apply_damage_x100(amount_x100: int, source: Node, cause: StringName) -> void:
	var new_hp_x100: int = max(0, hp_x100 - amount_x100)
	_set_sim(&"hp_x100", new_hp_x100)
	if new_hp_x100 != 0 or _zero_emitted:
		return

	# Capture the parent's world position BEFORE any consumer can free us.
	# Yadgar consumers (Phase 5) read this off the unit_died payload, not
	# by calling back into a possibly-freed HealthComponent.
	var death_pos: Vector3 = Vector3.ZERO
	var parent_node: Node = get_parent()
	if parent_node is Node3D:
		death_pos = (parent_node as Node3D).global_position
	_set_sim(&"last_death_position", death_pos)

	# Latch BEFORE emit so a re-entrant emit (an unforeseen consumer that
	# damages this same unit synchronously from its handler) cannot recurse
	# through the death path.
	_set_sim(&"_zero_emitted", true)

	# Resolve killer's unit_id from the source Node (duck-typed; same
	# pattern as FarrSystem.apply_farr_change).
	var killer_unit_id: int = -1
	if source != null and is_instance_valid(source):
		var uid: Variant = source.get(&"unit_id")
		if typeof(uid) == TYPE_INT:
			killer_unit_id = int(uid)

	# Cause-string augmentation for the worker-killed-idle Farr drain
	# (Phase 2 session 1 wave 2A deliverable 10, per 02d_PHASE_2_KICKOFF.md
	# §2 strategy (c)). When the dying unit is a Kargar AND its FSM is in
	# &"idle" at the moment of death, append "_idle_worker" to the cause.
	# FarrSystem's listener parses this suffix and applies -1 Farr
	# (01_CORE_MECHANICS.md §4 "Worker killed idle (-1)").
	#
	# Why this lives in HealthComponent (not FarrSystem): the listener-side
	# of unit_died can't reach back into a possibly-freed unit to ask
	# "were you idle?" The dying-side has the parent unit and its FSM
	# still alive (we're inside the damage tick, queue_free is deferred).
	# Encoding in the cause string is the simplest way to carry that info
	# across the signal boundary without extending the signal signature
	# (which would require coordinated changes across EventBus's allowlist
	# and forwarder; the suffix convention is forward-extensible without
	# any of that).
	#
	# Convention: the suffix is "_idle_worker" — concatenated with whatever
	# base cause the caller passed. So "melee_attack" becomes
	# "melee_attack_idle_worker" when the conditions match. FarrSystem's
	# parser uses String(cause).ends_with("_idle_worker") so any future
	# cause prefix automatically participates.
	var augmented_cause: StringName = cause
	var pn: Node = parent_node
	if pn != null:
		var pn_unit_type: Variant = pn.get(&"unit_type")
		if typeof(pn_unit_type) == TYPE_STRING_NAME and pn_unit_type == &"kargar":
			# Check the parent's FSM state via the legibility helper. Per
			# State Machine Contract §6.5: is_idle() returns true when the
			# unit's current state is &"idle" (and ALSO when fsm.current is
			# null, defensively — a unit with no current state is treated
			# as idle for damage-attribution purposes, since it's certainly
			# not engaged in any meaningful work).
			if pn.has_method(&"is_idle") and bool(pn.call(&"is_idle")):
				augmented_cause = StringName(String(cause) + "_idle_worker")

	# Emit ORDER MATTERS — see the listener-order discipline note above.
	#   1. unit_health_zero — StateMachine death-preempt (Contract §4.2).
	#      Triggers transition to &"dying" (or queue_free fallback).
	#   2. unit_died — broader payload for telemetry, FarrSystem drain
	#      (this session's wave 2A), Yadgar (Phase 5), SelectionManager
	#      eviction (LATER — currently SelectionManager filters via
	#      is_instance_valid each frame, but a unit_died-driven prune is a
	#      LATER optimization).
	EventBus.unit_health_zero.emit(unit_id)
	EventBus.unit_died.emit(unit_id, killer_unit_id, augmented_cause, death_pos)


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
