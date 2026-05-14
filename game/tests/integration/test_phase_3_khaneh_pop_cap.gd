# Integration test — Phase 3 wave 3 (3/5): Khaneh contribution to population_cap.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 "Wave 3" target 3.
# After Khaneh placement completes:
#   (a) ResourceSystem.population_cap_for(team) increases by exactly
#       BalanceData.buildings.khaneh.population_capacity (regression lock
#       vs. the hardcoded-constant failure mode).
#   (b) EventBus.resource_changed fires with kind=&"population_cap" and
#       delta = BalanceData value.
#   (c) Multiple Khaneh placements accumulate correctly (cap grows linearly).
#
# This file is ADDITIVE to test_phase_3_khaneh_placement.gd — that file
# covers the end-to-end placement chain. This file focuses on the ResourceSystem
# side of the cap bump: verifying the value against BalanceData and testing
# accumulation across multiple buildings.
#
# Pitfall #2: FSM/per-tick driver. Same _drive_loop_ticks pattern.
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const BuildingScript: Script = preload("res://scripts/world/buildings/building.gd")


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
	u.get_movement().move_speed = 100.0
	return u


func _drive_loop_ticks(n: int) -> void:
	for i in range(n):
		SimClock._is_ticking = true
		_kargar.fsm.tick(SimClock.SIM_DT)
		SimClock._is_ticking = false
		harness.advance_ticks(1)


func _drive_until_khaneh_placed(max_ticks: int) -> bool:
	for _i in range(max_ticks):
		_drive_loop_ticks(1)
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b):
				return true
	return false


# Read the expected cap bonus from BalanceData so the test stays valid across
# re-tuning. Returns -1 if BalanceData is missing or the entry is absent.
func _expected_pop_cap_bonus() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return -1
	var bd: Resource = load(path)
	if bd == null:
		return -1
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return -1
	var stats: Variant = (bldgs as Dictionary).get(&"khaneh", null)
	if stats == null:
		return -1
	var cap_v: Variant = stats.get(&"population_capacity")
	if typeof(cap_v) != TYPE_INT and typeof(cap_v) != TYPE_FLOAT:
		return -1
	return int(cap_v)


# ---------------------------------------------------------------------------
# Flow 1 — cap bump matches BalanceData.buildings.khaneh.population_capacity.
# ---------------------------------------------------------------------------

func test_khaneh_pop_cap_bump_matches_balance_data() -> void:
	var expected_bonus: int = _expected_pop_cap_bonus()
	assert_true(expected_bonus > 0,
		"BalanceData.buildings.khaneh.population_capacity must be present and > 0")

	_kargar = _spawn_kargar(Vector3.ZERO)
	var cap_before: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_before, 0,
		"Sanity: Iran starts at 0 population_cap (no buildings yet)")

	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(10.0, 0.0, 5.0),
		},
	)
	var placed: bool = _drive_until_khaneh_placed(200)
	assert_true(placed, "Khaneh must place within 200 ticks")

	var cap_after: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after - cap_before, expected_bonus,
		"population_cap delta must equal BalanceData.buildings.khaneh.population_capacity "
		+ "(expected " + str(expected_bonus) + ", got " + str(cap_after - cap_before) + ")")


# ---------------------------------------------------------------------------
# Flow 2 — resource_changed fires with correct kind, delta, and new_total.
# ---------------------------------------------------------------------------

var _events: Array = []


func _on_resource_changed(team: int, kind: StringName, delta_x100: int,
		new_total_x100: int) -> void:
	_events.append({
		&"team": team, &"kind": kind,
		&"delta_x100": delta_x100, &"new_total_x100": new_total_x100,
	})


func test_khaneh_placement_emits_resource_changed_for_pop_cap() -> void:
	var expected_bonus: int = _expected_pop_cap_bonus()
	assert_true(expected_bonus > 0, "BalanceData must have khaneh.population_capacity > 0")

	_events.clear()
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

	# Find the population_cap event.
	var cap_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == &"population_cap" and ev[&"team"] == Constants.TEAM_IRAN:
			cap_ev = ev
			break
	assert_not_null(cap_ev,
		"Khaneh placement must emit resource_changed with kind=&\"population_cap\"")
	assert_eq(cap_ev[&"delta_x100"], expected_bonus,
		"resource_changed delta must equal BalanceData.buildings.khaneh.population_capacity "
		+ "(= " + str(expected_bonus) + ")")
	assert_eq(cap_ev[&"new_total_x100"], expected_bonus,
		"resource_changed new_total = expected_bonus (started from 0)")


# ---------------------------------------------------------------------------
# Flow 3 — two Khaneh placements accumulate linearly.
# ---------------------------------------------------------------------------

func test_two_khaneh_accumulate_population_cap() -> void:
	var expected_bonus: int = _expected_pop_cap_bonus()
	assert_true(expected_bonus > 0, "BalanceData must have khaneh.population_capacity > 0")

	# First Khaneh.
	_kargar = _spawn_kargar(Vector3.ZERO)
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	)
	var placed_first: bool = _drive_until_khaneh_placed(200)
	assert_true(placed_first, "First Khaneh must place within tick budget")

	var cap_after_one: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after_one, expected_bonus,
		"After first Khaneh: cap = " + str(expected_bonus))

	# Second Khaneh — re-use the same Kargar (it should have returned to Idle).
	# No existing mine so we just dispatch another COMMAND_CONSTRUCT at a
	# different position.
	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(20.0, 0.0, 0.0),
		},
	)
	# Drive again until we have 2 buildings in the group.
	var placed_second: bool = false
	for _i in range(300):
		_drive_loop_ticks(1)
		var count: int = get_tree().get_nodes_in_group(&"buildings").size()
		if count >= 2:
			placed_second = true
			break
	assert_true(placed_second, "Second Khaneh must place within tick budget")

	var cap_after_two: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after_two, 2 * expected_bonus,
		"After two Khaneh: cap = 2 × " + str(expected_bonus)
		+ " (linear accumulation, no double-count)")


# ---------------------------------------------------------------------------
# Flow 4 — cap bump is team-specific (Turan cap unaffected by Iran Khaneh).
# ---------------------------------------------------------------------------

func test_khaneh_only_bumps_owning_teams_cap() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	var turan_cap_before: int = ResourceSystem.population_cap_for(Constants.TEAM_TURAN)

	_kargar.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": &"khaneh",
			&"target_position": Vector3(10.0, 0.0, 5.0),
		},
	)
	_drive_until_khaneh_placed(200)

	var turan_cap_after: int = ResourceSystem.population_cap_for(Constants.TEAM_TURAN)
	assert_eq(turan_cap_after, turan_cap_before,
		"Iran Khaneh placement must NOT change Turan's population_cap "
		+ "(team isolation invariant)")
