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
## Building list (Phase 3 session 1 wave 1C):
##   - Khaneh (the only building this session). Cost surfaced via
##     `Khaneh.cost_coin()`.
##
## Session 2+ extends the list to Mazra'eh / Ma'dan / Sarbaz-khaneh /
## Atashkadeh as those concrete Buildings ship. The button table here
## is the place to extend.
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
## Pitfall #1 awareness (mouse_filter on Control nodes): every
## decorative Control (MarginContainer, VBoxContainer, the menu label)
## uses MOUSE_FILTER_PASS so background clicks fall through to the
## world (the menu doesn't eat clicks in its rect when it's hidden —
## visibility = false on the root Control is the primary defense, but
## belt-and-braces). Only the actual Button uses MOUSE_FILTER_STOP so
## the button itself reliably catches the click.
##
## Sim Contract / lint compliance:
##   - i18n: every visible string flows through tr(). Strings:
##     UI_BUILD_MENU_HEADER, UI_BUILDING_KHANEH_COST. The Persian
##     column stays empty per Tier 2 schedule.
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


# === Node refs =============================================================
# Resolved @onready against the build_menu.tscn structure.

@onready var _root: Control = $Root
@onready var _vbox: VBoxContainer = $Root/Margin/VBox
@onready var _header_label: Label = $Root/Margin/VBox/HeaderLabel
@onready var _khaneh_button: Button = $Root/Margin/VBox/KhanehButton


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
# against strings.csv ("House (%d Coin)"). The cost is the static
# BalanceData value (Khaneh.cost_coin()); a future preview-affordability
# pass could grey the button when the player can't afford it.
func _refresh_button_labels() -> void:
	_header_label.text = tr("UI_BUILD_MENU_HEADER")
	var cost: int = _KhanehScript.call(&"cost_coin")
	_khaneh_button.text = tr("UI_BUILDING_KHANEH_COST") % [cost]


# === Button handler ========================================================

# Pitfall #4 awareness: emit a READ-shaped signal here; do NOT call
# ResourceSystem.change_resource synchronously. The cost is deducted at
# placement time in UnitState_Constructing's on-arrival step.
func _on_khaneh_button_pressed() -> void:
	var cost_x100: int = _KhanehScript.call(&"cost_coin") * 100
	EventBus.build_placement_started.emit(_KhanehScript.KIND_KHANEH, cost_x100)


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
