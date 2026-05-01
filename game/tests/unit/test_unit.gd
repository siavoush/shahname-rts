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
