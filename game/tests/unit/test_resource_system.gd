# Tests for ResourceSystem autoload — Phase 3 wave 1B.
#
# Contract:
#   - 01_CORE_MECHANICS.md §3 — Iran economy (Coin, Grain)
#   - 02f_PHASE_3_KICKOFF.md §3 wave 1B — ResourceSystem deliverable
#   - docs/SIMULATION_CONTRACT.md §1.1 (on-tick mutation rule), §1.6 (fixed-point)
#   - game/scripts/autoload/resource_system.gd — the SUT
#
# Naming choice (load-bearing — see resource_system.gd header):
#   The chokepoint method is `change_resource`, NOT `apply_resource_change`.
#   The latter would expand the L1 lint allowlist (`apply_*\(` pattern in
#   tools/lint_simulation.sh).
extends GutTest


var _events: Array = []


func _on_resource_changed(team: int, kind: StringName, delta_x100: int,
		new_total_x100: int) -> void:
	_events.append({
		"team": team,
		"kind": kind,
		"delta_x100": delta_x100,
		"new_total_x100": new_total_x100,
	})


# Helper: run a Callable inside a single sim tick so change_resource's on-tick
# assert is satisfied. Mirrors the pattern in test_farr_system.gd.
func _run_inside_tick(body: Callable) -> void:
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			body.call()
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)


func before_each() -> void:
	_events = []
	SimClock.reset()
	ResourceSystem.reset()
	EventBus.resource_changed.connect(_on_resource_changed)
	_events = []  # discard the synthetic emit during reset, if any


func after_each() -> void:
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)
	SimClock.reset()
	ResourceSystem.reset()


# === Initial state ==========================================================

func test_starting_coin_seeds_from_balance_data() -> void:
	# balance.tres ships economy.starting_coin = 150 for both teams.
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 150.0, 1e-6,
		"Iran starts at 150 Coin per balance.tres economy.starting_coin")
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_TURAN), 150.0, 1e-6,
		"Turan starts at 150 Coin per balance.tres economy.starting_coin")


func test_starting_grain_seeds_from_balance_data() -> void:
	# balance.tres ships economy.starting_grain = 50.
	assert_almost_eq(ResourceSystem.grain_for(Constants.TEAM_IRAN), 50.0, 1e-6,
		"Iran starts at 50 Grain per balance.tres economy.starting_grain")


func test_starting_population_is_zero() -> void:
	# No units at match start (the spawn happens in main.gd post-load).
	assert_eq(ResourceSystem.population_for(Constants.TEAM_IRAN), 0,
		"Population starts at 0")
	assert_eq(ResourceSystem.population_cap_for(Constants.TEAM_IRAN), 0,
		"Population cap starts at 0 — first Khaneh ships in Phase 3 session 2")


# === change_resource — happy path ==========================================

func test_positive_coin_delta_raises_total() -> void:
	# Start at 150 (15000 x100). Add 10 (1000 x100). New total: 160 (16000).
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, 1000,
			&"test_positive", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 160.0, 1e-6,
		"+10 Coin from 150 → 160")


func test_negative_coin_delta_lowers_total() -> void:
	# Start at 150. Spend 50 (5000 x100). New total: 100.
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, -5000,
			&"test_negative", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 100.0, 1e-6,
		"-50 Coin from 150 → 100")


func test_grain_mutation_independent_of_coin() -> void:
	# Modifying grain doesn't move coin.
	var coin_pre: float = ResourceSystem.coin_for(Constants.TEAM_IRAN)
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_GRAIN, 500,
			&"test_grain", null)
	)
	assert_almost_eq(ResourceSystem.grain_for(Constants.TEAM_IRAN), 55.0, 1e-6,
		"+5 Grain from 50 → 55")
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), coin_pre, 1e-6,
		"Coin unchanged when modifying Grain")


func test_per_team_isolation() -> void:
	# Mutating Iran's coin doesn't change Turan's. Both teams start at 150.
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, 5000,
			&"test_iran_only", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 200.0, 1e-6,
		"Iran rose to 200")
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_TURAN), 150.0, 1e-6,
		"Turan unchanged at 150")


# === Clamping ==============================================================

func test_overspend_clamps_to_zero() -> void:
	# Start at 150. Try to spend 200 (20000 x100). Clamped to 0.
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, -20000,
			&"test_overspend", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 0.0, 1e-6,
		"Overspend clamped to 0")


# === Fixed-point fidelity ===================================================

func test_fixed_point_storage_avoids_float_drift() -> void:
	# Add 0.05 ten times. With float math this would drift; fixed-point is exact.
	_run_inside_tick(func() -> void:
		for _i in range(10):
			ResourceSystem.change_resource(
				Constants.TEAM_IRAN, Constants.KIND_COIN, 5,
				&"test_drift", null)
	)
	# 150.0 + 10 * 0.05 = 150.5 exactly.
	assert_eq(ResourceSystem.coin_x100_for(Constants.TEAM_IRAN), 15050,
		"10 × 0.05 Coin deltas land exactly at 15050 (150.5)")


# === Signal emission ========================================================

func test_resource_changed_signal_fires_on_mutation() -> void:
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, 1000,
			&"test_signal", null)
	)
	assert_eq(_events.size(), 1, "Exactly one resource_changed emit")
	var ev: Dictionary = _events[0]
	assert_eq(ev["team"], Constants.TEAM_IRAN, "team carries through")
	assert_eq(ev["kind"], Constants.KIND_COIN, "kind carries through")
	assert_eq(ev["delta_x100"], 1000, "delta_x100 carries the effective delta")
	assert_eq(ev["new_total_x100"], 16000,
		"new_total_x100 reflects post-mutation total (150 + 10 = 160)")


func test_emit_reports_clamped_delta_on_overspend() -> void:
	# Start at 150 (15000). Request -20000 (overspend). Effective delta = -15000
	# (the post-clamp move), NOT -20000.
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, -20000,
			&"test_clamp_signal", null)
	)
	assert_eq(_events.size(), 1)
	var ev: Dictionary = _events[0]
	assert_eq(ev["delta_x100"], -15000,
		"Emitted delta reflects clamped move (-150, not -200)")
	assert_eq(ev["new_total_x100"], 0,
		"Post-clamp total is 0")


# === Unknown-kind rejection =================================================

func test_unknown_kind_logs_error_and_no_mutation() -> void:
	# A typo or future-kind that isn't COIN/GRAIN gets rejected. No mutation,
	# no signal. (push_error is logged; we can't capture it easily, but we can
	# verify the no-mutation outcome.)
	var coin_pre: float = ResourceSystem.coin_for(Constants.TEAM_IRAN)
	var grain_pre: float = ResourceSystem.grain_for(Constants.TEAM_IRAN)
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, &"unknown_kind", 1000,
			&"test_unknown", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), coin_pre, 1e-6,
		"Coin unchanged on unknown-kind reject")
	assert_almost_eq(ResourceSystem.grain_for(Constants.TEAM_IRAN), grain_pre, 1e-6,
		"Grain unchanged on unknown-kind reject")
	assert_eq(_events.size(), 0,
		"No signal emitted on unknown-kind reject")


# === reset() symmetry =======================================================

# === Node registry — Phase 3 session 2 wave 1A (Room A Decision 4) =========
#
# Per Room A's ratified decision (2026-05-14): ResourceSystem exposes
# register_node / unregister_node so future AI consumers (Phase 6 scout AI,
# Phase 3 DummyAI variants) can enumerate resource sources by kind without
# walking the scene tree each time.
#
# Wave-1A scope: ship the API + idempotency + double-register-warning.
# No consumer exists yet; the API surface lands so Mazra'eh's
# _on_placement_complete can call register_node when the wave-1A Mazra'eh
# ships in this same wave (world-builder's slice). Phase 6 / future
# query-side helpers (get_nodes_of_kind, by_team filter) land when a
# consumer demands them.
#
# v1.2.1 fix-up (2026-05-14): API now takes kind as an explicit parameter:
# `register_node(node, kind: StringName)`. Original v1.2.0 derived kind from
# `node.kind` field, but that breaks for Mazra'eh (which extends Building,
# so `node.kind = &"mazraeh"` is the Building kind, NOT the resource kind
# &"grain"). Caller passes the RESOURCE kind explicitly — eliminates the
# field-name ambiguity at the seam between MineNode (kind IS resource kind)
# and Mazra'eh-as-Building (kind is Building kind).

func test_register_node_stores_under_explicit_kind() -> void:
	# Caller passes the resource kind explicitly. The node's `kind` field
	# (if any) is ignored — the registry trusts the caller's intent.
	var dummy: _FakeResourceNode = _FakeResourceNode.new()
	dummy.kind = &"coin"  # node's own kind (may be Building kind, doesn't matter)
	add_child_autofree(dummy)
	ResourceSystem.register_node(dummy, &"coin")
	var found: bool = ResourceSystem.is_node_registered(dummy)
	assert_true(found,
		"register_node(node, &\"coin\") stores the node — "
		+ "is_node_registered returns true")
	assert_eq(ResourceSystem.registered_node_count_for_kind(&"coin"), 1,
		"node lands in the &\"coin\" bucket")


func test_register_node_decouples_node_kind_from_registered_kind() -> void:
	# v1.2.1 motivating case: Mazra'eh has `kind = &"mazraeh"` (Building kind)
	# but registers as a GRAIN source. The registered kind is the explicit
	# parameter, not the node.kind field.
	var mazraeh_like: _FakeResourceNode = _FakeResourceNode.new()
	mazraeh_like.kind = &"mazraeh"  # Building kind (irrelevant to registry)
	add_child_autofree(mazraeh_like)
	ResourceSystem.register_node(mazraeh_like, &"grain")  # resource kind explicit
	assert_eq(ResourceSystem.registered_node_count_for_kind(&"grain"), 1,
		"Mazra'eh-like (kind=&\"mazraeh\") registers under explicit &\"grain\"")
	assert_eq(ResourceSystem.registered_node_count_for_kind(&"mazraeh"), 0,
		"Mazra'eh-like does NOT register under its Building kind &\"mazraeh\" — "
		+ "the explicit registered kind is the authority")


func test_unregister_node_removes_a_registered_node() -> void:
	var dummy: _FakeResourceNode = _FakeResourceNode.new()
	dummy.kind = &"grain"
	add_child_autofree(dummy)
	ResourceSystem.register_node(dummy, &"grain")
	ResourceSystem.unregister_node(dummy)
	var found: bool = ResourceSystem.is_node_registered(dummy)
	assert_false(found,
		"unregister_node removes the node — subsequent is_node_registered "
		+ "returns false")


func test_unregister_node_no_kind_arg_finds_node_under_any_kind() -> void:
	# unregister_node intentionally does NOT take a kind argument — it scans
	# all buckets. This matters because the caller's death/teardown path may
	# not remember which kind the node was registered under (the registered
	# kind is decided at register-time and lives in the registry, not on the
	# node itself). The scan is O(num_kinds) — trivial at MVP scale (~2-3 kinds).
	var dummy: _FakeResourceNode = _FakeResourceNode.new()
	dummy.kind = &"mazraeh"  # Building kind
	add_child_autofree(dummy)
	ResourceSystem.register_node(dummy, &"grain")  # registered under resource kind
	# The caller's teardown path calls unregister_node(self) — no kind argument.
	ResourceSystem.unregister_node(dummy)
	assert_false(ResourceSystem.is_node_registered(dummy),
		"unregister_node(node) finds and removes the node regardless of "
		+ "which kind bucket holds it — no kind argument needed")


func test_unregister_node_is_idempotent_on_unknown_node() -> void:
	# Per Room A — "unregister of unknown is no-op." A Mazra'eh that
	# never managed to register (perhaps because it destructs before
	# its _on_placement_complete fires) should not crash the system on
	# unregister-during-cleanup.
	var unknown: _FakeResourceNode = _FakeResourceNode.new()
	unknown.kind = &"grain"
	add_child_autofree(unknown)
	# Note: NEVER registered.
	ResourceSystem.unregister_node(unknown)  # must not crash
	assert_false(ResourceSystem.is_node_registered(unknown),
		"unregister of an unknown node is a no-op (still not registered)")


func test_double_register_emits_warning_but_does_not_duplicate() -> void:
	# Per Room A — "double-register-warning." If a Mazra'eh's
	# _on_placement_complete is somehow called twice (test fixture bug,
	# future construction-state refactor), we want a loud warning so the
	# bug is observable, but we DO NOT want the node listed twice in the
	# registry (would double-count grain-source enumeration for AI).
	var dummy: _FakeResourceNode = _FakeResourceNode.new()
	dummy.kind = &"coin"
	add_child_autofree(dummy)
	ResourceSystem.register_node(dummy, &"coin")
	# Second registration with the SAME kind — must not crash, must not duplicate.
	ResourceSystem.register_node(dummy, &"coin")
	# Verify only one entry exists by counting.
	var count: int = ResourceSystem.registered_node_count_for_kind(&"coin")
	assert_eq(count, 1,
		"double-register yields ONE entry, not two — registry is idempotent")


func test_register_node_handles_multiple_kinds() -> void:
	# A MineNode (registered as &"coin") and a Mazra'eh (registered as
	# &"grain") should both register without colliding. Verified via the
	# per-kind count helper.
	var mine: _FakeResourceNode = _FakeResourceNode.new()
	mine.kind = &"coin"  # matches registered kind for MineNode (kind IS resource kind)
	add_child_autofree(mine)
	var farm: _FakeResourceNode = _FakeResourceNode.new()
	farm.kind = &"mazraeh"  # Mazra'eh case — kind is Building kind
	add_child_autofree(farm)
	ResourceSystem.register_node(mine, &"coin")
	ResourceSystem.register_node(farm, &"grain")  # explicit resource kind
	assert_eq(ResourceSystem.registered_node_count_for_kind(&"coin"), 1,
		"coin registry has 1 entry (the mine)")
	assert_eq(ResourceSystem.registered_node_count_for_kind(&"grain"), 1,
		"grain registry has 1 entry (the farm) — no cross-kind collision")


func test_reset_clears_node_registry() -> void:
	# reset() is called by MatchHarness between simulated matches. The
	# node registry must be cleared too — otherwise a node from a prior
	# match would linger and skew enumeration in the next.
	var dummy: _FakeResourceNode = _FakeResourceNode.new()
	dummy.kind = &"coin"
	add_child_autofree(dummy)
	ResourceSystem.register_node(dummy, &"coin")
	assert_true(ResourceSystem.is_node_registered(dummy))
	ResourceSystem.reset()
	assert_false(ResourceSystem.is_node_registered(dummy),
		"reset() clears the node registry — match teardown discipline")


# Inner-class fake ResourceNode for the registry tests. Has only what the
# registry contract requires (a `kind` field for backward-compat with
# v1.2.0 callers; the v1.2.1 register_node signature uses the explicit
# kind arg, but the field still exists for cases where consumers want to
# read the node's own kind for other reasons).
# Real ResourceNode / Mazra'eh extend Node3D, but the registry shouldn't
# care about Node3D-ness — explicit kind is the registry contract.
class _FakeResourceNode extends Node:
	var kind: StringName = &""


func test_reset_restores_starting_values() -> void:
	# Mutate, then reset, then verify we're back at the starting values.
	_run_inside_tick(func() -> void:
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_COIN, 5000,
			&"test_mutate", null)
		ResourceSystem.change_resource(
			Constants.TEAM_IRAN, Constants.KIND_GRAIN, -1000,
			&"test_mutate", null)
	)
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 200.0, 1e-6,
		"sanity: mutation applied")
	ResourceSystem.reset()
	assert_almost_eq(ResourceSystem.coin_for(Constants.TEAM_IRAN), 150.0, 1e-6,
		"reset restores Iran coin to 150")
	assert_almost_eq(ResourceSystem.grain_for(Constants.TEAM_IRAN), 50.0, 1e-6,
		"reset restores Iran grain to 50")
