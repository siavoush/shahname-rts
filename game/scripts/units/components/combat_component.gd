extends "res://scripts/core/sim_node.gd"
##
## CombatComponent — per-unit attack damage / speed / range and a target slot.
##
## Per docs/SIMULATION_CONTRACT.md §1.3 (SimNode discipline) + §1.6 (fixed-point
## integer arithmetic for accumulating state) and 02d_PHASE_2_KICKOFF.md §2
## deliverable 1.
##
## Behavior:
##   - The component holds a target unit_id (or -1 sentinel for "no target").
##     UnitState_Attacking calls `set_target(uid)` on entry; `_sim_tick`
##     fires an attack against that target each cycle, gated by an integer
##     cooldown counter and an XZ range check.
##   - Damage is applied via `target.get_health().take_damage_x100(amount)`
##     (the new fixed-point chokepoint added on HealthComponent in this wave).
##     Float damage paths exist on HealthComponent for legacy and tests.
##   - Cooldown is stored as integer ticks (`_attack_cooldown_ticks`),
##     decremented per tick. When it reaches 0 and the attack fires, the
##     cooldown is reset to `roundi(SimClock.SIM_HZ / attack_speed_per_sec)`.
##     Storing ticks (rather than seconds) keeps the timing exact across the
##     30 Hz integer tick cadence — same Sim Contract §1.6 reasoning that
##     drives Farr / hp_x100.
##   - Range check is XZ-only (Y axis ignored), matching SpatialIndex's
##     projection convention so combat range and selection-radius queries
##     agree about who's "near."
##
## Wiring (per State Machine Contract §3 lifecycle):
##   - The attacking state drives this component's `_sim_tick(dt)` directly,
##     same way Phase 1 wave-2 UnitState_Moving drives MovementComponent.
##     When the future CombatSystem phase coordinator ships, it will iterate
##     registered CombatComponents in `combat` phase order and the state's
##     direct call moves out (a one-line refactor, documented as a LATER
##     item per the wave-1A BUILD_LOG entry).
##
## Target lookup seam:
##   - Production wires `target_lookup_callable` from a Unit-registry autoload
##     OR a parent-Unit-walks-the-tree fallback (the kickoff §2 deliverable
##     1 left this open: "use SpatialIndex or a unit registry — if no
##     registry exists, this is the trigger to add one"). Wave 1A picks the
##     simplest path that keeps tests fast: a `Callable(int) -> Node3D`
##     injected by tests, with a default fallback that walks the tree from
##     the parent Unit looking for any Unit with the matching `unit_id`.
##     A registry autoload is a LATER item once the unit count exceeds the
##     scale where a tree-walk is acceptable (Phase 2 session 2 / Phase 3 —
##     adds 50+ units; tree-walk per attack tick becomes O(N)).
##
## Why extend SimNode (via path-string preload, not class_name)?
## Same project-wide pattern (docs/ARCHITECTURE.md §6 v0.4.0 registry race).
## class_name retained so unit / state code can declare typed
## `@onready var combat: CombatComponent`.
class_name CombatComponent

# Reference to the attacker's unit_id, supplied by the parent Unit on _ready.
# Mirrors the HealthComponent / MovementComponent convention.
@export var unit_id: int = -1

# Public combat stats. Read from BalanceData.units[unit_type] in
# Unit._apply_balance_data_defaults; tests may override directly.
#
# attack_damage_x100: fixed-point integer (Sim Contract §1.6). 10.0 hp/hit
# stored as 1000. Routed through HealthComponent.take_damage_x100 so no
# rounding happens on the damage application path.
var attack_damage_x100: int = 0

# attack_speed_per_sec: float — attacks per second. Float here is fine
# because we round to integer ticks at the cooldown-reset boundary, so
# accumulating drift never has a chance to build up. The integer cooldown
# itself is the deterministic store.
var attack_speed_per_sec: float = 1.0

# attack_range: float — world units. Compared against XZ-only squared
# distance (no sqrt). Float because instantaneous values per Sim Contract
# §1.6 ("Position, velocity, and other per-frame physics state stay float").
var attack_range: float = 1.5


# === Internal state =========================================================

# Integer cooldown counter. 0 means "ready to fire." Decremented at the
# start of every _sim_tick.
var _attack_cooldown_ticks: int = 0

# Current target's unit_id, or -1 sentinel for "no target." Cleared back
# to -1 when the target frees mid-tick (defensive against the Phase 1
# session 2 cb95d09-class re-entrancy lesson — see BUILD_LOG 2026-05-04).
var _target_unit_id: int = -1


# Target-lookup seam. Production sets this to a registry autoload's lookup
# function; tests inject a closure over fixture nodes. If null, the
# fallback walks the scene tree from the parent Unit looking for a sibling
# Unit with the matching unit_id (good enough for Phase 2 session 1's
# 5v5 mirror combat scale).
var target_lookup_callable: Callable = Callable()


# === Public API =============================================================

## Set the current target by unit_id. -1 clears the target back to "no target."
##
## Resets the cooldown to 0 so the first tick after acquiring a target can
## fire immediately (no "wind-up" delay). The state machine's enter() is
## what calls this; the discrete enter+first-tick gives a single-tick
## attack on engagement, which matches RTS expectations.
func set_target(unit_id_value: int) -> void:
	_target_unit_id = unit_id_value
	_attack_cooldown_ticks = 0


# === Per-tick simulation ====================================================

## Per-tick combat logic.
##
## Order:
##   1. Decrement _attack_cooldown_ticks (clamped at 0).
##   2. If no target, return.
##   3. Look up the target; if not valid (freed, or registry returned null),
##      clear _target_unit_id and return.
##   4. XZ range check; if out of range, return (the state handles re-entry
##      to Moving to close the gap).
##   5. If cooldown > 0, return (waiting).
##   6. Apply damage via target.get_health().take_damage_x100(attack_damage_x100)
##      and reset cooldown to roundi(SIM_HZ / attack_speed_per_sec).
func _sim_tick(_dt: float) -> void:
	# Step 1: cooldown decrement.
	if _attack_cooldown_ticks > 0:
		_set_sim(&"_attack_cooldown_ticks", _attack_cooldown_ticks - 1)

	# Step 2: no-target shortcut.
	if _target_unit_id == -1:
		return

	# Step 3: target resolution. If the registry returns null OR the node
	# is no longer valid, clear and bail.
	var target: Node3D = _resolve_target(_target_unit_id)
	if target == null or not is_instance_valid(target):
		_set_sim(&"_target_unit_id", -1)
		return

	# Step 4: XZ-only range check. Squared distance avoids a sqrt; matches
	# SpatialIndex's _xz_distance_sq projection.
	var attacker_pos: Vector3 = _get_owner_position()
	var target_pos: Vector3 = target.global_position
	var dx: float = attacker_pos.x - target_pos.x
	var dz: float = attacker_pos.z - target_pos.z
	var dist_sq: float = dx * dx + dz * dz
	if dist_sq > attack_range * attack_range:
		# Out of range; the state machine re-enters Moving to close.
		# Don't reset cooldown here — if we just regained range, we want
		# to fire on the next tick, not eat another wait cycle.
		return

	# Step 5: cooldown gate.
	if _attack_cooldown_ticks > 0:
		return

	# Step 6: fire. Pull HealthComponent off the target (duck-typed via
	# get_health(); both Unit and the test fixture expose it) and call
	# take_damage_x100. Then reset cooldown.
	if not target.has_method(&"get_health"):
		# Defensive: target shape doesn't match. Clear and bail.
		_set_sim(&"_target_unit_id", -1)
		return
	var health: Node = target.call(&"get_health")
	if health == null or not is_instance_valid(health):
		_set_sim(&"_target_unit_id", -1)
		return
	if health.has_method(&"take_damage_x100"):
		health.call(&"take_damage_x100", attack_damage_x100, get_parent())
	# Cooldown reset. roundi enforces the deterministic rounding rule
	# called out in Sim Contract §1.6.
	var cooldown: int = roundi(float(SimClock.SIM_HZ) / attack_speed_per_sec)
	# Defensive: attack_speed_per_sec near 0 would produce huge cooldowns
	# (effectively never-fire); cap at sane upper bound to keep the integer
	# from wrapping and to make tests deterministic. SIM_HZ * 60 = 1 minute
	# at 30 Hz; an attacker that "never" attacks should be modeled with a
	# different mechanism, not a 1e6-tick cooldown.
	if cooldown < 1:
		cooldown = 1
	_set_sim(&"_attack_cooldown_ticks", cooldown)


# === Internal helpers =======================================================

# Resolve a unit_id to a Node3D. Calls target_lookup_callable if set;
# otherwise walks the parent Unit's siblings looking for any Unit whose
# unit_id matches. Returns null if not found.
func _resolve_target(uid: int) -> Node3D:
	if target_lookup_callable.is_valid():
		var result: Variant = target_lookup_callable.call(uid)
		if result is Node3D:
			return result as Node3D
		return null
	# Fallback: walk the scene tree from the root looking for a Node3D with
	# matching unit_id. O(N) — acceptable at session-1 scale (10 units total).
	# A registry autoload is the right answer when scale increases (LATER).
	var root: Node = get_tree().root if get_tree() != null else null
	if root == null:
		return null
	return _walk_for_unit_id(root, uid)


func _walk_for_unit_id(node: Node, uid: int) -> Node3D:
	# Cheap duck-typed check — don't import Unit (registry race), just look
	# for the unit_id property on Node3Ds.
	if node is Node3D:
		var node_uid: Variant = node.get(&"unit_id")
		if typeof(node_uid) == TYPE_INT and int(node_uid) == uid:
			return node as Node3D
	for child in node.get_children():
		var hit: Node3D = _walk_for_unit_id(child, uid)
		if hit != null:
			return hit
	return null


func _get_owner_position() -> Vector3:
	var p: Node = get_parent()
	if p is Node3D:
		return (p as Node3D).global_position
	return Vector3.ZERO
