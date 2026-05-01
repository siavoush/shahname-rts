extends Node
##
## main.gd — Phase 0 placeholder root scene script.
##
## Session 1's only on-screen artifact: a Label that confirms SimClock is
## ticking. Periodically prints SimClock.tick to the console so a developer
## can verify the 30 Hz fixed-step driver is running. Replaced by the real
## main scene (menu -> match) in Phase 8.

@onready var _status_label: Label = $StatusLabel

var _last_print_tick: int = 0


func _ready() -> void:
	print("[main] Shahnameh RTS booted. Godot %s, SIM_HZ=%d." % [
		Engine.get_version_info().get("string", "unknown"),
		SimClock.SIM_HZ,
	])


func _process(_delta: float) -> void:
	# UI read of sim state — explicitly allowed by Sim Contract §1.1
	# ("Reads from _process are unrestricted").
	_status_label.text = "tick=%d  sim_time=%.2fs" % [SimClock.tick, SimClock.sim_time]
	# Print once per second so the console isn't flooded.
	if SimClock.tick - _last_print_tick >= SimClock.SIM_HZ:
		_last_print_tick = SimClock.tick
		print("[main] SimClock.tick = %d (sim_time=%.2fs)" % [SimClock.tick, SimClock.sim_time])
