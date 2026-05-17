# Tests for MineNode — the Coin-yielding ResourceNode subclass.
#
# Per docs/RESOURCE_NODE_CONTRACT.md §1.3 + Phase 3 wave 1A kickoff §3.
extends GutTest


const MineNodeScene: PackedScene = preload(
	"res://scenes/world/resource_nodes/mine_node.tscn")
const MineNodeScript: Script = preload(
	"res://scripts/world/resource_nodes/mine_node.gd")


var _node: Variant


func before_each() -> void:
	SimClock.reset()


func after_each() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	SimClock.reset()


# Spawn via the scene template — exercises the path the live game uses
# (mesh + script wiring resolve at scene load, not at .new()).
func _spawn_mine() -> Variant:
	var m: Variant = MineNodeScene.instantiate()
	add_child_autofree(m)
	return m


# ---------------------------------------------------------------------------
# Scene smoke + schema
# ---------------------------------------------------------------------------

func test_scene_instantiates_with_script_attached() -> void:
	_node = _spawn_mine()
	assert_true(_node is Node3D, "MineNode is a Node3D")
	assert_true(_node.get_script() == MineNodeScript
			or _node.get_script() == load(MineNodeScript.resource_path),
		"MineNode scene has the mine_node.gd script attached")


func test_mine_node_kind_is_coin() -> void:
	# 01_CORE_MECHANICS.md §3 — Iran economy has two resources, Coin (sekkeh)
	# and Grain (ghallat). MineNode yields Coin per RESOURCE_NODE_CONTRACT §1.3.
	_node = _spawn_mine()
	assert_eq(_node.kind, Constants.KIND_COIN,
		"MineNode.kind is &\"coin\" (Constants.KIND_COIN)")


func test_initial_reserves_positive() -> void:
	# Wave 1A hardcodes a reserves value (BalanceData wire-up is wave 1B's
	# domain). The exact number is documented in the source; we assert
	# positivity so a freshly-spawned mine is gatherable.
	_node = _spawn_mine()
	assert_true(_node.reserves_x100 > 0,
		"MineNode spawns with positive reserves (hardcoded for wave 1A)")
	assert_true(_node.is_gatherable,
		"MineNode is gatherable from spawn")


func test_max_slots_is_one_phase_3_simplification() -> void:
	# Per kickoff §3 wave-1A — Phase 3 simplification: 1 slot per mine.
	# Contract §1.3 allows 2 long-term; revisit if playtest needs it.
	_node = _spawn_mine()
	assert_eq(_node.max_slots, 1,
		"MineNode.max_slots is 1 (Phase 3 simplification)")


# ---------------------------------------------------------------------------
# Slot API — inherited from ResourceNode base, smoke-test on the concrete.
# ---------------------------------------------------------------------------

func test_request_extract_grants_slot() -> void:
	_node = _spawn_mine()
	assert_true(_node.request_extract(1),
		"first request_extract on a fresh mine succeeds")
	assert_eq(_node.occupied_slots(), 1)


func test_complete_extract_returns_coin_payload() -> void:
	_node = _spawn_mine()
	_node.request_extract(1)
	SimClock._is_ticking = true
	var payload: Dictionary = _node.complete_extract(1)
	SimClock._is_ticking = false
	assert_eq(payload.get(&"kind", &""), Constants.KIND_COIN,
		"payload kind is &\"coin\"")
	assert_true(payload.get(&"amount_x100", 0) > 0,
		"payload carries a positive amount")


func test_complete_extract_decrements_reserves() -> void:
	_node = _spawn_mine()
	var before: int = _node.reserves_x100
	_node.request_extract(1)
	SimClock._is_ticking = true
	_node.complete_extract(1)
	SimClock._is_ticking = false
	assert_true(_node.reserves_x100 < before,
		"reserves decremented after one extract trip")


func test_release_extract_frees_slot() -> void:
	# Contract §4.1: release always called from state exit() — even on death.
	_node = _spawn_mine()
	_node.request_extract(1)
	assert_eq(_node.occupied_slots(), 1)
	_node.release_extract(1)
	assert_eq(_node.occupied_slots(), 0,
		"release_extract frees the slot")


# ---------------------------------------------------------------------------
# Depletion — queue_free.call_deferred() per Pitfall #8 / #11.
# ---------------------------------------------------------------------------

func test_mine_depletes_when_reserves_exhausted() -> void:
	# Drive enough extracts to exhaust reserves; assert is_gatherable flips
	# false and the node queues itself for free (verifiable after multiple
	# process_frame awaits per Pitfall #8).
	_node = _spawn_mine()
	var trips: int = 0
	var max_trips: int = 500  # safety cap to prevent infinite loop on bug
	while _node.is_gatherable and trips < max_trips:
		_node.request_extract(1)
		SimClock._is_ticking = true
		_node.complete_extract(1)
		SimClock._is_ticking = false
		trips += 1
	assert_false(_node.is_gatherable,
		"is_gatherable flips false at depletion")
	assert_eq(_node.reserves_x100, 0,
		"reserves zeroed at depletion")
	assert_true(trips < max_trips,
		"depletion happened within reasonable trip count (got %d)" % trips)


func test_depleted_mine_rejects_further_requests() -> void:
	# After depletion the slot API rejects new requests — consumer sees
	# false and bails to Idle (per UnitState_Gathering's request-failed path).
	_node = _spawn_mine()
	# Force-exhaust reserves cleanly:
	_node.reserves_x100 = 0
	_node.is_gatherable = false
	assert_false(_node.request_extract(1),
		"a depleted mine refuses new requests")


# ---------------------------------------------------------------------------
# Pitfall #8 awareness — deferred free verified across multiple frames.
# ---------------------------------------------------------------------------

func test_depleted_mine_queues_self_for_free() -> void:
	# MineNode._on_depleted() calls queue_free.call_deferred() per the
	# established Pitfall #8 pattern (UnitState_Dying.enter is the precedent).
	# Per Pitfall #8 the test must await TWO process_frames at minimum to
	# observe the actual free in a unit-test context.
	_node = _spawn_mine()
	# Exhaust via the API so _on_depleted is the trigger.
	var trips: int = 0
	while _node.is_gatherable and trips < 500:
		_node.request_extract(1)
		SimClock._is_ticking = true
		_node.complete_extract(1)
		SimClock._is_ticking = false
		trips += 1
	# Pitfall #8: queue_free.call_deferred() takes 2 frame awaits to observe.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(_node),
		"MineNode is freed after depletion + 3 process_frame awaits (Pitfall #8)")
	_node = null  # null so after_each doesn't try to double-free


# ---------------------------------------------------------------------------
# Sanity: the yellow-cylinder placeholder is in the scene.
# ---------------------------------------------------------------------------

func test_scene_has_meshinstance3d_child() -> void:
	# Placeholder visual contract per CLAUDE.md "placeholder shapes only" —
	# a yellow cylinder. We don't assert color in the headless test (that's
	# a live-test-only readability question, per the lessons from FarrGauge
	# contrast), but the mesh child must exist so the live game has a
	# visible mine.
	_node = _spawn_mine()
	var mesh: Node = _node.get_node_or_null(^"MeshInstance3D")
	assert_not_null(mesh,
		"MineNode scene includes a MeshInstance3D placeholder visual")


# Wave 1B (2026-05-15): ResourceNode base self-adds to &"resource_nodes"
# group on _ready. This is the cross-cutting seam for Ma'dan's nearest-mine
# discovery — Ma'dan iterates &"resource_nodes" group to find adjacent
# mines within radius. Future Phase 6 AI scouting consumers use the same
# seam.
#
# Mirrors the &"buildings" group convention from Building._ready. The
# group join is added in wave 1B (resource_node.gd) — backward-compat
# safe because nothing in wave 1A consumed the group.
func test_mine_node_joins_resource_nodes_group() -> void:
	_node = _spawn_mine()
	assert_true(_node.is_in_group(&"resource_nodes"),
		"MineNode must join &\"resource_nodes\" group via ResourceNode._ready "
		+ "(wave 1B seam for Ma'dan adjacency discovery)")


# ---------------------------------------------------------------------------
# NavigationObstacle3D — L26 resolution (wave 1C Track 3 Phase 2A)
# ---------------------------------------------------------------------------

func test_mine_node_has_navigation_obstacle() -> void:
	# L26 resolution per docs/WAVE_1C_NAVMESH_SPIKE.md §2.5 + RNC §3.2 v1.4.0.
	# MineNode scenes carry a NavigationObstacle3D so workers route around the
	# deposit. Per STUDIO_PROCESS.md §9 (2026-05-15 rule): presence alone is
	# insufficient — verify Path A config is in effect (affect_navigation_mesh
	# + vertices polygon). Effect verified by integration test
	# test_phase_3_nav_obstacle_carving_behavioral.gd (qa-engineer's Track 2B).
	_node = _spawn_mine()
	var nav: Node = _node.get_node_or_null(^"NavigationObstacle3D")
	assert_not_null(nav,
		"MineNode must contain a NavigationObstacle3D (L26 resolution — "
		+ "workers route around the deposit per RNC §3.2 v1.4.0)")
	assert_true(nav is NavigationObstacle3D,
		"NavigationObstacle3D node is the right type")
	assert_true(nav.affect_navigation_mesh,
		"NavigationObstacle3D.affect_navigation_mesh must be true on MineNode "
		+ "(Path A static-carve mode — without this the obstacle is inert)")
	assert_gt(nav.vertices.size(), 2,
		"NavigationObstacle3D.vertices must be non-empty polygon on MineNode "
		+ "(8-vertex octagon at r=0.85 per WAVE_1C_NAVMESH_SPIKE §2.5)")
