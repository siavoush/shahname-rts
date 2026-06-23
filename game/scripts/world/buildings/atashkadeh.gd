extends "res://scripts/world/buildings/building.gd"
##
## Atashkadeh (آتشکده) — Iran "fire-house" / sacred-flame container.
## Fourth Tier-1 anchor-category Building variant: **sacral-emitter /
## divine-source**. 5/5 closes the Iran Tier-1 roster.
##
## Source: 01_CORE_MECHANICS.md §4.3 (Farr generators — "Atashkadeh (fire
## temple): +1 Farr/min") + §5 (Tier 1 row: "+1 Farr/min, prerequisite for
## Tier 2 advance; 150 coin, 50 grain") + §5 Tier-2 gating row ("requires
## Farr ≥ 40 + Atashkadeh built").
##
## Anchor-category taxonomy (per session-2 retro's building-variant
## classification — see Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh headers
## for prior anchors):
##   - Khaneh: civic-anchor (settled household + population cap).
##   - Mazra'eh: civic-anchor / resource-producing (Grain).
##   - Ma'dan: labor-organization (modifier-emitter on adjacent mine).
##   - Sarbaz-khaneh: identity-bearing institutional (unit-production).
##   - **Atashkadeh: sacral-emitter / divine-source** — the building
##     whose mere existence emits Farr per tick. Distinct from the prior
##     four: not civic continuity, not material extraction, not labor-
##     organization, not unit-production institution — but a *continuity-
##     of-sacred-flame* container whose presence in the world is itself
##     the legitimizing mechanism. This is the FIRST passive-emit
##     building and the Tier-1 → Tier-2 gateway.
##
## Cultural note — atashkadeh (آتش‌کده), the place where the fire is kept:
##
##   *Atash* (آتش, fire) + *-kadeh* (-کده, "place / dwelling / abode";
##   the same suffix in *deh-kadeh* / village, *mey-kadeh* / wine-house).
##   The literal compound is **"fire-place"** or **"fire-house"** — a
##   container, a dwelling FOR the flame. The dictionary-default English
##   gloss "fire temple" is the tricky-gloss to handle with care: in
##   modern English usage "temple" imports an Abrahamic house-of-worship
##   register — congregation-space, scheduled service, a building people
##   gather IN to face an altar. The atash-kadeh is structurally something
##   else. It is the architectural container that exists so the sacred
##   flame can be KEPT — tended continuously by hereditary fire-priests,
##   never permitted to extinguish, fed only with consecrated wood. The
##   community's relationship to it is not "we gather there to worship"
##   but "we sustain it because its continuity is the continuity of the
##   ordered cosmos." Lead with the literal "fire-house"; treat "fire
##   temple" as the gloss that comes with theological baggage requiring
##   correction.
##
##   The Shahnameh's load-bearing anchor (00_SHAHNAMEH_RESEARCH.md §1
##   lines 85-88, Pishdadian foundational events): **Hushang** strikes
##   a stone hunting a serpent, sparks fire, and institutes its keeping
##   — Ferdowsi gives this moment the founding of the Sadeh festival.
##   The Shahnameh frame is unambiguous: fire is not a metaphor for the
##   divine, it is the visible-continuous medium through which the
##   divine relates to legitimate kingship. *Farr-ī Yazdān* (فرّ ایزدی,
##   "divine glory," 00_SHAHNAMEH_RESEARCH.md §229-231) is the same
##   theological-political fact viewed from the ruler side: just kings
##   carry the Farr, unjust kings lose it. Jamshid (§1 line 88) loses
##   the Farr when his pride corrupts him and the order he founded
##   falls — the same passage that anchors Ma'dan's metallurgical
##   inheritance anchors Atashkadeh's theological one. **The
##   Atashkadeh is where the sacred fire that legitimizes the king
##   is kept burning. That is the source-truth the mechanic maps onto.**
##
##   How the mechanic surfaces the cultural truth: Atashkadeh emits
##   +1 Farr/min CONTINUOUSLY while standing (01_CORE_MECHANICS.md
##   §4.3 generators list) — passive, per-tick, no worker dwell, no
##   trip, no action required. This is mechanically distinct from
##   every prior building and the distinction IS the source-truth:
##   the Farr does not flow because something is HARVESTED (Mazra'eh)
##   or PRODUCED (Sarbaz-khaneh) or BUFFED (Ma'dan) — it flows because
##   the sacred flame is being KEPT, continuously, the way fire-priests
##   keep it. The mechanic IS the theology, not a metaphor laid over
##   it. The Tier-1 → Tier-2 gateway condition (Farr ≥ 40 + Atashkadeh
##   built, 01_CORE_MECHANICS.md §5 Tier-2 row) likewise IS the
##   Shahnameh's claim that legitimate rule must be theologically
##   anchored before it can scale — you do not become Qal'eh (fortress,
##   the Tier-2 sovereign seat) without first sustaining the fire-house
##   that gives sovereignty its source. Loss of Atashkadeh costs −5 Farr
##   (§4.3 drains list: "Loss of an Atashkadeh building: −5 Farr — the
##   sacred flame is extinguished"); this is not "building lost" damage,
##   it is *sacred-flame extinguished* damage — the discontinuity itself
##   is the wound.
##
##   Cross-faction caveat (loremaster leading hypothesis — singular,
##   not a three-option list, per J3 cross-faction shape):
##
##   Turan's Farr economy almost certainly does NOT clone Atashkadeh.
##   Per 00_SHAHNAMEH_RESEARCH.md §311 ("the Shahnameh is culturally
##   Zoroastrian in its setting") + §307 ("design Turan as worthy
##   rivals, not cartoon villains"), the cultural-theological fact is
##   complex: Zoroastrianism is not exclusively Iranian, and historical
##   fire-cult practice extended across pre-Islamic Iranian-language
##   peoples broadly. BUT the *Shahnameh's* framing — which is the
##   project's anchor, not historical Zoroastrianism in general —
##   centers Farr-ī Yazdān as the legitimating substance of Iranian
##   kingship in opposition to Turanian rulership. Turan's analogue,
##   if any, likely routes through **khan-loyalty + steppe-mobile
##   sworn-bond rituals** — legitimacy carried in the sworn relation
##   between named ruler (Afrasiyab, Piran) and named warrior, not
##   in a continuously-tended sacred-flame in a fixed sacral building.
##   This is a STRUCTURAL MISMATCH sharper than the building-vs-
##   building variant gap (cf. Sarbaz-khaneh / mobile war-camps;
##   Ma'dan / baj; Mazra'eh / karavan): Iran's legitimacy LIVES in
##   a tended-flame in a fixed building; Turan's lives in the
##   loyalty bond and the named ruler. **Do not clone Atashkadeh as
##   a Turan building** — a naive copy would erase the settled-
##   theological vs steppe-personal asymmetry the Shahnameh's
##   Iran-Turan dichotomy is built on. When Turan Tier-1 legitimacy
##   mechanics ship (post-MVP), expect a fundamentally different
##   shape and require a fresh loremaster review. This question is
##   currently a design-chat candidate (Turan economy / legitimacy
##   pending design ratification — flag for QUESTIONS_FOR_DESIGN
##   if not already routed).
##
##   Forward-compat note — sacral-emitter anchor category and the
##   Tier-1 → Tier-2 gateway:
##
##   Atashkadeh is the FIRST instance of the **sacral-emitter /
##   divine-source** variant (loremaster anchor-category taxonomy,
##   session-2 retro; predicted slot now occupied). Future Tier-2
##   Iran sacral-emitter buildings INHERIT this anchor category but
##   carry distinct sub-variant framing — the taxonomy may grow to
##   accommodate the difference:
##     - **Dadgah** (دادگاه, "place-of-justice"; *dād* justice +
##       *-gāh* place) — +0.5 Farr/min (§4.3, §5 Tier-2 row). Same
##       passive-emit mechanical shape, but the framing shifts from
##       sacred-flame-continuity to **justice-as-Farr-source**.
##       Shahnameh frame: a just king sustains Farr through right
##       judgment (Kay Khosrow as the ideal just king, §1 line 103);
##       Dadgah surfaces the institutional setting where justice is
##       rendered. Sub-variant: sacral-emitter / justice-source.
##     - **Barghah** (بارگاه, "audience-court / royal-court") —
##       +0.5 Farr/min (§4.3, §5 Tier-2 row). Same passive-emit
##       shape, framing shifts to **sovereignty-as-Farr-source** —
##       the legitimate king holding court IS itself Farr-generating.
##       Sub-variant: sacral-emitter / sovereignty-source.
##     - **Yadgar** (یادگار, "memorial / remembrance") — +0.25
##       Farr/min, only after a hero has died (§4.3, §5 Tier-2 row).
##       Same passive-emit shape, framing is **remembrance-as-Farr-
##       source** — naming-the-dead-heroes sustains the civilization's
##       moral substance. Sub-variant: sacral-emitter / memorial-source.
##   Subsequent Iran sacral-emitter buildings inheriting this template
##   should keep: (a) continuous passive emit (no worker dwell, no
##   action required — the building's *existence-while-tended* is the
##   mechanic), (b) explicit framing of WHICH Shahnameh source-of-
##   legitimacy this sub-variant surfaces (flame, justice, sovereignty,
##   remembrance — they are NOT interchangeable), (c) registration with
##   FarrSystem at Stage 2 (operational flip) rather than Stage 1
##   (structural placement) — the sacred fire is not "burning" until
##   construction completes; mirrors Mazra'eh.is_gatherable +
##   Sarbaz-khaneh.is_ready_to_produce gating discipline (per L5
##   two-stage seam). The Tier-1 → Tier-2 GATEWAY status, however,
##   is unique to Atashkadeh — Dadgah / Barghah / Yadgar do not gate
##   tier-up, only Atashkadeh does. Keep that asymmetry intact when
##   the future-clone templates ship.
##
## ## What lives here vs Building base
##
##   - kind = &"atashkadeh" (Building-identity per RNC §4.5 SSOT;
##     dual-init pattern per khaneh.gd / mazraeh.gd / madan.gd /
##     sarbaz_khaneh.gd — _init AND _ready both set kind).
##   - NO resource_kind field (Atashkadeh is not a resource source).
##   - NO ResourceNode-shape fields (production is passive emission,
##     not gathering — the API surface is distinct).
##   - is_emitting_farr: bool field, defaults false; flipped true in
##     `_on_construction_complete` (Stage 2 operational marker mirroring
##     Mazra'eh.is_gatherable + Sarbaz-khaneh.is_ready_to_produce per
##     §9.L5).
##   - _on_placement_complete (Stage 1): super-call first (Wave 1D
##     navmesh rebake), then FogSystem vision-source registration +
##     EventBus.building_placed emit. Standard structural pattern per
##     §9.L4a.
##   - _on_construction_complete (Stage 2): super-call first per
##     §9.L4a + §9.L4b (base body currently `pass` but discipline
##     applies regardless), then flip is_emitting_farr = true + attempt
##     FarrSystem.register_emitter registration. The actual per-tick
##     emit is GATED on FarrSystem.register_emitter existing (forward-
##     compat seam — currently logs an info message; the real per-tick
##     emit ships when FarrSystem's full impl lands in Phase 4).
##   - Static cost_coin() helper with defensive 150-coin fallback +
##     cost_grain() helper with defensive 50-grain fallback. Atashkadeh
##     is the FIRST building with a non-zero grain cost in the Tier-1
##     roster (Mazra'eh / Ma'dan / Sarbaz-khaneh are coin-only).
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
## Scene-side (world-builder Track 2 — separate PR if shipped): BoxMesh
## sized to convey "sacred precinct" — likely a tall narrow structure
## with a fire-pit visual element. Color distinct from prior four
## buildings: probably a warm orange/red firelight tone (world-builder
## decides; reads as "fire-temple" from across the map).
## NavigationObstacle3D present (workers route AROUND, not through —
## Atashkadeh is a structural building like Khaneh / Ma'dan / Sarbaz-
## khaneh, contrasts with Mazra'eh's walkable field).
##
## ## Why extend by path-string (not class_name on the base)
##
## Same class_name registry race as every other Building subclass (per
## Pitfall #13). Path-string extends sidesteps the race.
##
## ## Why _init AND _ready set kind
##
## Dual-init pattern per kargar.gd / khaneh.gd / mazraeh.gd / madan.gd /
## sarbaz_khaneh.gd headers. Scene-instantiation order resets @export
## defaults between _init and _ready; atashkadeh.tscn (when world-builder
## ships it) does not override the `kind` export, so the engine would
## clobber any _init write back to base default (&""). _ready setter is
## the canonical fix; _init kept so Atashkadeh.new() headless construction
## (no scene) also reports the right kind — used by tests per §9.M4.
class_name Atashkadeh


## Canonical kind StringName for the Atashkadeh class. Matches the
## BalanceData lookup key (`buildings.atashkadeh` in balance.tres, once
## balance-engineer-p3s5 ships the bldg_atashkadeh sub-resource entry
## via parallel dispatch).
const KIND_ATASHKADEH: StringName = &"atashkadeh"

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1


# === Defensive fallback constants ===========================================
#
# Match prior subclass pattern (Khaneh / Mazra'eh / Ma'dan / Sarbaz-khaneh
# cost helpers) — "config error doesn't break the UI" — when balance.tres
# is unreachable or the bldg_atashkadeh entry is missing, the building
# still functions with reasonable defaults rather than zero-valued
# degenerate behavior.
#
# Per 01_CORE_MECHANICS.md §5: "Atashkadeh — 150 coin + 50 grain"
# (placeholder; balance-engineer-p3s5 tunes via balance.tres in parallel
# dispatch).
const _FALLBACK_COIN_COST: int = 150
const _FALLBACK_GRAIN_COST: int = 50


# === Operational state =======================================================

## True once construction has completed (Stage 2 — _on_construction_complete
## has fired) AND the building has activated its passive Farr-emit cadence.
## Public surface for the future FarrSystem.register_emitter consumer:
## when FarrSystem ships its full impl (Phase 4), it queries this flag to
## determine which buildings contribute to the per-tick Farr-emit aggregate.
##
## False during construction-in-progress (Stage 1 only — building exists
## structurally but has not yet activated its sacral function).
##
## Default false ensures operational-gating discipline carries through the
## two-stage lifecycle: a half-built Atashkadeh does NOT emit Farr.
## Mirrors Mazra'eh.is_gatherable's default-false pattern + Sarbaz-khaneh.
## is_ready_to_produce's pattern (§9.L5 — per-subclass marker until N≥4
## share near-identical bool-flip semantics; Atashkadeh is N=3, hold the
## per-subclass shape).
##
## Wave 2A.5 scope: the flag itself + forward-compat
## FarrSystem.register_emitter call site. The actual per-tick emit ships
## when FarrSystem gains the register_emitter API (Phase 4 FarrSystem
## full impl).
var is_emitting_farr: bool = false


func _init() -> void:
	kind = KIND_ATASHKADEH


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (dual-init pattern per
	# khaneh.gd / mazraeh.gd / madan.gd / sarbaz_khaneh.gd headers). The base
	# class doesn't currently read kind directly, but the symmetry guards
	# future refactors.
	kind = KIND_ATASHKADEH
	super._ready()
	# §9.M6 — spawn log mirroring throne.gd:282 / madan.gd:242 / mazraeh.gd:197.
	print("[atashkadeh] _ready team=%d position=%s unit_id=%d" % [
		team, str(global_position), unit_id])


# === Autoload helper =========================================================
#
# Same canonical pattern as mazraeh.gd / madan.gd / sarbaz_khaneh.gd.
# Engine.has_singleton() does NOT find GDScript autoloads (Pitfall #12
# TWO-PART) — script autoloads register as direct SceneTree children, not
# C++/GDExtension singletons. This is the correct discovery pattern.
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
#   Stage 2 (_on_construction_complete) — OPERATIONAL: the building begins
#     emitting Farr passively. The is_emitting_farr flag flips true; the
#     forward-compat FarrSystem.register_emitter call site fires (or logs
#     a forward-compat info when FarrSystem.register_emitter doesn't yet
#     exist — Phase 4 supersedes).
#
# Atashkadeh's CAPABILITY — passive Farr-emit at +1/min — is gated on
# Stage 2. A half-built Atashkadeh reveals fog (Stage 1 vision-source)
# and emits building_placed, but does NOT contribute Farr until
# construction completes.

# Stage 1 — structural side-effects only.
#
# super-call discipline (§9.L4a + Wave 1D ship): the base
# _on_placement_complete now runs the explicit-pipeline navmesh rebake.
# Subclasses MUST call super FIRST so the rebake fires before any subclass
# work that depends on a fresh navmesh state. Same shape as
# sarbaz_khaneh.gd:249.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Base class triggers the navmesh rebake (Wave 1D pipeline). Atashkadeh
	# has a NavigationObstacle3D (workers route AROUND the temple precinct
	# — the sacred enclosure is not walked through), so the rebake fires
	# here and carves the footprint into the live navmesh immediately on
	# placement.
	super._on_placement_complete(placer_unit_id)
	# FogSystem ships in wave 3A. Forward-compat guard via SceneTree autoload
	# pattern (Engine.has_singleton does NOT find GDScript autoloads —
	# Pitfall #12). Sight=0, is_static=true: Atashkadeh reveals its own
	# footprint (the temple IS visible to its owner team without needing a
	# separate vision source — same shape as Khaneh / Mazra'eh / Ma'dan /
	# Sarbaz-khaneh).
	var _fog_node: Node = _autoload_or_null(&"FogSystem")
	if _fog_node != null and _fog_node.has_method(&"register_vision_source"):
		var sight: int = _resolve_fog_sight_cells()
		_fog_handle = _fog_node.call(&"register_vision_source", self, team, sight, true)
	EventBus.building_placed.emit(placer_unit_id, kind, team, global_position)


# Stage 2 — operational activation. The Atashkadeh begins passive Farr
# emission from this tick onward.
#
# super-call discipline (§9.L4a + §9.L4b): base _on_construction_complete
# is currently `pass`, but we call super anyway per the rule — if the base
# adds non-trivial Stage-2 behavior in a future wave (e.g., a project-wide
# ResourceSystem.notify_construction_complete chokepoint), every subclass
# already routes through it.
#
# The is_emitting_farr flip is the load-bearing operational gate. Future
# Phase-4 consumers (FarrSystem per-tick aggregate, build menu, AI tech
# decisions, Tier-2 gating check) read this flag to decide whether the
# Atashkadeh contributes to the +1/min Farr generation.
#
# Mirrors Mazra'eh.is_gatherable's Stage-2 flip + Sarbaz-khaneh.
# is_ready_to_produce's Stage-2 flip — same operational-gating discipline
# applied to the sacral-emit capability.
#
# FarrSystem.register_emitter seam (Phase 4 wave 1 — NOW LIVE): FarrSystem
# gained the register_emitter(building, farr_per_min) API this wave. The
# Wave-2A.5 forward-compat has_method guard (+ its L7 allowlist entry) is
# REMOVED — the method now exists, so guarding it would be a §9.M7
# defensive-fallback-masking guard (it would silently no-op if a future
# refactor renamed the method, instead of crashing loud). We call it directly.
#
# Rate source: BalanceData.bldg_atashkadeh.farr_per_min_x100 (= 100 = +1/min,
# Sim Contract §1.6 integer path), converted to whole-Farr/min at the
# register_emitter boundary. Falls back to the spec +1/min if BalanceData is
# absent (test scenes) — loud-default, NOT silent-zero (§9.L9).
#
# Farr-chokepoint discipline (CLAUDE.md "All Farr changes flow through
# apply_farr_change()"): this code does NOT mutate Farr directly. The
# registration is the seam; the per-tick emit inside FarrSystem._flush_emitter_
# accrual routes through apply_farr_change with reason=&"atashkadeh_emission"
# + source_unit=the emitter. The chokepoint is preserved.
func _on_construction_complete(placer_unit_id: int) -> void:
	super._on_construction_complete(placer_unit_id)
	is_emitting_farr = true
	var farr_per_min: float = _resolve_farr_per_min()
	FarrSystem.register_emitter(self, farr_per_min)
	print("[atashkadeh] construction-complete — registered as Farr emitter "
		+ "+%.2f/min placer=%d team=%d unit_id=%d" % [
			farr_per_min, placer_unit_id, team, unit_id])


# Resolve the per-minute Farr emission rate (whole Farr units) from
# BalanceData.bldg_atashkadeh.farr_per_min_x100 (x100 → whole-Farr/min at this
# boundary). Spec default +1.0/min (§4.3) if BalanceData / the field is absent.
func _resolve_farr_per_min() -> float:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 1.0
	var bd: Resource = load(path)
	if bd == null:
		return 1.0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 1.0
	var stats: Variant = (bldgs as Dictionary).get(KIND_ATASHKADEH, null)
	if stats == null:
		return 1.0
	var v: Variant = stats.get(&"farr_per_min_x100")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v) / 100.0
	return 1.0


# === Static cost helpers =====================================================
#
# Read the Atashkadeh's coin + grain costs from BalanceData (in whole
# units, not fixed-point). Used by the build menu to display the price
# next to the button. Same defensive fall-through pattern as Khaneh /
# Mazra'eh / Ma'dan / Sarbaz-khaneh cost helpers.
#
# Returns the fallback when BalanceData / the entry / the field is missing
# — placeholder until balance-engineer-p3s5 ships the bldg_atashkadeh
# SubResource entry via parallel dispatch.
#
# Atashkadeh is the FIRST building in the Tier-1 roster with a non-zero
# grain cost (50 grain per 01_CORE_MECHANICS.md §5). The cost_grain()
# helper is new to the cost-helper family.
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
	var stats: Variant = (bldgs as Dictionary).get(KIND_ATASHKADEH, null)
	if stats == null:
		return _FALLBACK_COIN_COST
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return _FALLBACK_COIN_COST
	return int(coin_v)


static func cost_grain() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return _FALLBACK_GRAIN_COST
	var bd: Resource = load(path)
	if bd == null:
		return _FALLBACK_GRAIN_COST
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return _FALLBACK_GRAIN_COST
	var stats: Variant = (bldgs as Dictionary).get(KIND_ATASHKADEH, null)
	if stats == null:
		return _FALLBACK_GRAIN_COST
	var grain_v: Variant = stats.get(&"grain_cost")
	if typeof(grain_v) != TYPE_INT and typeof(grain_v) != TYPE_FLOAT:
		return _FALLBACK_GRAIN_COST
	return int(grain_v)


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
	var v: Variant = fog_cfg.get(&"sight_atashkadeh_cells")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


func _exit_tree() -> void:
	# Wave 3-BuildingDestructibility (session 9, architecture-reviewer
	# C1.2 BLOCKER fix-up): super-call required.
	super._exit_tree()
	# Phase 4 wave 1: unregister as a Farr emitter on the non-destruction free
	# path (harness teardown free(), scene reload). The destruction path
	# (_on_health_zero → building_destroyed) already unregisters via FarrSystem's
	# handler BEFORE queue_free, so this is an idempotent no-op there; here it
	# covers frees that never fired building_destroyed. unregister_emitter is
	# idempotent (logs the no-op when not registered).
	if is_emitting_farr:
		FarrSystem.unregister_emitter(self)
	if _fog_handle >= 0:
		var fog: Node = _autoload_or_null(&"FogSystem")
		if fog != null and fog.has_method(&"deregister_vision_source"):
			fog.call(&"deregister_vision_source", _fog_handle)
		_fog_handle = -1
