#!/usr/bin/env python3
"""
aggregate_match_results.py — Wave 3-Sim Track 3 aggregation script.

Reads an NDJSON file produced by run_ai_vs_ai_batch.sh (one match result per
line) and writes an aggregate summary JSON to --output.

Usage:
    python3 tools/aggregate_match_results.py <results.ndjson> [--output <agg.json>]

Output schema (aggregate.json):
  {
    "batch_meta": {
      "total_matches": int,
      "valid_matches": int,         # lines that parsed as JSON with required fields
      "invalid_lines": int,
      "generated_at": "ISO-8601"
    },
    "outcomes": {
      "iran_win":  int,
      "turan_win": int,
      "stalemate": int,
      "iran_win_pct":  float,       # % of valid matches
      "turan_win_pct": float,
      "stalemate_pct": float
    },
    "duration_ticks": {
      "min": int, "max": int,
      "p25": float, "p50": float, "p75": float, "p95": float,
      "mean": float
    },
    "duration_seconds": {
      "min": float, "max": float,
      "p25": float, "p50": float, "p75": float, "p95": float,
      "mean": float
    },
    "first_engagement_tick": {
      "min": int, "max": int,
      "p50": float, "mean": float
    },
    "iran_economy_at_end": {
      "coin_x100": {"median": float, "mean": float, "min": int, "max": int},
      "grain_x100": {"median": float, "mean": float, "min": int, "max": int},
      "farr_x100":  {"median": float, "mean": float, "min": int, "max": int}
    },
    "turan_economy_at_end": {
      "coin_x100": {"median": float, "mean": float, "min": int, "max": int},
      "grain_x100": {"median": float, "mean": float, "min": int, "max": int},
      "farr_x100":  {"median": float, "mean": float, "min": int, "max": int}
    },
    "military_at_end": {
      "iran_units_alive":  {"median": float, "mean": float},
      "turan_units_alive": {"median": float, "mean": float},
      "iran_buildings_alive":  {"median": float, "mean": float},
      "turan_buildings_alive": {"median": float, "mean": float}
    },
    "events_summary": {
      "turan_probes_fired":       {"median": float, "mean": float, "total": int},
      "buildings_destroyed_total": {"median": float, "mean": float, "total": int},
      "units_killed_total":       {"median": float, "mean": float, "total": int}
    }
  }
"""

import argparse
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path


def _percentile(sorted_vals: list, pct: float) -> float:
    """Nearest-rank percentile on a pre-sorted list. Returns 0.0 on empty."""
    if not sorted_vals:
        return 0.0
    n = len(sorted_vals)
    idx = max(0, min(n - 1, math.ceil(pct / 100.0 * n) - 1))
    return float(sorted_vals[idx])


def _stats(values: list) -> dict:
    if not values:
        return {"min": 0, "max": 0, "p25": 0.0, "p50": 0.0,
                "p75": 0.0, "p95": 0.0, "mean": 0.0}
    s = sorted(values)
    mean = sum(s) / len(s)
    return {
        "min": s[0],
        "max": s[-1],
        "p25": _percentile(s, 25),
        "p50": _percentile(s, 50),
        "p75": _percentile(s, 75),
        "p95": _percentile(s, 95),
        "mean": round(mean, 2),
    }


def _stats_short(values: list) -> dict:
    """Compact stats without p25/p75/p95 — for lower-signal fields."""
    if not values:
        return {"min": 0, "max": 0, "p50": 0.0, "mean": 0.0}
    s = sorted(values)
    return {
        "min": s[0],
        "max": s[-1],
        "p50": _percentile(s, 50),
        "mean": round(sum(s) / len(s), 2),
    }


def _economy_stats(values: list) -> dict:
    if not values:
        return {"median": 0.0, "mean": 0.0, "min": 0, "max": 0}
    s = sorted(values)
    return {
        "median": _percentile(s, 50),
        "mean": round(sum(s) / len(s), 2),
        "min": s[0],
        "max": s[-1],
    }


def _military_stats(values: list) -> dict:
    if not values:
        return {"median": 0.0, "mean": 0.0}
    s = sorted(values)
    return {
        "median": _percentile(s, 50),
        "mean": round(sum(s) / len(s), 2),
    }


def _event_stats(values: list) -> dict:
    if not values:
        return {"median": 0.0, "mean": 0.0, "total": 0}
    s = sorted(values)
    return {
        "median": _percentile(s, 50),
        "mean": round(sum(s) / len(s), 2),
        "total": sum(values),
    }


def aggregate(ndjson_path: Path) -> dict:
    lines = ndjson_path.read_text(encoding="utf-8").splitlines()
    total = len([l for l in lines if l.strip()])
    records = []
    invalid = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            invalid += 1
            continue
        # Require minimum fields; skip malformed records
        if not all(k in obj for k in ("match_id", "outcome", "duration_ticks")):
            invalid += 1
            continue
        records.append(obj)

    valid = len(records)
    outcomes = {"iran_win": 0, "turan_win": 0, "stalemate": 0}
    duration_ticks_vals = []
    duration_secs_vals = []
    first_eng_vals = []
    iran_coin, iran_grain, iran_farr = [], [], []
    turan_coin, turan_grain, turan_farr = [], [], []
    iran_units, turan_units = [], []
    iran_bldgs, turan_bldgs = [], []
    probes_vals, bldgs_destroyed_vals, units_killed_vals = [], [], []

    for r in records:
        oc = r.get("outcome", "stalemate")
        if oc in outcomes:
            outcomes[oc] += 1
        else:
            outcomes["stalemate"] += 1

        duration_ticks_vals.append(int(r.get("duration_ticks", 0)))
        duration_secs_vals.append(float(r.get("duration_seconds", 0.0)))

        if "first_engagement_tick" in r:
            first_eng_vals.append(int(r["first_engagement_tick"]))

        iran = r.get("iran", {})
        iran_coin.append(int(iran.get("coin_x100_at_end", 0)))
        iran_grain.append(int(iran.get("grain_x100_at_end", 0)))
        iran_farr.append(int(iran.get("farr_x100_at_end", 0)))
        iran_units.append(int(iran.get("units_alive_at_end", 0)))
        iran_bldgs.append(int(iran.get("buildings_alive_at_end", 0)))

        turan = r.get("turan", {})
        turan_coin.append(int(turan.get("coin_x100_at_end", 0)))
        turan_grain.append(int(turan.get("grain_x100_at_end", 0)))
        turan_farr.append(int(turan.get("farr_x100_at_end", 0)))
        turan_units.append(int(turan.get("units_alive_at_end", 0)))
        turan_bldgs.append(int(turan.get("buildings_alive_at_end", 0)))

        ev = r.get("events_summary", {})
        probes_vals.append(int(ev.get("turan_probes_fired", 0)))
        bldgs_destroyed_vals.append(int(ev.get("buildings_destroyed_total", 0)))
        units_killed_vals.append(int(ev.get("units_killed_total", 0)))

    def pct(n: int) -> float:
        if valid == 0:
            return 0.0
        return round(n / valid * 100.0, 1)

    return {
        "batch_meta": {
            "total_matches": total,
            "valid_matches": valid,
            "invalid_lines": invalid,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        },
        "outcomes": {
            "iran_win":  outcomes["iran_win"],
            "turan_win": outcomes["turan_win"],
            "stalemate": outcomes["stalemate"],
            "iran_win_pct":  pct(outcomes["iran_win"]),
            "turan_win_pct": pct(outcomes["turan_win"]),
            "stalemate_pct": pct(outcomes["stalemate"]),
        },
        "duration_ticks":   _stats(duration_ticks_vals),
        "duration_seconds": _stats(duration_secs_vals),
        "first_engagement_tick": _stats_short(first_eng_vals),
        "iran_economy_at_end": {
            "coin_x100":  _economy_stats(iran_coin),
            "grain_x100": _economy_stats(iran_grain),
            "farr_x100":  _economy_stats(iran_farr),
        },
        "turan_economy_at_end": {
            "coin_x100":  _economy_stats(turan_coin),
            "grain_x100": _economy_stats(turan_grain),
            "farr_x100":  _economy_stats(turan_farr),
        },
        "military_at_end": {
            "iran_units_alive":      _military_stats(iran_units),
            "turan_units_alive":     _military_stats(turan_units),
            "iran_buildings_alive":  _military_stats(iran_bldgs),
            "turan_buildings_alive": _military_stats(turan_bldgs),
        },
        "events_summary": {
            "turan_probes_fired":        _event_stats(probes_vals),
            "buildings_destroyed_total": _event_stats(bldgs_destroyed_vals),
            "units_killed_total":        _event_stats(units_killed_vals),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate NDJSON match results into a summary JSON."
    )
    parser.add_argument("ndjson", type=Path, help="Path to results.ndjson")
    parser.add_argument("--output", "-o", type=Path, default=None,
                        help="Output path for aggregate.json (default: stdout)")
    args = parser.parse_args()

    if not args.ndjson.exists():
        print(f"Error: {args.ndjson} does not exist", file=sys.stderr)
        return 1

    result = aggregate(args.ndjson)

    if args.output:
        args.output.write_text(
            json.dumps(result, indent=2) + "\n", encoding="utf-8"
        )
        print(f"Aggregate written to: {args.output}")
    else:
        print(json.dumps(result, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
