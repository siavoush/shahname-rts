# Simulation Architecture Contract

*Outcome of Sync 1 between engine-architect, ai-engineer, qa-engineer.*
*Status: **1.2.0** ratified 2026-04-30 (Convergence Review revision pass).*
*Created: 2026-04-30*

---

## 0. Why this document exists

Every system in the game — combat, Farr, AI, abilities, the Kaveh Event timer — needs a shared answer to two questions: *when does state change?* and *how do other systems see those changes?*

Without a contract, each system improvises. Improvisation here is paid back tenfold later: replays diverge, AI-vs-AI balance sims produce different answers on different machines, and the Kaveh 30-second countdown drifts depending on framerate. Pin it down once, build everything else on top.

This contract governs the **simulation layer** only — gameplay state and the systems that mutate it. Rendering, input capture, UI animation, debug overlays, and audio are *not* bound by it; they read freely.

---

## 1. Time & Tick Discipline

### 1.1 The rule

> **Gameplay state mutates only inside a `_sim_tick()` call dispatched by `SimClock`. All other code reads only.**

Reads from `_process` are unrestricted (rendering interpolation, hover previews, UI binding). Writes from `_process` are forbidden. The same applies to signal handlers that fire off-tick, `await` resumptions outside the tick, and any timer or tween callback.

### 1.2 `SimClock` autoload

```gdscript
# autoload/sim_clock.gd
extends Node

const SIM_HZ: int = 30
const SIM_DT: float = 1.0 / SIM_HZ

var tick: int = 0           # monotonic, starts at 0 on match begin
var sim_time: float = 0.0   # derived: tick * SIM_DT
var _is_ticking: bool = false
var _accumulator: float = 0.0
var _phases: Array[StringName] = [
    &"input", &"ai", &"movement", &"spatial_rebuild",
    &"combat", &"farr", &"cleanup",
]

func is_ticking() -> bool:
    return _is_ticking

func _physics_process(delta: float) -> void:
    _accumulator += delta
    while _accumulator >= SIM_DT:
        _accumulator -= SIM_DT
        _run_tick()

func _run_tick() -> void:
    _is_ticking = true
    EventBus.tick_started.emit(tick)
    for phase in _phases:
        EventBus.sim_phase.emit(phase, tick)
    EventBus.tick_ended.emit(tick)
    _is_ticking = false
    tick += 1
    sim_time = tick * SIM_DT
```

Each phase is driven by a phase coordinator (`MovementSystem`, `CombatSystem`, etc.) that connects to `EventBus.sim_phase` and runs its registered components in deterministic order (sorted by `unit_id`).

**Hard rule:** no gameplay code reads `Time.get_ticks_msec()`, `OS.get_unix_time()`, or accumulates its own delta. The only "now" is `SimClock.tick` and `SimClock.sim_time`.

### 1.3 Structural enforcement: `SimNode` base class

All gameplay components extend `SimNode`. The base class provides one helper that asserts mutation happens on-tick:

```gdscript
# core/sim_node.gd
class_name SimNode extends Node

func _sim_tick(_dt: float) -> void:
    pass   # override in subclass

func _set_sim(prop: StringName, value: Variant) -> void:
    assert(SimClock.is_ticking(),
        "Off-tick mutation of '%s' on %s" % [prop, name])
    set(prop, value)
```

Components write through `_set_sim`. In debug builds, off-tick writes crash with a stack trace. In release, the assert compiles out — no perf cost.

**Self-only mutation rule.** `_set_sim` is `_`-prefixed and intended to mutate `self` exclusively. A component never reaches into a sibling, parent, or unrelated node and calls `other._set_sim(&"prop", v)` — the assert would still pass (we are on-tick), but encapsulation breaks: ownership of "who can write this field" becomes diffuse and audits get hard. Pattern: if state X needs to change as a side effect of state Y, the *owner of X* exposes a method (`take_damage(amount)`, `apply_farr_change(...)`) which internally calls its own `_set_sim`. Cross-component writes go through method calls, never through reaching in.

`apply_farr_change(amount, reason, source_unit)` (mandated by `CLAUDE.md`) calls `_set_sim` internally, so every Farr mutation is checked for free.

**Why `SimNode` and not a `SimMutation` autoload:** see the design note at the end of §3.

### 1.4 CI lint rule (owned by qa-engineer)

A pre-commit / CI check (shell + ripgrep) flags these anti-patterns. Patterns are regex-based and runnable as a pre-commit script:

| ID | Pattern (ripgrep) | Scope | Rationale |
|---|---|---|---|
| L1 | `func\s+_process\b` then within body: `\b(apply_\w+|\w+_tick|\w+State\.update)\b` | `game/scripts/**/*.gd` | Catches gameplay mutation called from `_process`. |
| L2 | `func\s+_process\b` then within body: `EventBus\.\w+\.emit` | `game/scripts/**/*.gd` | Catches write-shaped EventBus emissions from `_process`. (Read-shaped signals like `selection_changed` are exempt — see allowlist.) |
| L3 | `\brandi\(\|\brandf\(\|\brandi_range\(\|\brandf_range\(` | `game/scripts/**/*.gd` minus `game/scripts/autoload/rng.gd` | Catches bare RNG outside the GameRNG autoload. |
| L4 | `emit_signal\(\s*"` | `game/scripts/**/*.gd` | Catches string-form signal emission (must use `EventBus.foo.emit(...)`). |
| L5 | `\bTime\.get_(unix_time|ticks_msec|ticks_usec)\(` | `game/scripts/**/*.gd` minus `game/scripts/autoload/sim_clock.gd` | Catches wall-clock reads in gameplay. |

Implementation: `tools/lint_simulation.sh` shell script runs the five `rg` commands, exits non-zero on any match. CI calls it; pre-commit hook calls it. Allowlist for L2 (read-shaped signals) lives at the top of the script as a regex blocklist applied after the match.

Lint complements `SimNode`. Lint catches "didn't extend SimNode at all" cases; `SimNode` catches "extended it but mutated off-tick anyway." Both are required.

### 1.5 UI consumers of write-shaped EventBus signals

§1.1 says rendering and UI may *read* simulation state freely. The companion rule for *writes*:

> **UI consumers of write-shaped EventBus signals must defer all visual state changes to the next `_process` frame. UI never reaches into sim state during a sink callback, and never starts a Tween or AnimationPlayer in the callback's synchronous body.**

Pattern: the UI handler appends the event to a per-frame queue; `_process` drains the queue and applies visual changes (Tween starts, label updates, particle bursts). This keeps render side-effects decoupled from sim phases — a `unit_died` signal firing in the `combat` phase doesn't synchronously start a death animation that races a queued cleanup, and a `farr_changed` signal doesn't pause the sim to lerp the gauge mid-tick.

```gdscript
# ui/farr_gauge.gd
var _pending_changes: Array[Dictionary] = []

func _ready() -> void:
    EventBus.farr_changed.connect(_on_farr_changed)

func _on_farr_changed(amount, reason, source_unit_id, farr_after, tick) -> void:
    _pending_changes.append({"amount": amount, "after": farr_after})

func _process(_dt: float) -> void:
    while not _pending_changes.is_empty():
        var change := _pending_changes.pop_front()
        _spawn_floating_number(change.amount)
        _tween_gauge_to(change.after)
```

The queue-then-drain pattern is enforced by convention; lint rule L2 (§1.4) catches the worst offenders (`EventBus.*.emit` from `_process`), but the UI-side discipline of *not synchronously mutating Tweens in a callback* is reviewed at code-review.

### 1.6 Numeric Representation: Determinism via Integer Arithmetic

State that accumulates over the course of a match — Farr first, Zur and Shar later, possibly economy ledgers if drift becomes visible — is stored as **fixed-point integer**, formatted to float only at boundaries (HUD readout, telemetry NDJSON, balance tooling).

**The problem.** IEEE-754 floats are platform-dependent in subtle ways: identical sequences of additions on x86-64 vs ARM64 can diverge at the 1e-15 level, and that drift accumulates. A 25-minute match at 30 Hz is 45,000 ticks; multiple Farr generators each contributing fractional values per tick produce outcomes that cross the Kaveh threshold (15.0) on different machines despite identical seeds and identical inputs. Same problem hits any AI-vs-AI sim suite that compares end-state across runs.

**The rule.**
- Every accumulating gameplay scalar uses an **integer backing store** scaled by a domain-specific factor (e.g., `farr_x100: int` where 50.0 Farr = 5000 stored). Domain factor lives in `BalanceData` or a per-domain constant.
- All arithmetic — adds, subtracts, multiplications by integer factors — happens on the integer.
- Float conversion happens **only** at:
  - HUD/UI display (`farr_for_display() -> float` returns `farr_x100 / 100.0`)
  - Telemetry NDJSON output (`MatchLogger` formats the float)
  - Balance tooling (diff scripts, dashboards)
- Multiplication by float multipliers (e.g., AI difficulty `gather_mult`) is allowed *if* it converts back to int via `roundi()` or `int()` before storage. The rounding rule is part of the domain spec and must be deterministic across platforms.

**Farr is the first concrete case.** The `FarrSystem` stores `farr_x100: int`; `apply_farr_change(amount: float, reason, source)` converts `amount` to `int(roundi(amount * 100.0))` at the boundary, then adds. `BalanceData.FarrConfig` exposes float-typed fields for tuning ergonomics, but the runtime store is integer. The Kaveh threshold (15.0) compares as `farr_x100 < 1500`, exact. Tier-2 threshold (40.0) compares as `farr_x100 >= 4000`, exact.

**What this is not.** Not a fixed-point math library, not a pervasive replacement for floats. Position (`Node3D.global_position`), velocity, and other per-frame physics state stay float — they don't accumulate over the match in a way that matters, and Godot's transform math is float-internal regardless. The rule is for *long-lived gameplay scalars that cross thresholds*. If a future system needs a similar guarantee, it follows this pattern.

---

## 2. Tick Order

The seven-stage pipeline runs in this order every tick:

| # | Phase | Purpose | One-line rationale |
|---|---|---|---|
| 1 | `input` | Drain queued player commands into intents | Player input is the source of truth for the tick. Latest first. |
| 2 | `ai` | AI controllers run `tick()`, may emit commands and target updates | AI sees post-input world; one-tick stale spatial data is fine for targeting heuristics. |
| 3 | `movement` | Resolve velocity, apply position deltas, handle path completion | Position changes happen here and only here. |
| 4 | `spatial_rebuild` | `SpatialIndex` rebuilds from scratch | Combat must see post-movement positions. AI saw pre-movement (acceptable). |
| 5 | `combat` | Range checks, damage application, death events | Reads fresh `SpatialIndex`; emits `unit_died` for cleanup. |
| 6 | `farr` | Apply Farr deltas accumulated this tick (drains, generators, snowball checks) | Farr depends on combat outcomes (kills, snowball ratio). Must run after combat. |
| 7 | `cleanup` | Reap dead nodes, advance timers, emit `tick_ended` | Single deferred-free point — no `queue_free` mid-tick. |

Components must not bypass this order. If component A's tick depends on component B's tick output, B is in an earlier phase or A reads stale data. Out-of-phase reads crash via `SimNode` asserts on the mutated property.

### 2.1 Phase coordinators (the only path that calls `_sim_tick`)

`SimClock._run_tick()` does **not** call `_sim_tick` on any component directly. It only emits `EventBus.sim_phase(phase, tick)`. One *phase coordinator* per phase listens for that signal and iterates its registered components. This indirection is what guarantees `advance_ticks(n)` and the live `_physics_process` driver execute the *same code paths*.

```gdscript
# systems/movement_system.gd  (phase coordinator for "movement")
extends Node

var components: Array[SimNode] = []   # sorted by unit_id

func _ready() -> void:
    EventBus.sim_phase.connect(_on_phase)

func register(c: SimNode) -> void:
    components.append(c)
    components.sort_custom(func(a, b): return a.unit_id < b.unit_id)

func _on_phase(phase: StringName, _tick: int) -> void:
    if phase != &"movement": return
    for c in components:
        c._sim_tick(SimClock.SIM_DT)
```

Every phase that ticks components has a coordinator with this shape. Iteration order is `unit_id` ascending, locked. Insertions resort; deletions filter. Coordinators that don't tick components (e.g., `spatial_rebuild` calls `SpatialIndex._rebuild()` once, no per-component iteration) follow the same signal-listening shape with their own body.

**Any `SimNode` may register with any phase coordinator.** The phase a node registers with is a property of *the node*, not its class — a `MineNode` registers with the `cleanup` coordinator (to flush its deferred-depletion emit), a `HealthComponent` registers with `combat`, a `MovementComponent` registers with `movement`. A node that needs work in two phases registers twice (with two coordinators). The `cleanup` coordinator is no different from the others — its phase semantics are "things that happen after combat/farr resolved this tick" and it accepts arbitrary `SimNode` registrations, not just dying-unit reaping. World-builder's `MineNode` deferred-depletion pattern (Resource Node Contract §3.3) is the canonical example.

Coordinators that drive non-component singletons (`spatial_rebuild` → `SpatialIndex._rebuild()`, `input` → input drainer) keep that work inline in the coordinator body and do *not* expose a `register()` API for arbitrary nodes. Phases that *do* tick a node list (`movement`, `ai`, `combat`, `farr`, `cleanup`) all expose the same `register()`/`unregister()` shape.

**Implication for `advance_ticks`:** the test harness drives the simulation by emitting the same `EventBus.sim_phase` signals in order — never by calling `_sim_tick` directly. This closes the divergence risk between live and headless paths: any change to the live tick flow automatically applies to tests, and vice versa. See §6.1.

---

## 3. SpatialIndex API

### 3.1 Autoload

```gdscript
# autoload/spatial_index.gd
extends Node

const CELL_SIZE: float = 8.0
var _cells: Dictionary = {}   # Vector2i -> Array[Node]

func register(agent: Node) -> void: ...
func unregister(agent: Node) -> void: ...

func query_radius(center: Vector3, radius: float) -> Array[Node]: ...
func query_nearest_n(point: Vector3, n: int, team_filter: int) -> Array[Node]: ...
func query_radius_team(center: Vector3, radius: float, team: int) -> Array[Node]: ...

func _rebuild() -> void: ...   # called from spatial_rebuild phase
```

### 3.2 Population

Any node with a `SpatialAgentComponent` child auto-registers on `_ready`, deregisters on `tree_exiting`. The component exposes `team: int` and `agent_radius: float`. The Y axis is ignored; the grid is 2D over the XZ plane.

### 3.3 Complexity

- Rebuild: O(N) where N = registered agents. Fine at 200+ agents.
- `query_radius(r)`: O(C + k) where C = cells covered ≈ `(2r/CELL_SIZE)²` and k = candidates returned. With `r ≤ 20m` (largest MVP query — snowball), C ≤ 36 cells.
- `query_nearest_n`: spirals outward from the source cell until N candidates collected, then sorts. O(C + k log k).
- `query_radius_team`: same as `query_radius` with a team filter applied during cell scan.

`team_filter = -1` means any team. `query_nearest_n` excludes the source if the source is a registered agent (caller may pass its own node and not get itself).

### 3.4 Read-safety from `_input` and `_process`

`SpatialIndex` is **read-safe from `_input` and `_process` between tick boundaries.** UI consumers (selection raycast in `_input`, F4 attack-range overlay in `_process`, hover tooltips, etc.) may call `query_radius` and friends from these contexts and get a coherent answer reflecting the world state as of the most recent `tick_ended`.

The one exception: queries issued *during* the `spatial_rebuild` phase return undefined results. The rebuild is not interruptible, but it is also not atomic from a reader's perspective. UI should treat the index as quiescent only between ticks (after `EventBus.tick_ended` fires for tick N, until `EventBus.sim_phase(&"spatial_rebuild", N+1)` fires for the next tick). In practice this is automatic: `_input` and `_process` run on Godot's main loop, and `_physics_process` (where `spatial_rebuild` runs) is a separate loop — they don't reentrantly interleave. The rule is documented for discipline, not as a runtime hazard.

UI never *writes* to `SpatialIndex`. Registration and rebuild are sim-side only. A UI consumer reading a stale index for one frame is acceptable (the next render frame catches up); a UI consumer writing to the index would corrupt simulation state and break determinism.

---

## 4. Movement & Pathfinding

### 4.1 `MovementComponent` (extends `SimNode`)

```gdscript
class_name MovementComponent extends SimNode

@export var max_speed: float = 5.0
var path_state: IPathScheduler.PathState = IPathScheduler.PathState.READY
var _waypoints: PackedVector3Array = []
var _request_id: int = -1
var _scheduler: IPathScheduler   # injected; defaults to PathSchedulerService

func request_move(target: Vector3, priority: int = 0) -> void:
    if _request_id != -1:
        _scheduler.cancel_repath(_request_id)
    _request_id = _scheduler.request_repath(
        get_parent().unit_id, owner_position(), target, priority)
    path_state = IPathScheduler.PathState.PENDING

func _sim_tick(dt: float) -> void:
    if path_state == IPathScheduler.PathState.PENDING:
        var result := _scheduler.poll_path(_request_id)
        if result.state != IPathScheduler.PathState.PENDING:
            path_state = result.state
            _waypoints = result.waypoints
            _request_id = -1
    if path_state == IPathScheduler.PathState.READY and not _waypoints.is_empty():
        _advance_along_path(dt)
```

`request_move` is non-blocking. Calling it twice in the same tick replaces the in-flight request (idempotent-per-tick). Result lands on `requested_tick + 1` or later — caller checks `path_state` next tick.

**`Node3D.global_position` exemption.** Position is the most-frequent write in the simulation and is set directly on the parent `Node3D` (`unit.global_position = ...`) inside `_advance_along_path`, *not* through `_set_sim`. This is intentional: `Node3D.global_position` is a Godot built-in setter, not a `SimNode` field, and routing every position write through `_set_sim` adds noise without value. The on-tick invariant still holds — these writes only happen inside the `movement` phase, where `SimClock.is_ticking()` is true. Writing `global_position` from `_process` or any other off-tick context is forbidden by the same rule, just enforced via lint (L1) rather than the runtime assert. If we ever discover position writes leaking off-tick, we add a dedicated lint pattern; not worth a `_set_sim_position` helper for the current shape.

### 4.2 `IPathScheduler` interface

```gdscript
class_name IPathScheduler

enum PathState { PENDING, READY, FAILED, CANCELLED }

func request_repath(unit_id: int, from: Vector3, to: Vector3, priority: int) -> int:
    push_error("abstract"); return -1

func poll_path(request_id: int) -> Dictionary:
    # returns { state: PathState, waypoints: PackedVector3Array }
    push_error("abstract"); return {}

func cancel_repath(request_id: int) -> void:
    push_error("abstract")
```

`priority` is **advisory for MVP** — accepted on the API, ignored by both implementations. Bucketing arrives if profiling demands it.

### 4.3 Implementations

**`NavigationAgentPathScheduler`** (production, engine-architect owns)
Wraps `NavigationServer3D`. Issues a path query asynchronously, parks the result in a request table keyed by `request_id`, returns it on `poll_path`. Polled, never callback-into-gameplay — keeps results on tick boundaries.

**`MockPathScheduler`** (qa-engineer owns)
Returns a straight-line path from `from` to `to` (two waypoints). Result is `READY` on `requested_tick + 1`. Exposes `call_log: Array[Dictionary]` for test assertions. `FAILED` is forced via `mock.fail_next_request()` for testing unreachable-target paths.

`MovementComponent._scheduler` resolves from a `PathSchedulerService` autoload by default. Tests inject the mock by writing `unit.get_movement()._scheduler = MockPathScheduler.new()` before calling `advance_ticks`.

---

## 5. RNG

### 5.1 `GameRNG` autoload

```gdscript
# autoload/rng.gd
extends Node

var combat: RandomNumberGenerator = RandomNumberGenerator.new()
var ai: RandomNumberGenerator = RandomNumberGenerator.new()
var kaveh: RandomNumberGenerator = RandomNumberGenerator.new()
var world: RandomNumberGenerator = RandomNumberGenerator.new()

func seed_match(match_seed: int) -> void:
    combat.seed = hash([match_seed, "combat"])
    ai.seed     = hash([match_seed, "ai"])
    kaveh.seed  = hash([match_seed, "kaveh"])
    world.seed  = hash([match_seed, "world"])
```

### 5.2 Domains

- `combat` — damage rolls, miss/crit if added later, hit-stagger jitter.
- `ai` — AI tactical decisions, build-order tiebreaks, target selection.
- `kaveh` — worker defection rolls (25% per worker), rebel composition.
- `world` — map decoration, resource node jitter, anything one-shot at world gen.

### 5.3 Usage

```gdscript
var damage := base_damage + GameRNG.combat.randi_range(0, variance)
```

Bare `randi()` and `randf()` are forbidden in gameplay code. Lint enforces this.

`seed_match` is called at match start by `GameManager` from a seed surfaced in match-setup UI (or auto-generated from time and logged). Same seed + same player inputs ⇒ same end state. This is the basis for replays and the QA regression test.

---

## 6. Test Hooks

### 6.1 `advance_ticks(n: int)` contract

The headless test harness calls `advance_ticks(n)` to drive the simulation deterministically without a render loop, audio, or wall-clock dependency.

**Must do:**
- Set `SimClock._is_ticking = true` for each tick.
- Emit `EventBus.tick_started(tick)`.
- Emit `EventBus.sim_phase(phase, tick)` for each of the 7 phases in order. **Do not call `_sim_tick` on components directly** — phase coordinators (see §2.1) listen for `sim_phase` and iterate their components in `unit_id` order. The harness shares this code path with the live `_physics_process` driver, which is the whole point.
- Increment `SimClock.tick` and update `sim_time` after each tick.
- Emit `EventBus.tick_ended(tick)`, then set `_is_ticking = false`.

**Must not do:**
- Call `_sim_tick` on components directly. (Bypasses the coordinator and lets headless and live paths drift.)
- Touch `NavigationServer3D` (use `MockPathScheduler` instead — injected via `MovementComponent._scheduler`).
- Call `_process` or `_physics_process` on any node.
- Read wall-clock time. Time advances only via `SimClock.tick`.
- Render anything. The harness runs in `--headless` mode.

The `MockPathScheduler` callback resolution and `SpatialIndex._rebuild` happen automatically because their phase coordinators are listening for `sim_phase` like everyone else — no special-case harness code.

### 6.2 Determinism regression test (qa-engineer authors)

```gdscript
# tests/integration/test_determinism.gd
func test_same_seed_same_outcome():
    var match_a := MatchHarness.new(seed=42, scenario="basic_combat")
    var match_b := MatchHarness.new(seed=42, scenario="basic_combat")
    match_a.advance_ticks(30 * 60)   # 60 seconds
    match_b.advance_ticks(30 * 60)
    assert_eq(match_a.snapshot(), match_b.snapshot())
```

`snapshot()` returns a dictionary of all unit positions, HP, Farr, and resource counts. Equality must hold bitwise for ints, near-equal for floats with tight tolerance (1e-6). Drift past this means a determinism leak — flag immediately.

---

## 7. Telemetry Boundary

### Phase 0 ships:
- `EventBus.farr_changed(amount, reason, source_unit_id, tick)` — used by F2 debug overlay (CLAUDE.md mandate).
- `EventBus.unit_died(unit_id, killer_id, cause, tick)`.
- `EventBus.tick_started(tick)` / `EventBus.tick_ended(tick)` for profiling.

That's the minimum surface for the debug overlay framework and for QA assertions.

### Phase 6 ships (`MatchLogger`):
- Subscribes to all relevant EventBus signals, writes a structured log per match (NDJSON, one event per line).
- Used by balance-engineer for AI-vs-AI sim analysis.
- Used by qa-engineer for replay diffs.

### EventBus sink API (Phase 0)

EventBus exposes a passive-consumer hook so `MatchLogger` (and any other observer) can attach without modifying EventBus internals:

```gdscript
# autoload/event_bus.gd
extends Node

# ... typed signal declarations above ...

const _SINK_SIGNALS: Array[StringName] = [
    &"farr_changed", &"unit_died", &"ability_cast",
    &"tick_started", &"tick_ended", &"sim_phase",
    # extend as new write-shaped signals are added
]

func connect_sink(callable: Callable) -> void:
    for sig in _SINK_SIGNALS:
        get(sig).connect(func(...args): callable.call(sig, args))

func disconnect_sink(callable: Callable) -> void:
    # symmetric; iterate _SINK_SIGNALS and disconnect
    ...
```

Phase 6 `MatchLogger` calls `EventBus.connect_sink(_on_event)` once on match start, writes one NDJSON line per call. Adding a new sink-tracked signal in the future = adding it to `_SINK_SIGNALS`, no `MatchLogger` change. Phase 0 ships `connect_sink` even though no consumer uses it yet — locking the API now means Phase 6 is purely additive.

---

## 8. Worked Example: Cleaving Strike

Rostam's Cleaving Strike (`01_CORE_MECHANICS.md` §7.2) is a wide-arc melee AoE on 30s cooldown. This is the proof the contract is usable end-to-end.

```gdscript
# units/abilities/cleaving_strike.gd
class_name CleavingStrike extends SimNode

const COOLDOWN_TICKS: int = 30 * SimClock.SIM_HZ   # 30s = 900 ticks
const ARC_RADIUS: float = 6.0
const ARC_DEGREES: float = 120.0
const DAMAGE: int = 80

var _ready_at_tick: int = 0   # ability ready when SimClock.tick >= this

func can_cast() -> bool:
    return SimClock.tick >= _ready_at_tick

func cast(caster: Unit, facing: Vector3) -> void:
    assert(SimClock.is_ticking(), "Cleaving Strike cast off-tick")
    var enemies := SpatialIndex.query_radius_team(
        caster.global_position, ARC_RADIUS, Team.TURAN)
    for enemy in enemies:
        if _within_arc(caster.global_position, facing, enemy.global_position):
            var roll := GameRNG.combat.randi_range(-5, 5)
            enemy.get_health().apply_damage(DAMAGE + roll, caster)
    _set_sim(&"_ready_at_tick", SimClock.tick + COOLDOWN_TICKS)
    EventBus.ability_cast.emit(caster.unit_id, &"cleaving_strike", SimClock.tick)
```

What this demonstrates:
- Time via `SimClock.tick`, never wall-clock.
- Spatial query via `SpatialIndex.query_radius_team`, not a physics scan.
- Damage roll via `GameRNG.combat`, never `randi()`.
- Cooldown mutation via `_set_sim` — the assert catches off-tick casts.
- Telemetry via `EventBus`, no string-form `emit_signal`.
- Reads work-in-arc geometry freely (pure read).

Eight lines of mutation, all on-tick, all replayable, all testable with `MockPathScheduler` + `advance_ticks`.

---

## Appendix: Design notes on equivalent options

**`SimNode` base class vs `SimMutation` autoload.**
Both implement the same assert. `SimNode` chosen because:
- The check is *intrinsic* to a component's identity. Extending `SimNode` declares "I hold gameplay state." Calling a global `SimMutation.write(self, prop, val)` is just discipline.
- `_set_sim` is shorter at the call site than `SimMutation.write(self, ...)` and reads naturally.
- Subclassing forces a structural relationship that grep can find: every `extends SimNode` is an audit point. Autoload calls are stringly-discoverable at best.

The lint rule covers the case where someone forgets to extend `SimNode` at all; `SimNode` covers the case where they extended it but mutated wrong.

**Tick rate (30Hz vs 20 vs 60).**
30Hz gives ~33ms responsiveness — comfortable for RTS commands (humans don't notice sub-50ms input latency in this genre). 20Hz frees CPU for sims but feels chunky on `request_move`. 60Hz is wasted; nothing in our spec needs sub-33ms granularity. Locked at 30, revisitable post-Phase-2 with profiling data.

**SpatialIndex rebuild vs incremental update.**
Rebuild is O(N), trivially correct, and at 100-200 units takes microseconds. Incremental updates (move agent X from cell A to cell B) save work but need careful handling of the agent-currently-in-flight case. Not worth the bug surface for MVP.

---

*End of v1. Pending sign-off from ai-engineer and qa-engineer. Changes after sign-off require a Sync 2.*
