class_name Command extends RefCounted
##
## Command — a player- or AI-issued action to be consumed by a unit's state
## machine.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.4.
##
## Pooled. Never call `Command.new()` directly outside of CommandPool — the
## pool rents and returns instances to avoid per-tick allocation churn.
## CommandQueue.push expects rented Commands; CommandQueue.pop / clear return
## them to the pool.

# StringName key — Constants.COMMAND_MOVE, COMMAND_ATTACK, etc.
var kind: StringName = &""

# Kind-specific payload. Examples:
#   move      → { target: Vector3 }
#   attack    → { target_unit: Node }
#   gather    → { node: Vector3 }  (the resource node position)
#   build     → { kind: StringName, pos: Vector3 }
#   ability   → { name: StringName, target: Vector3 | Node | null }
var payload: Dictionary = {}


## Reset to a fresh state. Called by CommandPool on rent and return so
## consumers always see a clean Command. Self-only mutation.
func reset() -> void:
	kind = &""
	payload = {}
