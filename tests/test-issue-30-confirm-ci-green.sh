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
# Cycle 2 (review-response, PR #31 Codex Medium finding) — AC-30-12 .. -23
# Per .autoflow/issue-30-verification-design.md cycle-2 §1/§4. Fix target:
# classify_rollup()'s status-branched reduction (pending short-circuit on a
# positive non_terminal predicate). AC-30-1..-11 above remain regression
# fences unchanged.
# =============================================================================

echo ""
echo "=== AC-30-12 (primary kill — reviewer C1: stale CANCELLED w/ts + timestamp-less QUEUED replacement -> pending, not exit 12) ==="

AC12_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC12_LOG="$(mktemp)"
run_bounded 5 "$AC12_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC12_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-12: outer watchdog never fired (script self-terminated at its own deadline)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-12: stale CANCELLED + timestamp-less QUEUED resolves to pending -> exit 13 at deadline" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-12: exit code is NOT 12 (the false-red the reviewer found)" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG" "$AC12_LOG"

# =============================================================================
echo ""
echo "=== AC-30-13 (CheckRun conclusion==null family — QUEUED/PENDING/WAITING/IN_PROGRESS all resolve to pending) ==="

for PENDING_STATUS in QUEUED PENDING WAITING IN_PROGRESS; do
  AC13_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"'"$PENDING_STATUS"'","conclusion":null,"startedAt":null,"completedAt":null}
]}'
  GH_INVOCATION_LOG="$(mktemp)"
  AC13_LOG="$(mktemp)"
  run_bounded 5 "$AC13_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="$AC13_BODY" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-13 ($PENDING_STATUS): resolves to pending -> exit 13, not 12" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC13_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-14 (stale FAILURE + timestamp-less pending replacement -> pending, not exit 12) ==="

AC14_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC14_LOG="$(mktemp)"
run_bounded 5 "$AC14_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC14_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-14: stale FAILURE + timestamp-less QUEUED resolves to pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-14: exit code is NOT 12" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG" "$AC14_LOG"

# =============================================================================
echo ""
echo "=== AC-30-15 (order-independence: AC-30-12 fixture classifies identically under both array orders) ==="

AC15_ORDER_A="$AC12_BODY"
AC15_ORDER_B='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC15_LOG_A="$(mktemp)"
run_bounded 5 "$AC15_LOG_A" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC15_ORDER_A" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
AC15_EXIT_A="$RB_EXIT"
rm -f "$GH_INVOCATION_LOG" "$AC15_LOG_A"

GH_INVOCATION_LOG="$(mktemp)"
AC15_LOG_B="$(mktemp)"
run_bounded 5 "$AC15_LOG_B" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC15_ORDER_B" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
AC15_EXIT_B="$RB_EXIT"
rm -f "$GH_INVOCATION_LOG" "$AC15_LOG_B"

assert_true "AC-30-15: [terminal,pending] order -> exit 13" "[ \"\$AC15_EXIT_A\" -eq 13 ]"
assert_true "AC-30-15: [pending,terminal] order -> exit 13" "[ \"\$AC15_EXIT_B\" -eq 13 ]"
assert_true "AC-30-15: both orders agree (no order-dependent flap)" "[ \"\$AC15_EXIT_A\" -eq \"\$AC15_EXIT_B\" ]"

# =============================================================================
echo ""
echo "=== AC-30-16 (no-createdAt regression guard: AC-30-12 fixture already carries no createdAt on any entry) ==="

assert_false "AC-30-16: AC-30-12 fixture body contains no createdAt key (live CheckRun shape)" \
  "printf '%s' \"\$AC12_BODY\" | grep -q 'createdAt'"

GH_INVOCATION_LOG="$(mktemp)"
AC16_LOG="$(mktemp)"
run_bounded 5 "$AC16_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC12_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
assert_true "AC-30-16: createdAt-free stale-terminal + pending pair still resolves to pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG" "$AC16_LOG"

# =============================================================================
echo ""
echo "=== AC-30-17 (multi-terminal + one pending: two stale terminals + one timestamp-less pending -> pending) ==="

AC17_ORDER_A='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:30:00Z","completedAt":"2026-07-24T09:32:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null}
]}'
AC17_ORDER_B='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:30:00Z","completedAt":"2026-07-24T09:32:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC17_LOG_A="$(mktemp)"
run_bounded 5 "$AC17_LOG_A" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC17_ORDER_A" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
AC17_EXIT_A="$RB_EXIT"
rm -f "$GH_INVOCATION_LOG" "$AC17_LOG_A"

GH_INVOCATION_LOG="$(mktemp)"
AC17_LOG_B="$(mktemp)"
run_bounded 5 "$AC17_LOG_B" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC17_ORDER_B" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
AC17_EXIT_B="$RB_EXIT"
rm -f "$GH_INVOCATION_LOG" "$AC17_LOG_B"

assert_true "AC-30-17: two-terminal + one pending resolves to pending -> exit 13 (order A)" "[ \"\$AC17_EXIT_A\" -eq 13 ]"
assert_true "AC-30-17: two-terminal + one pending resolves to pending -> exit 13 (order B)" "[ \"\$AC17_EXIT_B\" -eq 13 ]"

# =============================================================================
echo ""
echo "=== AC-30-18 (cycle-1 timestamped-pending preserved — AC-30-9 regression fence) ==="

GH_INVOCATION_LOG="$(mktemp)"
AC18_LOG="$(mktemp)"
run_bounded 5 "$AC18_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC9_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357
assert_true "AC-30-18: real-timestamp pending (AC-30-9 shape) still resolves to pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG" "$AC18_LOG"

# =============================================================================
echo ""
echo "=== AC-30-19 (no over-suppression — genuine latest red preserved, AC-30-3 fence) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC3_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-19: stale SUCCESS + later genuine FAILURE still exits 12 (not masked to pending)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-20 (all-terminal tie unchanged — AC-30-6 fence) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC6_ORDER_A"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC20_EXIT_A="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC6_ORDER_B"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC20_EXIT_B="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

assert_true "AC-30-20: all-terminal tie order A still exits 12 (status-priority key inert)" "[ \"\$AC20_EXIT_A\" -eq 12 ]"
assert_true "AC-30-20: all-terminal tie order B still exits 12" "[ \"\$AC20_EXIT_B\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-30-21 (full existing issue-30 + issue-25 suites still green) ==="

ISSUE25_OUTPUT_21="$(bash "$ISSUE25_SUITE" 2>&1)"
ISSUE25_RC_21=$?
assert_true "AC-30-21: tests/test-issue-25-confirm-ci-green.sh exits 0" \
  "[ \"\$ISSUE25_RC_21\" -eq 0 ]"
ISSUE25_RESULTS_LINE_21="$(printf '%s\n' "$ISSUE25_OUTPUT_21" | grep -E '^Results: ' | tail -n 1)"
assert_true "AC-30-21: issue-25 suite reports 0 failed" \
  "printf '%s' \"\$ISSUE25_RESULTS_LINE_21\" | grep -qE '0 failed'"
echo "  (issue-25 suite: $ISSUE25_RESULTS_LINE_21)"
echo "  (issue-30 whole-suite fence: this script's own Results footer below covers AC-30-1..-23)"

# =============================================================================
echo ""
echo "=== AC-30-22 (predicate is positive conclusion==null, NOT terminal-complement — genuine-latest-fail preserved) ==="

AC22_ORDER_A='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"STALE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC22_ORDER_B='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"STALE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC22_ORDER_A"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC22_EXIT_A="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC22_ORDER_B"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC22_EXIT_B="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

assert_true "AC-30-22: {STALE earlier, genuine FAILURE latest} exits 12 (order A) — unrecognized-terminal stays terminal" \
  "[ \"\$AC22_EXIT_A\" -eq 12 ]"
assert_true "AC-30-22: {STALE earlier, genuine FAILURE latest} exits 12 (order B)" \
  "[ \"\$AC22_EXIT_B\" -eq 12 ]"
assert_false "AC-30-22: exit code is NOT 13 (a complement predicate would wrongly mask the failure as pending)" \
  "[ \"\$AC22_EXIT_A\" -eq 13 ]"

# =============================================================================
echo ""
echo "=== AC-30-23 (StatusContext non_terminal leg — SC pending short-circuit, PENDING + EXPECTED variants) ==="

for SC_STATE in PENDING EXPECTED; do
  AC23_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"FAILURE","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"'"$SC_STATE"'"}
]}'
  GH_INVOCATION_LOG="$(mktemp)"
  AC23_LOG="$(mktemp)"
  run_bounded 5 "$AC23_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="$AC23_BODY" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-23 ($SC_STATE): same-context stale FAILURE + $SC_STATE resolves to pending -> exit 13, not 12" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC23_LOG"
done

# =============================================================================
# Cycle 3 (review-response, PR #31 codex re-review Medium finding) — AC-30-24 .. -30
# Per .autoflow/issue-30-verification-design.md cycle-3 §1/§4. Fix target:
# classify_rollup()'s def ident (:150-157) — space-join string key collides
# across a (workflowName,name) word-boundary shift. AC-30-1..-23 above remain
# regression fences unchanged.
#
# [MUST] carry-forward from GATE:PLAN (issue-30-ledger.md Cycle 3): the
# colliding pair's SUCCESS entry MUST have a LATER timestamp than the
# FAILURE entry — a non-timestamped colliding pair already exits 12 at HEAD
# via the fail-safe rank tie-break (AC-30-6 class) and would wrongly
# pass-at-RED. Both fixtures below give the SUCCESS entry the later
# startedAt/completedAt.
# =============================================================================

echo ""
echo "=== AC-30-24 (primary kill — reviewer collision fixture: distinct (workflowName,name) pairs collide under space-join) ==="

AC24_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Build Linux","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Linux","workflowName":"CI Build","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC24_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Linux","workflowName":"CI Build","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"},
{"__typename":"CheckRun","name":"Build Linux","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC24_FWD"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC24_EXIT_FWD="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC24_REV"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC24_EXIT_REV="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

assert_true "AC-30-24: (CI,Build Linux)FAILURE + (CI Build,Linux)SUCCESS stay two distinct groups -> exit 12 (fwd order)" \
  "[ \"\$AC24_EXIT_FWD\" -eq 12 ]"
assert_false "AC-30-24: exit code is NOT 0 (the false-green the reviewer found, fwd order)" \
  "[ \"\$AC24_EXIT_FWD\" -eq 0 ]"
assert_true "AC-30-24: same collision pair -> exit 12 (rev order)" \
  "[ \"\$AC24_EXIT_REV\" -eq 12 ]"
assert_false "AC-30-24: exit code is NOT 0 (rev order)" \
  "[ \"\$AC24_EXIT_REV\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-30-25 (word-boundary collision class — generalization, no shared literal tokens) ==="

AC25_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"C","workflowName":"A B","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"B C","workflowName":"A","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC25_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"B C","workflowName":"A","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"},
{"__typename":"CheckRun","name":"C","workflowName":"A B","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC25_FWD"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC25_EXIT_FWD="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC25_REV"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
AC25_EXIT_REV="$RUN_EXIT"
rm -f "$GH_INVOCATION_LOG"

assert_true "AC-30-25: (A B,C)FAILURE + (A,B C)SUCCESS stay two distinct groups -> exit 12 (fwd order)" \
  "[ \"\$AC25_EXIT_FWD\" -eq 12 ]"
assert_true "AC-30-25: same word-boundary pair -> exit 12 (rev order)" \
  "[ \"\$AC25_EXIT_REV\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-30-26 (legitimate same-identity dedup preserved — AC-30-1 fence, space-in-name) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC1_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-26: genuinely-equal (CI,\"Tests: Ubuntu\") identity (space-in-name) still dedups -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-27 (absent-workflowName dedup-by-name preserved — AC-30-5 fence) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC5_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357

assert_true "AC-30-27: absent-workflowName same-name entries still dedup under the array key -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-28 (StatusContext identity via array key preserved — AC-30-8 fence) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8A_ALL_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-28: distinct-context StatusContext entries stay separate under array key -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8A_ONE_RED"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-28: distinct-context one FAILURE under array key -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$AC8B_BODY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 357
assert_true "AC-30-28: same-context stale FAILURE + later SUCCESS still dedups under array key -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-30-29 (RAW-branch smoke/regression fence — mixed key population classifies cleanly, total=3) ==="

# run_confirm/RUN_EXIT cannot verify this AC: the mixed body classifies
# "3 0 2" (green!=total, fail=0), which the script does NOT short-circuit on
# (loops to the poll deadline, exit 13, which encodes nothing about total);
# and any jq error would be swallowed by classify_rollup's own 2>/dev/null.
# So this AC pipes the fixture through the SAME jq program (extracted
# verbatim from the script under test, not retyped) directly, capturing
# stderr separately from stdout — the only c3 AC not exercised via
# run_confirm/RUN_EXIT (documented harness carve-out, §0.2/§2).
AC29_JQ_PROGRAM="$(sed -n "/^classify_rollup() {/,/^}/p" "$SCRIPT" \
  | sed -n "/jq -r '/,/2>\/dev\/null/p" \
  | sed '1d;$d')"

assert_true "AC-30-29: classify_rollup's jq program was extracted from the script (non-empty)" \
  "[ -n \"\$AC29_JQ_PROGRAM\" ]"

AC29_BODY='{"statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"Foreign","weird":"shape"}
]}'

AC29_STDOUT_FILE="$(mktemp)"
AC29_STDERR_FILE="$(mktemp)"
printf '%s' "$AC29_BODY" | jq -r "$AC29_JQ_PROGRAM" >"$AC29_STDOUT_FILE" 2>"$AC29_STDERR_FILE"
AC29_LINE="$(cat "$AC29_STDOUT_FILE")"
AC29_STDERR="$(cat "$AC29_STDERR_FILE")"
rm -f "$AC29_STDOUT_FILE" "$AC29_STDERR_FILE"

assert_true "AC-30-29: mixed CheckRun+StatusContext+RAW-fallback body classifies as \"3 0 2\" (three groups, total=3)" \
  "[ \"\$AC29_LINE\" = \"3 0 2\" ]"
assert_true "AC-30-29: classify_rollup's jq program emits no stderr on the mixed body" \
  "[ -z \"\$AC29_STDERR\" ]"

# =============================================================================
echo ""
echo "=== AC-30-30 (full existing issue-30 + issue-25 suites still green) ==="

ISSUE25_OUTPUT_30="$(bash "$ISSUE25_SUITE" 2>&1)"
ISSUE25_RC_30=$?
assert_true "AC-30-30: tests/test-issue-25-confirm-ci-green.sh exits 0" \
  "[ \"\$ISSUE25_RC_30\" -eq 0 ]"
ISSUE25_RESULTS_LINE_30="$(printf '%s\n' "$ISSUE25_OUTPUT_30" | grep -E '^Results: ' | tail -n 1)"
assert_true "AC-30-30: issue-25 suite reports 0 failed" \
  "printf '%s' \"\$ISSUE25_RESULTS_LINE_30\" | grep -qE '0 failed'"
echo "  (issue-25 suite: $ISSUE25_RESULTS_LINE_30)"
echo "  (issue-30 whole-suite fence: this script's own Results footer below covers AC-30-1..-29)"

# =============================================================================
# Cycle 4 (review-response, PR #31 codex 3rd review Medium finding) — AC-30-31 .. -40
# Per .autoflow/issue-30-verification-design.md cycle-4 §1/§4. Fix target:
# classify_rollup()'s branch-A representative-selection arm (:170-176) — the
# any(non_terminal) absolute-priority veto over-excludes a comparably-newer
# terminal from the candidate pool. AC-30-1..-30 above remain regression
# fences unchanged.
#
# RED expectation: AC-30-31, -32, -36 FAIL — branch A excludes the
# comparably-newer terminal, so each fixture classifies "1 0 0", never
# short-circuits, and runs to the poll deadline -> exit 13 (Case A/SC expect
# 12, Case B expects 0). AC-30-33, -34, -35, -37, -39, -40 are
# passing-at-RED regression / over-correction fences (HEAD already pends
# these). AC-30-38 is passing-at-RED (both suites already green).
# =============================================================================

echo ""
echo "=== AC-30-31 (primary kill — reviewer Case A: older IN_PROGRESS + newer FAILURE -> exit 12, not 13) ==="

AC31_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC31_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null}
]}'

for AC31_ORDER_NAME in FWD REV; do
  AC31_BODY_VAR="AC31_$AC31_ORDER_NAME"
  GH_INVOCATION_LOG="$(mktemp)"
  AC31_LOG="$(mktemp)"
  run_bounded 8 "$AC31_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="${!AC31_BODY_VAR}" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-31 ($AC31_ORDER_NAME): outer watchdog never fired (script self-terminated)" \
    "[ \"\$RB_KILLED\" -eq 0 ]"
  assert_true "AC-30-31 ($AC31_ORDER_NAME): older IN_PROGRESS + newer FAILURE resolves -> exit 12" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 12 ]"
  assert_false "AC-30-31 ($AC31_ORDER_NAME): exit code is NOT 13 (the false-pending the reviewer found)" \
    "[ \"\$RB_EXIT\" -eq 13 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC31_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-32 (reviewer's missing test — Case B SUCCESS twin: older IN_PROGRESS + newer SUCCESS -> exit 0, not 13) ==="

AC32_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC32_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null}
]}'

for AC32_ORDER_NAME in FWD REV; do
  AC32_BODY_VAR="AC32_$AC32_ORDER_NAME"
  GH_INVOCATION_LOG="$(mktemp)"
  AC32_LOG="$(mktemp)"
  run_bounded 8 "$AC32_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="${!AC32_BODY_VAR}" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-32 ($AC32_ORDER_NAME): outer watchdog never fired (script self-terminated)" \
    "[ \"\$RB_KILLED\" -eq 0 ]"
  assert_true "AC-30-32 ($AC32_ORDER_NAME): older IN_PROGRESS + newer SUCCESS resolves -> exit 0" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 0 ]"
  assert_false "AC-30-32 ($AC32_ORDER_NAME): exit code is NOT 13 (green PR hanging to deadline)" \
    "[ \"\$RB_EXIT\" -eq 13 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC32_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-33 (Case C — c2-protected pending, must NOT regress; re-run AC-30-12 fixture unchanged) ==="

GH_INVOCATION_LOG="$(mktemp)"
AC33_LOG="$(mktemp)"
run_bounded 8 "$AC33_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC12_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-33: outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-33: stale-terminal + timestamp-less non-terminal (AC-30-12 shape) stays pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG" "$AC33_LOG"

# =============================================================================
echo ""
echo "=== AC-30-34 (Case D — equal begin-timestamp FAILURE tie -> pending, not exit 12) ==="

AC34_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:48:00Z","completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC34_LOG="$(mktemp)"
run_bounded 8 "$AC34_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC34_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-34: outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-34: equal-startedAt IN_PROGRESS/FAILURE tie stays pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-34: exit code is NOT 12 (the tie must not resolve toward the terminal)" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG" "$AC34_LOG"

# =============================================================================
echo ""
echo "=== AC-30-35 (Case E — older terminal beside newer non-terminal -> pending, not exit 12) ==="

AC35_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:42:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:48:00Z","completedAt":null}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC35_LOG="$(mktemp)"
run_bounded 8 "$AC35_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC35_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-35: outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-35: older terminal FAILURE beside newer live IN_PROGRESS stays pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-35: exit code is NOT 12 (an older/superseded terminal must not win)" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG" "$AC35_LOG"

# =============================================================================
echo ""
echo "=== AC-30-36 (StatusContext leg — createdAt basis, FAILURE and SUCCESS twins, both array orders) ==="

AC36_FAIL_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"PENDING","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"FAILURE","createdAt":"2026-07-24T09:48:00Z"}
]}'
AC36_FAIL_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"FAILURE","createdAt":"2026-07-24T09:48:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"PENDING","createdAt":"2026-07-24T09:40:00Z"}
]}'
AC36_SUCCESS_FWD='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"PENDING","createdAt":"2026-07-24T09:40:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:48:00Z"}
]}'
AC36_SUCCESS_REV='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS","createdAt":"2026-07-24T09:48:00Z"},
{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"PENDING","createdAt":"2026-07-24T09:40:00Z"}
]}'

for AC36_CASE in "FAIL_FWD:12" "FAIL_REV:12" "SUCCESS_FWD:0" "SUCCESS_REV:0"; do
  AC36_BODY_VAR="AC36_${AC36_CASE%%:*}"
  AC36_EXPECT="${AC36_CASE##*:}"
  GH_INVOCATION_LOG="$(mktemp)"
  AC36_LOG="$(mktemp)"
  run_bounded 8 "$AC36_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="${!AC36_BODY_VAR}" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-36 (${AC36_CASE%%:*}): outer watchdog never fired (script self-terminated)" \
    "[ \"\$RB_KILLED\" -eq 0 ]"
  assert_true "AC-30-36 (${AC36_CASE%%:*}): StatusContext createdAt-basis resolves -> exit $AC36_EXPECT" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq $AC36_EXPECT ]"
  assert_false "AC-30-36 (${AC36_CASE%%:*}): exit code is NOT 13 (false-pending on the createdAt slot)" \
    "[ \"\$RB_EXIT\" -eq 13 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC36_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-37 (multi non-terminal — one incomparable -> pending, not exit 12) ==="

AC37_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"QUEUED","conclusion":null,"startedAt":null,"completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC37_LOG="$(mktemp)"
run_bounded 8 "$AC37_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC37_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-37: outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-37: comparable + timestamp-less non-terminals beside newer FAILURE stays pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-37: exit code is NOT 12 (a single incomparable non-terminal must block the override)" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
rm -f "$GH_INVOCATION_LOG" "$AC37_LOG"

# =============================================================================
echo ""
echo "=== AC-30-39 (Case D2 — equal begin-timestamp SUCCESS tie -> pending, the false-green fence [MUST]) ==="

AC39_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":"2026-07-24T09:40:00Z","completedAt":null},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:40:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

GH_INVOCATION_LOG="$(mktemp)"
AC39_LOG="$(mktemp)"
run_bounded 8 "$AC39_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC39_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 357

assert_true "AC-30-39: outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-30-39: equal-startedAt IN_PROGRESS/SUCCESS tie stays pending -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-30-39: exit code is NOT 0 (the false-green a full-ts_key override would produce)" \
  "[ \"\$RB_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG" "$AC39_LOG"

# =============================================================================
echo ""
echo "=== AC-30-40 (has_start type-appropriate slot — the injection false-result fence [MUST]) ==="

AC40_FAIL_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":null,"createdAt":"2026-07-24T09:59:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'
AC40_SUCCESS_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"IN_PROGRESS","conclusion":null,"startedAt":null,"createdAt":"2026-07-24T09:59:00Z"},
{"__typename":"CheckRun","name":"Tests: Ubuntu","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-07-24T09:48:00Z","completedAt":"2026-07-24T09:50:00Z"}
]}'

for AC40_TWIN in FAIL SUCCESS; do
  AC40_BODY_VAR="AC40_${AC40_TWIN}_BODY"
  GH_INVOCATION_LOG="$(mktemp)"
  AC40_LOG="$(mktemp)"
  run_bounded 8 "$AC40_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
    GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
    GH_MOCK_POLL_BODY="${!AC40_BODY_VAR}" \
    CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
    bash "$SCRIPT" --pr 357

  assert_true "AC-30-40 ($AC40_TWIN twin): outer watchdog never fired (script self-terminated)" \
    "[ \"\$RB_KILLED\" -eq 0 ]"
  assert_true "AC-30-40 ($AC40_TWIN twin): startedAt-less CheckRun w/ injected createdAt beside newer terminal stays pending -> exit 13" \
    "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
  assert_false "AC-30-40 ($AC40_TWIN twin): exit code is NOT 12 (false red via createdAt-slot injection)" \
    "[ \"\$RB_EXIT\" -eq 12 ]"
  assert_false "AC-30-40 ($AC40_TWIN twin): exit code is NOT 0 (false green via createdAt-slot injection)" \
    "[ \"\$RB_EXIT\" -eq 0 ]"
  rm -f "$GH_INVOCATION_LOG" "$AC40_LOG"
done

# =============================================================================
echo ""
echo "=== AC-30-38 (full existing issue-30 + issue-25 suites still green) ==="

ISSUE25_OUTPUT_38="$(bash "$ISSUE25_SUITE" 2>&1)"
ISSUE25_RC_38=$?
assert_true "AC-30-38: tests/test-issue-25-confirm-ci-green.sh exits 0" \
  "[ \"\$ISSUE25_RC_38\" -eq 0 ]"
ISSUE25_RESULTS_LINE_38="$(printf '%s\n' "$ISSUE25_OUTPUT_38" | grep -E '^Results: ' | tail -n 1)"
assert_true "AC-30-38: issue-25 suite reports 0 failed" \
  "printf '%s' \"\$ISSUE25_RESULTS_LINE_38\" | grep -qE '0 failed'"
echo "  (issue-25 suite: $ISSUE25_RESULTS_LINE_38)"
echo "  (issue-30 whole-suite fence: this script's own Results footer below covers AC-30-1..-37, -39 and -40)"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
