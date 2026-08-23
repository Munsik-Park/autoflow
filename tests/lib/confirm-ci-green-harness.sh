#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# confirm-ci-green harness — Issue #122
# =============================================================================
# One sourced file holding the harness the two confirm-ci-green suites
# (tests/test-issue-25-confirm-ci-green.sh, tests/test-issue-30-confirm-ci-green.sh)
# drove scripts/handoff/confirm-ci-green.sh through. Both suites are live and
# neither is redundant with the other or with any standing lint, so this is an
# EXTRACTION, not a retirement — the one item of #122 where a shared helper is
# the right answer rather than a provenance row.
#
# Sourced, never executed. The caller sets MOCK_GH_DIR and SCRIPT before use.
#
# CONTRACT
#
#   run_bounded <seconds> <logfile> <cmd...>
#       Runs the command under a wall-clock bound, writing combined output to
#       <logfile>. Sets RB_EXIT to the command's exit status and RB_KILLED to 1
#       exactly when the watchdog fired. `timeout`/`gtimeout` are preferred and
#       their exit 124 is read as the watchdog firing; otherwise the
#       process-group sleep+kill fallback below is used. That fallback's
#       statement order is the CANONICAL block
#       scripts/test/check-watchdog-detachment.sh enumerates — it scans tests/
#       recursively, so this file is in its subject set. Moved here VERBATIM:
#       no reflow, no reordering, no re-indentation.
#
#   run_confirm <argv...>
#       Invokes "$SCRIPT" with "$MOCK_GH_DIR" prepended to PATH and every mock
#       environment variable forwarded, capturing stdout+stderr into RUN_OUTPUT
#       and the exit status into RUN_EXIT. The forwarded variable set is the
#       UNION of the two suites' former copies, so each caller keeps its own
#       behaviour and neither gains a variable it sets: an unset member
#       forwards as the empty string, exactly as it did before.
#
#   PRECHECK_MERGEABLE_CLEAN
#       The shared precheck fixture body, a constant. tests/test-issue-25's
#       further fixture bodies (PRECHECK_CONFLICTING_DIRTY, the POLL_* set) stay
#       in that suite: only one suite uses them, so hoisting them here would
#       widen this file's contract for a single consumer.
#
# DELIBERATELY NOT UNIFIED — recorded here with its ground, per the
# tests/lib/base-ref.sh precedent that a refused unification is written down so
# the next cycle does not re-adjudicate it:
#
#   * assert_true / assert_false and the PASS/FAIL/TESTS counters. Re-authored
#     in most suites in this tree. Unifying them would put nearly the whole
#     tests tree in one cycle's change surface and make every suite's result
#     accounting depend on a sourced file — out of proportion to this issue,
#     and a separate decision.
#   * run_bounded_in in tests/test-push-context-base-ref.sh. Same bounded-runner
#     family, but it additionally changes directory into a scratch clone per
#     call; its callers depend on that, and folding the extra parameter into
#     run_bounded would widen this contract for one consumer.
#   * harness_run in tests/test-bounded-execution-fallback.sh. That suite's own
#     outer-bound timing wrapper, not a shipped fallback site — and
#     scripts/test/check-watchdog-detachment.sh names it as an explicit
#     subject-set exclusion for exactly that reason. Extracting it would move a
#     deliberately excluded site into the scanned tier and invert that lint's
#     judgement.
# =============================================================================

# Bounded execution helper: prefer timeout/gtimeout; else a sleep+kill
# fallback. Sets RB_EXIT and RB_KILLED (1 iff the watchdog fired).
run_bounded() {
  local bound="$1" logfile="$2"; shift 2
  RB_KILLED=0
  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi
  if [ -n "$timeout_bin" ]; then
    ( "$timeout_bin" "$bound" "$@" ) >"$logfile" 2>&1
    RB_EXIT=$?
    [ "$RB_EXIT" -eq 124 ] && RB_KILLED=1
  else
    local marker="$logfile.watchdog"
    set -m
    ( "$@" ) >"$logfile" 2>&1 </dev/null &
    local pid=$!
    ( sleep "$bound"
      if kill -0 "$pid" 2>/dev/null; then
        echo killed > "$marker"
        kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
      fi
    ) >/dev/null 2>&1 &
    local watchdog_pid=$!
    set +m
    wait "$pid" 2>/dev/null
    RB_EXIT=$?
    if [ -s "$marker" ]; then
      RB_KILLED=1
    else
      kill -TERM -"$watchdog_pid" 2>/dev/null || kill "$watchdog_pid" 2>/dev/null
    fi
    wait "$watchdog_pid" 2>/dev/null
    rm -f "$marker" 2>/dev/null
  fi
}

# Shared precheck fixture body (JSON, one line).
PRECHECK_MERGEABLE_CLEAN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}'

# run_confirm — invoke the script under test with the mock-gh PATH prepended,
# capturing stdout/stderr/exit into globals. $1.. are the script's own argv.
run_confirm() {
  local out
  out="$(mktemp)"
  ( PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="${GH_INVOCATION_LOG:-}" \
    GH_MOCK_EXIT="${GH_MOCK_EXIT:-}" \
    GH_MOCK_PRECHECK_BODY="${GH_MOCK_PRECHECK_BODY:-}" \
    GH_MOCK_PRECHECK_EXIT="${GH_MOCK_PRECHECK_EXIT:-}" \
    GH_MOCK_PRECHECK_SLEEP="${GH_MOCK_PRECHECK_SLEEP:-}" \
    GH_MOCK_POLL_BODY="${GH_MOCK_POLL_BODY:-}" \
    GH_MOCK_POLL_SEQUENCE_FILE="${GH_MOCK_POLL_SEQUENCE_FILE:-}" \
    GH_MOCK_POLL_COUNTER_FILE="${GH_MOCK_POLL_COUNTER_FILE:-}" \
    CI_POLL_TIMEOUT_SECS="${CI_POLL_TIMEOUT_SECS:-}" \
    CI_POLL_INTERVAL_SECS="${CI_POLL_INTERVAL_SECS:-}" \
    bash "$SCRIPT" "$@" ) >"$out" 2>&1
  RUN_EXIT=$?
  RUN_OUTPUT="$(cat "$out")"
  rm -f "$out"
}
