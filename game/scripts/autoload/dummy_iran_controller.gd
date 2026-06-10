extends Node
##
## DummyIranController — Wave 3-Sim reference AI for the Iran faction.
##
## Mirrors TuranController's autoload + EventBus.sim_phase wiring shape
## (canonical pattern per `turan_controller.gd:140` and per the post-BUG-D1
## convention at `fog_system.gd`). Filters `Constants.PHASE_AI` like
## TuranController. Distinct from TuranController in TWO load-bearing ways:
##
##   1. Iran has an ECONOMY. DummyIran dispatches the Iran Kargar starting
##      cluster to coin mines, executes the canonical build-order (Khaneh →
##      Sarbaz-khaneh → Mazra'eh), trains Piyades, and sends Iran combat
##      units on attack-move toward the Turan Throne.
##   2. The build-order is a HARDCODED tick schedule per `02t §3 Q4` +
##      `docs/AI_VS_AI_RESULT_FORMAT.md §6.4`. There is no decision-making,
##      no adaptation, no opponent-modelling. Determinism-given-seed is the
##      explicit point: this AI exists to be a STABLE reference across
##      batch runs, not a good player.
##
## What ships in Wave-B3 (review finding GP-5 — replaces the Wave 3-Sim
## checkpoint-log-only stubs):
##   - Mine-gather dispatch for the 5 starting Kargars at tick 0, unified
##     into the idle-worker re-dispatch sweep (see _redispatch_idle_workers).
##   - REAL build-order execution via the SAME command-queue path the
##     player uses: `worker.replace_command(Constants.COMMAND_CONSTRUCT,
##     {building_kind, target_position})` — payload shape matches
##     BuildPlacementHandler.process_confirm_click_hit exactly. The sim
##     cannot distinguish AI-issued from player-issued construction.
##   - Deterministic placement: fixed offset ring around the Iran Throne,
##     each candidate validated via BuildPlacementHandler.
##     is_placement_geometry_valid — the SAME rule the player's ghost +
##     confirm-click use. Invalid spots step to the next offset.
##   - Affordability gate BEFORE issuing each build step (ResourceSystem
##     coin/grain reads vs BalanceData.buildings[kind] costs). Unaffordable
##     at the scheduled tick → retry next AI tick with a state-change-gated
##     wait log (§9.M6.4).
##   - Piyade training: every AI tick the controller polls Iran
##     Sarbaz-khanehs with `is_ready_to_produce` (the established Stage-2
##     operational surface — chosen over construction_finalized
##     subscription because the controller never holds the Building ref:
##     the worker's UnitState_Constructing instantiates it; polling the
##     &"buildings" group is Pitfall-#16-safe by construction) and calls
##     `request_train(&"piyade")`. request_train's own validation chain
##     (single-slot, affordability, pop-cap) gates retries; rejection is
##     communicated via its bool return per its contract, so denied
##     requests are NOT logged (the accepted-request log + ResourceSystem
##     change logs carry the telemetry).
##   - Piyade production cap (per balance-engineer Finding C / §6.3.3) at
##     4 units while no operational Mazra'eh exists. Once the scheduled
##     Mazra'eh completes (is_gatherable flips at Stage 2), the cap LIFTS
##     permanently (latched): training continues whenever affordable —
##     grain affordability inside request_train becomes the binding
##     constraint, which is the simplest defensible rule now that grain
##     income exists. Mazra'eh destruction post-lift does NOT re-impose
##     the cap (grain affordability still gates).
##   - Worker management: UnitState_Constructing routes the builder back
##     to Idle on completion (unit_state_constructing.gd:_request_idle);
##     the idle-worker sweep re-dispatches any idle Iran Kargar to gather
##     on the next AI tick. Gather targets prioritize an operational Iran
##     Mazra'eh with a free extract slot (grain income for post-cap
##     training), then neutral still-gatherable coin mines (the
##     is_gatherable filter handles mine-depletion retargeting when the
##     worker idles out of a depleted mine's gather loop).
##   - State-change-gated `[dummy-iran]` logs per §9.M6.4 — no per-tick spam.
##
## What this controller still DOES NOT ship (follow-up waves):
##   - Khaneh #2 at tick 3600 (§6.4 optional step — first batch data
##     decides whether pop-cap 5 from Khaneh #1 actually binds).
##   - Tier-up / tech-advancement / adaptive behavior.
##
## Cultural framing (matching the brief's tone for TuranController):
##   Iran in the Shahnameh is the realm whose preservation IS the saga's
##   moral arc. A "Dummy Iran" controller is structurally honest — Iran's
##   defense in the AI-vs-AI matrix is meant to be REACTIVE, gathering
##   resources, raising the khaneh and the sarbaz-khaneh, training Piyades,
##   and engaging the Turan probe forces. It is not Rostam; it is the realm
##   Rostam defends. The cultural-note prose lands at Phase 6 when full
##   FSM AI replaces this scaffold.
##
## Pitfall #16 safety (MANDATORY per §9.L11): Iran unit references are
## stored as untyped Variant + validated with `is_instance_valid()` before
## any property read. Iran units can die between commands — Turan combat
## can kill the commanded worker / Piyade between issuing a command and
## the next AI tick. The safety pattern mirrors TuranController.
##
## Pitfall #17 test-discipline (MANDATORY): tests use `free()` not
## `queue_free()` + await pattern. Wiring-path tests drive via
## `EventBus.sim_phase.emit(&"ai", N)` per BUG-D1 lesson.

# ---------------------------------------------------------------------------
# Reused player-flow surfaces (preloaded by path to dodge the class_name
# registry race — Pitfall #13)
# ---------------------------------------------------------------------------

## Placement-validity SSOT — the static is_placement_geometry_valid on the
## player's BuildPlacementHandler (Wave-B3 extraction). One rule, two
## consumers; the AI cannot drift from the player's placement legality.
const _BuildPlacementHandlerScript: Script = preload(
	"res://scripts/input/build_placement_handler.gd")

## Mazra'eh script — for the fertile-tile placement check the player's
## build menu applies to the Mazra'eh button (permissive no-op until
## TerrainSystem ships; included for parity with the player flow).
const _MazraehScript: Script = preload(
	"res://scripts/world/buildings/mazraeh.gd")


# ---------------------------------------------------------------------------
# Build-order schedule constants (per 02t §3 Q4 + AI_VS_AI_RESULT_FORMAT §6.4)
#
# Deliberately HARDCODED here (not BalanceData): the reference AI's schedule
# is a determinism anchor for batch-run comparability, not a designer-tuned
# balance dial. Per the header — this AI exists to be stable, not good.
# ---------------------------------------------------------------------------

## Tick at which DummyIran dispatches its 5 starting Kargars to mines.
## §3 Q4: "Tick 0: 5 workers → nearest coin mines."
const _GATHER_DISPATCH_TICK: int = 0

## Tick at which DummyIran dispatches a Kargar to build Khaneh #1.
## §6.4: feasible (150 starting coin + early income vs 50-coin cost).
const _KHANEH_1_TICK: int = 300

## Tick at which DummyIran dispatches a Kargar to build Sarbaz-khaneh #1.
## §6.4: feasible (~206-338 coin available vs 100-coin cost).
const _SARBAZ_KHANEH_1_TICK: int = 1200

## Tick at which DummyIran dispatches a Kargar to build Mazra'eh #1 —
## the §6.3.3 recommendation to break the 4-Piyade grain cap (50 starting
## grain / 10 grain per Piyade leaves no headroom without grain income).
##
## Why 2400: §6.4 keeps tick 2400 as the "Iran has 1-2 Piyades" schedule
## checkpoint, and the §6.2 affordability table shows a comfortable coin
## surplus there (~136+ coin low-estimate after Piyade #2's coin cost vs
## the Mazra'eh's 60-coin cost). The step ALSO gates on
## _MAZRAEH_MIN_PIYADES below so "after Piyade #2" holds literally even
## when training slips (affordability-retry pushes the step, never skips).
const _MAZRAEH_1_TICK: int = 2400

## Piyade train-requests that must have been ACCEPTED before the Mazra'eh
## step fires ("one Mazra'eh after Piyade #2" per the wave brief).
## Counted at request-accept time (resources committed — the controller's
## deterministic counter); the spawn tick trails by a fixed 90-tick dwell
## and adds no decision value.
const _MAZRAEH_MIN_PIYADES: int = 2

## Hard cap on Piyade production per balance-engineer Finding C / Track 1
## spec §6.3.3, in force while NO operational Iran Mazra'eh exists. Iran
## starts with 50 grain; each Piyade costs 10 grain. At 4 Piyades + 10
## grain reserve, the controller stops queueing until the scheduled
## Mazra'eh (Stage 2 complete) lifts the cap — see _drive_piyade_training.
const _PIYADE_PRODUCTION_CAP: int = 4

## How many ticks the controller waits between sending Iran combat units
## (Piyade once trained, also pre-spawned Piyades from main.gd) on
## attack-move toward the Turan Throne. Once per ~30s — keeps the AI
## responsive without thrashing commands.
const _ATTACK_MOVE_CADENCE_TICKS: int = 900

## Deterministic placement-offset ring around the Iran Throne, tried in
## order; the first offset passing the player-flow geometry rule wins.
## 6m spacing clears the shared 2.5m overlap threshold (see
## BuildPlacementHandler.is_placement_geometry_valid) with margin on both
## sides of two adjacent footprints; the 12m outer ring is fallback for a
## crowded inner ring. Throne at (0,0,-32) on the MVP map → all candidates
## stay far from the mine cluster at Z≈0..15.
const _BUILD_OFFSETS_M: Array[Vector3] = [
	Vector3(6.0, 0.0, 0.0), Vector3(-6.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -6.0),
	Vector3(6.0, 0.0, 6.0), Vector3(-6.0, 0.0, 6.0),
	Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -6.0),
	Vector3(12.0, 0.0, 0.0), Vector3(-12.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 12.0), Vector3(0.0, 0.0, -12.0),
	Vector3(12.0, 0.0, 6.0), Vector3(-12.0, 0.0, 6.0),
	Vector3(12.0, 0.0, -6.0), Vector3(-12.0, 0.0, -6.0),
]

## The build-order as ordered steps, processed strictly head-first (a
## waiting step blocks later steps — build-ORDER semantics). Kind tokens
## are the canonical BalanceData.buildings keys, pinned to the
## UnitState_Constructing._BUILDING_SCENE_PATHS table (the same keys the
## player's build menu dispatches).
##   step:         build-step number for the [dummy-iran] build_order log.
##   tick:         earliest tick the step may fire.
##   kind:         building kind for the COMMAND_CONSTRUCT payload.
##   min_piyades:  accepted train-requests required before the step fires.
const _BUILD_ORDER: Array[Dictionary] = [
	{&"step": 1, &"tick": _KHANEH_1_TICK, &"kind": &"khaneh",
		&"min_piyades": 0},
	{&"step": 2, &"tick": _SARBAZ_KHANEH_1_TICK, &"kind": &"sarbaz_khaneh",
		&"min_piyades": 0},
	{&"step": 3, &"tick": _MAZRAEH_1_TICK, &"kind": &"mazraeh",
		&"min_piyades": _MAZRAEH_MIN_PIYADES},
]


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## FSM state. `&"awaiting_start"` (pre-tick-0), `&"gathering_phase"`
## (workers dispatched, civic build-order running), `&"military_phase"`
## (Sarbaz-khaneh #1 issued — military production pipeline active).
## gathering→military advances when the Sarbaz-khaneh COMMAND_CONSTRUCT is
## actually ISSUED (not merely scheduled) so the state name reflects what
## the controller has truly done.
var _state: StringName = &"awaiting_start"

## Tick at which the next attack-move sweep fires. Initialized at
## _ready to _ATTACK_MOVE_CADENCE_TICKS so the first sweep is delayed
## one full cadence; subsequent sweeps advance by the cadence.
var _next_attack_sweep_tick: int = _ATTACK_MOVE_CADENCE_TICKS

## Last build-order step the controller ACKED via log. Used to gate the
## log emit to state-change boundaries — no per-tick spam per §9.M6.4.
var _last_acked_build_step: int = -1

## Index of the head (next pending) step in _BUILD_ORDER. Advances only
## when the step's COMMAND_CONSTRUCT is actually issued.
var _next_build_step: int = 0

## Count of ACCEPTED request_train(&"piyade") calls this match. Drives the
## production cap and the Mazra'eh step's min_piyades gate.
var _piyades_trained: int = 0

## Latched true the first AI tick an operational Iran Mazra'eh is observed
## (is_gatherable == true). Once lifted, the Piyade cap never re-imposes —
## grain affordability inside request_train is the binding constraint.
var _piyade_cap_lifted: bool = false

## §9.M6.4 state-change gates — last logged wait signature per channel.
## A repeat of the same signature on subsequent ticks does NOT re-log;
## the gate clears when the waited-on action finally fires.
var _last_build_wait_sig: String = ""
var _last_training_wait_sig: String = ""
var _last_sweep_wait_sig: String = ""

## Session-11 hotfix (review ARCH-2) — headless-batch gate. This controller
## is an autoload and therefore boots in EVERY game, including live player
## sessions, where an active dummy AI would seize the player's workers at
## tick 0 and clobber their commands with attack-move sweeps every 900
## ticks. `enabled` gates the sim_phase handler; it is true ONLY under the
## `--headless-batch` boot (the same cmdline-user-args sentinel main.gd
## uses to spawn HeadlessMatchRunner). Tests set `enabled = true`
## explicitly. reset() deliberately does NOT touch it — enablement is
## boot-scoped, not match-scoped.
var enabled: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# ARCH-2 gate: active ONLY under the headless-batch boot. In a live
	# player game the controller stays connected but inert (early-return
	# in _on_sim_phase) so the wiring path is identical in both modes and
	# tests can flip `enabled` without re-wiring (BUG-D1 lesson).
	enabled = OS.get_cmdline_user_args().has("--headless-batch")
	print("[dummy-iran] DummyIranController._ready enabled=%s" % str(enabled))
	# Canonical pattern (per turan_controller.gd:140): subscribe to
	# EventBus.sim_phase + filter to PHASE_AI inside the handler.
	# SimClock does NOT declare per-phase signals; the bus is the seam.
	# BUG-D1 lesson — wiring path is load-bearing.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)


## Disconnect at tree exit so a freed controller doesn't keep handling
## phase signals. Symmetric with _ready; mirrors turan_controller.gd:146.
func _exit_tree() -> void:
	if EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.disconnect(_on_sim_phase)


# ---------------------------------------------------------------------------
# Public test API — mirrors TuranController surface
# ---------------------------------------------------------------------------

## Reset to pristine state. Used by HeadlessMatchRunner between matches +
## by GUT before_each / after_each. Same shape as `turan_controller.gd:158`.
func reset() -> void:
	_state = &"awaiting_start"
	_next_attack_sweep_tick = _ATTACK_MOVE_CADENCE_TICKS
	_last_acked_build_step = -1
	_next_build_step = 0
	_piyades_trained = 0
	_piyade_cap_lifted = false
	_last_build_wait_sig = ""
	_last_training_wait_sig = ""
	_last_sweep_wait_sig = ""
	print("[dummy-iran] reset state=awaiting_start")


## Public read-only FSM-state accessor for tests + the future F3 debug
## overlay. Mirrors `turan_controller.gd:get_state`.
func get_state() -> StringName:
	return _state


## Accepted Piyade train-request count — read by tests + future telemetry.
func get_piyades_trained() -> int:
	return _piyades_trained


# ---------------------------------------------------------------------------
# EventBus.sim_phase handler — canonical filter pattern
# ---------------------------------------------------------------------------

## Per-tick AI step. Filters to `Constants.PHASE_AI` (`&"ai"`) — runs after
## `fog_update` (phase 2) per SIMULATION_CONTRACT §2 v1.5.0. Wiring-path
## discipline: tests drive via `EventBus.sim_phase.emit(&"ai", tick)`, NOT
## by calling `_on_sim_phase` directly (BUG-D1 lesson).
func _on_sim_phase(phase: StringName, tick: int) -> void:
	# ARCH-2 gate — inert outside --headless-batch boots (live player
	# games must never have the dummy AI fighting the player for control).
	if not enabled:
		return
	if phase != Constants.PHASE_AI:
		return

	# Match start — advance out of awaiting_start at the first AI tick at
	# or after the dispatch tick (>= not == so a runner that skips tick 0
	# can never strand the controller pre-start forever).
	if tick >= _GATHER_DISPATCH_TICK and _state == &"awaiting_start":
		_state = &"gathering_phase"
		_log_build_step(0, "gather_dispatch workers=%d" %
			_count_iran_units_of_kind(&"kargar"))
	if _state == &"awaiting_start":
		return

	# Ordering is load-bearing: the idle-worker sweep runs BEFORE the
	# build-order step so a build command issued THIS tick (worker still
	# in &"idle" until its FSM applies the pending swap during this tick's
	# movement phase) can never be clobbered by a same-tick gather
	# re-dispatch from our own sweep.
	_redispatch_idle_workers()
	_process_build_order(tick)
	_drive_piyade_training()

	# Periodic attack-move sweep — once per cadence, dispatch all alive
	# Iran combat units (including main.gd's pre-spawned Piyades and the
	# Piyades trained above) toward the Turan Throne. The sweep makes
	# matches terminate by driving combat instead of letting workers
	# gather forever.
	if tick >= _next_attack_sweep_tick:
		_attack_move_iran_combat_units_toward_turan_throne()
		_next_attack_sweep_tick = tick + _ATTACK_MOVE_CADENCE_TICKS


# ---------------------------------------------------------------------------
# Internal — build-order execution (Wave-B3, review finding GP-5)
# ---------------------------------------------------------------------------

# Process the head build-order step. Strictly sequential: the head step
# blocks until its tick has arrived AND its piyade-gate, affordability,
# worker, and placement preconditions all pass — then the
# COMMAND_CONSTRUCT is issued through the SAME Unit.replace_command path
# the player's BuildPlacementHandler uses, with the identical payload
# shape {building_kind, target_position}. Each wait reason logs once per
# signature (§9.M6.4); retries are silent until the signature changes.
func _process_build_order(tick: int) -> void:
	if _next_build_step >= _BUILD_ORDER.size():
		return
	var step: Dictionary = _BUILD_ORDER[_next_build_step]
	if tick < int(step[&"tick"]):
		return
	var kind: StringName = step[&"kind"]
	var step_no: int = int(step[&"step"])

	# "After Piyade #N" gate (Mazra'eh step). Counted on accepted
	# train-requests — see _MAZRAEH_MIN_PIYADES doc.
	var min_piyades: int = int(step[&"min_piyades"])
	if _piyades_trained < min_piyades:
		_log_build_wait("step=%d kind=%s reason=awaiting_piyades" %
			[step_no, kind], " have=%d need=%d" %
			[_piyades_trained, min_piyades])
		return

	# Affordability gate BEFORE issuing (cost re-checks + deduction happen
	# again at placement inside UnitState_Constructing — this pre-screen
	# mirrors the player flow's confirm-click affordability check).
	if not _can_afford_building(kind):
		_log_build_wait("step=%d kind=%s reason=unaffordable" %
			[step_no, kind], " coin_x100=%d grain_x100=%d" % [
				ResourceSystem.coin_x100_for(Constants.TEAM_IRAN),
				ResourceSystem.grain_x100_for(Constants.TEAM_IRAN)])
		return

	var worker: Variant = _pick_build_worker()
	if worker == null:
		_log_build_wait("step=%d kind=%s reason=no_available_worker" %
			[step_no, kind])
		return

	var pos_v: Variant = _pick_build_position(kind)
	if pos_v == null:
		_log_build_wait("step=%d kind=%s reason=no_valid_placement" %
			[step_no, kind])
		return

	# Issue — canonical player payload shape per
	# build_placement_handler.gd:process_confirm_click_hit.
	worker.call(&"replace_command", Constants.COMMAND_CONSTRUCT, {
		&"building_kind": kind,
		&"target_position": pos_v,
	})
	_last_build_wait_sig = ""
	_log_build_step(step_no, "%s_issued worker_id=%d pos=%s tick=%d" % [
		String(kind), int(worker.get(&"unit_id")), str(pos_v), tick])
	_next_build_step += 1

	# FSM milestone: the military pipeline starts when the Sarbaz-khaneh
	# command is actually issued.
	if kind == &"sarbaz_khaneh" and _state != &"military_phase":
		_state = &"military_phase"
		print("[dummy-iran] state=military_phase "
			+ "trigger=sarbaz_khaneh_issued tick=%d" % tick)


# Pick the build worker deterministically: the alive Iran Kargar with the
# LOWEST unit_id whose FSM state is idle or gathering (never a worker
# mid-construction or mid-deposit — redirecting a returning worker would
# drop its carried load). Pitfall #16 safe.
func _pick_build_worker() -> Variant:
	var best: Variant = null
	var best_id: int = 0
	for kargar: Node in _alive_iran_units_of_kind(&"kargar"):
		if not is_instance_valid(kargar):
			continue
		var fsm_v: Variant = kargar.get(&"fsm")
		if fsm_v == null:
			continue
		var st: StringName = StringName(fsm_v.call(&"current_state_name"))
		if st != Constants.STATE_IDLE and st != Constants.STATE_GATHERING:
			continue
		var uid: int = int(kargar.get(&"unit_id"))
		if best == null or uid < best_id:
			best = kargar
			best_id = uid
	return best


# Pick the placement position deterministically: Iran Throne position plus
# the first _BUILD_OFFSETS_M candidate passing the player-flow geometry
# rule (BuildPlacementHandler.is_placement_geometry_valid — the SSOT).
# The Mazra'eh additionally passes the player build-menu's fertile-tile
# check (permissive no-op until TerrainSystem ships). Returns Vector3 or
# null when no throne / no valid offset exists (caller retries next tick).
func _pick_build_position(kind: StringName) -> Variant:
	var throne_pos_v: Variant = _find_throne_position(Constants.TEAM_IRAN)
	if throne_pos_v == null:
		return null
	var throne_pos: Vector3 = throne_pos_v
	for offset: Vector3 in _BUILD_OFFSETS_M:
		var pos: Vector3 = throne_pos + offset
		# Reflective static call via the preloaded Script ref — same
		# pattern as main.gd's `_UnitScript.call(&"reset_id_counter")`
		# (dodges the unsafe_method_access warning on Script-typed consts).
		if not bool(_BuildPlacementHandlerScript.call(
				&"is_placement_geometry_valid", get_tree(), pos)):
			continue
		if kind == &"mazraeh" \
				and not bool(_MazraehScript.call(&"is_valid_placement", pos)):
			continue
		return pos
	return null


# Affordability pre-screen for a build step. Costs come from
# BalanceData.buildings[kind].coin_cost / .grain_cost via the canonical
# Dictionary lookup (BUG-C1 pattern) — same SSOT UnitState_Constructing
# deducts from at placement. Both-or-neither discipline mirrors the
# player flow (BUG-B2.5).
func _can_afford_building(kind: StringName) -> bool:
	var cost_coin: int = _resolve_building_stat_int(kind, &"coin_cost")
	var cost_grain: int = _resolve_building_stat_int(kind, &"grain_cost")
	if cost_coin > 0 and ResourceSystem.coin_x100_for(
			Constants.TEAM_IRAN) < cost_coin * 100:
		return false
	if cost_grain > 0 and ResourceSystem.grain_x100_for(
			Constants.TEAM_IRAN) < cost_grain * 100:
		return false
	return true


# Canonical BalanceData Dictionary lookup (BUG-C1 pattern):
# BalanceData.buildings[kind].<field>, defensive fall-through to 0 on any
# failure (file / load / dict / entry / field / type). Mirrors
# building.gd:_read_bldg_stats_int parameterized by kind. Values are in
# WHOLE units (not _x100) — callers multiply by 100 to compare against
# ResourceSystem's fixed-point accessors.
func _resolve_building_stat_int(kind: StringName, field: StringName) -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null or not (stats is Resource):
		return 0
	var v: Variant = (stats as Resource).get(field)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return 0
	return int(v)


# ---------------------------------------------------------------------------
# Internal — Piyade training (Wave-B3)
# ---------------------------------------------------------------------------

# Poll Iran Sarbaz-khanehs that are ready to produce and request Piyade
# training, respecting the production cap until the Mazra'eh lifts it.
# request_train's own validation chain (produces / is_complete /
# single-slot / coin / grain / pop-cap) gates everything else; per its
# contract, rejection is communicated via the bool return — denied
# requests are deliberately NOT logged (normal during the 90-tick dwell).
func _drive_piyade_training() -> void:
	var producers: Array[Node] = []
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if not is_instance_valid(b):
			continue
		var team_v: Variant = b.get(&"team")
		if team_v == null or int(team_v) != Constants.TEAM_IRAN:
			continue
		if StringName(b.get(&"kind")) != &"sarbaz_khaneh":
			continue
		# is_ready_to_produce is SarbazKhaneh's Stage-2 operational gate
		# (sarbaz_khaneh.gd:203) — the established surface for "can this
		# building accept training requests".
		if not bool(b.get(&"is_ready_to_produce")):
			continue
		producers.append(b)
	if producers.is_empty():
		return

	# Cap-lift latch: the first operational Iran Mazra'eh permanently
	# lifts the grain-protection cap (see header).
	if not _piyade_cap_lifted and _has_operational_iran_mazraeh():
		_piyade_cap_lifted = true
		print("[dummy-iran] piyade_cap_lifted mazraeh_operational=true "
			+ "trained=%d" % _piyades_trained)

	for b: Node in producers:
		if not _piyade_cap_lifted \
				and _piyades_trained >= _PIYADE_PRODUCTION_CAP:
			_log_training_wait("piyade_cap_reached cap=%d awaiting_mazraeh"
				% _PIYADE_PRODUCTION_CAP)
			return
		if bool(b.call(&"request_train", &"piyade")):
			_piyades_trained += 1
			_last_training_wait_sig = ""
			print("[dummy-iran] train_request_accepted unit=piyade "
				+ "building_id=%d total_trained=%d" % [
					int(b.get(&"unit_id")), _piyades_trained])


# True when any Iran Mazra'eh in the world is operational (Stage 2
# complete — is_gatherable flipped true per mazraeh.gd:253). Pitfall #16
# safe group walk.
func _has_operational_iran_mazraeh() -> bool:
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if not is_instance_valid(b):
			continue
		var team_v: Variant = b.get(&"team")
		if team_v == null or int(team_v) != Constants.TEAM_IRAN:
			continue
		if StringName(b.get(&"kind")) != &"mazraeh":
			continue
		var g_v: Variant = b.get(&"is_gatherable")
		if typeof(g_v) == TYPE_BOOL and bool(g_v):
			return true
	return false


# ---------------------------------------------------------------------------
# Internal — idle-worker gather sweep (tick-0 dispatch + worker management)
# ---------------------------------------------------------------------------

# Dispatch every IDLE Iran Kargar to a gather target via COMMAND_GATHER
# (canonical payload per click_handler.gd: {target_node: <Node>}).
# Round-robin over the target list; the existing UnitState_Gathering
# state machine handles slot contention + mine-depletion retargeting.
#
# This single sweep covers BOTH the tick-0 initial dispatch (all 5
# starting Kargars are idle at tick 0) and the post-construction return
# to gathering (UnitState_Constructing routes the builder back to Idle on
# completion; the sweep re-dispatches it on the next AI tick).
#
# Pitfall #16 safe — every Node ref validated before property access.
func _redispatch_idle_workers() -> void:
	var idle_workers: Array[Node] = []
	for kargar: Node in _alive_iran_units_of_kind(&"kargar"):
		if not is_instance_valid(kargar):
			continue
		var fsm_v: Variant = kargar.get(&"fsm")
		if fsm_v == null:
			continue
		if StringName(fsm_v.call(&"current_state_name")) \
				!= Constants.STATE_IDLE:
			continue
		idle_workers.append(kargar)
	if idle_workers.is_empty():
		return

	var targets: Array[Node] = _gather_targets()
	if targets.is_empty():
		# Silent-ish no-op: fixture contexts (no main.tscn) and the
		# all-mines-depleted endgame both land here. One gated log per
		# signature change (§9.M6.4), not per tick.
		_log_sweep_wait("no_gather_targets idle_workers=%d"
			% idle_workers.size())
		return
	_last_sweep_wait_sig = ""

	for i in range(idle_workers.size()):
		var kargar: Node = idle_workers[i]
		if not is_instance_valid(kargar):
			continue
		var target: Node = targets[i % targets.size()]
		if not is_instance_valid(target):
			continue
		kargar.call(&"replace_command", Constants.COMMAND_GATHER, {
			&"target_node": target,
		})
		# Event log (a command issue is a state mutation, not per-tick
		# spam — idle workers leave &"idle" the same tick, so this line
		# fires once per dispatch event).
		print("[dummy-iran] gather_dispatch worker_id=%d target=%s" % [
			int(kargar.get(&"unit_id")), String(target.name)])


# Build the deterministic gather-target list:
#   1. Operational Iran Mazra'eh(s) with a free extract slot FIRST —
#      grain income is the post-cap training constraint (§6.3.3), and the
#      Mazra'eh has max_slots=1 so at most one worker anchors on grain.
#   2. Neutral, still-gatherable coin mines (is_gatherable=false filters
#      depleted mines — resource_node.gd flips it at depletion).
# Coin mines are neutral via *absence* of team rather than TEAM_NEUTRAL
# literal; treat null/missing team as neutral (same as the Wave 3-Sim
# dispatch this sweep replaces).
func _gather_targets() -> Array[Node]:
	var targets: Array[Node] = []
	for b: Node in get_tree().get_nodes_in_group(&"buildings"):
		if not is_instance_valid(b):
			continue
		var team_v: Variant = b.get(&"team")
		if team_v == null or int(team_v) != Constants.TEAM_IRAN:
			continue
		if StringName(b.get(&"kind")) != &"mazraeh":
			continue
		var g_v: Variant = b.get(&"is_gatherable")
		if typeof(g_v) != TYPE_BOOL or not bool(g_v):
			continue
		if int(b.call(&"occupied_slots")) >= int(b.get(&"max_slots")):
			continue
		targets.append(b)
	for node: Node in get_tree().get_nodes_in_group(&"resource_nodes"):
		if not is_instance_valid(node):
			continue
		var team_v2: Variant = node.get(&"team")
		var team_int: int = int(team_v2) if team_v2 != null \
			else Constants.TEAM_NEUTRAL
		if team_int != Constants.TEAM_NEUTRAL:
			continue
		var g_v2: Variant = node.get(&"is_gatherable")
		if typeof(g_v2) == TYPE_BOOL and not bool(g_v2):
			continue
		targets.append(node)
	return targets


# ---------------------------------------------------------------------------
# Internal — attack-move sweep
# ---------------------------------------------------------------------------

# Dispatch alive Iran combat units (Piyade, Kamandar, Savar, AsbSavar*) on
# attack-move toward the Turan Throne. The Turan Throne is found via the
# &"thrones" group. If no Turan Throne exists, the sweep no-ops (match
# is already won or pre-throne-spawn fixture state).
func _attack_move_iran_combat_units_toward_turan_throne() -> void:
	var turan_throne_pos: Variant = _find_throne_position(
		Constants.TEAM_TURAN)
	if turan_throne_pos == null:
		return

	for kind: StringName in [&"piyade", &"kamandar", &"savar",
			&"asb_savar_kamandar"]:
		for unit: Node in _alive_iran_units_of_kind(kind):
			if not is_instance_valid(unit):
				continue
			# Canonical payload per attack_move_handler.gd:182 — {target: Vector3}.
			unit.call(&"replace_command", Constants.COMMAND_ATTACK_MOVE, {
				&"target": turan_throne_pos,
			})


# Find a team's Throne position via the &"thrones" group. Returns the
# Throne's global_position (Vector3), or null if not found / freed.
# Pitfall #16 safe — uses `is_instance_valid()` before any read; team is
# read defensively (fixture Node3Ds may not expose the field).
func _find_throne_position(team: int) -> Variant:
	for node: Node in get_tree().get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		var team_v: Variant = node.get(&"team")
		if team_v == null or int(team_v) != team:
			continue
		var node3d: Node3D = node as Node3D
		if node3d == null:
			continue
		return node3d.global_position
	return null


# ---------------------------------------------------------------------------
# Internal — group queries
# ---------------------------------------------------------------------------

# Return all alive Iran units of the given unit_type. Filters by
# `is_instance_valid` + `team` + `unit_type`. Pitfall #16 safe.
func _alive_iran_units_of_kind(kind: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != Constants.TEAM_IRAN:
			continue
		if StringName(node.get(&"unit_type")) != kind:
			continue
		out.append(node)
	return out


# Count alive Iran units of the given unit_type. Convenience wrapper for
# the state-change log emit.
func _count_iran_units_of_kind(kind: StringName) -> int:
	return _alive_iran_units_of_kind(kind).size()


# ---------------------------------------------------------------------------
# Internal — §9.M6.4 state-change-gated logging
# ---------------------------------------------------------------------------

# Emit a state-change `[dummy-iran]` log line + advance the ACK
# counter so subsequent identical-step ticks don't re-log. Per §9.M6.4.
func _log_build_step(step: int, summary: String) -> void:
	print("[dummy-iran] build_order step=%d %s" % [step, summary])
	_last_acked_build_step = step


# Build-order wait log, gated on the wait-reason SIGNATURE (which omits
# fluctuating values like resource balances so income ticks don't re-log
# the same wait). `detail` carries the volatile diagnostics, printed only
# when the signature first changes.
func _log_build_wait(signature: String, detail: String = "") -> void:
	if signature == _last_build_wait_sig:
		return
	_last_build_wait_sig = signature
	print("[dummy-iran] build_order_wait %s%s" % [signature, detail])


# Training wait log — same gate shape as _log_build_wait.
func _log_training_wait(signature: String) -> void:
	if signature == _last_training_wait_sig:
		return
	_last_training_wait_sig = signature
	print("[dummy-iran] training_wait %s" % signature)


# Gather-sweep wait log — same gate shape as _log_build_wait.
func _log_sweep_wait(signature: String) -> void:
	if signature == _last_sweep_wait_sig:
		return
	_last_sweep_wait_sig = signature
	print("[dummy-iran] gather_sweep_wait %s" % signature)
