# Tests for GroupMoveController — formation-distribution dispatch.
#
# Contract: docs/STATE_MACHINE_CONTRACT.md §2.5 (Unit.replace_command is the
# only sanctioned write path). Per kickoff brief Phase 1 session 2 wave 1B,
# the controller distributes a multi-unit move across deterministic offsets
# around the click point so units don't pile on the exact same nav-target.
#
# What we cover (per kickoff):
#   - empty Array no-op
#   - single unit → identity (target unchanged, no offset)
#   - 5 units → 5 distinct offsets, each within radius R of target
#   - same input twice → identical offsets (determinism — no RNG)
#   - freed-unit array → still dispatches to live ones, skips invalid
#   - multi-unit dispatch puts a Move command in every unit's queue with the
#     expected kind and payload.target shape (uses the real Unit.replace_command
#     contract via MatchHarness-spawned units)
extends GutTest


const GroupMoveControllerScript: Script = preload(
	"res://scripts/movement/group_move_controller.gd")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")
const MockPathSchedulerScript: Script = preload(
	"res://scripts/navigation/mock_path_scheduler.gd")
const MatchHarnessScript: Script = preload(
	"res://tests/harness/match_harness.gd")


# Lightweight fake that exposes only the surface dispatch_group_move needs to
# *call* (replace_command). Captures the most-recent invocation so offset
# tests can read the dispatched target back. No FSM, no command_queue, no
# scene tree — pure script object. Avoids Unit's heavy spawn cost when all
# we want to verify is the geometry math.
class FakeUnit extends RefCounted:
	var unit_id: int = -1
	var last_kind: StringName = &""
	var last_payload: Dictionary = {}
	var call_count: int = 0

	func replace_command(kind: StringName, payload: Dictionary) -> void:
		call_count += 1
		last_kind = kind
		last_payload = payload


var _harness: Variant
var _spawned_units: Array = []


func before_each() -> void:
	SimClock.reset()
	CommandPool.reset()
	UnitScript.call(&"reset_id_counter")
	_spawned_units.clear()


func after_each() -> void:
	for u in _spawned_units:
		if is_instance_valid(u):
			u.queue_free()
	_spawned_units.clear()
	if _harness != null:
		_harness.teardown()
		_harness = null
	SimClock.reset()
	CommandPool.reset()


# Build a fresh FakeUnit. Cheap; no scene tree.
func _make_fake(uid: int) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	return u


# Spawn a real Kargar via the scene template so we have the full
# replace_command → command_queue → fsm.transition_to_next path. Used by
# the dispatch-shape test. Inject a MockPathScheduler so Moving's repath
# doesn't touch NavigationServer3D.
func _spawn_real_unit() -> Variant:
	var u: Variant = KargarScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	# Override the scheduler with a mock so Moving.enter's request_repath is
	# benign. Same pattern as test_unit_states.gd.
	var mock: Variant = MockPathSchedulerScript.new()
	u.get_movement()._scheduler = mock
	_spawned_units.append(u)
	return u


# ---------------------------------------------------------------------------
# Empty input
# ---------------------------------------------------------------------------

func test_empty_units_array_is_a_noop() -> void:
	# Pure no-op — must not push_error, push_warning, or crash.
	GroupMoveControllerScript.dispatch_group_move([], Vector3(10, 0, 10))
	# No way to observe a no-op other than "did not crash."
	assert_true(true, "empty Array dispatch must not crash")


# ---------------------------------------------------------------------------
# Single unit: identity
# ---------------------------------------------------------------------------

func test_single_unit_target_is_unchanged() -> void:
	# 1 unit → no offset; target passes through verbatim. Behavior matches
	# the single-click move (Phase 1 session 1) exactly.
	var u: FakeUnit = _make_fake(1)
	var target: Vector3 = Vector3(7.5, 0.0, -3.25)
	GroupMoveControllerScript.dispatch_group_move([u], target)
	assert_eq(u.call_count, 1, "single unit must receive exactly one command")
	assert_eq(u.last_kind, Constants.COMMAND_MOVE,
		"single unit dispatch must be a Move command")
	var dispatched: Vector3 = u.last_payload.get(&"target", Vector3.ZERO)
	assert_eq(dispatched, target,
		"single unit's dispatched target must equal the click point exactly")


# ---------------------------------------------------------------------------
# Multi-unit: distinct offsets within radius
# ---------------------------------------------------------------------------

func test_five_units_get_five_distinct_offsets() -> void:
	# 5 distinct positions, all within the offset radius of the target.
	var fakes: Array = []
	for i in range(5):
		fakes.append(_make_fake(i + 1))
	var target: Vector3 = Vector3(20.0, 0.0, 30.0)
	GroupMoveControllerScript.dispatch_group_move(fakes, target)

	# Collect dispatched targets. Use Vector3 directly — we'll dedupe via
	# round-trip serialization since Array.has uses == which works for
	# Vector3.
	var seen: Array = []
	for u in fakes:
		assert_eq(u.call_count, 1,
			"each unit in the group must get exactly one command")
		var t: Vector3 = u.last_payload.get(&"target", Vector3.ZERO)
		assert_false(seen.has(t),
			"each unit's offset target must be distinct (got duplicate %s)" % t)
		seen.append(t)
		# Each offset must be within the configured radius of the click point.
		var d: float = Vector2(t.x - target.x, t.z - target.z).length()
		var r: float = Constants.GROUP_MOVE_OFFSET_RADIUS
		# Two-ring arrangement allows up to 2*R for outer-ring slots; we keep
		# 5 units in the inner ring + center, so all offsets fit within R.
		# Add a small epsilon to absorb floating-point math (sin/cos roundoff).
		assert_true(d <= r + 1e-4,
			"unit %d offset distance %f exceeds radius %f" % [u.unit_id, d, r])


func test_five_units_y_is_preserved_from_target() -> void:
	# Y axis is ignored for offset math (offsets live on the XZ plane per
	# Constants/SpatialIndex). Each dispatched target must keep the click's
	# Y component verbatim — preserves any future height-aware navmesh.
	var fakes: Array = []
	for i in range(5):
		fakes.append(_make_fake(i + 1))
	var target: Vector3 = Vector3(0.0, 1.7, 0.0)
	GroupMoveControllerScript.dispatch_group_move(fakes, target)
	for u in fakes:
		var t: Vector3 = u.last_payload.get(&"target", Vector3.ZERO)
		assert_almost_eq(t.y, target.y, 1e-6,
			"dispatched target Y must equal the click target Y for unit %d" % u.unit_id)


# ---------------------------------------------------------------------------
# Determinism: same input twice produces identical offsets
# ---------------------------------------------------------------------------

func test_same_input_twice_produces_identical_offsets() -> void:
	# Critical: replays and tests rely on bit-for-bit determinism. No RNG
	# allowed in offset math.
	var fakes_a: Array = []
	var fakes_b: Array = []
	for i in range(5):
		fakes_a.append(_make_fake(i + 1))
		fakes_b.append(_make_fake(i + 1))
	var target: Vector3 = Vector3(13.5, 0.0, -7.25)

	GroupMoveControllerScript.dispatch_group_move(fakes_a, target)
	GroupMoveControllerScript.dispatch_group_move(fakes_b, target)

	for i in range(5):
		var ta: Vector3 = fakes_a[i].last_payload.get(&"target", Vector3.ZERO)
		var tb: Vector3 = fakes_b[i].last_payload.get(&"target", Vector3.ZERO)
		assert_eq(ta, tb,
			"unit at index %d must receive identical offset on repeat dispatch" % i)


# ---------------------------------------------------------------------------
# Freed units
# ---------------------------------------------------------------------------

func test_freed_units_in_array_are_skipped() -> void:
	# When the input Array contains entries that fail is_instance_valid (e.g.,
	# a unit that died between selection and dispatch), the controller must
	# silently skip them and dispatch to the live ones.
	var live_a: Variant = _spawn_real_unit()
	var dead: Variant = _spawn_real_unit()
	var live_b: Variant = _spawn_real_unit()

	# Free the middle unit and let the queue_free settle.
	dead.queue_free()
	await get_tree().process_frame

	var inputs: Array = [live_a, dead, live_b]
	# Should not crash on the dead element; the two live units must each
	# get exactly one Move command in their queue.
	GroupMoveControllerScript.dispatch_group_move(inputs, Vector3(5, 0, 5))

	# replace_command pushes a fresh Command then calls fsm.transition_to_next,
	# which pops it. After dispatch, command_queue should be empty (popped),
	# and current_command should hold the dispatched payload. Cheap probe:
	# read current_command from each live unit.
	assert_eq(live_a.current_command.get(&"kind"), Constants.COMMAND_MOVE,
		"live unit A must have received the Move command")
	assert_eq(live_b.current_command.get(&"kind"), Constants.COMMAND_MOVE,
		"live unit B must have received the Move command")


# ---------------------------------------------------------------------------
# Dispatch shape: real Unit.replace_command path (kickoff: "use MatchHarness
# only for the dispatch test")
# ---------------------------------------------------------------------------

func test_multi_unit_dispatch_goes_through_replace_command() -> void:
	# Use the MatchHarness so we share the production setup the rest of the
	# test suite uses (autoload reset, MockPathScheduler injected, BalanceData
	# loaded). Spawn 3 real Kargar units inside the harness's lifetime.
	_harness = MatchHarnessScript.new()
	_harness.start_match(0, &"empty")

	var units: Array = []
	for i in range(3):
		units.append(_spawn_real_unit())

	var target: Vector3 = Vector3(15.0, 0.0, 25.0)
	GroupMoveControllerScript.dispatch_group_move(units, target)

	# Each unit must have observed a Move command land in its FSM via the
	# replace_command → transition_to_next pipeline. After dispatch, the
	# StateMachine has popped the command into current_command; payload.target
	# is the per-unit offset.
	var seen_targets: Array = []
	for u in units:
		assert_eq(u.current_command.get(&"kind"), Constants.COMMAND_MOVE,
			"unit %d must have a Move command dispatched" % u.unit_id)
		var p: Variant = u.current_command.get(&"payload", {})
		assert_true(p is Dictionary, "dispatched payload must be a Dictionary")
		assert_true((p as Dictionary).has(&"target"),
			"dispatched payload must have a target key")
		var t: Vector3 = (p as Dictionary)[&"target"]
		assert_false(seen_targets.has(t),
			"each unit's dispatched target must be distinct (saw duplicate %s)" % t)
		seen_targets.append(t)
