# Tests for the Phase-1+2 starting workforce — main.gd's spawn helper and
# its position-array constants.
#
# Spec references:
#   - 02b_PHASE_1_KICKOFF.md §2 deliverable 9 ("Spawn 5 Kargar at game start")
#   - 02d_PHASE_2_KICKOFF.md §2 deliverables 5+6 (5 Iran Piyade + 5 Turan
#     Piyade at opposite map ends, so lead can right-click to engage)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverables 1-4 (Kamandar, Savar,
#     AsbSavarKamandar + Turan mirrors). Wave-2B extends spawn so the lead
#     has 33 units in two opposing columns to interactively test the full
#     RPS triangle.
#   - 01_CORE_MECHANICS.md §2 step 1 (canonical 3-worker start; we ship 5
#     for wave-2 click-target ergonomics, downgrade to 3 in Phase 3 economy)
#
# What we cover:
#   - main.gd's nine spawn-position consts each declare the right entry count
#     (5 / 5 / 5 / 3 / 3 / 3 / 3 / 3 / 3)
#   - All positions in each array are pairwise distinct
#   - Iran Piyade and Turan Piyade spawn positions are on OPPOSITE Z-sides
#     (Iran negative, Turan positive) so the lead has to walk units across
#     the map to engage
#   - When main.gd's `_spawn_starting_units` runs against a stub World
#     parent, it produces 33 children:
#       * 5 Kargars (team Iran, unit_ids 1..5)
#       * 5 Piyade (team Iran, unit_ids 6..10)
#       * 5 TuranPiyade (team Turan, unit_ids 11..15)
#       * 3 Kamandar (team Iran, unit_ids 16..18)
#       * 3 Savar (team Iran, unit_ids 19..21)
#       * 3 AsbSavarKamandar (team Iran, unit_ids 22..24)
#       * 3 TuranKamandar (team Turan, unit_ids 25..27)
#       * 3 TuranSavar (team Turan, unit_ids 28..30)
#       * 3 TuranAsbSavar (team Turan, unit_ids 31..33)
#
# Why we DON'T load main.tscn here: doing so brings in the terrain scene,
# which bakes a NavigationRegion3D into the World3D's default nav map.
# That bake persists across tests and breaks
# `test_navigation_agent_path_scheduler.gd::test_request_without_navmap_resolves_failed`
# (which assumes the world's default nav map is empty). We sidestep that
# by spawning unit instances directly under a stub Node3D instead.
extends GutTest


const MainScript: GDScript = preload("res://scripts/main.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const KamandarScene: PackedScene = preload("res://scenes/units/kamandar.tscn")
const SavarScene: PackedScene = preload("res://scenes/units/savar.tscn")
const AsbSavarKamandarScene: PackedScene = preload("res://scenes/units/asb_savar_kamandar.tscn")
const TuranKamandarScene: PackedScene = preload("res://scenes/units/turan_kamandar.tscn")
const TuranSavarScene: PackedScene = preload("res://scenes/units/turan_savar.tscn")
const TuranAsbSavarScene: PackedScene = preload("res://scenes/units/turan_asb_savar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0).
var _main_node: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _main_node != null and is_instance_valid(_main_node):
		_main_node.queue_free()
	_main_node = null
	SimClock.reset()


# Helpers — script-path-walk type detection. Dodges the class_name
# registry race that bites `if child is Kargar` at parse time.
const _KARGAR_SCRIPT_PATH: String = "res://scripts/units/kargar.gd"
const _PIYADE_SCRIPT_PATH: String = "res://scripts/units/piyade.gd"
const _TURAN_PIYADE_SCRIPT_PATH: String = "res://scripts/units/turan_piyade.gd"
const _KAMANDAR_SCRIPT_PATH: String = "res://scripts/units/kamandar.gd"
const _SAVAR_SCRIPT_PATH: String = "res://scripts/units/savar.gd"
const _ASB_SAVAR_KAMANDAR_SCRIPT_PATH: String = "res://scripts/units/asb_savar_kamandar.gd"
const _TURAN_KAMANDAR_SCRIPT_PATH: String = "res://scripts/units/turan_kamandar.gd"
const _TURAN_SAVAR_SCRIPT_PATH: String = "res://scripts/units/turan_savar.gd"
const _TURAN_ASB_SAVAR_SCRIPT_PATH: String = "res://scripts/units/turan_asb_savar.gd"


func _is_unit_of(node: Node, script_path: String) -> bool:
	var s: Script = node.get_script()
	while s != null:
		if s.resource_path == script_path:
			return true
		s = s.get_base_script()
	return false


func _has_exact_script(node: Node, script_path: String) -> bool:
	# Exact-script-path match (no base-class walk). Use this when sibling
	# Unit subclasses share an ancestor and a base-class walk would yield
	# false positives.
	var s: Script = node.get_script()
	if s == null:
		return false
	return s.resource_path == script_path


func _is_kargar(node: Node) -> bool:
	return _is_unit_of(node, _KARGAR_SCRIPT_PATH)


func _is_piyade(node: Node) -> bool:
	# Note: TuranPiyade does NOT inherit from Piyade — they're sibling Unit
	# subclasses. Both check for an exact script-path match (no false
	# positives from base-class walk).
	return _has_exact_script(node, _PIYADE_SCRIPT_PATH)


func _is_turan_piyade(node: Node) -> bool:
	return _has_exact_script(node, _TURAN_PIYADE_SCRIPT_PATH)


func _is_kamandar(node: Node) -> bool:
	return _has_exact_script(node, _KAMANDAR_SCRIPT_PATH)


func _is_savar(node: Node) -> bool:
	return _has_exact_script(node, _SAVAR_SCRIPT_PATH)


func _is_asb_savar_kamandar(node: Node) -> bool:
	return _has_exact_script(node, _ASB_SAVAR_KAMANDAR_SCRIPT_PATH)


func _is_turan_kamandar(node: Node) -> bool:
	return _has_exact_script(node, _TURAN_KAMANDAR_SCRIPT_PATH)


func _is_turan_savar(node: Node) -> bool:
	return _has_exact_script(node, _TURAN_SAVAR_SCRIPT_PATH)


func _is_turan_asb_savar(node: Node) -> bool:
	return _has_exact_script(node, _TURAN_ASB_SAVAR_SCRIPT_PATH)


# Set of all wave-2B unit-type predicates (closures) used by aggregate
# checks. Keyed by short type label.
const _NEW_TYPE_KEYS: Array[StringName] = [
	&"kamandar",
	&"savar",
	&"asb_savar_kamandar",
	&"turan_kamandar",
	&"turan_savar",
	&"turan_asb_savar",
]


# Helper — instantiate a fresh main.gd Node + a synthetic World child, hook
# them up so the script's @onready vars resolve, and run _ready manually.
# This mirrors what main.tscn would do at scene-boot, but without bringing
# the terrain.tscn (and its navmesh bake) along for the ride.
func _spawn_main_with_stub_world() -> Variant:
	var m: Variant = MainScript.new()
	# Provide a fake StatusLabel and World so the @onready resolution
	# inside main.gd works.
	var world: Node3D = Node3D.new()
	world.name = "World"
	m.add_child(world)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	m.add_child(status)
	add_child_autofree(m)
	# add_child triggers _ready on m, which calls _spawn_starting_units.
	await get_tree().process_frame
	return m


# ---------------------------------------------------------------------------
# const declarations — pure-code checks (no scene tree needed)
# ---------------------------------------------------------------------------

func _assert_position_array_size(const_name: StringName, expected: int) -> void:
	var positions: Variant = MainScript.get(const_name)
	assert_typeof(positions, TYPE_ARRAY,
		"%s must be an Array" % const_name)
	assert_eq((positions as Array).size(), expected,
		"main.gd.%s must have exactly %d entries" % [const_name, expected])


func _assert_pairwise_distinct(const_name: StringName) -> void:
	var positions: Array = MainScript.get(const_name) as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"%s positions %d and %d overlap: %s vs %s" % [const_name, i, j, a, b])


func test_kargar_spawn_positions_constant_has_five_entries() -> void:
	_assert_position_array_size(&"_KARGAR_SPAWN_POSITIONS", 5)


func test_piyade_spawn_positions_constant_has_five_entries() -> void:
	_assert_position_array_size(&"_PIYADE_SPAWN_POSITIONS", 5)


func test_turan_piyade_spawn_positions_constant_has_five_entries() -> void:
	_assert_position_array_size(&"_TURAN_PIYADE_SPAWN_POSITIONS", 5)


func test_kamandar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_KAMANDAR_SPAWN_POSITIONS", 3)


func test_savar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_SAVAR_SPAWN_POSITIONS", 3)


func test_asb_savar_kamandar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_ASB_SAVAR_KAMANDAR_SPAWN_POSITIONS", 3)


func test_turan_kamandar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_TURAN_KAMANDAR_SPAWN_POSITIONS", 3)


func test_turan_savar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_TURAN_SAVAR_SPAWN_POSITIONS", 3)


func test_turan_asb_savar_spawn_positions_constant_has_three_entries() -> void:
	_assert_position_array_size(&"_TURAN_ASB_SAVAR_SPAWN_POSITIONS", 3)


func test_kargar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_KARGAR_SPAWN_POSITIONS")


func test_piyade_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_PIYADE_SPAWN_POSITIONS")


func test_turan_piyade_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_TURAN_PIYADE_SPAWN_POSITIONS")


func test_kamandar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_KAMANDAR_SPAWN_POSITIONS")


func test_savar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_SAVAR_SPAWN_POSITIONS")


func test_asb_savar_kamandar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_ASB_SAVAR_KAMANDAR_SPAWN_POSITIONS")


func test_turan_kamandar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_TURAN_KAMANDAR_SPAWN_POSITIONS")


func test_turan_savar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_TURAN_SAVAR_SPAWN_POSITIONS")


func test_turan_asb_savar_spawn_positions_are_pairwise_distinct() -> void:
	_assert_pairwise_distinct(&"_TURAN_ASB_SAVAR_SPAWN_POSITIONS")


func test_iran_clusters_have_negative_z_turan_clusters_positive_z() -> void:
	# Live-game-broken-surface answer for wave 2B: the lead must be able to
	# read the layout as "two opposing armies" at default zoom. That requires
	# Iran clusters all on one Z-side and Turan clusters mirrored. Pin the
	# convention: Iran trios have Z < 0 (south of origin), Turan trios have
	# Z > 0 (north). This matches the existing Iran/Turan Piyade Z split
	# from wave-2A.
	for const_name: StringName in [
		&"_KAMANDAR_SPAWN_POSITIONS",
		&"_SAVAR_SPAWN_POSITIONS",
		&"_ASB_SAVAR_KAMANDAR_SPAWN_POSITIONS",
	]:
		for p: Vector3 in (MainScript.get(const_name) as Array):
			assert_true(p.z < 0.0,
				"every Iran new-type position must have Z<0 (south of origin); %s had Z=%.2f"
					% [const_name, p.z])
	for const_name: StringName in [
		&"_TURAN_KAMANDAR_SPAWN_POSITIONS",
		&"_TURAN_SAVAR_SPAWN_POSITIONS",
		&"_TURAN_ASB_SAVAR_SPAWN_POSITIONS",
	]:
		for p: Vector3 in (MainScript.get(const_name) as Array):
			assert_true(p.z > 0.0,
				"every Turan new-type position must have Z>0 (north of origin); %s had Z=%.2f"
					% [const_name, p.z])


func test_iran_and_turan_piyade_are_on_opposite_z_sides() -> void:
	# Live-game-broken-surface answer for deliverables 5+6: the lead must
	# have to walk units across a meaningful distance to engage. If both
	# armies started near each other, the Moving → Attacking transition
	# would never get exercised over distance — would only verify in-range
	# combat. Pin the geometry: Iran Piyade Z must be negative; Turan
	# Piyade Z must be positive; the gap must be > 20 units.
	var iran_positions: Array = MainScript.get(&"_PIYADE_SPAWN_POSITIONS") as Array
	var turan_positions: Array = MainScript.get(&"_TURAN_PIYADE_SPAWN_POSITIONS") as Array
	for p: Vector3 in iran_positions:
		assert_true(p.z < 0.0,
			"every Iran Piyade must spawn at negative Z (south of origin), got Z=%.2f"
				% p.z)
	for p: Vector3 in turan_positions:
		assert_true(p.z > 0.0,
			"every Turan Piyade must spawn at positive Z (north of origin), got Z=%.2f"
				% p.z)
	# Gap check — average Iran Piyade vs average Turan Piyade Z should be
	# > 20 units apart so units actually have to walk to engage.
	var iran_avg_z: float = 0.0
	for p: Vector3 in iran_positions:
		iran_avg_z += p.z
	iran_avg_z /= iran_positions.size()
	var turan_avg_z: float = 0.0
	for p: Vector3 in turan_positions:
		turan_avg_z += p.z
	turan_avg_z /= turan_positions.size()
	assert_true(turan_avg_z - iran_avg_z > 20.0,
		"Iran and Turan Piyade should be > 20 units apart in Z, got gap=%.2f"
			% (turan_avg_z - iran_avg_z))


# ---------------------------------------------------------------------------
# spawn behavior — main.gd's _ready spawns 15 units under World
# ---------------------------------------------------------------------------

func _is_starting_unit(child: Node) -> bool:
	return (
		_is_kargar(child)
		or _is_piyade(child)
		or _is_turan_piyade(child)
		or _is_kamandar(child)
		or _is_savar(child)
		or _is_asb_savar_kamandar(child)
		or _is_turan_kamandar(child)
		or _is_turan_savar(child)
		or _is_turan_asb_savar(child)
	)


func test_main_ready_spawns_thirty_three_units_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var total: int = 0
	for child in world.get_children():
		if _is_starting_unit(child):
			total += 1
	assert_eq(total, 33,
		"main.gd._ready must spawn exactly 33 starting units under World, got %d"
			% total)


func test_main_ready_spawns_five_kargars_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var kargars: Array = []
	for child in world.get_children():
		if _is_kargar(child):
			kargars.append(child)
	assert_eq(kargars.size(), 5,
		"main.gd._ready must spawn exactly 5 Kargars under World, got %d" % kargars.size())


func test_main_ready_spawns_five_iran_piyade_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var piyades: Array = []
	for child in world.get_children():
		if _is_piyade(child):
			piyades.append(child)
	assert_eq(piyades.size(), 5,
		"main.gd._ready must spawn exactly 5 Iran Piyade under World, got %d" % piyades.size())


func test_main_ready_spawns_five_turan_piyade_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var turans: Array = []
	for child in world.get_children():
		if _is_turan_piyade(child):
			turans.append(child)
	assert_eq(turans.size(), 5,
		"main.gd._ready must spawn exactly 5 Turan Piyade under World, got %d" % turans.size())


func _count_children(world: Node, predicate: Callable) -> int:
	var n: int = 0
	for child in world.get_children():
		if predicate.call(child):
			n += 1
	return n


func test_main_ready_spawns_three_kamandar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_kamandar), 3,
		"main.gd._ready must spawn exactly 3 Iran Kamandar under World")


func test_main_ready_spawns_three_savar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_savar), 3,
		"main.gd._ready must spawn exactly 3 Iran Savar under World")


func test_main_ready_spawns_three_asb_savar_kamandar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_asb_savar_kamandar), 3,
		"main.gd._ready must spawn exactly 3 Iran Asb-savar Kamandar under World")


func test_main_ready_spawns_three_turan_kamandar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_turan_kamandar), 3,
		"main.gd._ready must spawn exactly 3 Turan Kamandar under World")


func test_main_ready_spawns_three_turan_savar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_turan_savar), 3,
		"main.gd._ready must spawn exactly 3 Turan Savar under World")


func test_main_ready_spawns_three_turan_asb_savar_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_children(world, _is_turan_asb_savar), 3,
		"main.gd._ready must spawn exactly 3 Turan Asb-savar under World")


func test_all_starting_kargars_are_team_iran() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	for child in world.get_children():
		if _is_kargar(child):
			assert_eq(int(child.team), Constants.TEAM_IRAN,
				"every starting Kargar must be team Iran (got %d on unit_id=%d)"
					% [child.team, child.unit_id])


func test_all_starting_iran_piyade_are_team_iran() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	for child in world.get_children():
		if _is_piyade(child):
			assert_eq(int(child.team), Constants.TEAM_IRAN,
				"every starting Iran Piyade must be team Iran (got %d on unit_id=%d)"
					% [child.team, child.unit_id])


func test_all_starting_turan_piyade_are_team_turan() -> void:
	# Live-game-broken-surface answer for deliverable 6: a unit with team =
	# Constants.TEAM_TURAN must be plumbed through _ready so SpatialAgent
	# sees the right team filter for cross-team queries.
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	for child in world.get_children():
		if _is_turan_piyade(child):
			assert_eq(int(child.team), Constants.TEAM_TURAN,
				"every starting Turan Piyade must be team Turan (got %d on unit_id=%d)"
					% [child.team, child.unit_id])
			# Also verify the SpatialAgentComponent mirrors the team —
			# this is what cross-team queries (and wave 2B click-on-enemy)
			# rely on.
			var sa: Node = child.get_node(^"SpatialAgentComponent")
			assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
				"Turan Piyade.team must mirror to SpatialAgentComponent.team")


func _assert_all_team(world: Node, predicate: Callable, expected_team: int, label: String) -> void:
	for child in world.get_children():
		if predicate.call(child):
			assert_eq(int(child.team), expected_team,
				"every starting %s must be team %d (got %d on unit_id=%d)"
					% [label, expected_team, child.team, child.unit_id])
			# Live-game-broken-surface: the team field must be set BEFORE
			# add_child so SpatialAgentComponent's _ready mirrors the right
			# value. This re-asserts the wave-2A pattern for every new type.
			var sa: Node = child.get_node(^"SpatialAgentComponent")
			assert_eq(int(sa.get(&"team")), expected_team,
				"%s.team must mirror to SpatialAgentComponent.team" % label)


func test_all_starting_iran_new_types_are_team_iran() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	_assert_all_team(world, _is_kamandar, Constants.TEAM_IRAN, "Kamandar")
	_assert_all_team(world, _is_savar, Constants.TEAM_IRAN, "Savar")
	_assert_all_team(world, _is_asb_savar_kamandar, Constants.TEAM_IRAN, "AsbSavarKamandar")


func test_all_starting_turan_new_types_are_team_turan() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	_assert_all_team(world, _is_turan_kamandar, Constants.TEAM_TURAN, "TuranKamandar")
	_assert_all_team(world, _is_turan_savar, Constants.TEAM_TURAN, "TuranSavar")
	_assert_all_team(world, _is_turan_asb_savar, Constants.TEAM_TURAN, "TuranAsbSavar")


func test_starting_units_are_direct_children_of_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var found: int = 0
	for child in world.get_children():
		if _is_starting_unit(child):
			found += 1
			assert_same(child.get_parent(), world,
				"every starting unit must be a direct child of World")
	assert_eq(found, 33, "expected 33 starting units as direct children of World")


func _collect_sorted_ids(world: Node, predicate: Callable) -> Array[int]:
	var ids: Array[int] = []
	for child in world.get_children():
		if predicate.call(child):
			ids.append(int(child.unit_id))
	ids.sort()
	return ids


func test_starting_units_have_unit_ids_1_through_33() -> void:
	# Unit.reset_id_counter() runs at the top of _spawn_starting_units,
	# so the very first spawned unit gets id 1 and ids run sequentially
	# through 33. Determinism here means replay diffs and snapshot tests
	# stay stable across runs.
	#
	# Spawn order is enforced (matches the order _spawn_starting_units
	# iterates the position-array consts):
	#   Kargar          1..5
	#   Iran Piyade     6..10
	#   Turan Piyade    11..15
	#   Kamandar        16..18
	#   Savar           19..21
	#   AsbSavarKamandar 22..24
	#   TuranKamandar   25..27
	#   TuranSavar      28..30
	#   TuranAsbSavar   31..33
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")

	assert_eq(_collect_sorted_ids(world, _is_kargar), [1, 2, 3, 4, 5],
		"Kargar unit_ids must be 1..5 (spawned first)")
	assert_eq(_collect_sorted_ids(world, _is_piyade), [6, 7, 8, 9, 10],
		"Iran Piyade unit_ids must be 6..10")
	assert_eq(_collect_sorted_ids(world, _is_turan_piyade), [11, 12, 13, 14, 15],
		"Turan Piyade unit_ids must be 11..15")
	assert_eq(_collect_sorted_ids(world, _is_kamandar), [16, 17, 18],
		"Iran Kamandar unit_ids must be 16..18")
	assert_eq(_collect_sorted_ids(world, _is_savar), [19, 20, 21],
		"Iran Savar unit_ids must be 19..21")
	assert_eq(_collect_sorted_ids(world, _is_asb_savar_kamandar), [22, 23, 24],
		"Iran AsbSavarKamandar unit_ids must be 22..24")
	assert_eq(_collect_sorted_ids(world, _is_turan_kamandar), [25, 26, 27],
		"Turan Kamandar unit_ids must be 25..27")
	assert_eq(_collect_sorted_ids(world, _is_turan_savar), [28, 29, 30],
		"Turan Savar unit_ids must be 28..30")
	assert_eq(_collect_sorted_ids(world, _is_turan_asb_savar), [31, 32, 33],
		"Turan AsbSavar unit_ids must be 31..33")
