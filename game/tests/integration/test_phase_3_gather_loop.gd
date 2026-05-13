# Integration test for the Phase 3 wave 1B gather loop.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 wave 1B Definition of Done.
# Live chain: right-click mine → ClickHandler → Unit.replace_command →
#   StateMachine → UnitState_Gathering → walk → MineNode.request_extract →
#   dwell → complete_extract → carry set → UnitState_Returning → walk back →
#   ResourceSystem.change_resource → EventBus.resource_changed → HUD update.
#
# Plus death-triggered drains: kill an idle Kargar → Farr drops by 1.0;
# kill a gathering Kargar → Farr drops by 0.5 (via FarrDrainDispatcher
# subscribed to unit_health_zero PRE-Dying-swap).
#
# This file is the wave-3 qa coverage for the gather loop. Per Testing
# Contract §3.1 + wave-0 precedent, it uses MatchHarness for autoload
# resets but spawns units/mines directly (harness.spawn_unit returns
# null until Phase 1+ stubs ship).
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var harness: Variant = null
var _kargar: Variant = null
var _mine: Variant = null


func before_each() -> void:
	harness = MatchHarnessScript.new()
	harness.start_match(0, &"empty")
	CommandPool.reset()
	SelectionManager.reset()
	ResourceSystem.reset()
	FarrSystem.reset()
	FarrDrainDispatcher.reset()
	UnitScript.call(&"reset_id_counter")
	_kargar = null
	_mine = null


func after_each() -> void:
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	_kargar = null
	_mine = null
	SelectionManager.reset()
	CommandPool.reset()
	ResourceSystem.reset()
	FarrSystem.reset()
	FarrDrainDispatcher.reset()
	harness.teardown()
	harness = null


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_IRAN
	u.get_movement()._scheduler = harness._mock_scheduler
	# Boost speed so the walk completes within the test's tick budget.
	u.get_movement().move_speed = 100.0
	return u


func _spawn_mine(pos: Vector3 = Vector3(5.0, 0.0, 0.0)) -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	m.extract_ticks = 2  # short dwell so tests stay tight
	return m


# Helper: drive FSM tick AND advance SimClock so movement requests resolve
# through the mock path scheduler.
func _drive_loop_ticks(n: int) -> void:
	for i in range(n):
		# fsm.tick must be inside the simclock tick boundary so on-tick asserts
		# (HealthComponent.take_damage, ResourceSystem.change_resource,
		# FarrSystem.apply_farr_change) all hold when they fire.
		SimClock._is_ticking = true
		_kargar.fsm.tick(SimClock.SIM_DT)
		SimClock._is_ticking = false
		# Advance the harness so path requests get resolved and time moves
		# forward for any tick-counted state.
		harness.advance_ticks(1)


# ---------------------------------------------------------------------------
# Flow 1 — Gather → deposit credits Iran Coin via ResourceSystem.
# ---------------------------------------------------------------------------

func test_full_gather_loop_credits_iran_coin() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	# Initial state: 150 Coin from balance.tres.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, 15000,
		"Iran starts at 150 Coin (15000 x100) per balance.tres")

	# Dispatch a gather command — the input-handler equivalent at the
	# unit-API level.
	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)
	# Drive ticks until the worker completes at least one full trip:
	# walk → extract → walk back → deposit. The deposit fires when
	# Returning state arrives at the deposit target.
	var loop_complete: bool = false
	for i in range(200):
		_drive_loop_ticks(1)
		var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
		if coin_now > coin_before:
			loop_complete = true
			break
	assert_true(loop_complete,
		"Full gather loop must credit Iran coin within tick budget")
	# Coin gained must equal mine's yield_per_trip_x100 (1000 = 10 Coin).
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after - coin_before, 1000,
		"Single trip deposits exactly 10 Coin (yield_per_trip_x100 = 1000)")


# ---------------------------------------------------------------------------
# Flow 2 — Deposit emits resource_changed signal that HUD would consume.
# ---------------------------------------------------------------------------

var _resource_events: Array = []


func _on_resource_changed(team: int, kind: StringName, delta_x100: int,
		new_total_x100: int) -> void:
	_resource_events.append({
		&"team": team, &"kind": kind,
		&"delta_x100": delta_x100, &"new_total_x100": new_total_x100,
	})


func test_deposit_emits_resource_changed_signal() -> void:
	_resource_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)
	for i in range(200):
		_drive_loop_ticks(1)
		if _resource_events.size() > 0:
			break
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)
	assert_gt(_resource_events.size(), 0,
		"Deposit must emit at least one EventBus.resource_changed")
	var ev: Dictionary = _resource_events[0]
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries Iran team")
	assert_eq(ev[&"kind"], Constants.KIND_COIN, "signal carries KIND_COIN")
	assert_eq(ev[&"delta_x100"], 1000, "delta_x100 = 1000 (10 Coin)")
	assert_eq(ev[&"new_total_x100"], 16000,
		"new_total_x100 = 16000 (150 + 10 = 160 Coin)")


# ---------------------------------------------------------------------------
# Flow 3 — Idle Kargar death drains Farr by 1.0 via the dispatcher.
# ---------------------------------------------------------------------------

func test_idle_kargar_death_drains_farr_one() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	# Worker stays in &"idle" — no gather command issued. Kill via
	# HealthComponent.take_damage with lethal amount.
	var farr_before: float = FarrSystem.value_farr
	# Drive the kill inside a tick so health-component asserts hold.
	SimClock._is_ticking = true
	var hc: Node = _kargar.get_health()
	hc.take_damage_x100(hc.max_hp_x100, null, &"test_kill")
	SimClock._is_ticking = false
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 1.0, 1e-4,
		"idle Kargar death drops Farr by 1.0 (dispatcher reads "
		+ "fsm.current.id == &\"idle\" pre-Dying-swap)")


# ---------------------------------------------------------------------------
# Flow 4 — Gathering Kargar death drains Farr by 0.5.
# ---------------------------------------------------------------------------

func test_gathering_kargar_death_drains_farr_half() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	# Force-transition the worker into Gathering, then kill mid-walk.
	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)
	# One drive_loop_ticks transitions into Gathering.
	_drive_loop_ticks(1)
	assert_eq(_kargar.fsm.current.id, &"gathering",
		"sanity: worker is in Gathering state before kill")
	var farr_before: float = FarrSystem.value_farr
	SimClock._is_ticking = true
	var hc: Node = _kargar.get_health()
	hc.take_damage_x100(hc.max_hp_x100, null, &"test_kill")
	SimClock._is_ticking = false
	var farr_after: float = FarrSystem.value_farr
	assert_almost_eq(farr_before - farr_after, 0.5, 1e-4,
		"gathering Kargar death drops Farr by 0.5 (lighter drain — "
		+ "worker was contributing)")
