# Tests for UnitState_Constructing — Kargar worker's "walk to site, dwell,
# place" state. Phase 3 session 1 wave 1C.
#
# Per docs/STATE_MACHINE_CONTRACT.md §3 + 02f_PHASE_3_KICKOFF.md §3 wave 1C
# + 01_CORE_MECHANICS.md §5.
#
# Mirrors test_unit_state_gathering.gd's shape: shape (id/priority/
# interrupt), enter (path request), _sim_tick (walk → dwell → place),
# exit (path cancel), defensive bails.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern.
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const UnitStateConstructingScript: Script = preload(
	"res://scripts/units/states/unit_state_constructing.gd")
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd")
const IPathSchedulerScript: Script = preload(
	"res://scripts/core/path_scheduler.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _unit: Variant
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	ResourceSystem.reset()
	UnitScript.call(&"reset_id_counter")
	BuildingScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)


func after_each() -> void:
	if _unit != null and is_instance_valid(_unit):
		_unit.queue_free()
	_unit = null
	# Free any leftover buildings placed during the test (group lookup).
	# Use free() (not queue_free) so the building is gone synchronously —
	# subsequent before_each / tests in this file see an empty
	# &"buildings" group on first inspection, not a residual lingering
	# until the next process_frame.
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if is_instance_valid(b):
			# Disconnect parent first so free() doesn't fight Godot's
			# child-iteration safety.
			var p: Node = b.get_parent()
			if p != null:
				p.remove_child(b)
			b.free()
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	ResourceSystem.reset()
	SimClock.reset()
	CommandPool.reset()


func _spawn_kargar(pos: Vector3 = Vector3.ZERO) -> Variant:
	var u: Variant = UnitScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	u.get_movement()._scheduler = _mock
	u.global_position = pos
	# Fast move so arrival happens in one tick.
	u.get_movement().move_speed = 100.0
	return u


func _tick_fsm() -> void:
	SimClock._is_ticking = true
	_unit.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


func _drive_one_loop() -> void:
	# Walk-pump pattern: fsm.tick + harness-ish SimClock advance so the
	# MockPathScheduler delivers READY on the next poll.
	_tick_fsm()
	SimClock._test_run_tick()


# ---------------------------------------------------------------------------
# Shape — id, priority, interrupt_level
# ---------------------------------------------------------------------------

func test_constructing_state_id_priority_and_interrupt_level() -> void:
	var s: Variant = UnitStateConstructingScript.new()
	assert_eq(s.id, Constants.STATE_CONSTRUCTING,
		"Constructing.id is Constants.STATE_CONSTRUCTING (&\"constructing\")")
	assert_eq(s.priority, 5,
		"Constructing.priority is 5 (peer with Gathering / Returning)")
	assert_eq(s.interrupt_level, 1,
		"Constructing.interrupt_level is COMBAT (1) — damage interrupts the build")


# ---------------------------------------------------------------------------
# enter — read building_kind + target_position, start moving
# ---------------------------------------------------------------------------

func test_enter_reads_payload_and_requests_repath() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	# Manually set current_command (the state reads off ctx.current_command).
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# Mock scheduler must have received one repath request to the target.
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site")
	var last: Dictionary = _mock.call_log[-1]
	assert_almost_eq(last.get(&"to", Vector3.ZERO).x, 5.0, 0.0001,
		"repath request `to` matches the target_position")


# ---------------------------------------------------------------------------
# Defensive bails — invalid payloads → transition to Idle
# ---------------------------------------------------------------------------

func test_enter_bails_to_idle_on_missing_building_kind() -> void:
	_unit = _spawn_kargar()
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			# building_kind absent
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	assert_eq(_unit.fsm.current.id, &"idle",
		"Constructing bails to Idle when building_kind is missing")


func test_enter_bails_to_idle_on_unknown_building_kind() -> void:
	_unit = _spawn_kargar()
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"unknown_building_xyz",
			&"target_position": Vector3.ZERO,
		},
	}
	_unit.fsm.transition_to(&"constructing")
	assert_eq(_unit.fsm.current.id, &"idle",
		"Constructing bails to Idle when building_kind is not in scene table")


# Wave-1A live-test fix (2026-05-14): Mazra'eh was missing from
# _BUILDING_SCENE_PATHS at line 98-100, causing the worker to bail to Idle
# when the build menu's Mazra'eh button dispatched COMMAND_CONSTRUCT with
# building_kind=&"mazraeh". Same shape as the original Khaneh BUG-08.
# Mirrors test_enter_reads_payload_and_requests_repath but for Mazra'eh —
# the positive-case assertion is that the state does NOT abort to idle
# (it transitions through to moving toward the target).
func test_enter_accepts_mazraeh_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"mazraeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized, the state
	# proceeds to drive movement toward the build site.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"mazraeh\" building_kind — present in "
		+ "_BUILDING_SCENE_PATHS after wave-1A late-add fix")
	# Mock scheduler must have received one repath request to the target —
	# confirms the state entered the moving phase (mirrors the khaneh test
	# at line 110).
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Mazra'eh")


func test_enter_bails_to_idle_on_missing_target_position() -> void:
	_unit = _spawn_kargar()
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			# target_position absent
		},
	}
	_unit.fsm.transition_to(&"constructing")
	assert_eq(_unit.fsm.current.id, &"idle",
		"Constructing bails to Idle when target_position is missing")


# ---------------------------------------------------------------------------
# _sim_tick — full happy path: walk, dwell, place, transition to Idle
# ---------------------------------------------------------------------------

func test_sim_tick_walk_dwell_place_full_cycle() -> void:
	# Set Iran's Coin high enough that the cost check passes (50 Coin →
	# 5000 x100; balance.tres seed = 150 Coin = 15000 x100, so this is
	# already covered, but keep the assertion explicit).
	assert_true(
		ResourceSystem.coin_x100_for(Constants.TEAM_IRAN) >= 5000,
		"sanity: starting Coin >= cost")
	_unit = _spawn_kargar(Vector3.ZERO)
	var target: Vector3 = Vector3(5.0, 0.0, 0.0)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": target,
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Drive enough ticks for: walk (~1 tick with move_speed=100) +
	# path-resolve (mock takes 1 tick to flip PENDING→READY) + dwell
	# (90 ticks placeholder). 150 ticks is generous.
	var max_ticks: int = 200
	var placed: bool = false
	for _i in range(max_ticks):
		_drive_one_loop()
		# Check if any building landed in the &"buildings" group.
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and b.get(&"is_complete") == true:
				placed = true
				break
		if placed:
			break
	assert_true(placed,
		"Within %d ticks, a Khaneh must appear in the &\"buildings\" group "
		% max_ticks
		+ "via UnitState_Constructing's placement step")
	# State should have transitioned to Idle once placement completed.
	assert_eq(_unit.fsm.current.id, &"idle",
		"After placement, the worker transitions back to Idle")


func test_sim_tick_deducts_coin_at_placement() -> void:
	# 50 Coin should leave Iran's treasury when the Khaneh is placed.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(200):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before - coin_after, 5000,
		"Placement deducts exactly 50 Coin (5000 x100) via "
		+ "ResourceSystem.change_resource")


func test_sim_tick_bumps_population_cap_at_placement() -> void:
	# Khaneh.population_capacity = 10 — the post-placement cap should
	# be 10 higher than the pre-placement cap.
	var cap_before: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(200):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break
	var cap_after: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after - cap_before, 10,
		"Khaneh placement bumps population_cap by +10")


func test_sim_tick_emits_building_placed_signal() -> void:
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team,
				&"pos": pos})
	EventBus.building_placed.connect(handler)
	_unit = _spawn_kargar(Vector3.ZERO)
	var target: Vector3 = Vector3(5.0, 0.0, 0.0)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": target,
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(200):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"Exactly one building_placed signal fires per placement")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"kind"], &"khaneh",
		"Signal carries kind = &\"khaneh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN,
		"Signal carries the placing worker's team")
	assert_eq(ev[&"uid"], _unit.unit_id,
		"Signal carries the placing worker's unit_id")


# ---------------------------------------------------------------------------
# Insufficient-funds edge case — placement fails without deducting cost
# ---------------------------------------------------------------------------

func test_sim_tick_skips_placement_when_insufficient_coin() -> void:
	# Zero out Iran's coin so the cost check fails when the worker arrives.
	# The state should bail to Idle WITHOUT deducting Coin AND WITHOUT
	# instantiating the Khaneh.
	SimClock._is_ticking = true
	# Drain to zero via change_resource (negative delta). Iran starts at
	# 150 Coin = 15000 x100; spend the whole thing.
	var have_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, -have_x100,
		&"test_drain", null)
	SimClock._is_ticking = false
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 0,
		"sanity: Iran coin drained to 0")

	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(200):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break

	# No building was placed.
	assert_eq(get_tree().get_nodes_in_group(&"buildings").size(), 0,
		"No Khaneh instantiated when funds insufficient at placement")
	# Coin stays at 0 — no spurious deduction.
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 0,
		"Coin stays at 0 — no deduction when placement fails")


# ---------------------------------------------------------------------------
# exit — path cancel
# ---------------------------------------------------------------------------

func test_exit_cancels_in_flight_repath() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# Confirm there's an in-flight request.
	assert_ne(_unit.get_movement()._request_id, -1,
		"sanity: movement has an in-flight request_id after enter")
	# Transition out to Idle. The StateMachine queues transitions in
	# _pending_id; the actual exit/enter swap happens on the next
	# fsm.tick(). So we request the transition then tick once to drain.
	_unit.fsm.transition_to(&"idle")
	_tick_fsm()
	assert_eq(_unit.get_movement()._request_id, -1,
		"exit cancels in-flight repath (request_id back to -1 sentinel) "
		+ "once the FSM drains the pending Idle transition")


# ---------------------------------------------------------------------------
# Path-failure bail — Constructing transitions to Idle on FAILED path
# ---------------------------------------------------------------------------

func test_sim_tick_bails_to_idle_on_path_failure() -> void:
	_mock.fail_next_request()
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Drive enough ticks for the FAILED path resolution to surface.
	for _i in range(5):
		_drive_one_loop()
	assert_eq(_unit.fsm.current.id, &"idle",
		"FAILED path resolution drops back to Idle (no placement)")
	# No building placed.
	assert_eq(get_tree().get_nodes_in_group(&"buildings").size(), 0,
		"No Khaneh placed when path fails")
