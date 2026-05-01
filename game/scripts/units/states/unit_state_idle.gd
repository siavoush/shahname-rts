class_name UnitState_Idle extends "res://scripts/core/state_machine/unit_state.gd"
##
## UnitState_Idle — the unit's "no current work" state.
##
## Per docs/STATE_MACHINE_CONTRACT.md §3.4 (Idle.enter / Idle._sim_tick are
## empty; a new command landing on an idle unit triggers transition_to_next
## from the input layer via Unit.replace_command / append_command). This state
## is therefore a *true* no-op on the gameplay side — its only job is to
## "wait" while the StateMachine framework dispatches incoming commands.
##
## Visual cue (off-tick, render-only):
##   We pulse the parent unit's MeshInstance3D scale slightly so the player
##   can see the unit is alive but uncommitted. Per Sim Contract §1.5, this
##   visual must NOT mutate gameplay state — scale is purely render-side
##   (MeshInstance3D.scale doesn't feed into combat math, pathfinding, or
##   any SimNode field). We drive the pulse from the SimClock.tick * SIM_DT
##   value, which is deterministic and replay-safe — Sim Contract §1.1
##   forbids gameplay code reading wall-clock APIs (TimeProvider is the
##   only sanctioned wall-clock seam, and only off-tick), so SimClock.tick
##   is also the right driver for any sim-tick-side render decoration. We
##   technically don't need determinism for a pulse — but cheap, free, and
##   removes a divergence vector from headless determinism tests.
##
##   Pulse implementation lives in `_sim_tick`, NOT in `_process`. Per
##   Sim Contract §1.5 the visual could live in `_process`, but our State
##   class doesn't have a `_process` (it's a RefCounted). Driving the
##   render-side scale write from `_sim_tick` is allowed because:
##     (a) It writes to a Node3D's `scale` field, not a SimNode field —
##         the on-tick assert isn't tripped.
##     (b) The write is idempotent (same input → same output); no
##         accumulator drift.
##     (c) The mesh scale is render-only; it doesn't feed into any
##         simulation pathway.
##
## interrupt_level: NONE — Idle is the lowest-priority "do nothing" state.
## Damage during Idle is handled by the death-preempt path (HealthComponent
## emits unit_health_zero → StateMachine forces Dying). No Idle-specific
## damage interrupt is needed.
##
## Lifecycle:
##   enter(prev, ctx)  — cache the MeshInstance3D ref so per-tick reads
##                       are O(1). Reset the pulse phase.
##   _sim_tick(dt, ctx) — write the scale field on the cached MeshInstance3D.
##                        No transition logic — the StateMachine framework
##                        handles command-queue dispatch via transition_to_next
##                        when commands arrive (Contract §3.4).
##   exit()             — restore the mesh scale to 1.0 so the next state
##                        starts visually neutral.
##
## Tests cover: enter caches the mesh; _sim_tick writes scale; transition_to_next
## from the StateMachine dispatches a Move command into Moving without us
## having to poll.

# Pulse parameters. Subtle — per CLAUDE.md placeholder visuals, the pulse
# is a "the unit is alive" cue, not a stylistic flourish. ~5% amplitude at
# ~1 Hz reads as a gentle breath without distracting from gameplay.
const _PULSE_AMPLITUDE: float = 0.05    # ±5% scale variation
const _PULSE_FREQUENCY_HZ: float = 1.0  # one full cycle per second

# Cached mesh ref. Set in enter(); cleared in exit(). Untyped (Variant) so
# this script parses cleanly under the same class_name registry order
# constraints as the rest of the state-machine framework
# (docs/ARCHITECTURE.md §6 v0.4.0).
var _mesh: Variant = null


func _init() -> void:
	id = &"idle"
	priority = 0
	# InterruptLevel.NONE — damage during Idle goes through the death-preempt
	# path, not a state-level interrupt. Idle is the rest state; nothing
	# damage-driven needs to "interrupt" it because there's no in-flight work
	# to be interrupted. Player commands flow through transition_to_next via
	# Unit.replace_command, which doesn't depend on interrupt_level.
	interrupt_level = 0  # InterruptLevel.NONE


# Cache the parent unit's MeshInstance3D so the per-tick scale write is a
# direct field set, not a tree lookup. The unit.tscn template names this
# child "MeshInstance3D" (per the scene); concrete unit subclasses (Kargar,
# etc.) keep the same node name so the lookup is stable.
func enter(_prev: Object, ctx: Object) -> void:
	_mesh = null
	if ctx == null:
		return
	if not ctx.has_method(&"get_node_or_null"):
		return
	var n: Node = ctx.get_node_or_null(^"MeshInstance3D")
	if n is Node3D:
		_mesh = n
		# Reset to neutral on entry so the pulse starts from rest.
		_mesh.scale = Vector3.ONE


# Per-tick: write the pulse scale. No gameplay logic — Idle is a true
# no-op on the simulation side. Command-queue dispatch is handled by the
# StateMachine framework's transition_to_next path when external code
# (player input, AI controller) pushes a Command via Unit.replace_command
# / append_command (Contract §3.4).
func _sim_tick(_dt: float, _ctx: Object) -> void:
	if _mesh == null:
		return
	# Deterministic pulse driven by SimClock.tick. Replay-safe: two runs
	# with identical seeds and tick counts produce identical scale values.
	# (Replay-safe isn't required for a pulse, but it's free and removes
	# a divergence vector from headless determinism tests.)
	var t: float = float(SimClock.tick) * SimClock.SIM_DT
	var pulse: float = 1.0 + _PULSE_AMPLITUDE * sin(TAU * _PULSE_FREQUENCY_HZ * t)
	_mesh.scale = Vector3(pulse, pulse, pulse)


# Restore the mesh to neutral scale so the successor state starts clean.
# (The successor may rewrite scale — Moving doesn't, but a future Casting
# or Constructing might want full control.)
func exit() -> void:
	if _mesh != null:
		_mesh.scale = Vector3.ONE
	_mesh = null
