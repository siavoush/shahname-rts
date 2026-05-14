#!/usr/bin/env bash
# Run the Shahnameh RTS game with Godot, tee-ing all output to a log file
# that Claude Code sessions can read directly.
#
# Usage:
#   tools/run_game.sh             # interactive — opens the game window
#   tail -f /tmp/shahnameh.log    # in another terminal, OR from a Claude
#                                 # session, to watch live output
#
# Log path is fixed at /tmp/shahnameh.log so Claude doesn't need to
# guess. The file is overwritten each run (use `tee -a` if appending is
# preferred). Live-test sessions: rerun this script for each round; the
# log captures everything the editor would have printed.

set -u

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/../game" && pwd)"
LOG_PATH="${SHAHNAMEH_LOG:-/tmp/shahnameh.log}"

if [[ ! -x "$GODOT_BIN" ]]; then
	echo "Godot binary not found at: $GODOT_BIN" >&2
	echo "Set GODOT_BIN=/path/to/godot if your install is elsewhere." >&2
	exit 1
fi

echo "Logging to: $LOG_PATH"
echo "Project:    $PROJECT_DIR"
echo "Run: tail -f $LOG_PATH (from another terminal / Claude session)"
echo

# `tee` captures BOTH stdout and stderr (2>&1) so Godot's [main] /
# [click] / [build-placement] / etc. prints AND any GDScript errors
# land in the same file.
"$GODOT_BIN" --path "$PROJECT_DIR" 2>&1 | tee "$LOG_PATH"
