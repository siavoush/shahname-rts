extends "res://scripts/world/buildings/building.gd"
##
## Sowari-khaneh (سواری‌خانه) — Iran "rider-house" / cavalry stable. First
## Tier-2 institutional building; **sub-slot** under the identity-bearing
## institutional anchor-category established by Sarbaz-khaneh (Wave 2A).
##
## Source: 01_CORE_MECHANICS.md §5 line 194 (Tier-2 row — "Sowari-khaneh
## (cavalry stable) — Produces Savar (cavalry) — 200 coin") +
## §5 line 189 (Tier-2 gating — requires Farr ≥ 40 + Atashkadeh built).
##
## Anchor-category sub-slot classification (per Wave 2B Track 0 loremaster
## brief-time review — J2 watchlist trichotomy N=2 graduation):
##
##   Outcome: **SLOT-FIT-VERIFY**. Sowari-khaneh fills the predicted-empty
##   *cavalry-tradition* sub-slot under the identity-bearing institutional
##   anchor-category. The anchor-shape (institution that transforms civilian
##   into named military arm via formal oath + trained skill) is invariant;
##   the sub-slot specializes the *arm* (mounted-aristocratic) and the
##   *cultural register* (Iranian noble-class cavalry tradition vs
##   Sarbaz-khaneh's generic sepah-infantry).
##
##   Sub-slot taxonomy under identity-bearing institutional:
##     - generic-infantry sepah   → Sarbaz-khaneh (Tier 1, Wave 2A)
##     - **cavalry-tradition       → Sowari-khaneh (Tier 2, Wave 2B)**
##     - archery-tradition         → Tirandazi (Tier 2, Wave 2B)
##
## Cultural note — sowari-khaneh (سواری‌خانه), the house of the mounted:
##
##   *Sowari* (سواری, "riding / mounted-warrior practice"; from *savar*,
##   the rider) + *-khaneh* (خانه, house / hall). The compound is
##   "rider-house" in literal form — the place where the mounted military
##   arm is formalized. The English gloss "cavalry stable" is the
##   tricky-gloss to handle with care: in modern usage "stable" imports
##   a service-building register (where the horses are kept, where the
##   groom works) that compresses Sowari-khaneh's institutional weight.
##   The atashkadeh-of-mounted-arms is the closer analogy — a building
##   where a specific military-cultural inheritance is kept and
##   transmitted. The horses live here, yes; but more importantly, the
##   *skill of mounted combat in Iranian style* lives here.
##
##   The Shahnameh's load-bearing anchor (00_SHAHNAMEH_RESEARCH.md §3
##   lines 161-165 + §4 line 188): Iran's military is "champion-driven
##   warfare led by heroic pahlavans" backed by "Persian cavalry, heavy
##   armored infantry, legendary archers." The Iranian cavalry tradition
##   is structurally NOT the steppe horse-archer (Turan's signature
##   shape, §3 line 163: "Swift cavalry, horse archers, raiders");
##   Iranian Savar is *heavy* — armored, lance-and-mace mounted melee,
##   the noble-class warrior whose archetype is Rostam-on-Rakhsh (the
##   Shahnameh's mounted pahlavan-and-warhorse pair). Savar as
##   institutional-ordinary unit is the *trained-class* version of that
##   archetype: not Rostam, not exceptional, but Iran's noble-warrior
##   layer that holds the line in mounted formation while the pahlavan
##   decides outcomes in single combat. Sowari-khaneh is where that
##   trained-class is made — distinct from Sarbaz-khaneh (which makes
##   piyade/kamandar infantry) by *arm + cultural register*, not by
##   anchor-shape.
##
##   How the mechanic surfaces the cultural truth: Sowari-khaneh costs
##   200 coin with no grain component (clone-rule from Sarbaz-khaneh
##   header: coin-economy-framing — the king's purse sustains the
##   mounted-aristocracy, not peasant levy). The Tier-2 placement gating
##   (Qal'eh + Farr ≥ 40 prereqs, deferred Wave 2C) anchors the
##   cultural-political fact that mounted-aristocratic military arms
##   require *legitimate kingship + theological-anchor* first — you
##   cannot field the noble cavalry of a kingdom that has not yet
##   established its sovereignty (Qal'eh / fortress) AND its legitimacy
##   (Farr threshold). Construction_ticks = 1080 (balance-engineer's
##   ladder-defense L1 override of lead's 900 recommendation; 36s vs
##   Sarbaz-khaneh's 26s) reflects the deeper institutional commitment:
##   training mounted-warriors plus their horses is slower than training
##   foot-soldiers.
##
##   Cross-faction caveat (loremaster leading hypothesis — singular,
##   not a list, per J3 cross-faction shape):
##
##   Turan's cavalry is NOT a Sowari-khaneh-clone. Per
##   00_SHAHNAMEH_RESEARCH.md §3 line 163 + §4 line 199, Turan's
##   signature unit is the steppe horse-archer — fast, light, raiding
##   formation. Turanian cavalry tradition routes through the otaq
##   (mobile war-camp) + sworn-warrior-to-khan loyalty bond, NOT
##   through a fixed institutional-mounted-aristocracy building. The
##   structural mismatch is sharp: Iran's mounted-arm LIVES in the
##   institutional-noble class trained at a named building; Turan's
##   mounted-arm LIVES in the herder-warrior whose horse and bow are
##   his daily life, not a trained specialization. **Do not clone
##   Sowari-khaneh as a Turan building.** When Turan Tier-2 military
##   ships (post-MVP), expect a fundamentally different shape (a
##   mobile-raid-camp emitter? An otaq-cluster aggregator?) and require
##   a fresh loremaster review. Turan economy still pending design
##   ratification — flag for QUESTIONS_FOR_DESIGN.md if not already
##   routed.
##
##   Forward-compat note — identity-bearing institutional sub-slot
##   taxonomy:
##
##   Sowari-khaneh's brief-time review is part of the FIRST application
##   of the J2 watchlist trichotomy (clone-check / slot-fit-verify /
##   taxonomy-growth-required) — outcome was slot-fit-verify for both
##   Sowari + Tirandazi sibling Tier-2 ship. Future Tier-2/3 Iran
##   military buildings inheriting this anchor-category may add further
##   sub-slots (e.g., a pil-khaneh / war-elephant institution, per
##   00_SHAHNAMEH_RESEARCH.md §4 line 191 — Sasanian-era, likely
##   post-MVP). The sub-slot axis is *military-arm*; each future
##   sub-slot specializes the arm and the cultural register. Clone the
##   anchor-shape (institutional-oath + trained-skill + coin-economy
##   framing + Stage-2 production gating); specialize the cultural-note
##   prose per the arm's Shahnameh anchor.
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

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1


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
	# Wave 3A.6 Track 1 — Sowari-khaneh produces Savar (Tier-2 cavalry).
	# Per kickoff §1: NOT [&"savar", &"asb_savar_kamandar"] — AsbSavarKamandar
	# production is explicitly deferred to Phase 4 / Tier-2-polish wave. The
	# production locus question (Sowari-khaneh-as-2nd-option vs new building)
	# is open per 01_CORE_MECHANICS.md ambiguity; ship Savar alone for 3A.6.
	produces = [&"savar"]


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd / atashkadeh.gd
	# headers). The base class doesn't currently read kind directly, but
	# the symmetry guards future refactors.
	kind = KIND_SOWARI_KHANEH
	# Dual-init mirror — scene defaults clobber _init writes between _init
	# and _ready (kargar.gd header pattern). Same shape as `kind` above.
	produces = [&"savar"]
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
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
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
	var v: Variant = fog_cfg.get(&"sight_sowari_khaneh_cells")
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


# === Destruction handler — subclass override =================================

## Wave 3-BuildingDestructibility (session 9). On hp=0: cancel
## production + emit final state_changed + call super. Per
## architecture-reviewer C2.5 + §3.1.a.
func _on_health_zero(unit_id_in: int) -> void:
	if _destruction_emitted:
		return
	if _production_state == &"training":
		var canceled_unit: StringName = _production_unit
		_production_state = &"idle"
		_production_unit = &""
		_production_progress_ticks = 0
		_production_total_ticks = 0
		production_state_changed.emit(unit_id, &"idle", canceled_unit, 0.0)
		print("[sowari_khaneh] production_cancel_on_destruction unit=%s" % str(canceled_unit))
	super._on_health_zero(unit_id_in)
