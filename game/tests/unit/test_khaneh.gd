# Tests for the Khaneh (Iran house) building — Phase 3 session 1 wave 1C.
#
# Per 02f_PHASE_3_KICKOFF.md §3 wave 1C + 01_CORE_MECHANICS.md §5.
# Mirrors test_kargar.gd's shape: scene smoke, schema, BalanceData
# hookup, visual differentiation, identity, placement side-effects.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0).
extends GutTest


const KhanehScene: PackedScene = preload(
	"res://scenes/world/buildings/khaneh.tscn")
const KhanehScript: Script = preload(
	"res://scripts/world/buildings/khaneh.gd")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")


var _khaneh: Variant


func before_each() -> void:
	SimClock.reset()
	BuildingScript.call(&"reset_id_counter")
	ResourceSystem.reset()


func after_each() -> void:
	if _khaneh != null and is_instance_valid(_khaneh):
		_khaneh.queue_free()
	_khaneh = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_khaneh(team: int = Constants.TEAM_IRAN) -> Variant:
	var k: Variant = KhanehScene.instantiate()
	k.team = team
	add_child_autofree(k)
	return k


# ---------------------------------------------------------------------------
# Visual smoke + identity
# ---------------------------------------------------------------------------

func test_khaneh_scene_loads() -> void:
	_khaneh = _spawn_khaneh()
	assert_not_null(_khaneh, "khaneh.tscn must load to a non-null node")


func test_khaneh_inherits_building_composition() -> void:
	# The khaneh.tscn inherits from building.tscn; every component the
	# parent scene declares must be in the tree on the inherited child.
	_khaneh = _spawn_khaneh()
	assert_not_null(_khaneh.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from building.tscn must be present on Khaneh")
	assert_not_null(_khaneh.get_node_or_null(^"StaticBody3D"),
		"StaticBody3D (BUG-07 lesson) must be present on Khaneh")
	assert_not_null(_khaneh.get_node_or_null(^"NavigationObstacle3D"),
		"NavigationObstacle3D (RESOURCE_NODE_CONTRACT §3.2 carve) "
		+ "must be present on Khaneh")


func test_khaneh_is_a_building() -> void:
	# Khaneh extends Building; same script-base-walk pattern as
	# test_kargar.gd::test_kargar_is_a_unit (dodges the class_name
	# registry race).
	_khaneh = _spawn_khaneh()
	var s: Script = _khaneh.get_script()
	var found_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/world/buildings/building.gd":
			found_base = true
			break
		s = s.get_base_script()
	assert_true(found_base,
		"Khaneh instance must inherit from building.gd in its script chain")


func test_khaneh_kind_is_khaneh_string_name() -> void:
	# Dual-init pattern (per kargar.gd's header) — _init and _ready both
	# set kind so scene-loaded instances don't get clobbered by engine
	# @export reset between _init and _ready.
	_khaneh = _spawn_khaneh()
	assert_eq(_khaneh.kind, &"khaneh",
		"Khaneh.kind must be the StringName &\"khaneh\" "
		+ "(matches BalanceData.buildings.khaneh key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — the whole point of `kind` being right
# ---------------------------------------------------------------------------

func test_khaneh_static_cost_coin_matches_balance_data() -> void:
	# balance.tres declares bldg_khaneh.coin_cost = 50.
	# The build menu reads this without instantiating a Khaneh.
	assert_eq(KhanehScript.call(&"cost_coin"), 50,
		"Khaneh.cost_coin() must return 50 (from balance.tres bldg_khaneh.coin_cost)")


func test_khaneh_resolves_population_capacity_from_balance_data() -> void:
	# balance.tres declares bldg_khaneh.population_capacity = 10.
	# Verified indirectly via the placement side-effect; the
	# _resolve_population_capacity helper is exercised by the placement
	# test below. Here we sanity-check it returns the expected value.
	_khaneh = _spawn_khaneh()
	# Call the helper directly — it's instance-bound (reads self.kind).
	var cap: int = _khaneh._resolve_population_capacity()
	assert_eq(cap, 10,
		"Khaneh._resolve_population_capacity() must return 10 "
		+ "(from balance.tres bldg_khaneh.population_capacity)")


# ---------------------------------------------------------------------------
# Mesh override — visually distinct from base building.tscn
# ---------------------------------------------------------------------------

func test_khaneh_material_is_tan_not_neutral_grey() -> void:
	# The base building.tscn material is neutral grey (0.55, 0.55, 0.55).
	# Khaneh overrides to earthy tan (0.78, 0.65, 0.45). If this regresses,
	# the placeholder visual differentiation regresses — a Khaneh would
	# look like a generic Building instance.
	_khaneh = _spawn_khaneh()
	var mi: MeshInstance3D = _khaneh.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "Khaneh must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"Khaneh material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.r > 0.7,
		"Khaneh albedo red channel must be high (tan), got r=%.2f"
		% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.5,
		"Khaneh albedo blue channel must be low (tan, not grey), got b=%.2f"
		% sm.albedo_color.b)
	# Also distinct from the kargar (0.65, 0.5, 0.3) — Khaneh is brighter.
	assert_true(sm.albedo_color.r > 0.65,
		"Khaneh red must be brighter than Kargar (0.65) for silhouette "
		+ "differentiation, got r=%.2f" % sm.albedo_color.r)


# ---------------------------------------------------------------------------
# Placement side-effects — _on_placement_complete fires the chokepoint
# ---------------------------------------------------------------------------

func test_placement_bumps_population_cap_via_resource_system() -> void:
	# When a Khaneh is placed (place_at fires), the team's
	# population_cap should increase by population_capacity (10 from
	# BalanceData). The chokepoint is ResourceSystem.change_population_cap.
	_khaneh = _spawn_khaneh(Constants.TEAM_IRAN)
	var cap_before: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	# place_at is sanctioned on-tick context (it's called from
	# UnitState_Constructing's _sim_tick); tests must wrap in SimClock
	# ticking so ResourceSystem's on-tick assert holds.
	SimClock._is_ticking = true
	_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	var cap_after: int = ResourceSystem.population_cap_for(Constants.TEAM_IRAN)
	assert_eq(cap_after - cap_before, 10,
		"Khaneh placement must bump population_cap by 10 "
		+ "(BalanceData.buildings.khaneh.population_capacity)")


func test_placement_bumps_only_owning_team_cap() -> void:
	# Iran-owned Khaneh placement should NOT affect Turan's cap.
	_khaneh = _spawn_khaneh(Constants.TEAM_IRAN)
	var turan_cap_before: int = ResourceSystem.population_cap_for(
		Constants.TEAM_TURAN)
	SimClock._is_ticking = true
	_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	var turan_cap_after: int = ResourceSystem.population_cap_for(
		Constants.TEAM_TURAN)
	assert_eq(turan_cap_after, turan_cap_before,
		"Iran Khaneh placement must not affect Turan population_cap")


func test_placement_emits_building_placed_signal() -> void:
	# UI consumers, future AI controllers, and telemetry sinks all
	# subscribe to EventBus.building_placed. A placed Khaneh fires it
	# exactly once with the right payload.
	var captured: Array = []
	var handler: Callable = func(uid: int, kind: StringName, team: int,
			pos: Vector3) -> void:
		captured.append({&"uid": uid, &"kind": kind, &"team": team,
				&"pos": pos})
	EventBus.building_placed.connect(handler)
	_khaneh = _spawn_khaneh(Constants.TEAM_IRAN)
	var placement_pos: Vector3 = Vector3(5.0, 0.0, -3.0)
	SimClock._is_ticking = true
	_khaneh.place_at(placement_pos, Constants.TEAM_IRAN, 42)
	SimClock._is_ticking = false
	EventBus.building_placed.disconnect(handler)
	assert_eq(captured.size(), 1,
		"Khaneh placement must emit building_placed exactly once")
	var ev: Dictionary = captured[0]
	assert_eq(ev[&"uid"], 42,
		"signal carries the placer worker's unit_id (42 in this test)")
	assert_eq(ev[&"kind"], &"khaneh",
		"signal carries the Khaneh kind StringName")
	assert_eq(ev[&"team"], Constants.TEAM_IRAN,
		"signal carries the owning team")
	assert_almost_eq(ev[&"pos"].x, placement_pos.x, 0.0001,
		"signal carries the world-space placement position")


func test_place_at_marks_is_complete_true() -> void:
	# Khaneh inherits the base place_at; verify the inherited behavior
	# still works through the subclass hook.
	_khaneh = _spawn_khaneh(Constants.TEAM_IRAN)
	assert_false(_khaneh.is_complete, "starts incomplete")
	SimClock._is_ticking = true
	_khaneh.place_at(Vector3.ZERO, Constants.TEAM_IRAN, 1)
	SimClock._is_ticking = false
	assert_true(_khaneh.is_complete,
		"Khaneh.is_complete = true after place_at — instant placement, "
		+ "session 1 wave 1C")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Building subclass
# ---------------------------------------------------------------------------

func test_khaneh_script_directly_constructable() -> void:
	# Same pattern as test_kargar.gd::test_kargar_script_directly_constructable.
	# Some harness fixtures may construct a Khaneh without the .tscn (no
	# visual children). The class itself, when instantiated bare, should
	# still self-tag with kind = &"khaneh" via _init.
	var bare: Variant = KhanehScript.new()
	assert_eq(bare.kind, &"khaneh",
		"Khaneh.new() (no scene) must set kind = &\"khaneh\" in _init")
	bare.free()
