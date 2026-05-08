# Tests for the Turan_Asb_Savar (Turan horse archer) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (units) + §11 (Turan faction red palette)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 4 (Turan mirror roster)
#
# What we cover:
#   - turan_asb_savar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is a TuranAsbSavar (class) and a Unit (parent)
#   - unit_type == &"turan_asb_savar" — note the SHORTENED key vs the Iran
#     side's &"asb_savar_kamandar" (per balance.tres comment line 184: "key is
#     turan_asb_savar (shorter than Iran's compound name)" — the Iran-side
#     "kamandar" suffix is understood from context for Turan units; folding
#     for the RPS matrix happens via _resolve_key("turan_asb_savar") →
#     "asb_savar" → _turan_base_to_iran_key("asb_savar") → "asb_savar_kamandar"
#     row, all in combat_matrix.gd from balance-engineer wave 1B).
#   - max_hp / move_speed / attack_damage_x100 / attack_speed_per_sec /
#     attack_range all wire through from BalanceData (mirror of Iran
#     Asb-savar Kamandar — Phase 2 mirror combat per kickoff §2 (4))
#   - The mesh override is a BoxMesh, IDENTICAL dimensions to Iran
#     Asb-savar Kamandar (0.6 × 0.5 × 0.9 — same elongated horse-archer
#     silhouette so silhouette communicates "same archetype, opposing team").
#   - The material override is Turan-red (high red, low blue, distinct
#     from Iran-blue Asb-savar's (0.18, 0.28, 0.50) and from other Turan
#     units' palettes).
#   - attack_range >= 5.0 invariant holds (ranged invariant)
#   - move_speed > 2.5 invariant holds (cavalry invariant)
#   - Team plumbing mirrors to SpatialAgentComponent
#   - Bare TuranAsbSavar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer populated the &"turan_asb_savar"
# entry in balance.tres in commit 743898a (the shorter key per the comment
# at balance.tres:184). Tests read balance.tres at test-time and assert
# the component value matches what BalanceData says — verifies WIRING,
# not NUMBERS. Same pattern as test_kamandar.gd / test_savar.gd / test_asb_savar_kamandar.gd.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_turan_piyade /
# test_asb_savar_kamandar.
extends GutTest


const TuranAsbSavarScene: PackedScene = preload("res://scenes/units/turan_asb_savar.tscn")
const TuranAsbSavarScript: Script = preload("res://scripts/units/turan_asb_savar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _tas: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _tas != null and is_instance_valid(_tas):
		_tas.queue_free()
	_tas = null
	SimClock.reset()


# Helper — instantiate a Turan_Asb_Savar and add it to the test scene tree
# so _ready runs (which is when BalanceData defaults get applied).
func _spawn_tas(team: int = Constants.TEAM_TURAN) -> Variant:
	var u: Variant = TuranAsbSavarScene.instantiate()
	u.team = team
	add_child_autofree(u)
	return u


# Helper — read the turan_asb_savar UnitStats sub-resource from balance.tres
# at test-time. Returns null if BalanceData isn't loadable or the entry
# is missing.
func _load_tas_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	# Note: SHORTENED key per balance.tres comment line 184. Iran side
	# uses "asb_savar_kamandar" (compound); Turan uses "turan_asb_savar".
	return (units as Dictionary).get(&"turan_asb_savar", null)


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_turan_asb_savar_scene_loads() -> void:
	_tas = _spawn_tas()
	assert_not_null(_tas, "turan_asb_savar.tscn must load to a non-null node")


func test_turan_asb_savar_inherits_unit_components() -> void:
	# The turan_asb_savar.tscn inherits from unit.tscn; every component the
	# parent scene declares must be in the tree on the inherited child.
	_tas = _spawn_tas()
	assert_not_null(_tas.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on TuranAsbSavar")
	assert_not_null(_tas.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on TuranAsbSavar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_turan_asb_savar_is_a_unit() -> void:
	# TuranAsbSavar extends Unit; assert via script-base-walk to dodge the
	# class_name registry race.
	_tas = _spawn_tas()
	var s: Script = _tas.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"TuranAsbSavar instance must inherit from unit.gd somewhere in its script chain")


func test_turan_asb_savar_unit_type_is_shortened_string_name() -> void:
	# Per balance.tres comment line 184: Turan unit_type is the SHORTENED
	# &"turan_asb_savar" (not the compound &"turan_asb_savar_kamandar"). The
	# RPS matrix lookup folds: _resolve_key("turan_asb_savar") strips prefix
	# to "asb_savar", then _turan_base_to_iran_key("asb_savar") expands to
	# "asb_savar_kamandar" row. If THIS test fails, balance.tres lookups
	# silently fall back to component defaults (max_hp 100 GDScript default
	# might happen to match — covers up the bug — but combat fields would
	# stay 0/1.0/0).
	_tas = _spawn_tas()
	assert_eq(_tas.unit_type, &"turan_asb_savar",
		"TuranAsbSavar.unit_type must be the SHORTENED StringName &\"turan_asb_savar\" "
		+ "(matches balance.tres key per line 184 comment; NOT the compound "
		+ "&\"turan_asb_savar_kamandar\")")


# ---------------------------------------------------------------------------
# BalanceData hookup — wiring verification, mirror of Iran Asb-savar
# ---------------------------------------------------------------------------

func test_turan_asb_savar_max_hp_wires_through_balance_data() -> void:
	var stats: Variant = _load_tas_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"turan_asb_savar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_tas = _spawn_tas()
	var h: Node = _tas.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"TuranAsbSavar max_hp_x100 must wire through BalanceData unit_turan_asb_savar.max_hp (got %s)"
			% [expected_max_hp])


func test_turan_asb_savar_move_speed_is_cavalry_fast() -> void:
	# Cavalry archetype invariant: must be faster than Piyade's 2.5. Mirror
	# stats with Iran Asb-savar Kamandar — both 4.0 per balance.tres (mirror
	# combat for Phase 2; no faction-asymmetric balance yet).
	var stats: Variant = _load_tas_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_asb_savar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_tas = _spawn_tas()
	var m: Node = _tas.get_movement()
	assert_not_null(m, "MovementComponent must be reachable via get_movement()")
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"TuranAsbSavar move_speed must wire through BalanceData unit_turan_asb_savar.move_speed")
	assert_true(expected_speed > 2.5,
		"TuranAsbSavar move_speed must exceed Piyade's 2.5 (cavalry invariant), "
		+ "got %s" % [expected_speed])


func test_turan_asb_savar_attack_damage_wires_through_balance_data() -> void:
	var stats: Variant = _load_tas_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_asb_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_turan_asb_savar.attack_damage_x100 not yet populated "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	_tas = _spawn_tas()
	var c: Node = _tas.get_combat()
	assert_not_null(c, "CombatComponent must be reachable via get_combat()")
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"TuranAsbSavar attack_damage_x100 must wire through BalanceData")


func test_turan_asb_savar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_tas_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_asb_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_asb_savar.attack_speed_per_sec not yet populated.")
		return
	_tas = _spawn_tas()
	var c: Node = _tas.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"TuranAsbSavar attack_speed_per_sec must wire through BalanceData")


func test_turan_asb_savar_attack_range_is_ranged() -> void:
	# Ranged-archetype invariant: attack_range >= 5.0. Mirror of Iran
	# Asb-savar Kamandar — both 7.0 per balance.tres.
	var stats: Variant = _load_tas_stats()
	if stats == null:
		pending("BalanceData entry for &\"turan_asb_savar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_turan_asb_savar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_tas = _spawn_tas()
	var c: Node = _tas.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"TuranAsbSavar attack_range must wire through BalanceData (mounted-archer ranged)")
	assert_true(expected_range >= 5.0,
		"TuranAsbSavar attack_range must be at least 5.0 to read as ranged "
		+ "(melee Piyade is 1.5; got %s)" % [expected_range])


# ---------------------------------------------------------------------------
# Mesh override — IDENTICAL elongated dimensions to Iran Asb-savar Kamandar
# ---------------------------------------------------------------------------

func test_turan_asb_savar_uses_elongated_box_mesh_mirror_of_iran() -> void:
	# Mirror combat: same dimensions as Iran Asb-savar Kamandar
	# (Vector3(0.6, 0.5, 0.9)) so silhouette communicates "same archetype,
	# opposing team" — only team color differs. The elongation invariant
	# (depth > width) carries the unit-type cue both sides.
	_tas = _spawn_tas()
	var mi: MeshInstance3D = _tas.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"TuranAsbSavar mesh must be BoxMesh (elongated horse-archer silhouette), got %s"
			% [mi.mesh.get_class()])
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.x, 0.6, 0.001,
		"TuranAsbSavar BoxMesh width (X) must be 0.6 (mirror of Iran Asb-savar)")
	assert_almost_eq(bm.size.y, 0.5, 0.001,
		"TuranAsbSavar BoxMesh height (Y) must be 0.5 (mirror of Iran Asb-savar)")
	assert_almost_eq(bm.size.z, 0.9, 0.001,
		"TuranAsbSavar BoxMesh depth (Z) must be 0.9 (mirror of Iran Asb-savar)")
	# Elongation invariant — Z (depth) > X (width). Same load-bearing visual
	# cue both sides.
	assert_true(bm.size.z > bm.size.x,
		"TuranAsbSavar must be elongated (depth > width), got x=%s z=%s"
			% [bm.size.x, bm.size.z])


func test_turan_asb_savar_material_is_turan_red() -> void:
	# Turan-red palette per kickoff §2 (3): Color(0.55, 0.18, 0.18) — high
	# red (>0.5), low blue (<0.3). Distinct from Iran-blue Asb-savar's
	# (0.18, 0.28, 0.50) and from other Turan units' palettes
	# (Turan_Piyade 0.7, 0.3, 0.3; TuranKamandar 0.55, 0.15, 0.15;
	# TuranSavar 0.65, 0.15, 0.15). The Turan-red analog of Iran-blue
	# Asb-savar's "specialist Iran combat unit" hue.
	_tas = _spawn_tas()
	var mi: MeshInstance3D = _tas.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "TuranAsbSavar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"TuranAsbSavar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.r > sm.albedo_color.b,
		"TuranAsbSavar albedo red must exceed blue (Turan-red, not Iran-blue), "
		+ "got r=%.2f b=%.2f" % [sm.albedo_color.r, sm.albedo_color.b])
	assert_true(sm.albedo_color.r > 0.4,
		"TuranAsbSavar albedo red channel must be high (Turan palette), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.35,
		"TuranAsbSavar albedo blue channel must be low (Turan palette, not Iran-blue), "
		+ "got b=%.2f" % sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — set externally by spawn code (Turan default)
# ---------------------------------------------------------------------------

func test_turan_asb_savar_team_can_be_assigned() -> void:
	_tas = _spawn_tas(Constants.TEAM_TURAN)
	var sa: Node = _tas.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
		"TuranAsbSavar.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_turan_asb_savar_script_directly_constructable() -> void:
	# Test scenarios that construct a TuranAsbSavar without going through the
	# .tscn (e.g., harness fixtures that don't want the visual children) must
	# still get unit_type = &"turan_asb_savar" via _init.
	var bare: Variant = TuranAsbSavarScript.new()
	assert_eq(bare.unit_type, &"turan_asb_savar",
		"TuranAsbSavar.new() (no scene) must set unit_type = &\"turan_asb_savar\" in _init")
	bare.free()
