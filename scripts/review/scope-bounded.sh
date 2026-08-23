#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/review/scope-bounded.sh — mechanical scope judgment for a review-response cycle (issue #135)
#
# A review-response cycle (re-entered on a Medium+ reviewer finding) is `scope-bounded` when the
# judgment below holds. The judgment is a set relation, never an agent's "this is small":
#
#   triage   every Medium+ finding names a file, and the set of those files is a subset of the
#            file set of the previous cycle's PR diff;
#   fix      the fix adds no new file (a new script / workflow / hook / test file is a new
#            mechanism and leaves the bounded path).
#
# Subcommands
#   triage --findings <review-findings.md> (--pr <N> | --diff-files <file>)
#         Prints three lines for the orchestrator to append to the findings artifact:
#           scope-bounded: true|false
#           scope-bounded-finding-files: <space-separated>
#           scope-bounded-grounds: <reason>
#         Exit 0 when bounded, 1 when not, 2 on usage / unreadable input.
#   check-fix --base <rev> --head <rev>
#         Re-evaluates the fix condition after GREEN. Prints
#           scope-bounded-fix: true|false
#           scope-bounded-fix-grounds: <reason>
#         Exit 0 when the bounded path holds, 1 when it must be left, 2 on usage.
#
# Findings-table grammar (docs/autoflow-guide.md > HANDOFF step 6.5): a markdown table whose
# first cell is the severity and whose second cell is `path:line` (or `path`). Rows below the
# first "superseded" / "historical" heading are ignored — only the latest review counts.

set -euo pipefail

usage() { sed -n '/^# Subcommands/,/^# Findings-table/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2; exit 2; }

# finding_files <findings.md> → Medium+ file paths (one per line); prints "<nofile>" for a
# Medium+ row with no parseable path so the caller can fail closed.
finding_files() {
  awk '
    /^#+ .*([Ss]uperseded|[Hh]istorical)/ { stop = 1 }
    stop { next }
    /^\|/ {
      n = split($0, c, "|")
      sev = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", sev)
      if (sev != "Medium" && sev != "High" && sev != "Critical") next
      loc = c[3]; gsub(/`/, "", loc); gsub(/^[ \t]+|[ \t]+$/, "", loc)
      sub(/:[0-9].*$/, "", loc); sub(/[ \t].*$/, "", loc)
      if (loc == "" || loc == "—" || loc == "-") print "<nofile>"; else print loc
    }' "$1" | sort -u
}

cmd_triage() {
  local findings="" pr="" difffile=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --findings) findings="${2:-}"; shift 2 ;;
      --pr) pr="${2:-}"; shift 2 ;;
      --diff-files) difffile="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$findings" ] && [ -r "$findings" ] || usage
  [ -n "$pr" ] || [ -n "$difffile" ] || usage
  local diff_set
  if [ -n "$difffile" ]; then
    [ -r "$difffile" ] || usage
    diff_set=$(sort -u "$difffile")
  else
    diff_set=$(gh pr diff "$pr" --name-only | sort -u)
  fi
  local found
  found=$(finding_files "$findings")
  local files_line; files_line=$(printf '%s' "$found" | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$found" ]; then
    printf 'scope-bounded: false\nscope-bounded-finding-files:\nscope-bounded-grounds: no Medium+ finding row — nothing to bound\n'
    return 1
  fi
  if printf '%s\n' "$found" | grep -qx '<nofile>'; then
    printf 'scope-bounded: false\nscope-bounded-finding-files: %s\nscope-bounded-grounds: a Medium+ finding names no file — set relation not evaluable, full path\n' "$files_line"
    return 1
  fi
  local outside
  outside=$(comm -23 <(printf '%s\n' "$found") <(printf '%s\n' "$diff_set") | tr '\n' ' ' | sed 's/ $//')
  if [ -n "$outside" ]; then
    printf 'scope-bounded: false\nscope-bounded-finding-files: %s\nscope-bounded-grounds: outside the previous PR diff: %s\n' "$files_line" "$outside"
    return 1
  fi
  printf 'scope-bounded: true\nscope-bounded-finding-files: %s\nscope-bounded-grounds: finding files ⊆ PR diff files (%s files in diff)\n' "$files_line" "$(printf '%s\n' "$diff_set" | grep -c .)"
  return 0
}

cmd_check_fix() {
  local base="" head=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) base="${2:-}"; shift 2 ;;
      --head) head="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$base" ] && [ -n "$head" ] || usage
  local added
  added=$(git diff --diff-filter=A --name-only "$base" "$head" | tr '\n' ' ' | sed 's/ $//')
  if [ -n "$added" ]; then
    printf 'scope-bounded-fix: false\nscope-bounded-fix-grounds: the fix adds new files (new mechanism): %s\n' "$added"
    return 1
  fi
  printf 'scope-bounded-fix: true\nscope-bounded-fix-grounds: no file added between %s and %s\n' "$base" "$head"
  return 0
}

case "${1:-}" in
  triage) shift; cmd_triage "$@" ;;
  check-fix) shift; cmd_check_fix "$@" ;;
  *) usage ;;
esac
