#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/canary/emit-phase-marker.sh
#
# Issue #35 — per-phase-transition marker emitter.
# Serializes ONE JSON record per phase transition (feature design §4.2) and
# APPENDS it (append-only, never truncates) to the per-issue, gitignored file
# .autoflow/issue-<N>-phases.jsonl. Prints a repo-relative path:line anchor on
# stdout; the record body is never printed.
#
# Out of scope (issue #35): wiring this emitter into any phase transition. It is
# a standalone CLI only.
#
# The timestamp has exactly ONE producer and no environment override — there is
# deliberately no PHASE_MARKER_TS escape hatch (feature design §4.2, settled).
# Format: UTC with a Z suffix, portable across BSD and GNU date.
#
# Usage:
#   scripts/canary/emit-phase-marker.sh --issue <N> --cycle <C> --phase <NAME> --event <enter|exit>
#     --issue <N>     issue number, canonical positive integer (no leading zeros)
#     --cycle <C>     cycle number, canonical positive integer
#     --phase <NAME>  free-form non-empty phase label (e.g. RED, GATE:PLAN)
#     --event <E>     exactly one of: enter exit
#
# Precedent: scripts/handoff/emit-cycle-digest.sh (header, root derivation,
# jq record build, append-only write, path:line anchor).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<'EOF'
usage: scripts/canary/emit-phase-marker.sh --issue <N> --cycle <C> --phase <NAME> --event <enter|exit>
emit-phase-marker: all four flags are required; each takes its value as the next argument.
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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue) [ "$#" -ge 2 ] || usage; ISSUE="$2"; shift 2 ;;
    --cycle) [ "$#" -ge 2 ] || usage; CYCLE="$2"; shift 2 ;;
    --phase) [ "$#" -ge 2 ] || usage; PHASE="$2"; shift 2 ;;
    --event) [ "$#" -ge 2 ] || usage; EVENT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$ISSUE" ] || die "--issue is required"
[ -n "$CYCLE" ] || die "--cycle is required"
[ -n "$PHASE" ] || die "--phase is required"
[ -n "$EVENT" ] || die "--event is required"

case "$ISSUE" in
  0 | 0* | *[!0-9]*)
    die "--issue must be a positive integer without leading zeros (got: $ISSUE)" ;;
esac
case "$CYCLE" in
  0 | 0* | *[!0-9]*)
    die "--cycle must be a positive integer without leading zeros (got: $CYCLE)" ;;
esac

case "$EVENT" in
  enter | exit) ;;
  *) die "--event must be enter or exit (got: $EVENT)" ;;
esac

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

LINE="$(jq -c -n \
  --argjson sv 1 --arg issue "#$ISSUE" --argjson cycle "$CYCLE" \
  --arg phase "$PHASE" --arg event "$EVENT" --arg ts "$TS" \
  '{schema_version:$sv, issue:$issue, cycle:$cycle, phase:$phase, event:$event, ts:$ts}')"

TARGET="$REPO_ROOT/.autoflow/issue-${ISSUE}-phases.jsonl"

# Append-only write (never a truncating redirect).
mkdir -p "$(dirname "$TARGET")"
printf '%s\n' "$LINE" >> "$TARGET"

echo ".autoflow/issue-${ISSUE}-phases.jsonl:$(wc -l < "$TARGET" | tr -d ' ')"
