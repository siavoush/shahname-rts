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
@onready var _selectable_component: Node = get_node_or_null(^"SelectableComponent")
@onready var _spatial_agent: Node = get_node_or_null(^"SpatialAgentComponent")


## Returns the HealthComponent child. Untyped (Variant via Node return) to
## avoid hard class_name dependencies at parse time; callers may type-narrow
## with `as HealthComponent` if they want.
func get_health() -> Node:
	return _health_component


func get_movement() -> Node:
	return _movement_component


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
	if _selectable_component != null:
		_selectable_component.set(&"unit_id", unit_id)

	# Initialize component defaults from BalanceData (best-effort — concrete
	# unit-type subclasses or scene scripts may have already set values).
	_apply_balance_data_defaults()

	# StateMachine setup. Concrete unit types (Kargar, etc.) register their
	# states in their own _ready BEFORE chaining to super._ready, so by the
	# time we reach this point in the base, the state list is populated.
	# If a unit ships with no states registered (the bare base used in
	# tests), we skip init — the test sets up its own fsm fixture.
	fsm.ctx = self
	if not fsm._states.is_empty():
		# Default to Idle if it was registered. Concrete subclasses that
		# want a different starting state call fsm.init(&"<id>") themselves
		# before super._ready.
		if fsm._states.has(&"idle"):
			fsm.init(&"idle")


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
