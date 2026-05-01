extends GutTest
##
## Tests for translation infrastructure + ResourceHUD scene.
##
## Coverage:
##   - tr() returns the expected English strings for the seeded UI_* keys
##   - resource_hud.tscn loads cleanly and has the expected node structure
##   - HUD labels show defensive defaults when producer autoloads are absent
##   - HUD labels read from FarrSystem when present (mocked sibling node)
##   - HUD labels read coin/grain from GameState.player_resources when seeded
##   - _process refresh path actually updates label text on next frame
##
## Per Phase 0 ui-developer kickoff: text-only HUD; the circular Farr gauge
## with color thresholds + floating change numbers is Phase 1+.
##
## Per Sim Contract §1.5: HUD reads sim state freely off-tick. None of these
## tests advance SimClock.tick — the HUD doesn't depend on tick boundaries.
##
## TDD discipline (STUDIO_PROCESS.md §12.3): tests pass before commit;
## pre-commit hook enforces.


const HUD_SCENE_PATH: String = "res://scenes/ui/resource_hud.tscn"


# Captured GameState state we mutated, restored after every test so we don't
# leak side effects into other test files. GameState ships an autoload-level
# `reset()` (per game_state.gd) but it doesn't know about player_resources /
# player_pop yet (those land with gameplay-systems' future ResourceSystem).
# We track changes ourselves.
var _saved_resources: Variant = null
var _saved_pop: Variant = null
var _saved_pop_cap: Variant = null
var _gs_had_resources: bool = false
var _gs_had_pop: bool = false
var _gs_had_pop_cap: bool = false

# Tracks the FarrSystem mocks this test created so after_each can remove
# them without touching a real autoload that future sessions might wire.
var _mock_farr_systems: Array[Node] = []

# When we mutate the real FarrSystem autoload's backing fixed-point store,
# stash the original value so after_each restores it and other test files
# don't see leaked state. Mutating the autoload directly (rather than via
# apply_farr_change) keeps these tests off-tick — apply_farr_change asserts
# SimClock.is_ticking() and we don't want to spin the clock here.
var _saved_farr_x100: Variant = null


func before_each() -> void:
	# Snapshot any GameState fields we might overwrite.
	_gs_had_resources = (GameState.get(&"player_resources") != null)
	_gs_had_pop = (GameState.get(&"player_pop") != null)
	_gs_had_pop_cap = (GameState.get(&"player_pop_cap") != null)
	_saved_resources = GameState.get(&"player_resources") if _gs_had_resources else null
	_saved_pop = GameState.get(&"player_pop") if _gs_had_pop else null
	_saved_pop_cap = GameState.get(&"player_pop_cap") if _gs_had_pop_cap else null
	# Snapshot the live FarrSystem autoload's backing store, if registered.
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr != null:
		_saved_farr_x100 = farr.get(&"_farr_x100")
	else:
		_saved_farr_x100 = null


func after_each() -> void:
	# Restore snapshot. If we wrote a property GameState didn't natively have,
	# the cleanest restore in GDScript-on-Object is to set it back to null —
	# downstream tests don't depend on the absence of a key, only on the
	# defensive read path returning the default.
	if _gs_had_resources:
		GameState.set(&"player_resources", _saved_resources)
	else:
		GameState.set(&"player_resources", null)
	if _gs_had_pop:
		GameState.set(&"player_pop", _saved_pop)
	else:
		GameState.set(&"player_pop", null)
	if _gs_had_pop_cap:
		GameState.set(&"player_pop_cap", _saved_pop_cap)
	else:
		GameState.set(&"player_pop_cap", null)
	_remove_mock_farr_system()
	# Restore live FarrSystem autoload's backing store.
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr != null and _saved_farr_x100 != null:
		farr.set(&"_farr_x100", _saved_farr_x100)


# ---------------------------------------------------------------------------
# 1. Translation infrastructure — tr() returns English seed strings
# ---------------------------------------------------------------------------

func test_tr_ui_farr_returns_english() -> void:
	# Locale defaults to en in project.godot; the strings.csv ships with
	# UI_FARR=Farr. If translations don't load, tr() returns the key itself
	# — which would fail this assert and signal a wiring break.
	assert_eq(tr("UI_FARR"), "Farr",
		"tr('UI_FARR') must resolve to 'Farr' under en locale")


func test_tr_ui_coin_returns_english() -> void:
	assert_eq(tr("UI_COIN"), "Coin",
		"tr('UI_COIN') must resolve to 'Coin' under en locale")


func test_tr_ui_grain_returns_english() -> void:
	assert_eq(tr("UI_GRAIN"), "Grain",
		"tr('UI_GRAIN') must resolve to 'Grain' under en locale")


func test_tr_ui_population_returns_english() -> void:
	assert_eq(tr("UI_POPULATION"), "Pop",
		"tr('UI_POPULATION') must resolve to 'Pop' under en locale")


func test_tr_ui_tier_keys_resolve() -> void:
	# Tier keys feed the future tier indicator (Phase 4); shipped now so the
	# ui-developer's Phase 4 work is a config change, not a wiring change.
	assert_eq(tr("UI_TIER_VILLAGE"), "Village")
	assert_eq(tr("UI_TIER_FORTRESS"), "Fortress")


# ---------------------------------------------------------------------------
# 2. Scene structure — loads cleanly and has the expected nodes
# ---------------------------------------------------------------------------

func test_resource_hud_scene_loads_without_error() -> void:
	var packed: PackedScene = load(HUD_SCENE_PATH)
	assert_not_null(packed,
		"resource_hud.tscn must load cleanly from %s" % HUD_SCENE_PATH)


func test_resource_hud_scene_has_expected_labels() -> void:
	# The scene must expose the four Labels the script @onreadys onto.
	# Names match the .tscn structure: Margin/HBox/{Coin,Grain,Farr,Pop}Label.
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	assert_not_null(hud.get_node_or_null("Margin/HBox/CoinLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/GrainLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/FarrLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/PopLabel"))


# ---------------------------------------------------------------------------
# 3. Defensive reads — HUD shows defaults when producers absent
# ---------------------------------------------------------------------------

func test_farr_label_shows_default_when_farr_system_absent() -> void:
	# Defensive default path: when no FarrSystem autoload (or stand-in) is
	# present at the SceneTree root, the HUD falls back to 50 (the
	# documented starting Farr per 01_CORE_MECHANICS.md §4.1).
	#
	# If gameplay-systems' real FarrSystem autoload has already shipped and
	# is wired into project.godot by the time this test runs, this scenario
	# (no producer at all) is no longer reachable — skip the test rather
	# than report a false failure.
	_remove_mock_farr_system()
	if get_tree().root.get_node_or_null(NodePath("FarrSystem")) != null:
		pending("FarrSystem autoload is registered; defensive-default path unreachable")
		return
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	# _ready ran at instantiation; force a refresh anyway for determinism.
	hud._refresh_labels()
	var label: Label = hud.get_node("Margin/HBox/FarrLabel")
	assert_eq(label.text, "Farr: 50",
		"FarrLabel must read default 50 when FarrSystem autoload is missing")


func test_coin_label_shows_zero_when_resources_absent() -> void:
	# GameState has no `player_resources` declared field at Phase 0; clear
	# any meta we (or a previous test) may have set.
	if GameState.has_meta(&"player_resources"):
		GameState.remove_meta(&"player_resources")
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	hud._refresh_labels()
	var label: Label = hud.get_node("Margin/HBox/CoinLabel")
	assert_eq(label.text, "Coin: 0",
		"CoinLabel must show 0 when GameState.player_resources is missing")


func test_pop_label_shows_zero_zero_when_fields_absent() -> void:
	if GameState.has_meta(&"player_pop"):
		GameState.remove_meta(&"player_pop")
	if GameState.has_meta(&"player_pop_cap"):
		GameState.remove_meta(&"player_pop_cap")
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	hud._refresh_labels()
	var label: Label = hud.get_node("Margin/HBox/PopLabel")
	assert_eq(label.text, "Pop: 0/0",
		"PopLabel must show 0/0 when GameState pop fields are missing")


# ---------------------------------------------------------------------------
# 4. Live reads — HUD picks up values from autoloads
# ---------------------------------------------------------------------------

func test_farr_label_reads_from_mock_farr_system() -> void:
	# Provide a FarrSystem stand-in at the SceneTree root so _autoload_or_null
	# resolves it. Mirror the production API: a `value_farr` float field.
	# If a real FarrSystem autoload is already registered (gameplay-systems'
	# parallel session-4 work landed first), reuse it and mutate the field
	# instead — autoloads can't be shadowed by name.
	_inject_or_mutate_farr_system(47.0)
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		_remove_mock_farr_system()
		pending("resource_hud.tscn unavailable")
		return
	hud._refresh_labels()
	var label: Label = hud.get_node("Margin/HBox/FarrLabel")
	assert_eq(label.text, "Farr: 47",
		"FarrLabel must reflect FarrSystem.value_farr when present")
	_remove_mock_farr_system()


func test_coin_label_reads_from_player_resources() -> void:
	# Phase 0 contract: the HUD reads coin/grain from a Dictionary keyed by
	# Constants.KIND_COIN / KIND_GRAIN on GameState.player_resources. Tests
	# that data path so the eventual ResourceSystem just needs to populate
	# the dict — no HUD edits.
	#
	# `set_meta` is the seam used while GameState doesn't yet declare the
	# field as a typed property (Phase 0 wave 1; gameplay-systems will
	# declare it when ResourceSystem ships). The HUD's _read_field_or_meta
	# helper reads declared property first, then meta — so the same code
	# works for both phases.
	var resources: Dictionary = {
		Constants.KIND_COIN: 250,
		Constants.KIND_GRAIN: 180,
	}
	GameState.set_meta(&"player_resources", resources)
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	hud._refresh_labels()
	var coin_label: Label = hud.get_node("Margin/HBox/CoinLabel")
	var grain_label: Label = hud.get_node("Margin/HBox/GrainLabel")
	assert_eq(coin_label.text, "Coin: 250")
	assert_eq(grain_label.text, "Grain: 180")
	GameState.remove_meta(&"player_resources")


func test_pop_label_reads_from_pop_fields() -> void:
	GameState.set_meta(&"player_pop", 12)
	GameState.set_meta(&"player_pop_cap", 30)
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	hud._refresh_labels()
	var label: Label = hud.get_node("Margin/HBox/PopLabel")
	assert_eq(label.text, "Pop: 12/30")
	GameState.remove_meta(&"player_pop")
	GameState.remove_meta(&"player_pop_cap")


# ---------------------------------------------------------------------------
# 5. _process refresh path — labels update on subsequent frames
# ---------------------------------------------------------------------------

func test_process_picks_up_farr_changes_between_frames() -> void:
	# Mutate the FarrSystem after the HUD has been processing. The next
	# _process tick must show the updated value. Verifies the poll model.
	#
	# Both mutations route through _inject_or_mutate_farr_system because the
	# real FarrSystem autoload's `value_farr` is a getter-only computed
	# property — a direct `set()` is silently a no-op. The helper writes the
	# integer-backed `_farr_x100` for the production path.
	_inject_or_mutate_farr_system(30.0)
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		_remove_mock_farr_system()
		pending("resource_hud.tscn unavailable")
		return
	# Frame 1.
	await get_tree().process_frame
	var label: Label = hud.get_node("Margin/HBox/FarrLabel")
	assert_eq(label.text, "Farr: 30")
	# Mutate, pump, re-check.
	_inject_or_mutate_farr_system(95.0)
	await get_tree().process_frame
	assert_eq(label.text, "Farr: 95",
		"_process must re-read FarrSystem each frame")
	_remove_mock_farr_system()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _instantiate_hud() -> CanvasLayer:
	var packed: PackedScene = load(HUD_SCENE_PATH)
	if packed == null:
		return null
	var hud: CanvasLayer = packed.instantiate() as CanvasLayer
	add_child_autofree(hud)
	return hud


# Provide a FarrSystem-shaped node at the SceneTree root reading `value_farr`
# float. Three cases:
#   1. The real FarrSystem autoload exists (gameplay-systems' wave-1 work):
#      mutate its `_farr_x100` backing store directly (off-tick is fine —
#      we're not going through apply_farr_change). Returns the autoload.
#   2. No FarrSystem present and no prior mock: spawn a Node, set
#      `value_farr`, attach to root, track for cleanup. Returns the mock.
#   3. A prior mock from this same test exists: mutate it. Returns the mock.
func _inject_or_mutate_farr_system(target_value: float) -> Node:
	var farr: Node = get_tree().root.get_node_or_null(NodePath("FarrSystem"))
	if farr != null:
		# Case 1 — real autoload (or a prior test session's mock): write the
		# fixed-point store if it has one (production); else write
		# `value_farr` directly (mock). Ordering matters: production stores
		# are integer-backed and `value_farr` is a getter-only computed
		# property, so writing `value_farr` on the production autoload is a
		# no-op.
		if farr.get(&"_farr_x100") != null:
			farr.set(&"_farr_x100", roundi(target_value * 100.0))
		else:
			farr.set(&"value_farr", target_value)
		return farr
	# Case 2 — fresh mock.
	var mock: Node = Node.new()
	mock.name = "FarrSystem"
	mock.set(&"value_farr", target_value)
	get_tree().root.add_child(mock)
	_mock_farr_systems.append(mock)
	return mock


func _remove_mock_farr_system() -> void:
	# Drop ONLY the test-injected FarrSystem stand-ins this test owns. We
	# never touch a node we didn't create — if gameplay-systems' real
	# FarrSystem autoload lands in parallel and is registered before our
	# tests run, our mocks are still removable; the real one is not because
	# we never added it to _mock_farr_systems.
	for mock: Node in _mock_farr_systems:
		if is_instance_valid(mock) and mock.is_inside_tree():
			get_tree().root.remove_child(mock)
			mock.queue_free()
	_mock_farr_systems.clear()
