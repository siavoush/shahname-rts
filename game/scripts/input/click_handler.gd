extends Node

# Right-click move dispatcher — single-unit fast path returns target verbatim,
# multi-unit selection fans out across a ring (wave 2C wiring).
const _GroupMove := preload("res://scripts/movement/group_move_controller.gd")
##
## ClickHandler — translates raw mouse clicks into SelectionManager + Unit
## command writes.
##
## Phase 1 session 1 wave 2 (ui-developer). Per docs/02b_PHASE_1_KICKOFF.md §2 (2)+(3).
##
## Responsibilities:
##   - Left-click anywhere: raycast from camera through mouse position. If hit
##     is a Unit (or a child of a Unit), SelectionManager.select_only(unit). If
##     hit is empty terrain (or no hit), SelectionManager.deselect_all().
##   - Right-click anywhere: raycast from camera through mouse position. If hit
##     is terrain (NOT a unit), build a Move Command (kind = &"move",
##     payload = {target: Vector3}) and push to each currently-selected unit's
##     command_queue via Unit.replace_command. If no units are selected, no-op.
##
## Sim Contract §1.5 fit:
##   _unhandled_input runs off-tick — exactly the right context per the contract
##   ("UI-side state ... CAN be mutated from _input"). The SelectionManager
##   broadcast emits EventBus.selection_changed (read-shaped, L2-allowlisted).
##   Unit.replace_command pushes to a CommandQueue — that is gameplay-state
##   mutation, but the queue is observable-only-by-the-state-machine-tick;
##   per the State Machine Contract §3.4 the state machine will dispatch the
##   command on its next on-tick `transition_to_next()`. Calling replace_command
##   from off-tick is safe because the queue mutation is buffered: `tick()`
##   reads `_pending_id` after `current._sim_tick`, and `replace_command`
##   itself calls `fsm.transition_to_next()` which sets `_pending_id`. The
##   StateMachine's bounded-chain loop in `tick()` drains it on the next
##   sim-tick. No off-tick write to component-owned `_set_sim`-protected fields
##   happens here — only queue / pending-id mutation, which is RefCounted/Object
##   surface. (See engine-architect's wave 1 design note in §6 v0.9.0.)
##
## Sim Contract §3.4 fit:
##   Raycast queries SpatialIndex/PhysicsServer indirectly via direct_space_state.
##   Both are read-safe between tick boundaries from _input / _process. We do
##   not touch the SpatialIndex directly here (that pattern is reserved for
##   AoE-style per-radius selects in Phase 1 session 2's box-drag). For
##   single-click, a physics raycast against unit collision shapes is the
##   simplest precise hit-test and avoids mismatches between visual and
##   spatial-index positions.
##
## Wiring:
##   This script is attached to a node under Main in main.tscn so its
##   _unhandled_input fires for clicks not consumed by the camera or HUD.
##   The camera's _unhandled_input handles MOUSE_WHEEL_UP/DOWN only, so left
##   and right click events propagate down to us.
##
## Out of scope (Phase 1 session 2 onward):
##   - Box / drag selection (left-click-drag → rectangle marquee → multi-select)
##   - Shift+click add-to-selection
##   - Ctrl+1-9 control groups
##   - Double-click select-all-of-type
##   - Attack-move (A + click) — Phase 2
##   - Hover info / cursor changes per context

# ============================================================================
# Configuration
# ============================================================================

## Maximum raycast distance from camera origin. 1000 world-units covers any
## sensible RTS click on a 256m map even from extreme zoom-out. Larger values
## are cheap; this is just the line length, not a per-distance cost.
const RAYCAST_DISTANCE: float = 1000.0

## Collision mask for the raycast. 0xFFFFFFFF = "all layers" — for MVP we hit
## every static body in the scene (terrain + unit collision shapes). Refining
## per-layer (e.g., one layer for selectables, another for terrain) is a
## post-Phase-2 optimization when the layer system actually matters.
const RAYCAST_COLLISION_MASK: int = 0xFFFFFFFF

## Verbose logging of every click and raycast result. Phase 1 wave 2
## diagnostic — left ON until interactive testing confirms the click flow
## is reliable on the live build, then can be flipped off (or gated by
## DebugOverlayManager) once the path is trusted.
const DEBUG_LOG_CLICKS: bool = true


# ============================================================================
# Lifecycle
# ============================================================================

## Disable the handler entirely. Tests flip this on so they can drive
## select / move flows directly through the SelectionManager + Unit APIs
## without a real Viewport / Camera3D / physics world.
var _test_mode: bool = false


func set_test_mode(on: bool) -> void:
	_test_mode = on


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _test_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	# Only react on press (not release). RTS convention is press-to-act so
	# rapid click flurries don't double-fire on the release edge.
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if DEBUG_LOG_CLICKS:
				print("[click] LEFT press at screen=", mb.position)
			_handle_left_click(mb.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if DEBUG_LOG_CLICKS:
				print("[click] RIGHT press at screen=", mb.position)
			_handle_right_click(mb.position)
			get_viewport().set_input_as_handled()


# ============================================================================
# Left click — selection
# ============================================================================

## Raycast the click position against the world. If we hit a Unit, select_only;
## if we hit terrain or nothing, deselect_all.
func _handle_left_click(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_left_click_hit(hit)


## Routing layer — public so tests can drive the select/deselect decision
## without a real Camera3D + physics world. Callers from production go through
## `_handle_left_click(screen_pos)`; tests inject a synthetic hit Dictionary
## (or an empty Dict for "missed").
##
## Hit-dictionary shape mirrors what PhysicsDirectSpaceState3D.intersect_ray
## returns: empty Dict on miss, otherwise has `collider`, `position`, `normal`,
## etc. We only consume `collider` for the unit lookup.
func process_left_click_hit(hit: Dictionary) -> void:
	if hit.is_empty():
		# No collider hit — clicked into the void / off the terrain. Deselect.
		if DEBUG_LOG_CLICKS:
			print("[click] LEFT: no raycast hit → deselect_all")
		SelectionManager.deselect_all()
		return
	var unit: Object = _resolve_unit_from_hit(hit)
	if unit != null and not _is_player_team(unit):
		# P1 (live playtest 2026-06-11): a DIRECT left-click on an enemy unit
		# must NOT enter selection. We null it out so the flow falls through to
		# the producer-ancestor / deselect branch below — selecting an enemy
		# would make it commandable (the live bug: the enemy then attacked the
		# player's own worker on the player's right-click). SelectionManager
		# also gates this, but resolving null here keeps the log + branch
		# semantics clean and consistent with the tolerance path.
		if DEBUG_LOG_CLICKS:
			print("[click] LEFT: enemy unit id=", unit.get(&"unit_id"),
				" team=", _read_team(unit), " — not selectable")
		unit = null
	if unit == null:
		# Tolerance fallback — terrain hit may still be NEAR a selectable unit.
		# Visible mesh > collision shape, so a click on a unit's silhouette can
		# fall through to terrain. SpatialIndex rescues those.
		#
		# P1 (live playtest 2026-06-11): the SELECTION tolerance must only
		# rescue player-team units. Without the team filter the fallback would
		# pick the nearest unit regardless of team — an enemy standing closer
		# than a friendly would resolve, SelectionManager would then reject it,
		# and the click would deselect instead of selecting the friendly the
		# player was aiming for. Filter the query to the player team.
		unit = _resolve_unit_from_tolerance(hit, GameState.player_team)
	if unit != null:
		if DEBUG_LOG_CLICKS:
			var uid_v: Variant = unit.get(&"unit_id")
			print("[click] LEFT: hit unit id=", uid_v, " collider=", hit.get(&"collider"))
		SelectionManager.select_only(unit)
	else:
		# Wave 3A.6 Track 2: hit was not a unit — but it MIGHT be an owned
		# producer building. Walk up from the collider looking for an
		# ancestor with non-empty `produces` (Track 1 contract surface).
		# If found AND team == player team, open ProductionPanel; else
		# fall through to deselect.
		var producer: Node3D = _find_owned_producer_ancestor(hit.get(&"collider"))
		if producer != null:
			if DEBUG_LOG_CLICKS:
				print("[click] LEFT: hit owned producer building kind=",
						producer.get(&"kind"), " → opening ProductionPanel")
			_open_production_panel(producer)
		else:
			# Hit something that wasn't a unit or producer (terrain, future
			# props, etc.) — deselect.
			if DEBUG_LOG_CLICKS:
				print("[click] LEFT: hit non-unit collider=", hit.get(&"collider"), " → deselect_all")
			SelectionManager.deselect_all()


# ============================================================================
# Right click — issue Move command
# ============================================================================

## Raycast the click position. If we hit terrain (not a unit), build a Move
## Command and replace_command on every selected unit. If no units are selected,
## or we hit a unit (Phase 2 will route this to attack-move), no-op.
func _handle_right_click(screen_pos: Vector2) -> void:
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		# Nothing selected — nothing to command.
		return
	var hit: Dictionary = _raycast_from_screen(screen_pos)
	process_right_click_hit(hit)


## Routing layer — public so tests can drive the move-command decision without
## a real Camera3D + physics world. Same shape as `process_left_click_hit`.
##
## If no units are selected, no-op (the caller's _handle_right_click also
## short-circuits, but this method is defensive so direct test calls behave
## the same way as the input-driven path).
##
## Dispatch table — precedence order (Phase 2 wave 2B + Phase 3 wave 1B +
## P1/P2/P3 hotfix, live playtest 2026-06-11):
##   0. hit empty / no selection → no-op.
##   1. ENEMY UNIT (opposing team) → Attack Command per selected unit. Payload
##      carries BOTH target_unit_id AND target_node (P2 — id-only collides with
##      the Building id-namespace; see below).
##   2. ENEMY BUILDING (opposing team, strictly excludes NEUTRAL) → Attack
##      Command per selected unit. Payload { target_unit_id, target_node }
##      (P3). Resolved via &"buildings" group membership on a collider ancestor.
##   3. GATHER — neutral mines / own-or-neutral gather-capable buildings
##      (Mazra'eh) → Gather Command per worker. Enemy Mazra'eh never reaches
##      here (caught at step 2 — it is an enemy building first, gather surface
##      second). Combat units in the selection are skipped (SC2 convention).
##   4. FRIENDLY UNIT (same team) → no-op (follow/guard/friendly-fire later).
##   5. GROUND → group-move dispatch via GroupMoveController.
##
## Why enemy-building precedes gather: a Mazra'eh DUCK-TYPES the gather surface
## (request_extract). Without the building-attack check first, an enemy Mazra'eh
## would route to gather (workers walking INTO enemy territory to farm it).
## Team-gating the building-attack check keeps OWN/NEUTRAL Mazra'eh as gather
## (current behavior, not regressed) while ENEMY Mazra'eh becomes attack.
func process_right_click_hit(hit: Dictionary) -> void:
	var sel: Array = SelectionManager.selected_units
	if sel.is_empty():
		# Nothing selected — nothing to command.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: no selection → no-op")
		return
	if hit.is_empty():
		# Right-clicked into the void / off the terrain — no actionable target.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: no raycast hit → no-op")
		return
	# Reference team is the player's team (SSOT — GameState.player_team). The
	# P1 selection gate guarantees the selection is player-team-only, so this
	# equals sel[0].team; reading the SSOT directly avoids a stale-selection
	# edge case and is the same source the simulation uses for "opposing".
	var sel_team: int = GameState.player_team
	# ---- Step 1: ENEMY UNIT attack (highest precedence) ----
	var hit_unit: Object = _resolve_unit_from_hit(hit)
	if hit_unit == null:
		# Tolerance fallback: a right-click slightly off-center on an enemy's
		# silhouette can hit terrain instead of the unit's collision pad. If a
		# selectable unit lives within Constants.CLICK_TOLERANCE_RADIUS of the
		# terrain hit, treat the click as if it had hit that unit. No team
		# filter (TEAM_ANY) — both enemy (→attack) and friendly (→no-op) must
		# resolve here; the team branch below decides the outcome.
		hit_unit = _resolve_unit_from_tolerance(hit)
	if hit_unit != null:
		var hit_team: int = _read_team(hit_unit)
		if hit_team != sel_team:
			# Enemy unit: dispatch Attack command per selected unit.
			var target_uid_v: Variant = hit_unit.get(&"unit_id")
			if target_uid_v == null or typeof(target_uid_v) != TYPE_INT:
				if DEBUG_LOG_CLICKS:
					print("[click] RIGHT: enemy hit but unit_id missing/typed wrong → no-op")
				return
			var target_uid: int = int(target_uid_v)
			if DEBUG_LOG_CLICKS:
				print("[click] RIGHT: attack command target_unit_id=",
					target_uid, " selected=", sel.size())
			# Per-unit dispatch: UnitState_Attacking handles target resolution
			# + range checks. Group formation engagement priority (split fire,
			# focus fire) is Phase 3+ — for now every selected friendly attacks
			# the same target.
			#
			# P2 (live playtest 2026-06-11): thread `target_node` alongside
			# `target_unit_id`. Units and Buildings share the global unit_id
			# counter, so an id-only payload let UnitState_Attacking resolve a
			# unit id to a same-id BUILDING (the live bug: {target_unit_id: 2}
			# meant Kargar 2 but resolved to the Turan Throne, building id 2).
			# Attacking prefers `target_node` when present
			# (unit_state_attacking.gd:138). Same payload shape D1 ships in
			# unit_state_attack_move.gd:359-362.
			for u in sel:
				if u != null and is_instance_valid(u):
					u.replace_command(
						Constants.COMMAND_ATTACK,
						{&"target_unit_id": target_uid, &"target_node": hit_unit},
					)
			return
		# Friendly unit: no-op. Follow / guard / friendly-fire are later phases.
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: hit friendly unit (same team=",
				sel_team, ") → no-op")
		return
	# ---- Step 2: ENEMY BUILDING attack (P3) ----
	# Resolve a Building under the click via &"buildings" group membership on a
	# collider ancestor (the canonical building-discovery seam — building.gd
	# joins the group at _ready; D1 stage-2 acquisition uses the same group).
	# Buildings expose team / unit_id / get_footprint_aabb by construction.
	var hit_building: Node = _resolve_building_from_hit(hit)
	if hit_building != null:
		var b_team: int = _read_team(hit_building)
		# Opposing-team-only, STRICTER than `!= sel_team`: TEAM_NEUTRAL is
		# excluded (matches D1's _find_engage_building rationale — never
		# auto-attack a neutral / unclaimed building; deliberate raids on
		# neutral buildings remain an explicit later-phase decision). An
		# under-construction ENEMY building IS attackable (its team is already
		# opposing — only NEUTRAL is the exclusion, and a placed enemy building
		# carries the enemy team from place_at).
		if b_team != sel_team and b_team != Constants.TEAM_NEUTRAL:
			var b_uid_v: Variant = hit_building.get(&"unit_id")
			if b_uid_v == null or typeof(b_uid_v) != TYPE_INT:
				if DEBUG_LOG_CLICKS:
					print("[click] RIGHT: enemy building but unit_id missing/typed wrong → no-op")
				return
			var b_uid: int = int(b_uid_v)
			var b_kind_v: Variant = hit_building.get(&"kind")
			var dispatched: int = 0
			# Mirror the enemy-UNIT branch exactly for mixed selections,
			# INCLUDING workers (kargar): the enemy-unit branch dispatches the
			# Attack command to EVERY selected unit with no worker exclusion, so
			# this branch does the same (do not invent new behavior). Workers
			# walking to attack a building is the existing enemy-unit behavior
			# carried forward; balance/UX of worker-attack is a later concern.
			for u in sel:
				if u != null and is_instance_valid(u):
					u.replace_command(
						Constants.COMMAND_ATTACK,
						{&"target_unit_id": b_uid, &"target_node": hit_building},
					)
					dispatched += 1
			if DEBUG_LOG_CLICKS:
				print("[click] RIGHT: attack building command target_unit_id=",
					b_uid, " kind=", b_kind_v, " dispatched=", dispatched)
			return
		# Own / neutral building: fall through. If it is a gather-capable
		# building (own Mazra'eh) the gather check below picks it up; otherwise
		# it falls to ground-move (right-click own Sarbaz-khaneh ≈ rally walk).
		if DEBUG_LOG_CLICKS:
			print("[click] RIGHT: building team=", b_team,
				" not opposing → fall through (gather/move)")
	# ---- Step 3: GATHER (neutral mines / own-or-neutral gather buildings) ----
	# If the hit is a ResourceNode (duck-typed via has_method(&"request_extract")
	# + is_gatherable), dispatch a gather command to every selected worker. An
	# ENEMY Mazra'eh never reaches here — it was caught by step 2 as an enemy
	# building. Own/neutral Mazra'eh + mines reach here unchanged (no regression).
	var hit_node: Node = _resolve_resource_node_from_hit(hit)
	if hit_node != null:
		_dispatch_gather_to_workers(sel, hit_node)
		return
	# ---- Step 4 (implicit): ground move ----
	var target: Vector3 = hit.get(&"position", Vector3.ZERO)
	if DEBUG_LOG_CLICKS:
		print("[click] RIGHT: move command target=", target, " selected=", sel.size())
	# Single and multi selections both route through the controller — its
	# size-1 identity path keeps single-click bitwise-identical, multi-unit
	# distributes on the GROUP_MOVE_OFFSET_RADIUS ring. The controller invokes
	# Unit.replace_command(&"move", {target}) per live unit (is_instance_valid
	# filtered).
	_GroupMove.dispatch_group_move(sel, target)


## Read the `team` field off a Unit-shaped Node, defaulting to TEAM_NEUTRAL
## when the field is missing. Same defensive pattern as _is_unit_shaped's
## duck-typing — avoids an `is Unit` check that would re-introduce the
## class_name registry race.
func _read_team(unit: Object) -> int:
	if unit == null:
		return Constants.TEAM_NEUTRAL
	if not (&"team" in unit):
		return Constants.TEAM_NEUTRAL
	return int(unit.get(&"team"))


## True iff `unit` belongs to the player's team. Units without a `team` field
## are treated as player-team (matches the team-less duck-typed fixture
## convention and SelectionManager._is_selectable_team's allow-on-absent rule).
## P1 (live playtest 2026-06-11).
func _is_player_team(unit: Object) -> bool:
	if unit == null:
		return false
	if not (&"team" in unit):
		return true
	return int(unit.get(&"team")) == GameState.player_team


# ============================================================================
# Raycasting
# ============================================================================

## Issue a physics raycast from the active Camera3D through the screen-space
## click position. Returns the hit Dictionary (collider, position, normal, ...)
## or an empty Dictionary if no hit / no camera available.
##
## Per Sim Contract §3.4: PhysicsServer queries from _input are safe between
## tick boundaries. The query is purely read-shaped; we never write to the
## physics world or the spatial index from this path.
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
	var world: World3D = get_world_3d_safe()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, RAYCAST_COLLISION_MASK)
	# Hit collision shapes only; no Area3Ds. Unit's CharacterBody3D + terrain
	# StaticBody3D are both bodies.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


## Resolve the Unit (or Unit subclass) that a raycast hit belongs to.
##
## Strategy: the hit `collider` is the StaticBody3D / CharacterBody3D the ray
## struck. Engine-architect's wave 1 confirmed that Unit extends CharacterBody3D
## directly, so when a ray hits a unit, `collider` IS the Unit instance. For
## defensive coverage (a future scene structure that nests collision under a
## child node), we walk up the parent chain looking for an ancestor that
## responds to the `replace_command` and `command_queue` methods/fields — the
## Unit-shaped duck-typing.
##
## Returns null if no Unit is found in the ancestor chain (e.g., the ray hit
## the terrain's StaticBody3D, which is not a Unit). Untyped Object return
## per the project class_name registry race convention.
func _resolve_unit_from_hit(hit: Dictionary) -> Object:
	var collider_v: Variant = hit.get(&"collider", null)
	if collider_v == null:
		return null
	var node: Node = collider_v
	while node != null:
		if _is_unit_shaped(node):
			return node
		node = node.get_parent()
	return null


## Tolerance fallback — when the raycast hit is terrain (no unit resolved),
## probe the SpatialIndex for selectable units within
## `Constants.CLICK_TOLERANCE_RADIUS` of the hit position on the XZ plane and
## return the closest one. Returns null if the hit dict has no `position`
## (defensive — shouldn't happen for a real raycast hit) or if no unit-shaped
## node lives within the tolerance ring.
##
## Why this exists: visible meshes are larger than collision pads (Piyade
## visual `0.5×0.7×0.5` vs collision `0.4×0.55×0.4`). A click on the rendered
## silhouette can miss the collision body and the raycast then strikes the
## ground beneath/beside it. Without this fallback, RTS players misread the
## game as broken — clicks they intended for the unit walked the selection
## past it (bug surfaced in Phase 2 session 1 live-test).
##
## SpatialIndex query returns SpatialAgentComponent nodes (their parent
## is the unit). We walk each parent through the same `_is_unit_shaped`
## duck-type as `_resolve_unit_from_hit` to keep the contract identical.
## XZ-projection is the contract per docs/SIMULATION_CONTRACT.md §3.1; Y is
## ignored when measuring distance from the hit point.
##
## `team_filter` (P1, live playtest 2026-06-11): when not Constants.TEAM_ANY,
## the SpatialIndex query is team-scoped via query_radius_team so only agents on
## that team are candidates. The LEFT-click selection path passes
## GameState.player_team (rescue only the player's own units — never resolve an
## enemy as a selection target). The RIGHT-click attack path passes TEAM_ANY so
## the existing enemy-attack / friendly-no-op tolerance resolution is preserved.
func _resolve_unit_from_tolerance(hit: Dictionary, team_filter: int = Constants.TEAM_ANY) -> Object:
	if not hit.has(&"position"):
		return null
	var hit_pos: Vector3 = hit.get(&"position", Vector3.ZERO)
	var nearby: Array = SpatialIndex.query_radius_team(
		hit_pos, Constants.CLICK_TOLERANCE_RADIUS, team_filter)
	if nearby.is_empty():
		return null
	var best: Node = null
	var best_d2: float = INF
	for agent in nearby:
		if not is_instance_valid(agent):
			continue
		var owner_node: Node = agent.get_parent()
		if owner_node == null:
			continue
		if not _is_unit_shaped(owner_node):
			continue
		# XZ-only squared distance — matches SpatialIndex's projection.
		var op: Vector3 = (owner_node as Node3D).global_position \
			if owner_node is Node3D else Vector3.ZERO
		var dx: float = op.x - hit_pos.x
		var dz: float = op.z - hit_pos.z
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			best = owner_node
	if best != null and DEBUG_LOG_CLICKS:
		var uid_v: Variant = best.get(&"unit_id")
		print("[click] tolerance fallback resolved unit id=", uid_v,
			" at d2=", best_d2, " from hit_pos=", hit_pos)
	return best


## Duck-type check: is `n` a Unit (or behaves like one)?
##
## We do not `is Unit` because the global class_name registry race makes typed
## checks brittle in autoload-and-test contexts (per docs/ARCHITECTURE.md §6
## v0.4.0). Instead we look for the Unit-defining surface: a `command_queue`
## field plus the `replace_command` method. Concrete Unit subclasses (Kargar,
## etc., gameplay-systems wave 2) inherit both, so the check carries forward.
func _is_unit_shaped(n: Node) -> bool:
	if n == null:
		return false
	if not n.has_method(&"replace_command"):
		return false
	if not (&"command_queue" in n):
		return false
	return true


# ============================================================================
# Right click — gather routing (Phase 3 wave 1B)
# ============================================================================

## Resolve a ResourceNode (MineNode, future Mazra'eh) from a raycast hit.
##
## Strategy: walk up the parent chain looking for an ancestor that responds
## to `request_extract`. ResourceNode subclasses ship this method as part of
## the consumer API (docs/RESOURCE_NODE_CONTRACT.md §4). The duck-type check
## avoids hard class_name dependencies (same registry-race rationale as
## _resolve_unit_from_hit).
##
## Returns null if the hit was terrain / a unit / any non-ResourceNode.
func _resolve_resource_node_from_hit(hit: Dictionary) -> Node:
	var collider_v: Variant = hit.get(&"collider", null)
	if collider_v == null:
		return null
	var node: Node = collider_v
	while node != null:
		if _is_resource_node_shaped(node):
			return node
		node = node.get_parent()
	return null


## Resolve a Building from a raycast hit (P3, live playtest 2026-06-11).
##
## Canonical building-discovery seam: walk up the collider ancestor chain
## looking for the first node in the &"buildings" SceneTree group. Every
## Building joins that group at _ready (building.gd:358) — it is the SSOT
## "I am a building, not a unit" marker (ARCHITECTURE.md §6 v0.20.4) and the
## same seam D1 stage-2 acquisition (_find_engage_building) uses. Members are
## Building base by construction, so they expose team / unit_id /
## get_footprint_aabb. The building's clickable surface is its StaticBody3D
## child (per the BUG-07 lesson), so the raycast hits the StaticBody3D and we
## walk up to the Building root.
##
## Returns null if no &"buildings"-group ancestor exists in the chain (terrain,
## units, resource props, etc.).
func _resolve_building_from_hit(hit: Dictionary) -> Node:
	var collider_v: Variant = hit.get(&"collider", null)
	if collider_v == null:
		return null
	if not (collider_v is Node):
		return null
	var node: Node = collider_v as Node
	while node != null:
		if node.is_in_group(&"buildings"):
			return node
		node = node.get_parent()
	return null


## Duck-type check: is `n` a ResourceNode (or behaves like one)?
##
## We do not `is ResourceNode` because the class_name registry race makes
## typed checks brittle in autoload-and-test contexts (per docs/ARCHITECTURE.md
## §6 v0.4.0). Instead we look for the ResourceNode-defining surface:
## `request_extract` + `is_gatherable` field. Both ship on the base class.
func _is_resource_node_shaped(n: Node) -> bool:
	if n == null:
		return false
	if not n.has_method(&"request_extract"):
		return false
	if not (&"is_gatherable" in n):
		return false
	return true


## Dispatch a gather command to every worker in `sel` targeting `target_node`.
## Non-worker units in the selection are skipped — see process_right_click_hit
## dispatch table for rationale.
func _dispatch_gather_to_workers(sel: Array, target_node: Node) -> void:
	var workers_dispatched: int = 0
	for u in sel:
		if u == null or not is_instance_valid(u):
			continue
		if not _is_worker_shaped(u):
			continue
		u.replace_command(
			Constants.COMMAND_GATHER,
			{&"target_node": target_node},
		)
		workers_dispatched += 1
	if DEBUG_LOG_CLICKS:
		print("[click] RIGHT: gather command target=",
			(target_node as Node3D).global_position if target_node is Node3D else "?",
			" workers_dispatched=", workers_dispatched,
			" of selected=", sel.size())


## Worker duck-type: a Unit whose `unit_type` reads as &"kargar". Phase 3
## only Kargar workers exist; when other gather-capable units ship (Phase 4+),
## extend this to check a `can_gather` capability field instead of a hard
## unit_type comparison.
func _is_worker_shaped(n: Object) -> bool:
	if n == null:
		return false
	var ut: Variant = n.get(&"unit_type")
	if typeof(ut) != TYPE_STRING_NAME:
		return false
	return ut == &"kargar"


# ============================================================================
# World access
# ============================================================================

## get_world_3d() exists on Node3D but our handler is a plain Node. Resolve
## via the viewport, which always has a World3D in a 3D scene.
func get_world_3d_safe() -> World3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	# In Godot 4, `Viewport.get_world_3d()` returns the scene's World3D.
	return viewport.find_world_3d()


# ============================================================================
# Wave 3A.6 Track 2 — owned-producer-building click → ProductionPanel
# ============================================================================
#
# When a left-click hits a non-unit collider, the click MIGHT be on a
# building owned by the player. If that building has a non-empty `produces`
# field (Track 1 contract surface — Sarbaz-khaneh / Sowari-khaneh /
# Tirandazi at MVP), we open the ProductionPanel for it instead of
# deselect-all'ing.
#
# Why walk-up-from-collider: the building's clickable surface is its
# StaticBody3D child (set up in building.tscn per BUG-07 lesson). The
# raycast hits the StaticBody3D, NOT the Building Node3D root. We walk
# upward from the collider looking for the first ancestor that has the
# `produces` schema field — that's the Building root.
#
# Why team check: clicking an enemy building should NOT open OUR
# production panel. Future Phase 4+ may show an "info panel" for enemy
# buildings; for MVP, enemy-building click falls through to deselect.

## Walk up from `collider` (a Node, typically a StaticBody3D) looking for
## an ancestor with a non-empty `produces` field AND team == player team
## (Constants.TEAM_IRAN at MVP). Returns the Building root Node3D, or null.
##
## Defensive: returns null on any of:
##   - collider is null or freed
##   - no ancestor has a `produces` field
##   - the ancestor's `produces` is empty (non-producer building)
##   - the ancestor's team != TEAM_IRAN (enemy building)
##   - the building isn't yet `is_complete = true` (still under
##     construction — opening the panel would show a 0% progress bar
##     for the placement state and confuse the player)
func _find_owned_producer_ancestor(collider: Variant) -> Node3D:
	if collider == null:
		return null
	if not (collider is Node):
		return null
	var node: Node = collider as Node
	while node != null:
		if (&"produces" in node) and (&"team" in node):
			# Candidate. Check the gates.
			var produces_v: Variant = node.get(&"produces")
			if typeof(produces_v) == TYPE_ARRAY and not (produces_v as Array).is_empty():
				var team_v: Variant = node.get(&"team")
				if typeof(team_v) == TYPE_INT and int(team_v) == Constants.TEAM_IRAN:
					# Optional: is_complete gate. A still-being-built
					# producer shouldn't open the panel — the player
					# can't train from it yet. is_complete may be
					# absent on duck-typed test fixtures; treat
					# absent as "complete" defensively.
					var is_complete_v: Variant = node.get(&"is_complete")
					var is_complete: bool = true
					if typeof(is_complete_v) == TYPE_BOOL:
						is_complete = bool(is_complete_v)
					if is_complete and node is Node3D:
						return node as Node3D
		node = node.get_parent()
	return null


## Locate the ProductionPanel CanvasLayer node in the scene and open() it
## for the given building. The panel lives at the same scene-layer as
## the other HUD CanvasLayers (BuildMenu, ResourceHUD, etc.) —
## main.tscn instances it once at boot.
##
## Path-resolve via group lookup rather than hardcoded scene path —
## tolerant of main.tscn reorgs.
func _open_production_panel(building: Node3D) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# ProductionPanel adds itself to the &"production_panel" group on
	# _ready (defensive single-instance discovery — same pattern as
	# build_menu's _is_kargar_shaped resolution).
	var panels: Array = tree.get_nodes_in_group(&"production_panel")
	if panels.is_empty():
		# Panel not yet in scene (boot-order race or test environment
		# without ProductionPanel instanced). Defensive: log + fall
		# through. The user still sees the building, but no panel
		# opens; lead's live-test will notice + flag.
		if DEBUG_LOG_CLICKS:
			print("[click] LEFT: no ProductionPanel in scene; producer click ignored")
		return
	var panel: Node = panels[0]
	# §9.M7 L7 cleanup: former `if not panel.has_method(&"open"): return`
	# silently swallowed contract drift. open() is contract-promised on
	# &"production_panel" group members (production_panel.gd curates the
	# group in _ready); hard-assert so drift fails loudly at this line.
	assert(panel.has_method(&"open"),
		"&\"production_panel\" group member missing open() — see production_panel.gd")
	panel.call(&"open", building)
