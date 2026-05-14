extends "res://scripts/world/resource_nodes/resource_node.gd"
##
## MineNode — the Coin-yielding ResourceNode subclass.
##
## Source: 01_CORE_MECHANICS.md §3 (Iran economy — Coin / sekkeh as the
## currency of military production) + docs/RESOURCE_NODE_CONTRACT.md §1.3.
## Phase 3 wave 1A — kickoff doc 02f_PHASE_3_KICKOFF.md §3.
##
## Cultural note: in the Shahnameh, coins (سکّه — sekkeh) are the visible
## evidence of legitimate kingship — kings mint their own coinage to
## announce sovereignty (cf. Kavus, Khosrow, the contested mints of the
## Sassanid era). For Iran, coin-mining mines on the map are the player's
## first economic anchor — Tier 1 of the game's currency loop.
##
## Wave 1A scope:
##   - Hardcoded reserves (100 Coin × 100 fixed-point = 10000 x100 units).
##     Wave 1B reads this from BalanceData; for wave 1A, the value lives in
##     this script with a TODO citing wave 1B.
##   - Single slot per mine (Phase 3 simplification per kickoff §3). The
##     contract §1.3 allows 2 long-term; balance-engineer raises after
##     playtest.
##   - On depletion: queue_free.call_deferred() per Known Pitfall #8 — we're
##     inside complete_extract which runs inside the worker's _sim_tick (a
##     tree-mutating context); the deferred form is the canonical path. Tests
##     observing the free must await ≥2 process_frame (Pitfall #8) or ≥3 in
##     deeper test trees.
##
## What lives here vs in the base class:
##   - kind = &"coin", concrete reserves wiring, queue_free at depletion.
## Base ResourceNode owns the schema, slot bookkeeping, the three-call API.
##
## Visual placeholder per CLAUDE.md "colored shapes only":
##   - Yellow cylinder (~1.5 wide × 0.5 tall). The "Iran-coin gold" color
##     `Color(0.85, 0.7, 0.2)` per kickoff §3 — saturated enough to stay
##     readable against the sandy terrain. Lead live-tests visibility post-
##     wave-1A and adjusts if it bleeds into the terrain like the FarrGauge
##     did pre-Phase 2 session 1's contrast fix.
##
## Why extend by path-string (not class_name):
## Same class_name registry race that bites Unit / Kargar (see kargar.gd
## header). MineNode scripts may be parsed during scene-tree warm-up before
## the ResourceNode class_name is in the global registry. Path-string
## extends sidesteps the race entirely. Wave 1B's Mazra'eh follows the same
## pattern.

# Wave-1A hardcoded reserves. TODO(phase-3-wave-1B): read from
# BalanceData.economy.resource_nodes.mine_initial_stock once the autoload +
# config sub-resource ship. Per RESOURCE_NODE_CONTRACT §7: 1500 is the
# starting point balance-engineer drafted; for wave 1A we use a smaller
# round-trippable number (100 Coin per mine, 10000 x100) so depletion is
# easily observable in playtest within a single match minute.
const _WAVE_1A_RESERVES_X100: int = 10000  # 100 Coin per mine

# Per-trip carry size. TODO(phase-3-wave-1B): read from
# BalanceData.economy.resource_nodes.coin_yield_per_trip. Default 10 Coin
# per trip = 1000 x100. Means 10 trips per mine before depletion at the
# wave-1A reserve level — observable in lead's first live-test loop.
const _WAVE_1A_YIELD_PER_TRIP_X100: int = 1000  # 10 Coin per trip

# Per-trip dwell time in sim ticks. TODO(phase-3-wave-1B): read from
# BalanceData.economy.resource_nodes.trip_full_load_ticks. 60 ticks at
# SIM_HZ=30 = 2 seconds dwell at the node — feels like "the worker is
# actually doing something" without being so long that the lead loses
# attention mid-trip during the first live test.
const _WAVE_1A_EXTRACT_TICKS: int = 60


func _init() -> void:
	# Configure the schema fields BEFORE _ready so the base class sees the
	# right values. The unit.gd / kargar.gd dual-init pattern (set in _init
	# AND _ready) is overkill here — MineNode has no @export field the scene
	# could clobber between _init and _ready. Set once.
	kind = Constants.KIND_COIN
	reserves_x100 = _WAVE_1A_RESERVES_X100
	yield_per_trip_x100 = _WAVE_1A_YIELD_PER_TRIP_X100
	extract_ticks = _WAVE_1A_EXTRACT_TICKS
	max_slots = 1  # Phase 3 simplification per kickoff §3
	is_gatherable = true


# Pitfall #8 awareness — call_deferred form because we're running inside
# complete_extract, which is called from the worker state's _sim_tick (a
# tree-mutating context per the StateMachine transition mechanism). The
# direct queue_free here would race with the FSM's own tree mutations.
# Tests verifying the free must await ≥2 process_frame (see test_mine_node.gd
# test_depleted_mine_queues_self_for_free).
#
# Pitfall #11 awareness: integration tests using SimClock._test_run_tick()
# loops will NOT observe the free (no process_frame between iterations).
# Those tests use `is_gatherable == false` as the depletion predicate
# instead of `is_instance_valid(node)`. The MineNode unit tests above
# follow the await-process_frame pattern; integration tests in wave 1B
# (ResourceSystem) / wave 3 (full loop) should follow Pitfall #11.
func _on_depleted() -> void:
	queue_free.call_deferred()
