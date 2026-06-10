extends Node
##
## BuildPlacementHandler — input handler for the building-placement flow.
##
## Phase 3 session 1 wave 1C deliverable 6. Per
## 02f_PHASE_3_KICKOFF.md §3 wave 1C.
##
## Flow:
##   1. Player clicks a build-menu button → BuildMenu emits
##      EventBus.build_placement_started(kind, cost_x100) → this handler
##      enters placement mode (_placement_kind != &""; ghost preview
##      spawned and follows the cursor).
##   2. Cursor moves → ghost preview tracks mouse position (raycast to
##      terrain). Color is green when valid (on terrain, away from
##      existing buildings), red when invalid.
##   3. Player left-clicks valid terrain → dispatch COMMAND_CONSTRUCT
##      to every Kargar in the selection. Exit placement mode.
##   4. Player right-clicks OR presses Escape → cancel placement.
##      Ghost despawns. No command dispatched.
##
## Why a separate node (not folded into ClickHandler):
##   Gather routing went into ClickHandler (wave 1B) but the placement
##   flow has stateful cursor-tracking that doesn't fit the
##   "press → consume" shape of single-click selection. A dedicated
##   handler keeps click_handler.gd lean and the placement-mode
##   state local. Same precedent as AttackMoveHandler being a sibling
##   of ClickHandler.
##
## Input ordering (Pitfall #5):
##   When _placement_kind != &"", this handler's _unhandled_input
##   consumes the click BEFORE ClickHandler interprets it. **Godot
##   dispatches _unhandled_input in REVERSE sibling order** — the
##   higher-index sibling fires first (verified by
##   tests/unit/test_godot_unhandled_input_dispatch_order.gd). So this
##   handler is placed AFTER ClickHandler / BoxSelectHandler /
##   DoubleClickSelect in main.tscn so it fires first. When in
##   placement mode it consumes the click and calls
##   `get_viewport().set_input_as_handled()`; the other sibling
##   handlers never see the event. Regression-locked by
##   test_main_tscn_build_placement_handler_after_click_handler and
##   test_pitfall_5_build_placement_handler_after_click_handler_standalone
##   in tests/integration/test_phase_3_khaneh_placement.gd.
##
##   BUG-10 history (2026-05-14): the wave-1C placement put BPH at a
##   LOWER sibling index ("BEFORE ClickHandler") under the mistaken
##   "lower-index = first" convention copied from AttackMoveHandler.
##   That convention was backwards; ClickHandler at the lower index
##   actually fired first, consumed every terrain click via deselect-
##   all, and the BUG-08 selection_changed guard then cancelled the
##   orphaned placement state. See ARCHITECTURE.md §6 v0.20.8.
##
##   When _placement_kind == &"" (no active placement), the handler
##   short-circuits and lets ClickHandler do its normal job.
##
## Sim Contract §1.5 fit:
##   Same as ClickHandler / AttackMoveHandler. _unhandled_input runs
##   off-tick; the COMMAND_CONSTRUCT dispatch goes via
##   Unit.replace_command (Object surface, queued for the next on-tick
##   transition_to_next). The cost-affordability pre-screen reads from
##   ResourceSystem (off-tick read; Sim Contract §1.5 sanctions UI
##   reads of sim state).
##
## Ghost preview:
##   A separate Node3D instance loaded from ghost_placement_preview.tscn
##   (the ghost is a translucent Khaneh-mesh; deliberately NO collision
##   shape — the ghost must not block raycasts or unit physics). The
##   ghost's color is driven by `_placement_is_valid` — green when
##   placement is valid, red when invalid. Validity is currently:
##     - hit a valid terrain raycast (not off the map);
##     - placement does NOT overlap an existing building (group lookup,
##       cheap with ~1-3 buildings in session 1).
##   Future validity checks (Phase 4+): on navmesh, within tech-radius,
##   resource constraints.
##
## Pitfall #4 awareness:
##   The build_placement_started handler enters placement mode and
##   spawns the ghost. We DO NOT mutate ResourceSystem here. The
##   affordability check at confirm-time reads ResourceSystem.coin_x100_for
##   (read-only); the actual deduction lives in UnitState_Constructing's
##   on-arrival step.
##
## Pitfall #1 awareness:
##   The ghost preview is a Node3D in the world, NOT a Control. Not
##   subject to mouse_filter discipline. The build menu (which IS a
##   Control surface) handles its own mouse_filter; this handler only
##   touches 3D world space.
##
## BUG-07 lesson awareness:
##   The ghost preview INTENTIONALLY has no collision body — it must
##   not be raycast-target. The PLACED Khaneh (created by
##   UnitState_Constructing) does have a StaticBody3D via the base
##   Building scene (deliverable 1's BUG-07 lesson). So the placement
##   chain is consistent: ghost = no collision, placed = collision.

const RAYCAST_DISTANCE: float = 1000.0
const RAYCAST_COLLISION_MASK: int = 0xFFFFFFFF
const DEBUG_LOG_CLICKS: bool = true

# Ghost preview scene — translucent Khaneh visual that follows the cursor.
const _GhostPreviewScene: PackedScene = preload(
	"res://scenes/world/buildings/ghost_placement_preview.tscn")


# ============================================================================
# State
# ============================================================================

# When non-empty StringName, the handler is in placement mode for that
# building kind (currently only &"khaneh" — extend with session 2's
# building roster).
var _placement_kind: StringName = &""

# Cost (in coin_x100) of the building being placed. Cached from the
# build_placement_started signal so the confirm step can affordability-
# check without re-reading BalanceData.
var _placement_cost_x100: int = 0

# Grain cost (in grain_x100) of the building being placed. Wave 2B BUG-B2
# fix-wave (2026-05-22): the EventBus.build_placement_started signal
# carries ONLY coin (signature locked at session-1; see build_menu.gd:272-
# 277 comment which contracts grain handling to the sim-side). For the
# placement-handler's affordability check + ghost-color discipline, we
# read grain_cost from BalanceData via the same defensive-fall-through
# pattern as UnitState_Constructing._resolve_cost_grain (Wave 2A.5 BUG-A
# fix `dfa9a33`). Resolved at _on_build_placement_started; defaults to 0
# for buildings without grain cost (Khaneh / Mazra'eh / Ma'dan / Sarbaz-
# khaneh / Sowari-khaneh / Tirandazi all have grain_cost=0). Non-zero
# only for Atashkadeh (50 grain) at MVP scope.
var _placement_grain_cost_x100: int = 0

# The ghost preview Node3D instance. Spawned on entering placement
# mode, freed on exit / confirm.
var _ghost: Node3D = null

# Whether the current ghost position is a valid placement target.
# Drives the ghost color (green=true, red=false). Read by tests and
# by the confirm step (invalid clicks are rejected, ghost stays).
var _placement_is_valid: bool = false

# Last-known cursor world position. Updated in _process; read by the
# confirm step (so the dispatched COMMAND_CONSTRUCT uses the position
# the player visually clicked on).
var _last_cursor_world_pos: Vector3 = Vector3.ZERO


# Test seam — same pattern as ClickHandler / AttackMoveHandler.
var _test_mode: bool = false


func set_test_mode(on: bool) -> void:
	_test_mode = on


# Test-only inspectors.
func is_placement_active() -> bool:
	return _placement_kind != &""


func placement_kind() -> StringName:
	return _placement_kind


func ghost_is_valid() -> bool:
	return _placement_is_valid


func get_ghost() -> Node3D:
	return _ghost


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	if not EventBus.build_placement_started.is_connected(_on_build_placement_started):
		EventBus.build_placement_started.connect(_on_build_placement_started)
	# BUG-08 guard — auto-cancel placement if the selection no longer
	# contains a Kargar mid-placement. Defends against ANY deselection
	# path (Button-press race in deliverable 5 / BUG-08; control-group
	# recall to a non-Kargar; scripted deselect_all; future paths). Without
	# this guard, an orphaned ghost stays in the world and the next
	# confirm-click silently fails on the empty-selection branch — the
	# exact failure mode the lead live-tested at Phase 3 session 1 close.
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.build_placement_started.is_connected(_on_build_placement_started):
		EventBus.build_placement_started.disconnect(_on_build_placement_started)
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)
	_destroy_ghost()


# ============================================================================
# Signal handlers
# ============================================================================

# BUG-08 — auto-cancel placement when the selection no longer contains
# a Kargar mid-placement. The selection_changed signal carries unit_ids,
# but we route through SelectionManager.selected_units for live Node refs
# (the live ref is needed for the _find_first_worker duck-type check).
# Same defensive pattern as build_menu.gd::_on_selection_changed.
func _on_selection_changed(_selected_unit_ids: Array) -> void:
	if _placement_kind == &"":
		return  # not in placement mode — nothing to guard.
	var sel: Array = SelectionManager.selected_units
	if _find_first_worker(sel) == null:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] BUG-08 guard — selection lost its "
				+ "Kargar mid-placement; auto-cancelling")
		_cancel_placement()


# Enter placement mode. Spawn the ghost preview as a child of the
# scene-tree root so it lives in world space and survives until we
# explicitly destroy it.
func _on_build_placement_started(building_kind: StringName, cost_coin_x100: int) -> void:
	# If we're already in placement mode (player clicked the build button
	# twice rapidly, or the menu is buggy), reset the prior ghost first.
	if _placement_kind != &"":
		_destroy_ghost()
	_placement_kind = building_kind
	_placement_cost_x100 = cost_coin_x100
	# Wave 2B BUG-B2 fix-wave: resolve grain cost from BalanceData by kind.
	# The EventBus signal carries coin only (contract locked); grain is
	# discovered handler-side via the same BalanceData read pattern that
	# UnitState_Constructing uses. Returns 0 for buildings with grain_cost=0
	# (every building except Atashkadeh at MVP scope), in which case the
	# affordability check's grain branch is a no-op and the original
	# Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh / Sowari-khaneh /
	# Tirandazi behavior is preserved unchanged.
	_placement_grain_cost_x100 = _resolve_grain_cost_x100(building_kind)
	_placement_is_valid = false
	_spawn_ghost()
	if DEBUG_LOG_CLICKS:
		print("[build-placement] entered placement mode for kind=",
			building_kind, " coin_x100=", cost_coin_x100,
			" grain_x100=", _placement_grain_cost_x100)


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if _placement_kind == &"":
		return  # not in placement mode — let other handlers run.
	# BUG-10 diagnostic — entry log gated on placement mode. Future
	# input-ordering bugs are diagnosable by checking this line against
	# the [click] / [box-select] logs in run order.
	if DEBUG_LOG_CLICKS and event is InputEventMouseButton and event.pressed:
		print("[build-placement] _unhandled_input entry — kind=", _placement_kind,
			" button=", event.button_index)
	if not (event is InputEventMouseButton):
		# Mouse motion is handled in _process for ghost tracking, not here.
		# Escape cancels.
		if event is InputEventKey:
			var ek: InputEventKey = event
			if ek.pressed and ek.keycode == KEY_ESCAPE:
				_cancel_placement()
				get_viewport().set_input_as_handled()
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_confirm_click(mb.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			# Right-click cancels placement (RTS convention).
			_cancel_placement()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _test_mode:
		return
	if _placement_kind == &"":
		return
	# Track cursor. Update ghost position + validity each frame.
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_update_ghost_from_screen(screen_pos)


# ============================================================================
# Click + ghost handlers
# ============================================================================

# Handle a left-click during placement mode. If the click is on valid
# terrain AND there's a Kargar in the selection, dispatch the
# COMMAND_CONSTRUCT to that worker and exit placement mode. Otherwise
# reject (ghost stays, mode stays).
func _handle_confirm_click(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_confirm_click_hit(hit)


# Public for tests. Same shape as ClickHandler.process_*_hit — drives the
# logic without needing a live Camera3D / physics world.
func process_confirm_click_hit(hit: Dictionary) -> void:
	if _placement_kind == &"":
		return
	if hit.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click — no raycast hit, "
				+ "rejecting (ghost stays in placement mode)")
		return
	# Validate. Refresh against the click point (more authoritative than
	# the last _process update — the click point may differ from cursor
	# by a frame). Wave 2B BUG-B2 fix-wave: GEOMETRIC validity and
	# AFFORDABILITY validity were collapsed into a single composite
	# _is_placement_valid_at for the ghost-color discipline, but at
	# confirm-time we still differentiate them because the FAILURE SEMANTIC
	# differs:
	#   - Geometric invalid (over building / off-map): ghost stays, player
	#     tries another location. NO _cancel_placement().
	#   - Affordability invalid (insufficient coin/grain): can't fix by
	#     re-clicking; cancel the entire placement. The downstream
	#     selection / worker checks below also cancel — same semantic.
	# Geometric check first; affordability falls through to the existing
	# coin/grain blocks below (which both call _cancel_placement on failure).
	var hit_pos: Vector3 = hit.get(&"position", Vector3.ZERO)
	if not _is_geometric_placement_valid_at(hit_pos):
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click on geometrically INVALID "
				+ "location ", hit_pos, " — rejecting (ghost stays for retry)")
		return
	# Affordability gate. Read ResourceSystem.coin_x100_for and reject
	# if the player no longer has the coin (they may have spent it
	# between menu-press and confirm-click).
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but selection is empty"
				+ " — rejecting (no worker to dispatch to)")
		_cancel_placement()
		return
	var worker: Object = _find_first_worker(sel)
	if worker == null:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but selection has no "
				+ "worker — rejecting")
		_cancel_placement()
		return
	var team: int = Constants.TEAM_NEUTRAL
	if &"team" in worker:
		team = int(worker.get(&"team"))
	# Wave 2B BUG-B2.5 fix-wave (2026-05-22): both-or-neither
	# affordability at confirm-click. Mirrors UnitState_Constructing's
	# BUG-A fix at `dfa9a33`. Pre-fix-wave this was coin-only and the
	# grain check happened downstream in UnitState_Constructing — for
	# Atashkadeh (150 coin + 50 grain), a player with coin but no grain
	# would have their click accepted here, worker walked to the site,
	# then UnitState_Constructing's both-or-neither would reject. Silent
	# failure from the player's perspective. Now both checks fire here
	# at confirm time, mirroring the ghost-color logic in
	# _is_affordability_valid above.
	if _placement_cost_x100 > 0 and ResourceSystem.coin_x100_for(team) < _placement_cost_x100:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but insufficient Coin"
				+ " — rejecting (have=%d need=%d)"
				% [ResourceSystem.coin_x100_for(team), _placement_cost_x100])
		_cancel_placement()
		return
	if _placement_grain_cost_x100 > 0 and ResourceSystem.grain_x100_for(team) < _placement_grain_cost_x100:
		if DEBUG_LOG_CLICKS:
			print("[build-placement] confirm click but insufficient Grain"
				+ " — rejecting (have=%d need=%d). BUG-B2.5 fix-wave: "
				+ "second instance of affordability-check-incomplete "
				+ "failure mode; first was BUG-A at UnitState_Constructing."
				% [ResourceSystem.grain_x100_for(team), _placement_grain_cost_x100])
		_cancel_placement()
		return
	# Dispatch! Build the COMMAND_CONSTRUCT payload + push to the worker.
	worker.replace_command(
		Constants.COMMAND_CONSTRUCT,
		{
			&"building_kind": _placement_kind,
			&"target_position": hit_pos,
		},
	)
	if DEBUG_LOG_CLICKS:
		print("[build-placement] dispatched COMMAND_CONSTRUCT kind=",
			_placement_kind, " pos=", hit_pos, " worker_id=",
			worker.get(&"unit_id"))
	# Exit placement mode — ghost despawns, _placement_kind cleared.
	_destroy_ghost()
	_placement_kind = &""
	_placement_cost_x100 = 0
	_placement_grain_cost_x100 = 0


# Update ghost transform from a screen-space cursor position. Public for
# tests so they can inject a fake screen_pos without a Camera3D.
func _update_ghost_from_screen(screen_pos: Vector2) -> void:
	if _ghost == null:
		return
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	if hit.is_empty():
		# Off-map — leave ghost where it was; mark invalid.
		_placement_is_valid = false
		_set_ghost_color(_placement_is_valid)
		return
	var pos: Vector3 = hit.get(&"position", Vector3.ZERO)
	_last_cursor_world_pos = pos
	_ghost.global_position = pos
	_placement_is_valid = _is_placement_valid_at(pos)
	_set_ghost_color(_placement_is_valid)


# Validity check — combines GEOMETRIC validity with AFFORDABILITY validity.
# Wave 2B BUG-B2 fix-wave (2026-05-22): user live-test surfaced that the
# ghost stayed GREEN when the player couldn't afford the building, then
# the click silently cancelled at the affordability gate downstream. The
# user experienced "click does nothing / deselects." Fix: collapse both
# checks into _is_placement_valid_at so the ghost-color truthfully
# reflects whether a click WILL succeed, not just whether the geometry
# WOULD be valid IF resources were sufficient. Same pattern as the BUG-A
# fix at UnitState_Constructing `dfa9a33` — both-or-neither affordability
# discipline applied at the ghost-color layer too.
#
# Geometric validity (1-3 below) is unchanged from session-5 Task #143
# state; affordability (4) is the new addition.
#   1. Hit position is on the terrain plane (Y close to 0).
#   2. Position does not overlap an existing building (&"buildings" group).
#   3. Position does not overlap an existing resource node (&"resource_nodes"
#      group — mines, future grain deposits). Task #143 fix: prior versions
#      missed this, allowing a Ma'dan to be placed directly ON a mine
#      cylinder. The check generalizes: any building placed over any
#      resource node is rejected.
#   4. **NEW (BUG-B2 fix):** affordability — player's coin AND grain both
#      meet the requirement. Both-or-neither pattern mirrors BUG-A fix at
#      UnitState_Constructing `dfa9a33`.
# Future (Phase 4+): on-navmesh check, tech-radius constraint.
func _is_placement_valid_at(pos: Vector3) -> bool:
	# Composite check: BOTH gates must pass. Either failure → red ghost.
	return _is_geometric_placement_valid_at(pos) and _is_affordability_valid()


# Geometric validity check — extracted from the original _is_placement_valid_at
# at BUG-B2 fix-wave (2026-05-22) so the composite function above can
# combine geometry with affordability cleanly. Behavior is unchanged from
# the pre-fix-wave implementation (Task #143 + earlier).
#
# Wave-B3 (review finding GP-5): the body moved verbatim into the static
# is_placement_geometry_valid below so DummyIranController's AI build
# placement validates against the SAME rules the player flow uses (the
# sim must not distinguish AI-issued from player-issued construction).
# This instance method is the player-flow entry point; it delegates.
func _is_geometric_placement_valid_at(pos: Vector3) -> bool:
	return is_placement_geometry_valid(get_tree(), pos)


## Shared geometric placement-validity rule — the single source of truth
## for "can a building footprint legally land at pos". Consumers:
##   - the player flow (ghost color + confirm-click) via
##     _is_geometric_placement_valid_at above;
##   - DummyIranController (Wave-B3, review finding GP-5) — the reference
##     AI's deterministic build placement validates each offset candidate
##     against this exact rule before issuing COMMAND_CONSTRUCT.
## Static + tree-parameterized (no instance state is read) so non-input
## consumers don't need a live BuildPlacementHandler node.
static func is_placement_geometry_valid(tree: SceneTree, pos: Vector3) -> bool:
	if tree == null:
		return false
	# Off-map / clearly out of range — terrain plane is Y=0, allow some
	# tolerance for raycast slop.
	if pos.y > 1.0 or pos.y < -1.0:
		return false
	# Overlap threshold for both groups. 2.5m derives from the Khaneh
	# footprint 2x2 (half-diagonal ~1.4) plus margin. For MineNode the
	# cylinder radius is 0.75 and a Ma'dan footprint is 2.5x2.5 (half-
	# diagonal ~1.77), so 1.77 + 0.75 = ~2.52 — the same threshold gives
	# a sensible no-overlap gap. Per-kind footprint reads via
	# Building.get_footprint_aabb() are a future refinement
	# (Phase 4+); 2.5m blanket is fine at MVP scope.
	const _OVERLAP_THRESHOLD: float = 2.5
	const _OVERLAP_THRESHOLD_SQ: float = _OVERLAP_THRESHOLD * _OVERLAP_THRESHOLD
	# Overlap check against placed buildings. Use the &"buildings"
	# group (every Building joins it on _ready per deliverable 1).
	for b: Node in tree.get_nodes_in_group(&"buildings"):
		if not is_instance_valid(b):
			continue
		if not (b is Node3D):
			continue
		var bp: Vector3 = (b as Node3D).global_position
		var dx: float = bp.x - pos.x
		var dz: float = bp.z - pos.z
		if dx * dx + dz * dz < _OVERLAP_THRESHOLD_SQ:
			return false
	# Overlap check against placed resource nodes (mines today; future
	# grain deposits / quarries). ResourceNode._ready joins
	# &"resource_nodes" (resource_node.gd:133). Task #143 — live-test
	# surfaced a Ma'dan placed directly on a mine deposit.
	for r: Node in tree.get_nodes_in_group(&"resource_nodes"):
		if not is_instance_valid(r):
			continue
		if not (r is Node3D):
			continue
		var rp: Vector3 = (r as Node3D).global_position
		var rdx: float = rp.x - pos.x
		var rdz: float = rp.z - pos.z
		if rdx * rdx + rdz * rdz < _OVERLAP_THRESHOLD_SQ:
			return false
	return true


# Affordability validity check — Wave 2B BUG-B2 + BUG-B2.5 fix-wave
# (2026-05-22). Returns true when the placing team can afford BOTH the
# coin cost and the grain cost. Mirrors the both-or-neither affordability
# pattern shipped at UnitState_Constructing `dfa9a33` (BUG-A fix); this
# is the SECOND instance of the "affordability-check incomplete" failure
# mode — Wave 2A.5 fix landed UnitState_Constructing's side but missed
# the BuildPlacementHandler pre-screen. Now corrected.
#
# Team resolution: read from the first Kargar in the current selection.
# When no Kargar is selected (selection lost mid-placement, or empty),
# we conservatively return TRUE — the affordability check should not be
# the cause of red-ghost when the actual blocker is "no worker to
# dispatch to" (BUG-08 guard handles selection-loss separately). This
# preserves the existing UX: cancel-on-empty-selection at confirm-click
# is the dedicated path, not a ghost-color flip.
func _is_affordability_valid() -> bool:
	var team: int = _resolve_placement_team()
	if team == Constants.TEAM_NEUTRAL:
		# No worker / can't resolve team — affordability is conservatively
		# TRUE; the empty-selection branch in confirm-click cancels via
		# its own dedicated path.
		return true
	# Both-or-neither: coin AND grain must satisfy. Either failure → red.
	# Each cost is "skip if 0" so buildings without grain cost (every
	# Tier-1/2 building except Atashkadeh at MVP) have the grain branch
	# pass trivially.
	if _placement_cost_x100 > 0:
		if ResourceSystem.coin_x100_for(team) < _placement_cost_x100:
			return false
	if _placement_grain_cost_x100 > 0:
		if ResourceSystem.grain_x100_for(team) < _placement_grain_cost_x100:
			return false
	return true


# Resolve the placing team from the current selection. Returns
# Constants.TEAM_NEUTRAL when no Kargar is in the selection (caller
# treats this as "skip the affordability check"). Same selection-lookup
# pattern as confirm-click's worker resolution.
func _resolve_placement_team() -> int:
	var sel: Array = SelectionManager.selected_units
	var worker: Object = _find_first_worker(sel)
	if worker == null:
		return Constants.TEAM_NEUTRAL
	if &"team" in worker:
		return int(worker.get(&"team"))
	return Constants.TEAM_NEUTRAL


# Read the building's grain_cost from BalanceData. Mirrors the defensive
# fall-through pattern in UnitState_Constructing._resolve_cost_grain
# (Wave 2A.5 BUG-A fix `dfa9a33`) — same SSOT, same fallback semantics.
# Returns 0 on any failure path (missing file / missing entry / wrong
# type), which preserves the no-grain-cost behavior for the Tier-1/2
# Iran roster except Atashkadeh.
#
# Returns grain_cost in WHOLE units (not _x100). The handler stores the
# x100 form to match _placement_cost_x100's scale, so the caller
# multiplies the return by 100.
func _resolve_grain_cost_x100(building_kind: StringName) -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(building_kind, null)
	if stats == null:
		return 0
	var grain_v: Variant = stats.get(&"grain_cost")
	if typeof(grain_v) != TYPE_INT and typeof(grain_v) != TYPE_FLOAT:
		return 0
	return int(grain_v) * 100


# ============================================================================
# Cancel / ghost management
# ============================================================================

func _cancel_placement() -> void:
	if DEBUG_LOG_CLICKS:
		print("[build-placement] placement cancelled (kind was=",
			_placement_kind, ")")
	_destroy_ghost()
	_placement_kind = &""
	_placement_cost_x100 = 0
	_placement_grain_cost_x100 = 0
	_placement_is_valid = false


func _spawn_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_destroy_ghost()
	_ghost = _GhostPreviewScene.instantiate() as Node3D
	# Add to the scene tree root so the ghost lives in world space.
	# Defensive — get_tree().root may be null in some test contexts;
	# in production it's always there.
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		# No tree — abort spawn silently. Test fixtures may construct
		# the handler without a tree.
		_ghost.free()
		_ghost = null
		return
	tree.root.add_child(_ghost)


func _destroy_ghost() -> void:
	if _ghost == null:
		return
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


# Set the ghost mesh's color to green (valid) or red (invalid). The
# ghost preview script (ghost_placement_preview.gd) owns the color
# logic; we just flip an exposed property.
func _set_ghost_color(is_valid: bool) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		return
	if _ghost.has_method(&"set_validity"):
		_ghost.call(&"set_validity", is_valid)


# ============================================================================
# Helpers
# ============================================================================

# Find the first Kargar in the selection. Returns null if none.
# Same duck-type as BuildMenu / ClickHandler.
func _find_first_worker(sel: Array) -> Object:
	for u in sel:
		if u == null or not is_instance_valid(u):
			continue
		var ut: Variant = u.get(&"unit_type")
		if typeof(ut) == TYPE_STRING_NAME and ut == &"kargar":
			return u
	return null


# Raycast from camera through screen-space cursor. Same pattern as
# ClickHandler._raycast_from_screen — duplicate code, but the
# alternative is exposing ClickHandler's helper publicly which would
# couple the two handlers.
func _raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return {}
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return {}
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * RAYCAST_DISTANCE
	var world: World3D = viewport.find_world_3d()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, RAYCAST_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)
