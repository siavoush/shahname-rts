extends "res://scripts/world/buildings/building.gd"
##
## Tirandazi (تیراندازی) — Iran "arrow-shooting" / archery discipline. Second
## Tier-2 Iran military building per 01_CORE_MECHANICS.md §5. Anchor-category:
## **identity-bearing institutional** with **archery-tradition sub-slot**
## (per docs/ANCHOR_CATEGORY_TAXONOMY.md v1.0.0 + Wave 2B loremaster Track 0
## brief-time review, 2026-05-21).
##
## Source: 01_CORE_MECHANICS.md §5 line 195 ("Tirandazi — 175 coin Tier 2,
## produces advanced Kamandar variants including Asb-savar Kamandar") +
## docs/ARCHITECTURE.md §6 (post-Wave 2B close entry) +
## docs/ANCHOR_CATEGORY_TAXONOMY.md v1.0.0 (anchor-category SSOT).
##
## ## NAMING-SHAPE NOTE (-dazi suffix vs -khaneh)
##
## Tirandazi's naming differs from its sibling identity-bearing-institutional
## buildings: where Sarbaz-khaneh + Sowari-khaneh use *-khaneh* (house),
## Tirandazi uses *-dazi* (shooting; the verbal-noun form of *andakhtan*,
## "to throw / shoot"). Per loremaster Track 0 brief-time verdict (2026-05-21):
## **the naming divergence is surface-language ONLY. Mechanical template-shape
## is identical to Sarbaz-khaneh + Sowari-khaneh.** The `-dazi` suffix carries
## cultural weight in the cultural-note prose (the Parthian-shot tradition
## is canonically about *trained skill* transmission, not just the building),
## but it does NOT alter:
##   - the anchor-category (still identity-bearing institutional)
##   - the lifecycle hooks (Stage 1 / Stage 2 identical)
##   - the operational marker (still is_ready_to_produce)
##   - the coin-economy framing (still coin-only, no grain)
##   - the deliberate-construction-time framing
## The naming-shape divergence is honored in the cultural-note prose at
## Track 1.5 paste (loremaster authors the `-dazi` framing); the CODE
## structure stays parallel.
##
## ## Cultural note — PLACEHOLDER for Track 1.5 (loremaster framing)
##
## *Tirandazi* (تیراندازی, lit. "arrow-throwing" / "arrow-shooting") — the
## institution of archery as a trained discipline. The mechanic surfaces
## the cultural truth: the Parthian-shot tradition (firing accurately while
## riding away — the iconic Iranian archery technique) is a TRAINED SKILL
## transmitted across generations, housed in a formal institution.
##
## [TRACK 1.5 PASTE] Loremaster Track 0 brief-time block routes from lead
## post-Track-1 ship. Four-element template:
##   1. Cultural referent — Shahnameh episodes anchoring the archery
##      tradition (Arash the Archer; Aresh-e Kamangir's bow-shot that
##      defined Iran-Turan border; the legendary kamandar archers per
##      00_SHAHNAMEH_RESEARCH.md §4 line 189).
##   2. Mechanic-surfaces-truth — how 175-coin + 960-tick construction
##      (slightly cheaper + slightly faster than Sowari-khaneh's
##      200-coin + 1080-tick cavalry-institution) lands archery-
##      institution as MORE EFFICIENT to train but with a specialized
##      output (Asb-savar Kamandar: the mounted archer).
##   3. Cross-faction caveat — Turan's archery tradition is the canonical
##      threat (the horse-archer culture per §3 line 163-165). The
##      structural mismatch: Iran's archery is institutional (trained
##      in a formal building); Turan's is native (steppe-children
##      learn to ride and shoot before they walk).
##   4. Forward-compat — the parent variant (identity-bearing
##      institutional) now has 3 sub-slots populated: generic-infantry
##      sepah (Sarbaz-khaneh), cavalry-tradition (Sowari-khaneh),
##      archery-tradition (Tirandazi). The -dazi naming-shape note
##      goes HERE in the prose, not in code.
##
## ## What lives here vs Building base
##
##   - kind = &"tirandazi" (dual-init pattern per kargar.gd / khaneh.gd /
##     mazraeh.gd / madan.gd / sarbaz_khaneh.gd / atashkadeh.gd /
##     sowari_khaneh.gd headers — _init AND _ready both set kind).
##   - NO resource_kind field (Tirandazi is not a resource source).
##   - NO ResourceNode-shape fields (production is not gathering — the
##     API surface is distinct).
##   - is_ready_to_produce: bool field, defaults false; flipped true in
##     `_on_construction_complete` (Stage 2 operational marker per
##     §9.L5). MIRRORS Sarbaz-khaneh.is_ready_to_produce + Sowari-khaneh.
##     is_ready_to_produce exactly — same field name, same semantics,
##     sub-slot specialization is at the unit-class level (Asb-savar
##     Kamandar / advanced Kamandar variants), NOT the marker level.
##   - _on_placement_complete (Stage 1): super-call first (§9.L4a +
##     Wave 1D rebake), then FogSystem vision-source registration +
##     EventBus.building_placed emit. Standard Stage-1 structural
##     pattern; identical shape to Sarbaz-khaneh / Sowari-khaneh.
##   - _on_construction_complete (Stage 2): super-call first
##     (§9.L4a + §9.L4b), then flip is_ready_to_produce = true.
##   - Static cost_coin() helper with defensive 175-coin fallback
##     (01_CORE_MECHANICS.md §5 line 195 spec). Tirandazi is coin-only
##     (grain_cost = 0 per Track 3 BalanceData).
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
## differentiation to read as "archery-institution" rather than cavalry-
## institution or infantry-institution. world-builder owns scene
## composition; this Track 1 ships the script + tests via .new() per
## §9.M4 to decouple ship timings. NavigationObstacle3D present at scene
## level (workers route AROUND — structural building like Sarbaz-khaneh /
## Sowari-khaneh).
##
## ## Why extend by path-string (not class_name on the base)
##
## Same class_name registry race as every other Building subclass (per
## Pitfall #13). Path-string extends sidesteps the race.
##
## ## Why _init AND _ready set kind
##
## Dual-init pattern per kargar.gd / khaneh.gd / mazraeh.gd / madan.gd /
## sarbaz_khaneh.gd / atashkadeh.gd / sowari_khaneh.gd headers. Scene-
## instantiation order resets @export defaults between _init and _ready;
## tirandazi.tscn (when world-builder ships it) does not override the
## `kind` export, so the engine would clobber any _init write back to
## base default (&""). _ready setter is the canonical fix; _init kept
## so Tirandazi.new() headless construction (no scene) also reports the
## right kind — used by tests per §9.M4.
class_name Tirandazi


## Canonical kind StringName for the Tirandazi class. Matches the
## BalanceData lookup key (`buildings.tirandazi` in balance.tres,
## shipped at Track 3 / 6503b0c via balance-engineer-p3s3's H3 + L6
## inaugural dogfood).
const KIND_TIRANDAZI: StringName = &"tirandazi"


# === Defensive fallback constants ===========================================
#
# Match prior subclass pattern (Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh /
# Atashkadeh / Sowari-khaneh cost helpers) — "config error doesn't break
# the UI" — when balance.tres is unreachable or the bldg_tirandazi entry
# is missing, the building still functions with a reasonable default rather
# than zero-valued degenerate behavior.
#
# Per 01_CORE_MECHANICS.md §5 line 195: "Tirandazi — 175 coin Tier 2,
# produces advanced Kamandar variants including Asb-savar Kamandar".
# Track 3 BalanceData entry shipped at 6503b0c with coin_cost = 175 +
# construction_ticks = 960 + tier = 2.
const _FALLBACK_COIN_COST: int = 175


# === Operational state =======================================================

## True once construction has completed (Stage 2 — _on_construction_complete
## has fired). Public surface for the future Phase-4 production system:
## when a consumer (UnitProductionQueue, build menu, AI training decisions)
## wants to know whether this Tirandazi can accept Asb-savar-Kamandar
## training requests, it reads is_ready_to_produce.
##
## False during construction-in-progress (Stage 1 only — building exists
## structurally but has not yet finished training-its-trainers in the
## archery discipline).
##
## Default false ensures operational-gating discipline at spawn. Mirrors
## Mazra'eh.is_gatherable + Sarbaz-khaneh.is_ready_to_produce +
## Atashkadeh.is_emitting_farr + Sowari-khaneh.is_ready_to_produce
## default-false patterns per §9.L5.
##
## Wave 2B scope: the flag itself. The actual production-queue + timer +
## UI ship in Phase 4; this Track 1 ships the flag only.
var is_ready_to_produce: bool = false


func _init() -> void:
	kind = KIND_TIRANDAZI


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd / atashkadeh.gd /
	# sowari_khaneh.gd headers). The base class doesn't currently read kind
	# directly, but the symmetry guards future refactors.
	kind = KIND_TIRANDAZI
	super._ready()


# === Autoload helper =========================================================
#
# Same canonical pattern as mazraeh.gd / madan.gd / sarbaz_khaneh.gd /
# atashkadeh.gd / sowari_khaneh.gd. Engine.has_singleton() does NOT find
# GDScript autoloads (Pitfall #12 TWO-PART) — script autoloads register as
# direct SceneTree children, not C++/GDExtension singletons. This is the
# correct discovery pattern.
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
#     READY TO PRODUCE Asb-savar Kamandar (mounted archer) and advanced
#     Kamandar variants. Training can now be queued (Phase 4 wires the
#     actual queue).
#
# Tirandazi's CAPABILITY — accepting Kamandar-variant training requests
# — is gated on Stage 2. A half-built Tirandazi reveals fog and emits
# the placement signal, but cannot yet train archers.

# Stage 1 — structural side-effects only.
#
# super-call discipline (§9.L4a + Wave 1D ship): the base
# _on_placement_complete runs the explicit-pipeline navmesh rebake.
# Subclasses MUST call super FIRST so the rebake fires before any subclass
# work that depends on a fresh navmesh state. Same shape as
# sarbaz_khaneh.gd:249 / sowari_khaneh.gd.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class triggers the navmesh rebake (Wave 1D pipeline). Tirandazi
	# has a NavigationObstacle3D (workers route AROUND the archery range —
	# structural building), so the rebake fires here and carves the
	# footprint into the live navmesh immediately on placement.
	super._on_placement_complete(placer_unit_id)
	# FogSystem ships in wave 3A. Forward-compat guard via SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads —
	# Pitfall #12). Sight=0, is_static=true: Tirandazi reveals its own
	# footprint (the institutional building IS visible to its owner team
	# without needing a separate vision source — same shape as every other
	# Iran building shipped to date).
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		_fog_node.call(&"register_vision_source", self, team, 0, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation. The Tirandazi becomes "ready to
# produce" from this tick onward.
#
# super-call discipline (§9.L4a + §9.L4b): base _on_construction_complete
# is currently `pass`, but we call super anyway per the rule — if the base
# adds non-trivial Stage-2 behavior in a future wave, every subclass
# already routes through it.
#
# The is_ready_to_produce flip is the load-bearing operational gate.
# Future Phase-4 consumers (production-queue UI, AI training decisions)
# read this flag to decide whether the Tirandazi can accept Asb-savar
# Kamandar / advanced Kamandar training requests.
func _on_construction_complete(placer_unit_id: int) -> void:
	super._on_construction_complete(placer_unit_id)
	is_ready_to_produce = true


# === Static cost helper ======================================================
#
# Read the Tirandazi's coin cost from BalanceData (in whole coin, not
# fixed-point). Used by the build menu (Track 4 — ui-developer) to display
# the price next to the button. Same defensive fall-through pattern as
# all prior cost helpers.
#
# Returns _FALLBACK_COIN_COST when BalanceData / the entry / the field is
# missing — the bldg_tirandazi SubResource shipped at Track 3 (6503b0c)
# so the normal path returns 175 from BalanceData; fallback fires only
# when balance.tres is unreachable (headless tests without the file
# present).
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
	var stats: Variant = (bldgs as Dictionary).get(KIND_TIRANDAZI, null)
	if stats == null:
		return _FALLBACK_COIN_COST
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return _FALLBACK_COIN_COST
	return int(coin_v)
