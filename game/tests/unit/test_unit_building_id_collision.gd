# Regression tests — Unit/Building unit_id namespace-collision ROOT fix.
#
# Session-11 hotfix, 2026-06-08 full-review finding ARCH-1 (BLOCKER).
#
# The bug class: Units and Buildings keep SEPARATE static id counters that
# both start at 1 and collide in the same int space. Building HCs used to
# emit on the GLOBAL `EventBus.unit_health_zero` / `unit_died` channels;
# consumers filter by id only, so razing building id N death-preempted
# (StateMachine → &"dying" → queue_free) the healthy UNIT with unit_id N,
# and FarrDrainDispatcher could apply a worker-death Farr drain for a
# building death. Workarounds existed at three consumer sites (BUG-G1 /
# BUG-H8 target_node threading); this is the EMITTER-side root fix:
# HealthComponent.emit_global_death_signals, set false by
# Building._init_health_from_balance_data.
#
# Invariants pinned here:
#   1. A Building-flagged HC reaching 0 emits the LOCAL health_zero signal
#      but NEVER the global unit_health_zero / unit_died channels.
#   2. A Unit HC (default flag) still emits all three — unit-side death
#      preempt + Farr drains + telemetry are unaffected.
#   3. The collision scenario: two HCs sharing id N; the building-side
#      death produces ZERO global emissions for id N (nothing for a
#      same-id unit consumer to misfire on).
#   4. Wiring: a REAL Building scene (Ma'dan canonical) gets the flag set
#      false by _init_health_from_balance_data — the fix is wired, not
#      just available.
#
# Pitfall #17 discipline: free() not queue_free()+await where applicable;
# add_child_autofree handles lifetime.
extends GutTest


const HealthComponentScript: Script = preload(
	"res://scripts/units/components/health_component.gd")
const MadanScene: PackedScene = preload(
	"res://scenes/world/buildings/madan.tscn")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")

const COLLIDING_ID: int = 7

var _unit_hc: Variant
var _building_hc: Variant
var _global_zero_ids: Array[int] = []
var _global_died_ids: Array[int] = []
var _local_zero_ids: Array[int] = []


func before_each() -> void:
	SimClock.reset()
	_global_zero_ids.clear()
	_global_died_ids.clear()
	_local_zero_ids.clear()

	_unit_hc = HealthComponentScript.new()
	add_child_autofree(_unit_hc)
	_unit_hc.unit_id = COLLIDING_ID
	# Unit-side default: emit_global_death_signals stays true.

	_building_hc = HealthComponentScript.new()
	add_child_autofree(_building_hc)
	_building_hc.unit_id = COLLIDING_ID
	# What Building._init_health_from_balance_data now sets:
	_building_hc.emit_global_death_signals = false
	_building_hc.health_zero.connect(_on_local_zero)

	EventBus.unit_health_zero.connect(_on_global_zero)
	EventBus.unit_died.connect(_on_global_died)


func after_each() -> void:
	if EventBus.unit_health_zero.is_connected(_on_global_zero):
		EventBus.unit_health_zero.disconnect(_on_global_zero)
	if EventBus.unit_died.is_connected(_on_global_died):
		EventBus.unit_died.disconnect(_on_global_died)
	SimClock._is_ticking = false
	SimClock.reset()


func _on_global_zero(unit_id: int) -> void:
	_global_zero_ids.append(unit_id)


func _on_global_died(unit_id: int, _killer: int, _cause: StringName,
		_pos: Vector3) -> void:
	_global_died_ids.append(unit_id)


func _on_local_zero(unit_id: int) -> void:
	_local_zero_ids.append(unit_id)


# Same on-tick wrapper discipline as test_health_component.gd — _set_sim
# asserts require SimClock.is_ticking() during the mutation.
func _on_tick(body: Callable) -> void:
	SimClock._is_ticking = true
	body.call()
	SimClock._is_ticking = false


# ---------------------------------------------------------------------------
# Invariant 1 + 3 — building death is globally silent, locally loud
# ---------------------------------------------------------------------------

func test_building_hc_death_never_emits_global_unit_channels() -> void:
	_building_hc.init_max_hp(10.0)
	_on_tick(func() -> void:
		_building_hc.take_damage(10.0, null))
	assert_eq(_global_zero_ids.size(), 0,
		"ARCH-1: building death must NOT emit global unit_health_zero — "
		+ "a same-id Unit consumer (StateMachine death-preempt) would "
		+ "queue_free a healthy unit")
	assert_eq(_global_died_ids.size(), 0,
		"ARCH-1: building death must NOT emit global unit_died — "
		+ "FarrDrainDispatcher would misfire a worker-death drain")
	assert_eq(_local_zero_ids, [COLLIDING_ID] as Array[int],
		"BUG-G1 local channel must still fire exactly once — Building "
		+ "subclass cleanup chains subscribe to the LOCAL signal")


func test_colliding_unit_is_untouched_by_building_death() -> void:
	_unit_hc.init_max_hp(50.0)
	_building_hc.init_max_hp(10.0)
	_on_tick(func() -> void:
		_building_hc.take_damage(10.0, null))
	# The unit HC sharing id 7 must be alive + at full HP — nothing in
	# the building's death path may have reached it.
	assert_true(is_instance_valid(_unit_hc),
		"ARCH-1: same-id unit must survive a building's destruction")
	assert_true(bool(_unit_hc.is_alive()),
		"ARCH-1: same-id unit must remain alive (no death-preempt path)")
	assert_eq(int(_unit_hc.hp_x100), 5000,
		"ARCH-1: same-id unit hp must be untouched")


# ---------------------------------------------------------------------------
# Invariant 2 — unit-side global emits are unaffected
# ---------------------------------------------------------------------------

func test_unit_hc_death_still_emits_global_channels() -> void:
	_unit_hc.init_max_hp(10.0)
	_on_tick(func() -> void:
		_unit_hc.take_damage(10.0, null))
	assert_eq(_global_zero_ids, [COLLIDING_ID] as Array[int],
		"unit death must still emit global unit_health_zero exactly once "
		+ "(StateMachine death-preempt depends on it)")
	assert_eq(_global_died_ids, [COLLIDING_ID] as Array[int],
		"unit death must still emit global unit_died exactly once "
		+ "(telemetry / FarrSystem / Phase-5 Yadgar consumers)")


func test_hc_default_flag_is_unit_semantics() -> void:
	var fresh: Variant = HealthComponentScript.new()
	add_child_autofree(fresh)
	assert_true(bool(fresh.emit_global_death_signals),
		"default HC must keep unit semantics (global emits ON) — only "
		+ "Building._init_health_from_balance_data opts out")


# ---------------------------------------------------------------------------
# Invariant 4 — the fix is WIRED on a real Building scene
# ---------------------------------------------------------------------------

func test_real_building_scene_gets_global_emits_suppressed() -> void:
	BuildingScript.call(&"reset_id_counter")
	var madan: Variant = MadanScene.instantiate()
	madan.set(&"team", Constants.TEAM_IRAN)
	add_child_autofree(madan)
	var hc: Variant = madan.get_node_or_null(^"HealthComponent")
	assert_not_null(hc,
		"madan.tscn must carry a HealthComponent (Wave 3-BD)")
	assert_false(bool(hc.emit_global_death_signals),
		"ARCH-1 wiring: Building._init_health_from_balance_data must set "
		+ "emit_global_death_signals=false on its HC — without this the "
		+ "flag exists but the collision persists")
