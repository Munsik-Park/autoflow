#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# ARCHITECT relay — orchestrator isolation check (issue #179, ADR-0023 D4)
# =============================================================================
# Deliberation Isolation (CLAUDE.md, docs/design-rationale.md > Decision 8)
# requires that the orchestrator never receives the round-by-round prose.
# Under the relay the participants write their turns to the transcript file
# and return one line, so the property is checkable after the fact: no turn
# body may appear in the orchestrator's own session transcript. This script
# takes the first N characters of every turn body in the relay transcript,
# JSON-encodes them the way the session log stores text, and searches the
# session JSONL for that exact sequence (and for the raw form, in case a
# fragment was logged unescaped). One hit is a leak.
#
# Usage:
#   isolation-check.sh <relay-transcript.md> <session.jsonl> [--chars <N>]
#     N defaults to 200 (the review §6 metric).
#
# Prints one line per turn — `turn <n>: clean` or `turn <n>: LEAK (<hits>)` —
# and a summary line. Exit: 0 every turn clean | 1 at least one leak |
# 2 usage / missing file / jq absent.
# =============================================================================

set -uo pipefail

usage() { echo "usage: isolation-check.sh <relay-transcript.md> <session.jsonl> [--chars <N>]" >&2; exit 2; }

[ $# -ge 2 ] || usage
T="$1"; S="$2"; shift 2
CHARS=200
while [ $# -gt 0 ]; do
  case "$1" in
    --chars) [ $# -ge 2 ] || usage; CHARS="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$CHARS" in ''|*[!0-9]*|0) usage ;; esac
[ -f "$T" ] || { echo "isolation-check: $T not found" >&2; exit 2; }
[ -f "$S" ] || { echo "isolation-check: $S not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "isolation-check: jq is required" >&2; exit 2; }

# Turn bodies: everything between a `### Turn n` heading and the next
# level-2/level-3 heading, leading blank lines dropped. Emitted as
# NUL-separated "n\tbody" records so multi-line bodies survive intact.
bodies() {
  LC_ALL=C awk '
    BEGIN { inb = 0; n = "" }
    /^### Turn [0-9]+ / {
      if (inb) { printf("%s\t%s%c", n, body, 0) }
      n = $0; sub(/^### Turn /, "", n); sub(/ .*$/, "", n)
      body = ""; inb = 1; started = 0; next
    }
    /^(##|###) / { if (inb) { printf("%s\t%s%c", n, body, 0) }; inb = 0; next }
    {
      if (!inb) next
      if (!started && $0 ~ /^[[:space:]]*$/) next
      started = 1
      body = body (body == "" ? "" : "\n") $0
    }
    END { if (inb) printf("%s\t%s%c", n, body, 0) }
  ' "$T"
}

leaks=0; checked=0
while IFS= read -r -d '' rec; do
  n="${rec%%	*}"; body="${rec#*	}"
  if [ -z "$body" ]; then
    echo "turn $n: (empty body — skipped)"
    continue
  fi
  # First N characters (character-wise, not byte-wise: the transcripts are UTF-8).
  needle="$(printf '%s' "$body" | LC_ALL=en_US.UTF-8 cut -c1-"$CHARS" 2>/dev/null || printf '%s' "$body" | head -c "$CHARS")"
  [ -n "$needle" ] || { echo "turn $n: (empty needle — skipped)"; continue; }
  # The session log stores text JSON-encoded: newlines as \n, quotes as \", etc.
  escaped="$(printf '%s' "$needle" | jq -Rs . | sed -e 's/^"//' -e 's/"$//')"
  hits=$(grep -cF -- "$escaped" "$S" 2>/dev/null || true)
  raw_hits=0
  case "$needle" in
    *$'\n'*) ;;  # a multi-line raw needle cannot occur on one JSONL line
    *) raw_hits=$(grep -cF -- "$needle" "$S" 2>/dev/null || true) ;;
  esac
  total=$(( ${hits:-0} + ${raw_hits:-0} ))
  checked=$((checked + 1))
  if [ "$total" -gt 0 ]; then
    echo "turn $n: LEAK ($total hit(s) in $S)"
    leaks=$((leaks + 1))
  else
    echo "turn $n: clean"
  fi
done < <(bodies)

echo "isolation-check: $checked turn(s) checked, $leaks leak(s), first $CHARS character(s) of each body"
[ "$leaks" = "0" ]
