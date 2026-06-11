# Tests for SelectionManager autoload.
#
# Contract: docs/02b_PHASE_1_KICKOFF.md §2 (7) + this session's brief —
#   - SelectionManager.select adds to selection and emits selection_changed
#   - select_only clears existing selection then selects the target
#   - deselect_all clears selection and emits an empty broadcast
#   - add_to_selection scaffolded API (Phase 1 session 2 wires Shift+click)
#   - is_selected and selection_size read accessors
#   - SelectableComponent on the unit toggles via the autoload's calls
#
# Test fixtures use a minimal "fake unit" Node3D wrapper that exposes the
# Unit-shaped surface ClickHandler and SelectionManager rely on:
#   - unit_id: int
#   - get_selectable() returning a real SelectableComponent
#   - replace_command method (no-op for these tests)
#   - command_queue field (CommandQueue stub)
#
# Going through real Unit.tscn is unnecessary for these tests; the Unit
# class is integration-tested in test_unit.gd. We test the autoload's
# state machine + signal emission contract here.
extends GutTest


const SelectableComponentScript: Script = preload(
	"res://scripts/units/components/selectable_component.gd")


# Plain-Node fake unit. Exposes the duck-typed surface SelectionManager
# expects (get_selectable, unit_id, command_queue, replace_command).
# Inherits Node3D so ring's parent expectation is satisfied.
class FakeUnit extends Node3D:
	var unit_id: int = -1
	var command_queue: Object = null  # stubbed; tests don't drive the queue here
	var _selectable: Variant = null
	var _last_replace_kind: StringName = &""
	var _last_replace_payload: Dictionary = {}
	var _replace_call_count: int = 0

	func get_selectable() -> Object:
		return _selectable

	func replace_command(kind: StringName, payload: Dictionary) -> void:
		_replace_call_count += 1
		_last_replace_kind = kind
		_last_replace_payload = payload


# Captures EventBus.selection_changed payload(s).
class SignalRecorder extends RefCounted:
	var emissions: Array = []

	func on_selection_changed(ids: Array) -> void:
		# Make a defensive copy — Godot may pass the same Array reference
		# across emissions (it shouldn't but better safe).
		var copy: Array = []
		for id in ids:
			copy.append(int(id))
		emissions.append(copy)


# Team-aware fake unit — exposes `team` so the P1 selection gate
# (_is_selectable_team) can reject non-player-team entities. Separate from
# FakeUnit (which is intentionally team-less to assert the allow-on-absent
# rule survives the gate).
class TeamedFakeUnit extends Node3D:
	var unit_id: int = -1
	var team: int = Constants.TEAM_IRAN
	var command_queue: Object = null
	var _selectable: Variant = null

	func get_selectable() -> Object:
		return _selectable

	func replace_command(_kind: StringName, _payload: Dictionary) -> void:
		pass


var _recorder: SignalRecorder
var _units: Array = []


func before_each() -> void:
	SimClock.reset()
	GameState.reset()  # player_team back to TEAM_IRAN (P1 gate SSOT)
	SelectionManager.reset()
	_recorder = SignalRecorder.new()
	# Re-connect every test so a freshly-reset autoload still sees us.
	if not EventBus.selection_changed.is_connected(_recorder.on_selection_changed):
		EventBus.selection_changed.connect(_recorder.on_selection_changed)
	_units.clear()


func after_each() -> void:
	if _recorder != null and EventBus.selection_changed.is_connected(_recorder.on_selection_changed):
		EventBus.selection_changed.disconnect(_recorder.on_selection_changed)
	_recorder = null
	# Free any spawned fake units so the global SelectionManager doesn't keep
	# stale references around for the next test.
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	SelectionManager.reset()
	GameState.reset()
	SimClock.reset()


# Construct a team-aware fake unit with a real SelectableComponent attached.
func _make_teamed_unit(uid: int, team: int) -> TeamedFakeUnit:
	var u: TeamedFakeUnit = TeamedFakeUnit.new()
	u.unit_id = uid
	u.team = team
	add_child_autofree(u)
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


# Construct a fake unit with a real SelectableComponent attached. Adds it to
# the scene so the component's _ready (which subscribes to EventBus and
# creates its ring) actually runs.
func _make_unit(uid: int) -> FakeUnit:
	var u: FakeUnit = FakeUnit.new()
	u.unit_id = uid
	add_child_autofree(u)
	# Attach a real SelectableComponent so select()/deselect() route
	# through the same code path the production Unit takes.
	var sc: Variant = SelectableComponentScript.new()
	sc.unit_id = uid
	u.add_child(sc)
	u._selectable = sc
	_units.append(u)
	return u


# ===========================================================================
# select()
# ===========================================================================

func test_select_adds_unit_to_selection() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	assert_eq(SelectionManager.selection_size(), 1,
		"select() must add the unit to the selection set")
	assert_true(SelectionManager.is_selected(u),
		"is_selected() must report true after select()")


func test_select_emits_selection_changed_with_unit_id() -> void:
	var u: FakeUnit = _make_unit(42)
	SelectionManager.select(u)
	assert_eq(_recorder.emissions.size(), 1,
		"select() must emit selection_changed exactly once")
	assert_eq(_recorder.emissions[0], [42],
		"signal payload must contain the selected unit_id")


func test_select_calls_select_on_selectable_component() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	# The SelectableComponent's is_selected reflects the toggle.
	assert_true(u._selectable.is_selected,
		"SelectableComponent.is_selected must be true after SelectionManager.select()")


func test_select_is_idempotent() -> void:
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	SelectionManager.select(u)  # re-select same unit — should no-op
	assert_eq(SelectionManager.selection_size(), 1,
		"select() of an already-selected unit must be idempotent")
	assert_eq(_recorder.emissions.size(), 1,
		"re-selecting the same unit must NOT emit a second signal")


func test_select_null_is_safe_noop() -> void:
	SelectionManager.select(null)
	assert_eq(SelectionManager.selection_size(), 0,
		"select(null) must be a safe no-op")
	assert_eq(_recorder.emissions.size(), 0,
		"select(null) must not emit a signal")


# ===========================================================================
# select_only()
# ===========================================================================

func test_select_only_replaces_existing_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	_recorder.emissions.clear()  # ignore the first emission
	SelectionManager.select_only(b)
	assert_eq(SelectionManager.selection_size(), 1,
		"select_only must clear existing selection")
	assert_true(SelectionManager.is_selected(b),
		"select_only target must be in selection")
	assert_false(SelectionManager.is_selected(a),
		"previously-selected unit must be deselected by select_only")


func test_select_only_deselects_old_unit_visual() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select_only(b)
	assert_false(a._selectable.is_selected,
		"old unit's SelectableComponent must be deselected by select_only")
	assert_true(b._selectable.is_selected,
		"new unit's SelectableComponent must be selected by select_only")


func test_select_only_emits_signal_exactly_once() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.select_only(b)
	assert_eq(_recorder.emissions.size(), 1,
		"select_only must emit selection_changed exactly once (single-broadcast contract)")
	assert_eq(_recorder.emissions[0], [2],
		"signal payload must contain only the new target")


func test_select_only_with_null_clears_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.select_only(null)
	assert_eq(SelectionManager.selection_size(), 0,
		"select_only(null) clears the selection (deselect-all semantics)")
	assert_eq(_recorder.emissions.size(), 1,
		"select_only(null) emits once")
	assert_eq(_recorder.emissions[0], [],
		"select_only(null) emits empty list")


# ===========================================================================
# deselect_all()
# ===========================================================================

func test_deselect_all_clears_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	SelectionManager.deselect_all()
	assert_eq(SelectionManager.selection_size(), 0,
		"deselect_all clears the selection set")
	assert_false(a._selectable.is_selected,
		"every previously-selected unit's component must be deselected")


func test_deselect_all_emits_empty_broadcast() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.deselect_all()
	assert_eq(_recorder.emissions.size(), 1,
		"deselect_all emits selection_changed exactly once")
	assert_eq(_recorder.emissions[0], [],
		"deselect_all emits an empty list")


func test_deselect_all_on_empty_set_still_emits() -> void:
	# This is an explicit choice (documented in source) — deselect_all on an
	# already-empty set still emits the empty broadcast so consumers re-render.
	SelectionManager.deselect_all()
	assert_eq(_recorder.emissions.size(), 1,
		"deselect_all on empty selection still broadcasts")


# ===========================================================================
# add_to_selection() — Phase 1 session 2 hook (API exists, ring scaffolded now)
# ===========================================================================

func test_add_to_selection_extends_selection() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.add_to_selection(b)
	assert_eq(SelectionManager.selection_size(), 2,
		"add_to_selection adds without clearing")
	assert_true(SelectionManager.is_selected(a))
	assert_true(SelectionManager.is_selected(b))


# ===========================================================================
# Lifecycle / freed units
# ===========================================================================

func test_freed_units_are_filtered_from_selection_size() -> void:
	var a: FakeUnit = _make_unit(1)
	var b: FakeUnit = _make_unit(2)
	SelectionManager.select(a)
	SelectionManager.select(b)
	a.queue_free()
	# Wait for the queued free.
	await get_tree().process_frame
	# selection_size filters freed units defensively.
	assert_eq(SelectionManager.selection_size(), 1,
		"freed units must not be counted in selection_size")


func test_reset_clears_selection_without_emitting() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	_recorder.emissions.clear()
	SelectionManager.reset()
	assert_eq(SelectionManager.selection_size(), 0,
		"reset() clears the selection set")
	assert_eq(_recorder.emissions.size(), 0,
		"reset() does NOT emit (per source contract — use deselect_all for the broadcast)")


# ===========================================================================
# selected_units accessor (returns a fresh copy; safe to iterate)
# ===========================================================================

func test_selected_units_returns_a_copy() -> void:
	var a: FakeUnit = _make_unit(1)
	SelectionManager.select(a)
	var sel: Array = SelectionManager.selected_units
	assert_eq(sel.size(), 1)
	# Mutating the returned array must not affect the autoload's state.
	sel.clear()
	assert_eq(SelectionManager.selection_size(), 1,
		"selected_units returns a fresh copy; mutating it must not leak")


# ===========================================================================
# P1 team gate (live playtest 2026-06-11) — non-player-team units are NOT
# selectable. Canonical seam: enemy can't be selected → enemy can't be
# commanded (the live bug had a Turan unit selected then ordered to attack the
# player's own worker).
# ===========================================================================

func test_select_rejects_enemy_team_unit() -> void:
	# Regression (a): an enemy (TEAM_TURAN) unit must NOT enter selection via
	# select(). GameState.player_team is TEAM_IRAN by default.
	var enemy: TeamedFakeUnit = _make_teamed_unit(1, Constants.TEAM_TURAN)
	SelectionManager.select(enemy)
	assert_eq(SelectionManager.selection_size(), 0,
		"enemy-team unit must be rejected by select()")
	assert_false(SelectionManager.is_selected(enemy))
	assert_eq(_recorder.emissions.size(), 0,
		"rejected enemy select() must not emit selection_changed")


func test_select_accepts_player_team_unit() -> void:
	var ally: TeamedFakeUnit = _make_teamed_unit(1, Constants.TEAM_IRAN)
	SelectionManager.select(ally)
	assert_eq(SelectionManager.selection_size(), 1,
		"player-team unit must be selectable")
	assert_true(SelectionManager.is_selected(ally))


func test_select_only_on_enemy_deselects_all() -> void:
	# Single-click on an enemy must NOT select it; it deselects (matches the
	# left-click-on-terrain semantics — clicking something unselectable clears
	# the current selection).
	var ally: TeamedFakeUnit = _make_teamed_unit(1, Constants.TEAM_IRAN)
	var enemy: TeamedFakeUnit = _make_teamed_unit(2, Constants.TEAM_TURAN)
	SelectionManager.select(ally)
	_recorder.emissions.clear()
	SelectionManager.select_only(enemy)
	assert_eq(SelectionManager.selection_size(), 0,
		"select_only(enemy) deselects all instead of selecting the enemy")
	assert_false(SelectionManager.is_selected(enemy))
	assert_false(SelectionManager.is_selected(ally))


func test_add_to_selection_rejects_enemy() -> void:
	# add_to_selection delegates to select(), so the gate applies — an enemy
	# cannot be Shift+clicked into an existing selection.
	var ally: TeamedFakeUnit = _make_teamed_unit(1, Constants.TEAM_IRAN)
	var enemy: TeamedFakeUnit = _make_teamed_unit(2, Constants.TEAM_TURAN)
	SelectionManager.select(ally)
	SelectionManager.add_to_selection(enemy)
	assert_eq(SelectionManager.selection_size(), 1,
		"add_to_selection must reject an enemy (gate inherited from select())")
	assert_true(SelectionManager.is_selected(ally))
	assert_false(SelectionManager.is_selected(enemy))


func test_team_gate_follows_game_state_player_team() -> void:
	# The gate reads GameState.player_team (SSOT) — flipping the player team to
	# Turan makes Turan units selectable and Iran units rejected.
	GameState.player_team = Constants.TEAM_TURAN
	var iran: TeamedFakeUnit = _make_teamed_unit(1, Constants.TEAM_IRAN)
	var turan: TeamedFakeUnit = _make_teamed_unit(2, Constants.TEAM_TURAN)
	SelectionManager.select(iran)
	assert_eq(SelectionManager.selection_size(), 0,
		"with player_team=Turan, an Iran unit is the enemy and is rejected")
	SelectionManager.select(turan)
	assert_true(SelectionManager.is_selected(turan),
		"with player_team=Turan, a Turan unit is selectable")


func test_team_less_fixture_still_selectable() -> void:
	# The allow-on-absent rule: a unit WITHOUT a `team` field passes the gate
	# (preserves the team-less FakeUnit fixtures + non-team selectables).
	var u: FakeUnit = _make_unit(1)
	SelectionManager.select(u)
	assert_eq(SelectionManager.selection_size(), 1,
		"team-less fixture must remain selectable (allow-on-absent)")
