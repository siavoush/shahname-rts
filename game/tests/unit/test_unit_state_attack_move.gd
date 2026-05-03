# Tests for UnitState_AttackMove.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §3.4 (transition_to_next +
# current_command), §3.5 (interrupt levels), Phase 2 session 1 wave 2B
# kickoff §2 deliverable 4.
#
# AttackMove is the "walk to target, engage anything in ENGAGE_RADIUS along
# the way, resume after kill" command. It composes Moving + per-tick spatial
# query + transition to Attacking.
#
# What we cover:
#   - id / priority / interrupt_level shape (priority between Moving's 10 and
#     Attacking's 20; interrupt_level NEVER like Attacking — engagement
#     commitment shouldn't be damage-interruptible)
#   - enter() with valid Vector3 target reads payload.target and calls
#     request_repath (same shape as UnitState_Moving's enter)
#   - enter() with no current_command bails to Idle (defensive)
#   - enter() with malformed target (non-Vector3) bails to Idle
#   - _sim_tick with NO enemy in engage radius behaves as Moving (drives
#     movement, eventually arrives → transition_to_next)
#   - _sim_tick with enemy in engage radius queues a follow-up AttackMove
#     command (resume after kill) and transitions to Attacking with the enemy
#     as target_unit_id
#   - exit() cancels in-flight repath (same defensive cleanup as Moving)
#   - resume-after-attack: queue inspection — after the Attacking transition,
#     ctx.command_queue's head should be a fresh AttackMove with the original
#     target so transition_to_next from Attacking re-enters AttackMove.
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/unit.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateAttackMoveScript: Script = preload(
	"res://scripts/units/states/unit_state_attack_move.gd"
)
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd"
)
const IPathSchedulerScript: Script = preload("res://scripts/core/path_scheduler.gd")


# Same shape as test_unit_state_attacking.gd's stub — gives us a CombatComponent
# substitute that responds to set_target() so AttackMove's transition into
# Attacking exercises its enter() path cleanly.
class _StubCombat extends Node:
	var attack_range: float = 1.5
	var last_set_target: int = -1

	func set_target(unit_id: int) -> void:
		last_set_target = unit_id


var _attacker: Variant
var _enemy: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	SpatialIndex.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _attacker != null and is_instance_valid(_attacker):
		_attacker.queue_free()
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()
	_attacker = null
	_enemy = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SpatialIndex.reset()
	SimClock.reset()
	CommandPool.reset()


# Spawn a Unit + inject mock scheduler + stub CombatComponent. Mirrors the
# pattern in test_unit_state_attacking.gd.
func _spawn_unit_with_stub_combat(team: int = 1) -> Variant:
	var u: Variant = UnitScene.instantiate()
	u.unit_type = &"piyade"
	u.team = team
	add_child_autofree(u)
	u.get_movement()._scheduler = _mock
	# Replace any auto-instanced CombatComponent with our stub.
	var existing: Node = u.get_node_or_null(^"CombatComponent")
	if existing != null:
		u.remove_child(existing)
		existing.queue_free()
	var stub: _StubCombat = _StubCombat.new()
	stub.name = "CombatComponent"
	u.add_child(stub)
	u.set(&"_combat_component", stub)
	# Mirror the team into the SpatialAgentComponent so query_radius_team
	# filtering picks up the right team. Unit._ready does this normally; we
	# refresh it here in case the team field was set after _ready.
	var sa: Node = u.get_node_or_null(^"SpatialAgentComponent")
	if sa != null:
		sa.set(&"team", team)
	return u


func _tick_attacker() -> void:
	SimClock._is_ticking = true
	_attacker.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# Force an immediate spatial-index rebuild so query_radius_team observes
# whatever positions we set in the test. The production path rebuilds during
# the spatial_rebuild phase; tests can drive it directly.
func _rebuild_spatial_index() -> void:
	SpatialIndex._rebuild()


# ---------------------------------------------------------------------------
# Shape: id / priority / interrupt_level
# ---------------------------------------------------------------------------

func test_attack_move_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateAttackMoveScript.new()
	assert_eq(s.id, &"attack_move",
		"AttackMove.id is &\"attack_move\"")
	assert_eq(s.priority, 15,
		"AttackMove.priority is 15 (between Moving's 10 and Attacking's 20)")
	assert_eq(s.interrupt_level, 2,
		"AttackMove.interrupt_level is NEVER (2) — same as Attacking; the "
		+ "command is committed engagement movement, not casual walking")


# ---------------------------------------------------------------------------
# enter(): valid + invalid payload handling
# ---------------------------------------------------------------------------

func test_enter_with_valid_target_calls_request_repath() -> void:
	# Same payload shape as Move (target: Vector3); kind differs as
	# &"attack_move" but enter() reads target the same way.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(20.0, 0.0, 0.0)}
	)
	_tick_attacker()  # drain dispatch
	assert_eq(_attacker.fsm.current.id, &"attack_move",
		"replace_command(&\"attack_move\") dispatches into AttackMove state")
	# request_repath fired with the payload target.
	assert_eq(_mock.call_log.size(), 1,
		"AttackMove.enter must call request_repath exactly once on entry")
	var entry: Dictionary = _mock.call_log[0]
	assert_eq(entry.to, Vector3(20.0, 0.0, 0.0),
		"request_repath target matches AttackMove command payload")


func test_enter_without_current_command_transitions_to_idle() -> void:
	# Defensive bail same as Moving's no-payload branch.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.current_command = {}
	_attacker.fsm.transition_to(&"attack_move")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"idle",
		"AttackMove with no current_command transitions back to Idle")


func test_enter_without_target_in_payload_transitions_to_idle() -> void:
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.current_command = {
		&"kind": &"attack_move",
		&"payload": {},
	}
	_attacker.fsm.transition_to(&"attack_move")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"idle",
		"AttackMove with no `target` in payload transitions back to Idle")


func test_enter_with_non_vector3_target_transitions_to_idle() -> void:
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.current_command = {
		&"kind": &"attack_move",
		&"payload": {&"target": "not_a_vector"},
	}
	_attacker.fsm.transition_to(&"attack_move")
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"idle",
		"AttackMove with malformed target transitions back to Idle")


# ---------------------------------------------------------------------------
# _sim_tick: no enemy in range — behaves as Moving
# ---------------------------------------------------------------------------

func test_sim_tick_no_enemy_in_range_behaves_as_moving() -> void:
	# With no enemy units registered with the SpatialIndex, AttackMove's
	# per-tick query_radius_team returns empty — the state should keep moving
	# toward the original target.
	_attacker = _spawn_unit_with_stub_combat(1)
	_attacker.global_position = Vector3.ZERO
	_attacker.get_movement().move_speed = 10.0
	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(5.0, 0.0, 0.0)}
	)
	_tick_attacker()  # dispatch into AttackMove + enter
	assert_eq(_attacker.fsm.current.id, &"attack_move",
		"unit is in AttackMove after dispatch")
	# Advance the mock so the path becomes READY.
	SimClock._test_run_tick()
	_rebuild_spatial_index()
	# Subsequent ticks: AttackMove keeps moving, eventually arrives → idle.
	# Stay in attack_move while waypoints remain — same arrival semantics as
	# UnitState_Moving.
	_tick_attacker()
	# AttackMove with no enemies should still be the active state on this
	# tick (path was just READY, waypoints loaded).
	assert_true(
		_attacker.fsm.current.id == &"attack_move"
		or _attacker.fsm.current.id == &"idle",
		"AttackMove with no enemies behaves as Moving — stays in state until "
		+ "arrival, then transitions to Idle"
	)


# ---------------------------------------------------------------------------
# _sim_tick: enemy in engage radius → transitions to Attacking with enemy id
# ---------------------------------------------------------------------------

func test_sim_tick_enemy_in_engage_radius_transitions_to_attacking() -> void:
	# Place an enemy unit within ENGAGE_RADIUS (4.0) of the attacker.
	# AttackMove's _sim_tick query_radius_team(self.position, ENGAGE_RADIUS,
	# OPPOSING_TEAM) finds them and dispatches an Attack command.
	_attacker = _spawn_unit_with_stub_combat(Constants.TEAM_IRAN)
	_attacker.global_position = Vector3.ZERO
	_enemy = _spawn_unit_with_stub_combat(Constants.TEAM_TURAN)
	_enemy.global_position = Vector3(2.0, 0.0, 0.0)  # within ENGAGE_RADIUS=4

	# Issue the attack_move command — target is well past the enemy so the
	# unit doesn't immediately arrive.
	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(50.0, 0.0, 0.0)}
	)
	_tick_attacker()  # dispatch → enter()
	assert_eq(_attacker.fsm.current.id, &"attack_move")

	# Force the spatial index to populate.
	_rebuild_spatial_index()

	# Tick again — _sim_tick runs the engage query and (with enemy in range)
	# transitions to Attacking.
	_tick_attacker()
	assert_eq(_attacker.fsm.current.id, &"attacking",
		"AttackMove with enemy in ENGAGE_RADIUS transitions to Attacking")


func test_sim_tick_attacking_uses_correct_enemy_target_id() -> void:
	# Verify the Attack command dispatched to Attacking carries the discovered
	# enemy's unit_id, not a stale target_unit_id from somewhere else.
	_attacker = _spawn_unit_with_stub_combat(Constants.TEAM_IRAN)
	_attacker.global_position = Vector3.ZERO
	_enemy = _spawn_unit_with_stub_combat(Constants.TEAM_TURAN)
	_enemy.global_position = Vector3(1.0, 0.0, 0.0)  # within melee range

	var combat: _StubCombat = _attacker.get_node(^"CombatComponent")

	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(50.0, 0.0, 0.0)}
	)
	_tick_attacker()  # enter()
	_rebuild_spatial_index()
	_tick_attacker()  # discover enemy → transition_to(&"attacking")
	# Attacking.enter caches the target; Attacking._sim_tick (next tick) drives
	# combat.set_target to the enemy id.
	_tick_attacker()
	assert_eq(combat.last_set_target, int(_enemy.unit_id),
		"AttackMove's discovered enemy must become the Attacking target's "
		+ "unit_id (verified via stub combat.set_target call)")


# ---------------------------------------------------------------------------
# Resume after kill: AttackMove queues a fresh AttackMove command before
# transitioning to Attacking, so transition_to_next from Attacking re-enters
# AttackMove with the original move target.
# ---------------------------------------------------------------------------

func test_attacking_to_attack_move_resume_after_target_dies() -> void:
	# Sequence:
	#   1. AttackMove is dispatched with target = (50, 0, 0).
	#   2. _sim_tick discovers an enemy in range, transitions to Attacking.
	#      (BEFORE that transition, AttackMove enqueues a follow-up AttackMove
	#      command with the same target, so the queue's next entry is the
	#      resume-move.)
	#   3. Enemy dies (queue_free) — Attacking transitions_to_next.
	#   4. transition_to_next pops the queued AttackMove → re-enters
	#      AttackMove with the original (50, 0, 0) target.
	_attacker = _spawn_unit_with_stub_combat(Constants.TEAM_IRAN)
	_attacker.global_position = Vector3.ZERO
	_enemy = _spawn_unit_with_stub_combat(Constants.TEAM_TURAN)
	_enemy.global_position = Vector3(1.0, 0.0, 0.0)

	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(50.0, 0.0, 0.0)}
	)
	_tick_attacker()  # dispatch → AttackMove.enter
	_rebuild_spatial_index()
	_tick_attacker()  # AttackMove._sim_tick → enqueue resume + transition Attacking
	assert_eq(_attacker.fsm.current.id, &"attacking",
		"transitioned to Attacking on enemy detection")
	# The queue should now hold one resume-AttackMove command.
	assert_eq(_attacker.command_queue.size(), 1,
		"AttackMove enqueued a resume command before handing off to Attacking")

	# Kill the enemy — Attacking will detect on next tick and transition_to_next.
	_enemy.queue_free()
	await get_tree().process_frame
	_enemy = null  # avoid double-free in after_each

	_tick_attacker()  # Attacking._sim_tick observes invalid target → next
	# transition_to_next pops the queued AttackMove and re-enters it with the
	# original target.
	assert_eq(_attacker.fsm.current.id, &"attack_move",
		"after target died, Attacking transition_to_next re-enters AttackMove "
		+ "with the original move target (resume after kill)")


# ---------------------------------------------------------------------------
# exit(): cancels in-flight repath
# ---------------------------------------------------------------------------

func test_exit_cancels_in_flight_repath() -> void:
	# Same defensive cleanup as UnitState_Moving — out-of-range AttackMove
	# left a PENDING request on the scheduler; exit must cancel it.
	_attacker = _spawn_unit_with_stub_combat(Constants.TEAM_IRAN)
	_attacker.global_position = Vector3.ZERO
	_attacker.replace_command(
		&"attack_move", {&"target": Vector3(50.0, 0.0, 0.0)}
	)
	_tick_attacker()  # enter() — request_repath issued
	var first_id: int = int(_attacker.get_movement()._request_id)
	assert_true(first_id > 0,
		"AttackMove.enter should have issued a repath request (got id=%d)" % first_id)

	# Force a transition out via direct fsm.transition_to(&"idle"). AttackMove.exit
	# should cancel the request.
	_attacker.fsm.transition_to(&"idle")
	_tick_attacker()
	var poll: Dictionary = _mock.poll_path(first_id)
	assert_eq(poll.state, IPathSchedulerScript.PathState.CANCELLED,
		"AttackMove.exit must cancel the in-flight repath")


# ---------------------------------------------------------------------------
# Registration: Unit base class registers AttackMove alongside other states
# ---------------------------------------------------------------------------

func test_unit_base_registers_attack_move() -> void:
	_attacker = _spawn_unit_with_stub_combat()
	assert_true(_attacker.fsm._states.has(&"attack_move"),
		"Unit base class registers AttackMove (mirroring Idle/Moving/Attacking)")
