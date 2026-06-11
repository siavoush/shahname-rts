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
##   Local-accumulation pattern — dehqan-Throne reciprocity made spatially
##   explicit (Wave 3-LocalDropoffs, 2026-05-25):
##
##   Mazra'eh now implements RNC §5.2 IDropoffTarget for grain — workers
##   harvesting from this farm deposit grain HERE (local granary) before any
##   onward flow to the Throne. This surfaces the Shahnameh-era economic-
##   political fact that the dehqan's land is itself a *site of accumulation*
##   distinct from the royal treasury: harvested grain is held at the
##   farmstead's granary before any tax-flow leaves. The mechanic preserves
##   the "wealth flows to the takht" framing established by `throne.gd`
##   (Wave-3-Throne) — Mazra'eh is the FIRST stop, not the final terminus.
##
##   Forward-compat seam (Phase 4+ Trade & Transport scope): the local-store
##   accumulation point becomes the caravan-origin once Trade & Transport
##   ships. The `&"grain_depots"` SceneTree group + `dropoff_for_team_by_kind`
##   API shape are the structural seams future caravan-source consumers will
##   read; the cultural framing here (farmstead-granary as staging yard) is
##   the cultural seam future caravan-mechanic prose will inherit. See
##   `QUESTIONS_FOR_DESIGN.md` 2026-05-24 "Trade & Transport economy" entry.
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
##   - extract_ticks = 90 (3s at SIM_HZ=30 — cultural long-dwell; deliberate
##     hardcode, see _ROOM_A_EXTRACT_TICKS deferral comment).
##   - yield_per_trip_x100 + max_slots read from BalanceData.economy.
##     resource_nodes (grain_yield_per_trip × 100 / farm_max_workers) at
##     _ready — wave/b1-mine-ssot SSOT fix. Room A's 2-Grain/trip value
##     lives in data/balance.tres, not here.
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

## Wave-3-LocalDropoffs (session 9): the RESOURCE kind this Mazra'eh
## accepts as an IDropoffTarget. Distinct from `kind = &"mazraeh"` (the
## Building kind) per RNC §4.6's kind-vs-resource_kind distinction.
##
## The kind-filter behavior: `deposit()` rejects any non-grain deposit
## with a loud log + worker carry zeroed (BUG-C1/D1/D2 defensive-fallback-
## masking lesson: rejection without carry-zero is a silent-loss bug).
## Per brief v1.0.1 §3.1 item 4 + architecture-reviewer C2.1 mitigation:
## the lookup-side filter (ResourceSystem.dropoff_for_team_by_kind) is the
## canonical gate — should NEVER pass a kind-mismatched depot through.
## The building-side filter here is defense-in-depth + a bug-signal log
## when the invariant is ever violated.
const ACCEPTED_KIND: StringName = Constants.KIND_GRAIN

## SceneTree group name for grain-depot lookup. ResourceSystem.dropoff_for_
## team_by_kind iterates this group filtered by team + ACCEPTED_KIND to
## find a worker's deposit target for grain. Mirrors Throne's &"thrones"
## group pattern (Wave-3-Throne) + RNC §5.2 forward-compat-seams §3.3.
const GRAIN_DEPOTS_GROUP: StringName = &"grain_depots"

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1

## Wave-3-LocalDropoffs forward-compat scaffold (brief v1.0.1 §2 + C4.3):
## the per-Mazra'eh accumulation buffer for Trade & Transport Q2. Today
## this field is unused — `deposit()` calls `ResourceSystem.change_resource`
## directly (deposit-RELAY shape). Q2 will refactor `deposit()` to credit
## `_local_stock_x100 += amount` + emit caravans on full (deposit-
## ACCUMULATOR shape). Declaring the field now signals Q2 intent and
## avoids a Property-Schema-Change-In-Phase-4 ripple. Fixed-point per
## Sim Contract §1.6 (x100 scale; same as ResourceSystem._coin_x100 etc.).
var _local_stock_x100: int = 0

# Dwell ticks — DELIBERATE hardcode (wave/b1-mine-ssot probe outcome,
# 2026-06-08): Room A (02g §2.4, ratified 2026-05-14) fixed Mazra'eh's dwell
# at 90 ticks (3s) explicitly DISTINCT from MineNode's 60 — the dehqan
# "stewardship of the land" cultural texture is per-kind. The only existing
# BalanceData schema field, economy.resource_nodes.trip_full_load_ticks
# (= 60, RNC §7: "Both use trip_full_load_ticks"), is SHARED by mine and
# farm and cannot express the ratified per-kind split; wiring it here would
# either erase the 3s cultural dwell or retime the mine. A farm-specific
# schema field would fix this, but inventing schema fields is out of scope
# for the SSOT-fix track — deferred to balance-engineer's next schema pass.
const _ROOM_A_EXTRACT_TICKS: int = 90  # 3s dwell (cultural long-dwell, Room A)

# §9.L9 visible-fallback values for the BalanceData-driven tunables below —
# used ONLY when the _ready read fails (file missing / schema mismatch).
# Values match the Room A resolution so a fallback farm still behaves as
# designed; the "[mazraeh] balance_config_missing" log is the visibility
# signal (fallback-by-failure-visibility-shape).
const _FALLBACK_YIELD_PER_TRIP_X100: int = 200  # 2 Grain/trip (Room A R1-α)
const _FALLBACK_MAX_SLOTS: int = 1              # tend-the-field model (RNC §7)

# Fixed-point scale per Sim Contract §1.6: BalanceData resource-node keys
# are whole-unit ints (RNC §7); the gather payload is x100 ints.
const _X100: int = 100

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
# max_slots + yield_per_trip_x100 resolve from BalanceData.economy.
# resource_nodes (farm_max_workers / grain_yield_per_trip) in _ready —
# wave/b1-mine-ssot SSOT fix (review GP-3). Initializers are the §9.L9
# visible fallbacks; they only survive when the BalanceData read fails.
var max_slots: int = _FALLBACK_MAX_SLOTS
var yield_per_trip_x100: int = _FALLBACK_YIELD_PER_TRIP_X100


func _init() -> void:
	kind = KIND_MAZRAEH


func _ready() -> void:
	kind = KIND_MAZRAEH
	super._ready()
	# Wave-3-LocalDropoffs (session 9) — join the &"grain_depots" group so
	# ResourceSystem.dropoff_for_team_by_kind can find this instance for
	# grain-carrying workers. Mirrors Throne's &"thrones" group join
	# (throne.gd:_ready) + RNC §5.2 group-iteration anti-misuse warning
	# (mirror C1.2: buildings use SceneTree groups, not SpatialIndex).
	add_to_group(GRAIN_DEPOTS_GROUP)
	_resolve_balance_config()
	print("[mazraeh] _ready team=%d position=%s unit_id=%d joined=%s" % [
		team, str(global_position), unit_id, str(GRAIN_DEPOTS_GROUP)])


# Read the BalanceData-backed gather tunables (grain_yield_per_trip,
# farm_max_workers) from economy.resource_nodes via the canonical defensive
# lookup chain (BUG-C1 + §9.L11; mirrors _resolve_fog_sight_cells below and
# MineNode._resolve_balance_config). wave/b1-mine-ssot SSOT fix: pre-fix,
# these were hardcoded and designer edits to the .tres keys silently did
# nothing (review GP-3). extract_ticks deliberately NOT wired — see the
# _ROOM_A_EXTRACT_TICKS deferral comment.
func _resolve_balance_config() -> void:
	var cfg: Resource = _resource_node_config_or_null()
	if cfg == null:
		# §9.L9 visible fallback — loud log so a misconfigured BalanceData
		# is diagnosable from the scroll, never silent.
		print("[mazraeh] balance_config_missing — using visible fallbacks "
			+ "max_slots=%d yield_per_trip_x100=%d" % [max_slots, yield_per_trip_x100])
		return
	yield_per_trip_x100 = _cfg_int(cfg, &"grain_yield_per_trip",
		_FALLBACK_YIELD_PER_TRIP_X100 / _X100) * _X100
	max_slots = _cfg_int(cfg, &"farm_max_workers", _FALLBACK_MAX_SLOTS)
	print("[mazraeh] config_resolved source=balance_data max_slots=%d "
		% max_slots
		+ "yield_per_trip_x100=%d extract_ticks=%d(hardcode, Room A)"
		% [yield_per_trip_x100, extract_ticks])


# Defensive chain to the ResourceNodeConfig sub-resource. Returns null on
# any failure step (caller falls back loudly per §9.L9).
func _resource_node_config_or_null() -> Resource:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var econ: Variant = bd.get(&"economy")
	if econ == null or not (econ is Resource):
		return null
	var cfg: Variant = (econ as Resource).get(&"resource_nodes")
	if cfg == null or not (cfg is Resource):
		return null
	return cfg as Resource


# Typed field read with per-field fallback — same terminal-step shape as
# building.gd::_resolve_max_hp (typeof check before cast).
func _cfg_int(cfg: Resource, field: StringName, fallback: int) -> int:
	var v: Variant = cfg.get(field)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		print("[mazraeh] balance_field_missing field=%s — using fallback %d"
			% [field, fallback])
		return fallback
	return int(v)


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
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
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
## has_method branching. Deliberately NOT BalanceData-wired — see the
## _ROOM_A_EXTRACT_TICKS deferral comment (per-kind dwell has no schema
## field; trip_full_load_ticks is shared with MineNode).
var extract_ticks: int = _ROOM_A_EXTRACT_TICKS


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


func _resolve_fog_sight_cells() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var fog_cfg: Variant = bd.get(&"fog")
	if fog_cfg == null:
		return 0
	var v: Variant = fog_cfg.get(&"sight_mazraeh_cells")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


func _exit_tree() -> void:
	# Wave 3-BuildingDestructibility (session 9, architecture-reviewer
	# C1.2 BLOCKER fix-up): super-call required.
	super._exit_tree()
	if _fog_handle >= 0:
		var fog: Node = _autoload_or_null(&"FogSystem")
		if fog != null and fog.has_method(&"deregister_vision_source"):
			fog.call(&"deregister_vision_source", _fog_handle)
		_fog_handle = -1


# === IDropoffTarget protocol — RNC §5.2 (Wave-3-LocalDropoffs, session 9) ===
#
# Mazra'eh implements the duck-typed IDropoffTarget protocol for GRAIN-
# carrying workers. The protocol is two methods + the canonical name
# signatures per RNC §5.2 — mirrors Throne's implementation at
# throne.gd:344-380 (only ONE difference: Throne accepts all kinds;
# Mazra'eh kind-filters to ACCEPTED_KIND = Constants.KIND_GRAIN).
#
# Today's shape (deposit-RELAY): `deposit()` calls
# `ResourceSystem.change_resource` directly. No local accumulation.
# Tomorrow's shape (Q2 Trade & Transport deposit-ACCUMULATOR): refactor
# to credit `_local_stock_x100 += amount` + emit caravans on full. The
# protocol method signatures stay; bodies change. See brief v1.0.1 §2
# "Non-throwaway property" for the platform-shape preserved/internals
# refactored boundary.
#
# Mirror C1.4 — only-one-path-per-cycle: `deposit()` is the chokepoint
# call site when Mazra'eh-routed; `UnitState_Returning._perform_deposit`
# MUST NOT also call `change_resource` for the same gather cycle. The
# brief v1.0.1 §3.1 item 5 (re-query in `_perform_deposit`) ensures the
# routing decision is fresh — if a Mazra'eh was destroyed mid-walk, the
# Returning state's re-query returns Throne (or null) and the deposit
# goes there.


## Implements IDropoffTarget — see RESOURCE_NODE_CONTRACT.md §5.
##
## Accepts grain deposits. Rejects coin (or any non-grain kind) with a
## loud log + worker carry zeroed per architecture-reviewer C2.1
## mitigation: rejection without carry-zero is a silent-loss bug shape
## (BUG-C1/D1/D2 defensive-fallback-masking lesson).
##
## Per brief v1.0.1 §3.1 item 4: lookup-side filter
## (ResourceSystem.dropoff_for_team_by_kind) is the canonical gate —
## should NEVER pass a kind-mismatched depot through. Building-side
## filter here is defense-in-depth + a bug-signal log if the invariant
## is ever violated upstream.
##
## `amount` is already-x100 fixed-point (UnitState_Returning passes
## `_carry_amount_x100` directly per the existing convention; see
## throne.gd:deposit header for the canonical signature documentation).
##
## Pre-condition: caller is inside the unit's _sim_tick path — on-tick
## by construction (Sim Contract §1.3 + Wave-3-Throne Throne.deposit
## header rationale).
func deposit(resource_kind: StringName, amount: int, worker: Unit) -> void:
	if amount <= 0:
		# Zero/negative deposit is a no-op (matches Throne/Returning's
		# existing skip-empty-carry guard).
		return
	var worker_id: int = -1
	if worker != null and is_instance_valid(worker):
		worker_id = worker.unit_id
	if resource_kind != ACCEPTED_KIND:
		# Kind mismatch — REJECT. This branch should never fire if the
		# lookup-side filter (dropoff_for_team_by_kind) is correct; the
		# loud log enables diagnosis when it does fire.
		print("[mazraeh] deposit_rejected kind_mismatch got=%s expected=%s worker=%d team=%d" % [
			str(resource_kind), str(ACCEPTED_KIND), worker_id, team])
		# Zero the worker's carry so the stale carry doesn't survive to
		# next gather cycle. Per architecture-reviewer C2.1: rejection
		# WITHOUT carry-zero is a silent-loss bug shape.
		if worker != null and is_instance_valid(worker):
			if &"_carry_kind" in worker:
				worker.set(&"_carry_kind", &"")
			if &"_carry_amount_x100" in worker:
				worker.set(&"_carry_amount_x100", 0)
		return
	# Kind-match path. §9.M6 log BEFORE the chokepoint call so failures
	# (off-tick assertion crash etc.) are still visible in the log scroll.
	print("[mazraeh] deposit_received from=%d kind=%s amount_x100=%d team=%d" % [
		worker_id, str(resource_kind), amount, team])
	# Canonical chokepoint call. Mirror C1.4: Mazra'eh owns this call
	# when this path fires; UnitState_Returning's inline change_resource
	# at the fallback branch MUST NOT also fire for the same cycle.
	#
	# Future (Q2 Trade & Transport): replace this with
	#   _local_stock_x100 += amount
	# and emit caravans on full. The brief v1.0.1 §2 forward-compat seam.
	ResourceSystem.change_resource(
		team, resource_kind, amount, &"gather_deposit", worker)


## Implements IDropoffTarget — see RESOURCE_NODE_CONTRACT.md §5.
##
## Returns the world position the worker should walk to BEFORE depositing.
## Mirrors Throne.get_deposit_position(): a small Y nudge so the worker
## visually arrives at the building's footprint center. Future refinement
## (Phase 4 polish): a $DepositMarker child Node3D for the farm-edge
## geometry. UnitState_Returning.enter() reads this to set the walk-back
## target.
func get_deposit_position() -> Vector3:
	return global_position + Vector3(0.0, 0.5, 0.0)


# === Destruction handler — subclass override =================================

## Wave 3-BuildingDestructibility (session 9). On hp=0:
##   1. Unregister this Mazra'eh as a ResourceSystem gather node so the
##      registry doesn't hold a freed-Object ref. Active gather workers
##      handle dead-target via existing `is_instance_valid(_target_node)`
##      check in UnitState_Gathering:162-164 — slot release is automatic
##      on next worker tick.
##   2. Log the cleanup for live-test diagnostics.
##   3. Call super (latch + generic emit + queue_free).
##
## Per §3.1.a checklist. Group memberships (&"buildings", &"grain_depots",
## &"resource_nodes") auto-removed on queue_free per Godot SceneTree
## convention.
func _on_health_zero(unit_id_in: int) -> void:
	if _destruction_emitted:
		return
	# Unregister from ResourceSystem's resource-node registry. Pitfall #16
	# implicit guard: ResourceSystem.unregister_node tolerates an unknown
	# node (idempotent — see resource_system.gd `unregister_node`).
	# (§9.M7 L7 cleanup: former `if ResourceSystem.has_method(...)` guard
	# was a stale relic — unregister_node is ratified ResourceSystem API;
	# the direct call fails loudly on contract regression.)
	ResourceSystem.unregister_node(self)
	print("[mazraeh] unregistered_resource_node unit_id=%d" % unit_id)
	# Base handles latch + generic emit + queue_free.
	super._on_health_zero(unit_id_in)
