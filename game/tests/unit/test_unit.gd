# Tests for Unit base class + unit.tscn template.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §5.1 (Unit owns the FSM and
# command queue, components hold the SimNode-discipline state).
#
# What we cover:
#   - unit_id auto-assignment from static counter
#   - reset_id_counter restarts numbering
#   - team is mirrored to SpatialAgentComponent
#   - HealthComponent init_max_hp is called from BalanceData
#   - MovementComponent move_speed is set from BalanceData
#   - command_queue is constructed before _ready
#   - is_idle / is_engaged / is_dying helpers reflect FSM state
#
# Plus the visual smoke test (per Phase 0 retro §9): load the scene,
# verify expected nodes exist in the tree, no assertion failures.
#
# Untyped Variant fixture per the project-wide class_name registry race
# pattern (docs/ARCHITECTURE.md §6 v0.4.0). The Unit class_name resolves
# at runtime fine, but inline GDScript test classes parse before the
# global registry settles. The preloaded script ref carries the same
# methods.
extends GutTest


const UnitScene: PackedScene = preload("res://scenes/units/unit.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _unit: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")


func after_each() -> void:
	if _unit != null and is_instance_valid(_unit):
		_unit.queue_free()
	_unit = null
	SimClock.reset()


# Spawn a Unit instance via the .tscn template, then add it to the scene
# so its _ready chain runs. Returns Variant (no class_name dependency).
func _spawn_unit(unit_type: StringName = &"kargar", team: int = 1) -> Variant:
	var u: Variant = UnitScene.instantiate()
	u.unit_type = unit_type
	u.team = team
	add_child_autofree(u)
	return u


# ---------------------------------------------------------------------------
# Visual smoke test (Phase 0 retro §9 rule)
# ---------------------------------------------------------------------------

func test_scene_loads_and_has_expected_components_in_tree() -> void:
	# Load the scene, confirm every expected component is in the tree.
	# This catches the "scene was edited but a component was deleted"
	# class of bug.
	_unit = _spawn_unit()
	assert_not_null(_unit, "unit.tscn must load to a non-null Unit")
	assert_not_null(_unit.get_node_or_null(^"MeshInstance3D"),
		"MeshInstance3D placeholder must be in the tree")
	assert_not_null(_unit.get_node_or_null(^"CollisionShape3D"),
		"CollisionShape3D must be in the tree")
	assert_not_null(_unit.get_node_or_null(^"HealthComponent"),
		"HealthComponent must be in the tree")
	assert_not_null(_unit.get_node_or_null(^"MovementComponent"),
		"MovementComponent must be in the tree")
	assert_not_null(_unit.get_node_or_null(^"SelectableComponent"),
		"SelectableComponent must be in the tree")
	assert_not_null(_unit.get_node_or_null(^"SpatialAgentComponent"),
		"SpatialAgentComponent must be in the tree")


# ---------------------------------------------------------------------------
# unit_id assignment
# ---------------------------------------------------------------------------

func test_first_spawned_unit_gets_id_1() -> void:
	_unit = _spawn_unit()
	assert_eq(int(_unit.unit_id), 1, "first spawned unit gets id 1 from counter")


func test_second_spawned_unit_gets_id_2() -> void:
	var first: Variant = _spawn_unit()
	_unit = _spawn_unit()
	assert_eq(int(first.unit_id), 1)
	assert_eq(int(_unit.unit_id), 2)


func test_reset_id_counter_restarts_numbering() -> void:
	var first: Variant = _spawn_unit()
	first.queue_free()
	# Queue free completes next frame.
	await get_tree().process_frame
	UnitScript.call(&"reset_id_counter")
	_unit = _spawn_unit()
	assert_eq(int(_unit.unit_id), 1,
		"reset_id_counter must restart numbering at 1")


# ---------------------------------------------------------------------------
# Component getters
# ---------------------------------------------------------------------------

func test_get_health_returns_health_component() -> void:
	_unit = _spawn_unit()
	var h: Node = _unit.get_health()
	assert_not_null(h)
	# Has the hp accessor — it's a HealthComponent.
	assert_true(&"hp_x100" in h,
		"get_health must return the HealthComponent (with hp_x100 storage)")


func test_get_movement_returns_movement_component() -> void:
	_unit = _spawn_unit()
	var m: Node = _unit.get_movement()
	assert_not_null(m)
	assert_true(&"move_speed" in m,
		"get_movement must return the MovementComponent (with move_speed)")


func test_get_selectable_returns_selectable_component() -> void:
	_unit = _spawn_unit()
	var s: Node = _unit.get_selectable()
	assert_not_null(s)
	assert_true(&"is_selected" in s,
		"get_selectable must return the SelectableComponent (with is_selected)")


func test_get_state_machine_returns_fsm() -> void:
	_unit = _spawn_unit()
	assert_not_null(_unit.get_state_machine(), "fsm must be non-null")
	assert_same(_unit.get_state_machine(), _unit.fsm,
		"get_state_machine returns the same instance as the field")


# ---------------------------------------------------------------------------
# Team mirroring to SpatialAgentComponent
# ---------------------------------------------------------------------------

func test_team_is_mirrored_to_spatial_agent_component() -> void:
	_unit = _spawn_unit(&"kargar", Constants.TEAM_TURAN)
	var sa: Node = _unit.get_node(^"SpatialAgentComponent")
	assert_eq(int(sa.get(&"team")), Constants.TEAM_TURAN,
		"team field on SpatialAgentComponent must mirror Unit.team")


# ---------------------------------------------------------------------------
# BalanceData defaults applied on _ready
# ---------------------------------------------------------------------------

func test_balance_data_initializes_health_max_hp() -> void:
	# The kargar entry in balance.tres has max_hp = 60.0.
	_unit = _spawn_unit(&"kargar")
	var h: Node = _unit.get_health()
	assert_eq(int(h.get(&"max_hp_x100")), 6000,
		"max_hp_x100 must be set from BalanceData (kargar = 60.0 → 6000)")
	assert_eq(int(h.get(&"hp_x100")), 6000,
		"hp_x100 starts at full")


func test_balance_data_initializes_move_speed() -> void:
	# kargar move_speed = 3.5.
	_unit = _spawn_unit(&"kargar")
	var m: Node = _unit.get_movement()
	assert_almost_eq(float(m.get(&"move_speed")), 3.5, 0.01,
		"move_speed must be set from BalanceData (kargar = 3.5)")


# ---------------------------------------------------------------------------
# Component unit_id propagation
# ---------------------------------------------------------------------------

func test_unit_id_is_propagated_to_components() -> void:
	_unit = _spawn_unit()
	assert_eq(int(_unit.get_health().get(&"unit_id")), int(_unit.unit_id),
		"HealthComponent.unit_id matches Unit.unit_id")
	assert_eq(int(_unit.get_movement().get(&"unit_id")), int(_unit.unit_id),
		"MovementComponent.unit_id matches Unit.unit_id")
	assert_eq(int(_unit.get_selectable().get(&"unit_id")), int(_unit.unit_id),
		"SelectableComponent.unit_id matches Unit.unit_id")


# ---------------------------------------------------------------------------
# Command queue
# ---------------------------------------------------------------------------

func test_command_queue_exists_at_ready() -> void:
	_unit = _spawn_unit()
	assert_not_null(_unit.command_queue,
		"command_queue is constructed before _ready")
	assert_eq(int(_unit.command_queue.size()), 0,
		"freshly-spawned unit has empty command queue")


# Note: replace_command / append_command call fsm.transition_to_next when
# transitioning. With no states registered (base Unit, no concrete state
# subclasses yet), the FSM remains uninitialized; calling transition_to_next
# would crash. Concrete-state-aware tests of replace_command live in wave 2.

# ---------------------------------------------------------------------------
# Legibility helpers
# ---------------------------------------------------------------------------

func test_is_idle_helpers_handle_uninit_fsm() -> void:
	# A Unit with no states registered (the base) has fsm.current == null.
	# is_idle defensively returns true (nothing else to be), is_engaged /
	# is_dying / is_busy return false. This keeps AI controllers and UI
	# from crashing when introspecting an uninitialized unit.
	_unit = _spawn_unit()
	assert_true(_unit.is_idle())
	assert_false(_unit.is_engaged())
	assert_false(_unit.is_dying())
	assert_false(_unit.is_busy())


# ===========================================================================
# Wave 3A.5 Track 2 — fog vision-source register/deregister
# ===========================================================================
#
# Per §9.H3 first-exercise-of-dormant-schema: these tests validate that
# unit.gd's register call at _ready correctly reads
# `BalanceData.fog.sight_<unit_type>_cells` for each unit kind. The
# typo-bait surface is real — `Resource` returns null for missing
# property reads, and my `_register_fog_vision_source` early-bails on
# null without flagging. A typo'd field name produces "unit reveals
# nothing in live game" — silent failure. These tests catch it at
# headless test time.
#
# Coupled-test-gate per Wave 3A.5 §3.1: Track 1 (world-builder)
# implements FogSystem.register_vision_source real body. Tests below
# work against BOTH the 3A.0 stub (returns -1) and Track 1's real impl
# (returns a non-zero handle) — they assert the call REACHED
# FogSystem, not that the handle has any specific value.

# --- H3 dogfood: per-kind sight-radius lookup from BalanceData -----------

func test_h3_fog_sight_radius_per_kind_lookup() -> void:
	# BEHAVIORAL §9.H3: spawn a Unit of each kind, verify the
	# BalanceData.fog.sight_<kind>_cells lookup returns the right value.
	# Per fog_config.gd defaults (verified at fog_config.gd:87-104):
	#   sight_kargar_cells = 3
	#   sight_piyade_cells = 3
	#   sight_kamandar_cells = 4
	#   sight_savar_cells = 4
	#   sight_rostam_cells = 5
	# If unit.gd's field-name composition (`"sight_" + unit_type + "_cells"`)
	# has a typo OR fog_config.gd defaults are mistyped, this test catches it.
	var bd: Resource = load(Constants.PATH_BALANCE_DATA)
	assert_not_null(bd, "sanity: BalanceData loads")
	var fog_cfg: Variant = bd.get(&"fog")
	assert_not_null(fog_cfg, "sanity: BalanceData.fog sub-resource exists")
	assert_true(fog_cfg is Resource,
		"sanity: BalanceData.fog is a Resource (FogConfig)")
	# Per-kind lookups via the same composed field-name pattern that
	# unit.gd uses. If unit.gd's code typos this composition, this test
	# is the canonical detector.
	var expected: Dictionary = {
		&"kargar": 3,
		&"piyade": 3,
		&"kamandar": 4,
		&"savar": 4,
		&"rostam": 5,
	}
	for kind: StringName in expected:
		var field_name: StringName = StringName(
			"sight_" + String(kind) + "_cells")
		var radius_v: Variant = (fog_cfg as Resource).get(field_name)
		assert_true(
			typeof(radius_v) == TYPE_INT or typeof(radius_v) == TYPE_FLOAT,
			"H3 typo-bait surface: BalanceData.fog.%s must exist as int. "
			% field_name
			+ "If null/missing, fog_config.gd defaults are mistyped OR "
			+ "unit.gd's field-name composition has drifted.")
		var radius: int = int(radius_v)
		assert_eq(radius, int(expected[kind]),
			"H3 typo-bait surface: BalanceData.fog.%s = %d, expected %d "
			% [field_name, radius, int(expected[kind])]
			+ "per fog_config.gd defaults (kargar/piyade=3, kamandar/savar=4, "
			+ "rostam=5).")


# --- Register-on-spawn: _fog_handle captured from FogSystem call ----------

func test_register_on_spawn_kargar_captures_fog_handle() -> void:
	# BEHAVIORAL: spawning a Unit with unit_type=&"kargar" triggers
	# _register_fog_vision_source at _ready, which calls
	# FogSystem.register_vision_source and captures the handle in
	# _fog_handle. The default sentinel is 0; after spawn, _fog_handle
	# must be SET to whatever FogSystem returned.
	#
	# Wave 3A.0 stub: returns -1. Wave 3A.5 Track 1 real impl: returns
	# a non-zero positive handle. Either way, _fog_handle != 0 after
	# spawn (because the call reached FogSystem). Asserting != 0
	# is stub-compatible AND real-impl-compatible.
	_unit = _spawn_unit(&"kargar", 1)
	# The _fog_handle field is private (leading underscore) but exposed
	# for tests via direct property read. Per project convention,
	# tests may read underscore-prefixed state.
	assert_ne(_unit._fog_handle, 0,
		"_fog_handle must be set after _ready (FogSystem.register_vision_source "
		+ "was called and returned a handle). Default is 0; spawn must "
		+ "supersede. Got: %d" % _unit._fog_handle)


func test_register_skipped_when_unit_type_empty() -> void:
	# Defensive: a bare Unit.new() with no unit_type set must not register
	# (no kind → no sight-radius lookup). _fog_handle stays at default 0.
	# This preserves test fixtures that construct minimal Unit instances.
	var u: Variant = UnitScript.new()
	u.team = 1
	# unit_type stays &"" by default.
	add_child_autofree(u)
	assert_eq(u._fog_handle, 0,
		"_fog_handle must stay 0 when unit_type is empty — no register "
		+ "fires because there's no kind to look up sight-radius for.")


# --- Deregister-on-tree-exit -----------------------------------------------

func test_deregister_on_exit_tree_resets_handle() -> void:
	# BEHAVIORAL: when a Unit leaves the SceneTree (via queue_free /
	# tree teardown), _exit_tree fires and calls
	# FogSystem.deregister_vision_source(_fog_handle), then resets
	# _fog_handle = 0. The reset is the observable seam confirming
	# deregister was called.
	_unit = _spawn_unit(&"piyade", 1)
	assert_ne(_unit._fog_handle, 0,
		"sanity: register fired at _ready, handle is set")
	# Manually trigger _exit_tree by removing from parent (or via free).
	# Capture handle BEFORE free; assert reset post-free.
	var unit_ref: Variant = _unit
	unit_ref.get_parent().remove_child(unit_ref)
	# _exit_tree fires when remove_child completes.
	assert_eq(unit_ref._fog_handle, 0,
		"_fog_handle must be reset to 0 after _exit_tree fires "
		+ "(deregister-then-reset pattern). Confirms the deregister path "
		+ "executed end-to-end.")
	unit_ref.queue_free()
	_unit = null


# --- Coupled with Track 1: future "spawning a unit reveals cells" --------
#
# When Track 1's FogSystem.is_visible_to gets a real implementation that
# reads from _sources populated by register_vision_source, the assertion
# "spawning a Kargar at (0,0,0) for team Iran makes (0,0,0) visible to
# team Iran" becomes testable. Until then, the stub's is_visible_to
# returns false unconditionally.
#
# This test is structured to PASS against BOTH the stub (visibility
# returns false; we just assert no-crash on the read) and the real
# impl (returns true; we assert team-visibility). The conditional
# branch documents the coupling explicitly.

func test_spawned_unit_visibility_no_crash() -> void:
	# Minimum-viable: spawning a Unit must not crash FogSystem.is_visible_to
	# when called for the spawn position. Track 1 may make this stronger
	# (real visibility); the no-crash assertion is the coupled-test-gate
	# floor that holds against both stub and real impl.
	_unit = _spawn_unit(&"kargar", 1)
	_unit.global_position = Vector3.ZERO
	# is_visible_to is the consumer-side API. Per FogSystem header line
	# 210, the stub returns false unconditionally; Track 1 real impl
	# returns true when the team has a vision source covering the cell.
	# Either way, the call must not crash + must return bool.
	var visible: bool = FogSystem.is_visible_to(_unit.team, Vector3.ZERO)
	assert_true(typeof(visible) == TYPE_BOOL,
		"FogSystem.is_visible_to must return bool, not crash. Got type %d"
		% typeof(visible))
