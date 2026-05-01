extends Node
##
## EventBus — single autoload for typed cross-system signals.
##
## Per docs/SIMULATION_CONTRACT.md §7: every signal in the project is declared
## here with typed args. Adding a signal requires editing this file. This is
## what keeps signals from devolving into a stringly-typed junk drawer
## (Risk Register, 02_IMPLEMENTATION_PLAN.md §6).
##
## Session 1 declares only the simulation-tick lifecycle signals. Other
## signals (farr_changed, unit_died, ability_cast, unit_state_changed, ...)
## are added in their respective phases per the implementation plan.
##
## The connect_sink / disconnect_sink API is the passive-consumer hook for
## MatchLogger (Phase 6) and any future telemetry sink. Per the Sim Contract
## §7 — Phase 0 ships the API even though no consumer subscribes yet, so
## Phase 6 is purely additive.

# ---- Tick lifecycle signals -------------------------------------------------
# Every tick-driven gameplay system observes these. SimClock is the sole emitter.

@warning_ignore("unused_signal")
signal tick_started(tick: int)

@warning_ignore("unused_signal")
signal tick_ended(tick: int)

@warning_ignore("unused_signal")
signal sim_phase(phase: StringName, tick: int)


# ---- State-machine and unit-lifecycle signals ------------------------------
# Declared here to support StateMachine death-preempt (State Machine Contract
# §4.2) and the unit_state_changed telemetry channel (§5.3 / §7.3). Producers
# (HealthComponent, Unit) ship in Phase 1+; the framework subscribes from
# Phase 0 so the wiring exists when consumers land.

@warning_ignore("unused_signal")
signal unit_health_zero(unit_id: int)

@warning_ignore("unused_signal")
signal unit_state_changed(unit_id: int, from_id: StringName, to_id: StringName, tick: int)


# ---- Farr signals -----------------------------------------------------------
# Emitted by FarrSystem.apply_farr_change(). The chokepoint is mandated by
# CLAUDE.md ("All Farr changes flow through a single function..."). Every
# Farr movement traces through here — UI overlay, telemetry sink, Kaveh-Event
# trigger, and balance analysis all subscribe.
#
# Fields per docs/SIMULATION_CONTRACT.md §7 (Phase 0 telemetry contract):
#   amount           — effective delta after clamp (float, post-conversion
#                      from internal fixed-point)
#   reason           — caller-supplied string for the F2 overlay log
#                      ("Hero rescued worker", "Worker killed defenseless")
#   source_unit_id   — int, -1 sentinel when no source unit was provided
#   farr_after       — Farr value after the change (float, post-clamp)
#   tick             — SimClock.tick at apply time (immutable in payload)
#
# Phase 0 wave 1 ships the signal; producers (generators/drains) wire up in
# Phase 4. F2 debug overlay consumes from Phase 4 onward.

@warning_ignore("unused_signal")
signal farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int)


# ---- Sink registry ----------------------------------------------------------
# Sinks observe every signal in _SINK_SIGNALS. To support disconnect_sink, we
# remember the per-signal forwarder Callables we created for each sink so we
# can disconnect by reference. The sink itself receives (signal_name, args:Array).
#
# Each forwarder is a per-signal Callable matching that signal's signature
# exactly — GDScript doesn't have varargs lambdas, so we register one
# concrete forwarder per (sink, signal) pair.

const _SINK_SIGNALS: Array[StringName] = [
	&"tick_started",
	&"tick_ended",
	&"sim_phase",
	&"unit_health_zero",
	&"unit_state_changed",
	&"farr_changed",
	# Extend as new write-shaped signals are added. Order is not significant.
]

# sink_callable -> { signal_name: forwarder_callable }
var _sink_forwarders: Dictionary = {}


## Subscribe a sink to every tracked signal. The sink Callable is invoked once
## per emit with (signal_name: StringName, args: Array). The args array carries
## the signal's positional arguments in order.
##
## Idempotent: connecting a sink twice is a no-op.
func connect_sink(sink: Callable) -> void:
	if _sink_forwarders.has(sink):
		return
	var forwarders: Dictionary = {}
	for sig in _SINK_SIGNALS:
		var forwarder: Callable = _make_forwarder(sig, sink)
		forwarders[sig] = forwarder
		var s: Signal = get(sig)
		s.connect(forwarder)
	_sink_forwarders[sink] = forwarders


## Remove a previously-connected sink. Idempotent: disconnecting an unknown
## sink is a no-op.
func disconnect_sink(sink: Callable) -> void:
	if not _sink_forwarders.has(sink):
		return
	var forwarders: Dictionary = _sink_forwarders[sink]
	for sig in forwarders.keys():
		var s: Signal = get(sig)
		var forwarder: Callable = forwarders[sig]
		if s.is_connected(forwarder):
			s.disconnect(forwarder)
	_sink_forwarders.erase(sink)


# Build the per-signal forwarder. Each signal in _SINK_SIGNALS gets a hand-
# rolled Callable here matching its exact arity. When we add signals we add
# arms here. Reflective approaches (Object.connect with bound array, etc.)
# don't preserve typed-arg checks, so we keep the dispatch explicit.
func _make_forwarder(sig: StringName, sink: Callable) -> Callable:
	match sig:
		&"tick_started":
			return func(tick: int) -> void: sink.call(sig, [tick])
		&"tick_ended":
			return func(tick: int) -> void: sink.call(sig, [tick])
		&"sim_phase":
			return func(phase: StringName, tick: int) -> void:
				sink.call(sig, [phase, tick])
		&"unit_health_zero":
			return func(unit_id: int) -> void: sink.call(sig, [unit_id])
		&"unit_state_changed":
			return func(unit_id: int, from_id: StringName, to_id: StringName, tick: int) -> void:
				sink.call(sig, [unit_id, from_id, to_id, tick])
		&"farr_changed":
			return func(amount: float, reason: String, source_unit_id: int,
					farr_after: float, tick: int) -> void:
				sink.call(sig, [amount, reason, source_unit_id, farr_after, tick])
		_:
			push_error("EventBus._make_forwarder: signal '%s' has no forwarder arm" % sig)
			return Callable()
