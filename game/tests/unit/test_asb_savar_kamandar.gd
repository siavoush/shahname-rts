# Tests for the Iran Asb-savar Kamandar (horse archer) unit type.
#
# Spec references:
#   - 01_CORE_MECHANICS.md §6 (Iran units, Asb-savar Kamandar = mounted archer)
#   - 02e_PHASE_2_SESSION_2_KICKOFF.md §2 deliverable 3 (ranged + cavalry hybrid)
#   - 02_IMPLEMENTATION_PLAN.md §169 (ship now Phase 2 to expose combat math;
#     Tier-2 stat rebalance lands Phase 4 when tech tier ships)
#
# What we cover:
#   - asb_savar_kamandar.tscn loads cleanly via PackedScene.instantiate
#   - The instantiated node is an AsbSavarKamandar (class) and a Unit (parent)
#   - unit_type == &"asb_savar_kamandar" so Unit._apply_balance_data_defaults
#     reads the right BalanceData entry
#   - max_hp / move_speed / attack_damage_x100 / attack_speed_per_sec /
#     attack_range all wire through from BalanceData (whatever balance.tres
#     declares — wave-1B populates them)
#   - The mesh override is a BoxMesh with the elongated 0.6 × 0.5 × 0.9 size
#     (the horse-archer silhouette — taller in Z than X to read as
#     elongated rather than just bigger). NOT just a scaled Piyade box —
#     the elongation is the load-bearing visual cue per kickoff.
#   - The material override is Iran-blue darker hue (high blue, low red,
#     darker than Piyade's blue) — distinct from Kamandar's muted variant
#     and Savar's deep-saturated.
#   - attack_range >= 5.0 invariant holds (this is a ranged unit; the whole
#     point is range + speed for kiting combat math)
#   - move_speed > 2.5 invariant holds (cavalry-fast, even if slightly slower
#     than Savar to differentiate)
#   - Team plumbing mirrors to SpatialAgentComponent
#   - Bare AsbSavarKamandar.new() construction sets unit_type
#
# Wave-1B coordination: balance-engineer populated BalanceData entries for
# asb_savar_kamandar in PARALLEL with this wave (1C). Tests read balance.tres
# at test-time and assert the component value matches what BalanceData says —
# tests verify WIRING (the unit reads from BalanceData), not NUMBERS (which
# balance-engineer owns). Same pattern as test_kamandar.gd / test_savar.gd.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). Same as test_piyade.gd /
# test_kamandar.gd / test_savar.gd.
extends GutTest


const AsbSavarKamandarScene: PackedScene = preload("res://scenes/units/asb_savar_kamandar.tscn")
const AsbSavarKamandarScript: Script = preload("res://scripts/units/asb_savar_kamandar.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _ask: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _ask != null and is_instance_valid(_ask):
		_ask.queue_free()
	_ask = null
	SimClock.reset()


# Helper — instantiate an Asb-savar Kamandar and add it to the test scene
# tree so _ready runs (which is when BalanceData defaults get applied).
func _spawn_ask(team: int = Constants.TEAM_IRAN) -> Variant:
	var u: Variant = AsbSavarKamandarScene.instantiate()
	u.team = team
	add_child_autofree(u)
	return u


# Helper — read the asb_savar_kamandar UnitStats sub-resource from
# balance.tres at test-time. Returns null if BalanceData isn't loadable
# or the entry is missing.
func _load_ask_stats() -> Variant:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return null
	return (units as Dictionary).get(&"asb_savar_kamandar", null)


# ---------------------------------------------------------------------------
# Visual smoke (Phase 0 retro §9 rule): scene loads, expected nodes present
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_scene_loads() -> void:
	_ask = _spawn_ask()
	assert_not_null(_ask, "asb_savar_kamandar.tscn must load to a non-null node")


func test_asb_savar_kamandar_inherits_unit_components() -> void:
	# The asb_savar_kamandar.tscn inherits from unit.tscn; every component
	# the parent scene declares must be in the tree on the inherited child.
	_ask = _spawn_ask()
	assert_not_null(_ask.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"HealthComponent"),
		"HealthComponent from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"MovementComponent"),
		"MovementComponent from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"CombatComponent"),
		"CombatComponent from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent from unit.tscn must be present on AsbSavarKamandar")
	assert_not_null(_ask.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent from unit.tscn must be present on AsbSavarKamandar")


# ---------------------------------------------------------------------------
# Identity — class type and unit_type
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_is_a_unit() -> void:
	# AsbSavarKamandar extends Unit; assert via script-base-walk to dodge the
	# class_name registry race (same pattern as test_kargar/piyade/kamandar).
	_ask = _spawn_ask()
	var s: Script = _ask.get_script()
	var found_unit_base: bool = false
	while s != null:
		if s.resource_path == "res://scripts/units/unit.gd":
			found_unit_base = true
			break
		s = s.get_base_script()
	assert_true(found_unit_base,
		"AsbSavarKamandar instance must inherit from unit.gd somewhere in its script chain")


func test_asb_savar_kamandar_unit_type_is_correct_string_name() -> void:
	# Unit._apply_balance_data_defaults uses unit_type as the BalanceData key.
	# If this is wrong, all combat fields silently fall back to component
	# defaults. Iran Asb-savar Kamandar uses the full compound key
	# &"asb_savar_kamandar" (Turan mirror uses the shortened &"turan_asb_savar"
	# per balance.tres comment — separate test file).
	_ask = _spawn_ask()
	assert_eq(_ask.unit_type, &"asb_savar_kamandar",
		"AsbSavarKamandar.unit_type must be the StringName &\"asb_savar_kamandar\" (matches BalanceData key)")


# ---------------------------------------------------------------------------
# BalanceData hookup — wiring verification, not number pinning
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_max_hp_wires_through_balance_data() -> void:
	var stats: Variant = _load_ask_stats()
	if stats == null:
		pending(
			"BalanceData entry for &\"asb_savar_kamandar\" not yet present "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	var expected_max_hp: float = float(stats.get(&"max_hp"))
	_ask = _spawn_ask()
	var h: Node = _ask.get_health()
	assert_not_null(h, "HealthComponent must be reachable via get_health()")
	assert_eq(int(h.get(&"max_hp_x100")), int(roundf(expected_max_hp * 100.0)),
		"AsbSavarKamandar max_hp_x100 must wire through BalanceData unit_asb_savar_kamandar.max_hp (got %s)"
			% [expected_max_hp])


func test_asb_savar_kamandar_move_speed_is_cavalry_fast() -> void:
	# Cavalry archetype invariant: must be faster than Piyade's 2.5 — the
	# whole point of horse archers is movement+range. Per kickoff stats
	# guidance: 4.0 (slightly slower than Savar's 4.5 to differentiate).
	var stats: Variant = _load_ask_stats()
	if stats == null:
		pending("BalanceData entry for &\"asb_savar_kamandar\" not yet present.")
		return
	var expected_speed: float = float(stats.get(&"move_speed"))
	_ask = _spawn_ask()
	var m: Node = _ask.get_movement()
	assert_not_null(m, "MovementComponent must be reachable via get_movement()")
	assert_almost_eq(float(m.get(&"move_speed")), expected_speed, 0.01,
		"AsbSavarKamandar move_speed must wire through BalanceData unit_asb_savar_kamandar.move_speed")
	assert_true(expected_speed > 2.5,
		"AsbSavarKamandar move_speed must exceed Piyade's 2.5 (cavalry invariant — "
		+ "kiting combat math depends on outpacing foot infantry), got %s" % [expected_speed])


func test_asb_savar_kamandar_attack_damage_wires_through_balance_data() -> void:
	var stats: Variant = _load_ask_stats()
	if stats == null:
		pending("BalanceData entry for &\"asb_savar_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_damage_x100")
	if typeof(raw) != TYPE_INT or int(raw) == 0:
		pending(
			"BalanceData unit_asb_savar_kamandar.attack_damage_x100 not yet populated "
			+ "(balance-engineer wave 1B in flight)."
		)
		return
	_ask = _spawn_ask()
	var c: Node = _ask.get_combat()
	assert_not_null(c, "CombatComponent must be reachable via get_combat()")
	assert_eq(int(c.get(&"attack_damage_x100")), int(raw),
		"AsbSavarKamandar attack_damage_x100 must wire through BalanceData")


func test_asb_savar_kamandar_attack_speed_wires_through_balance_data() -> void:
	var stats: Variant = _load_ask_stats()
	if stats == null:
		pending("BalanceData entry for &\"asb_savar_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_speed_per_sec")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_asb_savar_kamandar.attack_speed_per_sec not yet populated.")
		return
	_ask = _spawn_ask()
	var c: Node = _ask.get_combat()
	assert_almost_eq(float(c.get(&"attack_speed_per_sec")), float(raw), 0.01,
		"AsbSavarKamandar attack_speed_per_sec must wire through BalanceData")


func test_asb_savar_kamandar_attack_range_is_ranged() -> void:
	# Ranged-archetype invariant: attack_range >= 5.0 — Asb-savar must be
	# functionally ranged for the kiting combat math. Per kickoff §2 (3):
	# 7.0 (slightly less than Kamandar foot archers' 8.0, more than melee).
	var stats: Variant = _load_ask_stats()
	if stats == null:
		pending("BalanceData entry for &\"asb_savar_kamandar\" not yet present.")
		return
	var raw: Variant = stats.get(&"attack_range")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		pending("BalanceData unit_asb_savar_kamandar.attack_range not yet populated.")
		return
	var expected_range: float = float(raw)
	_ask = _spawn_ask()
	var c: Node = _ask.get_combat()
	assert_almost_eq(float(c.get(&"attack_range")), expected_range, 0.01,
		"AsbSavarKamandar attack_range must wire through BalanceData (mounted-archer ranged)")
	assert_true(expected_range >= 5.0,
		"AsbSavarKamandar attack_range must be at least 5.0 to read as ranged "
		+ "(melee Piyade is 1.5; got %s)" % [expected_range])


# ---------------------------------------------------------------------------
# Mesh override — elongated silhouette (NOT just bigger Piyade)
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_uses_elongated_box_mesh() -> void:
	# Per kickoff §2 (3): "Visual: elongated cube/rectangle (size
	# Vector3(0.6, 0.5, 0.9))." The Z-axis (depth) is the longest dimension —
	# the visual cue for "this is the horse-archer," distinct from Savar's
	# wider-square (0.7×0.6×0.7) and Piyade's tall-cube (0.5×0.7×0.5).
	# Elongation, not just size, is the load-bearing distinguisher.
	_ask = _spawn_ask()
	var mi: MeshInstance3D = _ask.get_node(^"MeshInstance3D")
	assert_not_null(mi, "MeshInstance3D must be present")
	assert_true(mi.mesh is BoxMesh,
		"AsbSavarKamandar mesh must be BoxMesh (elongated horse-archer silhouette), got %s"
			% [mi.mesh.get_class()])
	var bm: BoxMesh = mi.mesh as BoxMesh
	assert_almost_eq(bm.size.x, 0.6, 0.001,
		"AsbSavarKamandar BoxMesh width (X) must be 0.6 (per kickoff §2 (3))")
	assert_almost_eq(bm.size.y, 0.5, 0.001,
		"AsbSavarKamandar BoxMesh height (Y) must be 0.5 (per kickoff §2 (3))")
	assert_almost_eq(bm.size.z, 0.9, 0.001,
		"AsbSavarKamandar BoxMesh depth (Z) must be 0.9 (per kickoff §2 (3))")
	# Elongation invariant — Z (depth) > X (width). The load-bearing visual
	# cue is "this is elongated" not "this is bigger." Distinguishes Asb-savar
	# from Savar's near-square horizontal footprint.
	assert_true(bm.size.z > bm.size.x,
		"AsbSavarKamandar must be elongated (depth > width), got x=%s z=%s"
			% [bm.size.x, bm.size.z])


func test_asb_savar_kamandar_material_is_iran_blue_darker_hue() -> void:
	# Iran-blue darker hue per kickoff: Color(0.18, 0.28, 0.50) — high blue
	# (>red), low red (<0.35), and DARKER than Piyade's (0.3, 0.4, 0.7) so
	# this Iran combat unit is silhouette-AND-color distinguishable on a
	# busy battlefield. Cool counterpoint to the sandy terrain.
	_ask = _spawn_ask()
	var mi: MeshInstance3D = _ask.get_node(^"MeshInstance3D")
	var mat: Material = mi.material_override
	assert_not_null(mat, "AsbSavarKamandar must have a material_override")
	assert_true(mat is StandardMaterial3D,
		"AsbSavarKamandar material_override must be StandardMaterial3D")
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	assert_true(sm.albedo_color.b > sm.albedo_color.r,
		"AsbSavarKamandar albedo blue must exceed red (Iran blue, not Turan-red), "
		+ "got r=%.2f b=%.2f" % [sm.albedo_color.r, sm.albedo_color.b])
	assert_true(sm.albedo_color.r < 0.35,
		"AsbSavarKamandar albedo red channel must be low (Iran palette), got r=%.2f"
			% sm.albedo_color.r)
	assert_true(sm.albedo_color.b < 0.65,
		"AsbSavarKamandar albedo blue must be DARKER than Piyade's 0.7 (specialist "
		+ "Iran combat unit variant), got b=%.2f" % sm.albedo_color.b)


# ---------------------------------------------------------------------------
# Team — set externally by spawn code
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_team_can_be_assigned() -> void:
	_ask = _spawn_ask(Constants.TEAM_IRAN)
	var sa: Node = _ask.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_IRAN,
		"AsbSavarKamandar.team must be mirrored to SpatialAgentComponent.team")


# ---------------------------------------------------------------------------
# Construction-without-scene — the script alone is a valid Unit subclass
# ---------------------------------------------------------------------------

func test_asb_savar_kamandar_script_directly_constructable() -> void:
	# Test scenarios that construct an AsbSavarKamandar without going through
	# the .tscn (e.g., harness fixtures that don't want the visual children)
	# must still get unit_type = &"asb_savar_kamandar" via _init.
	var bare: Variant = AsbSavarKamandarScript.new()
	assert_eq(bare.unit_type, &"asb_savar_kamandar",
		"AsbSavarKamandar.new() (no scene) must set unit_type = &\"asb_savar_kamandar\" in _init")
	bare.free()
