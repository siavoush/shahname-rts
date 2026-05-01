# Tests for SimNode base class.
#
# Contract: docs/SIMULATION_CONTRACT.md §1.3 — every gameplay component
# extends SimNode. _set_sim(prop, value) asserts SimClock.is_ticking() before
# mutating self. _sim_tick(_dt) is the virtual override point for per-tick
# logic. Self-only mutation is the discipline (§1.3 paragraph 4).
#
# Note on assertion semantics: assert() in GDScript halts execution in debug
# builds and compiles out in release builds. GUT cannot trap a fired assert()
# in-process — the engine calls push_error and (in debug) halts the script.
# The test below verifies the on-tick happy path. The off-tick path is
# indirectly verified by inspecting that _set_sim takes is_ticking into
# account and via the visible runtime error when the contract is breached.
extends GutTest


# A tiny SimNode subclass we can drive in isolation without spinning up the
# real component graph.
class TestSimNode extends "res://scripts/core/sim_node.gd":
	var hp: int = 100
	var label: String = "fresh"
	var ticks_seen: int = 0
	var last_dt: float = -1.0

	func _sim_tick(dt: float) -> void:
		ticks_seen += 1
		last_dt = dt


var _node: TestSimNode


func before_each() -> void:
	_node = TestSimNode.new()
	add_child_autofree(_node)
	SimClock.reset()


func after_each() -> void:
	SimClock.reset()


# -- Default _sim_tick is a no-op --------------------------------------------

func test_default_sim_tick_is_a_no_op() -> void:
	# A SimNode that doesn't override _sim_tick must not crash when called.
	var bare: SimNode = SimNode.new()
	add_child_autofree(bare)
	# Direct call — we're verifying the base method exists and returns cleanly.
	bare._sim_tick(SimClock.SIM_DT)
	# Reaching this line is the assertion.
	assert_true(true)


# -- _sim_tick subclass override fires correctly -----------------------------

func test_subclass_sim_tick_observes_dt() -> void:
	_node._sim_tick(SimClock.SIM_DT)
	assert_eq(_node.ticks_seen, 1)
	assert_almost_eq(_node.last_dt, SimClock.SIM_DT, 1e-6)


# -- _set_sim happy path (on-tick) -------------------------------------------

func test_set_sim_mutates_when_ticking() -> void:
	# Manually flip is_ticking using the Sim Contract's intended path: drive
	# a real tick and call _set_sim from inside the tick window.
	#
	# We use a one-shot signal handler that calls _set_sim during the
	# &"movement" phase — analogous to how a real component would mutate
	# itself when its phase coordinator dispatches.
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"movement":
			_node._set_sim(&"hp", 42)
			_node._set_sim(&"label", "mutated")
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)
	assert_eq(_node.hp, 42, "On-tick _set_sim must mutate the property")
	assert_eq(_node.label, "mutated", "On-tick _set_sim works for any property")


# -- _set_sim writes through Object.set (typed and dynamic) ------------------

func test_set_sim_supports_string_name_property_keys() -> void:
	# Drive a tick; mutate via StringName key — this is the canonical idiom.
	var handler: Callable = func(phase: StringName, _tick: int) -> void:
		if phase == &"farr":
			_node._set_sim(&"hp", 7)
	EventBus.sim_phase.connect(handler)
	SimClock._test_run_tick()
	EventBus.sim_phase.disconnect(handler)
	assert_eq(_node.hp, 7)


# -- Off-tick guard ---------------------------------------------------------
#
# The Sim Contract §1.3 says "_set_sim asserts off-tick mutation." In a debug
# build the assert raises a runtime error; in a release build it compiles
# out. GUT cannot trap a fired assert in-process, so the most we can verify
# here is the prerequisite (is_ticking is false outside a tick), and that
# the helper method exists and is callable in the on-tick happy path. The
# off-tick assertion is exercised manually with the editor's debug runner
# and via the lint rule (Sim Contract §1.4 patterns L1, L2, L5) which
# catches the call sites that would trigger it.

func test_is_ticking_is_false_outside_tick_window() -> void:
	# Sanity: confirms the precondition the _set_sim assert checks.
	assert_false(SimClock.is_ticking(),
		"Outside any phase coordinator dispatch, is_ticking must be false")
