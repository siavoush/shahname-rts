extends "res://scripts/world/buildings/building.gd"
##
## Sarbaz-khaneh (سربازخانه) — Iran "soldier-house" / barracks. Third Tier-1
## anchor-category Building variant: **identity-bearing institutional**.
##
## Source: 01_CORE_MECHANICS.md §5 (Iran buildings — "Sarbaz-khaneh (barracks)
## — produces piyade, savar, kamandar") + docs/ARCHITECTURE.md §6 v0.24.0
## (Phase 3 session 4 wave 2A close entry).
##
## Anchor-category taxonomy (per session-2 retro's building-variant
## classification — see Khaneh / Mazra'eh / Ma'dan headers for prior anchors):
##   - Khaneh: civic-anchor (settled household + population cap).
##   - Mazra'eh: resource-producing (Grain via duck-typed gather API).
##   - Ma'dan: labor-organization (modifier-emitter on adjacent mine).
##   - **Sarbaz-khaneh: identity-bearing institutional** — the building that
##     *produces* the army, where untrained workers become trained soldiers.
##     Distinct from the prior three: not civic continuity, not material
##     extraction, not labor-organization — but the formal institution that
##     transforms one social role (kargar / farmer / civilian) into another
##     (sarbaz / soldier). The Shahnameh frame for this transformation is
##     load-bearing for the wave-2A loremaster brief; placeholder text below
##     is replaced at Commit 1.5 with loremaster's content per the
##     coordination plan in 02h §3.
##
## Cultural note — sarbaz-khaneh (سرباز‌خانه), the institution that names the soldier:
##
##   *Sarbaz* (lit. "head-staked", one who has wagered his head — i.e. has
##   sworn loyalty on pain of death; the modern Persian gloss "soldier" loses
##   the oath register) + *khaneh* (house/hall). The compound is "soldier-
##   house" in dictionary form, but the institutional shape carries the
##   weight: the building where the oath is taken, the formation drilled, the
##   role formalized. Iran's military identity, in Shahnameh frame, is not
##   improvised levy — it is the *sepah* (سپاه, "army-as-institution"; the
##   gloss "army" loses the institutional/standing layer Iran's military
##   tradition rests on). Sarbaz-khaneh is where sepah is made.
##
##   The Shahnameh's load-bearing distinction (00_SHAHNAMEH_RESEARCH.md §3
##   lines 161-165 + §4 lines 187-191): Iran fields "champion-driven warfare
##   led by heroic pahlavans" backed by "heavy armored infantry, legendary
##   archers" — a TWO-LAYER military. The pahlavan (Rostam, Esfandiyar, Giv,
##   Bijan) is exceptional; the *piyade* and *kamandar* are the institutional
##   ordinary, the named-but-collective backbone that holds the line while
##   the heroes decide outcomes in single combat (*mard-o-mard*, §5.2). The
##   game's anchor categories already encode this split: Rostam is a future
##   pahlavan-class unit (hero exceptionalism); Sarbaz-khaneh produces the
##   institutional ordinary. The Iran player's army is BOTH layers — and
##   Sarbaz-khaneh is where the second, larger, less-glorious layer comes
##   from.
##
##   How the mechanic surfaces the cultural truth: Sarbaz-khaneh costs 100
##   coin with no grain component — framing it as a *standing-army coin-
##   economy institution* (the king's purse maintains the sepah), not a
##   peasant-levy or war-time muster. construction_ticks = 780 (26s @
##   SIM_HZ=30) lands the institutional commitment as DELIBERATE: 4× the
##   Khaneh's household raise-time, 3× the Mazra'eh's field-clear time —
##   building a sepah-institution is a longer commitment than building a
##   house or a farm. Once built, the queue produces Piyade (spear-and-
##   shield line) and Kamandar (the Parthian-shot archer tradition,
##   00_SHAHNAMEH_RESEARCH.md §4 line 189) — the two units that ARE the
##   Iran "ordinary military" the Shahnameh names. Pahlavan unlocks live
##   elsewhere (hero progression, post-MVP); Sarbaz-khaneh stays in its
##   lane as the institutional-ordinary producer.
##
##   Cross-faction caveat (loremaster leading hypothesis):
##   Turan's military is NOT a Sarbaz-khaneh-clone. Per 00_SHAHNAMEH_
##   RESEARCH.md §3 lines 163-165, Turan is "nomadic-steppe culture. Swift
##   cavalry, horse archers, raiders. Broader, looser armies built on
##   mobility." Per QUESTIONS_FOR_DESIGN.md Turan-economy entry, Turan's
##   military organization most likely routes through MOBILE WAR-CAMPS
##   (otaq-cluster, traveling with the herd) gated on the KHAN'S-LOYALTY /
##   sworn-warrior mechanic — warriors bound to a named ruler-figure
##   (Afrasiyab, Piran) rather than to a fixed institutional building.
##   This is a STRUCTURAL MISMATCH sharper than the building-vs-building
##   variant gap (cf. Ma'dan / baj): Iran's military identity LIVES in the
##   institutional building; Turan's lives in the loyalty bond and the
##   moving camp. **Do not clone Sarbaz-khaneh as a Turan building** — a
##   naive copy would erase the steppe-vs-settled distinction that is the
##   Iran-Turan asymmetry's whole point. When Turan Tier-1 military ships
##   (post-MVP), expect a fundamentally different shape and require a
##   fresh loremaster review.
##
##   Forward-compat note — identity-bearing-institutional anchor category:
##   Sarbaz-khaneh is the FIRST instance of the **identity-bearing
##   institutional** variant (loremaster anchor-category taxonomy, session-2
##   retro: distinct from civic-anchor Khaneh/Mazra'eh, labor-organization
##   Ma'dan, sacral-emitter Atashkadeh-pending). Future Tier-2 Iran
##   military buildings INHERIT this anchor category but specialize the
##   unit-class produced:
##     - **Sowari-khaneh** (سواری‌خانه, "rider-house") — produces Savar
##       cavalry (01_CORE_MECHANICS.md §5 line 194, 200 coin Tier 2).
##       Same institutional-oath shape, specialized to the mounted
##       tradition.
##     - **Tirandazi** (تیراندازی, "arrow-shooting [practice]") — produces
##       advanced Kamandar variants including Asb-savar Kamandar (line
##       195, 175 coin Tier 2). Note: Tirandazi is *practice/discipline*,
##       not *-khaneh*; the naming convention shifts slightly because the
##       Parthian-shot tradition is canonically about *trained skill*
##       transmission, not just the building. Clone the anchor-category
##       framing, but flag the naming shape at template-clone time.
##   Subsequent Iran military buildings inheriting this template should
##   keep: (a) coin-economy framing (no grain cost), (b) deliberate-
##   construction-time framing (institution-build is slower than house-
##   build), (c) the pahlavan/sepah two-layer split (no hero-class
##   production from these buildings).
##
## ## What lives here vs Building base
##
##   - kind = &"sarbaz_khaneh" (dual-init pattern per kargar.gd /
##     khaneh.gd / mazraeh.gd / madan.gd — _init and _ready both set it).
##   - NO resource_kind field (Sarbaz-khaneh is not a resource source).
##   - NO ResourceNode-shape fields (is_gatherable, reserves_x100, etc.
##     — production is not gathering; the API surface is distinct).
##   - _on_placement_complete: super-call first (Wave 1D rebake), then
##     FogSystem vision-source registration + EventBus.building_placed
##     emit. Standard Stage-1 structural pattern; identical shape to
##     Ma'dan's _on_placement_complete.
##   - _on_construction_complete: super-call first (no-op at base today,
##     but super()-call discipline applies per session-3 retro §9), then
##     flip is_ready_to_produce = true. This is the operational marker.
##     The actual production-queue + timer + UI ship in Phase 4; the
##     ready-to-produce flag is the public surface telling future Phase-4
##     code "this Sarbaz-khaneh can accept training requests."
##   - is_ready_to_produce: bool field, defaults false. Public surface
##     for Phase-4 production system. Flips true at Stage 2 (construction
##     complete) and stays true for the building's lifetime. The
##     two-stage parallel to Mazra'eh.is_gatherable and Ma'dan's
##     mine-modifier registration — same operational-gating discipline.
##
## Base Building owns: kind/team/unit_id schema, place_at seam, &"buildings"
## group join, get_footprint_aabb(), unit_id counter, two-stage lifecycle
## (place_at → _on_placement_complete; UnitState_Constructing dwell →
## _on_construction_complete + construction_finalized signal emit), Wave 1D
## navmesh-rebake pipeline in base _on_placement_complete.
##
## ## Visual placeholder per CLAUDE.md
##
## Scene-side (world-builder Track 2): BoxMesh sized to convey "institutional
## structure" — larger and more imposing than Khaneh's 2.0×1.2×2.0 footprint
## but matching the institutional weight. Color distinct from prior buildings:
## probably a deep red or military-bronze tone (world-builder decides; reads as
## "the army's home" from across the map). NavigationObstacle3D present
## (workers route AROUND, not through — Sarbaz-khaneh is a structural building
## like Khaneh / Ma'dan, contrasts with Mazra'eh's walkable field).
##
## ## Why extend by path-string (not class_name)
##
## Same class_name registry race as every other Building subclass (see
## khaneh.gd / mazraeh.gd / madan.gd headers + Pitfall #13). Path-string
## extends sidesteps the race entirely.
##
## ## Why _init AND _ready set kind
##
## Dual-init pattern per kargar.gd's header — scene-instantiation order
## resets @export defaults from the .tscn definition BETWEEN _init and _ready.
## sarbaz_khaneh.tscn doesn't override the `kind` export, so the engine
## would clobber any _init write back to the base default (&""). The
## _ready setter is the canonical fix; _init is kept so SarbazKhaneh.new()
## headless construction (no scene) also reports the right kind — useful
## for tests.
class_name SarbazKhaneh


## Canonical kind StringName for the Sarbaz-khaneh class. Matches the
## BalanceData lookup key (`buildings.sarbaz_khaneh` in balance.tres,
## once balance-engineer ships the bldg_sarbaz_khaneh sub-resource entry
## via Track 3).
const KIND_SARBAZ_KHANEH: StringName = &"sarbaz_khaneh"

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1

# === Defensive fallback constants ===========================================
#
# Match prior subclass pattern (Khaneh.cost_coin / Mazraeh.cost_coin /
# Madan.cost_coin / Madan._FALLBACK_*) — "config error doesn't break the
# UI" — when balance.tres is unreachable or the bldg_sarbaz_khaneh entry
# is missing, the building still functions with a reasonable default
# rather than zero-valued degenerate behavior.
#
# Per 01_CORE_MECHANICS.md §5: "Sarbaz-khaneh (barracks) — 100 coin"
# (placeholder; balance-engineer tunes via balance.tres Track 3).
const _FALLBACK_COIN_COST: int = 100


# === Operational state =======================================================

## True once construction has completed (Stage 2 — _on_construction_complete
## has fired). Public surface for the Phase-4 production system: when a
## consumer (future UnitProductionQueue, build menu, AI) wants to know
## whether this Sarbaz-khaneh can accept training requests, it reads
## is_ready_to_produce.
##
## False during construction-in-progress (Stage 1 only — building exists
## structurally but has not yet finished training-its-trainers).
##
## Default false ensures the operational-gating discipline carries through
## the two-stage lifecycle: workers cannot queue training at a half-built
## Sarbaz-khaneh. Mirrors Mazra'eh.is_gatherable's default-false pattern.
##
## Phase 4 scope: the actual production-queue + timer + UI consume this
## flag. Wave 2A ships the flag only — gating is in place when production
## ships, no follow-up needed to the base class.
var is_ready_to_produce: bool = false


func _init() -> void:
	kind = KIND_SARBAZ_KHANEH


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd headers). The base class doesn't
	# currently read kind directly, but the symmetry guards future refactors.
	kind = KIND_SARBAZ_KHANEH
	super._ready()


# === Autoload helper =========================================================
#
# Same canonical pattern as mazraeh.gd:143-147 / madan.gd:176-180. Engine.
# has_singleton() does NOT find GDScript autoloads (Pitfall #12 TWO-PART) —
# script autoloads register as direct SceneTree children, not C++/GDExtension
# singletons. This is the correct discovery pattern.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


# === Lifecycle hooks =========================================================
#
# Two-stage lifecycle per Building base (session 3 wave 1C):
#   Stage 1 (_on_placement_complete) — STRUCTURAL: the building exists in
#     the world (visible, click-targetable, navmesh-carved via base rebake
#     pipeline from Wave 1D). Worker has just arrived and place_at fired.
#   Stage 2 (_on_construction_complete) — OPERATIONAL: the building is
#     READY TO PRODUCE. Soldier-training can now be queued (Phase 4 wires
#     the actual queue; the ready-to-produce flag is the public surface).
#
# Sarbaz-khaneh's CAPABILITY — accepting training requests — is gated on
# Stage 2. A half-built Sarbaz-khaneh reveals fog and emits the placement
# signal, but cannot yet train soldiers.

# Stage 1 — structural side-effects only.
#
# super-call discipline (session-3 retro §9 + Wave 1D ship): the base
# _on_placement_complete now runs the explicit-pipeline navmesh rebake.
# Subclasses MUST call super FIRST so the rebake fires before any subclass
# work that depends on a fresh navmesh state. Same shape as madan.gd:211.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class triggers the navmesh rebake (Wave 1D pipeline). Sarbaz-khaneh
	# has a NavigationObstacle3D (workers route AROUND the barracks), so the
	# rebake fires here and carves the footprint into the live navmesh
	# immediately on placement.
	super._on_placement_complete(placer_unit_id)
	# FogSystem ships in wave 3A. Forward-compat guard via SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads — Pitfall
	# #12). Sight=0, is_static=true: Sarbaz-khaneh reveals its own footprint
	# (the institutional building IS visible to its owner team without needing
	# a separate vision source — same shape as Khaneh / Mazra'eh / Ma'dan).
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation. The Sarbaz-khaneh becomes "ready to
# produce" from this tick onward.
#
# super-call discipline (session-3 retro §9): base _on_construction_complete
# is currently `pass`, but we call super anyway per the new rule — if the
# base adds non-trivial Stage-2 behavior in a future wave (e.g., a
# project-wide ResourceSystem.notify_construction_complete chokepoint),
# every subclass already routes through it.
#
# The is_ready_to_produce flip is the load-bearing operational gate. Future
# Phase-4 consumers (production-queue UI, AI training decisions) read this
# flag to decide whether the building can accept training requests.
#
# Mirrors Mazra'eh.is_gatherable's Stage-2 flip and Ma'dan's Stage-2
# modifier-registration: same operational-gating discipline applied to
# the institutional-production capability.
func _on_construction_complete(placer_unit_id: int) -> void:
	super._on_construction_complete(placer_unit_id)
	is_ready_to_produce = true


# === Static cost helper ======================================================
#
# Read the Sarbaz-khaneh's coin cost from BalanceData (in whole coin, not
# fixed-point). Used by the build menu (Track 4 — ui-developer-p3s3) to
# display the price next to the button. Same defensive fall-through
# pattern as Khaneh.cost_coin() / Mazraeh.cost_coin() / Madan.cost_coin().
#
# Returns _FALLBACK_COIN_COST when BalanceData / the entry / the field is
# missing — placeholder until balance-engineer's Track 3 ships the
# bldg_sarbaz_khaneh SubResource entry. Mirrors the Khaneh / Mazra'eh /
# Ma'dan pattern with a wave-2A fallback since balance-engineer ships in
# parallel.
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
	var stats: Variant = (bldgs as Dictionary).get(KIND_SARBAZ_KHANEH, null)
	if stats == null:
		return _FALLBACK_COIN_COST
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return _FALLBACK_COIN_COST
	return int(coin_v)


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
	var v: Variant = fog_cfg.get(&"sight_sarbazkhane_cells")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


func _exit_tree() -> void:
	if _fog_handle >= 0:
		var fog: Node = _autoload_or_null(&"FogSystem")
		if fog != null and fog.has_method(&"deregister_vision_source"):
			fog.call(&"deregister_vision_source", _fog_handle)
		_fog_handle = -1
