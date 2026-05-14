# Tests for main.gd::_spawn_starting_resources — Phase 3 wave 1A spawn
# helper for the 5 Coin MineNode instances.
#
# Mirror of test_match_start_spawn.gd's unit-spawn assertions, but for
# resources. Lives in its own file to keep wave-1A's diff scope contained
# (per Pitfall #7 / per-TDD-cycle commits) — the existing
# test_match_start_spawn.gd is "wave 2B's spawn coverage" by convention.
extends GutTest


const MainScript: GDScript = preload("res://scripts/main.gd")
const _MINE_NODE_SCRIPT_PATH: String = (
	"res://scripts/world/resource_nodes/mine_node.gd")


var _main_node: Variant


func before_each() -> void:
	SimClock.reset()


func after_each() -> void:
	if _main_node != null and is_instance_valid(_main_node):
		_main_node.queue_free()
	_main_node = null
	SimClock.reset()


# Spawn a fresh main.gd with stub World + StatusLabel, same pattern as
# test_match_start_spawn.gd. Returns the main node after _ready completes.
func _spawn_main_with_stub_world() -> Variant:
	var m: Variant = MainScript.new()
	var world: Node3D = Node3D.new()
	world.name = "World"
	m.add_child(world)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	m.add_child(status)
	add_child_autofree(m)
	await get_tree().process_frame
	return m


# Script-path predicate (registry-race-safe) — same shape as the existing
# spawn test's _has_exact_script.
func _is_mine_node(node: Node) -> bool:
	var s: Script = node.get_script()
	if s == null:
		return false
	return s.resource_path == _MINE_NODE_SCRIPT_PATH


# ---------------------------------------------------------------------------
# Const-array shape — pure code, no scene.
# ---------------------------------------------------------------------------

func test_coin_mine_spawn_positions_has_five_entries() -> void:
	var positions: Variant = MainScript.get(&"_COIN_MINE_SPAWN_POSITIONS")
	assert_typeof(positions, TYPE_ARRAY)
	assert_eq((positions as Array).size(), 5,
		"main.gd._COIN_MINE_SPAWN_POSITIONS must have exactly 5 entries (wave 1A)")


func test_coin_mine_positions_pairwise_distinct() -> void:
	var positions: Array = MainScript.get(&"_COIN_MINE_SPAWN_POSITIONS") as Array
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[j]
			assert_true(a.distance_to(b) > 0.01,
				"_COIN_MINE_SPAWN_POSITIONS %d and %d overlap: %s vs %s"
				% [i, j, a, b])


# ---------------------------------------------------------------------------
# Live spawn — main._ready calls _spawn_starting_resources after units.
# ---------------------------------------------------------------------------

func test_five_mines_appear_under_world() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var count: int = 0
	for child in world.get_children():
		if _is_mine_node(child):
			count += 1
	assert_eq(count, 5,
		"five Coin MineNodes spawn as direct children of World")


func test_mines_positions_match_const() -> void:
	_main_node = await _spawn_main_with_stub_world()
	var world: Node = _main_node.get_node(^"World")
	var spawn_positions: Array = MainScript.get(
		&"_COIN_MINE_SPAWN_POSITIONS") as Array
	for child in world.get_children():
		if not _is_mine_node(child):
			continue
		# Each MineNode's local position is one of the entries in the const.
		var pos: Vector3 = (child as Node3D).position
		var matched: bool = false
		for expected: Vector3 in spawn_positions:
			if pos.distance_to(expected) < 0.01:
				matched = true
				break
		assert_true(matched,
			"MineNode position %s must match one of _COIN_MINE_SPAWN_POSITIONS"
			% str(pos))
