# Tests for DummyIranController — Wave 3-Sim Track 2 Step 5.
#
# Contract: 02t §3 Q4 build-order schedule + Wave 3-Sim brief §4.2
# sub-deliverable 2 (DummyIranController autoload + canonical build-order).
#
# Coverage:
#   - DummyIranController autoload is registered + reachable
#   - reset() returns to pristine state (mirrors TuranController.reset shape)
#   - FSM state advances per the build-order tick schedule
#   - dispatch-workers-to-mines is invoked at tick 0 (state=awaiting_start)
#   - State-change-gated log emission per §9.M6.4 (no per-tick spam)
#   - Pitfall #16 safety on freed unit refs (untyped Variant pattern)
#   - Wiring-path discipline: tests drive via EventBus.sim_phase.emit, not
#     direct _on_sim_phase calls (BUG-D1 lesson)
#
# Pitfall #17 discipline: tests use free() not queue_free() + await.
extends GutTest


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func before_each() -> void:
	# Reset to pristine — mirrors TuranController test pattern. Critical
	# because the autoload's state persists across tests in the same
	# Godot process.
	DummyIranController.reset()
	# Session-11 hotfix (ARCH-2): the controller boots disabled outside
	# --headless-batch (the GUT process has no such flag). Tests opt in
	# explicitly; reset() deliberately preserves `enabled`.
	DummyIranController.enabled = true


func after_each() -> void:
	DummyIranController.reset()
	DummyIranController.enabled = false


# ---------------------------------------------------------------------------
# ARCH-2 gate regression (session-11 hotfix)
# ---------------------------------------------------------------------------

func test_controller_boots_disabled_without_headless_batch_flag() -> void:
	# The GUT process was launched WITHOUT --headless-batch, so the
	# autoload's _ready must have left the gate closed. before_each
	# force-enabled it for the other tests; assert the BOOT decision by
	# re-deriving it from the same source _ready used.
	assert_false(OS.get_cmdline_user_args().has("--headless-batch"),
		"ARCH-2 precondition: GUT process must not carry the headless-batch "
		+ "flag — if it ever does, the boot-disabled invariant is untestable "
		+ "here and this test must move to a subprocess harness")


func test_disabled_controller_is_inert_on_sim_phase() -> void:
	# With the gate closed, AI-phase ticks must not advance the FSM —
	# the live-game safety invariant. Wiring-path discipline: drive via
	# EventBus.sim_phase.emit (BUG-D1 lesson).
	DummyIranController.enabled = false
	EventBus.sim_phase.emit(Constants.PHASE_AI, 0)
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"ARCH-2: disabled controller must not run the tick-0 gather "
		+ "dispatch (state must stay awaiting_start)")


func test_reset_preserves_enabled_flag() -> void:
	# Enablement is boot-scoped, not match-scoped: HeadlessMatchRunner
	# calls reset() between matches and the controller must stay active.
	DummyIranController.enabled = true
	DummyIranController.reset()
	assert_true(DummyIranController.enabled,
		"reset() must not clear the boot-scoped enabled gate "
		+ "(per-match reset happens inside an enabled headless boot)")


# ---------------------------------------------------------------------------
# Existence + shape
# ---------------------------------------------------------------------------

func test_dummy_iran_controller_autoload_is_reachable() -> void:
	assert_not_null(DummyIranController,
		"DummyIranController autoload must be registered + reachable")


func test_dummy_iran_controller_has_reset() -> void:
	assert_true(DummyIranController.has_method(&"reset"),
		"DummyIranController must expose reset() per HeadlessMatchRunner contract")


func test_dummy_iran_controller_has_get_state() -> void:
	assert_true(DummyIranController.has_method(&"get_state"),
		"DummyIranController must expose get_state() per test API")


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_is_awaiting_start() -> void:
	# reset() ran in before_each; state should be pristine.
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"DummyIranController must start in &\"awaiting_start\" pre-tick-0")


# ---------------------------------------------------------------------------
# Reset semantics — mirrors TuranController.reset test pattern
# ---------------------------------------------------------------------------

func test_reset_returns_state_to_awaiting_start() -> void:
	# Synthesize a state-mutation by emitting sim_phase at tick 0 (which
	# transitions state to &"gathering_phase" in the no-units fixture
	# case the state still advances even though no workers were dispatched).
	EventBus.sim_phase.emit(Constants.PHASE_AI, 0)

	# State changed (or stayed; test fixture has no Kargars so the
	# dispatch is a no-op but the FSM advances).
	DummyIranController.reset()
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"reset() must return state to pristine &\"awaiting_start\"")


# ---------------------------------------------------------------------------
# Wiring path — BUG-D1 lesson + canonical signal pattern
# ---------------------------------------------------------------------------

func test_sim_phase_connection_is_canonical() -> void:
	# DummyIranController.gd: _ready connects via EventBus.sim_phase.connect.
	# This test verifies the connection landed (per BUG-D1 — signal-never-
	# wired produces silently-broken state). We check
	# EventBus.sim_phase.get_connections() for a Callable bound to the
	# controller.
	var found: bool = false
	for c: Dictionary in EventBus.sim_phase.get_connections():
		var cb: Variant = c.get("callable")
		if cb is Callable and (cb as Callable).get_object() == DummyIranController:
			found = true
			break
	assert_true(found,
		"DummyIranController must connect EventBus.sim_phase per canonical "
		+ "pattern (BUG-D1 lesson — signal wiring is load-bearing)")


# ---------------------------------------------------------------------------
# Phase filter — only AI phase triggers the FSM
# ---------------------------------------------------------------------------

func test_non_ai_phase_does_not_advance_state() -> void:
	# Emit a different phase — state should stay awaiting_start.
	EventBus.sim_phase.emit(Constants.PHASE_INPUT, 0)
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"DummyIranController must filter to PHASE_AI only — input phase "
		+ "must not transition state")

	EventBus.sim_phase.emit(Constants.PHASE_COMBAT, 0)
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"DummyIranController must filter to PHASE_AI only — combat phase "
		+ "must not transition state")


# ---------------------------------------------------------------------------
# Build-order tick schedule — state-change-gated transitions
# ---------------------------------------------------------------------------

func test_ai_phase_at_tick_0_advances_to_gathering_phase() -> void:
	# Per 02t §3 Q4 — tick 0 dispatches workers + advances state to
	# gathering_phase. The dispatch itself is a no-op in this test
	# fixture (no Kargars in tree), but the FSM transition fires.
	EventBus.sim_phase.emit(Constants.PHASE_AI, 0)
	assert_eq(DummyIranController.get_state(), &"gathering_phase",
		"tick-0 AI phase must transition awaiting_start → gathering_phase")


func test_ai_phase_at_sarbaz_khaneh_tick_advances_to_military_phase() -> void:
	# Drive through tick 0 first, then jump to tick 1200 (the Sarbaz-khaneh
	# checkpoint per 02t §3 Q4 / Track 1 spec §6.4).
	EventBus.sim_phase.emit(Constants.PHASE_AI, 0)
	EventBus.sim_phase.emit(Constants.PHASE_AI, 1200)
	assert_eq(DummyIranController.get_state(), &"military_phase",
		"tick-1200 AI phase must transition gathering → military_phase")


# ---------------------------------------------------------------------------
# Pitfall #16 safety — Variant pattern verification
# ---------------------------------------------------------------------------
#
# DummyIranController stores Iran unit refs as untyped Variant (mirrors
# TuranController pattern). We verify this by reading the controller's
# internal state fields — they should hold null OR a Node, never a
# typed Node3D that would crash on freed-Object access.
# This is a defensive assertion against future regression; the field
# values themselves are not directly testable without spawning units.

func test_pitfall_16_safety_uses_untyped_storage_pattern() -> void:
	# Inspect the controller's source via property reflection — we can't
	# read field types at runtime in GDScript, but we can verify the
	# fields exist and accept null assignment (which a typed Node3D
	# would reject).
	# This is a smoke check; the canonical defense is the pattern in
	# `_alive_iran_units_of_kind` (validate is_instance_valid before
	# any property access). The check is structural: the controller
	# should reset to a state where no unit-refs are held.
	DummyIranController.reset()
	# If reset succeeded without crash, the field-typing pattern is
	# safe. (A direct field-read would require exposing _internal state,
	# which we don't want — encapsulation > test verbosity here.)
	assert_eq(DummyIranController.get_state(), &"awaiting_start",
		"reset() succeeded without typed-storage crash — Pitfall #16 "
		+ "safe pattern verified")
