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
## Config source (wave/b1-mine-ssot SSOT fix, 2026-06-08 — review ARCH-5/GP-3):
##   - All four tunables (reserves, max_slots, yield per trip, dwell ticks)
##     are read from BalanceData.economy.resource_nodes at _ready via the
##     canonical defensive lookup chain (BUG-C1 pattern; mirrors
##     building.gd::_resolve_max_hp). RNC §7 is the schema SSOT:
##     mine_initial_stock=1500, mine_max_workers=2, coin_yield_per_trip=10,
##     trip_full_load_ticks=60. Designer tunes data/balance.tres; this script
##     holds no live gameplay numbers — only §9.L9 visible fallbacks.
##   - Pre-fix history: wave 1A hardcoded 100-Coin reserves + 1 slot "with a
##     TODO citing wave 1B"; the TODO was never executed, so designer edits
##     to the .tres keys silently did nothing (Track-1 Findings A+B).
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

# §9.L9 visible-fallback values — used ONLY when the BalanceData read in
# _ready fails (file missing / null load / schema-shape mismatch). These
# are deliberately the small wave-1A numbers, NOT the production RNC §7
# values: a fallback mine holds 100 Coin and depletes in 10 trips — fast
# enough to be DIAGNOSABLE in any playtest minute, never silently "fine"
# (fallback-by-failure-visibility-shape). The "[mine] balance_config_missing"
# log line in _resolve_balance_config is the companion signal.
const _FALLBACK_RESERVES_X100: int = 10000        # 100 Coin — depletes in 10 trips
const _FALLBACK_YIELD_PER_TRIP_X100: int = 1000   # 10 Coin per trip
const _FALLBACK_EXTRACT_TICKS: int = 60           # 2s dwell at SIM_HZ=30
const _FALLBACK_MAX_SLOTS: int = 1

# Fixed-point scale per Sim Contract §1.6: BalanceData resource-node keys
# are whole-unit ints (RNC §7); sim-side reserves/yield are x100 ints.
const _X100: int = 100


func _init() -> void:
	# Configure the schema fields BEFORE _ready so the base class sees the
	# right values. The unit.gd / kargar.gd dual-init pattern (set in _init
	# AND _ready) is overkill here — MineNode has no @export field the scene
	# could clobber between _init and _ready. Set once; _ready overwrites
	# from BalanceData (the fallbacks only survive when that read fails).
	kind = Constants.KIND_COIN
	reserves_x100 = _FALLBACK_RESERVES_X100
	yield_per_trip_x100 = _FALLBACK_YIELD_PER_TRIP_X100
	extract_ticks = _FALLBACK_EXTRACT_TICKS
	max_slots = _FALLBACK_MAX_SLOTS
	is_gatherable = true


func _ready() -> void:
	super._ready()  # &"resource_nodes" group join (Ma'dan adjacency seam)
	_resolve_balance_config()


# Read the four mine tunables from BalanceData.economy.resource_nodes via
# the canonical defensive Variant lookup chain (BUG-C1 + §9.L11; mirrors
# building.gd::_resolve_max_hp and mazraeh.gd::_resolve_fog_sight_cells).
# Schema SSOT: RNC §7 ("MineNode._ready() reads its starting stock from
# BalanceData.economy.resource_nodes.mine_initial_stock").
#
# Whole-unit keys (mine_initial_stock, coin_yield_per_trip) convert to x100
# fixed-point here; tick/slot keys are used as-is. One config_resolved log
# per node per §9.M6 (single _ready-time mutation, not a per-tick path).
func _resolve_balance_config() -> void:
	var cfg: Resource = _resource_node_config_or_null()
	if cfg == null:
		# §9.L9 visible fallback — loud log so a misconfigured BalanceData
		# is diagnosable from the scroll, never silent.
		print("[mine] balance_config_missing — using visible fallbacks "
			+ "reserves_x100=%d max_slots=%d yield_per_trip_x100=%d extract_ticks=%d"
			% [reserves_x100, max_slots, yield_per_trip_x100, extract_ticks])
		return
	reserves_x100 = _cfg_int(cfg, &"mine_initial_stock",
		_FALLBACK_RESERVES_X100 / _X100) * _X100
	yield_per_trip_x100 = _cfg_int(cfg, &"coin_yield_per_trip",
		_FALLBACK_YIELD_PER_TRIP_X100 / _X100) * _X100
	extract_ticks = _cfg_int(cfg, &"trip_full_load_ticks", _FALLBACK_EXTRACT_TICKS)
	max_slots = _cfg_int(cfg, &"mine_max_workers", _FALLBACK_MAX_SLOTS)
	print("[mine] config_resolved source=balance_data reserves_x100=%d "
		% reserves_x100
		+ "max_slots=%d yield_per_trip_x100=%d extract_ticks=%d"
		% [max_slots, yield_per_trip_x100, extract_ticks])


# Defensive chain to the ResourceNodeConfig sub-resource. Returns null on
# any failure step (caller falls back loudly per §9.L9).
func _resource_node_config_or_null() -> Resource:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var econ: Variant = bd.get(&"economy")
	if econ == null or not (econ is Resource):
		return null
	var cfg: Variant = (econ as Resource).get(&"resource_nodes")
	if cfg == null or not (cfg is Resource):
		return null
	return cfg as Resource


# Typed field read with per-field fallback — same shape as the terminal
# step of building.gd::_resolve_max_hp (typeof check before cast).
func _cfg_int(cfg: Resource, field: StringName, fallback: int) -> int:
	var v: Variant = cfg.get(field)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		print("[mine] balance_field_missing field=%s — using fallback %d"
			% [field, fallback])
		return fallback
	return int(v)


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
