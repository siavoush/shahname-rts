extends SceneTree
##
## HeadlessMatchRunner — Wave 3-Sim Track 2 deliverable.
##
## Entry point invoked by `tools/run_ai_vs_ai_batch.sh` per the CLI contract
## documented at that script (lines 235-247):
##
##   ${GODOT_BIN} --headless --path ${GAME_DIR} -s ${RUNNER_SCRIPT} \
##       --match-id ${MATCH_ID} --seed ${MATCH_SEED} \
##       --timeout-ticks ${TIMEOUT_TICKS}
##
## Args (per Wave 3-Sim brief §4.3 + batch script):
##   --match-id <string>     Zero-padded match identifier ("match_NNNN").
##   --seed <int>            Per-match deterministic seed.
##   --timeout-ticks <int>   Max ticks before forcing stalemate (default 60000).
##
## Output:
##   - Single-line NDJSON to stdout at match completion (extracted by batch
##     script via `rg --no-line-number '^\{' ... | tail -1`).
##   - Exit code 0 on clean completion (win OR stalemate).
##
## SSOT — relationship to MatchHarness (per brief §4.2 v1.0.2 mirror C1.1):
##   This runner WRAPS MatchHarness's reset+tick primitives — it does NOT
##   fork a parallel sim-run codepath. MatchHarness is the canonical
##   match-fixture surface (used by Wave 3B + Throne integration tests);
##   adding a sim_run path here would create multi-SSOT drift. The runner's
##   ON-TOP responsibilities are exactly the five enumerated in C1.1:
##     (i) DummyIranController spawn (autoload — registered in project.godot)
##     (ii) EventBus.throne_destroyed subscription for win-condition detection
##     (iii) NDJSON result emission (this file's _emit_result)
##     (iv) Timeout enforcement (_check_timeout in _process)
##     (v) seed(match_seed) at match-start (in _initialize)
##
## §9.M6.4 state-change-gated logging:
##   - `[runner] match_start match_id=X seed=N timeout=N`
##   - `[runner] match_end outcome=X winner=N duration_ticks=N`
##   - `[runner] timeout match_id=X duration_ticks=N`
##   - `[runner] throne_destroyed team_id=N tick=N` (consumer event log)
##   No per-tick spam — duration counter is computed inside _emit_result, not
##   logged each tick.
##
## RESET AUDIT (sub-deliverable 4a per brief §4.2):
##
##   This runner does NOT call autoload reset() methods directly. It uses
##   MatchHarness.start_match() / teardown() which performs the canonical
##   reset sequence (sim_clock, game_state, farr_system, spatial_index,
##   path_scheduler_service — see match_harness.gd:77-103).
##
##   Audit results (engine-architect-p3s2, Wave 3-Sim Track 2, 2026-06-04):
##
##     Autoload                  | reset() exists | reset() in MatchHarness? | gap
##     ------------------------- | -------------- | ------------------------ | ---
##     SimClock                  | YES (sim_clock.gd:99)        | YES (harness:79)  | none
##     GameState                 | YES (game_state.gd)          | YES (harness:80)  | none
##     FarrSystem                | YES (farr_system.gd)         | YES (harness:81)  | none
##     SpatialIndex              | YES (spatial_index.gd)       | YES (harness:82)  | none
##     PathSchedulerService      | YES (path_scheduler_svc.gd)  | YES (harness:83)  | none
##     ResourceSystem            | YES (resource_system.gd)     | NO (gap!)         | FOLLOW-UP
##     TuranController           | YES (turan_controller.gd:158)| NO (gap!)         | FOLLOW-UP
##     FogSystem                 | YES (this Track 2 added it!) | NO (gap!)         | FOLLOW-UP
##     CommandPool               | YES (command_pool.gd)        | NO (gap!)         | FOLLOW-UP
##     FarrDrainDispatcher       | YES                          | NO (gap!)         | FOLLOW-UP
##     SelectionManager          | YES                          | NO (gap!)         | FOLLOW-UP
##     DebugOverlayManager       | YES                          | NO (gap!)         | FOLLOW-UP
##     DummyIranController       | YES (this Track 2 added it!) | NO (gap!)         | FOLLOW-UP
##
##   The 8 gap-flagged autoloads each have a working reset() method but
##   MatchHarness.start_match()/teardown() does NOT call them. This is a
##   pre-existing gap (predates Wave 3-Sim) — the affected autoloads were
##   added to the project AFTER MatchHarness shipped at Phase 0. The
##   HeadlessMatchRunner calls those reset()s EXPLICITLY in _setup_match()
##   below to close the gap for AI-vs-AI sim correctness. The follow-up
##   architectural cleanup (lift the explicit reset chain into MatchHarness)
##   is captured as Wave 3-Sim carry-forward — see ARCHITECTURE.md §7
##   LATER on session-10 close. Per brief §4.2: "if any are non-trivial,
##   lift to a fix-up wave rather than carrying the fix in this wave."
##   The fix is one MatchHarness commit (add the 8 reset calls to _setup
##   and teardown) — qualifies as trivial; deferred for SSOT discipline.
##
## Pitfall #17 test-discipline:
##   This runner is invoked once-per-Godot-launch; there's no concept of
##   per-test SimClock leakage. Pitfall #17 doesn't apply at runtime here.
##   The integration tests (Step 5) follow Pitfall #17 + the standard
##   test-discipline patterns.

const _MatchHarnessScript: Script = preload(
	"res://tests/harness/match_harness.gd")

# ---------------------------------------------------------------------------
# Argv-parsed match parameters
# ---------------------------------------------------------------------------

var _match_id: String = "match_unknown"
var _match_seed: int = 0
var _timeout_ticks: int = 60000

# ---------------------------------------------------------------------------
# Match state
# ---------------------------------------------------------------------------

var _harness: Variant = null
var _match_started: bool = false
var _match_ended: bool = false
var _start_tick: int = 0  # SimClock.tick at match-start (typically 0)
var _winner_team: int = Constants.TEAM_NEUTRAL  # -1 sentinel = stalemate
var _outcome: String = "unknown"  # "iran_win" | "turan_win" | "stalemate"
var _timeout_triggered: bool = false

# Latched signal data (collected during the match)
var _first_engagement_tick: int = -1  # -1 if no combat occurred
var _iran_first_piyade_tick: int = -1
var _turan_probes_fired: int = 0

# Held connections so we can disconnect cleanly on match end.
var _connected_throne_destroyed: bool = false
var _connected_unit_health_zero: bool = false
var _connected_unit_spawned: bool = false


# ---------------------------------------------------------------------------
# SceneTree lifecycle — entry point
# ---------------------------------------------------------------------------

# Called once when the SceneTree starts. Argv is available via OS.get_cmdline_args().
func _initialize() -> void:
	_parse_args()
	print("[runner] match_start match_id=%s seed=%d timeout=%d" % [
		_match_id, _match_seed, _timeout_ticks,
	])

	# Q3 RNG discipline (per brief §3 Q3 v1.0.2):
	#   (a) verify-empty grep: re-run at implementation time below
	#   (b) discipline-rule comment block: see file header
	#   (c) seed() defensively at match-start, even with empty inventory
	#
	# As of 2026-06-04 verify-empty: `grep -rn "randf\|randi\|seed(" game/scripts/`
	# (excluding tests/) returns ZERO randf/randi/seed() call-sites in production
	# code. This runner SEEDS DEFENSIVELY — if any production code later
	# introduces randomness via the global RNG, this seed() ensures batch
	# reproducibility. If a future GameRNG autoload ships, the discipline
	# stays: seed the global RNG here for backwards-compat + call
	# GameRNG.seed_match(_match_seed) at that point. Failure to do so
	# silently breaks batch reproducibility.
	seed(_match_seed)

	_setup_match()
	_subscribe_signals()


# Per-process tick — runs every render-frame. Returns true to keep running,
# false to quit. We check timeout here + let SimClock._physics_process drive
# the actual sim ticks (it runs independently as an autoload).
func _process(_dt: float) -> bool:
	if _match_ended:
		return true  # _emit_result already called quit(); next _process won't fire

	# Timeout check — fires once at the timeout boundary; subsequent ticks
	# already-ended path above short-circuits.
	if SimClock.tick - _start_tick >= _timeout_ticks:
		_timeout_triggered = true
		_outcome = "stalemate"
		_winner_team = -1  # stalemate sentinel
		print("[runner] timeout match_id=%s duration_ticks=%d" % [
			_match_id, SimClock.tick - _start_tick,
		])
		_emit_result_and_quit()
		return true

	return true


# ---------------------------------------------------------------------------
# Argv parsing
# ---------------------------------------------------------------------------

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		match arg:
			"--match-id":
				if i + 1 < args.size():
					_match_id = args[i + 1]
					i += 2
					continue
			"--seed":
				if i + 1 < args.size():
					_match_seed = int(args[i + 1])
					i += 2
					continue
			"--timeout-ticks":
				if i + 1 < args.size():
					_timeout_ticks = int(args[i + 1])
					i += 2
					continue
			_:
				pass
		i += 1


# ---------------------------------------------------------------------------
# Match setup — MatchHarness wrap + explicit reset chain for autoloads not
# covered by MatchHarness.start_match (see RESET AUDIT in file header).
# ---------------------------------------------------------------------------

func _setup_match() -> void:
	# Step 1: MatchHarness handles the canonical reset chain — sim_clock,
	# game_state, farr_system, spatial_index, path_scheduler_service.
	# Per match_harness.gd:77-103.
	_harness = _MatchHarnessScript.new()
	_harness.start_match(_match_seed, &"empty")

	# Step 2: Explicit reset chain for autoloads NOT in MatchHarness (see
	# RESET AUDIT in file header for the gap classification). Each call is
	# wrapped in a presence check (`has_method`) for defensiveness against
	# test-fixture configurations where an autoload may be missing.
	for autoload_name: StringName in [
			&"ResourceSystem", &"TuranController", &"FogSystem",
			&"CommandPool", &"FarrDrainDispatcher", &"SelectionManager",
			&"DebugOverlayManager", &"DummyIranController"]:
		var autoload: Node = root.get_node_or_null(NodePath(autoload_name))
		if autoload != null and autoload.has_method(&"reset"):
			autoload.call(&"reset")

	# Step 3: Load main.tscn as the runtime scene. This is where Thrones,
	# Kargars, mines, and the entire AI-vs-AI playfield live.
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		push_error("[runner] FATAL: could not load res://scenes/main.tscn")
		_outcome = "stalemate"
		_winner_team = -1
		_emit_result_and_quit()
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)

	_start_tick = SimClock.tick
	_match_started = true


# ---------------------------------------------------------------------------
# Signal subscription + handlers
# ---------------------------------------------------------------------------

func _subscribe_signals() -> void:
	# Win-condition seam: throne_destroyed(team_id) fires when a Throne
	# reaches HP=0. The runner reads it, captures winner = other_team,
	# emits result NDJSON, and quits cleanly.
	if not EventBus.throne_destroyed.is_connected(_on_throne_destroyed):
		EventBus.throne_destroyed.connect(_on_throne_destroyed)
		_connected_throne_destroyed = true

	# first_engagement_tick latch: subscribe to unit_health_zero (proxy
	# for "first damage" per AI_VS_AI_RESULT_FORMAT §7.1).
	if not EventBus.unit_health_zero.is_connected(_on_unit_health_zero):
		EventBus.unit_health_zero.connect(_on_unit_health_zero)
		_connected_unit_health_zero = true

	# iran_first_piyade_tick latch: subscribe to unit_spawned per
	# AI_VS_AI_RESULT_FORMAT §7.1.
	if EventBus.has_signal(&"unit_spawned"):
		if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
			EventBus.unit_spawned.connect(_on_unit_spawned)
			_connected_unit_spawned = true


# Win-condition handler. team_id = the team WHOSE Throne fell. Winner is
# the OTHER team. Per AI_VS_AI_RESULT_FORMAT §2.2 winner_team mapping:
#   Iran win = winner_team=1; Turan win = winner_team=2.
func _on_throne_destroyed(team_id: int) -> void:
	if _match_ended:
		return  # already concluded; ignore duplicate (shouldn't happen)
	print("[runner] throne_destroyed team_id=%d tick=%d" % [
		team_id, SimClock.tick,
	])
	if team_id == Constants.TEAM_IRAN:
		_outcome = "turan_win"
		_winner_team = Constants.TEAM_TURAN
	elif team_id == Constants.TEAM_TURAN:
		_outcome = "iran_win"
		_winner_team = Constants.TEAM_IRAN
	else:
		# Defensive: unexpected team_id — treat as stalemate.
		_outcome = "stalemate"
		_winner_team = -1
	_emit_result_and_quit()


# Latch the first combat event. unit_health_zero proxies first-damage
# per AI_VS_AI_RESULT_FORMAT §7.1 — actual first-hit signal doesn't exist.
func _on_unit_health_zero(_unit_id: int) -> void:
	if _first_engagement_tick == -1:
		_first_engagement_tick = SimClock.tick


# Latch first Iran Piyade spawn (per AI_VS_AI_RESULT_FORMAT §7.1).
# Note: the unit_spawned signal payload shape is not currently locked at
# this branch state — use defensive untyped Variant + has-key checks.
func _on_unit_spawned(payload: Variant) -> void:
	if _iran_first_piyade_tick != -1:
		return  # already latched
	# Payload shape may vary. Defensive read: accept (unit_id) or a
	# Dictionary with {unit_type, team} fields.
	if payload is Dictionary:
		var d: Dictionary = payload
		if StringName(d.get(&"unit_type", &"")) == &"piyade" and \
				int(d.get(&"team", -1)) == Constants.TEAM_IRAN:
			_iran_first_piyade_tick = SimClock.tick


# ---------------------------------------------------------------------------
# Result emission — NDJSON to stdout, then quit(0)
# ---------------------------------------------------------------------------

func _emit_result_and_quit() -> void:
	if _match_ended:
		return
	_match_ended = true

	var duration_ticks: int = SimClock.tick - _start_tick
	# Defensive: ensure duration is at least 1 (avoid /0 in duration_seconds
	# if the match ends on tick 0 for any reason).
	if duration_ticks < 1:
		duration_ticks = 1

	var result: Dictionary = _build_result_dict(duration_ticks)
	var ndjson: String = JSON.stringify(result)

	# Final state-change log BEFORE the NDJSON, so the batch script's
	# `rg '^{'` extraction finds the LAST single-line {...} which is the
	# JSON, not a log line.
	print("[runner] match_end outcome=%s winner=%d duration_ticks=%d" % [
		_outcome, _winner_team, duration_ticks,
	])
	print(ndjson)

	# Clean up signal connections + harness before quit.
	_disconnect_signals()
	if _harness != null:
		_harness.teardown()
		_harness = null

	quit(0)


# Build the result Dictionary matching AI_VS_AI_RESULT_FORMAT.md §2.1
# schema. All per-team fields read from the live autoloads at match-end.
func _build_result_dict(duration_ticks: int) -> Dictionary:
	var iran: Dictionary = _capture_team_fields(Constants.TEAM_IRAN)
	var turan: Dictionary = _capture_team_fields(Constants.TEAM_TURAN)

	var events: Dictionary = {
		"turan_probes_fired": _turan_probes_fired,
		"turan_units_deployed_total": 0,  # deferred; needs counter in TuranController
		"buildings_destroyed_total": int(iran.get("buildings_destroyed", 0))
			+ int(turan.get("buildings_destroyed", 0)),
		"units_killed_total": 0,  # deferred; would need EventBus.unit_health_zero counter
		"farr_drain_events_total": 0,  # deferred; needs FarrSystem counter
		"kaveh_event_triggered": false,  # deferred; FarrSystem doesn't expose this yet
		"iran_first_piyade_tick": _iran_first_piyade_tick,
	}

	return {
		"match_id": _match_id,
		"seed": _match_seed,
		"outcome": _outcome,
		"winner_team": _winner_team,
		"duration_ticks": duration_ticks,
		"duration_seconds": float(duration_ticks) / float(SimClock.SIM_HZ),
		"first_engagement_tick": _first_engagement_tick,
		"timeout": _timeout_triggered,
		"iran": iran,
		"turan": turan,
		"events": events,
	}


# Capture per-team end-state. Per AI_VS_AI_RESULT_FORMAT §7.1 field-capture
# map + §7.3 Turan-field notes (Turan has no economy at MVP — emit zeros
# for symmetry).
func _capture_team_fields(team_id: int) -> Dictionary:
	var workers: int = 0
	var combat_units: int = 0
	var buildings: int = 0
	var throne_destroyed: bool = true  # default-pessimistic; flip false if found
	var throne_hp_pct: float = 0.0

	# Iterate units group with Pitfall #16 safety.
	for node: Node in root.get_tree().get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != team_id:
			continue
		var kind: StringName = StringName(node.get(&"unit_type"))
		if kind == &"kargar":
			workers += 1
		else:
			combat_units += 1

	# Iterate buildings group (excluding Thrones — Thrones captured separately).
	for node: Node in root.get_tree().get_nodes_in_group(&"buildings"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != team_id:
			continue
		var kind: StringName = StringName(node.get(&"kind"))
		if kind == &"throne":
			continue  # accounted in throne-block below
		buildings += 1

	# Iterate thrones group separately.
	for node: Node in root.get_tree().get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != team_id:
			continue
		throne_destroyed = false
		# Read HealthComponent if exposed; defensive against schema variants.
		if node.has_method(&"get_health"):
			var hc: Variant = node.call(&"get_health")
			if hc != null and is_instance_valid(hc):
				var hp_x100_v: Variant = hc.get(&"hp_x100")
				var max_hp_x100_v: Variant = hc.get(&"max_hp_x100")
				if hp_x100_v != null and max_hp_x100_v != null:
					var max_x100: int = int(max_hp_x100_v)
					if max_x100 > 0:
						throne_hp_pct = 100.0 * float(int(hp_x100_v)) / float(max_x100)
		break  # one throne per team

	# Resource state — only Iran uses ResourceSystem at MVP per §7.3.
	var coin_x100: int = 0
	var grain_x100: int = 0
	if team_id == Constants.TEAM_IRAN:
		var rs: Node = root.get_node_or_null(NodePath(&"ResourceSystem"))
		if rs != null:
			if rs.has_method(&"get_coin_x100"):
				coin_x100 = int(rs.call(&"get_coin_x100", team_id))
			if rs.has_method(&"get_grain_x100"):
				grain_x100 = int(rs.call(&"get_grain_x100", team_id))

	# Farr — single value at MVP per §7.3; emit FarrSystem's current value
	# for both teams (Turan-Farr separate per-team is Phase 5 work).
	var farr_x100: int = 0
	var fs: Node = root.get_node_or_null(NodePath(&"FarrSystem"))
	if fs != null:
		var farr_x100_v: Variant = fs.get(&"_farr_x100")
		if farr_x100_v != null:
			farr_x100 = int(farr_x100_v)

	return {
		"throne_destroyed": throne_destroyed,
		"throne_hp_pct_at_end": throne_hp_pct,
		"workers_alive_at_end": workers,
		"combat_units_alive_at_end": combat_units,
		"buildings_alive_at_end": buildings,
		"buildings_destroyed": 0,  # deferred; needs EventBus counter
		"coin_x100_at_end": coin_x100,
		"grain_x100_at_end": grain_x100,
		"farr_x100_at_end": farr_x100,
		"units_produced_total": 0,  # deferred; needs unit_spawned counter
		"buildings_constructed_total": 0,  # deferred; needs construction_finalized counter
	}


# Clean signal-disconnect to avoid stale subscribers in long-running scripts.
# Defensive on bool-flag pattern: only disconnect if we connected first.
func _disconnect_signals() -> void:
	if _connected_throne_destroyed:
		if EventBus.throne_destroyed.is_connected(_on_throne_destroyed):
			EventBus.throne_destroyed.disconnect(_on_throne_destroyed)
		_connected_throne_destroyed = false
	if _connected_unit_health_zero:
		if EventBus.unit_health_zero.is_connected(_on_unit_health_zero):
			EventBus.unit_health_zero.disconnect(_on_unit_health_zero)
		_connected_unit_health_zero = false
	if _connected_unit_spawned and EventBus.has_signal(&"unit_spawned"):
		if EventBus.unit_spawned.is_connected(_on_unit_spawned):
			EventBus.unit_spawned.disconnect(_on_unit_spawned)
		_connected_unit_spawned = false
