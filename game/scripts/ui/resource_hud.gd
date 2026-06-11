extends CanvasLayer
##
## ResourceHUD — top-bar resource readout + FarrGauge.
##
## Phase 0 shipped this as text-only ("Coin: N | Grain: N | Farr: N | Pop: N/N").
## Phase 1 session 2 wave 1C replaced the text Farr label with the FarrGauge
## sub-scene (`farr_gauge.tscn`).
## Phase 3 wave 1B (this session): Coin/Grain/Pop now subscribe to
## EventBus.resource_changed (FarrGauge pattern) and read from
## ResourceSystem autoload instead of GameState.player_resources meta.
##
## Layout: top bar, `MarginContainer` → `HBoxContainer`:
##   [Coin] [Grain] [Pop] [Spacer (size_flags_horizontal=EXPAND)] [FarrGauge]
##
## Spec §11 anchors the gauge "top-right." The HBox spans the full top bar;
## an EXPAND-flagged Spacer pushes the gauge to the right edge while
## Coin/Grain/Pop stay left.
##
## Reading model — UI off-tick reads only (Sim Contract §1.5):
##   - On _ready: seed from ResourceSystem.coin_for / grain_for / population_for
##     so the HUD shows coherent values before the first signal arrives.
##   - Subscribe to EventBus.resource_changed and refresh on signal.
##   - The Farr gauge continues to own its own EventBus.farr_changed wiring.
##   - GameState meta fallback is retained for the legacy test path
##     (test_resource_hud.gd's pre-Phase-3 cases) but production reads always
##     go through ResourceSystem.
##
## Internationalization: every label string is run through `tr()` against
## translations/strings.csv. The Persian addition at Tier 2 is a config change,
## not a refactor (per CLAUDE.md). The gauge's internal "Farr N" centered
## label uses tr("UI_FARR") for the same reason.

# === LABEL NODES ============================================================
# Wired via @onready when the scene loads. Names match the .tscn structure.

@onready var _coin_label: Label = $Margin/HBox/CoinLabel
@onready var _grain_label: Label = $Margin/HBox/GrainLabel
@onready var _pop_label: Label = $Margin/HBox/PopLabel


# === CONSTANTS ==============================================================
# Default values when the producer autoload doesn't exist yet (test scenes
# loading the HUD in isolation, Phase 0 fixtures). Keeps the HUD rendering
# coherent during legacy test runs.

const _DEFAULT_COIN: int = 0
const _DEFAULT_GRAIN: int = 0
const _DEFAULT_POP: int = 0
const _DEFAULT_POP_CAP: int = 0


# === LIFECYCLE ==============================================================

func _ready() -> void:
	# Seed once at start so the HUD shows a coherent state before any signal
	# arrives. Same pattern as FarrGauge._seed_initial_farr_from_system.
	_refresh_labels()
	# Subscribe to ResourceSystem's signal. EventBus is an autoload so this is
	# always reachable in production; defensive is_connected guards against
	# re-entry from hot-reload.
	if not EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.connect(_on_resource_changed)


# Symmetric cleanup. Without this the F2 debug overlay (Phase 4) would see
# ghost connections from prior HUD instances after scene teardown. Mirrors
# FarrGauge._exit_tree.
func _exit_tree() -> void:
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)


# === SIGNAL HANDLER =========================================================
# Authoritative update path for Phase 3+. Any resource mutation flows through
# ResourceSystem.change_resource → EventBus.resource_changed → here.
# Sim Contract §1.5: handler reads sim state freely off-tick. Writes only to
# UI-local label text; never mutates ResourceSystem or emits write-shaped
# signals.
func _on_resource_changed(_team: int, _kind: StringName, _delta_x100: int,
		_new_total_x100: int) -> void:
	# We refresh ALL labels rather than branching on kind. Cheaper than tracking
	# which kind moved and resolving the right label; HUD updates are O(1) per
	# signal and there's no per-frame cost.
	_refresh_labels()


# === RENDERING ==============================================================
# Re-read every relevant value from the autoloads and write the formatted
# strings into the three labels. Cheap (O(1) reads, O(1) format).

func _refresh_labels() -> void:
	_coin_label.text = "%s: %d" % [tr("UI_COIN"), _read_coin()]
	_grain_label.text = "%s: %d" % [tr("UI_GRAIN"), _read_grain()]
	var pop: int = _read_pop()
	var pop_cap: int = _read_pop_cap()
	_pop_label.text = "%s: %d/%d" % [tr("UI_POPULATION"), pop, pop_cap]


# === RESOURCESYSTEM READS (production path) =================================
# Production code path: read live values from ResourceSystem autoload.
# Falls back to the GameState meta path if ResourceSystem is unavailable
# (test contexts that pre-date Phase 3 wave 1B).
#
# §9.M7 L7 cleanup: the former `rs.has_method(&"coin_for")`-style guards
# were stale relics — coin_for / grain_for / population_for /
# population_cap_for are ratified ResourceSystem API. The `rs != null`
# autoload-or-null check is the sanctioned seam (headless unit tests run
# without the autoload); a renamed/missing method on a present autoload
# now errors loudly instead of silently flipping the HUD onto the legacy
# GameState path (the exact BUG-3 / Wave 3-Sim zero-coin failure shape).

func _read_coin() -> int:
	var rs: Node = _autoload_or_null(&"ResourceSystem")
	if rs != null:
		return int(rs.coin_for(Constants.TEAM_IRAN))
	# Legacy path: GameState.player_resources dict (Phase 0 / test fixtures).
	return _read_resource(Constants.KIND_COIN, _DEFAULT_COIN)


func _read_grain() -> int:
	var rs: Node = _autoload_or_null(&"ResourceSystem")
	if rs != null:
		return int(rs.grain_for(Constants.TEAM_IRAN))
	return _read_resource(Constants.KIND_GRAIN, _DEFAULT_GRAIN)


func _read_pop() -> int:
	var rs: Node = _autoload_or_null(&"ResourceSystem")
	if rs != null:
		return int(rs.population_for(Constants.TEAM_IRAN))
	return _read_int_field(&"GameState", &"player_pop", _DEFAULT_POP)


func _read_pop_cap() -> int:
	var rs: Node = _autoload_or_null(&"ResourceSystem")
	if rs != null:
		return int(rs.population_cap_for(Constants.TEAM_IRAN))
	return _read_int_field(&"GameState", &"player_pop_cap", _DEFAULT_POP_CAP)


# === LEGACY DEFENSIVE AUTOLOAD READS (test-fixture path) ====================
# Retained for the Phase 0 / Phase 1 test fixtures that seed values via
# GameState meta. Production code reaches them only when ResourceSystem is
# missing — which doesn't happen in production but DOES happen in older test
# files. The two-source pattern keeps both code paths working without
# requiring those tests to migrate atomically.


# Read a resource by KIND_* StringName from GameState.player_resources.
func _read_resource(kind: StringName, default_value: int) -> int:
	var gs: Node = _autoload_or_null(&"GameState")
	if gs == null:
		return default_value
	var resources: Variant = _read_field_or_meta(gs, &"player_resources")
	if resources == null or typeof(resources) != TYPE_DICTIONARY:
		return default_value
	var dict: Dictionary = resources
	if not dict.has(kind):
		return default_value
	var raw: Variant = dict[kind]
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return default_value
	return int(raw)


# Resolve a field from a Node by trying declared properties first, then the
# meta dictionary.
func _read_field_or_meta(node: Node, field: StringName) -> Variant:
	var via_get: Variant = node.get(field)
	if via_get != null:
		return via_get
	if node.has_meta(field):
		return node.get_meta(field)
	return null


# Helper: reach into an autoload, pull an int-shaped field, fall back to
# default_value if the autoload or field isn't there yet.
func _read_int_field(autoload_name: StringName, field: StringName, default_value: int) -> int:
	var node: Node = _autoload_or_null(autoload_name)
	if node == null:
		return default_value
	var raw: Variant = _read_field_or_meta(node, field)
	if raw == null:
		return default_value
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return default_value
	return int(raw)


# Resolve an autoload by name through the engine's main loop. Script autoloads
# register as direct children of the SceneTree root under their registered
# name; Engine.has_singleton() does NOT find them (that API is for C++/
# GDExtension singletons). Same pattern as FarrGauge._autoload_or_null.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(NodePath(autoload_name))
