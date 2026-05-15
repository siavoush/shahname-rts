# Integration test — Wave 1B Commit 3: Ma'dan-buffs-MineNode-extraction full chain.
#
# Verifies the end-to-end Option B behavior (Open Space Room A 2026-05-14):
# placing a Ma'dan adjacent to a MineNode boosts the Kargar's complete_extract
# payload via the ResourceNode modifier-registry API shipped at 3d7b722.
#
# Coverage:
#   1. Ma'dan placement registers it as an extraction_modifier on the
#      nearest MineNode within radius (4m default).
#   2. complete_extract on the buffed mine returns the multiplied payload
#      (base * 1.5 = 1.5x default per balance-engineer's d798e78).
#   3. Reserves on the buffed mine decrement by the EFFECTIVE amount (faster
#      depletion — semantically correct: the buff amplifies both haul AND wear).
#   4. A Ma'dan placed OUT of radius leaves the mine's yield untouched (no
#      false-positive buff).
#
# Pitfall #11: never use is_instance_valid as a death-detection predicate
# in SimClock._test_run_tick loops. Not relevant here (no death paths
# exercised); noted per permanent per-file contract.
extends GutTest


const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")


var _mine: Variant = null
var _madan: Variant = null


func before_each() -> void:
	SimClock.reset()
	ResourceSystem.reset()
	_mine = null
	_madan = null


func after_each() -> void:
	if _mine != null and is_instance_valid(_mine):
		_mine.queue_free()
	if _madan != null and is_instance_valid(_madan):
		_madan.queue_free()
	_mine = null
	_madan = null
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_mine_at(pos: Vector3) -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	return m


func _spawn_madan_at(pos: Vector3) -> Variant:
	var b: Variant = MadanScene.instantiate()
	add_child_autofree(b)
	b.team = Constants.TEAM_IRAN
	# place_at finalizes the placement (sets is_complete + fires
	# _on_placement_complete, which triggers register_extraction_modifier
	# on the nearest mine).
	b.place_at(pos, Constants.TEAM_IRAN, 1)
	return b


# ---------------------------------------------------------------------------
# Modifier-registration chain — Ma'dan placement registers on adjacent mine
# ---------------------------------------------------------------------------

func test_madan_placement_registers_extraction_modifier_on_adjacent_mine() -> void:
	# Mine at origin; Ma'dan at (3, 0, 0) is within the 4m default radius.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	# Per Commit 2 register_extraction_modifier, the modifier list on
	# the mine should contain exactly one modifier after Ma'dan placement.
	assert_eq(_mine.registered_modifier_count(), 1,
		"Mine within Ma'dan radius must have 1 registered modifier "
		+ "after Ma'dan placement")


func test_madan_placement_out_of_radius_does_not_register() -> void:
	# Mine at origin; Ma'dan at (10, 0, 0) is OUTSIDE the 4m default radius.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(10.0, 0.0, 0.0))
	assert_eq(_mine.registered_modifier_count(), 0,
		"Mine out of Ma'dan radius must have 0 registered modifiers")


# ---------------------------------------------------------------------------
# Effective yield — buffed mine's complete_extract returns multiplied payload
# ---------------------------------------------------------------------------

func test_buffed_mine_complete_extract_returns_multiplied_payload() -> void:
	# Set up the buff scenario: Ma'dan adjacent to mine. Then exercise
	# complete_extract on the mine via a synthetic worker unit_id.
	#
	# We bypass the full Kargar / UnitState_Gathering chain — that's
	# covered by test_phase_3_gather_loop / test_phase_3_multi_cycle_gather.
	# This integration test specifically verifies the modifier-multiplier
	# math at the seam where Commit 1's Ma'dan-side calls hit Commit 2's
	# MineNode-side API.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	# MineNode wave-1A constants: yield_per_trip_x100 = 1000 (10 Coin).
	# Ma'dan multiplier: 150/100 = 1.5x.
	# Expected effective: 1000 * 150 / 100 = 1500 (15 Coin).
	var base_yield: int = _mine.yield_per_trip_x100
	assert_eq(base_yield, 1000,
		"Pre-condition: MineNode wave-1A default yield_per_trip_x100 = 1000")
	# Drive a synthetic gather cycle: request → complete.
	# Note: request/complete must run on-tick per SimClock contract.
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	# Buffed payload reflects 1.5x multiplier.
	assert_eq(payload[&"amount_x100"], 1500,
		"Buffed mine's complete_extract returns 1500 (base 1000 * 1.5)")
	assert_eq(payload[&"kind"], &"coin",
		"Buffed mine's payload retains kind = &\"coin\"")


func test_unbuffed_mine_complete_extract_returns_base_payload() -> void:
	# Counterfactual: no Ma'dan, mine yields base payload (1000 x100).
	_mine = _spawn_mine_at(Vector3.ZERO)
	# Sanity: no modifiers registered.
	assert_eq(_mine.registered_modifier_count(), 0)
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], 1000,
		"Unbuffed mine returns base 1000 (no multiplier applied)")


# ---------------------------------------------------------------------------
# Reserves accounting — buffed mine depletes faster per trip
# ---------------------------------------------------------------------------

func test_buffed_mine_reserves_decrement_by_effective_amount() -> void:
	# A buffed mine should consume the EFFECTIVE amount from reserves,
	# not the base amount. This is the "amplifies haul AND wear"
	# semantics from Commit 2's design note.
	_mine = _spawn_mine_at(Vector3.ZERO)
	_madan = _spawn_madan_at(Vector3(3.0, 0.0, 0.0))
	var initial_reserves: int = _mine.reserves_x100
	_mine.request_extract(99)
	SimClock._is_ticking = true
	var payload: Dictionary = _mine.complete_extract(99)
	SimClock._is_ticking = false
	# Effective payload = 1500. Reserves should decrement by 1500.
	assert_eq(payload[&"amount_x100"], 1500)
	assert_eq(_mine.reserves_x100, initial_reserves - 1500,
		"Buffed mine reserves decrement by EFFECTIVE amount (1500), not base 1000")
