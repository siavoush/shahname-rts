extends Node
##
## main.gd — Phase 1 placeholder root scene script.
##
## Phase 0 deliverable was a SimClock-tick console print. Phase 1 session 1
## wave 2 adds initial unit spawning so the project boots into something
## visibly RTS-shaped: five colored cylinders (Kargar workers) on the
## terrain, ready for the wave-2 SelectionManager + ClickHandler (ui-developer)
## to make them interactive.
##
## Per 02b_PHASE_1_KICKOFF.md §2 deliverable 9: "Spawn 5 Kargar at game
## start — placeholder spawn logic in main.gd or a small MatchSetup script."
## The kickoff doc gives discretion; main.gd is the simpler choice for
## five worker positions (~30 lines of spawn code), and keeps the single-
## source-of-truth for "where do units start at scene load" right where
## any future reader would look first. If/when spawn logic grows past
## ~50 lines (multiple unit types, randomized positions, etc.), extract
## to scripts/match_setup.gd — that decision is deferred per CLAUDE.md
## "implementation choice, prefer simplest option" rule.
##
## Spawn count: 5 (vs. the canonical 3 from 01_CORE_MECHANICS.md §2).
## Five gives the wave-2 selection UI more click-targets to test with;
## the canonical 3-worker start lands when the resource economy ships
## in Phase 3. Documented in QUESTIONS_FOR_DESIGN.md only if the design
## chat objects — for now, this is a UX-of-testing knob, not a balance
## value. (Per CLAUDE.md "Escalation" rule #1: implementation choice
## with no gameplay effect → make the choice, document briefly.)

const _KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
# Path-string preload of unit.gd to avoid the class_name-registry race
# (docs/ARCHITECTURE.md §6 v0.4.0) — main.gd is loaded at scene boot,
# which is the same window where the Unit class_name may not yet be
# resolvable. Used only for the static reset_id_counter() helper.
const _UnitScript: Script = preload("res://scripts/units/unit.gd")


@onready var _status_label: Label = $StatusLabel
@onready var _world: Node3D = $World

var _last_print_tick: int = 0


# Known spawn positions for the 5 Phase-1 starting workers.
# Y=0.5 puts the Kargar mesh-base just above the terrain plane (the
# Kargar mesh is offset upward inside the scene; this Y just nudges the
# whole CharacterBody3D so the collision shape doesn't sit half-buried).
# X/Z spread is a small "+" pattern centered on the origin so they fit
# in the default camera frame without trial-and-error positioning.
const _KARGAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 0.5, 0.0),
	Vector3(-3.0, 0.5, 0.0),
	Vector3(3.0, 0.5, 0.0),
	Vector3(0.0, 0.5, -3.0),
	Vector3(0.0, 0.5, 3.0),
]


func _ready() -> void:
	print("[main] Shahnameh RTS booted. Godot %s, SIM_HZ=%d." % [
		Engine.get_version_info().get("string", "unknown"),
		SimClock.SIM_HZ,
	])
	_spawn_starting_kargars()


# Spawn the Phase-1 starting workforce. Called from _ready (off-tick — UI
# layer of scene boot, no SimNode mutation discipline applies). Each
# Kargar instance auto-assigns its unit_id from the static Unit counter;
# we reset that counter first so the very first Kargar is always #1
# (deterministic test snapshots, replay diff cleanliness).
func _spawn_starting_kargars() -> void:
	# Per Unit.reset_id_counter doc — match-start hook so unit ids
	# always start at 1. MatchHarness already calls this on start_match;
	# the live boot does the equivalent here. Reflective call via the
	# preloaded script ref (not `Unit.reset_id_counter()`) for the same
	# class_name-registry-race reason _UnitScript exists.
	_UnitScript.call(&"reset_id_counter")

	for pos: Vector3 in _KARGAR_SPAWN_POSITIONS:
		var k: Node3D = _KargarScene.instantiate() as Node3D
		# Team is set BEFORE add_child so the Unit's _ready (which mirrors
		# team to SpatialAgentComponent) sees the correct value.
		k.set(&"team", Constants.TEAM_IRAN)
		# Position is set BEFORE add_child for the same reason — the
		# SpatialAgentComponent registers position on _ready.
		k.position = pos
		_world.add_child(k)


func _process(_delta: float) -> void:
	# UI read of sim state — explicitly allowed by Sim Contract §1.1
	# ("Reads from _process are unrestricted").
	_status_label.text = "tick=%d  sim_time=%.2fs" % [SimClock.tick, SimClock.sim_time]
	# Print once per second so the console isn't flooded.
	if SimClock.tick - _last_print_tick >= SimClock.SIM_HZ:
		_last_print_tick = SimClock.tick
		print("[main] SimClock.tick = %d (sim_time=%.2fs)" % [SimClock.tick, SimClock.sim_time])
