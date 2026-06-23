# Tests for FarrDrainDispatcher autoload — Phase 3 wave 1B.
#
# Contract:
#   - 02f_PHASE_3_KICKOFF.md §2 Open Space resolution (2026-05-13):
#     - drain_rates positive magnitudes; dispatcher applies negative sign
#     - subscribe to unit_health_zero PRE-Dying-swap (NOT unit_died, which
#       fires from Dying.enter — every death would look like state.id ==
#       &"dying")
#   - 01_CORE_MECHANICS.md §4 — Farr drain rates spec
#   - game/scripts/autoload/farr_drain_dispatcher.gd — the SUT
#
# Coverage:
#   - Subscription: subscribes to EventBus.unit_health_zero, NOT unit_died.
#   - Dispatch table: state.id × unit_type → drain key resolution.
#   - Lookup: BalanceData.farr.drain_rates[key] used as the magnitude.
#   - Sign: dispatcher applies -magnitude at call site (positive magnitudes
#     stored in BalanceData).
extends GutTest


# Helper: run a Callable inside a single sim tick. Same pattern as
# test_farr_system.gd. The handler fires inside the combat phase so
# apply_farr_change's on-tick assert holds.
func _run_inside_tick(body: Callable) -> void:
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			body.call()
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)


func before_each() -> void:
	SimClock.reset()
	# Restore Farr to spec default (50.0) directly.
	FarrSystem._farr_x100 = 5000
	FarrDrainDispatcher.reset()


func after_each() -> void:
	SimClock.reset()
	FarrSystem._farr_x100 = 5000
	FarrDrainDispatcher.reset()


# === Subscription contract — UNIT_HEALTH_ZERO, NOT UNIT_DIED ===============

func test_dispatcher_subscribes_to_unit_health_zero_not_unit_died() -> void:
	# Critical contract from the Open Space resolution: the dispatcher must
	# read FSM state PRE-Dying-swap, which means it subscribes to
	# unit_health_zero (emitted before the StateMachine death-preempt swaps
	# the state to Dying) — not unit_died (emitted from Dying.enter, which
	# would always read state.id == &"dying").
	assert_true(
		EventBus.unit_health_zero.is_connected(
			FarrDrainDispatcher._on_unit_health_zero),
		"FarrDrainDispatcher MUST subscribe to unit_health_zero"
	)


func test_dispatcher_does_not_subscribe_to_unit_died() -> void:
	# Negative contract: the dispatcher must NOT subscribe to unit_died.
	# Subscribing to unit_died would always see state.id == &"dying" (the
	# Dying state's enter() is what emits unit_died via HealthComponent),
	# collapsing the two drain keys into one.
	assert_false(
		EventBus.unit_died.is_connected(
			FarrDrainDispatcher._on_unit_health_zero),
		"FarrDrainDispatcher MUST NOT subscribe to unit_died — that would "
		+ "read state.id pos-Dying-swap and collapse drain keys"
	)


# === Dispatch table — resolve_drain_key ====================================

func test_resolve_drain_key_idle_kargar_returns_worker_killed_idle() -> void:
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"idle", &"kargar"),
		&"worker_killed_idle",
		"idle Kargar → worker_killed_idle"
	)


func test_resolve_drain_key_gathering_returns_worker_killed_during_gather() -> void:
	# Any unit type in gathering state — the carry was in progress.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"gathering", &"kargar"),
		&"worker_killed_during_gather",
		"gathering → worker_killed_during_gather"
	)


func test_resolve_drain_key_returning_returns_worker_killed_during_gather() -> void:
	# Symmetric with gathering — the worker was mid-task.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"returning", &"kargar"),
		&"worker_killed_during_gather",
		"returning → worker_killed_during_gather"
	)


func test_resolve_drain_key_idle_piyade_returns_empty() -> void:
	# Non-worker in idle: no drain. A Piyade standing idle that dies is normal
	# combat attrition, not a worker-loss penalty.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"idle", &"piyade"),
		&"",
		"idle non-worker → no drain"
	)


func test_resolve_drain_key_attacking_returns_empty() -> void:
	# Combat-state death: no drain. Phase 3 doesn't drain for combat-unit
	# deaths — snowball protection in §4.3 covers that and ships Phase 4+.
	assert_eq(
		FarrDrainDispatcher.resolve_drain_key(&"attacking", &"piyade"),
		&"",
		"attacking → no drain"
	)


# === End-to-end emit — apply_farr_change is called with negative sign ======

# Fake Unit with the duck-typed surface the dispatcher reads (unit_id,
# unit_type, fsm.current.id). Extends Node so the scene-tree walk finds it.
class FakeFSM:
	var current: FakeState = null


class FakeState:
	var id: StringName = &""


class FakeUnit extends Node:
	var unit_id: int = -1
	var unit_type: StringName = &""
	var team: int = 0
	var _dying: bool = false
	var fsm: FakeFSM = FakeFSM.new()
	# replace_command is the duck-type marker the dispatcher's
	# _find_unit_recursive looks for in addition to unit_id.
	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass
	# is_dying() is the canonical alive predicate the D1 snowball pop-sums read
	# (Fix F2). Real Unit defines it (unit.gd:586); the fake mirrors the shape.
	func is_dying() -> bool:
		return _dying


func _make_fake_unit(uid: int, ut: StringName, state_id: StringName) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.unit_type = ut
	u.fsm.current = FakeState.new()
	u.fsm.current.id = state_id
	add_child_autofree(u)
	return u


# === D1 snowball-drain test scaffolding ====================================
#
# D1 enumerates the &"units" / &"buildings" SceneTree groups (not the
# _find_unit_recursive walk the worker drains use). These helpers spawn fakes
# that JOIN those groups + carry the full surface D1 reads (team, unit_type,
# is_dying, population_cost via BalanceData, produces/is_complete for buildings).

# Spawn a unit-shaped fake in the &"units" group (so D1's _team_population /
# _team_living_military_count enumerations find it). state_id defaults &"idle"
# (irrelevant to D1 — D1 reads team + type, not FSM state).
func _make_unit_in_group(uid: int, ut: StringName, t: int, dying: bool = false) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	u.unit_type = ut
	u.team = t
	u._dying = dying
	u.fsm.current = FakeState.new()
	u.fsm.current.id = &"idle"
	add_child_autofree(u)
	u.add_to_group(&"units")
	return u


class FakeBuilding extends Node:
	var unit_id: int = -1
	var team: int = 0
	var is_complete: bool = false
	var produces: Array[StringName] = []
	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


# Spawn a building-shaped fake in the &"buildings" group. produces + is_complete
# drive D1b's military-production check.
func _make_building_in_group(uid: int, t: int, prod: Array[StringName],
		complete: bool) -> FakeBuilding:
	var b: FakeBuilding = FakeBuilding.new()
	b.unit_id = uid
	b.team = t
	b.produces = prod
	b.is_complete = complete
	add_child_autofree(b)
	b.add_to_group(&"buildings")
	return b


func test_idle_kargar_death_drains_farr_by_one() -> void:
	var u: FakeUnit = _make_fake_unit(101, &"kargar", &"idle")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	# Started at 50.0 (5000 x100). Drain magnitude 1.0 (positive) applied as
	# -1.0 → 49.0.
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"idle Kargar death drains Farr by 1.0 (50.0 → 49.0)")


func test_gathering_kargar_death_drains_farr_by_half() -> void:
	var u: FakeUnit = _make_fake_unit(102, &"kargar", &"gathering")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	# 50.0 - 0.5 = 49.5.
	assert_almost_eq(FarrSystem.value_farr, 49.5, 1e-4,
		"gathering Kargar death drains Farr by 0.5 (50.0 → 49.5)")


func test_returning_kargar_death_drains_farr_by_half() -> void:
	var u: FakeUnit = _make_fake_unit(103, &"kargar", &"returning")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	assert_almost_eq(FarrSystem.value_farr, 49.5, 1e-4,
		"returning Kargar death drains Farr by 0.5 (50.0 → 49.5)")


func test_non_worker_death_does_not_drain() -> void:
	var u: FakeUnit = _make_fake_unit(104, &"piyade", &"attacking")
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(u.unit_id)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"non-worker death in combat state does not drain Farr")


func test_unknown_unit_id_does_not_crash() -> void:
	# Defensive: unknown unit_id (already freed, or test artifact) just bails
	# silently without mutating Farr.
	_run_inside_tick(func() -> void:
		EventBus.unit_health_zero.emit(99999)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"unknown unit_id bails silently — no Farr change")


# ===========================================================================
# D1 — §4.3 snowball-injustice drains (unit_died handler)
# ===========================================================================
#
# Contract: 01_CORE_MECHANICS.md §4.3 + DECISIONS.md 2026-06-22 §1.1.
#   snowball_kill_outnumbered = 0.5 ; snowball_economy_when_broken = 1.0 ;
#   snowball_ratio = 3.0. All units have population_cost = 1 in balance.tres,
#   so attacker_pop / defender_pop equal the living-unit counts (the victim +
#   any is_dying() unit excluded from BOTH sums — Fix F4 determinism).
#
# Iran = TEAM_IRAN (1, attacker), Turan = TEAM_TURAN (2, defender).

# --- D1a: outnumbered-kill drain -------------------------------------------

func test_d1a_fires_at_exactly_three_to_one() -> void:
	# Attacker (Iran) pop 3; defender (Turan) living pop 1 AFTER excluding the
	# just-killed victim. threshold = roundi(3.0 * 1) = 3; attacker 3 >= 3 → fire.
	_make_unit_in_group(201, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(202, &"piyade", Constants.TEAM_IRAN)
	var killer: FakeUnit = _make_unit_in_group(203, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(204, &"turan_piyade", Constants.TEAM_TURAN)        # living defender
	var victim: FakeUnit = _make_unit_in_group(205, &"turan_piyade", Constants.TEAM_TURAN)  # the kill
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	# 50.0 - 0.5 = 49.5.
	assert_almost_eq(FarrSystem.value_farr, 49.5, 1e-4,
		"D1a fires at exactly 3:1 (attacker_pop=3, defender_pop=1) → -0.5 Farr")


func test_d1a_does_not_fire_below_three_to_one() -> void:
	# Attacker pop 2; defender living pop 1 (excl victim). 2 < roundi(3*1)=3 → no fire.
	_make_unit_in_group(211, &"piyade", Constants.TEAM_IRAN)
	var killer: FakeUnit = _make_unit_in_group(212, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(213, &"turan_piyade", Constants.TEAM_TURAN)        # living defender
	var victim: FakeUnit = _make_unit_in_group(214, &"turan_piyade", Constants.TEAM_TURAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1a does NOT fire at 2:1 (attacker_pop=2, defender_pop=1, threshold=3)")


func test_d1a_bails_on_killer_minus_one() -> void:
	# killer_unit_id = -1 (attrition / environmental / Farr-drain death). No
	# injustice → bail, regardless of the population ratio.
	_make_unit_in_group(221, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(222, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(223, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(224, &"turan_piyade", Constants.TEAM_TURAN)
	var victim: FakeUnit = _make_unit_in_group(225, &"turan_piyade", Constants.TEAM_TURAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, -1, &"farr_drain", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1a bails on killer_unit_id=-1 (no source) even at 3:1")


func test_d1a_bails_on_unresolved_killer() -> void:
	# killer_unit_id references a unit not in the tree (freed before resolve).
	# Attacker team read OFF THE KILLER (Fix F1); can't read it → bail.
	_make_unit_in_group(231, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(232, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(233, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(234, &"turan_piyade", Constants.TEAM_TURAN)
	var victim: FakeUnit = _make_unit_in_group(235, &"turan_piyade", Constants.TEAM_TURAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, 88888, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1a bails when the killer can't be resolved (Fix F1 — team read off killer)")


func test_d1a_bails_on_friendly_fire() -> void:
	# killer.team == victim.team → friendly-fire bail (a separate later concern).
	# Even with a lopsided overall roster, same-team kill never drains via D1a.
	_make_unit_in_group(241, &"turan_piyade", Constants.TEAM_TURAN)
	_make_unit_in_group(242, &"turan_piyade", Constants.TEAM_TURAN)
	var killer: FakeUnit = _make_unit_in_group(243, &"turan_piyade", Constants.TEAM_TURAN)
	var victim: FakeUnit = _make_unit_in_group(244, &"turan_piyade", Constants.TEAM_TURAN)
	# An Iran unit exists so the "victim's opposite" mis-derivation (the F1 bug)
	# would have computed a ratio; reading off the killer makes it friendly-fire.
	_make_unit_in_group(245, &"piyade", Constants.TEAM_IRAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"hero_friendly_fire", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1a friendly-fire bail (killer.team == victim.team)")


func test_d1a_same_tick_multi_death_is_order_invariant() -> void:
	# Fix F4 determinism: two Turan deaths in the SAME tick must produce the same
	# total Farr regardless of handler order. The exclusion contract (exclude the
	# just-emitted victim id + is_dying() units from BOTH pop sums) guarantees
	# each death's ratio test reads the SAME team-pop snapshot — order-invariant.
	#
	# Setup: Iran attacker pop 6; Turan has 2 living defenders (251, 252) plus
	# 2 victims dying THIS tick (253, 254). For each victim, defender_pop excludes
	# only THAT victim (253 sees {251,252,254}=3; 254 sees {251,252,253}=3).
	# attacker 6 >= roundi(3*3)=9? No — 6 < 9, so NEITHER fires. The point of the
	# test is order-invariance of the SNAPSHOT, not that a drain fires: run the
	# two emits in both orders and assert identical Farr.
	_make_unit_in_group(255, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(256, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(257, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(258, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(259, &"piyade", Constants.TEAM_IRAN)
	var killer: FakeUnit = _make_unit_in_group(260, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(251, &"turan_piyade", Constants.TEAM_TURAN)
	_make_unit_in_group(252, &"turan_piyade", Constants.TEAM_TURAN)
	var v1: FakeUnit = _make_unit_in_group(253, &"turan_piyade", Constants.TEAM_TURAN)
	var v2: FakeUnit = _make_unit_in_group(254, &"turan_piyade", Constants.TEAM_TURAN)
	# Order A: v1 then v2.
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(v1.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
		EventBus.unit_died.emit(v2.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	var farr_order_a: float = FarrSystem.value_farr
	# Reset Farr, re-run Order B: v2 then v1.
	FarrSystem._farr_x100 = 5000
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(v2.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
		EventBus.unit_died.emit(v1.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	var farr_order_b: float = FarrSystem.value_farr
	assert_almost_eq(farr_order_a, farr_order_b, 1e-6,
		"Same-tick multi-death is order-invariant (Fix F4 exclusion contract)")


func test_d1a_same_tick_multi_death_is_order_invariant_via_is_dying_path() -> void:
	# Fix F4 HARDENING (review finding F1): the existing order-invariant test
	# above drives co-victims with _dying == false, so ONLY the exclude_unit_id
	# branch (farr_drain_dispatcher.gd ~line 315) ever engages — the is_dying()
	# exclusion branch (~line 319) is never exercised. But in the LIVE game the
	# emit order is:
	#     unit_health_zero(victim)
	#       -> StateMachine death-preempt sets victim to &"dying" SYNCHRONOUSLY
	#          (state_machine.gd:292-306)
	#       -> unit_died(victim)   <-- D1's _on_unit_died fires HERE
	# so by the time _on_unit_died runs, the just-emitted victim is ALREADY
	# is_dying(), AND any co-victim that died earlier the SAME tick is also
	# is_dying(). This test mirrors that sequence: flip each victim's _dying
	# = true immediately BEFORE emitting its unit_died, so the is_dying()
	# exclusion is the operative predicate (not the id-exclusion half).
	#
	# Roster: attacker pop 6, two living defenders 271/272, two same-tick
	# victims 273/274. Because each victim is flipped to dying BEFORE its emit,
	# the FIRST processed death sees the other victim still living (defender_pop
	# = {271,272,otherVictim} = 3; threshold roundi(3*3)=9; 6 < 9 → no fire),
	# while the SECOND processed death sees the first victim already is_dying()
	# (defender_pop = {271,272} = 2; threshold roundi(3*2)=6; 6 >= 6 → fires
	# -0.5). So EACH order fires exactly once (the second death) → -0.5 total,
	# identical regardless of which victim is emitted first. The point is
	# order-invariance of the SNAPSHOT under the is_dying() path; running both
	# orders and asserting identical Farr locks the contract against a future
	# emit-order refactor.
	_make_unit_in_group(275, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(276, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(277, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(278, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(279, &"piyade", Constants.TEAM_IRAN)
	var killer: FakeUnit = _make_unit_in_group(280, &"piyade", Constants.TEAM_IRAN)
	_make_unit_in_group(271, &"turan_piyade", Constants.TEAM_TURAN)
	_make_unit_in_group(272, &"turan_piyade", Constants.TEAM_TURAN)
	var v1: FakeUnit = _make_unit_in_group(273, &"turan_piyade", Constants.TEAM_TURAN)
	var v2: FakeUnit = _make_unit_in_group(274, &"turan_piyade", Constants.TEAM_TURAN)
	# Order A: v1 then v2. Flip each victim to dying right before its emit
	# (mirrors unit_health_zero -> dying-transition -> unit_died in the live game).
	_run_inside_tick(func() -> void:
		v1._dying = true
		EventBus.unit_died.emit(v1.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
		v2._dying = true
		EventBus.unit_died.emit(v2.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	var farr_order_a: float = FarrSystem.value_farr
	# Reset Farr + both victims' dying flags, re-run Order B: v2 then v1.
	FarrSystem._farr_x100 = 5000
	v1._dying = false
	v2._dying = false
	_run_inside_tick(func() -> void:
		v2._dying = true
		EventBus.unit_died.emit(v2.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
		v1._dying = true
		EventBus.unit_died.emit(v1.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	var farr_order_b: float = FarrSystem.value_farr
	assert_almost_eq(farr_order_a, farr_order_b, 1e-6,
		"Same-tick multi-death via the is_dying() exclusion path is order-invariant "
		+ "(F1 hardening — mirrors live unit_health_zero->dying->unit_died sequence)")


func test_d1a_same_tick_multi_death_fires_identically_when_threshold_met() -> void:
	# Positive companion: a 3:1 roster where BOTH same-tick deaths cross the
	# threshold. Attacker pop 6; Turan has 0 OTHER living defenders, just the 2
	# victims. For each victim, the OTHER victim is still living-in-group (not yet
	# excluded — only THIS victim is excluded), so defender_pop = 1 per death.
	# threshold = roundi(3*1)=3; attacker 6 >= 3 → each death fires -0.5.
	# Total = -1.0 regardless of order.
	for uid in [261, 262, 263, 264, 265, 266]:
		_make_unit_in_group(uid, &"piyade", Constants.TEAM_IRAN)
	var killer: FakeUnit = _make_unit_in_group(267, &"piyade", Constants.TEAM_IRAN)
	var v1: FakeUnit = _make_unit_in_group(268, &"turan_piyade", Constants.TEAM_TURAN)
	var v2: FakeUnit = _make_unit_in_group(269, &"turan_piyade", Constants.TEAM_TURAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(v1.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
		EventBus.unit_died.emit(v2.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"Two same-tick 3:1 kills each drain -0.5 → -1.0 total (50.0 → 49.0)")


# --- D1b: kicking-them-while-down drain ------------------------------------

func test_d1b_fires_when_military_broken() -> void:
	# Victim is a worker (Kargar); the Turan team has 0 living military units AND
	# 0 operational military-production buildings → military-broken → -1.0.
	# Iran (attacker) has units; that's irrelevant to D1b (it's about the victim
	# team being broken). A non-3:1 roster so D1a does NOT also fire (isolate D1b).
	_make_unit_in_group(301, &"piyade", Constants.TEAM_IRAN)              # 1 attacker
	var killer: FakeUnit = _make_unit_in_group(302, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(303, &"kargar", Constants.TEAM_TURAN)  # worker
	# Turan: no military units, no barracks. (The dying worker is excluded anyway.)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	# D1a: attacker_pop=2, defender_pop=0 (only the victim worker, excluded) → D1a
	# bails (defender_pop<1). D1b: worker + military-broken → -1.0. 50.0 → 49.0.
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"D1b fires when victim is a worker on a military-broken team → -1.0")


func test_d1b_does_not_fire_when_barracks_stands() -> void:
	# Victim worker, 0 living military units, but an OPERATIONAL military-
	# production building (Sarbaz-khaneh, produces piyade, is_complete) stands →
	# NOT military-broken → no D1b drain.
	var killer: FakeUnit = _make_unit_in_group(311, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(312, &"kargar", Constants.TEAM_TURAN)
	_make_building_in_group(313, Constants.TEAM_TURAN, [&"turan_piyade"] as Array[StringName], true)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1b does NOT fire when a complete military-production building stands")


func test_d1b_does_not_fire_when_incomplete_barracks_only() -> void:
	# An INCOMPLETE barracks does NOT count as operational → still military-broken
	# → D1b fires. (Verifies the is_complete gate.)
	var killer: FakeUnit = _make_unit_in_group(321, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(322, &"kargar", Constants.TEAM_TURAN)
	_make_building_in_group(323, Constants.TEAM_TURAN, [&"turan_piyade"] as Array[StringName], false)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"D1b fires when only an INCOMPLETE barracks exists (is_complete gate)")


func test_d1b_does_not_fire_when_military_alive() -> void:
	# Victim worker, but the team still has a living military unit → not broken.
	var killer: FakeUnit = _make_unit_in_group(331, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(332, &"kargar", Constants.TEAM_TURAN)
	_make_unit_in_group(333, &"turan_piyade", Constants.TEAM_TURAN)  # living military
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1b does NOT fire when the victim team still has a living military unit")


func test_d1b_does_not_fire_for_non_worker_victim() -> void:
	# A military-unit death on a broken team is normal attrition, not D1b.
	var killer: FakeUnit = _make_unit_in_group(341, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(342, &"turan_piyade", Constants.TEAM_TURAN)
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	# D1a: attacker_pop=1, defender_pop=0 (only victim, excluded) → bail. D1b:
	# victim is not a worker → no fire. Farr unchanged.
	assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
		"D1b only applies to worker victims; a military death does not drain")


func test_d1b_dying_military_unit_excluded_from_broken_check() -> void:
	# A military unit already in is_dying() does NOT count as "living military" —
	# so a worker dying alongside an already-dying last soldier still reads as
	# military-broken (Fix F4 — is_dying excluded from the count).
	var killer: FakeUnit = _make_unit_in_group(351, &"piyade", Constants.TEAM_IRAN)
	var victim: FakeUnit = _make_unit_in_group(352, &"kargar", Constants.TEAM_TURAN)
	_make_unit_in_group(353, &"turan_piyade", Constants.TEAM_TURAN, true)  # dying military
	_run_inside_tick(func() -> void:
		EventBus.unit_died.emit(victim.unit_id, killer.unit_id, &"melee_attack", Vector3.ZERO)
	)
	assert_almost_eq(FarrSystem.value_farr, 49.0, 1e-4,
		"D1b: an is_dying() military unit is excluded from the broken check → fires")


# --- D1 subscription contract ----------------------------------------------

func test_dispatcher_subscribes_to_unit_died_for_snowball() -> void:
	# D1 hooks unit_died (carries the killer — Fix F1). This is a DIFFERENT
	# subscription from the worker-drain unit_health_zero hook; both coexist.
	assert_true(
		EventBus.unit_died.is_connected(FarrDrainDispatcher._on_unit_died),
		"FarrDrainDispatcher MUST subscribe to unit_died for the §4.3 snowball drains"
	)
