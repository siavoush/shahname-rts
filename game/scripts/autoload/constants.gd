extends Node
##
## Constants — structural keys, enums, and identifiers used across the project.
##
## Per docs/TESTING_CONTRACT.md §1.1 and 02_IMPLEMENTATION_PLAN.md §2: this file
## holds STRUCTURAL constants and keys. It does NOT hold tunable gameplay
## numbers — those live in `BalanceData.tres` (balance-engineer's session 4
## deliverable). Examples:
##
##   - In here: signal name StringNames, phase StringNames, resource kind keys,
##              team identifiers, layer indices, file paths, "rarely changes"
##              values that affect code structure.
##   - In BalanceData: HP, damage, costs, build times, Farr deltas, ranges —
##              every number a balance pass would tune.
##
## Why split: balance-engineer iterates on tuning numbers in a tight loop. If
## those values lived in code constants, every tuning iteration would require
## a code edit + recompile + restart. Resources are hot-reloadable; constants
## are not. The split is documented in `docs/TESTING_CONTRACT.md` §1.1.
##
## Section headers below mirror the convention in `02a_PHASE_0_KICKOFF.md`:
## one logical group per `# === ... ===` header.

# === SIM PHASE NAMES =========================================================
# Canonical 30Hz tick pipeline phases. Matches docs/SIMULATION_CONTRACT.md §1.2
# and SimClock.PHASES. Phase coordinators listen on EventBus.sim_phase and
# branch on these StringNames. Keeping the names here means cross-system
# consumers don't typo phase strings — type-checked at the call site.

const PHASE_INPUT: StringName = &"input"
const PHASE_AI: StringName = &"ai"
const PHASE_MOVEMENT: StringName = &"movement"
const PHASE_SPATIAL_REBUILD: StringName = &"spatial_rebuild"
const PHASE_COMBAT: StringName = &"combat"
const PHASE_FARR: StringName = &"farr"
const PHASE_CLEANUP: StringName = &"cleanup"

# Convenience array in canonical order. SimClock.PHASES is the SSOT; this
# constant exists for consumers that want to iterate without taking a
# dependency on SimClock at parse time.
const PHASES: Array[StringName] = [
	PHASE_INPUT, PHASE_AI, PHASE_MOVEMENT, PHASE_SPATIAL_REBUILD,
	PHASE_COMBAT, PHASE_FARR, PHASE_CLEANUP,
]


# === EVENT BUS SIGNAL NAMES ==================================================
# StringName references for every signal declared on EventBus. Used by sinks,
# tests, and phase coordinators that switch on signal name. The string source
# of truth still lives in `event_bus.gd`; these constants exist so consumers
# don't pass raw strings (typos = silent connection failures).

const SIGNAL_TICK_STARTED: StringName = &"tick_started"
const SIGNAL_TICK_ENDED: StringName = &"tick_ended"
const SIGNAL_SIM_PHASE: StringName = &"sim_phase"

# Signals that land in later sessions/phases. Declared here for forward
# reference by code that wants to refer to them as keys (e.g., tests asserting
# absence). The actual `signal` declaration lives in `event_bus.gd` when the
# producer system ships.
const SIGNAL_FARR_CHANGED: StringName = &"farr_changed"
const SIGNAL_UNIT_DIED: StringName = &"unit_died"
const SIGNAL_UNIT_HEALTH_ZERO: StringName = &"unit_health_zero"
const SIGNAL_UNIT_STATE_CHANGED: StringName = &"unit_state_changed"
const SIGNAL_ABILITY_CAST: StringName = &"ability_cast"
const SIGNAL_SELECTION_CHANGED: StringName = &"selection_changed"


# === TEAMS ===================================================================
# Match teams. Iran is team 1, Turan team 2. team 0 is reserved for "neutral"
# (resource nodes, decorative props that don't take damage). team -1 is the
# query-filter sentinel meaning "any team" — see SpatialIndex.query_nearest_n.

const TEAM_NEUTRAL: int = 0
const TEAM_IRAN: int = 1
const TEAM_TURAN: int = 2

# Sentinel used by spatial queries to mean "no team filter". Matches the
# convention in docs/SIMULATION_CONTRACT.md §3.3.
const TEAM_ANY: int = -1


# === RESOURCE KINDS ==========================================================
# The two resources tracked in MVP per 01_CORE_MECHANICS.md §3. StringName
# keys; never integer-encoded so logs and signal payloads are self-describing.

const KIND_COIN: StringName = &"coin"
const KIND_GRAIN: StringName = &"grain"


# === MATCH PHASES ============================================================
# GameState.match_phase enumerates these. StringName keys match what
# MatchLogger writes to NDJSON for clean post-hoc filtering.

const MATCH_PHASE_LOBBY: StringName = &"lobby"
const MATCH_PHASE_PLAYING: StringName = &"playing"
const MATCH_PHASE_ENDED: StringName = &"ended"


# === MATCH OUTCOMES ==========================================================
# Set on GameState.winner_team when a match ends. NEUTRAL on draw or
# pre-match (lobby/playing); the explicit team values when one side wins.

const OUTCOME_NONE: int = TEAM_NEUTRAL
const OUTCOME_IRAN_WIN: int = TEAM_IRAN
const OUTCOME_TURAN_WIN: int = TEAM_TURAN


# === SPATIAL INDEX ===========================================================
# Grid cell size for the uniform-grid SpatialIndex (docs/SIMULATION_CONTRACT.md
# §3.1). 8m on the XZ plane; the Y axis is ignored (flat grid for MVP).
# This is structural, not tunable — moving it is a perf knob with knock-on
# effects on every query, so it lives here, not in BalanceData.

const SPATIAL_CELL_SIZE: float = 8.0


# === STATE IDS ===============================================================
# Canonical state-id StringNames used by StateMachine (docs/STATE_MACHINE_CONTRACT.md
# §2.2). Concrete unit-state classes ship in Phase 1; the ids are fixed here
# so tests, telemetry, and AI helpers (Unit.is_idle / is_engaged / is_dying)
# can reference them without restating the strings.

const STATE_IDLE: StringName = &"idle"
const STATE_MOVING: StringName = &"moving"
const STATE_ATTACKING: StringName = &"attacking"
const STATE_GATHERING: StringName = &"gathering"
const STATE_CONSTRUCTING: StringName = &"constructing"
const STATE_CASTING: StringName = &"casting"
const STATE_DYING: StringName = &"dying"


# === COMMAND KINDS ===========================================================
# Command.kind enum values per docs/STATE_MACHINE_CONTRACT.md §2.4.

const COMMAND_MOVE: StringName = &"move"
const COMMAND_ATTACK: StringName = &"attack"
const COMMAND_GATHER: StringName = &"gather"
const COMMAND_BUILD: StringName = &"build"
const COMMAND_ABILITY: StringName = &"ability"


# === STATE MACHINE LIMITS ====================================================
# Hard caps from docs/STATE_MACHINE_CONTRACT.md §2.4 / §3.3 / §7.1. These are
# structural (tied to allocation patterns), not tuning knobs — moving them
# would require revisiting CommandPool sizing and ring-buffer assumptions.

const COMMAND_QUEUE_CAPACITY: int = 32                  # per-unit hard cap
const STATE_MACHINE_TRANSITIONS_PER_TICK: int = 4       # bounded chain in tick()
const STATE_MACHINE_HISTORY_SIZE_UNIT: int = 16         # ring buffer entries
const STATE_MACHINE_HISTORY_SIZE_AI: int = 64           # AI controller has more


# === FILE PATHS ==============================================================
# Canonical resource paths. Centralized so renames are a one-line change.
# Files referenced here may not exist yet — the constant is the contract.

const PATH_BALANCE_DATA: String = "res://data/balance.tres"
const PATH_TELEMETRY_DIR: String = "res://data/telemetry/"
const PATH_TRANSLATIONS_DIR: String = "res://translations/"


# === MAP CONFIGURATION =======================================================
# Single source of truth for map dimensions. Structural constant — changing
# this would require nav mesh rebake, camera bound recalculation, and spawn
# position repositioning. Lives here, not in BalanceData, because it is
# structural (code shape changes), not a balance knob.
#
# MAP_SIZE_WORLD: the MVP map is a 256×256 world-unit square on the XZ plane
# (Y=0). Matches docs/02_IMPLEMENTATION_PLAN.md Phase 0 convergence checkpoint.
# Target match length: 15-25 minutes per 01_CORE_MECHANICS.md §6.
#
# NAV_AGENT_RADIUS: minimum clearance around obstacles the NavigationServer3D
# bakes into the navmesh. 0.5 world units — wide enough for infantry (smallest
# mobile unit). Per docs/RESOURCE_NODE_CONTRACT.md §3.2: buildings add their
# own NavigationObstacle3D; no runtime navmesh rebake after initial bake.

const MAP_SIZE_WORLD: float = 256.0
const NAV_AGENT_RADIUS: float = 0.5


# === DEBUG OVERLAY KEYS ======================================================
# F1-F4 binding registry. ui-developer's DebugOverlayManager (parallel session)
# reads these to wire toggles to the right registered overlays. Kept here so
# the engine layer doesn't need to import the UI layer.

const OVERLAY_KEY_F1: StringName = &"f1_pathfinding"
const OVERLAY_KEY_F2: StringName = &"f2_farr_log"
const OVERLAY_KEY_F3: StringName = &"f3_state_machine"
const OVERLAY_KEY_F4: StringName = &"f4_attack_ranges"
