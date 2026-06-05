extends Node
##
## HeadlessMatchRunner — Wave 3-Sim Track 2 deliverable.
##
## Boot model (post-fix-up, see Wave 3-Sim BUG):
##   The runner is NOT a `-s` SceneTree entry-point — that boot mode does
##   NOT register project autoloads, which broke every `SimClock` /
##   `EventBus` / `Constants` / `BalanceData` identifier at compile time.
##   Instead: `tools/run_ai_vs_ai_batch.sh` launches `main.tscn` normally
##   (autoloads boot first per project.godot's [autoload] block), and
##   `main.gd._ready()` detects `--headless-batch` in `OS.get_cmdline_args()`
##   and instantiates this runner as a Node child of itself.
##
## Entry point invoked by `tools/run_ai_vs_ai_batch.sh`:
##
##   ${GODOT_BIN} --headless --path ${GAME_DIR} -- \
##       --headless-batch --match-id ${MATCH_ID} --seed ${MATCH_SEED} \
##       --timeout-ticks ${TIMEOUT_TICKS}
##
## Args (per Wave 3-Sim brief §4.3):
##   --headless-batch        Sentinel that tells main.gd to spawn the runner.
##   --match-id <string>     Zero-padded match identifier ("match_NNNN").
##   --seed <int>            Per-match deterministic seed.
##   --timeout-ticks <int>   Max ticks before forcing stalemate (default 60000).
##
## Output:
##   - Single-line NDJSON to stdout at match completion (extracted by batch
##     script via `rg --no-line-number '^\{' ... | tail -1`).
##   - Exit code 0 on clean completion (win OR stalemate) via
##     `get_tree().quit(0)`.
##
## SSOT — relationship to MatchHarness (per brief §4.2 v1.0.2 mirror C1.1):
##   This runner is NOT a fork of MatchHarness — it operates on the LIVE
##   main.tscn scene flow which boots all autoloads at start. The runner's
##   responsibilities are:
##     (i) EventBus.throne_destroyed subscription for win-condition detection
##     (ii) NDJSON result emission (_emit_result_and_quit)
##     (iii) Timeout enforcement (_process check against SimClock.tick)
##     (iv) seed(match_seed) at match-start (in _ready)
##
##   Per-match RESET is handled implicitly by the process model: each batch
##   invocation is a fresh Godot process, so autoloads boot pristine.
##   No cross-match leak is possible across the process boundary.
##
## §9.M6.4 state-change-gated logging:
##   - `[runner] match_start match_id=X seed=N timeout=N`
##   - `[runner] match_end outcome=X winner=N duration_ticks=N`
##   - `[runner] timeout match_id=X duration_ticks=N`
##   - `[runner] throne_destroyed team_id=N tick=N` (consumer event log)
##   No per-tick spam — duration counter is computed inside _emit_result, not
##   logged each tick.
##
## §9.D9 Q3 RNG discipline (per brief §3 Q3 v1.0.2):
##   Verify-empty grep at 2026-06-04 + 2026-06-05 implementation passes
##   confirmed ZERO `randf`/`randi`/`seed()` call-sites in production
##   `game/scripts/` (only a comment hit in `build_menu.gd`). This runner
##   calls `seed(match_seed)` defensively at match-start. If future
##   production code introduces randomness via the global RNG, this seed()
##   ensures batch reproducibility. If a future GameRNG autoload ships,
##   the discipline stays: seed the global RNG here for backwards-compat
##   + add GameRNG.seed_match(_match_seed) at that point. Failure to do
##   so silently breaks batch reproducibility.

# ---------------------------------------------------------------------------
# Argv-parsed match parameters
# ---------------------------------------------------------------------------

var _match_id: String = "match_unknown"
var _match_seed: int = 0
var _timeout_ticks: int = 60000

# ---------------------------------------------------------------------------
# Match state
# ---------------------------------------------------------------------------

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

# Test-only escape: when true, _emit_result_and_quit() short-circuits to
# field-flips only (no JSON emit, no _build_result_dict call, no quit()).
# Allows integration tests (Step 5: test_headless_runner_*.gd) to drive
# the runner's signal handlers + timeout-arithmetic in-process without
# the runner trying to call get_tree().quit() (which would terminate the
# GUT runner) or _capture_team_fields (which would scan the test-fixture
# tree). Live runs leave this false (the runtime never sets it).
var _test_skip_emit: bool = false


# ---------------------------------------------------------------------------
# Node lifecycle — entry point
# ---------------------------------------------------------------------------

# Called by Godot once when the runner is added to the SceneTree by
# main.gd._ready (under --headless-batch). At this point all autoloads
# have been registered + main.tscn's _spawn_starting_* methods have run
# (or are running this same frame).
func _ready() -> void:
	_parse_args()
	print("[runner] match_start match_id=%s seed=%d timeout=%d" % [
		_match_id, _match_seed, _timeout_ticks,
	])

	# §9.D9 Q3 RNG discipline — seed defensively (see file header).
	seed(_match_seed)

	_start_tick = SimClock.tick
	_subscribe_signals()


# Per-frame tick. Checks timeout against SimClock.tick. We do NOT drive
# sim-ticks here — SimClock._physics_process is the canonical driver
# (Sim Contract §6.1) and runs as a co-resident autoload.
func _process(_dt: float) -> void:
	if _match_ended:
		return

	# Timeout boundary check.
	if SimClock.tick - _start_tick >= _timeout_ticks:
		_timeout_triggered = true
		_outcome = "stalemate"
		_winner_team = -1  # stalemate sentinel
		print("[runner] timeout match_id=%s duration_ticks=%d" % [
			_match_id, SimClock.tick - _start_tick,
		])
		_emit_result_and_quit()


# ---------------------------------------------------------------------------
# Argv parsing
# ---------------------------------------------------------------------------

func _parse_args() -> void:
	# Args land in OS.get_cmdline_user_args() (everything after the `--`
	# separator on the godot CLI). Per main.gd's flag-detect, --headless-batch
	# is in the same set; consistency is the discipline here.
	var args: PackedStringArray = OS.get_cmdline_user_args()
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
# Result emission — NDJSON to stdout, then get_tree().quit(0)
# ---------------------------------------------------------------------------

func _emit_result_and_quit() -> void:
	if _match_ended:
		return
	_match_ended = true

	# Test escape (Step 5 integration tests): skip the parts that touch the
	# scene tree (group queries via _build_result_dict + get_tree().quit()).
	# Field-flips already happened in the caller.
	if _test_skip_emit:
		return

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

	_disconnect_signals()
	get_tree().quit(0)


# Build the result Dictionary matching AI_VS_AI_RESULT_FORMAT.md §2.1
# schema. All per-team fields read from the live autoloads at match-end.
func _build_result_dict(duration_ticks: int) -> Dictionary:
	var iran: Dictionary = _capture_team_fields(Constants.TEAM_IRAN)
	var turan: Dictionary = _capture_team_fields(Constants.TEAM_TURAN)
	return _assemble_result_dict(duration_ticks, iran, turan)


# Assemble the top-level result dict from already-built team dicts. Split out
# from _build_result_dict so the Step 5 integration tests can verify the
# canonical AI_VS_AI_RESULT_FORMAT.md §2.1 schema shape without depending on
# a running SceneTree (which _capture_team_fields requires for group queries).
func _assemble_result_dict(
		duration_ticks: int,
		iran: Dictionary,
		turan: Dictionary) -> Dictionary:
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
#
# Group inventory: only Building.gd joins &"buildings" + Throne.gd joins
# &"thrones" (verified at runner fix-up time). Unit.gd does NOT join any
# group, so unit-count capture uses scene-tree recursion + duck-typing on
# `unit_type` field.
func _capture_team_fields(team_id: int) -> Dictionary:
	var workers: int = 0
	var combat_units: int = 0
	var buildings: int = 0
	var throne_destroyed: bool = true  # default-pessimistic; flip false if found
	var throne_hp_pct: float = 0.0

	var st: SceneTree = get_tree()

	# Unit recursion: scene-tree walk filtered by `unit_type` field. The
	# field is declared on Unit (game/scripts/units/unit.gd:111), so any
	# concrete Unit subclass exposes it. Pitfall #16 — is_instance_valid
	# guard on every iteration.
	var unit_stack: Array[Node] = [st.root]
	while not unit_stack.is_empty():
		var node: Node = unit_stack.pop_back()
		if not is_instance_valid(node):
			continue
		for child: Node in node.get_children():
			unit_stack.push_back(child)
		# Duck-type: a Unit instance exposes a non-empty unit_type StringName.
		var ut_v: Variant = node.get(&"unit_type")
		if ut_v == null:
			continue
		var kind: StringName = StringName(ut_v)
		if kind == &"":
			continue
		# Filter by team.
		var team_v: Variant = node.get(&"team")
		if team_v == null or int(team_v) != team_id:
			continue
		if kind == &"kargar":
			workers += 1
		else:
			combat_units += 1

	# Iterate buildings group (excluding Thrones — Thrones captured separately).
	for node: Node in st.get_nodes_in_group(&"buildings"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != team_id:
			continue
		var kind: StringName = StringName(node.get(&"kind"))
		if kind == &"throne":
			continue  # accounted in throne-block below
		buildings += 1

	# Iterate thrones group separately.
	for node: Node in st.get_nodes_in_group(&"thrones"):
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
	# ResourceSystem exposes coin_for/grain_for returning float; the
	# RESULT_FORMAT schema field is x100 fixed-point, so multiply on read.
	var coin_x100: int = 0
	var grain_x100: int = 0
	if team_id == Constants.TEAM_IRAN:
		coin_x100 = roundi(ResourceSystem.coin_for(team_id) * 100.0)
		grain_x100 = roundi(ResourceSystem.grain_for(team_id) * 100.0)

	# Farr — single value at MVP per §7.3; emit FarrSystem's current value
	# for both teams (Turan-Farr separate per-team is Phase 5 work).
	var farr_x100: int = 0
	var farr_x100_v: Variant = FarrSystem.get(&"_farr_x100")
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
