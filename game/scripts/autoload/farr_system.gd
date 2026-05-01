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


# Public read accessor — float for HUD / telemetry / consumer code. The
# float conversion happens at the boundary, never in arithmetic. Per Sim
# Contract §1.6.
var value_farr: float:
	get:
		return _farr_x100 / 100.0


# -- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	_load_starting_value_from_balance_data()


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
