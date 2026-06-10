# Integration test — Wave 1B Commit 3 (+ Commit 3.5 QA supplement):
# Ma'dan-buffs-MineNode-extraction full chain.
#
# Verifies the end-to-end Option B behavior (Open Space Room A 2026-05-14):
# placing a Ma'dan adjacent to a MineNode boosts the Kargar's complete_extract
# payload via the ResourceNode modifier-registry API shipped at 3d7b722.
#
# Commit 3 (5a53108) coverage (gp-sys):
#   1. Ma'dan placement registers it as an extraction_modifier on the
#      nearest MineNode within radius (4m default).
#   2. complete_extract on the buffed mine returns the multiplied payload
#      (base * 1.5 = 1.5x default per balance-engineer's d798e78).
#   3. Reserves on the buffed mine decrement by the EFFECTIVE amount (faster
#      depletion — semantically correct: the buff amplifies both haul AND wear).
#   4. A Ma'dan placed OUT of radius leaves the mine's yield untouched (no
#      false-positive buff).
#   5. Counterfactual: unbuffed mine returns base payload.
#
# Commit 3.5 (qa-engineer supplement) — missing tests from Commit 3 brief:
#   6. Non-stacking: two Ma'dans adjacent to the same mine — first-registered
#      wins (modifier_count == 1; effective yield 1500, NOT 2250 = 1.5^2 x base).
#      Per design Q3 (not-stacking, first-registered-wins per BalanceData
#      modifier_stacks=false from balance-engineer's d798e78).
#   7. Cross-cutting exclusion: Ma'dan is NOT in &"resource_nodes" group
#      (it is a buff-emitter Building, not a resource source). It IS in
#      &"buildings" group. BoxSelectHandler's _collect_unit_shaped filter
#      (not is_in_group(&"buildings")) correctly excludes it.
#   8. class_name alignment: madan.gd declares `class_name Madan` (no
#      apostrophe — loremaster transliteration-consistency rule). Catches
#      accidental rename drift.
#
# _run_inside_tick helper (new tests — Commit 3.5 additions):
#   Per godot-reviewer-p3s2 note at wave-1A re-review: new test code should
#   adopt the _run_inside_tick helper (see test_resource_system.gd:31-37)
#   rather than direct _is_ticking=true/false writes.
#   Existing tests (Commit 3) are left untouched; new tests use the helper.
#
# Pitfall #11: never use is_instance_valid as a death-detection predicate
# in SimClock._test_run_tick loops. Not relevant here (no death paths
# exercised); noted per permanent per-file contract.
extends GutTest


const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")
const MazraehScene: PackedScene = preload(
	"res://scenes/world/buildings/mazraeh.tscn")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _mine: Variant = null
var _madan: Variant = null
var _madan2: Variant = null
var _mazraeh: Variant = null


func before_each() -> void:
	SimClock.reset()
	ResourceSystem.reset()
	BuildingScript.call(&"reset_id_counter")
	_mine = null
	_madan = null
	_madan2 = null
	_mazraeh = null


func after_each() -> void:
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	if _madan != null and is_instance_valid(_madan):
		_madan.queue_free()
	if _madan2 != null and is_instance_valid(_madan2):
		_madan2.queue_free()
	if _mazraeh != null and is_instance_valid(_mazraeh):
		_mazraeh.queue_free()
	_mine = null
	_madan = null
	_madan2 = null
	_mazraeh = null
	ResourceSystem.reset()
	BuildingScript.call(&"reset_id_counter")
	SimClock.reset()


# Helper: run body Callable inside a single sim tick so on-tick assertions
# (complete_extract, change_resource) are satisfied without direct
# _is_ticking writes. Mirrors test_resource_system.gd:31-37.
# New tests (Commit 3.5) use this helper. Existing Commit 3 tests left as-is.
func _run_inside_tick(body: Callable) -> void:
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			body.call()
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)


func _spawn_mine_at(pos: Vector3) -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	return m


# SSOT expectation helpers (wave/b1-mine-ssot, review ARCH-5/GP-3):
# expected yields are READ from the real balance.tres, never re-pinned as
# literals (§9.M8 real-data round-trip — designer retunes of
# coin_yield_per_trip / modifier_value_x100 keep this file green).
#   base   = economy.resource_nodes.coin_yield_per_trip × 100 (fixed-point)
#   buffed = base × buildings[&"madan"].modifier_value_x100 / 100
# At the current .tres values: base 1000 (10 Coin), buffed 1500 (×1.5).
func _base_yield_x100() -> int:
	var bd: Resource = load(Constants.PATH_BALANCE_DATA)
	assert_not_null(bd, "balance.tres must load for SSOT expectations")
	var econ: Resource = bd.get(&"economy")
	var cfg: Resource = econ.get(&"resource_nodes")
	return int(cfg.get(&"coin_yield_per_trip")) * 100


func _madan_multiplier_x100() -> int:
	var bd: Resource = load(Constants.PATH_BALANCE_DATA)
	assert_not_null(bd, "balance.tres must load for SSOT expectations")
	var bldgs: Dictionary = bd.get(&"buildings")
	var stats: Resource = bldgs[&"madan"]
	return int(stats.get(&"modifier_value_x100"))


func _buffed_yield_x100() -> int:
	return _base_yield_x100() * _madan_multiplier_x100() / 100


func _spawn_madan_at(pos: Vector3) -> Variant:
	var b: Variant = MadanScene.instantiate()
	add_child_autofree(b)
	b.team = Constants.TEAM_IRAN
	# Per wave 1C two-stage lifecycle: place_at fires Stage 1
	# (_on_placement_complete — structural). The modifier-registration
	# side-effect is gated on Stage 2 (_on_construction_complete) which
	# UnitState_Constructing fires after construction_ticks elapse. For
	# integration tests that only need the final operational state, we
	# fire both stages back-to-back here. Tests that need to assert
	# pre-Stage-2 behavior (mid-construction Ma'dan does NOT buff) drive
	# the construction state directly; see
	# test_madan_does_not_buff_mine_during_construction below.
	b.place_at(pos, Constants.TEAM_IRAN, 1)
	b._on_construction_complete(1)
	return b


# Spawn a Ma'dan with Stage 1 only — mid-construction. The
# modifier-registration side-effect must NOT have fired. Used by the
# behavioral test for the new wave-1C operational-gating contract.
func _spawn_madan_mid_construction_at(pos: Vector3) -> Variant:
	var b: Variant = MadanScene.instantiate()
	add_child_autofree(b)
	b.team = Constants.TEAM_IRAN
	b.place_at(pos, Constants.TEAM_IRAN, 1)
	return b


# ---------------------------------------------------------------------------
# Modifier-registration chain — Ma'dan placement registers on adjacent mine
# ---------------------------------------------------------------------------

func test_madan_placement_registers_extraction_modifier_on_adjacent_mine() -> void:
	# Mine at origin; Ma'dan at (3, 0, 0) is within the 4m default radius.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	# Per Commit 2 register_extraction_modifier, the modifier list on
	# the mine should contain exactly one modifier after Ma'dan placement.
	assert_eq(_mine.registered_modifier_count(), 1,
		"Mine within Ma'dan radius must have 1 registered modifier "
		+ "after Ma'dan placement")


func test_madan_placement_out_of_radius_does_not_register() -> void:
	# Mine at origin; Ma'dan at (10, 0, 0) is OUTSIDE the 4m default radius.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(10.0, 0.0, 0.0))
	assert_eq(_mine.registered_modifier_count(), 0,
		"Mine out of Ma'dan radius must have 0 registered modifiers")


# ---------------------------------------------------------------------------
# Wave 1C two-stage lifecycle — mid-construction Ma'dan does NOT buff
# ---------------------------------------------------------------------------
#
# The session-3 wave-1C operational-gating contract: a Ma'dan that has
# been placed structurally (Stage 1, _on_placement_complete) but has
# NOT yet completed construction (Stage 2, _on_construction_complete)
# must NOT register as an extraction modifier on the adjacent mine.
# The buff is gated on Stage 2.
#
# BEHAVIORAL coverage: verify that the mine's effective yield while
# the Ma'dan is mid-construction matches the UNBUFFED value (1000 x100,
# the base yield_per_trip_x100), NOT the buffed value (1500 x100 with
# the 1.5x modifier). This is the load-bearing behavioral assertion —
# a structural check (modifier_count == 0) is also asserted, but the
# yield equality is what matters to gameplay.

func test_madan_does_not_buff_mine_during_construction() -> void:
	# Mine at origin; Ma'dan at (3, 0, 0) is within the 4m default radius
	# of the mine. Place the Ma'dan with Stage 1 ONLY (not Stage 2) —
	# this is the mid-construction state. The mine must NOT have a
	# registered modifier and must yield the BASE amount on extract.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_mid_construction_at(Vector3(3.0, 0.0, 0.0))
	# Structural: no modifier registered yet — Stage 2 hasn't fired.
	assert_eq(_mine.registered_modifier_count(), 0,
		"Mid-construction Ma'dan (Stage 1 only) must NOT register as a "
		+ "modifier on the adjacent mine. The registration is gated on "
		+ "_on_construction_complete (Stage 2, wave 1C operational gate).")
	# Behavioral: complete_extract on the mine must yield the BASE
	# amount, not the buffed amount. This is the gameplay-observable
	# assertion that locks the contract.
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], _base_yield_x100(),
		"Mid-construction Ma'dan: mine must yield the BASE coin_yield_per_trip "
		+ "x100 from balance.tres, NOT the buffed yield. Workers gathering "
		+ "from the adjacent mine while the Ma'dan is half-built see the "
		+ "un-amplified yield.")


func test_madan_buff_applies_once_construction_completes() -> void:
	# Counterpart to the previous test: fire Stage 2 on the same Ma'dan
	# (place it mid-construction, then fire _on_construction_complete
	# directly to simulate the dwell elapsing). The buff must apply.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_mid_construction_at(Vector3(3.0, 0.0, 0.0))
	# Pre-condition: no modifier yet.
	assert_eq(_mine.registered_modifier_count(), 0,
		"Pre-condition: mid-construction Ma'dan has not yet buffed")
	# Fire Stage 2 — simulates UnitState_Constructing's dwell-complete
	# branch calling _on_construction_complete on the building.
	_madan._on_construction_complete(1)
	assert_eq(_mine.registered_modifier_count(), 1,
		"After _on_construction_complete (Stage 2), Ma'dan registers as "
		+ "an extraction modifier on the adjacent mine. The buff applies "
		+ "from this tick onward.")
	# Behavioral: complete_extract now yields the buffed amount (1500).
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], _buffed_yield_x100(),
		"Post-Stage-2: mine yields the buffed amount "
		+ "(base coin_yield_per_trip x100 × madan modifier_value_x100 / 100, "
		+ "both from balance.tres).")


# ---------------------------------------------------------------------------
# Effective yield — buffed mine's complete_extract returns multiplied payload
# ---------------------------------------------------------------------------

func test_buffed_mine_complete_extract_returns_multiplied_payload() -> void:
	# Set up the buff scenario: Ma'dan adjacent to mine. Then exercise
	# complete_extract on the mine via a synthetic worker unit_id.
	#
	# We bypass the full Kargar / UnitState_Gathering chain — that's
	# covered by test_phase_3_gather_loop / test_phase_3_multi_cycle_gather.
	# This integration test specifically verifies the modifier-multiplier
	# math at the seam where Commit 1's Ma'dan-side calls hit Commit 2's
	# MineNode-side API.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	# SSOT (wave/b1-mine-ssot): base yield = coin_yield_per_trip × 100 from
	# balance.tres; Ma'dan multiplier = modifier_value_x100 from the madan
	# BuildingStats. Expected effective = base * mult / 100.
	var base_yield: int = _mine.yield_per_trip_x100
	assert_eq(base_yield, _base_yield_x100(),
		"Pre-condition: MineNode yield_per_trip_x100 matches balance.tres "
		+ "coin_yield_per_trip x100 (SSOT wiring)")
	# Drive a synthetic gather cycle: request → complete.
	# Note: request/complete must run on-tick per SimClock contract.
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	# Buffed payload reflects the modifier multiplier.
	assert_eq(payload[&"amount_x100"], _buffed_yield_x100(),
		"Buffed mine's complete_extract returns base × madan multiplier "
		+ "(both read from balance.tres)")
	assert_eq(payload[&"kind"], &"coin",
		"Buffed mine's payload retains kind = &\"coin\"")


func test_unbuffed_mine_complete_extract_returns_base_payload() -> void:
	# Counterfactual: no Ma'dan, mine yields the base balance.tres payload.
	_mine = _spawn_mine_at(Vector3.ZERO)
	# Sanity: no modifiers registered.
	assert_eq(_mine.registered_modifier_count(), 0)
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], _base_yield_x100(),
		"Unbuffed mine returns base coin_yield_per_trip x100 from "
		+ "balance.tres (no multiplier applied)")


# ---------------------------------------------------------------------------
# Reserves accounting — buffed mine depletes faster per trip
# ---------------------------------------------------------------------------

func test_buffed_mine_reserves_decrement_by_effective_amount() -> void:
	# A buffed mine should consume the EFFECTIVE amount from reserves,
	# not the base amount. This is the "amplifies haul AND wear"
	# semantics from Commit 2's design note.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	var initial_reserves: int = _mine.reserves_x100
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	# Reserves should decrement by the EFFECTIVE (buffed) amount.
	var buffed: int = _buffed_yield_x100()
	assert_eq(payload[&"amount_x100"], buffed)
	assert_eq(_mine.reserves_x100, initial_reserves - buffed,
		"Buffed mine reserves decrement by EFFECTIVE (buffed) amount, "
		+ "not the base yield")


# ===========================================================================
# Non-stacking — two Ma'dans adjacent to the same mine (Commit 3.5 addition)
# ===========================================================================
#
# Per design Q3 (2026-05-14 + lead's update 2026-05-15):
#   modifier_stacks = false (first-registered-wins).
# Two Ma'dans both within radius of the same mine: only the first registers;
# the second register call is silently rejected.
# Effective yield = base * 1.5 = 1500, NOT base * 1.5 * 1.5 = 2250.
# Modifier count on mine = 1 (not 2).

func test_two_madans_adjacent_mine_only_first_registers() -> void:
	# Both Ma'dans are within 4m of the mine at origin.
	# Place the first at (2, 0, 0) and the second at (-2, 0, 0).
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(2.0, 0.0, 0.0))
	_madan2 = _spawn_madan_at(Vector3(-2.0, 0.0, 0.0))
	# Only the first-registered modifier should be in the list.
	assert_eq(_mine.registered_modifier_count(), 1,
		"With modifier_stacks=false, mine must have exactly 1 modifier "
		+ "even after two Ma'dans register. First-registered-wins per Q3.")


func test_two_madans_effective_yield_is_not_stacked() -> void:
	# Verify effective yield = 1500 (1.5x), NOT 2250 (1.5 * 1.5 x).
	# This is the empirical lock on non-stacking semantics.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(2.0, 0.0, 0.0))
	_madan2 = _spawn_madan_at(Vector3(-2.0, 0.0, 0.0))
	# Pre-condition: single modifier registered.
	assert_eq(_mine.registered_modifier_count(), 1)
	# Check effective yield via effective_yield_per_trip_x100 directly
	# (no need to run complete_extract; the modifier chain is the seam).
	var effective: int = _mine.effective_yield_per_trip_x100()
	var single_buff: int = _buffed_yield_x100()
	var double_buff: int = single_buff * _madan_multiplier_x100() / 100
	assert_eq(effective, single_buff,
		"Effective yield with two adjacent Ma'dans must be the SINGLE-buff "
		+ "value (base × multiplier, from balance.tres), NOT the squared "
		+ ("multiplier (%d) which stacking would produce. " % double_buff)
		+ "modifier_stacks=false per balance-engineer's d798e78.")


func test_second_madan_register_returns_false_non_stacking() -> void:
	# register_extraction_modifier returns false on rejection per its header.
	# Verify the second Ma'dan's registration is rejected.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(2.0, 0.0, 0.0))
	# First Ma'dan already registered via _spawn_madan_at's place_at.
	# Manually attempt to register the second Ma'dan via the API directly
	# (bypassing the placement-time path to test the API surface cleanly).
	var second_madan: Variant = MadanScene.instantiate()
	add_child_autofree(second_madan)
	second_madan.team = Constants.TEAM_IRAN
	# Register directly — this is the path place_at would call.
	var result: bool = _mine.register_extraction_modifier(second_madan)
	assert_false(result,
		"register_extraction_modifier must return false when modifier_stacks=false "
		+ "and a modifier is already registered (first-registered-wins, Q3).")
	second_madan.queue_free()


# ===========================================================================
# Cross-cutting exclusion (Commit 3.5 addition)
# ===========================================================================
#
# Ma'dan is a buff-emitter Building, not a resource source or a selectable unit.
# Per wave-1A BLOCK-A discipline (gp-sys's wave-1A brief): verify the new
# wave-1B participant is correctly EXCLUDED from surfaces it shouldn't be in.
#
# Three surfaces to verify:
#   (a) NOT in &"resource_nodes" group — Ma'dan is not a mine/farm.
#       Madan._on_placement_complete uses this group to FIND mines; it would
#       be a self-reference bug if Ma'dan were also IN the group.
#   (b) IS in &"buildings" group — inherited from Building._ready. This is
#       the canonical "I am a building" marker (ARCHITECTURE.md §6 v0.20.4).
#   (c) BoxSelectHandler._collect_unit_shaped excludes nodes in &"buildings"
#       (the `not node.is_in_group(&"buildings")` filter at box_select_handler.gd:427).
#       Ma'dan has unit_id + team from Building base and IS Node3D — it would
#       match WITHOUT the filter. The filter is load-bearing. BUG-11 fix surface.

func test_madan_not_in_resource_nodes_group() -> void:
	# Ma'dan searches the &"resource_nodes" group to find adjacent mines.
	# It must NOT be in that group itself — otherwise a Ma'dan could
	# "discover" another Ma'dan as a mine and attempt an invalid modifier
	# chain (future: multiple Ma'dan placement on top of each other).
	_madan = _spawn_madan_at(Vector3.ZERO)
	assert_false(_madan.is_in_group(&"resource_nodes"),
		"Ma'dan must NOT be in &\"resource_nodes\" group. "
		+ "It is a buff-emitter Building, not a resource source. "
		+ "MineNode is in &\"resource_nodes\"; Mazra'eh is NOT either "
		+ "(it's in &\"buildings\"). The group is for ResourceNode subclasses only.")


func test_madan_is_in_buildings_group() -> void:
	# Building._ready adds every Building subclass to &"buildings".
	# This is the exclusion key that BoxSelectHandler reads.
	# Also verified by test_madan.gd::test_madan_joins_buildings_group_on_ready;
	# repeated here as a cross-cutting integration check in the context of
	# the full placement pipeline (place_at fires before we assert).
	_madan = _spawn_madan_at(Vector3.ZERO)
	assert_true(_madan.is_in_group(&"buildings"),
		"Ma'dan must be in &\"buildings\" group after placement "
		+ "(inherited from Building._ready). "
		+ "This is the BUG-11 exclusion key for BoxSelectHandler.")


func test_madan_excluded_from_box_select_by_buildings_group_filter() -> void:
	# BoxSelectHandler._collect_unit_shaped (line 426-431 of
	# box_select_handler.gd) filters out nodes in &"buildings". Ma'dan
	# has unit_id + team (from Building base) AND is Node3D — it would
	# pass the duck-type check WITHOUT the buildings filter.
	#
	# We verify the preconditions for the filter to apply:
	#   1. Ma'dan has unit_id (would pass the first duck-type check).
	#   2. Ma'dan has team (would pass the second duck-type check).
	#   3. Ma'dan IS in &"buildings" (the exclusion key that blocks it).
	# Combined: the filter `not node.is_in_group(&"buildings")` is the
	# gate that keeps Ma'dan out of box-select results.
	#
	# Observable via contract: check that the filter condition evaluates
	# correctly without needing a real Camera3D (headless test limitation).
	_madan = _spawn_madan_at(Vector3.ZERO)
	var has_unit_id: bool = (&"unit_id" in _madan)
	var has_team: bool = (&"team" in _madan)
	var in_buildings: bool = _madan.is_in_group(&"buildings")
	assert_true(has_unit_id,
		"Pre-condition: Ma'dan has unit_id field from Building base "
		+ "(would match duck-type check without the buildings filter)")
	assert_true(has_team,
		"Pre-condition: Ma'dan has team field from Building base "
		+ "(would match duck-type check without the buildings filter)")
	assert_true(in_buildings,
		"Ma'dan is_in_group(&\"buildings\") must be true — "
		+ "this is what the BoxSelectHandler filter reads to EXCLUDE Ma'dan. "
		+ "not is_in_group(&\"buildings\") => false => Ma'dan excluded.")
	# The final exclusion is `not is_in_group(&"buildings")` = false.
	assert_false(not in_buildings,
		"not is_in_group(&\"buildings\") must evaluate to false — "
		+ "this is the gate that keeps Ma'dan out of box-select results.")


# ===========================================================================
# class_name alignment (Commit 3.5 addition)
# ===========================================================================
#
# Per loremaster's transliteration-consistency rule: the GDScript class_name
# must be `Madan` (no apostrophe). An apostrophe in a GDScript identifier
# would be a syntax error, so this is more of a "no rename drift" check —
# verifies the script's get_class() reports the correct name.
# Secondary: confirms the madan.gd file declares class_name at all (some
# scripts omit it if they only extend by path-string).

func test_madan_class_name_is_madan_no_apostrophe() -> void:
	# The script declares `class_name Madan` at line 121 of madan.gd.
	# In Godot 4, get_class() returns the C++ base type (e.g., "Node3D")
	# for path-string-extends GDScript classes — not the GDScript class_name.
	# The correct API to retrieve a GDScript's declared class_name is
	# Script.get_global_name(), which returns the registered global name.
	# For `class_name Madan` in madan.gd, this must return "Madan".
	#
	# Note: if this returns "" it means class_name was not declared or was
	# renamed; if it returns "Ma'dan" or any other spelling it catches
	# loremaster transliteration drift.
	_madan = _spawn_madan_at(Vector3.ZERO)
	var s: Script = _madan.get_script()
	assert_not_null(s,
		"Ma'dan instance must have an attached script (madan.gd)")
	var global_name: StringName = s.get_global_name()
	assert_eq(global_name, &"Madan",
		"madan.gd must declare class_name Madan (no apostrophe — "
		+ "loremaster transliteration-consistency rule). "
		+ "Script.get_global_name() must return \"Madan\". Got: " + global_name)


# ===========================================================================
# Task #117 — Mazra'eh adjacency exclusion (Wave-1C carry-forward)
# ===========================================================================
#
# Load-bearing edge from session-3 Layer 1.5 enumeration: building-to-building
# proximity ≠ modifier-target proximity. A Ma'dan placed adjacent to a Mazra'eh
# (within `modifier_radius_m` = 4m default) must NOT register the Mazra'eh
# as its modifier target. Ma'dan only buffs MineNodes (which live in the
# &"resource_nodes" group); Mazra'eh is a Building subclass in &"buildings"
# (NOT in &"resource_nodes"), so the group iteration structurally excludes
# it. This test confirms the BEHAVIORAL consequence — no false-positive
# modifier registration on a near Mazra'eh.
#
# Companion to test_madan_not_in_resource_nodes_group above (structural
# group-membership check). That test asserts the field; this test asserts
# the gameplay-observable consequence: Mazra'eh placed adjacent to Ma'dan
# yields no buffer chain. If Ma'dan's discovery ever switches from
# &"resource_nodes" to a broader group (or starts iterating &"buildings"
# by mistake), the structural test still passes but this behavioral test
# catches the regression.


func _spawn_mazraeh_at(pos: Vector3) -> Variant:
	var m: Variant = MazraehScene.instantiate()
	add_child_autofree(m)
	m.team = Constants.TEAM_IRAN
	# Full lifecycle (Stage 1 + Stage 2) — adjacent Mazra'eh is operational.
	m.place_at(pos, Constants.TEAM_IRAN, 1)
	m._on_construction_complete(1)
	return m


func test_madan_adjacent_to_mazraeh_does_not_register_modifier_on_mazraeh() -> void:
	# Mazra'eh at origin (within Ma'dan's 4m radius). Ma'dan placed at
	# (3, 0, 0) is within radius. The Ma'dan's mine-discovery iterates
	# &"resource_nodes" — Mazra'eh is NOT in that group (it's in
	# &"buildings"). Modifier registration should NOT fire on the Mazra'eh.
	#
	# Two complementary observations:
	#   (a) the Mazra'eh exposes no register_extraction_modifier method
	#       (it's a Building subclass duck-typing the gather API, not the
	#       modifier API). If Ma'dan's discovery returned the Mazra'eh, the
	#       call would crash. We assert no crash on placement.
	#   (b) the Ma'dan's _find_nearest_mine_within_radius returns null when
	#       only a Mazra'eh is in radius — the internal seam exclusion.
	_mazraeh = _spawn_mazraeh_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	# Observation (a): placement completed without crash.
	assert_true(_madan.is_complete,
		"Task #117: Ma'dan placed adjacent to a Mazra'eh must complete "
		+ "placement without crash (the discovery seam structurally "
		+ "excludes Mazra'eh from the modifier-target search)")
	# Observation (b): the internal discovery seam confirms exclusion.
	var nearest: Variant = _madan._find_nearest_mine_within_radius(4.0)
	assert_eq(nearest, null,
		"Task #117 BEHAVIORAL: _find_nearest_mine_within_radius must "
		+ "return null when only a Mazra'eh is in radius. Mazra'eh lives "
		+ "in &\"buildings\", NOT in &\"resource_nodes\"; the group filter "
		+ "is the structural lock. building-to-building proximity != "
		+ "modifier-target proximity.")


func test_madan_adjacent_to_mazraeh_and_mine_buffs_only_mine() -> void:
	# Mixed scenario: Ma'dan placed with BOTH a Mazra'eh and a MineNode
	# within radius. The Mazra'eh is at (-3, 0, 0); the MineNode is at
	# (3, 0, 0). Ma'dan at origin should buff the MINE, ignoring the
	# Mazra'eh. Confirms that Mazra'eh-in-radius does not even contribute
	# to the discovery scan (Mazra'eh is structurally absent from the
	# &"resource_nodes" iteration).
	_mazraeh = _spawn_mazraeh_at(Vector3(-3.0, 0.0, 0.0))
	_mine = _spawn_mine_at(Vector3(3.0, 0.0, 0.0))
	_madan = _spawn_madan_at(Vector3.ZERO)
	# The mine is buffed.
	assert_eq(_mine.registered_modifier_count(), 1,
		"Task #117: with Mazra'eh + Mine both in radius, the Ma'dan "
		+ "registers as a modifier on the MINE only.")
	# Behavioral verification of the buff: complete_extract yields the
	# 1.5x payload (1500 x100), confirming the Ma'dan actually bonded to
	# the mine and not the Mazra'eh.
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], _buffed_yield_x100(),
		"Task #117 BEHAVIORAL: buffed mine yields base × madan multiplier "
		+ "(both from balance.tres). If Ma'dan had bonded to the Mazra'eh "
		+ "by mistake, the mine would yield the base amount instead.")
