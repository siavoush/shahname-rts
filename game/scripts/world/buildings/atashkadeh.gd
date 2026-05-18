extends "res://scripts/world/buildings/building.gd"
##
## Atashkadeh (آتشکده) — Iran fire-temple. Fourth Tier-1 anchor-category
## Building variant: **sacral-emitter** (the fifth anchor variant overall,
## introducing the passive-Farr-emit pattern). Tier-1 closure: Atashkadeh
## is the last of the five Tier-1 Iran buildings (Khaneh, Mazra'eh, Ma'dan,
## Sarbaz-khaneh, Atashkadeh).
##
## Source: 01_CORE_MECHANICS.md §4.3 (Farr generators — Atashkadeh +1
## Farr/min) + 01_CORE_MECHANICS.md §5 (Tier-1 row: 150 coin + 50 grain,
## Tier-2 gateway prerequisite) + docs/ARCHITECTURE.md §6 (post-Wave 2A.5
## close entry, version bumps at wave close).
##
## Anchor-category taxonomy (per §9.J2 + Khaneh / Mazra'eh / Ma'dan /
## Sarbaz-khaneh headers for prior anchors):
##   - Khaneh: civic-anchor (settled household + population cap).
##   - Mazra'eh: resource-producing (Grain via duck-typed gather API).
##   - Ma'dan: labor-organization (modifier-emitter on adjacent mine).
##   - Sarbaz-khaneh: identity-bearing institutional (army-producer
##     pending Phase-4 production-queue, `is_ready_to_produce` flag).
##   - **Atashkadeh: sacral-emitter** — the building that passively emits
##     Farr at a fixed per-minute cadence. Distinct from prior four: not
##     civic continuity, not material extraction, not labor-organization,
##     not institutional-production — but the temple that channels divine
##     legitimacy into the civilization meter. Tier-2 GATEWAY: the player
##     must have Atashkadeh built (and Farr ≥ 40) to advance from Village
##     to Fortress tier. The Farr-emit + Tier-2-gating make Atashkadeh
##     unique in the Tier-1 roster — it is both a passive generator AND
##     a structural prerequisite for tech progression.
##
## ## Cultural note — PLACEHOLDER for Commit 1.5 (loremaster framing)
##
## *Atashkadeh* (آتشکده, lit. "fire-place" / "house of fire") — the
## sacred precinct where the eternal flame is tended by the magi
## (mowbedan), the source of ritual legitimacy that binds the king's
## rule to the divine order. The mechanic surfaces this transformation:
## Atashkadeh emits Farr passively at +1/min once construction completes,
## representing the temple's role as the channel through which divine
## sanction (farr-e izadi) flows into the civilization.
##
## The four-part cultural-note template (per §9.J2 + world-builder's
## session-2 retro pattern) will be filled by loremaster-p3s5:
##   1. Cultural referent — which Shahnameh episodes / characters anchor
##      the "fire-temple as divine legitimacy" frame? (Jamshid's farr
##      and its forfeit, Zoroaster's revelation, the legitimacy contests
##      between Iran kings, the fire-tending magi caste.)
##   2. Mechanic-surfaces-truth — how does +1 Farr/min + Tier-2 gating
##      render the cultural truth in gameplay?
##   3. Cross-faction caveat — Turan does NOT have an Atashkadeh-clone.
##      The fire-temple is specifically Iranian / Zoroastrian; Turan's
##      religious shape is distinct (shamanic / steppe-spiritual). Do
##      NOT bake "sacral-emitter" semantics into the Building base.
##   4. Forward-compat — future sacral-emitter buildings (Dadgah,
##      Barghah per 01_CORE_MECHANICS.md §4.3 generators) inherit the
##      anchor-category framing + passive-Farr-emit pattern. Field
##      naming (is_emitting_farr) generalizes; per-subclass marker
##      stays per §9.L5 N≥3 hold (Atashkadeh is the THIRD operational
##      marker; N=3 not yet a strong pattern to abstract).
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
		_fog_node.call(&"register_vision_source", self, team, 0, true)
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
# Forward-compat FarrSystem.register_emitter seam: the canonical Phase-4
# FarrSystem will gain a register_emitter(building, farr_per_min) API
# that drives the per-tick aggregate. Until then, this code path logs a
# forward-compat info-line + sets the flag. The dispatch lead's brief
# explicitly calls out that the per-tick emit is DEFERRED to Phase 4 (the
# brief notes: "FarrSystem.register_emitter does not exist yet (will ship
# at Phase 4 FarrSystem full impl). For Wave 2A.5, the building flips
# is_emitting_farr=true but the actual per-tick emit is DEFERRED").
#
# Why log instead of silent no-op: when Phase 4 ships and we audit which
# buildings registered as emitters, the log line gives us a paper trail
# (search logs for "atashkadeh would emit"). Same telemetry-friendly
# pattern as FogSystem's forward-compat guard.
#
# Farr-chokepoint discipline note (per agent-def "All Farr changes flow
# through apply_farr_change()"): this code does NOT mutate Farr directly.
# When FarrSystem.register_emitter ships, the registration is the seam;
# the per-tick emit inside FarrSystem will route through apply_farr_change
# with reason=&"atashkadeh_passive_emit" and source_unit=self. The
# chokepoint discipline is preserved.
func _on_construction_complete(placer_unit_id: int) -> void:
	super._on_construction_complete(placer_unit_id)
	is_emitting_farr = true
	# Forward-compat: FarrSystem.register_emitter ships in Phase 4. Until
	# then, we log so future audit can trace which buildings would have
	# registered. The has_method guard is real forward-compat (FarrSystem
	# autoload exists today but lacks the register_emitter method); this
	# is NOT the same as the obsolete ResourceSystem.has_method guard
	# removed at Task #117 — that one was dead code because the method
	# existed. This guard is live until Phase 4 ships register_emitter.
	if FarrSystem.has_method(&"register_emitter"):
		FarrSystem.call(&"register_emitter", self, 1.0)
	else:
		# Telemetry seam for the audit-when-Phase-4-ships read. Format
		# mirrors EventBus.building_placed emit-style: kind + team + position.
		print(
			"[atashkadeh] would emit +1/min Farr at construction-complete "
			+ "but FarrSystem.register_emitter is not yet implemented "
			+ "(Phase 4 deferred). placer=%d team=%d pos=%s"
			% [placer_unit_id, team, str(global_position)]
		)


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
