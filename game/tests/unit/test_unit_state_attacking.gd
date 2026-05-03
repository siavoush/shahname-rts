# Tests for UnitState_Attacking.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §3.4 (transition_to_next +
# current_command), §3.5 (interrupt levels), §6.2 (worked example).
#
# Wave 1B (Phase 2 session 1) deliverable. This wave builds the state
# itself — the click-handler enemy-right-click branch lands in wave 2B.
# Tests exercise the state in isolation by directly seeding
# `Unit.current_command` with the attack payload and forcing the FSM into
# &"attacking" via `transition_to`.
#
# Coordination with gameplay-systems wave 1A:
#   That wave ships CombatComponent + last_death_position + unit_died on
#   HealthComponent. CombatComponent.attack_range and CombatComponent.set_target
#   are the surfaces this state drives. Until that wave lands, the tests use
#   a lightweight stand-in CombatComponent stub attached to the unit (see
#   `_stub_combat_on`) so this state's behavior is verifiable independently
#   of the parallel gameplay-systems wave. When CombatComponent ships and
#   gets wired into unit.tscn, the tests still pass because the stub mirrors
#   the same surface (`attack_range: float`, `set_target(unit_id: int)`).
#
# What we cover:
#   - id / priority / interrupt_level shape
#   - enter() with valid target_unit_id caches the target Unit and combat ref
#   - enter() with missing target_unit_id bails to Idle
#   - enter() with a target_unit_id that doesn't resolve to a live unit bails
#     to Idle (defensive — same shape as Moving's no-target bail)
#   - _sim_tick when target is OUT of attack_range drives MovementComponent
#     repath toward target.global_position (per wave-1B brief option (b))
#   - _sim_tick when target is IN attack_range drives combat.set_target(id)
#   - _sim_tick after target is queue_freed transitions_to_next
#   - exit() clears combat target (set_target(-1)) and cancels in-flight repath
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/unit.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateAttackingScript: Script = preload(
	"res://scripts/units/states/unit_state_attacking.gd"
)
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd"
)
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")


# Stand-in CombatComponent for the duration of wave 1B.
#
# Mirrors the surface gameplay-systems wave 1A is shipping:
#   - attack_range: float
#   - set_target(unit_id: int) -> void
#   - last_set_target: int (test-only; track what set_target was called with)
#
# When the real CombatComponent lands and gets wired into unit.tscn, this
# stub is no longer needed for production paths. The tests inject the stub
# explicitly so the assertions remain valid against either shape.
class _StubCombat extends Node:
	var attack_range: float = 1.5
	var last_set_target: int = -1

	func set_target(unit_id: int) -> void:
		last_set_target = unit_id


var _attacker: Variant
var _target: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _attacker != null and is_instance_valid(_attacker):
		_attacker.queue_free()
	if _target != null and is_instance_valid(_target):
		_target.queue_free()
	_attacker = null
	_target = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


# Spawn a Unit and inject the test mock scheduler + a stub combat component.
# Returns the spawned unit; the stub combat is added as a child named
# "CombatComponent" so the to-be-shipped Unit.get_combat() accessor finds it
# via the same `get_node_or_null(^"CombatComponent")` lookup pattern other
# component getters use.
#
# Defensive against gameplay-systems' wave 1A landing the real CombatComponent
# in unit.tscn first: if a child already named "CombatComponent" exists, we
# remove it before attaching the stub. Either way the test owns the combat
# surface for its assertions (last_set_target, attack_range).
func _spawn_unit_with_stub_combat(team: int = 1) -> Variant:
	var u: Variant = UnitScene.instantiate()
	u.unit_type = &"piyade"
	u.team = team
	add_child_autofree(u)
	# Inject mock scheduler defensively — _ready may have latched the prod
	# instance via PathSchedulerService.scheduler.
	u.get_movement()._scheduler = _mock
	# If the real CombatComponent already wired into unit.tscn, remove it so
	# the stub is the only "CombatComponent" child.
	var existing: Node = u.get_node_or_null(^"CombatComponent")
	if existing != null:
		u.remove_child(existing)
		existing.queue_free()
	# Attach the combat stub. Unit.get_combat() (added in this wave) does
	# get_node_or_null(^"CombatComponent"), so we name the stub accordingly.
	var stub: _StubCombat = _StubCombat.new()
	stub.name = "CombatComponent"
	u.add_child(stub)
	# Re-resolve the @onready cache by reading from the live tree.
	u.set(&"_combat_component", stub)
	return u


# Drive a sim tick on the unit's FSM. Mirrors test_unit_states.gd::_tick_fsm.
func _tick_attacker() -> void:
	SimClock._is_ticking = true
	_attacker.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# Shape: id / priority / interrupt_level
# ---------------------------------------------------------------------------

func test_attacking_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateAttackingScript.new()
	assert_eq(s.id, &"attacking", "Attacking.id is &\"attacking\"")
	assert_eq(s.priority, 20,
		"Attacking.priority is 20 (above Moving's 10 — attack preempts move)")
	assert_eq(s.interrupt_level, InterruptLevel.NEVER,
		"Attacking.interrupt_level is NEVER — damage doesn't interrupt the "
		+ "attack itself, only player commands or death")


# ---------------------------------------------------------------------------
# enter(): valid + invalid target lookup
# ---------------------------------------------------------------------------

func test_enter_with_valid_target_caches_target_and_combat() -> void:
	_attacker = _spawn_unit_with_stub_combat(1)
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(0.5, 0.0, 0.0)  # in melee range

	# Seed current_command as if transition_to_next had dispatched an attack.
	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()

	assert_eq(_attacker.fsm.current.id, &"attacking",
		"unit transitions into Attacking on valid target lookup")


func test_enter_with_missing_target_unit_id_bails_to_idle() -> void:
	_attacker = _spawn_unit_with_stub_combat(1)
	# payload has no target_unit_id key.
	_attacker.current_command = {&"kind": &"attack", &"payload": {}}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()
	# Defensive bail: same pattern as UnitState_Moving's no-target branch.
	assert_eq(_attacker.fsm.current.id, &"idle",
		"Attacking with no target_unit_id in payload transitions back to Idle")


func test_enter_with_unresolvable_target_id_bails_to_idle() -> void:
	# target_unit_id refers to a unit that doesn't exist — defensive bail.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": 9999},  # no such unit
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"idle",
		"Attacking with unresolvable target_unit_id transitions back to Idle")


# ---------------------------------------------------------------------------
# _sim_tick: out-of-range vs. in-range behavior
# ---------------------------------------------------------------------------

func test_sim_tick_out_of_range_drives_request_repath_toward_target() -> void:
	# Target far enough to be out of melee range (attack_range = 1.5).
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(20.0, 0.0, 0.0)

	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	# Tick 1: StateMachine drains pending → Attacking.enter() runs (caches refs).
	_tick_attacker()
	# Tick 2: now Attacking._sim_tick actually runs and drives request_repath.
	_tick_attacker()
	# request_repath should have been called at least once with the target's
	# current position.
	assert_true(_mock.call_log.size() >= 1,
		"Attacking._sim_tick must drive request_repath when target out of range")
	var entry: Dictionary = _mock.call_log[_mock.call_log.size() - 1]
	assert_eq(entry.to, _target.global_position,
		"request_repath target matches the target unit's current position")


func test_sim_tick_in_range_drives_combat_set_target() -> void:
	# Target within melee range — attacker should drive combat.set_target.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(0.5, 0.0, 0.0)  # well within 1.5

	var combat: _StubCombat = _attacker.get_node(^"CombatComponent")

	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()  # tick 1: drain pending → Attacking.enter() runs
	_tick_attacker()  # tick 2: Attacking._sim_tick fires set_target

	assert_eq(combat.last_set_target, int(_target.unit_id),
		"Attacking._sim_tick must drive combat.set_target to the target unit_id "
		+ "when target is in attack_range")


# ---------------------------------------------------------------------------
# _sim_tick: target dies / queue_free
# ---------------------------------------------------------------------------

func test_sim_tick_after_target_freed_transitions_to_next() -> void:
	# Target is freed mid-combat. _sim_tick observes is_instance_valid is false
	# and transitions_to_next (lands in Idle when no command queued).
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(0.5, 0.0, 0.0)

	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"attacking",
		"unit is in Attacking after seeding current_command + transition")

	# Free the target. The is_instance_valid check on the cached ref should
	# become false on the next _sim_tick.
	_target.queue_free()
	# Wait one frame for queue_free to take effect.
	await get_tree().process_frame
	_target = null  # avoid re-free in after_each

	_tick_attacker()  # _sim_tick observes invalid target → transition_to_next
	assert_eq(_attacker.fsm.current.id, &"idle",
		"Attacking transitions to Idle after target is freed (no queued command)")


# ---------------------------------------------------------------------------
# exit(): combat target cleared + repath cancelled
# ---------------------------------------------------------------------------

func test_exit_clears_combat_target() -> void:
	# After Attacking exits, combat.set_target(-1) must have been called so
	# the CombatComponent doesn't keep firing at the prior target.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(0.5, 0.0, 0.0)

	var combat: _StubCombat = _attacker.get_node(^"CombatComponent")

	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()  # drain pending → enter()
	_tick_attacker()  # _sim_tick → set_target
	# Sanity: target was set in range during _sim_tick.
	assert_eq(combat.last_set_target, int(_target.unit_id))

	# Force a transition out — Attacking.exit fires.
	_attacker.fsm.transition_to(&"idle")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"idle")
	assert_eq(combat.last_set_target, -1,
		"Attacking.exit must clear combat target via set_target(-1)")


func test_exit_cancels_in_flight_repath() -> void:
	# Target out of range so enter() / _sim_tick issued a repath request.
	# Forcing a transition out of Attacking should cancel that request.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_target = _spawn_unit_with_stub_combat(2)
	_target.global_position = Vector3(20.0, 0.0, 0.0)

	_attacker.current_command = {
		&"kind": &"attack",
		&"payload": {&"target_unit_id": int(_target.unit_id)},
	}
	_attacker.fsm.transition_to(&"attacking")
	_tick_attacker()  # drain pending → enter()
	_tick_attacker()  # _sim_tick → request_repath out of range

	var first_id: int = int(_attacker.get_movement()._request_id)
	assert_true(first_id > 0,
		"out-of-range Attacking should have issued a repath request "
		+ "(got _request_id=%d)" % first_id)

	# Force exit by transitioning to Idle.
	_attacker.fsm.transition_to(&"idle")
	_tick_attacker()

	var poll: Dictionary = _mock.poll_path(first_id)
	assert_eq(poll.state, IPathSchedulerScript.PathState.CANCELLED,
		"Attacking.exit must cancel the in-flight repath")


# ---------------------------------------------------------------------------
# Registration: Unit base class registers Attacking alongside Idle / Moving
# ---------------------------------------------------------------------------

func test_unit_base_registers_attacking() -> void:
	# Sanity: the Unit base class registers Attacking on _ready, so concrete
	# unit types don't need to repeat the boilerplate. Mirrors the existing
	# Idle / Moving registration test in test_unit_states.gd.
	_attacker = _spawn_unit_with_stub_combat()
	assert_true(_attacker.fsm._states.has(&"attacking"),
		"Unit base class registers Attacking")


func test_unit_exposes_get_combat_accessor() -> void:
	_attacker = _spawn_unit_with_stub_combat()
	assert_true(_attacker.has_method(&"get_combat"),
		"Unit must expose get_combat() accessor (mirroring get_health / get_movement)")
	var combat: Variant = _attacker.get_combat()
	assert_true(combat != null,
		"get_combat() returns the CombatComponent child (stub here)")
