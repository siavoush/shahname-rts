extends "res://scripts/core/sim_node.gd"
##
## FarrSystem — Iran's civilization-level meter (the game's central mechanical
## innovation; per Ferdowsi's Shahnameh, the divine glory of just rule).
##
## Source references:
##   - 01_CORE_MECHANICS.md §4 — Farr full spec (range 0-100, starts 50,
##     generators, drains, snowball protection)
##   - 01_CORE_MECHANICS.md §9 — Kaveh Event (Farr-collapse revolt)
##   - docs/SIMULATION_CONTRACT.md §1.6 — Numeric Representation principle:
##     Farr is the canonical case for fixed-point integer storage to prevent
##     IEEE-754 platform divergence over a 25-min match (45,000 ticks).
##   - CLAUDE.md — apply_farr_change() chokepoint mandate.
##
## Shahnameh source: Farr (فر) — the divine glory of just rule. In the epic,
## a king who rules justly is granted Farr by Ahura Mazda; a tyrant loses it.
## When Zahhak's Farr collapses, Kaveh the Blacksmith raises his apron-banner
## (the Derafsh-e-Kaviani) and the people revolt. This mechanic makes that
## load-bearing in gameplay: ignore your civilization's righteousness and
## the people will rise against you (§9 Kaveh Event).
##
## Storage: fixed-point int (Farr × 100). 50.0 Farr = 5000 stored. Float
## conversion happens only at HUD/telemetry/balance-tooling boundaries.
##
## Phase 0 session 4 wave 1 deliverable: chokepoint + storage + clamp +
## on-tick assertion. Generators (Atashkadeh +1/min, etc.) and drains
## (worker killed -1, etc.) ship in Phase 4. The Kaveh Event ships in
## Phase 5.
##
## Why extend SimNode (via path-string preload, not class_name)?
## SimNode owns the on-tick mutation chokepoint (_set_sim with assert).
## Extending it means apply_farr_change inherits that discipline for free,
## and the runtime crash-in-debug fires on any off-tick mutation. The
## path-string base is the same workaround used by the StateMachine
## framework (docs/ARCHITECTURE.md §6 v0.4.0): autoloads parse before the
## class_name registry is fully populated, so extending by class_name
## risks a resolution race.

# Internal storage: fixed-point int (Farr × 100). 50.0 Farr = 5000 stored.
# Default holds the spec value from 01_CORE_MECHANICS.md §4.1; the
# BalanceData read in _ready() may overwrite it if the file exists.
var _farr_x100: int = 5000


# === Building-emitter registry (Phase 4 wave 1 — D2) ========================
#
# Buildings whose mere existence emits Farr per minute while standing
# (Atashkadeh +1/min today; Dadgah/Barghah/Yadgar in Tier-2 sub-waves).
# Per 01_CORE_MECHANICS.md §4.3 Farr generators list. A building registers
# via register_emitter(building, farr_per_min) at Stage-2 construction-complete
# and unregisters via unregister_emitter(building) at destruction.
#
# Registry: Dictionary[int, int] keyed by the building's instance id (stable,
# survives the Node going invalid better than a Node-keyed dict for the
# deterministic iteration we need). Value is the per-minute rate in x100
# fixed-point (e.g. Atashkadeh +1/min = 100). Iteration order is insertion
# order in GDScript Dictionaries — deterministic across same-seed runs.
#
# Why store the rate-x100 (not the Node)? The per-tick accrual only needs the
# aggregate rate; we keep a parallel Node ref for the apply_farr_change
# source_unit + the unregister-by-Node lookup.
var _emitter_rate_x100: Dictionary = {}   # instance_id -> farr_per_min_x100 (int)
var _emitter_node: Dictionary = {}        # instance_id -> Node (source_unit ref)

# Fixed-point accumulator for emitter accrual (Sim Contract §1.6 — per-tick
# accumulation, NOT per-minute rounding, so platform float drift can't cross
# the Kaveh/Tier-2 thresholds). Units: x100-Farr × ticks. Each &"farr" phase we
# add the aggregate per-minute rate; when the accumulator crosses one game-
# minute's worth of ticks (SIM_HZ * 60 = 1800 tick-units per whole x100-Farr
# unit-minute), we flush whole-x100-Farr increments through apply_farr_change.
#
# Derivation: a +R/min-x100 emitter contributes R x100-Farr per 1800 ticks, i.e.
# R/1800 x100-Farr per tick. Summing over emitters and accumulating the integer
# numerator (Σ rate_x100) per tick, we flush floor(accum / 1800) whole x100-Farr
# units and keep the remainder. All integer math — deterministic.
var _emitter_accum_numerator: int = 0
const _EMITTER_ACCUM_DENOM: int = SimClock.SIM_HZ * 60   # 1800 ticks/game-minute


# === Royal-largesse upkeep cadence (Phase 4 wave 1 — D3) ====================
#
# Per-game-minute Coin upkeep per living military unit per team. Drains
# TREASURY via ResourceSystem.change_resource (NOT Farr — DECISIONS.md
# 2026-06-22 §1.2). The cadence is a deterministic tick comparison (no
# fixed-point accumulator needed — the interval is a whole-tick count):
# fire when SimClock.tick >= _next_upkeep_tick, then advance by the interval.
#
# _next_upkeep_tick initializes to the interval (1800) so the FIRST drain fires
# at tick 1800 (t=60s), not tick 0 — past workers-reach-mines, no turn-1
# starvation. Re-armed from BalanceData on reset(). -1 sentinel = "not yet
# loaded" (lazy-loaded on first &"farr" phase if reset() didn't run).
var _next_upkeep_tick: int = -1


# Public read accessor — float for HUD / telemetry / consumer code. The
# float conversion happens at the boundary, never in arithmetic. Per Sim
# Contract §1.6.
var value_farr: float:
	get:
		return _farr_x100 / 100.0


## Fixed-point read accessor for telemetry consumers that must avoid the
## float boundary (headless runner NDJSON capture per AI_VS_AI_RESULT_FORMAT
## §7.1). Session-11 data-validity wave — integration mirror C5.3: the doc
## promised this accessor while the runner reflected into the private
## _farr_x100; shipping the accessor makes doc + code agree.
func get_farr_x100() -> int:
	return _farr_x100


# -- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	_load_starting_value_from_balance_data()
	# Phase 3 wave 1B (2026-05-13): the worker-killed-idle drain previously
	# wired through this autoload's unit_died listener (cause-string suffix
	# parsing from Phase 2 session 1) is RETIRED in favor of
	# FarrDrainDispatcher, which subscribes to unit_health_zero (pre-Dying-
	# swap) and dispatches via BalanceData.farr.drain_rates. Open Space
	# resolution 2026-05-13. The legacy listener method below remains in
	# this file but is no longer connected; the body is now a no-op
	# guarded by a deprecation note.
	#
	# Phase 4 wave 1: connect the per-tick &"farr" phase (D2 emitter accrual +
	# D3 upkeep cadence) and the building_destroyed channel (D2 Atashkadeh-loss
	# drain). Canonical wiring pattern (per turan_controller.gd / dummy_iran_
	# controller.gd): subscribe to EventBus.sim_phase + filter to PHASE_FARR in
	# the handler — SimClock declares no per-phase signals; the bus is the seam.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)
	if not EventBus.building_destroyed.is_connected(_on_building_destroyed):
		EventBus.building_destroyed.connect(_on_building_destroyed)
	# Arm the upkeep cadence from BalanceData (first drain at t=60s).
	_arm_upkeep_cadence()


# Defensive load: balance-engineer ships BalanceData.tres in this same wave.
# If the file isn't present yet (or BalanceData.farr is missing), we keep
# the spec default (50.0). This is the "fall back to spec defaults" path
# called out in the kickoff doc and CLAUDE.md.
#
# The lookup path is centralized in Constants.PATH_BALANCE_DATA so a future
# rename is a single-line change.
func _load_starting_value_from_balance_data() -> void:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		# No BalanceData yet — spec defaults stand. Quiet early in the
		# project; later phases may want a push_warning here.
		return
	var bd: Resource = load(path)
	if bd == null:
		push_warning("FarrSystem: BalanceData at %s failed to load; using spec defaults" % path)
		return
	# Duck-typed read: BalanceData may not be class_name-resolvable when the
	# autoload parses (same constraint that drove the SpatialIndex pattern,
	# docs/ARCHITECTURE.md §6 v0.4.0). `bd.get(&"farr")` returns null cleanly
	# if the field doesn't exist on this Resource type.
	var farr_cfg: Variant = bd.get(&"farr")
	if farr_cfg == null:
		return
	var starting: Variant = farr_cfg.get(&"starting_value")
	if typeof(starting) != TYPE_FLOAT and typeof(starting) != TYPE_INT:
		return
	# Convert to fixed-point at the boundary (Sim Contract §1.6). Clamp to
	# the legal Farr range while we're at it — defends against
	# misconfigured BalanceData (validate_hard catches this too, but
	# defense in depth is cheap).
	var starting_x100: int = clampi(roundi(float(starting) * 100.0), 0, 10000)
	_farr_x100 = starting_x100


# -- THE chokepoint ----------------------------------------------------------
#
# All Farr changes flow through this function. Per CLAUDE.md:
#   "All Farr changes flow through a single function:
#    apply_farr_change(amount, reason, source_unit). This is non-negotiable —
#    every Farr movement gets logged and surfaces in the debug overlay."
#
# Contract:
#   - amount: requested delta as a float, in Farr units (e.g., +3.0, -1.0).
#     Converted to fixed-point at the boundary via roundi(amount * 100).
#   - reason: human-readable string for the F2 overlay log
#     ("hero_rescued_worker", "worker_killed_defenseless"). Logged verbatim.
#   - source_unit: optional Node identifying who caused the change. May be
#     null (cosmic events, eclipse drains, etc.). Encoded as -1 sentinel
#     in the signal payload when null, since signals must carry primitives
#     for telemetry-NDJSON serializability (Testing Contract §3.1).
#
# Behavior:
#   1. Asserts SimClock.is_ticking() per Sim Contract §1.3 (the on-tick rule).
#   2. Converts amount to fixed-point delta.
#   3. Computes new value, clamped to [0, 10000] (i.e., [0.0, 100.0]).
#   4. Mutates _farr_x100 via _set_sim (inherited from SimNode — runtime
#      tripwire for off-tick mutation).
#   5. Emits EventBus.farr_changed with the *effective* delta (post-clamp),
#      so downstream consumers see a coherent ledger. Requesting +200 from
#      50 reports +50, not +200 — the meter only moved 50.
#
# Phase 4 will add: generator wiring (per-tick), drain wiring (event-driven),
# snowball-protection helpers. None of those land in this wave.
## Test/lifecycle helper: reset Farr to the BalanceData starting value (or
## spec default 50.0 if BalanceData is unavailable). Called by MatchHarness
## before each simulated match so teardown/restart doesn't leak Farr state.
##
## Cross-domain note (docs/ARCHITECTURE.md §6): reset() is added here at
## qa-engineer's request (Phase 0 session 4 wave 2) per the wave-2 kickoff
## doc's explicit guidance: "gameplay-systems' wave-1 retro flagged that
## reset() not added in this skeleton… You're MatchHarness — you need it.
## Add it (cross-domain, but small; document in §6)."
## Does NOT call apply_farr_change (which asserts on-tick) — writes the
## fixed-point store directly, then emits a synthetic farr_changed so
## subscribers see the reset.
func reset() -> void:
	# Determine the target starting value from BalanceData.
	var target_x100: int = 5000  # spec default (50.0)
	var path: String = Constants.PATH_BALANCE_DATA
	if FileAccess.file_exists(path):
		var bd: Resource = load(path)
		if bd != null:
			var farr_cfg: Variant = bd.get(&"farr")
			if farr_cfg != null:
				var starting: Variant = farr_cfg.get(&"starting_value")
				if typeof(starting) == TYPE_FLOAT or typeof(starting) == TYPE_INT:
					target_x100 = clampi(roundi(float(starting) * 100.0), 0, 10000)

	var old_x100: int = _farr_x100
	_farr_x100 = target_x100

	# Emit synthetic farr_changed so F2 overlay and any subscriber stays
	# consistent. delta = new - old; source_unit_id = -1 (no source).
	# Per Testing Contract §3.1 "_test_set_farr semantics" — same logic applies
	# to reset(). Note: this emit is off-tick (reset is called by MatchHarness
	# before/after match start, outside SimClock ticks). That is intentional and
	# differs from apply_farr_change's on-tick-only contract. The reset() hook
	# is a test-harness escape, not a gameplay mutation path.
	var effective_delta: float = float(target_x100 - old_x100) / 100.0
	EventBus.farr_changed.emit(
		effective_delta,
		"harness_reset",
		-1,
		float(target_x100) / 100.0,
		SimClock.tick,
	)

	# Phase 3 wave 1B: the unit_died subscription is retired in favor of
	# FarrDrainDispatcher (which subscribes to unit_health_zero pre-Dying-
	# swap). reset() no longer re-arms the legacy listener. The dispatcher
	# autoload owns its own subscription lifecycle in _ready.

	# Phase 4 wave 1: clear the emitter registry + accrual accumulator so a
	# building from a prior simulated match doesn't linger (MatchHarness
	# discipline — mirrors ResourceSystem.reset()'s registry clear). Re-arm
	# the upkeep cadence from BalanceData so the first upkeep drain of the
	# next match fires at t=60s relative to that match's tick 0.
	_emitter_rate_x100.clear()
	_emitter_node.clear()
	_emitter_accum_numerator = 0
	_arm_upkeep_cadence()
	print("[farr] reset farr=%.2f emitters=0 next_upkeep_tick=%d" % [
		value_farr, _next_upkeep_tick])


# DEPRECATED (Phase 3 wave 1B Open Space resolution 2026-05-13): the
# worker-killed-idle Farr drain previously routed through this listener
# (subscribed to EventBus.unit_died, parsed an "_idle_worker" cause-string
# suffix that HealthComponent appended). The new path:
#   - FarrDrainDispatcher subscribes to EventBus.unit_health_zero (PRE-Dying
#     state swap), reads unit.fsm.current.id, dispatches via
#     BalanceData.farr.drain_rates.
# This method is retained (not deleted) so any external code mistakenly
# routing calls still observes a defined symbol. Body is a no-op.
#
# HealthComponent still appends the "_idle_worker" suffix to its cause
# emit for telemetry parity with the legacy F2 overlay (Phase 4); future
# cleanup may remove that augmentation entirely.
func _on_unit_died(_unit_id: int, _killer_unit_id: int,
		_cause: StringName, _position: Vector3) -> void:
	pass


func apply_farr_change(amount: float, reason: String, source_unit: Node) -> void:
	# On-tick assertion. Sim Contract §1.3 mandates this for every state-
	# mutating function; CLAUDE.md elevates the apply_farr_change function
	# specifically as the canonical SimNode-style chokepoint.
	assert(SimClock.is_ticking(),
		"Off-tick Farr mutation: amount=%s reason='%s'" % [amount, reason])

	# Boundary conversion: float → fixed-point. roundi() is the deterministic
	# rounding rule (Sim Contract §1.6 — "the rounding rule is part of the
	# domain spec and must be deterministic across platforms"). banker's
	# rounding is not used; roundi rounds half-away-from-zero.
	var delta_x100: int = roundi(amount * 100.0)

	# Compute the new value with clamp. We compute the post-clamp value
	# first, then derive the effective delta from it. This way the signal
	# payload's `amount` field reports what the meter actually moved, not
	# the (possibly oversized) request.
	var pre_x100: int = _farr_x100
	var post_x100: int = clampi(pre_x100 + delta_x100, 0, 10000)
	var effective_delta_x100: int = post_x100 - pre_x100

	# Mutate self via _set_sim — inherits the on-tick assert from SimNode.
	# Per the self-only mutation rule (Sim Contract §1.3): _set_sim mutates
	# `self` exclusively; FarrSystem is a single-instance autoload, so the
	# rule is trivially satisfied — there is no other FarrSystem to reach
	# into.
	_set_sim(&"_farr_x100", post_x100)

	# Convert the source Node to a serializable id. The convention used
	# throughout the project for "no source unit" is the int -1 sentinel
	# (matches Constants.TEAM_ANY's pattern; matches the int -1 used in
	# match_start_tick's "no match" case in GameState).
	var source_unit_id: int = -1
	if source_unit != null:
		# Phase 1+ Unit nodes will have a `unit_id: int` field. Until then,
		# duck-type-read it; fall back to instance id for diagnostics.
		var uid: Variant = source_unit.get(&"unit_id")
		if typeof(uid) == TYPE_INT:
			source_unit_id = uid
		else:
			source_unit_id = source_unit.get_instance_id()

	# Emit. The effective delta and post-clamp value are what consumers
	# care about (telemetry ledger, F2 overlay, Kaveh trigger). The tick
	# is captured here, not at consumer time, so the payload is immutable
	# regardless of when the consumer reads it.
	EventBus.farr_changed.emit(
		float(effective_delta_x100) / 100.0,
		reason,
		source_unit_id,
		value_farr,
		SimClock.tick,
	)


# === D2 — Building-emitter registry API =====================================
#
# Source: 01_CORE_MECHANICS.md §4.3 (Farr generators — "Atashkadeh +1 Farr/min,
# Dadgah +0.5, Barghah +0.5, Yadgar +0.25 post-hero-death"). A building whose
# continuous existence generates Farr registers here at Stage-2 construction-
# complete; the per-tick accrual happens in the &"farr" sim phase.
#
# Cultural referent (CLAUDE.md — keep the setting in the code's bones):
# the Atashkadeh emits Farr because the sacred flame is being KEPT, continuously
# — the mechanic IS the theology (the just king's legitimacy flows from the
# tended fire, Hushang's founding fire per 00_SHAHNAMEH_RESEARCH.md §1; Farr-ī
# Yazdān §229-231). NOT a metaphor laid over the mechanic.

## Register a Farr-emitting building. farr_per_min is in WHOLE Farr units per
## minute (e.g. Atashkadeh = 1.0). Converted to x100 fixed-point at this
## boundary (Sim Contract §1.6) for the integer per-tick accrual. Idempotent:
## re-registering the same building updates its rate (last-writer-wins) without
## duplicating — a building never double-counts.
##
## Called by Atashkadeh._on_construction_complete (Stage-2 operational flip).
## The per-tick emit routes through apply_farr_change inside _flush_emitter_
## accrual — chokepoint discipline preserved (CLAUDE.md).
func register_emitter(building: Node, farr_per_min: float) -> void:
	if building == null or not is_instance_valid(building):
		push_error("FarrSystem.register_emitter: null/invalid building — no-op.")
		return
	var id: int = building.get_instance_id()
	var rate_x100: int = roundi(farr_per_min * 100.0)
	var already: bool = _emitter_rate_x100.has(id)
	_emitter_rate_x100[id] = rate_x100
	_emitter_node[id] = building
	# §9.M6 — log register (one-shot per building). emitters count + aggregate
	# rate in the suffix for quick "how much Farr is being generated" diagnosis.
	print("[farr] register_emitter node=%s rate_x100/min=%d (%s) emitters=%d aggregate_x100/min=%d" % [
		str(building), rate_x100, ("update" if already else "new"),
		_emitter_rate_x100.size(), _aggregate_emitter_rate_x100()])


## Remove a building from the emitter registry. Idempotent — unregistering an
## unknown building is a no-op (logged so the audit trail shows the attempt).
## Called by the building_destroyed handler (a destroyed Atashkadeh stops
## emitting) AND directly by a building's teardown if it ever needs to.
func unregister_emitter(building: Node) -> void:
	if building == null:
		return
	var id: int = building.get_instance_id()
	if not _emitter_rate_x100.has(id):
		# Not registered (already unregistered, or never was) — log the bail so
		# the audit trail shows the no-op (observability: why nothing changed).
		print("[farr] unregister_emitter node=%s — not registered, no-op" % str(building))
		return
	var rate_x100: int = int(_emitter_rate_x100[id])
	_emitter_rate_x100.erase(id)
	_emitter_node.erase(id)
	print("[farr] unregister_emitter node=%s rate_x100/min=%d emitters=%d aggregate_x100/min=%d" % [
		str(building), rate_x100, _emitter_rate_x100.size(),
		_aggregate_emitter_rate_x100()])


## Introspection helper — true if the building is currently a registered
## emitter. Used by tests + the F2 overlay; not a hot-path consumer surface.
func is_emitter_registered(building: Node) -> bool:
	if building == null:
		return false
	return _emitter_rate_x100.has(building.get_instance_id())


## Count of registered emitters. Tests + diagnostics.
func emitter_count() -> int:
	return _emitter_rate_x100.size()


# Sum of all registered per-minute rates (x100 fixed-point). Deterministic:
# integer sum over Dictionary values (insertion-order iteration).
func _aggregate_emitter_rate_x100() -> int:
	var total: int = 0
	for id in _emitter_rate_x100:
		total += int(_emitter_rate_x100[id])
	return total


# === Per-tick &"farr" phase handler (D2 accrual + D3 upkeep) ================
#
# Canonical phase-coordinator shape (per dummy_iran_controller.gd / turan_
# controller.gd): subscribe to EventBus.sim_phase, branch on PHASE_FARR. Runs
# in the &"farr" phase (Sim Contract §2 phase 7 — AFTER combat, so emitter
# gains + upkeep see post-combat unit counts). SimClock.is_ticking() is true
# here by construction, satisfying the apply_farr_change / change_resource
# on-tick asserts.
func _on_sim_phase(phase: StringName, tick: int) -> void:
	if phase != Constants.PHASE_FARR:
		return
	_flush_emitter_accrual()
	_run_upkeep_cadence(tick)


# D2 — Per-tick fixed-point emitter accrual. Adds the aggregate per-minute rate
# (x100) to the integer numerator; flushes whole x100-Farr units when the
# accumulator crosses a game-minute's worth of ticks (1800). Per-tick
# accumulation (NOT per-minute rounding) per Sim Contract §1.6 determinism —
# the integer numerator can't drift across platforms.
#
# Example: a single Atashkadeh (rate_x100/min = 100) accrues 100 per tick into
# the numerator. After 1800 ticks (1 game-min) the numerator is 180000;
# 180000 / 1800 = 100 whole x100-Farr units flushed = +1.00 Farr. Exact.
func _flush_emitter_accrual() -> void:
	var aggregate_x100_per_min: int = _aggregate_emitter_rate_x100()
	if aggregate_x100_per_min == 0:
		# No emitters — nothing to accrue. No log (this is the common per-tick
		# case before any Atashkadeh is built; logging every tick would spam).
		return
	_emitter_accum_numerator += aggregate_x100_per_min
	if _emitter_accum_numerator < _EMITTER_ACCUM_DENOM:
		return  # Less than one whole x100-Farr unit accrued yet — keep waiting.
	# Flush the whole-x100-Farr units; keep the remainder for the next tick.
	var whole_x100_farr: int = _emitter_accum_numerator / _EMITTER_ACCUM_DENOM
	_emitter_accum_numerator -= whole_x100_farr * _EMITTER_ACCUM_DENOM
	# Route through the chokepoint. apply_farr_change takes a FLOAT Farr amount
	# (it re-multiplies by 100 internally); we computed whole x100-Farr units, so
	# divide by 100 at the call boundary. source_unit = the first registered
	# emitter (a representative; the F2 log carries the reason token regardless).
	var source: Node = _first_emitter_node()
	apply_farr_change(
		float(whole_x100_farr) / 100.0,
		String(Constants.FARR_REASON_ATASHKADEH_EMISSION),
		source)


# Return any registered emitter Node (for apply_farr_change's source_unit). The
# emission is an aggregate; the source is representative, not authoritative.
# Returns null if the only emitters have gone invalid (defensive).
func _first_emitter_node() -> Node:
	for id in _emitter_node:
		var n: Variant = _emitter_node[id]
		if n != null and is_instance_valid(n):
			return n
	return null


# === D3 — Royal-largesse Coin upkeep ========================================
#
# Source: DECISIONS.md 2026-06-22 §1.2 + 01_CORE_MECHANICS.md §4 (economy
# staging). Per game-minute, drain Coin per living military unit per team via
# ResourceSystem.change_resource (TREASURY, NOT Farr — keeps the Farr meter
# pure for justice/legitimacy; economy down-flow per SHAHNAMEH_ECONOMY_
# RESEARCH.md §6.2).
#
# Cultural referent: royal largesse = the just king's obligation to sustain his
# army from the treasury (down-flow generosity). A stalled army still eats.
#
# Cadence is a deterministic whole-tick comparison (no fixed-point accumulator —
# the interval is an integer tick count). Fires when tick >= _next_upkeep_tick,
# then advances by the interval. First fire at tick = interval (t=60s).
func _run_upkeep_cadence(tick: int) -> void:
	if _next_upkeep_tick < 0:
		# Cadence not armed yet (reset() / _ready not run with BalanceData). Arm
		# lazily so a bare-autoload test still gets deterministic behavior.
		_arm_upkeep_cadence()
	if tick < _next_upkeep_tick:
		return
	# Advance the cadence FIRST (so a single missed catch-up tick can't double-
	# fire; if the sim ever skips ticks the next fire still lands on the grid).
	var interval: int = _upkeep_interval_ticks()
	_next_upkeep_tick = tick + interval
	var coin_per_unit: int = _upkeep_coin_per_military_unit()
	if coin_per_unit <= 0:
		print("[farr] upkeep tick=%d — coin_per_unit=%d (<=0), no drain" % [
			tick, coin_per_unit])
		return
	# Drain per team. Workers do NOT count (standing-army cost only).
	for team in [Constants.TEAM_IRAN, Constants.TEAM_TURAN]:
		var military_count: int = _count_living_military_for_team(team)
		if military_count == 0:
			# Observability: log the bail (zero military → zero drain).
			print("[farr] upkeep tick=%d team=%d military=0 — no drain" % [tick, team])
			continue
		# 8 coin/unit → -8*count coin → -800*count x100 (Sim Contract §1.6).
		var coin_drain: int = coin_per_unit * military_count
		ResourceSystem.change_resource(
			team,
			Constants.KIND_COIN,
			-coin_drain * 100,
			Constants.RESOURCE_REASON_ROYAL_LARGESSE_UPKEEP,
			self)
		print("[farr] upkeep tick=%d team=%d military=%d coin_drain=%d next=%d" % [
			tick, team, military_count, coin_drain, _next_upkeep_tick])


# Count living military units of a team. "Living" = NOT is_dying() (Fix F2 —
# is_dying() is the canonical Dying-state predicate on Unit; NOT get_health()
# which returns the always-non-null HealthComponent node). Workers (Kargar) are
# excluded — upkeep is a standing-army cost. Enumerates the canonical &"units"
# group (every Unit joins at unit.gd:268).
func _count_living_military_for_team(team: int) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"units"):
		if not is_instance_valid(node):
			continue
		var node_team: Variant = node.get(&"team")
		if typeof(node_team) != TYPE_INT or int(node_team) != team:
			continue
		if not _is_living_military(node):
			continue
		count += 1
	return count


# True if `unit` is a LIVING MILITARY unit: not dying, and its unit_type is in
# Constants.MILITARY_UNIT_TYPES. Shared by D3 (upkeep) and D1a (snowball pop
# sums use the same living-predicate via the dispatcher). Centralizes the F2
# alive-predicate contract: is_dying() — NOT get_health().
func _is_living_military(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# Alive predicate: is_dying() is the canonical Dying-state check (Fix F2).
	# Duck-typed (registry-race per ARCHITECTURE §6 v0.4.0); a unit lacking the
	# method is treated as not-dying (the field-default for a non-FSM stub).
	if unit.has_method(&"is_dying") and bool(unit.call(&"is_dying")):
		return false
	var ut: Variant = unit.get(&"unit_type")
	if typeof(ut) != TYPE_STRING_NAME:
		return false
	return Constants.MILITARY_UNIT_TYPES.has(ut)


# Arm the upkeep cadence: _next_upkeep_tick = the interval, so the first drain
# fires at tick = interval (t=60s @30Hz with the default 1800). Called from
# _ready + reset.
func _arm_upkeep_cadence() -> void:
	_next_upkeep_tick = _upkeep_interval_ticks()


func _upkeep_interval_ticks() -> int:
	var econ: Variant = _economy_config()
	if econ == null:
		return SimClock.SIM_HZ * 60  # spec default: 1 game-minute @30Hz = 1800
	var v: Variant = econ.get(&"royal_largesse_upkeep_interval_ticks")
	if typeof(v) == TYPE_INT and int(v) > 0:
		return int(v)
	return SimClock.SIM_HZ * 60


func _upkeep_coin_per_military_unit() -> int:
	var econ: Variant = _economy_config()
	if econ == null:
		return 0  # No BalanceData → no upkeep (test scenes without balance.tres).
	var v: Variant = econ.get(&"royal_largesse_upkeep_coin_per_military_unit")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


# Load EconomyConfig from BalanceData. Cached on first call (the path is read
# every cadence-arm + every upkeep fire; one load is enough). Defensive: returns
# null if BalanceData is absent (test scenes loading the autoload in isolation).
var _economy_cfg_cache: Variant = null

func _economy_config() -> Variant:
	if _economy_cfg_cache != null:
		return _economy_cfg_cache
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	_economy_cfg_cache = bd.get(&"economy")
	return _economy_cfg_cache


# === D2 — Atashkadeh-loss drain (building_destroyed channel) ================
#
# Source: 01_CORE_MECHANICS.md §4.3 Drains ("Loss of an Atashkadeh building:
# −5 Farr — the sacred flame is extinguished"). When ANY building is destroyed
# we (a) unregister it as an emitter (a destroyed Atashkadeh stops generating),
# and (b) if it was an Atashkadeh, fire the -5 legitimacy drain.
#
# Cultural referent: losing the Atashkadeh is not "building lost" damage — it is
# *sacred-flame extinguished* damage. The discontinuity itself is the wound
# (the continuity of the tended fire is the continuity of legitimate rule).
#
# Runs in the &"combat"/&"cleanup" phase (building_destroyed emits from
# Building._on_health_zero, fired in the combat phase via HealthComponent), so
# SimClock.is_ticking() holds — apply_farr_change's on-tick assert is satisfied.
func _on_building_destroyed(team_id: int, kind: StringName, building_unit_id: int) -> void:
	# (a) Unregister the building as a Farr emitter regardless of kind — a
	# destroyed building can no longer keep its flame. We resolve the Node by
	# instance id from the emitter registry (the signal carries unit_id, not the
	# Node, but our registry is keyed by instance id; we scan for a match on the
	# building's own unit_id field).
	_unregister_emitter_by_building_unit_id(building_unit_id)
	# (b) Atashkadeh-loss drain. Only the sacred-flame building drains Farr on
	# destruction this wave (civilian/military building-loss drains are
	# forward-compat keys, not wired here).
	# Compare the StringName (NOT Atashkadeh.KIND_ATASHKADEH class_name ref) —
	# autoloads parse before the class_name registry populates (registry race,
	# ARCHITECTURE §6 v0.4.0). Constants.BUILDING_KIND_ATASHKADEH = &"atashkadeh".
	if kind != Constants.BUILDING_KIND_ATASHKADEH:
		print("[farr] building_destroyed team=%d kind=%s unit_id=%d — not Atashkadeh, no Farr drain" % [
			team_id, str(kind), building_unit_id])
		return
	var magnitude: float = _lookup_drain_magnitude(Constants.FARR_DRAIN_KEY_ATASHKADEH_LOST)
	if magnitude <= 0.0:
		print("[farr] atashkadeh_lost team=%d — drain magnitude <=0 (key missing?), no drain" % team_id)
		return
	# Negative sign at the call site (positive magnitudes stored — convention
	# matching FarrDrainDispatcher). source_unit = null (the building is freed).
	apply_farr_change(
		-magnitude,
		String(Constants.FARR_REASON_ATASHKADEH_LOST),
		null)
	print("[farr] atashkadeh_lost team=%d unit_id=%d drain=-%.2f" % [
		team_id, building_unit_id, magnitude])


# Find a registered emitter whose Node's `unit_id` matches the destroyed
# building's unit_id, and unregister it. The building_destroyed signal carries
# the building's unit_id (distinct id-space from Units per BUG-G1); our registry
# is keyed by instance id, so we scan the registry for the matching Node.
func _unregister_emitter_by_building_unit_id(building_unit_id: int) -> void:
	var match_node: Node = null
	for id in _emitter_node:
		var n: Variant = _emitter_node[id]
		if n == null or not is_instance_valid(n):
			continue
		var uid: Variant = (n as Node).get(&"unit_id")
		if typeof(uid) == TYPE_INT and int(uid) == building_unit_id:
			match_node = n as Node
			break
	if match_node != null:
		unregister_emitter(match_node)


# Look up a drain magnitude by key from BalanceData.farr.drain_rates. Returns
# 0.0 for missing keys (caller bails — no spurious zero-delta emit). Mirrors
# FarrDrainDispatcher._lookup_drain_magnitude (the dispatcher owns the snowball
# drains; FarrSystem owns the Atashkadeh-loss drain — both read the same table).
func _lookup_drain_magnitude(key: StringName) -> float:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0.0
	var bd: Resource = load(path)
	if bd == null:
		return 0.0
	var farr_cfg: Variant = bd.get(&"farr")
	if farr_cfg == null:
		return 0.0
	var rates: Variant = farr_cfg.get(&"drain_rates")
	if typeof(rates) != TYPE_DICTIONARY:
		return 0.0
	var raw: Variant = (rates as Dictionary).get(key, 0.0)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return 0.0
	return float(raw)


func _exit_tree() -> void:
	# Symmetric teardown so a freed/reloaded autoload doesn't keep handling
	# phase + destruction signals. Mirrors dummy_iran_controller.gd:280.
	if EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.disconnect(_on_sim_phase)
	if EventBus.building_destroyed.is_connected(_on_building_destroyed):
		EventBus.building_destroyed.disconnect(_on_building_destroyed)
