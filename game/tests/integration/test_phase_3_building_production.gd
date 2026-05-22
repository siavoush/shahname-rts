# Integration test — Phase 3 session 7 wave 3A.6 Track 1.
#
# Per 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 1 last bullet:
# "Integration test: place Sarbaz-khaneh → request_train(&"piyade") →
# tick dwell forward → assert Piyade exists in scene with correct team."
#
# This exercises the full producer-side surface end-to-end:
#   1. Spawn a Sarbaz-khaneh via its scene template (covers _ready,
#      EventBus.sim_phase subscription, dual-init for kind + produces).
#   2. Mark is_complete = true (skip the construction state — that
#      flow is tested separately and the production-loop scope is
#      what this integration test owns).
#   3. Set up ResourceSystem with enough coin/grain + pop room.
#   4. Call request_train(&"piyade") — verify success.
#   5. Drive EventBus.sim_phase &"movement" emits until the dwell
#      counter expires.
#   6. Assert a Piyade unit exists in the building's parent subtree,
#      with the correct team, after spawn.
#   7. Assert state returns to &"idle" + signal fires.
#
# Mirrors test_phase_3_gather_loop.gd's integration shape — full
# fixture + behavioral assertions across system boundaries.
extends GutTest


const SarbazKhanehScene: PackedScene = preload(
	"res://scenes/world/buildings/sarbaz_khaneh.tscn")
const BuildingScript: Script = preload(
	"res://scripts/world/buildings/building.gd")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _sarbaz_khaneh: Variant
var _world_root: Node


func before_each() -> void:
	SimClock.reset()
	ResourceSystem.reset()
	BuildingScript.call(&"reset_id_counter")
	UnitScript.call(&"reset_id_counter")
	# Create a world-like parent for the building. Trained units are added
	# to the building's parent — using a dedicated test root keeps assertions
	# scoped to this test's children.
	_world_root = Node3D.new()
	_world_root.name = &"WorldRoot"
	add_child_autofree(_world_root)


func after_each() -> void:
	if _sarbaz_khaneh != null and is_instance_valid(_sarbaz_khaneh):
		_sarbaz_khaneh.queue_free()
	_sarbaz_khaneh = null
	_world_root = null
	SimClock.reset()


# ---------------------------------------------------------------------------
# Helper: spawn the building under _world_root + mark it operationally ready.
# ---------------------------------------------------------------------------

func _spawn_sarbaz_khaneh_complete(team: int = Constants.TEAM_IRAN) -> Variant:
	var b: Variant = SarbazKhanehScene.instantiate()
	b.team = team
	# Position somewhere not at world origin so the rally-point offset
	# produces a distinguishable spawn position.
	b.position = Vector3(5.0, 0.5, 10.0)
	_world_root.add_child(b)
	# Skip the construction state — this integration test covers the
	# production half, not the construction half. Both halves exercised
	# back-to-back is a follow-up "end-to-end" test we don't need yet.
	b.is_complete = true
	return b


# ---------------------------------------------------------------------------
# Full producer-side flow: request_train → dwell → spawn → idle.
# ---------------------------------------------------------------------------

func test_sarbaz_khaneh_produces_piyade_end_to_end() -> void:
	# 1. Spawn building.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh_complete(Constants.TEAM_IRAN)

	# 2. Set up ResourceSystem with affordability.
	SimClock._is_ticking = true
	ResourceSystem.change_population_cap(
		Constants.TEAM_IRAN, 10, &"test_setup", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)

	# 3. Request train. Should succeed.
	var ok: bool = _sarbaz_khaneh.request_train(&"piyade")
	assert_true(ok,
		"request_train(piyade) must succeed on a complete Sarbaz-khaneh "
		+ "with resources + pop cap room")
	assert_eq(_sarbaz_khaneh._production_state, &"training")
	assert_eq(_sarbaz_khaneh._production_unit, &"piyade")
	var dwell_at_start: int = _sarbaz_khaneh._production_progress_ticks
	assert_gt(dwell_at_start, 0,
		"dwell ticks initialized > 0 after request_train")

	# 4. Drive movement-phase emits until dwell expires. Add a generous
	# margin so this test isn't brittle to dwell-tick tuning changes.
	# The fallback dwell is 90 ticks; BalanceData may ship a higher number
	# (kickoff §1 table: 90 = 3s for Piyade). 500 emits = >16s of sim
	# time — covers either fallback or a slow tuned value.
	var spawn_happened_at: int = -1
	for i in range(500):
		EventBus.sim_phase.emit(&"movement", i)
		if _sarbaz_khaneh._production_state == &"idle":
			spawn_happened_at = i
			break
	SimClock._is_ticking = false

	# 5. State returned to idle.
	assert_ne(spawn_happened_at, -1,
		"production must complete within 500 movement-phase emits "
		+ "(fallback 90 + max tuned + margin). Got: state=%s, dwell=%d"
		% [_sarbaz_khaneh._production_state, _sarbaz_khaneh._production_progress_ticks])
	assert_eq(_sarbaz_khaneh._production_state, &"idle",
		"state must return to idle after spawn")
	assert_eq(_sarbaz_khaneh._production_unit, &"",
		"_production_unit must clear when transitioning to idle")

	# 6. A Piyade exists in the world root with the correct team.
	var piyade: Node = null
	for child in _world_root.get_children():
		if child == _sarbaz_khaneh:
			continue
		var unit_type_v: Variant = child.get(&"unit_type")
		if unit_type_v == &"piyade":
			piyade = child
			break
	assert_not_null(piyade,
		"a Piyade unit must be spawned in the world root after dwell completes")
	# Team is mirrored from the building.
	assert_eq(int(piyade.get(&"team")), Constants.TEAM_IRAN,
		"spawned Piyade must inherit the building's team (Iran)")
	# 7. Rally-point: Piyade must be south of the building (Iran flow).
	var bldg_pos: Vector3 = _sarbaz_khaneh.global_position
	var unit_pos: Vector3 = piyade.global_position
	assert_gt(unit_pos.z, bldg_pos.z,
		"Iran-spawned Piyade must be south (+Z) of its building at the rally point")


func test_request_train_denied_when_pop_cap_full_does_not_spawn() -> void:
	# Negative path: with pop_cap full, request_train returns false and
	# no unit ever spawns even if we drive sim_phase emits.
	_sarbaz_khaneh = _spawn_sarbaz_khaneh_complete(Constants.TEAM_IRAN)
	SimClock._is_ticking = true
	# pop_cap stays at 0 (BalanceData starting). population stays at 0.
	# population_for >= population_cap_for (both 0) — the >= branch in
	# request_train denies even at zero/zero.
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, 100000, &"t", null)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_GRAIN, 100000, &"t", null)
	var ok: bool = _sarbaz_khaneh.request_train(&"piyade")
	assert_false(ok,
		"request_train must deny when population >= population_cap (0/0 case)")
	# Even with 100 movement phases, no production happens.
	for i in range(100):
		EventBus.sim_phase.emit(&"movement", i)
	SimClock._is_ticking = false
	# No Piyade should exist.
	for child in _world_root.get_children():
		if child == _sarbaz_khaneh:
			continue
		var unit_type_v: Variant = child.get(&"unit_type")
		assert_ne(unit_type_v, &"piyade",
			"no Piyade must spawn when request_train was denied")
