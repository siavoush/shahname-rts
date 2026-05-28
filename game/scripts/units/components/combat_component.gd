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

# attacker_unit_type: StringName — the OWNING unit's type identifier
# (e.g., &"piyade", &"savar", &"turan_kamandar"). Read by the RPS multiplier
# lookup at damage-fire time. Set by Unit._apply_balance_data_defaults from
# the parent Unit's `unit_type` field. Defaults to &"" — get_multiplier()
# treats an unknown attacker as 1.0× (forward-compat / pre-wired tests).
#
# Phase 2 session 2 wave 2A — see 02e_PHASE_2_SESSION_2_KICKOFF.md §2 item 5.
var attacker_unit_type: StringName = &""

# combat_matrix: CombatMatrix Resource (untyped slot to avoid the project-wide
# class_name registry race documented in docs/ARCHITECTURE.md §6 v0.4.0).
# Set by Unit._apply_balance_data_defaults to BalanceData.combat. Read at
# damage-fire time via combat_matrix.get_multiplier(attacker_type, target_type).
#
# CRITICAL — MUST call get_multiplier(...) NOT raw effectiveness[atk][def] dict
# access. get_multiplier() does Turan-mirror folding (strips "turan_" prefix,
# special-cases "turan_asb_savar" → "asb_savar_kamandar"). Raw dict access
# bypasses the fold and Turan units deal wrong damage in-game while headless
# tests pass. Flagged as the Live-game-broken-surface for this wave.
#
# Defaults to null — _sim_tick treats a missing matrix as 1.0× neutral so the
# wave-1A unit-test fixtures (which pre-date this field) still pass.
var combat_matrix: Resource = null


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

# BUG-H8 (2026-05-27): cached target Node ref to bypass the scene-tree walk
# when the caller knows the actual target. Avoids the Unit/Building
# unit_id namespace collision (per BUG-G1) where _walk_for_unit_id returns
# whichever node-of-id-N is found first — which may not be the intended
# target. Set via set_target_node(node); cleared on set_target(-1).
var _cached_target_node: Variant = null


# === Public API =============================================================

## Set the current target by unit_id. -1 clears the target back to "no target."
##
## Resets the cooldown to 0 so the first tick after acquiring a target can
## fire immediately (no "wind-up" delay). The state machine's enter() is
## what calls this; the discrete enter+first-tick gives a single-tick
## attack on engagement, which matches RTS expectations.
##
## **Idempotent on same-target re-entry (BUG-04 fix, Phase 2 session 1
## post-wave-3).** UnitState_Attacking._sim_tick calls this every in-range
## tick (per the BUG-01 fix's per-tick drive pattern). Without idempotency,
## cooldown would reset to 0 every tick and the attack would fire every
## tick (30 atk/sec at 30 Hz instead of the 1.0 atk/sec the cooldown
## semantic intends). The early-return preserves cooldown semantics across
## per-tick set_target calls while still resetting on a genuine target
## change (engagement, retarget). Only NEW targets restart the timing.
func set_target(unit_id_value: int) -> void:
	if _target_unit_id == unit_id_value:
		return
	# §9.M6 — log target change. Skips the idempotent re-entry so we only
	# see real target acquisitions / retargets / clears, not the per-tick spam.
	var owner_uid: int = -1
	var parent_node: Node = get_parent()
	if parent_node != null:
		var raw_uid: Variant = parent_node.get(&"unit_id")
		if typeof(raw_uid) == TYPE_INT:
			owner_uid = int(raw_uid)
	print("[combat] target_change attacker_id=%d %d→%d" % [
		owner_uid, _target_unit_id, unit_id_value])
	_target_unit_id = unit_id_value
	_attack_cooldown_ticks = 0
	if unit_id_value == -1:
		_cached_target_node = null


## Cache the actual target Node ref. Bypasses _resolve_target's id lookup
## (which can return wrong node on Unit/Building unit_id collision per
## BUG-G1). Caller MUST also call set_target(unit_id) for consistency.
## Pass null to clear.
func set_target_node(node: Variant) -> void:
	if node == null:
		_cached_target_node = null
		return
	if not is_instance_valid(node):
		_cached_target_node = null
		return
	_cached_target_node = node


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

	# Step 4: XZ-only range check. Edge-distance semantic for Buildings
	# (BUG-H6 fix-up): the unit can't reach the building's center (blocked
	# by NavigationObstacle3D) so the range check uses center-distance
	# minus footprint half-extent. For Units the footprint is 0.
	var attacker_pos: Vector3 = _get_owner_position()
	var target_pos: Vector3 = target.global_position
	var dx: float = attacker_pos.x - target_pos.x
	var dz: float = attacker_pos.z - target_pos.z
	var dist_sq: float = dx * dx + dz * dz
	var center_dist: float = sqrt(dist_sq)
	var fp_half: float = 0.0
	if target.has_method(&"get_footprint_aabb"):
		var aabb: AABB = target.get_footprint_aabb()
		fp_half = maxf(aabb.size.x, aabb.size.z) * 0.5
	var edge_dist: float = maxf(0.0, center_dist - fp_half)
	if edge_dist > attack_range:
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
		# RPS multiplier lookup (Phase 2 session 2 wave 2A — see kickoff §2
		# item 5). attacker_unit_type is set by Unit._apply_balance_data_defaults
		# from the parent Unit's `unit_type`; target_unit_type is read from the
		# resolved target Node3D. Both default to &"" if missing — get_multiplier
		# returns 1.0 for unknown pairs so unwired test fixtures still fire damage.
		#
		# CRITICAL — call get_multiplier(...) NOT effectiveness[atk][def] raw
		# dict access. get_multiplier folds the "turan_" prefix; raw access
		# silently misses Turan units and they deal wrong damage in the live
		# game. Flagged in the wave-2A kickoff brief as the load-bearing
		# Live-game-broken-surface for this integration.
		var scaled_damage_x100: int = attack_damage_x100
		if combat_matrix != null and combat_matrix.has_method(&"get_multiplier"):
			var target_unit_type: StringName = &""
			var raw_target_type: Variant = target.get(&"unit_type")
			if typeof(raw_target_type) == TYPE_STRING_NAME:
				target_unit_type = raw_target_type
			elif typeof(raw_target_type) == TYPE_STRING:
				target_unit_type = StringName(raw_target_type)
			var multiplier: float = float(combat_matrix.call(
				&"get_multiplier", attacker_unit_type, target_unit_type))
			# Round to int — Sim Contract §1.6 forbids storing the float on a
			# SimNode field. The local Variant slot above is fine (non-state).
			scaled_damage_x100 = roundi(float(attack_damage_x100) * multiplier)
		# Pass &"melee_attack" as the cause. HealthComponent's death emit
		# augments this with "_idle_worker" if the dying unit is a Kargar
		# in idle (Phase 2 session 1 wave 2A deliverable 10). Future
		# ranged units (Kamandar, ...) will pass &"ranged_attack" from
		# their own combat path — a CombatComponent-level "kind" flag is
		# a LATER refactor when the second cause source ships.
		# §9.M6 — log damage fire. Fires at attack_speed_per_sec rate (~1 Hz
		# for Piyade), bounded log volume. Includes attacker + target ids,
		# resolved unit types, post-multiplier damage_x100, distance.
		var owner_uid_for_log: int = -1
		var owner_parent: Node = get_parent()
		if owner_parent != null:
			var raw_owner_uid: Variant = owner_parent.get(&"unit_id")
			if typeof(raw_owner_uid) == TYPE_INT:
				owner_uid_for_log = int(raw_owner_uid)
		var target_uid_for_log: int = -1
		var raw_target_uid: Variant = target.get(&"unit_id")
		if typeof(raw_target_uid) == TYPE_INT:
			target_uid_for_log = int(raw_target_uid)
		var target_type_for_log: StringName = &""
		var raw_ttype: Variant = target.get(&"unit_type")
		if typeof(raw_ttype) == TYPE_STRING_NAME:
			target_type_for_log = raw_ttype
		elif typeof(raw_ttype) == TYPE_STRING:
			target_type_for_log = StringName(raw_ttype)
		else:
			# Buildings expose `kind: StringName` instead of `unit_type`.
			var raw_kind: Variant = target.get(&"kind")
			if typeof(raw_kind) == TYPE_STRING_NAME:
				target_type_for_log = raw_kind
		print("[combat] fire attacker_id=%d (%s) target_id=%d (%s) damage_x100=%d dist=%.2f" % [
			owner_uid_for_log, str(attacker_unit_type),
			target_uid_for_log, str(target_type_for_log),
			scaled_damage_x100, sqrt(dist_sq)])
		health.call(&"take_damage_x100", scaled_damage_x100, get_parent(), &"melee_attack")
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
	# BUG-H8: prefer cached Node ref if set. Bypasses the namespace-collision
	# risk in _walk_for_unit_id (Unit + Building both index into the global
	# unit_id counter; walk-first-hit can return the wrong one).
	if _cached_target_node != null and is_instance_valid(_cached_target_node) \
			and _cached_target_node is Node3D:
		return _cached_target_node as Node3D
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
