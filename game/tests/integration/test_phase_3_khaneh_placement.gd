# Integration test for the Phase 3 session 1 wave 1C Khaneh placement chain.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 wave 1C Definition of Done.
# Live chain: Kargar selected → COMMAND_CONSTRUCT dispatched →
#   UnitState_Constructing → walk to target → arrive → dwell →
#   Khaneh instantiated + place_at → ResourceSystem.change_resource
#   (Coin deduction) → ResourceSystem.change_population_cap (cap bump)
#   → EventBus.building_placed → UnitState_Constructing transitions to Idle.
#
# This file is the wave-3 qa coverage for the Khaneh placement chain.
# Per Testing Contract §3.1 + wave-0 precedent + the gather-loop
# integration test (test_phase_3_gather_loop.gd), it uses MatchHarness
# for autoload resets but spawns units / dispatches commands directly.
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var harness: Variant = null
var _kargar: Variant = null


func before_each() -> void:
	harness = MatchHarnessScript.new()
	harness.start_match(0, &"empty")
	CommandPool.reset()
	SelectionManager.reset()
	ResourceSystem.reset()
	FarrSystem.reset()
	UnitScript.call(&"reset_id_counter")
	BuildingScript.call(&"reset_id_counter")
	_kargar = null


func after_each() -> void:
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	# Free any buildings placed during the test (group lookup, sync free).
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if is_instance_valid(b):
			var p: Node = b.get_parent()
			if p != null:
				p.remove_child(b)
			b.free()
	SelectionManager.reset()
	CommandPool.reset()
	ResourceSystem.reset()
	FarrSystem.reset()
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


# Drive FSM tick + advance SimClock — same pattern as
# test_phase_3_gather_loop.gd::_drive_loop_ticks.
func _drive_loop_ticks(n: int) -> void:
	for i in range(n):
		SimClock._is_ticking = true
		_kargar.fsm.tick(SimClock.SIM_DT)
		SimClock._is_ticking = false
		harness.advance_ticks(1)


# Drive the placement loop until either a Khaneh appears in the
# &"buildings" group OR the budget runs out.
func _drive_until_khaneh_placed(max_ticks: int) -> bool:
	for _i in range(max_ticks):
		_drive_loop_ticks(1)
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b):
				return true
	return false


# ---------------------------------------------------------------------------
# Flow 1 — Full Khaneh placement chain end-to-end.
# ---------------------------------------------------------------------------

func test_full_khaneh_placement_chain() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	# Capture initial Coin + cap.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var cap_before: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, 15000,
		"Iran starts at 150 Coin (15000 x100) per balance.tres")
	assert_eq(cap_before, 0,
		"Iran starts at 0 population_cap (no Khaneh placed yet)")

	# Dispatch COMMAND_CONSTRUCT — same payload the build menu /
	# BuildPlacementHandler would produce. Equivalent to the lead
	# pressing the build button + clicking valid terrain.
	var target: Vector3 = Vector3(10.0, 0.0, 5.0)
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": target,
		},
	)

	# Drive ticks until the Khaneh lands. Walk (~1 tick with
	# move_speed=100) + path-resolve (mock 1 tick) + dwell (90 ticks).
	# 200 is generous.
	var placed: bool = _drive_until_khaneh_placed(200)
	assert_true(placed,
		"Full placement chain must instantiate the Khaneh within "
		+ "200 ticks (walk + dwell + place)")

	# Verify the placed building has the right kind and team.
	var buildings: Array = get_tree().get_nodes_in_group(&"buildings")
	assert_eq(buildings.size(), 1,
		"Exactly one Khaneh placed (no duplicates from re-entry)")
	var khaneh: Node = buildings[0]
	assert_eq(khaneh.get(&"kind"), &"khaneh",
		"Placed building.kind = &\"khaneh\"")
	assert_eq(khaneh.get(&"team"), Constants.TEAM_IRAN,
		"Placed building.team mirrors the worker's team (Iran)")
	assert_true(khaneh.get(&"is_complete"),
		"Placed building.is_complete = true (instant placement, session 1)")

	# Position check — Khaneh's global position matches the target.
	var pos: Vector3 = khaneh.global_position
	assert_almost_eq(pos.x, target.x, 0.0001,
		"Khaneh global_position.x = target.x")
	assert_almost_eq(pos.z, target.z, 0.0001,
		"Khaneh global_position.z = target.z")

	# Coin deducted by 50 (5000 x100).
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before - coin_after, 5000,
		"Khaneh placement deducted exactly 50 Coin (5000 x100)")

	# Population cap bumped by 10.
	var cap_after: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after - cap_before, 10,
		"Khaneh placement bumped population_cap by +10")

	# Worker transitioned back to Idle after placement.
	assert_eq(_kargar.fsm.current.id, &"idle",
		"After placement, Kargar transitions back to Idle")


# ---------------------------------------------------------------------------
# Flow 2 — Khaneh placement emits building_placed signal exactly once.
# ---------------------------------------------------------------------------

var _building_placed_events: Array = []


func _on_building_placed(unit_id: int, kind: StringName, team: int,
		pos: Vector3) -> void:
	_building_placed_events.append({
		&"unit_id": unit_id, &"kind": kind,
		&"team": team, &"pos": pos,
	})


func test_khaneh_placement_emits_building_placed_signal_once() -> void:
	_building_placed_events.clear()
	EventBus.building_placed.connect(_on_building_placed)
	_kargar = _spawn_kargar(Vector3.ZERO)
	var target: Vector3 = Vector3(10.0, 0.0, 5.0)
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": target,
		},
	)
	_drive_until_khaneh_placed(200)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	assert_eq(_building_placed_events.size(), 1,
		"building_placed must fire exactly once per Khaneh placement")
	var ev: Dictionary = _building_placed_events[0]
	assert_eq(ev[&"unit_id"], _kargar.unit_id,
		"Signal carries the placing Kargar's unit_id")
	assert_eq(ev[&"kind"], &"khaneh",
		"Signal carries kind = &\"khaneh\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN,
		"Signal carries TEAM_IRAN (the placing worker's team)")


# ---------------------------------------------------------------------------
# Flow 3 — Khaneh placement emits resource_changed for Coin spend AND cap bump.
# ---------------------------------------------------------------------------

var _resource_changed_events: Array = []


func _on_resource_changed(team: int, kind: StringName, delta_x100: int,
		new_total_x100: int) -> void:
	_resource_changed_events.append({
		&"team": team, &"kind": kind,
		&"delta_x100": delta_x100, &"new_total_x100": new_total_x100,
	})


func test_khaneh_placement_emits_resource_changed_for_coin_and_cap() -> void:
	_resource_changed_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(10.0, 0.0, 5.0),
		},
	)
	_drive_until_khaneh_placed(200)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)
	# Two write-shaped emissions: one Coin deduction (KIND_COIN, delta -5000)
	# and one cap bump (&"population_cap", delta +10).
	var saw_coin_deduct: bool = false
	var saw_cap_bump: bool = false
	for ev in _resource_changed_events:
		if ev[&"kind"] == Constants.KIND_COIN and ev[&"delta_x100"] == -5000:
			saw_coin_deduct = true
		if ev[&"kind"] == &"population_cap" and ev[&"delta_x100"] == 10:
			saw_cap_bump = true
	assert_true(saw_coin_deduct,
		"resource_changed fires with kind=KIND_COIN delta=-5000 (50 Coin spend)")
	assert_true(saw_cap_bump,
		"resource_changed fires with kind=&\"population_cap\" delta=+10")


# ---------------------------------------------------------------------------
# Flow 4 — Placed Khaneh has the required collision body (BUG-07 lesson)
#          and NavigationObstacle3D (RESOURCE_NODE_CONTRACT §3.2).
# ---------------------------------------------------------------------------

func test_placed_khaneh_has_collision_body_and_nav_obstacle() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(10.0, 0.0, 5.0),
		},
	)
	_drive_until_khaneh_placed(200)
	var buildings: Array = get_tree().get_nodes_in_group(&"buildings")
	assert_eq(buildings.size(), 1)
	var khaneh: Node = buildings[0]
	# BUG-07 lesson — click targets need a CollisionObject3D ancestor in
	# their subtree so future selection raycasts (session 2+) can hit them.
	var has_body: bool = false
	var has_nav_obstacle: bool = false
	for child in khaneh.get_children():
		if child is CollisionObject3D:
			has_body = true
		if child is NavigationObstacle3D:
			has_nav_obstacle = true
	assert_true(has_body,
		"Placed Khaneh must contain a CollisionObject3D — BUG-07 lesson "
		+ "(click-targets need raycast-reachable bodies)")
	assert_true(has_nav_obstacle,
		"Placed Khaneh must contain a NavigationObstacle3D for "
		+ "dynamic navmesh carving (RESOURCE_NODE_CONTRACT §3.2)")
