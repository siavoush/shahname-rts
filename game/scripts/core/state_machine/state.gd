extends RefCounted
##
## NOTE: class_name intentionally omitted. The Sim Contract describes this
## type as `class_name State`, but Godot 4.6's class_name resolver has a
## known race when this script is referenced from inner classes that extend
## it by path-string (notably GUT-collected test scripts). Removing the
## global registration eliminates the resolution race entirely while
## preserving the behavior. Callers reference the script by path or via
## `preload(...)`. State Machine Contract is consulted by behavior, not
## by class_name presence.
##
## State — base class for any FSM state (unit, AI controller).
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.2.
##
## Subclass conventions:
##   - id is a lowercase StringName matching the class noun (&"idle",
##     &"moving", &"attacking", &"gathering", &"constructing", &"casting",
##     &"dying"). Used as the dictionary key in StateMachine._states and as
##     the telemetry id.
##   - State-internal fields (cooldown ticks, progress counters, cached
##     target refs) live directly on the State and are mutated by the state's
##     own _sim_tick only. They do NOT need _set_sim — see Contract §5.2 for
##     the rationale (the on-tick invariant is preserved by construction
##     here, not by assertion, because States are RefCounted and have no
##     external write path).
##   - Gameplay state that *outlives* a single state instance — HP, position,
##     Farr — never lives on a State at all. It lives on the unit's
##     components (HealthComponent, Node3D.global_position, etc.), which are
##     real SimNodes and use _set_sim per Sync 1.
##
## Lifecycle hooks (all run inside the owning unit's _sim_tick):
##   - enter(prev, ctx)         — set up state-local timers, kick off side
##                                 effects (e.g., issue request_move),
##                                 cache target references.
##   - _sim_tick(dt, ctx)       — per-tick logic; may call ctx.fsm.transition_to
##                                 or ctx.fsm.transition_to_next when the
##                                 state's work is done.
##   - exit()                   — cleanup; cancel in-flight requests, clear
##                                 caches. Must NOT decide what runs next.
##
## Concrete unit states (Idle, Moving, Attacking, Gathering, ...) ship in
## Phase 1+. This base class plus UnitState ship Phase 0.

# Subclass overrides — assigned in subclass _init or via constructor.
# Note: not `const` because RefCounted const fields aren't easily overrideable
# from a subclass init. We document that they should be set once and never
# mutated thereafter.
#
# `interrupt_level` defaults to 0 (= InterruptLevel.NONE). We don't import
# InterruptLevel here because that would create a class_name dependency from
# this script (which is itself referenced by inner test classes via
# extends-by-path). Subclasses set the value via the InterruptLevel enum
# directly: `interrupt_level = InterruptLevel.NEVER`.
var id: StringName = &""
var priority: int = 0
var interrupt_level: int = 0   # InterruptLevel.NONE


## Called when this state becomes current. `prev` is the previous state (may
## be null on initial init); `ctx` is the StateMachine's owning context (a
## Unit, AI controller, etc.). Override in subclass.
##
## `_prev` is typed loosely as Object instead of self-class-name `State` to
## avoid a class_name self-reference resolution race that bites GUT when it
## collects subclasses defined inline in test scripts (the inner subclass
## extends this script by path-string, and parsing the inherited method
## body fails if the global class_name registry isn't yet populated).
## Subclasses can still type-narrow their override parameter to `State` if
## they want — Godot considers Object-narrower-to-State a valid override.
func enter(_prev: Object, _ctx: Object) -> void:
	pass


## Per-tick logic. Override in subclass. Only place a state may request a
## transition. ctx is passed for convenience — callers may also reach
## ctx.fsm directly.
func _sim_tick(_dt: float, _ctx: Object) -> void:
	pass


## Called when this state is being replaced. Cleanup only — must not decide
## what runs next (that's the StateMachine's job per Contract §3.4).
func exit() -> void:
	pass
