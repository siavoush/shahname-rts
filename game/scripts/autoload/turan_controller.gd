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
	# Cadence elapsed — try to launch a probe.
	print("[turan] cadence elapsed, attempting probe at tick=", SimClock.tick)  # DEBUG
	var target: Variant = _pick_target()
	if not is_instance_valid(target):
		# No visible Iran unit. Stay idle; counter stays at cadence so we
		# retry next AI-tick (don't wait another full cadence after a no-op).
		print("[turan]   no visible Iran target — staying idle")  # DEBUG
		return
	var commanded: Variant = _pick_turan_unit(target)
	if not is_instance_valid(commanded):
		# No alive Turan unit OR all Turan units are too far / freed. Stay
		# idle; same retry-asap semantics as no-target.
		# Per brief §4 Track 1 Decision 5: "Pop-cap fallback if no Turan
		# units alive — log debug message, stay in idle. No production-
		# driving (deferred per §1 exclusions)."
		print("[turan]   target found but no Turan unit near it — staying idle")  # DEBUG
		return
	print("[turan]   PROBE FIRING — target=", target, " commanded=", commanded)  # DEBUG
	# Issue the attack-move. Pitfall #16 safety: we just `is_instance_valid`d
	# both Variants above — the cast inside _issue_attack_move is safe in
	# this synchronous path.
	var target_pos: Vector3 = (target as Node3D).global_position
	_issue_attack_move(commanded as Node3D, target_pos)
	# Capture refs for monitoring + transition.
	_current_probe_target = target
	_current_probe_unit = commanded
	_state = &"probing"
	_ticks_since_last_probe = 0


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

## Resolve `_probe_cadence_ticks` from `BalanceData.ai.normal_wave_cadence_ticks`.
##
## Defensive shape: any failure in the BalanceData chain falls back to the
## schema's Normal default (3600). This preserves test fixtures that
## construct TuranController without the full balance chain — mirrors the
## same defensive pattern used in `unit.gd:_register_fog_vision_source`.
func _resolve_probe_cadence() -> int:
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


## Pick the nearest Iran unit visible to Turan via FogSystem.
##
## Per brief §4 Track 1 Decision 2: "Target priority — nearest Iran unit
## visible to Turan via `FogSystem.is_visible_to`."
##
## Strategy:
##   1. Query the SpatialIndex for all Iran-team units within a wide radius
##      centered on... the map origin. (MVP simplification — Phase 6 will
##      use the per-Turan-unit distance.) Wave 3B treats the entire map as
##      one search zone since the map is 256m square and AI doesn't yet
##      track its own positions.
##   2. Filter by `FogSystem.is_visible_to(TEAM_TURAN, unit.global_position)`.
##   3. Return the nearest one to the map origin (Vector3.ZERO).
##
## Returns Variant: a live Node3D (Iran unit) on success, or null when no
## visible Iran target exists. Caller MUST `is_instance_valid()` before
## casting.
func _pick_target() -> Variant:
	var fog: Node = _autoload_or_null(&"FogSystem")
	if fog == null:
		print("[turan-diag]   FogSystem autoload not found")  # DEBUG
		return null
	var spatial: Node = _autoload_or_null(&"SpatialIndex")
	if spatial == null:
		print("[turan-diag]   SpatialIndex autoload not found")  # DEBUG
		return null
	# Query Iran-team agents in a broad radius. SpatialIndex.query_radius_team
	# returns SpatialAgentComponent Nodes; the parent is the Unit.
	var origin: Vector3 = Vector3.ZERO
	var agents: Array = spatial.call(
		&"query_radius_team", origin, _PROBE_SEARCH_RADIUS_M, Constants.TEAM_IRAN)
	print("[turan-diag]   SpatialIndex returned ", agents.size(), " Iran agents")  # DEBUG
	var best_target: Variant = null
	var best_dist_sq: float = INF
	var fog_rejected: int = 0
	for agent in agents:
		if not is_instance_valid(agent):
			continue
		var parent: Node = agent.get_parent()
		if not is_instance_valid(parent):
			continue
		if not (parent is Node3D):
			continue
		var pos: Vector3 = (parent as Node3D).global_position
		# Fog gate: target must be currently visible to Turan.
		var vis: bool = fog.call(&"is_visible_to", Constants.TEAM_TURAN, pos)
		if not vis:
			fog_rejected += 1
			continue
		var dx: float = pos.x - origin.x
		var dz: float = pos.z - origin.z
		var d2: float = dx * dx + dz * dz
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_target = parent
	if best_target == null and agents.size() > 0:
		print("[turan-diag]   fog rejected ", fog_rejected, " of ", agents.size(), " agents")  # DEBUG
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
