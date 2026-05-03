extends RefCounted
##
## GroupMoveController — formation-distribution dispatcher for multi-unit moves.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.5 (replace_command is the only
## sanctioned write path) and Phase 1 session 2 kickoff §2 deliverable 4.
##
## Why it exists:
##   When the player right-clicks a target with N units selected, naïvely
##   issuing the same target to every unit causes them to path to one nav-
##   point and pile/shove. Ring-distribution gives each unit a slightly
##   different target around the click so the formation arrives spread out.
##
## Algorithm (Phase 1 — simplest thing that works):
##   - 1 unit  → identity. Target unchanged. Behavior matches single-click move.
##   - 2..7 units → unit 0 at center, then up to 6 slots on a ring of radius R
##                  at angles 0°, 60°, 120°, 180°, 240°, 300° (cos/sin).
##   - 8+ units → fall back to a second ring at 2R with 30° spacing (12 slots),
##                then a third ring at 3R if the group is huge. Phase 1's
##                workforce caps at 5; the larger-N path exists for safety.
##
##   Determinism: angles are pure trig over the unit's index; no RNG. Same
##   input Array + same target ⇒ bitwise-identical offsets across runs.
##
## Snapping survival: R = Constants.GROUP_MOVE_OFFSET_RADIUS = 2.0 world units,
##   8× the navmesh cell_size (0.25 baked in terrain.tscn). Adjacent slots are
##   ~2 world units apart on the ring (chord = 2R sin(30°) = R = 2.0), well
##   above the snap-to-poly resolution — multiple units in the same selection
##   do not collapse onto a single nav-point under NavigationServer3D.
##
## Out of scope (Phase 1 session 2):
##   - Facing / rotation. Phase 2.
##   - Formation type (line, wedge, column). Phase 2.
##   - Reservation-based pathing (units claim their slot). Phase 3+ when the
##     spatial reservation system arrives with buildings.
##   - Off-navmesh target validation. Each unit's request_repath returns
##     FAILED on its own; that's the unit's UnitState_Moving problem (already
##     handled per docs/STATE_MACHINE_CONTRACT.md and the Moving state's
##     FAILED-path branch).
##
## No class_name: same reason as MatchHarness — RefCounted scripts loaded by
## GUT collectors race against the global class_name registry. Callers
## preload the script and call statics directly:
##   const _GMC := preload("res://scripts/movement/group_move_controller.gd")
##   _GMC.dispatch_group_move(units, target)


# Slots per ring. Inner ring has 6 (60° spacing); outer rings double.
# Unit 0 sits at center, then ring 1 fills (1..6), then ring 2 (7..18), etc.
const _RING_SLOTS_INNER: int = 6
const _CENTER_SLOTS: int = 1


## Dispatch a Move command to each unit in `units`, distributing the targets
## around `target` in a deterministic ring pattern so units don't pile.
##
## Per the kickoff contract (§2 deliverable 4):
##   - Empty Array        → no-op (no error, no warning).
##   - Single unit        → target verbatim (identity; matches single-click).
##   - Freed units        → silently skipped via is_instance_valid.
##   - N≥2 live units     → each gets a distinct offset within the ring radius,
##                          dispatched via Unit.replace_command(&"move", ...).
##
## The unit's command_queue is replaced (right-click semantics, not Shift-
## queue). For Shift-queue formation moves, append_command is the matching
## primitive — not exposed here pending the wave-2 wiring decision.
##
## Y-axis pass-through: offsets live on the XZ plane (matches SpatialIndex's
## flat-grid projection rule); each dispatched target keeps the click's Y
## verbatim so any future height-aware navmesh isn't broken by us.
static func dispatch_group_move(units: Array, target: Vector3) -> void:
	if units.is_empty():
		return

	# Filter once. Holding the live list lets us address by index when
	# computing the offset, and skips invalid entries without renumbering
	# the slots for the ones that follow (the array order is the slot order,
	# so a freed unit just leaves a slot unused — this keeps the dispatch
	# deterministic against a stable input ordering).
	var live: Array = []
	for u in units:
		if u != null and is_instance_valid(u):
			live.append(u)

	if live.is_empty():
		return

	# Single-unit fast path: identity. No ring math, no float drift.
	if live.size() == 1:
		live[0].replace_command(
			Constants.COMMAND_MOVE,
			{&"target": target},
		)
		return

	# Multi-unit ring distribution.
	for i in range(live.size()):
		var offset: Vector3 = _slot_offset(i)
		var slot_target: Vector3 = Vector3(
			target.x + offset.x,
			target.y,
			target.z + offset.z,
		)
		live[i].replace_command(
			Constants.COMMAND_MOVE,
			{&"target": slot_target},
		)


# Compute the XZ-plane offset for a given slot index. Center is index 0;
# ring 1 holds indices 1..6; ring 2 holds indices 7..18; etc.
#
# Pure function over the index — no RNG, no time, no scene state. Same index
# ⇒ same offset across runs and machines.
static func _slot_offset(index: int) -> Vector3:
	if index < _CENTER_SLOTS:
		return Vector3.ZERO

	var radius: float = Constants.GROUP_MOVE_OFFSET_RADIUS

	# Find which ring this index belongs to and its position within that ring.
	# Ring 1 has 6 slots (indices 1..6), ring 2 has 12 (7..18), ring 3 has 18
	# (19..36), etc. — 6 × ring_number slots per ring.
	var ring: int = 1
	var slot_index_in_ring: int = index - _CENTER_SLOTS
	var slots_in_ring: int = _RING_SLOTS_INNER * ring
	while slot_index_in_ring >= slots_in_ring:
		slot_index_in_ring -= slots_in_ring
		ring += 1
		slots_in_ring = _RING_SLOTS_INNER * ring

	var ring_radius: float = radius * float(ring)
	var angle_step: float = TAU / float(slots_in_ring)
	var angle: float = float(slot_index_in_ring) * angle_step
	return Vector3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius)
