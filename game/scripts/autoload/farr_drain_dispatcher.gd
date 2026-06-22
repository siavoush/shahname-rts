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
	# Phase 4 wave 1 (D1 — §4.3 snowball-injustice drains): subscribe to
	# unit_died (NOT unit_health_zero). Chosen because unit_died carries the
	# KILLER (killer_unit_id) — the §4.3 snowball drains are about WHO did the
	# killing (the attacker team's population), so killer-attribution is
	# load-bearing (Fix F1). This is a DIFFERENT concern from the worker-loss
	# drains above (which read the victim's PRE-Dying FSM state via
	# unit_health_zero); the two subscriptions coexist. See _on_unit_died.
	if not EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.connect(_on_unit_died)


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


# === D1 — §4.3 snowball-injustice drains (unit_died handler) ================
#
# Source: 01_CORE_MECHANICS.md §4.3 (snowball protection) + DECISIONS.md
# 2026-06-22 §1.1a/§1.1b. Hooks unit_died (carries the killer — Fix F1).
#
# Cultural referent (CLAUDE.md — keep the setting in the code's bones): the
# just king does not crush a fallen foe, and Farr (divine glory) abandons the
# ruler who rules through cruelty or excess (Jamshid's fall — pride/excess cost
# him the Farr, 00_SHAHNAMEH_RESEARCH.md §1; Zahhak's tyranny). Two drains:
#   D1a — outnumbered-kill: killer team ≥ 3× victim team population. "You cannot
#         bully your way to high Farr" (§4.3 anti-tyranny clause).
#   D1b — kicking-them-while-down: killing a worker / destroying a mine while
#         the victim's team is military-broken. Cruelty to a defenseless economy.
#
# Runs DURING the combat phase (unit_died emits from HealthComponent in &"combat"
# — Sim Contract §2 phase 6), so SimClock.is_ticking() holds; apply_farr_change's
# on-tick assert is satisfied by construction.
#
# DETERMINISM (Fix F4, Sim Contract §1.6): the just-killed victim is still
# transiently in &"units" (queue_free is deferred to &"cleanup"). We EXCLUDE
# from BOTH team population sums any unit that is_dying() OR is the just-emitted
# victim unit_id — so a same-tick multi-death resolves identically regardless of
# intra-phase handler order. The exclusion is the load-bearing determinism
# contract; a same-tick multi-death test guards it.
func _on_unit_died(unit_id: int, killer_unit_id: int, cause: StringName,
		_position: Vector3) -> void:
	var victim: Node = _find_unit_by_id(unit_id)
	if victim == null:
		# Victim already freed — can't read team/type, can't attribute. Log the
		# bail (observability: why no drain fired).
		print("[farr-snowball] unit_died unit_id=%d — victim unresolved, no drain" % unit_id)
		return
	var victim_team: int = _read_team(victim)

	# --- D1a: outnumbered-kill drain ---------------------------------------
	_maybe_drain_outnumbered(unit_id, killer_unit_id, victim, victim_team)

	# --- D1b: kicking-them-while-down drain --------------------------------
	_maybe_drain_economy_when_broken(unit_id, killer_unit_id, victim, victim_team, cause)


# D1a — outnumbered-kill. Resolve the killer; bail on no-killer / unresolved /
# friendly-fire (Fix F1). Then test the 3:1 population ratio (§1.1a).
func _maybe_drain_outnumbered(victim_id: int, killer_unit_id: int,
		_victim: Node, victim_team: int) -> void:
	# Bail 1: no killer (attrition / environmental / Farr-drain death — no
	# injustice). killer_unit_id == -1 is the EventBus "no source" sentinel.
	if killer_unit_id == -1:
		print("[farr-snowball] D1a victim=%d killer=-1 (no source) — no outnumbered drain" % victim_id)
		return
	# Bail 2: killer unresolved (freed before we could read its team). Read the
	# attacker team OFF THE KILLER (Fix F1) — NOT the victim's opposite.
	var killer: Node = _find_unit_by_id(killer_unit_id)
	if killer == null:
		print("[farr-snowball] D1a victim=%d killer=%d unresolved — no outnumbered drain" % [
			victim_id, killer_unit_id])
		return
	var attacker_team: int = _read_team(killer)
	# Bail 3: friendly fire (same-team killer) — a separate later concern, not
	# this drain. Falls out correctly from reading the team off the killer.
	if attacker_team == victim_team:
		print("[farr-snowball] D1a victim=%d killer=%d friendly-fire (team=%d) — no outnumbered drain" % [
			victim_id, killer_unit_id, attacker_team])
		return
	# Compute each team's army population (sum of population_cost over LIVING
	# units, excluding is_dying + the just-emitted victim — determinism Fix F4).
	var attacker_pop: int = _team_population(attacker_team, victim_id)
	var defender_pop: int = _team_population(victim_team, victim_id)
	# 3:1 boundary test. Integer cross-multiply (attacker_pop >= ratio *
	# defender_pop) avoids float division; ratio comes from BalanceData
	# (snowball_ratio = 3.0, tunable). Use roundi at the boundary for the
	# float-ratio → integer-threshold conversion (deterministic).
	var ratio: float = _snowball_ratio()
	# defender_pop == 0 edge: with the victim excluded, a defender with only the
	# just-died unit reads pop 0. attacker_pop >= 3*0 = 0 is trivially true for
	# any attacker_pop >= 1 — but a wiped-out defender is the §1.1b "broken
	# economy" case, not the §1.1a "outnumbered battle" case. Require
	# defender_pop >= 1 so D1a is about asymmetric LIVE engagements, not
	# annihilation (which D1b's military-broken path covers).
	if defender_pop < 1:
		print("[farr-snowball] D1a victim=%d defender_pop=0 (excl. victim) — not an outnumbered drain (see D1b)" % victim_id)
		return
	var threshold: int = roundi(ratio * float(defender_pop))
	if attacker_pop < threshold:
		print("[farr-snowball] D1a victim=%d attacker_pop=%d defender_pop=%d threshold=%d (ratio %.2f) — below 3:1, no drain" % [
			victim_id, attacker_pop, defender_pop, threshold, ratio])
		return
	var magnitude: float = _lookup_drain_magnitude(
		Constants.FARR_REASON_SNOWBALL_KILL_OUTNUMBERED)
	if magnitude <= 0.0:
		print("[farr-snowball] D1a key snowball_kill_outnumbered missing/<=0 — no drain")
		return
	# Fire the drain. source_unit = killer (the attacker caused the injustice).
	FarrSystem.apply_farr_change(
		-magnitude,
		String(Constants.FARR_REASON_SNOWBALL_KILL_OUTNUMBERED),
		killer)
	print("[farr-snowball] D1a DRAIN victim=%d killer=%d attacker_pop=%d defender_pop=%d threshold=%d drain=-%.2f" % [
		victim_id, killer_unit_id, attacker_pop, defender_pop, threshold, magnitude])


# D1b — kicking-them-while-down. Fires when the victim is a worker (or a
# Ma'dan/mine is destroyed — handled via building destruction, see note) AND
# the victim's team is military-broken (§1.1b: zero living military units AND
# zero operational military-production buildings).
#
# Mine-destruction note: a Ma'dan/mine is a BUILDING, so its destruction emits
# building_destroyed (not unit_died). This handler covers the WORKER half of
# the §1.1b scope (the unit_died path). The mine half would route through a
# building_destroyed consumer; per the brief's Predicates this wave wires the
# worker path (the canonical defenseless-victim case). The mine path is a
# documented follow-on (no Ma'dan-destruction snowball drain wired this wave —
# flagged below for QUESTIONS_FOR_DESIGN if the design wants it now).
func _maybe_drain_economy_when_broken(victim_id: int, killer_unit_id: int,
		victim: Node, victim_team: int, _cause: StringName) -> void:
	# Scope gate: victim must be a worker (Kargar). A military unit dying is
	# normal attrition, not "kicking the economy while it's down."
	var victim_type: StringName = _read_unit_type(victim)
	if victim_type != Constants.UNIT_TYPE_KARGAR:
		# Not a worker — D1b does not apply. (No log: the common case is a
		# combat-unit death; logging every one would spam. D1a already logged
		# its own decision for this death.)
		return
	# Killer-attribution gate (Fix F1, mirrors D1a): "kicking them while down"
	# requires a KICKER. A worker dying with no resolvable attacker — attrition,
	# Farr-drain death, scripted/test direct-damage (killer_unit_id == -1) — is
	# not an enemy cruelly mopping up a defenseless economy. Bail. This ALSO
	# prevents double-counting with the base worker-killed-idle drain: that drain
	# fires off unit_health_zero for ANY worker death; D1b is the additional
	# "an enemy did this while you were broken" injustice, so it requires the
	# enemy to be identified. (DECISIONS.md 2026-06-22 §1.1b is a state predicate;
	# the killer-attribution gate is the F1 principle applied to D1b — see
	# QUESTIONS_FOR_DESIGN.md for the double-drain-vs-single-drain design note.)
	if killer_unit_id == -1:
		print("[farr-snowball] D1b victim=%d worker killer=-1 (no attacker) — no economy-broken drain" % victim_id)
		return
	var killer: Node = _find_unit_by_id(killer_unit_id)
	if killer == null:
		print("[farr-snowball] D1b victim=%d worker killer=%d unresolved — no economy-broken drain" % [
			victim_id, killer_unit_id])
		return
	# Friendly-fire bail (mirrors D1a): a team killing its own worker while
	# broken is not the §4.3 enemy-cruelty injustice.
	if _read_team(killer) == victim_team:
		print("[farr-snowball] D1b victim=%d worker killer=%d friendly-fire — no economy-broken drain" % [
			victim_id, killer_unit_id])
		return
	# Military-broken predicate: zero living military units of victim_team AND
	# zero operational military-production buildings of victim_team. Exclude the
	# just-emitted victim from the unit sum (determinism; a worker death never
	# changes the military count, but exclusion is uniform with D1a).
	var living_military: int = _team_living_military_count(victim_team, victim_id)
	if living_military > 0:
		print("[farr-snowball] D1b victim=%d worker team=%d living_military=%d — not broken, no drain" % [
			victim_id, victim_team, living_military])
		return
	var mil_prod_buildings: int = _team_operational_military_production_count(victim_team)
	if mil_prod_buildings > 0:
		print("[farr-snowball] D1b victim=%d worker team=%d military=0 but mil_prod_buildings=%d — not broken, no drain" % [
			victim_id, victim_team, mil_prod_buildings])
		return
	# All conditions hold: an identified enemy killed a worker on a military-
	# broken team.
	var magnitude: float = _lookup_drain_magnitude(
		Constants.FARR_REASON_SNOWBALL_ECONOMY_WHEN_BROKEN)
	if magnitude <= 0.0:
		print("[farr-snowball] D1b key snowball_economy_when_broken missing/<=0 — no drain")
		return
	FarrSystem.apply_farr_change(
		-magnitude,
		String(Constants.FARR_REASON_SNOWBALL_ECONOMY_WHEN_BROKEN),
		killer)
	print("[farr-snowball] D1b DRAIN victim=%d(worker) killer=%d team=%d military-broken drain=-%.2f" % [
		victim_id, killer_unit_id, victim_team, magnitude])


# === D1 helpers =============================================================

# Sum population_cost over LIVING units of `team`, EXCLUDING is_dying() units
# AND the just-emitted victim id (Fix F4 determinism — same-tick multi-death
# order-invariance). population_cost is read from BalanceData.units[type].
func _team_population(team: int, exclude_unit_id: int) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var total: int = 0
	for node: Node in tree.get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		if _read_unit_id(node) == exclude_unit_id:
			continue  # Exclude the just-emitted victim (determinism).
		if _read_team(node) != team:
			continue
		if _is_dying(node):
			continue  # Exclude dying units (determinism — they're leaving).
		total += _population_cost_for(_read_unit_type(node))
	return total


# Count LIVING MILITARY units of `team`, excluding is_dying() + the victim id.
# Military = unit_type in Constants.MILITARY_UNIT_TYPES (workers excluded).
func _team_living_military_count(team: int, exclude_unit_id: int) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		if _read_unit_id(node) == exclude_unit_id:
			continue
		if _read_team(node) != team:
			continue
		if _is_dying(node):
			continue
		if Constants.MILITARY_UNIT_TYPES.has(_read_unit_type(node)):
			count += 1
	return count


# Count OPERATIONAL military-production buildings of `team`. A building is
# military-production if its `produces` array contains a military unit type;
# "operational" = construction-complete (is_complete true). Enumerates the
# &"buildings" group (every Building joins at building.gd:358).
func _team_operational_military_production_count(team: int) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"buildings"):
		if not is_instance_valid(node):
			continue
		if _read_team(node) != team:
			continue
		if not _is_building_operational(node):
			continue
		if _building_produces_military(node):
			count += 1
	return count


# A building is operational if its `is_complete` flag is true. This is the
# SAME gate Building.request_train uses (building.gd:676 "Building must be
# operationally ready (construction complete)") — so "operational military-
# production building" means exactly "a building where request_train for a
# military unit would pass the operational check." Using request_train's own
# gate keeps the military-broken predicate coherent with what production can
# actually do. (is_complete flips at place_at/Stage-1 in this codebase; the
# choice tracks request_train's contract, not the Stage-1/Stage-2 naming.)
# Defensive: a building without the field (shouldn't happen) reads as not-
# operational (conservative — won't spuriously block the military-broken drain).
func _is_building_operational(building: Node) -> bool:
	var v: Variant = building.get(&"is_complete")
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	return false


# True if the building's `produces` array contains any military unit type.
# Reads the `produces: Array[StringName]` field (building.gd:275).
func _building_produces_military(building: Node) -> bool:
	var produces: Variant = building.get(&"produces")
	if typeof(produces) != TYPE_ARRAY:
		return false
	for kind in (produces as Array):
		if typeof(kind) == TYPE_STRING_NAME and Constants.MILITARY_UNIT_TYPES.has(kind):
			return true
	return false


# population_cost for a unit_type from BalanceData.units[type]. Defaults to 1
# (the UnitStats default) if BalanceData / the type / the field is missing.
func _population_cost_for(unit_type: StringName) -> int:
	if unit_type == &"":
		return 0
	if _balance_data == null:
		_balance_data = _try_load_balance_data()
		if _balance_data == null:
			return 1  # No BalanceData — every unit counts as 1 (loud-default).
	var units: Variant = _balance_data.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return 1
	var stats: Variant = (units as Dictionary).get(unit_type, null)
	if stats == null:
		return 1
	var v: Variant = stats.get(&"population_cost")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 1


# The 3:1 snowball ratio from BalanceData.farr.snowball_ratio (default 3.0).
func _snowball_ratio() -> float:
	if _balance_data == null:
		_balance_data = _try_load_balance_data()
		if _balance_data == null:
			return 3.0
	var farr_cfg: Variant = _balance_data.get(&"farr")
	if farr_cfg == null:
		return 3.0
	var v: Variant = farr_cfg.get(&"snowball_ratio")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return 3.0


# Alive predicate (Fix F2): is_dying() is the canonical Dying-state check
# (unit.gd:586) — NOT get_health() (which returns the always-non-null
# HealthComponent node). Duck-typed (registry race, ARCHITECTURE §6 v0.4.0); a
# node lacking the method reads as not-dying (field-default for non-FSM stubs).
func _is_dying(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method(&"is_dying"):
		return bool(node.call(&"is_dying"))
	return false


func _read_team(node: Node) -> int:
	var v: Variant = node.get(&"team")
	if typeof(v) == TYPE_INT:
		return int(v)
	return Constants.TEAM_NEUTRAL


func _read_unit_id(node: Node) -> int:
	var v: Variant = node.get(&"unit_id")
	if typeof(v) == TYPE_INT:
		return int(v)
	return -1


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
