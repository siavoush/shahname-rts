# Tests for TimeProvider autoload.
#
# Contract: docs/SIMULATION_CONTRACT.md §1 — gameplay code reads time only
# through TimeProvider. The mock-injection support is what makes Farr/Kaveh
# tests deterministic later.
extends GutTest


func after_each() -> void:
	# Always clear any mock between tests so we don't leak state.
	TimeProvider.clear_mock()


func test_now_ms_returns_a_positive_integer_when_unmocked() -> void:
	var t: int = TimeProvider.now_ms()
	assert_typeof(t, TYPE_INT, "now_ms must return int")
	assert_gt(t, 0, "now_ms should report wall-clock time > 0")


func test_now_ms_advances_with_real_time_when_unmocked() -> void:
	var first: int = TimeProvider.now_ms()
	# Use OS to wait briefly without depending on TimeProvider itself.
	OS.delay_msec(20)
	var second: int = TimeProvider.now_ms()
	assert_gte(second - first, 10, "now_ms should advance with the real wall clock")


func test_set_mock_pins_now_ms_to_supplied_value() -> void:
	TimeProvider.set_mock(123_456)
	assert_eq(TimeProvider.now_ms(), 123_456, "Mock value must be returned verbatim")
	# A second call returns the same value — the mock is sticky, not a one-shot.
	assert_eq(TimeProvider.now_ms(), 123_456, "Mock should persist across calls")


func test_set_mock_overrides_previous_mock() -> void:
	TimeProvider.set_mock(1000)
	TimeProvider.set_mock(2000)
	assert_eq(TimeProvider.now_ms(), 2000, "Latest set_mock wins")


func test_clear_mock_returns_to_real_time() -> void:
	TimeProvider.set_mock(42)
	assert_eq(TimeProvider.now_ms(), 42)
	TimeProvider.clear_mock()
	var real: int = TimeProvider.now_ms()
	assert_ne(real, 42, "clear_mock should resume reading real wall clock")
	# Real time post-clear must report a fresh wall-clock read. Confirm it
	# advances on a second call rather than asserting on absolute magnitude
	# (which is process-uptime-dependent and can be small in CI).
	OS.delay_msec(5)
	var later: int = TimeProvider.now_ms()
	assert_gt(later, real, "Real wall clock should keep advancing after clear_mock")


func test_is_mocked_reports_state() -> void:
	assert_false(TimeProvider.is_mocked(), "Fresh state is unmocked")
	TimeProvider.set_mock(7)
	assert_true(TimeProvider.is_mocked(), "After set_mock, is_mocked is true")
	TimeProvider.clear_mock()
	assert_false(TimeProvider.is_mocked(), "After clear_mock, is_mocked is false")
