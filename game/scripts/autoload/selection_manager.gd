extends Node
##
## SelectionManager — the authoritative current-selection set, autoloaded.
##
## Phase 1 session 1 wave 2 (ui-developer). Per docs/02b_PHASE_1_KICKOFF.md §2 (7).
##
## Responsibilities:
##   - Track which Unit instances are currently selected.
##   - Broadcast changes via EventBus.selection_changed(selected_unit_ids: Array).
##   - Toggle each unit's SelectableComponent visual state via select() / deselect().
##
## Design / scope:
##   - Phase 1 session 1 (this wave) wires only the API plus single-click selection
##     via the click handler. Multi-select (box-drag, Shift+click, Ctrl+groups) is
##     Phase 1 session 2.
##   - The shape `select / select_only / deselect_all / add_to_selection` is the
##     full long-term API surface; `add_to_selection` ships now (so session 2
##     doesn't have to retrofit) but is not yet wired to any input.
##   - State lives only here. SelectableComponent listens to the broadcast and
##     mirrors per-unit visual state from it. Two writers + one signal would be
##     a synchronization-bug factory; the pattern is single-writer (this autoload),
##     many-readers (every SelectableComponent).
##
## Sim Contract §1.5 fit:
##   Selection is UI state, not simulation state. EventBus.selection_changed is
##   read-shaped — it does NOT appear in EventBus._SINK_SIGNALS, the L2 lint
##   allowlist exempts it from the no-emit-from-_process rule, and its emission
##   from _input/_unhandled_input is explicitly allowed. The simulation tick
##   pipeline neither produces nor consumes the signal. Per Sim Contract §3.4,
##   SpatialIndex queries from _input are read-safe between ticks — the click
##   handler relies on that for raycasting. This file does not call the spatial
##   index directly; the click handler is the consumer.
##
## Per-unit lifetime:
##   Units exiting the tree (queue_free) silently disappear from _selected_units
##   on the next state-mutation call (we filter !is_instance_valid before
##   broadcasting). We do NOT eagerly subscribe to tree_exiting because that
##   would couple this autoload to every spawned Unit. The lazy filter is cheap
##   (selection sets are tiny — typically 1, never more than 200) and it keeps
##   the autoload independent.
##
## Why an autoload and not a Node in main.tscn:
##   Many systems (UI, input handler, future hotkey rebinder, control-group
##   manager, hover tooltip, build menu) need read access to the current
##   selection. An autoload guarantees a single global instance with a stable
##   path. Sim-side consumers should use EventBus.selection_changed instead of
##   reading this autoload directly so the dependency is a signal, not a
##   global lookup.

# ============================================================================
# State
# ============================================================================

## Currently-selected units. Stored as Variant in an untyped Array because the
## class_name registry race (docs/ARCHITECTURE.md §6 v0.4.0) makes a typed
## `Array[Unit]` annotation brittle when this autoload parses before the global
## class_name registry is populated. Concrete entries are always Unit instances.
var _selected_units: Array = []


## Public read-only accessor for the current selection. Returns a fresh shallow
## copy so callers can iterate safely without observing concurrent mutations.
## Filters out freed units defensively.
var selected_units: Array:
	get:
		var live: Array = []
		for u in _selected_units:
			if is_instance_valid(u):
				live.append(u)
		return live


# ============================================================================
# Team gate (P1 — live playtest 2026-06-11)
# ============================================================================

## P1 BLOCKER fix (live playtest 2026-06-11): enemy units were selectable and
## therefore COMMANDABLE — a Turan piyade got selected via the click-tolerance
## fallback, then the player's right-click issued an attack command TO the enemy
## unit, which killed the player's own Kargar on the player's order.
##
## Root cause was an INCONSISTENCY: box-select (box_select_handler.gd) and
## double-click-select (double_click_select.gd) were already Iran-only (they
## filter candidates to `team == TEAM_IRAN` during the scene walk), but
## single-click and the tolerance fallback routed straight to select_only()
## with NO team check. SelectionManager is the ONE canonical seam every input
## path funnels through (single-click, box, double-click, control-group bind via
## the snapshot of selected_units, attack-move arming via selection_size) — so
## gating HERE makes all paths consistent without scattering has_method/team
## guards at every call site (forbidden by STUDIO_PROCESS §9.M7).
##
## Consequences that fall out automatically (no separate guard needed):
##   - ControlGroups.bind snapshots selected_units → can never capture an enemy.
##   - AttackMoveHandler arms on selection_size>0 and dispatches to
##     selected_units → can never arm with / command an enemy.
##
## Gate semantics: a unit is rejected only when it HAS a `team` field whose
## value differs from GameState.player_team. A unit with NO `team` field passes
## through unchanged (test fixtures / non-team selectables) — this preserves the
## defensive duck-typing convention used throughout the input layer and avoids
## breaking the team-less FakeUnit fixtures in test_selection_manager.gd.
func _is_selectable_team(unit: Object) -> bool:
	if unit == null:
		return false
	# No team field → not a team entity; allow (preserves prior behavior for
	# team-less fixtures). Enemy units always carry a `team` field.
	if not (&"team" in unit):
		return true
	var unit_team: int = int(unit.get(&"team"))
	if unit_team == GameState.player_team:
		return true
	# Rejection branch — loud observability log (no silent no-ops; N=8 incident
	# history, observability rule). P1 live playtest 2026-06-11.
	var uid_v: Variant = unit.get(&"unit_id")
	print("[selection] REJECT non-player-team unit id=", uid_v,
		" team=", unit_team, " (player_team=", GameState.player_team,
		") — not selectable")
	return false


# ============================================================================
# Public API
# ============================================================================

## Add `unit` to the selection set. Idempotent — re-selecting an already-
## selected unit is a no-op (no signal re-emission).
##
## Calls `unit.get_selectable().select()` for the immediate per-unit visual
## update, AND emits EventBus.selection_changed so any other SelectableComponent
## listeners (or future overlay/HUD code) can mirror state from the broadcast.
## The dual-path ensures the source unit's ring lights up the same frame even
## if its component happens to be paused/disconnected for any reason.
func select(unit: Object) -> void:
	if unit == null:
		return
	if not is_instance_valid(unit):
		return
	# P1 (live playtest 2026-06-11): reject non-player-team units at the
	# canonical seam so no input path can select (and thus command) an enemy.
	if not _is_selectable_team(unit):
		return
	# Idempotency: already selected → no-op (avoids signal storms on rapid clicks).
	for existing in _selected_units:
		if existing == unit:
			return
	_selected_units.append(unit)
	_call_selectable(unit, &"select")
	_broadcast()


## Replace the selection set with exactly `unit`. Used for left-click-no-modifier
## "click on unit X = X is the only thing selected." Clears whatever was previously
## selected (deselecting their components), then selects the new target. Always
## emits the signal exactly once (single-broadcast contract for the input layer).
func select_only(unit: Object) -> void:
	if unit == null or not is_instance_valid(unit):
		# Treat as a deselect-all — clicking on null/freed unit shouldn't leave
		# stale state in the selection set.
		deselect_all()
		return
	# P1 (live playtest 2026-06-11): single-click on a non-player-team unit must
	# NOT enter selection. We deselect-all to match the documented left-click-
	# on-terrain semantics (clicking something you can't select clears the
	# current selection) — consistent feel, no commandable enemy. The rejection
	# is logged inside _is_selectable_team.
	if not _is_selectable_team(unit):
		deselect_all()
		return
	# Deselect everyone EXCEPT the target (so the target keeps its ring on
	# instead of flickering through deselect → select).
	var preserved: bool = false
	for existing in _selected_units:
		if not is_instance_valid(existing):
			continue
		if existing == unit:
			preserved = true
			continue
		_call_selectable(existing, &"deselect")
	_selected_units.clear()
	if not preserved:
		_call_selectable(unit, &"select")
	_selected_units.append(unit)
	_broadcast()


## Add `unit` to the existing selection set. Reserved for Shift+click in
## Phase 1 session 2; the API ships now so input handlers can call it without
## a future refactor. Functionally identical to `select()` today — kept as a
## distinct method so a future change (e.g., max-selection cap) only touches
## one path.
func add_to_selection(unit: Object) -> void:
	select(unit)


## Clear the entire selection set. Calls deselect on each previously-selected
## unit's SelectableComponent and emits an empty-list broadcast. Idempotent —
## calling on an already-empty set still emits an empty broadcast (so HUD/overlay
## consumers re-render their "nothing selected" state if they missed an earlier
## emission for any reason).
##
## Single-broadcast contract: emits EventBus.selection_changed exactly once
## per call, regardless of how many units were selected.
func deselect_all() -> void:
	for existing in _selected_units:
		if is_instance_valid(existing):
			_call_selectable(existing, &"deselect")
	_selected_units.clear()
	_broadcast()


## True iff `unit` is currently selected. Used by tests and by future input
## handlers (e.g., Shift+click toggling).
func is_selected(unit: Object) -> bool:
	if unit == null:
		return false
	for existing in _selected_units:
		if existing == unit:
			return true
	return false


## Number of currently-selected units (filters out freed entries on the read).
func selection_size() -> int:
	var n: int = 0
	for u in _selected_units:
		if is_instance_valid(u):
			n += 1
	return n


# ============================================================================
# Internals
# ============================================================================

## Build the broadcast payload (Array of unit_ids), filtering freed units, and
## emit EventBus.selection_changed exactly once.
##
## Per the read-shaped signal carve-out (Sim Contract §1.5 + L2 allowlist),
## emission from _input / _unhandled_input contexts is allowed. This method
## does not check tick state.
func _broadcast() -> void:
	var ids: Array = []
	# Compact in-place: prune freed entries while we collect the broadcast list.
	var live: Array = []
	for u in _selected_units:
		if not is_instance_valid(u):
			continue
		live.append(u)
		var uid_v: Variant = u.get(&"unit_id")
		if uid_v != null:
			ids.append(int(uid_v))
	_selected_units = live
	EventBus.selection_changed.emit(ids)


## Best-effort call to a unit's SelectableComponent method. Untyped to dodge
## the class_name registry race; we duck-type via has_method.
func _call_selectable(unit: Object, method: StringName) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	# Prefer the typed accessor on Unit if present (covers the production path).
	if unit.has_method(&"get_selectable"):
		var sc: Object = unit.call(&"get_selectable")
		if sc != null and is_instance_valid(sc) and sc.has_method(method):
			sc.call(method)
			return
	# Fallback: maybe the unit IS the selectable component directly (test fixtures).
	if unit.has_method(method):
		unit.call(method)


# ============================================================================
# Test / lifecycle helpers
# ============================================================================

## Reset to pristine state. Mirrors the pattern used by other autoloads
## (SimClock.reset, GameState.reset, FarrSystem.reset, SpatialIndex.reset).
## Called by MatchHarness teardown and by GUT before_each / after_each for
## tests that touch the selection.
##
## Does NOT emit a final empty broadcast — callers that want the broadcast
## should call deselect_all() instead. The intent of reset() is "wipe state
## without side effects" so test setup/teardown doesn't pollute signal counts.
func reset() -> void:
	_selected_units.clear()
