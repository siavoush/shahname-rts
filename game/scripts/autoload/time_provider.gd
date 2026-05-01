extends Node
##
## TimeProvider — the only sanctioned source of wall-clock time in the project.
##
## Per docs/SIMULATION_CONTRACT.md §1 the only "now" in gameplay code is
## SimClock.tick / SimClock.sim_time. TimeProvider exists for the narrow set of
## off-tick consumers that genuinely need wall-clock time (telemetry timestamps,
## perf instrumentation, debug overlays) — and crucially, for tests that need
## to inject a deterministic value without `await`-ing real time.
##
## The mock-injection API is what makes Farr/Kaveh tests deterministic later —
## those systems will accept TimeProvider as their clock source so the test
## harness can pin time to exact millisecond values.
##
## Lint rule L5 (Sim Contract §1.4) forbids gameplay code from calling
## Time.get_ticks_msec() directly. This file is on the lint allowlist.

var _mock_ms: int = -1            # -1 sentinel = no mock active
var _mock_active: bool = false


## Returns the current time in milliseconds. When a mock is set, returns the
## mock value verbatim. Otherwise returns Godot's monotonic millisecond clock.
func now_ms() -> int:
	if _mock_active:
		return _mock_ms
	return Time.get_ticks_msec()


## Test-only: pin now_ms() to a fixed value until clear_mock() is called.
## Subsequent calls to set_mock override the current mock — they don't stack.
func set_mock(ms: int) -> void:
	_mock_ms = ms
	_mock_active = true


## Test-only: drop any active mock and resume reading real wall-clock time.
## Idempotent — safe to call when no mock is active.
func clear_mock() -> void:
	_mock_ms = -1
	_mock_active = false


## Returns true while a mock is active. Useful for assertions in tests, and as
## a debug-overlay surface (we want to see at a glance if we're in a mocked run).
func is_mocked() -> bool:
	return _mock_active
