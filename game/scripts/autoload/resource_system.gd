extends "res://scripts/core/sim_node.gd"
##
## ResourceSystem — per-team Coin / Grain / Population counters and the single
## sanctioned write seam for all resource mutations.
##
## Source references:
##   - 01_CORE_MECHANICS.md §3 — Iran economy (Coin / sekkeh, Grain / ghallat)
##   - 02f_PHASE_3_KICKOFF.md §3 wave 1B — "ResourceSystem (autoload) tracks
##     coin_x100, grain_x100, population, population_cap per team."
##   - docs/SIMULATION_CONTRACT.md §1.3 — Self-only mutation rule; SimNode
##     chokepoint discipline (on-tick assert via _set_sim).
##   - docs/SIMULATION_CONTRACT.md §1.6 — fixed-point integer storage
##     (Coin × 100, Grain × 100). Float conversion only at HUD/telemetry
##     boundaries.
##   - CLAUDE.md — the apply_farr_change chokepoint pattern; this is the
##     analogous chokepoint for resources.
##
## Why extend SimNode (via path-string preload, not class_name)?
## SimNode owns the on-tick mutation chokepoint (_set_sim with assert). The
## path-string base is the registry-race workaround documented in
## docs/ARCHITECTURE.md §6 v0.4.0 — autoloads parse before the class_name
## registry is fully populated, so extending by class_name risks resolution
## failure.
##
## Naming note (load-bearing — documented in commit body):
##   The single write method is `change_resource`, NOT `apply_resource_change`.
##   The lint rule L1 (`tools/lint_simulation.sh`) flags `apply_*\(` calls
##   when the same file defines an off-tick frame entry. Adopting
##   `change_resource` keeps the chokepoint pattern (single write seam)
##   without expanding the L1 allowlist. The FarrSystem precedent
##   (`apply_farr_change`) predates the lint rule; reserving the `apply_*`
##   namespace for the Farr chokepoint while every other chokepoint takes a
##   verb-noun shape minimizes future allowlist churn.
##
## The chokepoint:
##   change_resource(team: int, kind: StringName, amount_x100: int,
##                   reason: StringName, source_unit: Object) -> void
## - asserts SimClock.is_ticking() (Sim Contract §1.1)
## - mutates the per-team counter via _set_sim
## - emits EventBus.resource_changed(team, kind, delta_x100, new_total_x100)
##
## Phase 3 wave 1B ships the autoload + signal. Wave 1B's Returning state
## deposit and Farr drain dispatcher both consume this chokepoint. Wave 1C+
## adds population_cap mutation paths (Khaneh building completion).

# Internal storage — fixed-point ints, per-team. Dictionary[int, int] keyed by
# Constants.TEAM_*. The dicts are initialized in _ready from the economy
# config's `starting_coin` / `starting_grain` for both teams; population starts
# at 0 (no units yet) and population_cap starts at 0 (no Khaneh yet — Khaneh
# +5 lands in Phase 3 session 2).
var _coin_x100: Dictionary = {}
var _grain_x100: Dictionary = {}
var _population: Dictionary = {}
var _population_cap: Dictionary = {}


# === Throne dropoff-target memo (Wave-3-Throne, RNC §5.2) ===================
#
# Per RNC §5.2 + brief §4 Track 1: workers query
# ResourceSystem.dropoff_for_team(team) to find their faction's Throne
# during gather-deposit cycles. The lookup walks the &"thrones" SceneTree
# group and filters by team; memoizing per-team per-tick avoids the
# scene-tree scan on every deposit.
#
# Pitfall #16 (mirror C2.1): the memo's stored Node ref may become a
# freed Object if the Throne is destroyed between the memo-set tick and
# the next consumer read. We MUST `is_instance_valid()` before returning;
# we ALSO subscribe to EventBus.throne_destroyed to evict eagerly.
#
# Dictionary[int, Node3D] keyed by Constants.TEAM_IRAN / TEAM_TURAN. Empty
# at start; populated lazily on first lookup; cleared on throne_destroyed.
# Memo is per-tick effective via _dropoff_memo_tick storing the
# SimClock.tick value of the most-recent lookup per team. A consumer
# in a later tick re-walks the group (cheap; thrones group has ≤2 members
# in MVP — one per faction). The per-tick limit is more about correctness
# (multi-tick deposits on the same tick all benefit from the cache) than
# performance.
var _dropoff_memo: Dictionary = {}
var _dropoff_memo_tick: Dictionary = {}


# === Lifecycle ==============================================================

func _ready() -> void:
	_load_starting_values_from_balance_data()
	# Wave-3-Throne — subscribe to throne_destroyed for memo eviction.
	# When a Throne is destroyed, its Node ref in the memo becomes a
	# freed Object; we evict eagerly so the next dropoff_for_team call
	# re-walks the group instead of returning a freed ref.
	if not EventBus.throne_destroyed.is_connected(_on_throne_destroyed):
		EventBus.throne_destroyed.connect(_on_throne_destroyed)


# Defensive load mirroring FarrSystem._load_starting_value_from_balance_data:
# if BalanceData isn't on disk, fall back to zero-initialized state. Reads
# economy.starting_coin and economy.starting_grain.
func _load_starting_values_from_balance_data() -> void:
	# Initialize all four counters with zero for both teams (and neutral, which
	# stays at zero — neutral isn't an economic actor but the slot exists so
	# tests can poke a team-key without a guard).
	var teams: Array[int] = [
		Constants.TEAM_IRAN, Constants.TEAM_TURAN, Constants.TEAM_NEUTRAL,
	]
	for t in teams:
		_coin_x100[t] = 0
		_grain_x100[t] = 0
		_population[t] = 0
		_population_cap[t] = 0

	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return
	var bd: Resource = load(path)
	if bd == null:
		push_warning(
			"ResourceSystem: BalanceData at %s failed to load; "
			% path
			+ "starting both teams at 0 coin / 0 grain."
		)
		return
	var econ: Variant = bd.get(&"economy")
	if econ == null:
		return
	var starting_coin: Variant = econ.get(&"starting_coin")
	var starting_grain: Variant = econ.get(&"starting_grain")
	if typeof(starting_coin) == TYPE_INT or typeof(starting_coin) == TYPE_FLOAT:
		# Fixed-point: starting_coin is in whole Coin units; multiply by 100.
		var coin_x100: int = int(float(starting_coin) * 100.0)
		_coin_x100[Constants.TEAM_IRAN] = coin_x100
		_coin_x100[Constants.TEAM_TURAN] = coin_x100
	if typeof(starting_grain) == TYPE_INT or typeof(starting_grain) == TYPE_FLOAT:
		var grain_x100: int = int(float(starting_grain) * 100.0)
		_grain_x100[Constants.TEAM_IRAN] = grain_x100
		_grain_x100[Constants.TEAM_TURAN] = grain_x100


# === Public read API ========================================================
# Float conversion happens at the boundary; consumers (HUD, telemetry, tests)
# read floats and don't see the fixed-point machinery. Per Sim Contract §1.6.

func coin_for(team: int) -> float:
	return float(_coin_x100.get(team, 0)) / 100.0


func grain_for(team: int) -> float:
	return float(_grain_x100.get(team, 0)) / 100.0


func population_for(team: int) -> int:
	return int(_population.get(team, 0))


func population_cap_for(team: int) -> int:
	return int(_population_cap.get(team, 0))


# Fixed-point accessors for systems that need exact int math (combat / cost
# checks). HUD code uses the float accessors above.

func coin_x100_for(team: int) -> int:
	return int(_coin_x100.get(team, 0))


func grain_x100_for(team: int) -> int:
	return int(_grain_x100.get(team, 0))


# === THE chokepoint =========================================================
#
# All resource mutations flow through change_resource. The function:
#   1. Asserts SimClock.is_ticking() per Sim Contract §1.1.
#   2. Looks up the per-team dict for the kind.
#   3. Mutates the new total via _set_sim (off-tick crash in debug).
#   4. Emits EventBus.resource_changed with the effective delta + new total.
#
# Parameters:
#   team:        Constants.TEAM_* identifier.
#   kind:        StringName — Constants.KIND_COIN / KIND_GRAIN, or a special
#                key for population (handled separately by change_population).
#   amount_x100: signed fixed-point delta. Positive = gain, negative = spend.
#   reason:      StringName for the F2 telemetry log
#                (e.g., &"gather_deposit", &"unit_production_cost").
#   source_unit: optional Object identifying who caused the change. May be
#                null. Reserved for telemetry symmetry with apply_farr_change.
#
# Phase 3 wave 1B handles Coin and Grain via this method. Population uses
# change_population (a sister chokepoint) because population isn't fixed-point
# — it's a unit count.
func change_resource(
	team: int,
	kind: StringName,
	amount_x100: int,
	reason: StringName,
	_source_unit: Object,
) -> void:
	assert(SimClock.is_ticking(),
		"Off-tick resource mutation: team=%d kind='%s' amount_x100=%d reason='%s'"
		% [team, kind, amount_x100, reason])

	# Resolve the per-team dict for this kind. Coin and Grain are the two
	# resources in MVP (Constants.KIND_COIN / KIND_GRAIN). Other kinds are
	# rejected with a push_error — silent drops would hide typos in callers.
	var store: Dictionary
	if kind == Constants.KIND_COIN:
		store = _coin_x100
	elif kind == Constants.KIND_GRAIN:
		store = _grain_x100
	else:
		push_error(
			"ResourceSystem.change_resource: unknown kind '%s' " % kind
			+ "(team=%d amount_x100=%d). Only KIND_COIN and KIND_GRAIN "
			% [team, amount_x100]
			+ "are accepted in Phase 3. No mutation applied."
		)
		return

	var pre: int = int(store.get(team, 0))
	var post: int = pre + amount_x100
	# Clamp at zero — negative balances are not a thing in this game. Cost
	# checks happen BEFORE change_resource is called (production system asks
	# "can I afford this?" before spending); the clamp here is belt-and-braces
	# against a bug spending more than available.
	if post < 0:
		post = 0
	# Effective delta (what the meter actually moved) — emitted in the signal
	# so consumers see a coherent ledger even when the clamp clipped a spend.
	var effective_delta: int = post - pre

	# Update via the chokepoint. _set_sim's on-tick assert is the second line
	# of defense behind the assert at the top of this function — both fire
	# under the same condition in debug.
	store[team] = post
	# Write the dict back through _set_sim so the Sim Contract §1.3 invariant
	# holds (mutation routed through the chokepoint, not direct field write).
	# Writing the same dict reference back is a no-op semantically but
	# preserves the discipline pattern; future fields that aren't dict-shaped
	# will follow the same form without divergence.
	if kind == Constants.KIND_COIN:
		_set_sim(&"_coin_x100", store)
	else:
		_set_sim(&"_grain_x100", store)

	# source_unit + reason are captured in the parameter signature for
	# forward-compat with future telemetry consumers (parallels
	# apply_farr_change's signature). resource_changed is intentionally
	# team/kind/delta/total-only today; reason lives in F2 overlay (Phase 4),
	# source_unit_id resolution is a 3-line re-add when a consumer needs it
	# (see git history pre-v1.2.2 for the resolution pattern). Per Manifesto
	# Principle 4 (Lean Iteration): dead reference-only code deleted.
	EventBus.resource_changed.emit(team, kind, effective_delta, post)


# Population is integer-valued (not fixed-point — there's no fractional
# population). Lives on a sister chokepoint so the signature is honest.
# Phase 3 wave 1B does not consume this yet (no unit production / Khaneh
# build flow in this wave); ships ahead for wave 1C use.
func change_population(
	team: int,
	delta: int,
	reason: StringName,
	_source_unit: Object,
) -> void:
	assert(SimClock.is_ticking(),
		"Off-tick population mutation: team=%d delta=%d reason='%s'"
		% [team, delta, reason])
	var pre: int = int(_population.get(team, 0))
	var post: int = pre + delta
	if post < 0:
		post = 0
	var effective_delta: int = post - pre
	_population[team] = post
	_set_sim(&"_population", _population)
	# source_unit + reason capture parallels change_resource (above). Today's
	# resource_changed signal is team/kind/delta/total-only; reason flows
	# through F2 overlay. Dead reference-only code deleted v1.2.2 (Manifesto
	# Principle 4); see change_resource for the same shape.
	#
	# Use the same EventBus signal for symmetry; resource_changed carries a
	# StringName kind so population can ride the same channel under
	# &"population". Avoids a second signal that the HUD would also need to
	# subscribe to.
	EventBus.resource_changed.emit(team, &"population", effective_delta, post)


func change_population_cap(
	team: int,
	delta: int,
	reason: StringName,
	_source_unit: Object,
) -> void:
	assert(SimClock.is_ticking(),
		"Off-tick population_cap mutation: team=%d delta=%d reason='%s'"
		% [team, delta, reason])
	var pre: int = int(_population_cap.get(team, 0))
	var post: int = pre + delta
	if post < 0:
		post = 0
	var effective_delta: int = post - pre
	_population_cap[team] = post
	_set_sim(&"_population_cap", _population_cap)
	EventBus.resource_changed.emit(team, &"population_cap", effective_delta, post)


# === Resource-node registry — Phase 3 session 2 wave 1A (Room A Decision 4) =
#
# Per the Room A Open Space ratified 2026-05-14, ResourceSystem exposes a
# registry of ResourceNode-like nodes so future consumers (Phase 6 scout AI,
# Phase 5 Kaveh Event scripting) can enumerate &"coin" / &"grain" sources by
# kind without scene-tree walks. Wave 1A scope ships the API + reset
# behavior; the query side (get_nodes_of_kind, by_team filter) lands when a
# consumer demands it.
#
# Why on ResourceSystem (not on a new ResourceNodeRegistry autoload):
# Mazra'eh's _on_placement_complete already calls into ResourceSystem (for
# the chokepoint). Registering with the same autoload at the same seam
# keeps the cross-cutting surface small. The MineNode wave-1A code shipped
# without using this — mines were raycast-routed, not registry-enumerated.
# Mazra'eh in wave 1A this session, and DummyAI in wave 3B, are the first
# registry-using consumers (DummyAI may or may not — depends on its build
# order shape per the Path C decision-log).
#
# Why duck-typed on `kind` (not class-checked on ResourceNode):
# Mazra'eh extends Building, not ResourceNode (option (iii) per Room A —
# duck-typed three-call API). A class_check `node is ResourceNode` would
# reject Mazra'eh. The registry tolerates anything exposing a `kind`
# StringName field via `.get(&"kind")`. Same pattern as
# UnitState_Gathering's `has_method(&"request_extract")` filter.

# Per-kind registry — Dictionary[StringName, Array[Node]] keyed by the
# RESOURCE kind passed explicitly at register-time (&"coin" / &"grain").
# The values are Arrays-of-Nodes so iteration order is stable across
# registrations (deterministic Phase 6 enumeration).
#
# v1.2.1 fix-up rationale (2026-05-14): the original v1.2.0 read kind from
# `node.kind`. That worked for MineNode (whose `kind = &"coin"` is the
# resource kind) but BROKE for Mazra'eh (which extends Building, so
# `kind = &"mazraeh"` is the Building kind, NOT the resource kind &"grain").
# A consumer asking `get_nodes_of_kind(&"grain")` would have missed Mazra'eh
# entirely. Decoupling registered-kind from node-kind via the explicit
# parameter eliminates the ambiguity at the seam between MineNode-as-
# ResourceNode and Mazra'eh-as-Building.
#
# A node's registration is keyed only on the kind passed at register-time;
# the registry does not introspect node.kind. The double-register guard
# (same node, same kind, twice) catches buggy callers; double-register
# under DIFFERENT kinds is allowed (a hypothetical hybrid node could
# legitimately register under multiple kinds).
var _nodes_by_kind: Dictionary = {}


## Register a resource-providing node so consumers can enumerate it.
##
## The `kind` parameter is the RESOURCE kind (&"coin" / &"grain"), passed
## explicitly by the caller. It does NOT have to match the node's `kind`
## field — for Mazra'eh (which extends Building, so `node.kind = &"mazraeh"`
## is the Building kind), the caller passes `&"grain"` here. The registry
## stores the node under the EXPLICIT kind, not the node's field.
##
## Callers:
##   - Mazra'eh's _on_placement_complete: `register_node(self, Constants.KIND_GRAIN)`
##   - Future MineNode self-register seam: `register_node(self, Constants.KIND_COIN)`
##   - Phase 5+ resource sources: caller-decided kind.
##
## Idempotency: registering the SAME node under the SAME kind twice emits a
## warning and does NOT duplicate. Registering the SAME node under
## DIFFERENT kinds is allowed (hypothetical hybrid node case) — both buckets
## carry the ref; unregister_node clears all buckets.
##
## Sanctioned-write context: this method may be called from off-tick
## contexts (a building's _on_placement_complete runs from inside the
## worker's _sim_tick, which is on-tick; but for symmetry with the
## off-tick Mazra'eh-construction case in wave 1C, the registry is a
## control-plane structure, not a sim-state structure — same precedent
## as _coin_x100's initial _load_starting_values write at _ready).
##
## kind must be a non-empty StringName. An empty kind or null/invalid node
## produces a push_error and no-op.
func register_node(node: Node, kind: StringName) -> void:
	if node == null or not is_instance_valid(node):
		push_error(
			"ResourceSystem.register_node: null or invalid node — no-op.")
		return
	if kind == &"":
		push_error(
			"ResourceSystem.register_node: empty kind StringName. No-op. "
			+ "node=%s" % str(node))
		return
	# Ensure the per-kind array exists.
	if not _nodes_by_kind.has(kind):
		_nodes_by_kind[kind] = []
	var bucket: Array = _nodes_by_kind[kind]
	# Idempotency guard — warn but don't duplicate.
	if bucket.has(node):
		push_warning(
			"ResourceSystem.register_node: node already registered "
			+ "for kind &\"%s\". Ignoring second registration. " % kind
			+ "(Caller may have called _on_placement_complete twice.)")
		return
	bucket.append(node)


## Remove a node from the registry. Idempotent — unregistering an unknown
## node is a no-op (no warn). Callers (Mazra'eh on destruction, MineNode
## on depletion) call this from teardown paths where the node may or may
## not be registered.
func unregister_node(node: Node) -> void:
	if node == null:
		# Even a freed instance can be deregistered if we scan all buckets
		# for the ref. But null is a hard no-op.
		return
	# Scan all buckets — the node may have been registered under a kind
	# that's since changed (shouldn't happen, but the death-path code
	# shouldn't have to know the node's kind to clean up after it).
	for kind in _nodes_by_kind.keys():
		var bucket: Array = _nodes_by_kind[kind]
		if bucket.has(node):
			bucket.erase(node)
			# Don't return — defensively continue scanning in case a bug
			# double-registered the node under two kinds. Harmless for the
			# common case (single registration); diagnostic for the bad case.


## Introspection helper — true if the node is currently in the registry
## under any kind. Used by tests + the F4 debug overlay (Phase 4+); not a
## hot-path consumer surface (Phase 6 AI uses the per-kind enumeration
## helper instead).
func is_node_registered(node: Node) -> bool:
	if node == null:
		return false
	for kind in _nodes_by_kind.keys():
		if (_nodes_by_kind[kind] as Array).has(node):
			return true
	return false


## Per-kind count — tests + future enumeration scaffolding. The full
## get_nodes_of_kind enumeration API lands when a consumer needs it.
func registered_node_count_for_kind(kind: StringName) -> int:
	if not _nodes_by_kind.has(kind):
		return 0
	return (_nodes_by_kind[kind] as Array).size()


# === Test/harness helper ====================================================
#
# Mirrors FarrSystem.reset() — called by MatchHarness before each simulated
# match so teardown/restart doesn't leak resource state. Re-loads starting
# values from BalanceData.
func reset() -> void:
	_coin_x100.clear()
	_grain_x100.clear()
	_population.clear()
	_population_cap.clear()
	# Wave-1A: also clear the node registry so a node from a prior simulated
	# match doesn't linger and skew enumeration in the next. MatchHarness
	# discipline.
	_nodes_by_kind.clear()
	# Wave-3-Throne: clear the dropoff memo too. Same MatchHarness shape —
	# a Throne ref from a prior match would be a freed Object in the next.
	_dropoff_memo.clear()
	_dropoff_memo_tick.clear()
	_load_starting_values_from_balance_data()


# === Throne dropoff-target lookup (Wave-3-Throne, RNC §5.2) =================
#
# Per RNC §5.2 + brief §4 Track 1. Resolves the team's deposit target by
# walking the &"thrones" SceneTree group + filtering by team. Memoized
# per-team per-SimClock-tick to avoid scene-tree scans on every gather
# cycle.
#
# **Pitfall #16 MANDATORY (mirror C2.1):** `is_instance_valid()` BEFORE
# returning the memoized value. Eviction also runs on
# EventBus.throne_destroyed, but the per-call guard is the load-bearing
# safety — if the throne was freed between throne_destroyed emit and the
# next consumer read, the per-call guard catches it.
#
# Returns Node3D (the Throne instance) or null when no Throne exists for
# this team (test fixture, pre-spawn, or destroyed-and-not-yet-respawned
# state).


## Look up the Throne instance serving as the deposit target for a team.
##
## Returns the Throne Node3D or null. **The returned ref is validated
## via is_instance_valid() before return**; callers MAY rely on a
## non-null return being a live instance THIS tick. Callers walking
## across multiple ticks SHOULD re-call this method each tick (cheap;
## memoized).
##
## team: Constants.TEAM_IRAN or TEAM_TURAN. TEAM_NEUTRAL returns null
## (no neutral Throne).
func dropoff_for_team(team: int) -> Node3D:
	# Per-tick memo check. SimClock.tick is the canonical "now" — if the
	# memo entry was set this same tick, return it (after Pitfall #16
	# guard).
	var current_tick: int = SimClock.tick
	if _dropoff_memo_tick.get(team, -1) == current_tick:
		var cached: Variant = _dropoff_memo.get(team, null)
		if cached != null and is_instance_valid(cached):
			return cached as Node3D
		# Cached ref is dead (freed between memo-set and now). Fall
		# through to re-walk.
	# Walk the &"thrones" group, filter by team, take the FIRST match.
	# MVP has exactly one Throne per faction, so first-match is the only
	# match. Multi-Throne factions (out of MVP scope) would need a
	# preference policy (nearest? lowest unit_id?). Today: first.
	var tree: SceneTree = get_tree()
	if tree == null:
		# Test fixture without scene tree — no Thrones to find.
		_dropoff_memo[team] = null
		_dropoff_memo_tick[team] = current_tick
		# §9.M6 — throttled log (don't spam every gather cycle).
		_log_dropoff_throttled(team, null)
		return null
	var found: Node3D = null
	for node in tree.get_nodes_in_group(&"thrones"):
		if not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue
		var node_team: Variant = node.get(&"team")
		if typeof(node_team) == TYPE_INT and int(node_team) == team:
			found = node as Node3D
			break
	_dropoff_memo[team] = found
	_dropoff_memo_tick[team] = current_tick
	# §9.M6 — throttled log (1 per few seconds; spammy gather cycles
	# would otherwise drown the log).
	_log_dropoff_throttled(team, found)
	return found


# Throttle map: team → last-logged tick. Logs at most once per ~3 seconds
# (90 ticks @ 30Hz) per team. Keeps the live-test log readable without
# losing the diagnostic signal entirely.
var _dropoff_log_last_tick: Dictionary = {}
const _DROPOFF_LOG_THROTTLE_TICKS: int = 90


func _log_dropoff_throttled(team: int, found: Node3D) -> void:
	var last: int = int(_dropoff_log_last_tick.get(team, -10000))
	var now: int = SimClock.tick
	if now - last < _DROPOFF_LOG_THROTTLE_TICKS:
		return
	_dropoff_log_last_tick[team] = now
	var found_desc: String = "null"
	if found != null and is_instance_valid(found):
		found_desc = "<Throne unit_id=%d pos=%s>" % [
			int(found.get(&"unit_id")), str(found.global_position)]
	print("[resource] dropoff_for_team(team=%d) → %s" % [team, found_desc])


func _on_throne_destroyed(team_id: int) -> void:
	# Evict the memo for this team so the next consumer re-walks the
	# group instead of returning a freed Node ref. Pitfall #16 belt-
	# and-braces: the per-call `is_instance_valid` in dropoff_for_team
	# would also catch the freed ref, but eager eviction is faster and
	# avoids the rare case where validity-check returns true on a
	# half-freed object during the same-frame destruction.
	if _dropoff_memo.has(team_id):
		_dropoff_memo.erase(team_id)
	if _dropoff_memo_tick.has(team_id):
		_dropoff_memo_tick.erase(team_id)
	print("[resource] dropoff_memo evicted for team=%d (throne_destroyed)" % team_id)
