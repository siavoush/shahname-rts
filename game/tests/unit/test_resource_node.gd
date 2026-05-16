# Tests for the ResourceNode abstract base class.
#
# Contract: docs/RESOURCE_NODE_CONTRACT.md §1, §3, §4. Phase 3 wave 1A —
# kickoff doc 02f_PHASE_3_KICKOFF.md §3.
#
# The base class is intentionally thin: it pins the field shape (`kind`,
# `reserves_x100`, `extract_ticks`, `max_slots`, `is_gatherable`), the
# three-call API (`request_extract` / `complete_extract` / `release_extract`),
# and the slot-occupancy bookkeeping that subclasses inherit. Concrete
# behavior (visuals, depletion `queue_free`, reserves source) lives in the
# subclass (MineNode for wave 1A).
#
# Wave 1A API naming: the kickoff specifies `request_extract` /
# `complete_extract` / `release_extract` (as opposed to RESOURCE_NODE_CONTRACT
# §4's `begin_extract` / `tick_extract` / `release_extract`). The kickoff
# wins for wave 1A — it captures the design-chat-resolved naming the
# gathering state expects. The contract may be patched at wave-close if the
# naming proves load-bearing.
extends GutTest


const ResourceNodeScript: Script = preload("res://scripts/world/resource_nodes/resource_node.gd")


# A test-only concrete subclass that does the minimum to exercise the base
# class's bookkeeping — no scene, no mesh, just a Node3D-shaped SimNode that
# inherits the API. We need a Node3D parent because the production
# ResourceNode is a Node3D (workers walk to its global_position).
class _FakeResourceNode extends "res://scripts/world/resource_nodes/resource_node.gd":
	pass


var _node: Variant


func before_each() -> void:
	SimClock.reset()
	_node = _FakeResourceNode.new()
	# Set up the typical configuration a subclass would write at _ready.
	_node.kind = &"test_resource"
	_node.reserves_x100 = 1000  # 10 units carried at x100 fixed-point
	_node.extract_ticks = 5
	_node.max_slots = 1
	_node.is_gatherable = true


func after_each() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	SimClock.reset()


# ---------------------------------------------------------------------------
# Field shape — the schema the contract pins.
# ---------------------------------------------------------------------------

func test_resource_node_extends_node3d() -> void:
	# Workers walk to global_position to gather; the node must be a Node3D.
	assert_true(_node is Node3D,
		"ResourceNode must extend Node3D so workers can read global_position")


func test_resource_node_defaults() -> void:
	var fresh: Variant = _FakeResourceNode.new()
	assert_eq(fresh.kind, &"",
		"default kind is empty StringName until subclass sets it")
	assert_eq(fresh.reserves_x100, 0,
		"default reserves are 0 until subclass configures from BalanceData")
	assert_eq(fresh.extract_ticks, 1,
		"default extract_ticks is 1 (one-tick extract) — minimum viable")
	assert_eq(fresh.max_slots, 1,
		"default max_slots is 1 — Phase 3 simplification")
	assert_true(fresh.is_gatherable,
		"default is_gatherable is true so a freshly-constructed node is usable")
	fresh.queue_free()


# ---------------------------------------------------------------------------
# Slot bookkeeping — request_extract / release_extract roundtrip.
# ---------------------------------------------------------------------------

func test_request_extract_grants_slot_when_available() -> void:
	var ok: bool = _node.request_extract(7)
	assert_true(ok, "first worker requesting a slot succeeds")
	assert_eq(_node.occupied_slots(), 1,
		"occupied_slots reflects the granted slot")


func test_request_extract_rejects_when_all_slots_taken() -> void:
	_node.max_slots = 1
	var ok1: bool = _node.request_extract(1)
	var ok2: bool = _node.request_extract(2)
	assert_true(ok1, "first worker gets the only slot")
	assert_false(ok2, "second worker is rejected — max_slots is 1")


func test_request_extract_rejects_when_not_gatherable() -> void:
	_node.is_gatherable = false
	var ok: bool = _node.request_extract(1)
	assert_false(ok,
		"a non-gatherable node refuses extract requests (depleted, under construction)")


func test_release_extract_frees_a_slot() -> void:
	_node.max_slots = 1
	_node.request_extract(1)
	assert_eq(_node.occupied_slots(), 1)
	_node.release_extract(1)
	assert_eq(_node.occupied_slots(), 0,
		"release frees the slot for re-use")
	# Another worker can now claim the slot.
	assert_true(_node.request_extract(2),
		"slot is reusable after release")


func test_release_extract_is_idempotent() -> void:
	# Contract §4.1: "release_extract is always called even on death."
	# Death-path may attempt to release a slot that was never granted
	# (extract bailed at request time, or the worker died before reaching
	# the node). Defensive idempotency keeps the death cleanup simple.
	_node.release_extract(99)  # never claimed
	assert_eq(_node.occupied_slots(), 0,
		"releasing an unowned worker is a no-op (not an error)")


func test_same_worker_cannot_double_request() -> void:
	# A worker holding a slot can't claim a second one on the same node.
	# Defensive — prevents a buggy state from leaking two slots for the
	# same unit_id.
	_node.max_slots = 2
	assert_true(_node.request_extract(1), "first request succeeds")
	assert_false(_node.request_extract(1),
		"same worker re-requesting is rejected (already holds a slot)")
	assert_eq(_node.occupied_slots(), 1,
		"double-request does not bump occupancy")


# ---------------------------------------------------------------------------
# complete_extract — the carry payload.
# ---------------------------------------------------------------------------

func test_complete_extract_returns_carry_payload_and_decrements_reserves() -> void:
	# Per Resource Node Contract §4: complete_extract returns the carry
	# payload (kind + amount_x100). The reserves drop by the payload.
	_node.reserves_x100 = 1000
	_node.request_extract(1)
	# Drive complete inside a sim tick so _set_sim assertions pass on any
	# child mutations (subclasses may add bookkeeping).
	SimClock._is_ticking = true
	var payload: Dictionary = _node.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"kind", &""), &"test_resource",
		"payload carries the node's kind")
	assert_true(payload.get(&"amount_x100", 0) > 0,
		"payload carries a positive amount")
	assert_true(_node.reserves_x100 < 1000,
		"reserves decremented by complete_extract")


func test_complete_extract_releases_the_slot() -> void:
	# Completing a trip implicitly frees the slot — the worker is leaving
	# the node, so the next worker can step in. (release_extract is still
	# called by the state's exit() for the abnormal path; complete + release
	# is double-release-safe per the idempotency test.)
	_node.request_extract(1)
	assert_eq(_node.occupied_slots(), 1)
	SimClock._is_ticking = true
	_node.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(_node.occupied_slots(), 0,
		"complete_extract frees the slot the worker held")


func test_complete_extract_for_unowned_worker_returns_empty_payload() -> void:
	# Defensive: a worker that never requested can't complete. Returns an
	# empty payload (kind=&"", amount_x100=0) so callers can branch on it
	# without crashing.
	SimClock._is_ticking = true
	var payload: Dictionary = _node.complete_extract(99)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"kind", &""), &"",
		"unknown worker complete returns empty kind")
	assert_eq(payload.get(&"amount_x100", 0), 0,
		"unknown worker complete returns zero amount")


# ---------------------------------------------------------------------------
# Depletion — when reserves hit zero, is_gatherable flips false.
# ---------------------------------------------------------------------------

func test_complete_extract_flips_is_gatherable_when_reserves_zero() -> void:
	# Subclass-driven concrete depletion (queue_free etc.) lives in
	# MineNode; the base class is responsible only for the flag flip,
	# which is the consumer-visible signal that a new request_extract
	# will be rejected.
	_node.reserves_x100 = 100  # one trip's worth (default extract uses a chunk)
	_node.request_extract(1)
	SimClock._is_ticking = true
	_node.complete_extract(1)
	SimClock._is_ticking = false
	# After exhausting reserves, is_gatherable is false.
	assert_eq(_node.reserves_x100, 0,
		"reserves zeroed after the final extract")
	assert_false(_node.is_gatherable,
		"is_gatherable flips false once reserves are exhausted")


# ---------------------------------------------------------------------------
# Extraction-modifier registry — wave 1B (Ma'dan buff-emitter integration).
# ---------------------------------------------------------------------------
#
# Tests for register_extraction_modifier / unregister_extraction_modifier /
# effective_yield_per_trip_x100. Per Open Space Room A Option B
# (2026-05-14): Ma'dan registers as an extraction modifier on the adjacent
# MineNode; MineNode.complete_extract reads effective_yield_per_trip_x100
# which composes the base yield with registered modifiers' multipliers.
#
# Stacking rule (design Q3, lead's 2026-05-15 confirmation): default
# false (first-registered-wins). When the first modifier's
# BalanceData modifier_stacks=false AND another modifier tries to register,
# the second register returns false silently.
#
# Test-only modifier fake: provides yield_multiplier_x100() method only,
# plus a `kind` field for the BalanceData stacking lookup. Inner class
# to avoid coupling to Madan's full surface (cultural-note block, scene,
# etc.). The base class doesn't care about modifier-emitter identity —
# only the duck-typed methods.
class _FakeModifier extends Node:
	var kind: StringName = &""
	var _multiplier_x100: int = 100

	func yield_multiplier_x100() -> int:
		return _multiplier_x100


func test_register_extraction_modifier_returns_true_on_first_register() -> void:
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	add_child_autofree(m)
	var ok: bool = _node.register_extraction_modifier(m)
	assert_true(ok,
		"First register_extraction_modifier call must succeed (return true)")
	assert_eq(_node.registered_modifier_count(), 1,
		"Modifier count is 1 after one successful register")


func test_register_extraction_modifier_rejects_null() -> void:
	var ok: bool = _node.register_extraction_modifier(null)
	assert_false(ok,
		"register_extraction_modifier(null) must return false (rejection)")
	assert_eq(_node.registered_modifier_count(), 0,
		"Modifier count remains 0 on null-rejection")


func test_register_extraction_modifier_rejects_same_modifier_twice() -> void:
	# Same-modifier double-register is silent false. Defensive against
	# test-fixture bugs or wave-1C respawn patterns.
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	add_child_autofree(m)
	_node.register_extraction_modifier(m)
	var ok: bool = _node.register_extraction_modifier(m)
	assert_false(ok,
		"Re-registering the SAME modifier must return false (rejection)")
	assert_eq(_node.registered_modifier_count(), 1,
		"Modifier count stays at 1 — no duplicate")


func test_unregister_extraction_modifier_removes_a_registered_modifier() -> void:
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	add_child_autofree(m)
	_node.register_extraction_modifier(m)
	assert_eq(_node.registered_modifier_count(), 1)
	_node.unregister_extraction_modifier(m)
	assert_eq(_node.registered_modifier_count(), 0,
		"unregister_extraction_modifier removes the registered modifier")


func test_unregister_extraction_modifier_idempotent_on_unknown() -> void:
	# Mirrors release_extract idempotency. A modifier's destruction
	# path may call unregister even if it was never registered.
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	add_child_autofree(m)
	_node.unregister_extraction_modifier(m)  # never registered
	assert_eq(_node.registered_modifier_count(), 0,
		"unregister of an unregistered modifier is a no-op (no crash)")


func test_effective_yield_per_trip_x100_no_modifiers_returns_base() -> void:
	_node.yield_per_trip_x100 = 1000  # 10 Coin per trip at x100 scale
	assert_eq(_node.effective_yield_per_trip_x100(), 1000,
		"effective_yield_per_trip_x100 returns base unchanged when no "
		+ "modifiers registered")


func test_effective_yield_per_trip_x100_one_modifier_multiplies() -> void:
	# Ma'dan's MVP yield_multiplier_x100 = 150 (1.5x). 1000 * 150 / 100 = 1500.
	_node.yield_per_trip_x100 = 1000
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	m._multiplier_x100 = 150
	add_child_autofree(m)
	_node.register_extraction_modifier(m)
	assert_eq(_node.effective_yield_per_trip_x100(), 1500,
		"effective_yield_per_trip_x100 with one 1.5x modifier returns "
		+ "base * 1.5 (1000 * 150 / 100 = 1500)")


func test_effective_yield_per_trip_x100_after_unregister_returns_to_base() -> void:
	_node.yield_per_trip_x100 = 1000
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	m._multiplier_x100 = 150
	add_child_autofree(m)
	_node.register_extraction_modifier(m)
	_node.unregister_extraction_modifier(m)
	assert_eq(_node.effective_yield_per_trip_x100(), 1000,
		"After unregister, effective_yield_per_trip_x100 returns to base")


func test_complete_extract_uses_effective_yield_when_modifier_registered() -> void:
	# Integration with complete_extract: the payload amount_x100 reflects
	# the modifier multiplier. Mine yields 100 Coin baseline; with a 1.5x
	# modifier the payload is 150 (in x100 fixed-point: 100x100=10000 base,
	# 10000*150/100=15000 effective; but we test with smaller numbers
	# matching the fixture's _node.reserves_x100 = 1000 from before_each).
	_node.reserves_x100 = 2000  # enough for one boosted trip
	_node.yield_per_trip_x100 = 1000  # 10 Coin at x100 scale
	var m: _FakeModifier = _FakeModifier.new()
	m.kind = &"test_modifier"
	m._multiplier_x100 = 150
	add_child_autofree(m)
	_node.register_extraction_modifier(m)
	_node.request_extract(1)
	SimClock._is_ticking = true
	var payload: Dictionary = _node.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(payload[&"amount_x100"], 1500,
		"complete_extract payload amount_x100 reflects the modifier "
		+ "multiplier (1000 base * 1.5 = 1500)")
	# Reserves decrement by the EFFECTIVE amount, not the base — this is
	# the correct behavior: a buffed mine depletes faster per trip.
	assert_eq(_node.reserves_x100, 500,
		"Reserves decrement by the effective amount (2000 - 1500 = 500)")
