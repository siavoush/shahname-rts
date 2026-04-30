# State Machine Contract

*Outcome of Sync 2 between engine-architect and ai-engineer.*
*Status: **1.0.0** ratified 2026-04-30.*
*Created: 2026-04-30*

> Foundation: this contract sits on top of `SIMULATION_CONTRACT.md`. Every transition, command-queue mutation, timer read, and `_sim_tick` happens inside the simulation tick discipline defined there. No exceptions.

---

## 1. Decision: Flat FSM for both units and AI

A single generic `StateMachine` class, instanced separately for each unit and each AI controller, holding a flat set of `State` references. No hierarchical state machines, no behavior trees in the framework.

**Why not HSM:** Unit FSMs are 8–12 states, flat handles them. Encoding parent/child adds machinery (entry-exit chains, scoped transitions, parallel children) that we'd use rarely and pay for every tick. AI MVP is 4 phases (`Economy`, `BuildUp`, `Attack`, `Defend`) — also flat. If post-MVP behavior trees arrive, they ship as a separate `BehaviorTree` class composed alongside `StateMachine`, not a generalization of it.

**Why not BT-lite (states return success/failure/running):** harder to debug than explicit transitions; the F1–F4 overlay pattern needs a single "current state" answer. Flat FSM gives that for free.

---

## 2. Core Types — `StateMachine`, `State`, `Command`

Four types, all in `core/state_machine/`. Behavior (`tick`, `transition_to`, dispatch flow) is specified in §3; this section pins the *shape*.

### 2.1 `InterruptLevel` enum

```gdscript
class_name InterruptLevel

enum {
    NONE,    # default; no damage interrupts. Idle, casual movement.
    COMBAT,  # damage interrupts. Gathering, non-combat movement, returning.
    NEVER,   # damage cannot interrupt. Constructing, casting, dying.
}
```

`NEVER` blocks damage-driven preemption only. Player `replace_command` and death always win (§3.5, §4).

### 2.2 `State`

```gdscript
class_name State extends RefCounted

const id: StringName = &""              # subclass overrides; set once, never mutated
const priority: int = 0                 # tie-break when multiple transitions valid same tick
const interrupt_level: int = InterruptLevel.NONE

func enter(prev: State, ctx: Unit) -> void: pass
func _sim_tick(dt: float, ctx: Unit) -> void: pass
func exit() -> void: pass
```

Subclass conventions:
- `id` is a lowercase `StringName` matching the class noun: `&"idle"`, `&"moving"`, `&"attacking"`, `&"gathering"`, `&"constructing"`, `&"casting"`, `&"dying"`. Used as the dictionary key in `StateMachine._states` and as the telemetry id.
- State-internal fields (cooldown ticks, progress counters, cached target refs) live directly on the `State` and are mutated by the state's own `_sim_tick` only. They do **not** need `_set_sim` (see §5.2 — Sync 1's invariant is preserved by construction here, not by assertion).
- Gameplay state that *outlives* a single state instance — HP, position, Farr — never lives on a State at all. It lives on the unit's components (`HealthComponent`, `Node3D.global_position`, etc.), which are real `SimNode`s and use `_set_sim` per Sync 1.

### 2.3 `StateMachine`

```gdscript
class_name StateMachine extends RefCounted

var ctx: Unit                              # owning unit (or AI controller's owning Node)
var _states: Dictionary = {}               # StringName -> State, populated at unit spawn
var current: State                         # active state; never null after init
var _pending_id: StringName = &""          # set by transition_to, drained at end of tick
var _history: PackedInt32Array             # ring buffer indices; see §7
var current_state_name: StringName:        # alias for current.id, read-only for overlay
    get: return current.id

func register(state: State) -> void          # called at spawn for each state
func init(initial_id: StringName) -> void    # set current = _states[initial_id]; calls enter()
func tick(dt: float) -> void                 # the entry point Unit._sim_tick calls
func transition_to(target_id: StringName) -> void  # request transition; deferred to tick end
func _on_unit_health_zero(unit_id: int) -> void    # see §4
```

`StateMachine` is `RefCounted`, not a `Node`. It piggybacks on the owning unit's `_sim_tick` (§5.1). This lets us avoid scene-tree overhead per unit — a 50-vs-50 battle has 100 StateMachines, not 100 extra Node3Ds in the scene.

States call `transition_to_next()` (§3.4) on completion to dispatch into the next queued command, or `transition_to(&"<id>")` for explicit non-completion transitions. Bounded chain of 4 transitions per tick is enforced inside `tick`.

### 2.4 `Command` and `CommandQueue`

```gdscript
class_name Command extends RefCounted

var kind: StringName    # &"move" | &"attack" | &"gather" | &"build" | &"ability"
var payload: Dictionary # kind-specific: { target: Vector3 } | { target_unit: Node } | etc.

func reset() -> void:   # called by pool on rent/return
    kind = &""
    payload = {}
```

```gdscript
class_name CommandQueue extends Object   # NOT RefCounted; lifetime tied to Unit

const CAPACITY: int = 32   # per-unit hard cap
var _ring: Array[Command] = []
var _head: int = 0
var _size: int = 0

func push(cmd: Command) -> void:         # append (Shift+click)
func push_front(cmd: Command) -> void:   # rare; AI panic insertions
func peek() -> Command                   # null if empty
func pop() -> Command                    # rents from CommandPool; caller frees
func clear() -> void                     # bulk drop (right-click replace)
func size() -> int
func is_empty() -> bool
```

Capacity is a hard cap (32). The 33rd `push` drops the *oldest* command and emits a debug warning — protects against accidental Shift-spam in the input layer.

### 2.5 `CommandPool` and the `Unit` write API

`CommandPool` is a single autoload of pre-allocated `Command` objects shared across units (32 × ~250 max units ≈ 8000 entries). `rent()` returns a reset Command; `return_to_pool(cmd)` resets and re-shelves. Never call `Command.new()`.

The *only* sanctioned write paths into a unit's queue are two helpers on `Unit`:

- `replace_command(kind, payload)` — clears the queue (returning Commands to the pool), rents a fresh Command, pushes it, and calls `fsm.transition_to_next()`. The unit lands on the new work state directly (§3.4).
- `append_command(kind, payload)` — rents and pushes only. No transition request; the current state finishes, calls `transition_to_next()` itself, and §3.4 picks up the new top.

Player input layer and AI controllers (§6) both call these; nothing else writes the queue.

---

## 3. Lifecycle & Allocation Contract

### 3.1 State allocation: instantiate once, reuse forever

Every `State` instance for a unit is allocated at spawn (in the unit's `_ready`) and stored in `StateMachine._states`. Transitions swap the `current` reference and never call `.new()`. State objects are reused across the unit's lifetime and freed with the unit. Non-negotiable: a 50-vs-50 battle at 30 Hz with frequent transitions would otherwise burn thousands of throwaway `RefCounted` allocations per second.

`Command` objects follow the same rule via `CommandPool` (§2.5): `push` rents, `pop`/`clear` returns. The 33rd `push` to a unit's 32-deep queue drops the oldest with a debug warning.

### 3.2 Lifecycle hooks

`State` exposes three hooks. All run inside the owning unit's `_sim_tick` — never off-tick.

```gdscript
func enter(prev: State, ctx: Unit) -> void:
    # Set up state-local timers, kick off side effects (e.g., issue request_move),
    # cache target references. Read the current top of ctx.command_queue if needed.

func _sim_tick(dt: float, ctx: Unit) -> void:
    # Per-tick logic. Decide whether to transition. Mutate self via _set_sim if
    # the state holds gameplay-relevant fields (cooldowns, progress timers).

func exit() -> void:
    # Tear down: cancel in-flight requests, clear caches. Must NOT decide what
    # state runs next — that's the StateMachine's job (see §3.4).
```

`enter` receives the previous state for log/debug purposes; states should not branch on `prev` for behavior. `exit` is purely cleanup. Neither hook may directly call `transition_to()` — only `_sim_tick` may request a transition (or §3.5 death preempt).

### 3.3 Transition mechanism

A state requests a transition by calling `ctx.fsm.transition_to(&"target_id")` from inside its `_sim_tick`. The StateMachine sets `_pending_id` and applies the swap *after* `current._sim_tick` returns — never mid-tick. The swap calls `prev.exit()`, replaces `current`, calls `current.enter(prev, ctx)`, emits `EventBus.unit_state_changed`, and records the transition in the history ring (§7).

If the new state's `enter` (or §3.4's queue redirect) sets a fresh `_pending_id`, the swap loop runs again immediately, capped at **4 chained transitions per tick** to contain runaway loops. This is what lets a Shift-queued chain (Attacking → Moving → Gathering) finish in one tick instead of three.

### 3.4 Command consumption: `transition_to_next()`

When a state finishes its work, it calls `ctx.fsm.transition_to_next()`. This is the StateMachine's "I'm done, dispatch me to whatever's queued, otherwise go idle" helper:

```gdscript
func transition_to_next() -> void:
    var cmd := ctx.command_queue.peek()
    if cmd == null:
        transition_to(&"idle")
        return
    ctx.command_queue.pop()
    transition_to(_state_for_command(cmd))   # &"move" → &"moving", etc.
```

`_state_for_command` is the kind-to-state-id mapping: `&"move"` → `&"moving"`, `&"attack"` → `&"attacking"`, `&"gather"` → `&"gathering"`, `&"build"` → `&"moving"` (with a build-target rider on the next state's enter context, then auto-transitions to `&"constructing"` on arrival).

> **One rule:** states call `transition_to_next()` on completion. They never dequeue directly. `transition_to(&"<id>")` remains the primitive for non-completion transitions (e.g., `Moving` requesting `&"attacking"` after observing an enemy in range).

`Idle.enter` is empty; `Idle._sim_tick` is empty. A new command landing on an idle unit triggers `transition_to_next()` from the input layer (via `replace_command` / `append_command`), which dispatches into the next work state. A Shift-queued chain flows through `transition_to_next()` at each completion — no Idle tick, no wasted frames. The bounded re-dispatch loop in §3.3 (max 4 transitions per tick) still applies.

### 3.5 No-veto rule

A state's `_sim_tick` may decline to transition for its own reasons (e.g., `Constructing` finishes its build before yielding). It may *not* veto an external transition request — `transition_to` from outside the state always wins. The state's `exit` runs cleanup; that's its only recourse.

This matters for command replacement: when the player right-clicks a new target, `unit.replace_command(...)` calls `command_queue.clear()`, `command_queue.push(new_cmd)`, then `fsm.transition_to_next()`. The §3.4 helper pops the only queued command and lands the unit on the new work state directly. Current state cannot block this; same primitive serves AI panic-retreat.

`INTERRUPT_NEVER` does **not** block player commands. It blocks damage-driven preemption (§4) only. Constructing is interruptible by a player order; just not by being shot.

---

## 4. Death Preemption — Explicit Mechanism

Death is a one-tick force-transition that bypasses the normal transition machinery.

### 4.1 The signal

`HealthComponent` emits `EventBus.unit_health_zero(unit_id)` from its `_sim_tick` the moment HP reaches 0 (during the `combat` phase). It does not call `queue_free` or schedule cleanup directly.

### 4.2 The handler

Each `StateMachine` connects to `EventBus.unit_health_zero` at construction:

```gdscript
func _on_unit_health_zero(unit_id: int) -> void:
    if ctx.unit_id != unit_id: return
    if current.id == &"dying": return
    var prev := current
    prev.exit()
    current = _states[&"dying"]
    _pending_id = &""   # cancel any in-flight pending transition
    current.enter(prev, ctx)
    EventBus.unit_state_changed.emit(unit_id, prev.id, &"dying", SimClock.tick)
```

Three properties: (1) **preemptive over `interrupt_level`** — `INTERRUPT_NEVER` does not protect against death; casting a long ability mid-lethal-damage cancels the cast. (2) **Cancels `_pending_id`** — any in-flight pending transition is dropped; `Dying` wins. (3) **Single-tick guarantee** — the handler runs in the `combat` phase, so the dying transition is observable by `cleanup` the same tick.

### 4.3 The `Dying` state

`Dying` is the only state with `INTERRUPT_NEVER` *and* a fixed duration. `enter()` plays the death animation (placeholder: scale-to-zero), starts a 30-tick (1s) timer, emits `EventBus.unit_died`. `_sim_tick` decrements the timer; on expiry it requests removal from `cleanup`. Terminal state — no transition out exists.

---

## 5. SimNode Integration

### 5.1 The unit drives the FSM, not the other way around

`Unit extends SimNode`. `Unit._sim_tick` calls `fsm.tick(dt)` exactly once per simulation tick. The StateMachine itself is **not** a `SimNode` and is **not** registered with the movement-system phase coordinator. It piggybacks on the unit's tick.

```gdscript
class_name Unit extends SimNode

@onready var fsm: StateMachine = $StateMachine
@onready var command_queue: CommandQueue = CommandQueue.new()

func _sim_tick(dt: float) -> void:
    fsm.tick(dt)   # only entry point into state logic this frame
```

This satisfies Sync 1 hard constraint #2: state mutation has exactly one entry point per tick. The FSM cannot be ticked twice (no rogue `_process` driver), cannot tick across phases (state changes happen inside `movement` phase via the unit's coordinator).

### 5.2 States are RefCounted; their internal fields don't need `_set_sim`

States are `RefCounted`, not `SimNode`. The `_set_sim` assert exists to catch mutation by *external* writers (UI code, signal handlers, off-tick callbacks). A state's internal fields (`_swing_cooldown_tick`, `_progress`, cached target refs) have no external writers — they are mutated only inside the state's own `_sim_tick`, which runs only inside the unit's `_sim_tick`, which runs only inside the `movement` phase coordinator. The Sync 1 invariant is preserved by construction; the runtime check would be redundant.

What *does* extend `SimNode`: the unit's components (`HealthComponent`, `CombatComponent`, `FarrTracker`, etc.). These hold gameplay state read by many systems and *do* need the assert. States read those components (`ctx.health.current`) and call their methods (`ctx.health.apply_damage(n, attacker)`); the methods on the components route through `_set_sim` as required by Sync 1.

This avoids both the Node-tree explosion (100 units × 10 states = 1000 extra Nodes) and the awkward `state._data._set_sim(...)` composition indirection. States stay light-weight `RefCounted` objects, allocated once per unit at spawn (§3.1), and they cannot violate the on-tick invariant because they have no path to be ticked off-tick.

### 5.3 Telemetry

Every transition emits `EventBus.unit_state_changed(unit_id, from_id, to_id, tick)`. F3 debug overlay subscribes for live AI/state visualization. `MatchLogger` (Phase 6) sinks the same signal automatically (per Sync 1 §7 sink contract).

---

## 6. AI Controller Relationship

The AI controller (Turan, MVP) is a `StateMachine` instance — same class, different state set. Reuses every mechanism in §3 (transitions, dispatcher, history) without modification. This is the single biggest reason flat FSM was the right choice for both: one debug overlay shape, one tick discipline, one history format.

### 6.1 Controller structure

```gdscript
class_name TuranController extends Node

@onready var fsm: StateMachine = StateMachine.new()
var owned_units: Array[Unit] = []   # all Turan units this controller commands
var economy: EconomyTracker         # resource counts, pop, build queue
var perception: ThreatMap           # snapshot of player base/army built each AI tick

func _ready() -> void:
    fsm.ctx = self
    fsm.register(EconomyState.new())
    fsm.register(BuildUpState.new())
    fsm.register(AttackState.new())
    fsm.register(DefendState.new())
    fsm.init(&"economy")
```

The controller is a `Node` (not `SimNode`) registered with the `ai` phase coordinator. It does not extend `SimNode` because it holds no per-tick gameplay state of its own — its state lives on the units it commands and on its passive `economy`/`perception` snapshots, both of which are recomputed from world state on each AI tick.

### 6.2 Tick wiring

The `ai` phase coordinator calls `controller.tick(dt)` every simulation tick. The controller throttles internally — AI decisions don't need 30Hz:

```gdscript
const AI_DECISION_HZ: int = 4   # 4 decisions per second
const AI_TICK_INTERVAL: int = SimClock.SIM_HZ / AI_DECISION_HZ   # = 7 sim ticks

func tick(dt: float) -> void:
    if SimClock.tick % AI_TICK_INTERVAL != 0:
        return
    perception.refresh()
    fsm.tick(dt * AI_TICK_INTERVAL)   # dt scaled to match decision cadence
```

Units the controller commands tick at full 30Hz (their own state machines run every sim tick). Only the *strategic* layer is throttled. This is why the separation matters: command issuance is bursty (every 7 ticks), command execution is continuous.

### 6.3 No command queue at the controller

The controller does *not* own a `CommandQueue`. It is the *issuer* of commands, not a receiver. Per AI tick, controller states call:

```gdscript
unit.replace_command(&"attack", { target_unit: enemy_throne })   # urgent: drop everything
unit.append_command(&"move", { target: rally_point })            # additive: queue behind current
```

No new methods, no new patterns — the same primitives the player input layer uses. AI panic-retreat and player right-click trace through identical code.

### 6.4 One-way coupling: AI reads unit state, never writes to it

The controller **never** calls `unit.fsm.transition_to()`. The only legal touchpoints from controller → unit are:
- `unit.replace_command(...)` / `unit.append_command(...)` (write the queue)
- `unit.fsm.current_state_name` (read the current state id)
- `unit.is_idle()` / `unit.is_engaged()` / `unit.is_dying()` (read helpers, see §6.5)
- `unit.global_position`, `unit.health.current`, etc. (read sim state)

This rule is what makes the unit FSM a black box from the AI's perspective. The controller has zero knowledge of how a unit transitions internally — it sees only "what state is the unit in *right now*" and "give it a new top-of-queue if I want it doing something else."

### 6.5 Legibility helpers on `Unit`

To keep AI controller code readable (and to avoid scattering string comparisons against state ids), the `Unit` class exposes a thin layer of read-only helpers:

```gdscript
# unit.gd
func is_idle() -> bool:
    return fsm.current.id == &"idle"

func is_engaged() -> bool:
    return fsm.current.id in [&"attacking", &"casting"]

func is_dying() -> bool:
    return fsm.current.id == &"dying"

func is_busy() -> bool:
    return fsm.current.id in [&"constructing", &"gathering", &"casting"]
```

Helpers stay shallow — they wrap state-id comparisons, not behavior. If the AI needs richer context (e.g., "is this worker carrying resources right now?"), it reads the gathering state's exposed fields directly, *without* a helper, because such a helper would make the AI dependent on the worker's internal state shape and break the black-box rule.

### 6.6 AI states (full spec in `01_CORE_MECHANICS.md` §12)

Four MVP states registered on the controller's FSM: `EconomyState`, `BuildUpState`, `AttackState`, `DefendState`. Each `_sim_tick` (every 7 sim ticks per §6.2) issues commands to `owned_units` via `replace_command`/`append_command`; transitions flow through §3 as for any FSM. Difficulty (`Easy`/`Normal`/`Hard`) is multiplier knobs on the controller's economy thresholds and aggression timers, never branching state logic — same code path, different numbers.

---

## 7. Debug Introspection

Single shape works for both unit FSMs and AI FSMs (one of the wins from keeping flat).

### 7.1 Live introspection (F3 overlay)

Each `StateMachine` exposes:
```gdscript
var current_state_name: StringName        # alias for current.id, surfaced for overlay
var transition_history: Array[Transition] # ring buffer, last N transitions
```

`Transition` is a small struct: `{ from: StringName, to: StringName, tick: int, reason: StringName }`. Ring buffer size 16 per unit (covers ~30s of tick history at typical transition rates), 64 per AI controller. Pre-allocated, never grows.

### 7.2 Overlay rendering

F3 toggle (per CLAUDE.md) draws over selected unit:
- Current state id (`"attacking"`)
- Last 3 transitions (`gathering → moving → idle`)
- For AI: phase + last decision (`AttackState: target=Throne, since tick 8420`)

### 7.3 Telemetry signal

`EventBus.unit_state_changed(unit_id, from_id, to_id, tick)` emits on every transition. Headless tests assert state sequences against this signal. `MatchLogger` (Phase 6) writes them to NDJSON for replay diff.

---

## 8. Worked Example: Kargar's Day

A worker is told to mine, Shift-queued to build a farm, then the player right-clicks an enemy to attack. Mid-swing, the worker dies.

```
tick 100  Player right-clicks coin mine.
            unit.replace_command(&"move", { target: mine_pos })
            queue.push(&"gather", { node: mine_pos })   # input layer expands
            queue: [Move, Gather]
            fsm.transition_to_next()
            pops Move → transitions to Moving.
            Moving.enter() issues request_move(mine_pos).

tick 130  Path consumed; Moving completes.
            Moving calls transition_to_next().
            pops Gather → transitions to Gathering. No Idle tick.

tick 200  Player Shift+right-clicks fertile tile to queue a farm build.
            unit.append_command(&"build", { kind: "Mazra'eh", pos: tile_pos })
            queue: [Build]   (Gathering still active; queue just grows)

tick 280  Gather full → deposits at Throne → Gathering completes.
            Gathering.transition_to_next() → pops Build → translates to Moving
            (toward tile_pos) with build-target rider in the command payload.
            On arrival, Moving completes; the build rider tells it to call
            transition_to(&"constructing") explicitly (not transition_to_next),
            because Build is a compound and queue-peek would miss the build phase.

tick 350  Player right-clicks an enemy (no Shift).
            unit.replace_command(&"attack", { target_unit: enemy })
            queue.clear() then push(Attack); fsm.transition_to_next().
            §3.5: Constructing has INTERRUPT_NEVER but that only blocks damage.
            Player commands win. Constructing.exit() refunds half-built materials.
            transition_to_next() pops Attack → transitions to Attacking.

tick 420  Mid-swing, enemy archer lands the kill shot.
            HealthComponent._sim_tick sees hp == 0 → EventBus.unit_health_zero.
            fsm._on_unit_health_zero force-transitions to Dying (§4).
            Attacking.exit() cancels the swing.
            Dying.enter() emits unit_died, schedules removal in 30 ticks.

tick 450  cleanup phase processes pending removal. Unit is freed.
```

Properties demonstrated, in order: Shift-queue chains through §3.4 redirect with no Idle tick; `replace_command` is the universal cancel (player + AI use the same primitive); `INTERRUPT_NEVER` blocks damage preemption only, not player commands; death preempts an in-progress swing in one tick regardless of `interrupt_level`; every transition emits `unit_state_changed` for telemetry.

---

*End of joint draft v1. §2 and §6 filled by ai-engineer; pending engine-architect consistency pass, then ratification.*
