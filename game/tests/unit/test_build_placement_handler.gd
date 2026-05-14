# Tests for the BuildPlacementHandler — Phase 3 session 1 wave 1C deliverable 6.
#
# Per 02f_PHASE_3_KICKOFF.md §3 wave 1C. The handler bridges the build
# menu (deliverable 5) and UnitState_Constructing (deliverable 3):
# build_placement_started signal → placement mode + ghost → click on
# valid terrain → COMMAND_CONSTRUCT to selected Kargar.
#
# Test pattern follows test_click_handler.gd / test_attack_move_handler.gd:
# drive the routing layer (`process_confirm_click_hit`) with synthetic
# hit dictionaries instead of needing a live Camera3D + physics world.
extends GutTest


const BuildPlacementHandlerScript: Script = preload(
	"res://scripts/input/build_placement_handler.gd")
const GhostScene: PackedScene = preload(
	"res://scenes/world/buildings/ghost_placement_preview.tscn")
const KargarScene: PackedScene = preload("res://scenes/units/kargar.tscn")
const PiyadeScene: PackedScene = preload("res://scenes/units/piyade.tscn")
const UnitScript: Script = preload("res://scripts/units/unit.gd")


var _handler: Variant
var _kargar: Variant
var _piyade: Variant


func before_each() -> void:
	SimClock.reset()
	UnitScript.call(&"reset_id_counter")
	SelectionManager.reset()
	ResourceSystem.reset()


func after_each() -> void:
	if _handler != null and is_instance_valid(_handler):
		_handler.queue_free()
	_handler = null
	if _kargar != null and is_instance_valid(_kargar):
		_kargar.queue_free()
	_kargar = null
	if _piyade != null and is_instance_valid(_piyade):
		_piyade.queue_free()
	_piyade = null
	# Free any ghosts left in the scene tree root.
	for n in get_tree().root.get_children():
		var s: Script = n.get_script()
		if s != null and s.resource_path == \
				"res://scripts/world/buildings/ghost_placement_preview.gd":
			n.queue_free()
	SelectionManager.reset()
	ResourceSystem.reset()
	SimClock.reset()


func _spawn_handler() -> Variant:
	var h: Variant = BuildPlacementHandlerScript.new()
	add_child_autofree(h)
	h.set_test_mode(true)  # Don't try to read InputEvents / Viewport in tests.
	return h


func _spawn_kargar() -> Variant:
	var u: Variant = KargarScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	return u


func _spawn_piyade() -> Variant:
	var u: Variant = PiyadeScene.instantiate()
	u.team = Constants.TEAM_IRAN
	add_child_autofree(u)
	return u


# Helper — build a synthetic terrain hit dict at a given position. Mirrors
# what PhysicsDirectSpaceState3D.intersect_ray returns on a hit.
func _terrain_hit(pos: Vector3) -> Dictionary:
	return {&"position": pos, &"normal": Vector3.UP, &"collider": null}


# ---------------------------------------------------------------------------
# Initial state — not in placement mode
# ---------------------------------------------------------------------------

func test_handler_starts_inactive() -> void:
	_handler = _spawn_handler()
	assert_false(_handler.is_placement_active(),
		"Handler starts NOT in placement mode")
	assert_eq(_handler.placement_kind(), &"",
		"placement_kind is empty StringName at start")
	assert_null(_handler.get_ghost(),
		"No ghost spawned until placement is entered")


# ---------------------------------------------------------------------------
# Entering placement mode — build_placement_started signal
# ---------------------------------------------------------------------------

func test_build_placement_started_enters_placement_mode() -> void:
	_handler = _spawn_handler()
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_true(_handler.is_placement_active(),
		"Handler enters placement mode on build_placement_started")
	assert_eq(_handler.placement_kind(), &"khaneh",
		"placement_kind reflects the signal payload")


func test_build_placement_started_spawns_ghost() -> void:
	_handler = _spawn_handler()
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_not_null(_handler.get_ghost(),
		"Ghost preview is spawned when placement mode begins")


func test_build_placement_started_twice_resets_ghost() -> void:
	# Double-press / re-entry case — second signal should clean up the
	# first ghost and spawn a new one.
	_handler = _spawn_handler()
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	var first_ghost: Node = _handler.get_ghost()
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	var second_ghost: Node = _handler.get_ghost()
	assert_not_null(second_ghost, "Second build_placement_started spawns a new ghost")
	assert_ne(first_ghost, second_ghost,
		"Second ghost is a different instance from the first")


# ---------------------------------------------------------------------------
# Confirm click — dispatches COMMAND_CONSTRUCT
# ---------------------------------------------------------------------------

func test_confirm_click_dispatches_command_construct_to_kargar() -> void:
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	# Confirm at a valid terrain position (Y close to 0).
	var target: Vector3 = Vector3(10.0, 0.0, 5.0)
	_handler.process_confirm_click_hit(_terrain_hit(target))
	# Unit.replace_command pushes a Command + calls fsm.transition_to_next
	# which sets _pending_id. The actual swap (with enter()) happens on
	# the next fsm.tick. Drain it.
	SimClock._is_ticking = true
	_kargar.fsm.tick(SimClock.SIM_DT)
	SimClock._is_ticking = false
	assert_eq(_kargar.fsm.current.id, &"constructing",
		"Kargar transitions to Constructing after confirm click + tick drain")
	# Verify the payload survived through current_command.
	var cmd: Dictionary = _kargar.current_command
	assert_eq(cmd.get(&"kind", &""), Constants.COMMAND_CONSTRUCT,
		"current_command.kind is COMMAND_CONSTRUCT")
	var payload: Dictionary = cmd.get(&"payload", {})
	assert_eq(payload.get(&"building_kind", &""), &"khaneh",
		"Payload carries the building kind")
	assert_almost_eq(payload.get(&"target_position", Vector3.ZERO).x,
		target.x, 0.0001,
		"Payload carries the click world position")


func test_confirm_click_exits_placement_mode() -> void:
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	_handler.process_confirm_click_hit(_terrain_hit(Vector3(10.0, 0.0, 5.0)))
	assert_false(_handler.is_placement_active(),
		"Handler exits placement mode after successful confirm")
	assert_null(_handler.get_ghost(),
		"Ghost is destroyed after successful confirm")


# ---------------------------------------------------------------------------
# Defensive paths — empty hit / empty selection / no worker / no money
# ---------------------------------------------------------------------------

func test_confirm_click_with_empty_hit_keeps_placement_mode() -> void:
	# Off-terrain click — ghost stays, mode stays. Player can retry.
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	_handler.process_confirm_click_hit({})
	assert_true(_handler.is_placement_active(),
		"Empty hit (off-map click) does NOT exit placement mode — "
		+ "player gets another shot")


func test_confirm_click_with_empty_selection_cancels_placement() -> void:
	# Player deselected the worker between menu-click and confirm.
	# Cancel cleanly — there's nobody to dispatch to.
	_handler = _spawn_handler()
	# No selection at confirm time.
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	_handler.process_confirm_click_hit(_terrain_hit(Vector3(10.0, 0.0, 5.0)))
	assert_false(_handler.is_placement_active(),
		"Empty selection at confirm cancels placement cleanly")


func test_confirm_click_with_combat_unit_selection_cancels_placement() -> void:
	# Same shape as empty-selection — no worker to dispatch to.
	_handler = _spawn_handler()
	_piyade = _spawn_piyade()
	SelectionManager.select_only(_piyade)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	_handler.process_confirm_click_hit(_terrain_hit(Vector3(10.0, 0.0, 5.0)))
	assert_false(_handler.is_placement_active(),
		"Combat-unit-only selection cancels placement (no worker to "
		+ "dispatch to)")


func test_confirm_click_with_insufficient_coin_cancels_placement() -> void:
	# Player had enough coin at menu-press but spent it before confirm.
	# Affordability gate rejects + cancels.
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	# Drain coin to 0.
	SimClock._is_ticking = true
	var have: int = ResourceSystem.coin_x100_for(Constants.TEAM_IRAN)
	ResourceSystem.change_resource(
		Constants.TEAM_IRAN, Constants.KIND_COIN, -have,
		&"test_drain", null)
	SimClock._is_ticking = false
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	_handler.process_confirm_click_hit(_terrain_hit(Vector3(10.0, 0.0, 5.0)))
	assert_false(_handler.is_placement_active(),
		"Insufficient Coin at confirm cancels placement")
	# Kargar is still Idle — no dispatch.
	assert_eq(_kargar.fsm.current.id, &"idle",
		"Kargar stays Idle when placement is cancelled for insufficient funds")


# ---------------------------------------------------------------------------
# Validity check — overlap detection
# ---------------------------------------------------------------------------

func test_validity_rejects_overlap_with_existing_building() -> void:
	# Place a Khaneh manually in the world; verify the handler reports
	# invalid at the same position.
	_handler = _spawn_handler()
	# Spawn a Khaneh via the scene at a known position. Use the &"buildings"
	# group joined on _ready so the validity check finds it.
	var existing: Variant = preload(
		"res://scenes/world/buildings/khaneh.tscn").instantiate()
	add_child_autofree(existing)
	existing.global_position = Vector3(10.0, 0.0, 5.0)
	# Now exercise validity at the same position.
	var valid: bool = _handler._is_placement_valid_at(Vector3(10.0, 0.0, 5.0))
	assert_false(valid,
		"Placement at the same position as an existing building is INVALID")


func test_validity_accepts_position_away_from_existing_building() -> void:
	_handler = _spawn_handler()
	# No buildings — any reasonable position should be valid.
	var valid: bool = _handler._is_placement_valid_at(Vector3(10.0, 0.0, 5.0))
	assert_true(valid,
		"Placement on empty terrain (no overlap) is VALID")


# ---------------------------------------------------------------------------
# Confirm click on invalid position — rejects, ghost stays
# ---------------------------------------------------------------------------

func test_confirm_click_on_invalid_position_does_not_dispatch() -> void:
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	# Drop an existing Khaneh to make the position invalid.
	var existing: Variant = preload(
		"res://scenes/world/buildings/khaneh.tscn").instantiate()
	add_child_autofree(existing)
	existing.global_position = Vector3(10.0, 0.0, 5.0)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	# Confirm at the overlapping position.
	_handler.process_confirm_click_hit(_terrain_hit(Vector3(10.0, 0.0, 5.0)))
	# Placement mode stays active — player can move the cursor and retry.
	assert_true(_handler.is_placement_active(),
		"Confirm on invalid position keeps placement mode active")
	# Kargar didn't get a dispatch.
	assert_ne(_kargar.fsm.current.id, &"constructing",
		"Kargar did NOT transition to Constructing on invalid confirm")


# ---------------------------------------------------------------------------
# Cancel — explicit cancel_placement helper coverage
# ---------------------------------------------------------------------------

func test_cancel_placement_clears_state() -> void:
	_handler = _spawn_handler()
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_true(_handler.is_placement_active())
	_handler._cancel_placement()
	assert_false(_handler.is_placement_active(),
		"_cancel_placement clears the placement mode")
	assert_null(_handler.get_ghost(),
		"_cancel_placement destroys the ghost")
	assert_eq(_handler.placement_kind(), &"",
		"_cancel_placement clears placement_kind")


# ---------------------------------------------------------------------------
# BUG-08 — selection cleared mid-placement auto-cancels
# ---------------------------------------------------------------------------
# Lead's Phase 3 session 1 live-test: when a Button-press race or any other
# path clears the selection while placement mode is active, the handler must
# auto-cancel rather than leave the ghost orphaned. Without this guard the
# only escape is a right-click / Escape, and meanwhile a stale ghost is in
# the world and the next confirm-click silently fails on the empty-selection
# branch.

func test_selection_deselect_all_cancels_active_placement() -> void:
	# Enter placement mode with a Kargar selected; then deselect all.
	# The handler should auto-cancel placement (ghost despawned,
	# _placement_kind cleared).
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_true(_handler.is_placement_active(),
		"sanity: placement mode active after build_placement_started")
	# This is the bug path: selection gets cleared while placement
	# mode is active.
	SelectionManager.deselect_all()
	assert_false(_handler.is_placement_active(),
		"BUG-08: deselect_all mid-placement must auto-cancel — "
		+ "ghost orphaned otherwise")
	assert_null(_handler.get_ghost(),
		"BUG-08: ghost must be destroyed when selection clears mid-placement")
	assert_eq(_handler.placement_kind(), &"",
		"BUG-08: _placement_kind must be cleared on auto-cancel")


func test_selection_replaced_with_combat_unit_cancels_active_placement() -> void:
	# Variant: selection replaced with a non-Kargar unit (e.g., control
	# group recall to a Piyade-only group). Same guard — no Kargar in
	# the new selection means there's no worker to dispatch to.
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	_piyade = _spawn_piyade()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_true(_handler.is_placement_active(), "sanity")
	# Replace selection with a non-worker.
	SelectionManager.select_only(_piyade)
	assert_false(_handler.is_placement_active(),
		"BUG-08: replacing selection with a non-Kargar must auto-cancel "
		+ "placement (no worker to dispatch to)")
	assert_null(_handler.get_ghost(),
		"BUG-08: ghost destroyed when selection no longer contains a Kargar")


func test_selection_replaced_with_other_kargar_keeps_placement_active() -> void:
	# Counter-case: if the new selection STILL contains a Kargar (a
	# different worker, or the same one re-selected), the placement
	# mode is preserved. We auto-cancel ONLY when there's no worker
	# left to dispatch to.
	_handler = _spawn_handler()
	_kargar = _spawn_kargar()
	var other_kargar: Variant = _spawn_kargar()
	SelectionManager.select_only(_kargar)
	EventBus.build_placement_started.emit(&"khaneh", 5000)
	assert_true(_handler.is_placement_active(), "sanity")
	SelectionManager.select_only(other_kargar)
	assert_true(_handler.is_placement_active(),
		"BUG-08: replacing selection with a different Kargar must NOT "
		+ "cancel placement — the new worker can build")
	# Cleanup the additional kargar.
	if is_instance_valid(other_kargar):
		other_kargar.queue_free()


# ---------------------------------------------------------------------------
# Ghost preview — green/red color flip
# ---------------------------------------------------------------------------

func test_ghost_set_validity_flips_color() -> void:
	# Direct test of the ghost script's API.
	var ghost: Variant = GhostScene.instantiate()
	add_child_autofree(ghost)
	# Initial state: red (invalid).
	var mi: MeshInstance3D = ghost.get_node(^"MeshInstance3D")
	var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.r > 0.5,
		"Ghost starts red (invalid) — r > 0.5, got r=%.2f" % mat.albedo_color.r)
	# Flip to valid.
	ghost.set_validity(true)
	mat = mi.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.g > 0.5,
		"After set_validity(true) ghost is green — g > 0.5, got g=%.2f"
		% mat.albedo_color.g)
	# Flip back to invalid.
	ghost.set_validity(false)
	mat = mi.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.r > 0.5,
		"After set_validity(false) ghost is red — r > 0.5, got r=%.2f"
		% mat.albedo_color.r)


func test_ghost_scene_has_no_collision_body() -> void:
	# BUG-07 lesson INVERTED for the ghost. The ghost must NOT have a
	# CollisionObject3D in its subtree — otherwise the placement
	# raycast would hit the ghost itself instead of the terrain.
	var ghost: Variant = GhostScene.instantiate()
	add_child_autofree(ghost)
	var found_body: bool = false
	for child in ghost.get_children():
		if child is CollisionObject3D:
			found_body = true
			break
	assert_false(found_body,
		"Ghost MUST NOT contain a CollisionObject3D — otherwise the "
		+ "placement raycast would hit the ghost itself instead of the "
		+ "terrain underneath (BUG-07 lesson inverted)")


func test_ghost_not_in_buildings_group() -> void:
	# The validity-check overlap test iterates the &"buildings" group.
	# If the ghost were in it, it'd report "overlapping itself" as
	# invalid everywhere.
	var ghost: Variant = GhostScene.instantiate()
	add_child_autofree(ghost)
	assert_false(ghost.is_in_group(&"buildings"),
		"Ghost MUST NOT be in the &\"buildings\" group — otherwise the "
		+ "validity-overlap check would self-flag every position as invalid")
