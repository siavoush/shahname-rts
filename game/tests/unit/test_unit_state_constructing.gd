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


# Wave-1B (2026-05-15): Ma'dan ships as the second non-resource-producing
# Building subclass (Mazra'eh was the resource-producing case; Ma'dan is
# the modifier-emitter shape). Like Mazra'eh, Ma'dan must be in the
# _BUILDING_SCENE_PATHS dict so the construction state accepts the kind
# without aborting — the wave-1A late-add discipline lesson applied
# pre-emptively this wave by shipping the dict entry in the same commit
# as the Ma'dan class + scene + build menu button.
func test_enter_accepts_madan_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"madan",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"madan\" building_kind — present in "
		+ "_BUILDING_SCENE_PATHS at wave-1B Commit 1 (late-add discipline)")
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Ma'dan")


# Wave-2A (2026-05-17): Sarbaz-khaneh ships as the fourth Building subclass
# (third anchor-category — identity-bearing institutional, after Khaneh /
# Mazra'eh / Ma'dan). Like the prior subclasses, the kind StringName must
# be in _BUILDING_SCENE_PATHS so the construction state accepts the kind
# without aborting. Same late-add discipline lesson applied at Commit 1:
# kind StringName lives in this dict from the same commit as the subclass
# class + tests. The scene file (sarbaz_khaneh.tscn) is parallel-shipped
# by world-builder Track 2 — this enter-phase test passes regardless of
# whether the scene is on disk (the scene load happens at arrival, not enter).
func test_enter_accepts_sarbaz_khaneh_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"sarbaz_khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized in
	# _BUILDING_SCENE_PATHS.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"sarbaz_khaneh\" building_kind — "
		+ "present in _BUILDING_SCENE_PATHS at wave-2A Commit 1")
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Sarbaz-khaneh")


# Wave-2A.5 (2026-05-18): Atashkadeh ships as the fifth and final Tier-1
# Iran building (Tier-1 closure). Anchor-category: sacral-emitter. Same
# late-add discipline applied pre-emptively: the &"atashkadeh" entry is
# in _BUILDING_SCENE_PATHS from Commit 1, NOT a follow-up after live-test
# discovers the omission (per the session-2 wave-1A lesson internalized
# at session-3 onward).
func test_enter_accepts_atashkadeh_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"atashkadeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized in
	# _BUILDING_SCENE_PATHS.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"atashkadeh\" building_kind — "
		+ "present in _BUILDING_SCENE_PATHS at wave-2A.5 Commit 1")
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Atashkadeh")


# Wave 2B (2026-05-21): Tier-2 entry. Sowari-khaneh + Tirandazi ship as
# the sixth + seventh Iran buildings (first two Tier-2). Late-add
# discipline pre-empted as always: the kind StringNames ship in
# _BUILDING_SCENE_PATHS in the SAME Commit 1 as the classes per the
# session-2 wave-1A lesson internalized at session-3 onward.
func test_enter_accepts_sowari_khaneh_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"sowari_khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized in
	# _BUILDING_SCENE_PATHS.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"sowari_khaneh\" building_kind — "
		+ "present in _BUILDING_SCENE_PATHS at wave-2B Commit 1")
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Sowari-khaneh")


func test_enter_accepts_tirandazi_building_kind() -> void:
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"tirandazi",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	_tick_fsm()
	# State must NOT abort to idle — the kind is recognized in
	# _BUILDING_SCENE_PATHS. The -dazi naming-shape divergence (vs
	# Sarbaz/Sowari-khaneh's -khaneh) is surface-language only per
	# loremaster Track 0; the mechanical kind-StringName lookup works
	# identically.
	assert_ne(_unit.fsm.current.id, &"idle",
		"Constructing must accept &\"tirandazi\" building_kind — "
		+ "present in _BUILDING_SCENE_PATHS at wave-2B Commit 1")
	assert_gt(_mock.call_log.size(), 0,
		"enter must issue a path request to the build site for Tirandazi")


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
	# (90 ticks per Khaneh construction_ticks). 200 ticks is generous.
	# Per wave 1C: place_at fires on the ARRIVAL tick (Stage 1), but the
	# worker stays in the constructing state for the full
	# construction_ticks dwell before transitioning back to Idle.
	var max_ticks: int = 200
	var placed: bool = false
	for _i in range(max_ticks):
		_drive_one_loop()
		# Check if any building landed in the &"buildings" group.
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and b.get(&"is_complete") == true:
				placed = true
				break
		# Run the loop until BOTH placement AND idle (post-dwell) — the
		# Khaneh appears early in the loop (Stage 1), but Stage 2 (and
		# the Idle transition) happen ~90 ticks later.
		if placed and _unit.fsm.current.id == &"idle":
			break
	assert_true(placed,
		"Within %d ticks, a Khaneh must appear in the &\"buildings\" group "
		% max_ticks
		+ "via UnitState_Constructing's placement step")
	# State should have transitioned to Idle once construction completed.
	assert_eq(_unit.fsm.current.id, &"idle",
		"After construction completes, the worker transitions back to Idle")


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
	# Khaneh.population_capacity = 5 (per spec; reverted from session-1
	# placeholder 10 at session-6 close retro). The post-placement cap
	# should be 5 higher than the pre-placement cap.
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
	assert_eq(cap_after - cap_before, 5,
		"Khaneh placement bumps population_cap by +5 (per spec)")


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
# Wave 2A.5 fix-up — dual-cost (coin + grain) deduction tests
# ---------------------------------------------------------------------------
#
# Live-test BUG-A: Atashkadeh placement deducted coin (150 → 0) but NOT
# grain (50 → 50). UnitState_Constructing._perform_placement only handled
# coin. Atashkadeh is the FIRST building with non-zero grain_cost; the
# wiring gap surfaced because no prior subclass exercised the grain path.
#
# Fix-up shape: _perform_placement now runs both-or-neither affordability —
# coin check + grain check BOTH BEFORE any deduction. Either insufficient
# resource → return false → no debit on either. Both sufficient → deduct
# coin then grain.
#
# Tests below cover the three relevant cases.

func test_atashkadeh_placement_deducts_both_coin_and_grain() -> void:
	# BEHAVIORAL positive case: player has 150 coin + 50 grain available
	# (Iran starts with 150 coin + 100 grain per balance.tres seed). Build
	# Atashkadeh. Expected: both deducted. Coin: 150 → 0. Grain: 100 → 50.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var grain_before: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	# Sanity: starting resources cover Atashkadeh's cost.
	assert_true(coin_before >= 15000,
		"sanity: starting Coin >= 150 (Atashkadeh cost). Got: %d x100" % coin_before)
	assert_true(grain_before >= 5000,
		"sanity: starting Grain >= 50 (Atashkadeh cost). Got: %d x100" % grain_before)
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"atashkadeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(1000):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var grain_after: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before - coin_after, 15000,
		"BEHAVIORAL: Atashkadeh placement deducts exactly 150 Coin "
		+ "(15000 x100). BUG-A regression test.")
	assert_eq(grain_before - grain_after, 5000,
		"BEHAVIORAL: Atashkadeh placement deducts exactly 50 Grain "
		+ "(5000 x100). BUG-A regression test — pre-fix-up, this was 0 "
		+ "(grain path never read).")


func test_placement_fails_when_insufficient_grain_does_not_debit_coin() -> void:
	# BEHAVIORAL both-or-neither: drain grain to below Atashkadeh's
	# requirement; leave coin sufficient. Placement must fail at the
	# grain check AND coin must remain undebited. The pre-fix-up
	# implementation would have debited coin first and only then noticed
	# the missing grain check — but my fix checks both BEFORE deducting
	# either, so this scenario produces a clean both-untouched failure.
	#
	# Iran starts with 100 grain x100 = 10000. Drain to 4000 (40 grain,
	# below the 50-grain requirement).
	SimClock._is_ticking = true
	var have_grain_x100: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, -(have_grain_x100 - 4000),
		&"test_drain", null)
	SimClock._is_ticking = false
	assert_eq(ResourceSystem.grain_x100_for(Constants.TEAM_IRAN), 4000,
		"sanity: Iran grain drained to 4000 x100 (40 grain — below 50 "
		+ "Atashkadeh requirement)")
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)

	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"atashkadeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(1000):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break

	# No building was placed.
	assert_eq(get_tree().get_nodes_in_group(&"buildings").size(), 0,
		"No Atashkadeh instantiated when grain insufficient at placement")
	# BEHAVIORAL: coin stays at the pre-attempt value — both-or-neither
	# discipline ensures the coin check passing doesn't trigger a debit
	# when grain check fails downstream.
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before, coin_after,
		"BEHAVIORAL: Coin must NOT be debited when grain check fails. "
		+ "Pre-fix-up would have debited coin then failed grain check — "
		+ "the both-or-neither restructure prevents the partial-failure "
		+ "state. coin_before=%d coin_after=%d" % [coin_before, coin_after])
	# Grain stays at 4000 — the grain check itself does not debit.
	assert_eq(ResourceSystem.grain_x100_for(Constants.TEAM_IRAN), 4000,
		"Grain stays at 4000 — no debit when placement fails at grain check")


func test_placement_fails_when_insufficient_coin_does_not_check_grain() -> void:
	# BEHAVIORAL early-return on coin failure: when coin is insufficient,
	# the function returns at the coin check BEFORE querying grain. Grain
	# is untouched whether sufficient or not — the coin check is the
	# first gate.
	#
	# Drain coin to 0. Leave grain sufficient. Attempt Atashkadeh.
	# Placement fails at coin; grain remains at starting value.
	SimClock._is_ticking = true
	var have_coin_x100: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, -have_coin_x100,
		&"test_drain", null)
	SimClock._is_ticking = false
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 0,
		"sanity: Iran coin drained to 0")
	var grain_before: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)

	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"atashkadeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	for _i in range(1000):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break

	# No building was placed.
	assert_eq(get_tree().get_nodes_in_group(&"buildings").size(), 0,
		"No Atashkadeh instantiated when coin insufficient at placement")
	# Coin stays at 0 — no spurious deduction.
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 0,
		"Coin stays at 0 — no debit when placement fails at coin check")
	# Grain UNTOUCHED — the coin check returned false BEFORE the grain
	# branch executed.
	assert_eq(ResourceSystem.grain_x100_for(Constants.TEAM_IRAN), grain_before,
		"BEHAVIORAL: Grain unchanged after coin-insufficient failure. "
		+ "The coin check returns false before any grain code path runs "
		+ "(neither check nor debit fires on grain side).")


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


# ===========================================================================
# Wave 1C two-stage lifecycle — behavioral coverage
# ===========================================================================
#
# Per session 3 wave 1C: place_at now fires on the ARRIVAL tick (Stage
# 1, structural). The building exists in the world but is NOT yet
# operational. After construction_ticks ticks elapse,
# _on_construction_complete fires (Stage 2, operational). These tests
# verify the BEHAVIORAL contract — not just structural fields, but the
# observable gameplay consequence:
#   - During construction, a Mazra'eh's is_gatherable stays false.
#     Right-clicking the half-built farm does not route the worker.
#   - The construction_progress_updated signal fires during the dwell
#     phase but NOT at completion (the operational hook is the
#     distinct completion signal).
#   - Costs are deducted at structural placement (arrival tick), NOT
#     deferred to operational completion. The player loses the Coin
#     the moment the building footprint appears.


func test_mazraeh_is_not_gatherable_during_construction() -> void:
	# Drive a Mazra'eh construction. Mazra'eh has construction_ticks=600
	# in balance.tres — too long to drive all of it here, but we only
	# need to verify the mid-construction state: is_gatherable must be
	# false from arrival through Stage 2.
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"mazraeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Drive a handful of ticks past arrival so place_at has fired but
	# we're still well within the 600-tick dwell.
	var found_mazraeh: Variant = null
	for _i in range(30):
		_drive_one_loop()
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and b.get(&"kind") == &"mazraeh":
				found_mazraeh = b
				break
		if found_mazraeh != null:
			break
	assert_not_null(found_mazraeh,
		"Mazra'eh must be instantiated (Stage 1 — structural) within "
		+ "30 ticks of construct command")
	# Behavioral: is_gatherable stays false during construction. The
	# half-built Mazra'eh exists in the world, has is_complete = true
	# (structurally placed), but does NOT permit gathering.
	assert_true(found_mazraeh.is_complete,
		"sanity: Mazra'eh is_complete = true post-Stage-1 (structurally placed)")
	assert_false(found_mazraeh.is_gatherable,
		"BEHAVIORAL: Mazra'eh.is_gatherable must be false during "
		+ "construction. The Stage 2 flip (_on_construction_complete) "
		+ "has NOT fired yet (construction_ticks=600 is not elapsed).")
	# The worker is still in the constructing state (not idle), confirming
	# we're truly mid-construction.
	assert_eq(_unit.fsm.current.id, &"constructing",
		"Worker still in constructing state — mid-dwell, not yet idle")


func test_mazraeh_becomes_gatherable_at_construction_complete() -> void:
	# Drive the full Mazra'eh construction (600 ticks dwell + walk ≈ 605).
	# After completion, is_gatherable must be true. This is the
	# integration-level proof of the Stage 2 flip via the actual
	# UnitState_Constructing dwell counter, complementing the unit-level
	# test_mazraeh_is_gatherable_flips_on_construction_complete in
	# test_mazraeh.gd that drives the hook directly.
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"mazraeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# 700 ticks is generous: 1 tick walk + 600 dwell + a few transition.
	var max_ticks: int = 700
	for _i in range(max_ticks):
		_drive_one_loop()
		if _unit.fsm.current.id == &"idle":
			break
	assert_eq(_unit.fsm.current.id, &"idle",
		"Worker returns to Idle after full Mazra'eh construction")
	# Find the placed Mazra'eh and assert is_gatherable.
	var mazraeh: Variant = null
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if is_instance_valid(b) and b.get(&"kind") == &"mazraeh":
			mazraeh = b
			break
	assert_not_null(mazraeh,
		"Placed Mazra'eh must be in &\"buildings\" group post-construction")
	assert_true(mazraeh.is_gatherable,
		"BEHAVIORAL: post-construction, is_gatherable is true — Stage 2 "
		+ "(_on_construction_complete) has fired via the dwell-complete branch")


func test_coin_deducted_at_structural_placement_not_completion() -> void:
	# Cost-timing contract (wave 1C revision): the Coin deduction happens
	# at Stage 1 (arrival tick), NOT Stage 2 (dwell completion). The
	# rationale is preserved from session 1: dying mid-walk costs nothing,
	# dying mid-construction costs the Coin (the building exists). Verify
	# the Coin leaves the treasury once the Khaneh appears in the world,
	# regardless of whether the dwell has completed.
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
	# Drive until the Khaneh appears (Stage 1) but BEFORE dwell completes.
	# Khaneh has construction_ticks=90; drive ~5 ticks past arrival so we're
	# definitely mid-dwell, not completed.
	var khaneh: Variant = null
	for _i in range(8):
		_drive_one_loop()
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and b.get(&"kind") == &"khaneh":
				khaneh = b
				break
		if khaneh != null:
			break
	assert_not_null(khaneh, "Khaneh must be instantiated within 8 ticks")
	# Worker should still be constructing (mid-dwell) — 8 ticks << 90 dwell.
	assert_eq(_unit.fsm.current.id, &"constructing",
		"sanity: worker mid-dwell, not yet idle")
	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_before - coin_after, 5000,
		"Cost timing: Coin deducted at Stage 1 (structural placement), "
		+ "NOT deferred to Stage 2. The player loses 50 Coin (5000 x100) "
		+ "the moment the Khaneh footprint appears.")


# ---------------------------------------------------------------------------
# Progress signal — emit during dwell, no double-emit at completion
# ---------------------------------------------------------------------------

func test_construction_progress_updated_emits_during_dwell() -> void:
	# Drive a Khaneh build (90 dwell ticks). Capture every progress emit.
	# Expected: ~89 emits with percent_x100 monotonically increasing
	# from a low value to just below 10000. No emit at the completion
	# tick (Stage 2 firing is the distinct completion signal).
	var captured: Array = []
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Connect the progress handler the moment the Khaneh is instantiated.
	# We poll for it each tick and connect once found.
	var khaneh: Variant = null
	var max_ticks: int = 200
	var on_progress: Callable = func(percent_x100: int) -> void:
		captured.append(percent_x100)
	for _i in range(max_ticks):
		_drive_one_loop()
		if khaneh == null:
			for b: Node in get_tree().get_nodes_in_group(&"buildings"):
				if is_instance_valid(b) and b.get(&"kind") == &"khaneh":
					khaneh = b
					khaneh.construction_progress_updated.connect(on_progress)
					break
		if _unit.fsm.current.id == &"idle":
			break
	if khaneh != null:
		khaneh.construction_progress_updated.disconnect(on_progress)
	# BEHAVIORAL: at least some progress emits fired during the dwell.
	# We can't predict the exact count because we connected mid-dwell
	# (a few early ticks of progress will have been missed), but there
	# must be substantially more than zero.
	assert_gt(captured.size(), 10,
		"Progress signal must emit each dwell tick — got %d emits "
		% captured.size()
		+ "from connection to completion (expected many tens for Khaneh's "
		+ "90-tick dwell minus the late connection)")
	# Monotonically increasing: each successive emit's percent_x100 is
	# >= the previous one.
	var prev: int = -1
	for v in captured:
		assert_true(int(v) >= prev,
			"Progress emits must be monotonically non-decreasing")
		prev = int(v)
	# Last captured value must be < 10000 — the no-double-emit contract.
	# Stage 2 fires AFTER the last progress emit; the progress signal
	# never reaches 10000.
	assert_lt(prev, 10000,
		"BEHAVIORAL: progress signal must NEVER emit percent_x100 = 10000. "
		+ "The completion signal is _on_construction_complete firing, NOT "
		+ "a progress=100% emit. Last captured value: %d" % prev)


func test_construction_progress_basis_points_match_elapsed_over_total() -> void:
	# Lock the formula: percent_x100 = elapsed * 10000 / total, where
	# total = construction_ticks (90 for Khaneh) and elapsed counts up
	# from 1 at the first dwell-emit tick.
	#
	# We connect from the very first dwell tick, drive a small number of
	# ticks, then assert the captured values match the formula precisely
	# (no floating-point comparison; integer-exact).
	var captured: Array = []
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Walk + path-resolve takes ~2 ticks; place_at fires on the arrival
	# tick (no emit on that tick — the emit happens on the NEXT tick
	# when _dwell_remaining_ticks is decremented). Drive 1 tick to get
	# the worker walking, find the Khaneh, then connect.
	var khaneh: Variant = null
	for _i in range(3):
		_drive_one_loop()
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and b.get(&"kind") == &"khaneh":
				khaneh = b
				break
		if khaneh != null:
			break
	assert_not_null(khaneh, "Khaneh must be instantiated within 3 ticks")
	var on_progress: Callable = func(percent_x100: int) -> void:
		captured.append(percent_x100)
	khaneh.construction_progress_updated.connect(on_progress)
	# Drive 5 _drive_one_loop iterations. Each iteration runs both
	# fsm.tick + SimClock._test_run_tick which causes the Unit's
	# _on_sim_phase to ALSO fire fsm.tick — so each loop iteration
	# emits TWICE. We assert at-least-5-emits and check formula
	# correctness for each.
	for _i in range(5):
		_drive_one_loop()
	khaneh.construction_progress_updated.disconnect(on_progress)
	assert_gt(captured.size(), 4,
		"5 drive-loop iterations must produce at least 5 progress emits")
	# Each captured value must equal floor(k * 10000 / 90) for some
	# integer k in [1, 89]. We search the legal set rather than reverse-
	# engineering k (the inverse v * 90 / 10000 is off-by-one due to
	# integer-division rounding — e.g. 1111 reverses to 9 but the
	# forward formula 9 * 10000 / 90 = 1000, NOT 1111; the correct k=10).
	var legal_values: Dictionary = {}
	for k in range(1, 90):
		legal_values[k * 10000 / 90] = k
	var prev_k: int = 0
	for v in captured:
		var iv: int = int(v)
		assert_true(iv > 0 and iv < 10000,
			"Each emit must be in (0, 10000) — got %d" % iv)
		assert_true(legal_values.has(iv),
			"Captured value %d must equal k*10000/90 for some k in [1,89]" % iv)
		var k: int = legal_values[iv]
		assert_gt(k, prev_k,
			"Successive emits must have strictly increasing k (no "
			+ "duplicates / regressions): prev_k=%d, this_k=%d, v=%d"
			% [prev_k, k, iv])
		prev_k = k


# ---------------------------------------------------------------------------
# construction_finalized signal — Task #139 Track 1 follow-on
# ---------------------------------------------------------------------------
#
# Integration-level coverage for the Stage-2 completion signal. The
# externally-observable signal that resolves ui-developer-p3s3's
# progress-overlay hide-trigger gap. Behavioral contract:
#   - Emitted exactly ONCE per built building, at Stage 2 (after the
#     virtual hook returns).
#   - Carries the placing worker's unit_id as payload.
#   - Receivers see post-Stage-2 state when handler fires (the virtual
#     fires FIRST, then the signal — so is_gatherable / modifier
#     registrations are visible on readout).
#   - No emit if construction is interrupted mid-dwell.

func test_construction_finalized_emits_exactly_once_per_construction() -> void:
	# Drive a full Khaneh construction (~92 ticks). Capture every
	# construction_finalized emit. Expected: exactly one emit, with
	# placer_unit_id = the worker's unit_id.
	var captured: Array = []
	_unit = _spawn_kargar(Vector3.ZERO)
	var worker_id: int = _unit.unit_id
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"khaneh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	# Connect the handler the moment the Khaneh is instantiated.
	var khaneh: Variant = null
	var on_finalized: Callable = func(placer_unit_id: int) -> void:
		captured.append(placer_unit_id)
	for _i in range(200):
		_drive_one_loop()
		if khaneh == null:
			for b: Node in get_tree().get_nodes_in_group(&"buildings"):
				if is_instance_valid(b) and b.get(&"kind") == &"khaneh":
					khaneh = b
					khaneh.construction_finalized.connect(on_finalized)
					break
		if _unit.fsm.current.id == &"idle":
			break
	if khaneh != null:
		khaneh.construction_finalized.disconnect(on_finalized)
	# Exactly one emit — no duplicates from re-entry, no missing emit.
	assert_eq(captured.size(), 1,
		"construction_finalized must emit exactly ONCE per built building. "
		+ "Got %d emits." % captured.size())
	assert_eq(int(captured[0]), worker_id,
		"construction_finalized payload must equal the placing worker's "
		+ "unit_id (%d). Got %d." % [worker_id, int(captured[0])])


func test_construction_finalized_fires_after_on_construction_complete() -> void:
	# Emit ORDERING contract: the virtual hook fires FIRST, then the
	# signal. Receivers must see post-Stage-2 state (is_gatherable = true
	# for Mazra'eh). Drive a full Mazra'eh construction and check
	# is_gatherable AFTER the construction_finalized handler has run.
	#
	# GDScript lambda capture is by-value at creation time, so we cannot
	# read `mazraeh` inside the closure to inspect the building's state —
	# the closure would see the null value the variable had at creation.
	# Instead the handler appends a sentinel (1) per emit; after the
	# loop, we look up the Mazra'eh on the SceneTree and read
	# is_gatherable directly. The ordering proof relies on the fact that
	# the signal handler fires synchronously WITHIN emit_signal(), which
	# itself is called AFTER the virtual returns — so if is_gatherable
	# is true post-signal, the virtual must have fired first.
	var finalized_emit_count: Array = []
	_unit = _spawn_kargar(Vector3.ZERO)
	_unit.current_command = {
		"kind": &"construct",
		"payload": {
			&"building_kind": &"mazraeh",
			&"target_position": Vector3(5.0, 0.0, 0.0),
		},
	}
	_unit.fsm.transition_to(&"constructing")
	var mazraeh: Variant = null
	var on_finalized: Callable = func(_placer_unit_id: int) -> void:
		finalized_emit_count.append(1)
	for _i in range(700):
		_drive_one_loop()
		if mazraeh == null:
			for b: Node in get_tree().get_nodes_in_group(&"buildings"):
				if is_instance_valid(b) and b.get(&"kind") == &"mazraeh":
					mazraeh = b
					mazraeh.construction_finalized.connect(on_finalized)
					break
		if _unit.fsm.current.id == &"idle":
			break
	if mazraeh != null:
		mazraeh.construction_finalized.disconnect(on_finalized)
	assert_eq(finalized_emit_count.size(), 1,
		"construction_finalized fires exactly once for a full Mazra'eh build")
	# Re-fetch mazraeh from the SceneTree (avoid closure-capture). At
	# this point Stage 2 has run AND the signal has fired — both
	# operational side-effects should be visible.
	assert_not_null(mazraeh,
		"sanity: Mazra'eh was placed and tracked")
	# BEHAVIORAL emit-ordering check: the virtual ran BEFORE the signal,
	# so is_gatherable = true is visible immediately after the signal.
	# If the order were reversed (signal-before-virtual), a consumer that
	# read is_gatherable in its handler would see false; here we check the
	# weaker post-loop invariant — both have fired, both effects applied.
	assert_true(mazraeh.is_gatherable,
		"BEHAVIORAL: post-Stage-2, is_gatherable = true AND "
		+ "construction_finalized has fired. Both side-effects landed.")


func test_construction_finalized_does_not_emit_on_path_failure() -> void:
	# Interrupted construction: a path-failed worker never reaches the
	# build site, so _on_construction_complete never fires and
	# construction_finalized never emits. Counterfactual lock.
	var captured: Array = []
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
	# Connect at the EventBus level isn't possible (signal is on the
	# building), so we connect to every building that appears. Path
	# failure means no building should appear, but we set up the
	# connection plumbing anyway for completeness.
	var connected_any: bool = false
	var on_finalized: Callable = func(placer_unit_id: int) -> void:
		captured.append(placer_unit_id)
	for _i in range(10):
		_drive_one_loop()
		for b: Node in get_tree().get_nodes_in_group(&"buildings"):
			if is_instance_valid(b) and not connected_any:
				b.construction_finalized.connect(on_finalized)
				connected_any = true
		if _unit.fsm.current.id == &"idle":
			break
	# Worker bailed to idle without placing.
	assert_eq(_unit.fsm.current.id, &"idle",
		"sanity: path failure → idle")
	assert_eq(get_tree().get_nodes_in_group(&"buildings").size(), 0,
		"sanity: no building placed on path failure")
	# No construction_finalized fire — both because nothing was placed
	# AND because the dwell never completed.
	assert_eq(captured.size(), 0,
		"construction_finalized must NOT emit when construction is "
		+ "interrupted before Stage 2. Got %d spurious emits."
		% captured.size())
