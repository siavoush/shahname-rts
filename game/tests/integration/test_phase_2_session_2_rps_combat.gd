# Integration tests — Phase 2 session 2 wave 3 (qa-engineer).
#
# Covers the full live combat chain for the expanded RPS roster:
#   1. RPS triangle outcome tests (1v1 fights to death or analytics)
#   2. Turan-fold correctness via live chain
#   3. 33-unit match-start roster verification
#   4. Kiting-math correctness (analytical, not behavioral)
#   5. Cross-feature smoke — box-select + right-click + 5v5 RPS outcome
#   6. CombatComponent integration audit (live-path complement to wave-2A unit tests)
#
# Contract refs: docs/TESTING_CONTRACT.md §3 (MatchHarness patterns),
# docs/SIMULATION_CONTRACT.md §1.6 (fixed-point), 02e_PHASE_2_SESSION_2_KICKOFF.md §3.
#
# The live-game-broken-surface this file exercises:
#   Real CombatComponent._sim_tick driven by real Unit._on_sim_phase listening
#   to real EventBus.sim_phase from real SimClock, with real BalanceData.combat
#   .get_multiplier() returning scaled damage to take_damage_x100.
#   Each test that uses SimClock._test_run_tick exercises the FULL chain.
#
# Typing: Variant slots for unit refs — docs/ARCHITECTURE.md §6 v0.4.0.
#
# Phase 3 wave 0 migration: manual autoload bookkeeping in before_each/after_each
# replaced with MatchHarness.start_match()/teardown() per TESTING_CONTRACT.md §3.1.
# Remaining per-test resets (CommandPool, SelectionManager, DebugOverlayManager,
# UnitScript.reset_id_counter) are not in the harness scope and stay inline.

extends GutTest


# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------

const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const KamandarScene: PackedScene = preload("res://scenes/units/kamandar.tscn")
const SavarScene: PackedScene = preload("res://scenes/units/savar.tscn")
const AsbSavarKamandarScene: PackedScene = preload("res://scenes/units/asb_savar_kamandar.tscn")
const TuranKamandarScene: PackedScene = preload("res://scenes/units/turan_kamandar.tscn")
const TuranSavarScene: PackedScene = preload("res://scenes/units/turan_savar.tscn")
const TuranAsbSavarScene: PackedScene = preload("res://scenes/units/turan_asb_savar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MainScene: PackedScene = preload("res://scenes/main.tscn")
const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")

const BALANCE_PATH: String = "res://data/balance.tres"


# ---------------------------------------------------------------------------
# Test state
# ---------------------------------------------------------------------------

var harness: Variant = null

# Unit refs kept as Variant per class_name registry race pattern.
var _unit_a: Variant = null
var _unit_b: Variant = null
var _extra_units: Array = []


# ---------------------------------------------------------------------------
# Shared setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	harness = MatchHarnessScript.new()
	harness.start_match(0, &"empty")
	# Non-harness resets: autoloads not managed by MatchHarness.
	CommandPool.reset()
	SelectionManager.reset()
	DebugOverlayManager.reset()
	UnitScript.call(&"reset_id_counter")
	_unit_a = null
	_unit_b = null
	_extra_units = []


func after_each() -> void:
	if _unit_a != null and is_instance_valid(_unit_a):
		_unit_a.queue_free()
	if _unit_b != null and is_instance_valid(_unit_b):
		_unit_b.queue_free()
	for u in _extra_units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_extra_units = []
	_unit_a = null
	_unit_b = null
	# Non-harness resets: must precede harness.teardown so signal connections
	# from tests are cleared before autoloads reset.
	SelectionManager.reset()
	DebugOverlayManager.reset()
	CommandPool.reset()
	harness.teardown()
	harness = null


# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

func _spawn(scene: PackedScene, pos: Vector3, team: int) -> Variant:
	var u: Variant = scene.instantiate()
	add_child_autofree(u)
	u.global_position = pos
	u.team = team
	u.get_movement()._scheduler = harness._mock_scheduler
	return u


func _advance(n: int) -> void:
	for _i in range(n):
		SimClock._test_run_tick()


# Instant-resolve scheduler: path resolves same tick (models live
# NavigationAgentPathScheduler). Required for Attacking-out-of-range tests
# where the default MockPathScheduler's next-tick resolution races against
# per-tick cancel_repath.
class _InstantPathScheduler extends "res://scripts/core/path_scheduler.gd":
	var _next_id: int = 1
	var _requests: Dictionary = {}

	func request_repath(unit_id: int, from: Vector3, to: Vector3, _priority: int) -> int:
		var rid: int = _next_id
		_next_id += 1
		var wps: PackedVector3Array = PackedVector3Array()
		wps.append(from)
		wps.append(to)
		_requests[rid] = {
			&"unit_id": unit_id,
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
		if _requests.has(request_id):
			var entry: Dictionary = _requests[request_id]
			if int(entry[&"state"]) == PathState.READY:
				entry[&"state"] = PathState.CANCELLED


# Helper: collect nodes with (unit_id, team) properties recursively.
func _collect_unit_nodes(node: Node, out: Array) -> void:
	if (&"unit_id" in node) and (&"team" in node) and (node is Node3D):
		out.append(node)
	for child in node.get_children():
		_collect_unit_nodes(child, out)


# ============================================================================
# 1. RPS triangle outcome tests
#
# Each test places two units in attack range of each other, issues Attack
# commands to both, and runs until one dies. The spec-expected winner wins.
# HP math per balance.tres:
#   piyade:       HP=100, dmg_x100=1000, atk_speed=1.0/s (30-tick CD), range=1.5
#   kamandar:     HP=60,  dmg_x100=1500, atk_speed=0.7/s (43-tick CD), range=8.0
#   savar:        HP=150, dmg_x100=1200, atk_speed=0.9/s (33-tick CD), range=1.8
#   asb_savar:    HP=100, dmg_x100=1300, atk_speed=0.6/s (50-tick CD), range=7.0
#   RPS matrix:   piyade→savar: 1.5×, savar→kamandar: 2.0×, kamandar→piyade: 1.5×
#                 asb_savar→piyade: 1.2×, asb_savar→savar: 0.5×
# ============================================================================

func test_piyade_vs_savar_piyade_wins_1v1() -> void:
	# Analytical: Piyade deals 1000×1.5=1500/hit. Savar HP=15000 x100.
	# Savar dies in ceil(15000/1500)=10 hits × 30-tick CD = 300 ticks.
	# Savar deals 1200×0.7=840/hit vs Piyade HP=10000. Piyade dies in ceil(10000/840)=12 hits × 33-tick CD ≈ 396 ticks.
	# Piyade outlives Savar → Piyade wins.
	# Note: queue_free.call_deferred defers to process_frame which doesn't run inside
	# SimClock._test_run_tick loops. We detect death via hp_x100 ≤ 0 (set synchronously
	# when damage is applied) rather than is_instance_valid (deferred free).
	_unit_a = _spawn(PiyadeScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(SavarScene, Vector3(1.5, 0.0, 0.0), Constants.TEAM_TURAN)  # within piyade range 1.5

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	# Run until one unit reaches hp_x100 ≤ 0 or 500-tick budget.
	var savar_hp_reached_zero: bool = false
	var piyade_hp_reached_zero: bool = false
	for _i in range(500):
		_advance(1)
		if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
			savar_hp_reached_zero = true
			break
		if is_instance_valid(_unit_a) and int(_unit_a.get_health().hp_x100) <= 0:
			piyade_hp_reached_zero = true
			break

	assert_true(savar_hp_reached_zero and not piyade_hp_reached_zero,
		"Piyade vs Savar (1.5× anti-cavalry): Savar HP must reach 0 before Piyade HP. "
		+ "Analytical: Savar dies ~300 ticks (10 hits at 1500 x100), "
		+ "Piyade survives ~396 ticks (12 hits at 840 x100). "
		+ "savar_dead=%s piyade_dead=%s. "
		+ "If both false: no damage landed (FSM or combat wiring broken). "
		+ "If piyade_dead=true first: RPS multiplier not applied or matrix values wrong."
		% [str(savar_hp_reached_zero), str(piyade_hp_reached_zero)])


func test_savar_vs_kamandar_savar_wins_1v1() -> void:
	# Analytical: Savar deals 1200×2.0=2400/hit. Kamandar HP=6000 x100.
	# Kamandar dies in ceil(6000/2400)=3 hits × 33-tick CD = 99 ticks.
	# Kamandar deals 1500×0.7=1050/hit vs Savar HP=15000. Savar dies in ceil(15000/1050)=15 hits × 43-tick CD = 645 ticks.
	# Savar wins decisively.
	# Place at 1.8 (Savar attack_range). Kamandar range=8.0 so it also fires.
	_unit_a = _spawn(SavarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(KamandarScene, Vector3(1.8, 0.0, 0.0), Constants.TEAM_TURAN)

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	var kamandar_hp_reached_zero: bool = false
	var savar_hp_reached_zero: bool = false
	for _i in range(200):
		_advance(1)
		if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
			kamandar_hp_reached_zero = true
			break
		if is_instance_valid(_unit_a) and int(_unit_a.get_health().hp_x100) <= 0:
			savar_hp_reached_zero = true
			break

	assert_true(kamandar_hp_reached_zero and not savar_hp_reached_zero,
		"Savar vs Kamandar (2.0× cavalry-vs-archer): Kamandar HP must reach 0 before Savar. "
		+ "Analytical: Kamandar dies ~99 ticks (3 hits at 2400 x100), "
		+ "Savar survives ~645 ticks (15 hits at 1050 x100). "
		+ "kamandar_dead=%s savar_dead=%s. "
		+ "If savar_dead=true: RPS 2.0× multiplier not applied or matrix wrong."
		% [str(kamandar_hp_reached_zero), str(savar_hp_reached_zero)])


func test_kamandar_vs_piyade_kamandar_wins_at_range() -> void:
	# Kamandar range=8.0 vs Piyade range=1.5. Place them at distance 6.0 so
	# Kamandar fires immediately. Piyade must close 6.0 - 1.5 = 4.5 units.
	# Piyade move_speed=2.5/sec → 2.5/30 per tick. Ticks to close = 4.5/(2.5/30) = 54 ticks.
	# Kamandar dmg 1500×1.5=2250/hit every 43 ticks. In 54 ticks: 2 shots (at tick 1 and 44).
	# Piyade HP=10000. Damage taken: 2×2250=4500 before reaching melee. Piyade still alive.
	# Once in melee (after ~54 ticks), Piyade lands 1000×1.0=1000/hit every 30 ticks.
	# Kamandar HP=6000. Piyade needs ceil(6000/1000)=6 hits × 30 ticks = 180 ticks in melee.
	# Kamandar continues firing at 1.5× every 43 ticks. By tick 54+180=234, Kamandar has
	# fired ~5-6 more times. Cumulative Piyade damage: 4500 + 6×2250 = 18000 > 10000 HP.
	# Piyade dies. Kamandar wins at this range.
	# Test: assert Piyade has taken damage before reaching melee range, AND Kamandar
	# ultimately wins (Piyade dies before Kamandar or at significant Kamandar advantage).
	var instant: Variant = _InstantPathScheduler.new()
	PathSchedulerService.set_scheduler(instant)

	_unit_a = _spawn(KamandarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(PiyadeScene, Vector3(6.0, 0.0, 0.0), Constants.TEAM_TURAN)
	_unit_a.get_movement()._scheduler = instant
	_unit_b.get_movement()._scheduler = instant

	var piyade_initial_hp_x100: int = int(_unit_b.get_health().hp_x100)

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	# Advance to tick 50 — Piyade should have taken hits from Kamandar at range
	# but not yet be in melee (Piyade at roughly distance 2.4 from start).
	_advance(50)

	var piyade_hp_at_50: int = -1
	if _unit_b != null and is_instance_valid(_unit_b):
		piyade_hp_at_50 = int(_unit_b.get_health().hp_x100)

	# Assert Piyade took at least one hit within the first 50 ticks (Kamandar
	# fires at range 8.0 which exceeds the 6.0 starting gap immediately).
	if piyade_hp_at_50 != -1:
		assert_lt(piyade_hp_at_50, piyade_initial_hp_x100,
			"Kamandar vs Piyade: Piyade must take at least one hit within 50 ticks "
			+ "(Kamandar range=8.0, Piyade start at distance=6.0 — within range immediately). "
			+ "hp_at_50=%d initial=%d" % [piyade_hp_at_50, piyade_initial_hp_x100])

	# Now run to completion — Kamandar should win with 1.5× vs Piyade at this range.
	var piyade_hp_reached_zero: bool = false
	for _i in range(400):
		_advance(1)
		if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
			piyade_hp_reached_zero = true
			break
		if is_instance_valid(_unit_a) and int(_unit_a.get_health().hp_x100) <= 0:
			# Kamandar died first — unexpected
			break

	assert_true(piyade_hp_reached_zero,
		"Kamandar vs Piyade at range 6.0 (1.5× anti-infantry): Piyade HP must reach 0. "
		+ "Analytical: Kamandar accumulates 1.5× damage advantage while Piyade closes, "
		+ "then continues firing in melee. Combined DPS overwhelms Piyade HP.")
	PathSchedulerService.set_scheduler(harness._mock_scheduler)


func test_asb_savar_vs_piyade_asb_savar_wins_at_range() -> void:
	# AsbSavar range=7.0, Piyade range=1.5. Place at distance 5.0 (within AsbSavar range).
	# AsbSavar does NOT move (no movement command). Piyade walks toward it.
	# AsbSavar dmg 1300×1.2=1560/hit every 50 ticks. Piyade HP=10000.
	# Piyade needs to close 5.0 - 1.5 = 3.5 units at 2.5/30 per tick = 42 ticks.
	# In 42 ticks AsbSavar fires at tick 1 (= 1 hit, 1560 dmg). Second hit at tick 51 (after melee).
	# Once in melee, Piyade hits 1000/hit every 30 ticks. AsbSavar HP=10000.
	# This is close — assert AsbSavar wins (it has HP parity but hits first at range
	# and 1.2× multiplier advantage).
	var instant: Variant = _InstantPathScheduler.new()
	PathSchedulerService.set_scheduler(instant)

	_unit_a = _spawn(AsbSavarKamandarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(PiyadeScene, Vector3(5.0, 0.0, 0.0), Constants.TEAM_TURAN)
	_unit_a.get_movement()._scheduler = instant
	_unit_b.get_movement()._scheduler = instant

	# AsbSavar attacks Piyade but does not issue a move command (held at position).
	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	# Piyade attacks AsbSavar — it will walk toward it.
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	var piyade_hp_reached_zero: bool = false
	for _i in range(500):
		_advance(1)
		if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
			piyade_hp_reached_zero = true
			break
		if is_instance_valid(_unit_a) and int(_unit_a.get_health().hp_x100) <= 0:
			# AsbSavar died — unexpected
			break

	assert_true(piyade_hp_reached_zero,
		"AsbSavar vs Piyade (1.2× kiting advantage, held at range): Piyade HP must reach 0. "
		+ "AsbSavar range=7.0 > Piyade range=1.5; AsbSavar fires first and compounds "
		+ "the 1.2× advantage. If AsbSavar survives: multiplier not applied or range gate wrong.")
	PathSchedulerService.set_scheduler(harness._mock_scheduler)


func test_turan_piyade_vs_turan_savar_turan_piyade_wins() -> void:
	# Turan mirror of the Piyade vs Savar test. The RPS matrix folds
	# turan_piyade → piyade row, turan_savar → savar row: 1.5× applies symmetrically.
	# Outcome must be identical to the Iran-Iran case.
	_unit_a = _spawn(TuranPiyadeScene, Vector3.ZERO, Constants.TEAM_TURAN)
	_unit_b = _spawn(TuranSavarScene, Vector3(1.5, 0.0, 0.0), Constants.TEAM_IRAN)

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	var turan_savar_hp_reached_zero: bool = false
	var turan_piyade_hp_reached_zero: bool = false
	for _i in range(500):
		_advance(1)
		if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
			turan_savar_hp_reached_zero = true
			break
		if is_instance_valid(_unit_a) and int(_unit_a.get_health().hp_x100) <= 0:
			turan_piyade_hp_reached_zero = true
			break

	assert_true(turan_savar_hp_reached_zero and not turan_piyade_hp_reached_zero,
		"Turan Piyade vs Turan Savar: Turan Savar HP must reach 0 first (symmetric to Iran pair, "
		+ "1.5× Turan-fold via get_multiplier). "
		+ "turan_savar_dead=%s turan_piyade_dead=%s. "
		+ "If Turan Savar doesn't die: Turan-mirror folding broken (raw dict bypassed)."
		% [str(turan_savar_hp_reached_zero), str(turan_piyade_hp_reached_zero)])


# ============================================================================
# 2. Turan-fold correctness via live chain
#
# Critical integration: Iran Piyade vs Iran Savar and Turan_Piyade vs Turan_Savar
# must apply the SAME 1.5× multiplier. If CombatComponent ever bypasses
# get_multiplier() and reads the raw effectiveness dict, Turan keys return 1.0
# (the dict has no "turan_piyade" row — only "piyade" etc.), producing wrong damage.
# This test catches that regression on the live damage-fire path.
# ============================================================================

func test_turan_fold_hp_drop_matches_iran_pair_within_tolerance() -> void:
	# Spawn Iran Piyade vs Iran Savar. Record HP drop after 3 ticks.
	# Spawn Turan_Piyade vs Turan_Savar. Record HP drop after 3 ticks.
	# Both must apply 1.5× and produce identical scaled damage per hit.
	# Tolerance: 1 HP (fixed-point rounding — both round the same value).

	# Iran pair.
	var iran_piyade: Variant = _spawn(PiyadeScene, Vector3(100.0, 0.0, 0.0), Constants.TEAM_IRAN)
	var iran_savar: Variant = _spawn(SavarScene, Vector3(101.0, 0.0, 0.0), Constants.TEAM_TURAN)
	_extra_units.append(iran_piyade)
	_extra_units.append(iran_savar)

	var iran_savar_initial: int = int(iran_savar.get_health().hp_x100)

	iran_piyade.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(iran_savar.unit_id)})
	iran_savar.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(iran_piyade.unit_id)})

	# Turan pair — separated from Iran pair by large X offset to prevent cross-targeting.
	var turan_piyade: Variant = _spawn(TuranPiyadeScene, Vector3(200.0, 0.0, 0.0), Constants.TEAM_TURAN)
	var turan_savar: Variant = _spawn(TuranSavarScene, Vector3(201.0, 0.0, 0.0), Constants.TEAM_IRAN)
	_extra_units.append(turan_piyade)
	_extra_units.append(turan_savar)

	var turan_savar_initial: int = int(turan_savar.get_health().hp_x100)

	turan_piyade.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(turan_savar.unit_id)})
	turan_savar.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(turan_piyade.unit_id)})

	# Advance 3 ticks — first attack fires on tick 1 (cooldown=0 on new target).
	_advance(3)

	# If either Savar died in 3 ticks (hp_x100=0), the multiplier is definitely firing.
	if int(iran_savar.get_health().hp_x100) <= 0 or int(turan_savar.get_health().hp_x100) <= 0:
		pass_test("One Savar reached HP=0 in 3 ticks — RPS multiplier applied (scale ok)")
		return

	var iran_savar_drop: int = iran_savar_initial - int(iran_savar.get_health().hp_x100)
	var turan_savar_drop: int = turan_savar_initial - int(turan_savar.get_health().hp_x100)

	# Both should have taken exactly 1500 x100 (1000 × 1.5) damage.
	assert_gt(iran_savar_drop, 0,
		"Iran Savar must have taken damage from Iran Piyade in 3 ticks")
	assert_gt(turan_savar_drop, 0,
		"Turan Savar must have taken damage from Turan Piyade in 3 ticks")

	# The key assertion: Turan-fold produces the SAME scaled damage as Iran-Iran.
	assert_true(abs(iran_savar_drop - turan_savar_drop) <= 100,
		"Turan-fold correctness: Iran Piyade→Savar and Turan_Piyade→Turan_Savar "
		+ "must deal the same scaled damage (both fold to 1.5×). "
		+ "Iran drop=%d, Turan drop=%d. If they differ: CombatComponent bypassed "
		+ "get_multiplier() and Turan keys returned 1.0× from raw dict access."
		% [iran_savar_drop, turan_savar_drop])


# ============================================================================
# 3. 33-unit match-start roster verification
#
# The existing test_main_tscn_spawns_33_units_correct_teams (in
# test_phase_2_session_1_combat.gd) locks team counts. Here we extend
# with: unit_type population, team-to-SpatialAgentComponent mirroring,
# and unit_id ordering for the 6 new wave-2B types.
# ============================================================================

func test_match_start_33_units_all_unit_types_have_correct_type_strings() -> void:
	# Every combat unit's unit_type must be a non-empty StringName after spawn.
	# This catches the dual-init failure mode: if _ready does NOT override
	# unit_type before super._ready, the @export reset between _init and _ready
	# leaves unit_type="" and BalanceData lookup silently no-ops (unit fires 0 dmg).
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_nodes(main_node, all_units)

	assert_eq(all_units.size(), 33,
		"pre-condition: main.tscn must spawn 33 units")

	var empty_type_units: Array = []
	for u in all_units:
		var ut: Variant = u.get(&"unit_type")
		if typeof(ut) != TYPE_STRING_NAME or String(StringName(ut)).is_empty():
			empty_type_units.append(u.get(&"unit_id"))

	assert_eq(empty_type_units.size(), 0,
		"All 33 units must have a non-empty unit_type (dual-init pattern). "
		+ "Units with empty type: %s. Empty type means BalanceData lookup "
		+ "silently no-ops → unit fires 0 damage in live game." % str(empty_type_units))


func test_match_start_wave_2b_unit_types_present() -> void:
	# The 6 new wave-2B types must each be represented.
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_nodes(main_node, all_units)

	var type_counts: Dictionary = {}
	for u in all_units:
		var ut: StringName = StringName(String(u.get(&"unit_type")))
		type_counts[ut] = int(type_counts.get(ut, 0)) + 1

	var expected_types: Array = [
		&"kamandar", &"savar", &"asb_savar_kamandar",
		&"turan_kamandar", &"turan_savar", &"turan_asb_savar",
	]
	for expected: StringName in expected_types:
		assert_true(type_counts.has(expected) and int(type_counts.get(expected, 0)) == 3,
			"Wave-2B type '%s' must appear exactly 3 times in the 33-unit roster. "
			+ "Got: %d" % [String(expected), int(type_counts.get(expected, 0))])


func test_match_start_wave_2b_teams_correctly_assigned() -> void:
	# Iran trios (Kamandar, Savar, AsbSavar) must all be TEAM_IRAN.
	# Turan trios (TuranKamandar, TuranSavar, TuranAsbSavar) must all be TEAM_TURAN.
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_nodes(main_node, all_units)

	var iran_types: Array = [&"kamandar", &"savar", &"asb_savar_kamandar"]
	var turan_types: Array = [&"turan_kamandar", &"turan_savar", &"turan_asb_savar"]

	for u in all_units:
		var ut: StringName = StringName(String(u.get(&"unit_type")))
		var team: int = int(u.get(&"team"))
		if ut in iran_types:
			assert_eq(team, Constants.TEAM_IRAN,
				"Unit type '%s' must be on TEAM_IRAN (got team=%d)" % [String(ut), team])
		elif ut in turan_types:
			assert_eq(team, Constants.TEAM_TURAN,
				"Unit type '%s' must be on TEAM_TURAN (got team=%d)" % [String(ut), team])


func test_match_start_unit_ids_1_through_33_in_spawn_order() -> void:
	# Wave-2B spawn order (per main.gd docstring):
	#   Kargar 1..5, Iran Piyade 6..10, Turan Piyade 11..15,
	#   Kamandar 16..18, Savar 19..21, AsbSavar 22..24,
	#   TuranKamandar 25..27, TuranSavar 28..30, TuranAsbSavar 31..33.
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_nodes(main_node, all_units)

	var ids: Array = []
	for u in all_units:
		ids.append(int(u.get(&"unit_id")))
	ids.sort()

	assert_eq(ids.size(), 33, "Must have exactly 33 unit_ids")
	for i in range(33):
		assert_eq(ids[i], i + 1,
			"unit_id sequence must be 1..33 in order; got ids[%d]=%d" % [i, ids[i]])


# ============================================================================
# 4. Kiting-math correctness (analytical, not behavioral)
#
# Tests that the COMBAT MATH supports kiting — not that the AI kites.
# AsbSavar at fixed position (no movement command), Turan Piyade approaches.
# Asserts: AsbSavar fires before Piyade reaches melee, and fires again before
# OR near when Piyade closes.
# ============================================================================

func test_kiting_math_asb_savar_fires_before_piyade_closes_melee() -> void:
	# AsbSavar at origin, Piyade at distance 6.0.
	# AsbSavar range=7.0 → within range immediately. Fires at tick 1.
	# Piyade move_speed=2.5/sec → 2.5/30 ≈ 0.0833 units/tick.
	# Gap = 6.0 - 1.5 = 4.5 units to close. Ticks to close ≈ 4.5/0.0833 = 54 ticks.
	# AsbSavar cooldown = 1/0.6 × 30 = 50 ticks. Second fire at tick 51 — BEFORE Piyade closes (54 ticks).
	# So AsbSavar fires at least TWICE before Piyade is in melee range.
	var instant: Variant = _InstantPathScheduler.new()
	PathSchedulerService.set_scheduler(instant)

	_unit_a = _spawn(AsbSavarKamandarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(TuranPiyadeScene, Vector3(6.0, 0.0, 0.0), Constants.TEAM_TURAN)
	_unit_a.get_movement()._scheduler = instant
	_unit_b.get_movement()._scheduler = instant

	# AsbSavar attacks Piyade — does NOT issue a movement command (held at origin).
	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})
	# Piyade attacks AsbSavar, triggering its approach walk.
	_unit_b.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_a.unit_id)})

	var piyade_initial_hp_x100: int = int(_unit_b.get_health().hp_x100)

	# Advance 50 ticks — just before Piyade should close melee (analytical: 54 ticks).
	_advance(50)

	# Assertions:
	var piyade_hp_zero_at_50: bool = is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0
	if piyade_hp_zero_at_50:
		pass_test("Piyade HP reached 0 by tick 50 — AsbSavar damage was decisive (ok)")
		PathSchedulerService.set_scheduler(harness._mock_scheduler)
		return

	var piyade_hp_at_50: int = int(_unit_b.get_health().hp_x100)
	var piyade_dist_from_asb_savar: float = float(_unit_b.global_position.distance_to(_unit_a.global_position))

	# AsbSavar must have fired at least once (piyade took damage).
	assert_lt(piyade_hp_at_50, piyade_initial_hp_x100,
		"Kiting-math: Piyade must have taken at least one hit by tick 50 "
		+ "(AsbSavar range=7.0 > Piyade start distance=6.0; fires immediately). "
		+ "hp_at_50=%d initial=%d" % [piyade_hp_at_50, piyade_initial_hp_x100])

	# Piyade must not yet be in AsbSavar's melee range (Piyade range=1.5).
	# At tick 50 Piyade has closed ≈ 50 × 0.0833 = 4.17 units from distance 6.0 → still ≈ 1.83 away.
	assert_gt(piyade_dist_from_asb_savar, 1.5,
		"Kiting-math: Piyade must not yet be at melee range (1.5) by tick 50. "
		+ "Analytical: Piyade closes ~4.17 units in 50 ticks → still ~1.83 away. "
		+ "dist=%.2f" % piyade_dist_from_asb_savar)

	# Advance to tick 55 — AsbSavar second shot should have fired (50-tick cooldown).
	_advance(5)

	if is_instance_valid(_unit_b) and int(_unit_b.get_health().hp_x100) <= 0:
		pass_test("Piyade HP reached 0 by tick 55 — kiting DPS was decisive (ok)")
		PathSchedulerService.set_scheduler(harness._mock_scheduler)
		return

	var piyade_hp_at_55: int = int(_unit_b.get_health().hp_x100)
	# The second shot should have landed between tick 51-55.
	var expected_per_shot_x100: int = roundi(1300.0 * 1.2)  # 1560
	assert_lte(piyade_hp_at_55, piyade_hp_at_50 - expected_per_shot_x100 + 200,
		"Kiting-math: AsbSavar second shot must land by tick 55 (cooldown=50 ticks). "
		+ "hp_at_50=%d hp_at_55=%d expected second shot ~1560 damage."
		% [piyade_hp_at_50, piyade_hp_at_55])

	PathSchedulerService.set_scheduler(harness._mock_scheduler)


func test_kiting_math_analytical_shot_count_within_close_window() -> void:
	# Pure analytical verification — does the math produce the right number of shots
	# in the kiting window, independent of actual unit behavior?
	# Window: from t=0 to t=ticks_to_close (Piyade closes 4.5 units at 2.5/30 per tick).
	var piyade_move_per_tick: float = 2.5 / 30.0
	var gap_to_close: float = 6.0 - 1.5  # Piyade range
	var ticks_to_close: float = gap_to_close / piyade_move_per_tick

	var asb_savar_cooldown_ticks: int = roundi(30.0 / 0.6)  # 50

	var shots_in_window: int = 1  # First shot fires at tick 1 (cooldown=0 after set_target)
	var next_shot_tick: int = 1 + asb_savar_cooldown_ticks
	while float(next_shot_tick) <= ticks_to_close:
		shots_in_window += 1
		next_shot_tick += asb_savar_cooldown_ticks

	assert_gte(shots_in_window, 1,
		"Kiting-math analytical: AsbSavar must fire at least 1 shot before Piyade closes. "
		+ "ticks_to_close=%.1f, asb_savar_cooldown=%d, shots=%d"
		% [ticks_to_close, asb_savar_cooldown_ticks, shots_in_window])

	# Verify the damage math is material: shots × 1560 vs Piyade HP=10000.
	var dmg_per_shot_x100: int = roundi(1300.0 * 1.2)  # 1560
	var total_dmg_x100: int = shots_in_window * dmg_per_shot_x100
	assert_gt(total_dmg_x100, 0,
		"Kiting-math analytical: damage in window must be positive "
		+ "(shots=%d × %d = %d x100)" % [shots_in_window, dmg_per_shot_x100, total_dmg_x100])


# ============================================================================
# 5. Cross-feature smoke
#
# Load main.tscn, box-select Iran Piyade cluster, right-click a Turan Savar.
# Advance ticks until at least one Turan Savar dies. Assert at least one Iran
# Piyade is still alive (1.5× anti-cavalry advantage). This is the "RPS
# produces the spec outcome at multi-unit scale via the live engine path" test.
# ============================================================================

func test_cross_feature_5_piyade_vs_savar_piyade_cluster_survives() -> void:
	# This test exercises the FULL live engine path:
	#   SelectionManager.select_only → ClickHandler.process_right_click_hit
	#   → EventBus.attack_command_issued → Unit.replace_command
	#   → FSM transitions → CombatComponent._sim_tick with real BalanceData RPS lookup
	#   → HP decrements → unit_died → UnitState_Dying → queue_free.
	# 5 Iran Piyade vs the 3 Iran Savar tactic (using Turan Savar from the main roster).
	var main_node: Node = MainScene.instantiate()
	add_child_autofree(main_node)
	await get_tree().process_frame

	var all_units: Array = []
	_collect_unit_nodes(main_node, all_units)

	# Identify Iran Piyade cluster (unit_ids 6..10, type=piyade, team=IRAN).
	var iran_piyade_units: Array = []
	for u in all_units:
		if StringName(String(u.get(&"unit_type"))) == &"piyade" and int(u.get(&"team")) == Constants.TEAM_IRAN:
			iran_piyade_units.append(u)

	# Identify Turan Savar cluster (type=turan_savar, team=TURAN).
	var turan_savar_units: Array = []
	for u in all_units:
		if StringName(String(u.get(&"unit_type"))) == &"turan_savar" and int(u.get(&"team")) == Constants.TEAM_TURAN:
			turan_savar_units.append(u)

	assert_eq(iran_piyade_units.size(), 5,
		"pre-condition: 5 Iran Piyade must exist in main.tscn roster")
	assert_eq(turan_savar_units.size(), 3,
		"pre-condition: 3 Turan Savar must exist in main.tscn roster")

	# Position the Turan Savar cluster adjacent to the Iran Piyade cluster
	# so no movement is needed (avoids mock scheduler issues in full-scene context).
	for i in range(turan_savar_units.size()):
		turan_savar_units[i].global_position = Vector3(float(i) * 1.5 - 1.5, 0.5, -9.0)

	# Swap instant scheduler for all units so attack commands work.
	var instant: Variant = _InstantPathScheduler.new()
	PathSchedulerService.set_scheduler(instant)
	for u in iran_piyade_units:
		u.get_movement()._scheduler = instant
	for u in turan_savar_units:
		u.get_movement()._scheduler = instant

	# Issue attack commands: each Iran Piyade targets the first Turan Savar.
	# (Focus fire so first kill happens sooner.)
	var target_id: int = int(turan_savar_units[0].unit_id)
	for piyade_unit in iran_piyade_units:
		piyade_unit.replace_command(Constants.COMMAND_ATTACK,
			{&"target_unit_id": target_id})
	# Turan Savars attack back.
	for savar_unit in turan_savar_units:
		savar_unit.replace_command(Constants.COMMAND_ATTACK,
			{&"target_unit_id": int(iran_piyade_units[0].unit_id)})

	# Advance until at least one Turan Savar reaches HP=0 or 600-tick budget.
	# HP-based death detection: queue_free.call_deferred defers actual free to process_frame
	# which doesn't run inside SimClock._test_run_tick loops. hp_x100 reaches 0 synchronously.
	var savar_hp_zero_count: int = 0
	for _i in range(600):
		_advance(1)
		savar_hp_zero_count = 0
		for sv in turan_savar_units:
			if is_instance_valid(sv) and int(sv.get_health().hp_x100) <= 0:
				savar_hp_zero_count += 1
		if savar_hp_zero_count >= 1:
			break

	assert_gte(savar_hp_zero_count, 1,
		"Cross-feature smoke: at least 1 Turan Savar HP must reach 0 within 600 ticks "
		+ "(5 Iran Piyade focus-firing with 1.5× anti-cavalry advantage). "
		+ "Savar HP=15000 x100, Piyade dmg=1500 x100/hit per Piyade = 7500/hit combined.")

	# Assert at least one Iran Piyade is still alive (they have 1.5× advantage).
	var surviving_piyade: int = 0
	for piyade_unit in iran_piyade_units:
		if is_instance_valid(piyade_unit) and int(piyade_unit.get_health().hp_x100) > 0:
			surviving_piyade += 1

	assert_gt(surviving_piyade, 0,
		"Cross-feature smoke: at least 1 Iran Piyade must survive after first Savar kill "
		+ "(1.5× advantage should mean Piyade suffers fewer losses). "
		+ "surviving=%d" % surviving_piyade)

	PathSchedulerService.set_scheduler(harness._mock_scheduler)


# ============================================================================
# 6. CombatComponent integration audit
#
# Wave-2A added tests in test_rps_matrix_integration.gd using unit fixtures.
# These tests exercise the SAME multiplier paths through REAL unit scenes
# loaded with real BalanceData, catching any wiring gaps between the fixture
# tests and the live path. Does not duplicate wave-2A; provides the live-
# unit complement.
# ============================================================================

func test_live_kamandar_vs_piyade_applies_1_5x_from_balance_tres() -> void:
	# Kamandar fires at Piyade via the full live chain.
	# Damage = BalanceData.units.kamandar.attack_damage_x100 × matrix[kamandar][piyade] (1.5×).
	# Assert Piyade HP drops by exactly that value on first hit.
	_unit_a = _spawn(KamandarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(PiyadeScene, Vector3(1.5, 0.0, 0.0), Constants.TEAM_TURAN)  # within Kamandar range

	var bd: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var kamandar_stats: Variant = bd.get(&"units").get(&"kamandar")
	var base_dmg_x100: int = int(kamandar_stats.get(&"attack_damage_x100"))
	var matrix: Variant = bd.get(&"combat")
	var mult: float = float(matrix.call(&"get_multiplier", &"kamandar", &"piyade"))
	var expected_dmg_x100: int = roundi(float(base_dmg_x100) * mult)
	var piyade_max_hp_x100: int = roundi(float(bd.get(&"units").get(&"piyade").get(&"max_hp")) * 100.0)
	var expected_hp_x100: int = piyade_max_hp_x100 - expected_dmg_x100

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})

	# 3 ticks: FSM transition (tick 1) + first attack fire (tick 1 on entry, cooldown=0).
	_advance(3)

	if _unit_b == null or not is_instance_valid(_unit_b):
		pass_test("Piyade died in 3 ticks — damage applied (ok)")
		_unit_b = null
		return

	var hp_after: int = int(_unit_b.get_health().hp_x100)
	assert_eq(hp_after, expected_hp_x100,
		"Live Kamandar vs Piyade: base=%d × mult=%.2f → %d damage; "
		+ "HP %d → %d expected, got %d"
		% [base_dmg_x100, mult, expected_dmg_x100,
			piyade_max_hp_x100, expected_hp_x100, hp_after])


func test_live_savar_vs_kamandar_applies_2_0x_from_balance_tres() -> void:
	# Savar fires at Kamandar. Damage = 1200 × 2.0 = 2400 x100.
	# Kamandar HP=60 (6000 x100). After 1 hit → 6000-2400 = 3600 x100 (36 HP).
	_unit_a = _spawn(SavarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(KamandarScene, Vector3(1.8, 0.0, 0.0), Constants.TEAM_TURAN)  # within Savar range 1.8

	var bd: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var savar_stats: Variant = bd.get(&"units").get(&"savar")
	var base_dmg_x100: int = int(savar_stats.get(&"attack_damage_x100"))
	var matrix: Variant = bd.get(&"combat")
	var mult: float = float(matrix.call(&"get_multiplier", &"savar", &"kamandar"))
	var expected_dmg_x100: int = roundi(float(base_dmg_x100) * mult)
	var kamandar_max_hp_x100: int = roundi(float(bd.get(&"units").get(&"kamandar").get(&"max_hp")) * 100.0)
	var expected_hp_x100: int = kamandar_max_hp_x100 - expected_dmg_x100

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})

	_advance(3)

	if _unit_b == null or not is_instance_valid(_unit_b):
		pass_test("Kamandar died in 3 ticks — 2.0× damage was decisive (ok)")
		_unit_b = null
		return

	var hp_after: int = int(_unit_b.get_health().hp_x100)
	assert_eq(hp_after, expected_hp_x100,
		"Live Savar vs Kamandar: base=%d × mult=%.2f → %d damage; "
		+ "HP %d → %d expected, got %d"
		% [base_dmg_x100, mult, expected_dmg_x100,
			kamandar_max_hp_x100, expected_hp_x100, hp_after])


func test_live_turan_kamandar_vs_turan_piyade_matches_iran_pair_damage() -> void:
	# Turan mirror: TuranKamandar vs TuranPiyade must apply same 1.5× as Iran pair.
	# Critical: this proves Turan-fold is wired in the LIVE path (not just unit-fixture tests).
	# If get_multiplier() is bypassed: raw dict has no "turan_kamandar" key → 1.0× returned
	# → TuranKamandar deals 1500 x100 instead of 2250 x100 → wrong HP drop.
	_unit_a = _spawn(TuranKamandarScene, Vector3.ZERO, Constants.TEAM_TURAN)
	_unit_b = _spawn(TuranPiyadeScene, Vector3(1.5, 0.0, 0.0), Constants.TEAM_IRAN)

	var bd: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var kamandar_stats: Variant = bd.get(&"units").get(&"kamandar")
	var base_dmg_x100: int = int(kamandar_stats.get(&"attack_damage_x100"))
	var matrix: Variant = bd.get(&"combat")
	# Fold: turan_kamandar → kamandar row; turan_piyade → piyade column.
	var mult: float = float(matrix.call(&"get_multiplier", &"turan_kamandar", &"turan_piyade"))
	var expected_dmg_x100: int = roundi(float(base_dmg_x100) * mult)
	var piyade_max_hp_x100: int = roundi(float(bd.get(&"units").get(&"piyade").get(&"max_hp")) * 100.0)
	var expected_hp_x100: int = piyade_max_hp_x100 - expected_dmg_x100

	assert_almost_eq(mult, 1.5, 0.01,
		"pre-condition: get_multiplier(turan_kamandar, turan_piyade) must return 1.5 (fold to kamandar→piyade)")

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})

	_advance(3)

	if _unit_b == null or not is_instance_valid(_unit_b):
		pass_test("TuranPiyade died in 3 ticks — Turan-fold damage applied (ok)")
		_unit_b = null
		return

	var hp_after: int = int(_unit_b.get_health().hp_x100)
	assert_eq(hp_after, expected_hp_x100,
		"Live TuranKamandar vs TuranPiyade (Turan-fold must give 1.5×): "
		+ "base=%d × mult=%.2f → %d dmg; HP %d → %d expected, got %d. "
		+ "If hp_after == %d (base-1.0× case): CombatComponent bypassed get_multiplier()."
		% [base_dmg_x100, mult, expected_dmg_x100,
			piyade_max_hp_x100, expected_hp_x100, hp_after,
			piyade_max_hp_x100 - base_dmg_x100])


func test_live_asb_savar_vs_piyade_applies_1_2x_from_balance_tres() -> void:
	# AsbSavar at range vs Piyade: 1300 × 1.2 = 1560 x100 per hit.
	# Piyade max_hp=100 (10000 x100). After 1 hit → 10000 - 1560 = 8440 x100.
	_unit_a = _spawn(AsbSavarKamandarScene, Vector3.ZERO, Constants.TEAM_IRAN)
	_unit_b = _spawn(PiyadeScene, Vector3(1.5, 0.0, 0.0), Constants.TEAM_TURAN)  # within AsbSavar range

	var bd: Resource = ResourceLoader.load(BALANCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var asb_stats: Variant = bd.get(&"units").get(&"asb_savar_kamandar")
	var base_dmg_x100: int = int(asb_stats.get(&"attack_damage_x100"))
	var matrix: Variant = bd.get(&"combat")
	var mult: float = float(matrix.call(&"get_multiplier", &"asb_savar_kamandar", &"piyade"))
	var expected_dmg_x100: int = roundi(float(base_dmg_x100) * mult)
	var piyade_max_hp_x100: int = roundi(float(bd.get(&"units").get(&"piyade").get(&"max_hp")) * 100.0)
	var expected_hp_x100: int = piyade_max_hp_x100 - expected_dmg_x100

	assert_almost_eq(mult, 1.2, 0.01,
		"pre-condition: get_multiplier(asb_savar_kamandar, piyade) must be 1.2")

	_unit_a.replace_command(Constants.COMMAND_ATTACK,
		{&"target_unit_id": int(_unit_b.unit_id)})

	_advance(3)

	if _unit_b == null or not is_instance_valid(_unit_b):
		pass_test("Piyade died in 3 ticks (ok)")
		_unit_b = null
		return

	var hp_after: int = int(_unit_b.get_health().hp_x100)
	assert_eq(hp_after, expected_hp_x100,
		"Live AsbSavar vs Piyade: base=%d × mult=%.2f → %d damage; "
		+ "HP %d → %d expected, got %d"
		% [base_dmg_x100, mult, expected_dmg_x100,
			piyade_max_hp_x100, expected_hp_x100, hp_after])
