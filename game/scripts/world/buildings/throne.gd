extends "res://scripts/world/buildings/building.gd"
##
## Throne (تخت) — singular sovereignty-bearing institution. One per faction;
## the seat of kingship; the realm's terminal stake.
##
## Anchor-category: **sovereignty-bearing institution** (5th anchor-category,
## NEW at this wave; loremaster brief-time classification 2026-05-24 +
## docs/ANCHOR_CATEGORY_TAXONOMY.md v1.1.0 §1.5).
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
## ## Cultural note — Throne as the seat of kingship
##
## **Placeholder — to be replaced verbatim by loremaster's 4-part cultural-
## note prose at Commit 1.5 per Wave 2A.5 / 2B established pattern.**
##
## Reference framing (loremaster delivered 2026-05-24 brief-time review):
##   - Iran's Throne: Farr-legitimized theological kingship — the king's
##     just rule is materially expressed in the realm's prosperity. The
##     dehqan-Throne reciprocity (tribute flowing UP, prosperity flowing
##     DOWN) is the Shahnameh-attested economic-political relationship
##     the deposit-mechanic makes visible. Workers depositing at the
##     Throne is not just bookkeeping — it's the moment the farr-bearing
##     king's authority gains material expression.
##   - Turan's Throne: sworn-loyalty named-rulership (Afrasiyab's seat,
##     Piran's hospitality of Siavush). DIFFERENT cultural register
##     (kingship by oath-to-named-ruler rather than by farr-legitimization),
##     SAME anchor-shape (singular seat, terminal-stakes, deposit-target).
##   - **First cross-faction-symmetric anchor-category** — opposite of the
##     structural-mismatch pattern of the four prior anchor-categories
##     (civic-anchor / resource-producing / labor-organization /
##     sacral-emitter / identity-bearing-institutional). The Throne is
##     where Iran and Turan share the institutional SHAPE while differing
##     in cultural register.
##
## See `docs/ANCHOR_CATEGORY_TAXONOMY.md` v1.1.0 §1.5 for the formal
## category definition + sub-slot tier-progression axis (Throne →
## Qal'eh → Royal Court).
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
	# (_on_health_zero checks unit_id) ensures we only react to OUR
	# destruction. Subscription must happen even when HealthComponent
	# is absent in the scene (Phase 8 will add it; for now, tests +
	# future production paths drive unit_health_zero directly when
	# damage lands). Mirrors Unit's death-preempt pattern at
	# state_machine.gd:_on_unit_health_zero — every Unit listens
	# globally + filters by id, even before its HealthComponent fires.
	if not EventBus.unit_health_zero.is_connected(_on_health_zero):
		EventBus.unit_health_zero.connect(_on_health_zero)
	# If a HealthComponent IS present (forward-compat — Phase 8 + scene
	# refinement), initialize it from BalanceData.
	var hc: Node = get_node_or_null(^"HealthComponent")
	if hc == null:
		print("[throne]   no HealthComponent in scene — destruction signal "
			+ "still wired via unit_health_zero subscription")
		return
	var max_hp: float = _resolve_max_hp()
	if hc.has_method(&"init_max_hp"):
		hc.call(&"init_max_hp", max_hp)
	if hc.has_method(&"set"):
		hc.set(&"unit_id", unit_id)


func _on_health_zero(unit_id_in: int) -> void:
	# This subscription is global (every Throne listens to every
	# unit_health_zero). Filter to OUR unit_id before reacting.
	if unit_id_in != unit_id:
		return
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
