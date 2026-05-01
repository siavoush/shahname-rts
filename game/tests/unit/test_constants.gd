# Tests for Constants autoload.
#
# Contract: docs/TESTING_CONTRACT.md §1.1 and 02_IMPLEMENTATION_PLAN.md §2 —
# Constants holds STRUCTURAL keys/enums only (no tunable gameplay numbers).
# These tests are intentionally small — they verify the autoload exists, the
# values match the contract, and the phase/team conventions used by other
# subsystems are correct.
extends GutTest


# -- Existence and shape ------------------------------------------------------

func test_constants_autoload_is_reachable() -> void:
	# Constants is registered in project.godot as a singleton autoload; the
	# global identifier should resolve here without import.
	assert_not_null(Constants, "Constants autoload must be reachable")


# -- Phase StringNames match SimClock canonical order ------------------------

func test_phases_array_matches_sim_clock() -> void:
	# Constants.PHASES must equal SimClock.PHASES verbatim — both reference
	# docs/SIMULATION_CONTRACT.md §1.2 as the SSOT.
	assert_eq(Constants.PHASES, SimClock.PHASES,
		"Constants.PHASES must mirror SimClock.PHASES (Sim Contract §1.2 SSOT)")


func test_individual_phase_constants_are_correct() -> void:
	assert_eq(Constants.PHASE_INPUT, &"input")
	assert_eq(Constants.PHASE_AI, &"ai")
	assert_eq(Constants.PHASE_MOVEMENT, &"movement")
	assert_eq(Constants.PHASE_SPATIAL_REBUILD, &"spatial_rebuild")
	assert_eq(Constants.PHASE_COMBAT, &"combat")
	assert_eq(Constants.PHASE_FARR, &"farr")
	assert_eq(Constants.PHASE_CLEANUP, &"cleanup")


# -- Team identifiers ---------------------------------------------------------

func test_team_constants_are_distinct_and_canonical() -> void:
	# Iran = 1, Turan = 2, neutral = 0, any = -1. Used by SpatialIndex, AI, etc.
	assert_eq(Constants.TEAM_NEUTRAL, 0)
	assert_eq(Constants.TEAM_IRAN, 1)
	assert_eq(Constants.TEAM_TURAN, 2)
	assert_eq(Constants.TEAM_ANY, -1, "TEAM_ANY sentinel for spatial query filter")
	# All four must be distinct.
	var teams := [Constants.TEAM_NEUTRAL, Constants.TEAM_IRAN, Constants.TEAM_TURAN, Constants.TEAM_ANY]
	var unique := {}
	for t in teams:
		unique[t] = true
	assert_eq(unique.size(), 4, "Team constants must be pairwise distinct")


# -- Resource kinds -----------------------------------------------------------

func test_resource_kind_keys_are_string_names() -> void:
	assert_eq(Constants.KIND_COIN, &"coin")
	assert_eq(Constants.KIND_GRAIN, &"grain")
	# StringName, not String — hash equality check.
	assert_typeof(Constants.KIND_COIN, TYPE_STRING_NAME)
	assert_typeof(Constants.KIND_GRAIN, TYPE_STRING_NAME)


# -- State-machine ids and command kinds -------------------------------------

func test_state_id_constants_are_lowercase_names() -> void:
	# Mirrors docs/STATE_MACHINE_CONTRACT.md §2.2 lowercase-noun convention.
	assert_eq(Constants.STATE_IDLE, &"idle")
	assert_eq(Constants.STATE_MOVING, &"moving")
	assert_eq(Constants.STATE_ATTACKING, &"attacking")
	assert_eq(Constants.STATE_DYING, &"dying")


func test_command_kind_constants_match_state_contract() -> void:
	assert_eq(Constants.COMMAND_MOVE, &"move")
	assert_eq(Constants.COMMAND_ATTACK, &"attack")
	assert_eq(Constants.COMMAND_GATHER, &"gather")
	assert_eq(Constants.COMMAND_BUILD, &"build")
	assert_eq(Constants.COMMAND_ABILITY, &"ability")


# -- Structural caps ----------------------------------------------------------

func test_state_machine_caps_are_canonical() -> void:
	assert_eq(Constants.COMMAND_QUEUE_CAPACITY, 32,
		"Per State Machine Contract §2.4 — 32 is the per-unit hard cap")
	assert_eq(Constants.STATE_MACHINE_TRANSITIONS_PER_TICK, 4,
		"Per State Machine Contract §3.3 — bounded chain of 4")
	assert_eq(Constants.STATE_MACHINE_HISTORY_SIZE_UNIT, 16)
	assert_eq(Constants.STATE_MACHINE_HISTORY_SIZE_AI, 64)


func test_spatial_cell_size_is_eight_meters() -> void:
	# Per Sim Contract §3.1 — 8m uniform cell.
	assert_almost_eq(Constants.SPATIAL_CELL_SIZE, 8.0, 1e-6)


# -- Match-phase enum ---------------------------------------------------------

func test_match_phase_values() -> void:
	assert_eq(Constants.MATCH_PHASE_LOBBY, &"lobby")
	assert_eq(Constants.MATCH_PHASE_PLAYING, &"playing")
	assert_eq(Constants.MATCH_PHASE_ENDED, &"ended")
