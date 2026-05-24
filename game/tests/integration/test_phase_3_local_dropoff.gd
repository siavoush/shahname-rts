# Integration test — Phase 3 session 9 Wave-3-LocalDropoffs Track 1.
#
# Per 02r_PHASE_3_SESSION_9_LOCAL_DROPOFFS_KICKOFF.md v1.0.1 §3.1 item 7
# (last bullet): "test_phase_3_local_dropoff.gd (NEW integration) —
# Kargar gathers coin from Mine, deposits at NEAREST Ma'dan (not Throne)
# when Ma'dan exists; falls back to Throne when no Ma'dan."
#
# Validates the full kind-aware routing surface end-to-end + the C1.4
# only-one-path-per-cycle invariant (exactly 10 coin per deposit, not
# 20 — observable assertion).
extends GutTest


const MazraehScene: PackedScene = preload(
	"res://scenes/world/buildings/mazraeh.tscn")
const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")
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
var _madan: Variant
var _mazraeh: Variant
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
	_world_root = Node3D.new()
	_world_root.name = &"WorldRoot"
	add_child_autofree(_world_root)


func after_each() -> void:
	for ref in [_kargar, _madan, _mazraeh, _throne, _mine]:
		if ref != null and is_instance_valid(ref):
			ref.queue_free()
	_kargar = null
	_madan = null
	_mazraeh = null
	_throne = null
	_mine = null
	_world_root = null
	PathSchedulerService.reset()
	if _mock != null:
		_mock.clear_log()
	_mock = null
	# Reset SimClock state. Belt-and-braces: explicit _is_ticking clear
	# AND reset(). Either alone has historically leaked tick state across
	# test files (the 2nd workspace-bleed pattern from Task #208).
	SimClock._is_ticking = false
	SimClock.reset()
	CommandPool.reset()
	ResourceSystem.reset()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spawn_madan(team: int, pos: Vector3 = Vector3.ZERO) -> Variant:
	var m: Variant = MadanScene.instantiate()
	m.set(&"team", team)
	m.position = pos
	_world_root.add_child(m)
	return m


func _spawn_throne(team: int, pos: Vector3 = Vector3.ZERO) -> Variant:
	var t: Variant = ThroneScene.instantiate()
	t.set(&"team", team)
	t.position = pos
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
	SimClock._is_ticking = true
	_kargar.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false


func _enter_returning_with_coin_carry(deposit_target: Vector3) -> void:
	# Mirror test_unit_state_returning.gd:_enter_returning fixture —
	# direct carry + current_command write + transition to Returning.
	_kargar._carry_kind = Constants.KIND_COIN
	_kargar._carry_amount_x100 = 1000
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
# Kind-routing: Ma'dan-present, Throne-present → routes to Ma'dan (NOT Throne)
# ---------------------------------------------------------------------------

func test_kargar_with_coin_carry_deposits_at_madan_when_present() -> void:
	# Setup: BOTH Ma'dan AND Throne exist. The kind-aware routing must
	# pick Ma'dan (kind-matching local depot) NOT Throne (universal
	# fallback). This is the wave's primary win condition.
	_madan = _spawn_madan(Constants.TEAM_IRAN, Vector3.ZERO)
	_throne = _spawn_throne(Constants.TEAM_IRAN, Vector3(0.0, 0.0, -32.0))
	_kargar = _spawn_kargar()
	_mine = _spawn_mine()
	# Sanity: dropoff_for_team_by_kind(IRAN, KIND_COIN) returns the Ma'dan
	# (not the Throne). The Ma'dan is in &"coin_depots" group.
	var dropoff: Node3D = ResourceSystem.dropoff_for_team_by_kind(
		Constants.TEAM_IRAN, Constants.KIND_COIN)
	assert_eq(dropoff, _madan,
		"sanity precondition: dropoff_for_team_by_kind(IRAN, KIND_COIN) "
		+ "with Ma'dan + Throne both present must return the Ma'dan "
		+ "(kind-matching local depot wins over universal fallback)")
	# Drive Returning to deposit.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_enter_returning_with_coin_carry(Vector3.ZERO)
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
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	# Critical: 1000 x100, not 2000. C1.4 only-one-path enforced —
	# Ma'dan.deposit owns the chokepoint call; UnitState_Returning's
	# inline fallback does NOT also fire.
	assert_eq(coin_after - coin_before, 1000,
		"Ma'dan-routed deposit must credit team by EXACTLY 1000 x100 once. "
		+ "If this is 2000, C1.4 only-one-path-per-cycle was violated "
		+ "(both Ma'dan.deposit AND inline change_resource fired).")


# ---------------------------------------------------------------------------
# Throne fallback: no Ma'dan → routes to Throne
# ---------------------------------------------------------------------------

func test_kargar_with_coin_carry_falls_back_to_throne_when_no_madan() -> void:
	# Setup: ONLY Throne (no Ma'dan). dropoff_for_team_by_kind must fall
	# back to Throne (universal fallback). Coin still credits.
	_throne = _spawn_throne(Constants.TEAM_IRAN, Vector3.ZERO)
	_kargar = _spawn_kargar()
	_mine = _spawn_mine()
	var dropoff: Node3D = ResourceSystem.dropoff_for_team_by_kind(
		Constants.TEAM_IRAN, Constants.KIND_COIN)
	assert_eq(dropoff, _throne,
		"sanity precondition: dropoff_for_team_by_kind(IRAN, KIND_COIN) "
		+ "with no Ma'dan must fall back to Throne (universal fallback)")
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_enter_returning_with_coin_carry(Vector3.ZERO)
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
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after - coin_before, 1000,
		"Throne-fallback deposit must credit by 1000 x100 (Throne.deposit "
		+ "owns the chokepoint, same C1.4 invariant as Ma'dan path)")


# ---------------------------------------------------------------------------
# No-depot fallback: no Ma'dan AND no Throne → inline change_resource
# ---------------------------------------------------------------------------

func test_kargar_with_coin_carry_falls_back_to_inline_when_no_depot() -> void:
	# Setup: no Ma'dan, no Throne. UnitState_Returning's inline
	# change_resource fallback fires (wave-1B preserved behavior).
	_kargar = _spawn_kargar()
	_mine = _spawn_mine()
	# Sanity: dropoff_for_team_by_kind returns null.
	var dropoff: Node3D = ResourceSystem.dropoff_for_team_by_kind(
		Constants.TEAM_IRAN, Constants.KIND_COIN)
	assert_null(dropoff,
		"sanity precondition: no Ma'dan + no Throne → dropoff_for_team_by_kind "
		+ "returns null → Returning's inline fallback fires")
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	_enter_returning_with_coin_carry(Vector3.ZERO)
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
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after - coin_before, 1000,
		"No-depot inline-fallback deposit must credit by 1000 x100 "
		+ "(wave-1B path preserved when no canonical IDropoffTarget exists)")
