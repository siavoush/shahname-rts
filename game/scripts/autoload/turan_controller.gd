extends Node
##
## TuranController — Wave 3B probe-attack scaffold for the Turan AI opponent.
##
## Canonical spec: `docs/AI_DIFFICULTY.md` v1.1.0 (SSOT) + the Wave 3B kickoff
##   brief `02p_PHASE_3_SESSION_8_WAVE_3B_KICKOFF.md` v1.1.0.
##
## What this wave SHIPS (per brief §1):
##   - Autoload Node subscribed to `EventBus.sim_phase` (canonical pattern
##     per `spatial_index.gd:43`, `unit.gd:363`, `building.gd:367`, and the
##     post-BUG-D1 `fog_system.gd`).
##   - Probe-attack FSM: `&"idle"` ↔ `&"probing"`. On idle after probe-cadence
##     ticks elapse: pick a Turan-visible Iran unit via
##     `FogSystem.is_visible_to`, issue attack-move to the nearest alive Turan
##     unit, transition to probing. On probing: monitor target + commanded
##     unit; transition back to idle once either is invalid/dead.
##   - Difficulty-aware probe cadence: `BalanceData.ai.normal_wave_cadence_ticks`
##     read at `_ready` (3600 ticks = 120s @ 30Hz). Difficulty UI is a later
##     wave; 3B hardcodes Normal.
##
## What this wave DOES NOT SHIP (per brief §1 explicit exclusions):
##   - Turan economy / building placement / production-driving / tech-up.
##   - Easy/Normal/Hard difficulty selection UI.
##   - `attack_army_threshold` enforcement (requires army-grouping logic).
##   - Kaveh Event integration (Phase 5).
##
## Cultural framing (per brief §4 Track 1 reminder + AI_DIFFICULTY.md §0):
##   Turan in the Shahnameh is the antagonist civilization across the
##   Iran-Turan wars (Manuchehr, Kay Kavus, Kay Khosrow eras). The eventual
##   Phase 6 TuranController will need to feel like Afrasiyab's strategic
##   mind — kingdom-level pressure, not horde-rushing. 3B is the mechanical
##   floor; the cultural-note prose lands at Phase 6.
##
## Pitfall #16 safety (MANDATORY per brief §4 Track 1 + ARCHITECTURE.md §6
##   v0.31.0 retro): the target Node and the commanded Turan unit are stored
##   as untyped `Variant`, NEVER as typed Node3D/Unit. Iran can kill our
##   commanded unit between idle→probing and the next probing-tick;
##   `queue_free.call_deferred` from `UnitState_Dying.enter` reaps the Node
##   asynchronously, so any subsequent `as Node3D` cast crashes the engine.
##   ALL accesses go through `is_instance_valid()` BEFORE cast or property
##   read. Mirrors the post-fix shape at `fog_system.gd:341` (the first
##   canonical-incident anchor for Pitfall #16).
##
## Pitfall #17 test-discipline (MANDATORY per brief §4 Track 1):
##   Tests use `node.free()` rather than `queue_free()` + `await
##   get_tree().process_frame`. The await leaks `_physics_process` ticks into
##   SimClock; downstream tests fail asymmetrically.
##
## Wiring-path test discipline (MANDATORY per brief §4 Track 1 — BUG-D1
##   lesson): tests drive `EventBus.sim_phase.emit(&"ai", 1)` to exercise the
##   actual signal connection, not a direct call to `_on_sim_phase`. This
##   catches BUG-D1's same shape (signal never connected → handler never
##   fired) at ship time.

# ---------------------------------------------------------------------------
# Tunables read from BalanceData (resolved at _ready)
# ---------------------------------------------------------------------------

## Ticks between probe attacks. Read once at `_ready` from
## `BalanceData.ai.normal_wave_cadence_ticks` (canonical: `ai_config.gd:41`,
## default 3600 ticks = 120s @ 30Hz). Cached so the per-tick path doesn't
## touch the BalanceData chain.
##
## §9.L10 zero-canonical-consumer fallback applied: `BalanceData.ai` had ZERO
## existing consumers at brief time (verified via `git grep BalanceData.ai`),
## so the field name + access shape were verified directly against the
## schema-declaration file at `game/data/sub_resources/ai_config.gd:41`.
##
## Fallback when BalanceData/AIConfig is missing (test fixtures, pre-3B
## branches): the default below mirrors the schema's Normal default so
## headless fixtures don't have to construct a BalanceData chain.
const _DEFAULT_PROBE_CADENCE_TICKS: int = 3600

## Maximum search radius (world units) when picking the nearest visible
## Iran unit. Used by `SpatialIndex.query_radius_team`. The MVP map is 256m
## per `Constants.MAP_SIZE_WORLD`; a 256m radius covers the entire map and
## keeps probe-target selection O(N) in the unit count.
const _PROBE_SEARCH_RADIUS_M: float = 256.0


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## FSM state. `&"idle"` or `&"probing"`.
var _state: StringName = &"idle"

## Ticks elapsed since the last probe attack was issued. Resets to 0
## whenever we transition idle→probing. The first probe is delayed by one
## full cadence (counter starts at 0 + transitions when >= cadence).
var _ticks_since_last_probe: int = 0

## Cadence (in ticks) before the next probe fires. Read from
## `BalanceData.ai.normal_wave_cadence_ticks` at `_ready`.
var _probe_cadence_ticks: int = _DEFAULT_PROBE_CADENCE_TICKS

## Current probe target (an Iran Node we picked via FogSystem). Stored as
## Variant per Pitfall #16 — Iran can free this Node between probes; the
## subsequent `as Node3D` cast would crash the engine. ALL accesses must
## `is_instance_valid()` first. Set on idle→probing, cleared on
## probing→idle.
var _current_probe_target: Variant = null

## Currently-commanded Turan unit (the one we issued attack-move to). Same
## Pitfall #16 safety as `_current_probe_target` — combat can kill our
## commanded unit before its probe resolves. Set on idle→probing, cleared
## on probing→idle.
var _current_probe_unit: Variant = null

## Last logged stall state — used to rate-limit per-tick stall logs to
## state-change events only (BUG-H5 log-flood fix 2026-05-26). Without
## this gate the retry-asap loop (_step_idle stays in idle, cadence pinned
## at ceiling, re-fires every AI tick) prints the cadence-elapsed +
## no-target lines 30x/sec → 90+ lines/sec → 800KB+ log in 4 min.
var _last_stall_reason: String = ""

## Last picked-target signature — gates the diag log to state-change only.
## Same rationale as _last_stall_reason: prevent per-tick spam.
var _last_pick_signature: String = ""

## Total probes LAUNCHED this match (idle→probing transitions). Monotonic;
## reset() clears it. Wave 3-Sim result-format v1.1.0 (Track B2): this is
## the observable surface HeadlessMatchRunner reads at match end for the
## NDJSON `events.turan_probes_fired` field (AI_VS_AI_RESULT_FORMAT.md §2.2).
## Counting the LAUNCH edge (not probing→idle resolution) means a probe
## still in flight when the match ends counts as fired — the semantics the
## diagnostic check `probes ≈ floor(duration_ticks / cadence)` expects.
var _probes_fired_total: int = 0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Read probe cadence from BalanceData.ai.normal_wave_cadence_ticks.
	# Defensive: missing BalanceData / AIConfig / field → fall back to the
	# schema's Normal default. Test fixtures often construct TuranController
	# without the full balance chain.
	_probe_cadence_ticks = _resolve_probe_cadence()
	print("[turan] TuranController._ready — cadence=", _probe_cadence_ticks)  # DEBUG (live-test diag)

	# Subscribe to EventBus.sim_phase. Canonical pattern (per brief §4 Track 1
	# + BUG-D1 lesson at `fog_system.gd` post-fix `f855ec5`):
	#   - SimClock does NOT declare per-phase signals.
	#   - SimClock emits `EventBus.sim_phase(phase, tick)` for ALL phases.
	#   - Subscribers connect to `EventBus.sim_phase` + filter by phase.
	# Mirrors `spatial_index.gd:43`, `unit.gd:363`, `building.gd:367`.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)


## Disconnect at tree exit so a freed controller doesn't keep handling phase
## signals. Symmetric with `_ready`. Mirrors `unit.gd:_exit_tree`.
func _exit_tree() -> void:
	if EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.disconnect(_on_sim_phase)


# ---------------------------------------------------------------------------
# Public test API
# ---------------------------------------------------------------------------

## Reset to pristine state. Used by GUT before_each / after_each — mirrors
## `SimClock.reset` / `SpatialIndex.reset` / `GameState.reset`. Tests that
## create units across cases need this to avoid state leaking between cases.
func reset() -> void:
	_state = &"idle"
	_ticks_since_last_probe = 0
	_current_probe_target = null
	_current_probe_unit = null
	_last_stall_reason = ""
	_last_pick_signature = ""
	_probes_fired_total = 0


## Public read-only snapshot of FSM state for tests + the future F3 debug
## overlay (per `CLAUDE.md` "Debug overlays as first-class").
func get_state() -> StringName:
	return _state


## Public read-only counter accessor. Tests assert this advances per tick.
func get_ticks_since_last_probe() -> int:
	return _ticks_since_last_probe


## Public read-only probe-cadence accessor. Tests verify the BalanceData
## read landed (= 3600 at Normal default).
func get_probe_cadence_ticks() -> int:
	return _probe_cadence_ticks


## Public read-only total of probes launched this match (idle→probing
## transitions). HeadlessMatchRunner reads this at match end for the NDJSON
## `events.turan_probes_fired` field. Documented accessor per Wave 3-Sim
## result-format v1.1.0 — TuranController declares no per-probe signal, so
## a match-end read of this monotonic counter is the cleanest surface.
func get_probes_fired_total() -> int:
	return _probes_fired_total


# ---------------------------------------------------------------------------
# EventBus.sim_phase handler — canonical filter pattern
# ---------------------------------------------------------------------------

## Per-tick AI step. Filters to `Constants.PHASE_AI` (`&"ai"`) — runs after
## `fog_update` (phase 2) per `SIMULATION_CONTRACT.md` §2 v1.5.0, so
## `FogSystem.is_visible_to` reads fresh visibility this tick.
##
## NOTE: per brief §4 Track 1 wiring-path test discipline, tests drive this
## via `EventBus.sim_phase.emit(&"ai", 1)` — NOT by calling `_on_sim_phase`
## directly. The signal-connection itself is load-bearing (BUG-D1 lesson).
func _on_sim_phase(phase: StringName, _tick: int) -> void:
	if phase != Constants.PHASE_AI:
		return
	# Dispatch to the FSM step for the current state.
	match _state:
		&"idle":
			_step_idle()
		&"probing":
			_step_probing()
		_:
			# Unknown state — recover by snapping back to idle. Defensive
			# (the FSM only writes the two valid StringNames, but external
			# test setters could land us here).
			_state = &"idle"


# ---------------------------------------------------------------------------
# FSM step functions
# ---------------------------------------------------------------------------

## Idle step: increment cadence counter. When counter >= cadence, try to
## pick a target + commanded unit + issue attack-move + transition to
## probing. If either pick fails (no visible Iran units, no alive Turan
## units), the counter STAYS at the cadence ceiling so the next AI-tick
## tries again immediately — a probe deferred this tick should fire as soon
## as a target appears, not wait another full cadence.
##
## First-probe delay: counter starts at 0 in `_ready` and on probing→idle
## transition, so the first probe fires `_probe_cadence_ticks` ticks after
## match start (per brief §4 Track 1 Decision 4 — "First-probe delay
## delayed by one full cadence. Iran establishes presence first").
func _step_idle() -> void:
	_ticks_since_last_probe += 1
	if _ticks_since_last_probe < _probe_cadence_ticks:
		return
	# Cadence elapsed — try to launch a probe. Per the original Wave 3B
	# design, on no-target we STAY at the cadence ceiling and retry every
	# AI tick (30/sec). All per-tick stall logs are gated by stall-reason
	# state-change to avoid log flood (BUG-H5).
	var target: Variant = _pick_target()
	if not is_instance_valid(target):
		_log_stall_once("no_visible_iran_target")
		return
	var commanded: Variant = _pick_turan_unit(target)
	if not is_instance_valid(commanded):
		_log_stall_once("no_turan_unit_near_target")
		return
	# PROBE FIRING — clear stall latch + log the event (single shot per probe).
	if _last_stall_reason != "":
		print("[turan] stall_end after_reason=%s tick=%d" % [_last_stall_reason, SimClock.tick])
		_last_stall_reason = ""
	print("[turan] PROBE FIRING — target=", target, " commanded=", commanded, " tick=", SimClock.tick)
	# Issue the attack. Pitfall #16 safety: we just `is_instance_valid`d
	# both Variants above — the cast below is safe in this synchronous path.
	#
	# BUG-H6 fix-up (Wave 3-BD live-test 2026-05-27): we issue COMMAND_ATTACK
	# with target_unit_id, NOT COMMAND_ATTACK_MOVE with a Vector3. Reason: the
	# Vector3 destination is the building's center, which is INSIDE the
	# NavigationObstacle3D footprint. Pathing to it fails (or auto-snaps to
	# the obstacle edge, then is_moving=false fires arrival), UnitState_AttackMove
	# transitions to Idle → probe ends without combat. COMMAND_ATTACK uses
	# UnitState_Attacking's own walk-toward + range-check logic; it doesn't
	# need to reach the building's center, just attack_range of it. Works
	# uniformly for both Unit and Building targets (both have unit_id).
	var target_uid: int = -1
	var raw_uid: Variant = target.get(&"unit_id")
	if typeof(raw_uid) == TYPE_INT:
		target_uid = int(raw_uid)
	_issue_attack(commanded as Node3D, target, target_uid)
	# Capture refs for monitoring + transition.
	_current_probe_target = target
	_current_probe_unit = commanded
	_state = &"probing"
	_ticks_since_last_probe = 0
	# Result-format v1.1.0 (Track B2): count the launch edge. The PROBE
	# FIRING print above is the §9.M6 event log for this mutation.
	_probes_fired_total += 1


## Probing step: monitor the current probe. Transition back to idle when
## EITHER the target OR the commanded unit becomes invalid (combat killed
## it, scene-tree teardown, etc.). Per brief §1: "On `&"probing"`: monitor;
## transition back to `&"idle"` after attack resolves OR target lost."
##
## Pitfall #16 safety MANDATORY: both Variants are checked via
## `is_instance_valid()` before any property access or cast. The mirror of
## the canonical pattern at `fog_system.gd:341`.
func _step_probing() -> void:
	# If either ref is null OR the underlying Object was freed, the probe
	# is "resolved" — go back to idle. `is_instance_valid(null) == false`,
	# so null and freed-Object both fall through cleanly here.
	if not is_instance_valid(_current_probe_target):
		_transition_to_idle()
		return
	if not is_instance_valid(_current_probe_unit):
		_transition_to_idle()
		return
	# Both refs still alive. For 3B MVP we don't track richer probe-
	# resolution criteria (e.g., "target took damage", "commanded unit
	# reached target position"). Phase 6 will tighten this with proper
	# attack-resolution detection per AI_DIFFICULTY.md §2.
	# Until then, we stay in probing as long as both refs are alive.


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Log a stall reason ONCE per stall period — re-firing only when the
## reason transitions. Prevents the retry-asap loop from spamming 30
## lines/sec into the log (BUG-H5 log-flood). When the reason matches
## the last logged reason, stay silent.
func _log_stall_once(reason: String) -> void:
	if reason == _last_stall_reason:
		return
	print("[turan] stall_start reason=%s tick=%d" % [reason, SimClock.tick])
	_last_stall_reason = reason


## Resolve `_probe_cadence_ticks` from `BalanceData.ai.normal_wave_cadence_ticks`.
##
## Defensive shape: any failure in the BalanceData chain falls back to the
## schema's Normal default (3600). This preserves test fixtures that
## construct TuranController without the full balance chain — mirrors the
## same defensive pattern used in `unit.gd:_register_fog_vision_source`.
func _resolve_probe_cadence() -> int:
	# SIM_FAST_MODE override (session 9 close retro 2026-05-28; balance-engineer
	# proposal). When true, compresses cadence 3600 → 300 ticks (120s → 10s)
	# for live-test quality-of-life. NEVER true on main.
	if Constants.SIM_FAST_MODE:
		print("[turan] SIM_FAST_MODE active — cadence overridden to ", Constants.SIM_FAST_PROBE_CADENCE_TICKS)
		return Constants.SIM_FAST_PROBE_CADENCE_TICKS
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return _DEFAULT_PROBE_CADENCE_TICKS
	var bd: Resource = load(path)
	if bd == null:
		return _DEFAULT_PROBE_CADENCE_TICKS
	var ai_cfg: Variant = bd.get(&"ai")
	if ai_cfg == null or not (ai_cfg is Resource):
		return _DEFAULT_PROBE_CADENCE_TICKS
	var cadence_v: Variant = (ai_cfg as Resource).get(&"normal_wave_cadence_ticks")
	if typeof(cadence_v) != TYPE_INT and typeof(cadence_v) != TYPE_FLOAT:
		return _DEFAULT_PROBE_CADENCE_TICKS
	var cadence: int = int(cadence_v)
	if cadence <= 0:
		# Defensive: 0 or negative cadence would never fire (or fire every
		# tick). Treat as missing — fall back to default.
		return _DEFAULT_PROBE_CADENCE_TICKS
	return cadence


## Pick the nearest Iran target visible to Turan via FogSystem.
##
## Priority order:
##   1. Iran Throne if visible (decisive — win condition).
##   2. Nearest visible Iran building OR unit (combined candidate pool).
##
## BUG-H1 fix (Wave 3-BuildingDestructibility live-test): pre-fix code only
## considered Iran units (SpatialIndex) after Throne. Buildings with HC could
## take damage in theory but were never targeted → defensibility unplayable.
## Fix extends the candidate pool to include all non-Throne Iran buildings
## via the canonical &"buildings" SceneTree group (registered at
## `building.gd:358`).
##
## Strategy:
##   1. Throne special-case (preserved from Wave 3-Throne).
##   2. Walk &"buildings" group; filter to TEAM_IRAN + non-Throne + fog-visible.
##   3. Query SpatialIndex for Iran-team agents; filter to fog-visible.
##   4. Merge both candidate lists; return nearest to map origin.
##
## Returns Variant: a live Node3D (Iran unit or building) on success, or null
## when no visible Iran target exists. Caller MUST `is_instance_valid()` before
## casting.
func _pick_target() -> Variant:
	var fog: Node = _autoload_or_null(&"FogSystem")
	if fog == null:
		print("[turan-diag]   FogSystem autoload not found")  # DEBUG
		return null
	# Priority 1: Iran Throne if visible.
	var iran_throne: Variant = _find_iran_throne_if_visible(fog)
	if iran_throne != null:
		# §9.M6 — log the target-priority transition. Only when we
		# actually shift TO throne-target (not when we stay on
		# throne-target across ticks); _current_probe_target tracks the
		# previous target.
		if _current_probe_target != iran_throne:
			print("[turan] target_switch unit → throne (iran_throne unit_id=%d)" % [
				int((iran_throne as Node3D).get(&"unit_id"))])
		return iran_throne

	# Priority 2: nearest visible Iran building OR unit.
	var origin: Vector3 = Vector3.ZERO
	var best_target: Variant = null
	var best_dist_sq: float = INF

	# Building candidates via &"buildings" group. Excludes Throne (handled above)
	# via &"thrones" group check. Pitfall #16 safety: validate each Node before
	# any access — group nodes can be freed asynchronously per Wave 3-BD destruction.
	#
	# Filter is "non-Turan" rather than "Iran only" per user design intent
	# (BUG-H1 live-test 2026-05-26): half-built buildings (team=TEAM_NEUTRAL=0,
	# the brief window between scene-instantiation and place_at when the
	# worker is interrupted) should also be destroyable. The looser filter
	# catches that case. Currently no buildings live at TEAM_NEUTRAL outside
	# this transient state, so this doesn't introduce false-positive targets.
	var buildings_total: int = 0
	var buildings_eligible: int = 0
	var buildings_fog_rejected: int = 0
	var tree: SceneTree = get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group(&"buildings"):
			if not is_instance_valid(node):
				continue
			if not (node is Node3D):
				continue
			buildings_total += 1
			# Skip Throne — already handled in priority 1.
			if node.is_in_group(&"thrones"):
				continue
			var node_team: Variant = node.get(&"team")
			# Non-Turan filter (includes TEAM_IRAN + TEAM_NEUTRAL half-built).
			if typeof(node_team) == TYPE_INT and int(node_team) == Constants.TEAM_TURAN:
				continue
			buildings_eligible += 1
			var b_pos: Vector3 = (node as Node3D).global_position
			var b_vis: bool = fog.call(&"is_visible_to", Constants.TEAM_TURAN, b_pos)
			if not b_vis:
				buildings_fog_rejected += 1
				continue
			var bdx: float = b_pos.x - origin.x
			var bdz: float = b_pos.z - origin.z
			var b_d2: float = bdx * bdx + bdz * bdz
			if b_d2 < best_dist_sq:
				best_dist_sq = b_d2
				best_target = node

	# Unit candidates via SpatialIndex.
	var spatial: Node = _autoload_or_null(&"SpatialIndex")
	var agents: Array = []
	var unit_fog_rejected: int = 0
	if spatial != null:
		agents = spatial.call(
			&"query_radius_team", origin, _PROBE_SEARCH_RADIUS_M, Constants.TEAM_IRAN)
		for agent in agents:
			if not is_instance_valid(agent):
				continue
			var parent: Node = agent.get_parent()
			if not is_instance_valid(parent):
				continue
			if not (parent is Node3D):
				continue
			var pos: Vector3 = (parent as Node3D).global_position
			var vis: bool = fog.call(&"is_visible_to", Constants.TEAM_TURAN, pos)
			if not vis:
				unit_fog_rejected += 1
				continue
			var dx: float = pos.x - origin.x
			var dz: float = pos.z - origin.z
			var d2: float = dx * dx + dz * dz
			if d2 < best_dist_sq:
				best_dist_sq = d2
				best_target = parent
	else:
		print("[turan-diag]   SpatialIndex autoload not found")  # DEBUG

	# §9.M6 — diag log gated to state-change only (BUG-H5). The signature
	# encodes the candidate-counts + picked target; identical signatures
	# back-to-back fire once per state-change, not per-tick (the retry-asap
	# loop would otherwise spam 30 lines/sec).
	var picked_label: String = "null"
	if best_target != null:
		var picked_uid: Variant = best_target.get(&"unit_id")
		var picked_uid_int: int = -1
		if typeof(picked_uid) == TYPE_INT:
			picked_uid_int = int(picked_uid)
		var picked_kind_or_type: Variant = best_target.get(&"unit_type")
		var picked_kind_label: String = ""
		if typeof(picked_kind_or_type) == TYPE_STRING_NAME:
			picked_kind_label = str(picked_kind_or_type)
		else:
			var k: Variant = best_target.get(&"kind")
			if typeof(k) == TYPE_STRING_NAME:
				picked_kind_label = str(k)
		picked_label = "unit_id=%d (%s) dist=%.2f" % [
			picked_uid_int, picked_kind_label, sqrt(best_dist_sq)]
	var sig: String = "b%d_e%d_fb%d_u%d_fu%d_%s" % [
		buildings_total, buildings_eligible, buildings_fog_rejected,
		agents.size(), unit_fog_rejected, picked_label]
	if sig != _last_pick_signature:
		print("[turan-diag] _pick_target: buildings_total=%d eligible=%d fog_rej=%d units_total=%d fog_rej=%d picked=%s tick=%d" % [
			buildings_total, buildings_eligible, buildings_fog_rejected,
			agents.size(), unit_fog_rejected, picked_label, SimClock.tick])
		_last_pick_signature = sig
	return best_target


## Pick the nearest alive Turan unit to the target. Returns Variant (Node3D
## or null). Caller MUST `is_instance_valid()` before casting.
func _pick_turan_unit(target: Variant) -> Variant:
	if not is_instance_valid(target):
		return null
	if not (target is Node3D):
		return null
	var target_pos: Vector3 = (target as Node3D).global_position
	var spatial: Node = _autoload_or_null(&"SpatialIndex")
	if spatial == null:
		return null
	var agents: Array = spatial.call(
		&"query_radius_team", target_pos, _PROBE_SEARCH_RADIUS_M, Constants.TEAM_TURAN)
	var best_unit: Variant = null
	var best_dist_sq: float = INF
	for agent in agents:
		if not is_instance_valid(agent):
			continue
		var parent: Node = agent.get_parent()
		if not is_instance_valid(parent):
			continue
		if not (parent is Node3D):
			continue
		# Only commandable units: must have `replace_command`. Workers
		# (Kargar) have it too — they CAN be commanded to attack-move; for
		# 3B that's acceptable (a worker walking toward Iran is the rare
		# corner case; Phase 6 will filter to combat-capable units only).
		if not parent.has_method(&"replace_command"):
			continue
		var pos: Vector3 = (parent as Node3D).global_position
		var dx: float = pos.x - target_pos.x
		var dz: float = pos.z - target_pos.z
		var d2: float = dx * dx + dz * dz
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_unit = parent
	return best_unit


## Issue an attack-move command to a Turan unit toward a world position.
##
## Per brief §4 Track 1 Decision 2 + canonical pattern from
## `attack_move_handler.gd:180`:
##   `unit.replace_command(Constants.COMMAND_ATTACK_MOVE, {&"target": pos})`
##
## Wave 3B uses COMMAND_ATTACK_MOVE — the canonical kind already exists
## (Constants.COMMAND_ATTACK_MOVE = &"attack_move") and is consumed by
## `UnitState_AttackMove`. Falls back to COMMAND_MOVE if the unit is a
## subclass that doesn't register UnitState_AttackMove (defensive — every
## Unit subclass registers it per `unit.gd:144`, so this is belt-and-
## suspenders).
func _issue_attack_move(unit: Node3D, target_position: Vector3) -> void:
	if not is_instance_valid(unit):
		return
	if not unit.has_method(&"replace_command"):
		return
	# Canonical attack-move payload shape per `attack_move_handler.gd:182`:
	# `{&"target": Vector3}`. UnitState_AttackMove reads `current_command.payload`
	# to extract the target.
	unit.call(
		&"replace_command",
		Constants.COMMAND_ATTACK_MOVE,
		{&"target": target_position},
	)


## Issue COMMAND_ATTACK with target_unit_id payload. Used for Unit + Building
## targets where the Turan unit needs to walk-toward + engage within
## attack_range without trying to reach the destination's exact center
## (which for buildings is inside a NavigationObstacle3D footprint and
## causes UnitState_AttackMove to bail to Idle — BUG-H6 2026-05-27).
##
## UnitState_Attacking handles the walk-toward logic internally per its
## per-tick distance check + request_repath fallback.
func _issue_attack(unit: Node3D, target_node: Variant, target_unit_id: int) -> void:
	if not is_instance_valid(unit):
		return
	if not unit.has_method(&"replace_command"):
		return
	if target_unit_id < 0:
		# Defensive: target without unit_id — fall back to attack-move via
		# global_position (legacy code path for the rare no-unit_id target).
		push_warning(
			"TuranController._issue_attack: target has no valid unit_id; "
			+ "skipping attack command"
		)
		return
	# BUG-H8 (2026-05-27 live-test): the payload carries the actual target
	# Node ref in addition to target_unit_id. UnitState_Attacking's
	# fallback _find_unit_by_id walk hits namespace collisions between
	# Buildings and Units (both share the global unit_id counter — per
	# BUG-G1 architecture-review finding). The Node ref lets the receiver
	# bypass the ambiguous lookup. target_unit_id stays in the payload for
	# (a) backward-compat with other COMMAND_ATTACK callers (player
	# right-click) and (b) downstream CombatComponent set_target which
	# still uses id.
	unit.call(
		&"replace_command",
		Constants.COMMAND_ATTACK,
		{
			&"target_unit_id": target_unit_id,
			&"target_node": target_node,
		},
	)


## Transition probing→idle. Clears probe refs + resets cadence counter so
## the next probe waits a full cadence (gives Iran breathing room between
## attacks). Per brief §1: "Wave 3B is the probe-attack scaffold; sophistication
## arrives in Phase 6 per AI_DIFFICULTY.md §2."
func _transition_to_idle() -> void:
	_state = &"idle"
	_current_probe_target = null
	_current_probe_unit = null
	_ticks_since_last_probe = 0


## Resolve an autoload by name without taking a hard parse-time dependency.
## Mirrors the safe-resolve pattern used in `unit.gd` + `fog_system.gd`
## (BUG-D1 retro context). Returns null when the autoload isn't registered
## (test fixtures that skip project.godot autoloads).
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(autoload_name)))


## Wave-3-Throne — look up Iran's Throne via the &"thrones" SceneTree group
## and return it if visible to Turan via FogSystem. Returns null when no
## Iran Throne exists OR Iran's Throne is not currently visible to Turan
## (fog-of-war hides it).
##
## **Anti-misuse warning (mirror C1.2):** buildings do NOT register with
## SpatialIndex (SpatialIndex tracks UNITS via SpatialAgentComponent only).
## Querying SpatialIndex.query_radius_team for the Throne would silently
## return zero matches — the BUG-D2 shape recapitulated. Group iteration
## is the canonical lookup channel for buildings.
##
## **Pitfall #16 safety:** every Node ref returned by get_nodes_in_group
## is validated via is_instance_valid before access. A Throne that was
## destroyed between the group-iteration and now would be a freed Object
## otherwise.
func _find_iran_throne_if_visible(fog: Node) -> Variant:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue
		var node_team: Variant = node.get(&"team")
		if typeof(node_team) != TYPE_INT or int(node_team) != Constants.TEAM_IRAN:
			continue
		var pos: Vector3 = (node as Node3D).global_position
		var vis: bool = fog.call(&"is_visible_to", Constants.TEAM_TURAN, pos)
		if vis:
			return node
		# Throne exists but is hidden by fog — continue scan in case there
		# are multiple (out of MVP scope but defensive); otherwise fall
		# through to the unit-target fallback.
	return null
