#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: HANDOFF step-5 CI-green confirm helper — Issue #25
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-25-verification-design.md) / feature design
# (.autoflow/issue-25-feature-design.md). Docs/ops meta-suite (no jest, no
# npm) — mirrors tests/test-issue-953-cycle-digest.sh / test-issue-979-probe.sh:
# assert_true/assert_false over exit-code capture, a PATH-injected `gh` shim
# (tests/issue-25/mock-gh/gh, pattern per tests/issue-92/mock-gh/gh), and
# section-extraction doc assertions bound to stable structural tokens.
#
# Script under test: scripts/handoff/confirm-ci-green.sh (does not exist yet —
# this commit is RED). Exit-code contract (feature §4):
#   0  = CI green (>=1 check present, every element green)
#   10 = not mergeable (precheck OR mid-poll flip) — HANDOFF-internal-retry
#   11 = MERGEABLE but 0 checks ever published within the bound
#   12 = a check concluded FAILURE/ERROR/CANCELLED/TIMED_OUT (red build)
#   13 = checks present but still pending at the deadline (slow CI)
#   64 = usage / missing-arg / bad-env-int
#
# gh-call shape (verification design §1, "applies to every unit AC below"):
# the script issues ONLY `gh pr view` (no `gh pr checks` subcommand exists).
# The precheck call requests `--json mergeable,mergeStateStatus` (no
# statusCheckRollup); every poll call requests
# `--json mergeable,mergeStateStatus,statusCheckRollup`. The "no poll
# attempted" regression marker (AC2) is therefore keyed off the ABSENCE of any
# statusCheckRollup-bearing `gh pr view` line in $GH_INVOCATION_LOG — never
# off a `pr checks` verb (feature §6 poll-detection marker note; verification
# design DCR "re-key AC1/AC2/AC3/AC6/AC9 off statusCheckRollup" [MUST]).
#
# RED expectation (pre-implementation, this commit):
#   AC1, AC2, AC-FLIP, AC3, AC4, AC5, AC-RED, AC9 — FAIL. The script does not
#   exist, so every invocation exits 127 (bash: no such file), which never
#   matches any of the contract's exit codes (0/10/11/12/13/64), and no gh
#   call is ever dispatched (the invocation log stays empty), so every
#   ordering / call-count assertion FAILS too.
#   AC6 — the primary discriminator (script existence) FAILS. The two
#   secondary static/dynamic negative-assertions (absence of a mutating gh
#   verb / merge token) are VACUOUSLY true pre-implementation (nothing to
#   find yet, matching tests/test-issue-964-sigpipe-safe-pipes.sh's own
#   "vacuous PASS" convention for a guard with nothing to detect) — they are
#   guards, not RED discriminators for AC6; the existence check is what
#   confirms overall Red.
#   AC7, AC8 — FAIL (docs not yet restructured; current text asserted against
#   the design's stable tokens does not contain them).
#
# Self-guard (SIGPIPE-safe pipes, docs/submodule-common-rules.md > Testing
# Standards item 6): every assertion in this file captures its producer into
# a variable before matching (`x=$(...); printf '%s\n' "$x" | grep -qF ...`
# or a bare `[ ]` test) — no `grep -A/-B/-C` / streaming producer is piped
# directly into a short-circuiting consumer.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/handoff/confirm-ci-green.sh"
MOCK_GH_DIR="$PROJECT_ROOT/tests/issue-25/mock-gh"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EXTERNAL_REVIEW_SEQ="$PROJECT_ROOT/docs/external-review-sequencing.md"
GIT_WORKFLOW="$PROJECT_ROOT/docs/git-workflow.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"

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

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

# Bounded execution helper (per tests/test-issue-979-probe.sh run_bounded):
# prefer timeout/gtimeout; else a sleep+kill fallback. Sets RB_EXIT and
# RB_KILLED (1 iff the watchdog fired). Used as the OUTER wall-clock guard
# for AC5's finite-termination proof (the script has no probe_run_bounded of
# its own around the whole invocation — feature D3 note, §0 DCR-5).
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

# Fixture bodies (JSON, one line each — feature §3.3 field shapes).
PRECHECK_MERGEABLE_CLEAN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}'
PRECHECK_CONFLICTING_DIRTY='{"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY"}'

POLL_ALL_GREEN_CHECKRUN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"}]}'
POLL_ALL_GREEN_STATUSCONTEXT='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS"}]}'
POLL_EMPTY_ROLLUP='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[]}'
POLL_PENDING='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"IN_PROGRESS","conclusion":null}]}'
POLL_FAILURE='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"FAILURE"}]}'
POLL_FLIPPED_CONFLICTING='{"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY","statusCheckRollup":[]}'

# run_confirm — invoke the script under test with the mock-gh PATH prepended,
# capturing stdout/stderr/exit into globals. $1.. are the script's own argv.
run_confirm() {
  local out
  out="$(mktemp)"
  ( PATH="$MOCK_GH_DIR:$PATH" \
    GH_INVOCATION_LOG="${GH_INVOCATION_LOG:-}" \
    GH_MOCK_PRECHECK_BODY="${GH_MOCK_PRECHECK_BODY:-}" \
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
echo "confirm-ci-green.sh (HANDOFF step-5 CI-green confirm, issue #25)"
echo "=============================================="

# =============================================================================
echo ""
echo "=== AC1 (precheck first, before any poll) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"; printf '%s\n' "$POLL_ALL_GREEN_CHECKRUN" > "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

FIRST_LINE="$(head -n 1 "$GH_INVOCATION_LOG" 2>/dev/null || true)"
assert_true "AC1: first logged gh call carries --json mergeable,mergeStateStatus" \
  "printf '%s' \"\$FIRST_LINE\" | grep -qF 'mergeable,mergeStateStatus'"
assert_false "AC1: first logged gh call does NOT carry statusCheckRollup" \
  "printf '%s' \"\$FIRST_LINE\" | grep -qF 'statusCheckRollup'"
FULL_LOG="$(cat "$GH_INVOCATION_LOG" 2>/dev/null || true)"
FIRST_ROLLUP_LINE="$(printf '%s\n' "$FULL_LOG" | grep -nF 'statusCheckRollup' | head -n 1 | cut -d: -f1 || true)"
assert_true "AC1: a statusCheckRollup-bearing call appears (at all) after line 1 in this MERGEABLE fixture" \
  "[ -n \"\$FIRST_ROLLUP_LINE\" ] && [ \"\$FIRST_ROLLUP_LINE\" -gt 1 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC2 (CONFLICTING/DIRTY exits 10, no poll — PR #321 regression) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_CONFLICTING_DIRTY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
run_confirm --pr 42

assert_true "AC2: exit code is 10 on precheck CONFLICTING/DIRTY" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
POLL_CALL_COUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
POLL_CALL_COUNT="${POLL_CALL_COUNT:-0}"
assert_true "AC2: no statusCheckRollup-bearing (poll) gh call was ever issued" \
  "[ \"\$POLL_CALL_COUNT\" -eq 0 ]"
assert_true "AC2: stderr carries the reserved HANDOFF-INTERNAL-RETRY token (DCR-6)" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qF 'HANDOFF-INTERNAL-RETRY'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-FLIP (mid-poll flip MERGEABLE -> CONFLICTING exits 10, feature D5) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"
printf '%s\n' "$POLL_EMPTY_ROLLUP" > "$SEQ_FILE"
printf '%s\n' "$POLL_FLIPPED_CONFLICTING" >> "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-FLIP: exit code is 10 on the iteration that observes the mid-poll flip" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
POLL_CALLS_AFTER_FLIP="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
POLL_CALLS_AFTER_FLIP="${POLL_CALLS_AFTER_FLIP:-0}"
assert_true "AC-FLIP: exactly 2 poll calls issued (flip observed on the 2nd, no 3rd call)" \
  "[ \"\$POLL_CALLS_AFTER_FLIP\" -eq 2 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC3 (MERGEABLE/CLEAN, checks eventually green -> exit 0) ==="

# Case (a): CheckRun-shape green, after 2 pending polls.
GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"
printf '%s\n' "$POLL_PENDING" > "$SEQ_FILE"
printf '%s\n' "$POLL_PENDING" >> "$SEQ_FILE"
printf '%s\n' "$POLL_ALL_GREEN_CHECKRUN" >> "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC3 (CheckRun shape): exit 0 once the rollup is non-empty and every element is green" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# Case (b, C3): StatusContext-only green (Jenkins classifier path).
GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"; printf '%s\n' "$POLL_ALL_GREEN_STATUSCONTEXT" > "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC3 (C3, StatusContext shape): exit 0 on a Jenkins-only green rollup (.state==SUCCESS classifier path)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC4 (MERGEABLE but 0 checks ever published -> exit 11, never green) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_EMPTY_ROLLUP"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC4: exit code is 11 (0 checks throughout the bound)" \
  "[ \"\$RUN_EXIT\" -eq 11 ]"
assert_false "AC4: exit code is NOT 0 (never read clean-but-empty as green)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_false "AC4: exit code is NOT 13 (distinct from the pending-at-timeout case)" \
  "[ \"\$RUN_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC5 (finite timeout with pending checks -> exit 13, never infinite hang) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_PENDING"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""

# Outer wall-clock guard (verification design AC5 method): ceiling =
# CI_POLL_TIMEOUT_SECS(2) + CI_POLL_INTERVAL_SECS(1) + slack(2) = 5s. This
# tripwire must NOT fire once the script self-terminates on its own deadline.
AC5_LOG="$(mktemp)"
run_bounded 5 "$AC5_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$GH_MOCK_PRECHECK_BODY" \
  GH_MOCK_POLL_BODY="$GH_MOCK_POLL_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC5: the outer 5s harness watchdog never had to fire (script self-terminated via its own deadline)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC5: exit code is 13 (checks present but never all-green within the bound)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG" "$AC5_LOG"

# =============================================================================
echo ""
echo "=== AC-RED (a check concluded failure -> exit 12) ==="

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_FAILURE"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-RED: exit code is 12 on a FAILURE-concluded check" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
assert_false "AC-RED: exit code is NOT 11" "[ \"\$RUN_EXIT\" -eq 11 ]"
assert_false "AC-RED: exit code is NOT 13" "[ \"\$RUN_EXIT\" -eq 13 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC6 (observe-only: no merge, no CI re-trigger, no conflict resolution) ==="
# Primary RED discriminator is script existence (below); the static grep and
# the dynamic invocation-log checks are guards that are vacuously true
# pre-implementation (nothing to detect yet) — see file header RED note.

assert_true "AC6 (primary RED discriminator): scripts/handoff/confirm-ci-green.sh exists" \
  "[ -f \"\$SCRIPT\" ]"

if [ -f "$SCRIPT" ]; then
  SCRIPT_SRC="$(cat "$SCRIPT")"
else
  SCRIPT_SRC=""
fi
assert_false "AC6 (static, guard): script source contains no 'gh pr merge'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF 'gh pr merge'"
assert_false "AC6 (static, guard): script source contains no '--merge' flag" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF -- '--merge'"
assert_false "AC6 (static, guard): script source contains no 'gh workflow run'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF 'gh workflow run'"
assert_false "AC6 (static, guard): script source contains no 'git rebase'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF 'git rebase'"
assert_false "AC6 (static, guard): script source contains no 'git merge'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF 'git merge'"
assert_false "AC6 (static, guard): script source contains no 'git push'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF 'git push'"
assert_false "AC6 (static, guard): script source contains no '--remove-label'" \
  "printf '%s' \"\$SCRIPT_SRC\" | grep -qF -- '--remove-label'"

# Dynamic: across every fixture run above, the invocation logs contained only
# `pr view` calls. Re-run one representative MERGEABLE+green fixture and
# confirm the log has no mutating gh subcommand token.
GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42
DYN_LOG="$(cat "$GH_INVOCATION_LOG" 2>/dev/null || true)"
assert_false "AC6 (dynamic, guard): invocation log contains no 'pr merge' call" \
  "printf '%s' \"\$DYN_LOG\" | grep -qF 'pr merge'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC7 (doc restructuring: step 5 prose -> script invocation + exit-code contract) ==="

STEP5_BODY="$(extract_section '^5\. Confirm CI is green' "$AUTOFLOW_GUIDE")"
STEP5_JOINED="$(printf '%s' "$STEP5_BODY" | tr '\n' ' ')"
assert_true "AC7: autoflow-guide.md step 5 references scripts/handoff/confirm-ci-green.sh" \
  "printf '%s' \"\$STEP5_JOINED\" | grep -qF 'confirm-ci-green.sh'"
assert_true "AC7: autoflow-guide.md step 5 retains the CONFLICTING branch-by-cause / HANDOFF-internal-retry prose (DCR-7)" \
  "printf '%s' \"\$STEP5_JOINED\" | grep -qF 'CONFLICTING'"

RECONCILE_BODY="$(extract_section 'Post-reconcile gate' "$EXTERNAL_REVIEW_SEQ")"
RECONCILE_JOINED="$(printf '%s' "$RECONCILE_BODY" | tr '\n' ' ')"
assert_true "AC7: external-review-sequencing.md Post-reconcile gate references confirm-ci-green.sh" \
  "printf '%s' \"\$RECONCILE_JOINED\" | grep -qF 'confirm-ci-green.sh'"
assert_true "AC7: external-review-sequencing.md Post-reconcile gate retains the TARGET pointer-equality token (DCR-7 retention guard)" \
  "printf '%s' \"\$RECONCILE_JOINED\" | grep -qF 'TARGET'"
assert_true "AC7: external-review-sequencing.md Post-reconcile gate retains the authenticated-Jenkins curl token (DCR-7 retention guard)" \
  "printf '%s' \"\$RECONCILE_JOINED\" | grep -qF 'curl'"

GITWORKFLOW_BODY="$(cat "$GIT_WORKFLOW" 2>/dev/null || true)"
assert_true "AC7: git-workflow.md cross-references confirm-ci-green.sh (no third prose restatement)" \
  "printf '%s' \"\$GITWORKFLOW_BODY\" | grep -qF 'confirm-ci-green.sh'"

# =============================================================================
echo ""
echo "=== AC8 (docs/maintained-docs.md registry row added) ==="

MAINTAINED_BODY="$(cat "$MAINTAINED_DOCS" 2>/dev/null || true)"
assert_true "AC8: maintained-docs.md contains a row citing scripts/handoff/confirm-ci-green.sh" \
  "printf '%s' \"\$MAINTAINED_BODY\" | grep -qF 'scripts/handoff/confirm-ci-green.sh'"
assert_true "AC8: maintained-docs.md row also cites the test tests/test-issue-25-confirm-ci-green.sh" \
  "printf '%s' \"\$MAINTAINED_BODY\" | grep -qF 'tests/test-issue-25-confirm-ci-green.sh'"

# =============================================================================
echo ""
echo "=== AC9 (CLI contract: --pr required, --repo optional, usage/env errors coded) ==="

GH_INVOCATION_LOG="$(mktemp)"
run_confirm
assert_true "AC9: missing --pr -> exit 64" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm --pr abc
assert_true "AC9: non-numeric --pr -> exit 64" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm --bogus-flag
assert_true "AC9: unknown flag -> exit 64" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
CI_POLL_TIMEOUT_SECS="not-a-number" run_confirm --pr 42
assert_true "AC9: non-numeric CI_POLL_TIMEOUT_SECS -> exit 64" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_CONFLICTING_DIRTY"
run_confirm --pr 42 --repo owner/name
REPO_LOG="$(cat "$GH_INVOCATION_LOG" 2>/dev/null || true)"
assert_true "AC9: --repo owner/name is forwarded to the gh pr view call argv" \
  "printf '%s' \"\$REPO_LOG\" | grep -qF -- '--repo owner/name'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
