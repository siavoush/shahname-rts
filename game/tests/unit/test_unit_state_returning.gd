# Tests for UnitState_Returning — the Kargar worker's deposit-and-loop state.
#
# Per docs/STATE_MACHINE_CONTRACT.md §3 + docs/RESOURCE_NODE_CONTRACT.md §5
# (IDropoffTarget protocol) + Phase 3 wave 1A kickoff §3.
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateReturningScript: Script = preload(
	"res://scripts/units/states/unit_state_returning.gd")
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd")
const IPathSchedulerScript: Script = preload(
	"res://scripts/core/path_scheduler.gd")


var _unit: Variant
var _mine: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _unit != null and is_instance_valid(_unit):
		_unit.queue_free()
	_unit = null
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	_mine = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()


func _spawn_unit() -> void:
	_unit = UnitScene.instantiate()
	_unit.team = Constants.TEAM_IRAN
	add_child_autofree(_unit)
	_unit.get_movement()._scheduler = _mock
	_unit.global_position = Vector3.ZERO
	_unit.get_movement().move_speed = 100.0


func _spawn_mine() -> void:
	_mine = MineNodeScene.instantiate()
	add_child_autofree(_mine)
	_mine.global_position = Vector3(5.0, 0.0, 0.0)


func _tick_fsm() -> void:
	SimClock._is_ticking = true
	_unit.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


# Force the unit into Returning with a payload mirroring what Gathering
# would write at complete_extract time.
func _enter_returning(target_node: Variant, deposit_target: Vector3) -> void:
	_unit._carry_kind = Constants.KIND_COIN
	_unit._carry_amount_x100 = 1000
	_unit.current_command = {
		"kind": &"return",
		"payload": {
			&"target_node": target_node,
			&"deposit_target": deposit_target,
			&"carry_kind": Constants.KIND_COIN,
			&"carry_amount_x100": 1000,
		},
	}
	_unit.fsm.transition_to(&"returning")
	_tick_fsm()


# ---------------------------------------------------------------------------
# Shape — id, priority, interrupt_level.
# ---------------------------------------------------------------------------

func test_returning_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateReturningScript.new()
	assert_eq(s.id, &"returning",
		"Returning.id is &\"returning\"")
	assert_eq(s.priority, 5,
		"Returning.priority is 5 (peer with Gathering)")
	assert_eq(s.interrupt_level, 1,
		"Returning.interrupt_level is COMBAT (1) — damage interrupts the carry")


# ---------------------------------------------------------------------------
# enter — start walking back, payload parsing.
# ---------------------------------------------------------------------------

func test_enter_requests_repath_toward_deposit_target() -> void:
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	assert_eq(_unit.fsm.current.id, &"returning")
	# request_repath called with deposit_target.
	assert_eq(_mock.call_log.size(), 1,
		"Returning.enter calls request_repath once")
	assert_eq(_mock.call_log[0].to, Vector3(10.0, 0.0, 10.0),
		"request_repath target matches payload.deposit_target")


func test_enter_without_payload_falls_back_to_self_position() -> void:
	# Wave 1A fallback: no payload.deposit_target → deposit at own position.
	# Defensive — the state still requests a path (zero-distance), arrives
	# next tick, and runs the deposit.
	_spawn_unit()
	_unit.global_position = Vector3(7.0, 0.0, 3.0)
	_unit.current_command = {"kind": &"return", "payload": {}}
	_unit.fsm.transition_to(&"returning")
	_tick_fsm()
	# Path request to own position.
	assert_eq(_mock.call_log.size(), 1)
	assert_eq(_mock.call_log[0].to, Vector3(7.0, 0.0, 3.0),
		"fallback deposit target is the unit's own position")


# ---------------------------------------------------------------------------
# Deposit step — clears carry, loops to Gathering with the same target_node.
# ---------------------------------------------------------------------------

func test_arrival_clears_carry_and_loops_to_gathering() -> void:
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	# Drive ticks until we transition out of Returning.
	SimClock._test_run_tick()
	var transitioned: bool = false
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			transitioned = true
			break
	assert_true(transitioned, "Returning transitions out after arrival")
	# Loop back to Gathering with the SAME target_node.
	assert_eq(_unit.fsm.current.id, &"gathering",
		"loops to Gathering with the original mine target_node")
	# Carry is zeroed.
	assert_eq(_unit._carry_kind, &"",
		"_carry_kind cleared at deposit")
	assert_eq(_unit._carry_amount_x100, 0,
		"_carry_amount_x100 zeroed at deposit")


# ---------------------------------------------------------------------------
# Phase 3 wave 1B — deposit routes through ResourceSystem.
# ---------------------------------------------------------------------------

func test_deposit_credits_team_coin_via_resource_system() -> void:
	# Phase 3 wave 1B: when Returning arrives and the carry is non-empty,
	# _perform_deposit calls ResourceSystem.change_resource for the team's
	# coin pool. This is the replacement for the wave 1A stub which only
	# zeroed the carry.
	ResourceSystem.reset()
	var pre_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	# Drive ticks until we transition out of Returning (deposit fires on
	# arrival). The Gathering->Returning carry write is in _enter_returning's
	# fixture; carry = (KIND_COIN, 1000 x100) = 10 Coin.
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var post_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(post_x100 - pre_x100, 1000,
		"deposit credits team coin by 1000 x100 (10 Coin) via ResourceSystem")
	ResourceSystem.reset()


func test_deposit_credits_correct_team() -> void:
	# Turan worker's deposit must credit Turan, not Iran. Per-team isolation
	# verified end-to-end at the chokepoint.
	ResourceSystem.reset()
	var iran_pre: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var turan_pre: int = ResourceSystem.coin_x100_for(Constants.TEAM_TURAN)
	_spawn_unit()
	_unit.team = Constants.TEAM_TURAN  # override default Iran
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var iran_post: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var turan_post: int = ResourceSystem.coin_x100_for(Constants.TEAM_TURAN)
	assert_eq(iran_post, iran_pre,
		"Iran balance unchanged when a Turan worker deposits")
	assert_eq(turan_post - turan_pre, 1000,
		"Turan balance credited by deposit amount")
	ResourceSystem.reset()


func test_empty_carry_does_not_credit() -> void:
	# Defensive case: if Returning enters with no carry (zero amount or
	# empty kind), _perform_deposit must NOT call change_resource. Avoids
	# a spurious resource_changed signal with delta=0 polluting the HUD log.
	ResourceSystem.reset()
	var pre: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_spawn_unit()
	_spawn_mine()
	_unit._carry_kind = &""  # empty carry
	_unit._carry_amount_x100 = 0
	_unit.current_command = {
		"kind": &"return",
		"payload": {
			&"target_node": _mine,
			&"deposit_target": Vector3(10.0, 0.0, 10.0),
		},
	}
	_unit.fsm.transition_to(&"returning")
	_tick_fsm()
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var post: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(post, pre,
		"Empty-carry deposit is a no-op on ResourceSystem (no spurious signal)")
	ResourceSystem.reset()


func test_arrival_with_depleted_mine_transitions_to_idle() -> void:
	# If the mine depletes (becomes !is_gatherable) while we're walking
	# back, the loop fails — we transition to Idle instead of looping.
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	# Deplete the mine while in flight.
	_mine.is_gatherable = false
	SimClock._test_run_tick()
	var landed_idle: bool = false
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id == &"idle":
			landed_idle = true
			break
	assert_true(landed_idle,
		"Returning transitions to Idle when the loop target is depleted")


func test_arrival_with_freed_mine_transitions_to_idle() -> void:
	# Mine queue_free()'d while we were walking back — defensive bail to Idle.
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	_mine.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SimClock._test_run_tick()
	var landed_idle: bool = false
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id == &"idle":
			landed_idle = true
			break
	assert_true(landed_idle,
		"Returning transitions to Idle when the loop target was freed")
	_mine = null


# ---------------------------------------------------------------------------
# exit — repath cancel.
# ---------------------------------------------------------------------------

func test_exit_cancels_in_flight_repath() -> void:
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	var first_id: int = int(_unit.get_movement()._request_id)
	assert_true(first_id > 0)
	# Force-transition to Idle — exit() should cancel.
	_unit.fsm.transition_to(&"idle")
	_tick_fsm()
	var poll: Dictionary = _mock.poll_path(first_id)
	assert_eq(poll.state, IPathSchedulerScript.PathState.CANCELLED,
		"Returning.exit cancels the in-flight repath")


# ---------------------------------------------------------------------------
# Integration smoke — gather → return → gather loop continuity.
# ---------------------------------------------------------------------------

func test_gather_return_gather_loop_continues() -> void:
	# Full mini-loop: Gathering ships → arrives at mine → extracts → enters
	# Returning → arrives at deposit point → deposits → loops back to
	# Gathering for another trip. Verified end-to-end via fsm.current.id
	# transitions.
	_spawn_unit()
	_spawn_mine()
	_mine.extract_ticks = 2  # short dwell
	_unit.replace_command(&"gather", {&"target_node": _mine})
	_tick_fsm()  # drain into Gathering
	assert_eq(_unit.fsm.current.id, &"gathering")
	# Drive enough ticks to: walk to mine, request, dwell, complete →
	# Returning, walk back, deposit → loop to Gathering for trip 2.
	# Track when we see the second &"gathering" entry.
	var seen_returning: bool = false
	var seen_second_gathering: bool = false
	SimClock._test_run_tick()
	for i in range(200):
		_tick_fsm()
		var sid: StringName = _unit.fsm.current.id
		if sid == &"returning":
			seen_returning = true
		if sid == &"gathering" and seen_returning:
			seen_second_gathering = true
			break
		# Advance clock between ticks so movement requests resolve.
		if i % 2 == 0:
			SimClock._test_run_tick()
	assert_true(seen_returning,
		"loop reached Returning at least once")
	assert_true(seen_second_gathering,
		"loop re-entered Gathering after Returning (gather-deposit-gather cycle)")


# ===========================================================================
# Wave-3-Throne — canonical IDropoffTarget routing (RNC §5.2)
# ===========================================================================
#
# Mirror C1.4: when a Throne exists for the worker's team, _perform_deposit
# routes through `throne.deposit(...)` and the inline `change_resource`
# call is SKIPPED. When no Throne exists (test fixtures, pre-spawn),
# inline change_resource still fires.
#
# Net effect on coin balance is IDENTICAL in both paths (Throne.deposit
# calls change_resource internally) — what matters is that ONLY ONE path
# fires per deposit cycle (no double-credit).

const _ThroneScene_T: PackedScene = preload(
	"res://scenes/world/buildings/throne.tscn")


func _spawn_throne_for_team(team: int) -> Variant:
	var t: Variant = _ThroneScene_T.instantiate()
	t.set(&"team", team)
	add_child_autofree(t)
	return t


func test_deposit_with_throne_present_routes_through_throne() -> void:
	# Throne-present path: worker deposits → Throne.deposit fires →
	# change_resource fires INTERNALLY in Throne (not by Returning).
	# Observable: coin increases by exactly 1000 x100 (not 2000 — only
	# one path fires per cycle, mirror C1.4).
	ResourceSystem.reset()
	_spawn_throne_for_team(Constants.TEAM_IRAN)
	var pre_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var post_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	# Critical: 1000 x100, not 2000. If double-credit (both paths fire),
	# this would be 2000. The C1.4 only-one-path enforcement is observable
	# here via the exact delta.
	assert_eq(post_x100 - pre_x100, 1000,
		"Throne-present path: coin credited by EXACTLY 1000 x100 once "
		+ "(via Throne.deposit's internal change_resource call). "
		+ "If this is 2000, both paths fired — C1.4 only-one-path violated.")
	ResourceSystem.reset()


func test_deposit_without_throne_falls_back_to_inline_change_resource() -> void:
	# Throne-absent path (no Throne in scene tree): inline change_resource
	# fires. This is the existing wave-1B behavior; the Throne addition
	# must NOT break it.
	ResourceSystem.reset()
	# No Throne spawned in this test.
	var pre_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_spawn_unit()
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var post_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(post_x100 - pre_x100, 1000,
		"Throne-absent fallback: coin credited by 1000 x100 via inline "
		+ "change_resource (wave-1B path preserved)")
	ResourceSystem.reset()


func test_deposit_throne_routing_per_team() -> void:
	# A Turan Throne must NOT receive an Iran worker's deposit, and
	# vice versa. dropoff_for_team filters by team; if filtering breaks,
	# this test catches cross-team credit.
	ResourceSystem.reset()
	_spawn_throne_for_team(Constants.TEAM_TURAN)  # ONLY Turan Throne
	var iran_pre: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var turan_pre: int = ResourceSystem.coin_x100_for(Constants.TEAM_TURAN)
	_spawn_unit()  # Iran worker by default
	_spawn_mine()
	_enter_returning(_mine, Vector3(10.0, 0.0, 10.0))
	SimClock._test_run_tick()
	for i in range(60):
		_tick_fsm()
		if _unit.fsm.current.id != &"returning":
			break
	var iran_post: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var turan_post: int = ResourceSystem.coin_x100_for(Constants.TEAM_TURAN)
	# Iran worker without an Iran Throne falls back to inline path,
	# credits Iran. Turan Throne is unrelated to this deposit.
	assert_eq(iran_post - iran_pre, 1000,
		"Iran worker with NO Iran Throne credits Iran via inline fallback")
	assert_eq(turan_post, turan_pre,
		"Turan balance must NOT change when Iran worker deposits "
		+ "(cross-team routing isolation)")
	ResourceSystem.reset()
