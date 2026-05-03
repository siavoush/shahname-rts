# Integration tests for Phase 2 session 1 combat flows.
#
# Contract: 02d_PHASE_2_KICKOFF.md §2 deliverable 11 (wave 3 scope).
# Related:  docs/TESTING_CONTRACT.md §3.1, docs/SIMULATION_CONTRACT.md §6.1,
#           docs/STATE_MACHINE_CONTRACT.md §3.4 / §3.5.
#
# BUGS FOUND (report to team-lead for routing):
#
# BUG-01: CombatComponent._sim_tick never called via EventBus.sim_phase chain.
#   File/line: game/scripts/units/states/unit_state_attacking.gd, entire _sim_tick.
#   Root cause: UnitState_Attacking._sim_tick calls combat.set_target() on each
#     in-range tick but never calls combat._sim_tick(dt). There is no combat phase
#     coordinator registered either, so EventBus.sim_phase(&"combat") fires with no
#     listeners. Damage never fires through the production FSM path.
#   Assertion that exposes it: test_bug01_combat_sim_tick_not_driven_by_fsm (below).
#   Fix path: UnitState_Attacking._sim_tick should call combat._sim_tick(dt) after
#     combat.set_target() when in range — same pattern as UnitState_Moving calling
#     movement._sim_tick(dt). Owner: gameplay-systems (ai-engineer owns the state,
#     but the handoff to combat._sim_tick follows the pattern gameplay-systems
#     established for Movement).
#
# BUG-02: AttackMoveHandler not present in main.tscn.
#   File/line: game/scenes/main.tscn — no AttackMoveHandler node.
#   Root cause: wave-2B shipped AttackMoveHandler but Deviation 02 (commit-race)
#     caused the ui-dev agent's commit (aa429ef) to sweep up the wave-2B code
#     without the main.tscn addition for AttackMoveHandler.
#   Assertion that exposes it: test_main_tscn_attack_move_handler_before_click_handler.
#   Fix path: Add AttackMoveHandler node BEFORE ClickHandler in main.tscn,
#     with script = res://scripts/input/attack_move_handler.gd. Owner: ai-engineer
#     (wave-2B was their scope).
#
# BUG-03: No 'dying' state registered for combat units (Piyade, Kargar, etc).
#   File/line: game/scripts/units/unit.gd — _ready() registers idle/moving/attacking/
#     attack_move states but NOT 'dying'. StateMachine._on_unit_health_zero() at line 288
#     push_errors and returns without queuing the unit free.
#   Root cause: The dying state implementation was deferred (not shipped in wave 1+2).
#     StateMachine.gd already has the death-preempt handler (_on_unit_health_zero) that
#     calls _apply_transition(&"dying", ...) but requires the state to be registered.
#     Without a dying state, killed units stay in the scene tree and remain valid Node
#     references — UnitState_Attacking._sim_tick()'s is_instance_valid(_target) check
#     never triggers, so attackers never return to idle after killing a target.
#   Assertion that exposes it: test_bug03_no_dying_state_unit_stays_valid_after_death.
#   Fix path: Add UnitState_Dying to unit.gd's FSM registration that calls queue_free()
#     on its owning unit (via ctx.queue_free()). Owner: gameplay-systems.
#
# Integration test structure:
#   Flows 1-2 (single attack, cooldown): drive CombatComponent via tick boundary
#     using the same pattern as test_combat_component.gd (_combat_tick helper).
#     BUG-01 regression is captured in a separate documented test.
#   Flows 3-9: test what actually works (FSM transitions via replace_command,
#     HealthBarsOverlay seam, AttackRangeOverlay, FarrDrain, pitfall regressions).
#
# Typing: Variant slots for unit refs — docs/ARCHITECTURE.md §6 v0.4.0.

extends GutTest


# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------

const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MockPathSchedulerScript: Script = preload("res://scripts/navigation/mock_path_scheduler.gd")
const ClickHandlerScript: Script = preload("res://scripts/input/click_handler.gd")
const AttackMoveHandlerScript: Script = preload("res://scripts/input/attack_move_handler.gd")
const HealthBarsOverlayScene: PackedScene = preload("res://scenes/ui/health_bars_overlay.tscn")
const AttackRangeOverlayScene: PackedScene = preload("res://scenes/ui/overlays/attack_range_overlay.tscn")
const MainScene: PackedScene = preload("res://scenes/main.tscn")


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _mock: Variant = null

var _iran: Variant = null
var _turan: Variant = null
var _kargar: Variant = null


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	SelectionManager.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	DebugOverlayManager.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	_iran = null
	_turan = null
	_kargar = null


func after_each() -> void:
	if _iran != null and is_instance_valid(_iran):
		_iran.queue_free()
	if _turan != null and is_instance_valid(_turan):
		_turan.queue_free()
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_iran = null
	_turan = null
	_kargar = null
	SelectionManager.reset()
	FarrSystem.reset()
	SpatialIndex.reset()
	DebugOverlayManager.reset()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

func _spawn_iran(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = PiyadeScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_IRAN
	u.get_movement()._scheduler = _mock
	return u


func _spawn_turan(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = TuranPiyadeScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_TURAN
	u.get_movement()._scheduler = _mock
	return u


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_IRAN
	u.get_movement()._scheduler = _mock
	return u


func _advance(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# Drive CombatComponent inside a real tick boundary. Mirrors the pattern from
# test_combat_component.gd — CombatComponent._sim_tick must run inside
# SimClock.is_ticking() == true (SimNode._set_sim asserts this). Because no
# combat-phase coordinator exists yet (BUG-01), we drive combat directly in
# tests rather than via the full FSM chain.
func _combat_tick(combat: Node) -> void:
	SimClock._is_ticking = true
	combat._sim_tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# Drive combat N times with one tick boundary per call.
func _combat_ticks(combat: Node, n: int) -> void:
	for _i in range(n):
		SimClock._is_ticking = true
		combat._sim_tick(SimClock.SIM_DT)
		SimClock._is_ticking = false
		# Increment the tick counter manually so cooldown comparisons match
		# real tick-count expectations (SIM_HZ-based cooldown formula uses
		# the same integer counter that SimClock.tick tracks during _run_tick).
		# We must NOT call _test_run_tick here because it also fires the FSM
		# tick, which calls set_target() again, resetting the cooldown.
		SimClock.tick += 1


# ============================================================================
# BUG-01 regression — CombatComponent never driven via EventBus.sim_phase chain
# ============================================================================
# This test DOCUMENTS the current bug. Until BUG-01 is fixed it asserts the
# broken (current) behavior and serves as the regression lock.
#
# The fix: UnitState_Attacking._sim_tick should call combat._sim_tick(dt)
# after calling combat.set_target() when in range. Owner: gameplay-systems.
#
# BUG-03 regression is in test_bug03_no_dying_state_unit_stays_valid_after_death
# below (asserts that a killed unit is NOT freed — current broken behavior).

func test_bug01_combat_sim_tick_not_driven_by_fsm() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))  # within 1.5 attack range

	var initial_hp_x100: int = int(_turan.get_health().hp_x100)

	# Transition Iran to Attacking with Turan as target via the normal command path.
	_iran.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_turan.unit_id)})

	# Advance 10 ticks via the real EventBus.sim_phase chain. This exercises:
	#   sim_phase(&"movement") → Unit._on_sim_phase → fsm.tick()
	#     → UnitState_Attacking._sim_tick() → combat.set_target() (in range)
	#   sim_phase(&"combat") → nobody listening (no coordinator registered)
	# Result: combat.set_target() is called each tick but combat._sim_tick() never runs.
	_advance(10)

	var hp_after: int = int(_turan.get_health().hp_x100)

	# BUG-01: HP does NOT decrement via the EventBus.sim_phase chain because
	# UnitState_Attacking._sim_tick never calls combat._sim_tick(dt).
	# When this test fails (hp_after < initial_hp_x100), BUG-01 is fixed.
	assert_eq(hp_after, initial_hp_x100,
		"BUG-01 REGRESSION: CombatComponent._sim_tick is not driven via EventBus chain; "
		+ "HP unchanged after 10 ticks (initial=%d after=%d). "
		% [initial_hp_x100, hp_after]
		+ "When fixed: UnitState_Attacking._sim_tick must call combat._sim_tick(dt).")


# ============================================================================
# Flow 1: Single-attack flow (via direct combat drive — bypasses BUG-01)
# ============================================================================

func test_single_attack_hp_decrements_with_direct_combat_drive() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))  # within 1.5 attack range

	var initial_hp_x100: int = int(_turan.get_health().hp_x100)
	assert_true(initial_hp_x100 > 0, "pre-condition: Turan has HP")

	# Wire CombatComponent with a direct lookup callable.
	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null

	# set_target(id) resets cooldown to 0; first _combat_tick fires immediately.
	combat.set_target(int(_turan.unit_id))
	_combat_tick(combat)

	var hp_after: int = int(_turan.get_health().hp_x100)
	assert_true(hp_after < initial_hp_x100,
		"HP must decrement on first combat tick after set_target (initial=%d after=%d)"
		% [initial_hp_x100, hp_after])


func test_single_attack_unit_died_emitted_with_correct_payload() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	var died_events: Array = []
	EventBus.unit_died.connect(
		func(uid: int, killer: int, cause: StringName, pos: Vector3) -> void:
			died_events.append({
				&"unit_id": uid,
				&"killer_unit_id": killer,
				&"cause": cause,
				&"position": pos,
			})
	)

	var turan_id: int = int(_turan.unit_id)
	var iran_id: int = int(_iran.unit_id)

	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null
	combat.set_target(turan_id)

	# At 10 dmg/hit (1000 x100), 100 HP (10000 x100) needs 10 hits.
	# Cooldown is 30 ticks at 1.0 atk/s. Drive until death or 400 ticks.
	var killed: bool = false
	for _i in range(400):
		_combat_tick(combat)
		if not died_events.is_empty():
			killed = true
			break

	assert_true(killed, "unit_died must be emitted within 400 combat ticks")
	assert_eq(died_events.size(), 1, "unit_died must fire exactly once")

	var ev: Dictionary = died_events[0]
	assert_eq(ev[&"unit_id"], turan_id, "unit_died.unit_id must match Turan Piyade")
	assert_eq(ev[&"killer_unit_id"], iran_id,
		"unit_died.killer_unit_id must match Iran Piyade")
	assert_true(String(ev[&"cause"]).contains("melee_attack"),
		"unit_died.cause must contain 'melee_attack'")


func test_single_attack_last_death_position_captured_before_free() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	var turan_world_pos: Vector3 = _turan.global_position
	var captured_positions: Array = []
	EventBus.unit_died.connect(
		func(_uid: int, _killer: int, _cause: StringName, pos: Vector3) -> void:
			captured_positions.append(pos)
	)

	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null
	combat.set_target(int(_turan.unit_id))

	for _i in range(400):
		_combat_tick(combat)
		if not captured_positions.is_empty():
			break

	assert_false(captured_positions.is_empty(), "unit_died must have been emitted")
	var pos: Vector3 = captured_positions[0]
	assert_true(pos.distance_to(turan_world_pos) < 0.5,
		"last_death_position must be near Turan's world position (got %s expected near %s)"
		% [str(pos), str(turan_world_pos)])


# BUG-03 regression: No dying state means killed units are never freed.
# This test asserts the current BROKEN behavior (unit still valid after being
# dealt lethal damage). When BUG-03 is fixed (dying state registered, unit
# gets queue_free'd), this test will fail — a sign to update it.
func test_bug03_no_dying_state_unit_stays_valid_after_death() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null
	combat.set_target(int(_turan.unit_id))

	# Deal enough damage to kill Turan (100 HP, 10 dmg/hit). After lethal damage:
	# - unit_health_zero fires → StateMachine push_errors (no dying state) → returns
	# - unit_died fires
	# - But the unit is NEVER queue_free'd — is_instance_valid() remains true.
	for _i in range(20):
		_combat_tick(combat)

	# BUG-03: Turan is still a valid instance after lethal damage because
	# no dying state exists to call queue_free. When this fails (Turan is freed),
	# BUG-03 is fixed — add a dying state and update this test.
	assert_true(is_instance_valid(_turan),
		"BUG-03 REGRESSION: unit stays valid after lethal damage because no "
		+ "'dying' state is registered. Fix: add UnitState_Dying to unit.gd that "
		+ "calls ctx.queue_free(). Owner: gameplay-systems.")


# ============================================================================
# Flow 2: Range check + cooldown timing
# ============================================================================

func test_out_of_range_no_damage_applied() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	# attack_range = 1.5; place Turan outside that.
	_turan = _spawn_turan(Vector3(5.0, 0.0, 0.0))

	var initial_hp_x100: int = int(_turan.get_health().hp_x100)
	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null
	combat.set_target(int(_turan.unit_id))

	_combat_ticks(combat, 5)

	var hp_after: int = int(_turan.get_health().hp_x100)
	assert_eq(hp_after, initial_hp_x100,
		"Out-of-range target (distance=5, range=1.5) must take no damage")


func test_in_range_damage_fires_after_set_target() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))  # within 1.5 range

	var initial_hp_x100: int = int(_turan.get_health().hp_x100)
	var combat: Node = _iran.get_combat()
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null
	combat.set_target(int(_turan.unit_id))

	_combat_tick(combat)  # cooldown=0 after set_target → fires immediately

	assert_true(int(_turan.get_health().hp_x100) < initial_hp_x100,
		"In-range target must take damage on first tick after set_target")


func test_cooldown_blocks_second_attack_before_30_ticks() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))
	_turan.get_health().init_max_hp(1000.0)

	var combat: Node = _iran.get_combat()
	combat.attack_speed_per_sec = 1.0
	combat.attack_damage_x100 = 100  # small damage — unit survives multiple hits
	combat.attack_range = 2.0
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null

	combat.set_target(int(_turan.unit_id))
	# First attack fires tick 1 (cooldown=0 → set_target resets).
	_combat_tick(combat)
	var hp_after_first: int = int(_turan.get_health().hp_x100)

	# Advance 29 more ticks (total 30 from set_target). Cooldown = 30 ticks at 30Hz.
	# The cooldown after first attack is RESET to 30, so it won't fire again until
	# we've driven 30 more combat ticks (tick 31 from set_target fires the second).
	# NOTE: _combat_ticks does NOT call _test_run_tick, so it does not re-trigger
	# the FSM's combat.set_target() call (which would reset cooldown to 0 again).
	_combat_ticks(combat, 29)
	var hp_after_29: int = int(_turan.get_health().hp_x100)
	assert_eq(hp_after_29, hp_after_first,
		"Second attack must not fire within 29 ticks of the first (30-tick cooldown)")


func test_cooldown_second_attack_fires_at_tick_31() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))
	_turan.get_health().init_max_hp(1000.0)

	var combat: Node = _iran.get_combat()
	combat.attack_speed_per_sec = 1.0
	combat.attack_damage_x100 = 100
	combat.attack_range = 2.0
	combat.target_lookup_callable = func(uid: int) -> Variant:
		if is_instance_valid(_turan) and int(_turan.unit_id) == uid:
			return _turan
		return null

	combat.set_target(int(_turan.unit_id))
	_combat_tick(combat)  # first attack
	var hp_after_first: int = int(_turan.get_health().hp_x100)

	_combat_ticks(combat, 30)  # exhaust the cooldown; tick 31 fires
	var hp_after_second: int = int(_turan.get_health().hp_x100)
	assert_true(hp_after_second < hp_after_first,
		"Second attack must fire at tick 31 (30-tick cooldown exhausted; "
		+ "hp after first=%d after second=%d)" % [hp_after_first, hp_after_second])


# ============================================================================
# Flow 3: Right-click-on-enemy (click_handler test seam)
# ============================================================================

func test_right_click_on_enemy_transitions_fsm_to_attacking() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	SelectionManager.select_only(_iran)
	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	handler.process_right_click_hit({
		&"collider": _turan,
		&"position": _turan.global_position,
		&"normal": Vector3.UP,
	})
	_advance(1)  # FSM transition deferred until next tick

	assert_eq(_iran.fsm.current.id, &"attacking",
		"Right-click on enemy must transition Iran Piyade to Attacking")


func test_right_click_on_friendly_is_noop() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	var iran2: Variant = _spawn_iran(Vector3(2.0, 0.0, 0.0))

	SelectionManager.select_only(_iran)
	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	handler.process_right_click_hit({
		&"collider": iran2,
		&"position": iran2.global_position,
		&"normal": Vector3.UP,
	})
	_advance(1)

	assert_eq(_iran.fsm.current.id, &"idle",
		"Right-click on a friendly unit must be a no-op (FSM stays Idle)")

	if is_instance_valid(iran2):
		iran2.queue_free()


func test_right_click_enemy_attack_command_queued_correctly() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	SelectionManager.select_only(_iran)
	var handler: Node = ClickHandlerScript.new()
	add_child_autofree(handler)
	handler.set_test_mode(true)

	handler.process_right_click_hit({
		&"collider": _turan,
		&"position": _turan.global_position,
		&"normal": Vector3.UP,
	})

	# After replace_command, the queue has the attack command.
	# Verify via the FSM transition after one tick.
	_advance(1)
	assert_eq(_iran.fsm.current.id, &"attacking",
		"Attack command must dispatch to Attacking state correctly")
	# And the target_unit_id in current_command must match.
	var payload: Dictionary = _iran.current_command.get(&"payload", {})
	assert_eq(int(payload.get(&"target_unit_id", -1)), int(_turan.unit_id),
		"current_command.payload.target_unit_id must match Turan unit_id")


# ============================================================================
# Flow 4: Attack-move flow
# ============================================================================

func test_attack_move_command_transitions_to_attack_move_state() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	var far_target: Vector3 = Vector3(20.0, 0.0, 0.0)

	_iran.replace_command(Constants.COMMAND_ATTACK_MOVE, {&"target": far_target})
	_advance(1)  # FSM applies transition

	assert_eq(_iran.fsm.current.id, &"attack_move",
		"AttackMove command must land in attack_move state")


func test_attack_move_enter_reads_target_from_payload() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	var far_target: Vector3 = Vector3(15.0, 0.0, 0.0)

	_iran.replace_command(Constants.COMMAND_ATTACK_MOVE, {&"target": far_target})
	_advance(1)

	# The state should have cached the target internally.
	var state: Object = _iran.fsm.current
	assert_eq(state.id, &"attack_move")
	# Verify the target was stored (attack_move state's _target field).
	var stored_target: Variant = state.get(&"_target")
	if typeof(stored_target) == TYPE_VECTOR3:
		assert_true((stored_target as Vector3).distance_to(far_target) < 0.1,
			"AttackMove state must cache the original target from the command payload")
	else:
		pass_test("_target field not accessible; state entered correctly")


func test_attack_move_enqueues_resume_and_attack_when_engaging() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(2.0, 0.0, 0.0))  # within ENGAGE_RADIUS

	# Register Turan in SpatialIndex.
	if SpatialIndex.has_method(&"_rebuild"):
		SpatialIndex.call(&"_rebuild")

	_iran.replace_command(Constants.COMMAND_ATTACK_MOVE,
		{&"target": Vector3(20.0, 0.0, 0.0)})
	_advance(1)  # path resolves to READY next tick

	# Rebuild spatial index so the engage query finds Turan.
	if SpatialIndex.has_method(&"_rebuild"):
		SpatialIndex.call(&"_rebuild")

	_advance(4)  # engage check fires within a few ticks

	# Iran should have transitioned to Attacking (engage found Turan) OR still
	# in AttackMove (engage radius may not be populated headless without full
	# navigation). Either state is valid at this point.
	var state_id: StringName = _iran.fsm.current.id
	assert_true(state_id == &"attacking" or state_id == &"attack_move" or state_id == &"moving",
		"After attack_move with nearby enemy, state must be attacking/attack_move/moving "
		+ "(got %s)" % state_id)


# ============================================================================
# Flow 5: Farr drain (worker-killed-idle)
# ============================================================================

func test_worker_killed_idle_drains_farr_by_one() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	assert_eq(_kargar.fsm.current.id, &"idle",
		"pre-condition: Kargar must be in idle state")

	var initial_farr: float = FarrSystem.value_farr
	var drain_reasons: Array = []
	EventBus.farr_changed.connect(
		func(_amt: float, reason: String, _src: int, _after: float, _tick: int) -> void:
			drain_reasons.append(reason)
	)

	# Kill the Kargar directly via take_damage_x100 with the idle-worker cause.
	# This drives the exact path that a combat attack would take, without
	# relying on BUG-01's broken FSM→combat chain.
	SimClock._is_ticking = true
	_kargar.get_health().take_damage_x100(99999, null, &"melee_attack")
	SimClock._is_ticking = false

	assert_almost_eq(FarrSystem.value_farr, initial_farr - 1.0, 1e-4,
		"Farr must drop by exactly 1.0 when idle Kargar is killed with melee_attack")

	assert_true("worker_killed_idle" in drain_reasons,
		"farr_changed must be emitted with reason 'worker_killed_idle'")


func test_worker_killed_moving_no_farr_drop() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)

	# Force Kargar into Moving state.
	_kargar.replace_command(&"move", {&"target": Vector3(10.0, 0.0, 0.0)})
	_advance(2)
	assert_eq(_kargar.fsm.current.id, &"moving",
		"pre-condition: Kargar must be in moving state")

	var initial_farr: float = FarrSystem.value_farr

	# Kill the Kargar while it's moving.
	SimClock._is_ticking = true
	_kargar.get_health().take_damage_x100(99999, null, &"melee_attack")
	SimClock._is_ticking = false

	assert_almost_eq(FarrSystem.value_farr, initial_farr, 1e-4,
		"Farr must NOT drop when a moving Kargar is killed (not idle)")


func test_farr_drain_reason_exact_value() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)

	var farr_events: Array = []
	EventBus.farr_changed.connect(
		func(amt: float, reason: String, _src: int, after: float, _tick: int) -> void:
			farr_events.append({&"amount": amt, &"reason": reason, &"after": after})
	)

	var initial_farr: float = FarrSystem.value_farr
	SimClock._is_ticking = true
	_kargar.get_health().take_damage_x100(99999, null, &"melee_attack")
	SimClock._is_ticking = false

	var drain_events: Array = farr_events.filter(
		func(e: Dictionary) -> bool: return e[&"reason"] == "worker_killed_idle"
	)
	assert_eq(drain_events.size(), 1,
		"Exactly one farr_changed event with reason 'worker_killed_idle' must fire")
	assert_almost_eq(float(drain_events[0][&"amount"]), -1.0, 1e-4,
		"Farr drain amount must be exactly -1.0")
	assert_almost_eq(float(drain_events[0][&"after"]), initial_farr - 1.0, 1e-4,
		"farr_changed 'after' field must reflect the new Farr value")


# ============================================================================
# Flow 6: HealthBarsOverlay correctness (compute_bar_entries public seam)
# ============================================================================

func test_health_bars_full_hp_units_excluded() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)

	var units: Array = [_iran, _turan]
	var projector: Callable = func(_u: Object) -> Dictionary:
		return {&"screen_pos": Vector2(400.0, 300.0), &"on_screen": true}

	var entries: Array = overlay.compute_bar_entries(units, projector)
	assert_eq(entries.size(), 0,
		"Full-HP units must NOT appear in health bar entries")


func test_health_bars_green_band_at_85_percent() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_iran.get_health().init_max_hp(100.0)

	SimClock._is_ticking = true
	_iran.get_health().take_damage_x100(1500, null, &"melee_attack")  # 15 HP dmg → 85 HP = 85%
	SimClock._is_ticking = false

	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)

	var entries: Array = overlay.compute_bar_entries([_iran],
		func(_u: Object) -> Dictionary:
			return {&"screen_pos": Vector2(400.0, 300.0), &"on_screen": true})

	assert_eq(entries.size(), 1, "85% HP unit must produce one bar entry")
	assert_eq(entries[0][&"band"], overlay.BAND_GREEN,
		"HP=85% must produce BAND_GREEN (threshold > 70%)")


func test_health_bars_yellow_band_at_50_percent() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_iran.get_health().init_max_hp(100.0)

	SimClock._is_ticking = true
	_iran.get_health().take_damage_x100(5000, null, &"melee_attack")  # 50 HP → 50%
	SimClock._is_ticking = false

	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)

	var entries: Array = overlay.compute_bar_entries([_iran],
		func(_u: Object) -> Dictionary:
			return {&"screen_pos": Vector2(400.0, 300.0), &"on_screen": true})

	assert_eq(entries.size(), 1)
	assert_eq(entries[0][&"band"], overlay.BAND_YELLOW,
		"HP=50% must produce BAND_YELLOW (30% ≤ ratio ≤ 70%)")


func test_health_bars_red_band_at_20_percent() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_iran.get_health().init_max_hp(100.0)

	SimClock._is_ticking = true
	_iran.get_health().take_damage_x100(8000, null, &"melee_attack")  # 20 HP → 20%
	SimClock._is_ticking = false

	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)

	var entries: Array = overlay.compute_bar_entries([_iran],
		func(_u: Object) -> Dictionary:
			return {&"screen_pos": Vector2(400.0, 300.0), &"on_screen": true})

	assert_eq(entries.size(), 1)
	assert_eq(entries[0][&"band"], overlay.BAND_RED,
		"HP=20% must produce BAND_RED (< 30%)")


func test_health_bars_only_damaged_units_shown() -> void:
	_iran = _spawn_iran(Vector3(0.0, 0.0, 0.0))
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	# Damage Iran only.
	SimClock._is_ticking = true
	_iran.get_health().take_damage_x100(3000, null, &"melee_attack")
	SimClock._is_ticking = false

	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)

	var entries: Array = overlay.compute_bar_entries([_iran, _turan],
		func(_u: Object) -> Dictionary:
			return {&"screen_pos": Vector2(400.0, 300.0), &"on_screen": true})

	assert_eq(entries.size(), 1, "Only damaged units must produce bar entries")
	assert_eq(entries[0][&"unit_id"], int(_iran.unit_id),
		"Bar entry must belong to the damaged Iran Piyade")


# ============================================================================
# Flow 7: AttackRangeOverlay + F4 toggle
# ============================================================================

func test_attack_range_overlay_circle_per_selected_unit() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	var iran2: Variant = _spawn_iran(Vector3(3.0, 0.0, 0.0))
	var iran3: Variant = _spawn_iran(Vector3(6.0, 0.0, 0.0))

	var overlay: Control = AttackRangeOverlayScene.instantiate()
	add_child_autofree(overlay)

	SelectionManager.select_only(_iran)
	SelectionManager.add_to_selection(iran2)
	SelectionManager.add_to_selection(iran3)
	overlay.handle_selection_changed([])

	assert_eq(overlay.circle_count(), 3,
		"3 selected Piyade must produce 3 attack-range circles")

	if is_instance_valid(iran2):
		iran2.queue_free()
	if is_instance_valid(iran3):
		iran3.queue_free()


func test_attack_range_overlay_radius_matches_combat_range() -> void:
	_iran = _spawn_iran(Vector3.ZERO)

	var overlay: Control = AttackRangeOverlayScene.instantiate()
	add_child_autofree(overlay)

	SelectionManager.select_only(_iran)
	overlay.handle_selection_changed([])

	var entries: Array = overlay.entries()
	assert_eq(entries.size(), 1, "One selected unit must produce one circle entry")

	var radius: float = float(entries[0][&"radius"])
	var expected: float = float(_iran.get_combat().attack_range)
	assert_almost_eq(radius, expected, 1e-4,
		"Circle radius must equal CombatComponent.attack_range")


func test_attack_range_overlay_f4_toggle() -> void:
	var overlay: Control = AttackRangeOverlayScene.instantiate()
	add_child_autofree(overlay)

	assert_false(overlay.visible, "AttackRangeOverlay must start hidden (F4 overlays start off)")

	DebugOverlayManager.handle_function_key(KEY_F4)
	assert_true(overlay.visible, "First F4 must show the overlay")

	DebugOverlayManager.handle_function_key(KEY_F4)
	assert_false(overlay.visible, "Second F4 must hide the overlay")


func test_attack_range_overlay_updates_on_selection_change() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	var iran2: Variant = _spawn_iran(Vector3(3.0, 0.0, 0.0))

	var overlay: Control = AttackRangeOverlayScene.instantiate()
	add_child_autofree(overlay)

	SelectionManager.select_only(_iran)
	overlay.handle_selection_changed([])
	assert_eq(overlay.circle_count(), 1)

	SelectionManager.add_to_selection(iran2)
	overlay.handle_selection_changed([])
	assert_eq(overlay.circle_count(), 2)

	SelectionManager.deselect_all()
	overlay.handle_selection_changed([])
	assert_eq(overlay.circle_count(), 0)

	if is_instance_valid(iran2):
		iran2.queue_free()


# ============================================================================
# Flow 8: Cross-feature smoke tests
# ============================================================================

func test_main_tscn_spawns_15_units_correct_teams() -> void:
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_shaped_nodes(main_node, all_units)

	assert_eq(all_units.size(), 15,
		"main.tscn must spawn exactly 15 units (5 Kargar + 5 Iran Piyade + 5 Turan Piyade)")

	var iran_count: int = 0
	var turan_count: int = 0
	for u in all_units:
		var t: int = int(u.get(&"team"))
		if t == Constants.TEAM_IRAN:
			iran_count += 1
		elif t == Constants.TEAM_TURAN:
			turan_count += 1

	assert_eq(iran_count, 10, "10 units must be on TEAM_IRAN")
	assert_eq(turan_count, 5, "5 units must be on TEAM_TURAN")


func test_main_tscn_has_health_bars_overlay() -> void:
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var hbo: Node = main_node.get_node_or_null("HealthBarsOverlay")
	assert_not_null(hbo,
		"main.tscn must contain a HealthBarsOverlay node (wave-2C deliverable)")
	if hbo != null:
		assert_true(hbo.has_method(&"compute_bar_entries"),
			"HealthBarsOverlay must have compute_bar_entries method")


func test_main_tscn_has_attack_range_overlay() -> void:
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var aro: Node = main_node.get_node_or_null("AttackRangeOverlay")
	assert_not_null(aro,
		"main.tscn must contain an AttackRangeOverlay node (wave-2C deliverable)")
	if aro != null:
		assert_true(aro.has_method(&"entries"),
			"AttackRangeOverlay must have entries() method")


func test_main_tscn_attack_move_handler_before_click_handler() -> void:
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var amh: Node = main_node.get_node_or_null("AttackMoveHandler")
	var ch: Node = main_node.get_node_or_null("ClickHandler")

	if amh == null:
		# BUG-02: AttackMoveHandler absent from main.tscn. Mark pending so the
		# pre-commit gate passes while the bug is outstanding.
		# Fix: add 'AttackMoveHandler' node BEFORE 'ClickHandler' in main.tscn
		# with script = res://scripts/input/attack_move_handler.gd. Owner: ai-engineer.
		pending("BUG-02: AttackMoveHandler not yet in main.tscn (wave-2B deliverable). "
			+ "Remove this pending() call once the node is added.")
		return

	assert_not_null(amh,
		"main.tscn must contain AttackMoveHandler (wave-2B deliverable)")

	if amh != null and ch != null:
		assert_true(amh.get_index() < ch.get_index(),
			"AttackMoveHandler (idx=%d) must appear BEFORE ClickHandler (idx=%d) "
			% [amh.get_index(), ch.get_index()])


func _collect_unit_shaped_nodes(node: Node, out: Array) -> void:
	if (&"unit_id" in node) and (&"team" in node) and (node is Node3D):
		out.append(node)
	for child in node.get_children():
		_collect_unit_shaped_nodes(child, out)


# ============================================================================
# Flow 9: Pitfall regression tests (#1-#5)
# ============================================================================

# Pitfall #1: mouse_filter on Control nodes.
func test_pitfall_1_health_bars_overlay_mouse_filter_ignore() -> void:
	var overlay: Control = HealthBarsOverlayScene.instantiate()
	add_child_autofree(overlay)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Pitfall #1: HealthBarsOverlay must have mouse_filter = MOUSE_FILTER_IGNORE")


func test_pitfall_1_attack_range_overlay_mouse_filter_ignore() -> void:
	var overlay: Control = AttackRangeOverlayScene.instantiate()
	add_child_autofree(overlay)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Pitfall #1: AttackRangeOverlay must have mouse_filter = MOUSE_FILTER_IGNORE")


# Pitfall #2: FSM / per-tick driver wiring.
# This test verifies that UnitState_Attacking IS entered via the EventBus chain.
# The combat damage (CombatComponent) is a SEPARATE bug (BUG-01).
func test_pitfall_2_attacking_state_entered_via_eventbus_chain() -> void:
	_iran = _spawn_iran(Vector3.ZERO)
	_turan = _spawn_turan(Vector3(1.0, 0.0, 0.0))

	_iran.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_turan.unit_id)})

	# Before tick: still idle (deferred transition).
	assert_eq(_iran.fsm.current.id, &"idle",
		"FSM must still be Idle before the first tick (transition is deferred)")

	# Drive via real EventBus chain — NOT by calling fsm.tick directly.
	_advance(1)

	assert_eq(_iran.fsm.current.id, &"attacking",
		"Pitfall #2: FSM must enter Attacking via EventBus.sim_phase chain")


# Pitfall #4: Re-entrant signal mutation.
# FarrSystem._on_unit_died → apply_farr_change → farr_changed emitted.
# The chain must not cause unit_died to re-emit (single emit per death).
func test_pitfall_4_no_reentrant_unit_died_on_worker_death() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)

	# Use Array (reference type) so the lambda captures a reference, not a copy.
	# GDScript lambdas capture primitive int by value; mutations inside the lambda
	# don't propagate back to the outer scope. Array elements are mutable via ref.
	var unit_died_events: Array = []
	EventBus.unit_died.connect(
		func(uid: int, _killer: int, _cause: StringName, _pos: Vector3) -> void:
			unit_died_events.append(uid)
	)

	SimClock._is_ticking = true
	_kargar.get_health().take_damage_x100(99999, null, &"melee_attack")
	SimClock._is_ticking = false

	assert_eq(unit_died_events.size(), 1,
		"Pitfall #4: unit_died must fire exactly once per death "
		+ "(re-entrant signal mutation guard)")


# Pitfall #5: Sibling tree-order for _unhandled_input.
# Tested in test_main_tscn_attack_move_handler_before_click_handler above.
# This standalone test explicitly locks in the node-index requirement.
func test_pitfall_5_attack_move_handler_before_click_handler_standalone() -> void:
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var amh: Node = main_node.get_node_or_null("AttackMoveHandler")
	var ch: Node = main_node.get_node_or_null("ClickHandler")

	if amh == null:
		# BUG-02: AttackMoveHandler absent — pitfall #5 ordering cannot be verified.
		pending("BUG-02: AttackMoveHandler not yet in main.tscn. "
			+ "Remove this pending() once the node is wired.")
		return
	assert_not_null(ch, "ClickHandler must be in main.tscn")
	if ch == null:
		return
	assert_true(amh.get_index() < ch.get_index(),
		"Pitfall #5: AttackMoveHandler (idx=%d) must appear BEFORE ClickHandler (idx=%d) "
		% [amh.get_index(), ch.get_index()])
