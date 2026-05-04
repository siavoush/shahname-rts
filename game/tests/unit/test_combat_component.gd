# Tests for CombatComponent.
#
# Contracts:
#   - docs/SIMULATION_CONTRACT.md §1.3 (SimNode discipline) + §1.6 (fixed-point
#     for accumulating state — attack_damage_x100 + cooldown ticks)
#   - docs/STATE_MACHINE_CONTRACT.md §3 (state lifecycle — combat is driven
#     from the state's _sim_tick until MovementSystem-style coordinator ships)
#   - 02d_PHASE_2_KICKOFF.md §2 deliverable 1
#
# What we cover:
#   - HP decrements correctly on damage (target.get_health().take_damage path).
#   - Cooldown blocks rapid-fire attacks (one hit per (1/attack_speed_per_sec)).
#   - Cooldown formula at 30 Hz (attack_speed_per_sec = 1.0 → 30-tick cooldown).
#   - Range check blocks out-of-range attacks (XZ distance only).
#   - Target = -1 sentinel is a no-op (no scan, no damage).
#   - Target freed mid-tick → safely clears _target_unit_id without crash.
#   - set_target stores the id (resets cooldown so first-tick attack lands).
extends GutTest


const CombatComponentScript: Script = preload("res://scripts/units/components/combat_component.gd")
const HealthComponentScript: Script = preload("res://scripts/units/components/health_component.gd")


# Test fixtures: an attacker (Node3D + CombatComponent) and a target
# (Node3D + HealthComponent). Both parents are bare Node3Ds — the combat
# component reads the parent's global_position via get_parent(), and the
# health component is mutated by combat through a getter on the unit.
#
# We give the test a tiny fake unit-registry: a static Dictionary that maps
# unit_id -> Node3D parent. CombatComponent's set_target / look-up uses this
# registry. This is the minimal seam — production wires it through Unit.
var _attacker_parent: Node3D
var _target_parent: Node3D
var _combat: Variant
var _target_health: Variant


# Minimal stub of the unit-registry behavior. CombatComponent calls a global
# function (or autoload accessor) to look up units by id. We register both
# fixtures in the registry before each test.
class _FakeTargetUnit extends Node3D:
	var unit_id: int = -1
	var _health: Node = null

	func get_health() -> Node:
		return _health


func before_each() -> void:
	SimClock.reset()

	# Build the target: Node3D with HealthComponent child. The "unit" is the
	# Node3D itself, not a real Unit instance — CombatComponent only needs
	# `target.get_health()` and `target.global_position`, both available via
	# duck-typing on a Node3D with a custom method.
	#
	# Lesson from session-2 v0.14.5 (BUILD_LOG): add_child_autofree MUST
	# precede global_position assignment because Node3D.global_transform
	# asserts is_inside_tree(). Same pattern below.
	_target_parent = _FakeTargetUnit.new()
	_target_parent.unit_id = 100
	add_child_autofree(_target_parent)
	_target_parent.global_position = Vector3(0.0, 0.0, 0.0)

	_target_health = HealthComponentScript.new()
	_target_health.unit_id = 100
	_target_parent.add_child(_target_health)
	_target_health.init_max_hp(100.0)
	_target_parent._health = _target_health

	# Attacker: Node3D with CombatComponent child. Position 1.0 unit away on X;
	# default tests use a 2.0 attack range so this is in-range.
	_attacker_parent = Node3D.new()
	add_child_autofree(_attacker_parent)
	_attacker_parent.global_position = Vector3(1.0, 0.0, 0.0)

	_combat = CombatComponentScript.new()
	_combat.attack_damage_x100 = 1000   # 10.0 damage per hit
	_combat.attack_speed_per_sec = 1.0  # 1 attack/sec → 30-tick cooldown at 30Hz
	_combat.attack_range = 2.0
	_attacker_parent.add_child(_combat)

	# Wire the combat-component's target-lookup to the test fixture. The
	# component exposes a settable `target_lookup_callable` for tests; in
	# production it calls into a registry autoload (or walks the scene tree
	# from the parent Unit). The seam matches MovementComponent's _scheduler
	# injection pattern (Sim Contract §4.1 / movement_component.gd).
	_combat.target_lookup_callable = func(uid: int) -> Node3D:
		if _target_parent != null \
				and is_instance_valid(_target_parent) \
				and _target_parent.unit_id == uid:
			return _target_parent
		return null


func after_each() -> void:
	# add_child_autofree handles parent cleanup; the components were added
	# as their children so go down with them. No manual queue_free.
	SimClock.reset()


# Helper: run one tick around a body. Same shape as test_health_component's
# _on_tick — the lift to a real SimClock tick boundary so _set_sim asserts pass.
func _on_tick(body: Callable) -> void:
	SimClock._is_ticking = true
	body.call()
	SimClock._is_ticking = false


# Helper: drive the combat component's _sim_tick inside one tick boundary.
func _combat_tick() -> void:
	SimClock._is_ticking = true
	_combat._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# set_target / sentinel
# ---------------------------------------------------------------------------

func test_target_minus_one_is_noop() -> void:
	# Default: _target_unit_id starts at -1.
	assert_eq(_combat._target_unit_id, -1, "default target is -1 sentinel")
	# Tick with no target: HP unchanged.
	_combat_tick()
	assert_eq(_target_health.hp_x100, 10000, "no damage when target is -1")


func test_set_target_stores_id() -> void:
	_combat.set_target(100)
	assert_eq(_combat._target_unit_id, 100, "set_target stores the id")


# BUG-04 regression-lock — set_target is idempotent on same-target re-entry.
# UnitState_Attacking._sim_tick calls set_target every in-range tick after
# the BUG-01 fix; without idempotency, cooldown resets to 0 every tick and
# damage fires at 30 atk/sec instead of 1 atk/sec at 30 Hz. The early-return
# preserves cooldown semantics across per-tick set_target while still
# resetting on a genuine target change.
func test_set_target_idempotent_does_not_reset_cooldown() -> void:
	_combat.set_target(100)
	_combat_tick()  # First attack fires; cooldown resets to 30.
	assert_eq(_combat._attack_cooldown_ticks, 30,
		"pre-condition: first attack reset cooldown to 30")
	# Same-target re-call must NOT reset cooldown to 0.
	_combat.set_target(100)
	assert_eq(_combat._attack_cooldown_ticks, 30,
		"BUG-04: same-target set_target must be idempotent — cooldown preserved "
		+ "(if 0, set_target reset cooldown unconditionally and combat fires every tick)")


func test_set_target_new_target_resets_cooldown() -> void:
	_combat.set_target(100)
	_combat_tick()  # First attack fires; cooldown 30.
	# New target → cooldown reset (engagement timing starts fresh).
	_combat.set_target(200)
	assert_eq(_combat._attack_cooldown_ticks, 0,
		"genuine target change resets cooldown (single-tick attack on new engagement)")
	assert_eq(_combat._target_unit_id, 200, "new target id stored")


# ---------------------------------------------------------------------------
# Damage path
# ---------------------------------------------------------------------------

func test_attack_decrements_target_hp() -> void:
	_combat.set_target(100)
	# First tick should fire (cooldown starts at 0).
	_combat_tick()
	# 100.0 - 10.0 = 90.0 → 9000 fixed-point.
	assert_eq(_target_health.hp_x100, 9000,
		"in-range attack with cooldown ready must apply attack_damage_x100")


func test_attack_uses_fixed_point_damage_exactly() -> void:
	# 12.55 damage = 1255 fixed-point. Verify the attacker's fixed-point
	# damage flows through HealthComponent.take_damage without rounding drift.
	_combat.attack_damage_x100 = 1255
	_combat.set_target(100)
	_combat_tick()
	# 100.0 hp = 10000 fixed; minus 1255 = 8745.
	assert_eq(_target_health.hp_x100, 8745,
		"attack_damage_x100 = 1255 must reduce hp_x100 by exactly 1255")


# ---------------------------------------------------------------------------
# Cooldown
# ---------------------------------------------------------------------------

func test_cooldown_blocks_rapid_fire() -> void:
	_combat.set_target(100)
	# First tick fires; second tick (immediately) should NOT fire because
	# the cooldown was reset to 30 ticks (1.0s @ 30Hz at attack_speed = 1.0).
	_combat_tick()
	_combat_tick()
	assert_eq(_target_health.hp_x100, 9000,
		"cooldown must block a second hit on the very next tick")


func test_cooldown_resets_to_30_ticks_at_1_hz_attack_speed() -> void:
	# attack_speed_per_sec = 1.0 at 30 Hz tick rate produces a 30-tick cooldown.
	_combat.set_target(100)
	_combat_tick()
	# After one fire, cooldown should be 30 (we just consumed tick 0 of the
	# cooldown, so 30 remaining). The component decrements at the *start*
	# of each tick before checking — so 29 remaining is also acceptable per
	# implementation choice. Pin the exact contract: just-fired → 30.
	assert_eq(_combat._attack_cooldown_ticks, 30,
		"cooldown formula: roundi(SIM_HZ / attack_speed_per_sec) = 30 at 1.0/sec")


func test_cooldown_resets_to_15_ticks_at_2_hz_attack_speed() -> void:
	# attack_speed_per_sec = 2.0 → 15-tick cooldown. Cross-check the formula.
	_combat.attack_speed_per_sec = 2.0
	_combat.set_target(100)
	_combat_tick()
	assert_eq(_combat._attack_cooldown_ticks, 15,
		"cooldown formula: roundi(30 / 2.0) = 15")


func test_attack_fires_again_after_cooldown_elapses() -> void:
	_combat.set_target(100)
	# Tick 1: fires (cooldown ready), HP 100→90.
	_combat_tick()
	# Ticks 2..30: cooldown decrements, no hits. After 30 ticks total elapsed
	# from the first fire (which is itself tick 1), the cooldown should reach
	# 0 on tick 31 — i.e., 30 ticks AFTER the fire tick the next attack lands.
	for _i in range(29):
		_combat_tick()
	# After 30 total ticks (1 fire + 29 wait), cooldown should be 1 (still
	# blocked); on tick 31 it reaches 0 and fires.
	assert_eq(_target_health.hp_x100, 9000, "still 1-tick blocked at 29 waits")
	_combat_tick()
	# Now 30 waits elapsed → cooldown reached 0 → attack fired again.
	# 90.0 - 10.0 = 80.0 → 8000.
	assert_eq(_target_health.hp_x100, 8000,
		"attack must fire again after cooldown elapses")


# ---------------------------------------------------------------------------
# Range
# ---------------------------------------------------------------------------

func test_out_of_range_blocks_attack() -> void:
	# Move the target outside attack_range = 2.0.
	_target_parent.global_position = Vector3(10.0, 0.0, 0.0)
	_combat.set_target(100)
	_combat_tick()
	assert_eq(_target_health.hp_x100, 10000,
		"out-of-range target must NOT take damage")


func test_range_uses_xz_only_ignoring_y() -> void:
	# Y mismatch must NOT push the target out of range. Per Sim Contract §3,
	# spatial queries are XZ only; combat must follow the same projection.
	_target_parent.global_position = Vector3(1.0, 100.0, 0.0)
	_combat.set_target(100)
	_combat_tick()
	# In range on XZ (1.0 < 2.0); Y=100 is irrelevant.
	assert_eq(_target_health.hp_x100, 9000,
		"range must be XZ-only (Y axis ignored)")


# ---------------------------------------------------------------------------
# Freed-target safety
# ---------------------------------------------------------------------------

func test_freed_target_clears_target_id() -> void:
	_combat.set_target(100)
	# Free the target's parent before the combat tick. The combat component
	# must (a) not crash, (b) clear _target_unit_id back to -1.
	# Use free() (immediate) rather than queue_free() so is_instance_valid
	# returns false synchronously on the next tick. autofree's later cleanup
	# becomes a no-op for the already-freed node.
	_target_parent.free()
	_target_parent = null
	_target_health = null
	_combat_tick()
	assert_eq(_combat._target_unit_id, -1,
		"freed target must clear _target_unit_id back to -1 sentinel")
