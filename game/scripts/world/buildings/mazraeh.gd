extends "res://scripts/world/buildings/building.gd"
##
## Mazra'eh (مزرعه) — Iran grain-farm building. Dual-nature: a Building
## that also presents the duck-typed ResourceNode gather surface so
## UnitState_Gathering treats it identically to MineNode.
##
## Source: 01_CORE_MECHANICS.md §3 (Iran economy — Grain as the pop-sustain
## resource) + §5 (Mazra'eh: "Grain source. Workers gather Grain here.
## Place on fertile-tile terrain.") + docs/RESOURCE_NODE_CONTRACT.md §4
## (duck-typed gather seam, UnitState_Gathering L143 has_method check).
## Phase 3 session 2 wave 1A — kickoff doc 02g_PHASE_3_SESSION_2_KICKOFF.md
## §2.4 (Room A resolution: trip-based long-dwell with R1-α cultural texture).
##
## Cultural note — dehqan (دهقان), the landed cultivator:
##   The *dehqan* (lit. "landed cultivator", sometimes glossed "lord of the
##   village") is among the Shahnameh's most resonant social figures.
##   Ferdowsi himself was dehqan stock — the opening
##   lines of the Shahnameh invoke the dehqan tradition of preserving the
##   ancient stories as an act of stewardship. The dehqan is not a peasant;
##   he is a custodian of ancestral memory, attached to a specific parcel of
##   land that he cultivates across generations. The farm is not just an
##   economic unit — it is the embodiment of settled continuity, of the
##   relationship between a people and the soil that defines them.
##
##   The mechanic surfaces this in the dwell time: a kargar dwells 3 seconds
##   at the Mazra'eh (90 ticks at SIM_HZ=30) vs 2 seconds at a mine (60
##   ticks). The grain yield is small per trip (2 Grain, vs 10 Coin from a
##   mine). The farm is not fast extraction — it is patient stewardship. The
##   player who invests in farms gets a steady, undepletable grain supply;
##   the player who ignores farms eventually cannot feed their armies (pop-cap
##   fails first, then unit production stalls). This is the economic pressure
##   the Shahnameh's Iran-side narrative is built on: the settled people
##   persist through cultivation, not conquest.
##
##   Ferdowsi's own identity here is relevant: he wrote the Shahnameh while
##   his dehqan lands were taxed away by Ghaznavid pressures. The act of
##   preservation — the farm, the story — as resistance to forces that would
##   uproot them both. A subtle reading, but the game's cultural authenticity
##   rule (CLAUDE.md: "load-bearing design constraints, not flavor") means
##   the mechanical weight of the farm should reflect this depth.
##
##   Cross-faction caveat (per building.gd header's shahnameh-loremaster note):
##   Turan's relationship to grain is not the same as Iran's. The Turanian
##   nomadic tradition does not anchor dignity to farmed land — it anchors it
##   to the *otaq* (tent household, Q3-pending), the herd, and the trade-route.
##   A Turan-side grain analogue, when it ships, will most likely take the form
##   of a **karavan** (کاروان) — a mobile caravan unit that travels between hubs
##   and arrives with Grain payloads on a timer, vulnerable to interception.
##   This is mechanically distinct from a static gather node and preserves the
##   Turan-as-mobile identity attested in 00_SHAHNAMEH_RESEARCH.md §natural-core.
##   Do not clone Mazra'eh as a Turan building (flagged for session N when Turan
##   economy ships; will require fresh loremaster review).
##
## What lives here vs in Building base:
##   - kind = &"mazraeh" (dual-init pattern as in khaneh.gd).
##   - Duck-typed three-call API (request_extract / complete_extract /
##     release_extract) — presented as methods on this Node3D subclass, NOT
##     by extending ResourceNode. UnitState_Gathering's has_method check at
##     L143 ("request_extract") is the seam; no UnitState_Gathering changes.
##   - reserves_x100 = -1 sentinel (infinite, per ResourceNode contract §1.5
##     and resource_node.gd complete_extract branch on line 174). Mazra'eh
##     does not deplete. Building destruction lifecycle (HP/HealthComponent)
##     ships in session-2 wave 1C — until then, deregistration on destruction
##     is a forward-compat hook that cannot fire.
##   - extract_ticks = 90 (3s at SIM_HZ=30 — cultural long-dwell).
##   - grain_yield_per_trip_x100 = 200 (2 Grain/trip at BalanceData default).
##   - _on_placement_complete: register with ResourceSystem as a gather target.
##   - Fertile-tile placement validation: is_valid_placement() class method
##     that checks TerrainSystem.is_fertile_tile(world_pos) — the build menu
##     greys the Mazra'eh button when the cursor is off a fertile tile.
##
## Visual placeholder per CLAUDE.md "colored rectangles for buildings":
##   - BoxMesh 4.0 × 0.3 × 4.0 (wide, flat — a field, not a building).
##     Height 0.3 so it reads as terrain-adjacent, not a structure. Width
##     4×4 world units = ~2 navmesh cells — workers walk ONTO it, not around
##     it. NO NavigationObstacle3D on Mazra'eh (contrast to Khaneh).
##   - Color(0.55, 0.75, 0.35) — agricultural green, distinct from the earthy
##     tan of Khaneh (0.78, 0.65, 0.45) and the sandy-brown of kargar
##     (0.65, 0.5, 0.3). Should read as "plant" from across the map.
##
## Why extend Building (not ResourceNode):
##   Mazra'eh needs the full Building lifecycle: construction timer (wave 1C),
##   HP/HealthComponent (also wave 1C — not present in wave 1A), build-menu
##   integration, the &"buildings" SceneTree group, placement hooks.
##   ResourceNode has none of that — it is designed for permanent map features
##   (mines), not player-built structures. The duck-typed API (three methods on
##   this class that mirror ResourceNode's surface) is the clean seam. The
##   alternative — multiple inheritance, or an Interface node — is out of scope
##   for GDScript. Duck-type + has_method is idiomatic GDScript.
##
## Why extend by path-string (not class_name):
##   Same class_name registry race as khaneh.gd / mine_node.gd (see those
##   headers). Path-string extends sidesteps the race entirely.
##
## Room A convergence (2026-05-14 — world-builder-p3s2 + gp-sys-p3s2):
##   The "R1-α vs R1-β" framing dissolved when both agents read the shipped
##   code. Result: trip-based, long-dwell (R1-α shape), existing three-call
##   API unchanged. See 02g_PHASE_3_SESSION_2_KICKOFF.md §2.4 for full log.
class_name Mazraeh


const KIND_MAZRAEH: StringName = &"mazraeh"

# Wave-1A hardcoded tunables. TODO(phase-3-wave-1B): read from BalanceData
# once FogConfig + economy sub-resources ship.
const _WAVE_1A_EXTRACT_TICKS: int = 90  # 3s dwell (cultural long-dwell, Room A)

# === Duck-typed ResourceNode schema fields ===================================
#
# These fields match the ResourceNode property surface (RESOURCE_NODE_CONTRACT
# §4.5) so ClickHandler._is_resource_node_shaped() and any future consumer that
# reads the schema can discover this node without isinstance checks.
#
# click_handler.gd:447-460 checks: has_method(&"request_extract") AND
# &"is_gatherable" in n — both must pass or right-clicks fall through silently.
#
# Default false: Mazra'eh is not gatherable until construction completes.
# Wave 1C (session 3): _on_construction_complete() flips this to true after
# construction_ticks ticks elapse in UnitState_Constructing. Previously
# (wave 1A) the flip lived in _on_placement_complete (instant placement);
# moving it to Stage 2 is the operational-gating change.
# Default-false ensures any future Building subclass using this template as
# a reference does not accidentally allow gathering during construction.
var is_gatherable: bool = false
var resource_kind: StringName = Constants.KIND_GRAIN
var reserves_x100: int = -1   # -1 sentinel = infinite (never depletes)
var max_slots: int = 1         # single-slot for wave 1A
var yield_per_trip_x100: int = 200  # 2 Grain per trip (Room A R1-α)


func _init() -> void:
	kind = KIND_MAZRAEH


func _ready() -> void:
	kind = KIND_MAZRAEH
	super._ready()


# === Autoload helper =========================================================

# GDScript autoloads are SceneTree children, not C++ singletons.
# Engine.has_singleton() / Engine.get_singleton() are INERT for them.
# This pattern (from farr_gauge.gd:257) is the correct autoload discovery.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


# === Placement side-effect ===================================================

# Stage 1 — structural placement (place_at). Per the Building base class
# two-stage lifecycle (header): this runs on the placement-finalization
# tick, BEFORE the construction timer has elapsed. Side-effects here
# are STRUCTURAL (the building exists in the world) but NOT FUNCTIONAL
# (the building cannot yet be used). is_gatherable stays false until
# _on_construction_complete fires.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class: navmesh rebake (Task #144). Mazra'eh has no NavigationObstacle3D
	# (workers walk ONTO the farm, not around it), so the base class impl
	# finds nav == null and returns early — zero cost, correct behavior.
	super._on_placement_complete(placer_unit_id)
	# ResourceSystem.register_node ships (Phase 3 wave 1A, project.godot
	# autoload). The wave-1B has_method guard was obsolete after the
	# Stage-2 migration locked the autoload-presence question structurally;
	# removed at Task #117 (Wave-1C carry-forward). Pass resource_kind
	# (&"grain") — Mazra'eh.kind is &"mazraeh" (Building kind) so implicit
	# would register under the wrong bucket.
	ResourceSystem.register_node(self, resource_kind)
	# FogSystem ships in wave 3A. Forward-compat guard: use SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads — they are
	# SceneTree children, not C++ singletons). Sight=0, is_static=true.
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		_fog_node.call(&"register_vision_source", self, team, 0, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation (called by UnitState_Constructing
# after construction_ticks ticks elapse). The is_gatherable flip is the
# load-bearing operational gate: ClickHandler reads
# `&"is_gatherable" in n` AND `is_gatherable == true`
# (click_handler.gd:447-460), so right-clicks on a mid-construction
# Mazra'eh fall through silently — the player cannot accidentally
# route a worker to gather from a half-built farm.
#
# placer_unit_id is the worker that built this Mazra'eh; forwarded for
# symmetry with _on_placement_complete and potential future telemetry.
func _on_construction_complete(_placer_unit_id: int) -> void:
	# super-call discipline (session-3 retro §9, retrofitted in Wave 2A
	# fix-up): base _on_construction_complete is currently `pass`, but
	# the discipline applies regardless — when the base gains non-trivial
	# Stage-2 behavior in a future wave, every subclass already routes
	# through it. Mirrors Sarbaz-khaneh's super-call shape.
	super._on_construction_complete(_placer_unit_id)
	is_gatherable = true


# === Duck-typed ResourceNode gather surface ==================================
#
# These three methods mirror ResourceNode's request_extract / complete_extract
# / release_extract surface exactly. UnitState_Gathering's has_method check at
# L143 ("request_extract") is the discovery seam — no state changes needed.
# The slot bookkeeping is intentionally simple: one slot, one worker.
#
# reserves_x100 sentinel: Mazra'eh uses -1 (infinite). The base
# ResourceNode.complete_extract treats -1 as "skip depletion check" (see
# resource_node.gd lines 173-179). Here we replicate that logic inline since
# Mazra'eh doesn't extend ResourceNode.

var _occupied: Dictionary = {}  # unit_id (int) -> true


## Grants the gather slot. Returns false when not yet placed (is_complete
## false), slot is already full, or this worker already holds the slot.
func request_extract(unit_id: int) -> bool:
	if not is_complete:
		return false
	if _occupied.has(unit_id):
		return false
	if _occupied.size() >= max_slots:
		return false
	_occupied[unit_id] = true
	return true


## Releases the gather slot. Idempotent — safe to call on worker death
## before queue_free per RESOURCE_NODE_CONTRACT §4.1.
func release_extract(unit_id: int) -> void:
	_occupied.erase(unit_id)


## Returns grain payload for one completed trip. Slot does not need to be
## held (idempotent on unowned worker — returns empty payload).
## Payload: { kind: &"grain", amount_x100: int }
## Mazra'eh never depletes (reserves_x100 = -1 semantics): returns the
## full per-trip yield unconditionally.
func complete_extract(unit_id: int) -> Dictionary:
	if not _occupied.has(unit_id):
		return {&"kind": &"", &"amount_x100": 0}
	_occupied.erase(unit_id)
	return {&"kind": Constants.KIND_GRAIN, &"amount_x100": yield_per_trip_x100}


## The UnitState_Gathering state reads extract_ticks at slot-grant time
## (L210: `_dwell_remaining_ticks = int(_target_node.extract_ticks)`).
## Expose it as a field so the state's property read works without
## has_method branching.
var extract_ticks: int = _WAVE_1A_EXTRACT_TICKS


## Convenience accessor: how many slots are currently occupied.
## Used by tests and F4 debug overlay.
func occupied_slots() -> int:
	return _occupied.size()


# === Placement validation ====================================================

## Read the Mazra'eh's coin cost from BalanceData (in whole coin, not
## fixed-point). Used by the build menu to display the price next to
## the button. Same defensive fall-through as Khaneh.cost_coin —
## missing file / missing entry / wrong type all return 0 so the UI
## stays alive when BalanceData is misconfigured.
##
## Static-side-only helper — exposed as a class function so the build
## menu can read the cost without instantiating a Mazra'eh scene just
## to inspect a number. Mirrors khaneh.gd::cost_coin exactly.
static func cost_coin() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(KIND_MAZRAEH, null)
	if stats == null:
		return 0
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return 0
	return int(coin_v)


## Returns true when world_pos is on a fertile tile — used by the build menu
## to grey the Mazra'eh button when the cursor is off fertile terrain.
## TerrainSystem is a GDScript autoload (SceneTree child, not C++ singleton);
## Engine.has_singleton() would always return false — use SceneTree root instead.
static func is_valid_placement(world_pos: Vector3) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return true  # permissive fallback (headless test, no scene tree)
	var terrain: Node = tree.root.get_node_or_null(NodePath(&"TerrainSystem"))
	if terrain == null or not terrain.has_method(&"is_fertile_tile"):
		return true  # permissive fallback until TerrainSystem ships (wave 3A+)
	return terrain.is_fertile_tile(world_pos)
