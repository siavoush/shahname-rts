extends Node
##
## main.gd — Phase 1 placeholder root scene script.
##
## Phase 0 deliverable was a SimClock-tick console print. Phase 1 session 1
## wave 2 added initial unit spawning so the project boots into something
## visibly RTS-shaped: five colored cylinders (Kargar workers) on the
## terrain.
##
## Phase 2 session 1 wave 2A extends the spawn to also include 5 Iran
## Piyade (combat infantry) and 5 Turan Piyade (Turan mirror), so the
## lead can right-click across the map to engage and verify the wave-1A
## CombatComponent + ai-engineer wave-1B UnitState_Attacking + future
## click-handler wiring (wave 2B) end-to-end.
##
## Per 02d_PHASE_2_KICKOFF.md §2 deliverables 5+6: "Place 5 spawned at the
## start of the match (extending main.gd::_spawn_starting_kargars to also
## spawn 5 Turan_Piyade at the opposite map corner). Match-start
## formation: Iran kargars + Iran Piyade at one side; Turan Piyade at
## the opposite side."
##
## Spawn count: 5 of each type (kargar, Iran Piyade, Turan Piyade) = 15 units.
## This stays consistent with the wave-2 ergonomics knob from session 1
## (5 was the count then; bumping to 15 for combat doesn't change the
## per-type count).
##
## (Per CLAUDE.md "Escalation" rule #1: implementation choice with no
## gameplay effect → make the choice, document briefly.)

const _KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const _PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const _TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
# Path-string preload of unit.gd to avoid the class_name-registry race
# (docs/ARCHITECTURE.md §6 v0.4.0) — main.gd is loaded at scene boot,
# which is the same window where the Unit class_name may not yet be
# resolvable. Used only for the static reset_id_counter() helper.
const _UnitScript: Script = preload("res://scripts/units/unit.gd")


@onready var _status_label: Label = $StatusLabel
@onready var _world: Node3D = $World

var _last_print_tick: int = 0


# Iran starting positions for the 5 Phase-1 starting workers.
# Y=0.5 puts the unit's mesh-base just above the terrain plane (the
# Kargar mesh is offset upward inside the scene; this Y just nudges the
# whole CharacterBody3D so the collision shape doesn't sit half-buried).
# X/Z spread is a small "+" pattern centered on the origin — the Iran
# home base.
const _KARGAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 0.5, 0.0),
	Vector3(-3.0, 0.5, 0.0),
	Vector3(3.0, 0.5, 0.0),
	Vector3(0.0, 0.5, -3.0),
	Vector3(0.0, 0.5, 3.0),
]


# Iran Piyade starting positions — south of the Kargar cluster (Z=-8 area).
# A 5-wide line so the lead can box-select all five at once and right-click
# at a Turan target. Spaced 1.5 units apart so they don't visually overlap.
const _PIYADE_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-3.0, 0.5, -8.0),
	Vector3(-1.5, 0.5, -8.0),
	Vector3(0.0, 0.5, -8.0),
	Vector3(1.5, 0.5, -8.0),
	Vector3(3.0, 0.5, -8.0),
]


# Turan Piyade starting positions — opposite end of the map (Z=+20 area).
# Far enough that lead's Iran units have to walk a meaningful distance to
# engage (verifies Moving → Attacking transition over distance, not just
# in-range). Same line spacing as Iran Piyade for visual symmetry.
const _TURAN_PIYADE_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-3.0, 0.5, 20.0),
	Vector3(-1.5, 0.5, 20.0),
	Vector3(0.0, 0.5, 20.0),
	Vector3(1.5, 0.5, 20.0),
	Vector3(3.0, 0.5, 20.0),
]


func _ready() -> void:
	print("[main] Shahnameh RTS booted. Godot %s, SIM_HZ=%d." % [
		Engine.get_version_info().get("string", "unknown"),
		SimClock.SIM_HZ,
	])
	_spawn_starting_units()


# Spawn the Phase-1+2 starting roster: 5 Iran Kargar + 5 Iran Piyade +
# 5 Turan Piyade. Called from _ready (off-tick — UI layer of scene boot,
# no SimNode mutation discipline applies). Each unit instance auto-assigns
# its unit_id from the static Unit counter; we reset that counter first so
# the very first spawned unit is always #1 (deterministic test snapshots,
# replay diff cleanliness).
#
# Spawn order matters for unit_id determinism: kargars (1..5), Iran Piyade
# (6..10), Turan Piyade (11..15). Tests assert this exact sequence
# (test_match_start_spawn.gd::test_starting_units_have_unit_ids_1_through_15).
func _spawn_starting_units() -> void:
	# Per Unit.reset_id_counter doc — match-start hook so unit ids
	# always start at 1. MatchHarness already calls this on start_match;
	# the live boot does the equivalent here. Reflective call via the
	# preloaded script ref (not `Unit.reset_id_counter()`) for the same
	# class_name-registry-race reason _UnitScript exists.
	_UnitScript.call(&"reset_id_counter")

	# Iran Kargars (workers) — unit_ids 1..5.
	for pos: Vector3 in _KARGAR_SPAWN_POSITIONS:
		_spawn_unit(_KargarScene, pos, Constants.TEAM_IRAN)

	# Iran Piyade (combat infantry) — unit_ids 6..10.
	for pos: Vector3 in _PIYADE_SPAWN_POSITIONS:
		_spawn_unit(_PiyadeScene, pos, Constants.TEAM_IRAN)

	# Turan Piyade (enemy mirror) — unit_ids 11..15.
	for pos: Vector3 in _TURAN_PIYADE_SPAWN_POSITIONS:
		_spawn_unit(_TuranPiyadeScene, pos, Constants.TEAM_TURAN)


# Internal spawn helper. Team is set BEFORE add_child so the Unit's _ready
# (which mirrors team to SpatialAgentComponent) sees the correct value.
# Position is set BEFORE add_child for the same reason — the
# SpatialAgentComponent registers position on _ready.
func _spawn_unit(scene: PackedScene, pos: Vector3, team: int) -> void:
	var u: Node3D = scene.instantiate() as Node3D
	u.set(&"team", team)
	u.position = pos
	_world.add_child(u)


func _process(_delta: float) -> void:
	# UI read of sim state — explicitly allowed by Sim Contract §1.1
	# ("Reads from _process are unrestricted").
	_status_label.text = "tick=%d  sim_time=%.2fs" % [SimClock.tick, SimClock.sim_time]
	# Print once per second so the console isn't flooded.
	if SimClock.tick - _last_print_tick >= SimClock.SIM_HZ:
		_last_print_tick = SimClock.tick
		print("[main] SimClock.tick = %d (sim_time=%.2fs)" % [SimClock.tick, SimClock.sim_time])
