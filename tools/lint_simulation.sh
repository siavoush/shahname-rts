#!/usr/bin/env bash
# lint_simulation.sh — Simulation Architecture lint rules (Sim Contract §1.4).
#
# Implements the 5 ripgrep patterns that enforce the tick-discipline invariants
# agreed in docs/SIMULATION_CONTRACT.md §1.4. Run from anywhere in the repo.
#
# Exit codes:
#   0  — clean, no violations found
#   1  — one or more violations found (details printed to stdout)
#   127 — ripgrep (rg) not found on PATH
#
# Used by: tools/git-hooks/pre-commit (CI + developer pre-commit gate)
# Owner: qa-engineer (Manifesto Principle 9 — Automated Enforcement)

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate the repo root regardless of where we're called from.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/game/scripts"

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found. Install with: brew install ripgrep" >&2
  exit 127
fi

# ---------------------------------------------------------------------------
# Tracking
# ---------------------------------------------------------------------------
VIOLATIONS=0

# Helper: print a violation header and increment the counter.
# Usage: _fail_header RULE_ID "description"
_fail_header() {
  local rule_id="$1"
  local description="$2"
  echo ""
  echo "┌── LINT VIOLATION ─────────────────────────────────────────────────"
  echo "│  Rule: ${rule_id}"
  echo "│  ${description}"
  echo "│  Matches:"
}

_fail_footer() {
  echo "└───────────────────────────────────────────────────────────────────"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# ---------------------------------------------------------------------------
# L1 — Gameplay mutation called from _process
#
# Rationale: gameplay state must only mutate inside a _sim_tick() call
# dispatched by SimClock (Sim Contract §1.1). _process runs off-tick.
#
# Strategy: a GDScript file that contains BOTH a `func _process` definition
# AND a call to apply_*(), *_tick(), or *State.update() is a violation.
# We detect each file in the scope that matches the mutation pattern, then
# confirm it also contains func _process. This avoids a full body-parser.
#
# Scope: game/scripts/**/*.gd
# ---------------------------------------------------------------------------

L1_MUTATION_PATTERN='\b(apply_\w+|\w+_tick\(|\w+State\.update\()'

# Find files that have a mutation-shaped call AND a _process definition.
L1_HITS=""
while IFS= read -r file; do
  if rg --quiet 'func\s+_process\b' "${file}" 2>/dev/null; then
    # File has _process — check if mutation pattern also appears.
    if rg --quiet "${L1_MUTATION_PATTERN}" "${file}" 2>/dev/null; then
      # Collect matching lines for the mutation calls to show the offender.
      local_hits="$(rg --with-filename --line-number "${L1_MUTATION_PATTERN}" "${file}" 2>/dev/null || true)"
      if [[ -n "${local_hits}" ]]; then
        L1_HITS="${L1_HITS}${local_hits}"$'\n'
      fi
    fi
  fi
done < <(rg --files --glob '*.gd' "${SCRIPTS_DIR}" 2>/dev/null)

if [[ -n "${L1_HITS}" ]]; then
  _fail_header "L1" "Gameplay mutation (apply_*, *_tick, *State.update) called from func _process"
  echo "${L1_HITS}" | sed 's/^/│    /'
  _fail_footer
fi

# ---------------------------------------------------------------------------
# L2 — EventBus.*.emit called from _process
#
# Rationale: write-shaped EventBus signals must not be emitted from _process
# (off-tick). Only read-shaped signals are exempt (see allowlist below).
#
# Allowlist (read-shaped signals — exempt from L2):
#   selection_changed — UI state, not sim state mutation
# The allowlist is applied by excluding matching lines from the results.
#
# Scope: game/scripts/**/*.gd
# ---------------------------------------------------------------------------

L2_EMIT_PATTERN='EventBus\.\w+\.emit\('

# Allowlist: these EventBus signal names are read-shaped and exempt from L2.
# Add new read-shaped signal names here (pipe-separated for grep -vE).
L2_ALLOWLIST='EventBus\.selection_changed\.emit\('

L2_HITS=""
while IFS= read -r file; do
  if rg --quiet 'func\s+_process\b' "${file}" 2>/dev/null; then
    if rg --quiet "${L2_EMIT_PATTERN}" "${file}" 2>/dev/null; then
      local_hits="$(rg --with-filename --line-number "${L2_EMIT_PATTERN}" "${file}" 2>/dev/null || true)"
      # Filter out allowlisted (read-shaped) signals.
      filtered="$(echo "${local_hits}" | grep -vE "${L2_ALLOWLIST}" || true)"
      if [[ -n "${filtered}" ]]; then
        L2_HITS="${L2_HITS}${filtered}"$'\n'
      fi
    fi
  fi
done < <(rg --files --glob '*.gd' "${SCRIPTS_DIR}" 2>/dev/null)

if [[ -n "${L2_HITS}" ]]; then
  _fail_header "L2" "EventBus.*.emit() called from func _process (write-shaped signals forbidden off-tick)"
  echo "${L2_HITS}" | sed 's/^/│    /'
  _fail_footer
fi

# ---------------------------------------------------------------------------
# L3 — Bare RNG outside the GameRNG autoload
#
# Rationale: gameplay RNG must flow through GameRNG (game/scripts/autoload/rng.gd)
# for determinism. Bare randi(), randf(), etc. produce non-reproducible results.
#
# Allowlist (files exempt from L3):
#   game/scripts/autoload/rng.gd — GameRNG itself is the approved RNG source
#     (this file does not exist yet at session 2; listed for when it lands in
#      session 3+ per the kickoff doc)
#
# Scope: game/scripts/**/*.gd minus the allowlist
# ---------------------------------------------------------------------------

L3_RNG_PATTERN='\brandi\(\)|\brandf\(\)|\brandi_range\(|\brandf_range\('

# Allowlist: paths exempt from L3 (space-separated for --ignore-file or manual filter).
L3_ALLOWLIST_PATH="${SCRIPTS_DIR}/autoload/rng.gd"

L3_HITS="$(rg --with-filename --line-number "${L3_RNG_PATTERN}" \
  --glob '*.gd' \
  "${SCRIPTS_DIR}" 2>/dev/null || true)"

# Remove allowlisted file from results.
if [[ -n "${L3_HITS}" ]] && [[ -n "${L3_ALLOWLIST_PATH}" ]]; then
  L3_HITS="$(echo "${L3_HITS}" | grep -v "^${L3_ALLOWLIST_PATH}:" || true)"
fi

# Filter out GDScript comment lines (lines where the code portion starts with #).
# rg output format: "path:linenum:content". We use rg itself (which is available
# and supports PCRE2) to strip lines where the content is whitespace+# (a comment).
# The pattern anchors after the second colon: matches lines like "file:42:   # comment".
if [[ -n "${L3_HITS}" ]]; then
  L3_HITS="$(echo "${L3_HITS}" | rg -v ':[0-9]+:\s*#' || true)"
fi

if [[ -n "${L3_HITS}" ]]; then
  _fail_header "L3" "Bare RNG call (randi/randf/randi_range/randf_range) outside GameRNG autoload"
  echo "│    Allowed only in: ${L3_ALLOWLIST_PATH}"
  echo "│    (rng.gd may not exist yet — it lands in a later session)"
  echo "${L3_HITS}" | sed 's/^/│    /'
  _fail_footer
fi

# ---------------------------------------------------------------------------
# L4 — String-form emit_signal("...")
#
# Rationale: signals must be emitted as EventBus.foo.emit(...) — typed, not
# as stringly-typed emit_signal("name", ...). The string form bypasses
# GDScript's type checker and makes signal consumers invisible to tooling.
#
# Scope: game/scripts/**/*.gd
# ---------------------------------------------------------------------------

L4_PATTERN='emit_signal\(\s*"'

L4_HITS="$(rg --with-filename --line-number "${L4_PATTERN}" \
  --glob '*.gd' \
  "${SCRIPTS_DIR}" 2>/dev/null || true)"

if [[ -n "${L4_HITS}" ]]; then
  _fail_header "L4" "String-form emit_signal(\"name\") used — must use EventBus.foo.emit(...) instead"
  echo "${L4_HITS}" | sed 's/^/│    /'
  _fail_footer
fi

# ---------------------------------------------------------------------------
# L5 — Wall-clock reads in gameplay code
#
# Rationale: the only "now" in gameplay is SimClock.tick / SimClock.sim_time
# (Sim Contract §1.1 hard rule). Time.get_ticks_msec() etc. are forbidden
# in gameplay scripts. TimeProvider is the single sanctioned wrapper.
#
# Allowlist (files exempt from L5):
#   game/scripts/autoload/time_provider.gd — TimeProvider IS the approved
#     wrapper around Time.get_ticks_msec(); this is the one place it lives.
#   game/scripts/autoload/sim_clock.gd — allowlisted as a safety belt
#     (sim_clock.gd does not currently call Time.get_*; listed defensively
#     in case a future clock implementation needs wall-clock drift correction)
#
# Note: The Sim Contract §1.4 table lists sim_clock.gd in the allowlist.
# The kickoff doc and time_provider.gd source both say time_provider.gd is
# the correct allowlist. Both files are listed here to satisfy both docs.
# Plan-vs-reality delta logged in docs/ARCHITECTURE.md §6.
#
# Scope: game/scripts/**/*.gd minus the allowlist
# ---------------------------------------------------------------------------

L5_PATTERN='\bTime\.get_(unix_time|ticks_msec|ticks_usec)\('

L5_ALLOWLIST_TIME_PROVIDER="${SCRIPTS_DIR}/autoload/time_provider.gd"
L5_ALLOWLIST_SIM_CLOCK="${SCRIPTS_DIR}/autoload/sim_clock.gd"

L5_HITS="$(rg --with-filename --line-number "${L5_PATTERN}" \
  --glob '*.gd' \
  "${SCRIPTS_DIR}" 2>/dev/null || true)"

# Remove allowlisted files from results.
if [[ -n "${L5_HITS}" ]]; then
  L5_HITS="$(echo "${L5_HITS}" | grep -v "^${L5_ALLOWLIST_TIME_PROVIDER}:" || true)"
  L5_HITS="$(echo "${L5_HITS}" | grep -v "^${L5_ALLOWLIST_SIM_CLOCK}:" || true)"
fi

if [[ -n "${L5_HITS}" ]]; then
  _fail_header "L5" "Wall-clock read (Time.get_ticks_msec/get_unix_time/get_ticks_usec) in gameplay code"
  echo "│    Use TimeProvider.now_ms() instead. Allowed only in:"
  echo "│      ${L5_ALLOWLIST_TIME_PROVIDER}"
  echo "│      ${L5_ALLOWLIST_SIM_CLOCK}"
  echo "${L5_HITS}" | sed 's/^/│    /'
  _fail_footer
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "${VIOLATIONS}" -eq 0 ]]; then
  echo "lint_simulation.sh — OK (0 violations across L1-L5)"
  exit 0
else
  echo "lint_simulation.sh — FAILED (${VIOLATIONS} rule(s) violated)"
  echo "Fix the violations above before committing."
  exit 1
fi
