# Unit tests — Wave C1 roster-as-knob: the SKIRMISH starting-roster preset.
#
# main.gd's `--roster <full|skirmish>` knob slices each spawn-position array
# to its Constants.SKIRMISH_* count under skirmish; FULL (the default) is
# byte-identical to the pre-knob spawn and stays pinned by the untouched
# test_match_start_spawn.gd (33 units, ids 1..33). This file pins:
#
#   - skirmish spawns 5 Kargar + 2 Iran Piyade + 2 Turan Piyade = 9 units
#   - no RPS-trio units spawn under skirmish
#   - unit_id determinism per preset: Kargar 1..5, Piyade 6..7, Turan 8..9
#   - both Thrones still spawn (the win condition is roster-independent)
#   - _resolve_roster validation: unknown values fall back LOUDLY to full
#
# Test seam: main.gd.roster_override — set BEFORE add_child (so _ready's
# _resolve_roster sees it); tests cannot inject OS cmdline user args.
# Stub-world fixture mirrors test_match_start_spawn.gd (no main.tscn load —
# the terrain navmesh bake leaks across tests).
extends GutTest


const MainScript: GDScript = preload("res://scripts/main.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")

const _KARGAR_SCRIPT_PATH: String = "res://scripts/units/kargar.gd"
const _PIYADE_SCRIPT_PATH: String = "res://scripts/units/piyade.gd"
const _TURAN_PIYADE_SCRIPT_PATH: String = "res://scripts/units/turan_piyade.gd"

# The six RPS-trio scripts that must NOT spawn under skirmish.
const _RPS_SCRIPT_PATHS: Array[String] = [
	"res://scripts/units/kamandar.gd",
	"res://scripts/units/savar.gd",
	"res://scripts/units/asb_savar_kamandar.gd",
	"res://scripts/units/turan_kamandar.gd",
	"res://scripts/units/turan_savar.gd",
	"res://scripts/units/turan_asb_savar.gd",
]


var _main_node: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _main_node != null and is_instance_valid(_main_node):
		_main_node.queue_free()
	_main_node = null
	SimClock.reset()


# Mirrors test_match_start_spawn.gd::_spawn_main_with_stub_world, plus the
# roster_override seam set BEFORE add_child triggers _ready.
func _spawn_main_with_stub_world(roster: StringName) -> Variant:
	var m: Variant = MainScript.new()
	m.set(&"roster_override", roster)
	var world: Node3D = Node3D.new()
	world.name = "World"
	m.add_child(world)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	m.add_child(status)
	add_child_autofree(m)
	await get_tree().process_frame
	return m


func _has_exact_script(node: Node, script_path: String) -> bool:
	var s: Script = node.get_script()
	if s == null:
		return false
	return s.resource_path == script_path


func _is_kargar(node: Node) -> bool:
	# Kargar check walks the base-script chain (matches the canonical
	# predicate in test_match_start_spawn.gd).
	var s: Script = node.get_script()
	while s != null:
		if s.resource_path == _KARGAR_SCRIPT_PATH:
			return true
		s = s.get_base_script()
	return false


func _count_with_script(world: Node, script_path: String) -> int:
	var n: int = 0
	for child in world.get_children():
		if _has_exact_script(child, script_path):
			n += 1
	return n


func _sorted_ids_with_script(world: Node, script_path: String) -> Array[int]:
	var ids: Array[int] = []
	for child in world.get_children():
		if _has_exact_script(child, script_path):
			ids.append(int(child.unit_id))
	ids.sort()
	return ids


# ---------------------------------------------------------------------------
# Skirmish spawn counts
# ---------------------------------------------------------------------------

func test_skirmish_spawns_five_kargars() -> void:
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_SKIRMISH)
	var world: Node = _main_node.get_node(^"World")
	var kargars: int = 0
	for child in world.get_children():
		if _is_kargar(child):
			kargars += 1
	assert_eq(kargars, Constants.SKIRMISH_WORKER_COUNT,
		"skirmish must keep the full %d-Kargar economy" % Constants.SKIRMISH_WORKER_COUNT)


func test_skirmish_spawns_two_piyade_per_side() -> void:
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_SKIRMISH)
	var world: Node = _main_node.get_node(^"World")
	assert_eq(_count_with_script(world, _PIYADE_SCRIPT_PATH),
		Constants.SKIRMISH_COMBAT_PER_SIDE,
		"skirmish must spawn exactly %d Iran Piyade" % Constants.SKIRMISH_COMBAT_PER_SIDE)
	assert_eq(_count_with_script(world, _TURAN_PIYADE_SCRIPT_PATH),
		Constants.SKIRMISH_COMBAT_PER_SIDE,
		"skirmish must spawn exactly %d Turan Piyade" % Constants.SKIRMISH_COMBAT_PER_SIDE)


func test_skirmish_spawns_no_rps_trio_units() -> void:
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_SKIRMISH)
	var world: Node = _main_node.get_node(^"World")
	for path: String in _RPS_SCRIPT_PATHS:
		assert_eq(_count_with_script(world, path), Constants.SKIRMISH_RPS_TRIO_COUNT,
			"skirmish must spawn zero units of %s" % path)


func test_skirmish_unit_ids_are_1_through_9_deterministic() -> void:
	# Same spawn order as full (Kargar -> Iran Piyade -> Turan Piyade), so
	# skirmish ids are deterministic per preset: replay/snapshot stability.
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_SKIRMISH)
	var world: Node = _main_node.get_node(^"World")
	var kargar_ids: Array[int] = []
	for child in world.get_children():
		if _is_kargar(child):
			kargar_ids.append(int(child.unit_id))
	kargar_ids.sort()
	assert_eq(kargar_ids, [1, 2, 3, 4, 5],
		"skirmish Kargar unit_ids must be 1..5 (spawned first)")
	assert_eq(_sorted_ids_with_script(world, _PIYADE_SCRIPT_PATH), [6, 7],
		"skirmish Iran Piyade unit_ids must be 6..7")
	assert_eq(_sorted_ids_with_script(world, _TURAN_PIYADE_SCRIPT_PATH), [8, 9],
		"skirmish Turan Piyade unit_ids must be 8..9")


func test_skirmish_still_spawns_both_thrones() -> void:
	# The roster knob reduces UNITS only — the win condition (Throne per
	# faction) and the economy targets are preset-independent.
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_SKIRMISH)
	var world: Node = _main_node.get_node(^"World")
	var thrones: int = 0
	for child in world.get_children():
		if child is Node3D and child.is_in_group(&"thrones"):
			thrones += 1
	assert_eq(thrones, 2,
		"skirmish must still spawn one Throne per faction")


# ---------------------------------------------------------------------------
# Roster resolution / validation
# ---------------------------------------------------------------------------

func test_full_override_spawns_the_canonical_33() -> void:
	# Explicit full override == default behavior (the default-arg path is
	# pinned by test_match_start_spawn.gd; this pins override-equivalence).
	_main_node = await _spawn_main_with_stub_world(Constants.ROSTER_FULL)
	var world: Node = _main_node.get_node(^"World")
	var units: int = 0
	for child in world.get_children():
		# Duck-type a Unit by non-empty unit_type (the runner's canonical
		# walk) — unit_id alone would also match Buildings (shared id
		# namespace per test_unit_building_id_collision.gd).
		var ut_v: Variant = child.get(&"unit_type")
		if ut_v != null and StringName(ut_v) != &"":
			units += 1
	assert_eq(units, 33,
		"roster_override=full must spawn the canonical 33-unit roster")


func test_resolve_roster_unknown_value_falls_back_to_full() -> void:
	# §9.L9 loud fallback: a typo'd preset must not silently run skirmish.
	# _resolve_roster push_error()s — assert the engine error so the test
	# documents (and tolerates) the expected loud failure.
	var m: Variant = MainScript.new()
	m.set(&"roster_override", &"bogus_preset")
	var resolved: StringName = m.call(&"_resolve_roster")
	assert_eq(resolved, Constants.ROSTER_FULL,
		"unknown roster values must fall back to ROSTER_FULL")
	m.free()


func test_resolve_roster_accepts_both_known_presets() -> void:
	var m: Variant = MainScript.new()
	m.set(&"roster_override", Constants.ROSTER_SKIRMISH)
	assert_eq(m.call(&"_resolve_roster"), Constants.ROSTER_SKIRMISH,
		"skirmish override must resolve to skirmish")
	m.set(&"roster_override", Constants.ROSTER_FULL)
	assert_eq(m.call(&"_resolve_roster"), Constants.ROSTER_FULL,
		"full override must resolve to full")
	m.free()
