extends GutTest
##
## Determinism regression test (per docs/TESTING_CONTRACT.md §6.2 and
## docs/SIMULATION_CONTRACT.md §6.2).
##
## Runs the same seeded match twice and asserts end-state snapshots are equal.
##
## Phase 0 stub: intentionally minimal — no units, no combat, no resources
## consumed. The empty-match case exercises:
##   - SimClock tick advancement is deterministic
##   - FarrSystem fixed-point storage produces identical values each run
##   - EventBus signal sequence is identical across runs
##   - GameRNG seeding (when GameRNG ships) produces the same sequence
##
## This will grow in Phase 1+ as each new system (movement, combat, Farr
## generators, Kaveh Event) adds real state variation that could leak
## non-determinism. The empty-match case passing is the Phase 0 bar.
##
## If this test fails, the most likely causes are:
##   - Wall-clock reads in a system (violates Sim Contract §1.2, caught by L5)
##   - Bare randi()/randf() calls outside GameRNG (caught by L3)
##   - Off-tick mutations that accumulate floating-point drift
##   - EventBus signal connection order varying across instances
##   - Global mutable state not reset between harness runs

# Preloaded script ref for the class_name-registry-race pattern.
const _MH: Script = preload("res://tests/harness/match_harness.gd")


func after_each() -> void:
	# Belt-and-braces: ensure autoloads are clean even if a test crashes early.
	SimClock.reset()
	GameState.reset()
	PathSchedulerService.reset()


# Helper: create + start_match in one step.
func _make_harness(match_seed: int = 0, scenario: StringName = &"empty") -> Variant:
	var h: Variant = _MH.new()
	h.start_match(match_seed, scenario)
	return h


# ---------------------------------------------------------------------------
# Phase 0 determinism test — empty match
# ---------------------------------------------------------------------------

## Same seeded empty match run twice must produce identical snapshots.
## This is the baseline bar for Phase 0: determinism holds when there's nothing
## happening except the tick pipeline.
func test_empty_match_is_deterministic() -> void:
	var h1: Variant = _make_harness(12345, &"empty")
	h1.advance_ticks(60)  # 2 simulated seconds at 30 Hz
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	var h2: Variant = _make_harness(12345, &"empty")
	h2.advance_ticks(60)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	assert_eq(snap1, snap2,
		"Same-seeded empty matches must produce identical snapshots. "
		+ "A mismatch means non-deterministic state is leaking — "
		+ "check for wall-clock reads (L5), bare RNG (L3), or "
		+ "global autoload state not reset between harness instances.")


## Different seeds in Phase 0 produce the same snapshot content because nothing
## exercises the RNG yet in an empty match. This documents that expectation
## explicitly — Phase 1+ will add tests where seeds produce different outcomes.
func test_different_seeds_produce_same_empty_snapshots() -> void:
	var h1: Variant = _make_harness(1, &"empty")
	h1.advance_ticks(60)
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	var h2: Variant = _make_harness(2, &"empty")
	h2.advance_ticks(60)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	# In an empty Phase 0 match tick=60, farr=50.0, resources=defaults, units=0.
	assert_eq(snap1["tick"], snap2["tick"],
		"Both matches ran 60 ticks — tick should be 60 in both")
	assert_almost_eq(float(snap1["farr"]), float(snap2["farr"]), 1e-6,
		"Empty matches produce identical Farr regardless of seed in Phase 0")


## Verify that two sequential harness runs don't bleed state into each other.
## This tests teardown isolation — a subtle form of determinism failure.
func test_sequential_harnesses_are_isolated() -> void:
	# Run 1: advance 30 ticks.
	var h1: Variant = _make_harness(99, &"empty")
	h1.advance_ticks(30)
	var snap1: Dictionary = h1.snapshot()
	h1.teardown()

	# Run 2: same seed, same tick count — must produce the same snapshot.
	var h2: Variant = _make_harness(99, &"empty")
	h2.advance_ticks(30)
	var snap2: Dictionary = h2.snapshot()
	h2.teardown()

	assert_eq(snap1, snap2,
		"Sequential harness runs with the same seed must produce identical snapshots. "
		+ "A mismatch means teardown() isn't resetting some global state properly.")
