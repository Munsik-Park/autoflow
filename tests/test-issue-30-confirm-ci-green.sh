#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: HANDOFF step-5 CI-green confirm helper — dedup false-red fix, Issue #30
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-30-verification-design.md) / feature design
# (.autoflow/issue-30-feature-design.md). Mirrors
# tests/test-issue-25-confirm-ci-green.sh: assert_true/assert_false over
# exit-code capture, the same PATH-injected `gh` shim
# (tests/issue-25/mock-gh/gh, reused UNCHANGED — the shim already echoes any
# poll body verbatim, so no shim change is needed to inject
# workflowName/startedAt/completedAt/createdAt sub-fields), and run_bounded
# for finite-termination proof (AC-30-9).
#
# Target: scripts/handoff/confirm-ci-green.sh classify_rollup() (:141-155).
# This file does NOT modify the script under test.
#
# RED expectation (pre-implementation, this commit; verification design §4):
#   AC-30-1, -2, -4, -5, -6, -9, -11 FAIL at current HEAD — classify_rollup()
#   has no latest-per-identity dedup, so a stale CANCELLED/FAILURE/ERROR/
#   TIMED_OUT check-run outvotes a same-name later SUCCESS (false red, exit
#   12 instead of 0); AC-30-6 flaps 0/12 by array order; AC-30-9's pending
#   replacement is misread as a stale terminal (false exit 12 instead of 13);
#   AC-30-11's dedup/latest doc token is absent from the header comment.
#   AC-30-3, -7, -8(a), -10 are passing-at-RED regression guards — current
#   (undeduped) behavior is already correct for those inputs. AC-30-8(b) (new
#   same-context StatusContext dedup) FAILs at RED alongside the
#   behavior-changing set.
#
# GREEN expectation: all of AC-30-1..-11 PASS; the issue-25 suite (AC-30-10)
# stays green.
#
# Self-guard (SIGPIPE-safe pipes, docs/submodule-common-rules.md > Testing
# Standards item 6): every assertion captures its producer into a variable
# before matching — no streaming producer piped directly into a
# short-circuiting consumer.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/handoff/confirm-ci-green.sh"
MOCK_GH_DIR="$PROJECT_ROOT/tests/issue-25/mock-gh"
ISSUE25_SUITE="$PROJECT_ROOT/tests/test-issue-25-confirm-ci-green.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  fi
}

# Bounded execution helper (per tests/test-issue-25-confirm-ci-green.sh
# run_bounded): prefer timeout/gtimeout; else a sleep+kill fallback. Sets
# RB_EXIT and RB_KILLED (1 iff the watchdog fired).
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
    ( "$@" ) >"$logfile" 2>&1 &
    local pid=$!
    ( sleep "$bound"; if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo killed > "$logfile.watchdog"; fi ) &
    local watchdog_pid=$!
    wait "$pid" 2>/dev/null
    RB_EXIT=$?
    if [ -s "$logfile.watchdog" ]; then
      RB_KILLED=1
    else
      kill "$watchdog_pid" 2>/dev/null
    fi
    wait "$watchdog_pid" 2>/dev/null
    rm -f "$logfile.watchdog" 2>/dev/null
  fi
}

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

echo "=============================================="
echo "confirm-ci-green.sh dedup fix (HANDOFF step-5, issue #30)"
echo "=============================================="

# =============================================================================
echo ""
echo "=== AC-30-1 (primary kill — PR #357 repro: same-name CANCELLED+SUCCESS dedups to green) ==="

AC1_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC1_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-1: same-name earlier CANCELLED + later SUCCESS dedups to green -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_false "AC-30-1: exit code is NOT 12 (the false-red this issue reports)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-2 (generalization: stale FAILURE/ERROR/TIMED_OUT + later same-name SUCCESS -> exit 0) ==="

for STALE_CONCLUSION in FAILURE ERROR TIMED_OUT; do
  AC2_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"'"$STALE_CONCLUSION"'","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
  GH_INVOCATION_LOG="$(mktemp)"
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
  GH_MOCK_POLL_BODY="$AC2_BODY"
  GH_MOCK_POLL_SEQUENCE_FILE=""
  GH_MOCK_POLL_COUNTER_FILE=""
  CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

  assert_true "AC-30-2 ($STALE_CONCLUSION): stale $STALE_CONCLUSION + later same-name SUCCESS dedups to green -> exit 0" \
    "[ \"\$RUN_EXIT\" -eq 0 ]"
  rm -f "$GH_INVOCATION_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-3 (no over-suppression: earlier SUCCESS + later same-name FAILURE stays red — regression guard) ==="

AC3_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC3_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-3: a stale SUCCESS does not mask a later genuine same-name FAILURE -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-4 (count integrity: total/green evaluated over deduped identities, not raw rows) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC1_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-4: 2-raw-row same-identity green body still exits 0 (not 13/pending)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_false "AC-30-4: exit code is NOT 13 (raw total=2 must not desync green==total)" \
  "[ \"\$RUN_EXIT\" -eq 13 ]"
assert_false "AC-30-4: exit code is NOT 11 (2 raw rows is not 'zero checks')" \
  "[ \"\$RUN_EXIT\" -eq 11 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-5 (identity-key fallback: absent workflowName dedups by name alone) ==="

AC5_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC5_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-5: same-name entries with absent workflowName still dedup (by name alone) -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-6 (deterministic fail-safe tie-break: all-timestamps-absent same-identity pair pins exit 12, order-independent) ==="

AC6_ORDER_A='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"}
]}'
AC6_ORDER_B='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC6_ORDER_A"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC6_EXIT_A="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC6_ORDER_B"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC6_EXIT_B="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

assert_true "AC-30-6: [CANCELLED, SUCCESS] order pins exit 12 (fail-safe rank resolves the tie to not-green)" \
  "[ \"\$AC6_EXIT_A\" -eq 12 ]"
assert_true "AC-30-6: [SUCCESS, CANCELLED] order ALSO pins exit 12 (order-independent)" \
  "[ \"\$AC6_EXIT_B\" -eq 12 ]"
assert_true "AC-30-6: both array orderings agree (no order-dependent flap)" \
  "[ \"\$AC6_EXIT_A\" -eq \"\$AC6_EXIT_B\" ]"

# =============================================================================
echo ""
echo "=== AC-30-7 (distinct-name checks classified identically to today — regression guard) ==="

AC7_ALL_GREEN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: macOS","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'
AC7_ONE_RED='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: macOS","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC7_ALL_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-7: all-distinct-name all-SUCCESS rollup -> exit 0 (unchanged)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC7_ONE_RED"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-7: one distinct-name FAILURE among distinct-name checks -> exit 12 (unchanged)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-8 (StatusContext: distinct-context unaffected (a) + same-context dedup (b)) ==="

# (a) distinct-context, regression guard — passing at RED.
AC8A_ALL_GREEN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/branch","state":"SUCCESS","createdAt":"2026-07-24T09:40:00Z"}
]}'
AC8A_ONE_RED='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/branch","state":"FAILURE","createdAt":"2026-07-24T09:40:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8A_ALL_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-8(a): distinct-context all-SUCCESS StatusContext rollup -> exit 0 (unchanged)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8A_ONE_RED"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-8(a): distinct-context one FAILURE among StatusContext entries -> exit 12 (unchanged)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

# (b) same-context dedup — behavior-changing, FAILs at RED (no StatusContext dedup today).
AC8B_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"FAILURE","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8B_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-8(b): same-context stale FAILURE + later SUCCESS dedups (createdAt-ordered) -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-9 (pending-latest not masked: stale terminal + later still-pending same-name entry -> exit 13, not 12) ==="

AC9_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:48:00Z","completedAt":null}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC9_LOG="$(mktemp)"
run_bounded 5 "$AC9_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC9_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-9: the outer 5s harness watchdog never had to fire (script self-terminated via its own deadline)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-9: dedup resolves to the later pending entry -> exit 13 at deadline (not exit 0, not exit 12)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG" "$AC9_LOG"

# =============================================================================
echo ""
echo "=== AC-30-10 (full existing issue-25 suite still green — regression fence for the whole script) ==="

ISSUE25_OUTPUT="$(bash "$ISSUE25_SUITE" 2>&1)"
ISSUE25_RC=$?
assert_true "AC-30-10: tests/test-issue-25-confirm-ci-green.sh exits 0" \
  "[ \"\$ISSUE25_RC\" -eq 0 ]"
ISSUE25_RESULTS_LINE="$(printf '%s\n' "$ISSUE25_OUTPUT" | grep -E '^Results: ' | tail -n 1)"
assert_true "AC-30-10: issue-25 suite reports 0 failed" \
  "printf '%s' \"\$ISSUE25_RESULTS_LINE\" | grep -qE '0 failed'"
echo "  (issue-25 suite: $ISSUE25_RESULTS_LINE)"

# =============================================================================
echo ""
echo "=== AC-30-11 (self-documenting: classify_rollup header comment documents the dedup step) ==="

CLASSIFY_HEADER="$(grep -B1 -F 'classify_rollup() {' "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-30-11: classify_rollup() header comment mentions dedup/latest-per-check" \
  "printf '%s' \"\$CLASSIFY_HEADER\" | grep -qiE 'dedup|latest'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
