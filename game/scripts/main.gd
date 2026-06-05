extends Node
##
## main.gd — Phase 1+2 placeholder root scene script.
##
## Phase 0 deliverable was a SimClock-tick console print. Phase 1 session 1
## wave 2 added initial unit spawning so the project boots into something
## visibly RTS-shaped: five colored cylinders (Kargar workers) on the
## terrain.
##
## Phase 2 session 1 wave 2A extended the spawn to also include 5 Iran
## Piyade (combat infantry) and 5 Turan Piyade (Turan mirror), so the
## lead can right-click across the map to engage and verify the wave-1A
## CombatComponent + ai-engineer wave-1B UnitState_Attacking + future
## click-handler wiring (wave 2B) end-to-end.
##
## Phase 2 session 2 wave 2B extends the spawn again with the full RPS
## roster (Kamandar + Savar + AsbSavarKamandar + their Turan mirrors,
## three of each) so the lead can interactively test the rock-paper-
## scissors triangle from `02e_PHASE_2_SESSION_2_KICKOFF.md` §2 (DoD
## items 3, 4, 5):
##   * 5 Piyade vs 5 Savar — Piyade should win (1.5× anti-cavalry).
##   * 5 Savar vs 5 Kamandar — Savar should curb-stomp (2.0× anti-archer).
##   * 3 Asb-savar vs 5 Piyade — Asb-savar kites (range 7.0 vs Piyade 1.5).
##
## Spawn count: 5 Kargar + 5 Iran Piyade + 5 Turan Piyade + 3 of each of
## the 6 new types = 33 starting units. Lead box-selects per-cluster for
## the scenario they want; the existing 5/5/5 anchors are unchanged so
## previous live-test muscle memory still works.
##
## (Per CLAUDE.md "Escalation" rule #1: implementation choice with no
## gameplay effect → make the choice, document briefly.)

const _KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const _MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
# Wave-3-Throne — scene shipped by world-builder Track 2 at 5ff7d26.
const _ThroneScene: PackedScene = preload(
	"res://scenes/world/buildings/throne.tscn")
const _PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const _TuranPiyadeScene: PackedScene = preload("res://scenes/units/turan_piyade.tscn")
const _KamandarScene: PackedScene = preload("res://scenes/units/kamandar.tscn")
const _SavarScene: PackedScene = preload("res://scenes/units/savar.tscn")
const _AsbSavarKamandarScene: PackedScene = preload("res://scenes/units/asb_savar_kamandar.tscn")
const _TuranKamandarScene: PackedScene = preload("res://scenes/units/turan_kamandar.tscn")
const _TuranSavarScene: PackedScene = preload("res://scenes/units/turan_savar.tscn")
const _TuranAsbSavarScene: PackedScene = preload("res://scenes/units/turan_asb_savar.tscn")
# Path-string preload of unit.gd to avoid the class_name-registry race
# (docs/ARCHITECTURE.md §6 v0.4.0) — main.gd is loaded at scene boot,
# which is the same window where the Unit class_name may not yet be
# resolvable. Used only for the static reset_id_counter() helper.
const _UnitScript: Script = preload("res://scripts/units/unit.gd")
# Wave-3-Sim — HeadlessMatchRunner is spawned under --headless-batch (see
# _ready + _spawn_headless_match_runner below). Path-string preload for
# parity with _UnitScript above.
const _HeadlessMatchRunnerScript: Script = preload(
	"res://scripts/sim/headless_match_runner.gd")


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


# ---------------------------------------------------------------------------
# Phase 2 session 2 wave 2B — RPS-roster spawn clusters.
#
# Geometry rationale (the "two opposing armies" read at default zoom):
#   * Iran clusters all live at Z < 0 (south of origin) — same side as the
#     existing Iran Piyade line at Z=-8. Three trios are arranged left/center/
#     right within the Iran band:
#       Kamandar          NW corner  (X≈-9, Z≈-12)
#       Savar             NE corner  (X≈+9, Z≈-12)
#       AsbSavarKamandar  S-center   (X≈ 0, Z≈-15)
#   * Turan clusters mirror those at Z > 0 — same side as the existing
#     Turan Piyade line at Z=+20:
#       TuranKamandar     NW corner  (X≈-9, Z≈+24)
#       TuranSavar        NE corner  (X≈+9, Z≈+24)
#       TuranAsbSavar     N-center   (X≈ 0, Z≈+27)
#
# Spacing within each trio is 1.5 units (matches Piyade-line spacing),
# so a tight box-select drag lands one cluster cleanly without picking up
# adjacent trios. The Iran↔Turan Z gap is ≥ 24 units (further than the
# wave-2A Piyade gap, deliberately) — Asb-savar's 7.0 attack range still
# requires a meaningful walk to engage.
#
# Live-game-broken-surface answers (Experiment 01):
#   1. Runtime state no unit test exercises: each scene must instantiate
#      cleanly and the Unit's @export unit_type must survive scene load
#      (the dual-init pattern: each unit subclass's _init AND _ready set
#      unit_type). Wave-1A through wave-1C scenes already cover this in
#      their own unit tests — wave-2B trusts that surface.
#   2. Headless can't detect: visual readability — does the layout READ
#      as Iran-column-vs-Turan-column? Does the trio of 3 stand visually
#      apart from the line of 5 Piyade? The Z-staggering (Kamandar/Savar
#      trios at Z=-12 vs Piyade at Z=-8) gives front/back separation;
#      the X-spread between corner trios prevents cluster overlap.
#   3. Min interactive smoke: lead boots, sees 33 units split into two
#      visible columns. Box-selects Iran Kamandar trio, right-clicks far
#      Turan Savar trio: Kamandar fires from range, Savar charges in,
#      Savar wins (anti-archer 2.0×). Repeat for each RPS pair.

const _KAMANDAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-10.5, 0.5, -12.0),
	Vector3(-9.0, 0.5, -12.0),
	Vector3(-7.5, 0.5, -12.0),
]

const _SAVAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(7.5, 0.5, -12.0),
	Vector3(9.0, 0.5, -12.0),
	Vector3(10.5, 0.5, -12.0),
]

const _ASB_SAVAR_KAMANDAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-1.5, 0.5, -15.0),
	Vector3(0.0, 0.5, -15.0),
	Vector3(1.5, 0.5, -15.0),
]

const _TURAN_KAMANDAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-10.5, 0.5, 24.0),
	Vector3(-9.0, 0.5, 24.0),
	Vector3(-7.5, 0.5, 24.0),
]

const _TURAN_SAVAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(7.5, 0.5, 24.0),
	Vector3(9.0, 0.5, 24.0),
	Vector3(10.5, 0.5, 24.0),
]

const _TURAN_ASB_SAVAR_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-1.5, 0.5, 27.0),
	Vector3(0.0, 0.5, 27.0),
	Vector3(1.5, 0.5, 27.0),
]


# ---------------------------------------------------------------------------
# Phase 3 wave 1A — Coin MineNode spawn cluster.
#
# Five mines placed in the central wave-area (Z ≈ 0..15, between Iran's
# Kargar/Piyade clusters at Z≤0 and Turan's at Z≥20). This is "no-man's
# land" — the player has to walk workers out from the home base to gather,
# which is the gameplay intent (mines aren't free at the doorstep).
#
# X-spread is asymmetric (mostly negative-X) to leave the +X corridor open
# for the existing Iran Savar / Turan Savar engagement zone. Y = 0.0 so the
# mine's mesh-bottom sits flat on the terrain — MineNode.tscn handles the
# 0.25 mesh-offset internally.
#
# Live-game-broken-surface considerations:
#   1. Positions are clearly within the terrain plane bounds — no off-map
#      mines that fail to spawn visibly.
#   2. Wave-1A doesn't yet bake a navmesh (LATER L2 MovementSystem coord),
#      so "off-navmesh" isn't a current failure mode; MockPathScheduler in
#      tests uses straight-line paths, and the live game falls back to the
#      production NavigationAgentPathScheduler (which itself FAILs when no
#      navmesh exists — workers seeing FAILED bail to Idle per wave-1A
#      defensive design). Wave 1B adds the navmesh; this spawn layout will
#      need a re-check to confirm each position is inside the baked region.
#   3. Yellow against sandy terrain — the FarrGauge contrast lesson is
#      reflected in MineNode.tscn's saturated gold material. Lead live-
#      tests post-wave-1A and reports if the color blends.

const _COIN_MINE_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-8.0, 0.0, 5.0),
	Vector3(-12.0, 0.0, 8.0),
	Vector3(-6.0, 0.0, 12.0),
	Vector3(-14.0, 0.0, 0.0),
	Vector3(-10.0, 0.0, 15.0),
]


func _ready() -> void:
	print("[main] Shahnameh RTS booted. Godot %s, SIM_HZ=%d." % [
		Engine.get_version_info().get("string", "unknown"),
		SimClock.SIM_HZ,
	])
	# Wave-3-Throne — Thrones spawn BEFORE units so workers can deposit at
	# them from tick 0 (no race where the first gather cycle completes
	# before any Throne exists). Each Throne joins the &"thrones" SceneTree
	# group on its _ready, so ResourceSystem.dropoff_for_team finds it
	# immediately afterward.
	_spawn_starting_buildings()
	_spawn_starting_units()
	_spawn_starting_resources()

	# Wave-3-Sim — under `--headless-batch` (the AI-vs-AI batch runner),
	# instantiate HeadlessMatchRunner as a child of self so it can observe
	# the match end-to-end (EventBus.throne_destroyed subscription +
	# timeout watchdog + NDJSON emit + get_tree().quit(0)). The runner is
	# spawned AFTER _spawn_starting_buildings/units so all starting Thrones,
	# Kargars, etc. exist before signal subscription latches first events.
	#
	# Args land in OS.get_cmdline_user_args() (everything after the `--`
	# separator). OS.get_cmdline_args() returns the FULL argv including
	# engine-consumed args like `--headless` / `--path`, which would also
	# work for has("--headless-batch") but we standardize on user_args
	# for clarity + to mirror the runner's _parse_args.
	if OS.get_cmdline_user_args().has("--headless-batch"):
		_spawn_headless_match_runner()


# Wave-3-Sim Track 2 — boot the HeadlessMatchRunner under --headless-batch.
# The runner is a plain Node; main.tscn's autoloads (SimClock, EventBus,
# ResourceSystem, FarrSystem, TuranController, DummyIranController, ...)
# boot first via project.godot's [autoload] block, so by the time the
# runner's _ready fires every identifier it references is resolvable.
func _spawn_headless_match_runner() -> void:
	var runner: Node = _HeadlessMatchRunnerScript.new()
	runner.name = &"HeadlessMatchRunner"
	add_child(runner)


# Wave-3-Throne — spawn one Throne per faction at match start. Iran's
# Throne sits south of the Kargar cluster (Z<<0); Turan's mirrors at
# Z>>0. Spec stakes are terminal: destroying a Throne = end of realm
# (forward-compat seam for Phase 8 win screen via
# EventBus.throne_destroyed).
#
# Per brief §4 Track 1 + 01_CORE_MECHANICS.md §1+§2: "each player starts
# with one Throne." MVP has exactly one per faction; multi-base + repair
# + rebuilding are out-of-scope per kickoff §1 deferrals.
#
# Position picks: Z=-32 / Z=+32 keep the Thrones far from the central
# wave-area (mines at Z≈0..15, RPS combat clusters at Z≈±8 to ±20) so
# workers visibly walk back from gather-site → Throne for their deposit
# loop. The map is 256m square per Constants.MAP_SIZE_WORLD; ±32 is
# well inside the playable area without crowding the unit clusters.
func _spawn_starting_buildings() -> void:
	# Iran Throne — south side (Z<0), behind the Kargar/Piyade clusters.
	var iran_throne: Node3D = _ThroneScene.instantiate() as Node3D
	iran_throne.set(&"team", Constants.TEAM_IRAN)
	iran_throne.position = Vector3(0.0, 0.0, -32.0)
	_world.add_child(iran_throne)
	# Turan Throne — north side (Z>0), behind the Turan unit clusters at
	# Z≈20-25. Symmetric to Iran's position so faction-asymmetric
	# gameplay can be analyzed against a symmetric geometry baseline.
	var turan_throne: Node3D = _ThroneScene.instantiate() as Node3D
	turan_throne.set(&"team", Constants.TEAM_TURAN)
	turan_throne.position = Vector3(0.0, 0.0, 32.0)
	_world.add_child(turan_throne)


# Spawn the Phase-1 + Phase-2 starting roster: 5 Iran Kargar + 5 Iran Piyade
# + 5 Turan Piyade + 3 Iran Kamandar + 3 Iran Savar + 3 Iran AsbSavarKamandar
# + 3 Turan Kamandar + 3 Turan Savar + 3 Turan AsbSavar = 33 units total.
# Called from _ready (off-tick — UI layer of scene boot, no SimNode mutation
# discipline applies). Each unit instance auto-assigns its unit_id from the
# static Unit counter; we reset that counter first so the very first spawned
# unit is always #1 (deterministic test snapshots, replay diff cleanliness).
#
# Spawn order matters for unit_id determinism (tests assert this exact
# sequence in test_match_start_spawn.gd::
# test_starting_units_have_unit_ids_1_through_33):
#   Kargar              1..5
#   Iran Piyade         6..10
#   Turan Piyade        11..15
#   Iran Kamandar       16..18
#   Iran Savar          19..21
#   Iran AsbSavarKamandar 22..24
#   Turan Kamandar      25..27
#   Turan Savar         28..30
#   Turan AsbSavar      31..33
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

	# Phase 2 session 2 wave 2B — RPS-triangle clusters.

	# Iran Kamandar (foot archers) — unit_ids 16..18.
	for pos: Vector3 in _KAMANDAR_SPAWN_POSITIONS:
		_spawn_unit(_KamandarScene, pos, Constants.TEAM_IRAN)

	# Iran Savar (cavalry) — unit_ids 19..21.
	for pos: Vector3 in _SAVAR_SPAWN_POSITIONS:
		_spawn_unit(_SavarScene, pos, Constants.TEAM_IRAN)

	# Iran AsbSavarKamandar (horse archers) — unit_ids 22..24.
	for pos: Vector3 in _ASB_SAVAR_KAMANDAR_SPAWN_POSITIONS:
		_spawn_unit(_AsbSavarKamandarScene, pos, Constants.TEAM_IRAN)

	# Turan Kamandar mirror — unit_ids 25..27.
	for pos: Vector3 in _TURAN_KAMANDAR_SPAWN_POSITIONS:
		_spawn_unit(_TuranKamandarScene, pos, Constants.TEAM_TURAN)

	# Turan Savar mirror — unit_ids 28..30.
	for pos: Vector3 in _TURAN_SAVAR_SPAWN_POSITIONS:
		_spawn_unit(_TuranSavarScene, pos, Constants.TEAM_TURAN)

	# Turan AsbSavar mirror — unit_ids 31..33.
	for pos: Vector3 in _TURAN_ASB_SAVAR_SPAWN_POSITIONS:
		_spawn_unit(_TuranAsbSavarScene, pos, Constants.TEAM_TURAN)


# Phase 3 wave 1A — spawn the starting resource nodes. Per kickoff §3:
# 5 Coin mines in the central wave-area so the lead can right-click a mine
# with a selected Kargar and observe the full gather-deposit-loop.
#
# Wave 1B adds:
#   - The deposit target (Throne or ResourceSystem hookup); wave-1A's
#     Returning state stub uses the worker's own position, which is enough
#     to verify the loop's FSM topology but not to credit a HUD counter.
#   - Mazra'eh (Grain) farms — Mazra'eh extends ResourceNode similarly.
#   - BalanceData-driven reserves / yield_per_trip / extract_ticks; wave 1A
#     hardcodes these in mine_node.gd with TODO citations.
func _spawn_starting_resources() -> void:
	for pos: Vector3 in _COIN_MINE_SPAWN_POSITIONS:
		var mine: Node3D = _MineNodeScene.instantiate() as Node3D
		mine.position = pos
		_world.add_child(mine)


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
