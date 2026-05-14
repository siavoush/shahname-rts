extends Node3D
##
## GhostPlacementPreview — translucent cursor-following preview shown while
## the player is in building-placement mode.
##
## Phase 3 session 1 wave 1C deliverable 6. Per
## 02f_PHASE_3_KICKOFF.md §3 wave 1C:
##   "Ghost preview: a translucent green/red version of the Khaneh mesh
##    that follows the cursor. Green when terrain valid (on navmesh,
##    away from existing buildings); red when invalid (overlaps)."
##
## What it IS:
##   - A Node3D with a MeshInstance3D placeholder (Khaneh-shaped box).
##   - A material with alpha < 1 so the world reads through.
##   - The `set_validity(bool)` API for the BuildPlacementHandler to
##     flip the color (green = valid, red = invalid).
##
## What it deliberately is NOT:
##   - Has NO collision shape / StaticBody3D. The ghost must NOT be a
##     click-target — the placement raycast goes to the terrain
##     underneath. BUG-07 lesson INVERTED here: ghost = no collision,
##     placed Khaneh = collision (from the base Building scene).
##   - Has NO NavigationObstacle3D. The ghost is a visual hint only;
##     a real navmesh carve happens when the actual building is placed.
##   - NOT in the &"buildings" group. The validity-check overlap test
##     iterates that group; if the ghost were in it, it'd report
##     "overlapping itself" and read as invalid everywhere.
##   - NOT a class_name'd type — single-purpose scene, no consumers
##     need to type-check against it.
##
## Visibility cues:
##   - Mesh: same BoxMesh size as Khaneh (2.0 × 1.2 × 2.0) so the
##     preview's footprint matches what will be placed.
##   - Color: green `Color(0.4, 0.85, 0.4, 0.45)` when valid; red
##     `Color(0.85, 0.3, 0.3, 0.45)` when invalid. Saturated enough to
##     read clearly against sandy terrain (FarrGauge / Iran-coin-gold
##     contrast lesson applied — lead may retune in live test).
##   - Y-offset: same 0.6 as building.tscn so the ghost's base sits on
##     the terrain plane, matching where the real building will land.
##
## Source: 01_CORE_MECHANICS.md §5 (building placement UX implicitly
## requires a preview); 02f_PHASE_3_KICKOFF.md §3 wave 1C (explicit
## green/red ghost spec).

# Green when the placement position is valid (on terrain, no overlap).
const _COLOR_VALID: Color = Color(0.4, 0.85, 0.4, 0.45)

# Red when invalid (off-terrain, overlapping another building).
const _COLOR_INVALID: Color = Color(0.85, 0.3, 0.3, 0.45)


@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	# Start invalid by default — the placement handler will call
	# set_validity(true) on the first valid cursor position. This way
	# a ghost spawned at the world origin reads as "not a valid
	# place to put this" until the cursor moves to terrain.
	set_validity(false)


# Public API called by BuildPlacementHandler each time the cursor
# moves over the terrain. Flips the mesh's material color.
##
## Test-friendly: tests inspect the resulting material's albedo to
## confirm the color flipped.
func set_validity(is_valid: bool) -> void:
	if _mesh == null:
		return
	var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if mat == null:
		# Fallback — create a fresh material if the scene didn't provide
		# one. Defensive against scene-file drift.
		mat = StandardMaterial3D.new()
		_mesh.material_override = mat
	mat.albedo_color = _COLOR_VALID if is_valid else _COLOR_INVALID
	# Transparency mode is set on the .tscn material; we don't toggle
	# it here. Re-setting albedo_color preserves the alpha.
