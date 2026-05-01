class_name SimNode extends Node
##
## SimNode — base class for every gameplay component that holds simulation
## state. Per docs/SIMULATION_CONTRACT.md §1.3.
##
## Two contracts:
##
## 1. _sim_tick(_dt: float) is the per-tick override point. Phase coordinators
##    (landing session 2+) call _sim_tick on their registered components in
##    deterministic (unit_id) order during their phase. The base implementation
##    is a no-op so SimNodes that exist only to hold state (and not to act per
##    tick) don't need to provide one.
##
## 2. _set_sim(prop, value) is the on-tick mutation helper. It asserts that
##    SimClock.is_ticking() is true before writing — catching any code path
##    that mutates gameplay state from _process, a signal handler firing
##    off-tick, an awaited resumption, or a Tween/Timer callback. In debug
##    builds the assert halts with a stack trace; in release builds the
##    assert compiles out, so there is no perf cost.
##
## Self-only mutation rule: _set_sim is _-prefixed and intended to mutate
## *self* exclusively. A component never reaches into a sibling, parent, or
## unrelated node and calls other._set_sim(...). If state X must change as a
## side effect of state Y, the *owner of X* exposes a method (e.g.
## take_damage, apply_farr_change) that internally calls its own _set_sim.
##
## See Sim Contract §1.3 for the full discipline; see Sim Contract §4.1's
## Node3D.global_position carve-out for the one position-write exemption.


## Override in subclass. Called once per simulation tick by the registered
## phase coordinator. Default body is a no-op so state-only components work
## without ceremony.
func _sim_tick(_dt: float) -> void:
	pass


## Mutate a property on self. Asserts the caller is inside a SimClock tick.
## In debug builds, off-tick callers crash here with a clear message; in
## release the assert is elided.
func _set_sim(prop: StringName, value: Variant) -> void:
	assert(SimClock.is_ticking(),
		"Off-tick mutation of '%s' on '%s' (parent: %s)" % [
			prop, name, get_parent().name if get_parent() != null else "<root>"])
	set(prop, value)
