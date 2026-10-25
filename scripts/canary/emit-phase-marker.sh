#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# scripts/canary/emit-phase-marker.sh
#
# Issue #35 — per-phase-transition marker emitter.
# Serializes ONE JSON record per phase transition (feature design §4.2) and
# APPENDS it (append-only, never truncates) to the attempt's file
# issue-<N>-phases.jsonl in the attempt's record directory, which the caller
# names with --records (ADR-0038 D4). Prints an absolute path:line anchor on
# stdout; the record body is never printed.
#
# Out of scope (issue #35): wiring this emitter into any phase transition. It is
# a standalone CLI only; its one reader is scripts/metrics/cycle-metrics.py,
# which reads the records left before ADR-0038 (D10).
#
# The timestamp has exactly ONE producer and no environment override — there is
# deliberately no PHASE_MARKER_TS escape hatch (feature design §4.2, settled).
# Format: UTC with a Z suffix, portable across BSD and GNU date.
#
# Usage:
#   scripts/canary/emit-phase-marker.sh --issue <N> --cycle <C> --phase <NAME> --event <enter|exit> --records <dir>
#     --issue <N>     issue number, canonical positive integer (no leading zeros)
#     --cycle <C>     cycle number, canonical positive integer
#     --phase <NAME>  free-form non-empty phase label (e.g. BUILD, GATE:PLAN)
#     --event <E>     exactly one of: enter exit
#     --records <dir> the attempt's record directory, an existing directory

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: scripts/canary/emit-phase-marker.sh --issue <N> --cycle <C> --phase <NAME> --event <enter|exit> --records <dir>
emit-phase-marker: all five flags are required; each takes its value as the next argument.
EOF
  exit 2
}

die() {
  echo "emit-phase-marker: $1" >&2
  exit 2
}

ISSUE=""
CYCLE=""
PHASE=""
EVENT=""
RECORDS=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue) [ "$#" -ge 2 ] || usage; ISSUE="$2"; shift 2 ;;
    --cycle) [ "$#" -ge 2 ] || usage; CYCLE="$2"; shift 2 ;;
    --phase) [ "$#" -ge 2 ] || usage; PHASE="$2"; shift 2 ;;
    --event) [ "$#" -ge 2 ] || usage; EVENT="$2"; shift 2 ;;
    --records) [ "$#" -ge 2 ] || usage; RECORDS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$ISSUE" ] || die "--issue is required"
[ -n "$CYCLE" ] || die "--cycle is required"
[ -n "$PHASE" ] || die "--phase is required"
[ -n "$EVENT" ] || die "--event is required"
[ -n "$RECORDS" ] || die "--records is required"
[ -d "$RECORDS" ] || die "--records is not a directory: $RECORDS"

require_canonical_positive_int() {
  case "$2" in
    0 | 0* | *[!0-9]*)
      die "--$1 must be a positive integer without leading zeros (got: $2)" ;;
  esac
}
require_canonical_positive_int issue "$ISSUE"
require_canonical_positive_int cycle "$CYCLE"

case "$EVENT" in
  enter | exit) ;;
  *) die "--event must be enter or exit (got: $EVENT)" ;;
esac

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

LINE="$(jq -c -n \
  --argjson sv 1 --arg issue "#$ISSUE" --argjson cycle "$CYCLE" \
  --arg phase "$PHASE" --arg event "$EVENT" --arg ts "$TS" \
  '{schema_version:$sv, issue:$issue, cycle:$cycle, phase:$phase, event:$event, ts:$ts}')"

DIR="$(cd -P "$RECORDS" && pwd)"
TARGET="$DIR/issue-${ISSUE}-phases.jsonl"

# Append-only write (never a truncating redirect).
printf '%s\n' "$LINE" >> "$TARGET"

echo "$TARGET:$(wc -l < "$TARGET" | tr -d ' ')"
