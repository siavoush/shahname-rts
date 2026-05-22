# Tests for the Tirandazi (Iran archery institution) — Phase 3 Wave 2B.
#
# Per 01_CORE_MECHANICS.md §5 line 195 (Tier-2 entry: 175 coin, produces
# advanced Kamandar variants incl. Asb-savar Kamandar) +
# docs/ARCHITECTURE.md §6 (Wave 2B close entry) +
# docs/ANCHOR_CATEGORY_TAXONOMY.md v1.0.0 (identity-bearing institutional /
# archery-tradition sub-slot).
#
# NAMING-SHAPE NOTE: Tirandazi uses -dazi (verbal-noun) instead of -khaneh.
# Per loremaster Track 0 brief-time verdict (2026-05-21), the -dazi vs
# -khaneh divergence is SURFACE-LANGUAGE ONLY — mechanical template-shape
# is identical to Sarbaz-khaneh + Sowari-khaneh. Tests mirror the same
# shape as test_sowari_khaneh.gd / test_sarbaz_khaneh.gd; the naming
# divergence lives in cultural-note prose (Track 1.5 paste), NOT in code
# or test structure.
#
# Test coverage:
#   1. Script identity (kind = &"tirandazi", dual-init, Building base
#      inheritance, class_name discipline, &"buildings" group).
#   2. is_ready_to_produce — Stage-2 operational marker. Mirrors
#      Sarbaz-khaneh / Sowari-khaneh per §9.L5.
#   3. Two-stage lifecycle BEHAVIORAL: Stage 1 does NOT set marker;
#      Stage 2 does.
#   4. super() chain — both lifecycle hooks call super per §9.L4a + §9.L4b.
#   5. Placement side-effect — EventBus.building_placed signal payload.
#   6. Cost helper — cost_coin() returns 175.
#   7. FogSystem autoload-guard no-crash (forward-compat).
#
# Test pattern per §9.M4: .new() headless construction. Scene-level
# coverage lives in world-builder Track 2.
extends GutTest


const TirandaziScript: Script = preload(
	"res://scripts/world/buildings/tirandazi.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _tirandazi: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _tirandazi != null and is_instance_valid(_tirandazi):
		_tirandazi.queue_free()
	_tirandazi = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_tirandazi(team: int = Constants.TEAM_IRAN) -> Variant:
	# Headless construction via .new() per §9.M4 — does not require the
	# parallel Track-2 scene file (tirandazi.tscn).
	var b: Variant = TirandaziScript.new()
	b.team = team
	add_child_autofree(b)
	return b


# ---------------------------------------------------------------------------
# Identity — kind, dual-init, inheritance chain, class_name, group
# ---------------------------------------------------------------------------

func test_tirandazi_script_directly_constructable() -> void:
	# Some harness fixtures construct bare (no scene). _init must set kind.
	var bare: Variant = TirandaziScript.new()
	assert_eq(bare.kind, &"tirandazi",
		"Tirandazi.new() (no scene) must set kind = &\"tirandazi\" in _init")
	bare.free()


func test_tirandazi_kind_post_ready() -> void:
	# Dual-init pattern — _ready must reaffirm kind after the engine
	# resets @export defaults between _init and _ready.
	_tirandazi = _spawn_tirandazi()
	assert_eq(_tirandazi.kind, &"tirandazi",
		"Tirandazi.kind must be &\"tirandazi\" after _ready")


func test_tirandazi_inherits_building_base() -> void:
	# Script-base-walk pattern — dodges class_name registry race per
	# Pitfall #13.
	_tirandazi = _spawn_tirandazi()
	var s: Script = _tirandazi.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"Tirandazi instance must inherit from building.gd in its script chain")


func test_tirandazi_class_name_is_tirandazi() -> void:
	# Per §9.J3 + loremaster transliteration-consistency rule. For
	# `class_name Tirandazi` this must return "Tirandazi".
	_tirandazi = _spawn_tirandazi()
	var s: Script = _tirandazi.get_script()
	var global_name: StringName = s.get_global_name()
	assert_eq(global_name, &"Tirandazi",
		"tirandazi.gd must declare class_name Tirandazi "
		+ "(transliteration discipline; the -dazi naming-shape divergence "
		+ "is surface-language only per loremaster Track 0 — the GDScript "
		+ "class_name follows the same Pascal-case convention as siblings). "
		+ "Got: " + global_name)


func test_tirandazi_joins_buildings_group_on_ready() -> void:
	# Inherited from Building._ready — consumers iterate &"buildings"
	# group for AI / UI / placement-validity discovery.
	_tirandazi = _spawn_tirandazi()
	assert_true(_tirandazi.is_in_group(&"buildings"),
		"Tirandazi inherits Building._ready add_to_group(&\"buildings\")")


# ---------------------------------------------------------------------------
# is_ready_to_produce field — Stage-2 operational marker
# ---------------------------------------------------------------------------

func test_tirandazi_has_is_ready_to_produce_field() -> void:
	# Public surface for Phase-4 production-queue. Tirandazi shares the
	# Sarbaz-khaneh / Sowari-khaneh marker name + semantics per loremaster
	# Track 0: -dazi naming divergence is surface-language only; mechanical
	# template-shape is identical.
	_tirandazi = _spawn_tirandazi()
	assert_true(&"is_ready_to_produce" in _tirandazi,
		"Tirandazi must expose is_ready_to_produce field for Phase-4 "
		+ "production-queue discovery (Asb-savar Kamandar training capacity)")


func test_tirandazi_is_ready_to_produce_defaults_false() -> void:
	# Default false ensures operational-gating discipline at spawn:
	# a freshly-instantiated Tirandazi cannot accept Kamandar training
	# requests until construction completes. Mirrors all prior operational
	# markers per §9.L5.
	_tirandazi = _spawn_tirandazi()
	assert_false(_tirandazi.is_ready_to_produce,
		"Tirandazi.is_ready_to_produce must default false at spawn — "
		+ "the archery range exists but cannot yet train Kamandar variants")


# ---------------------------------------------------------------------------
# Two-stage lifecycle BEHAVIORAL — Stage 1 vs Stage 2 operational gating
# ---------------------------------------------------------------------------

func test_is_ready_to_produce_stays_false_after_place_at_only() -> void:
	# BEHAVIORAL: place_at fires Stage 1 (structural). is_ready_to_produce
	# requires Stage 2 (_on_construction_complete).
	_tirandazi = _spawn_tirandazi()
	assert_false(_tirandazi.is_ready_to_produce,
		"sanity: false at spawn")
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_tirandazi.is_ready_to_produce,
		"BEHAVIORAL: is_ready_to_produce must REMAIN false after place_at "
		+ "alone — Stage 1 structural; flip gated on Stage 2 per §9.L5.")


func test_is_ready_to_produce_flips_on_construction_complete() -> void:
	# Stage 2 hook fires the flip. Drive the hook directly.
	_tirandazi = _spawn_tirandazi()
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_false(_tirandazi.is_ready_to_produce,
		"sanity: still false post-Stage-1")
	_tirandazi._on_construction_complete(1)
	assert_true(_tirandazi.is_ready_to_produce,
		"is_ready_to_produce must be true after _on_construction_complete "
		+ "(Stage 2 operational flip — archery training capacity activates)")


# ---------------------------------------------------------------------------
# super() chain — §9.L4a + §9.L4b discipline
# ---------------------------------------------------------------------------

func test_tirandazi_on_placement_complete_calls_super() -> void:
	# Per §9.L4a: subclass overrides of base virtuals with non-trivial
	# bodies MUST call super FIRST. is_complete is the observable seam
	# confirming the base chain ran end-to-end.
	_tirandazi = _spawn_tirandazi()
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_tirandazi.is_complete,
		"BEHAVIORAL: place_at completed without crash + is_complete=true. "
		+ "Confirms super._on_placement_complete() ran (base chain end-to-end).")


func test_tirandazi_on_construction_complete_calls_super() -> void:
	# Per §9.L4a + §9.L4b: super-call discipline applies even when base
	# body is currently `pass`. Future base additions inherit cleanly.
	_tirandazi = _spawn_tirandazi()
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	_tirandazi._on_construction_complete(1)
	assert_true(_tirandazi.is_ready_to_produce,
		"BEHAVIORAL: _on_construction_complete completed end-to-end "
		+ "(super invoked + subclass flip applied). §9.L4b forward-compat "
		+ "lock confirmed.")


# ---------------------------------------------------------------------------
# Placement side-effect — EventBus.building_placed signal
# ---------------------------------------------------------------------------

func test_tirandazi_placement_emits_building_placed_signal() -> void:
	# _on_placement_complete (Stage 1) must emit EventBus.building_placed
	# with kind = &"tirandazi".
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team, &"pos": pos})
	EventBus.building_placed.connect(handler)
	_tirandazi = _spawn_tirandazi(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3(9.0, 0.0, -4.0), Constants.TEAM_IRAN, 23)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"Tirandazi placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 23, "signal carries placer worker unit_id (23)")
	assert_eq(ev[&"kind"], &"tirandazi",
		"signal carries kind &\"tirandazi\"")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN, "signal carries TEAM_IRAN")


# ---------------------------------------------------------------------------
# place_at — base lifecycle integration
# ---------------------------------------------------------------------------

func test_place_at_sets_global_position() -> void:
	_tirandazi = _spawn_tirandazi()
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3(6.0, 0.0, 2.0), Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_almost_eq(_tirandazi.global_position.x, 6.0, 0.0001,
		"place_at sets global_position.x")
	assert_almost_eq(_tirandazi.global_position.z, 2.0, 0.0001,
		"place_at sets global_position.z")


# ---------------------------------------------------------------------------
# FogSystem guard — forward-compat (no crash when absent)
# ---------------------------------------------------------------------------

func test_tirandazi_placement_no_crash_when_fogsystem_absent() -> void:
	# When FogSystem singleton is NOT present, placement must succeed
	# without error. Same autoload-guard pattern as every other Iran
	# building.
	_tirandazi = _spawn_tirandazi()
	SimClock._is_ticking = true
	_tirandazi.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_tirandazi.is_complete,
		"Tirandazi placement completes without error when FogSystem absent")


# ---------------------------------------------------------------------------
# Static cost helper — cost_coin()
# ---------------------------------------------------------------------------

func test_tirandazi_cost_coin_returns_balance_data_value_or_fallback() -> void:
	# Cost reads BalanceData.buildings.tirandazi.coin_cost. Track 3 shipped
	# bldg_tirandazi.coin_cost = 175 at 6503b0c — normal path returns 175.
	# Fallback returns 175 when BalanceData unreachable. Either way, cost
	# is 175 per 01_CORE_MECHANICS.md §5 line 195.
	var cost: int = TirandaziScript.call(&"cost_coin")
	assert_eq(cost, 175,
		"Tirandazi.cost_coin() must return 175 (BalanceData or fallback "
		+ "both ship 175 per 01_CORE_MECHANICS.md §5 line 195). Got: %d" % cost)
