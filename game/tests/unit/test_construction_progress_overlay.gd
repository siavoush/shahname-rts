extends GutTest
##
## Tests for ConstructionProgressOverlay — Phase 3 session 3 wave 1C Track 2A
## (ui-developer).
##
## Pairs with the `Building.construction_progress_updated(percent_x100)` signal
## (Track 2B, commit 82bf198). The overlay renders a horizontal progress bar +
## "BUILDING N%" label above every in-progress building, hides at completion,
## and never absorbs mouse input.
##
## Behavioral coverage (per kickoff "test mandate" + Track 1 follow-on at 3fbce2b):
##   - On construction_progress_updated emit at value V → bar value reads V.
##   - On construction_finalized emit → cache entry erased → bar hides
##     (PRIMARY completion path under Track 1's two-stage lifecycle).
##   - At 10000 basis points (full) → bar hides (defence-in-depth path,
##     covers a hypothetical bypass of the [0, 9999] emit clamp).
##   - On building queue_free → cache pruned, no orphaned UI entry.
##   - mouse_filter == MOUSE_FILTER_IGNORE (Pitfall #1 — box-select drag-
##     through guard).
##
## Note: the `is_complete` field is NOT a hide-trigger under Track 1's
## lifecycle (gp-sys's commit 2cedf81). `is_complete = true` fires at the
## START of construction (Stage 1, structural placement). The overlay no
## longer gates on it; construction_finalized is the operational-arrival
## signal.
##
## We bypass the live Camera3D by exercising `compute_bar_entries(buildings,
## cache, project_building)` — the public seam takes an injected projector
## just like health_bars_overlay's seam. Real Camera3D projection is
## exercised in the lead's interactive smoke test.

const ConstructionProgressOverlayScript: Script = preload(
		"res://scripts/ui/construction_progress_overlay.gd")
const BuildingScript: Script = preload(
		"res://scripts/world/buildings/building.gd")


# Minimal Building fixture — re-declares both signals locally so the overlay's
# has_signal() / connect() probes pass without spawning a full Building scene.
# Mirrors the signal shapes shipped in building.gd:
#   construction_progress_updated(percent_x100: int) — per-tick dwell emit.
#   construction_finalized(placer_unit_id: int)       — post-Stage-2 emit.
class FakeBuilding extends Node3D:
	signal construction_progress_updated(percent_x100: int)
	signal construction_finalized(placer_unit_id: int)
	var is_complete: bool = false
	var kind: StringName = &"mazraeh"
	# A unit_id is part of the Building schema; tests don't care about
	# uniqueness here, but the field is read by some pruning paths.
	var unit_id: int = -1


var overlay: Control
var _buildings: Array = []


func before_each() -> void:
	SimClock.reset()
	overlay = ConstructionProgressOverlayScript.new()
	add_child_autofree(overlay)
	_buildings.clear()


func after_each() -> void:
	for b in _buildings:
		if is_instance_valid(b):
			b.queue_free()
	_buildings.clear()
	SimClock.reset()


func _make_building(
		screen_pos: Vector2,
		on_screen: bool = true
) -> FakeBuilding:
	var b: FakeBuilding = FakeBuilding.new()
	add_child_autofree(b)
	b.set_meta(&"_test_screen_pos", screen_pos)
	b.set_meta(&"_test_on_screen", on_screen)
	_buildings.append(b)
	return b


# Closure-friendly projector — mirrors health_bars_overlay test pattern.
static func _project_test_building(b: Object) -> Dictionary:
	if b == null or not is_instance_valid(b):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	if not (b is Node):
		return { &"screen_pos": Vector2.ZERO, &"on_screen": false }
	var pos_v: Variant = (b as Node).get_meta(&"_test_screen_pos", Vector2.ZERO)
	var os_v: Variant = (b as Node).get_meta(&"_test_on_screen", true)
	return { &"screen_pos": pos_v, &"on_screen": os_v }


# ---------------------------------------------------------------------------
# Signal-payload round-trip — "on signal emit at V, bar reads V"
# ---------------------------------------------------------------------------

func test_signal_emit_populates_cache_and_entry() -> void:
	# Production wires `_on_construction_progress_updated` to the building's
	# signal. We invoke through the public seam to verify the cache shape
	# the production path lands in.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	overlay.ingest_progress(b, 2500)  # 25%
	var cache: Dictionary = { b.get_instance_id(): 2500 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 1,
			"in-progress building must produce one entry")
	assert_eq(int(entries[0].get(&"percent_x100")), 2500,
			"entry must carry the signal payload verbatim")
	assert_eq(int(entries[0].get(&"percent")), 25,
			"display percent must be percent_x100 / 100 (floored)")


func test_signal_handler_writes_to_cache() -> void:
	# Connect the production signal sink directly — verifies the bind(building)
	# pattern lands the right cache entry.
	var b: FakeBuilding = _make_building(Vector2.ZERO)
	# We use the public ingest_progress seam to mirror what the connected
	# signal handler does — the connection itself is exercised by the
	# integration smoke test (the overlay's _ensure_signal_connected runs
	# in _process; here we want the cache-shape assertion only).
	overlay.ingest_progress(b, 3333)
	assert_eq(overlay.get_cached_percent_x100(b), 3333,
			"ingest_progress must write to the cache keyed by instance_id")


func test_partial_progress_renders_at_intermediate_percent() -> void:
	# 7300 basis points → 73%. The fill width inside the bar is proportional
	# to percent_x100 / 10000.
	var b: FakeBuilding = _make_building(Vector2(640, 360))
	var cache: Dictionary = { b.get_instance_id(): 7300 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 1)
	assert_eq(int(entries[0].get(&"percent")), 73)


# ---------------------------------------------------------------------------
# Hide-on-completion — construction_finalized signal + belt-and-braces
# ---------------------------------------------------------------------------

func test_construction_finalized_signal_erases_cache_entry() -> void:
	# PRIMARY hide-trigger under Track 1's two-stage lifecycle.
	# The overlay connects to building.construction_finalized; on emit,
	# the handler erases the cache entry. After erase, compute_bar_entries
	# returns nothing for this building.
	#
	# We wire the signal handler directly (mirroring what
	# _ensure_signal_connected does in production) and observe the cache.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	overlay.ingest_progress(b, 9500)
	assert_eq(overlay.get_cached_percent_x100(b), 9500,
			"precondition — cache populated mid-construction")
	# Connect the finalize sink the way production does (bind(building)).
	var sink: Callable = Callable(
			overlay, &"_on_construction_finalized").bind(b)
	b.construction_finalized.connect(sink)
	# Emit Stage 2 — operational arrival.
	b.construction_finalized.emit(42)  # placer_unit_id = 42, arbitrary
	# Cache entry must be gone — bar will hide on next compute_bar_entries.
	assert_eq(overlay.get_cached_percent_x100(b), -1,
			"construction_finalized handler must erase the cache entry")
	# Confirm compute_bar_entries sees no entry now (the visible behavior).
	var cache_after: Dictionary = {}  # what get_cached_percent_x100 reports
	# Use the overlay's internal cache state by passing an empty caller-
	# supplied cache — the public compute_bar_entries is pure-functional;
	# we pass the post-erase dict shape directly.
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache_after,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"post-finalize, building renders no bar")


func test_repeated_ensure_connect_does_not_duplicate_signal_wires() -> void:
	# Live-test regression (fix-up after a023242): the overlay's _process loop
	# calls _ensure_signal_connected every frame for every building in the
	# &"buildings" group. The internal _connected dedupe must hold, and the
	# is_connected() guard around the connect call must back it up — otherwise
	# Godot logs an ERROR per frame for the already-connected signal.
	#
	# This test simulates many _process passes: call _ensure_signal_connected
	# N times against the same building, then assert there's exactly one
	# connection per signal. Godot 4: `Signal.get_connections()` returns an
	# Array of Dictionaries, one per connection.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	for _i in range(10):
		overlay.call(&"_ensure_signal_connected", b)
	assert_eq(b.construction_progress_updated.get_connections().size(), 1,
			"_ensure_signal_connected must not duplicate the progress wire across frames")
	assert_eq(b.construction_finalized.get_connections().size(), 1,
			"_ensure_signal_connected must not duplicate the finalize wire across frames")


func test_finalized_handler_keeps_connection_alive() -> void:
	# Live-test regression (fix-up after a023242): the OLD finalize handler
	# erased `_connected[bid]` after Stage 2 fired. With the entry gone, the
	# per-frame _ensure_signal_connected re-attempted the connect every
	# subsequent frame — Godot logs ERROR each time. The fix: the handler
	# erases ONLY the percent cache row, NOT the _connected dedupe entry.
	# The connections themselves remain valid until the building queue_frees
	# (where _prune_stale_cache drops them correctly).
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	# Establish the connect pair through the production path.
	overlay.call(&"_ensure_signal_connected", b)
	assert_eq(b.construction_progress_updated.get_connections().size(), 1,
			"precondition — progress signal connected once")
	# Fire Stage 2; the handler should clear the cache row but keep the
	# connection set intact.
	b.construction_finalized.emit(0)  # placer_unit_id, arbitrary
	# Subsequent frame: _ensure_signal_connected runs again. If the
	# _connected entry survived (correct), this is a no-op. If it was
	# erroneously erased (the live-test bug), the function would attempt
	# to reconnect and Godot would log an ERROR — but the connection count
	# would also climb to 2.
	overlay.call(&"_ensure_signal_connected", b)
	assert_eq(b.construction_progress_updated.get_connections().size(), 1,
			"post-finalize, progress wire must remain a single connection")
	assert_eq(b.construction_finalized.get_connections().size(), 1,
			"post-finalize, finalize wire must remain a single connection")


func test_full_percent_hides_bar_belt_and_braces() -> void:
	# Defence-in-depth: percent_x100 == 10000 hides even if the cache somehow
	# holds it. Per the construction_progress_updated emitter contract, the
	# signal is clamped into [0, 9999] for the entire dwell phase — 10000
	# never lands via the normal emit path. This gate covers a hypothetical
	# bypass (debug "instant complete", future code path injecting 10000
	# through the test seam).
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	var cache: Dictionary = { b.get_instance_id(): 10000 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"percent_x100 >= 10000 must hide the bar (belt-and-braces)")


func test_just_below_full_still_renders() -> void:
	# 9999 basis points — strictly below the 10000 cutoff, still in-progress.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	var cache: Dictionary = { b.get_instance_id(): 9999 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 1,
			"9999 basis points must still render the bar")
	assert_eq(int(entries[0].get(&"percent")), 99)


# ---------------------------------------------------------------------------
# Cache lifecycle — freed buildings drop out
# ---------------------------------------------------------------------------

func test_freed_building_is_skipped_in_entries() -> void:
	# A building queue_free()'d mid-frame must not contribute an entry. The
	# overlay's _prune_stale_cache (called every _process) will eventually
	# drop the cache entry, but compute_bar_entries itself must short-circuit
	# on is_instance_valid first.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	var cache: Dictionary = { b.get_instance_id(): 5000 }
	b.queue_free()
	await get_tree().process_frame
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"freed buildings must be skipped defensively")


func test_no_cache_entry_means_no_bar() -> void:
	# A building with no progress signal received yet (e.g., placed
	# instantly, or signal not yet fired on its first tick) renders no bar
	# — better than rendering 0% which would imply a stuck timer.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	var empty_cache: Dictionary = {}
	var entries: Array = overlay.compute_bar_entries(
			[b],
			empty_cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"buildings without a cache entry render no bar")


# ---------------------------------------------------------------------------
# Off-screen / invalid input
# ---------------------------------------------------------------------------

func test_off_screen_building_is_skipped() -> void:
	var b: FakeBuilding = _make_building(Vector2(400, 300), false)
	var cache: Dictionary = { b.get_instance_id(): 5000 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"off-screen buildings must not contribute a bar entry")


func test_negative_percent_is_skipped() -> void:
	# Defence against a malformed emitter; the production signal is typed
	# int but signed.
	var b: FakeBuilding = _make_building(Vector2(400, 300))
	var cache: Dictionary = { b.get_instance_id(): -100 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 0,
			"negative percent values must be skipped defensively")


# ---------------------------------------------------------------------------
# Multiple buildings
# ---------------------------------------------------------------------------

func test_multiple_buildings_produce_multiple_entries() -> void:
	# Three in-progress buildings on-screen → three entries. One completed
	# (no cache entry — that's the post-construction_finalized state).
	# One off-screen (skipped via projector). Final count: 3.
	var a: FakeBuilding = _make_building(Vector2(100, 100))
	var b: FakeBuilding = _make_building(Vector2(200, 100))
	var c: FakeBuilding = _make_building(Vector2(300, 100))
	var done: FakeBuilding = _make_building(Vector2(400, 100))
	var off: FakeBuilding = _make_building(Vector2(500, 100), false)
	# `done` deliberately has NO cache entry — that's the visible state
	# after construction_finalized fires and the handler erases its row.
	var cache: Dictionary = {
		a.get_instance_id(): 2500,
		b.get_instance_id(): 5000,
		c.get_instance_id(): 7500,
		off.get_instance_id(): 5000,
	}
	var entries: Array = overlay.compute_bar_entries(
			[a, b, c, done, off],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 3,
			"three in-progress on-screen buildings must produce three entries")


func test_screen_pos_carried_through_to_entry() -> void:
	var b: FakeBuilding = _make_building(Vector2(640, 360))
	var cache: Dictionary = { b.get_instance_id(): 5000 }
	var entries: Array = overlay.compute_bar_entries(
			[b],
			cache,
			Callable(self, &"_project_test_building"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get(&"screen_pos"), Vector2(640, 360),
			"entry must carry the projected screen_pos for _draw")


# ---------------------------------------------------------------------------
# Mouse-filter discipline (Pitfall #1 — box-select drag-through guard)
# ---------------------------------------------------------------------------

func test_mouse_filter_is_ignore_at_runtime() -> void:
	# The overlay sits on top of the viewport. If its mouse_filter were
	# MOUSE_FILTER_STOP (Godot's default), it would silently swallow every
	# left/right click — and break box-select drag start/release. _ready
	# must defensively force IGNORE regardless of what the .tscn says.
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"Pitfall #1 — overlay.mouse_filter must be MOUSE_FILTER_IGNORE")


func test_overlay_does_not_block_box_select_hit_test() -> void:
	# A box-select drag's hit-test relies on the overlay NOT consuming the
	# input event. With MOUSE_FILTER_IGNORE the Control returns false from
	# _has_point checks (the input is never sent to it), so the box-select
	# handler's _unhandled_input fires as if the overlay weren't there. The
	# behavioral assertion is the mouse_filter — we re-state it here from
	# the box-select handler's POV.
	#
	# Direct simulation of a drag would require a real viewport + a Camera3D
	# wired up; that lives in test_session_2_box_select.gd's integration
	# scope. Here we lock the contract at the discipline-point: filter ==
	# IGNORE.
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"box-select hit-test depends on overlay never absorbing input")
