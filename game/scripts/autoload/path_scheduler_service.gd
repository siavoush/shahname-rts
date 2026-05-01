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
## Phase 0 ships the service with `scheduler = null`. Session 4 wires the
## production NavigationAgentPathScheduler (engine-architect) and the test
## MockPathScheduler (qa-engineer). Until then any consumer that requests a
## scheduler from this service must handle the null case.
##
## Why an autoload, not a Resource: the scheduler holds in-flight request
## tables and a callback into NavigationServer3D — runtime state. Resources
## are static data; we'd be fighting the type. Autoload + injectable ref is
## the simplest shape that supports both production and mock.

# The active scheduler. null sentinel until a real implementation is wired.
# Untyped Variant to avoid a hard dependency on the IPathScheduler class_name
# at autoload-parse time (same constraint as SpatialIndex/SpatialAgentComponent).
# Consumers should treat this as `IPathScheduler | null`.
var scheduler: Variant = null


## Inject a scheduler. Idempotent — passing the same scheduler twice is a no-op.
## Pass `null` to clear (used by tests in after_each).
func set_scheduler(s: Variant) -> void:
	scheduler = s


## Diagnostic: true if a scheduler is currently injected.
func has_scheduler() -> bool:
	return scheduler != null


## Test/lifecycle helper. Mirrors the reset() pattern on SimClock /
## GameState / SpatialIndex.
func reset() -> void:
	scheduler = null
