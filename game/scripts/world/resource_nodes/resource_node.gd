extends Node3D
##
## ResourceNode — abstract base for harvestable map entities (mines, farms).
##
## Per docs/RESOURCE_NODE_CONTRACT.md §1 (type hierarchy) + §4 (consumer API).
## Phase 3 wave 1A — kickoff doc 02f_PHASE_3_KICKOFF.md §3.
##
## Wave 1A subclasses: MineNode (Coin). Wave-1B+ adds Mazra'eh (Grain). The
## worker's UnitState_Gathering / UnitState_Returning treat both identically
## via this base class — no subclass branching in consumer code.
##
## API naming — wave-1A kickoff vs contract:
##   The kickoff (02f_PHASE_3_KICKOFF.md §3) specifies the three-call API as
##   request_extract / complete_extract / release_extract. The original
##   contract (docs/RESOURCE_NODE_CONTRACT.md §4) had named these
##   begin_extract / tick_extract / release_extract with per-tick yield
##   accumulation. The kickoff replaced tick-with-accumulator with a simpler
##   "request → dwell-on-state-side → complete" pattern: the gathering state
##   owns the dwell timer locally, and the node only needs to know "give me
##   the slot, give me the payload when I'm done."
##
##   This is the right surface for wave 1A because:
##     1. The state has the dwell timer anyway (extract_ticks counts down on
##        the state, not the node). Moving the yield accumulation off the
##        node simplifies the node's _sim_tick (it doesn't need one for the
##        wave-1A path — depletion is computed at complete_extract time).
##     2. Per-worker partial-carry tracking from a tick-accumulating extract
##        would require the node to maintain a per-worker progress
##        dictionary AND have a deferred-emit cleanup. Lifting both off the
##        node keeps the wave-1A surface small.
##   If wave 1B's Mazra'eh needs progressive yield (slow accumulation over
##   many ticks vs the mine's chunk-per-trip), the contract may revert to
##   the tick_extract shape — see RESOURCE_NODE_CONTRACT §1.5 escalation.
##
## What this base class DOES:
##   - Pins the field schema (kind, reserves_x100, extract_ticks, max_slots,
##     is_gatherable) every subclass exposes.
##   - Owns slot-occupancy bookkeeping (a small set of unit_ids currently
##     extracting). Caps at max_slots; rejects double-grants per worker.
##   - Implements request_extract / release_extract / complete_extract with
##     defensive idempotency for the death-path per contract §4.1.
##   - Flips is_gatherable false when reserves hit zero. Subclasses override
##     _on_depleted (called from inside complete_extract) to add the
##     concrete cleanup (e.g., MineNode.queue_free.call_deferred()).
##
## What this base class does NOT do:
##   - Visuals (mesh, material) — subclass scenes own those.
##   - NavigationObstacle3D — added at the subclass scene level when needed
##     (mines yes; farms walked-on, no — per contract §3.2).
##   - BalanceData consumption — subclass _ready reads the per-kind config.
##   - ResourceSystem registration — wave 1B; the contract §2.3 mandates
##     subclass _ready calls ResourceSystem.register_node(self).
##
## Why extend Node3D directly (not SimNode):
##   SimNode is `extends Node`, but a ResourceNode lives in the world and
##   must expose global_position to workers (they pathfind to it). The
##   SimNode discipline still applies — mutations of reserves_x100 and
##   is_gatherable happen inside _sim_tick or other on-tick contexts — but
##   we don't get the _set_sim assert for free. We could compose a child
##   SimNode for state-storage, but the cost outweighs the benefit at this
##   scope (one MineNode, one Mazra'eh). The on-tick discipline is
##   preserved by construction: every mutation is called from
##   complete_extract / request_extract / release_extract, all invoked from
##   the worker's _sim_tick.
##
##   The same composition tradeoff appears in Unit / CharacterBody3D vs
##   SimNode (see unit.gd header) — we accept the same compromise here.

# === Schema fields ===========================================================

## Resource kind. Subclass sets in _init or _ready. &"coin" (MineNode) /
## &"grain" (Mazra'eh, wave 1B+).
@export var kind: StringName = &""

## Remaining reserves in x100 fixed-point per Sim Contract §1.6. -1 sentinel
## means "infinite" (Mazra'eh, per RESOURCE_NODE_CONTRACT.md §1.5); positive
## integer counts down per complete_extract. Default 0 forces subclasses to
## set this explicitly (a node with 0 reserves is depleted at spawn — visible
## bug, fail-loud).
@export var reserves_x100: int = 0

## Number of sim ticks a gathering worker dwells at the node before
## complete_extract fires. State-side timer; the node itself doesn't tick on
## this in wave 1A. Subclass / BalanceData sets the kind-specific value.
@export var extract_ticks: int = 1

## Maximum simultaneous gathering workers. Wave 1A default 1 (Phase 3
## simplification per kickoff §3). Contract §1.3 lets MineNode raise to 2
## post-MVP; balance-engineer tunes via BalanceData.
@export var max_slots: int = 1

## False when the node is depleted, destroyed, or under construction.
## request_extract rejects when false. Subclasses flip via _set_sim during
## their lifecycle transitions (construction-complete, fatal damage).
var is_gatherable: bool = true

## Per-trip carry size in x100 fixed-point. The amount one complete_extract
## payload pays out. Subclass / BalanceData sets the kind-specific value.
## Wave 1A: MineNode defaults to a per-trip chunk of reserves (see mine_node.gd).
@export var yield_per_trip_x100: int = 100  # 1.0 unit per trip default


# === Slot bookkeeping ========================================================
# Set of unit_ids currently holding a gather slot. Using Dictionary as a set
# (value = true) for O(1) lookup + iteration. Workers identify themselves by
# unit_id in the request/release pair — the slot is keyed on identity, not
# on a Node ref, so a worker who dies and is queue_free'd doesn't strand its
# slot (the state's exit() calls release_extract with the unit_id before the
# Node goes away).

var _occupied: Dictionary = {}  # unit_id (int) -> true


# === Group membership =======================================================
#
# Self-add to &"resource_nodes" group on _ready so consumers (Ma'dan's
# placement adjacency search, future Phase 6 AI scouting, telemetry sinks)
# can enumerate the canonical resource-source list without walking the
# entire SceneTree or relying on ResourceSystem.register_node (which the
# wave-1A MineNode path does NOT call — see register_node v1.2.1 §9.X note
# in RESOURCE_NODE_CONTRACT.md).
#
# Mirrors the &"buildings" group convention from Building._ready. Mazra'eh
# (which extends Building, not ResourceNode) is NOT in &"resource_nodes"
# even though it duck-types the gather API — Mazra'eh is in &"buildings"
# instead. Consumers iterating &"resource_nodes" specifically want
# MineNode-shape source nodes (map-placed, raycast-routed coin/grain
# sources). Wave-1B Ma'dan's adjacency-search iterates this group.
#
# Added in wave 1B (2026-05-15) as the cross-cutting seam for Ma'dan's
# nearest-mine discovery. Existing MineNode behavior unchanged.
func _ready() -> void:
	add_to_group(&"resource_nodes")


## Returns the count of slots currently occupied. Used by tests and the F4
## debug overlay; production consumers branch on request_extract's bool
## return, not this counter.
func occupied_slots() -> int:
	return _occupied.size()


# === Three-call API (per kickoff doc) ========================================

## Worker requests a gather slot. Returns true if granted, false otherwise.
## Reasons for false: node not gatherable (depleted, under construction,
## destroyed), all slots taken, this unit_id already holds a slot here.
##
## Sanctioned write: this method may be called from off-tick contexts if a
## state transition requests it from enter() (which itself runs inside the
## owning unit's _sim_tick). The slot dict mutation is a self-contained
## bookkeeping field; the SimNode _set_sim discipline doesn't apply since
## ResourceNode extends Node3D (see header rationale).
func request_extract(unit_id: int) -> bool:
	if not is_gatherable:
		return false
	if _occupied.has(unit_id):
		return false  # double-grant guard
	if _occupied.size() >= max_slots:
		return false
	_occupied[unit_id] = true
	return true


## Worker releases the slot. Called from UnitState_Gathering.exit() per
## RESOURCE_NODE_CONTRACT §4.1 ("always called even on death"). Idempotent —
## releasing an unowned worker is a no-op so the death-path doesn't have
## to branch on "did I actually claim this slot."
func release_extract(unit_id: int) -> void:
	if _occupied.has(unit_id):
		_occupied.erase(unit_id)


## Worker completes a gather trip. Returns the carry payload Dictionary:
##   { kind: StringName, amount_x100: int }
## Decrements the node's reserves by the carry amount. Frees the slot the
## worker held. Flips is_gatherable false (and calls _on_depleted) when
## reserves reach 0.
##
## For an unknown / un-granted worker, returns an empty payload
## (kind=&"", amount_x100=0) without mutating state. The state's
## complete-then-exit ordering means a buggy state could theoretically
## complete twice; the empty payload is the diagnostic.
##
## Must be called inside a sim tick (the worker's _sim_tick is the caller).
## Subclasses overriding _on_depleted run their cleanup from inside the
## same call.
func complete_extract(unit_id: int) -> Dictionary:
	if not _occupied.has(unit_id):
		return {&"kind": &"", &"amount_x100": 0}
	_occupied.erase(unit_id)
	# Determine the chunk size. For finite reserves, never overdraw.
	var amount_x100: int = yield_per_trip_x100
	if reserves_x100 >= 0 and amount_x100 > reserves_x100:
		amount_x100 = reserves_x100
	if reserves_x100 >= 0:
		reserves_x100 -= amount_x100
	# Depletion check. Negative sentinel (-1, Mazra'eh) skips this branch —
	# Mazra'eh only stops yielding on destruction (contract §1.5).
	if reserves_x100 == 0:
		is_gatherable = false
		_on_depleted()
	return {&"kind": kind, &"amount_x100": amount_x100}


# === Subclass hooks ==========================================================

## Called from inside complete_extract once reserves hit zero. Subclasses
## override to add concrete cleanup (MineNode.queue_free.call_deferred()).
## Base class is a no-op so non-depleting subclasses (Mazra'eh with
## reserves_x100 = -1) need no override.
func _on_depleted() -> void:
	pass
