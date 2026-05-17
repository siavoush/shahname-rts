extends "res://scripts/world/buildings/building.gd"
##
## Sarbaz-khaneh (سربازخانه) — Iran "soldier-house" / barracks. Third Tier-1
## anchor-category Building variant: **identity-bearing institutional**.
##
## Source: 01_CORE_MECHANICS.md §5 (Iran buildings — "Sarbaz-khaneh (barracks)
## — produces piyade, savar, kamandar") + 02h_PHASE_3_SESSION_4_KICKOFF.md §3
## wave 2A (this wave).
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
## ## Cultural note — PLACEHOLDER for Commit 1.5 (loremaster framing)
##
## *Sarbaz-khaneh* (سربازخانه, lit. "soldier-house") — the formal
## institution where soldiers (sarbazan) are housed, trained, and made
## ready for the army. The mechanic surfaces this transformation: at
## Stage 1 (placement) the building physically exists, but it is not
## yet operational. At Stage 2 (construction complete) the building
## becomes *ready to produce* — soldiers can now be trained here.
##
## The four-part cultural-note template (per world-builder's session-2
## retro pattern) will be filled by loremaster:
##   1. Cultural referent — which Shahnameh episodes / characters anchor
##      the "training the army" institutional frame? (Kavus's failed
##      Mazandaran campaign? Rostam's tutelage of Sohrab? The standing
##      armies of Fereydun / Manuchehr?)
##   2. Mechanic-surfaces-truth — how does the construction-timer +
##      ready-to-produce gating render the cultural truth in gameplay?
##   3. Cross-faction caveat — Turan's analogue is NOT a barracks; the
##      Turanian steppe-army model is closer to clan-mobilization than
##      formal institution. The structural mismatch is sharp; do NOT
##      bake "barracks" semantics into the Building base class.
##   4. Forward-compat — future production-queue (Phase 4) inherits the
##      institutional frame: training-time, unit-cost, rally-points
##      all surface different facets of "the army takes time to forge."
##
## Cross-faction caveat (loremaster-leading-hypothesis, to be confirmed):
##   Turan's military-economy probably does NOT route through a fixed
##   "soldier-house" institution. The leading hypothesis is clan-based
##   mobilization (Afrasiyab's allied kings each bring their own forces;
##   the steppe-army assembles for a campaign and disperses after). Per
##   Mazra'eh / Ma'dan cross-faction notes: each faction's gameplay
##   institutions reflect its social organization; do NOT clone the
##   Sarbaz-khaneh template for a Turan-side barracks — that produces
##   hollow design. Flag for whoever owns Turan-side military scope.
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
		_fog_node.call(&"register_vision_source", self, team, 0, true)
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
