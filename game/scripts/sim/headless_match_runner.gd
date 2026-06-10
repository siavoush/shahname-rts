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
##     (iii) Timeout enforcement (tick-driven sim_phase cleanup check — DET-3:
##           the original _process check was frame-dependent, so stalemate
##           records were not run-reproducible; moved to the same tick-driven
##           path as the grace check, result-format v1.1.0)
##     (iv) seed(match_seed) at match-start (in _ready)
##     (v) Event-counter aggregation (unit_died / building_destroyed /
##         farr_changed / unit_spawned subscriptions; result-format v1.1.0)
##
## Throne-destruction GRACE WINDOW (result-format v1.1.0, Track B2):
##   On the FIRST throne_destroyed the runner latches winner + outcome +
##   duration_ticks (the throne-fall tick — pacing-signal purity per
##   AI_VS_AI_RESULT_FORMAT.md §2.2 v1.1.0) and arms a deterministic grace:
##   grace_end_tick = SimClock.tick + Constants.SIM_THRONE_GRACE_TICKS.
##   All subscriptions stay live through the grace so same-tick and trailing
##   events (death cascades, drain emits) are still counted. The NDJSON is
##   emitted + the process quits from the sim_phase &"cleanup" handler on the
##   first tick where SimClock.tick >= grace_end_tick. This resolves the
##   §9.B5 probe (test_headless_runner_throne_destruction_same_tick_ordering)
##   whose pinned conclusion was "grace becomes empirically motivated when
##   the deferred counters get wired" — they are wired in this same change.
##
##   Per-match RESET is handled implicitly by the process model: each batch
##   invocation is a fresh Godot process, so autoloads boot pristine.
##   No cross-match leak is possible across the process boundary.
##
## §9.M6.4 state-change-gated logging:
##   - `[runner] match_start match_id=X seed=N timeout=N`
##   - `[runner] match_end outcome=X winner=N duration_ticks=N kills=N ...`
##   - `[runner] timeout match_id=X duration_ticks=N`
##   - `[runner] throne_destroyed team_id=N tick=N` (consumer event log)
##   - `[runner] grace_started winner=N grace_end_tick=N tick=N` (once, at
##     first throne fall)
##   - `[runner] grace_elapsed tick=N` (once, at NDJSON emit)
##   - `[runner] throne_destroyed_during_grace team_id=N tick=N` (rare —
##     second throne falls inside the grace; winner already latched)
##   No per-tick spam — the sim_phase cleanup handler checks boundaries every
##   tick but logs only on the state CHANGES above. Counter increments are
##   not logged here (the producing systems already log each death /
##   destruction / drain); the final totals surface in the match_end line.
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

# Throne-destruction grace window (result-format v1.1.0). Armed by the FIRST
# throne_destroyed; the sim_phase cleanup handler emits + quits when
# SimClock.tick >= _grace_end_tick. Winner/outcome are latched at arm time —
# a second throne falling inside the grace does NOT flip the result.
var _grace_active: bool = false
var _grace_end_tick: int = 0

# Latched duration for the NDJSON `duration_ticks` field. For win outcomes
# this is the THRONE-FALL tick minus _start_tick (grace ticks excluded —
# pacing-signal purity per AI_VS_AI_RESULT_FORMAT.md §2.2 v1.1.0); for
# timeout it is the timeout tick minus _start_tick.
var _result_duration_ticks: int = 0

# Latched signal data (collected during the match)
var _first_engagement_tick: int = -1  # -1 if no combat occurred
var _iran_first_piyade_tick: int = -1
var _turan_probes_fired: int = 0

# Event counters (result-format v1.1.0 — previously hardcoded 0 per the
# deferred-counter pattern; now aggregated live from EventBus):
#   _units_killed_total          — EventBus.unit_died emits. Post-ARCH-1
#                                  hotfix this channel is UNIT-only (Building
#                                  HCs do not emit unit_died), which matches
#                                  the spec semantic "units that reached HP=0".
#   _buildings_destroyed_iran /  — EventBus.building_destroyed emits, split
#   _buildings_destroyed_turan     per team. Throne kind excluded (the Throne
#                                  is the win-condition, not a `buildings_
#                                  destroyed` stat, per schema §2.2).
#   _turan_units_deployed_total  — EventBus.unit_spawned emits with
#                                  team == TEAM_TURAN. NOTE: the current
#                                  TuranController COMMANDS pre-spawned roster
#                                  units rather than spawning probe waves, so
#                                  today this counts every Turan unit that
#                                  entered the match (starting roster included).
#                                  When Phase 6 Turan production lands, wave
#                                  spawns flow through the same channel.
#   _farr_drain_events_total     — EventBus.farr_changed emits with negative
#                                  effective delta. Drains clamped to a 0.0
#                                  effective delta (Farr already at floor) are
#                                  NOT counted — the signal reports post-clamp
#                                  movement and the meter did not move.
var _units_killed_total: int = 0
var _buildings_destroyed_iran: int = 0
var _buildings_destroyed_turan: int = 0
var _turan_units_deployed_total: int = 0
var _farr_drain_events_total: int = 0

# Held connections so we can disconnect cleanly on match end.
var _connected_throne_destroyed: bool = false
var _connected_unit_health_zero: bool = false
var _connected_unit_spawned: bool = false
var _connected_unit_died: bool = false
var _connected_building_destroyed: bool = false
var _connected_farr_changed: bool = false
var _connected_sim_phase: bool = false

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

	# Wave 3-Sim mirror C2.3 — accelerate wall-clock pacing. Default Godot
	# physics_ticks_per_second is 60. Raise it + max_physics_steps_per_frame
	# so the engine can fire multiple physics frames per render frame, and
	# SimClock's accumulator can drain all pending ticks per frame. The hard
	# upper bound is the CPU cost of one sim tick (spatial queries +
	# pathfinding + fog updates + per-unit FSM ticking). On a 14-combat-unit
	# starting roster the empirical sim-cost-per-tick limits us to ~25-30
	# sim-ticks/wall-sec regardless of the configured physics rate; further
	# speedup requires sim-level optimization (Phase 4+ scope: spatial
	# culling for AI scans, batched pathfinding, etc.). At ~30
	# sim-ticks/wall-sec a 60K-tick worst-case match is ~33 wall-min;
	# balance-engineer's 50-match calibration cycle is ~28h. Configured
	# aggressively to extract whatever speedup the engine can give without
	# changing simulation semantics. SimClock correctness (sim_phase order,
	# on-tick assertion, fixed-point math) is invariant under these knobs.
	Engine.physics_ticks_per_second = 1800
	Engine.max_physics_steps_per_frame = 12

	_start_tick = SimClock.tick
	_subscribe_signals()


# Tick-driven end-of-match checks (grace expiry + timeout). Runs on the
# sim_phase &"cleanup" emit — the LAST phase of every tick, so all of the
# tick's gameplay events (combat deaths, destruction emits, Farr drains)
# have already fired and been counted before we decide to seal the result.
#
# DET-3 fix (result-format v1.1.0): the timeout check previously lived in
# _process, which is frame-dependent — under variable frame pacing the
# stalemate could be detected 0..N sim-ticks after the boundary, making
# stalemate NDJSON records not run-reproducible. Checking on the cleanup
# phase makes both the timeout tick and the grace-emit tick functions of
# SimClock.tick alone.
#
# We do NOT drive sim-ticks here — SimClock._physics_process is the
# canonical driver (Sim Contract §6.1) and runs as a co-resident autoload.
func _on_sim_phase(phase: StringName, _tick: int) -> void:
	if phase != Constants.PHASE_CLEANUP:
		return
	if _match_ended:
		return

	# Grace expiry: a throne already fell; emit once the deterministic
	# grace window has elapsed. Checked BEFORE the timeout so a throne-fall
	# near the timeout boundary still resolves as a win, not a stalemate.
	if _grace_active:
		if SimClock.tick >= _grace_end_tick:
			print("[runner] grace_elapsed tick=%d" % SimClock.tick)
			_emit_result_and_quit()
		return

	# Timeout boundary check (tick-deterministic).
	if SimClock.tick - _start_tick >= _timeout_ticks:
		_timeout_triggered = true
		_outcome = "stalemate"
		_winner_team = -1  # stalemate sentinel
		_result_duration_ticks = SimClock.tick - _start_tick
		print("[runner] timeout match_id=%s duration_ticks=%d" % [
			_match_id, _result_duration_ticks,
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

	# iran_first_piyade_tick latch + turan_units_deployed_total counter:
	# subscribe to unit_spawned per AI_VS_AI_RESULT_FORMAT §7.1. Wave 3-Sim
	# mirror C2.1 — the signal is declared in event_bus.gd (no longer guarded
	# by has_signal which would mask the spec-vs-EventBus drift the original
	# code shipped with).
	if not EventBus.unit_spawned.is_connected(_on_unit_spawned):
		EventBus.unit_spawned.connect(_on_unit_spawned)
		_connected_unit_spawned = true

	# units_killed_total counter: unit_died is the UNIT-only death channel
	# (post-ARCH-1 hotfix Building HCs do not emit it) — exactly the schema
	# §2.2 semantic "total units that reached HP=0 across both teams".
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)
		_connected_unit_died = true

	# buildings_destroyed per-team counters: generic destruction channel
	# (Wave 3-BD). Throne kind filtered in the handler per schema §2.2.
	if not EventBus.building_destroyed.is_connected(_on_building_destroyed):
		EventBus.building_destroyed.connect(_on_building_destroyed)
		_connected_building_destroyed = true

	# farr_drain_events_total counter: every apply_farr_change flows through
	# the FarrSystem chokepoint which emits farr_changed (CLAUDE.md mandate),
	# so counting negative-delta emits == counting drain events.
	if not EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.connect(_on_farr_changed)
		_connected_farr_changed = true

	# Tick-driven end-of-match checks (grace expiry + DET-3 timeout) ride
	# the canonical sim_phase channel, filtered to PHASE_CLEANUP.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)
		_connected_sim_phase = true


# Win-condition handler. team_id = the team WHOSE Throne fell. Winner is
# the OTHER team. Per AI_VS_AI_RESULT_FORMAT §2.2 winner_team mapping:
#   Iran win = winner_team=1; Turan win = winner_team=2.
#
# Result-format v1.1.0: this handler no longer emits immediately. It latches
# winner/outcome/duration and ARMS the grace window; the NDJSON emit + quit
# happen in _on_sim_phase once SimClock.tick >= _grace_end_tick. Subscriptions
# stay live so same-tick + trailing events keep counting (the §9.B5 probe's
# concern (b), now empirically real with wired counters).
func _on_throne_destroyed(team_id: int) -> void:
	if _match_ended:
		return  # already concluded; ignore duplicate (shouldn't happen)
	if _grace_active:
		# Second throne falling inside the grace window (e.g., mutual
		# destruction cascade). First-throne-wins: the result is already
		# latched; log the event for the behavioral-tuning signal trail
		# (probe concern (3)) and keep counting.
		print("[runner] throne_destroyed_during_grace team_id=%d tick=%d" % [
			team_id, SimClock.tick,
		])
		return
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
	# duration_ticks records the THRONE-FALL tick (grace excluded) per
	# AI_VS_AI_RESULT_FORMAT §2.2 v1.1.0 — pacing-signal purity.
	_result_duration_ticks = SimClock.tick - _start_tick
	_grace_active = true
	_grace_end_tick = SimClock.tick + Constants.SIM_THRONE_GRACE_TICKS
	print("[runner] grace_started winner=%d grace_end_tick=%d tick=%d" % [
		_winner_team, _grace_end_tick, SimClock.tick,
	])


# Latch the first combat event. unit_health_zero proxies first-damage
# per AI_VS_AI_RESULT_FORMAT §7.1 — actual first-hit signal doesn't exist.
func _on_unit_health_zero(_unit_id: int) -> void:
	if _first_engagement_tick == -1:
		_first_engagement_tick = SimClock.tick


# Latch first Iran Piyade spawn (per AI_VS_AI_RESULT_FORMAT §7.1) + count
# Turan deployments (result-format v1.1.0 — see counter block comment for
# the "starting roster included" semantic note).
# Note: the unit_spawned signal payload shape is not currently locked at
# this branch state — use defensive untyped Variant + has-key checks.
func _on_unit_spawned(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var d: Dictionary = payload
	var team: int = int(d.get(&"team", -1))
	if team == Constants.TEAM_TURAN:
		_turan_units_deployed_total += 1
	if _iran_first_piyade_tick == -1 \
			and StringName(d.get(&"unit_type", &"")) == &"piyade" \
			and team == Constants.TEAM_IRAN:
		_iran_first_piyade_tick = SimClock.tick


# Count unit deaths (result-format v1.1.0). The producing HealthComponent
# already logs each death event (§9.M6 lives at the producer); the runner
# only aggregates. Totals surface in the match_end log line.
func _on_unit_died(_unit_id: int, _killer_unit_id: int, _cause: StringName,
		_position: Vector3) -> void:
	_units_killed_total += 1


# Count building destructions per team (result-format v1.1.0). Throne kind
# excluded — the Throne is the win-condition, captured by throne_destroyed /
# throne_hp_pct_at_end, not a `buildings_destroyed` stat (schema §2.2).
func _on_building_destroyed(team_id: int, kind: StringName, _unit_id: int) -> void:
	if kind == &"throne":
		return
	if team_id == Constants.TEAM_IRAN:
		_buildings_destroyed_iran += 1
	elif team_id == Constants.TEAM_TURAN:
		_buildings_destroyed_turan += 1


# Count Farr drain events (result-format v1.1.0). `amount` is the EFFECTIVE
# post-clamp delta per the farr_changed contract — a drain requested while
# Farr sits at the floor reports 0.0 and is intentionally not counted (the
# meter did not move).
func _on_farr_changed(amount: float, _reason: String, _source_unit_id: int,
		_farr_after: float, _tick: int) -> void:
	if amount < 0.0:
		_farr_drain_events_total += 1


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

	# duration_ticks was latched at throne-fall (win paths) or at the timeout
	# boundary (stalemate path) — NOT recomputed here, because by emit time
	# SimClock.tick has advanced through the grace window and the NDJSON
	# duration must exclude grace ticks (AI_VS_AI_RESULT_FORMAT §2.2 v1.1.0).
	var duration_ticks: int = _result_duration_ticks
	# Defensive: ensure duration is at least 1 (avoid /0 in duration_seconds
	# if the match ends on tick 0 for any reason).
	if duration_ticks < 1:
		duration_ticks = 1

	var result: Dictionary = _build_result_dict(duration_ticks)
	var ndjson: String = JSON.stringify(result)

	# Final state-change log BEFORE the NDJSON, so the batch script's
	# `rg '^{'` extraction finds the LAST single-line {...} which is the
	# JSON, not a log line. Counter totals surface here (§9.M6 — the
	# per-event logs live at the producers; this is the aggregate seal).
	print(("[runner] match_end outcome=%s winner=%d duration_ticks=%d "
			+ "kills=%d bldgs_destroyed=%d probes=%d deployed=%d farr_drains=%d") % [
		_outcome, _winner_team, duration_ticks,
		_units_killed_total,
		_buildings_destroyed_iran + _buildings_destroyed_turan,
		_turan_probes_fired, _turan_units_deployed_total,
		_farr_drain_events_total,
	])
	print(ndjson)

	_disconnect_signals()
	get_tree().quit(0)


# Build the result Dictionary matching AI_VS_AI_RESULT_FORMAT.md §2.1
# schema. All per-team fields read from the live autoloads at match-end.
func _build_result_dict(duration_ticks: int) -> Dictionary:
	# Probe count: TuranController exposes no per-probe signal; the documented
	# match-end accessor is the observable surface (result-format v1.1.0 —
	# §9.M7: direct call, no has_method guard; the accessor is contract-
	# promised on the autoload).
	_turan_probes_fired = TuranController.get_probes_fired_total()
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
		"turan_units_deployed_total": _turan_units_deployed_total,
		"buildings_destroyed_total": int(iran.get("buildings_destroyed", 0))
			+ int(turan.get("buildings_destroyed", 0)),
		"units_killed_total": _units_killed_total,
		"farr_drain_events_total": _farr_drain_events_total,
		# Deferred (probed at v1.1.0): FarrSystem has no Kaveh state or
		# trigger signal at this branch (Kaveh Event = Phase 5 per
		# 01_CORE_MECHANICS.md §9); nothing exists to wire. Stays false.
		"kaveh_event_triggered": false,
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

	# Iterate thrones group separately. Wave 3-Sim mirror C2.4 — the
	# `has_method(&"get_health")` guard was a stale relic; every Throne
	# has a HealthComponent post-Wave 3-BD. Asserting catches future
	# regression at runner_ready time instead of producing a silently-zero
	# throne_hp_pct field. Same memory pattern as BUG-C1, BUG-D2, and the
	# `coin_for` vs `get_coin_x100` case fixed in a5f5f21.
	for node: Node in st.get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != team_id:
			continue
		throne_destroyed = false
		assert(node.has_method(&"get_health"),
			"throne lacks get_health() — Wave 3-BD contract regressed")
		var hc: Variant = node.call(&"get_health")
		assert(hc != null and is_instance_valid(hc),
			"throne.get_health() returned null/freed — HC schema regressed")
		var hp_x100_v: Variant = hc.get(&"hp_x100")
		var max_hp_x100_v: Variant = hc.get(&"max_hp_x100")
		assert(hp_x100_v != null and max_hp_x100_v != null,
			"HealthComponent.hp_x100/max_hp_x100 fields missing — HC schema regressed")
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

	# Farr — FarrSystem tracks IRAN's single civilization meter at MVP.
	# Result-format v1.1.0 / §7.3: Turan emits the -1 SENTINEL ("not
	# separately tracked"), NOT Iran's value. Per balance-engineer's
	# self-flag: a self-consistent-but-wrong proxy (Iran's Farr labeled as
	# Turan's) produces confident wrong conclusions in batch analysis; an
	# explicit sentinel forces the aggregator to exclude it.
	# TODO: separate per-team Farr when Phase 5 campaign adds Turan Farr drain.
	var farr_x100: int = -1
	if team_id == Constants.TEAM_IRAN:
		var farr_x100_v: Variant = FarrSystem.get(&"_farr_x100")
		if farr_x100_v != null:
			farr_x100 = int(farr_x100_v)

	# Per-team destruction counter aggregated live from
	# EventBus.building_destroyed (result-format v1.1.0; Throne excluded).
	var destroyed: int = 0
	if team_id == Constants.TEAM_IRAN:
		destroyed = _buildings_destroyed_iran
	elif team_id == Constants.TEAM_TURAN:
		destroyed = _buildings_destroyed_turan

	return {
		"throne_destroyed": throne_destroyed,
		"throne_hp_pct_at_end": throne_hp_pct,
		"workers_alive_at_end": workers,
		"combat_units_alive_at_end": combat_units,
		"buildings_alive_at_end": buildings,
		"buildings_destroyed": destroyed,
		"coin_x100_at_end": coin_x100,
		"grain_x100_at_end": grain_x100,
		"farr_x100_at_end": farr_x100,
		# Deferred (probed at v1.1.0): unit_spawned's payload carries no
		# production-source discrimination (match-start roster vs trained-
		# at-building), and no construction_finalized counter channel is in
		# B2 scope. Stays 0 until a production-source field lands.
		"units_produced_total": 0,
		"buildings_constructed_total": 0,
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
	if _connected_unit_spawned:
		if EventBus.unit_spawned.is_connected(_on_unit_spawned):
			EventBus.unit_spawned.disconnect(_on_unit_spawned)
		_connected_unit_spawned = false
	if _connected_unit_died:
		if EventBus.unit_died.is_connected(_on_unit_died):
			EventBus.unit_died.disconnect(_on_unit_died)
		_connected_unit_died = false
	if _connected_building_destroyed:
		if EventBus.building_destroyed.is_connected(_on_building_destroyed):
			EventBus.building_destroyed.disconnect(_on_building_destroyed)
		_connected_building_destroyed = false
	if _connected_farr_changed:
		if EventBus.farr_changed.is_connected(_on_farr_changed):
			EventBus.farr_changed.disconnect(_on_farr_changed)
		_connected_farr_changed = false
	if _connected_sim_phase:
		if EventBus.sim_phase.is_connected(_on_sim_phase):
			EventBus.sim_phase.disconnect(_on_sim_phase)
		_connected_sim_phase = false
