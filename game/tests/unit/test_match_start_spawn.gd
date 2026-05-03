# Tests for the Phase-1+2 starting workforce — main.gd's spawn helper and
# its three position-array constants.
#
# Spec references:
#   - 02b_PHASE_1_KICKOFF.md §2 deliverable 9 ("Spawn 5 Kargar at game start")
#   - 02d_PHASE_2_KICKOFF.md §2 deliverables 5+6 (5 Iran Piyade + 5 Turan
#     Piyade at opposite map ends, so lead can right-click to engage)
#   - 01_CORE_MECHANICS.md §2 step 1 (canonical 3-worker start; we ship 5
#     for wave-2 click-target ergonomics, downgrade to 3 in Phase 3 economy)
#
# What we cover:
#   - main.gd's three spawn-position consts each declare exactly 5 entries
#   - All positions in each array are pairwise distinct
#   - Iran Piyade and Turan Piyade spawn positions are on OPPOSITE Z-sides
#     (Iran negative, Turan positive) so the lead has to walk units across
#     the map to engage
#   - When main.gd's `_spawn_starting_units` runs against a stub World
#     parent, it produces 15 children:
#       * 5 Kargars (team Iran, unit_ids 1..5)
#       * 5 Piyade (team Iran, unit_ids 6..10)
#       * 5 TuranPiyade (team Turan, unit_ids 11..15)
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


func _is_unit_of(node: Node, script_path: String) -> bool:
	var s: Script = node.get_script()
	while s != null:
		if s.resource_path == script_path:
			return true
		s = s.get_base_script()
	return false


func _is_kargar(node: Node) -> bool:
	return _is_unit_of(node, _KARGAR_SCRIPT_PATH)


func _is_piyade(node: Node) -> bool:
	# Note: TuranPiyade does NOT inherit from Piyade — they're sibling Unit
	# subclasses. Both check for an exact script-path match (no false
	# positives from base-class walk).
	var s: Script = node.get_script()
	if s == null:
		return false
	return s.resource_path == _PIYADE_SCRIPT_PATH


func _is_turan_piyade(node: Node) -> bool:
	var s: Script = node.get_script()
	if s == null:
		return false
	return s.resource_path == _TURAN_PIYADE_SCRIPT_PATH


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

func test_kargar_spawn_positions_constant_has_five_entries() -> void:
	var positions: Variant = MainScript.get(&"_KARGAR_SPAWN_POSITIONS")
	assert_typeof(positions, TYPE_ARRAY,
		"_KARGAR_SPAWN_POSITIONS must be an Array")
	assert_eq((positions as Array).size(), 5,
		"main.gd._KARGAR_SPAWN_POSITIONS must have exactly 5 entries (wave-2 ergonomics)")


func test_piyade_spawn_positions_constant_has_five_entries() -> void:
	var positions: Variant = MainScript.get(&"_PIYADE_SPAWN_POSITIONS")
	assert_typeof(positions, TYPE_ARRAY,
		"_PIYADE_SPAWN_POSITIONS must be an Array")
	assert_eq((positions as Array).size(), 5,
		"main.gd._PIYADE_SPAWN_POSITIONS must have exactly 5 entries (wave-2A scope)")


func test_turan_piyade_spawn_positions_constant_has_five_entries() -> void:
	var positions: Variant = MainScript.get(&"_TURAN_PIYADE_SPAWN_POSITIONS")
	assert_typeof(positions, TYPE_ARRAY,
		"_TURAN_PIYADE_SPAWN_POSITIONS must be an Array")
	assert_eq((positions as Array).size(), 5,
		"main.gd._TURAN_PIYADE_SPAWN_POSITIONS must have exactly 5 entries (wave-2A scope)")


func test_kargar_spawn_positions_are_pairwise_distinct() -> void:
	var positions: Array = MainScript.get(&"_KARGAR_SPAWN_POSITIONS") as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"kargar spawn positions %d and %d overlap: %s vs %s" % [i, j, a, b])


func test_piyade_spawn_positions_are_pairwise_distinct() -> void:
	var positions: Array = MainScript.get(&"_PIYADE_SPAWN_POSITIONS") as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"piyade spawn positions %d and %d overlap: %s vs %s" % [i, j, a, b])


func test_turan_piyade_spawn_positions_are_pairwise_distinct() -> void:
	var positions: Array = MainScript.get(&"_TURAN_PIYADE_SPAWN_POSITIONS") as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"turan piyade spawn positions %d and %d overlap: %s vs %s" % [i, j, a, b])


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

func test_main_ready_spawns_fifteen_units_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var total: int = 0
	for child in world.get_children():
		if _is_kargar(child) or _is_piyade(child) or _is_turan_piyade(child):
			total += 1
	assert_eq(total, 15,
		"main.gd._ready must spawn exactly 15 starting units under World, got %d"
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


func test_starting_units_are_direct_children_of_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var found: int = 0
	for child in world.get_children():
		if _is_kargar(child) or _is_piyade(child) or _is_turan_piyade(child):
			found += 1
			assert_same(child.get_parent(), world,
				"every starting unit must be a direct child of World")
	assert_eq(found, 15, "expected 15 starting units as direct children of World")


func test_starting_units_have_unit_ids_1_through_15() -> void:
	# Unit.reset_id_counter() runs at the top of _spawn_starting_units,
	# so the very first spawned unit gets id 1 and ids run sequentially
	# through 15. Determinism here means replay diffs and snapshot tests
	# stay stable across runs.
	#
	# Spawn order is enforced: kargars 1..5, Iran Piyade 6..10, Turan
	# Piyade 11..15. This matches the order the spawn helper iterates the
	# three position-array consts.
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")

	var kargar_ids: Array[int] = []
	var piyade_ids: Array[int] = []
	var turan_ids: Array[int] = []
	for child in world.get_children():
		if _is_kargar(child):
			kargar_ids.append(int(child.unit_id))
		elif _is_piyade(child):
			piyade_ids.append(int(child.unit_id))
		elif _is_turan_piyade(child):
			turan_ids.append(int(child.unit_id))
	kargar_ids.sort()
	piyade_ids.sort()
	turan_ids.sort()

	assert_eq(kargar_ids, [1, 2, 3, 4, 5],
		"Kargar unit_ids must be 1..5 (spawned first), got %s" % str(kargar_ids))
	assert_eq(piyade_ids, [6, 7, 8, 9, 10],
		"Iran Piyade unit_ids must be 6..10 (spawned second), got %s" % str(piyade_ids))
	assert_eq(turan_ids, [11, 12, 13, 14, 15],
		"Turan Piyade unit_ids must be 11..15 (spawned third), got %s" % str(turan_ids))
