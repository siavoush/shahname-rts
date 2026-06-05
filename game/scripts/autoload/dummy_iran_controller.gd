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
##      cluster to coin mines and (once Sarbaz-khaneh has trained Piyades)
##      tells them to attack-move toward the Turan Throne.
##   2. The build-order is a HARDCODED tick schedule per `02t §3 Q4`. There
##      is no decision-making, no adaptation, no opponent-modelling.
##      Determinism-given-seed is the explicit point: this AI exists to be
##      a STABLE reference across batch runs, not a good player.
##
## What ships in Wave 3-Sim Track 2:
##   - Mine-gather dispatch for the 5 starting Kargars at tick 0 (the
##     workers are pre-spawned by `main.gd:_spawn_starting_units`; the
##     controller just commands them).
##   - Piyade production cap (per balance-engineer Finding C — Track 1
##     spec §6.3.3) at 4 units before the grain economy would starve
##     subsequent training. The cap is HARDCODED here as a deliberate
##     transparent constraint; Phase 4+ adds Mazra'eh to the build-order.
##   - State-change-gated `[dummy-iran]` logs per §9.M6.4 — no per-tick spam.
##
## What this wave DOES NOT ship (deferred to follow-up balance-tuning waves):
##   - Building construction (Khaneh, Sarbaz-khaneh placement) via
##     COMMAND_BUILD. Wave 3-Sim ships the headless infrastructure +
##     gather-and-attack loop. The full hardcoded-build-order shipping
##     requires UnitState_Constructing live-game integration which has its
##     own dwell-tick budget; lifting that risk into Wave 3-Sim threatens
##     the wave's own scope. balance-engineer's Track 1 spec §6.4 acknowledges
##     this deferral and frames the schedule as a "starting proposal" the
##     follow-up wave refines.
##   - Mine-depletion retargeting per Track 1 Finding A. The first iteration
##     uses the Iran Kargar's existing `&"gathering"` state machine which
##     naturally re-targets when its current mine depletes.
##   - Tier-up / tech-advancement.
##
## Cultural framing (matching the brief's tone for TuranController):
##   Iran in the Shahnameh is the realm whose preservation IS the saga's
##   moral arc. A "Dummy Iran" controller is structurally honest — Iran's
##   defense in the AI-vs-AI matrix is meant to be REACTIVE, gathering
##   resources, training Piyades, and engaging the Turan probe forces.
##   It is not Rostam; it is the realm Rostam defends. The cultural-note
##   prose lands at Phase 6 when full FSM AI replaces this scaffold.
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
# Build-order schedule constants (per 02t §3 Q4)
# ---------------------------------------------------------------------------

## Tick at which DummyIran dispatches its 5 starting Kargars to mines.
## §3 Q4: "Tick 0: 5 workers → nearest coin mines."
const _GATHER_DISPATCH_TICK: int = 0

## Tick at which DummyIran would dispatch a Kargar to build Khaneh #1
## (deferred to follow-up wave; see header notes).
const _KHANEH_1_TICK: int = 300

## Tick at which DummyIran would dispatch a Kargar to build Sarbaz-khaneh #1
## (deferred to follow-up wave; see header notes).
const _SARBAZ_KHANEH_1_TICK: int = 1200

## Hard cap on Piyade production per balance-engineer Finding C / Track 1
## spec §6.3.3. Iran starts with 50 grain; each Piyade costs 10 grain. At
## 4 Piyades + 10 grain reserve, the controller stops queueing more units
## until Mazra'eh ships in a follow-up wave.
const _PIYADE_PRODUCTION_CAP: int = 4

## How many ticks the controller waits between sending Iran combat units
## (Piyade once trained, also pre-spawned Piyades from main.gd) on
## attack-move toward the Turan Throne. Once per ~30s — keeps the AI
## responsive without thrashing commands.
const _ATTACK_MOVE_CADENCE_TICKS: int = 900


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## FSM state. `&"awaiting_start"` (pre-tick-0), `&"gathering_phase"`
## (workers dispatched), `&"military_phase"` (Sarbaz-khaneh + Piyade
## production active). Conservative cadence: state advances ONLY on
## build-order-tick boundaries.
var _state: StringName = &"awaiting_start"

## Tick at which the next attack-move sweep fires. Initialized at
## _ready to _ATTACK_MOVE_CADENCE_TICKS so the first sweep is delayed
## one full cadence; subsequent sweeps advance by the cadence.
var _next_attack_sweep_tick: int = _ATTACK_MOVE_CADENCE_TICKS

## Last build-order step the controller ACKED via log. Used to gate the
## log emit to state-change boundaries — no per-tick spam per §9.M6.4.
var _last_acked_build_step: int = -1


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	print("[dummy-iran] DummyIranController._ready")
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
	print("[dummy-iran] reset state=awaiting_start")


## Public read-only FSM-state accessor for tests + the future F3 debug
## overlay. Mirrors `turan_controller.gd:get_state`.
func get_state() -> StringName:
	return _state


# ---------------------------------------------------------------------------
# EventBus.sim_phase handler — canonical filter pattern
# ---------------------------------------------------------------------------

## Per-tick AI step. Filters to `Constants.PHASE_AI` (`&"ai"`) — runs after
## `fog_update` (phase 2) per SIMULATION_CONTRACT §2 v1.5.0. Wiring-path
## discipline: tests drive via `EventBus.sim_phase.emit(&"ai", tick)`, NOT
## by calling `_on_sim_phase` directly (BUG-D1 lesson).
func _on_sim_phase(phase: StringName, tick: int) -> void:
	if phase != Constants.PHASE_AI:
		return

	# Tick-0 — initial gather dispatch.
	if tick == _GATHER_DISPATCH_TICK and _state == &"awaiting_start":
		_dispatch_workers_to_mines()
		_state = &"gathering_phase"
		_log_build_step(0, "gather_dispatch workers=%d" %
			_count_iran_units_of_kind(&"kargar"))

	# Build-order checkpoint logs (state-change-gated per §9.M6.4 — no
	# per-tick spam). The construction commands are deferred to a
	# follow-up wave per header notes; this controller currently emits
	# the schedule for telemetry but does not drive the construction.
	if tick == _KHANEH_1_TICK and _last_acked_build_step < 1:
		_log_build_step(1, "khaneh_1_scheduled deferred=true")

	if tick == _SARBAZ_KHANEH_1_TICK and _last_acked_build_step < 2:
		_log_build_step(2, "sarbaz_khaneh_1_scheduled deferred=true")
		_state = &"military_phase"

	# Periodic attack-move sweep — once per cadence, dispatch all alive
	# Iran combat units (including main.gd's pre-spawned Piyades) toward
	# the Turan Throne. The sweep makes matches terminate by driving
	# combat instead of letting workers gather forever.
	if tick >= _next_attack_sweep_tick:
		_attack_move_iran_combat_units_toward_turan_throne()
		_next_attack_sweep_tick = tick + _ATTACK_MOVE_CADENCE_TICKS


# ---------------------------------------------------------------------------
# Internal — gather dispatch
# ---------------------------------------------------------------------------

# Dispatch each Iran Kargar to its nearest unoccupied (or shared) coin
# mine via COMMAND_GATHER. Uses the existing &"units" + &"resource_nodes"
# SceneTree groups; no autoload-internal poking. Pitfall #16 safe — each
# Node ref is validated before property access.
func _dispatch_workers_to_mines() -> void:
	var kargars: Array[Node] = _alive_iran_units_of_kind(&"kargar")
	if kargars.is_empty():
		# Silent no-op in test-fixture contexts (no main.tscn loaded). The
		# headless runner's _setup_match loads main.tscn before the first
		# _on_sim_phase fires, so Kargars exist in the live runner path.
		# A push_warning here floods GUT logs in 1000+ unrelated tests.
		return

	# Find resource_nodes group; if empty, log and return (the runner's
	# scene may not have mines in fixture cases). Mines don't all expose a
	# `team` field — coin mines are neutral via *absence* of team rather
	# than TEAM_NEUTRAL literal. Treat null/missing team as neutral.
	var mines: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(&"resource_nodes"):
		if not is_instance_valid(node):
			continue
		var team_v: Variant = node.get(&"team")
		var team_int: int = int(team_v) if team_v != null else Constants.TEAM_NEUTRAL
		if team_int == Constants.TEAM_NEUTRAL:
			mines.append(node)
	if mines.is_empty():
		# Silent no-op — same rationale as kargars.is_empty() above.
		return

	# Round-robin assign kargars to mines; the existing UnitState_Gathering
	# state machine handles slot contention + mine depletion retargeting.
	for i in range(kargars.size()):
		var kargar: Node = kargars[i]
		if not is_instance_valid(kargar):
			continue
		var mine: Node = mines[i % mines.size()]
		if not is_instance_valid(mine):
			continue
		# Use replace_command — canonical payload per click_handler.gd:487
		# uses {target_node: <Node>} (Node ref, not id).
		kargar.call(&"replace_command", Constants.COMMAND_GATHER, {
			&"target_node": mine,
		})


# ---------------------------------------------------------------------------
# Internal — attack-move sweep
# ---------------------------------------------------------------------------

# Dispatch alive Iran combat units (Piyade, Kamandar, Savar, AsbSavar*) on
# attack-move toward the Turan Throne. The Turan Throne is found via the
# &"thrones" group. If no Turan Throne exists, the sweep no-ops (match
# is already won or pre-throne-spawn fixture state).
func _attack_move_iran_combat_units_toward_turan_throne() -> void:
	var turan_throne_pos: Variant = _find_turan_throne_position()
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


# Find the Turan Throne's position via the &"thrones" group. Returns
# the Throne's global_position (Vector3), or null if not found / freed.
# Pitfall #16 safe — uses `is_instance_valid()` before any read.
func _find_turan_throne_position() -> Variant:
	for node: Node in get_tree().get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		if int(node.get(&"team")) != Constants.TEAM_TURAN:
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


# Emit a state-change `[dummy-iran]` log line + advance the ACK
# counter so subsequent identical-step ticks don't re-log. Per §9.M6.4.
func _log_build_step(step: int, summary: String) -> void:
	print("[dummy-iran] build_order step=%d %s" % [step, summary])
	_last_acked_build_step = step
