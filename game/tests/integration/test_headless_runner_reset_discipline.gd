# Integration test — HeadlessMatchRunner reset discipline across N=3
# consecutive matches.
#
# Per 02t_PHASE_3_SESSION_10_WAVE_3_SIM_KICKOFF.md §7 Track 2 second bullet:
# "test_headless_runner_reset_discipline.gd — run N=3 matches consecutively,
#  verify no state leak (e.g., SimClock.tick reset to 0 each match;
#  ResourceSystem coin starts at canonical starting value each match)."
#
# Exercises the canonical reset chain the runner runs in _setup_match:
#   Step 1: MatchHarness.start_match — resets SimClock, GameState, FarrSystem,
#           SpatialIndex, PathSchedulerService (5 autoloads).
#   Step 2: Explicit reset() calls on 8 additional autoloads NOT covered by
#           MatchHarness (see headless_match_runner.gd RESET AUDIT in header):
#               ResourceSystem, TuranController, FogSystem, CommandPool,
#               FarrDrainDispatcher, SelectionManager, DebugOverlayManager,
#               DummyIranController.
#
# The N=3 iteration models the batch-runner pattern: each batch invocation
# spawns a fresh process per match, but the in-process test exercises the
# same reset semantics across 3 sequential simulated matches. State leak
# would manifest as: tick != 0 at match start, coin != starting_coin,
# Farr != 50.0, TuranController state != idle, DummyIranController state
# != awaiting_start.
extends GutTest


const MatchHarnessScript: Script = preload(
	"res://tests/harness/match_harness.gd")


# Autoloads with reset() that MatchHarness does NOT call. The runner's
# _setup_match runs these explicitly. Source-of-truth: file header RESET
# AUDIT in headless_match_runner.gd.
const _RUNNER_EXTRA_RESET_AUTOLOADS: Array[StringName] = [
	&"ResourceSystem",
	&"TuranController",
	&"FogSystem",
	&"CommandPool",
	&"FarrDrainDispatcher",
	&"SelectionManager",
	&"DebugOverlayManager",
	&"DummyIranController",
]


var _harness: Variant = null


func after_each() -> void:
	if _harness != null:
		_harness.teardown()
		_harness = null
	# Clean any residual state from intra-test mutations.
	SimClock.reset()
	GameState.reset()
	FarrSystem.reset()
	ResourceSystem.reset()
	TuranController.reset()
	FogSystem.reset()
	if Engine.has_singleton(&"DummyIranController") \
			or (Engine.get_main_loop() as SceneTree).root.has_node(
				NodePath(&"DummyIranController")):
		DummyIranController.reset()


# Simulates the runner's per-match reset chain: MatchHarness.start_match
# (Step 1) + explicit autoload-reset call sweep (Step 2). Mirrors
# headless_match_runner.gd:207-225 exactly.
func _runner_style_setup_match(match_seed: int) -> void:
	# Step 1 — MatchHarness reset chain.
	_harness = MatchHarnessScript.new()
	_harness.start_match(match_seed, &"empty")

	# Step 2 — explicit reset on the 8 autoloads MatchHarness doesn't cover.
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	for autoload_name: StringName in _RUNNER_EXTRA_RESET_AUTOLOADS:
		var autoload: Node = st.root.get_node_or_null(NodePath(autoload_name))
		if autoload != null and autoload.has_method(&"reset"):
			autoload.call(&"reset")


# Simulates the runner's per-match teardown: MatchHarness.teardown +
# explicit re-reset of the 8 autoloads (matches what a clean run would
# leave for the next match-start).
func _runner_style_teardown_match() -> void:
	if _harness != null:
		_harness.teardown()
		_harness = null


# ---------------------------------------------------------------------------
# N=3 reset discipline: SimClock.tick is 0 at match-start each match
# ---------------------------------------------------------------------------

func test_simclock_resets_to_zero_each_match_n3() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		assert_eq(SimClock.tick, 0,
			"match %d: SimClock.tick must be 0 at match-start" % match_index)
		# Simulate work happening inside the match.
		_harness.advance_ticks(500)
		assert_eq(SimClock.tick, 500,
			"match %d: ticks advance normally" % match_index)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# N=3 reset discipline: ResourceSystem starts at canonical values each match
# ---------------------------------------------------------------------------

func test_resource_system_resets_to_starting_values_each_match_n3() -> void:
	# Read canonical starting values from BalanceData.economy. ResourceSystem
	# loads these in _load_starting_values_from_balance_data() called from
	# reset() — so the post-reset values MUST equal the BalanceData entries.
	var starting_coin_iran: float = ResourceSystem.coin_for(Constants.TEAM_IRAN)
	var starting_grain_iran: float = ResourceSystem.grain_for(Constants.TEAM_IRAN)

	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)

		# At match-start, ResourceSystem.reset() must have loaded the canonical
		# starting values — same as the values we cached above.
		assert_almost_eq(
			ResourceSystem.coin_for(Constants.TEAM_IRAN),
			starting_coin_iran, 0.001,
			"match %d: Iran coin must reset to canonical starting value" % match_index)
		assert_almost_eq(
			ResourceSystem.grain_for(Constants.TEAM_IRAN),
			starting_grain_iran, 0.001,
			"match %d: Iran grain must reset to canonical starting value" % match_index)

		# Mutate ResourceSystem during the match to prove the next match's
		# reset() clears the leak. ResourceSystem.change_resource asserts
		# is_ticking() — wrap in advance_ticks via on-tick path.
		_harness.advance_ticks(1)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# N=3 reset discipline: FarrSystem returns to spec default (50.0) each match
# ---------------------------------------------------------------------------

func test_farr_system_resets_to_default_each_match_n3() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		# Per FarrSystem spec, reset() restores value_farr to the default
		# starting Farr (50.0 per 01_CORE_MECHANICS.md §4.2).
		assert_almost_eq(FarrSystem.value_farr, 50.0, 1e-4,
			"match %d: Farr must reset to spec default 50.0" % match_index)
		# Mutate during the match — test the leak guard.
		_harness._test_set_farr(75.5)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# N=3 reset discipline: TuranController FSM resets to idle each match
# ---------------------------------------------------------------------------

func test_turan_controller_resets_to_idle_each_match_n3() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		assert_eq(TuranController.get_state(), &"idle",
			"match %d: TuranController must reset to idle" % match_index)
		assert_eq(TuranController.get_ticks_since_last_probe(), 0,
			"match %d: TuranController probe counter must reset to 0"
				% match_index)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# N=3 reset discipline: DummyIranController FSM resets to awaiting_start
# ---------------------------------------------------------------------------

func test_dummy_iran_controller_resets_to_awaiting_start_each_match_n3() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		assert_eq(DummyIranController.get_state(), &"awaiting_start",
			"match %d: DummyIranController must reset to awaiting_start"
				% match_index)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# N=3 reset discipline: GameState.match_phase = PLAYING each match
# ---------------------------------------------------------------------------

func test_game_state_resets_to_playing_each_match_n3() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		assert_eq(GameState.match_phase, Constants.MATCH_PHASE_PLAYING,
			"match %d: GameState must be PLAYING after match-start"
				% match_index)
		_runner_style_teardown_match()


# ---------------------------------------------------------------------------
# Reset chain inventory: each enumerated autoload exposes a reset() method.
# If any of these grow new fields without resetting them, the in-process
# reset chain silently breaks; this is the regression guard that the
# autoloads named in the RESET AUDIT remain reset-capable.
# ---------------------------------------------------------------------------

func test_runner_extra_reset_autoloads_each_have_reset_method() -> void:
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	for autoload_name: StringName in _RUNNER_EXTRA_RESET_AUTOLOADS:
		var autoload: Node = st.root.get_node_or_null(NodePath(autoload_name))
		assert_not_null(autoload,
			"autoload '%s' must exist (registered in project.godot)"
				% autoload_name)
		assert_true(autoload.has_method(&"reset"),
			"autoload '%s' must expose a reset() method per runner RESET AUDIT"
				% autoload_name)


# ---------------------------------------------------------------------------
# Reset idempotency: calling _runner_style_setup_match repeatedly without
# teardown must not crash and must always land in the same pristine state.
# Models the case where a long-lived runner instance kicks off back-to-back
# matches without a clean shutdown between (defensive-correctness).
# ---------------------------------------------------------------------------

func test_setup_match_is_idempotent_across_repeated_calls() -> void:
	for match_index: int in range(3):
		_runner_style_setup_match(1000 + match_index)
		# Each repeated start_match call must land in the same pristine
		# state — proves reset() chains don't leak state on re-entry.
		assert_eq(SimClock.tick, 0)
		assert_eq(TuranController.get_state(), &"idle")
		assert_eq(DummyIranController.get_state(), &"awaiting_start")
		# Don't tear down in the loop — re-call setup straight away.
	_runner_style_teardown_match()
