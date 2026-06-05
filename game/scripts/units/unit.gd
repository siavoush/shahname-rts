class_name Unit extends CharacterBody3D
##
## Unit — base class for every player- or AI-controlled mobile unit.
##
## Per docs/STATE_MACHINE_CONTRACT.md §5.1: "Unit extends SimNode" — but
## SimNode is a Node, and a unit needs to be a CharacterBody3D for its
## position writes (Sim Contract §4.1's Node3D.global_position carve-out)
## and for future collision tuning (units pushing each other in formation,
## Phase 1 session 2 GroupMoveController). We therefore extend
## CharacterBody3D, satisfying the SimNode discipline by routing all
## sim-state mutation through component children (HealthComponent,
## MovementComponent, etc.) which DO extend SimNode. The pattern matches
## Sim Contract §1.3's "Self-only mutation rule" — components own their
## own state and Unit is just composition glue.
##
## Composition (per the unit.tscn template):
##   - Unit (CharacterBody3D)              — root, this script
##     ├── MeshInstance3D                  — placeholder colored cube
##     ├── CollisionShape3D                — BoxShape3D matching the mesh
##     ├── HealthComponent                 — hp / damage / death signal
##     ├── MovementComponent               — IPathScheduler integration
##     ├── SelectableComponent             — selection state + ring visual
##     ├── SpatialAgentComponent           — auto-registers with SpatialIndex
##     └── (StateMachine framework owns the FSM, instanced from this script
##          rather than as a Node child; per Contract §2.3 "RefCounted, not
##          a Node" rationale — avoids the Node-tree explosion of 100 units
##          × 10 states.)
##
## Lifecycle:
##   _ready:
##     1. Assign unit_id (auto-incremented from a static counter).
##     2. Read unit_type's UnitStats from BalanceData; init component
##        defaults (HealthComponent.init_max_hp, MovementComponent.move_speed).
##     3. Construct the StateMachine, register concrete UnitStates (Idle,
##        Moving, etc. — concrete states ship in wave 2; this base class
##        leaves the registration list empty so subclasses populate it).
##     4. Call fsm.init(&"idle") to land in the starting state.
##     5. Configure SpatialAgentComponent.team from this unit's `team` field.
##
##   _sim_tick (override from SimNode discipline — but Unit is a
##   CharacterBody3D and doesn't extend SimNode directly; instead, the
##   movement phase coordinator (Phase 1 wave 2) drives this method via a
##   typed-call):
##     - calls fsm.tick(SimClock.SIM_DT). The StateMachine then runs the
##       current state's _sim_tick, which may interact with movement /
##       health / etc. components.
##
## Phase 1 wave 1 (this session) ships only the base class — the Unit
## scene template, component wiring, and lifecycle hooks. Concrete unit
## types (Kargar, Piyade, etc.), concrete states (Idle, Moving), and
## spawning logic are wave 2 and beyond.
##
## Per CLAUDE.md placeholder policy: visuals are placeholder shapes only.
## The MeshInstance3D in unit.tscn is a small colored cube (~0.6 units
## tall) sized for a worker silhouette; concrete unit types may swap the
## mesh resource for different roles (cylinders for cavalry, larger cubes
## for hero, etc.) without touching this base class.

# === Static unit_id counter ================================================
# Monotonically increasing across all Units spawned during a match.
# Reset by reset_id_counter() at match-start (called by MatchHarness and
# the future MatchSetup script). The id is what every signal payload uses
# for cross-system unit identification (EventBus.unit_died.emit(unit_id),
# SpatialIndex queries returning Node refs from which the unit_id is read,
# StateMachine telemetry, MatchLogger NDJSON, etc.).
static var _next_unit_id: int = 1


## Reset the unit_id counter. Called at match start to ensure every match
## has units numbered from 1 (so replays diff cleanly and snapshots
## compare deterministically across runs).
static func reset_id_counter() -> void:
	_next_unit_id = 1


# === Per-instance fields ====================================================

## Identity assigned at spawn from the static counter. -1 sentinel until
## _ready runs.
var unit_id: int = -1

## Fog-system vision-source handle. Returned by
## `FogSystem.register_vision_source(...)` at `_ready`; passed back to
## `FogSystem.deregister_vision_source(handle)` at `_exit_tree` so the
## vision source is removed BEFORE the SceneTree completes the free.
##
## Default 0 — sentinel for "not registered" / "already deregistered."
## Per FogSystem.deregister_vision_source contract: idempotent and safe
## for unknown handles (0, -1, or any other), so calling
## deregister(_fog_handle) without checking is safe.
##
## Wave 3A.5 Track 2: this is the FIRST consumer of
## `FogSystem.register_vision_source`'s real implementation (Track 1
## ships the real body in the joint commit). At Wave 3A.0 the
## register/deregister calls were no-op stubs returning -1; with
## Track 1's real impl returning a non-zero handle, `_fog_handle`
## becomes load-bearing for the deregister path.
##
## H3 dogfood per §9.H3: the per-kind sight-radius read at register
## time (`BalanceData.fog.sight_<unit_type>_cells`) is the first
## runtime exercise of those dormant schema fields. A test in
## `test_unit.gd` validates each unit kind's lookup returns the
## right value (kargar=3, piyade=3, kamandar=4, savar=4, rostam=5)
## to catch the typo-bait surface (Resource returns 0 for missing
## int properties — silent fallback).
var _fog_handle: int = 0

## Unit-type StringName (e.g., &"kargar", &"piyade"). Concrete subclasses
## (Kargar, Piyade, ...) set this in their _init or via the scene template's
## script export. Used to look up UnitStats from BalanceData.
@export var unit_type: StringName = &""

## Team assignment (Constants.TEAM_IRAN / TEAM_TURAN / TEAM_NEUTRAL).
## Set by spawn-side code; mirrored down to the SpatialAgentComponent in
## _ready so spatial queries can filter by team.
@export var team: int = Constants.TEAM_NEUTRAL

## The unit's per-unit command queue. Player input and AI controllers push
## Commands here via Unit.replace_command / Unit.append_command (per
## State Machine Contract §2.5). The StateMachine reads from this on
## transition_to_next().
##
## Constructed in _init so it exists before _ready / before any external
## code can call replace_command on a freshly-spawned unit.
var command_queue: CommandQueue = CommandQueue.new()


## The owning StateMachine. Constructed in _init for the same reason as
## command_queue. Concrete states are registered in _ready by subclasses
## (or by the scene's script — wave 2 work).
var fsm: StateMachine = StateMachine.new()


# Concrete-state script preloads. Path-string instead of class_name to dodge
# the registry race documented in docs/ARCHITECTURE.md §6 v0.4.0 — when
# unit.gd is parsed alongside test scripts, the UnitState_Idle / _Moving
# global class_names may not be in the registry yet, causing unit.gd's own
# `class_name Unit` to fail to register (which cascades into "unit_type
# is a property of CharacterBody3D, not Unit" failures in test fixtures).
# The path-string preload sidesteps the race entirely.
const _UnitStateIdleScript: Script = preload("res://scripts/units/states/unit_state_idle.gd")
const _UnitStateMovingScript: Script = preload("res://scripts/units/states/unit_state_moving.gd")
const _UnitStateAttackingScript: Script = preload("res://scripts/units/states/unit_state_attacking.gd")
const _UnitStateAttackMoveScript: Script = preload("res://scripts/units/states/unit_state_attack_move.gd")
const _UnitStateDyingScript: Script = preload("res://scripts/units/states/unit_state_dying.gd")
# Phase 3 wave 1A — gather loop states. Registered on every Unit (including
# combat units) so transition_to(&"gathering") / transition_to(&"returning")
# always lands cleanly; combat units never receive a &"gather" command, so
# the registered-but-never-entered cost is the RefCounted state instance
# itself (one per unit, tiny).
const _UnitStateGatheringScript: Script = preload("res://scripts/units/states/unit_state_gathering.gd")
const _UnitStateReturningScript: Script = preload("res://scripts/units/states/unit_state_returning.gd")
# Phase 3 wave 1C — building-placement state. Registered on every Unit
# (including combat units) so transition_to(&"constructing") always lands
# cleanly. Combat units never receive a COMMAND_CONSTRUCT, so the
# registered-but-never-entered cost is one RefCounted state instance per
# unit, tiny. Same "register on every Unit" rationale as the wave-1A
# gather states.
const _UnitStateConstructingScript: Script = preload("res://scripts/units/states/unit_state_constructing.gd")


## Snapshot of the most-recently-dispatched Command, populated by
## StateMachine.transition_to_next() before it returns the Command to the
## CommandPool. Concrete UnitStates (UnitState_Moving, UnitState_Attacking,
## ...) read kind/payload off this slot in their `enter()` to decide their
## target / focus.
##
## Per State Machine Contract §3.4: "the popped command is returned, so
## concrete states must read their target from elsewhere (e.g.,
## ctx.current_command — to be defined when concrete states ship)." This
## slot is that definition. Wave 2 (ai-engineer) ships it alongside
## UnitState_Moving — Moving's `enter` reads `ctx.current_command["target"]`.
##
## Shape (matches Command):
##   { "kind": StringName, "payload": Dictionary }
##
## Empty Dictionary when no command has been dispatched (initial state).
## Cleared by transition_to_next when the queue is empty (sentinel for
## "transitioning to Idle without a command behind the move").
##
## Why a Dictionary instead of a Command ref: the Command is returned to
## the pool immediately after the state-id mapping is computed, so holding
## a ref would race with the pool re-renting the same instance. The
## Dictionary is a defensive copy of the kind/payload at dispatch time.
var current_command: Dictionary = {}


# === Worker carry state (Phase 3 wave 1A — gather loop) ====================
# UnitState_Gathering writes these on complete_extract; UnitState_Returning
# reads them at the Throne deposit step. Fixed-point per Sim Contract §1.6
# — _carry_amount_x100 is the deposit amount scaled by 100.
#
# Fields live on Unit (not Kargar) so any worker-like unit subclass shares
# the carry seam. Phase 3 only the Kargar uses these; the field is harmless
# (zero / empty) on combat units that never gather. Per RESOURCE_NODE_CONTRACT
# §4.3 the carry mutation rule is "node calls worker.set_carry(...)" — wave
# 1A's UnitState_Gathering writes the fields directly inside its _sim_tick
# instead of routing through a set_carry method (the state IS inside the
# unit's _sim_tick, so the on-tick invariant is preserved by construction).
# When a Mazra'eh extends the gather API (wave 1B+) with per-tick carry
# accumulation, the set_carry method may be revisited.
var _carry_kind: StringName = &""
var _carry_amount_x100: int = 0


# === Component getters (typed accessors) ===================================
# Per docs/SIMULATION_CONTRACT.md Component Model — getters are the canonical
# read seam so tests and other systems don't reach into the scene tree with
# string paths. The component lookup happens once on demand via get_node;
# the result is cached in _components_cache for subsequent reads.
#
# Why get_node_or_null instead of @onready var foo: HealthComponent = $...
# — the scene tree may not have the component yet when external code calls
# the getter (e.g., during a unit-test scenario that constructs Unit
# without a scene). Defensive fallback to null preserves the test seam.

@onready var _health_component: Node = get_node_or_null(^"HealthComponent")
@onready var _movement_component: Node = get_node_or_null(^"MovementComponent")
@onready var _combat_component: Node = get_node_or_null(^"CombatComponent")
@onready var _selectable_component: Node = get_node_or_null(^"SelectableComponent")
@onready var _spatial_agent: Node = get_node_or_null(^"SpatialAgentComponent")


## Returns the HealthComponent child. Untyped (Variant via Node return) to
## avoid hard class_name dependencies at parse time; callers may type-narrow
## with `as HealthComponent` if they want.
func get_health() -> Node:
	return _health_component


func get_movement() -> Node:
	return _movement_component


## Returns the CombatComponent child (if present). Wave 1B (Phase 2 session 1)
## ships the accessor; CombatComponent itself ships in gameplay-systems' wave
## 1A. UnitState_Attacking calls this in its enter() to cache the component
## ref; the state tolerates a null return defensively (out-of-range targets
## still drive movement; in-range targets are no-ops on the combat side with
## a push_warning).
func get_combat() -> Node:
	return _combat_component


func get_selectable() -> Node:
	return _selectable_component


func get_state_machine() -> StateMachine:
	return fsm


# === Lifecycle ==============================================================

func _ready() -> void:
	# Assign a fresh unit_id from the static counter.
	if unit_id == -1:
		unit_id = _next_unit_id
		_next_unit_id += 1

	# Wave 3-Sim mirror C1.2 fix — join the canonical &"units" SceneTree
	# group so DummyIranController + HeadlessMatchRunner + any future
	# discovery consumer share one primitive. Mirrors Building._ready which
	# joins &"buildings" at building.gd:358. Pre-fix, Unit was the only
	# major class lacking a group, which silently inerted DummyIran's
	# Kargar-dispatch (it queried &"units" but found nothing — Iran's
	# economy never started, Iran always stalemated).
	add_to_group(&"units")

	# Mirror the team to the SpatialAgentComponent so spatial queries
	# filter correctly. The SpatialAgentComponent has its own @export for
	# team, but the Unit owns the canonical team value (set by spawn code).
	if _spatial_agent != null:
		_spatial_agent.set(&"team", team)

	# Propagate unit_id to components so their EventBus emissions carry
	# the correct id. Tests may set unit_id manually before calling _ready
	# in a controlled fixture; the static-counter assignment above is the
	# default for production spawns.
	if _health_component != null:
		_health_component.set(&"unit_id", unit_id)
	if _movement_component != null:
		_movement_component.set(&"unit_id", unit_id)
	if _combat_component != null:
		_combat_component.set(&"unit_id", unit_id)
	if _selectable_component != null:
		_selectable_component.set(&"unit_id", unit_id)

	# Initialize component defaults from BalanceData (best-effort — concrete
	# unit-type subclasses or scene scripts may have already set values).
	_apply_balance_data_defaults()

	# Wave 3A.5 Track 2 — fog vision-source registration.
	# Per §9.H3: this is the FIRST runtime read of
	# `BalanceData.fog.sight_<unit_type>_cells`. The per-kind sight radius
	# is looked up from BalanceData.fog using a field name composed from
	# `unit_type` (e.g., &"kargar" → "sight_kargar_cells").
	#
	# FogSystem is a project.godot autoload (line 38), so the direct call
	# is safe — no _autoload_or_null guard needed (FogSystem is always
	# present in the SceneTree once main.tscn loads). The Wave 3A.0 stub
	# returned -1; Track 1 of this wave ships the real impl returning a
	# non-zero handle. The _fog_handle field captures whichever value the
	# current impl returns; deregister at _exit_tree is idempotent for
	# both sentinel forms (0 default, -1 stub return).
	#
	# is_static=false because units MOVE (their vision cells must
	# recompute per fog_update tick). Buildings call this with is_static=
	# true (static cell-set caching).
	_register_fog_vision_source()

	# StateMachine setup. The Unit base class registers the universally-
	# useful states (Idle, Moving) here so every concrete unit type ships
	# with a valid FSM out of the box. Concrete subclasses (Kargar, Piyade,
	# ...) may register additional role-specific states (Gathering for
	# workers, Attacking for combat units, etc.) in their own _ready BEFORE
	# chaining to super._ready, so the base's init(&"idle") sees the full
	# state set when it lands.
	fsm.ctx = self
	# Register concrete states only if the subclass hasn't already done so
	# (registering the same state twice would clobber any subclass-specific
	# state instance in _states[id]). Idle and Moving are the wave-2 default
	# pair; Attacking, Gathering, etc. ship in later phases with their owning
	# systems.
	if not fsm._states.has(&"idle"):
		fsm.register(_UnitStateIdleScript.new())
	if not fsm._states.has(&"moving"):
		fsm.register(_UnitStateMovingScript.new())
	if not fsm._states.has(&"attacking"):
		fsm.register(_UnitStateAttackingScript.new())
	if not fsm._states.has(&"attack_move"):
		fsm.register(_UnitStateAttackMoveScript.new())
	# BUG-03 fix (Phase 2 session 1 wave 3): Dying must be registered so the
	# StateMachine death-preempt path (Contract §4.2 — _on_unit_health_zero)
	# can land the transition. Without this register, _apply_transition
	# push_errors on the missing &"dying" entry and the unit stays alive in
	# the scene tree, leaving zombie corpses for attackers to keep engaging.
	if not fsm._states.has(&"dying"):
		fsm.register(_UnitStateDyingScript.new())
	# Phase 3 wave 1A — gather loop states. See preload-const header above
	# for the "register on every Unit" rationale. Phase 3 only the Kargar
	# uses them; combat units never receive a &"gather" command so the
	# registered-but-never-entered cost is one RefCounted state per unit
	# per id, tiny.
	if not fsm._states.has(&"gathering"):
		fsm.register(_UnitStateGatheringScript.new())
	if not fsm._states.has(&"returning"):
		fsm.register(_UnitStateReturningScript.new())
	# Phase 3 wave 1C — building placement state. See preload-const
	# header above for the "register on every Unit" rationale.
	if not fsm._states.has(Constants.STATE_CONSTRUCTING):
		fsm.register(_UnitStateConstructingScript.new())
	# init() lands the unit on the starting state and connects the
	# death-preempt signal. Subclasses that want a different starting
	# state can call fsm.init(&"<id>") before super._ready (init is
	# idempotent on already-initialized FSMs only insofar as the
	# subclass takes care to avoid double-init; we don't double-init
	# here ourselves).
	if not fsm._states.is_empty() and fsm.current == null:
		fsm.init(&"idle")

	# Wire the FSM into the simulation tick. Until the MovementSystem phase
	# coordinator lands (LATER item per BUILD_LOG 2026-05-01 wave 2), each
	# Unit subscribes to EventBus.sim_phase directly and ticks its own FSM
	# during the &"movement" phase. This is what the coordinator will do
	# later — iterate units and call fsm.tick — just without a central
	# registry. Order across units is signal-handler order (engine-defined;
	# stable per build, not formally deterministic across Godot versions).
	# For Phase 1 visual testing that is good enough; the coordinator will
	# take over deterministic ordering when it ships.
	if not EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.connect(_on_sim_phase)

	# Wave 3-Sim mirror C2.1 — emit unit_spawned for end-of-_ready latching
	# consumers (HeadlessMatchRunner's iran_first_piyade_tick; Phase 5+
	# sound-FX + tutorial cues). Payload is a Dictionary so future fields
	# extend without breaking subscribers; current keys are documented at
	# the signal declaration in event_bus.gd.
	EventBus.unit_spawned.emit({
		&"unit_type": unit_type,
		&"team": team,
		&"unit_id": unit_id,
		&"position": global_position,
	})


# Disconnect on tree exit so a freed unit's FSM doesn't keep ticking after
# queue_free. Symmetric with the connect in _ready.
#
# Wave 3A.5 Track 2 — also deregister the fog vision source here. _exit_tree
# fires on ALL freeing paths: the death-preempt path (HealthComponent emits
# unit_died → StateMachine transitions to &"dying" → UnitState_Dying.enter
# calls queue_free.call_deferred → Godot eventually fires _exit_tree before
# completing the free), manual queue_free in tests, scene-tree teardown.
# Deregistering here ensures the fog grid no longer references a freed
# CharacterBody3D, regardless of how the free was triggered.
#
# Per FogSystem.deregister_vision_source contract: idempotent — safe for
# any handle value including 0 (default sentinel) and -1 (Wave 3A.0 stub
# return). Calling unconditionally is correct.
func _exit_tree() -> void:
	if EventBus.sim_phase.is_connected(_on_sim_phase):
		EventBus.sim_phase.disconnect(_on_sim_phase)
	FogSystem.deregister_vision_source(_fog_handle)
	_fog_handle = 0


# Phase-signal handler. Drives fsm.tick during the &"movement" phase only.
# Uses SimClock.SIM_DT (the canonical fixed delta) so this path matches both
# the live accumulator and the tests that call `fsm.tick(SimClock.SIM_DT)`
# directly — same code, same numbers.
func _on_sim_phase(phase: StringName, _tick: int) -> void:
	if phase != &"movement":
		return
	if fsm == null or fsm.current == null:
		return
	fsm.tick(SimClock.SIM_DT)


# Wave 3A.5 Track 2 — register this unit with FogSystem as a vision source.
#
# Looks up the per-kind sight radius from BalanceData.fog using a field
# name composed from unit_type (e.g., &"kargar" → "sight_kargar_cells").
# Stores the returned handle in _fog_handle for the matching deregister
# at _exit_tree.
#
# Per §9.H3: this is the FIRST runtime read of
# `BalanceData.fog.sight_<unit_type>_cells`. The defensive pattern mirrors
# _apply_balance_data_defaults — load BalanceData, navigate to the fog
# sub-resource, compose the field name, type-check the return.
#
# Defensive shape: when ANY step fails (BalanceData absent, fog sub-resource
# null, unknown unit_type, missing field), the function early-bails AND
# leaves _fog_handle at its default 0. The deregister at _exit_tree is
# then a no-op (FogSystem.deregister_vision_source is idempotent for 0).
# This preserves test fixtures that construct bare Unit.new() without the
# full BalanceData chain.
#
# H3 typo-bait surface: if a future unit kind ships with a typo'd field
# name (e.g., "sight_kargarr_cells" instead of "sight_kargar_cells"),
# the `.get(field_name)` returns null + the type check fails + the
# function early-bails with _fog_handle = 0. The unit appears in the
# world but reveals nothing — silent failure mode flagged in
# brief §5.2. The test_unit.gd H3 dogfood test catches this by
# asserting each kind's lookup returns the right value at HEAD.
func _register_fog_vision_source() -> void:
	if unit_type == &"":
		return  # Base Unit with no concrete type — no fog vision source.
	# Compose the per-kind field name. Per FogConfig schema:
	#   sight_kargar_cells / sight_piyade_cells / sight_kamandar_cells /
	#   sight_savar_cells / sight_rostam_cells.
	# BUG-D4 fix: Turan unit_types are prefixed with "turan_" (e.g.,
	# "turan_piyade") but FogConfig field names are NOT prefixed — per
	# FOG_DATA_CONTRACT §2.2 "Turan units use the same keys (symmetric)."
	# Strip the prefix before the lookup. Mirrors combat_matrix.gd's
	# _turan_base_to_iran_key fold pattern.
	var lookup_kind: String = String(unit_type)
	if lookup_kind.begins_with("turan_"):
		lookup_kind = lookup_kind.substr(6)  # strip "turan_"
		if lookup_kind == "asb_savar":
			lookup_kind = "asb_savar_kamandar"  # special case per balance.tres
	var field_name: StringName = StringName(
		"sight_" + lookup_kind + "_cells")
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return  # No BalanceData on disk — bare-fixture path.
	var bd: Resource = load(path)
	if bd == null:
		return
	var fog_cfg: Variant = bd.get(&"fog")
	if fog_cfg == null or not (fog_cfg is Resource):
		return  # fog sub-resource absent (3A.0 ships it; pre-3A.0 fixtures bail).
	var radius_v: Variant = (fog_cfg as Resource).get(field_name)
	if typeof(radius_v) != TYPE_INT and typeof(radius_v) != TYPE_FLOAT:
		return  # Unknown kind / typo — H3 silent-failure detection point.
	var sight_radius_cells: int = int(radius_v)
	# Register. FogSystem is a project.godot autoload (line 38), direct call
	# is safe. is_static=false because units MOVE — per-tick recompute.
	_fog_handle = FogSystem.register_vision_source(
		self, team, sight_radius_cells, false)


# Read this unit's UnitStats from BalanceData (loaded from
# Constants.PATH_BALANCE_DATA) and apply defaults to the components.
# Defensive: if BalanceData isn't present, or doesn't have an entry for
# this unit_type, components keep whatever defaults the scene template
# set. This is the same "fall back to spec defaults" path FarrSystem uses
# (see scripts/autoload/farr_system.gd).
func _apply_balance_data_defaults() -> void:
	if unit_type == &"":
		return  # Base Unit with no concrete type — nothing to look up.
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return
	var bd: Resource = load(path)
	if bd == null:
		return
	var units: Variant = bd.get(&"units")
	if typeof(units) != TYPE_DICTIONARY:
		return
	var stats: Variant = (units as Dictionary).get(unit_type, null)
	if stats == null:
		return
	# Apply HP from stats.max_hp.
	var max_hp_value: Variant = stats.get(&"max_hp")
	if _health_component != null and (
		typeof(max_hp_value) == TYPE_FLOAT
		or typeof(max_hp_value) == TYPE_INT
	):
		_health_component.call(&"init_max_hp", float(max_hp_value))
	# Apply move speed from stats.move_speed.
	var move_speed_value: Variant = stats.get(&"move_speed")
	if _movement_component != null and (
		typeof(move_speed_value) == TYPE_FLOAT
		or typeof(move_speed_value) == TYPE_INT
	):
		_movement_component.set(&"move_speed", float(move_speed_value))
	# Apply combat fields from stats. CombatComponent ships in Phase 2 session 1
	# wave 1A (gameplay-systems); BalanceData fields are populated by
	# balance-engineer's wave 1C. All three reads are defensive — a unit with
	# no combat (e.g., Kargar with attack_damage_x100 = 0) tolerates missing
	# fields by keeping the component's defaults.
	if _combat_component != null:
		var attack_damage_x100_value: Variant = stats.get(&"attack_damage_x100")
		if typeof(attack_damage_x100_value) == TYPE_INT:
			_combat_component.set(&"attack_damage_x100", int(attack_damage_x100_value))
		var attack_speed_value: Variant = stats.get(&"attack_speed_per_sec")
		if typeof(attack_speed_value) == TYPE_FLOAT \
				or typeof(attack_speed_value) == TYPE_INT:
			_combat_component.set(&"attack_speed_per_sec", float(attack_speed_value))
		var attack_range_value: Variant = stats.get(&"attack_range")
		if typeof(attack_range_value) == TYPE_FLOAT \
				or typeof(attack_range_value) == TYPE_INT:
			_combat_component.set(&"attack_range", float(attack_range_value))
		# Phase 2 session 2 wave 2A — propagate this unit's type and the
		# CombatMatrix so CombatComponent._sim_tick can scale damage by the
		# RPS multiplier at damage-fire time. Defensive: missing matrix is
		# tolerated (CombatComponent treats it as 1.0× neutral).
		_combat_component.set(&"attacker_unit_type", unit_type)
		var combat_matrix: Variant = bd.get(&"combat")
		if combat_matrix is Resource:
			_combat_component.set(&"combat_matrix", combat_matrix)


# === Command queue helpers (per State Machine Contract §2.5) ================
# These are the *only* sanctioned write paths into command_queue. Player
# input layer and AI controllers both call these; nothing else writes the
# queue.

## Replace the unit's queue with a fresh single-Command. Used for
## right-click-style "drop everything and do this" semantics. Per Contract
## §3.5 — same primitive AI panic-retreat uses.
func replace_command(kind: StringName, payload: Dictionary) -> void:
	command_queue.clear()
	var cmd: Command = CommandPool.rent()
	cmd.kind = kind
	cmd.payload = payload
	command_queue.push(cmd)
	fsm.transition_to_next()


## Append a Command to the end of the queue. Used for Shift+click queueing.
## Does not request a transition; the current state finishes naturally and
## §3.4's transition_to_next picks up the new top.
func append_command(kind: StringName, payload: Dictionary) -> void:
	var cmd: Command = CommandPool.rent()
	cmd.kind = kind
	cmd.payload = payload
	command_queue.push(cmd)


# === Legibility helpers (per State Machine Contract §6.5) ==================

func is_idle() -> bool:
	if fsm.current == null:
		return true
	return fsm.current.id == &"idle"


func is_engaged() -> bool:
	if fsm.current == null:
		return false
	return fsm.current.id in [&"attacking", &"casting"]


func is_dying() -> bool:
	if fsm.current == null:
		return false
	return fsm.current.id == &"dying"


func is_busy() -> bool:
	if fsm.current == null:
		return false
	return fsm.current.id in [&"constructing", &"gathering", &"casting"]
