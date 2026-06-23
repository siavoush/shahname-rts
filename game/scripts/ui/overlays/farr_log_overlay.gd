extends Control
##
## FarrLogOverlay — F2 debug overlay: a floating on-screen log of every Farr
## change, newest at top.
##
## Phase 4 wave 1 (gameplay-systems). Fulfills the CLAUDE.md mandate: "every
## Farr movement gets logged and surfaces in the debug overlay" + "Debug
## overlays as first-class. Bind toggles to F1–F4 ... every Farr change as a
## floating log. Built once, used forever." The F2 slot has been a reserved
## logged no-op since Phase 0 (DebugOverlayManager); this wave wires it.
##
## Source references:
##   - CLAUDE.md — F2 = Farr log; the Farr chokepoint's farr_changed surfaces here.
##   - docs/SIMULATION_CONTRACT.md §1.5 — UI consumers of write-shaped EventBus
##     signals defer ALL visual state changes to the next _process frame
##     (queue-then-drain). farr_changed is write-shaped; we append to a
##     per-frame queue in the handler and drain it in _process.
##   - docs/PHASE_4_WAVE_1_FARR_KICKOFF.md (Observability) — "Wire the reserved
##     F2 debug overlay as a floating on-screen Farr-change log."
##
## Implementation choice — Control + Label, NOT Node3D:
##   Same constraint as AttackRangeOverlay (the F4 overlay): DebugOverlayManager.
##   register_overlay statically types its parameter as `Control` and
##   toggle_overlay does `_overlays[key] as Control` — a Node3D would silently
##   no-op the toggle. We are a Control with a child RichTextLabel.
##
## Re-entrancy discipline (Pitfall #4 + Sim Contract §1.5):
##   farr_changed fires DURING the &"farr" sim phase (the Farr chokepoint emits
##   on-tick). We MUST NOT mutate sim state, start a Tween, or touch the label
##   synchronously in the handler — we ONLY append the event to _pending. The
##   visual update (rebuild the label text) happens in _process, off-tick. This
##   is the canonical queue-then-drain pattern (Sim Contract §1.5, mirrors
##   FarrGauge._pending_changes). Lint L1/L2 do not match (no apply_* / no
##   EventBus.*.emit from _process).
##
## CRITICAL: mouse_filter == MOUSE_FILTER_IGNORE — Pitfall #1 (the F-overlay
## click-through regression). Set defensively at runtime in _ready.
##
## Starts hidden; F2 keypress is the only show-path (matches AttackRangeOverlay's
## F4 discipline — debug overlays are off by default so a fresh match isn't
## cluttered).

# Max log entries kept + displayed. A floating log is a recent-history view,
# not an unbounded ledger (the telemetry NDJSON sink is the full record). 20
# entries comfortably fills the panel without scrolling off-screen; older
# entries fall off the bottom. Structural (panel sizing), not a balance knob.
const MAX_ENTRIES: int = 20

# Cosmetic panel styling (structural UI, not a balance knob). Without a backing
# panel the overlay is just default-colored text floating over the 3D terrain —
# a single faint title line when the log is empty, easy to mistake for "F2 does
# nothing" (playtest 2026-06-22). A semi-transparent dark panel + padding makes
# the overlay unmistakably present the moment it is toggled, even with no entries.
const PANEL_BG_COLOR: Color = Color(0.05, 0.05, 0.08, 0.78)
const PANEL_PAD_PX: float = 8.0

# Per-frame queue of farr_changed events (queue-then-drain, Sim Contract §1.5).
# Each entry: { amount: float, reason: String, source_unit_id: int,
#               farr_after: float, tick: int }.
var _pending: Array[Dictionary] = []

# The displayed ring of recent entries (newest last). Rebuilt into the label
# text on drain. Bounded to MAX_ENTRIES.
var _entries: Array[Dictionary] = []

# Child label that paints the log text. Created in _ready (no .tscn dependency
# — this overlay is instantiated as a bare Control + self-built child, so it
# can ship without a scene-author handoff; matches the .new()-decouple pattern).
var _label: RichTextLabel = null


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# Pitfall #1 — force click-through regardless of any .tscn state.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to the top-left quadrant — the log floats in the upper-left,
	# clear of the resource HUD (top center) and build menu (bottom).
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 12.0
	offset_top = 90.0
	# F2 overlays start hidden — F2 keypress is the only show-path.
	visible = false
	_build_label()
	# Register with the F1-F4 framework so handle_function_key(KEY_F2) toggles
	# our visibility. DebugOverlayManager is an autoload — alive by the time
	# this scene-bound _ready fires.
	DebugOverlayManager.register_overlay(Constants.OVERLAY_KEY_F2, self)
	# Subscribe to the Farr chokepoint's broadcast. farr_changed is write-shaped
	# (emitted on-tick from the Farr chokepoint), but we only ENQUEUE here — the
	# visual update is deferred to _process (Sim Contract §1.5). No L2 violation
	# (we never emit; we never mutate sim state in the handler).
	if not EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.connect(_on_farr_changed)
	_refresh_label()


func _exit_tree() -> void:
	# Symmetric teardown — matches AttackRangeOverlay / FarrGauge hygiene.
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)
	if DebugOverlayManager.is_registered(Constants.OVERLAY_KEY_F2):
		DebugOverlayManager.unregister_overlay(Constants.OVERLAY_KEY_F2)


# Build the RichTextLabel child that paints the log. Sized to hold MAX_ENTRIES
# lines comfortably. BBCode on so positive gains read green / drains read red.
func _build_label() -> void:
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size = Vector2(360.0, 0.0)
	# Backing panel so the overlay reads as present-and-empty (not "F2 broken")
	# the instant it is toggled — see PANEL_BG_COLOR rationale above.
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = PANEL_BG_COLOR
	bg.content_margin_left = PANEL_PAD_PX
	bg.content_margin_right = PANEL_PAD_PX
	bg.content_margin_top = PANEL_PAD_PX
	bg.content_margin_bottom = PANEL_PAD_PX
	_label.add_theme_stylebox_override(&"normal", bg)
	add_child(_label)


# ============================================================================
# Signal handler — queue-then-drain (Sim Contract §1.5)
# ============================================================================
#
# farr_changed payload: (amount, reason, source_unit_id, farr_after, tick).
# We ONLY append to _pending here — no visual mutation, no Tween, no sim read.
# Public so tests can drive the path without going through the bus.

func handle_farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int) -> void:
	_pending.append({
		"amount": amount,
		"reason": reason,
		"source_unit_id": source_unit_id,
		"farr_after": farr_after,
		"tick": tick,
	})


func _on_farr_changed(amount: float, reason: String, source_unit_id: int,
		farr_after: float, tick: int) -> void:
	handle_farr_changed(amount, reason, source_unit_id, farr_after, tick)


# ============================================================================
# _process — drain the queue, rebuild the label (off-tick, read + UI-local only)
# ============================================================================
#
# Per Sim Contract §1.5: the per-frame drain applies queued events to UI-local
# state (the _entries ring + the label text). Never mutates sim state, never
# emits EventBus signals (lint L1/L2 clean), never starts a sim-state Tween.

func _process(_dt: float) -> void:
	if _pending.is_empty():
		return
	while not _pending.is_empty():
		var ev: Dictionary = _pending.pop_front()
		_entries.append(ev)
	# Trim to the most-recent MAX_ENTRIES.
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	_refresh_label()


# Rebuild the label text from _entries (newest at top). Each line:
#   [tick N] +X.XX  reason  → farr_after
# Gains green, drains red, zero-delta grey. All strings via tr() (i18n —
# CLAUDE.md "All UI strings in a translation table ... Even debug strings.").
func _refresh_label() -> void:
	if _label == null:
		return
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % tr("UI_DEBUG_FARR_LOG_TITLE"))
	# Iterate newest-first (reverse) so the latest change is at the top.
	for i in range(_entries.size() - 1, -1, -1):
		lines.append(_format_entry(_entries[i]))
	_label.text = "\n".join(lines)


func _format_entry(ev: Dictionary) -> String:
	var amount: float = float(ev.get("amount", 0.0))
	var reason: String = String(ev.get("reason", ""))
	var farr_after: float = float(ev.get("farr_after", 0.0))
	var tick: int = int(ev.get("tick", 0))
	var color: String = "gray"
	var sign_str: String = ""
	if amount > 0.0:
		color = "lime"
		sign_str = "+"
	elif amount < 0.0:
		color = "red"
	return "[color=%s][t=%d] %s%.2f  %s → %.2f[/color]" % [
		color, tick, sign_str, amount, reason, farr_after]


# ============================================================================
# Test accessors
# ============================================================================

## The current displayed entries (newest last). Read-only snapshot for tests.
func entries() -> Array[Dictionary]:
	return _entries.duplicate()


## Number of pending (not-yet-drained) events. Tests assert the queue-then-drain
## boundary: events sit in _pending until _process drains them.
func pending_count() -> int:
	return _pending.size()


## Force-drain the queue (test hook so a GUT test can exercise the drain without
## awaiting a real _process frame). Mirrors the _process body.
func drain_for_test() -> void:
	_process(0.0)
