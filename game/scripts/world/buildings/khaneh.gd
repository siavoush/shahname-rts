extends "res://scripts/world/buildings/building.gd"
##
## Khaneh (خانه) — Iran "house" building. Contributes to population_cap.
##
## Source: 01_CORE_MECHANICS.md §5 (Iran buildings list):
##     "Khaneh (house) — Population cap +5 per building. 50 coin. Low HP —
##      not a combat building."
##
## Phase 3 session 1 wave 1C (02f_PHASE_3_KICKOFF.md §3) ships Khaneh as
## the first concrete Building subclass — the smoke-test target for the
## placement state machine. Its post-placement side-effect is a
## population_cap bump on the owning team.
##
## Cultural note: in the Shahnameh, the home (خانه / khaneh) is the
## anchoring symbol of settled life — the persistence of family and
## hearth that anchors the Iranian dynasties' relationship to land and
## people (distinct from, but not morally above, Turan's mobile
## counterpart per 00_SHAHNAMEH_RESEARCH.md §7 "worthy rivals"). The
## population-cap mechanic is the gameplay surfacing of that idea: more
## homes, more households, more capacity to draw soldiers from a
## settled people. Mirrors how Iran's epic dynasties define themselves
## through what they BUILD — Jamshid's tools, Fereydun's halls, Kavus's
## flying-throne folly all staged against the backdrop of an Iran that
## organizes around its civic anchors. Turan's dignity comes from a
## different anchor (mobility, the Khan's tent, the loyalty of the
## *otaq*) — to be parameterized when Turan housing ships per the
## cross-faction caveat in building.gd.
##
## What lives here vs in the base class:
##   - kind = &"khaneh" (dual-init pattern — see _init / _ready below).
##   - Cost lookup (cost_coin_x100 from BalanceData) for the build menu.
##   - _on_placement_complete: bump ResourceSystem.population_cap +
##     emit EventBus.building_placed for telemetry / future UI.
## Base Building owns the schema, the place_at seam, the &"buildings"
## group join, the unit_id counter.
##
## Visual placeholder per CLAUDE.md "colored rectangles for buildings":
##   - BoxMesh ~2.0 × 1.2 × 2.0 (matches the base template size; Khaneh
##     is the smallest building so the base footprint serves directly).
##   - Earthy tan/sandy color `Color(0.78, 0.65, 0.45)` — Persian-village
##     mud-brick tone. Per Phase 3 session 1 wave 1C kickoff §3:
##     "earthy Persian-village tone, distinct from kargar sandy-brown."
##     The Kargar's color is `(0.65, 0.5, 0.3)` — Khaneh is brighter
##     and a touch warmer, so a worker standing next to a Khaneh reads
##     as a distinct silhouette.
##
## Why extend by path-string (not class_name):
##   Same class_name registry race that bites Unit / Kargar /
##   ResourceNode. Path-string extends sidesteps the race entirely.
##
## Why _init AND _ready set kind:
##   Per kargar.gd's header — scene-instantiation order in Godot 4
##   resets @export defaults from the .tscn definition BETWEEN _init
##   and _ready. khaneh.tscn doesn't override the `kind` export, so
##   the engine would clobber any _init write back to the base default
##   (&""). The _ready setter is the canonical fix; _init is kept so
##   `Khaneh.new()` headless construction (no scene) also reports the
##   right kind — useful for tests.
class_name Khaneh


## Canonical kind StringName for the Khaneh class. Matches the
## BalanceData lookup key (`buildings.khaneh` in balance.tres).
const KIND_KHANEH: StringName = &"khaneh"


func _init() -> void:
	kind = KIND_KHANEH


func _ready() -> void:
	# Set kind BEFORE the base class _ready reads it (the base class
	# doesn't read kind directly, but symmetry with kargar.gd's pattern
	# guards against future refactors where the base might use kind in
	# its _ready logic — say for a balance-data lookup like
	# Unit._apply_balance_data_defaults).
	kind = KIND_KHANEH
	super._ready()


# === Placement side-effect ===================================================
#
# Called from inside place_at after the base class has set
# global_position, team, and is_complete = true. The Khaneh's job at
# this seam is twofold:
#   1. Bump the owning team's population_cap by `population_capacity`
#      (read from BalanceData.buildings.khaneh).
#   2. Emit EventBus.building_placed so telemetry / UI / future AI
#      consumers see the placement.
#
# Sanctioned-write context: this method is called from place_at, which
# itself is called from UnitState_Constructing._sim_tick (the worker's
# _sim_tick). On-tick discipline holds by construction — same shape as
# ResourceNode.complete_extract calling _on_depleted from inside its
# tick path.
#
# Why ResourceSystem.change_population_cap (and not a direct write):
#   CLAUDE.md mandates the chokepoint pattern for resources. Wave 1B's
#   ResourceSystem ships `change_population_cap(team, delta, reason,
#   source_unit)` precisely for this use case — the wave-1B doc strings
#   call out Khaneh as the first consumer.
func _on_placement_complete(placer_unit_id: int) -> void:
	# Resolve population_capacity from BalanceData. Defensive: if
	# BalanceData isn't on disk (tests with no balance.tres), fall back
	# to 0 — the placement still succeeds (the building still exists)
	# but the cap doesn't move. That keeps the test surface honest:
	# a missing BalanceData is a configuration error, not a placement-
	# breaking exception.
	var pop_cap_delta: int = _resolve_population_capacity()
	if pop_cap_delta > 0:
		ResourceSystem.change_population_cap(
			team, pop_cap_delta, &"khaneh_placed", self)
	# Emit the placement signal regardless of cap delta — a Khaneh with
	# population_capacity=0 in BalanceData would be a config bug, not a
	# reason to suppress telemetry.
	EventBus.building_placed.emit(
		placer_unit_id, kind, team, global_position)


# Read population_capacity from balance.tres. Same defensive pattern as
# Unit._apply_balance_data_defaults — missing file / missing entry /
# wrong type all fall through to a 0 default.
func _resolve_population_capacity() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(kind, null)
	if stats == null:
		return 0
	var cap_v: Variant = stats.get(&"population_capacity")
	if typeof(cap_v) != TYPE_INT and typeof(cap_v) != TYPE_FLOAT:
		return 0
	return int(cap_v)


## Read the Khaneh's coin cost from BalanceData (in whole coin, not
## fixed-point). Used by the build menu to display the price next to
## the button. Same defensive fall-through as _resolve_population_capacity.
##
## Returns 0 when BalanceData / the entry / the field is missing — same
## "config error doesn't break the UI" pattern. The build menu sees
## "0 Coin" and the lead immediately notices something is wrong.
##
## Static-side-only helper — exposed as a class function (Khaneh.cost_coin())
## so the build menu can read the cost without instantiating a Khaneh
## scene just to inspect a number. Kargar / unit-stats have a similar
## pattern (UnitStats lookup via BalanceData) but at the call site,
## not via a helper.
static func cost_coin() -> int:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return 0
	var bd: Resource = load(path)
	if bd == null:
		return 0
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return 0
	var stats: Variant = (bldgs as Dictionary).get(KIND_KHANEH, null)
	if stats == null:
		return 0
	var coin_v: Variant = stats.get(&"coin_cost")
	if typeof(coin_v) != TYPE_INT and typeof(coin_v) != TYPE_FLOAT:
		return 0
	return int(coin_v)
