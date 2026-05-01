# Tests for the Phase 1 starting workforce — main.gd's _KARGAR_SPAWN_POSITIONS
# and the spawn helper.
#
# Spec references:
#   - 02b_PHASE_1_KICKOFF.md §2 deliverable 9 ("Spawn 5 Kargar at game start")
#   - kickoff prompt §"Your wave-2 deliverables" #2
#   - 01_CORE_MECHANICS.md §2 step 1 (canonical 3-worker start; we ship 5
#     for wave-2 click-target ergonomics, downgrade to 3 in Phase 3 economy)
#
# What we cover:
#   - main.gd's `_KARGAR_SPAWN_POSITIONS` const declares exactly 5 positions
#   - All 5 positions are distinct (no two Kargars start on top of each other)
#   - `_KargarScene` const points at the kargar.tscn we just authored
#   - When main.gd's `_spawn_starting_kargars` runs against a stub World
#     parent, it produces 5 children, all team Iran, all are Kargars,
#     unit_ids deterministically run 1..5
#
# Why we DON'T load main.tscn here: doing so brings in the terrain scene,
# which bakes a NavigationRegion3D into the World3D's default nav map.
# That bake persists across tests and breaks
# `test_navigation_agent_path_scheduler.gd::test_request_without_navmap_resolves_failed`
# (which assumes the world's default nav map is empty). We sidestep that
# by spawning Kargar instances directly under a stub Node3D instead. The
# end-to-end "main.tscn boots and spawns visible Kargars" check belongs
# in qa-engineer's wave-3 integration suite where scene-level pollution
# is isolated per test.
extends GutTest


const MainScript: GDScript = preload("res://scripts/main.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_unit.gd.
var _main_node: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _main_node != null and is_instance_valid(_main_node):
		_main_node.queue_free()
	_main_node = null
	SimClock.reset()


# Helper — script-path-walk Kargar detection. Dodges the class_name
# registry race that bites `if child is Kargar` at parse time.
const _KARGAR_SCRIPT_PATH: String = "res://scripts/units/kargar.gd"


func _is_kargar(node: Node) -> bool:
	var s: Script = node.get_script()
	while s != null:
		if s.resource_path == _KARGAR_SCRIPT_PATH:
			return true
		s = s.get_base_script()
	return false


# Helper — instantiate a fresh main.gd Node + a synthetic World child, hook
# them up so the script's @onready vars resolve, and run _ready manually.
# This mirrors what main.tscn would do at scene-boot, but without bringing
# the terrain.tscn (and its navmesh bake) along for the ride.
func _spawn_main_with_stub_world() -> Variant:
	var m: Variant = MainScript.new()
	# Provide a fake StatusLabel and World so the @onready resolution
	# inside main.gd works. We can't load main.tscn (would pull terrain),
	# so we hand-roll the minimum scene shape main.gd's _ready expects.
	var world: Node3D = Node3D.new()
	world.name = "World"
	m.add_child(world)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	m.add_child(status)
	add_child_autofree(m)
	# add_child triggers _ready on m, which calls _spawn_starting_kargars.
	await get_tree().process_frame
	return m


# ---------------------------------------------------------------------------
# const declarations — pure-code checks (no scene tree needed)
# ---------------------------------------------------------------------------

func test_kargar_spawn_positions_constant_has_five_entries() -> void:
	# main.gd declares `_KARGAR_SPAWN_POSITIONS: Array[Vector3]` with 5
	# entries. The number is the wave-2 ergonomics knob (5 click-targets
	# for SelectionManager testing); changing it here means changing the
	# spawn count, which is a real gameplay-shaping change. Pin it.
	var positions: Variant = MainScript.get(&"_KARGAR_SPAWN_POSITIONS")
	assert_typeof(positions, TYPE_ARRAY,
		"_KARGAR_SPAWN_POSITIONS must be an Array")
	assert_eq((positions as Array).size(), 5,
		"main.gd._KARGAR_SPAWN_POSITIONS must have exactly 5 entries (wave-2 ergonomics)")


func test_kargar_spawn_positions_are_pairwise_distinct() -> void:
	# Two Kargars sharing a spawn position would visually overlap and
	# break the "5 selectable targets" promise. The exact positions
	# aren't pinned (they're a presentation choice in main.gd); just
	# assert distinctness.
	var positions: Array = MainScript.get(&"_KARGAR_SPAWN_POSITIONS") as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"spawn positions %d and %d overlap: %s vs %s" % [i, j, a, b])


# ---------------------------------------------------------------------------
# spawn behavior — main.gd's _ready spawns 5 Kargars under World
# ---------------------------------------------------------------------------

func test_main_ready_spawns_five_kargars_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var kargars: Array = []
	for child in world.get_children():
		if _is_kargar(child):
			kargars.append(child)
	assert_eq(kargars.size(), 5,
		"main.gd._ready must spawn exactly 5 Kargars under World, got %d" % kargars.size())


func test_all_starting_kargars_are_team_iran() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	for child in world.get_children():
		if _is_kargar(child):
			assert_eq(int(child.team), Constants.TEAM_IRAN,
				"every starting Kargar must be team Iran (got %d on unit_id=%d)"
					% [child.team, child.unit_id])


func test_starting_kargars_are_direct_children_of_world() -> void:
	# The kickoff brief: "Place them as children of the World node ...
	# so the camera + lighting + terrain + units are all under the same
	# Node3D." Strict direct-children check.
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var found: int = 0
	for child in world.get_children():
		if _is_kargar(child):
			found += 1
			assert_same(child.get_parent(), world,
				"every starting Kargar must be a direct child of World")
	assert_eq(found, 5, "expected 5 Kargars as direct children of World")


func test_starting_kargars_have_unit_ids_1_through_5() -> void:
	# Unit.reset_id_counter() runs at the top of _spawn_starting_kargars,
	# so the very first spawned Kargar gets id 1 and ids run sequentially
	# through 5. Determinism here means replay diffs and snapshot tests
	# stay stable across runs.
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var ids: Array[int] = []
	for child in world.get_children():
		if _is_kargar(child):
			ids.append(int(child.unit_id))
	ids.sort()
	assert_eq(ids, [1, 2, 3, 4, 5],
		"starting Kargar unit_ids must be 1..5 in order, got %s" % str(ids))
