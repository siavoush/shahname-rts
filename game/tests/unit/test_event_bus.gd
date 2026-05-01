# Tests for EventBus autoload.
#
# Contract: docs/SIMULATION_CONTRACT.md §7 — typed signals declared in one
# file, with a passive sink API for telemetry consumers (Phase 6 MatchLogger).
# Session 1 ships only tick lifecycle signals: tick_started, tick_ended,
# sim_phase. Other signals land as their consuming systems land.
extends GutTest


# -- Signal capture helpers ---------------------------------------------------

var _tick_started_payloads: Array = []
var _tick_ended_payloads: Array = []
var _sim_phase_payloads: Array = []


func before_each() -> void:
	_tick_started_payloads = []
	_tick_ended_payloads = []
	_sim_phase_payloads = []


func _on_tick_started(tick: int) -> void:
	_tick_started_payloads.append(tick)


func _on_tick_ended(tick: int) -> void:
	_tick_ended_payloads.append(tick)


func _on_sim_phase(phase: StringName, tick: int) -> void:
	_sim_phase_payloads.append({"phase": phase, "tick": tick})


# -- Tests --------------------------------------------------------------------

func test_tick_started_signal_exists_and_emits_int_payload() -> void:
	EventBus.tick_started.connect(_on_tick_started)
	EventBus.tick_started.emit(42)
	EventBus.tick_started.disconnect(_on_tick_started)
	assert_eq(_tick_started_payloads, [42], "tick_started must deliver int payload verbatim")


func test_tick_ended_signal_exists_and_emits_int_payload() -> void:
	EventBus.tick_ended.connect(_on_tick_ended)
	EventBus.tick_ended.emit(7)
	EventBus.tick_ended.disconnect(_on_tick_ended)
	assert_eq(_tick_ended_payloads, [7], "tick_ended must deliver int payload verbatim")


func test_sim_phase_signal_exists_and_emits_phase_and_tick() -> void:
	EventBus.sim_phase.connect(_on_sim_phase)
	EventBus.sim_phase.emit(&"movement", 3)
	EventBus.sim_phase.disconnect(_on_sim_phase)
	assert_eq(_sim_phase_payloads.size(), 1)
	assert_eq(_sim_phase_payloads[0]["phase"], &"movement")
	assert_eq(_sim_phase_payloads[0]["tick"], 3)


func test_multiple_listeners_each_receive_emit() -> void:
	var second_log: Array = []
	var second_handler: Callable = func(t: int) -> void: second_log.append(t)
	EventBus.tick_started.connect(_on_tick_started)
	EventBus.tick_started.connect(second_handler)
	EventBus.tick_started.emit(99)
	EventBus.tick_started.disconnect(_on_tick_started)
	EventBus.tick_started.disconnect(second_handler)
	assert_eq(_tick_started_payloads, [99])
	assert_eq(second_log, [99])


func test_connect_sink_is_called_for_each_tracked_signal() -> void:
	var seen: Array = []
	var sink: Callable = func(sig: StringName, args: Array) -> void:
		seen.append({"sig": sig, "args": args})
	EventBus.connect_sink(sink)
	EventBus.tick_started.emit(11)
	EventBus.sim_phase.emit(&"input", 11)
	EventBus.tick_ended.emit(11)
	EventBus.disconnect_sink(sink)
	# Sink must have observed each emit, with the signal name passed.
	var sig_names: Array = []
	for entry in seen:
		sig_names.append(entry["sig"])
	assert_true(&"tick_started" in sig_names, "Sink should see tick_started")
	assert_true(&"sim_phase" in sig_names, "Sink should see sim_phase")
	assert_true(&"tick_ended" in sig_names, "Sink should see tick_ended")


func test_disconnect_sink_stops_delivery() -> void:
	var seen: Array = []
	var sink: Callable = func(sig: StringName, _args: Array) -> void: seen.append(sig)
	EventBus.connect_sink(sink)
	EventBus.disconnect_sink(sink)
	EventBus.tick_started.emit(1)
	assert_eq(seen.size(), 0, "Disconnected sink must not be invoked")
