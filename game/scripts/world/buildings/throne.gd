extends "res://scripts/world/buildings/building.gd"
##
## Throne (تخت, takht) — Iran/Turan royal-seat / civilizational HQ. The FIFTH
## anchor-category Building variant: **sovereignty-bearing institution**.
## Closes Iran Tier-1 (6/6 total: Khaneh + Mazra'eh + Ma'dan + Sarbaz-khaneh +
## Atashkadeh + Throne) AND introduces the first cross-faction-symmetric
## anchor-category — Turan ships an identical Throne instance with a different
## cultural register (sworn-loyalty named-rulership) but the same anchor-shape.
##
## Source: 01_CORE_MECHANICS.md §5 line 181 (Tier-1 row — "Throne (تخت) —
## Capital. Loss = defeat. Spawns workers. Comes pre-placed at game start."),
## §1 line 61 (win condition — "eliminate enemy main building (the Throne)"),
## §2 line 85 (match-start spawn), §10 line 332 (loss condition — "Your Throne
## is destroyed").
##
## Anchor-category classification (per Wave-3-Throne Track 4 loremaster
## brief-time review, 2026-05-22 — J2 watchlist trichotomy graduation
## moment, taxonomy-growth-required outcome #3):
##
##   Outcome: **TAXONOMY-GROWTH-REQUIRED**. Throne demanded a NEW anchor-
##   category beyond the four established Tier-1 anchors. Civic-anchor was
##   pre-assigned by lead's original brief; mirror-reviewer C3.1 correctly
##   flagged the mismatch (civic-anchor is replicable + productive-stewardship-
##   shaped; Throne is singular + terminus-of-flow). Loremaster review at
##   brief-time walked through each existing anchor-category and rejected
##   each — see docs/ANCHOR_CATEGORY_TAXONOMY.md §1.5 for the full reasoning.
##
##   The fifth anchor-category: **sovereignty-bearing institution**.
##   Mechanical shape: singular per faction + terminal-stakes (destruction =
##   loss) + IDropoffTarget (resources flow TO the seat) + high HP + spawns
##   workers + tier-transition convertible (→ Qal'eh fortified-royal-seat).
##   Cultural shape: the institutional CENTER of the realm — not one
##   institution among many but the condition-of-possibility for institutions.
##
##   Sub-slot taxonomy under sovereignty-bearing institution:
##     - **base-royal-seat       → Throne (Tier 1, Wave-3-Throne)**
##     - fortified-royal-seat     → Qal'eh (Tier 2, Wave 2C / Phase 4)
##     - imperial-court-seat      → Royal Court (Tier 3, post-MVP)
##
##   Sub-slot axis is *tier-progression of the seat*. Unlike other anchor-
##   categories where sub-slots are independent new-instance placeable
##   buildings, sovereignty-bearing institution sub-slots progress through
##   *conversion* of the existing seat (Throne → Qal'eh → Royal Court),
##   preserving the singular-per-faction invariant across tier-transitions.
##
## Cultural note — takht (تخت), the seat where the king sits:
##
##   *Takht* (تخت) is the canonical Persian word for "throne," and the
##   Shahnameh uses it ubiquitously across all three ages — the seat is what
##   distinguishes a king from a wanderer, a realm from a domain. The English
##   gloss "throne" is straightforward in this case — no high-baggage J3
##   tricky-gloss correction needed; the English-Persian register-alignment
##   is unusually clean. The cultural weight to surface is not in the WORD
##   but in the INSTITUTIONAL ROLE: takht is not a chair; it is the
##   civilization's center-of-gravity made architectural. Compound forms in
##   Persian extend this: *takht-e-shahi* (royal throne), *takht-neshin*
##   (one who sits on the throne, i.e., the reigning king as a role rather
##   than a name), *bar-takht* (on the throne, i.e., in power). The takht
##   persists; the *takht-neshin* changes.
##
##   The Shahnameh's load-bearing anchors (00_SHAHNAMEH_RESEARCH.md):
##   - **Kay Khosrow renouncing the throne** (§1 line 103) — the ideal just
##     king, having achieved final victory over Afrasiyab, *renounces the
##     takht* and walks into the mountains. He renounces the SEAT, not just
##     his personal rule; the institution persists; another *takht-neshin*
##     succeeds. This is the load-bearing anchor for "the throne is distinct
##     from any individual ruler."
##   - **Kaveh's banner threatening Zahhak's throne** (§1 line 90) — the
##     act that overthrows the tyrant is the threat-TO-THE-SEAT, not merely
##     the killing of the man. Fereydun does not simply kill Zahhak; he
##     chains him beneath Mount Damavand and INSTALLS himself on the seat
##     (§1 line 91). The seat is the political artifact whose continuity IS
##     the kingdom's continuity.
##   - **Iraj's seat divided** (§1 line 91) — when Fereydun divides the
##     world among Salm / Tur / Iraj, he is dividing the *seats*. The Iran-
##     Turan war originates in the violation of seat-inheritance — Salm and
##     Tur murder Iraj to seize his seat. The entire heroic-age conflict
##     traces back to this primal seat-violation.
##
##   The MECHANIC IS THE THEOLOGY: the Throne's "destruction ends the
##   kingdom" win-condition mechanically realizes the Shahnameh's political-
##   theological claim that civilization is anchored in the seat. This is
##   not a metaphor — it is the literal narrative shape of every Iran-Turan
##   campaign in the epic. The wars do not end when armies are defeated;
##   they end when *takht-e* Afrasiyab falls or *takht-e* Iran falls. The
##   game's win-condition is the Shahnameh's own win-condition made
##   playable.
##
##   How the mechanic surfaces the cultural truth:
##   - **Singular per faction (one Throne)** — Iran has one seat; you cannot
##     hedge across multiple capitals. Mirrors the Shahnameh's monarchic
##     theology: there is one legitimate seat, not many.
##   - **Pre-placed at match-start, not player-built** — the seat is the
##     STARTING CONDITION of civilization. You cannot found a new kingdom
##     mid-match by building a second throne. (Contrast: a player can build
##     additional Khaneh, additional Sarbaz-khaneh, additional Atashkadeh.
##     The throne is the *given*; everything else is *built upon* it.)
##   - **IDropoffTarget — workers deposit AT the Throne** — Coin and Grain
##     gathered by dehqan-class workers flow back to the seat. This is the
##     literal mechanical realization of *baj* and tax-flow-to-the-king
##     (the dehqan's stewardship culminates in delivery to the seat that
##     legitimates it). The dehqan-Throne reciprocity is the Shahnameh's
##     attested economic-political relationship made playable per-tick.
##   - **High HP + sustained-military-defendable (2000 HP per balance.tres)**
##     — destroying the seat must require committed military effort, NOT
##     opportunistic raid. The Shahnameh's seat-falls (Zahhak's, Afrasiyab's)
##     are climactic events at the END of campaigns, not incidental skirmish-
##     outcomes. HP tuning reflects this.
##   - **Spawns workers (kargar)** — the king's seat provisions the labor-
##     base. Culturally: dehqan-class workers belong to the realm whose seat
##     they serve; mechanically: the Throne is the labor-base origin point.
##   - **Forward-compat: tier-transition to Qal'eh** — when the player
##     achieves Tier-2 progression (per `01_CORE_MECHANICS.md §5 line 193`),
##     the Throne CONVERTS to Qal'eh (fortified-royal-seat). The seat
##     PERSISTS through tier-transition — the realm's identity does not
##     change when its seat fortifies; the seat earns its fortification
##     through progression. (Distinct from other anchor-categories where
##     Tier-2 buildings are new instances; here, the singular-per-faction
##     invariant is preserved by conversion-not-replacement.)
##
##   Cross-faction NEAR-symmetry (loremaster leading hypothesis, distinct
##   from the structural-mismatch pattern of the prior four anchor-
##   categories):
##
##   Turan ALSO ships a Throne. This is the ONLY anchor-category where
##   Iran and Turan have a structurally-symmetric building. Per
##   00_SHAHNAMEH_RESEARCH.md §3 line 115 + lore-corpus more broadly:
##   Afrasiyab's seat (the takht of Turan) is canonically named and
##   located; capture/destruction of the enemy throne is THE climactic
##   act of the Iran-Turan wars. Kay Khosrow's victory over Afrasiyab
##   (§1 line 103 + §1 line 121 indirectly via Siavoush's vengeance arc)
##   is the seat-fall that closes the Kayanian heroic age.
##
##   Cultural register differs sharply:
##   - Iran's takht is **Farr-legitimized** — kingship rests on the divine
##     glory anchored in sacred-flame continuity (Atashkadeh-flowing-to-
##     Throne); just rule sustains Farr, unjust rule loses it (Jamshid's
##     fall per §1 line 88 is the canonical case).
##   - Turan's takht is **sworn-loyalty-legitimized** — kingship rests on
##     the personal-bond network between Afrasiyab/khan-lineage and named
##     warriors (Piran-Viseh, etc.); legitimacy flows through allegiance,
##     not through theological anchor.
##
##   Anchor-shape invariant across both: singular seat, terminal-stakes,
##   IDropoffTarget, destruction = end-of-realm. **Do NOT structurally
##   differentiate the Turan Throne from the Iran Throne at the building-
##   class level — same `throne.gd` extends, same mechanic, different
##   team-id and visual accent.** The structural-mismatch hypothesis
##   governing the other four anchor-categories (Mazra'eh / Ma'dan /
##   Sarbaz-khaneh / Atashkadeh — each requiring a fundamentally different
##   Turan shape) does NOT apply here. Throne is the exception.
##
##   Forward-compat note — sovereignty-bearing institution sub-slot
##   taxonomy:
##
##   Throne is the FIRST instance of the sovereignty-bearing institution
##   anchor-category (taxonomy-growth-required outcome #3 in the J2
##   trichotomy's empirical history, after Ma'dan's labor-organization
##   and Atashkadeh's sacral-emitter / divine-source). Future tier-
##   progression instances:
##     - **Qal'eh** (قلعه, "fortress") — Tier-2 fortified-royal-seat.
##       CONVERTS the Throne (does not replace it). Per `01_CORE_
##       MECHANICS.md §5 line 193`, Qal'eh "converts your Throne to
##       'Fortress mode,' unlocking Tier 2 buildings." The conversion-
##       mechanic preserves seat-identity through tier-transition. Wave
##       2C / Phase 4 scope.
##     - **Royal Court** (predicted, post-MVP) — Tier-3 imperial-court-
##       seat. Per `01_CORE_MECHANICS.md §8 line 284`, the Tier-3
##       progression. Likely converts Qal'eh in similar shape.
##   The sub-slot axis is *tier-progression of the seat*; the conversion-
##   mechanic is structural to this anchor-category (distinguishing it
##   from sacral-emitter / identity-bearing-institutional / civic-anchor /
##   labor-organization, all of which use new-instance placement for sub-
##   slot specialization). The Throne template-seed lays this distinction
##   down; future tier-progression work inherits the conversion-not-
##   replacement pattern.
##
## ## What lives here vs Building base
##
##   - kind = &"throne". Dual-init pattern per kargar.gd / khaneh.gd /
##     atashkadeh.gd / sarbaz_khaneh.gd headers — _init AND _ready set it.
##   - Joins &"thrones" SceneTree group on _ready so
##     ResourceSystem.dropoff_for_team can iterate without walking the
##     subtree. Group membership is the canonical lookup channel for
##     buildings (units use SpatialAgentComponent / SpatialIndex; buildings
##     use SceneTree groups — per mirror C1.2 anti-misuse warning).
##   - **Implements RNC §5.2 IDropoffTarget protocol** — the
##     `deposit(resource_kind, amount, worker)` + `get_deposit_position()`
##     duck-typed pair that UnitState_Returning queries when a Throne
##     exists for the worker's team. Throne owns the chokepoint
##     ResourceSystem.change_resource call internally (mirror C1.4: only
##     ONE path calls change_resource per deposit cycle — when Throne
##     exists, Throne does; when no Throne, Returning falls back inline).
##   - Emits EventBus.throne_destroyed(team_id) when its HealthComponent
##     hits zero — forward-compat seam for Phase 8 win/lose screen.
##     Wave-3-Throne emits the signal; Phase 8 consumes.
##   - Registers a static FogSystem vision source on _on_placement_complete
##     using `sight_throne_cells = 4` from BalanceData.fog (forward-compat
##     schema from 3A.0; Throne is FIRST runtime consumer). Sight=4 cells
##     = 16m at 4m/cell — "always-on building vision anchoring the start
##     area" per fog_config.gd:77.
##
## Base Building owns: kind/team/unit_id schema, place_at seam, &"buildings"
## group join, get_footprint_aabb(), unit_id counter, two-stage lifecycle,
## sim_phase subscription (Wave 3A.6 production state machine — Throne does
## not yet `produces` anything; the field defaults []).
##
## ## Why extend by path-string (not class_name on the base)
##
## Same class_name registry race as every other Building subclass (per
## atashkadeh.gd / sarbaz_khaneh.gd / mazraeh.gd / madan.gd headers + the
## base building.gd:70-75 note). Path-string extends sidesteps the race
## entirely. THIS subclass uses `class_name Throne` for its own identity,
## which is registry-safe because the base building.gd doesn't declare
## one.
##
## **§9.L10 note on brief-vs-canonical-pattern:** brief v1.0.2 §4 Track 1
## specifies `class_name Throne extends Building`. The project's canonical
## pattern (atashkadeh.gd:1, sarbaz_khaneh.gd:1, mazraeh.gd:1, madan.gd:1,
## khaneh.gd:1) is `extends "res://scripts/world/buildings/building.gd"` +
## `class_name <Name>`. Per session-7/8 retro discipline: canonical
## project pattern overrides brief prose. This file follows canonical.
##
## ## Why _init AND _ready set kind
##
## Dual-init pattern per kargar.gd / atashkadeh.gd / sarbaz_khaneh.gd —
## scene-instantiation order resets @export defaults from the .tscn
## definition BETWEEN _init and _ready. throne.tscn (Track 2 ships) won't
## override the `kind` export, so the engine would clobber any _init
## write back to the base default (&""). The _ready setter is the
## canonical fix; _init is kept so Throne.new() headless construction
## (no scene) also reports the right kind — useful for tests.
class_name Throne


## Canonical kind StringName. Matches the BalanceData lookup key
## (`buildings.throne` in balance.tres; existing entry at balance.tres:213
## with max_hp=2000).
const KIND_THRONE: StringName = &"throne"

## SceneTree group name for Throne lookup. ResourceSystem.dropoff_for_team
## iterates this group filtered by team to find a worker's deposit target.
const THRONES_GROUP: StringName = &"thrones"

## Opaque FogSystem handle. -1 = not registered.
var _fog_handle: int = -1

## Latch to ensure throne_destroyed signal emits exactly once per Throne.
## Mirrors HealthComponent's unit_health_zero latch pattern.
var _destruction_emitted: bool = false


# === Defensive fallback constants ===========================================
#
# Match prior-subclass pattern (Atashkadeh.cost_coin / etc.) — "config error
# doesn't break the live game" — when balance.tres is unreachable or the
# bldg_throne entry is missing, the building still functions with reasonable
# defaults rather than zero-valued degenerate behavior.
#
# Per 01_CORE_MECHANICS.md §5 (Throne row): "Capital. Loss = defeat. Spawns
# workers." Spec doesn't give numeric HP; lead defers to balance-engineer
# at balance.tres:215 = max_hp 2000.

## Fallback Throne max_hp if BalanceData unreachable. 2000 matches
## balance.tres:215 bldg_throne.max_hp.
const _FALLBACK_MAX_HP: float = 2000.0


# === Lifecycle hooks =========================================================

func _init() -> void:
	kind = KIND_THRONE


func _ready() -> void:
	# Dual-init pattern (see header). Scene-instantiation order resets
	# @export defaults between _init and _ready; we re-write kind here so
	# the base class's _ready (which reads kind via the unit_id assignment +
	# group-join logic in building.gd) sees the right value.
	kind = KIND_THRONE
	super._ready()
	# Throne is OPERATIONALLY READY at spawn time — no construction dwell.
	# Match-start spawns it via main.gd:_spawn_starting_buildings which
	# directly add_child's into the world (no UnitState_Constructing flow).
	# We mark is_complete = true here so the production_state_changed /
	# is_complete gates in the base class treat the Throne as a ready
	# building from tick 0. Workers depositing at a freshly-spawned Throne
	# must work; can't wait for placement-flow construction.
	is_complete = true
	# Join the Thrones group so ResourceSystem.dropoff_for_team can find
	# this instance. Group membership is the canonical lookup channel for
	# buildings (mirror C1.2 anti-misuse: do NOT use SpatialIndex — that
	# tracks UNITS via SpatialAgentComponent).
	add_to_group(THRONES_GROUP)
	# §9.M6 — log the spawn so live-test can verify match-start spawn fires
	# both Thrones at expected positions.
	print("[throne] _ready team=%d position=%s unit_id=%d max_hp_target=%.1f" % [
		team, str(global_position), unit_id, _resolve_max_hp()])
	# Initialize HealthComponent if present. Scene composition follows the
	# pattern of other buildings (building.tscn → HealthComponent child).
	# We read max_hp from BalanceData.buildings[&"throne"].max_hp (canonical
	# Dictionary lookup per BUG-C1 fix-wave learning; NOT bldg_<kind>).
	_init_health_from_balance_data()
	# Register FogSystem vision source. Mirror of Atashkadeh / Sarbaz-khaneh
	# pattern. is_static = true (Throne never moves); sight = 4 cells per
	# FogConfig.sight_throne_cells (forward-compat schema from 3A.0; Throne
	# is FIRST runtime consumer per §9.H3).
	_register_fog_vision_source()


func _exit_tree() -> void:
	# Symmetric with _ready: deregister fog vision source so freed Throne
	# doesn't leave a dangling registry entry. Base building.gd:_exit_tree
	# disconnects sim_phase; we extend with fog deregister.
	super._exit_tree()
	if _fog_handle >= 0:
		var fog: Node = _autoload_or_null(&"FogSystem")
		if fog != null and fog.has_method(&"deregister_vision_source"):
			fog.call(&"deregister_vision_source", _fog_handle)
		_fog_handle = -1


# === IDropoffTarget protocol — RNC §5.2 canonical ============================
#
# These two methods are the duck-typed IDropoffTarget surface. Anything that
# queries `node.has_method(&"deposit")` finds them. RNC §5.2 prescribes the
# exact signatures; deviation breaks the worker-Returning-state routing.
#
# Mirror C1.1: lead's brief v1.0.0 invented `is_dropoff_target_for` /
# `get_dropoff_position` — those are NOT the canonical names. RNC §5.2 names
# are `deposit` and `get_deposit_position`. v1.0.2 corrects this. §9.L10
# applied: this file uses RNC §5.2 names verbatim.


## Implements IDropoffTarget — see RESOURCE_NODE_CONTRACT.md §5.
##
## Performs the canonical resource-deposit chokepoint call internally.
## `amount` is already-x100 fixed-point (UnitState_Returning passes the
## worker's `_carry_amount_x100` directly per the existing convention at
## unit_state_returning.gd:235 — `change_resource(team, kind, amount_x100,
## reason, ctx)`). The Throne does NOT re-multiply by 100.
##
## Mirror C1.4 disambiguation: ONLY ONE path calls change_resource per
## deposit cycle. When this method fires (Throne-exists path),
## UnitState_Returning's inline change_resource at line 235 MUST be
## skipped. The fallback path (Throne absent) preserves the inline call.
##
## Pre-condition: caller (UnitState_Returning) is inside the unit's
## _sim_tick path — on-tick by construction (Sim Contract §1.3).
func deposit(resource_kind: StringName, amount: int, worker: Unit) -> void:
	if amount <= 0:
		# Zero/negative deposit is a no-op — same defensive shape as
		# Returning's existing skip-empty-carry guard.
		return
	var worker_id: int = -1
	if worker != null and is_instance_valid(worker):
		worker_id = worker.unit_id
	# §9.M6 log BEFORE the chokepoint call so failures (e.g., off-tick
	# assertion crash) are still visible in the log scroll.
	print("[throne] deposit_received from=%d kind=%s amount_x100=%d team=%d" % [
		worker_id, str(resource_kind), amount, team])
	# Canonical chokepoint call. Signature per ResourceSystem.change_resource:
	#   (team: int, kind: StringName, amount_x100: int, reason: StringName,
	#    source_unit: Object) -> void
	ResourceSystem.change_resource(
		team, resource_kind, amount, &"gather_deposit", worker)


## Implements IDropoffTarget — see RESOURCE_NODE_CONTRACT.md §5.
##
## Returns the world position the worker should walk to BEFORE depositing.
## For MVP we use the building's global_position with a small Y nudge so
## the worker visually arrives at the Throne's footprint center. Future
## refinement (Phase 4 polish): a $DepositMarker child Node3D for the
## throne-room geometry.
##
## Returning state reads this in its enter() to set the walk-back target.
func get_deposit_position() -> Vector3:
	return global_position + Vector3(0.0, 0.5, 0.0)


# === Damage / destruction signal ============================================
#
# Per brief §4 Track 1 + §1 forward-compat seam: Throne emits
# EventBus.throne_destroyed(team_id) when its HealthComponent hits zero.
# Phase 8 win-screen consumer subscribes; this wave only emits.
#
# Wire-up shape: at _ready time, find the HealthComponent child and
# connect to its unit_health_zero signal. The signal payload is the
# unit_id (Throne's building unit_id, distinct from Unit ids).


func _init_health_from_balance_data() -> void:
	# Subscribe to unit_health_zero UNCONDITIONALLY — Throne's filter
	# BUG-G1 fix (architecture-reviewer 2026-05-24): subscribe to the LOCAL
	# HealthComponent.health_zero signal, NOT the global
	# EventBus.unit_health_zero channel. Buildings and Units have SEPARATE
	# unit_id counters that collide in the same int space (Iran Throne
	# unit_id=1 collides with Kargar #1 unit_id=1). The Unit-side
	# global-filter pattern at state_machine.gd:_on_unit_health_zero is
	# safe WITHIN the Unit namespace because all Units share one counter;
	# Buildings cannot safely use the same global channel.
	#
	# Consequence: if no HealthComponent is present on this scene yet,
	# the Throne CANNOT be destroyed in this run and throne_destroyed will
	# never fire. Phase 8 will add HealthComponent to throne.tscn alongside
	# the win-screen consumer. Until then, the seam is documented but
	# inert — explicitly and safely.
	var hc: Node = get_node_or_null(^"HealthComponent")
	if hc == null:
		print("[throne]   no HealthComponent in scene — Throne cannot be "
			+ "destroyed in this run; throne_destroyed signal will not "
			+ "fire from this instance until Phase 8 adds HC to throne.tscn")
		return
	# HC exists — subscribe to its LOCAL health_zero signal. The local
	# signal cannot collide because we connect to OUR component's signal
	# directly; no global namespace involved.
	if hc.has_signal(&"health_zero"):
		if not hc.health_zero.is_connected(_on_health_zero):
			hc.health_zero.connect(_on_health_zero)
	else:
		# Defensive: HC exists but lacks the local signal (older HC version
		# or test mock). Log + bail; do NOT fall back to the global channel
		# because that's exactly the bug we're fixing.
		push_warning("Throne: HealthComponent present but missing health_zero "
			+ "signal — destruction signal will not fire. "
			+ "(Update HealthComponent to expose health_zero per BUG-G1.)")
		return
	# Initialize HC from BalanceData.
	var max_hp: float = _resolve_max_hp()
	if hc.has_method(&"init_max_hp"):
		hc.call(&"init_max_hp", max_hp)
	if hc.has_method(&"set"):
		hc.set(&"unit_id", unit_id)


func _on_health_zero(unit_id_in: int) -> void:
	# Local-signal subscription per BUG-G1: this handler can ONLY be reached
	# via our OWN HealthComponent.health_zero emit, so unit_id_in matches
	# self.unit_id by construction. The unit_id_in parameter is retained
	# for telemetry symmetry with the global signal shape.
	if _destruction_emitted:
		return
	_destruction_emitted = true
	# §9.M6 — log destruction so live-test can verify the signal fires
	# and the Phase 8 win-screen seam will receive it.
	print("[throne] destroyed team=%d unit_id=%d" % [team, unit_id])
	EventBus.throne_destroyed.emit(team)


# === Autoload + BalanceData helpers ==========================================
#
# Same canonical pattern as atashkadeh.gd:287 / sarbaz_khaneh.gd:224.
# Engine.has_singleton does NOT find GDScript autoloads (Pitfall #12).
# This is the project-canonical discovery pattern.


func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))


## Read max_hp from BalanceData.buildings[&"throne"].max_hp via the
## canonical Dictionary lookup (per BUG-C1 fix-wave learning;
## `building.gd:_read_bldg_stats_int` uses the same shape). Falls back to
## _FALLBACK_MAX_HP on any defensive failure.
func _resolve_max_hp() -> float:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		print("[throne]   max_hp fallback (no balance.tres)")
		return _FALLBACK_MAX_HP
	var bd: Resource = load(path)
	if bd == null:
		print("[throne]   max_hp fallback (balance.tres failed to load)")
		return _FALLBACK_MAX_HP
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		print("[throne]   max_hp fallback (buildings dict missing)")
		return _FALLBACK_MAX_HP
	var stats: Variant = (bldgs as Dictionary).get(KIND_THRONE, null)
	if stats == null or not (stats is Resource):
		print("[throne]   max_hp fallback (no bldg_throne entry)")
		return _FALLBACK_MAX_HP
	var v: Variant = (stats as Resource).get(&"max_hp")
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		print("[throne]   max_hp fallback (bldg_throne.max_hp not numeric)")
		return _FALLBACK_MAX_HP
	return float(v)


## Register a FogSystem vision source for this Throne. Sight = 4 cells per
## FogConfig.sight_throne_cells (forward-compat schema from Wave 3A.0;
## Throne is FIRST runtime consumer per §9.H3 first-exercise discipline).
func _register_fog_vision_source() -> void:
	var fog: Node = _autoload_or_null(&"FogSystem")
	if fog == null or not fog.has_method(&"register_vision_source"):
		return  # Test fixture without FogSystem autoload — no-op.
	var sight: int = _resolve_fog_sight_cells()
	_fog_handle = fog.call(&"register_vision_source", self, team, sight, true)


## Read sight_throne_cells from BalanceData.fog. Mirrors the pattern at
## sarbaz_khaneh.gd:_resolve_fog_sight_cells.
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
	var v: Variant = fog_cfg.get(&"sight_throne_cells")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0
