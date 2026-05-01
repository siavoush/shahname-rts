extends CanvasLayer
##
## ResourceHUD — Phase 0 text-only resource readout (top-left).
##
## Per 02_IMPLEMENTATION_PLAN.md Phase 0 (ui-developer) and the kickoff doc:
## "Coin: 0 | Grain: 0 | FARR: 50 | Pop: 0/0". Text-only by design — the full
## circular Farr gauge with color thresholds, floating change numbers, and the
## hero portrait land in Phase 1+ per 01_CORE_MECHANICS.md §11.
##
## Reading model — UI off-tick reads only (Sim Contract §1.5):
##   - We poll FarrSystem and GameState in `_process` every frame. Reads are
##     unrestricted off-tick; we never write sim state from the HUD.
##   - The autoloads we read may not exist yet at Phase 0 (FarrSystem ships in
##     parallel with this work; GameState.player_resources / player_pop ship
##     later). Every read uses defensive `Engine.has_singleton()` and
##     `Object.get(&"prop")` patterns so the HUD displays "0" rather than
##     crashing while gameplay-systems work catches up.
##   - When the producer autoloads land, no code change here is needed — the
##     reads start returning real numbers.
##
## Internationalization: every label string is run through `tr()` against
## translations/strings.csv. The Persian addition at Tier 2 is a config change,
## not a refactor (per CLAUDE.md). Numbers are formatted with `%d` on the
## English side; if a future locale needs different digit shaping, the
## formatter moves into the translation layer.
##
## Aesthetic target for MVP HUD (per CLAUDE.md):
##   "Coin: 250 | Grain: 180 | FARR: 47 | Pop: 12/30"
##
## Layout: top-left corner, `MarginContainer` → `HBoxContainer` of labels.
## CanvasLayer overlays the 3D scene cleanly without world-space coupling.

# === LABEL NODES ============================================================
# Wired via @onready when the scene loads. Names match the .tscn structure.

@onready var _coin_label: Label = $Margin/HBox/CoinLabel
@onready var _grain_label: Label = $Margin/HBox/GrainLabel
@onready var _farr_label: Label = $Margin/HBox/FarrLabel
@onready var _pop_label: Label = $Margin/HBox/PopLabel


# === CONSTANTS ==============================================================
# Default values when the producer autoload doesn't exist yet. Keeps the HUD
# rendering coherent during the parallel Phase 0 build. Once FarrSystem +
# ResourceSystem land, the defensive reads return live values.

const _DEFAULT_FARR: int = 50               # Match 01_CORE_MECHANICS.md §4.1 starting Farr
const _DEFAULT_COIN: int = 0
const _DEFAULT_GRAIN: int = 0
const _DEFAULT_POP: int = 0
const _DEFAULT_POP_CAP: int = 0


# === LIFECYCLE ==============================================================

func _ready() -> void:
	# Render once at start so the scene shows a coherent state even before
	# the first _process tick lands. Same call path as the per-frame update.
	_refresh_labels()


func _process(_dt: float) -> void:
	# Sim Contract §1.5: UI reads sim state freely off-tick. We never write,
	# never start tweens here, never emit write-shaped EventBus signals.
	_refresh_labels()


# === RENDERING ==============================================================
# Re-read every relevant value from the autoloads and write the formatted
# strings into the four labels. Cheap (O(1) reads, O(1) format) — fine to
# run every frame at Phase 0. If the formatting cost ever shows up in a
# profile, switch to event-driven updates via farr_changed / resource_changed
# signals. Phase 0 prefers the simpler poll model.

func _refresh_labels() -> void:
	_coin_label.text = "%s: %d" % [tr("UI_COIN"), _read_coin()]
	_grain_label.text = "%s: %d" % [tr("UI_GRAIN"), _read_grain()]
	_farr_label.text = "%s: %d" % [tr("UI_FARR"), _read_farr_display()]
	var pop: int = _read_pop()
	var pop_cap: int = _read_pop_cap()
	_pop_label.text = "%s: %d/%d" % [tr("UI_POPULATION"), pop, pop_cap]


# === DEFENSIVE AUTOLOAD READS ===============================================
# Each reader returns the live value if the autoload + property exist, else
# the documented default. Pattern centralizes the existence check so the
# rendering code stays linear.

func _read_farr_display() -> int:
	# FarrSystem (gameplay-systems' parallel session-4 deliverable) is the
	# authoritative source. Sim Contract §1.6 mandates integer backing store
	# (farr_x100) with float conversion at display boundaries. Two read
	# shapes accepted:
	#   - `value_farr` (float): the kickoff doc's API name.
	#   - `farr_for_display()` (func -> float): the Sim Contract §1.6 boundary.
	# Either works; the HUD shows whichever exists.
	var farr_node: Node = _autoload_or_null(&"FarrSystem")
	if farr_node == null:
		return _DEFAULT_FARR
	if farr_node.has_method(&"farr_for_display"):
		return roundi(farr_node.call(&"farr_for_display"))
	var value_via_get: Variant = farr_node.get(&"value_farr")
	if value_via_get != null:
		return roundi(float(value_via_get))
	return _DEFAULT_FARR


func _read_coin() -> int:
	return _read_resource(Constants.KIND_COIN, _DEFAULT_COIN)


func _read_grain() -> int:
	return _read_resource(Constants.KIND_GRAIN, _DEFAULT_GRAIN)


# Read a resource by KIND_* StringName from GameState.player_resources, which
# we expect to be a Dictionary[StringName, int] when ResourceSystem ships.
# The defensive path covers: GameState absent (impossible in Phase 0 but
# cheap to check), player_resources missing, the kind not yet keyed, and
# the value being a non-numeric type.
#
# Two read shapes accepted:
#   1. `gs.player_resources` declared as a property on GameState (the long-
#      term shape — gameplay-systems' future ResourceSystem will declare it).
#   2. `gs.get_meta("player_resources", null)` — Godot meta dictionary, used
#      by Phase 0 tests and any temporary holding pattern. GDScript Object.set
#      on an undeclared property is a no-op, so meta is the cleanest seam for
#      "this property doesn't exist yet but I want to inject a value."
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
# meta dictionary. The two-source pattern lets the HUD ride atop both
# (a) future declared properties on autoloads and (b) test-time / Phase-0
# meta injections without forcing tests to monkey-patch real source files.
func _read_field_or_meta(node: Node, field: StringName) -> Variant:
	var via_get: Variant = node.get(field)
	if via_get != null:
		return via_get
	if node.has_meta(field):
		return node.get_meta(field)
	return null


func _read_pop() -> int:
	return _read_int_field(&"GameState", &"player_pop", _DEFAULT_POP)


func _read_pop_cap() -> int:
	return _read_int_field(&"GameState", &"player_pop_cap", _DEFAULT_POP_CAP)


# Helper: reach into an autoload, pull an int-shaped field, fall back to
# default_value if the autoload or field isn't there yet. Used for population
# (cap), and any future scalar fields the HUD wants to display. Reads
# declared properties first, then meta — same two-source pattern as
# _read_resource above.
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


# Resolve an autoload by name through the engine's main loop. Returns null if
# the autoload isn't registered (which is the Phase 0 state for FarrSystem
# until gameplay-systems' work lands in parallel).
#
# Why not Engine.has_singleton()? In Godot 4, autoloads registered via
# project.godot's [autoload] section are NOT singletons in the
# Engine.has_singleton() sense — those are C++/GDExtension singletons. Script
# autoloads are nodes added to the SceneTree root by the engine. We look them
# up via the tree.
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	# Autoloads are direct children of the root with the registered name.
	return root.get_node_or_null(NodePath(autoload_name))
