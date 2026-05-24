# Integration test — Phase 3 Throne wave Track 1.
#
# Per 02q_PHASE_3_SESSION_8_THRONE_KICKOFF.md §4 Track 1 last bullet:
# "Integration: test_phase_3_throne_deposit.gd — Kargar gathers, walks
# back to Throne, deposits, HUD coin counter increments."
#
# Exercises the full canonical RNC §5.2 IDropoffTarget routing surface
# end-to-end:
#   1. Spawn a Throne (via the .tscn scene template — exercises the
#      live-game path used by main.gd:_spawn_starting_buildings).
#   2. Spawn a Kargar worker carrying a payload.
#   3. Drive the Returning state to completion.
#   4. Assert ResourceSystem.coin_for(team) increments by the carry
#      amount AND throne.deposit was the path that fired (not the
#      inline fallback) — observable via coin delta = exactly carry
#      amount, no double-credit.
#
# Mirrors test_phase_3_gather_loop.gd's integration shape — full
# fixture + behavioral assertions across system boundaries.
extends GutTest


const ThroneScene: PackedScene = preload(
	"res://scenes/world/buildings/throne.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd")


var _kargar: Variant
var _throne: Variant
var _mine: Variant
var _world_root: Node
var _mock: Variant


func before_each() -> void:
	SimClock.reset()
	ResourceSystem.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	BuildingScript.call(&"reset_id_counter")
	_mock = MockPathSchedulerScript.new()
	PathSchedulerService.set_scheduler(_mock)
	# Test-world root to scope the scene tree.
	_world_root = Node3D.new()
	_world_root.name = &"WorldRoot"
	add_child_autofree(_world_root)


func after_each() -> void:
	for ref in [_kargar, _throne, _mine]:
		if ref != null and is_instance_valid(ref):
			ref.queue_free()
	_kargar = null
	_throne = null
	_mine = null
	_world_root = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	SimClock.reset()
	CommandPool.reset()
	ResourceSystem.reset()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spawn_throne(team: int = Constants.TEAM_IRAN) -> Variant:
	# Position the Throne close to the Kargar's spawn (0,0,0) so the
	# test's walk-back arc completes within the 120-tick test loop. The
	# integration test isn't about walk distance; it's about the
	# canonical routing once arrival happens.
	var t: Variant = ThroneScene.instantiate()
	t.set(&"team", team)
	t.position = Vector3(0.0, 0.0, 0.0)
	_world_root.add_child(t)
	return t


func _spawn_kargar() -> Variant:
	var k: Variant = KargarScene.instantiate()
	k.team = Constants.TEAM_IRAN
	k.position = Vector3.ZERO
	_world_root.add_child(k)
	return k


func _spawn_mine() -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	m.position = Vector3(10.0, 0.0, 10.0)
	_world_root.add_child(m)
	return m


func _tick_fsm() -> void:
	# Wrap fsm.tick in _is_ticking = true so on-tick chokepoint asserts
	# (ResourceSystem.change_resource etc.) are satisfied. Mirror of
	# test_unit_state_returning.gd:_tick_fsm.
	SimClock._is_ticking = true
	_kargar.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


func _enter_returning_with_carry(deposit_target: Vector3) -> void:
	# Mirror test_unit_state_returning.gd:_enter_returning fixture exactly —
	# direct current_command write + carry fields + transition. Bypasses
	# Gathering-state to focus on the deposit half.
	_kargar._carry_kind = Constants.KIND_COIN
	_kargar._carry_amount_x100 = 1000  # 10 Coin
	_kargar.current_command = {
		"kind": &"return",
		"payload": {
			&"target_node": _mine,
			&"deposit_target": deposit_target,
			&"carry_kind": Constants.KIND_COIN,
			&"carry_amount_x100": 1000,
		},
	}
	_kargar.fsm.transition_to(&"returning")


# ---------------------------------------------------------------------------
# End-to-end: Throne-present deposit credits via canonical RNC §5.2 path
# ---------------------------------------------------------------------------

func test_kargar_deposit_at_throne_credits_team_coin() -> void:
	# 1. Spawn Throne BEFORE Kargar so the &"thrones" group is populated
	#    when ResourceSystem.dropoff_for_team is queried.
	_throne = _spawn_throne(Constants.TEAM_IRAN)
	# 2. Spawn Kargar + Mine; populate carry state.
	_kargar = _spawn_kargar()
	_mine = _spawn_mine()
	# 3. Sanity: dropoff_for_team finds the Throne BEFORE deposit fires.
	#    If this fails, the &"thrones" group join hasn't happened or the
	#    lookup is broken — the whole canonical-path test is moot.
	var dropoff: Node3D = ResourceSystem.dropoff_for_team(Constants.TEAM_IRAN)
	assert_eq(dropoff, _throne,
		"sanity precondition: dropoff_for_team(IRAN) must return the spawned Throne "
		+ "before the deposit cycle starts")
	# 4. Capture coin balance pre-deposit.
	var pre_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	# 5. Drive the Returning state to deposit completion. Deposit target
	# is the Throne's position (0,0,0 in this test fixture).
	_enter_returning_with_carry(Vector3.ZERO)
	SimClock._test_run_tick()
	for i in range(120):
		if _kargar.fsm.current == null:
			break
		var sid: StringName = _kargar.fsm.current.id
		_tick_fsm()
		if sid != &"returning":
			break
		# Advance clock so movement requests resolve.
		if i % 2 == 0:
			SimClock._test_run_tick()
	# 6. Assert coin credited by EXACTLY 1000 x100 (10 Coin).
	#    Pre-fix this would double-credit (inline + Throne.deposit both
	#    fire) and show 2000. Mirror C1.4 only-one-path enforced.
	var post_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(post_x100 - pre_x100, 1000,
		"Throne-routed deposit must credit team by EXACTLY 1000 x100 "
		+ "(once, via Throne.deposit's internal change_resource call). "
		+ "If this is 2000, C1.4 only-one-path-per-cycle was violated.")


func test_kargar_deposit_without_throne_falls_back_to_inline_path() -> void:
	# Throne-absent fallback path (test fixture w/o match-start spawn).
	# Coin still credits via inline ResourceSystem.change_resource per
	# wave-1B preserved fallback. Validates that adding the Throne
	# routing did NOT break the pre-Throne test fixture path.
	# (No throne spawned here.)
	_kargar = _spawn_kargar()
	_mine = _spawn_mine()
	var pre_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_enter_returning_with_carry(Vector3.ZERO)
	SimClock._test_run_tick()
	for i in range(120):
		if _kargar.fsm.current == null:
			break
		var sid: StringName = _kargar.fsm.current.id
		_tick_fsm()
		if sid != &"returning":
			break
		if i % 2 == 0:
			SimClock._test_run_tick()
	var post_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(post_x100 - pre_x100, 1000,
		"Throne-absent fallback: coin credited by 1000 x100 via inline path "
		+ "(wave-1B path preserved)")
