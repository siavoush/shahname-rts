extends GutTest
##
## Determinism regression test (per docs/TESTING_CONTRACT.md §6.2 and
## docs/SIMULATION_CONTRACT.md §6.2).
##
## Two layers (Wave C3 / TEST-4 closed the Phase-0 debt):
##
##   1. Phase-0 baseline (kept): the same seeded EMPTY match run twice
##      produces identical snapshots. Guards the bare tick pipeline.
##
##   2. Real-gameplay snapshot-hash (NEW): the same seeded roster — gather
##      loop + throne deposit, melee combat with deaths, Farr drain, an
##      operational building — run twice IN-PROCESS for N ticks produces an
##      identical composite state hash. The composite covers: SimClock.tick,
##      ResourceSystem per-team coin/grain x100, FarrSystem farr_x100,
##      sorted per-unit (type, team, position-as-x100-ints, hp_x100), and
##      building count. This is the test that answers DET-2 ("does
##      in-process cross-run determinism hold despite EventBus
##      connection-order accumulation?") empirically.
##
## If this test fails, the most likely causes are:
##   - Wall-clock reads in a system (violates Sim Contract §1.2, caught by L5)
##   - Bare randi()/randf() calls outside seeded RNG (caught by L3)
##   - Off-tick mutations that accumulate floating-point drift
##   - EventBus signal connection order varying across runs (DET-2 — if the
##     divergence is HERE, the composite diff below shows positions/hp
##     differing while tick/resources match; document the diff in the
##     failure issue, do not paper over it)
##   - Global mutable state not reset between harness runs (MatchHarness v2
##     resets all 13 resettable autoloads — check any NEW autoload grew a
##     reset() and joined _reset_all_autoloads)

# Preloaded script ref for the class_name-registry-race pattern.
const _MH: Script = preload("res://tests/harness/match_harness.gd")
const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")

# Tick budget for the real-gameplay run. Sized so the scenario completes its
# interesting arcs (see _run_seeded_match):
#   - T2 kills the idle Kargar K2 at ~tick 180 (60 HP / 10 dmg per 30 ticks)
#     → FarrDrainDispatcher fires worker_killed_idle → Farr moves.
#   - P1 and T1 (100 HP each, mirrored commands) trade to mutual death at
#     ~tick 300 — the same-tick mutual-kill ordering is itself a determinism
#     surface worth pinning.
#   - K1 completes multiple full gather trips (walk → extract dwell 2 ticks
#     → walk back → throne deposit) → ResourceSystem coin moves repeatedly.
const _N_TICKS: int = 450

const _MATCH_SEED: int = 4242


func after_each() -> void:
	# Belt-and-braces: ensure autoloads are clean even if a test crashes early.
	SimClock.reset()
	GameState.reset()
	PathSchedulerService.reset()


# Helper: create + start_match in one step.
func _make_harness(match_seed: int = 0, scenario: StringName = &"empty") -> Variant:
	var h: Variant = _MH.new()
	h.start_match(match_seed, scenario)
	return h


# ---------------------------------------------------------------------------
# Phase 0 determinism baseline — empty match (kept from the Phase-0 stub)
# ---------------------------------------------------------------------------

## Same seeded empty match run twice must produce identical snapshots.
## Baseline bar: determinism holds when nothing happens except the tick
## pipeline.
func test_empty_match_is_deterministic() -> void:
	var h1: Variant = _make_harness(12345, &"empty")
	h1.advance_ticks(60)  # 2 simulated seconds at 30 Hz
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	var h2: Variant = _make_harness(12345, &"empty")
	h2.advance_ticks(60)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	assert_eq(snap1, snap2,
		"Same-seeded empty matches must produce identical snapshots. "
		+ "A mismatch means non-deterministic state is leaking — "
		+ "check for wall-clock reads (L5), bare RNG (L3), or "
		+ "global autoload state not reset between harness instances.")


## Verify that two sequential harness runs don't bleed state into each other.
## This tests teardown isolation — a subtle form of determinism failure.
func test_sequential_harnesses_are_isolated() -> void:
	var h1: Variant = _make_harness(99, &"empty")
	h1.advance_ticks(30)
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	var h2: Variant = _make_harness(99, &"empty")
	h2.advance_ticks(30)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	assert_eq(snap1, snap2,
		"Sequential harness runs with the same seed must produce identical snapshots. "
		+ "A mismatch means teardown() isn't resetting some global state properly.")


# ---------------------------------------------------------------------------
# TEST-4 — real-gameplay snapshot-hash determinism
# ---------------------------------------------------------------------------

# Run one full seeded mini-match and return its end-state composite.
#
# Scenario (all spawns via MatchHarness v2 — the real scenes, the real
# command-queue API, the real sim_phase tick chain):
#   K1 (Iran kargar @ origin)  — COMMAND_GATHER on a coin mine @ (6,0,0),
#                                deposits at the Iran throne @ (0,0,-4).
#   P1 (Iran piyade @ 20,0,0)  — COMMAND_ATTACK on T1 (mutual melee).
#   T1 (Turan piyade @ 21,0,0) — COMMAND_ATTACK on P1. In range from tick 0
#                                (1.0 apart, attack_range 1.5).
#   K2 (Iran kargar @ 30,0,0)  — idle victim.
#   T2 (Turan piyade @ 31,0,0) — COMMAND_ATTACK on K2 → worker_killed_idle
#                                Farr drain when K2 falls.
#   Khaneh (Iran @ 0,0,10)     — is_complete=true; static building census.
func _run_seeded_match(match_seed: int, n_ticks: int) -> Dictionary:
	var h: Variant = _make_harness(match_seed, &"empty")

	# Test-owned world fixture (resource nodes are not part of the harness
	# spawn API). Freed synchronously per run — Pitfall #17: free(), never
	# queue_free + await (the await leaks _physics_process ticks into
	# SimClock and the zombie node would shadow run 2).
	var world: Node3D = Node3D.new()
	add_child(world)
	var mine: Variant = MineNodeScene.instantiate()
	world.add_child(mine)
	mine.global_position = Vector3(6.0, 0.0, 0.0)
	mine.extract_ticks = 2  # short dwell so multiple trips fit the budget

	var throne: Variant = h.spawn_building(&"throne", Constants.TEAM_IRAN,
		Vector3(0.0, 0.0, -4.0))
	var khaneh: Variant = h.spawn_building(&"khaneh", Constants.TEAM_IRAN,
		Vector3(0.0, 0.0, 10.0))
	khaneh.is_complete = true  # canonical operational-building pattern
	assert_not_null(throne, "throne spawn must succeed (harness v2)")

	var k1: Variant = h.spawn_unit(&"kargar", Constants.TEAM_IRAN, Vector3.ZERO)
	var p1: Variant = h.spawn_unit(&"piyade", Constants.TEAM_IRAN,
		Vector3(20.0, 0.0, 0.0))
	var t1: Variant = h.spawn_unit(&"turan_piyade", Constants.TEAM_TURAN,
		Vector3(21.0, 0.0, 0.0))
	var k2: Variant = h.spawn_unit(&"kargar", Constants.TEAM_IRAN,
		Vector3(30.0, 0.0, 0.0))
	var t2: Variant = h.spawn_unit(&"turan_piyade", Constants.TEAM_TURAN,
		Vector3(31.0, 0.0, 0.0))

	# Attack payloads use the BUG-H8 preferred `target_node` key, NOT
	# `target_unit_id`: Unit and Building ids live in distinct counters that
	# overlap numerically, and id-based resolution can land on a building.
	# (This test's first red run was exactly that — the un-reset Building
	# counter drifted between runs, shifting which ids collided, and the two
	# runs fought different battles. target_node is collision-free.)
	k1.replace_command(Constants.COMMAND_GATHER, {&"target_node": mine})
	p1.replace_command(Constants.COMMAND_ATTACK, {&"target_node": t1})
	t1.replace_command(Constants.COMMAND_ATTACK, {&"target_node": p1})
	t2.replace_command(Constants.COMMAND_ATTACK, {&"target_node": k2})

	h.advance_ticks(n_ticks)

	var composite: Dictionary = _composite_state()

	world.free()
	h.teardown()
	return composite


# Composite end-state per the TEST-4 spec: tick, per-team coin/grain x100,
# farr_x100, sorted unit records (positions as x100 ints + hp_x100),
# building count. Unit records are pipe-joined Strings so the Array sorts
# deterministically and a failure diff is human-readable.
func _composite_state() -> Dictionary:
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	var units: Array[String] = []
	for node: Node in st.get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		var hc: Variant = node.call(&"get_health")
		var pos: Vector3 = node.global_position
		units.append("%s|%d|%d|%d|%d|%d" % [
			String(node.get(&"unit_type")),
			int(node.get(&"team")),
			roundi(pos.x * 100.0),
			roundi(pos.y * 100.0),
			roundi(pos.z * 100.0),
			int(hc.get(&"hp_x100")),
		])
	units.sort()

	var building_count: int = 0
	for node: Node in st.get_nodes_in_group(&"buildings"):
		if is_instance_valid(node):
			building_count += 1

	return {
		"tick": SimClock.tick,
		"coin_iran_x100": ResourceSystem.coin_x100_for(Constants.TEAM_IRAN),
		"grain_iran_x100": ResourceSystem.grain_x100_for(Constants.TEAM_IRAN),
		"coin_turan_x100": ResourceSystem.coin_x100_for(Constants.TEAM_TURAN),
		"grain_turan_x100": ResourceSystem.grain_x100_for(Constants.TEAM_TURAN),
		"farr_x100": FarrSystem.get_farr_x100(),
		"units": units,
		"building_count": building_count,
	}


## TEST-4 core: same seed → two consecutive in-process runs → identical
## composite state hash. JSON-string comparison first (readable diff on
## divergence — the DET-2 diagnostic), hash equality second (the pinned
## "snapshot-hash" contract).
func test_real_gameplay_same_seed_consecutive_runs_identical_state_hash() -> void:
	var state_a: Dictionary = _run_seeded_match(_MATCH_SEED, _N_TICKS)
	var state_b: Dictionary = _run_seeded_match(_MATCH_SEED, _N_TICKS)

	var json_a: String = JSON.stringify(state_a, "  ")
	var json_b: String = JSON.stringify(state_b, "  ")
	assert_eq(json_a, json_b,
		"DET-2: two consecutive in-process same-seed runs diverged. The diff "
		+ "above IS the diagnostic — units-only divergence points at EventBus "
		+ "connection-order or scene-tree iteration order; resource/farr "
		+ "divergence points at an unreset autoload or off-tick mutation.")
	assert_eq(json_a.hash(), json_b.hash(),
		"Composite state hash must match across same-seed runs (Sim Contract §6.2)")


## Vacuous-green guard (§9.M8 spirit): prove the determinism scenario
## actually exercised the systems it claims to cover. If a refactor inerts
## the roster (commands rejected, combat never fires, gather never deposits),
## the hash test above would still pass — two identical no-op runs. This
## sibling pins the real-data movement.
func test_real_gameplay_run_actually_exercises_systems() -> void:
	var state: Dictionary = _run_seeded_match(_MATCH_SEED, _N_TICKS)

	# Gather loop deposited: Iran coin above the 15000 x100 starting value.
	assert_gt(int(state["coin_iran_x100"]), 15000,
		"K1's gather loop must deposit coin above the 150.00 start "
		+ "(got %d x100) — gather chain broke" % int(state["coin_iran_x100"]))

	# Farr drain fired: K2's idle-worker death drains Farr below the 5000
	# x100 starting value (worker_killed_idle, 01_CORE_MECHANICS §4).
	assert_lt(int(state["farr_x100"]), 5000,
		"K2's death must fire worker_killed_idle Farr drain "
		+ "(got %d x100) — FarrDrainDispatcher chain broke" % int(state["farr_x100"]))

	# Combat killed: at least one unit record at hp_x100 == 0 (dying units
	# stay in &"units" until their deferred queue_free flushes — observable
	# end-state by design).
	var saw_dead: bool = false
	for record: String in (state["units"] as Array):
		if record.ends_with("|0"):
			saw_dead = true
			break
	assert_true(saw_dead,
		"At least one unit must reach hp 0 within %d ticks — combat chain broke. "
		% _N_TICKS + "Units: %s" % str(state["units"]))

	# Building census intact: throne + khaneh.
	assert_eq(int(state["building_count"]), 2,
		"Throne + Khaneh must both be alive at end-state")
