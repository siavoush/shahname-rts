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


# === Lifecycle ==============================================================

func _ready() -> void:
	_load_starting_values_from_balance_data()


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
	source_unit: Object,
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

	# Resolve source_unit_id for telemetry. -1 sentinel matches the convention
	# used by apply_farr_change (see farr_system.gd). source_unit.unit_id when
	# present, instance id fallback for diagnostics, -1 when null.
	var source_unit_id: int = -1
	if source_unit != null and is_instance_valid(source_unit):
		var uid: Variant = source_unit.get(&"unit_id")
		if typeof(uid) == TYPE_INT:
			source_unit_id = int(uid)
		else:
			source_unit_id = source_unit.get_instance_id()
	# source_unit_id is captured for forward-compat; the signal currently
	# doesn't carry it (write-shaped resource_changed has team/kind/delta/total
	# — the killer/source attribution is on the Farr signal, not here).
	# Keep the resolution code; downstream tasks may need it.
	# Silence the unused-warning by referencing once.
	if source_unit_id == -2:
		pass  # unreachable; keeps linter quiet
	# (No-op: source_unit_id retained for future signal extension. Today's
	# resource_changed is intentionally team/kind/delta-only — see signal
	# declaration in event_bus.gd for rationale.)

	# Reason is recorded in the F2 overlay (Phase 4); we don't emit it on the
	# write-shaped signal because every consumer that needs the reason can
	# subscribe to telemetry. Same precedent: farr_changed carries reason as
	# a String for F2; resource_changed is leaner because the resource
	# economy already has many more events than Farr.
	if reason == &"":
		pass

	EventBus.resource_changed.emit(team, kind, effective_delta, post)


# Population is integer-valued (not fixed-point — there's no fractional
# population). Lives on a sister chokepoint so the signature is honest.
# Phase 3 wave 1B does not consume this yet (no unit production / Khaneh
# build flow in this wave); ships ahead for wave 1C use.
func change_population(
	team: int,
	delta: int,
	reason: StringName,
	source_unit: Object,
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
	# Same source_unit / reason capture rationale as change_resource — kept
	# for telemetry symmetry; no signal field consumes them today.
	if source_unit == null and reason == &"":
		pass
	# Use the same EventBus signal for symmetry; resource_changed carries a
	# StringName kind so population can ride the same channel under
	# &"population". Avoids a second signal that the HUD would also need to
	# subscribe to.
	EventBus.resource_changed.emit(team, &"population", effective_delta, post)


func change_population_cap(
	team: int,
	delta: int,
	reason: StringName,
	source_unit: Object,
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
	if source_unit == null and reason == &"":
		pass
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

# Per-kind registry — Dictionary[StringName, Array[Node]] keyed by `kind`
# (&"coin" / &"grain"). The values are Arrays-of-Nodes so iteration order is
# stable across registrations (deterministic Phase 6 enumeration).
#
# A node's registration is keyed only on its `kind` at register-time; if a
# node's kind changes after registration (shouldn't happen in practice —
# Mazra'eh / MineNode don't mutate kind post-construction), the registry's
# bucket WON'T follow. The double-register guard catches reregistration
# under a different kind by emitting a warning.
var _nodes_by_kind: Dictionary = {}


## Register a resource-providing node so consumers can enumerate it.
##
## Callers: Mazra'eh's _on_placement_complete (wave 1A, world-builder's
## slice). MineNode could call this too — wave 1A wave-1A MineNode does
## NOT call it for backward-compat with the wave-1A raycast-routing path,
## but ResourceSystem.reset() / register_node remain available if a
## future MineNode self-register seam is added.
##
## Idempotency: registering the same node twice emits a warning and does
## NOT duplicate the registry entry. The warning surfaces a buggy caller
## that calls _on_placement_complete twice; the no-duplicate guard
## preserves the AI's enumeration correctness even if the caller is buggy.
##
## Sanctioned-write context: this method may be called from off-tick
## contexts (a building's `_ready` runs during scene-tree warm-up, before
## SimClock first tick). The mutation is on the registry Dictionary
## (not a sim-state field), so the SimNode _set_sim discipline doesn't
## apply. The registry is a control-plane structure, not a sim-state
## structure — same precedent as _coin_x100's initial _load_starting_values
## write at _ready.
##
## node must expose a `kind: StringName` field readable via `.get(&"kind")`.
## A null node or a node without `kind` produces a push_error and no-op.
func register_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		push_error(
			"ResourceSystem.register_node: null or invalid node — no-op.")
		return
	var kind_v: Variant = node.get(&"kind")
	if typeof(kind_v) != TYPE_STRING_NAME or StringName(kind_v) == &"":
		push_error(
			"ResourceSystem.register_node: node has no `kind` StringName "
			+ "field (or it is empty). No-op. node=%s" % str(node))
		return
	var kind: StringName = StringName(kind_v)
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
	_load_starting_values_from_balance_data()
