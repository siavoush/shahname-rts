#!/usr/bin/env bash
# run_tests.sh — headless GUT test runner.
#
# Usage: from the game/ directory, run `./run_tests.sh`. From the repo root,
# run `game/run_tests.sh`. Exits non-zero if any test fails. Used by the
# pre-commit hook (qa-engineer, session 2).
#
# Session-11 hotfix (review TEST-2 — cold-start false-green): on a fresh
# worktree that has never run the Godot import pass, GUT collects ZERO tests
# (class_name registry empty, scripts fail to parse) and still exits 0 —
# the pre-commit gate passes vacuously. We now parse GUT's own totals line
# and fail loudly when no tests ran.

set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT:-godot}"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1; then
  echo "ERROR: '${GODOT_BIN}' not on PATH. Install Godot 4 (e.g. brew install --cask godot)" >&2
  exit 127
fi

cd "${GAME_DIR}"

# Capture output so we can both stream it and parse the totals line.
# `|| GUT_EXIT=$?` keeps set -e from short-circuiting before we print.
GUT_EXIT=0
OUTPUT="$("${GODOT_BIN}" --headless --path "${GAME_DIR}" -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gexit 2>&1)" || GUT_EXIT=$?

printf '%s\n' "${OUTPUT}"

if [ "${GUT_EXIT}" -ne 0 ]; then
  exit "${GUT_EXIT}"
fi

# Cold-start false-green guard: GUT prints a totals block ending in
# "Tests             <N>". Zero or missing => the suite did not actually
# run (most likely a fresh worktree missing the import pass).
TESTS_RUN="$(printf '%s\n' "${OUTPUT}" | sed -n 's/^Tests[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p' | tail -1)"
if [ -z "${TESTS_RUN}" ] || [ "${TESTS_RUN}" -eq 0 ]; then
  echo "" >&2
  echo "ERROR: GUT reported ${TESTS_RUN:-no} tests run — refusing the vacuous green." >&2
  echo "  Likely cause: fresh worktree without a Godot import pass." >&2
  echo "  Fix:  cd game && ${GODOT_BIN} --headless --import" >&2
  exit 1
fi
