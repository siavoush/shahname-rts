# Integration test — Phase 3 wave 3 (2/5): ResourceSystem chokepoint correctness.
#
# Contract: 02f_PHASE_3_KICKOFF.md §3 "Wave 3" target 2.
# Two test angles per the brief:
#   (a) Positive — a deposit routes through change_resource and emits
#       EventBus.resource_changed with the correct (team, kind, delta_x100,
#       new_total_x100) tuple. The gather-loop test covers this at the
#       functional level; this file asserts the SIGNAL tuple exactly.
#   (b) Boundary — underflow guard: coin_x100 cannot go below 0 (clamp +
#       no negative balance); change_population underflow guard (population
#       cannot go negative). Population ceiling (population cannot exceed
#       population_cap) is a LATER item noted in §3 — that enforcement is
#       not in ResourceSystem today (Phase 3 session 1 has no unit-production
#       flow yet); see note at bottom of file.
#
# All ResourceSystem mutations must go through change_resource (or the
# sister chokepoints change_population / change_population_cap). This file
# directly calls those methods inside a tick-boundary to verify the
# chokepoint contract without going through the full gather loop.
#
# Pitfall #2: FSM/per-tick driver. We use SimClock._is_ticking = true/false
# to bracket the on-tick assertions, same pattern as gather-loop tests.
extends GutTest


const MatchHarnessScript: Script = preload("res://tests/harness/match_harness.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var harness: Variant = null


func before_each() -> void:
	harness = MatchHarnessScript.new()
	harness.start_match(0, &"empty")
	ResourceSystem.reset()
	FarrSystem.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	ResourceSystem.reset()
	FarrSystem.reset()
	harness.teardown()
	harness = null


# Helper: call a ResourceSystem method inside a tick boundary so the
# on-tick assert in change_resource / change_population passes.
func _call_in_tick(fn: Callable) -> void:
	SimClock._is_ticking = true
	fn.call()
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# Positive — change_resource emits resource_changed with the correct tuple.
# ---------------------------------------------------------------------------

var _events: Array = []


func _on_resource_changed(team: int, kind: StringName, delta_x100: int,
		new_total_x100: int) -> void:
	_events.append({
		&"team": team, &"kind": kind,
		&"delta_x100": delta_x100, &"new_total_x100": new_total_x100,
	})


func test_change_resource_emits_correct_resource_changed_tuple() -> void:
	_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)

	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var deposit_amount: int = 1000  # 10 Coin × 100

	_call_in_tick(func():
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN,
			deposit_amount, &"test_deposit", null)
	)

	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	assert_gt(_events.size(), 0, "change_resource must emit resource_changed")
	# Find the coin event (there may be others from harness setup).
	var coin_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == Constants.KIND_COIN and ev[&"team"] == Constants.TEAM_IRAN and ev[&"delta_x100"] > 0:
			coin_ev = ev
			break
	assert_not_null(coin_ev,
		"resource_changed must fire with kind=KIND_COIN and positive delta for Iran")
	assert_eq(coin_ev[&"team"], Constants.TEAM_IRAN,
		"Signal must carry TEAM_IRAN")
	assert_eq(coin_ev[&"kind"], Constants.KIND_COIN,
		"Signal must carry KIND_COIN")
	assert_eq(coin_ev[&"delta_x100"], deposit_amount,
		"delta_x100 must equal the deposited amount (1000)")
	assert_eq(coin_ev[&"new_total_x100"], coin_before + deposit_amount,
		"new_total_x100 = pre + delta (correct running total)")


func test_change_resource_grain_emits_correct_tuple() -> void:
	_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)

	var grain_before: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	var delta: int = 500  # 5 Grain × 100

	_call_in_tick(func():
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_GRAIN,
			delta, &"test_grain", null)
	)

	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	var grain_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == Constants.KIND_GRAIN and ev[&"team"] == Constants.TEAM_IRAN and ev[&"delta_x100"] > 0:
			grain_ev = ev
			break
	assert_not_null(grain_ev, "change_resource must emit for KIND_GRAIN")
	assert_eq(grain_ev[&"delta_x100"], delta,
		"grain delta_x100 = 500")
	assert_eq(grain_ev[&"new_total_x100"], grain_before + delta,
		"grain new_total_x100 correct")


# ---------------------------------------------------------------------------
# Boundary — underflow guard: coin cannot go below 0.
# ---------------------------------------------------------------------------

func test_coin_underflow_clamps_at_zero_not_negative() -> void:
	# Spend more Coin than the team has. The clamp should floor at 0.
	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_gt(coin_before, 0, "Sanity: team must start with some Coin")

	var overspend: int = coin_before + 9999  # far more than available

	_call_in_tick(func():
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN,
			-overspend, &"test_overspend", null)
	)

	var coin_after: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	assert_eq(coin_after, 0,
		"Coin underflow must clamp at 0 — no negative balance allowed "
		+ "(got " + str(coin_after) + " after overspend)")
	assert_true(coin_after >= 0,
		"coin_x100_for must never return a negative value")


func test_coin_underflow_emits_correct_effective_delta() -> void:
	# When the clamp fires, the emitted delta reflects what ACTUALLY changed,
	# not the requested amount (so the running total in the signal stays
	# coherent with the stored value).
	_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)

	var coin_before: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	var overspend: int = coin_before + 5000

	_call_in_tick(func():
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN,
			-overspend, &"test_underflow_signal", null)
	)

	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	var coin_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == Constants.KIND_COIN and ev[&"team"] == Constants.TEAM_IRAN and ev[&"delta_x100"] < 0:
			coin_ev = ev
			break
	assert_not_null(coin_ev, "Underflow spend must emit a resource_changed event")
	# Effective delta = post - pre = 0 - coin_before = -coin_before
	assert_eq(coin_ev[&"delta_x100"], -coin_before,
		"Effective delta must reflect only what actually changed "
		+ "(clamp truncates the over-spend)")
	assert_eq(coin_ev[&"new_total_x100"], 0,
		"new_total_x100 must be 0 after underflow clamp")


# ---------------------------------------------------------------------------
# Boundary — grain underflow guard (same clamp pattern).
# ---------------------------------------------------------------------------

func test_grain_underflow_clamps_at_zero() -> void:
	var grain_before: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	assert_gt(grain_before, 0, "Sanity: team must start with some Grain")

	_call_in_tick(func():
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_GRAIN,
			-(grain_before + 1000), &"test_grain_underflow", null)
	)

	var grain_after: int = ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)
	assert_eq(grain_after, 0,
		"Grain underflow must clamp at 0")


# ---------------------------------------------------------------------------
# Boundary — change_population underflow guard.
# ---------------------------------------------------------------------------

func test_population_cannot_go_negative() -> void:
	# Population starts at 0 (no units spawned). Try to subtract below 0.
	_call_in_tick(func():
		ResourceSystem.change_population(
			Constants.TEAM_IRAN, -5, &"test_pop_underflow", null)
	)
	var pop_after: int = ResourceSystem.population_for(Constants.TEAM_IRAN)
	assert_eq(pop_after, 0,
		"Population must clamp at 0, not go negative")
	assert_true(pop_after >= 0,
		"population_for must never return negative")


# ---------------------------------------------------------------------------
# Positive — change_population emits resource_changed under &"population" kind.
# ---------------------------------------------------------------------------

func test_change_population_emits_resource_changed() -> void:
	_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)

	_call_in_tick(func():
		ResourceSystem.change_population(
			Constants.TEAM_IRAN, 3, &"test_pop_spawn", null)
	)

	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	var pop_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == &"population" and ev[&"team"] == Constants.TEAM_IRAN:
			pop_ev = ev
			break
	assert_not_null(pop_ev,
		"change_population must emit resource_changed with kind=&\"population\"")
	assert_eq(pop_ev[&"delta_x100"], 3,
		"population delta_x100 = 3 (units spawned)")
	assert_eq(pop_ev[&"new_total_x100"], 3,
		"population new_total = 3 (started at 0)")


# ---------------------------------------------------------------------------
# Positive — change_population_cap emits resource_changed under &"population_cap".
# ---------------------------------------------------------------------------

func test_change_population_cap_emits_resource_changed() -> void:
	_events.clear()
	EventBus.resource_changed.connect(_on_resource_changed)

	_call_in_tick(func():
		ResourceSystem.change_population_cap(
			Constants.TEAM_IRAN, 10, &"test_khaneh_placed", null)
	)

	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	var cap_ev: Variant = null
	for ev in _events:
		if ev[&"kind"] == &"population_cap" and ev[&"team"] == Constants.TEAM_IRAN:
			cap_ev = ev
			break
	assert_not_null(cap_ev,
		"change_population_cap must emit resource_changed with kind=&\"population_cap\"")
	assert_eq(cap_ev[&"delta_x100"], 10,
		"population_cap delta = 10 (one Khaneh)")
	assert_eq(cap_ev[&"new_total_x100"], 10,
		"population_cap new_total = 10 (started at 0)")

# NOTE (LATER): Population ceiling enforcement — preventing population from
# exceeding population_cap — is not yet implemented in ResourceSystem Phase 3
# session 1. Unit production (Sarbaz-khaneh) ships in Phase 3 session 2; the
# ceiling check belongs there where the production system does the affordability
# check before calling change_population. We do NOT add a defensive clamp inside
# change_population itself because the ceiling is an application-layer rule (the
# callers must check before spending), not an invariant that belongs in the
# chokepoint (same pattern: coin underflow is structural; coin "can I afford
# this" is application-layer and lives in the production system).
# If a test author adds that ceiling guard in a future wave, remove this note.
