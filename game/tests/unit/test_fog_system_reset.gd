# Tests for FogSystem.reset() — Wave 3-Sim Track 2 sub-deliverable 4b.
#
# Contract: docs/FOG_DATA_CONTRACT.md §1 (grid schema) + Wave 3-Sim brief
# §4.2 sub-deliverable 4b (reset must clear all per-team visibility-cell data,
# clear vision-source registry, re-load FogConfig from BalanceData if needed,
# emit `[fog] reset` log per §9.M6.4).
#
# Source: game/scripts/autoload/fog_system.gd
#
# Coverage:
#   - reset() exists + is callable
#   - reset() clears _currently_visible (per-team byte grids → 0)
#   - reset() clears _ever_seen (per-team byte grids → 0)
#   - reset() clears _sources registry (next register returns handle=1)
#   - reset() is idempotent (call twice; second call has no observable effect
#     beyond a second log line)
#   - reset() re-initializes grid (grid_w + grid_h non-zero post-reset)
#   - reset() preserves the autoload's lifetime — no autoload teardown
extends GutTest

const FogSystemScript: Script = preload("res://scripts/autoload/fog_system.gd")
const _BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(256, 256))
const _CELL_SIZE: float = 4.0  # 64×64 grid

var _fog: Node


func before_each() -> void:
	_fog = FogSystemScript.new()
	_fog._init_grid(_BOUNDS, _CELL_SIZE)


func after_each() -> void:
	if is_instance_valid(_fog):
		_fog.free()


# --- Existence + shape -------------------------------------------------------

func test_reset_method_exists() -> void:
	assert_true(_fog.has_method(&"reset"),
		"FogSystem must expose reset() per Wave 3-Sim Track 2 sub-deliverable 4b")


# --- Per-team visibility grids cleared --------------------------------------

func test_reset_clears_currently_visible_grid() -> void:
	# Seed _currently_visible[team] with a non-zero byte to detect clear.
	var team_iran: int = Constants.TEAM_IRAN
	var team_idx: int = _fog._team_index(team_iran)
	var idx: int = _fog._cell_index(Vector2i(10, 10))
	_fog._currently_visible[team_idx][idx] = 1
	# Sanity: the seed actually landed.
	assert_eq(_fog._currently_visible[team_idx][idx], 1,
		"seed: _currently_visible[team][idx] should be 1 before reset")

	_fog.reset()

	# After reset, the same cell index must be 0. We re-resolve team_idx
	# because reset() re-initializes the grid via _init_grid; team layout
	# is stable so team_idx stays valid.
	assert_eq(_fog._currently_visible[team_idx][idx], 0,
		"reset() must clear _currently_visible[team] cell to 0")


func test_reset_clears_ever_seen_grid() -> void:
	# Same shape as above but for _ever_seen (which is normally append-only
	# during a match — reset is the ONLY path that clears it cross-match).
	var team_turan: int = Constants.TEAM_TURAN
	var team_idx: int = _fog._team_index(team_turan)
	var idx: int = _fog._cell_index(Vector2i(20, 20))
	_fog._ever_seen[team_idx][idx] = 1
	assert_eq(_fog._ever_seen[team_idx][idx], 1,
		"seed: _ever_seen[team][idx] should be 1 before reset")

	_fog.reset()

	assert_eq(_fog._ever_seen[team_idx][idx], 0,
		"reset() must clear _ever_seen[team] cell to 0 (cross-match memory clear)")


# --- Vision-source registry cleared ----------------------------------------

func test_reset_clears_sources_registry() -> void:
	# Register a vision source so _sources has content + _next_handle advances.
	var dummy: Node3D = Node3D.new()
	dummy.global_position = Vector3(50, 0, 50)  # Inside grid
	# Take ownership for cleanup — add_child + queue_free at after_each is
	# overkill for this isolated unit test; we own the dummy directly.
	var handle: int = _fog.register_vision_source(
		dummy, Constants.TEAM_IRAN, 3, true)
	assert_gte(handle, 1, "seed: register_vision_source returned positive handle")
	assert_eq(_fog._sources.size(), 1,
		"seed: _sources has 1 entry before reset")
	assert_gt(_fog._next_handle, 1,
		"seed: _next_handle advanced past 1 before reset")

	_fog.reset()

	assert_eq(_fog._sources.size(), 0,
		"reset() must clear _sources registry to empty")
	assert_eq(_fog._next_handle, 1,
		"reset() must reset _next_handle to 1 (fresh handle space)")

	# Verify next register returns handle=1 (proving counter actually reset)
	var fresh_dummy: Node3D = Node3D.new()
	fresh_dummy.global_position = Vector3(60, 0, 60)
	var new_handle: int = _fog.register_vision_source(
		fresh_dummy, Constants.TEAM_IRAN, 3, true)
	assert_eq(new_handle, 1,
		"first register_vision_source after reset() must return handle=1")

	dummy.free()
	fresh_dummy.free()


# --- Idempotency ------------------------------------------------------------

func test_reset_is_idempotent() -> void:
	# Two consecutive reset() calls must produce identical state. We assert
	# this by reading observable state after each call and comparing.
	_fog.reset()
	var grid_w_first: int = _fog.grid_w
	var grid_h_first: int = _fog.grid_h
	var sources_first: int = _fog._sources.size()
	var handle_first: int = _fog._next_handle

	_fog.reset()

	assert_eq(_fog.grid_w, grid_w_first,
		"reset() idempotent — grid_w stable across consecutive calls")
	assert_eq(_fog.grid_h, grid_h_first,
		"reset() idempotent — grid_h stable across consecutive calls")
	assert_eq(_fog._sources.size(), sources_first,
		"reset() idempotent — _sources size stable across consecutive calls")
	assert_eq(_fog._next_handle, handle_first,
		"reset() idempotent — _next_handle stable across consecutive calls")


# --- Grid re-initialization -------------------------------------------------

func test_reset_reinitializes_grid_with_non_zero_dimensions() -> void:
	# Whatever bounds + cell_size resolve to inside reset() (autoload fallback
	# at minimum), the resulting grid must have non-zero dimensions. This
	# guards against a regression where reset() forgets to call _init_grid.
	_fog.reset()
	assert_gt(_fog.grid_w, 0,
		"reset() must re-initialize grid: grid_w > 0")
	assert_gt(_fog.grid_h, 0,
		"reset() must re-initialize grid: grid_h > 0")
	assert_eq(_fog._currently_visible.size(), 2,  # NUM_TEAMS = 2 (Iran + Turan)
		"reset() must re-allocate _currently_visible for both teams")
	assert_eq(_fog._ever_seen.size(), 2,
		"reset() must re-allocate _ever_seen for both teams")


# --- Lifetime preservation --------------------------------------------------

func test_reset_does_not_free_the_autoload() -> void:
	# Sanity guard: reset() is a per-match state-clear, NOT a teardown. The
	# FogSystem Node itself must remain alive + reachable post-reset.
	_fog.reset()
	assert_true(is_instance_valid(_fog),
		"reset() must NOT free the FogSystem autoload itself")
