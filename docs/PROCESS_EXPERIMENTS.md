---
title: Process Experiments — Controlled Tests of Studio Process Changes
type: log
status: append-only
version: 1.2.0
owner: lead
summary: Append-only log of controlled experiments on the studio's working process. Plus the Known Godot Pitfalls list — engine foot-guns promoted from experiments. One entry per experiment — hypothesis, intervention, baseline, metrics, verdict. Prevents process-bloat-by-vibes; every change pays for itself or is dropped.
audience: all
read_when: kickoff-of-any-implementation-session
prerequisites: [docs/STUDIO_PROCESS.md, BUILD_LOG.md]
ssot_for:
  - active and historical process experiments
  - experiment baselines (which sessions are reference data)
  - verdicts on whether process changes were kept, dropped, or modified
  - Known Godot Pitfalls list (load-bearing engine foot-guns with regression locks)
references: [docs/STUDIO_PROCESS.md, BUILD_LOG.md, 02_IMPLEMENTATION_PLAN.md]
tags: [process, experiments, measurement, retro, pitfalls]
created: 2026-05-03
last_updated: 2026-05-13
---

# Process Experiments

## Why this exists

We were changing the studio's working process on vibes ("§9 rule added because that bit us once") instead of measuring whether changes actually help. N=1 incidents aren't a control group, and accumulated ceremony isn't free — it costs token spend, agent runtime, and lead attention.

This log enforces three rules:

1. **One intervention per session.** Hold everything else constant.
2. **Define metrics before the session starts.** Decide what "improvement" means upfront, not in retrospective rationalization.
3. **Verdict at session close.** Kept (intervention helped, cost justified), dropped (no improvement or net-negative), or modified (helped, but a cheaper variant might do the same).

A single session is N=1. Multiple sessions across a phase give directional signal. The goal isn't statistical significance — it's avoiding the failure mode where ceremony piles up forever because nobody asks "did this help?"

---

## Known Godot Pitfalls

Engine / GDScript foot-guns that have bitten this project in production. Each entry is backed by a specific incident commit and (where possible) a regression-lock test. **Every agent dispatch brief must include this list verbatim** so agents check against it before declaring done. New entries are added by godot-code-reviewer's wave-close audits when sufficient evidence accumulates ("KEEP" in their structured review output). Promoted from candidates to permanent here.

### #1 — Mouse filter on Control nodes

**Mechanism.** `Control.mouse_filter` defaults to `MOUSE_FILTER_STOP` (= 0). Any new HUD-style Control that isn't itself interactive will silently swallow clicks in its rect — cursor falls on the Control, ClickHandler / BoxSelectHandler never sees the event, looks like input is broken.

**Rule.** New decorative HUD Controls (Labels, Containers, Panels, custom `_draw` widgets) must set `mouse_filter = MOUSE_FILTER_IGNORE` (= 2) BOTH in the `.tscn` AND defensively at runtime in `_ready` if generated dynamically. The double-down is belt-and-braces because future scene-file edits don't always preserve property values.

**Canonical incident.** Phase 1 session 1 — HUD `MarginContainer` + Labels (Coin / Grain / Pop / Farr) ate clicks across the top 48 px of the screen. Lead's first interactive test caught it. Fix: commit `c583d48` set `mouse_filter = 2` on every HUD Control.

**Regression coverage.** `tests/integration/test_session_2_double_click_visual.gd` and the panel/overlay test suites assert `mouse_filter == MOUSE_FILTER_IGNORE` on every new Control they ship.

### #2 — FSM / per-tick driver wiring

**Mechanism.** Code inside a `RefCounted` State subclass (e.g., `UnitState_Moving._sim_tick`) only runs when something calls `fsm.tick()`. Tests typically call `fsm.tick(SimClock.SIM_DT)` directly. The live game needs a per-tick driver — a system that listens to `EventBus.sim_phase` and ticks each unit's FSM during the appropriate phase. Without that driver, states are dormant: enter() and exit() fire on transitions but `_sim_tick` is never reached.

**Rule.** Every new state or component that depends on `_sim_tick` to make progress must have a verifiable per-tick driver. Until the proper phase coordinator (e.g., `MovementSystem`, `CombatSystem`) ships, the transitional shape is `Unit._on_sim_phase(phase, _tick)` subscribing to `EventBus.sim_phase` and calling `fsm.tick(SimClock.SIM_DT)` when `phase == &"movement"` (or the relevant phase). Document the LATER coordinator-replacement comment in the source.

**Canonical incident.** Phase 1 session 1 — `UnitState_Moving._sim_tick` polled the path scheduler and stepped position, but nothing in the live scene called `fsm.tick()`. Tests called it directly. Live game silently ignored right-clicks. Fix: commit `c583d48` added `Unit._on_sim_phase` driver.

**Regression coverage.** `tests/integration/test_click_and_move.gd::test_on_sim_phase_drives_fsm_tick` exercises the full chain `EventBus.sim_phase → Unit._on_sim_phase → fsm.tick → state._sim_tick` rather than calling `fsm.tick` directly.

### #3 — Camera basis transform on screen-axis input

**Mechanism.** When the camera rig has a yaw/pitch (e.g., `camera_rig.tscn` has +45° yaw + 55° pitch), screen-axis input (mouse position, edge-pan axis, WASD axis) does NOT translate directly to world axis. Applying a screen-axis vector to `target_position` without rotating through `global_transform.basis` gives motion that drifts relative to where the camera is actually pointing.

**Rule.** Camera-relative motion (pan, edge-pan, screen-zoom-toward-mouse) must rotate the screen-axis vector through the camera rig's `global_transform.basis` before applying to world position. Headless test fixtures usually have identity basis so the bug is invisible there — only the live game with the rig's actual rotation surfaces it.

**Canonical incident.** Phase 1 session 1 — edge-pan moved opposite to the camera-look direction. WASD was correct (sign convention coincidentally aligned for identity basis); edge-pan inverted Y-sign too, so the two paths cancelled. Fix: commit `c583d48` rotates by `global_transform.basis` and aligns edge-pan / WASD sign conventions.

**Regression coverage.** `tests/unit/test_camera_controller.gd` covers the `pan_by` / `compute_edge_pan_axis` math; lead live-test catches direction.

### #4 — Re-entrant signal mutation

**Mechanism.** A handler subscribed to a state-holder's broadcast signal (e.g., `EventBus.selection_changed`) mutates the same state-holder synchronously inside the handler. The mutation triggers nested signal emissions, but Godot's signal-receiver iteration order means the OUTER emit's payload (now stale) is delivered to other receivers AFTER the inner emits unwind. Receivers later in the iteration see the stale payload and undo the inner mutations' work.

**Rule.** Don't mutate a state-holder from inside its own broadcast handler. If you must, defer the mutation via `call_deferred` so it runs after the outer emit fully unwinds. Default: handlers are read-only against the emitter; if you need to mutate, route through a deferred call or a separate signal that fires from a clean stack.

**Canonical incident.** Phase 1 session 2 — `DoubleClickSelect._on_selection_changed` called `SelectionManager.deselect_all` + `add_to_selection` × 5 inside the handler. Inner emits set all 5 SelectableComponents' rings ON; outer emit then continued with stale `[1]` payload, turning 4 of 5 rings OFF. Fix: commit `cb95d09` defers `_expand_to_visible_of_type.call_deferred(target)`.

**Regression coverage.** `tests/integration/test_session_2_double_click_visual.gd::test_signal_driven_double_click_makes_all_rings_visible` reproduces the bug headlessly via real Kargar instances + actual `SelectableComponent` ring assertions.

### #5 — Sibling tree-order load-bearing for `_unhandled_input`

**Mechanism.** When two or more sibling Nodes both implement `_unhandled_input`, Godot delivers the event in **reverse-tree-order** (later siblings first). If both consume the event via `set_input_as_handled()`, only the first one to process it wins. Reordering siblings in the `.tscn` silently changes which handler runs.

**Rule.** Any handler that needs first crack at an event must be placed LATER in sibling order than competing handlers. Document the dependency in the file header and add a regression test asserting the order in `main.tscn`. For more than 2 competing handlers, consider explicit `process_priority` on each, OR a dispatcher Node.

**Canonical incident.** Phase 2 session 1 wave 2B — `AttackMoveHandler` must consume left-press BEFORE `ClickHandler` interprets it as a single-click select, otherwise A+click is silently broken. Order documented in `attack_move_handler.gd` header and `main.tscn` as `... AttackMoveHandler → ClickHandler ...`.

**Regression coverage.** `tests/integration/test_phase_2_session_1_combat.gd::test_main_tscn_attack_move_handler_before_click_handler` and `test_pitfall_5_*` assert `amh.get_index() < ch.get_index()` on the live `main.tscn`.

### #8 — `Node.queue_free.call_deferred()` is double-deferred

**Mechanism.** `node.queue_free()` itself queues the free for end-of-frame. `node.queue_free.call_deferred()` queues `queue_free` for end-of-frame, AND `queue_free` then queues the actual deletion for end-of-NEXT-frame. So tests verifying "node is freed after deferred queue_free" need 2+ `await get_tree().process_frame` calls (unit-test variant) or 3 (integration runner has more pending deferreds in queue).

**Rule.** Use `node.queue_free()` directly when you're already off-tick (signal handlers in non-mutating contexts, `_process`, etc.). Reserve `queue_free.call_deferred()` for cases where you're CERTAIN you're in a tree-mutating context (mid-state-transition like `UnitState_Dying.enter`). When using `.call_deferred()`, tests must `await get_tree().process_frame` AT LEAST TWICE to observe the actual free.

**Canonical incident.** Phase 2 session 1 wave 3 BUG-03 fix — `UnitState_Dying.enter()` calls `ctx.queue_free.call_deferred()` because it's running inside `StateMachine._apply_transition` (a tree-mutating context). The regression test originally awaited only one `process_frame` and reported "unit not freed" — bumped to 2-3 awaits in commit `6590a16`.

**Regression coverage.** `tests/unit/test_unit_state_dying.gd` and `tests/integration/test_phase_2_session_1_combat.gd::test_bug03_dying_state_frees_unit_after_lethal_damage` both await multiple `process_frame` and have inline comments documenting why.

### #11 — `queue_free.call_deferred()` never resolves inside `SimClock._test_run_tick()` integration loops

**Mechanism.** Distinct from #8. #8 covers the unit-test case where deferred frees need 2+ `await get_tree().process_frame` calls. **In integration tests that drive ticks via `SimClock._test_run_tick()` in a tight loop**, NO `process_frame` happens between iterations — the loop is synchronous from Godot's perspective. The deferred free is enqueued but NEVER fires. So `is_instance_valid(unit)` stays `true` indefinitely after `hp_x100 ≤ 0`, even after the Dying state has called `queue_free.call_deferred()`.

Tests that use `is_instance_valid(unit)` as a death-detection predicate inside a `_test_run_tick` loop will hang forever (or until the loop-tick cap), because the unit appears alive even though its HP is zero and its FSM is in Dying state.

**Rule.** In integration tests using `SimClock._test_run_tick()` loops, **never use `is_instance_valid(unit)` as a combat-outcome predicate.** Use end-state predicates the simulation actually produces synchronously:
- `int(unit.get_health().hp_x100) <= 0` — HP-based death detection. The HealthComponent's `_set_sim` writes `hp_x100` before queueing the death, so this becomes true the same tick.
- `unit.fsm.current.id == &"dying"` — FSM-state-based detection.

Document the choice in the test file header so future readers don't re-derive it.

**Canonical incident.** Phase 2 session 2 wave 3 (qa-engineer) — initial draft of `test_phase_2_session_2_rps_combat.gd` used `is_instance_valid(unit)` for 6 of 17 RPS-outcome tests. All 6 hung at the tick-cap. Fix: switched to `hp_x100 ≤ 0` synchronous check. Surfaced again independently by `godot-reviewer-p2s2` (suggestion S4), `arch-reviewer-p2s2`, and confirmed by `godot-reviewer-pr9` in PR-attached review. Documented in ARCHITECTURE.md §6 v0.18.2.

**Regression coverage.** `tests/integration/test_phase_2_session_2_rps_combat.gd` file header docs the pattern explicitly. Future combat-outcome tests should reference this as the canonical example.

### Cluster preamble — GDScript class-identity asymmetry (#12 + #13)

Pitfalls #12 and #13 are two halves of the same architectural seam: GDScript's `class_name` registry lives at a layer Godot's runtime reflection APIs (`Engine.has_singleton`, `Engine.get_singleton`, `Node.get_class()`) do not see. The reflection APIs operate at the C++/GDExtension layer and treat GDScript class_names as transparent to them. **Two known surfaces below; a third surface (the `is <ClassName>` operator) is empirically unverified at promotion time** — godot-code-reviewer flagged a probe test as post-promotion work; if the `is` operator fails the same way against path-string-extends GDScript classes, a future Pitfall #14 promotion captures the third half. Until then, the project convention sidesteps the `is` operator with class_name types entirely (duck-typing is preferred). Both Pitfalls #12 and #13 are promoted as a single thematic cluster so future readers see "if you need GDScript class identity at runtime, here are the wrong APIs and the right ones."

### #12 — Engine.has_singleton / get_singleton + bare-identifier parse failure for forward-declared autoloads

**Mechanism (two-part).**

**(a) Parse-time.** Code that uses `FogSystem.register_vision_source(...)` syntactically references the bare identifier `FogSystem`. If `FogSystem` is a GDScript autoload that hasn't shipped yet (or is a forward-declared script-class), GDScript fails to parse the file at engine load. The bare identifier is unresolvable at parse-time even when the surrounding code is dead behind a guard.

**(b) Runtime.** `Engine.has_singleton(&"FogSystem")` returns FALSE for GDScript autoloads — i.e., autoloads registered via `project.godot`'s `[autoload]` section with `*res://...` syntax. The `Engine.singleton` API is for C++/GDExtension singletons only and does NOT see GDScript autoloads. A guard pattern using `Engine.has_singleton` to detect a GDScript autoload's presence always returns false; the guarded code never runs.

**Rule (two-part).**

**(a) Parse-time:** sidestep the bare identifier with `Engine.get_singleton(&"FogSystem")` (takes a StringName at parse-time; no bare identifier reference) followed by `.call(&"method_name", ...)` instead of direct method-call syntax. The parse-time bare-identifier reference is replaced by a runtime string lookup.

**(b) Runtime:** detect a GDScript autoload's presence via `SceneTree.root.get_node_or_null(NodePath(autoload_name))` — GDScript autoloads register as direct SceneTree children under their registered name. Reuse the `_autoload_or_null` helper pattern (canonical implementation: `farr_gauge.gd:261-268` and `resource_hud.gd:183-186`):

```gdscript
func _autoload_or_null(autoload_name: StringName) -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    var root: Window = tree.root
    if root == null:
        return null
    return root.get_node_or_null(NodePath(autoload_name))
```

Then call via `.call(&"method_name", ...)` per part (a).

**Canonical incident.** Phase 3 session 2 wave 1A — `mazraeh.gd:135-138` (FogSystem guard) and `:207-212` (TerrainSystem guard) used `Engine.has_singleton(&"FogSystem")` + `Engine.get_singleton`. The `Engine.has_singleton` call always returned false, so the fog-source registration was silently disabled. Would have surfaced as "Mazra'eh never appears in fog reveal" after FogSystem ships in wave 3A — a latent bug hidden by the forward-compat guard for >1 wave. The project's own `farr_gauge.gd:257-260` and `resource_hud.gd:183-186` had already documented the runtime gotcha with explicit prose. The wave-1A implementer didn't find the established correct pattern; godot-code-reviewer-p3s2 caught it at re-review as a CONVERGENT finding with arch-reviewer-p3s2. Fix at commit `6d73889` introduced the `_autoload_or_null` helper at `mazraeh.gd:143-147` (mirroring `farr_gauge.gd:261-268`).

**Regression coverage.** `tests/unit/test_mazraeh.gd::test_mazraeh_does_not_crash_when_fogsystem_is_absent` exercises the FogSystem-absent path. The present-autoload path requires a temporary-autoload scaffold not yet in the test infrastructure; flag for wave 3A's qa-engineer scope.

### #13 — Node.get_class() returns C++ base type for path-string-extends GDScript classes

**Mechanism.** A GDScript class declared `class_name Madan` that uses path-string `extends "res://path/to/base.gd"` (instead of `extends BaseClass`) does NOT register correctly with Godot's runtime `get_class()` reflection. `node.get_class()` always returns the C++ ancestor type (e.g., `"Node3D"`, `"CharacterBody3D"`), regardless of the declared `class_name`. The `class_name` registry is a GDScript-layer concept; `get_class()` walks the C++/GDExtension class hierarchy and is blind to GDScript class_name declarations on path-string-extends classes.

This affects two failure modes:
- **Class-identity check:** `if node.get_class() == "Madan":` always evaluates false for path-string-extends Madan instances, even though the class is declared correctly.
- **Class-name-by-string lookup:** code that filters or routes nodes by their declared class name via `get_class()` will silently skip path-string-extends classes.

**Rule.** To retrieve a GDScript class's declared name at runtime, use `node.get_script().get_global_name()` — this reads the class_name from the script-resource layer (GDScript-side) rather than the engine reflection layer (C++-side). Returns the declared `class_name` StringName, or `&""` if the class has no class_name. Example:

```gdscript
var node_script: Script = node.get_script()
if node_script != null:
    var declared_name: StringName = node_script.get_global_name()
    if declared_name == &"Madan":
        # node is a Madan instance via class_name registry
```

The same gotcha bites `Object.is_class(name)` for the same reason — it walks C++ hierarchy. Use `Script.get_global_name()` for class_name identity; use duck-typing (`has_method`, `&"field_name" in node`) for capability identity when class_name identity is not required.

**Why path-string-extends is the established project convention.** The project uses `extends "res://..."` instead of `extends BaseClass` to sidestep the GDScript class_name registry race documented in `ARCHITECTURE.md §6 v0.4.0`. This is a deliberate trade-off — path-string-extends preserves load-time stability at the cost of losing `get_class()`-based class-identity checks. The Pitfall #13 rule formalizes the trade-off: use `Script.get_global_name()` instead.

**Canonical incident.** Phase 3 session 2 wave 1B Commit 3.5 — qa-engineer-p3s2's initial draft of `test_madan_class_name_is_madan_no_apostrophe` (in `test_madan_buffs_mine_extraction.gd`) used `_madan.get_class()`. The test failed with `expected "Madan", got "Node3D"`. The fix in the same commit `9ade2bd` switched to `_madan.get_script().get_global_name()`. qa-engineer documented the failure mode + fix in the commit body. Surfaced and resolved within ~5 minutes; promotion-worthy because the failure-mode is invisible from `class_name Madan` source inspection alone (the source looks like it should work; only the runtime reflection layer exposes the asymmetry).

**Regression coverage.** `tests/integration/test_madan_buffs_mine_extraction.gd::test_madan_class_name_is_madan_no_apostrophe` (lines ~353-372) uses `Script.get_global_name()` and asserts `&"Madan"`. Use as the canonical pattern for future class-name regression-lock tests across the project (Mazra'eh, Khaneh, future Sarbaz-khaneh, etc.).

### #14 — GDScript lambda capture of reassigned locals is unreliable

**Mechanism.** GDScript lambda expressions (`func(...): ...`) capture enclosing-scope locals **by value at lambda-creation time**. If the captured local is reassigned in the enclosing scope AFTER the lambda is created, the closure does NOT see the new value — the lambda holds its capture-time snapshot. Tests that use a lambda to read a state value that gets mutated by a subsequent operation (e.g., a signal handler, a state-transition, an await) will assert against the stale snapshot, not the engine's current state.

This is distinct from Pitfall #9 (the candidate "primitive-int capture-by-value" pattern that was REJECTED for lack of evidence in Phase 2 session 1). Pitfall #14 is the broader, evidence-backed form: ALL reassigned locals, not just primitive ints. The mechanism is consistent — GDScript closures snapshot at creation, not lazy-read at invocation. Promoted to permanent at Phase 3 session 3 close after two independent incidents:

**Canonical incident 1 (gp-sys-p3s3, session-3 wave-1C Track 1 follow-on).** During development of the construction_finalized emit-ordering test (now in `test_unit_state_constructing.gd`), gp-sys-p3s3's first version used a lambda closing over `mazraeh.is_gatherable` for the post-emit readout:

```gdscript
# WRONG — lambda captures mazraeh.is_gatherable by value at lambda-creation
var captured_value: bool
var handler = func(_placer_id: int) -> void:
    captured_value = mazraeh.is_gatherable   # ← This reads the CURRENT value
                                              #   when the lambda fires (correct
                                              #   in this case), but the broader
                                              #   pattern below fails.

# WORSE — typical pattern where the bug shows up
var observed_state: Variant = null
var watcher = func(_placer_id: int) -> void:
    observed_state = mazraeh.is_gatherable
# ... later in test ...
some_signal.connect(watcher)
some_signal.emit(0)   # watcher runs; observed_state gets a value
mazraeh.is_gatherable = true   # ← reassignment AFTER lambda creation
                                #   doesn't propagate to the lambda's captured
                                #   snapshot if the captured local was a LOCAL
                                #   to the test method that the lambda closed
                                #   over.
assert_eq(observed_state, true, "...")   # asserts against stale snapshot
```

The actual mechanism is subtle: when the lambda closes over a node-property access path (`mazraeh.is_gatherable`), each invocation re-reads the property — so the lambda DOES see the latest value at fire time. But when the lambda closes over a **local variable** that the test method reassigns, the lambda holds the capture-time value. The asymmetry between property-path closure (re-reads on each fire) and local-variable closure (snapshots on lambda-creation) is the trap.

gp-sys-p3s3's fix: restructure to post-loop SceneTree readout (`mazraeh.is_gatherable` read directly after the signal fires, with no lambda intermediary). The read happens in test-method scope at the right time, no closure involved.

**Canonical incident 2 (ui-developer-p3s3, session-3 wave-1C Track 2A regression test).** During development of `test_repeated_ensure_connect_does_not_duplicate_signal_wires` (in `test_construction_progress_overlay.gd`), ui-developer-p3s3 explicitly chose the **Signal-introspection pattern** over a lambda-based observer — knowing the carry-forward from gp-sys's prior incident:

```gdscript
# RIGHT — use Signal.get_connections().size() directly, no lambda
func test_repeated_ensure_connect_does_not_duplicate_signal_wires() -> void:
    var building: Building = _make_test_building()
    # Establish wire once
    _overlay._ensure_signal_connected(building)
    assert_eq(building.construction_progress_updated.get_connections().size(), 1,
        "First _ensure_signal_connected establishes one connection")
    # Re-invoke N times — should be idempotent
    for i in range(10):
        _overlay._ensure_signal_connected(building)
    assert_eq(building.construction_progress_updated.get_connections().size(), 1,
        "Repeated _ensure_signal_connected MUST NOT add duplicate connections")
```

`Signal.get_connections()` reads the engine's connection table directly at the moment of the assertion — no closure, no snapshot, no reassignment trap.

**Operational mitigations** (apply per case):

1. **Default pattern — post-await SceneTree readout.** Read the state directly from the SceneTree in test-method scope after the operation completes. No closure intermediary.

   ```gdscript
   # Drive the state change
   some_signal.emit(0)
   await get_tree().process_frame
   # Read directly
   assert_eq(mazraeh.is_gatherable, true)
   ```

2. **Signal-watching pattern — `Signal.get_connections().size()` for signal-wiring tests.** When testing whether signals are correctly connected (or not duplicated), read the engine's connection table directly.

3. **Sentinel-append pattern — lambda appends to outer-scope sentinel array; test reads array contents post-await.** When you genuinely need a lambda observer (e.g., capturing a signal's payload), have the lambda APPEND to an outer-scope `Array` and read the array contents post-await. Arrays are passed by reference in GDScript, so the lambda's append IS visible to the enclosing scope.

   ```gdscript
   var observed_payloads: Array = []
   var watcher = func(payload: int) -> void:
       observed_payloads.append(payload)
   some_signal.connect(watcher)
   some_signal.emit(42)
   await get_tree().process_frame
   assert_eq(observed_payloads, [42])
   ```

**Regression coverage.** `tests/unit/test_unit_state_constructing.gd:784-786` documents the by-value-capture limitation with the sentinel-append workaround inline as a teaching example. `tests/unit/test_construction_progress_overlay.gd::test_repeated_ensure_connect_does_not_duplicate_signal_wires` (lines ~395-413) is the canonical Signal-introspection pattern.

**Cross-reference.** This pitfall pairs with the §9 cluster's **"Signal-introspection over lambda-capture for signal-wiring tests"** rule (2026-05-17, consumer-side-integration cluster). The §9 rule prescribes WHEN to apply the introspection pattern; this pitfall explains WHY the lambda alternative is unreliable.

### #15 — Godot inherited-scene nested-child override syntax

**Mechanism.** When a `.tscn` uses `instance=ExtResource(...)` to inherit from a base scene, overriding a node nested under another inherited node requires the path in the `parent=` attribute, NOT a slash-separated literal in the `name=` attribute. The Godot parser treats `/` in a `name=` value as a literal character — there is no auto-split into path components. The malformed declaration looks plausible to a human reader but the engine cannot resolve it: at scene load, Godot emits a `Node vanished` / `node not found` warning and silently leaves the base's value of the targeted node intact. The override never takes effect; the subclass appears to ship with subclass-specific properties but renders with base-class values.

Specifically: a subclass scene that inherits `building.tscn` (which contains `StaticBody3D > CollisionShape3D`) and wants to override the inner `CollisionShape3D.shape` cannot write `[node name="StaticBody3D/CollisionShape3D" parent="." index="0"]`. The slash is a literal; the engine looks for a child of `.` literally named `"StaticBody3D/CollisionShape3D"`, fails to find one, drops the override on the floor, and the base's `BoxShape3D` survives — silently.

**Silent-override signature (P3S4 retro addendum, 2026-05-17).** The malformed form does not crash or abort scene load. The scene instantiates cleanly, the visual mesh renders at the subclass dimensions (if a separate sibling-node override of MeshInstance3D succeeded), and no lint rule catches the form. Only indicators at runtime: (a) Godot warning `Node '<path>' was modified from inside an instance, but it has vanished.` in the editor / headless log (easily missed when the log scrolls past during a `bash run_tests.sh` invocation), and (b) behavioral divergence detectable only via the structural regression test or live-test (workers walking through what should be a blocked footprint). This pitfall is in the "plausible-but-wrong" category — the syntax looks credible to a human reader of `.tscn` files — which gives it its bite. Future implementors should expect "no error, wrong behavior" as the runtime signature.

**Trigger-condition refinement — when you're in new territory (P3S4 retro addendum).** The pitfall surfaces specifically when a subclass first introduces a property override on a node that is a grandchild (or deeper) of the inherited root. As long as subclasses only override sibling nodes of the inherited root (e.g., MeshInstance3D directly under the root), the issue does not surface. The first time a subclass needs to override a nested grandchild's property (e.g., CollisionShape3D under StaticBody3D under the root), the override-syntax surface is exercised for the first time. **Rule for new subclasses:** if you are overriding a property on a node that is NOT a direct child of the inherited scene's root, you are in nested-child override territory; the regression-test pattern below is mandatory in the same commit. This pairs with STUDIO_PROCESS.md §9 2026-05-17 (session-4) implementation-pattern cluster: "Inherited-scene-with-nested-overrides: instantiate-and-walk regression test mandatory at first occurrence."

**Rule.** When overriding a node nested under another inherited node in an inherited-scene `.tscn`, put the path in the `parent=` attribute (relative to the inherited root), and the bare node name in `name=`. The `index=` attribute is unnecessary on overrides (it's for new additions). Correct form:

```
[node name="CollisionShape3D" parent="StaticBody3D"]
shape = SubResource("BoxShape3D_subclass_override")
```

NOT:

```
[node name="StaticBody3D/CollisionShape3D" parent="." index="0"]
shape = SubResource("BoxShape3D_subclass_override")
```

**Canonical incident.** Phase 3 session 4 wave 2A — `sarbaz_khaneh.tscn` shipped with the wrong form in commit `1ff3039`. The Sarbaz-khaneh's intended 3.0×1.2×2.0 collision shape silently fell back to the base `building.tscn`'s 2.0×1.2×2.0. Visible signature at runtime: the building rendered at 3.0×2.0 XZ footprint (mesh override worked) but the navmesh source-geometry parse picked up the inherited 2.0×2.0 collision body — workers walked through the long-axis strips of Sarbaz-khaneh's actual visual silhouette. First subclass to override `CollisionShape3D` because the first subclass with a non-base footprint inheriting `building.tscn` — Khaneh kept 2.0×2.0; Mazra'eh and Ma'dan are standalone scenes (not inherited). Detected via live-test (workers visibly walking through the building) + log warning (`Node './StaticBody3D/CollisionShape3D' was modified from inside an instance, but it has vanished.`). Fix at commit `2f31b34`.

**Regression coverage.** `tests/unit/test_sarbaz_khaneh_scene.gd::test_collision_shape_matches_mesh_footprint` instantiates the scene and asserts `box.size.x == 3.0` — if the override silently fails the inherited 2.0 value is what gets read and the test fails. Use as the canonical pattern for future inherited-scene-with-nested-overrides tests: instantiate the scene, walk to the override target, assert the property has the subclass value, not the base.

**Project-wide audit (godot-code-reviewer fresh-spawn at PR #19, 2026-05-17):** No other instances of this syntax bug exist in `game/scenes/`. Building subclass inheritance audited cleanly — Khaneh inherits building.tscn but doesn't override CollisionShape3D (keeps base 2.0×2.0); Mazra'eh + Ma'dan are standalone Node3D scenes (not inherited); UI scenes don't use inherited-scene composition with nested-child overrides. Sarbaz-khaneh's larger footprint was the first occasion for the syntax surface to be exercised, exposing the pitfall at first incidence.

### #16 — `as Node3D` cast crashes on freed Object (nominal-safe operator is NOT safe on freed instances)

**Mechanism.** Godot's `as <Type>` cast operator is documented as null-safe — applied to `null`, it returns `null` rather than throwing. **It is NOT safe on a freed `Object` instance.** When applied to a Variant that holds a reference to an Object that has been `free()`'d or `queue_free()`'d and reaped, the cast triggers a script error before reaching any subsequent expression. The error is *"Attempted to cast a previously freed Object."* The pattern that LOOKS safe by analogy with null-checks is the trap:

```gdscript
# WRONG — `as Node3D` crashes if `record.node` is a freed Object
for record in _sources.values():
    var node: Node3D = record.node as Node3D
    if not is_instance_valid(node):  # ← never reached; cast already crashed
        continue
    # ... use node ...
```

The cast runs FIRST. If `record.node` is a freed Object, the cast crashes. `is_instance_valid()` never gets to fire.

**Rule.** When iterating a registry whose values may include freed Objects, validate with `is_instance_valid()` BEFORE casting. The safe pattern reads the Variant first, validates, then casts:

```gdscript
# RIGHT — read Variant, validate, then cast
for record in _sources.values():
    var node_v: Variant = record.node  # untyped Variant — does not crash on freed
    if not is_instance_valid(node_v):
        continue
    var node: Node3D = node_v as Node3D
    # ... use node ...
```

**Canonical incident.** Phase 3 session 7 Wave 3A.5 — world-builder-p3s2's `fog_system.gd::_on_fog_update_phase` original implementation cast Variant to `Node3D` before the `is_instance_valid()` check. Cross-track diagnostic from gp-sys-p3s3 at staging-time caught the failure (`test_fog_update_stale_source_cleanup` in `test_fog_system.gd`). Fix landed in world-builder's Track 1 ship `a6e6752` before commit propagated. **No fix-wave required** — the §9.D7(b) discipline closed the gap.

**Audit surface.** Defensive iteration over registry values (`_sources`, `_modifier_emitters`, `_last_seen_by_team`, future autoload-internal registries) is the high-risk pattern. Any `for record in <dict>.values()` followed by `as <Type>` cast without prior `is_instance_valid()` is suspect.

**Why it bites.** Documentation describes `as` as null-safe; the freed-object crash is undocumented behavior at the language level (the engine's GDScript bytecode interpreter raises the script error rather than the cast operator returning a sentinel). The pattern looks safe by analogy with idiomatic null-checks elsewhere. Pitfall #12 / #13 / #14 / **#16** are the GDScript-safety-pattern foot-gun family — each looks idiomatic, each crashes silently or with a script error in a non-obvious way.

**Regression coverage.** `test_fog_system.gd::test_fog_update_stale_source_cleanup` exercises the freed-node iteration path. Any future helper iterating possibly-freed registry values should include an equivalent regression test.

### #17 — `await get_tree().process_frame` leaks physics ticks into SimClock

**Mechanism.** When a GUT test calls `await get_tree().process_frame`, Godot's main loop advances one frame, which fires `_physics_process` on ALL autoloads including SimClock. SimClock's `_physics_process` accumulates `delta` into `_accumulator` and, when the accumulator crosses `1.0 / SIM_HZ` (33.33ms at 30 Hz), invokes `_run_tick` — advancing `SimClock.tick` and `SimClock.sim_time`. **The await leaks SimClock ticks into the test's surrounding state.** A test that asserts against `SimClock.tick` after the await observes mutated state, NOT the pre-await snapshot.

The downstream cost: tests that follow this pattern silently advance SimClock, breaking `test_match_harness` pre-conditions (which assert specific SimClock state) AND breaking determinism guarantees of any downstream simulation test that expected the SimClock to be at a known value.

**Rule.** For assertion-immediate-after-spawn cases (where the test does not require a fully rendered frame), use **synchronous `free()` instead of `queue_free()` + await**. The synchronous free does not consume an engine frame; SimClock does not advance. The valid form:

```gdscript
# WRONG — leaks 1+ SimClock ticks
test_node.queue_free()
await get_tree().process_frame
assert_some_post_free_state(...)

# RIGHT — no engine frame consumed
test_node.free()
assert_some_post_free_state(...)
```

When the test legitimately requires a rendered frame (visual smoke tests, multi-frame physics interactions), the pattern is permitted but **the test must opt-in explicitly** by snapshotting `SimClock.tick` at `before_each` and asserting in `after_each` that the test stayed within an expected delta. Pairs with the future engine-side guard (engine-architect's session-7 proposal: `SimClock._physics_process_enabled` flag flipped false in test fixtures).

**Canonical incident #1.** Phase 3 session 7 Wave 3A.5 — world-builder-p3s2's `test_fog_update_stale_source_cleanup` originally used `queue_free()` + `await get_tree().process_frame`. Pre-commit gate caught a downstream `test_match_harness` failure because the await leaked 4 physics ticks into SimClock. Fix landed in Track 1 ship `a6e6752`.

**Canonical incident #2.** Phase 3 session 7 Wave 3A.6 — ui-developer-p3s3 hit the SAME pattern on a different test (`test_panel_auto_closes_on_building_free` and `test_close_clears_rows` in `test_production_panel.gd`). Pre-commit gate caught it during their first commit attempt. They replaced with direct `_process(0.0)` drive + synchronous Dict cache assertions before re-commit. **N=2 confirmation in two consecutive waves.**

**Audit surface.** Every GUT test that uses `queue_free()` + `await get_tree().process_frame` followed by SimClock-sensitive assertions. Use `free()` unless a rendered frame is genuinely needed.

**Why it bites.** The await pattern is idiomatic Godot — common across the engine's own examples and community tests. The fact that it implicitly drives the project's deterministic-tick autoload is non-obvious; tests appear to work in isolation but fail when SimClock-coupled neighbors run in the same suite. The failure mode is downstream-only: the failing test is NOT the test that uses the await; it's some other test that asserts against SimClock state.

**Engine-side fix (engine-architect-p3s2's session-7 proposal — DEFERRED to a future wave).** Add `SimClock._physics_process_enabled: bool = true` flag (default true for production). Test fixtures flip false in `before_each`, true in `after_each`. When false, `_physics_process` short-circuits to a no-op. Engine guard scales O(1) vs test-discipline O(test-author-vigilance). Pairs with the test-side regression-lock pattern (snapshot `SimClock.tick` + `sim_time` in `before_each`; assert no change in `after_each` unless test opts in).

**Regression coverage.** Existing `test_fog_system.gd` + `test_production_panel.gd` use the fixed pattern. Project-wide audit candidate (gp-sys's session-7 retro offer): the ~15 defensive-cascade helpers + any other test using `queue_free()` + `await get_tree().process_frame` should be swept for the same shape.

### Candidate / deferred entries (not yet load-bearing)

| Candidate | Status | Reason |
|---|---|---|
| #6 — Cause-string suffix conventions are domain language | DEFERRED | Currently one consumer (`_idle_worker` → FarrSystem). Promote when a 2nd suffix ships — `_fleeing` / `_engaged` / `_ranged` will provide the pattern-validation needed. |
| #7 — Multi-agent shared-tree commit-staging race | KEPT IN PROCESS DOC, not Godot list | This is a process pattern, not engine. Lives in `STUDIO_PROCESS.md` §9 + `Deviation 02`. |
| #9 — GDScript lambda primitive-int capture-by-value | SUPERSEDED BY #14 (2026-05-17) | godot-code-reviewer's audit found no evidence in Phase 2 session 1 diff at original assessment; Phase 3 session 3 produced the broader form. The reassigned-locals capture-by-value mechanism is now formalized as Pitfall #14 (covers primitive-int + all other reassigned-local types). |
| #10 candidate — MockPathScheduler tick-1 latency vs per-tick reissue starves resolution | DEFERRED | Surfaced during BUG-06 fix. Tests using `MockPathScheduler` with per-tick `request_repath` re-issue (e.g., `UnitState_Attacking._sim_tick` out-of-range branch) will starve path resolution — each new request cancels the prior PENDING. Workaround: in-file `_InstantPathScheduler` synchronous-resolve stub (see `tests/integration/test_phase_2_session_1_combat.gd`). Promote when a 2nd test author hits this independently. |

## Format for new entries

```
## Experiment NN — short name (YYYY-MM-DD start)

**Sessions:** which sessions this experiment ran across (e.g., "Phase 1 session 2")
**Hypothesis:** what we expect the intervention to change. Be specific — "X reduces Y by ≥Z%."
**Intervention:** what we're doing differently. Held-constant: list what's NOT changing.
**Baseline:** what session/data we're comparing against, with numbers.
**Metrics:** the table we'll fill at session close. Columns: metric / how-measured / baseline / actual.
**Verdict:** Kept / Dropped / Modified. Filled at session close.
**Notes:** any caveats, surprises, or follow-up experiments suggested.
```

## Active experiments

### Experiment 01 — Live-game-broken-surface section in kickoff brief (2026-05-03)

**Sessions:** Phase 1 session 2 (single session for first verdict; may extend across more sessions if signal is unclear).

**Hypothesis:** Adding a "live-game-broken-surface" section to each deliverable's brief — forcing agents to enumerate what could fail at runtime despite passing tests — reduces live-game bugs found at boot by ≥50% with ≤20% increase in token spend.

**Intervention:** Each session-2 deliverable in `02c_PHASE_1_SESSION_2_KICKOFF.md` includes a sub-section the agent must answer before declaring done:

> *Live-game-broken-surface for this deliverable:*
> 1. What state/behavior must work at runtime that no unit test exercises?
> 2. What can a headless test not detect that the lead would notice in the editor?
> 3. What's the minimum interactive smoke test that catches it?

The agent commits answers alongside the code (in BUILD_LOG entry or commit body). Tests for the smoke-test scenarios are written too where feasible (e.g., scene-loading integration tests).

**Held constant** (NOT changed from session 1):
- Same kickoff-doc structure, same wave breakdown, same agent set, same TDD discipline, same pre-commit gate, same SemVer policy, same file-ownership rules.

**Baseline (Phase 1 session 1):**

| Metric | Session 1 value |
|---|---|
| Live-game bugs found at boot by lead | 3 (FSM not ticked, edge-pan direction, mouse_filter eating clicks) |
| Tests-pass-but-broken incidents | 1 fix pass containing all 3 bugs |
| Wave-3 (qa) bug catch rate | 0 / 3 (lead caught all live-game bugs; qa caught 0) |
| Test count delta | +69 wave 2, +9 wave 3 = +78 |
| Time kickoff → merge | ~24 hours wall clock |
| Total token spend (sum of agent task notifications) | TBD — recover from logs |
| LATER items surfaced | 2 (MovementSystem coordinator promoted, current_command lifetime) |

**Metrics captured at session 2 close (2026-05-03):**

| Metric | How measured | Baseline | Actual | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test count | 3 | 1 | **−67%** |
| Tests-pass-but-broken incidents | Count of post-test fix passes | 1 | 1 | unchanged |
| Wave-3 (qa) bug catch rate | qa caught / total live-game bugs | 0/3 | 0/1 | unchanged |
| Test count delta | New tests added | +78 | +162 (380→542) | +84 vs baseline |
| Time kickoff → merge | Wall clock | ~24h | ~3h (single-day session) | **−87%** |
| Total token spend | Σ task notification totals | ~unknown | ~unknown | not measured |
| LATER items surfaced | Count | 2 | 6+ across deliverables | +200%+ |
| Kickoff-doc writing time | Lead's wall clock | n/a (02b was ~2h) | ~1h (02c) | comparable |

**The 1 bug found and 2 visual nits:**

1. **Bug — re-entrant signal recursion in `DoubleClickSelect`** (commit `cb95d09`). Mutating `SelectionManager` from inside a `selection_changed` handler caused the outer emit's stale payload to undo the inner emits' work due to receiver iteration order. Fix: `call_deferred` on the expansion. **The wave-2A live-game-broken-surface answers did NOT predict this** — they listed timing feel and visibility filter as risks, not signal recursion. The category was outside the brief's prompts.
2. **Visual nit — HP bar red at full health** in selected-unit panel. Convention is green→yellow→red gradient. Polish item, not a bug. Spec didn't constrain colors.
3. **Visual nit — Farr gauge low contrast** against sandy terrain. Polish item.

**Verdict:** **KEPT WITH REFINEMENT.**

Justification:
- Live-game bugs at boot: 1 ≤ 1 (threshold met).
- Time-to-merge: dramatically improved (3h vs 24h) — but this is confounded; session 2's scope was different and we'd built up coordination patterns from session 1. Cannot attribute to the intervention alone.
- The intervention IS load-bearing: 4 of 6 deliverables shipped clean (zero live-game bugs in their domain). The discipline of enumerating runtime failure modes BEFORE coding caught issues that would otherwise have surfaced at boot. Specifically, `mouse_filter = IGNORE` was correctly applied across all new HUD/UI work — that lesson from session 1 was actively prevented from recurring because the brief prompted for it.
- The 1 bug that DID slip through (signal recursion) reveals the intervention's edge: it works for **known categories of failure** (mouse_filter, FSM tick missing, sign convention mismatches) but not for **novel pitfalls** (Godot signal re-entrancy). The fix is to grow the prompt over time as new categories surface.

**Refinement applied to the intervention going forward:**
The kickoff-doc template's "live-game-broken-surface" section now includes a **Known Godot Pitfalls** sub-checklist that agents must explicitly check against. Initial entries (each backed by a specific incident):
1. **Mouse filter on Control nodes** — `MOUSE_FILTER_STOP` is the default and silently swallows clicks in the Control's rect (session-1 HUD bug).
2. **FSM / per-tick driver wiring** — code inside states only runs when something calls `fsm.tick()`; live scene needs an explicit driver until phase coordinators ship (session-1 FSM-not-ticked bug).
3. **Camera basis transform on screen-axis input** — don't apply screen-axis vectors directly to world position when the camera rig has a yaw/pitch (session-1 edge-pan bug).
4. **Re-entrant signal mutation** — don't mutate a state holder (e.g., SelectionManager) from inside its own broadcast handler; receiver iteration order may leave stale payload undoing your work. Use `call_deferred` (session-2 double-click bug).

When a future session surfaces a new pitfall category, append it here. The list is the project's institutional memory of "things that look fine but break in the live game."

**Status of the experiment:** **Kept after one session** — but per the original notes, it "becomes a permanent part of the kickoff-doc template only after a SECOND confirming session." Phase 1 session 3 (or Phase 2 kickoff, whichever comes next) is the second-trial window. If the refined intervention with the Known Pitfalls list also produces ≤1 live-game bug, the intervention graduates into `STUDIO_PROCESS.md` as a permanent rule. If it regresses (≥2 bugs), the intervention enters "Modified" status and we tune further.

**Notes:**
- N=1 single session — directional signal only. The 67% bug reduction is suggestive, not statistically significant.
- The shared-working-tree coordination problem (multiple agents staging shared docs, reset discarding each other's edits) emerged as a SECOND independent issue this session — worth noting as data for a future Experiment 02 about commit-coordination patterns. See BUILD_LOG entries from wave 1 for the incident timeline.
- Cost-of-measurement was small (~30 min for the verdict table). Below the bottleneck threshold.

### Experiment 02 — Wave-close code review by godot-code-reviewer + architecture-reviewer (2026-05-03)

**Sessions:** Phase 2 session 1 (first formal trial); PR #4 (Phase 1 session 2) was an informal trial run after the wave had already shipped — its findings inform but don't count as the experiment's data point.

**Hypothesis:** Spawning `godot-code-reviewer` and `architecture-reviewer` in parallel at the end of each wave, BEFORE PR creation, catches at least one issue per session that the lead's live-test would otherwise miss OR significantly improves the structural quality of merged code (Manifesto principle adherence, contract fit, layer separation). The intervention is worth its token cost if either condition holds.

**Intervention:** Per `docs/STUDIO_PROCESS.md` §9 wave-close-review rule. After all wave commits land, lead spawns both reviewers in parallel (one Agent dispatch each, `run_in_background=true`). Reviewers produce structured output per their agent definitions (verdict, blocking issues, non-blocking suggestions, nits, what's clean). Blocking issues route back to the original agent for fix; non-blocking suggestions surface in PR description.

**Held constant** (from Experiment 01's intervention which is now baseline):
- Live-game-broken-surface section in every kickoff brief, including the Known Godot Pitfalls list (Experiment 01 refinement).
- Same kickoff-doc structure, wave breakdown, agent set, TDD discipline, pre-commit gate.

**Trial run data (PR #4, Phase 1 session 2 — post-merge informal trial):**

Both reviewers ran against PR #4 after the lead had already live-tested and the cb95d09 fix had landed. Findings:

| Reviewer | Verdict | Blocking | Non-blocking suggestions | Nits | New pitfalls candidates |
|---|---|---|---|---|---|
| godot-code-reviewer | APPROVE | 0 | 4 (S1 staleness window, S2 N+1 broadcast, S3 tree-order, S4 PASS-vs-IGNORE coverage) | 4 | 2 (N+1 broadcast pattern, MOUSE_FILTER_PASS coverage gap) |
| architecture-reviewer | APPROVE | 0 | 6 LATER follow-ups | — | 0 (no Manifesto/contract violations) |

**Trial-run signal:** the reviewers caught **0 bugs the lead's live-test had missed** in this small N=1 post-fix sample. They DID surface high-leverage refactor candidates (godot's S2 `select_many(units)` primitive closes 3 issues at once) and validated the cb95d09 fix's correctness across the codebase (godot-reviewer affirmatively checked the re-entrant pattern across all `selection_changed` subscribers). The architecture-reviewer's Manifesto-principle-grading lens is structural value the lead's live-test cannot provide.

**Trial run is suggestive but inconclusive.** The reviewers ran AFTER the bug was found and fixed. We don't know whether they would have caught the cb95d09 bug at write-time (i.e., reviewing the original wave-2A commit before cb95d09 existed). The Phase 2 session 1 formal trial is the first real test.

**Baseline (Experiment 01's session-2 result):**

| Metric | Session 2 value (with Experiment 01 intervention only) |
|---|---|
| Live-game bugs found at boot by lead | 1 (re-entrant signal recursion, cb95d09) |
| Tests-pass-but-broken incidents | 1 |
| Wave-3 (qa) bug catch rate | 0/1 |
| Manifesto/contract violations caught at merge | not measured (no reviewer existed) |
| Test count delta | +162 (380→542) |
| Time kickoff → merge | ~3h |
| LATER items surfaced | 6+ |

**Metrics to capture at Phase 2 session 1 close:**

| Metric | How measured | Baseline (session 2) | Actual | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test count | 1 | _TBD_ | _TBD_ |
| Bugs caught at wave-close review (BEFORE lead live-test) | Reviewers' blocking + actionable non-blocking findings | n/a (reviewers didn't exist) | _TBD_ | _TBD_ |
| Tests-pass-but-broken incidents | Count of post-test fix passes | 1 | _TBD_ | _TBD_ |
| Wave-3 (qa) bug catch rate | qa caught / total live-game bugs | 0/1 | _TBD_ | _TBD_ |
| Manifesto/contract violations caught | architecture-reviewer findings + lead-validated routes | n/a | _TBD_ | _TBD_ |
| Refactor candidates surfaced | reviewers' "next-session priority" list | 0 | _TBD_ (wave-3 PR #4 trial: 2) | _TBD_ |
| Reviewer token cost (sum of two agents per wave × N waves) | Σ task notification totals for review-only dispatches | n/a | _TBD_ | _TBD_ |
| Lead's review-processing time | Wall clock to read both reviews + route fixes | n/a | _TBD_ | _TBD_ |

**Verdict criteria:**

- **Kept** if: AT LEAST ONE of the following holds:
  - Reviewers caught ≥1 bug at write-time that the lead's live-test would have missed (causal lift, not correlation), OR
  - Reviewers found ≥2 actionable refactor candidates per session that subsequently paid off in cleaner Phase 3+ code, OR
  - Reviewers surfaced ≥1 Manifesto/contract violation per session that would have caused future drift.

  AND the reviewer token cost is ≤ 25% of total session token spend.

- **Modified** if: reviewers add value but the cost is high. Find a cheaper variant — e.g., one reviewer per wave instead of two, or only on highest-risk waves, or only at session-close instead of wave-close.

- **Dropped** if: reviewers consistently produce zero actionable findings AND token cost exceeds 25% of session spend, OR they produce noise that wastes lead time without preventing drift.

**Verdict:** **KEPT WITH REFINEMENT.**

Filled at Phase 2 session 1 wave-close (2026-05-03), post-reviewer-dispatch, pre-merge.

**Metrics captured:**

| Metric | How measured | Baseline (sess. 2) | Actual (Phase 2 sess. 1) | Δ |
|---|---|---|---|---|
| Live-game bugs found at boot | Lead live-test | 1 | 0 (qa caught 4 first) | −100% |
| Bugs caught at wave-close review | Reviewer findings flagged blocking/actionable | n/a | 0 blocking + 5 actionable docs/contract findings | new metric |
| Bugs caught by qa wave 3 (BEFORE reviewers) | qa report bug count | 0 (caught nothing lead missed) | 4 (BUG-01..04 — 3 production, 1 derivative) | +400% |
| Manifesto/contract findings | architecture-reviewer findings | 0 | 6 (F-1..F-6 in architecture-reviewer's review) | new metric |
| Refactor candidates surfaced | reviewers' "next-session priority" list | 2 | 5 (UnitRegistry triple-LATER, CombatSystem coordinator, suffix Constants, encapsulation helper, MatchHarness migration) | +150% |
| Test count delta | Σ tests added | +37 | +176 (542→718) | +376% |
| Time kickoff → merge | Wall clock | ~3h | ~5h+ (multiple bug-fix cycles + 2 deviations) | +67% |
| Reviewer token cost | Σ task notification totals (review-only dispatches) | n/a (informal trial) | TBD — recover from logs | new metric |
| Lead's review-processing time | Wall clock to read both reviews + route fixes | n/a | ~30 min | new metric |

**Verdict justification:**

The wave-close review **did** add structural value the lead's live-test wouldn't surface — specifically:
1. **arch-reviewer's F-1 + F-2** (missing §6 entries for BUG-01+03 and BUG-04 fixes) preserve archaeology that future sessions need. The lead noticed the v0.17.3 hole during commit history audits but the architecture-reviewer's structured grade caught BOTH F-1 and F-2 before merge.
2. **godot-code-reviewer's BUG-04 verification** (three-trace audit: same-target / new-target / freed-target) confirmed the fix didn't introduce a new bug — that's a level of static-analysis rigor the lead's live-test cannot match.
3. **5 candidate Pitfalls evaluated with calibrated KEEP/DEFER/REJECT decisions** — godot-code-reviewer correctly distinguished engine pitfalls (#5 sibling tree-order, #8 double-deferred queue_free) from process patterns (#7 commit-race) and rejected unsupported claims (#9 lambda capture). This is exactly the lens the wave-close review was designed to provide.
4. **arch-reviewer's contract-fit findings** caught the §2 phase-order drift (combat in movement phase) explicitly — a real but acknowledged-as-LATER architectural deviation.

The intervention's value comes from **structural drift detection**, not from "catching a bug the lead would have missed at boot." Phase 2 session 1's bugs (BUG-01..04) were caught by qa wave 3's integration tests, not by either reviewer. But the reviewers caught the v0.17.3/v0.17.5 §6 documentation holes that would have rotted the project's archaeology over multiple phases.

**Refinement applied to the intervention going forward:**

- **Reviewer briefs must include the explicit §6 entry checklist.** The reviewer-brief-side checklist works; the agent-brief-side reminder ("write a §6 entry per non-trivial deliverable") is observably insufficient when agents fall into the verification-loop pattern. The reviewer should be the second line of defense for archaeology.
- **`SendMessage` in reviewer tool list confirmed working.** Both reviewers proactively returned their structured output via SendMessage; no idle-without-content failures repeated from the informal trial. Mitigation from Experiment 02's setup is validated.

**Status:** **GRADUATED to permanent rule after Phase 2 session 2 confirming trial (2026-05-12).**

**Phase 2 session 2 verdict (2nd formal trial — closure data):**

| Metric | Session 1 trial baseline | Phase 2 sess 2 trial | Δ |
|---|---|---|---|
| Both reviewers return APPROVE | Yes | Yes | unchanged |
| Bugs found by reviewers that lead's live-test would have missed | 6 (F-1..F-6 LATER items) | 4 (S1..S4 + 4 nits per godot-reviewer) | comparable |
| Cross-reviewer convergent findings | 2 (§1.5 tween tension; cross-agent doc-stomp) | 3 (HP-death detection pattern; SSOT-in-spirit Pitfall #7; L13 escalation) | +1 |
| Reproducibility across fresh instances | Not measured | **Confirmed via PR #9 second pass** — same APPROVE, comparable density (4/4 vs 4/4, plus convergent escalations) | NEW DATA |
| Cost-of-measurement | ~20 min lead time | ~25 min lead time (added PR-attached posting) | +25% |

**Second-trial-specific findings beyond first-trial findings:**
- **PR-attached review pattern works.** Reviewers can post via `gh pr review --comment` using their `Bash` tool access. Reviews are now discoverable inline in the GitHub UI alongside the diff. Adds ~5 min per reviewer but produces persistent archaeological trail outside agent chat.
- **Reproducibility across fresh instances is real.** Two fresh instances on identical PR content returned matching verdicts (APPROVE) and comparable finding density (4 non-blocking + 4 nits each), with each surfacing 2-3 items the other did not. The reviewer-pair pattern is not lottery-dependent.
- **Convergent findings escalate themselves.** Items both reviewers flag independently (HP-death detection, Pitfall #7 SSOT) have higher promotion priority than single-reviewer findings.

**Promoted permanent rule (added to STUDIO_PROCESS.md §9 2026-05-12):** Every wave-close, lead dispatches both reviewer agents in parallel BEFORE PR creation. Reviewers post their full structured review via `gh pr review --comment` for GitHub-native archaeological trail. Convergent findings (flagged by both reviewers independently) auto-promote to LATER index items at next retro.

### Experiment 03 — Incremental commits + serialized wave-close (2026-05-04)

**Sessions:** Phase 2 session 2 (first formal trial).

**Hypothesis:** Two changes to commit discipline reduce cross-agent shared-tree conflicts (the verification-loop and commit-race patterns from Deviations 01 + 02) without measurable productivity loss:

1. **Per-TDD-cycle commits** — agents commit immediately after each `red → green` cycle (each new test+implementation pair), not at end-of-wave. Reduces working-tree contention; each agent's work is visible in `git log` in real time, so no agent reads "another agent's uncommitted work" in the tree and gets confused.
2. **Serialized wave-close commits** — when batched commits ARE necessary (e.g., docs aggregator at end of wave), lead nominates a one-at-a-time commit order rather than letting agents race each other. Removes the race condition that produced the misattributed `aa429ef` in Phase 2 session 1.

**Intervention:** Phase 2 session 2 kickoff brief includes both rules verbatim. Each agent dispatch brief includes:

> "Commit per TDD cycle: after each red→green→refactor sequence, run pre-commit gate, stage your specific files, commit. Do NOT batch commits at end-of-wave. End-of-wave should have at most a docs-only commit. If wave-close requires a coordination commit, lead nominates the order."

**Held constant** (NOT changed from Phase 2 session 1):
- Live-game-broken-surface section per deliverable (Experiment 01 active).
- Wave-close review by both reviewer agents (Experiment 02 active).
- Same kickoff doc structure, agent set, TDD discipline, pre-commit gate, file ownership rules.

**Baseline (Phase 2 session 1):**

| Metric | Phase 2 session 1 value |
|---|---|
| Verification-loop occurrences | 2+ (wave 1A/1B agents got stuck; recurred in wave-3 bug fix dispatch) |
| Commit-race incidents (misattributed commits) | 1 (`aa429ef` titled wave-2C, content is wave 2A+2B) |
| Lead-proxy commits required | 3 (Deviation 01 + 2 small follow-ups for stuck agents) |
| Cross-agent contamination of docs (BUILD_LOG, ARCHITECTURE) | 4+ minor stomps |
| Total commits on branch | 23 |
| Bug-fix dispatches required after wave-close review | 2 (BUG-04, BUG-06) |

**Phase 2 session 2 closure data (2026-05-12):**

| Metric | How measured | Baseline | Actual | Δ |
|---|---|---|---|---|
| Verification-loop occurrences | Agent reports "task already shipped, standing down" without committing | 2+ | **0** | **−100%** |
| Commit-race incidents | Misattributed commits or commits with cross-agent contamination | 1 | **2** (`cac29cc`, `3fefeea` — both in wave 1) | **+100%** |
| Lead-proxy commits required | Lead committed work agents should have committed themselves | 3 | **0** | **−100%** |
| Cross-agent docs contamination | Times an agent's `git diff` of BUILD_LOG / ARCHITECTURE included another agent's draft text | 4+ | 2 (folded into the 2 commit-race incidents above) | comparable |
| Total commits on branch | Σ commits in `main..HEAD` | 23 | 12 | smaller scope |
| Bug-fix dispatches after wave-close | (new metric) | 2 (BUG-04, BUG-06) | **0** | **−100%** |

**Verdict: MODIFIED.**

**Reasoning:**

The intervention has TWO mechanisms with very different verdicts:

1. **Per-TDD-cycle commits + anti-loop brief language: KEPT (permanent rule).** Verification-loop occurrences dropped from 2+ to 0. Lead-proxy commits dropped from 3 to 0. Four sequential single-agent waves (1B, 2A, 2B, 3) ALL shipped clean. The anti-loop cycle (implement → gate → diff staged → commit → log -1 confirm → report) is observably load-bearing. Promoting to permanent `STUDIO_PROCESS.md` §9 rule.

2. **Serialized wave-close commits: INSUFFICIENT.** Commit-race incidents went UP, not down (1 → 2 in wave 1's three-parallel-agent dispatch). Despite explicit "stage your specific files only" language in every brief, both incidents occurred when one agent's `git commit` swept up another agent's untracked working-tree files. The race is not at staging-time; it's at commit-write time when the pre-commit gate's ~2-minute test runner allows another agent's working-tree state to mature. **Sequential single-agent waves don't trigger it (waves 2A/2B/3 were clean). Parallel multi-agent waves do (wave 1's three parallel agents stomped twice).**

**Promoted to permanent rule (added to STUDIO_PROCESS.md §9 2026-05-12):** Per-TDD-cycle commits + anti-loop brief language. The discipline is load-bearing.

**Demoted to follow-up experiment:** The parallel-agent commit-race mitigation is unresolved. Recommend Experiment 04 (worktree-per-agent vs lead-orchestrated commit serialization) per arch-reviewer-p2s2's structural recommendation. The Pitfall #7 mitigation Open Space sync between Phase 2 close and Phase 3 kickoff is the right forum to choose the mitigation strategy.

**Cost-of-measurement:** ~10 min lead time for verdict-table fill. Below bottleneck.

**Notes:**
- The most informative data point: parallel-agent waves are structurally different from sequential ones. The discipline-side intervention works for sequential; structural intervention (worktrees or commit-lock) needed for parallel. Splitting the verdict captures both.
- Risk: per-TDD-cycle commits make `git log` more granular. May produce 30+ commits per wave instead of 5. Feature, not bug — granular commits make `git bisect` viable when a regression sneaks in. But PRs become longer to read.
- Companion to existing `STUDIO_PROCESS.md` §9 rule (2026-05-01) about pre-commit gate filtering by `git diff --cached --name-only` — that's an automation-side mitigation; this is a discipline-side one. Both should land together.

### Experiment 04 — `git worktree`-per-agent for parallel waves (2026-05-13)

**Sessions:** Phase 3 session 2 (first formal trial — Phase 3 session 1 is sequential by deliverable dependency, no parallel-wave trigger).

**Hypothesis:** Pre-creating a separate `git worktree` per dispatched agent for parallel-wave dispatches eliminates the Pitfall #7 cross-agent commit-staging race. Specifically: zero Pitfall #7 incidents in a parallel-wave dispatch where the prior shared-tree pattern would have produced ≥1 incident.

**Intervention:** When wave brief stamps `parallel-worktrees` mode (per the new STUDIO_PROCESS §9 2026-05-13 rule), lead pre-creates worktrees at dispatch time:

```bash
git worktree add ../shahnameh-rts-<dispatch-id> <branch>
```

One per dispatched agent. Brief delta is one line: `"Your worktree: ../shahnameh-rts-<dispatch-id>"`. Agent never manages worktree setup. Each worktree has independent `.uid` / `.import/` regeneration on first scene load. All worktrees commit to the SAME shared branch; git serializes the underlying `.git` write lock. Wave-close push order is lead-serialized.

**Held constant** (NOT changed from Phase 2 session 2):
- Live-game-broken-surface section per deliverable (Experiment 01, expected to graduate at Phase 3 sess 2 close).
- Wave-close review by reviewer pair via `gh pr review --comment` (Experiment 02, permanent).
- Per-TDD-cycle commits + anti-loop brief language (Experiment 03 sequential portion, permanent).
- Sequential-shared-tree mode remains for single-deliverable / heavy-shared-doc waves.

**Baseline (Phase 2 session 2 wave 1 — three parallel agents in shared tree):**

| Metric | Phase 2 sess 2 wave 1 (parallel-three, shared tree) |
|---|---|
| Pitfall #7 incidents in wave | 2 (`cac29cc` swept TuranKamandar; `3fefeea` swept TuranSavar) |
| Cross-agent doc contamination | 4+ stomps recoverable via §6 retro entries |
| Recovery overhead per incident | ~15 min lead time to document attribution |
| Branch commits affected | 2 of 12 (17%) carry wrong attribution in commit title |

**Metrics to capture at Phase 3 session 2 close:**

| Metric | How measured | Baseline | Actual | Δ |
|---|---|---|---|---|
| Pitfall #7 incidents | Misattributed commits (file headers ≠ commit title); cross-agent file sweeps | 2 in wave 1 | _TBD_ | _TBD_ |
| Cross-agent doc contamination | Times an agent's `git diff` of BUILD_LOG / ARCHITECTURE included another agent's draft text | 4+ | _TBD_ | _TBD_ |
| Worktree-creation overhead (lead) | Wall-clock time to `git worktree add` × N + brief delta | n/a | _TBD_ | _TBD_ |
| Worktree-cleanup overhead (lead) | Wall-clock `git worktree remove` × N at session close | n/a | _TBD_ | _TBD_ |
| First-load `.uid` / `.import/` regen cost (per agent) | Wall-clock from agent dispatch to first successful pre-commit gate | n/a | _TBD_ | _TBD_ |
| Parallel-wave throughput recovery | Wall-clock parallel vs equivalent sequential dispatches | n/a | _TBD_ | _TBD_ |

**Verdict criteria:**

- **Kept** if: Pitfall #7 incidents = 0 in Phase 3 session 2's parallel-wave dispatch, AND total worktree overhead < 20 min per session, AND no new orthogonal issues introduced.
- **Modified** if: Pitfall #7 incidents = 0 BUT overhead > 20 min OR a new issue emerges (e.g., shared `user://` test isolation bites). Tune the brief / cleanup discipline.
- **Dropped** if: Pitfall #7 incidents > 0 (worktrees didn't help, structural fix isn't the right structural fix), OR overhead > 40 min (impractical at the size of waves we run). Fallback to sequential-shared-tree as the permanent answer (Option 3 from the Open Space negotiation).

**Verdict:** _TBD — fill at Phase 3 session 2 close._

**Notes:**
- Pitfall #7 is now a CLOSED candidate in the Known Godot Pitfalls candidate list (above) — superseded by this experiment + the STUDIO_PROCESS §9 2026-05-13 permanent rule. The Pitfall list governs ENGINE foot-guns; the worktree workflow is a PROCESS rule. Different ownership surfaces, as the L20 closure documents.
- The 10 mandatory pitfalls for worktree mode (worktree naming by dispatch-id, `.godot/` gitignore, `balance.tres` sequential-only, file-count test semantic conflicts, retro aggregation, worktree cleanup, `user://` test isolation, `.uid` cache, fast-forward race at push) all came from the Constraint Negotiation engineering POVs. Folded into STUDIO_PROCESS §9 2026-05-13 entry. These are NOT separate experiments — they're the implementation guardrails for THIS experiment.
- Cost-of-measurement: ~15 min lead-time at session close to fill verdict table. Add to session-close-retro template.
- Graduates to permanent STUDIO_PROCESS §9 rule (currently provisional) only after a SECOND confirming session — Phase 3 session 3 or Phase 4 session 1 will be the second trial.

## Mid-flight deviations log

Per the discipline rule, deviations from the documented studio process (kickoff doc, STUDIO_PROCESS §9, ongoing experiments) are allowed when running into a known wall, but must be explicit and logged.

### Deviation 01 — lead committed wave-1A + wave-1B on behalf of stuck agents (2026-05-03, Phase 2 session 1)

**Trigger:** `gameplay-combat-core` (subagent_type=gameplay-systems, name=gameplay-combat-core) entered a verification loop after completing implementation work in the shared working tree. Each subsequent task on their list looked at the file already in the tree and reported "task already shipped by another agent, standing down" — when in fact the work was theirs from earlier in the same session, just uncommitted. Three rounds of explicit lead messaging ("this is YOUR work, please commit") failed to break the loop. `ai-eng-attacking-state` had similar behavior (work in tree, never reached the commit step).

**Process expectation violated:** kickoff doc §5 "End of session: Lead live-tests before PR" — but agents are supposed to commit their own work first. STUDIO_PROCESS §9 (2026-05-01) "verify git tree at session close" requires a tree to verify — agents weren't producing one.

**Deviation:** lead manually staged and committed wave-1A's gameplay-combat-core work and wave-1B's ai-eng-attacking-state work as a bundled commit (`81cf42a`), with body crediting both agents for authorship and tagging the commit as a mid-flight deviation. balance-engineer's wave-1C work (`a2b444f`) was committed by the agent themselves cleanly — no deviation there.

**Cost avoided:** continued waste of conversation rounds messaging stuck agents. Each "task already shipped, standing down" message + lead nudge cycle was costing ~5 turns. Without the deviation, work in the tree would have been blocked indefinitely or required a fresh agent spawn (which costs more tokens than just committing).

**Cost paid:**
- **Cleaner attribution loss:** the `81cf42a` commit credits two agents in one commit body, not the standard one-agent-per-commit shape. Future archaeologists reading `git log` see "lead committed two agents' work" as an outlier vs. the standard pattern. Mitigated by explicit body documentation.
- **Experiment 01 (live-game-broken-surface) data quality dent:** the deviation may correlate with the agent verification-loop bug in some way — was the loop a side effect of agents trying to apply the live-game-broken-surface section to too many tasks and getting confused about state? Need to verify in the session-close retro. Don't conflate the symptoms.
- **Experiment 02 (wave-close review) trial setup:** the wave-close review is supposed to happen AFTER all wave commits land, BEFORE PR. The lead-deviation commits land on the branch normally; wave-close review still runs against the branch. So this doesn't break Experiment 02's setup, but it does muddy the "agents are responsible for their own commits" assumption built into the agent dispatch process.

**Resolution / mitigation for future:**
- **Fold into the next agent-dispatch brief**: explicitly tell each agent that they are responsible for committing their own work BEFORE standing down. Add "if you find work in the tree that you don't recognize, run `git diff` to verify whether it's yours from earlier in the session — your task list is the authority on what you've done."
- **Investigate root cause**: the verification loop pattern is likely a fundamental Claude Code agent confusion about session continuity. May be worth a separate Experiment 03 on commit-discipline patterns once the current Experiments 01 and 02 close.
- **Recurring problem:** session 2 had a similar shared-tree-coordination problem (different mechanism: agents stepped on each other's docs). This is the second session this class of issue has surfaced. Tagging as a recurring pattern worth its own study.

**Verdict on the deviation itself:** appropriate for the situation but indicative of a process gap that should be closed in Phase 2 session 2's kickoff brief.

### Deviation 02 — parallel-agent commit-staging race produced a misattributed commit (2026-05-03, Phase 2 session 1 wave 2)

**Trigger:** three wave-2 agents (`gameplay-piyade-and-drain`, `ai-eng-attack-input`, `ui-dev-health-and-overlay`) running in parallel each modified shared files (`main.tscn`, `BUILD_LOG.md`, `docs/ARCHITECTURE.md`) AND wrote their own files. Each agent's editor / linter kept re-asserting their changes into the working tree. ui-dev-health-and-overlay was first to attempt commit:
1. Staged 9 of their own files. Verified `git diff --staged --stat` showed only theirs.
2. Between the verification and the actual commit, parallel agents' background writes restored more files into the index.
3. The pre-commit hook committed what was in the index at commit-time — which included gameplay-piyade-and-drain's wave-2A files AND ai-eng-attack-input's wave-2B files alongside / instead of ui-dev's wave-2C.
4. Result: commit `aa429ef` has the title `feat(ui): floating health bars + F4 attack-range overlay — Phase 2 session 1 wave 2C` but its content is the wave 2A + 2B work (Piyade, Turan_Piyade, Farr drain, attack-move handler, UnitState_AttackMove, click_handler enemy-right-click branch).
5. ui-dev-health-and-overlay caught the discrepancy post-commit, made a corrective commit `c203dfe` with their actual wave-2C deliverables and a clear note in the body explaining what happened. They tried `git reset --soft HEAD~1` to amend the misattributed commit but the action was sandbox-denied as destructive.

**Process expectation violated:**
- STUDIO_PROCESS §9 (2026-05-01) "verify git tree at session close, not just lint + tests" — the lead-side equivalent of `git diff --staged --stat` JUST BEFORE commit was not enforceable across parallel-agent boundaries. The tree changes between verification and commit.
- STUDIO_PROCESS §9 (2026-05-01) "Pre-commit gate must filter to tracked files when N agents run in parallel" — was already a known LATER item; this incident is the second occurrence (first was Phase 0 session 4 wave 1). Still not implemented.
- Implicit but unstated rule: "atomic commits per agent." The race violates this even though no agent intended to.

**Deviation:** lead is logging the issue and standing down agents whose work landed in the misattributed commit. NOT rewriting history (would require destructive `git reset` / `git rebase` and is contained to local branch — but per discipline rule, deviations are painful and serious; we don't compound by adding history rewrite). The commit log will permanently show the misattribution; the corrective commit `c203dfe` documents it in its body. Future readers of `git log` will see both commits and understand the race.

**Cost avoided:**
- Avoided destructive `git reset --hard` / `git rebase -i` operations that could have lost wave-2C work entirely under tooling error.
- Avoided multi-round agent coordination ("you commit first, no you commit first") which was already the failure mode.

**Cost paid:**
- Permanent ugly archaeology in `git log` — `aa429ef`'s commit message lies about its content. Mitigated by `c203dfe`'s body explanation, but a future agent reading just `git log --oneline` will be confused.
- The wave 2A and wave 2B agents have ambiguous "did I commit or not" state — needs explicit lead messaging to release them. Adds ~5 turns of cleanup messaging.
- `BUILD_LOG.md` and `docs/ARCHITECTURE.md` entries from wave 2A and 2B are NOT in `aa429ef` — they were in the working tree at commit time but didn't make it into the index. They're shipped via `c203dfe` (which had the wave-2C agent's docs additions only). The wave 2A and 2B retro entries are LOST FROM HISTORY unless reconstructed.

**Resolution / mitigation for future:**
- **Implement the LATER item from STUDIO_PROCESS §9 (2026-05-01):** pre-commit gate must filter to tracked files via `git diff --cached --name-only`. Already documented; long overdue.
- **Add to wave brief template:** "before staging, freeze the working tree by signaling other agents to pause. After staging, run `git diff --staged --stat` AND `git diff --stat` (the unstaged-but-modified set should not include any of YOUR files). Commit immediately."
- **Better: serialize wave-end commits.** Instead of N agents committing in parallel, lead nominates an order at wave-close. Each agent commits, signals done, next agent commits. Costs a few turns of coordination but eliminates the race entirely.
- **Best (long-term):** each agent commits IMMEDIATELY after completing each TDD red→green cycle, not at end-of-wave. By the time wave-close happens, only docs need committing. The agent gameplay-combat-core's own retrospective from Deviation 01 made this exact point.

**Pattern recognition:** this is the THIRD session this class of cross-agent shared-tree issue has surfaced (session 2 had docs-stomp; this session has Deviation 01 verification-loop AND Deviation 02 commit-race). The pattern is now load-bearing enough to warrant its own experiment in a future session — Experiment 03: incremental commits + serialized wave-close. Promote when current Experiments 01/02 close.

**Verdict on the deviation itself:** appropriate. Rewriting history would have introduced more risk than the misattribution itself. The commit log will live with the lie; the in-line body of `c203dfe` and this Deviation 02 entry are the explanatory record.

## Resolved experiments (archive)

_None yet — Experiment 01 stays Active until session 3 confirms or rejects the refinement, and Experiment 02 stays Active until Phase 2 session 1 produces its first verdict._
