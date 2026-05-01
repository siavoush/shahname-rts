# Tests for SpatialIndex autoload + SpatialAgentComponent.
#
# Contract: docs/SIMULATION_CONTRACT.md §3 — uniform 8m-grid, three queries,
# auto-register/deregister via SpatialAgentComponent, rebuild on the
# spatial_rebuild phase.
extends GutTest


# Preload the component script directly. We reference SpatialAgentComponent
# by class_name in production code paths, but tests are loaded by GUT's
# collector before the global class_name registry is fully populated; a
# preload binds the script reference at parse time, sidestepping the race.
const SpatialAgentComponentScript: Script = preload("res://scripts/core/spatial_agent_component.gd")


# Helper: build a Node3D with a SpatialAgentComponent child. Returns the
# component so the test can assert against it directly.
func _spawn_agent(pos: Vector3, team: int = Constants.TEAM_NEUTRAL) -> Node:
	var parent := Node3D.new()
	parent.global_position = pos
	add_child_autofree(parent)
	var agent: Node = SpatialAgentComponentScript.new()
	agent.team = team
	parent.add_child(agent)
	# parent.add_child fires _ready on the agent which auto-registers.
	return agent


func before_each() -> void:
	# Pristine state. SpatialIndex.reset clears agents+cells; SimClock reset
	# keeps tick counts isolated.
	SpatialIndex.reset()
	SimClock.reset()


func after_each() -> void:
	SpatialIndex.reset()
	SimClock.reset()


# -- Registration ------------------------------------------------------------

func test_agent_auto_registers_on_ready() -> void:
	var a := _spawn_agent(Vector3.ZERO)
	assert_eq(SpatialIndex.agent_count(), 1, "SpatialAgentComponent must register on _ready")
	# _spawn_agent prevents the unused-var warning.
	assert_not_null(a)


func test_agent_auto_deregisters_on_tree_exit() -> void:
	var parent := Node3D.new()
	parent.global_position = Vector3.ZERO
	add_child(parent)   # not auto-freed; we control its lifetime.
	var agent: Node = SpatialAgentComponentScript.new()
	parent.add_child(agent)
	assert_eq(SpatialIndex.agent_count(), 1)
	# Free the parent — _exit_tree must fire on the component, deregistering.
	parent.queue_free()
	# queue_free defers to end-of-frame; in tests we await the tree to drain.
	await get_tree().process_frame
	assert_eq(SpatialIndex.agent_count(), 0,
		"Component must deregister when its parent leaves the tree")


# -- query_radius ------------------------------------------------------------

func test_query_radius_returns_agents_within_distance() -> void:
	var a := _spawn_agent(Vector3(0, 0, 0))
	var b := _spawn_agent(Vector3(5, 0, 0))    # within 10m of origin
	var c := _spawn_agent(Vector3(20, 0, 0))   # outside 10m
	var hits := SpatialIndex.query_radius(Vector3.ZERO, 10.0)
	assert_eq(hits.size(), 2, "Two agents within 10m of origin")
	assert_true(a in hits)
	assert_true(b in hits)
	assert_false(c in hits)


func test_query_radius_ignores_y_axis() -> void:
	# An agent 100m above the query point on Y should still match (Y is
	# ignored per Sim Contract §3.1).
	var high := _spawn_agent(Vector3(2, 100, 2))
	var hits := SpatialIndex.query_radius(Vector3.ZERO, 5.0)
	assert_true(high in hits, "Y axis must be ignored — agent on XZ within radius")


func test_query_radius_empty_when_no_agents_in_range() -> void:
	_spawn_agent(Vector3(50, 0, 50))
	var hits := SpatialIndex.query_radius(Vector3.ZERO, 5.0)
	assert_eq(hits.size(), 0)


func test_query_radius_includes_agents_in_neighbor_cells() -> void:
	# Agent at (7, 0, 7) sits in cell (0,0); query from (9, 0, 9) which sits
	# in cell (1,1). The 4m radius spans both cells — the query must scan
	# multiple cells, not just the source cell.
	var a := _spawn_agent(Vector3(7, 0, 7))
	var hits := SpatialIndex.query_radius(Vector3(9, 0, 9), 4.0)
	assert_true(a in hits, "Query must include neighbor cells, not just source cell")


# -- query_radius_team -------------------------------------------------------

func test_query_radius_team_filters_by_team() -> void:
	var iran := _spawn_agent(Vector3(1, 0, 0), Constants.TEAM_IRAN)
	var turan := _spawn_agent(Vector3(2, 0, 0), Constants.TEAM_TURAN)
	var iran_hits := SpatialIndex.query_radius_team(Vector3.ZERO, 10.0, Constants.TEAM_IRAN)
	assert_eq(iran_hits.size(), 1)
	assert_true(iran in iran_hits)
	assert_false(turan in iran_hits)


func test_query_radius_team_with_team_any_returns_all() -> void:
	_spawn_agent(Vector3(1, 0, 0), Constants.TEAM_IRAN)
	_spawn_agent(Vector3(2, 0, 0), Constants.TEAM_TURAN)
	var hits := SpatialIndex.query_radius_team(Vector3.ZERO, 10.0, Constants.TEAM_ANY)
	assert_eq(hits.size(), 2, "TEAM_ANY (-1) sentinel returns all teams")


# -- query_nearest_n ---------------------------------------------------------

func test_query_nearest_n_returns_sorted_by_distance() -> void:
	var far := _spawn_agent(Vector3(20, 0, 0))
	var mid := _spawn_agent(Vector3(10, 0, 0))
	var near := _spawn_agent(Vector3(2, 0, 0))
	var hits := SpatialIndex.query_nearest_n(Vector3.ZERO, 3, Constants.TEAM_ANY)
	assert_eq(hits.size(), 3)
	assert_eq(hits[0], near, "Nearest first")
	assert_eq(hits[1], mid)
	assert_eq(hits[2], far)


func test_query_nearest_n_caps_at_n() -> void:
	for i in range(5):
		_spawn_agent(Vector3(float(i + 1), 0, 0))
	var hits := SpatialIndex.query_nearest_n(Vector3.ZERO, 2, Constants.TEAM_ANY)
	assert_eq(hits.size(), 2, "Result must be trimmed to n entries")


func test_query_nearest_n_filters_by_team() -> void:
	var iran_close := _spawn_agent(Vector3(1, 0, 0), Constants.TEAM_IRAN)
	var turan_closer := _spawn_agent(Vector3(0.5, 0, 0), Constants.TEAM_TURAN)
	var hits := SpatialIndex.query_nearest_n(Vector3.ZERO, 3, Constants.TEAM_IRAN)
	# Only the Iran agent qualifies.
	assert_eq(hits.size(), 1)
	assert_eq(hits[0], iran_close)
	assert_false(turan_closer in hits)


func test_query_nearest_n_handles_zero_n() -> void:
	_spawn_agent(Vector3.ZERO)
	var hits := SpatialIndex.query_nearest_n(Vector3.ZERO, 0, Constants.TEAM_ANY)
	assert_eq(hits.size(), 0, "n=0 must return an empty array, not crash")


# -- _rebuild on sim_phase ---------------------------------------------------

func test_rebuild_runs_on_spatial_rebuild_phase() -> void:
	# Move an agent's parent after registration; the index has the *old* cell
	# until a rebuild happens. Driving a tick must cause the rebuild and bring
	# the index up to date with the new position.
	var agent := _spawn_agent(Vector3.ZERO)
	# Sanity: agent at origin is found by an origin query.
	assert_true(agent in SpatialIndex.query_radius(Vector3.ZERO, 1.0))
	# Move to (50, 0, 50). No rebuild yet — origin query may still hit if the
	# old cell entry lingered (we keep insertions on register), but the new
	# location query should certainly miss before rebuild...
	(agent.get_parent() as Node3D).global_position = Vector3(50, 0, 50)
	# Drive one tick — sim_phase emits spatial_rebuild → SpatialIndex._rebuild.
	SimClock._test_run_tick()
	# After rebuild, agent is at (50, 0, 50), and a query there finds it.
	var hits := SpatialIndex.query_radius(Vector3(50, 0, 50), 1.0)
	assert_true(agent in hits, "Rebuild must reflect new agent position")
	# Old origin cell must no longer hold the agent.
	var old_hits := SpatialIndex.query_radius(Vector3.ZERO, 1.0)
	assert_false(agent in old_hits, "Rebuild must clear the old cell entry")


func test_rebuild_drops_invalid_agents() -> void:
	# Register two; free one via the parent. After rebuild the count drops.
	var parent_a := Node3D.new()
	add_child(parent_a)
	var agent_a: Node = SpatialAgentComponentScript.new()
	parent_a.add_child(agent_a)

	var parent_b := Node3D.new()
	add_child_autofree(parent_b)
	var agent_b: Node = SpatialAgentComponentScript.new()
	parent_b.add_child(agent_b)

	assert_eq(SpatialIndex.agent_count(), 2)
	parent_a.queue_free()
	await get_tree().process_frame
	# tree_exiting on agent_a fires unregister, dropping the count to 1.
	assert_eq(SpatialIndex.agent_count(), 1)
	# Agent_b survives.
	var hits := SpatialIndex.query_radius(Vector3.ZERO, 100.0)
	assert_true(agent_b in hits)
