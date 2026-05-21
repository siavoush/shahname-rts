extends "res://scripts/world/buildings/building.gd"
##
## Sowari-khaneh (سواری‌خانه) — Iran "rider-house" / cavalry barracks. First
## Tier-2 Iran military building per 01_CORE_MECHANICS.md §5. Anchor-category:
## **identity-bearing institutional** with **cavalry-tradition sub-slot**
## (per docs/ANCHOR_CATEGORY_TAXONOMY.md v1.0.0 + Wave 2B loremaster Track 0
## brief-time review, 2026-05-21).
##
## Source: 01_CORE_MECHANICS.md §5 line 194 ("Sowari-khaneh — 200 coin Tier 2,
## produces Savar cavalry") + docs/ARCHITECTURE.md §6 (post-Wave 2B close
## entry, version bumps at wave close) + docs/ANCHOR_CATEGORY_TAXONOMY.md
## v1.0.0 (anchor-category SSOT).
##
## Anchor-category taxonomy (per docs/ANCHOR_CATEGORY_TAXONOMY.md):
##   - identity-bearing institutional (Sarbaz-khaneh Tier 1, generic-infantry
##     sepah sub-slot) is the parent variant.
##   - Sowari-khaneh inherits the parent's mechanical template-shape:
##     same lifecycle hooks, same is_ready_to_produce operational marker
##     (Stage 2 flip), same coin-only economy framing, same deliberate
##     construction-time framing (institution-build slower than house-
##     build), same pahlavan/sepah two-layer split (no hero-class
##     production).
##   - Sub-slot specialization: cavalry-tradition. The unit-class produced
##     is Savar (cavalry) — the mounted backbone of the Iran sepah,
##     mechanically distinct from Sarbaz-khaneh's foot-infantry (Piyade)
##     output.
##
## ## Cultural note — PLACEHOLDER for Track 1.5 (loremaster framing)
##
## *Sowari-khaneh* (سواری‌خانه, lit. "rider-house" / "house of the rider")
## — the institution where mounted soldiers (savaran) are trained for the
## sepah. The mechanic surfaces the cultural truth: cavalry is a tradition
## of trained skill (horsemanship + lance + sword in motion) housed in a
## formal institution, mirroring Sarbaz-khaneh's institutional shape
## specialized to the mounted layer.
##
## [TRACK 1.5 PASTE] Loremaster Track 0 brief-time block routes from lead
## post-Track-1 ship. Four-element template:
##   1. Cultural referent — Shahnameh episodes anchoring the
##      mounted-warrior tradition (likely Rostam's Rakhsh frame; Bizhan,
##      Giv, the Iran cavalry tradition broadly).
##   2. Mechanic-surfaces-truth — how 200-coin + 1080-tick construction
##      lands cavalry-institution as MORE deliberate than infantry-
##      institution (Sarbaz-khaneh's 780-tick precedent).
##   3. Cross-faction caveat — Turan's cavalry tradition is the canonical
##      threat per 00_SHAHNAMEH_RESEARCH.md §3 lines 163-165 ("nomadic-
##      steppe culture. Swift cavalry, horse archers..."). The
##      structural mismatch: Iran's mounted tradition is institutional
##      (sown into the sepah); Turan's is native (the steppe-rider
##      identity itself). Do NOT clone Sowari-khaneh for Turan.
##   4. Forward-compat — the parent variant (identity-bearing
##      institutional) now has 3 sub-slots populated: generic-infantry
##      sepah (Sarbaz-khaneh), cavalry-tradition (Sowari-khaneh),
##      archery-tradition (Tirandazi, sibling Tier-2 ship).
##
## ## What lives here vs Building base
##
##   - kind = &"sowari_khaneh" (dual-init pattern per kargar.gd /
##     khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd headers —
##     _init AND _ready both set kind).
##   - NO resource_kind field (Sowari-khaneh is not a resource source).
##   - NO ResourceNode-shape fields (production is not gathering — the
##     API surface is distinct).
##   - is_ready_to_produce: bool field, defaults false; flipped true in
##     `_on_construction_complete` (Stage 2 operational marker per
##     §9.L5). MIRRORS Sarbaz-khaneh.is_ready_to_produce exactly —
##     same field name, same semantics, sub-slot specialization is at
##     the unit-class level (Savar vs Piyade), NOT the marker level.
##   - _on_placement_complete (Stage 1): super-call first (§9.L4a +
##     Wave 1D rebake), then FogSystem vision-source registration +
##     EventBus.building_placed emit. Standard Stage-1 structural
##     pattern; identical shape to Sarbaz-khaneh / Ma'dan.
##   - _on_construction_complete (Stage 2): super-call first
##     (§9.L4a + §9.L4b — base body currently `pass` but discipline
##     applies regardless), then flip is_ready_to_produce = true.
##   - Static cost_coin() helper with defensive 200-coin fallback
##     (01_CORE_MECHANICS.md §5 line 194 spec). Sowari-khaneh is
##     coin-only (grain_cost = 0 per Track 3 BalanceData) — preserving
##     the Sarbaz-khaneh coin-economy framing for the institutional-
##     production anchor-category.
##
## Base Building owns: kind/team/unit_id schema, place_at seam,
## &"buildings" group join, get_footprint_aabb(), unit_id counter,
## two-stage lifecycle (place_at → _on_placement_complete;
## UnitState_Constructing dwell → _on_construction_complete +
## construction_finalized signal emit), Wave 1D navmesh-rebake pipeline
## in base _on_placement_complete.
##
## ## Visual placeholder per CLAUDE.md
##
## Scene-side (world-builder Track 2 — parallel ship): BoxMesh + mesh
## differentiation to read as "cavalry-institution" rather than infantry-
## institution. world-builder owns scene composition; this Track 1 ships
## the script + tests via .new() per §9.M4 to decouple ship timings.
## NavigationObstacle3D present at scene level (workers route AROUND —
## structural building like Sarbaz-khaneh).
##
## ## Why extend by path-string (not class_name on the base)
##
## Same class_name registry race as every other Building subclass (per
## Pitfall #13). Path-string extends sidesteps the race.
##
## ## Why _init AND _ready set kind
##
## Dual-init pattern per kargar.gd / khaneh.gd / mazraeh.gd / madan.gd /
## sarbaz_khaneh.gd / atashkadeh.gd headers. Scene-instantiation order
## resets @export defaults between _init and _ready; sowari_khaneh.tscn
## (when world-builder ships it) does not override the `kind` export,
## so the engine would clobber any _init write back to base default (&"").
## _ready setter is the canonical fix; _init kept so SowariKhaneh.new()
## headless construction (no scene) also reports the right kind — used
## by tests per §9.M4.
class_name SowariKhaneh


## Canonical kind StringName for the Sowari-khaneh class. Matches the
## BalanceData lookup key (`buildings.sowari_khaneh` in balance.tres,
## shipped at Track 3 / 6503b0c via balance-engineer-p3s3's H3 + L6
## inaugural dogfood).
const KIND_SOWARI_KHANEH: StringName = &"sowari_khaneh"


# === Defensive fallback constants ===========================================
#
# Match prior subclass pattern (Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh /
# Atashkadeh cost helpers) — "config error doesn't break the UI" — when
# balance.tres is unreachable or the bldg_sowari_khaneh entry is missing,
# the building still functions with a reasonable default rather than
# zero-valued degenerate behavior.
#
# Per 01_CORE_MECHANICS.md §5 line 194: "Sowari-khaneh — 200 coin Tier 2,
# produces Savar cavalry". Track 3 BalanceData entry shipped at 6503b0c
# with coin_cost = 200 + construction_ticks = 1080 + tier = 2.
const _FALLBACK_COIN_COST: int = 200


# === Operational state =======================================================

## True once construction has completed (Stage 2 — _on_construction_complete
## has fired). Public surface for the future Phase-4 production system:
## when a consumer (UnitProductionQueue, build menu, AI training decisions)
## wants to know whether this Sowari-khaneh can accept Savar-training
## requests, it reads is_ready_to_produce.
##
## False during construction-in-progress (Stage 1 only — building exists
## structurally but has not yet finished training-its-trainers in the
## cavalry tradition).
##
## Default false ensures operational-gating discipline at spawn. Mirrors
## Mazra'eh.is_gatherable + Sarbaz-khaneh.is_ready_to_produce + Atashkadeh.
## is_emitting_farr default-false patterns per §9.L5 (per-subclass marker
## until N≥4 share near-identical bool-flip semantics; we are now at N=4
## with Atashkadeh — N≥4 trigger is met but Sowari-khaneh shares
## Sarbaz-khaneh's exact field name + semantics, suggesting the parent
## variant's marker hoists at Phase 4 production-queue ship, not now).
##
## Wave 2B scope: the flag itself. The actual production-queue + timer +
## UI ship in Phase 4; this Track 1 ships the flag only — gating is in
## place when production ships, no follow-up needed to the base class.
var is_ready_to_produce: bool = false


func _init() -> void:
	kind = KIND_SOWARI_KHANEH


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd / atashkadeh.gd
	# headers). The base class doesn't currently read kind directly, but
	# the symmetry guards future refactors.
	kind = KIND_SOWARI_KHANEH
	super._ready()


# === Autoload helper =========================================================
#
# Same canonical pattern as mazraeh.gd / madan.gd / sarbaz_khaneh.gd /
# atashkadeh.gd. Engine.has_singleton() does NOT find GDScript autoloads
# (Pitfall #12 TWO-PART) — script autoloads register as direct SceneTree
# children, not C++/GDExtension singletons. This is the correct discovery
# pattern.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


# === Lifecycle hooks =========================================================
#
# Two-stage lifecycle per Building base (session-3 wave-1C — §9.L5):
#   Stage 1 (_on_placement_complete) — STRUCTURAL: the building exists in
#     the world (visible, click-targetable, navmesh-carved via base rebake
#     pipeline from Wave 1D). Worker has just arrived and place_at fired.
#   Stage 2 (_on_construction_complete) — OPERATIONAL: the building is
#     READY TO PRODUCE Savar cavalry. Training can now be queued (Phase 4
#     wires the actual queue; the is_ready_to_produce flag is the public
#     surface).
#
# Sowari-khaneh's CAPABILITY — accepting Savar training requests — is
# gated on Stage 2. A half-built Sowari-khaneh reveals fog and emits the
# placement signal, but cannot yet train cavalry.

# Stage 1 — structural side-effects only.
#
# super-call discipline (§9.L4a + Wave 1D ship): the base
# _on_placement_complete runs the explicit-pipeline navmesh rebake.
# Subclasses MUST call super FIRST so the rebake fires before any subclass
# work that depends on a fresh navmesh state. Same shape as
# sarbaz_khaneh.gd:249 / atashkadeh.gd.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class triggers the navmesh rebake (Wave 1D pipeline). Sowari-
	# khaneh has a NavigationObstacle3D (workers route AROUND the cavalry
	# barracks — structural building), so the rebake fires here and carves
	# the footprint into the live navmesh immediately on placement.
	super._on_placement_complete(placer_unit_id)
	# FogSystem ships in wave 3A. Forward-compat guard via SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads —
	# Pitfall #12). Sight=0, is_static=true: Sowari-khaneh reveals its own
	# footprint (the institutional building IS visible to its owner team
	# without needing a separate vision source — same shape as Khaneh /
	# Mazra'eh / Ma'dan / Sarbaz-khaneh / Atashkadeh).
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		_fog_node.call(&"register_vision_source", self, team, 0, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation. The Sowari-khaneh becomes "ready to
# produce" from this tick onward.
#
# super-call discipline (§9.L4a + §9.L4b): base _on_construction_complete
# is currently `pass`, but we call super anyway per the rule — if the base
# adds non-trivial Stage-2 behavior in a future wave, every subclass
# already routes through it.
#
# The is_ready_to_produce flip is the load-bearing operational gate.
# Future Phase-4 consumers (production-queue UI, AI training decisions)
# read this flag to decide whether the Sowari-khaneh can accept Savar
# training requests.
#
# Mirrors Sarbaz-khaneh's Stage-2 flip + sub-slot specialization rule
# (mechanical template-shape identical; the cavalry-tradition specialty
# manifests at unit-class level, not lifecycle level).
func _on_construction_complete(placer_unit_id: int) -> void:
	super._on_construction_complete(placer_unit_id)
	is_ready_to_produce = true


# === Static cost helper ======================================================
#
# Read the Sowari-khaneh's coin cost from BalanceData (in whole coin, not
# fixed-point). Used by the build menu (Track 4 — ui-developer-p3s3) to
# display the price next to the button. Same defensive fall-through
# pattern as Khaneh.cost_coin() / Mazraeh.cost_coin() / Madan.cost_coin() /
# SarbazKhaneh.cost_coin() / Atashkadeh.cost_coin().
#
# Returns _FALLBACK_COIN_COST when BalanceData / the entry / the field is
# missing — the bldg_sowari_khaneh SubResource shipped at Track 3
# (6503b0c) so the normal path returns 200 from BalanceData; fallback
# fires only when balance.tres is unreachable (headless tests without
# the file present).
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
	var stats: Variant = (bldgs as Dictionary).get(KIND_SOWARI_KHANEH, null)
	if stats == null:
		return _FALLBACK_COIN_COST
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return _FALLBACK_COIN_COST
	return int(coin_v)
