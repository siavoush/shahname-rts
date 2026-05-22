##
## FogConfig — fog-of-war tunables: cell size + per-kind sight radii.
##
## Canonical shape: docs/FOG_DATA_CONTRACT.md §2.2 (sight-radius table) + §7
##   (BalanceData keys for fog).
##
## All sight radii are stored as integer cell counts. At 4m/cell (cell_size_meters
## = 4.0), multiply by 4 to get world-metre equivalents for human reference.
## The runtime path (wave 3A.5 register_vision_source call-sites) reads these
## integer values directly — no float conversion in the per-tick hot path.
## Per SIMULATION_CONTRACT §1.6: integer arithmetic for accumulating state.
##
## §9.L9 (fallback-by-failure-visibility-shape, session-6 retro):
##   Non-zero defaults match what Wave 3A.5 consumers actually need.
##   A sight radius of 0 is silent: a building with sight=0 reveals only its
##   own footprint, not the surrounding area. For military buildings
##   (Sarbaz-khaneh: 3, Tier-2: 2) this would be a functionally-wrong silent
##   default. Non-zero defaults ensure a misconfigured BalanceData read
##   still produces visible (wrong but diagnosable) behavior at live-test.
##
##   Exception: Khaneh / Mazra'eh / Ma'dan default to 0. These are non-military
##   buildings that the pre-flight explicitly flagged as "footprint-only
##   placeholder" — balance-engineer sets the tuned value via balance.tres at
##   Wave 3A.5 brief-time. The 0 default for these three is semantically correct
##   as a placeholder (not a bug-obscuring silent default), and a future §9.L9
##   note should record this distinction.
##
## Wave 3A.0 scope: class definition + defaults. Balance-engineer (Track 2)
## ships the balance.tres sub-resource entry with final values.
## Wave 3A.5 scope: register_vision_source call-sites in 7 buildings replace
##   their `sight=0` forward-compat placeholder reads with
##   `BalanceData.fog.sight_<kind>_cells`.
class_name FogConfig extends Resource


# --- Grid parameters ---

## World metres per fog cell. NOT read in the per-tick path (grid is computed
## once at FogSystem._ready from map bounds + this constant). Human reference:
## at 4.0m/cell, 256m map = 64 × 64 = 4096 cells per team.
## FOG_DATA_CONTRACT §1.1.
@export var cell_size_meters: float = 4.0


# --- Building sight radii (integer cells) ---
# FOG_DATA_CONTRACT §2.2 table. Human-readable world-metre equivalents
# in parentheses at 4m/cell.

## Khaneh — footprint-only placeholder (0 = footprint only, no surrounding reveal).
## Balance-engineer tunes via balance.tres at Wave 3A.5 brief-time.
@export var sight_khaneh_cells: int = 0

## Mazra'eh — footprint-only placeholder. Walkable farm; workers gather at it
## rather than defending it. Balance-engineer tunes at Wave 3A.5 brief-time.
@export var sight_mazraeh_cells: int = 0

## Ma'dan — footprint-only placeholder. Modifier-emitter on adjacent mine;
## non-military. Balance-engineer tunes at Wave 3A.5 brief-time.
@export var sight_madan_cells: int = 0

## Sarbaz-khaneh (barracks) — 3 cells (12m). Per FOG_DATA_CONTRACT §2.2.
## Military building; meaningful LOS around the entrance.
@export var sight_sarbazkhane_cells: int = 3   # 12m

## Atashkadeh (fire-house) — 2 cells (8m). Per FOG_DATA_CONTRACT §2.2.
## Sacral building; compact sight — the sacred precinct is self-contained.
@export var sight_atashkadeh_cells: int = 2    # 8m

## Sowari-khaneh (cavalry stable, Tier 2) — 2 cells (8m).
## Same compact military-institution sight as Atashkadeh.
@export var sight_sowari_khaneh_cells: int = 2  # 8m

## Tirandazi (archery range, Tier 2) — 2 cells (8m).
## Same compact military-institution sight as Atashkadeh.
@export var sight_tirandazi_cells: int = 2      # 8m

## Throne — 4 cells (16m). Per FOG_DATA_CONTRACT §2.2.
## The seat of kingship; always-on building vision anchoring the Iran start area.
@export var sight_throne_cells: int = 4         # 16m


# --- Unit sight radii (integer cells) ---
# FOG_DATA_CONTRACT §2.2 table. All are non-zero per §9.L9.
# Turan units use the same keys (symmetric by default).

## Kargar (worker) — 3 cells (12m). Per FOG_DATA_CONTRACT §2.2.
@export var sight_kargar_cells: int = 3         # 12m

## Piyade (infantry) — 3 cells (12m). Per FOG_DATA_CONTRACT §2.2.
@export var sight_piyade_cells: int = 3         # 12m

## Kamandar (archer) — 4 cells (16m). Per FOG_DATA_CONTRACT §2.2.
## Archers have slightly better situational awareness — their discipline
## requires reading the battlefield ahead of their firing arc.
@export var sight_kamandar_cells: int = 4       # 16m

## Savar (cavalry) — 4 cells (16m). Per FOG_DATA_CONTRACT §2.2.
## Mounted reconnaissance; same sight as Kamandar at Tier 1.
@export var sight_savar_cells: int = 4          # 16m

## Rostam (hero) — 5 cells (20m). Per FOG_DATA_CONTRACT §2.2.
## Pahlavans read the field further; Rostam's legend includes perceiving
## threats at range (Raksh waking him before ambushes, Shahnameh passim).
@export var sight_rostam_cells: int = 5         # 20m
