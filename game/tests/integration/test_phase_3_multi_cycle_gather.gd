# Integration test — Phase 3 wave 3 (1/5): multi-cycle gather loop stability.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 "Wave 3" target 1.
# The single-cycle case (gather → deposit credits coin, emits resource_changed)
# is covered by test_phase_3_gather_loop.gd. THIS file exercises loop stability
# over ≥3 complete gather→deposit cycles and verifies:
#   (a) cumulative coin total = initial + (N × yield_per_trip)
#   (b) _carry_amount_x100 resets to 0 after each deposit
#   (c) _carry_kind resets to &"" after each deposit
#
# Pitfall #11: never use is_instance_valid as a death-detection predicate in
# SimClock._test_run_tick loops. Not relevant here (no combat), but noted per
# permanent per-file contract.
#
# Pitfall #2: FSM / per-tick driver. We drive fsm.tick + advance_ticks(1)
# via _drive_loop_ticks(n) — same pattern as test_phase_3_gather_loop.gd.
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
	# High speed so walks complete within tick budgets.
	u.get_movement().move_speed = 100.0
	return u


func _spawn_mine(pos: Vector3 = Vector3(5.0, 0.0, 0.0)) -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	# Short dwell so tests stay tight; long enough for reserves not to
	# deplete before 3 trips (default reserves >> 3 extracts).
	m.extract_ticks = 2
	return m


func _drive_loop_ticks(n: int) -> void:
	for i in range(n):
		SimClock._is_ticking = true
		_kargar.fsm.tick(SimClock.SIM_DT)
		SimClock._is_ticking = false
		harness.advance_ticks(1)


# ---------------------------------------------------------------------------
# Flow 1 — Three complete gather→deposit cycles. Cumulative coin must equal
# initial_coin + 3 × yield_per_trip.
# ---------------------------------------------------------------------------

func test_three_cycles_cumulative_coin_matches_3x_yield() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))

	var coin_start: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	# Yield per trip is fixed by BalanceData (mine_node.gd reads it). The
	# single-cycle test verifies the value is 1000 (10 Coin × 100). We
	# derive it from the first deposit rather than hardcoding so this test
	# stays valid if BalanceData is retuned.
	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)

	# Drive until three deposits have landed.
	var deposit_count: int = 0
	var yield_per_trip: int = -1
	var last_coin: int = coin_start

	for _i in range(600):
		_drive_loop_ticks(1)
		var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
		if coin_now > last_coin:
			deposit_count += 1
			if yield_per_trip == -1:
				yield_per_trip = coin_now - last_coin
			last_coin = coin_now
		if deposit_count >= 3:
			break

	assert_eq(deposit_count, 3,
		"Worker must complete 3 full gather→deposit cycles within tick budget")
	assert_gt(yield_per_trip, 0,
		"yield_per_trip must be > 0 (BalanceData not missing)")

	var coin_end: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_end - coin_start, 3 * yield_per_trip,
		"After 3 cycles: cumulative coin delta = 3 × yield_per_trip "
		+ "(no leak, no double-credit)")


# ---------------------------------------------------------------------------
# Flow 2 — _carry_amount_x100 resets to 0 after each deposit.
# ---------------------------------------------------------------------------

func test_carry_amount_resets_to_zero_after_each_deposit() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))

	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)

	# Track: at the tick after each deposit, carry must be 0.
	var deposit_count: int = 0
	var carry_nonzero_after_deposit: int = 0
	var last_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)

	for _i in range(600):
		_drive_loop_ticks(1)
		var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
		if coin_now > last_coin:
			deposit_count += 1
			last_coin = coin_now
			# The deposit step (UnitState_Returning._perform_deposit) zeroes
			# _carry_amount_x100 in the SAME tick it calls change_resource.
			# By the time we read here (one _drive_loop_ticks later), the
			# reset has happened.
			var carry: int = int(_kargar.get(&"_carry_amount_x100"))
			if carry != 0:
				carry_nonzero_after_deposit += 1
		if deposit_count >= 3:
			break

	assert_eq(deposit_count, 3,
		"Sanity: 3 cycles completed")
	assert_eq(carry_nonzero_after_deposit, 0,
		"_carry_amount_x100 must be 0 after each deposit (no carry leak between cycles)")


# ---------------------------------------------------------------------------
# Flow 3 — _carry_kind resets to &"" after each deposit.
# ---------------------------------------------------------------------------

func test_carry_kind_resets_to_empty_after_each_deposit() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))

	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)

	var deposit_count: int = 0
	var kind_nonempty_after_deposit: int = 0
	var last_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)

	for _i in range(600):
		_drive_loop_ticks(1)
		var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
		if coin_now > last_coin:
			deposit_count += 1
			last_coin = coin_now
			var kind: StringName = _kargar.get(&"_carry_kind")
			if kind != &"":
				kind_nonempty_after_deposit += 1
		if deposit_count >= 3:
			break

	assert_eq(deposit_count, 3,
		"Sanity: 3 cycles completed")
	assert_eq(kind_nonempty_after_deposit, 0,
		"_carry_kind must be &\"\" after each deposit (no stale kind between cycles)")


# ---------------------------------------------------------------------------
# Flow 4 — Loop persists when mine still has reserves after 3 trips.
# Transition after cycle 3 should be back to gathering, not idle.
# ---------------------------------------------------------------------------

func test_worker_stays_in_gather_loop_not_idle_while_mine_has_reserves() -> void:
	_kargar = _spawn_kargar(Vector3.ZERO)
	_mine = _spawn_mine(Vector3(5.0, 0.0, 0.0))
	# Give the mine plenty of reserves (default MineNode reserves >> 10 trips).
	_kargar.replace_command(
		Constants.COMMAND_GATHER,
		{&"target_node": _mine},
	)

	var deposit_count: int = 0
	var last_coin: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)

	for _i in range(600):
		_drive_loop_ticks(1)
		var coin_now: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
		if coin_now > last_coin:
			deposit_count += 1
			last_coin = coin_now
		if deposit_count >= 3:
			break

	assert_eq(deposit_count, 3, "Sanity: 3 cycles completed")
	# Worker should be in gathering or returning, not idle — the loop
	# continues while the mine has reserves.
	var fsm_id: StringName = _kargar.fsm.current.id
	assert_true(
		fsm_id == &"gathering" or fsm_id == &"returning",
		"Worker must stay in gather/return loop (not &\"idle\") while mine has reserves. "
		+ "Actual state: " + str(fsm_id)
	)
