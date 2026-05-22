extends CanvasLayer
##
## BuildMenu — bottom-right HUD panel listing buildings the selected Kargar
## can construct.
##
## Phase 3 session 1 wave 1C deliverable 5. Per
## 02f_PHASE_3_KICKOFF.md §3 wave 1C.
##
## Visibility:
##   - Empty selection → menu hidden.
##   - Selection contains at least one Kargar → menu visible with one
##     button per available building.
##   - Selection contains no Kargar (combat units only) → menu hidden.
##     Sessoin 2's Sarbaz-khaneh production panel will be a SEPARATE
##     CanvasLayer; the build menu is worker-only.
##
## Building list:
##   - Khaneh (wave 1C session 1). Cost via `Khaneh.cost_coin()`.
##   - Mazra'eh (session 2 wave 1A late-add — enables wave-1A live-test
##     by exposing a UI path to instantiate the grain farm in-game).
##     Cost via `Mazraeh.cost_coin()`.
##
## Session 2+ extends the list to Ma'dan / Sarbaz-khaneh / Atashkadeh
## as those concrete Buildings ship. The button table here is the
## place to extend.
##
## Reads:
##   - EventBus.selection_changed (read-shaped) to know when to show /
##     hide. Connect in _ready, disconnect on tree exit.
##   - SelectionManager.selected_units for the current selection at
##     refresh time (the signal carries unit_ids; we resolve via
##     SelectionManager.selected_units which has the live Node refs).
##   - Khaneh.cost_coin() — static helper exposing the cost from
##     BalanceData for the button label.
##
## Writes:
##   - On button click: EventBus.build_placement_started(building_kind,
##     cost_coin_x100). The BuildPlacementHandler (deliverable 6)
##     subscribes and takes over input handling for the next click.
##
## Pitfall #4 awareness (re-entrant signal mutation): the button's
## pressed handler emits build_placement_started — a READ-shaped UI
## signal. We DO NOT call ResourceSystem.change_resource synchronously
## here. The actual Coin deduction happens at placement time in
## UnitState_Constructing's on-arrival step, not when the menu button
## is pressed. If a future preview-cost-reservation feature wants to
## visually deduct, route through call_deferred.
##
## Pitfall #1 awareness (mouse_filter on Control nodes) + BUG-08 fix:
## the Root Control uses MOUSE_FILTER_STOP — the entire menu surface
## is an input shield, so clicks within the menu's screen rect never
## fall through to _unhandled_input handlers (ClickHandler / BPH).
## Decorative children (Background, MarginContainer, VBoxContainer,
## HeaderLabel) use MOUSE_FILTER_PASS so clicks layer inward to the
## Button. Without Root=STOP, the PRESS edge of a click on the Button
## (Button.action_mode defaults to ACTION_MODE_BUTTON_RELEASE) leaks
## to ClickHandler's _unhandled_input + BPH's, triggering deselect-
## all-on-empty-terrain because BPH's _placement_kind is still &"" on
## PRESS (placement mode is only entered on RELEASE when the Button's
## pressed signal fires). Result before the fix: selection wiped
## before placement starts, menu hides itself (no Kargar selected),
## ghost orphaned. Lead-reported as BUG-08 at Phase 3 session 1 close.
##
## Sim Contract / lint compliance:
##   - i18n: every visible string flows through tr(). Strings:
##     UI_BUILD_MENU_HEADER, UI_BUILDING_KHANEH_COST,
##     UI_BUILDING_KHANEH_TOOLTIP, UI_BUILDING_MAZRAEH_COST,
##     UI_BUILDING_MAZRAEH_TOOLTIP, UI_BUILDING_MADAN_COST,
##     UI_BUILDING_MADAN_TOOLTIP, UI_BUILDING_SARBAZ_KHANEH_COST,
##     UI_BUILDING_SARBAZ_KHANEH_TOOLTIP, UI_BUILDING_ATASHKADEH_COST,
##     UI_BUILDING_ATASHKADEH_TOOLTIP, UI_BUILDING_SOWARI_KHANEH_COST,
##     UI_BUILDING_SOWARI_KHANEH_TOOLTIP, UI_BUILDING_TIRANDAZI_COST,
##     UI_BUILDING_TIRANDAZI_TOOLTIP.
##     The Persian column stays empty per Tier 2 schedule.
##   - No sim-state writes. UI reads only. The build_placement_started
##     emission is read-shaped (no consumer mutates sim state in the
##     handler — BuildPlacementHandler's handler is also UI-shaped;
##     state mutation happens at placement time, on-tick).
##   - No `apply_*` method names (L1 lint).

# === Layout / styling constants ============================================

const _PANEL_WIDTH: float = 200.0
const _PANEL_HEIGHT: float = 120.0

# Bottom-right anchor offset margins (matches resource_hud's MARGIN
# convention).
const _MARGIN_RIGHT: float = 16.0
const _MARGIN_BOTTOM: float = 16.0

# Background color — neutral dark with alpha so the world reads through.
# Same dark palette as SelectedUnitPanel for a coherent HUD look.
const _COLOR_BG: Color = Color(0.1, 0.1, 0.12, 0.75)

# Button color — earthy tan to subtly hint at the Khaneh's material.
const _COLOR_BUTTON_NORMAL: Color = Color(0.45, 0.38, 0.25)

# Button color — agricultural green for the Mazra'eh (related to the
# field placeholder color but darker so it reads against the dark HUD).
const _COLOR_BUTTON_MAZRAEH: Color = Color(0.45, 0.55, 0.30)

# Button color — stone/metal grey for the Ma'dan (related to the
# building scene's industrial-grey but darker so it reads against the
# dark HUD).
const _COLOR_BUTTON_MADAN: Color = Color(0.55, 0.55, 0.60)

# Button color — martial-red / oxidized-iron for the Sarbaz-khaneh
# (barracks). Reads as "military / armed force" without overpowering
# the dark HUD palette.
const _COLOR_BUTTON_SARBAZ_KHANEH: Color = Color(0.65, 0.30, 0.25)

# Button color — fire-amber / sacred-flame hue for the Atashkadeh.
# Warm gold-orange that reads as "kept flame" — distinct from
# Sarbaz-khaneh's blood-rust and the other three buildings' tints.
const _COLOR_BUTTON_ATASHKADEH: Color = Color(0.85, 0.65, 0.20)

# Button color — cavalry-blue-grey / saddle-leather hue for the
# Sowari-khaneh (cavalry stable). Mirrors the Iran-blue palette
# used on Savar unit meshes.
const _COLOR_BUTTON_SOWARI_KHANEH: Color = Color(0.35, 0.42, 0.55)

# Button color — arrow-fletch-brown / wood-shaft hue for the
# Tirandazi (archery training ground). Distinct from Sowari-khaneh's
# cavalry-blue-grey.
const _COLOR_BUTTON_TIRANDAZI: Color = Color(0.55, 0.42, 0.28)


# === Node refs =============================================================
# Resolved @onready against the build_menu.tscn structure.

@onready var _root: Control = $Root
@onready var _vbox: VBoxContainer = $Root/Margin/VBox
@onready var _header_label: Label = $Root/Margin/VBox/HeaderLabel
@onready var _khaneh_button: Button = $Root/Margin/VBox/KhanehButton
@onready var _mazraeh_button: Button = $Root/Margin/VBox/MazraehButton
@onready var _madan_button: Button = $Root/Margin/VBox/MadanButton
@onready var _sarbaz_khaneh_button: Button = $Root/Margin/VBox/SarbazKhanehButton
@onready var _atashkadeh_button: Button = $Root/Margin/VBox/AtashkadehButton
@onready var _sowari_khaneh_button: Button = $Root/Margin/VBox/SowariKhanehButton
@onready var _tirandazi_button: Button = $Root/Margin/VBox/TirandaziButton


# === Lifecycle =============================================================

func _ready() -> void:
	# Defensive: ensure the root starts hidden until a selection arrives.
	# The .tscn also sets visible = false on the Root, but the runtime
	# guard catches any future scene edit that flips it.
	_root.visible = false

	# Wire the Khaneh button. The button's `pressed` signal fires once
	# per click; we emit build_placement_started in the handler.
	if not _khaneh_button.pressed.is_connected(_on_khaneh_button_pressed):
		_khaneh_button.pressed.connect(_on_khaneh_button_pressed)
	if not _mazraeh_button.pressed.is_connected(_on_mazraeh_button_pressed):
		_mazraeh_button.pressed.connect(_on_mazraeh_button_pressed)
	if not _madan_button.pressed.is_connected(_on_madan_button_pressed):
		_madan_button.pressed.connect(_on_madan_button_pressed)
	if not _sarbaz_khaneh_button.pressed.is_connected(_on_sarbaz_khaneh_button_pressed):
		_sarbaz_khaneh_button.pressed.connect(_on_sarbaz_khaneh_button_pressed)
	if not _atashkadeh_button.pressed.is_connected(_on_atashkadeh_button_pressed):
		_atashkadeh_button.pressed.connect(_on_atashkadeh_button_pressed)
	if not _sowari_khaneh_button.pressed.is_connected(_on_sowari_khaneh_button_pressed):
		_sowari_khaneh_button.pressed.connect(_on_sowari_khaneh_button_pressed)
	if not _tirandazi_button.pressed.is_connected(_on_tirandazi_button_pressed):
		_tirandazi_button.pressed.connect(_on_tirandazi_button_pressed)

	# Subscribe to selection changes. Read-shaped signal; we only update
	# UI-local visibility / button text in the handler.
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)

	# Seed initial state from the current SelectionManager so the menu
	# state is coherent at boot (mirrors ResourceHUD._refresh_labels).
	_refresh_from_selection()


func _exit_tree() -> void:
	# Symmetric cleanup. Prevents ghost connections from prior instances
	# after scene teardown (mirrors ResourceHUD._exit_tree).
	if _khaneh_button != null \
			and _khaneh_button.pressed.is_connected(_on_khaneh_button_pressed):
		_khaneh_button.pressed.disconnect(_on_khaneh_button_pressed)
	if _mazraeh_button != null \
			and _mazraeh_button.pressed.is_connected(_on_mazraeh_button_pressed):
		_mazraeh_button.pressed.disconnect(_on_mazraeh_button_pressed)
	if _madan_button != null \
			and _madan_button.pressed.is_connected(_on_madan_button_pressed):
		_madan_button.pressed.disconnect(_on_madan_button_pressed)
	if _sarbaz_khaneh_button != null \
			and _sarbaz_khaneh_button.pressed.is_connected(_on_sarbaz_khaneh_button_pressed):
		_sarbaz_khaneh_button.pressed.disconnect(_on_sarbaz_khaneh_button_pressed)
	if _atashkadeh_button != null \
			and _atashkadeh_button.pressed.is_connected(_on_atashkadeh_button_pressed):
		_atashkadeh_button.pressed.disconnect(_on_atashkadeh_button_pressed)
	if _sowari_khaneh_button != null \
			and _sowari_khaneh_button.pressed.is_connected(_on_sowari_khaneh_button_pressed):
		_sowari_khaneh_button.pressed.disconnect(_on_sowari_khaneh_button_pressed)
	if _tirandazi_button != null \
			and _tirandazi_button.pressed.is_connected(_on_tirandazi_button_pressed):
		_tirandazi_button.pressed.disconnect(_on_tirandazi_button_pressed)
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


# === Selection handling ====================================================

# Read-shaped signal handler. The signal payload (selected_unit_ids)
# carries int ids; we route through SelectionManager.selected_units for
# the live Node refs which is what _refresh_from_selection inspects.
# Sim Contract §1.5 fit: handler reads sim state freely off-tick.
func _on_selection_changed(_selected_unit_ids: Array) -> void:
	_refresh_from_selection()


# Update the menu's visible state from the current selection. Visible if
# selection contains at least one Kargar; hidden otherwise.
#
# Button labels are refreshed here too (cost may change as the player's
# Coin balance changes — wave-1B's HUD reflects that; here we just show
# the static cost from BalanceData).
func _refresh_from_selection() -> void:
	var sel: Array = SelectionManager.selected_units
	var has_kargar: bool = false
	for u in sel:
		if u == null or not is_instance_valid(u):
			continue
		if _is_kargar_shaped(u):
			has_kargar = true
			break
	_root.visible = has_kargar
	if has_kargar:
		_refresh_button_labels()


# Refresh the button label text. tr() resolves UI_BUILDING_KHANEH_COST
# against strings.csv ("Khaneh (%d Coin)" — Persian name as primary label
# per shahnameh-loremaster review 2026-05-14; the canonical en-side
# convention is Persian-primary, English in tooltip if added). The cost
# is the static BalanceData value (Khaneh.cost_coin()); a future
# preview-affordability pass could grey the button when the player
# can't afford it.
func _refresh_button_labels() -> void:
	_header_label.text = tr("UI_BUILD_MENU_HEADER")
	# Khaneh / Mazra'eh / Ma'dan tooltips added Wave 2B fix-wave (BUG-B1).
	# The three older buildings were grandfathered without tooltips when
	# the tooltip pattern was introduced at Wave 2A (Sarbaz-khaneh). Live-
	# test surfaced the asymmetry. J3 literal-first framing per loremaster
	# discipline — Ma'dan especially is load-bearing ("ore-source /
	# generative place" NOT industrial-revolution "mine" baggage, per
	# madan.gd header lines ~25-32 + Pishdadian civilizational-invention
	# triad framing).
	var khaneh_cost: int = _KhanehScript.call(&"cost_coin")
	_khaneh_button.text = tr("UI_BUILDING_KHANEH_COST") % [khaneh_cost]
	# Drift-proof tooltip — substitute live population_capacity from
	# BalanceData rather than hardcoding the number. Matches the
	# Atashkadeh dual-cost dynamic-substitution pattern (Wave 2A.5) and
	# the cost-label %d pattern across all 7 buildings. §9.L6 read-from-
	# canonical-source applied at the UI surface: if balance-engineer
	# tunes bldg_khaneh.population_capacity, the tooltip updates
	# automatically without strings.csv or test edits.
	# Surfaced as fix-wave BUG-B1.5 after L1 spec-wins caught a spec-vs-
	# shipped divergence (spec said +5, shipped +10) at BUG-B1 time —
	# lesson is that hardcoded UI numbers are themselves a drift-vector.
	var khaneh_pop_cap: int = _KhanehScript.call(&"population_capacity")
	_khaneh_button.tooltip_text = tr("UI_BUILDING_KHANEH_TOOLTIP") % [khaneh_pop_cap]
	var mazraeh_cost: int = _MazraehScript.call(&"cost_coin")
	_mazraeh_button.text = tr("UI_BUILDING_MAZRAEH_COST") % [mazraeh_cost]
	_mazraeh_button.tooltip_text = tr("UI_BUILDING_MAZRAEH_TOOLTIP")
	var madan_cost: int = _MadanScript.call(&"cost_coin")
	_madan_button.text = tr("UI_BUILDING_MADAN_COST") % [madan_cost]
	_madan_button.tooltip_text = tr("UI_BUILDING_MADAN_TOOLTIP")
	var sarbaz_cost: int = _SarbazKhanehScript.call(&"cost_coin")
	_sarbaz_khaneh_button.text = tr("UI_BUILDING_SARBAZ_KHANEH_COST") % [sarbaz_cost]
	_sarbaz_khaneh_button.tooltip_text = tr("UI_BUILDING_SARBAZ_KHANEH_TOOLTIP")
	# Atashkadeh is the only Tier-1 building with a dual-resource cost
	# (01_CORE_MECHANICS.md §5: 150 coin, 50 grain). The label format
	# substitutes both static values from BalanceData via the cost_coin /
	# cost_grain static helpers — keeps the surface drift-proof if
	# balance-engineer tunes either cost.
	var atashkadeh_cost_coin: int = _AtashkadehScript.call(&"cost_coin")
	var atashkadeh_cost_grain: int = _AtashkadehScript.call(&"cost_grain")
	_atashkadeh_button.text = tr("UI_BUILDING_ATASHKADEH_COST") % [
			atashkadeh_cost_coin, atashkadeh_cost_grain]
	_atashkadeh_button.tooltip_text = tr("UI_BUILDING_ATASHKADEH_TOOLTIP")
	# Sowari-khaneh + Tirandazi — Wave 2B Tier-2 entry. Both coin-only
	# per spec §5 (200 coin / 175 coin, no grain component), so they
	# reuse the single-cost label format (Sarbaz-khaneh / Khaneh /
	# Mazra'eh / Ma'dan precedent). Loremaster J3 tooltip framing for
	# both honors the Persian-primary + literal-gloss convention from
	# Track 0; J4 (l) constraint applies to Tirandazi specifically
	# (no Arash naming — institutional-ordinary register only).
	var sowari_khaneh_cost: int = _SowariKhanehScript.call(&"cost_coin")
	_sowari_khaneh_button.text = tr("UI_BUILDING_SOWARI_KHANEH_COST") % [sowari_khaneh_cost]
	_sowari_khaneh_button.tooltip_text = tr("UI_BUILDING_SOWARI_KHANEH_TOOLTIP")
	var tirandazi_cost: int = _TirandaziScript.call(&"cost_coin")
	_tirandazi_button.text = tr("UI_BUILDING_TIRANDAZI_COST") % [tirandazi_cost]
	_tirandazi_button.tooltip_text = tr("UI_BUILDING_TIRANDAZI_TOOLTIP")


# === Button handler ========================================================

# Pitfall #4 awareness: emit a READ-shaped signal here; do NOT call
# ResourceSystem.change_resource synchronously. The cost is deducted at
# placement time in UnitState_Constructing's on-arrival step.
func _on_khaneh_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6 (whole-coin → coin_x100).
	var cost_x100: int = _KhanehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(_KhanehScript.KIND_KHANEH, cost_x100)


func _on_mazraeh_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6 (whole-coin → coin_x100).
	var cost_x100: int = _MazraehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(_MazraehScript.KIND_MAZRAEH, cost_x100)


func _on_madan_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6 (whole-coin → coin_x100).
	var cost_x100: int = _MadanScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(_MadanScript.KIND_MADAN, cost_x100)


func _on_sarbaz_khaneh_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6 (whole-coin → coin_x100).
	var cost_x100: int = _SarbazKhanehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(
			_SarbazKhanehScript.KIND_SARBAZ_KHANEH, cost_x100)


func _on_atashkadeh_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6 (whole-coin → coin_x100).
	# Note: build_placement_started's signal contract carries ONLY coin
	# cost (EventBus signal signature locked at coin-only). The 50-grain
	# cost is deducted at placement time inside UnitState_Constructing
	# (gp-sys's atashkadeh entry). UI shows both costs in the label, but
	# the dispatch signal carries one. Same UI vs sim-side separation as
	# every other button.
	var cost_x100: int = _AtashkadehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(
			_AtashkadehScript.KIND_ATASHKADEH, cost_x100)


func _on_sowari_khaneh_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6. Sowari-khaneh is coin-only
	# (no grain) per balance.tres bldg_sowari_khaneh (Wave 2B Track 3).
	var cost_x100: int = _SowariKhanehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(
			_SowariKhanehScript.KIND_SOWARI_KHANEH, cost_x100)


func _on_tirandazi_button_pressed() -> void:
	# x100 fixed-point per Sim Contract §1.6. Tirandazi is coin-only
	# (no grain) per balance.tres bldg_tirandazi (Wave 2B Track 3).
	var cost_x100: int = _TirandaziScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(
			_TirandaziScript.KIND_TIRANDAZI, cost_x100)


# === Duck-type helpers ====================================================

# Worker check: a Unit whose `unit_type` reads as &"kargar". Phase 3 only
# Kargar workers exist; when other build-capable units ship (Phase 4+),
# extend this to check a `can_build` capability field instead of a hard
# unit_type comparison. Same pattern as click_handler.gd::_is_worker_shaped.
func _is_kargar_shaped(n: Object) -> bool:
	if n == null:
		return false
	var ut: Variant = n.get(&"unit_type")
	if typeof(ut) != TYPE_STRING_NAME:
		return false
	return ut == &"kargar"


# Path-string preload of the Khaneh script to avoid the class_name
# registry race (Khaneh is class_name'd, but autoload-and-test parse
# order can still race — same defensive pattern as the rest of the
# codebase).
const _KhanehScript: Script = preload("res://scripts/world/buildings/khaneh.gd")
const _MazraehScript: Script = preload("res://scripts/world/buildings/mazraeh.gd")
const _MadanScript: Script = preload("res://scripts/world/buildings/madan.gd")
const _SarbazKhanehScript: Script = preload("res://scripts/world/buildings/sarbaz_khaneh.gd")
const _AtashkadehScript: Script = preload("res://scripts/world/buildings/atashkadeh.gd")
const _SowariKhanehScript: Script = preload("res://scripts/world/buildings/sowari_khaneh.gd")
const _TirandaziScript: Script = preload("res://scripts/world/buildings/tirandazi.gd")
