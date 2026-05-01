extends "res://scripts/core/sim_node.gd"
##
## SelectableComponent — per-unit selection state and visual indicator.
##
## Per docs/STATE_MACHINE_CONTRACT.md context (selectability is a UI concern,
## not a sim concern; the simulation neither produces nor consumes
## EventBus.selection_changed).
##
## Behavior:
##   - is_selected reflects whether this unit is in the SelectionManager's
##     current selection set.
##   - Subscribes to EventBus.selection_changed; when the broadcast list
##     contains this component's unit_id, becomes selected; otherwise
##     deselected.
##   - The visual indicator (a placeholder selection ring) is a sibling
##     MeshInstance3D the parent unit scene exposes via the @export
##     `_ring_path` NodePath. We toggle its `visible` property.
##
## Visibility carve-out (off-tick safe):
##   selection_changed is a UI-side, read-shaped EventBus signal (its
##   producer is the SelectionManager autoload listening to mouse clicks
##   in _input). Toggling a MeshInstance3D's visibility is a render-only
##   side effect, not a sim-state mutation; per Sim Contract §1.5 the rule
##   that bites here is "UI never reaches into sim state during a sink
##   callback, and never starts a Tween or AnimationPlayer in the
##   callback's synchronous body." We don't start Tweens; visibility is a
##   single property write, idempotent, and read by the renderer next
##   frame. Per the L2 lint allowlist (tools/lint_simulation.sh),
##   selection_changed is exempt from the no-emit-from-_process rule for
##   the same reason.
##
## Why extend SimNode (via path-string preload, not class_name)?
## Same project-wide pattern: avoid the class_name registry race.
## class_name retained on the component so the unit script can declare a
## typed @onready var selectable: SelectableComponent.
##
## Selection ring placeholder graphics: per CLAUDE.md, all visuals are
## placeholder shapes until the design chat green-lights real art. The
## ring is a flat CylinderMesh ("disk") in Iran's faction palette (gold).
## Created lazily in _ready if no ring path was set, so a freshly-spawned
## unit always has a visible selection cue without scene authoring overhead.
class_name SelectableComponent

# Reference to the unit's id, set by the parent Unit on _ready.
@export var unit_id: int = -1

# Optional: the path to a child node (typically a MeshInstance3D) that
# represents the selection ring. If empty, _ready creates a default
# placeholder ring as a sibling node.
@export var ring_path: NodePath

# Cached ring node ref (resolved at _ready). Toggled by select/deselect.
var _ring: Node3D = null

# Backing storage for is_selected. We expose a property with explicit
# setter/getter so writes from outside (e.g., legacy paths or the
# SelectionManager calling .select() directly) trigger ring visibility
# updates.
var is_selected: bool = false


# === Lifecycle ==============================================================

func _ready() -> void:
	# Resolve or create the selection ring.
	if not ring_path.is_empty():
		var n: Node = get_node_or_null(ring_path)
		if n is Node3D:
			_ring = n as Node3D
	if _ring == null:
		_ring = _make_default_ring()
		# Add as a sibling under the parent unit so its position follows
		# the unit's transform automatically. We call_deferred to avoid
		# the "parent is busy setting up children" error when this
		# component's _ready fires from within the parent Unit's own
		# _ready chain (Godot forbids tree mutation while a parent is
		# still adding its initial children).
		var p: Node = get_parent()
		if p != null:
			p.add_child.call_deferred(_ring)
			# Set ring's initial properties before it joins the tree so
			# they're correct on first frame.
			_ring.visible = is_selected
	else:
		# A user-supplied ring path resolved cleanly — set visibility now.
		_ring.visible = is_selected
	# Subscribe to the selection broadcast.
	EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


# === Public API =============================================================

## Mark this component as selected. Updates the ring visibility.
##
## Off-tick safe — selection is a UI concern, not a sim mutation. Routes
## through `_apply_selection` which writes the field directly (no _set_sim);
## the SimNode discipline doesn't apply because is_selected is not
## simulation state. Combat, AI, Farr, etc. never read this field.
func select() -> void:
	_apply_selection(true)


## Mark this component as deselected. Updates the ring visibility.
func deselect() -> void:
	_apply_selection(false)


# === Internal ===============================================================

func _apply_selection(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	if _ring != null:
		_ring.visible = selected


# Listen to the broadcast: if our unit_id appears in the list, select; else
# deselect. Untyped Array param since signal payload is declared as plain
# Array (signal accepts Array[int] but the payload is a generic Array at
# the receiver to keep wiring simple).
func _on_selection_changed(selected_unit_ids: Array) -> void:
	# Ints in / ints out — accept either Array[int] or generic Array of ints.
	var found: bool = false
	for id in selected_unit_ids:
		if int(id) == unit_id:
			found = true
			break
	_apply_selection(found)


# Build the placeholder selection ring. A thin gold disk on the ground.
# Sized roughly to a worker silhouette; concrete units may override via
# the ring_path export when they want a different size.
func _make_default_ring() -> MeshInstance3D:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "SelectionRing"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.height = 0.05
	mesh.radial_segments = 24
	ring.mesh = mesh
	# Iran's faction palette per CLAUDE.md visuals doc — gold/yellow.
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	mat.flags_transparent = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	# Sit just above the ground plane so it's visible; the disk's center
	# of geometry is at the parent's local origin, +Y nudge keeps it from
	# z-fighting with terrain.
	ring.position = Vector3(0.0, 0.025, 0.0)
	# Hidden by default; select() flips it on.
	ring.visible = false
	return ring
