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

func before_each() -> void:
	# Snapshot any GameState fields we might overwrite.
	_gs_had_resources = (GameState.get(&"player_resources") != null)
	_gs_had_pop = (GameState.get(&"player_pop") != null)
	_gs_had_pop_cap = (GameState.get(&"player_pop_cap") != null)
	_saved_resources = GameState.get(&"player_resources") if _gs_had_resources else null
	_saved_pop = GameState.get(&"player_pop") if _gs_had_pop else null
	_saved_pop_cap = GameState.get(&"player_pop_cap") if _gs_had_pop_cap else null


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
	# The scene must expose the three Labels the script @onreadys onto, plus
	# the FarrGauge sub-scene that replaces the Phase 0 FarrLabel.
	# Names match the .tscn structure: Margin/HBox/{Coin,Grain,Pop}Label and
	# Margin/HBox/FarrGauge.
	var hud: CanvasLayer = _instantiate_hud()
	if hud == null:
		pending("resource_hud.tscn unavailable")
		return
	assert_not_null(hud.get_node_or_null("Margin/HBox/CoinLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/GrainLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/PopLabel"))
	assert_not_null(hud.get_node_or_null("Margin/HBox/FarrGauge"),
		"FarrGauge sub-scene replaces the Phase 0 FarrLabel (wave 1C)")
	# FarrLabel must be gone — its presence would mean a stale reference still
	# in the scene file. Catch any incomplete migration.
	assert_null(hud.get_node_or_null("Margin/HBox/FarrLabel"),
		"FarrLabel removed in wave 1C; FarrGauge replaces it")


# ---------------------------------------------------------------------------
# 3. Defensive reads — HUD shows defaults when producers absent
# ---------------------------------------------------------------------------

# Phase 1 session 2 wave 1C: FarrLabel replaced by FarrGauge. Coverage of
# the gauge's defensive seeding when FarrSystem is absent lives in
# test_farr_gauge.gd::test_initial_displayed_farr_falls_back_when_farr_system_missing.


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

# Phase 1 session 2 wave 1C: gauge owns its own FarrSystem read path; the
# corresponding live-read coverage moved to test_farr_gauge.gd::
# test_initial_displayed_farr_seeds_from_farr_system.


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

# Phase 1 session 2 wave 1C: per-frame poll-and-refresh for Farr is gone;
# the gauge updates on EventBus.farr_changed. Coverage of the signal-driven
# refresh lives in test_farr_gauge.gd::test_displayed_farr_eventually_matches_target_after_tween
# and test_farr_changed_signal_updates_target_farr.


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


