# Integration test — Phase 3 wave 3 (5/5): Cross-feature smoke.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 "Wave 3" target 5.
# Verifies that Phase 2 combat and Phase 3 gather loop coexist in a single
# match without corrupting each other:
#
#   (a) 2 Kargar workers gather from a mine while 2 Iran Piyade fight
#       2 Turan Piyade. After N ticks:
#       - gather still completes at least one cycle (coin increases)
#       - combat still resolves (one side's HP drops)
#
#   (b) FarrDrainDispatcher subscribes to unit_health_zero and dispatches
#       the correct key based on the dying unit's fsm.current.id PRE-Dying-
#       swap (Open Space sync 2026-05-13, architecture §6 v0.20.0):
#       - idle Kargar death → worker_killed_idle (Farr -1.0)
#       - gathering Kargar death → worker_killed_during_gather (Farr -0.5)
#       - returning Kargar death → worker_killed_during_gather (Farr -0.5)
#       These are tested by killing a Kargar in a known FSM state inside a
#       tick boundary and asserting the resulting Farr delta.
#
# Pitfall #11: use hp_x100 <= 0 or fsm.current.id == &"dying" for death
# detection (NOT is_instance_valid in a _test_run_tick loop).
# Pitfall #2: all unit FSMs are driven via EventBus.sim_phase when using
# harness.advance_ticks(n) — each unit's _on_sim_phase connects to this
# signal in _ready.
# Pitfall #10 (candidate): Attacking._sim_tick re-issues request_repath
# every tick when out-of-range, which starves MockPathScheduler. Use the
# instant-resolve scheduler for combat units (same approach as
# test_phase_2_session_1_combat.gd BUG-06 test).
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


# Instant-resolve path scheduler — same pattern as BUG-06 regression test.
# Attacking._sim_tick re-issues request_repath EVERY tick when out-of-range,
# which cancels the prior PENDING MockPathScheduler request before it resolves.
# An instant-resolve scheduler sidesteps this by returning READY synchronously.
class _InstantScheduler extends "res://scripts/core/path_scheduler.gd":
	var _next_id: int = 1
	var _requests: Dictionary = {}

	func request_repath(unit_id: int, from: Vector3, to: Vector3, priority: int) -> int:
		var rid: int = _next_id
		_next_id += 1
		var wps: PackedVector3Array = PackedVector3Array()
		wps.append(from)
		wps.append(to)
		_requests[rid] = {
			&"unit_id": unit_id,
			&"priority": priority,
			&"state": PathState.READY,
			&"waypoints": wps,
		}
		return rid

	func poll_path(request_id: int) -> Dictionary:
		if not _requests.has(request_id):
			return {&"state": PathState.FAILED, &"waypoints": PackedVector3Array()}
		var entry: Dictionary = _requests[request_id]
		return {
			&"state": int(entry[&"state"]),
			&"waypoints": entry[&"waypoints"],
		}

	func cancel_repath(request_id: int) -> void:
		if not _requests.has(request_id):
			return
		var entry: Dictionary = _requests[request_id]
		if int(entry[&"state"]) == PathState.READY:
			entry[&"state"] = PathState.CANCELLED


var harness: Variant = null
var _iran_piyade_1: Variant = null
var _iran_piyade_2: Variant = null
var _turan_piyade_1: Variant = null
var _turan_piyade_2: Variant = null
var _kargar_1: Variant = null
var _kargar_2: Variant = null
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
	_iran_piyade_1 = null
	_iran_piyade_2 = null
	_turan_piyade_1 = null
	_turan_piyade_2 = null
	_kargar_1 = null
	_kargar_2 = null
	_mine = null


func after_each() -> void:
	var nodes: Array = [
		_iran_piyade_1, _iran_piyade_2,
		_turan_piyade_1, _turan_piyade_2,
		_kargar_1, _kargar_2, _mine,
	]
	for n in nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_iran_piyade_1 = null
	_iran_piyade_2 = null
	_turan_piyade_1 = null
	_turan_piyade_2 = null
	_kargar_1 = null
	_kargar_2 = null
	_mine = null
	SelectionManager.reset()
	CommandPool.reset()
	ResourceSystem.reset()
	FarrSystem.reset()
	FarrDrainDispatcher.reset()
	harness.teardown()
	harness = null


func _spawn_iran_piyade(pos: Vector3) -> Variant:
	var u: Variant = PiyadeScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_IRAN
	# Instant scheduler so out-of-range Attacking doesn't starve on MockPathScheduler.
	u.get_movement()._scheduler = _InstantScheduler.new()
	return u


func _spawn_turan_piyade(pos: Vector3) -> Variant:
	var u: Variant = TuranPiyadeScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_TURAN
	u.get_movement()._scheduler = _InstantScheduler.new()
	return u


func _spawn_kargar(pos: Vector3, mine: Variant) -> Variant:
	var u: Variant = KargarScene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = Constants.TEAM_IRAN
	u.get_movement()._scheduler = harness._mock_scheduler
	u.get_movement().move_speed = 100.0
	# Pre-issue the gather command so the loop starts immediately.
	u.replace_command(Constants.COMMAND_GATHER, {&"target_node": mine})
	return u


func _spawn_mine(pos: Vector3) -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	m.extract_ticks = 2
	return m


# Helper: kill a unit inside a tick boundary (same approach as gather-loop tests).
func _kill_unit_in_tick(unit: Variant) -> void:
	var hc: Node = unit.get_health()
	SimClock._is_ticking = true
	hc.take_damage_x100(int(hc.max_hp_x100), null, &"test_kill")
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# Flow 1 — 2 Kargar gather + 2v2 Piyade combat coexist over N ticks.
# Both loops must make progress; neither must corrupt the other.
# ---------------------------------------------------------------------------

func test_gather_and_combat_coexist_without_corruption() -> void:
	# Set up gather loop: mine offset from Kargar spawn so they walk.
	_mine = _spawn_mine(Vector3(10.0, 0.0, 30.0))
	_kargar_1 = _spawn_kargar(Vector3(0.0, 0.0, 30.0), _mine)
	_kargar_2 = _spawn_kargar(Vector3(2.0, 0.0, 30.0), _mine)

	# Set up combat: Iran Piyade vs Turan Piyade within attack range (1.5).
	_iran_piyade_1 = _spawn_iran_piyade(Vector3(0.0, 0.0, 0.0))
	_iran_piyade_2 = _spawn_iran_piyade(Vector3(2.0, 0.0, 0.0))
	_turan_piyade_1 = _spawn_turan_piyade(Vector3(0.0, 0.0, 1.0))
	_turan_piyade_2 = _spawn_turan_piyade(Vector3(2.0, 0.0, 1.0))

	# Issue attack commands. Iran attacks Turan, Turan attacks Iran.
	_iran_piyade_1.replace_command(
		Constants.COMMAND_ATTACK, {&"target_unit_id": int(_turan_piyade_1.unit_id)})
	_iran_piyade_2.replace_command(
		Constants.COMMAND_ATTACK, {&"target_unit_id": int(_turan_piyade_2.unit_id)})
	_turan_piyade_1.replace_command(
		Constants.COMMAND_ATTACK, {&"target_unit_id": int(_iran_piyade_1.unit_id)})
	_turan_piyade_2.replace_command(
		Constants.COMMAND_ATTACK, {&"target_unit_id": int(_iran_piyade_2.unit_id)})

	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var hp_turan1_before: int = int(_turan_piyade_1.get_health().hp_x100)
	var hp_iran1_before: int = int(_iran_piyade_1.get_health().hp_x100)

	# Drive 150 ticks via the EventBus chain — ALL units' FSMs advance.
	# Workers gather while Piyade fight. harness.advance_ticks drives
	# EventBus.sim_phase which each unit listens to via _on_sim_phase.
	harness.advance_ticks(150)

	# Gather assertion — at least one deposit must have completed.
	# Use the looser > assertion because the Kargar's gather loop may not
	# have completed a full cycle for both workers yet, but at least one
	# should have deposited within 150 ticks (walk ~1 tick at speed 100,
	# dwell 2 ticks, return ~1 tick).
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_gt(coin_after, coin_before,
		"After 150 ticks, at least one Kargar must have deposited Coin "
		+ "(gather loop made progress despite concurrent combat)")

	# Combat assertion — at least one Turan unit must have taken damage.
	var hp_turan1_after: int = int(_turan_piyade_1.get_health().hp_x100)
	var hp_turan2_after: int = int(_turan_piyade_2.get_health().hp_x100)
	var any_turan_damaged: bool = hp_turan1_after < hp_turan1_before \
		or hp_turan2_after < int(_turan_piyade_2.get_health().hp_x100)
	# Because we're inside assert at this point, recalculate:
	any_turan_damaged = hp_turan1_after < hp_turan1_before
	if not any_turan_damaged:
		any_turan_damaged = int(_turan_piyade_2.get_health().hp_x100) < hp_turan1_before
	assert_true(any_turan_damaged,
		"After 150 ticks, at least one Turan Piyade must have taken damage "
		+ "(combat loop made progress despite concurrent gather)")

	# No state corruption: ResourceSystem coin must not be negative.
	assert_true(coin_after >= 0,
		"Coin must not be negative after concurrent combat+gather")


# ---------------------------------------------------------------------------
# Flow 2 — FarrDrainDispatcher: idle Kargar death drains Farr by 1.0.
# Verifies the dispatcher subscribed to unit_health_zero PRE-Dying-swap.
# ---------------------------------------------------------------------------

func test_farr_drain_dispatcher_idle_kargar_death_drains_1() -> void:
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	_kargar_1 = _spawn_kargar(Vector3(0.0, 0.0, 0.0), _mine)
	# Cancel the gather command — keep the worker idle.
	_kargar_1.replace_command(Constants.COMMAND_MOVE, {&"target": Vector3.ZERO})
	# Give it 5 ticks to settle to idle (the Move arrives immediately since
	# the target is the current position via MockPathScheduler).
	harness.advance_ticks(5)
	assert_eq(_kargar_1.fsm.current.id, &"idle",
		"Sanity: Kargar must be idle before kill")

	var farr_before: float = FarrSystem.value_farr
	_kill_unit_in_tick(_kargar_1)
	var farr_after: float = FarrSystem.value_farr

	# Dispatcher reads fsm.current.id == &"idle" PRE-Dying-swap →
	# resolves key "worker_killed_idle" → drain magnitude = 1.0.
	assert_almost_eq(farr_before - farr_after, 1.0, 1e-4,
		"Idle Kargar death must drain Farr by exactly 1.0 "
		+ "(FarrDrainDispatcher reads pre-Dying state; "
		+ "farr_before=" + str(farr_before) + " farr_after=" + str(farr_after) + ")")


# ---------------------------------------------------------------------------
# Flow 3 — FarrDrainDispatcher: gathering Kargar death drains Farr by 0.5.
# ---------------------------------------------------------------------------

func test_farr_drain_dispatcher_gathering_kargar_death_drains_half() -> void:
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	_kargar_1 = _spawn_kargar(Vector3(0.0, 0.0, 0.0), _mine)

	# Drive ticks until the Kargar enters the Gathering state.
	var reached_gathering: bool = false
	for _i in range(30):
		harness.advance_ticks(1)
		if _kargar_1.fsm.current.id == &"gathering":
			reached_gathering = true
			break
	assert_true(reached_gathering,
		"Sanity: Kargar must reach Gathering state within 30 ticks")

	var farr_before: float = FarrSystem.value_farr
	_kill_unit_in_tick(_kargar_1)
	var farr_after: float = FarrSystem.value_farr

	# Dispatcher reads fsm.current.id == &"gathering" PRE-Dying-swap →
	# resolves key "worker_killed_during_gather" → drain magnitude = 0.5.
	assert_almost_eq(farr_before - farr_after, 0.5, 1e-4,
		"Gathering Kargar death must drain Farr by exactly 0.5 "
		+ "(lighter drain — worker was contributing; "
		+ "farr_before=" + str(farr_before) + " farr_after=" + str(farr_after) + ")")


# ---------------------------------------------------------------------------
# Flow 4 — FarrDrainDispatcher: returning Kargar death drains Farr by 0.5.
# The returning case uses the same drain key as gathering per dispatch table.
# ---------------------------------------------------------------------------

func test_farr_drain_dispatcher_returning_kargar_death_drains_half() -> void:
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	_kargar_1 = _spawn_kargar(Vector3(0.0, 0.0, 0.0), _mine)

	# Drive until the Kargar reaches the Returning state (after gathering completes).
	var reached_returning: bool = false
	for _i in range(80):
		harness.advance_ticks(1)
		if _kargar_1.fsm.current.id == &"returning":
			reached_returning = true
			break
	assert_true(reached_returning,
		"Sanity: Kargar must reach Returning state within 80 ticks")

	var farr_before: float = FarrSystem.value_farr
	_kill_unit_in_tick(_kargar_1)
	var farr_after: float = FarrSystem.value_farr

	# Dispatcher reads fsm.current.id == &"returning" PRE-Dying-swap →
	# resolves key "worker_killed_during_gather" → drain magnitude = 0.5.
	assert_almost_eq(farr_before - farr_after, 0.5, 1e-4,
		"Returning Kargar death must drain Farr by exactly 0.5 "
		+ "(same key as gathering — worker was task-engaged; "
		+ "farr_before=" + str(farr_before) + " farr_after=" + str(farr_after) + ")")


# ---------------------------------------------------------------------------
# Flow 5 — Piyade death (combat unit, not a Kargar) does NOT drain Farr.
# Per dispatch table: non-Kargar in any state → drain key = &"" → no drain.
# ---------------------------------------------------------------------------

func test_combat_unit_death_does_not_drain_farr() -> void:
	_iran_piyade_1 = _spawn_iran_piyade(Vector3.ZERO)
	assert_eq(_iran_piyade_1.fsm.current.id, &"idle",
		"Sanity: Piyade starts idle")

	var farr_before: float = FarrSystem.value_farr
	_kill_unit_in_tick(_iran_piyade_1)
	var farr_after: float = FarrSystem.value_farr

	# Piyade idle death: dispatch table returns &"" (non-kargar in idle)
	# → no drain dispatched → Farr unchanged.
	assert_almost_eq(farr_before, farr_after, 1e-4,
		"Piyade (non-worker) idle death must NOT change Farr "
		+ "(combat attrition is not a Farr event in Phase 3; "
		+ "farr_before=" + str(farr_before) + " farr_after=" + str(farr_after) + ")")
