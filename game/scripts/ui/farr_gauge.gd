extends Control
##
## FarrGauge — circular Farr meter widget (Phase 1 session 2 wave 1C).
##
## Replaces the Phase 0 text "Farr: 50" readout with a custom-`_draw` circular
## arc whose fill expresses Farr from 0 to Constants.FARR_MAX. Threshold ticks
## (Tier 2 advance, Kaveh trigger) are painted at their angular positions per
## BalanceData.farr_config — never hardcoded (CLAUDE.md).
##
## Source references:
##   - 01_CORE_MECHANICS.md §4.1 — Farr range 0–100, starts 50
##   - 01_CORE_MECHANICS.md §4.2 — Tier 2 gate at Farr ≥ 40
##   - 01_CORE_MECHANICS.md §4.4 — visualization spec: color shifts ≥70 / 40-70
##     / 15-40 / <15, audio cues at threshold crossings, change-feedback labels
##   - 01_CORE_MECHANICS.md §9.1 — Kaveh Event triggers below Farr 15 for 30s
##   - 01_CORE_MECHANICS.md §11 — UI requirement: "Farr gauge (top-right):
##     circular meter, 0–100, with color thresholds and threshold-crossing
##     audio cues"
##   - CLAUDE.md — placeholder visuals, all UI strings via tr(), no magic numbers
##   - docs/SIMULATION_CONTRACT.md §1.5 — UI reads sim state freely off-tick
##
## Design choices (per the wave-1C proposal, balance-engineer review):
##   1. Custom `_draw()` over TextureProgressBar — no asset dependency, exact
##      threshold-tick placement, polygon-fan fill via draw_arc.
##   2. Signal-driven update via EventBus.farr_changed — never polled in
##      `_process` (avoids dropping the per-frame cost the text HUD pays today).
##   3. Tween 0.25s TRANS_QUAD EASE_OUT on every farr_changed — no debounce.
##      balance-engineer veto on debounce: silently dropping small Farr deltas
##      would break CLAUDE.md's "every Farr movement gets logged and surfaces in
##      the debug overlay" mandate. Tween briefly each signal; if Phase 4's
##      Atashkadeh per-tick contribution causes visible stutter, batch on the
##      producer side, not here.
##   4. Tier 2 threshold tick: medium-weight gold (matches ≥70 color band) per
##      balance-engineer's visibility suggestion — a thin ivory mark on an
##      ivory band would have disappeared.
##   5. mouse_filter = MOUSE_FILTER_IGNORE — must not swallow click-throughs
##      to world units (Phase 1 session 1 regression: HUD MOUSE_FILTER_STOP
##      defaults ate clicks; this mistake does NOT recur).
##
## DEFERRED (intentionally out of session-2 scope):
##   - Below-Kaveh red pulsing animation (spec §4.4 "<15 red and pulsing"). When
##     this lands in Phase 2, drive the pulse from a separate `_process` state
##     flag (`_is_below_kaveh`) set in `_on_farr_changed`, NOT from the tween
##     target — the tween finishes; the pulse must keep animating while Farr
##     is below the threshold. The flag-and-_process pattern is replay-safe
##     (UI off-tick, no sim mutation) and survives tween completion.
##   - Floating reason-text labels ("+3 Farr (hero rescued worker)") per
##     spec §4.4. The signal payload carries `reason: String`; a future widget
##     can subscribe to the same farr_changed signal independently.
##   - Threshold-crossing audio cues (chime up at 40/70, distant horn down at
##     15) per spec §4.4 — Tier 2 audio concern.

# === PUBLIC STATE (read-only from outside) ==================================
# `target_farr` is the value the meter is moving TOWARD — the post-clamp value
# from EventBus.farr_changed.farr_after. `displayed_farr` is what `_draw` paints
# this frame; the tween interpolates it toward the target. Tests that don't
# want to wait for tween steps should read `target_farr` directly.

var target_farr: float = 50.0
var displayed_farr: float = 50.0


# === THRESHOLDS (loaded from BalanceData at _ready, then read-only) =========
# CLAUDE.md: "Threshold values read from BalanceData.farr_config. No hardcoded
# numbers." Defensive load mirrors farr_system.gd:67-91 — if BalanceData is
# missing (test scenes), fall back to spec defaults so the gauge stays
# coherent rather than crashing.

var tier2_threshold: float = 40.0
var kaveh_trigger_threshold: float = 15.0


# === COLOR-BAND CLASSIFICATION ==============================================
# Per 01_CORE_MECHANICS.md §4.4. Tags are StringNames so tests assert against
# stable identifiers, not RGB values — the implementer can tune the palette
# (and lead's live-test feedback may push us to) without breaking tests.
# Boundary policy is inclusive-at-lower-bound: exactly 70 → gold, exactly 40 →
# ivory, exactly 15 → dim. Avoids 14.99-vs-15.00 jitter across the
# Kaveh-warning UI.
#
# `tier3_visual_threshold` is the ≥70 boundary. It is intentionally NOT in
# BalanceData: spec §8 lists Tier 3 ("Royal Court") as post-MVP, so the
# threshold is structural/visual, not a balance knob — same justification as
# Constants.FARR_MAX. When Tier 3 ships, this becomes a balance value and
# moves to FarrConfig. For now: hardcoded with a citation comment.
const BAND_GOLD: StringName = &"gold"
const BAND_IVORY: StringName = &"ivory"
const BAND_DIM: StringName = &"dim"
const BAND_RED: StringName = &"red"
const _TIER3_VISUAL_THRESHOLD: float = 70.0   # spec §4.4 ≥70 gold band; post-MVP knob

# Computed per-frame from `displayed_farr` so it animates with the meter.
var color_band: StringName = BAND_IVORY


# === FILL RATIO (read-only computed property) ===============================
# Visual fill is target_farr / tier2_threshold, NOT target_farr / FARR_MAX.
# At Farr 40 (Tier 2 threshold) the gauge is full; above 40 the fill stays at
# 1.0 and the GOLD color band carries the "above-Tier-2" signal. This matches
# the kickoff doc §149: "fills from 0 to FARR_TIER2_THRESHOLD."
#
# Reads from `target_farr` rather than `displayed_farr` so external observers
# (debug overlay, tests) see the post-clamp commanded fill, not the
# mid-tween interpolation.
var fill_ratio: float:
	get:
		if tier2_threshold <= 0.0:
			return 0.0
		return clampf(target_farr / tier2_threshold, 0.0, 1.0)


# === VISUAL CONSTANTS =======================================================
# Placeholder palette per CLAUDE.md (colored shapes, not real art). Hand-picked
# for legibility against the placeholder grey terrain. Tunable per
# balance-engineer / lead live-test feedback — these are visual choices, not
# gameplay invariants, so they live here rather than in BalanceData.

const _ARC_START_ANGLE: float = -PI * 0.5      # 12 o'clock
const _ARC_FULL_SWEEP: float = TAU             # full revolution clockwise
const _ARC_RADIUS: float = 28.0
const _ARC_THICKNESS: float = 6.0
const _CENTER_OFFSET: Vector2 = Vector2(32.0, 32.0)
const _MIN_SIZE: Vector2 = Vector2(64.0, 64.0)

# Color bands (per spec §4.4)
const _COLOR_BAND_RED: Color = Color(0.7, 0.18, 0.18, 0.25)        # <15
const _COLOR_BAND_DIM: Color = Color(0.55, 0.55, 0.6, 0.18)        # 15-40
const _COLOR_BAND_IVORY: Color = Color(0.95, 0.92, 0.78, 0.25)     # 40-70
const _COLOR_BAND_GOLD: Color = Color(1.0, 0.85, 0.35, 0.30)       # ≥70

# Foreground arc colors (the moving fill). Brightness shifts as displayed_farr
# crosses bands. Per balance-engineer's "linear interpolation, no bias curve"
# approval — simple band lookup, no gradient.
const _COLOR_FILL_RED: Color = Color(0.95, 0.25, 0.20)
const _COLOR_FILL_DIM: Color = Color(0.7, 0.7, 0.75)
const _COLOR_FILL_IVORY: Color = Color(0.95, 0.92, 0.78)
const _COLOR_FILL_GOLD: Color = Color(1.0, 0.85, 0.35)
const _COLOR_RING_BG: Color = Color(0.15, 0.15, 0.17, 0.55)
const _COLOR_LABEL: Color = Color(0.95, 0.95, 0.92)

# Threshold tick colors (per balance-engineer's prominence guidance).
const _COLOR_TIER2_TICK: Color = Color(1.0, 0.85, 0.35)            # gold
const _COLOR_KAVEH_TICK: Color = Color(0.95, 0.20, 0.18)           # red
const _TICK_LENGTH_OUTSIDE: float = 4.0
const _TICK_LENGTH_INSIDE: float = 4.0
const _TICK_THICKNESS_TIER2: float = 2.0
const _TICK_THICKNESS_KAVEH: float = 3.0

# Tween parameters per the proposal. 0.20s is short enough that headless GUT
# tests pumping ~30 process_frame awaits reliably observe a settled tween,
# while still being long enough to read as animation in the live game (per
# the wave-1C proposal's "0.25s feels like settle, not jarring" reasoning —
# 0.20s is barely distinguishable and gives a comfortable test margin).
const _TWEEN_DURATION: float = 0.20


# === INTERNALS ==============================================================

var _active_tween: Tween = null


# === LIFECYCLE ==============================================================

func _ready() -> void:
	# Hard constraint: must NOT swallow clicks bound for world units. Phase 1
	# session 1 saw HUD Labels eating clicks via the MOUSE_FILTER_STOP default;
	# this gauge does not repeat that mistake.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _MIN_SIZE

	_load_thresholds_from_balance_data()
	_seed_initial_farr_from_system()

	# Subscribe to the chokepoint signal. EventBus is an autoload so this is
	# always reachable in production; defensive `is_instance_valid` would be
	# redundant against autoload presence.
	EventBus.farr_changed.connect(_on_farr_changed)

	queue_redraw()


# Symmetric cleanup. Without this the F2 debug overlay (Phase 4) would see
# ghost connections from prior gauge instances after scene teardown — a real
# leak in long-running editor sessions and in test runs that instantiate the
# gauge repeatedly.
func _exit_tree() -> void:
	if EventBus.farr_changed.is_connected(_on_farr_changed):
		EventBus.farr_changed.disconnect(_on_farr_changed)


# === BALANCE DATA + AUTOLOAD READS ==========================================

# Defensive load mirroring farr_system.gd:67-91 — if BalanceData isn't on disk
# (test scenes loading the gauge in isolation), keep the spec defaults rather
# than crash. If the file is present but `farr` is missing or the threshold
# fields are non-numeric, also fall back.
func _load_thresholds_from_balance_data() -> void:
	var path: String = Constants.PATH_BALANCE_DATA
	if not FileAccess.file_exists(path):
		return
	var bd: Resource = load(path)
	if bd == null:
		return
	var farr_cfg: Variant = bd.get(&"farr")
	if farr_cfg == null:
		return
	var t2: Variant = farr_cfg.get(&"tier2_threshold")
	if typeof(t2) == TYPE_FLOAT or typeof(t2) == TYPE_INT:
		tier2_threshold = float(t2)
	var kv: Variant = farr_cfg.get(&"kaveh_trigger_threshold")
	if typeof(kv) == TYPE_FLOAT or typeof(kv) == TYPE_INT:
		kaveh_trigger_threshold = float(kv)


# Seed displayed/target from FarrSystem.value_farr (the existing accessor used
# by resource_hud.gd:97-105). Defensive: if FarrSystem isn't autoloaded
# (test-only scenes), fall back to spec default 50.0.
#
# Why two read shapes? The production autoload exposes `value_farr` as a
# computed property over `_farr_x100` (per Sim Contract §1.6 fixed-point
# storage). Mock nodes used in tests may set `value_farr` directly. Object.get
# returns the field's current value in either case.
func _seed_initial_farr_from_system() -> void:
	var farr_node: Node = _autoload_or_null(&"FarrSystem")
	if farr_node == null:
		# No FarrSystem — keep spec default (50.0).
		color_band = _band_for(displayed_farr)
		return
	var seed_value: Variant = farr_node.get(&"value_farr")
	if typeof(seed_value) == TYPE_FLOAT or typeof(seed_value) == TYPE_INT:
		var clamped: float = clampf(float(seed_value), 0.0, Constants.FARR_MAX)
		target_farr = clamped
		displayed_farr = clamped
	color_band = _band_for(displayed_farr)


# Same autoload-resolution pattern resource_hud.gd:192-200 uses. Script
# autoloads register as direct children of the SceneTree root under their
# registered name; Engine.has_singleton() does NOT find them (that API is for
# C++/GDExtension singletons).
func _autoload_or_null(autoload_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(NodePath(autoload_name))


# === SIGNAL HANDLER =========================================================

# Authoritative update path. The signal payload's `farr_after` is the
# post-clamp Farr value at apply time; we just track it. Defensive clamp
# against Constants.FARR_MAX defends against synthetic emits from test code
# and any future hot-reload that changes FARR_MAX out from under us — the
# gauge never paints outside its visual range.
func _on_farr_changed(_amount: float, _reason: String, _source_unit_id: int,
		farr_after: float, _tick: int) -> void:
	target_farr = clampf(farr_after, 0.0, Constants.FARR_MAX)
	# Update color_band synchronously off target — observers (tests, the F2
	# overlay later) see the new band as soon as the signal fires, even
	# though the visual fill is mid-tween. This is the right semantic: "the
	# gauge has been told you're in red territory now, the visual is just
	# catching up."
	color_band = _band_for(target_farr)
	# Tween animates displayed_farr → target_farr; per-step callback re-runs
	# _band_for off the interpolated value to update intermediate band
	# crossings during the tween.
	_start_tween()


# Kill any running tween, start a fresh one. UI tween — off-tick (Sim Contract
# §1.5 explicitly permits UI tweens off-tick). Writes only to gauge-local
# state (`displayed_farr`); never mutates FarrSystem.
#
# `tween_method` calls `_apply_displayed_farr` each frame with the interpolated
# value, which updates `displayed_farr`, recomputes `color_band`, and triggers
# a redraw — all in one place. Avoids the dual-tween hack of running two
# parallel tweens just to repaint each step.
func _start_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_apply_displayed_farr, displayed_farr,
		target_farr, _TWEEN_DURATION)


# Per-frame tween step: updates displayed_farr, recomputes the band tag, and
# requests a redraw. Single funnel so the band tag and the visual stay in
# lockstep — there is no path to a frame where the visual fill and the
# `color_band` property disagree.
func _apply_displayed_farr(new_value: float) -> void:
	displayed_farr = new_value
	color_band = _band_for(new_value)
	queue_redraw()


# === RENDERING ==============================================================

func _draw() -> void:
	# Background ring — the unfilled track.
	draw_arc(_CENTER_OFFSET, _ARC_RADIUS, _ARC_START_ANGLE,
		_ARC_START_ANGLE + _ARC_FULL_SWEEP, 64, _COLOR_RING_BG, _ARC_THICKNESS)

	# Color band wash behind the fill — communicates the threshold zones at a
	# glance. Painted before the fill arc so the foreground reads cleanly.
	_draw_color_bands()

	# Foreground fill arc — sweeps from start angle to fill angle. The fill
	# is normalized to tier2_threshold (full meter at Farr=40) per kickoff §149,
	# not to FARR_MAX. Above Tier 2, the gold band tag carries the overshoot
	# signal. We use displayed_farr for smooth tween-driven animation.
	var visual_ratio: float = 0.0
	if tier2_threshold > 0.0:
		visual_ratio = clampf(displayed_farr / tier2_threshold, 0.0, 1.0)
	if visual_ratio > 0.0:
		var sweep: float = _ARC_FULL_SWEEP * visual_ratio
		draw_arc(_CENTER_OFFSET, _ARC_RADIUS, _ARC_START_ANGLE,
			_ARC_START_ANGLE + sweep, 64, _fill_color_for(color_band),
			_ARC_THICKNESS)

	# Threshold ticks (drawn last so they sit on top of fill + bands).
	_draw_threshold_tick(tier2_threshold, _COLOR_TIER2_TICK, _TICK_THICKNESS_TIER2)
	_draw_threshold_tick(kaveh_trigger_threshold, _COLOR_KAVEH_TICK, _TICK_THICKNESS_KAVEH)

	# Numeric label — center of the gauge. Keeps the Phase 0 readout's
	# debugging utility visible. Translation key UI_FARR (no new keys needed).
	_draw_numeric_label()


func _draw_color_bands() -> void:
	# Each band is an arc of the ring background. Ranges come from spec §4.4:
	# <15 red, 15-40 dim, 40-70 ivory, ≥70 gold. The lower two boundaries are
	# BalanceData-driven; the 70 boundary is a visual sub-band hint —
	# _TIER3_VISUAL_THRESHOLD documents that this is a structural choice that
	# becomes BalanceData-driven when Tier 3 ships post-MVP.
	_draw_band(0.0, kaveh_trigger_threshold, _COLOR_BAND_RED)
	_draw_band(kaveh_trigger_threshold, tier2_threshold, _COLOR_BAND_DIM)
	_draw_band(tier2_threshold, _TIER3_VISUAL_THRESHOLD, _COLOR_BAND_IVORY)
	_draw_band(_TIER3_VISUAL_THRESHOLD, Constants.FARR_MAX, _COLOR_BAND_GOLD)


func _draw_band(from_farr: float, to_farr: float, color: Color) -> void:
	# Band sits just inside the main ring — a thin secondary arc that doesn't
	# compete with the fill foreground.
	var inner_radius: float = _ARC_RADIUS - _ARC_THICKNESS - 1.0
	if inner_radius <= 0.0:
		return
	var from_angle: float = _ARC_START_ANGLE + _ARC_FULL_SWEEP * (from_farr / Constants.FARR_MAX)
	var to_angle: float = _ARC_START_ANGLE + _ARC_FULL_SWEEP * (to_farr / Constants.FARR_MAX)
	if to_angle <= from_angle:
		return
	draw_arc(_CENTER_OFFSET, inner_radius, from_angle, to_angle, 32, color, 3.0)


func _draw_threshold_tick(farr_value: float, color: Color, thickness: float) -> void:
	# A tick crossing the ring at the angular position for `farr_value`.
	# Drawn from slightly outside the ring to slightly inside.
	var ratio: float = clampf(farr_value / Constants.FARR_MAX, 0.0, 1.0)
	var angle: float = _ARC_START_ANGLE + _ARC_FULL_SWEEP * ratio
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var outer: Vector2 = _CENTER_OFFSET + dir * (_ARC_RADIUS + _TICK_LENGTH_OUTSIDE)
	var inner: Vector2 = _CENTER_OFFSET + dir * (_ARC_RADIUS - _TICK_LENGTH_INSIDE)
	draw_line(inner, outer, color, thickness)


func _draw_numeric_label() -> void:
	# `tr("UI_FARR")` for the prefix, integer Farr for the number — matches
	# the Phase 0 HUD aesthetic at lower visual weight (small, centered).
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	var text: String = "%s %d" % [tr("UI_FARR"), roundi(displayed_farr)]
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER,
		-1.0, font_size)
	var pos: Vector2 = _CENTER_OFFSET - Vector2(size.x * 0.5, -size.y * 0.25)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size,
		_COLOR_LABEL)


# === COLOR / BAND LOOKUP ====================================================
# Linear band lookup — Farr value picks the band tag (StringName, the public
# API), band tag picks the fill color (private). Per balance-engineer's
# review: keep simple, no gradient/bias curve.
#
# Boundary policy: inclusive at lower bound. Exactly 70 → gold, exactly 40 →
# ivory, exactly 15 → dim. Documented in the test file (color-band block).
# This avoids 14.99-vs-15.00 visual jitter at the Kaveh trigger.

func _band_for(farr_value: float) -> StringName:
	if farr_value >= _TIER3_VISUAL_THRESHOLD:
		return BAND_GOLD
	if farr_value >= tier2_threshold:
		return BAND_IVORY
	if farr_value >= kaveh_trigger_threshold:
		return BAND_DIM
	return BAND_RED


func _fill_color_for(band: StringName) -> Color:
	match band:
		BAND_GOLD:
			return _COLOR_FILL_GOLD
		BAND_IVORY:
			return _COLOR_FILL_IVORY
		BAND_DIM:
			return _COLOR_FILL_DIM
		BAND_RED:
			return _COLOR_FILL_RED
		_:
			return _COLOR_FILL_DIM
