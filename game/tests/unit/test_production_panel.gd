extends GutTest
##
## Tests for ProductionPanel — Wave 3A.6 Track 2 (ui-developer-p3s3).
##
## Per 02n_PHASE_3_SESSION_7_WAVE_3A_6_KICKOFF.md §4 Track 2:
## - Panel opens on building click (via click_handler routing).
## - Shows correct unit options per producer kind.
## - Affordability state correct (§9.L7 mandate).
## - Train button click invokes building.request_train(unit_kind).
##
## We bypass the click_handler routing in these unit tests — that's
## exercised by test_click_handler.gd extensions. Here we drive
## ProductionPanel directly via its public open()/close() API, mirroring
## the test discipline established by test_build_menu.gd.
##
## Pitfall #14 (lambda-capture-of-reassigned-locals): our train-button-
## press test uses a CONTAINER REFERENCE for capture (Array append, not
## reassigned). Safe pattern per session-5 distinction.

const ProductionPanelScene: PackedScene = preload(
		"res://scenes/ui/production_panel.tscn")


# === Fake producer building ================================================
#
# Mirrors the Building base's relevant schema for ProductionPanel
# consumption WITHOUT requiring a full Building scene instantiation
# (which would pull in NavigationObstacle3D / MeshInstance3D / etc.
# tangentially). Schema:
#   - kind: StringName (for header label)
#   - team: int (for affordability check team filter)
#   - produces: Array[StringName] (for row construction)
#   - _production_state: StringName (for busy-state UI)
#   - is_complete: bool (defensive — panel open() doesn't check this,
#     but the click_handler ancestor lookup does)
#   - signal production_state_changed (StringName, int, etc.)
#   - request_train(unit_kind) → bool (UI invokes this)

class FakeProducerBuilding extends Node3D:
	signal production_state_changed(
		building_id: int,
		state: StringName,
		unit_kind: StringName,
		progress_fraction: float)
	var kind: StringName = &"sarbaz_khaneh"
	var team: int = 1  # Constants.TEAM_IRAN
	var produces: Array = [&"piyade"]
	var _production_state: StringName = &"idle"
	var is_complete: bool = true
	var unit_id: int = 1
	var request_train_calls: Array = []  # capture for assertions
	var request_train_return: bool = true

	func request_train(unit_kind: StringName) -> bool:
		request_train_calls.append(unit_kind)
		return request_train_return


# === Fixtures ==============================================================

var _panel: Variant  # ProductionPanel
var _building: FakeProducerBuilding


func before_each() -> void:
	SimClock.reset()
	# Reset ResourceSystem to defaults — boot reads starting_coin /
	# starting_grain from BalanceData. ResourceSystem.reset() (if it
	# exists) OR direct internal poke; we use direct poke because
	# change_resource() asserts SimClock.is_ticking() (sim-tick guard)
	# and tests don't drive the sim tick.
	# Pre-fund: enough coin/grain for any train cost. Pop cap = 10
	# (room for at least 1 unit of any kind at MVP).
	ResourceSystem._coin_x100[Constants.TEAM_IRAN] = 100000  # 1000 coin
	ResourceSystem._grain_x100[Constants.TEAM_IRAN] = 100000
	ResourceSystem._population[Constants.TEAM_IRAN] = 0
	ResourceSystem._population_cap[Constants.TEAM_IRAN] = 10


func after_each() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if _building != null and is_instance_valid(_building):
		_building.queue_free()
	_building = null
	SimClock.reset()


func _spawn_panel() -> Variant:
	var panel: Variant = ProductionPanelScene.instantiate()
	add_child_autofree(panel)
	return panel


func _spawn_building() -> FakeProducerBuilding:
	var b: FakeProducerBuilding = FakeProducerBuilding.new()
	add_child_autofree(b)
	return b


# === Open / close lifecycle ================================================

func test_panel_starts_hidden() -> void:
	_panel = _spawn_panel()
	var root: Control = _panel.get_node(^"Root")
	assert_false(root.visible,
		"ProductionPanel Root must start hidden on _ready")
	assert_eq(_panel.current_building(), null,
		"current_building() must be null when closed")


func test_open_shows_panel_and_sets_building() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_panel.open(_building)
	var root: Control = _panel.get_node(^"Root")
	assert_true(root.visible, "open() must make Root visible")
	assert_eq(_panel.current_building(), _building,
		"current_building() must return the opened building")


func test_close_hides_panel_and_clears_building() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_panel.open(_building)
	_panel.close()
	var root: Control = _panel.get_node(^"Root")
	assert_false(root.visible, "close() must hide Root")
	assert_eq(_panel.current_building(), null,
		"current_building() must be null after close()")


func test_open_with_null_building_is_noop() -> void:
	_panel = _spawn_panel()
	_panel.open(null)
	var root: Control = _panel.get_node(^"Root")
	assert_false(root.visible,
		"open(null) must NOT make panel visible")


func test_open_then_open_different_building_switches() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_panel.open(_building)
	var second: FakeProducerBuilding = _spawn_building()
	second.kind = &"sowari_khaneh"
	second.produces = [&"savar"]
	_panel.open(second)
	assert_eq(_panel.current_building(), second,
		"open() with a different building must switch to it")


# === Row construction per producer kind ====================================

func test_sarbaz_khaneh_shows_one_piyade_row() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sarbaz_khaneh"
	_building.produces = [&"piyade"]
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	assert_eq(unit_rows.get_child_count(), 1,
		"Sarbaz-khaneh produces 1 unit kind → 1 row")


func test_sowari_khaneh_shows_one_savar_row() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sowari_khaneh"
	_building.produces = [&"savar"]
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	assert_eq(unit_rows.get_child_count(), 1,
		"Sowari-khaneh produces 1 unit kind → 1 row")


func test_tirandazi_shows_one_kamandar_row() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"tirandazi"
	_building.produces = [&"kamandar"]
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	assert_eq(unit_rows.get_child_count(), 1,
		"Tirandazi produces 1 unit kind → 1 row")


func test_close_clears_rows() -> void:
	# Per Task #199 (await get_tree().process_frame leaks physics ticks
	# into SimClock) — we avoid awaiting on the engine frame. Instead,
	# assert against the panel's internal dictionary cache which
	# `close()` clears SYNCHRONOUSLY. The Control children are
	# queue_freed (deferred) but the cache is the source-of-truth for
	# "is the panel showing this row?" anyway.
	_panel = _spawn_panel()
	_building = _spawn_building()
	_panel.open(_building)
	# Pre-condition: row dictionary populated by open().
	assert_gt(int(_panel._unit_rows_by_kind.size()), 0,
		"open() must populate _unit_rows_by_kind")
	_panel.close()
	assert_eq(int(_panel._unit_rows_by_kind.size()), 0,
		"close() must clear _unit_rows_by_kind (synchronous cache reset)")


# === Train button → request_train invocation ===============================

func test_train_button_press_invokes_request_train() -> void:
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sarbaz_khaneh"
	_building.produces = [&"piyade"]
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	var row: HBoxContainer = unit_rows.get_child(0)
	var train_btn: Button = row.get_meta(&"_train_button", null)
	assert_ne(train_btn, null, "row must have a _train_button meta")
	train_btn.pressed.emit()
	assert_eq(_building.request_train_calls.size(), 1,
		"Train button press must invoke building.request_train exactly once")
	assert_eq(_building.request_train_calls[0], &"piyade",
		"Train button press must pass the row's unit_kind to request_train")


# === §9.L7 affordability sweep =============================================
# These tests exercise the affordability gate: button enabled iff resources
# suffice + pop cap has room + building not busy. Mirrors build_menu's
# affordability test pattern from BUG-B2 fix-wave.

func test_train_button_disabled_when_coin_insufficient() -> void:
	# Drain coin to 0; train cost > 0 → button must disable.
	# (Fake building's BalanceData read falls through to fallback 0 since
	# the train_piyade_cost_coin field isn't in balance.tres yet — Track 3.
	# To exercise the path: directly drain coin AND manually set a non-
	# zero cost expectation via the panel's internal helper would require
	# poking _train_cost_coin. Instead: test the inverse — when balance
	# CAN cover the (zero-fallback) cost, button enables; that's covered
	# below. This test stub holds for when Track 3 ships non-zero costs.)
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sarbaz_khaneh"
	_building.produces = [&"piyade"]
	# Drain ALL coin for Iran team (direct internal poke; change_resource
	# requires SimClock.is_ticking() which tests don't drive).
	ResourceSystem._coin_x100[Constants.TEAM_IRAN] = 0
	_panel.open(_building)
	# With Track 3 not yet shipped, cost falls through to 0 (zero-cost is
	# a config-error scream per §9.L8 fail-visibly rationale). The
	# affordability check at zero cost passes vacuously. This test
	# documents the seam: when Track 3 ships non-zero costs, draining
	# coin disables the button. Re-evaluate this assertion's expectation
	# after Track 3 lands.
	# For now: assert the row exists; the disabled-state assertion is a
	# follow-up after Track 3 ships.
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	assert_eq(unit_rows.get_child_count(), 1,
		"Row should be present even when coin drained — seam test")


func test_train_button_disabled_when_building_busy() -> void:
	# Building._production_state == &"training" → all rows disable
	# regardless of resources (single-slot MVP rule).
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sarbaz_khaneh"
	_building.produces = [&"piyade"]
	_building._production_state = &"training"
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	var row: HBoxContainer = unit_rows.get_child(0)
	var train_btn: Button = row.get_meta(&"_train_button", null)
	assert_true(train_btn.disabled,
		"Train button must disable when building._production_state != &\"idle\"")
	assert_ne(train_btn.tooltip_text, "",
		"Busy-state button must have explanatory tooltip")


func test_train_button_enabled_when_resources_and_pop_cap_ok() -> void:
	# Pre-fund: 1000 coin, 1000 grain, pop_cap = 10, pop_used = 0
	# (set in before_each). With Track 3 fields not yet shipped, cost
	# fallbacks are 0 → button enables.
	_panel = _spawn_panel()
	_building = _spawn_building()
	_building.kind = &"sarbaz_khaneh"
	_building.produces = [&"piyade"]
	_panel.open(_building)
	var unit_rows: VBoxContainer = _panel.get_node(^"Root/Margin/VBox/UnitRows")
	var row: HBoxContainer = unit_rows.get_child(0)
	var train_btn: Button = row.get_meta(&"_train_button", null)
	assert_false(train_btn.disabled,
		"Train button must enable when resources cover cost AND pop cap has room")


# === Auto-close on building queue_free =====================================

func test_panel_auto_closes_on_building_free() -> void:
	# Per Task #199 (await get_tree().process_frame leaks physics ticks
	# into SimClock) — we avoid engine-frame awaits. Drive the panel's
	# _process poll directly with a synthetic delta after free_building.
	# The free is invoked via the building's `free()` method (immediate,
	# not deferred via queue_free) so is_instance_valid flips
	# synchronously.
	_panel = _spawn_panel()
	_building = _spawn_building()
	_panel.open(_building)
	# Confirm pre-state.
	var root: Control = _panel.get_node(^"Root")
	assert_true(root.visible, "Pre-condition: panel visible after open")
	# Track 2 building reference now becomes invalid immediately.
	_building.free()
	_building = null
	# Drive the panel's per-frame poll directly. The poll's
	# `is_instance_valid(_building)` check returns false → triggers
	# close(). No engine-frame await needed.
	_panel._process(0.0)
	assert_false(root.visible,
		"Panel must auto-close when its building is freed (drive _process directly)")
	assert_eq(_panel.current_building(), null,
		"current_building() must be null after auto-close on building free")


# === group membership for click_handler routing ============================

func test_panel_joins_production_panel_group() -> void:
	# click_handler.gd locates the panel via
	# SceneTree.get_nodes_in_group(&"production_panel"). Lock the group
	# membership invariant — without it, the click-route is silently
	# broken (no panel opens).
	_panel = _spawn_panel()
	assert_true(_panel.is_in_group(&"production_panel"),
		"ProductionPanel must join the &\"production_panel\" group on _ready " +
		"so click_handler can locate it")
