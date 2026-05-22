extends "res://scripts/world/buildings/building.gd"
##
## Ma'dan (مَعدَن) — Iran "mine/source" building. Buff-emitter that boosts
## adjacent MineNode extraction yield. NOT itself a resource source; Ma'dan
## modifies the MineNode it's placed near.
##
## Source: 01_CORE_MECHANICS.md §5 (Iran buildings list) +
## Open Space Room A ratified-as-Option-B (2026-05-14) — Ma'dan as modifier-
## emitter, NOT a separate registry entry under &"coin". The MineNode it
## modifies is already registered; Ma'dan registers as an EXTRACTION MODIFIER
## on that mine via `mine.register_extraction_modifier(self)`.
##
## Phase 3 session 2 wave 1B (02g_PHASE_3_SESSION_2_KICKOFF.md §3) ships
## Ma'dan as the FIRST non-resource-producing Building subclass. Its template
## will be cloned for Atashkadeh (Farr-emitter), Dadgah / Barghah (Farr-
## generators) post-wave-1B. The kind-vs-resource_kind separation pattern
## from RNC §4.6 (Mazra'eh) does NOT apply here — Ma'dan does NOT produce a
## resource and does NOT register with ResourceSystem.register_node. Its
## entire effect is the buff it applies to adjacent MineNodes.
##
## Cultural note (labor-organization frame — per loremaster brief-time SUGGEST
## 2026-05-15; see 00_SHAHNAMEH_RESEARCH.md §1 lines 86-88 Pishdadian triad).
##
## *Ma'dan* (لit. "ore-source", the *generative place* where the earth yields
## metal; the same word in classical Persian extends metaphorically to
## *ma'dan-e elm* — "source of knowledge" — reflecting a reading of the
## underground as a *source* rather than merely a worksite). The gloss
## "mine" is too narrow — industrial-revolution baggage compresses what is,
## in Ferdowsi's frame, the place where the substance of the earth is in
## ongoing relation to the people who know how to bring it out.
##
## The Shahnameh anchors Ma'dan in the Pishdadian-age civilizational-
## invention triad — Hushang, Tahmuras, Jamshid — three kings whose reigns
## carry the discoveries that make settled Iran possible:
##   - **Hushang** strikes a stone and discovers fire — the first
##     transformation of inert matter into useful energy.
##   - **Tahmuras Divband** ("the Div-binder") subdues the divs and
##     forces them to teach writing, weaving, the elements of craft —
##     knowledge wrested from chaos and made transmissible.
##   - **Jamshid** discovers iron in the earth, teaches the working
##     of metal, invents armor, founds the order of social classes
##     including the smiths. Jamshid is the load-bearing anchor: every
##     subsequent Shahnameh moment in which a king mints coin, an
##     armorer forges a weapon, or Kaveh raises his blacksmith's banner
##     against Zahhak is unthinkable without Jamshid's metallurgical
##     gift. The mine is where Jamshid's inheritance is *practiced*.
##
## Crucially: Ma'dan is NOT the moment of discovery — that is a one-time
## mythic event in the Pishdadian age — but the gameplay surfacing of the
## *inherited practice*: how organized labor around an ore body, carrying
## the techniques Jamshid bequeathed, extracts more than scattered effort
## would. **This is a labor-organization frame, NOT a civic-continuity
## frame** (cf. Khaneh / Mazra'eh, which are civic-anchor buildings tied
## to settled household and land continuity). Ma'dan's anchor type is
## the practice-of-craft, transmitted across generations from the
## Pishdadian gift to the player's worker organizing extraction at the
## seam.
##
## Cross-faction caveat (loremaster leading hypothesis — per their
## brief-time SUGGEST 2026-05-15):
##
## Turan's Coin economy almost certainly routes through ***baj*** (باج,
## tribute) — extraction via demand rather than via labor-on-ore. Turan
## kings (Afrasiyab and predecessors) accumulate wealth through tribute
## from subject peoples, raided arms from defeated armies, control of
## trade caravans across the steppe corridors — NOT through fixed
## mining infrastructure organizing local labor. This is the leading
## hypothesis (cf. *karavan* for Mazra'eh's grain analogue) — singular,
## not a list.
##
## **Structural mismatch sharper than Mazra'eh.** For grain, both factions
## conceivably build farms (the Mazra'eh template could clone). For coin,
## Turan plausibly DOES NOT build mines at all in the leading-hypothesis
## economy — they take coin from those who mine. A naive clone-Ma'dan-to-
## Turan would be design-broken-by-template-inertia. DO NOT bake Ma'dan-
## style fixed-mining-buff into the Building base class — when Turan's
## Tier 2 economic mechanics ship (post-MVP), expect a fundamentally
## different shape (a tribute-event mechanic? A raid-spoils accumulator?).
## Per 00_SHAHNAMEH_RESEARCH.md §7's "design Turan as worthy rivals,
## not cartoon villains" rule: each faction's economy reflects its
## social organization; copy/paste between them produces hollow design.
##
## What lives here vs in the base class:
##   - kind = &"madan" (dual-init pattern as in khaneh.gd / mazraeh.gd).
##   - NO resource_kind, NO ResourceNode-shape fields (is_gatherable,
##     reserves_x100, max_slots, yield_per_trip_x100). Ma'dan is NOT a
##     gather target; click_handler.gd:447's `&"is_gatherable" in n`
##     check correctly EXCLUDES Ma'dan from gather routing.
##   - _on_placement_complete (Stage 1): fog vision registration + emit
##     building_placed for telemetry. Structural side-effects only.
##   - _on_construction_complete (Stage 2, session 3 wave 1C): find
##     nearest MineNode within radius, register as extraction modifier.
##     The mine-modifier buff applies from this tick onward — a half-
##     built Ma'dan does NOT buff its adjacent mine. The
##     register_extraction_modifier API is ratified in RNC v1.3.0 §4.7;
##     the wave-1B forward-compat has_method guard is gone.
##   - Static cost_coin() helper for the build menu.
## Base Building owns: kind/team/unit_id schema, place_at seam,
## &"buildings" group join, get_footprint_aabb(), unit_id counter.
##
## Visual placeholder per CLAUDE.md "colored rectangles for buildings":
##   - BoxMesh ~2.5 × 1.0 × 2.5 — slightly smaller than Khaneh's 2.0×1.2×2.0
##     footprint, taller than Mazra'eh's 4×0.3×4 flat field, distinct silhouette.
##   - Stone-grey color Color(0.5, 0.5, 0.55) — neutral mineral tone.
##     Distinct from:
##       * Khaneh tan (0.78, 0.65, 0.45)
##       * Mazra'eh green (0.55, 0.75, 0.35)
##       * MineNode gold (0.85, 0.7, 0.2) — the mine itself
##       * Kargar sandy-brown (0.65, 0.5, 0.3)
##     Reads as "industrial structure adjacent to the mine."
##
## Why extend by path-string (not class_name):
##   Same class_name registry race that bites Unit / Kargar / ResourceNode /
##   Khaneh / Mazra'eh. Path-string extends sidesteps the race entirely.
##
## Why _init AND _ready set kind:
##   Per kargar.gd's header / khaneh.gd's header / mazraeh.gd's header —
##   scene-instantiation order in Godot 4 resets @export defaults from the
##   .tscn definition BETWEEN _init and _ready. madan.tscn doesn't override
##   the `kind` export, so the engine would clobber any _init write back to
##   the base default (&""). The _ready setter is the canonical fix; _init
##   is kept so `Madan.new()` headless construction (no scene) also reports
##   the right kind — useful for tests.
class_name Madan


## Canonical kind StringName for the Ma'dan class. Matches the BalanceData
## lookup key (`buildings.madan` in balance.tres, once balance-engineer
## ships the bldg_madan sub-resource entry).
const KIND_MADAN: StringName = &"madan"

## Opaque FogSystem handle returned by register_vision_source at placement.
## Used to deregister when the building is removed from the scene tree.
## -1 = not registered (before placement or if FogSystem unavailable).
var _fog_handle: int = -1


# === Defensive fallback constants ===========================================
#
# These match balance-engineer's d798e78 `bldg_madan` SubResource values and
# serve as defensive fallbacks if the BalanceData entry is missing at load
# time. Same pattern as Khaneh.cost_coin() / Mazraeh.cost_coin() —
# "config error doesn't break the UI" — when balance.tres is unreachable
# or the bldg_madan entry is missing, the building still functions with
# reasonable defaults rather than zero-valued degenerate behavior.
#
# Per balance-engineer's commit message + kickoff design Qs (2026-05-14):
#   Q1 modifier_radius: 4m (1 fog cell)
#   Q2 multiplier: 1.5x = 150/100 in x100 fixed-point
#   Q3 stacking: not-stacking (first-registered-wins)
#   Q4 placement validity: free placement; no-op if no mine adjacent
#   Q5 cost: 40 Coin (01_CORE_MECHANICS.md §5 explicit; overrides brief's 75)

## Defensive fallback for modifier_radius_m. balance-engineer ships 4.0.
const _FALLBACK_MODIFIER_RADIUS_M: float = 4.0

## Defensive fallback for modifier_value_x100. balance-engineer ships 150.
const _FALLBACK_YIELD_MULTIPLIER_X100: int = 150

## Defensive fallback for coin_cost. balance-engineer ships 40 per
## 01_CORE_MECHANICS.md §5 ("Ma'dan (mine) — 40 coin").
const _FALLBACK_COIN_COST: int = 40


func _init() -> void:
	kind = KIND_MADAN


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (per the dual-init
	# pattern documented in khaneh.gd / mazraeh.gd headers). The base class
	# doesn't currently read kind directly, but the symmetry guards future
	# refactors.
	kind = KIND_MADAN
	super._ready()


# === Autoload helper =========================================================
#
# Same canonical pattern as mazraeh.gd:143-147. Engine.has_singleton() does
# NOT find GDScript autoloads (Pitfall #12 TWO-PART) — script autoloads
# register as direct SceneTree children, not C++/GDExtension singletons.
# This is the correct discovery pattern.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


# === Lifecycle hooks =========================================================
#
# Two-stage lifecycle per Building base (wave 1C session 3):
#   Stage 1 (_on_placement_complete) — STRUCTURAL: the building exists in
#     the world (visible, click-targetable, footprint registered with fog
#     when wave 3A ships).
#   Stage 2 (_on_construction_complete) — OPERATIONAL: the mine modifier
#     is registered, so the adjacent mine's effective yield is buffed
#     from this tick onward.
#
# Ma'dan's BUFF — the entire point of the building — is gated on Stage 2.
# A half-built Ma'dan reveals fog and emits the placement signal, but
# does NOT buff its adjacent mine until the construction timer elapses.

# Stage 1 — structural side-effects only.
#
# Free placement (per design Q4): a Ma'dan placed without an adjacent
# mine still places successfully. The mine-discovery now happens at
# Stage 2 so the discovery + registration both happen at operational
# activation; placement-time has no mine-discovery side-effect anymore.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class triggers the navmesh rebake (Task #144 fix). Ma'dan has a
	# NavigationObstacle3D (workers route AROUND the mine infrastructure),
	# so the rebake fires here and carves Ma'dan's footprint into the live
	# navmesh immediately on placement.
	super._on_placement_complete(placer_unit_id)
	# FogSystem ships in wave 3A. Forward-compat guard: use SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads — Pitfall
	# #12). Sight=0, is_static=true. Ma'dan reveals its own footprint (the
	# building IS visible to its owner team without a separate vision source).
	#
	# Vision is a *structural* property (the building physically exists and
	# casts its footprint of vision), distinct from the operational buff —
	# we register fog vision at Stage 1, register the modifier at Stage 2.
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation. The Ma'dan's buff applies from this
# tick onward.
#
# Mine discovery + registration runs HERE (not Stage 1) so workers
# gathering during construction see the unbuffed mine yield. The
# behavioral guarantee: a Ma'dan placed mid-construction adjacent to
# a mine does NOT buff that mine until construction completes.
#
# Per the &"buildings" group convention (see Building base), MineNodes
# are NOT in &"buildings" — they're in &"resource_nodes". Mazra'eh
# (Building subclass duck-typing the gather API) is in &"buildings",
# not &"resource_nodes" — the kind filter in _find_nearest_mine_within_radius
# is belt-and-braces.
#
# register_extraction_modifier is no longer guarded by has_method — the
# API is ratified in RNC v1.3.0 §4.7 (wave-1B Commit 4) and is part of
# every ResourceNode subclass that ships with wave-1B onward. Pitfall:
# this assumes the search only returns ResourceNode subclasses; the
# &"resource_nodes" group is curated to that contract (see
# resource_node.gd::_ready).
func _on_construction_complete(_placer_unit_id: int) -> void:
	# super-call discipline (session-3 retro §9, retrofitted in Wave 2A
	# fix-up): base _on_construction_complete is currently `pass`, but
	# the discipline applies regardless — when the base gains non-trivial
	# Stage-2 behavior in a future wave, every subclass already routes
	# through it. Mirrors Sarbaz-khaneh's super-call shape.
	super._on_construction_complete(_placer_unit_id)
	var radius_m: float = _resolve_modifier_radius_m()
	var nearest_mine: Node = _find_nearest_mine_within_radius(radius_m)
	if nearest_mine != null:
		nearest_mine.register_extraction_modifier(self)
	# If no mine within radius (Q4 free placement): no-op fallthrough.
	# The Ma'dan still exists as a placed building; it just doesn't do
	# anything at runtime. A future mine built nearby would not retroactively
	# bond — modifier registration is a one-shot event at Stage 2.


## Find the nearest MineNode within the given radius (world units), or
## null if none.
##
## Discovery strategy: iterate the `&"resource_nodes"` SceneTree group.
## ResourceNode base class self-adds to this group in `_ready` (added
## in wave 1B as the cross-cutting seam for Ma'dan's nearest-mine
## discovery). MineNodes are the only members at MVP scope; future
## resource-source ResourceNode subclasses will join the same group.
##
## Mazra'eh (Building subclass that duck-types the gather API) is NOT in
## `&"resource_nodes"` — it's in `&"buildings"`. The kind filter below
## is belt-and-braces against future hybrid cases.
##
## Used by _on_placement_complete to bind the Ma'dan to its adjacent mine.
## Out-of-radius mines are not modified — Ma'dan placement is free (Q4)
## but only effective when within radius of a mine.
##
## Pitfall awareness: the search is XZ-distance only (Y ignored). Mines
## and Ma'dans both sit on the terrain plane, but the global_position Y
## of a building reflects its terrain-pose offset (e.g., 0.6 for the
## Building base mesh) — comparing XZ ignores this irrelevant delta.
func _find_nearest_mine_within_radius(radius_m: float) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var radius_sq: float = radius_m * radius_m
	var best_mine: Node = null
	var best_dist_sq: float = INF
	for n in tree.get_nodes_in_group(&"resource_nodes"):
		if n == null or not is_instance_valid(n):
			continue
		if not (n is Node3D):
			continue
		# Filter to coin-kind nodes. At MVP scope every &"resource_nodes"
		# member is a MineNode with kind = &"coin"; the check is belt-
		# and-braces for future hybrid resource-source cases.
		var node_kind: Variant = n.get(&"kind")
		if typeof(node_kind) != TYPE_STRING_NAME:
			continue
		if StringName(node_kind) != Constants.KIND_COIN:
			continue
		var d: Vector3 = (n as Node3D).global_position - global_position
		var d_sq: float = d.x * d.x + d.z * d.z  # XZ-only; fog discipline
		if d_sq <= radius_sq and d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_mine = n
	return best_mine


# === Static cost helper ======================================================
#
# Read the Ma'dan's coin cost from BalanceData (in whole coin, not fixed-
# point). Used by the build menu to display the price next to the button.
# Same defensive fall-through pattern as Khaneh.cost_coin() / Mazraeh.cost_coin().
#
# Returns _FALLBACK_COIN_COST when BalanceData / the entry / the field is
# missing — placeholder until balance-engineer ships the bldg_madan
# SubResource. Mirrors the Khaneh / Mazra'eh pattern but with a wave-1B
# fallback constant since balance-engineer is shipping in parallel.
static func cost_coin() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return _FALLBACK_COIN_COST
	var bd: Resource = load(path)
	if bd == null:
		return _FALLBACK_COIN_COST
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return _FALLBACK_COIN_COST
	var stats: Variant = (bldgs as Dictionary).get(KIND_MADAN, null)
	if stats == null:
		return _FALLBACK_COIN_COST
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return _FALLBACK_COIN_COST
	return int(coin_v)


## Returns the yield multiplier this Ma'dan applies, in x100 fixed-point.
## MineNode.effective_yield_per_trip_x100 (Commit 2) reads this via duck-
## type. Reads from BalanceData's `bldg_madan.modifier_value_x100` field
## (shipped at d798e78); falls back to _FALLBACK_YIELD_MULTIPLIER_X100
## for headless tests / missing BalanceData.
##
## Per design Q3 (not-stacking, first-registered-wins): every Ma'dan
## carries the same multiplier; the first to register on a mine wins
## the buff slot regardless of subsequent registrations.
func yield_multiplier_x100() -> int:
	var stats: Resource = _madan_stats_or_null()
	if stats == null:
		return _FALLBACK_YIELD_MULTIPLIER_X100
	var v: Variant = stats.get(&"modifier_value_x100")
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return _FALLBACK_YIELD_MULTIPLIER_X100
	var iv: int = int(v)
	if iv <= 0:
		# modifier_value_x100 = 0 means "not a modifier-emitter" per the
		# BuildingStats default — but a Ma'dan IS one, so treat 0 as a
		# config error and fall back.
		return _FALLBACK_YIELD_MULTIPLIER_X100
	return iv


## Resolve modifier_radius_m from BalanceData, falling back to
## _FALLBACK_MODIFIER_RADIUS_M if missing. Read once per placement (in
## _on_placement_complete) so a balance-data change between two Ma'dan
## placements applies to the second placement immediately.
func _resolve_modifier_radius_m() -> float:
	var stats: Resource = _madan_stats_or_null()
	if stats == null:
		return _FALLBACK_MODIFIER_RADIUS_M
	var v: Variant = stats.get(&"modifier_radius_m")
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return _FALLBACK_MODIFIER_RADIUS_M
	var fv: float = float(v)
	if fv <= 0.0:
		return _FALLBACK_MODIFIER_RADIUS_M
	return fv


# Returns the bldg_madan BuildingStats SubResource from BalanceData, or
# null if it's missing / unreachable. Internal helper for
# yield_multiplier_x100 + _resolve_modifier_radius_m. Mirrors the
# defensive Resource-load pattern from Khaneh.cost_coin() / Mazraeh.
func _madan_stats_or_null() -> Resource:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return null
	var bd: Resource = load(path)
	if bd == null:
		return null
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return null
	var stats: Variant = (bldgs as Dictionary).get(KIND_MADAN, null)
	if not (stats is Resource):
		return null
	return stats


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
	var v: Variant = fog_cfg.get(&"sight_madan_cells")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


func _exit_tree() -> void:
	if _fog_handle >= 0:
		var fog: Node = _autoload_or_null(&"FogSystem")
		if fog != null and fog.has_method(&"deregister_vision_source"):
			fog.call(&"deregister_vision_source", _fog_handle)
		_fog_handle = -1
