#!/usr/bin/env bash
# run_tests.sh — headless GUT test runner.
#
# Usage: from the game/ directory, run `./run_tests.sh`. From the repo root,
# run `game/run_tests.sh`. Exits non-zero if any test fails. Used by the
# pre-commit hook (qa-engineer, session 2).

set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT:-godot}"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1; then
  echo "ERROR: '${GODOT_BIN}' not on PATH. Install Godot 4 (e.g. brew install --cask godot)" >&2
  exit 127
fi

cd "${GAME_DIR}"
"${GODOT_BIN}" --headless --path "${GAME_DIR}" -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gexit
