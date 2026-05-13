extends Node
##
## FarrDrainDispatcher — resolves unit-death triggers to Farr-drain keys and
## dispatches the drain through FarrSystem's chokepoint.
##
## Source references:
##   - 02f_PHASE_3_KICKOFF.md §2 Open Space resolution (2026-05-13): the
##     drain-rate table lives in BalanceData.farr.drain_rates as positive
##     magnitudes; the dispatcher applies the negative sign at the call site.
##   - 01_CORE_MECHANICS.md §4 — Farr drain spec (worker killed idle: -1,
##     worker killed mid-task: -0.5).
##   - CLAUDE.md — apply_farr_change is the single sanctioned Farr mutation;
##     this dispatcher is its disciplined producer.
##
## Subscription choice (LOAD-BEARING — see Open Space note in kickoff §2):
##   This handler subscribes to EventBus.unit_health_zero, NOT unit_died.
##
##   Reason: the StateMachine's death-preempt path (Contract §4.2) listens for
##   unit_health_zero and force-transitions the unit to &"dying" — which means
##   any handler reading `unit.fsm.current.id` AFTER that swap would always
##   see &"dying", collapsing the two drain keys (worker_killed_idle vs
##   worker_killed_during_gather) into one. By subscribing to
##   unit_health_zero, we read the FSM state PRE-swap.
##
##   The order rests on two facts:
##     1. EventBus.unit_health_zero is emitted BEFORE unit_died inside
##        HealthComponent._apply_damage_x100 (see health_component.gd lines
##        237-238 — order documented as load-bearing in that file's header).
##     2. Godot signal-handler invocation order is connect() order. This
##        autoload connects in _ready() at engine boot — before any unit
##        spawns and its StateMachine.init() connects to the same signal.
##        So this handler runs first; reading fsm.current.id sees the
##        pre-Dying state.
##
##   If a future refactor inverts the emit order or breaks the autoload-vs-
##   per-unit-StateMachine connect ordering, switch to the alternative
##   mechanism: have the StateMachine stamp `last_alive_state_id` on the unit
##   BEFORE applying the Dying transition, and read that field here. That
##   alternative is documented but not currently active.
##
## Why a separate autoload (not folded into FarrSystem):
##   - FarrSystem already subscribes to EventBus.unit_died with a different,
##     legacy Farr-drain path (cause-string suffix parsing from Phase 2
##     session 1 wave 2A). Folding the new dispatcher into FarrSystem would
##     duplicate handlers on overlapping signals and require carefully
##     maintaining "this listener does the new path, that listener does the
##     legacy path." Cleaner to land the new dispatcher as its own autoload
##     and (in a later phase) retire the cause-string suffix path entirely.
##   - The dispatcher has zero owned state — it's pure routing. A standalone
##     autoload is the lightest container for that. Tests can clear and
##     re-arm the subscription cleanly.
##
## Dispatch table:
##   FSM state.id          unit_type   → drain key
##   ───────────────────────────────────────────────────────────────────────
##   &"gathering"          (any)       → &"worker_killed_during_gather"
##   &"returning"          (any)       → &"worker_killed_during_gather"
##   &"idle"               &"kargar"   → &"worker_killed_idle"
##   anything else                     → no drain
##
##   Phase 3 wave 1B fires for Kargar only (idle, gathering, returning). The
##   non-kargar idle case is intentionally not drained — a Piyade standing
##   idle in the field that gets killed shouldn't trigger the worker-loss
##   penalty.
##
## Resolving the dying unit:
##   The signal payload carries unit_id (int) — not a Node ref. There's no
##   global UnitRegistry yet (LATER L1 per ARCHITECTURE §7); we walk the
##   scene tree to find the unit by unit_id. The walk is O(N) over live
##   units per death event; for Phase 3's expected match scale (<100 units)
##   this is negligible. When UnitRegistry ships, swap to a direct lookup.

# Cached BalanceData reference for drain-rate lookups. Loaded lazily on first
# resolve so the autoload doesn't crash at boot if balance.tres is missing
# (test scenes loading the autoload in isolation).
var _balance_data: Resource = null


# === Lifecycle ==============================================================

func _ready() -> void:
	# Connect at autoload init — fires before any unit's StateMachine connects
	# to the same signal. See header for the load-bearing ordering rationale.
	if not EventBus.unit_health_zero.is_connected(_on_unit_health_zero):
		EventBus.unit_health_zero.connect(_on_unit_health_zero)


# === Signal handler =========================================================

# Resolve the dying unit, read its pre-Dying FSM state, dispatch the drain
# through FarrSystem.apply_farr_change.
#
# This handler runs DURING the combat phase (HealthComponent.take_damage is
# called from CombatComponent._sim_tick, which runs in the &"combat" phase).
# That means SimClock.is_ticking() is true here, satisfying
# apply_farr_change's on-tick assert by construction.
func _on_unit_health_zero(unit_id: int) -> void:
	var unit: Node = _find_unit_by_id(unit_id)
	if unit == null:
		return  # Unit freed before we could resolve — drop the drain silently.
	# Read the FSM state PRE-swap. The StateMachine's death-preempt handler
	# may or may not have already run by this point, depending on connection
	# order — see header rationale for why we expect to run first.
	var state_id: StringName = _read_fsm_state(unit)
	var unit_type: StringName = _read_unit_type(unit)
	var drain_key: StringName = _resolve_drain_key(state_id, unit_type)
	if drain_key == &"":
		return  # No drain configured for this state/type combination.
	var magnitude: float = _lookup_drain_magnitude(drain_key)
	if magnitude <= 0.0:
		return  # Key not in drain_rates, or magnitude misconfigured.
	# Fire the drain through the chokepoint. Note the negative sign: drain
	# magnitudes are stored positive; we apply the sign here at the call site.
	FarrSystem.apply_farr_change(-magnitude, String(drain_key), unit)


# === Dispatch table =========================================================
# Pure function (testable in isolation): given the dying unit's pre-Dying FSM
# state.id and unit_type, return the drain key for BalanceData.farr.drain_rates
# (or &"" for "no drain").
#
# Made non-private (no underscore) so the corresponding unit test can exercise
# the resolution table without instantiating a unit / harness — same pattern
# as other "pure routing" helpers in the codebase.
func resolve_drain_key(state_id: StringName, unit_type: StringName) -> StringName:
	return _resolve_drain_key(state_id, unit_type)


func _resolve_drain_key(state_id: StringName, unit_type: StringName) -> StringName:
	# Gathering / Returning: a Kargar mid-task dying. Per spec §4.3 + Open
	# Space, this is the lighter -0.5 drain (the worker was contributing;
	# losing them mid-task hurts less than losing one standing idle).
	if state_id == &"gathering" or state_id == &"returning":
		return &"worker_killed_during_gather"
	# Idle Kargar: the classic "worker killed defenseless" drain (-1 per spec
	# §4.3). Other unit types in idle don't trigger — only workers count
	# under this rule.
	if state_id == &"idle" and unit_type == &"kargar":
		return &"worker_killed_idle"
	# All other states / types: no drain. Phase 3 specifically does NOT drain
	# for combat-unit deaths (a Piyade dying in combat is normal expected
	# attrition; the snowball-protection drain in §4.3 covers asymmetric-
	# strength engagements and ships in Phase 4+).
	return &""


# === Helpers ================================================================

# Walk the scene tree looking for a Unit-shaped Node with the given unit_id.
# O(N) over live units per call. Phase 3 scale is <100 units; the walk is
# negligible. Replace with UnitRegistry direct lookup when that ships
# (LATER L1).
func _find_unit_by_id(unit_id: int) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	return _find_unit_recursive(root, unit_id)


func _find_unit_recursive(node: Node, unit_id: int) -> Node:
	# Check this node — duck-typed Unit shape (has unit_id field).
	var uid_v: Variant = node.get(&"unit_id")
	if typeof(uid_v) == TYPE_INT and int(uid_v) == unit_id \
			and node.has_method(&"replace_command"):
		return node
	# Recurse into children.
	for child in node.get_children():
		var found: Node = _find_unit_recursive(child, unit_id)
		if found != null:
			return found
	return null


# Read unit.fsm.current.id defensively. Returns &"" if any link in the chain
# is missing or the state has been swapped to Dying already.
func _read_fsm_state(unit: Node) -> StringName:
	if unit == null:
		return &""
	if not (&"fsm" in unit):
		return &""
	var fsm: Variant = unit.fsm
	if fsm == null:
		return &""
	var cur: Variant = fsm.current
	if cur == null:
		return &""
	var sid: Variant = cur.get(&"id")
	if typeof(sid) != TYPE_STRING_NAME:
		return &""
	return sid


func _read_unit_type(unit: Node) -> StringName:
	if unit == null:
		return &""
	var ut: Variant = unit.get(&"unit_type")
	if typeof(ut) != TYPE_STRING_NAME:
		return &""
	return ut


# Look up a drain magnitude by key from BalanceData.farr.drain_rates. Returns
# 0.0 for missing keys (handler then bails — no spurious zero-delta emit).
# Defensive against BalanceData absence (test scenes that don't ship it).
func _lookup_drain_magnitude(key: StringName) -> float:
	if _balance_data == null:
		_balance_data = _try_load_balance_data()
		if _balance_data == null:
			return 0.0
	var farr_cfg: Variant = _balance_data.get(&"farr")
	if farr_cfg == null:
		return 0.0
	var rates: Variant = farr_cfg.get(&"drain_rates")
	if typeof(rates) != TYPE_DICTIONARY:
		return 0.0
	var raw: Variant = (rates as Dictionary).get(key, 0.0)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return 0.0
	return float(raw)


func _try_load_balance_data() -> Resource:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	return load(path)


# === Test/harness helper ====================================================
# Allow tests to clear the cached BalanceData (e.g., to force a re-load after
# mutating drain_rates in fixture setup). Mirrors the reset() pattern other
# autoloads expose.
func reset() -> void:
	_balance_data = null
