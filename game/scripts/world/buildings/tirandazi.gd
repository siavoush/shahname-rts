extends "res://scripts/world/buildings/building.gd"
##
## Tirandazi (تیراندازی) — Iran "arrow-shooting practice-place" / archery
## range. Second Tier-2 institutional building; **sub-slot** under the
## identity-bearing institutional anchor-category established by
## Sarbaz-khaneh (Wave 2A).
##
## Source: 01_CORE_MECHANICS.md §5 line 195 (Tier-2 row — "Tirandazi
## (archery range) — Produces advanced Kamandar variants — 175 coin") +
## §5 line 189 (Tier-2 gating — requires Farr ≥ 40 + Atashkadeh built).
##
## Anchor-category sub-slot classification (per Wave 2B Track 0 loremaster
## brief-time review — J2 watchlist trichotomy N=2 graduation):
##
##   Outcome: **SLOT-FIT-VERIFY**. Tirandazi fills the predicted-empty
##   *archery-tradition* sub-slot under the identity-bearing institutional
##   anchor-category. The anchor-shape (institution that transforms civilian
##   into named military arm via formal oath + trained skill) is invariant.
##
##   Naming-shape divergence (Sarbaz-khaneh header prediction, locked at
##   Wave 2B Track 0):
##     Persian morphology marks the cultural register: *-khaneh* (house/
##     place) for sepah / mounted-aristocracy; *-dazi* (practice/discipline)
##     for archery. The Parthian-shot tradition is canonically about
##     TRAINED SKILL transmitted master-to-apprentice — the *skill itself*
##     is the load-bearing inheritance, not the building. **This is
##     SURFACE-LANGUAGE divergence, NOT anchor-shape divergence.** The
##     building still mechanically maps onto identity-bearing institutional
##     (footprint + production-queue + Tier-2 gating + Stage-2 lifecycle);
##     the *-dazi* suffix is Persian's way of saying "what matters here is
##     the practice that happens at this place," not "this is a new kind
##     of building."
##
##   Sub-slot taxonomy under identity-bearing institutional:
##     - generic-infantry sepah   → Sarbaz-khaneh (Tier 1, Wave 2A)
##     - cavalry-tradition         → Sowari-khaneh (Tier 2, Wave 2B)
##     - **archery-tradition       → Tirandazi (Tier 2, Wave 2B)**
##
## Cultural note — tirandazi (تیراندازی), the practice of arrow-shooting:
##
##   *Tir* (تیر, arrow) + *andazi* (انداز + nominalizer, "the throwing /
##   shooting of"; from *andakhtan* — to throw, release). The literal
##   compound is "arrow-shooting" — the PRACTICE itself, with the building
##   being where the practice happens. The English gloss "archery range"
##   is the tricky-gloss to handle with care: in modern usage "range"
##   imports a recreational-sport register (the place where one practices
##   for leisure or sport-competition) that compresses Tirandazi's
##   institutional weight. The Parthian-shot is not a sport; it is a
##   military-cultural inheritance whose transmission is the substance
##   of Iran's archery tradition. "Archery-discipline" is closer; "the
##   place where the arrow-shooting skill is trained" is the literal
##   shape.
##
##   The Shahnameh's load-bearing anchor (00_SHAHNAMEH_RESEARCH.md §4
##   line 189): "Persian/Parthian archery was legendary in the ancient
##   world." This is not flavor — the Parthian-shot (turning in the
##   saddle, releasing under the horse's neck, hitting at gallop) is
##   the most famous military technique attributed to the Iranian-
##   plateau peoples in the ancient sources. The Shahnameh's Kamandar
##   is the institutional-ordinary inheritor of that tradition — not
##   Arash-the-Archer (the mythological hero-archer whose bow-shot
##   defines the Iran-Turan border in legend; he is hero-class, not
##   institutional-class, and lives outside Tirandazi's scope). The
##   Kamandar collective who hold the field while pahlavans decide
##   single combat (mard-o-mard) ARE Tirandazi's product; the
##   hero-archer Arash is NOT. (Arash treatment in MVP scope deferred;
##   candidate for Phase-5 hero wave or Yadgar/hero-monument mechanic.)
##
##   How the mechanic surfaces the cultural truth: Tirandazi costs
##   175 coin with no grain component (clone-rule: coin-economy
##   framing). The cost is slightly LOWER than Sowari-khaneh's 200
##   coin — archery requires bow + arrow + training-ground but not
##   the warhorse + armor + stable-keeper infrastructure of mounted
##   aristocracy. The Tier-2 placement gating (Qal'eh + Farr ≥ 40
##   prereqs, deferred Wave 2C) anchors the cultural-political fact
##   that institutional-archery (as distinct from a single hunter
##   with a bow) requires the legitimate kingdom's training-and-
##   transmission apparatus. Construction_ticks = 960 (balance-engineer's
##   ladder-defense at 32s; slightly less than Sowari-khaneh's 1080
##   per the no-horses-to-train-alongside-warriors reasoning) reflects
##   the institutional commitment of training the skill.
##
##   Cross-faction caveat (loremaster leading hypothesis — singular,
##   not a list, per J3 cross-faction shape):
##
##   Turan's archery is NOT a Tirandazi-clone. Per
##   00_SHAHNAMEH_RESEARCH.md §3 line 163 + §4 line 199, Turan's
##   horse-archer is the *steppe-horse-archer* tradition — light,
##   mobile, harassment-formation, the bow learned-from-childhood-on-
##   horseback as daily-life skill, NOT institutionally-trained at a
##   named building. The structural mismatch is sharp: Iran's archery
##   tradition LIVES in institutional training (Tirandazi as the
##   place where the Parthian-shot is formally transmitted); Turan's
##   LIVES in the herder-warrior's daily practice from horseback (the
##   bow is part of his life, not a training-pathway he enters). **Do
##   not clone Tirandazi as a Turan building.** When Turan Tier-2
##   archery ships (post-MVP), expect a fundamentally different shape
##   and require a fresh loremaster review. Turan economy still
##   pending design ratification — flag for QUESTIONS_FOR_DESIGN.md
##   if not already routed.
##
##   Forward-compat note — naming-shape vs anchor-shape:
##
##   Tirandazi's *-dazi* suffix is the first instance of a
##   surface-language divergence within a same-anchor-category sub-slot
##   cluster. Future Iran buildings may use further Persian morphological
##   shapes (*-gah* place, *-kadeh* dwelling, *-gar* doer, *-zar*
##   place-of-X) that mark cultural register without indicating
##   anchor-shape divergence. The discipline locked at Wave 2B Track 0:
##   *Persian naming convention is one input to brief-time anchor-
##   category classification, but mechanical/cultural-load criteria
##   are the decisive inputs. Naming morphology surfaced in the
##   cultural-note header; anchor-shape determined independently.*
##   See docs/ANCHOR_CATEGORY_TAXONOMY.md §3 for the
##   naming-shape-vs-anchor-shape sub-section.
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

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1


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
	# Wave 3A.6 Track 1 — Tirandazi produces Kamandar (the Parthian-shot
	# archer tradition, 00_SHAHNAMEH_RESEARCH.md §4 line 189). Tirandazi
	# is *practice/discipline* — the building name reflects training, not
	# barracks. Per kickoff §1: only Kamandar this wave; the
	# AsbSavarKamandar (mounted archer) production locus is deferred.
	produces = [&"kamandar"]


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd / atashkadeh.gd /
	# sowari_khaneh.gd headers). The base class doesn't currently read kind
	# directly, but the symmetry guards future refactors.
	kind = KIND_TIRANDAZI
	# Dual-init mirror — scene defaults clobber _init writes between _init
	# and _ready (kargar.gd header pattern). Same shape as `kind` above.
	produces = [&"kamandar"]
	super._ready()
	# §9.M6 — spawn log mirroring throne.gd:282 / madan.gd:242 / mazraeh.gd:197.
	print("[tirandazi] _ready team=%d position=%s unit_id=%d" % [
		team, str(global_position), unit_id])


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
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
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
	var v: Variant = fog_cfg.get(&"sight_tirandazi_cells")
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
		print("[tirandazi] production_cancel_on_destruction unit=%s" % str(canceled_unit))
	super._on_health_zero(unit_id_in)
