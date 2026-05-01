extends Node
##
## PathSchedulerService — autoload that holds the active IPathScheduler.
##
## Per docs/SIMULATION_CONTRACT.md §4.3: MovementComponent reads its scheduler
## from this service by default. Tests inject MockPathScheduler by overriding
## the `scheduler` property directly on the unit's component (per the
## contract example), or by calling `set_scheduler(...)` on this service to
## swap globally.
##
## Phase 1 wires the production NavigationAgentPathScheduler as the default
## (this autoload's _ready instantiates it). Tests inject MockPathScheduler
## by writing `set_scheduler(mock)` in their fixture; `reset()` reverts to
## the production default so test isolation doesn't bleed into later runs.
##
## Why an autoload, not a Resource: the scheduler holds in-flight request
## tables and a callback into NavigationServer3D — runtime state. Resources
## are static data; we'd be fighting the type. Autoload + injectable ref is
## the simplest shape that supports both production and mock.

# Path-string load of the production scheduler — same registry-race-avoidance
# pattern used elsewhere in the project (docs/ARCHITECTURE.md §6 v0.4.0).
const _NavigationAgentPathScheduler: Script = preload(
	"res://scripts/navigation/navigation_agent_path_scheduler.gd"
)

# The active scheduler. Defaults to the production NavigationAgent-backed
# implementation set in _ready. Untyped Variant to avoid a hard dependency
# on the IPathScheduler class_name at autoload-parse time.
# Consumers should treat this as `IPathScheduler | null`.
var scheduler: Variant = null


func _ready() -> void:
	# Wire the production scheduler as the default. Tests override via
	# set_scheduler() in before_each; reset() reverts to a fresh production
	# instance so cross-test bleed-through is impossible.
	scheduler = _NavigationAgentPathScheduler.new()


## Inject a scheduler. Idempotent — passing the same scheduler twice is a no-op.
## Pass `null` to clear (rare; prefer reset() to revert to the production
## default after a test).
func set_scheduler(s: Variant) -> void:
	scheduler = s


## Diagnostic: true if a scheduler is currently injected.
func has_scheduler() -> bool:
	return scheduler != null


## Test/lifecycle helper. Resets to a fresh production scheduler instance.
## Mirrors the reset() pattern on SimClock / GameState / SpatialIndex.
##
## NOTE: Phase 0's reset() set scheduler = null. Phase 1 changes the contract
## to "reset reverts to the production default" — tests that wanted the null
## state for negative-path coverage now write `set_scheduler(null)` directly.
## Logged in docs/ARCHITECTURE.md §6.
func reset() -> void:
	scheduler = _NavigationAgentPathScheduler.new()
