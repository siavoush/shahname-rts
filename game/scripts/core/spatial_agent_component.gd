class_name SpatialAgentComponent extends SimNode
##
## SpatialAgentComponent — opt-in marker for SpatialIndex participation.
##
## Per docs/SIMULATION_CONTRACT.md §3.2: any node with a SpatialAgentComponent
## child auto-registers with SpatialIndex on _ready and deregisters on
## tree_exiting. The component carries the team filter and an agent_radius
## hint (used by query callers; the index itself is point-based).
##
## Why a SimNode and not just a Node: this is gameplay-relevant state. If a
## consumer ever mutates `team` mid-match (e.g., a "convert" mechanic), it
## must do so on-tick — the _set_sim assert is the tripwire.
##
## Y axis is ignored by SpatialIndex (flat XZ grid); the component reads
## get_parent().global_position.x and .z only. The parent must therefore be
## a Node3D — see _ready() for the runtime check.
##
## Phase 0 ships the component with no concrete consumers. Phase 1 attaches
## one to every Unit and Building scene template.

# Team this agent belongs to. Constants.TEAM_NEUTRAL / TEAM_IRAN / TEAM_TURAN.
@export var team: int = Constants.TEAM_NEUTRAL

# Agent radius — informational. SpatialIndex queries are point-vs-radius from
# the query caller's side; this field is what the *agent* claims as its size,
# used by selection raycasts and AoE callers that want to expand the query.
@export var agent_radius: float = 1.0


# Returns the agent's owning Node3D position. Y is ignored by the index, but
# kept here so callers don't have to know the projection rule.
func world_position() -> Vector3:
	var parent: Node = get_parent()
	if parent == null:
		return Vector3.ZERO
	if parent is Node3D:
		return (parent as Node3D).global_position
	return Vector3.ZERO


func _ready() -> void:
	# Defensive: if attached to a non-Node3D the agent is silently broken
	# (world_position would always return zero). Catch this at boot.
	var parent: Node = get_parent()
	assert(parent is Node3D,
		"SpatialAgentComponent must be a child of a Node3D — got %s" %
		(parent.get_class() if parent != null else "<null>"))
	# Auto-register with the index. SpatialIndex.register is idempotent and
	# safe to call before any other agents exist.
	SpatialIndex.register(self)


func _exit_tree() -> void:
	# Deregister on tree_exiting (queue_free, manual remove, scene change).
	# SpatialIndex.unregister is idempotent.
	SpatialIndex.unregister(self)
