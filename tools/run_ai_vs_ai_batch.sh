#!/usr/bin/env bash
# run_ai_vs_ai_batch.sh — Wave 3-Sim Track 3 batch runner.
#
# Runs N consecutive headless AI-vs-AI Godot matches, writes one NDJSON line
# per match to <output_dir>/results.ndjson, then calls the aggregation script
# to produce <output_dir>/aggregate.json.
#
# Usage:
#   tools/run_ai_vs_ai_batch.sh <N> [--master-seed <S>] [--output <dir>]
#                               [--godot <path>] [--runner-script <res-path>]
#                               [--timeout-ticks <T>] [--dry-run]
#
# Required:
#   N                    Number of matches to run (positive integer).
#
# Optional:
#   --master-seed <S>    Integer master seed. Each match gets seed:
#                          match_seed = master_seed XOR match_index
#                        Default: random (timestamp-based).
#   --output <dir>       Directory for results.ndjson + aggregate.json.
#                        Default: /tmp/ai_vs_ai_<timestamp>
#   --godot <path>       Path to Godot binary.
#                        Default: /Applications/Godot.app/Contents/MacOS/Godot
#   --runner-script <r>  res:// path to headless_match_runner.gd entry point.
#                        Default: res://scripts/sim/headless_match_runner.gd
#   --timeout-ticks <T>  Hard match timeout in sim ticks (default: 60000).
#   --dry-run            Write 3 fixture NDJSON lines instead of launching Godot.
#                        Used by test_batch_runner_dry_run.gd validation tests.
#
# Output layout:
#   <output_dir>/results.ndjson      — one JSON object per line, per match
#   <output_dir>/aggregate.json      — summary produced by aggregate_match_results.py
#   <output_dir>/match_<N>.log       — per-match stdout capture (for debugging)
#
# Exit codes:
#   0  All N matches completed (some may be stalemates; that's a balance signal).
#   1  Fatal error (bad args, Godot binary not found, output dir not writable).
#   2  One or more matches produced invalid/missing NDJSON (partial batch).

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
RUNNER_SCRIPT="res://scripts/sim/headless_match_runner.gd"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="/tmp/ai_vs_ai_${TIMESTAMP}"
MASTER_SEED=""
TIMEOUT_TICKS=60000
DRY_RUN=0
N_MATCHES=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GAME_DIR="${REPO_ROOT}/game"
AGGREGATE_PY="${SCRIPT_DIR}/aggregate_match_results.py"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <N> [--master-seed <S>] [--output <dir>] [--godot <path>]" >&2
    echo "           [--runner-script <res-path>] [--timeout-ticks <T>] [--dry-run]" >&2
    exit 1
fi

N_MATCHES="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --master-seed)
            MASTER_SEED="$2"; shift 2 ;;
        --output)
            OUTPUT_DIR="$2"; shift 2 ;;
        --godot)
            GODOT_BIN="$2"; shift 2 ;;
        --runner-script)
            RUNNER_SCRIPT="$2"; shift 2 ;;
        --timeout-ticks)
            TIMEOUT_TICKS="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        *)
            echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate N
# ---------------------------------------------------------------------------
if ! [[ "${N_MATCHES}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: N must be a positive integer, got: '${N_MATCHES}'" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Default master-seed to timestamp if not provided
# ---------------------------------------------------------------------------
if [[ -z "${MASTER_SEED}" ]]; then
    MASTER_SEED="$(date +%s)"
    echo "No --master-seed provided; using timestamp seed: ${MASTER_SEED}"
fi

# ---------------------------------------------------------------------------
# Validate Godot binary (skip for dry-run)
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" -eq 0 ]] && [[ ! -x "${GODOT_BIN}" ]]; then
    echo "Error: Godot binary not found or not executable: ${GODOT_BIN}" >&2
    echo "  Set --godot <path> to the correct Godot binary." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Create output directory
# ---------------------------------------------------------------------------
mkdir -p "${OUTPUT_DIR}"
RESULTS_FILE="${OUTPUT_DIR}/results.ndjson"
AGGREGATE_FILE="${OUTPUT_DIR}/aggregate.json"

echo ""
echo "=== AI-vs-AI Batch Runner ==="
echo "  Matches:       ${N_MATCHES}"
echo "  Master seed:   ${MASTER_SEED}"
echo "  Output dir:    ${OUTPUT_DIR}"
echo "  Timeout ticks: ${TIMEOUT_TICKS}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  Mode:          DRY-RUN (fixture NDJSON, no Godot invocation)"
else
    echo "  Godot binary:  ${GODOT_BIN}"
    echo "  Runner script: ${RUNNER_SCRIPT}"
fi
echo ""

# Truncate/create results file
: > "${RESULTS_FILE}"

FAILED_MATCHES=0
COMPLETED_MATCHES=0

# ---------------------------------------------------------------------------
# Match loop
# ---------------------------------------------------------------------------
for (( i=0; i<N_MATCHES; i++ )); do
    MATCH_ID="$(printf 'match_%04d' "${i}")"
    # Per §3 Q3: match_seed = master_seed XOR match_index (deterministic derivation)
    MATCH_SEED=$(( MASTER_SEED ^ i ))
    MATCH_LOG="${OUTPUT_DIR}/${MATCH_ID}.log"

    echo "[batch] Starting ${MATCH_ID} (seed=${MATCH_SEED}) [$(( i+1 ))/${N_MATCHES}]"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        # -----------------------------------------------------------------------
        # Dry-run: emit a fixture NDJSON line with deterministic values.
        # The fixture encodes the match_index so tests can verify ordering.
        # Outcome rotates: iran_win / turan_win / stalemate for indices 0/1/2+.
        # -----------------------------------------------------------------------
        case $(( i % 3 )) in
            0) OUTCOME="iran_win";   WINNER_TEAM=1; IRAN_THRONE_DEAD="false"; TURAN_THRONE_DEAD="true"  ;;
            1) OUTCOME="turan_win";  WINNER_TEAM=2; IRAN_THRONE_DEAD="true";  TURAN_THRONE_DEAD="false" ;;
            *)  OUTCOME="stalemate"; WINNER_TEAM=0; IRAN_THRONE_DEAD="false"; TURAN_THRONE_DEAD="false" ;;
        esac
        DURATION_TICKS=$(( 18000 + i * 1234 ))
        DURATION_SECONDS=$(echo "scale=1; ${DURATION_TICKS} / 30" | bc)
        FIRST_ENG_TICK=$(( 3600 + i * 100 ))

        printf '{
  "match_id": "%s",
  "seed": %d,
  "outcome": "%s",
  "winner_team": %d,
  "duration_ticks": %d,
  "duration_seconds": %s,
  "first_engagement_tick": %d,
  "iran": {
    "throne_destroyed": %s,
    "throne_hp_pct_at_end": %s,
    "workers_alive_at_end": 4,
    "units_alive_at_end": 6,
    "buildings_alive_at_end": 4,
    "buildings_destroyed": 0,
    "coin_x100_at_end": 18000,
    "grain_x100_at_end": 9000,
    "farr_x100_at_end": 4500
  },
  "turan": {
    "throne_destroyed": %s,
    "throne_hp_pct_at_end": %s,
    "workers_alive_at_end": 2,
    "units_alive_at_end": 3,
    "buildings_alive_at_end": 1,
    "buildings_destroyed": 1,
    "coin_x100_at_end": 8000,
    "grain_x100_at_end": 4000,
    "farr_x100_at_end": 2000
  },
  "events_summary": {
    "turan_probes_fired": %d,
    "buildings_destroyed_total": 1,
    "units_killed_total": 12
  }
}\n' \
            "${MATCH_ID}" "${MATCH_SEED}" "${OUTCOME}" "${WINNER_TEAM}" \
            "${DURATION_TICKS}" "${DURATION_SECONDS}" "${FIRST_ENG_TICK}" \
            "${IRAN_THRONE_DEAD}" \
            "$([ "${IRAN_THRONE_DEAD}" = "true" ] && echo "0.0" || echo "87.5")" \
            "${TURAN_THRONE_DEAD}" \
            "$([ "${TURAN_THRONE_DEAD}" = "true" ] && echo "0.0" || echo "72.3")" \
            "$(( i + 1 ))" \
        | tr -d '\n' >> "${RESULTS_FILE}"
        echo "" >> "${RESULTS_FILE}"

        echo "[batch] ${MATCH_ID} complete — outcome=${OUTCOME} ticks=${DURATION_TICKS} (dry-run fixture)"
        COMPLETED_MATCHES=$(( COMPLETED_MATCHES + 1 ))
        continue
    fi

    # -----------------------------------------------------------------------
    # Real run: invoke Godot headless with the match runner script.
    # HeadlessMatchRunner reads --match-id, --seed, --timeout-ticks from argv
    # and emits one NDJSON line to stdout on completion.
    # -----------------------------------------------------------------------
    set +e
    "${GODOT_BIN}" \
        --headless \
        --path "${GAME_DIR}" \
        -s "${RUNNER_SCRIPT}" \
        --match-id "${MATCH_ID}" \
        --seed "${MATCH_SEED}" \
        --timeout-ticks "${TIMEOUT_TICKS}" \
        > "${MATCH_LOG}" 2>&1
    EXIT_CODE=$?
    set -e

    if [[ "${EXIT_CODE}" -ne 0 ]]; then
        echo "[batch] WARNING: ${MATCH_ID} Godot exited with code ${EXIT_CODE}" >&2
        FAILED_MATCHES=$(( FAILED_MATCHES + 1 ))
        continue
    fi

    # Extract the NDJSON line from runner stdout (last non-empty line starting with '{')
    NDJSON_LINE="$(rg --no-line-number '^\{' "${MATCH_LOG}" | tail -1 || true)"
    if [[ -z "${NDJSON_LINE}" ]]; then
        echo "[batch] WARNING: ${MATCH_ID} produced no NDJSON output" >&2
        FAILED_MATCHES=$(( FAILED_MATCHES + 1 ))
        continue
    fi

    # Validate it parses as JSON
    if ! echo "${NDJSON_LINE}" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "[batch] WARNING: ${MATCH_ID} produced invalid JSON: ${NDJSON_LINE}" >&2
        FAILED_MATCHES=$(( FAILED_MATCHES + 1 ))
        continue
    fi

    echo "${NDJSON_LINE}" >> "${RESULTS_FILE}"
    OUTCOME="$(echo "${NDJSON_LINE}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('outcome','?'))")"
    DURATION="$(echo "${NDJSON_LINE}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('duration_ticks','?'))")"
    echo "[batch] ${MATCH_ID} complete — outcome=${OUTCOME} ticks=${DURATION}"
    COMPLETED_MATCHES=$(( COMPLETED_MATCHES + 1 ))
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "[batch] === Batch complete ==="
echo "[batch]   Completed: ${COMPLETED_MATCHES}/${N_MATCHES}"
if [[ "${FAILED_MATCHES}" -gt 0 ]]; then
    echo "[batch]   Failed:    ${FAILED_MATCHES}/${N_MATCHES} (see per-match logs in ${OUTPUT_DIR})"
fi
echo "[batch]   Results:   ${RESULTS_FILE}"

# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------
if [[ "${COMPLETED_MATCHES}" -gt 0 ]]; then
    echo ""
    echo "[batch] Running aggregation..."
    if python3 "${AGGREGATE_PY}" "${RESULTS_FILE}" --output "${AGGREGATE_FILE}"; then
        echo "[batch]   Aggregate: ${AGGREGATE_FILE}"
    else
        echo "[batch]   WARNING: aggregation failed — results.ndjson is still valid" >&2
    fi
fi

if [[ "${FAILED_MATCHES}" -gt 0 ]]; then
    exit 2
fi
exit 0
