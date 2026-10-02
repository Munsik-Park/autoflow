#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/review-gate.sh
#
# HANDOFF review triage — what is read once the findings file exists. For one
# reviewed pull request it reads the two signals the triage branches on — the
# verdict (`max_severity`, written to the PR's findings file by the review
# aggregator) and the `blocked-by-review` label — names the case, and counts
# the auto-resolution attempts on record. It changes nothing: the label is the
# aggregator's to set, the state file and the ledger the orchestrator's.
#
# What it does not decide: whether a finding holds, its class, its route, or
# whether a Low finding is worth fixing now (docs/units/delivery.md > Review
# triage).
#
# Attempt count: the level-2 ledger headings ending in `[review-autofix]` after
# the last heading ending in `[reentry-decision]` — the operator's decision to
# continue after a pause — or in the whole ledger when there is none.
#
# Output:
#   pr: <owner>/<name>#<N>
#   max_severity: <level>
#   label: present | absent
#   findings: <n> (Medium+: <m>)
#   attempts: <k> of 7
#   backstop: needed — <why>     (a Medium+ verdict on a PR without the label)
#   case: clean | low-only | resolve | cap | relabel
#
# Exit codes:
#   0   clean — no label, no finding
#   10  resolve — a Medium+ verdict; route its findings (attempt <k+1>). With
#       `backstop: needed`, the orchestrator attaches the label itself first
#   11  cap — a Medium+ verdict with 7 attempts on record; pause for the operator
#   12  relabel — the label is present on a verdict below Medium (or `None`):
#       the aggregator's label removal did not land, not a code finding
#   13  low-only — no label, findings below Medium
#   2   the findings file is absent or does not keep its contract (no single
#       readable `max_severity:` line, a `pr:` line naming another PR, or a
#       Medium+ row without a `remedy_class`) — the aggregator runs again
#
# A row whose disposition cell reads `rejected` — a finding the aggregator
# found does not hold — is a record, not a finding: it is counted in neither
# the findings nor the Medium+ total.
#   3   a `gh` read failed
#   64  usage
#
# Usage: scripts/handoff/review-gate.sh --issue <N> --pr <P> [--repo <owner/name>]
#                                       [--findings <file>] [--ledger <file>]

set -uo pipefail

TAG="review-gate"
CAP=7
ISSUE=""
PR=""
REPO=""
FINDINGS=""
LEDGER=""
usage() { echo "Usage: $0 --issue <N> --pr <P> [--repo <owner/name>] [--findings <file>] [--ledger <file>]"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || { usage >&2; exit 64; }; ISSUE="${2#\#}"; shift 2 ;;
    --pr) [ $# -ge 2 ] || { usage >&2; exit 64; }; PR="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || { usage >&2; exit 64; }; REPO="$2"; shift 2 ;;
    --findings) [ $# -ge 2 ] || { usage >&2; exit 64; }; FINDINGS="$2"; shift 2 ;;
    --ledger) [ $# -ge 2 ] || { usage >&2; exit 64; }; LEDGER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) usage >&2; exit 64 ;; esac
case "$PR" in ''|*[!0-9]*) usage >&2; exit 64 ;; esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
REPO_ARGS=()
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || { echo "[$TAG] cannot resolve the repository (gh repo view)" >&2; exit 3; }
else
  REPO_ARGS=(--repo "$REPO")
fi
[ -n "$FINDINGS" ] || FINDINGS=".autoflow/issue-$ISSUE-review-findings-${REPO%%/*}.${REPO#*/}-$PR.md"
[ -n "$LEDGER" ] || LEDGER=".autoflow/issue-$ISSUE-ledger.md"

echo "pr: $REPO#$PR"
if [ ! -f "$FINDINGS" ]; then
  echo "findings-file defect: $FINDINGS does not exist"
  exit 2
fi
named="$(sed -nE 's/^pr:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' "$FINDINGS" | sort -u)"
if [ -n "$named" ] && [ "$named" != "$REPO#$PR" ]; then
  echo "findings-file defect: $FINDINGS names $(printf '%s' "$named" | tr '\n' ' ')on its pr: line, not $REPO#$PR"
  exit 2
fi
sev="$(sed -nE 's/^max_severity:[[:space:]]*(Critical|High|Medium|Low Confidence|Low|None)[[:space:]]*$/\1/p' "$FINDINGS")"
if [ "$(printf '%s' "$sev" | grep -c .)" != "1" ]; then
  echo "findings-file defect: $FINDINGS carries no single readable max_severity: line"
  exit 2
fi

# A finding row: `| <Severity> | <path>:<line> | <remedy_class> | <finding> |
# <source> | <disposition> |`; a `rejected` disposition drops the row.
rows="$(awk -F'|' '
  { s = $2; gsub(/^[[:space:]`*]+|[[:space:]`*]+$/, "", s)
    d = $7; gsub(/^[[:space:]`*]+|[[:space:]`*]+$/, "", d) }
  d == "rejected" { next }
  s ~ /^(Critical|High|Medium|Low|Low Confidence)$/ {
    c = $4; gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", c)
    print s "\t" c }' "$FINDINGS")"
total="$(printf '%s' "$rows" | grep -c . || true)"
blocking="$(printf '%s\n' "$rows" | grep -c -E '^(Critical|High|Medium)	' || true)"
unclassed="$(printf '%s\n' "$rows" | grep -E '^(Critical|High|Medium)	' | grep -v -c -E '	(doc|test|impl|design|operator)$' || true)"
echo "max_severity: $sev"

labels="$(gh pr view "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --json labels -q '.labels[].name' 2>/dev/null)" || { echo "[$TAG] cannot read the labels of $REPO#$PR" >&2; exit 3; }
if printf '%s\n' "$labels" | grep -qx 'blocked-by-review'; then label=present; else label=absent; fi
echo "label: $label"
echo "findings: $total (Medium+: $blocking)"

attempts=0
if [ -f "$LEDGER" ]; then
  attempts="$(awk '
    /^## .*\[reentry-decision\][[:space:]]*$/ { n = 0; next }
    /^## .*\[review-autofix\][[:space:]]*$/ { n++ }
    END { print n + 0 }' "$LEDGER")"
fi
echo "attempts: $attempts of $CAP"

case "$sev" in
  Critical|High|Medium)
    if [ "$unclassed" != "0" ]; then
      echo "findings-file defect: $unclassed Medium+ row(s) carry no remedy_class"
      exit 2
    fi
    if [ "$label" = "absent" ]; then
      echo "backstop: needed — a $sev verdict stands on a pull request without blocked-by-review"
    fi
    if [ "$attempts" -ge "$CAP" ]; then
      echo "case: cap"
      exit 11
    fi
    echo "case: resolve"
    exit 10
    ;;
esac

if [ "$label" = "present" ]; then
  echo "case: relabel"
  exit 12
fi
if [ "$total" -gt 0 ]; then
  echo "case: low-only"
  exit 13
fi
echo "case: clean"
exit 0
