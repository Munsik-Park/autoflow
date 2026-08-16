#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# run-suites.sh — the local driver: selection, de-duplication, budget
# enforcement, per-suite reporting.
# =============================================================================
# It does not reimplement selection. `scripts/test/select-suites.sh` is the sole
# definition site; this script consumes it, exactly as the CI `select` step
# does. `--all` bypasses selection for a whole-tree sweep, which is what
# replaced the deleted tests/issue-59-full-sweep-driver.sh.
#
# DE-DUPLICATION is by resolved path, so a suite cannot execute twice in one
# pass however it entered the set.
#
# BUDGET is enforced with `timeout <budget-secs>` around each suite, and an
# overrun is a distinct TIMEOUT result that fails the run. Raise the budget
# deliberately in the suite's own header; do not treat a TIMEOUT as green.
# The CI path enforces the same declaration coarsely through each step's
# `timeout-minutes: ceil(budget-secs / 60)`, whose agreement with the header is
# asserted by scripts/test/check-suite-manifest.sh.
#
# Usage:
#   bash scripts/test/run-suites.sh [--root <dir>] [--base <ref>]
#                                   [--event pull_request|push] [--all] [--list]
#
# One `PASS|FAIL|TIMEOUT <path> <elapsed>s` line per executed suite, then a
# summary. Exit 0 when every executed suite passed, 1 on any failure or
# overrun, 2 usage.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

ROOT=""
BASE=""
EVENT="${GITHUB_EVENT_NAME:-pull_request}"
ALL=0
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="${2:-}"; shift ;;
    --base)  BASE="${2:-}"; shift ;;
    --event) EVENT="${2:-}"; shift ;;
    --all)   ALL=1 ;;
    --list)  LIST=1 ;;
    *)       echo "run-suites: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# The set to run: the whole enumerated tree under --all, otherwise whatever the
# single selection definition site returns.
# ---------------------------------------------------------------------------
if [ "$ALL" -eq 1 ]; then
  SELECTED="$(suite_enumerate "$ROOT")"
  SELECT_RC=0
else
  SELECT_ARGS=(--root "$ROOT" --event "$EVENT")
  [ -n "$BASE" ] && SELECT_ARGS+=(--base "$BASE")
  SELECTED="$(bash "$SCRIPT_DIR/select-suites.sh" "${SELECT_ARGS[@]}")"
  SELECT_RC=$?
fi

if [ "$SELECT_RC" -ne 0 ]; then
  echo "run-suites: selection failed (exit $SELECT_RC) — no suite executed" >&2
  exit 1
fi

# De-duplicate by resolved path, preserving order.
SELECTED="$(printf '%s\n' "$SELECTED" | awk 'NF && !seen[$0]++')"

if [ "$LIST" -eq 1 ]; then
  printf '%s\n' "$SELECTED"
  exit 0
fi

if [ -z "$SELECTED" ]; then
  echo "run-suites: 0 suite(s) selected"
  exit 0
fi

# ---------------------------------------------------------------------------
TOTAL=0; PASSED=0; FAILED=0; TIMEDOUT=0
RC=0

while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  [ -f "$ROOT/$suite" ] || continue
  TOTAL=$((TOTAL + 1))

  budget="$(suite_budget_secs "$ROOT/$suite" 2>/dev/null || true)"
  case "$budget" in
    ''|*[!0-9]*) budget="$SUITE_BUDGET_CEILING_SECS" ;;
  esac

  started="$(date +%s)"
  (cd "$ROOT" && timeout "$budget" bash "$suite" >/dev/null 2>&1)
  status=$?
  elapsed=$(( $(date +%s) - started ))

  if [ "$status" -eq 124 ]; then
    printf 'TIMEOUT %s %ss (declared budget-secs: %s)\n' "$suite" "$elapsed" "$budget"
    TIMEDOUT=$((TIMEDOUT + 1)); RC=1
  elif [ "$status" -eq 0 ]; then
    printf 'PASS %s %ss\n' "$suite" "$elapsed"
    PASSED=$((PASSED + 1))
  else
    printf 'FAIL %s %ss (exit %s)\n' "$suite" "$elapsed" "$status"
    FAILED=$((FAILED + 1)); RC=1
  fi
done <<< "$SELECTED"

echo ""
echo "run-suites: $PASSED passed, $FAILED failed, $TIMEDOUT timed out, of $TOTAL executed"
if [ "$TIMEDOUT" -gt 0 ]; then
  echo "  A TIMEOUT is an overrun of the suite's own declared budget-secs. Raise the budget"
  echo "  deliberately in the suite's header — and follow it in the workflow's"
  echo "  timeout-minutes — rather than treating the run as green."
fi
exit $RC
