#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/gate/remedy-route.sh — late-gate FAIL re-entry routing (issue #140)
#
# A GATE:QUALITY / VALIDATE / INTEGRATE FAIL no longer routes to RED
# unconditionally. The evaluator tags every failed rubric item with a
# `remedy_class`, and this script is the single owner of the mapping from
# that class set to the phase the cycle re-enters:
#
#   doc      → DOC_COMMIT  (orchestrator doc commit → selected suites → GATE:QUALITY re-score)
#   test     → RED
#   impl     → GREEN       (→ VERIFY step 1 → REFINE → VALIDATE)
#   design   → ARCHITECT   (shares the GATE:PLAN → ARCHITECT re-entry cap)
#   operator → PAUSE       (the evaluator could not classify with confidence;
#                           the operator decides — active:false, phase:awaiting-user)
#
# Mixed classes go to the farthest point: design > impl > test > doc. An
# `operator` class anywhere in the set pauses regardless of the others — an
# unclassifiable item must not be carried along a route chosen for its
# neighbours.
#
# Subcommands
#   route <class>...          print the re-entry target for the class set
#   default-class <item>      print the DEFAULT class for a GATE:QUALITY rubric
#                             item name — the evaluator's starting point, which
#                             it may override with a stated reason
#   replay <ledger>           re-derive, from an issue ledger, the class and route
#                             of every recorded GATE:QUALITY FAIL entry using the
#                             default item→class table. Output, one line per
#                             entry: `<id>\t<classes>\t<route>`
#
# Exit codes: 0 ok · 2 usage / unknown class / unknown item.

set -euo pipefail

usage() {
  sed -n '/^# Subcommands/,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

# rank: higher = farther back in the cycle
rank_of() {
  case "$1" in
    doc) echo 1 ;;
    test) echo 2 ;;
    impl) echo 3 ;;
    design) echo 4 ;;
    operator) echo 9 ;;
    *) echo "remedy-route: unknown remedy_class '$1' (doc|test|impl|design|operator)" >&2; exit 2 ;;
  esac
}

route_of() {
  case "$1" in
    1) echo DOC_COMMIT ;;
    2) echo RED ;;
    3) echo GREEN ;;
    4) echo ARCHITECT ;;
    9) echo PAUSE ;;
  esac
}

cmd_route() {
  [ $# -ge 1 ] || usage
  local max=0 r
  for c in "$@"; do
    r=$(rank_of "$c")
    [ "$r" -gt "$max" ] && max=$r
  done
  route_of "$max"
}

# Default class per GATE:QUALITY rubric item. The table is the evaluator's
# starting point, not its verdict: the evaluator re-states the class per failed
# item and may override it with a reason (e.g. a `Doc updates` cap caused by a
# prompt string inside a workflow script is `impl`, not `doc`). When it cannot
# decide, it writes `operator`.
cmd_default_class() {
  [ $# -eq 1 ] || usage
  case "$1" in
    "Doc updates") echo doc ;;
    "Test coverage"|"Test quality") echo test ;;
    "Completeness"|"Quality"|"Security"|"Impact scope"|"Minimal implementation"|"Commit conventions") echo impl ;;
    "Fit") echo design ;;
    *) echo "remedy-route: unknown GATE:QUALITY item '$1'" >&2; exit 2 ;;
  esac
}

RUBRIC_ITEMS=("Completeness" "Quality" "Test coverage" "Test quality" "Security" "Fit" "Impact scope" "Minimal implementation" "Commit conventions" "Doc updates")

# replay: for each level-2 ledger heading that names GATE:QUALITY and FAIL,
# collect `<item> <score>` pairs from the heading and its `- Decision:` line,
# keep the items scored below 7, map them through the default table, and route.
cmd_replay() {
  [ $# -eq 1 ] && [ -r "$1" ] || usage
  local ledger=$1 id decision text classes cls score item found=0
  while IFS= read -r line; do
    case "$line" in
      "## "*) ;;
      *) continue ;;
    esac
    printf '%s' "$line" | grep -q 'GATE:QUALITY' || continue
    printf '%s' "$line" | grep -qw 'FAIL' || continue
    id=$(printf '%s' "$line" | sed -E 's/^## ([A-Z][0-9]+) .*/\1/')
    # the entry's Decision line: first `- Decision:` after this heading
    decision=$(awk -v h="$line" 'found && /^- Decision:/ {print; exit} $0==h {found=1}' "$ledger")
    text="$line"$'\n'"$decision"
    classes=""
    for item in "${RUBRIC_ITEMS[@]}"; do
      # first `<item> <n>` occurrence, n in 0-10, word-bounded
      score=$(printf '%s' "$text" | grep -oE "(^|[^A-Za-z])${item} ([0-9]|10)\b" | head -1 | grep -oE '[0-9]+$' || true)
      [ -n "$score" ] || continue
      if [ "$score" -lt 7 ]; then
        cls=$(cmd_default_class "$item")
        case " $classes " in *" $cls "*) ;; *) classes="${classes:+$classes }$cls" ;; esac
      fi
    done
    found=1
    if [ -z "$classes" ]; then
      printf '%s\t%s\t%s\n' "$id" "-" "UNPARSED"
    else
      # shellcheck disable=SC2086
      printf '%s\t%s\t%s\n' "$id" "$classes" "$(cmd_route $classes)"
    fi
  done < "$ledger"
  [ "$found" -eq 1 ] || { echo "remedy-route: no GATE:QUALITY FAIL entry in $ledger" >&2; exit 2; }
}

case "${1:-}" in
  route) shift; cmd_route "$@" ;;
  default-class) shift; cmd_default_class "$@" ;;
  replay) shift; cmd_replay "$@" ;;
  *) usage ;;
esac
