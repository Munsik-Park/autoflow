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
# BUDGET is enforced on two clocks. The suite header's `budget-secs` is a
# CI-clock number; locally, a wall-clock bound is armed around each suite at the
# EFFECTIVE LOCAL CEILING — budget-secs x SUITE_LOCAL_SLOWDOWN_FACTOR — sized
# as a hang detector rather than a seconds-level cost gate. An overrun is a
# distinct TIMEOUT result that fails the run: investigate the suite, do not
# bump budget-secs — a local overrun is no evidence about the CI-clock number.
# The CI path enforces the header declaration coarsely through each step's
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

# require_value <flag> <remaining argc> <next argument> — a flag that takes a
# value requires one. A lost --root value would otherwise resolve to the real
# tree through the default below, and the run would be about a subject the
# caller never named. Omitting a flag entirely keeps its documented default.
require_value() {
  if [ "$2" -lt 2 ] || [ -z "$3" ]; then
    echo "run-suites: $1 requires a non-empty value" >&2
    return 1
  fi
}

ROOT=""
BASE=""
EVENT="${GITHUB_EVENT_NAME:-pull_request}"
ALL=0
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)  require_value "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --base)  require_value "$1" $# "${2:-}" || exit 2; BASE="$2"; shift ;;
    --event) require_value "$1" $# "${2:-}" || exit 2; EVENT="$2"; shift ;;
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
# run_suite_bounded <bound-secs> <root> <suite-path> <capture-file> — run one
# suite under a wall-clock bound, on hosts that have GNU `timeout`, hosts that have Homebrew's
# `gtimeout`, and hosts that have neither (macOS's default userland). Sets
# SUITE_RC to the suite's own exit status and SUITE_TIMED_OUT to 1 iff the bound
# fired; returns 0 always. Globals rather than a captured substitution because a
# $(...) subshell cannot set them — the same reason the repo's two other
# bounded-execution helpers (scripts/handoff/confirm-ci-green.sh > gh_bounded,
# scripts/preflight/check-review-backend.sh > probe_run_bounded) use globals.
#
# The overrun is carried by SUITE_TIMED_OUT rather than by exit status 124:
# under the watchdog the killed suite is reaped as a signalled process, so 124
# never appears on that path and keying the classification on it would report a
# genuine overrun as an ordinary FAIL.
run_suite_bounded() {
  local bound="$1" root="$2" suite="$3" cap="$4"
  SUITE_TIMED_OUT=0
  local tbin=""
  if command -v timeout >/dev/null 2>&1; then
    tbin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    tbin="gtimeout"
  fi
  if [ -n "$tbin" ]; then
    (cd "$root" && "$tbin" "$bound" bash "$suite" >"$cap" 2>&1)
    SUITE_RC=$?
    [ "$SUITE_RC" -eq 124 ] && SUITE_TIMED_OUT=1
    return 0
  fi

  # No bound tool resolves: detached sleep+kill watchdog, in the canonical block
  # shape scripts/test/check-watchdog-detachment.sh holds every such site to.
  # `</dev/null` is required here and only here: `set -m` puts the background
  # suite in its own process group, so a suite reading stdin would be stopped by
  # SIGTTIN with no visible cause.
  local marker; marker="$(mktemp)"
  set -m
  (cd "$root" && bash "$suite") >"$cap" 2>&1 </dev/null &
  local pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      echo fired > "$marker"
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  local wpid=$!
  set +m
  wait "$pid" 2>/dev/null
  SUITE_RC=$?
  if [ -s "$marker" ]; then
    SUITE_TIMED_OUT=1
  else
    kill -TERM -"$wpid" 2>/dev/null || kill "$wpid" 2>/dev/null
  fi
  wait "$wpid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
  return 0
}

# ---------------------------------------------------------------------------
# emit_capture <classification> <suite> <capture-file> — the failing suite's own
# stdout and stderr, in full and framed. Not a tail: the audience is a person at
# a terminal diagnosing the run that just failed, and a truncated record
# reproduces in miniature the loss this exists to remove.
emit_capture() {
  printf -- '--- %s output: %s ---\n' "$1" "$2"
  cat "$3"
  printf -- '--- end %s output: %s ---\n' "$1" "$2"
}

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
  # The declared budget is a CI-clock number; what a local run may spend is that
  # number times the cross-clock ratio. Spending the declared budget directly
  # here is the unit error this separation corrects.
  allowance="$(suite_local_allowance_secs "$budget")"

  # Captured per suite, shown only on a failure. This is the sole driver for the
  # bash suite tree, so a discarded stream leaves a FAIL line as the whole
  # diagnostic record; on PASS nothing is printed, which keeps an all-green
  # run's output shape unchanged.
  capture="$(mktemp)"
  started="$(date +%s)"
  run_suite_bounded "$allowance" "$ROOT" "$suite" "$capture"
  status="$SUITE_RC"
  elapsed=$(( $(date +%s) - started ))

  if [ "$SUITE_TIMED_OUT" -eq 1 ]; then
    # Both quantities are named, so the record explains itself: a reader can see
    # which number was spent and which number it was derived from.
    printf 'TIMEOUT %s %ss (declared budget-secs: %s, effective local ceiling: %ss = %s x %s)\n' \
      "$suite" "$elapsed" "$budget" "$allowance" "$budget" "$SUITE_LOCAL_SLOWDOWN_FACTOR"
    TIMEDOUT=$((TIMEDOUT + 1)); RC=1
    emit_capture TIMEOUT "$suite" "$capture"
  elif [ "$status" -eq 0 ]; then
    printf 'PASS %s %ss\n' "$suite" "$elapsed"
    PASSED=$((PASSED + 1))
  else
    printf 'FAIL %s %ss (exit %s)\n' "$suite" "$elapsed" "$status"
    FAILED=$((FAILED + 1)); RC=1
    emit_capture FAIL "$suite" "$capture"
  fi
  rm -f "$capture"
done <<< "$SELECTED"

echo ""
echo "run-suites: $PASSED passed, $FAILED failed, $TIMEDOUT timed out, of $TOTAL executed"
if [ "$TIMEDOUT" -gt 0 ]; then
  echo "  A TIMEOUT is an overrun of the EFFECTIVE LOCAL CEILING (declared budget-secs x"
  echo "  SUITE_LOCAL_SLOWDOWN_FACTOR), which is sized as a hang detector rather than a"
  echo "  seconds-level cost gate. Investigate the suite: at this size an overrun is a hang"
  echo "  or an order-of-magnitude regression, not a tight budget. Do NOT bump the header —"
  echo "  budget-secs is a CI-clock number, and a local overrun is no evidence about it."
fi
exit $RC
