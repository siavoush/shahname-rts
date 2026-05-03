class_name UnitState_Dying extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Dying — terminal state. Entered exclusively via the death-preempt
## path (StateMachine._on_unit_health_zero forces a transition to &"dying"
## regardless of interrupt_level when EventBus.unit_health_zero fires for
## this unit's id).
##
## Per docs/STATE_MACHINE_CONTRACT.md §3.5 + §4: dying is the highest-
## priority terminal state and cannot be interrupted by anything. Once
## entered, the unit is on the way out — no recovery, no retreat, no
## resurrection (Yadgar respawn for Rostam is a Phase 3+ feature and
## happens via a fresh unit spawn, not via state machine).
##
## Phase 2 session 1 wave-3 fix (BUG-03): without this state registered,
## StateMachine._on_unit_health_zero push_errors and returns; the
## CharacterBody3D stays alive in the scene tree and is_instance_valid()
## remains true, leading to attackers continuing to engage zombie
## corpses. Registering this state closes that gap — the unit is freed
## the same tick its HP hits zero.
##
## Lifecycle:
##   enter(prev, ctx):
##     Phase 5 will play a death animation here (sprite swap, particle
##     burst, sink-into-ground, etc.). For Phase 2 we free the owning
##     unit immediately. We use queue_free.call_deferred() rather than a
##     direct queue_free() to avoid mutating the scene tree mid-state-
##     transition: this state's enter() runs inside StateMachine._apply_
##     transition, which is itself called inside _on_unit_health_zero (a
##     signal handler firing inside another component's _sim_tick). A
##     direct free here would invalidate `current` while the StateMachine
##     was still using it. Deferring the free defers it to the next idle
##     tick of the SceneTree, by which point the StateMachine's transition
##     work is fully unwound.
##   _sim_tick: no-op. The unit will be freed before the next tick lands.
##   exit(): no-op. Dying is terminal — exit() is never called in practice.
##
## Source reference: this is plain mechanical bookkeeping, not a Shahnameh-
## rooted mechanic. Heroic deaths (Sohrab at Rostam's hand, Iraj's murder)
## get their own narrative treatment in Phase 3+ via cutscene + Farr-event
## hooks, not here. The Yadgar monument generator (per 01_CORE_MECHANICS.md
## §4 / §7) reads `EventBus.unit_died` which HealthComponent emits before
## this state is entered, so the +0.25 Farr/min generator is wired
## independently of this state's lifecycle.

# priority=100 puts Dying above every other state. Not strictly necessary
# (the death-preempt path bypasses priority comparison in
# StateMachine._on_unit_health_zero) but documents intent: "this is the
# top of the pile."
# interrupt_level=2 (NEVER) — death cannot be interrupted by damage. Player
# commands also cannot redirect a dying unit; the death-preempt path
# clears _pending_id before applying the transition.
func _init() -> void:
	id = &"dying"
	priority = 100
	interrupt_level = 2  # InterruptLevel.NEVER


# Free the owning unit. Deferred so we don't mutate the scene tree
# mid-state-transition. See file-header rationale for why call_deferred is
# load-bearing here.
func enter(_prev: Object, ctx: Object) -> void:
	if ctx == null or not is_instance_valid(ctx):
		return
	if not ctx.has_method(&"queue_free"):
		return
	ctx.queue_free.call_deferred()
