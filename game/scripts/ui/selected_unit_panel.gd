extends CanvasLayer
##
## SelectedUnitPanel — bottom-left HUD detail panel (Phase 1 session 2 wave 2B).
##
## Purpose: surface the player's current selection at a glance — what's
## selected, how healthy it is, what it can do. The minimum viable RTS
## "selected unit" widget.
##
## Per 02c_PHASE_1_SESSION_2_KICKOFF.md §2 (6):
##   - Empty selection: panel hidden (or "no selection" placeholder).
##   - Single selection: portrait rect (faction colored), HP bar, type label,
##     placeholder abilities row.
##   - Multi selection: small icon grid; clicking an icon narrows via
##     SelectionManager.select_only.
##
## Reads:
##   - EventBus.selection_changed (single subscribe in _ready, disconnect on
##     tree exit). The signal is read-shaped (UI-only) and is on the L2 lint
##     allowlist.
##   - Unit accessors: unit_id, unit_type, team, get_health() — duck-typed,
##     same surface SelectionManager / SelectableComponent rely on.
##   - HealthComponent.hp / max_hp / hp_x100 (boundary read via get(); the
##     component owns fixed-point storage — we read the float accessor).
##
## Why poll HP in `_process` instead of subscribing to a signal:
##   The HealthComponent does NOT emit a `unit_health_changed` per-tick signal
##   — only `unit_health_zero` on death (StateMachine death-preempt trigger).
##   Adding a per-tick signal would create a write-shaped EventBus emission
##   from `_sim_tick` for every damaged unit per tick — wasteful when 99% of
##   the time no UI consumer cares. Polling the *displayed* unit each
##   `_process` frame is O(1) and stays off-tick (Sim Contract §1.5: "UI reads
##   sim state freely off-tick"). When CombatSystem ships in Phase 2 and the
##   gameplay needs ON-CHANGE precision (e.g., damage numbers), we add a
##   targeted signal then; until then, polling one unit costs nothing.
##
## Sim Contract / lint compliance:
##   - mouse_filter discipline: containers PASS (so background clicks reach
##     the world), icon buttons STOP (so clicks land on the buttons). Same
##     pattern as drag_overlay's MOUSE_FILTER_IGNORE inoculation against the
##     session-1 regression.
##   - i18n: every visible string flows through tr(). No hardcoded English.
##     UI_PANEL_NO_SELECTION / UI_PANEL_HP / UI_PANEL_ABILITIES / UNIT_KARGAR
##     ship in strings.csv this wave; the Persian column stays empty per
##     CLAUDE.md "Tier 2 is a config change, not a refactor."
##   - No sim-state writes. UI reads only. Selection narrowing routes through
##     SelectionManager.select_only, the canonical write seam.
##   - Method names avoid the `apply_*` prefix — lint rule L1 forbids it in
##     files with `_process`. Our refresh path is `refresh_displayed_unit()`.
##
## DEFERRED (intentionally out of session-2 scope per kickoff §2 (6)):
##   - Real portraits / real ability icons (placeholder rects only —
##     CLAUDE.md "no real art until MVP loop is fun").
##   - Build menu inside the panel (Phase 3 — when buildings exist).
##   - Subgroup management beyond icon-narrows-to-one (Phase 2+).
##   - Ability-button hotkeys / cooldown rendering (Phase 2 with combat).

# ============================================================================
# State (read-only from outside)
# ============================================================================

# Tag for which sub-layout is currently rendered. Tests assert on this rather
# than walking nested visibility — stable identifier across visual tweaks.
const STATE_EMPTY: StringName = &"empty"
const STATE_SINGLE: StringName = &"single"
const STATE_MULTI: StringName = &"multi"

var visible_state: StringName = STATE_EMPTY

# unit_id of the unit currently rendered in the single-selection layout.
# -1 sentinel when no single-unit display is active.
var displayed_unit_id: int = -1

# 0..1 ratio of current_hp / max_hp for the displayed unit. Read by the HP
# bar's _draw and by tests. Snapped to 0 when no unit is displayed.
var hp_ratio: float = 0.0

# tr()-resolved display name of the displayed unit's type. Empty when no
# single unit is shown.
var displayed_type_label: String = ""

# Number of icons currently rendered in the multi-selection grid.
var icon_count: int = 0


# ============================================================================
# Tunables (placeholder visual constants — palette per CLAUDE.md)
# ============================================================================

# Faction palette (Iran sandy-brown, Turan TBD when Phase 2 ships).
const _COLOR_FACTION_IRAN: Color = Color(0.65, 0.5, 0.3)
const _COLOR_FACTION_TURAN: Color = Color(0.55, 0.3, 0.3)
const _COLOR_FACTION_NEUTRAL: Color = Color(0.55, 0.55, 0.6)

const _COLOR_BG: Color = Color(0.1, 0.1, 0.12, 0.75)
const _COLOR_HP_BG: Color = Color(0.15, 0.05, 0.05, 0.9)
const _COLOR_HP_FILL: Color = Color(0.85, 0.25, 0.2)
const _COLOR_ABILITY_PLACEHOLDER: Color = Color(0.3, 0.3, 0.34, 0.85)
const _COLOR_LABEL: Color = Color(0.95, 0.95, 0.92)

const _PANEL_WIDTH: float = 250.0
const _PANEL_HEIGHT: float = 120.0
const _PANEL_MARGIN: float = 16.0

const _PORTRAIT_SIZE: Vector2 = Vector2(50.0, 50.0)
const _HP_BAR_SIZE: Vector2 = Vector2(150.0, 10.0)

# Multi-select grid: 4 columns, dynamic rows. Each icon is square, padded.
const _ICON_SIZE: Vector2 = Vector2(36.0, 36.0)
const _ICON_PADDING: float = 4.0
const _ICONS_PER_ROW: int = 4
# Soft cap: panel does not grow unbounded. 12 icons (3 rows of 4) covers Phase
# 1's 5-worker case comfortably and is the typical RTS multi-select density.
# Beyond 12, we render the first 12 plus a "+N more" tag — a Phase 2 polish
# concern; for MVP we just cap.
const _MAX_ICONS: int = 12

# Background fallback color when team is unknown.
const _COLOR_PORTRAIT_FALLBACK: Color = Color(0.4, 0.4, 0.45)


# ============================================================================
# Sub-layout containers
# ============================================================================
# Each sub-layout is its own Control subtree under the panel root. The panel
# toggles `visible` per state. _ready resolves the @onready paths; the .tscn
# defines the structure.

@onready var _root: Control = $Root
@onready var _empty_layout: Control = $Root/EmptyLayout
@onready var _empty_label: Label = $Root/EmptyLayout/EmptyLabel
@onready var _single_layout: Control = $Root/SingleLayout
@onready var _portrait: ColorRect = $Root/SingleLayout/Portrait
@onready var _type_label: Label = $Root/SingleLayout/TypeLabel
@onready var _hp_bg: ColorRect = $Root/SingleLayout/HPBackground
@onready var _hp_fill: ColorRect = $Root/SingleLayout/HPBackground/HPFill
@onready var _abilities_label: Label = $Root/SingleLayout/AbilitiesLabel
@onready var _abilities_row: HBoxContainer = $Root/SingleLayout/AbilitiesRow
@onready var _multi_layout: Control = $Root/MultiLayout
@onready var _multi_grid: GridContainer = $Root/MultiLayout/IconGrid


# Internals
var _displayed_unit: Object = null
# Per-icon mapping: button (Object/BaseButton) -> unit_id (int). Used to route
# icon-click handlers and to defensively skip freed units.
var _icon_units: Array = []  # Array of Dictionary { button, unit_id }


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# layer = 0 — same plane as ResourceHUD. Bottom-left anchor is set in the
	# .tscn via the Root Control's anchor preset.
	# Subscribe to selection broadcasts. EventBus is an autoload so the lookup
	# is always valid; defensive checks would be redundant.
	if not EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.connect(_on_selection_changed)

	# Seed labels with translated text. Re-apply if the locale changes (Tier
	# 2 work — for now, single locale at boot).
	_empty_label.text = tr("UI_PANEL_NO_SELECTION")
	_abilities_label.text = tr("UI_PANEL_ABILITIES")

	_render_empty()


func _exit_tree() -> void:
	# Symmetric disconnect. Without this, the F2 debug overlay (Phase 4) would
	# see ghost connections from prior panel instances — same hygiene the
	# FarrGauge applies (farr_gauge.gd:_exit_tree).
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


# Off-tick poll for the displayed unit's HP. UI Sim-Contract §1.5: free to
# read sim state from _process; never write. Cheap (one is_instance_valid +
# one float read for the single displayed unit). Does NOT drive any tween or
# emit any write-shaped signal; just refreshes the visual.
func _process(_dt: float) -> void:
	if visible_state == STATE_SINGLE:
		refresh_displayed_unit()


# ============================================================================
# Selection listener
# ============================================================================

func _on_selection_changed(_selected_unit_ids: Array) -> void:
	# Pull the live selection set from the SelectionManager (which filters
	# freed units defensively). Working off the autoload's Array of Unit refs
	# rather than the broadcast's id-list lets us reach unit_type / get_health
	# without an indirection.
	var units: Array = SelectionManager.selected_units
	var n: int = units.size()
	if n == 0:
		_render_empty()
	elif n == 1:
		_render_single(units[0])
	else:
		_render_multi(units)


# ============================================================================
# Rendering — empty
# ============================================================================

func _render_empty() -> void:
	visible_state = STATE_EMPTY
	displayed_unit_id = -1
	hp_ratio = 0.0
	displayed_type_label = ""
	icon_count = 0
	_displayed_unit = null
	_clear_icon_grid()
	_empty_layout.visible = true
	_single_layout.visible = false
	_multi_layout.visible = false


# ============================================================================
# Rendering — single selection
# ============================================================================

func _render_single(unit: Object) -> void:
	visible_state = STATE_SINGLE
	_displayed_unit = unit
	displayed_unit_id = int(unit.get(&"unit_id"))
	displayed_type_label = _type_label_for(unit)
	_type_label.text = displayed_type_label
	_portrait.color = _faction_color(unit)
	_clear_icon_grid()
	icon_count = 0
	_empty_layout.visible = false
	_multi_layout.visible = false
	_single_layout.visible = true
	# Build placeholder ability slots. Phase 1 has no abilities yet; we render
	# 4 grey rects so the layout slot is real and the lead can see it on first
	# boot. Phase 2 (Rostam) replaces these with real ability buttons.
	_rebuild_ability_placeholders(4)
	# Initial HP read. _process will keep it fresh.
	refresh_displayed_unit()


# Public so tests can force a refresh without waiting on _process. Off-tick.
# Intentionally NOT named `apply_*` (lint rule L1).
func refresh_displayed_unit() -> void:
	if _displayed_unit == null or not is_instance_valid(_displayed_unit):
		# Displayed unit was freed (death, queue_free). Defensive cleanup —
		# fall back to whatever the live selection set says.
		_on_selection_changed([])
		return
	hp_ratio = _read_hp_ratio(_displayed_unit)
	# Resize the HP fill rect proportionally. ColorRect width is the only
	# property we update — ColorRect honors size on the next frame.
	_hp_fill.size = Vector2(_HP_BAR_SIZE.x * hp_ratio, _HP_BAR_SIZE.y)


# ============================================================================
# Rendering — multi-selection icon grid
# ============================================================================

func _render_multi(units: Array) -> void:
	visible_state = STATE_MULTI
	_displayed_unit = null
	displayed_unit_id = -1
	hp_ratio = 0.0
	displayed_type_label = ""
	_empty_layout.visible = false
	_single_layout.visible = false
	_multi_layout.visible = true
	_clear_icon_grid()
	var to_render: int = min(units.size(), _MAX_ICONS)
	for i in range(to_render):
		var u: Object = units[i]
		if not is_instance_valid(u):
			continue
		var btn: Button = _make_icon_button(u)
		_multi_grid.add_child(btn)
		_icon_units.append({"button": btn, "unit_id": int(u.get(&"unit_id"))})
	icon_count = _icon_units.size()


func _make_icon_button(unit: Object) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = _ICON_SIZE
	btn.flat = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP  # the ONE place clicks stop
	# Color the button via a theme override using its background color. Godot
	# Buttons don't have a direct color tint, so we add a child ColorRect that
	# fills the button's rect — same placeholder approach used elsewhere.
	var swatch: ColorRect = ColorRect.new()
	swatch.color = _faction_color(unit)
	swatch.anchor_right = 1.0
	swatch.anchor_bottom = 1.0
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE  # button keeps clicks
	btn.add_child(swatch)
	# Bind the unit_id at button-creation time so a later click resolves the
	# right unit even if the icon list is reshuffled.
	var uid: int = int(unit.get(&"unit_id"))
	btn.pressed.connect(handle_icon_click.bind(uid))
	# Tooltip: the type label. Helps the player tell apart icons of similar
	# colors. tr() so the tooltip honors locale.
	btn.tooltip_text = _type_label_for(unit)
	return btn


# Public for tests; also bound to each Button's `pressed` signal. Routes the
# click through SelectionManager.select_only — the canonical narrow path.
# Defensive: if the unit's been freed since render, no-op.
func handle_icon_click(unit_id: int) -> void:
	# Resolve the unit by walking the live selection set (which filters freed
	# entries). Walking the live set is safer than holding raw refs — a unit
	# may have died between render and click.
	for u in SelectionManager.selected_units:
		if not is_instance_valid(u):
			continue
		var uid_v: Variant = u.get(&"unit_id")
		if uid_v != null and int(uid_v) == unit_id:
			SelectionManager.select_only(u)
			return
	# Unit gone — silent no-op. The next selection_changed broadcast will
	# clean up the icon naturally.


func _clear_icon_grid() -> void:
	for entry in _icon_units:
		var btn: Variant = entry.get("button")
		if btn != null and is_instance_valid(btn):
			(btn as Node).queue_free()
	_icon_units.clear()
	# Also free any orphans (defensive — if a test added children directly).
	for child in _multi_grid.get_children():
		(child as Node).queue_free()


# ============================================================================
# Single-selection abilities row
# ============================================================================
# Build N grey rect placeholders. Phase 1: no real abilities, but the layout
# slot is real so the lead can see it. Phase 2 swaps these for real buttons
# wired to the unit's ability_set.

func _rebuild_ability_placeholders(count: int) -> void:
	for child in _abilities_row.get_children():
		(child as Node).queue_free()
	for i in range(count):
		var rect: ColorRect = ColorRect.new()
		rect.custom_minimum_size = Vector2(28.0, 28.0)
		rect.color = _COLOR_ABILITY_PLACEHOLDER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_abilities_row.add_child(rect)


# ============================================================================
# Helpers
# ============================================================================

# Color the portrait / icon swatch by the unit's team. Iran = sandy-brown
# (matches Kargar mesh material in scenes/units/kargar.tscn). Turan and
# neutral pre-set for Phase 2.
func _faction_color(unit: Object) -> Color:
	if unit == null or not is_instance_valid(unit):
		return _COLOR_PORTRAIT_FALLBACK
	var team_v: Variant = unit.get(&"team")
	if typeof(team_v) != TYPE_INT:
		return _COLOR_PORTRAIT_FALLBACK
	match int(team_v):
		Constants.TEAM_IRAN:
			return _COLOR_FACTION_IRAN
		Constants.TEAM_TURAN:
			return _COLOR_FACTION_TURAN
		_:
			return _COLOR_FACTION_NEUTRAL


# i18n key convention: UNIT_<TYPE_UPPER>. Phase 1 ships UNIT_KARGAR. Future
# unit types add a key per type (UNIT_PIYADE, UNIT_KAMANDAR, ...) without
# code edits — the lookup below is generic.
func _type_label_for(unit: Object) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var ut_v: Variant = unit.get(&"unit_type")
	if ut_v == null:
		return ""
	var key: String = "UNIT_" + String(ut_v).to_upper()
	return tr(key)


# Read current_hp / max_hp from the unit's HealthComponent. Returns 0 when
# the component or max_hp is unavailable (defensive — a freshly-constructed
# unit during a test fixture may have hp=0).
func _read_hp_ratio(unit: Object) -> float:
	if unit == null or not is_instance_valid(unit):
		return 0.0
	if not unit.has_method(&"get_health"):
		return 0.0
	var hc: Object = unit.call(&"get_health")
	if hc == null or not is_instance_valid(hc):
		return 0.0
	var hp_v: Variant = hc.get(&"hp")
	var max_v: Variant = hc.get(&"max_hp")
	if typeof(hp_v) != TYPE_FLOAT and typeof(hp_v) != TYPE_INT:
		return 0.0
	if typeof(max_v) != TYPE_FLOAT and typeof(max_v) != TYPE_INT:
		return 0.0
	var max_f: float = float(max_v)
	if max_f <= 0.0:
		return 0.0
	return clampf(float(hp_v) / max_f, 0.0, 1.0)
