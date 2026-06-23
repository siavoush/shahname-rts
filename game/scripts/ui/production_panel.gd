extends CanvasLayer
class_name ProductionPanel
##
## ProductionPanel — modal-ish floating panel for unit-training UI.
##
## Wave 3A.6 Track 2 (ui-developer-p3s3). Per
## 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 2.
##
## Opens when the player left-clicks an owned producer building (Sarbaz-
## khaneh, Sowari-khaneh, Tirandazi at MVP — any building with a non-empty
## `produces` field). Routing happens in click_handler.gd's
## process_left_click_hit — owned-producer-building hits open this panel
## instead of triggering deselect_all.
##
## Lifecycle:
##   - Hidden by default (.tscn Root.visible = false).
##   - open(building: Node3D) — show panel, populate rows from
##     building.produces, subscribe to building.production_state_changed.
##   - close() — disconnect signals, hide panel, drop building ref.
##   - Auto-close on: Escape key, click outside panel rect, building freed.
##
## §9.L7 affordability sweep (mandatory per kickoff §3.3):
##   - Train buttons enabled = "have enough coin AND grain AND pop cap room
##     for one unit".
##   - Disabled = greyed + tooltip explaining which resource is short.
##   - Updates on EventBus.resource_changed.
##   - Click-time both-or-neither: building.request_train() returns bool;
##     panel doesn't deduct directly (sim-side handles it). If
##     request_train returns false (shouldn't happen for an affordable
##     button, but defensive), button stays enabled and panel logs the
##     reason.
##
## Reads (Sim Contract §1.5 — off-tick UI reads sanctioned):
##   - building.produces — Array[StringName] of producible unit kinds.
##   - building.kind — for header label lookup.
##   - building.team — for affordability + pop cap checks.
##   - building._production_state / _production_unit /
##     _production_progress_ticks / _production_total_ticks — for
##     in-progress UI (Track 1 surfaces).
##   - BalanceData.bldg_<kind>.train_<unit>_cost_coin / cost_grain /
##     dwell_ticks — for row labels + affordability math (Track 3 schema).
##   - ResourceSystem.coin_x100_for / grain_x100_for / population_for /
##     population_cap_for — for affordability sweep.
##   - EventBus.resource_changed (read-shaped) — triggers affordability
##     re-evaluation.
##
## Writes:
##   - building.request_train(unit_kind) — public API on Building (Track 1
##     surface). The signal-shaped UI emit; deduction happens sim-side.
##
## Pitfall #1 awareness (mouse_filter):
##   Root uses MOUSE_FILTER_STOP — click-shield. Decorative children PASS.
##   Train buttons inherit STOP (Button default). Same discipline as
##   build_menu (BUG-08 lesson).
##
## §9.L7 codified pattern (UI numbers from BalanceData via static helpers):
##   The cost/dwell labels substitute %d from BalanceData rather than
##   hardcoding. Drift-proof against balance-engineer tuning.
##
## §9.L8 fallback-by-failure-visibility-shape (session-6 retro codified):
##   Cost fallbacks are 0 (zero-cost button SCREAMS config error → lead
##   notices). Dwell-ticks fallback is small-but-nonzero (a 0-dwell train
##   would silently mean instant spawn, which players accept as plausible
##   → use MATCH-SHIPPED-equivalent fallback).
##
## Sim Contract / lint compliance:
##   - i18n: every visible string flows through tr().
##   - No sim-state writes from this script. UI reads + request_train call
##     (which IS sim-side write, but invoked through the building's public
##     API, not a re-shape).
##   - No `apply_*` method names (L1 lint).

# === Layout / styling constants ============================================

# Panel root anchored centre-top per .tscn; constants for runtime tuning.
const _COLOR_BG: Color = Color(0.1, 0.1, 0.12, 0.85)
const _COLOR_DISABLED_TINT: Color = Color(0.5, 0.5, 0.5, 0.6)

# Affordability error message colour — soft red for tooltip explanation.
const _COLOR_AFFORDABILITY_WARNING: Color = Color(0.85, 0.45, 0.45)

# Pop-cap "one unit slot" requirement. All unit types occupy 1 slot at MVP;
# future heavier units (Atashbordar? Pahlevan?) may occupy more — when that
# ships, swap this for a per-unit-kind lookup from BalanceData.
const _POPULATION_PER_UNIT: int = 1


# === Node refs =============================================================

@onready var _root: Control = $Root
@onready var _header_label: Label = $Root/Margin/VBox/HeaderLabel
@onready var _unit_rows: VBoxContainer = $Root/Margin/VBox/UnitRows
@onready var _close_hint: Label = $Root/Margin/VBox/CloseHint


# === State =================================================================

# The producer building this panel currently represents. null when closed.
# We hold a weak-by-design Node ref: building freed → next _process tick
# detects via is_instance_valid and auto-closes.
var _building: Node3D = null

# Map of unit_kind (StringName) → HBoxContainer for that row, so we can
# rebuild the row's contents (button↔progress-bar swap) on
# production_state_changed without rebuilding the whole panel.
var _unit_rows_by_kind: Dictionary = {}


# === Lifecycle =============================================================

func _ready() -> void:
	# Defensive: ensure hidden at boot (mirrors build_menu._ready).
	_root.visible = false
	# Join the &"production_panel" group so click_handler.gd can locate
	# this CanvasLayer via SceneTree.get_nodes_in_group without a
	# hardcoded scene path. Mirrors how Building joins &"buildings".
	add_to_group(&"production_panel")
	# Subscribe to resource_changed for affordability sweep. The handler
	# updates button enabled state across all open rows.
	if not EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.connect(_on_resource_changed)


func _exit_tree() -> void:
	# Symmetric cleanup. Disconnect resource_changed + any building-bound
	# signal connections.
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)
	_disconnect_building_signals()


# Per-frame poll for building-validity. If the building gets queue_freed
# (destroyed mid-production), auto-close. Cheap when closed (early return);
# only inspects the ref when open.
func _process(_dt: float) -> void:
	if not _root.visible:
		return
	if _building == null or not is_instance_valid(_building):
		close()
		return


# Esc key + outside-click close. _unhandled_input fires AFTER UI controls
# (which consume their own input via mouse_filter STOP), so a click that
# lands here MUST have hit terrain or empty space → close the panel.
func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Click outside the panel rect → close. The Root.mouse_filter
			# = STOP means inside-panel clicks are absorbed by Root and
			# never reach _unhandled_input. So any click reaching here is
			# an outside-click.
			close()
			# Do NOT set_input_as_handled — the click should still
			# propagate to ClickHandler so terrain-clicks deselect or
			# move (existing behavior). The panel-close is a side-effect
			# of the click, not a consumption of it.


# === Public API ============================================================

## Open the panel for a producer building. Populates rows from
## building.produces, subscribes to production_state_changed for in-flight
## training, makes panel visible.
##
## Called by click_handler.gd::process_left_click_hit when an owned-
## producer-building collider is hit. Idempotent — calling open() with
## the same building twice is a no-op; calling with a different building
## first close()s the prior.
func open(building: Node3D) -> void:
	if building == null or not is_instance_valid(building):
		return
	if _building == building:
		# Already open for this building — defensive no-op.
		return
	# Switching buildings: close the prior first.
	if _building != null:
		close()
	_building = building
	_connect_building_signals()
	_rebuild_unit_rows()
	_refresh_header()
	_refresh_affordability()
	_root.visible = true


## Close the panel. Disconnects building-bound signals, clears rows, hides.
## Safe to call when already closed (idempotent).
func close() -> void:
	_disconnect_building_signals()
	_clear_unit_rows()
	_building = null
	_root.visible = false


## Public accessor — currently-open building, or null if closed.
## Used by tests to assert open/close behavior without poking _building.
func current_building() -> Node3D:
	if _building != null and not is_instance_valid(_building):
		return null
	return _building


# === Building signal wiring ================================================

func _connect_building_signals() -> void:
	if _building == null or not is_instance_valid(_building):
		return
	if not _building.has_signal(&"production_state_changed"):
		# Track 1 contract surface not present — building isn't a producer
		# OR is on an older codepath. Defensive: don't crash, just skip
		# the connect; panel will show static rows without in-progress
		# updates.
		return
	if not _building.production_state_changed.is_connected(_on_production_state_changed):
		_building.production_state_changed.connect(_on_production_state_changed)


func _disconnect_building_signals() -> void:
	if _building == null or not is_instance_valid(_building):
		return
	if not _building.has_signal(&"production_state_changed"):
		return
	if _building.production_state_changed.is_connected(_on_production_state_changed):
		_building.production_state_changed.disconnect(_on_production_state_changed)


# === Row construction ======================================================

# Build one HBoxContainer per `produces` entry in the building. Each row's
# children depend on whether THAT unit is currently being trained:
#   - idle: unit-name label + cost label + Train button.
#   - this-unit-training: unit-name label + ProgressBar + remaining-time
#     label.
#   - other-unit-training (when produces has 2+ entries; future Sowari-
#     khaneh): unit-name label + Train button DISABLED + "Building is busy"
#     tooltip.
func _rebuild_unit_rows() -> void:
	_clear_unit_rows()
	if _building == null or not is_instance_valid(_building):
		return
	var produces_v: Variant = _building.get(&"produces")
	if typeof(produces_v) != TYPE_ARRAY:
		return
	for unit_kind_v in (produces_v as Array):
		var unit_kind: StringName = StringName(unit_kind_v)
		var row: HBoxContainer = _create_unit_row(unit_kind)
		_unit_rows.add_child(row)
		_unit_rows_by_kind[unit_kind] = row


func _clear_unit_rows() -> void:
	_unit_rows_by_kind.clear()
	for child in _unit_rows.get_children():
		child.queue_free()


# Build one row's content. Reads cost from BalanceData via the building's
# kind and the target unit's kind, looks up the
# `bldg_<kind>.train_<unit>_cost_coin/grain` fields (Track 3 schema).
func _create_unit_row(unit_kind: StringName) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override(&"separation", 8)
	# Unit name label.
	var name_label: Label = Label.new()
	name_label.text = tr(_unit_label_tr_key(unit_kind))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	# Cost label.
	var cost_label: Label = Label.new()
	var coin_cost: int = _train_cost_coin(unit_kind)
	var grain_cost: int = _train_cost_grain(unit_kind)
	cost_label.text = _format_cost_label(coin_cost, grain_cost)
	cost_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(cost_label)
	# Train button — bound via Callable.bind(unit_kind) so the handler
	# knows which kind to train without inspecting button text.
	var train_btn: Button = Button.new()
	train_btn.text = tr("UI_PRODUCTION_TRAIN_BUTTON")
	train_btn.pressed.connect(_on_train_button_pressed.bind(unit_kind))
	row.add_child(train_btn)
	# Cache the button so affordability sweep can find it without
	# re-walking the row's children.
	row.set_meta(&"_train_button", train_btn)
	row.set_meta(&"_unit_kind", unit_kind)
	return row


# === Header / cost formatting ==============================================

func _refresh_header() -> void:
	if _building == null or not is_instance_valid(_building):
		return
	var kind_v: Variant = _building.get(&"kind")
	if typeof(kind_v) != TYPE_STRING_NAME and typeof(kind_v) != TYPE_STRING:
		_header_label.text = tr("UI_PRODUCTION_PANEL_TITLE")
		return
	var kind: StringName = StringName(kind_v)
	# Mirror build_menu key naming: UI_BUILDING_<KIND> in upper-snake.
	var name_key: String = "UI_BUILDING_" + _string_name_to_upper(kind)
	_header_label.text = tr(name_key)
	_close_hint.text = tr("UI_PRODUCTION_PANEL_CLOSE_HINT")


# Build the "(N Coin, M Grain)" or "(N Coin)" suffix. Mirrors build_menu's
# Atashkadeh dual-cost format pattern but inverts: production costs may
# have zero grain (Piyade/Kamandar) OR non-zero grain (Savar). Show grain
# only when nonzero.
func _format_cost_label(coin_cost: int, grain_cost: int) -> String:
	if grain_cost > 0:
		return tr("UI_PRODUCTION_COST_DUAL") % [coin_cost, grain_cost]
	return tr("UI_PRODUCTION_COST_COIN_ONLY") % [coin_cost]


# Convert a StringName (snake_case) to upper-snake for tr-key building.
# e.g., &"sarbaz_khaneh" → "SARBAZ_KHANEH".
func _string_name_to_upper(sn: StringName) -> String:
	return String(sn).to_upper()


# Build the unit-label tr-key for the given unit_kind. Mirrors build_menu
# UI_BUILDING_<KIND> shape but for units.
# e.g., &"piyade" → "UI_PRODUCTION_UNIT_PIYADE".
func _unit_label_tr_key(unit_kind: StringName) -> String:
	return "UI_PRODUCTION_UNIT_" + _string_name_to_upper(unit_kind)


# === BalanceData read helpers (§9.L7 drift-proof) ==========================

# Cost-coin lookup for the building+unit pair. Path:
#   BalanceData.buildings[building_kind].train_<unit_kind>_cost_coin
#
# Defensive fall-through to 0 per §9.L8 — a zero-cost train would
# visually scream "free unit, config error" → lead notices.
func _train_cost_coin(unit_kind: StringName) -> int:
	return _read_balance_int(unit_kind, "cost_coin", 0)


# Cost-grain lookup. Same defensive 0 fallback rationale as cost_coin.
func _train_cost_grain(unit_kind: StringName) -> int:
	return _read_balance_int(unit_kind, "cost_grain", 0)


# Dwell-ticks lookup. Fallback = 30 (1 second at 30Hz) — §9.L8
# MATCH-SHIPPED-EQUIVALENT semantics: a 0-dwell train would silently
# spawn the unit instantly, which the player would accept as plausible
# (no visible bug). A 1-second fallback is small enough to ship a unit
# quickly in degraded-config states but obvious-enough that something is
# off (1 second is faster than any tuned value will be).
func _train_dwell_ticks(unit_kind: StringName) -> int:
	return _read_balance_int(unit_kind, "dwell_ticks", 30)


# Shared BalanceData reader. Same defensive cascade pattern as
# Khaneh.cost_coin() / Atashkadeh.cost_grain() — every missing layer
# falls through to `fallback`.
func _read_balance_int(unit_kind: StringName, field_suffix: String, fallback: int) -> int:
	if _building == null or not is_instance_valid(_building):
		return fallback
	var building_kind_v: Variant = _building.get(&"kind")
	if typeof(building_kind_v) != TYPE_STRING_NAME and typeof(building_kind_v) != TYPE_STRING:
		return fallback
	var building_kind: StringName = StringName(building_kind_v)
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return fallback
	var bd: Resource = load(path)
	if bd == null:
		return fallback
	var bldgs: Variant = bd.get(&"buildings")
	if typeof(bldgs) != TYPE_DICTIONARY:
		return fallback
	var stats: Variant = (bldgs as Dictionary).get(building_kind, null)
	if stats == null:
		return fallback
	# Field name: "train_<unit_kind>_<field_suffix>".
	# e.g., "train_piyade_cost_coin", "train_savar_cost_grain",
	# "train_kamandar_dwell_ticks". Naming convention locked at kickoff §3.4.
	var field_name: StringName = StringName(
			"train_" + String(unit_kind) + "_" + field_suffix)
	var v: Variant = stats.get(field_name)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return fallback
	return int(v)


# === Affordability sweep (§9.L7 mandate) ===================================

# Re-evaluate every row's Train button enabled-state based on current
# coin/grain/pop-cap balance. Mirrors build_menu's affordability sweep
# pattern from BUG-B2 fix-wave.
func _refresh_affordability() -> void:
	if _building == null or not is_instance_valid(_building):
		return
	var team_v: Variant = _building.get(&"team")
	if typeof(team_v) != TYPE_INT:
		return
	var team: int = int(team_v)
	var coin_have_x100: int = ResourceSystem.coin_x100_for(team)
	var grain_have_x100: int = ResourceSystem.grain_x100_for(team)
	var pop_used: int = ResourceSystem.population_for(team)
	var pop_cap: int = ResourceSystem.population_cap_for(team)
	# Also factor in: if the building is currently training, ALL buttons
	# disable (one slot per building at MVP).
	var production_state_v: Variant = _building.get(&"_production_state")
	var is_busy: bool = false
	if typeof(production_state_v) == TYPE_STRING_NAME or typeof(production_state_v) == TYPE_STRING:
		is_busy = StringName(production_state_v) != &"idle"
	for row in _unit_rows.get_children():
		_refresh_row_affordability(row, coin_have_x100, grain_have_x100, pop_used, pop_cap, is_busy)


# Per-row affordability check. Updates button.disabled + tooltip_text.
# Click-time both-or-neither is enforced inside building.request_train
# (Track 1 contract surface); this method is the pre-emptive-grey-out for
# the UI surface.
func _refresh_row_affordability(
		row: HBoxContainer,
		coin_have_x100: int,
		grain_have_x100: int,
		pop_used: int,
		pop_cap: int,
		is_busy: bool
) -> void:
	var unit_kind: StringName = row.get_meta(&"_unit_kind", &"")
	var btn_v: Variant = row.get_meta(&"_train_button", null)
	if btn_v == null:
		return
	var btn: Button = btn_v
	# If the building is currently training (any unit), disable.
	if is_busy:
		btn.disabled = true
		btn.tooltip_text = tr("UI_PRODUCTION_BUSY_TOOLTIP")
		return
	# Otherwise: check coin + grain + pop cap.
	var coin_cost: int = _train_cost_coin(unit_kind)
	var grain_cost: int = _train_cost_grain(unit_kind)
	var coin_cost_x100: int = coin_cost * 100
	var grain_cost_x100: int = grain_cost * 100
	var pop_needed: int = pop_used + _POPULATION_PER_UNIT
	# Both-or-neither pre-check: enable iff ALL three resources are
	# available. Single-resource shortage → disabled + specific tooltip.
	if coin_have_x100 < coin_cost_x100:
		btn.disabled = true
		btn.tooltip_text = tr("UI_PRODUCTION_INSUFFICIENT_COIN") % [coin_cost]
		return
	if grain_have_x100 < grain_cost_x100:
		btn.disabled = true
		btn.tooltip_text = tr("UI_PRODUCTION_INSUFFICIENT_GRAIN") % [grain_cost]
		return
	if pop_needed > pop_cap:
		btn.disabled = true
		btn.tooltip_text = tr("UI_PRODUCTION_POP_CAP_FULL") % [pop_used, pop_cap]
		return
	# All gates pass — enable.
	btn.disabled = false
	btn.tooltip_text = ""


# === Signal handlers =======================================================

# ResourceSystem-side change → re-sweep affordability. team filter: only
# re-sweep when the change is for the currently-open building's team
# (other team's resource changes don't affect this panel).
func _on_resource_changed(team: int, _kind: StringName, _delta_x100: int, _new_total_x100: int) -> void:
	if not _root.visible:
		return
	if _building == null or not is_instance_valid(_building):
		return
	var building_team_v: Variant = _building.get(&"team")
	if typeof(building_team_v) != TYPE_INT:
		return
	if int(building_team_v) != team:
		return
	_refresh_affordability()


# Building's production state changed → rebuild affected row OR sweep all.
# At MVP one unit produced per building (Sarbaz-khaneh: piyade only,
# Sowari-khaneh: savar only, Tirandazi: kamandar only), so any state
# change affects every row's busy-state. Cheap: just call
# _refresh_affordability + redraw progress.
func _on_production_state_changed(
		_building_id: int,
		_state: StringName,
		_unit_kind: StringName,
		_progress_fraction: float
) -> void:
	if _building == null or not is_instance_valid(_building):
		return
	_refresh_affordability()
	# Future: swap row UI to progress-bar shape when state == &"training"
	# AND this row's unit_kind matches _unit_kind. MVP: button stays in
	# place but disabled with "Building is busy" tooltip — minimum
	# viable surface to let player understand the building is working.


# Train button press → building.queue_train (off-tick-safe). The button fires
# off-tick; queue_train buffers the request and the building commits it +
# deducts on-tick (next &"movement" phase). Calling request_train directly here
# skipped the deduction off-tick = free units (playtest 2026-06-22). UI never
# deducts directly per Pitfall #4 + UI-shaped-signal discipline.
func _on_train_button_pressed(unit_kind: StringName) -> void:
	if _building == null or not is_instance_valid(_building):
		return
	if not _building.has_method(&"queue_train"):
		# Track 1 contract surface not present — defensive log.
		push_warning(
				"ProductionPanel: building %s missing queue_train(); Track 1 not shipped?"
				% [_building])
		return
	var ok_v: Variant = _building.call(&"queue_train", unit_kind)
	if not (ok_v is bool and bool(ok_v)):
		# queue_train returned false on a cheap off-tick read — building
		# incomplete, already training, or a request is already queued
		# (building.gd:743-748). Authoritative affordability is re-checked
		# on-tick when _on_sim_phase commits via request_train, not here.
		# Re-sweep so the UI reflects the now-current state.
		_refresh_affordability()
