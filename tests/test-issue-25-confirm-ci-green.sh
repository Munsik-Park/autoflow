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
# Cycle-2 (review-response, PR #28 Medium finding) RED expectation - added by
# .autoflow/issue-25-c2-verification-design.md: AC-C2-1a, AC-C2-1b, AC-C2-2,
# AC-C2-3, AC-C2-5, AC-C2-7, AC-C2-8 FAIL against current HEAD (precheck is
# unbounded raw command substitution -- confirm-ci-green.sh:151 -- and any
# failed/empty/non-JSON precheck read is misclassified as a JSON-confirmed
# CONFLICTING, exit 10, per feature design section 1). AC-C2-4 and AC-C2-6 are
# **passing-at-RED regression guards** (design section 3): the current script
# already exits 10 with zero poll calls on a genuine CONFLICTING/DIRTY
# precheck, and already exits 0 on a fast, valid precheck -- both are
# unaffected by the c2 fix's failure-path change, so they hold both before
# and after GREEN.
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
echo ""
echo "=== AC-C2-1a (hung precheck self-bounds, recovers via poll -> exit 0) ==="
# verification design AC-C2-1a: mock precheck sleeps well past pre_bound
# (min(CI_POLL_INTERVAL_SECS,remaining)=1 with CI_POLL_INTERVAL_SECS=1); a
# healthy poll fixture is paired so the fixture hazard (design §1) is
# honored. Outer ceiling = CI_POLL_TIMEOUT_SECS(2) + interval(1) + slack(2).

C2_1A_LOG="$(mktemp)"
C2_1A_INV_LOG="$(mktemp)"
run_bounded 5 "$C2_1A_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$C2_1A_INV_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_PRECHECK_SLEEP=100 \
  GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-C2-1a: the outer 5s harness watchdog never had to fire (precheck self-bounded, not the unbounded raw call)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-C2-1a: exit code is 0 (bounded precheck fell through, healthy poll confirmed green)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 0 ]"
rm -f "$C2_1A_LOG" "$C2_1A_INV_LOG"

# =============================================================================
echo ""
echo "=== AC-C2-1b (precheck+poll never confirm mergeable -> bounded whole-script, exit 14) ==="
# verification design AC-C2-1b: GH_MOCK_EXIT fails EVERY gh call (precheck
# AND poll), so mergeable is never confirmed through the whole budget. The
# post-loop mergeable_confirmed==0 branch must land on the new distinct code
# 14, never conflated with the genuine-conflict 10.

C2_1B_LOG="$(mktemp)"
C2_1B_INV_LOG="$(mktemp)"
run_bounded 5 "$C2_1B_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$C2_1B_INV_LOG" \
  GH_MOCK_EXIT=1 \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-C2-1b: the outer 5s harness watchdog never had to fire (script self-terminated on its own budget)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-C2-1b: exit code is 14 (never confirmed mergeable through precheck+poll — transport failure, not a conflict)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 14 ]"
C2_1B_EXIT="$RB_EXIT"
rm -f "$C2_1B_LOG" "$C2_1B_INV_LOG"

# =============================================================================
echo ""
echo "=== AC-C2-2 (precheck gh failure != CONFLICTING, recovers via poll to exit 0) ==="
# verification design AC-C2-2: a precheck-SCOPED failure (GH_MOCK_PRECHECK_EXIT,
# NOT the all-calls GH_MOCK_EXIT, which would also fail the poll and mask
# recovery) paired with a healthy poll must recover to exit 0 — the direct
# kill of the reviewer's reproduced false-conflict case.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_EXIT=1
GH_MOCK_PRECHECK_BODY=""
GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-C2-2: a precheck-only gh failure recovers via the poll to exit 0 (not misclassified as a conflict)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_false "AC-C2-2: exit code is NOT 10 (transport failure != genuine conflict)" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
assert_false "AC-C2-2: stderr does NOT carry the genuine not-mergeable prose" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qF 'not mergeable ('"
GH_MOCK_PRECHECK_EXIT=""
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-C2-3 (empty / malformed / field-absent precheck body != CONFLICTING, recovers via poll) ==="
# verification design AC-C2-3, §1 fixture hazard: every fall-through case
# pins an explicit well-formed green poll body (not the {} default), so a
# spurious mid-poll exit 10 cannot masquerade as this AC's outcome.

C2_3_CASE_DESCS="EMPTY NONJSON EMPTYOBJ FIELDABSENT"
C2_3_CASE_EMPTY=""
C2_3_CASE_NONJSON="not json"
C2_3_CASE_EMPTYOBJ="{}"
C2_3_CASE_FIELDABSENT='{"foo":1}'

for c2_3_case in $C2_3_CASE_DESCS; do
  case "$c2_3_case" in
    EMPTY) c2_3_body="$C2_3_CASE_EMPTY" ;;
    NONJSON) c2_3_body="$C2_3_CASE_NONJSON" ;;
    EMPTYOBJ) c2_3_body="$C2_3_CASE_EMPTYOBJ" ;;
    FIELDABSENT) c2_3_body="$C2_3_CASE_FIELDABSENT" ;;
  esac
  GH_INVOCATION_LOG="$(mktemp)"
  GH_MOCK_PRECHECK_BODY="$c2_3_body"
  GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN"
  GH_MOCK_POLL_SEQUENCE_FILE=""
  GH_MOCK_POLL_COUNTER_FILE=""
  CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42
  assert_true "AC-C2-3 ($c2_3_case): precheck body falls through (not exit 10) and recovers to exit 0" \
    "[ \"\$RUN_EXIT\" -eq 0 ]"
  rm -f "$GH_INVOCATION_LOG"
done
GH_MOCK_PRECHECK_BODY=""

# =============================================================================
echo ""
echo "=== AC-C2-4 (genuine CONFLICTING/DIRTY still exit 10, zero poll calls — regression guard) ==="
# Passing-at-RED regression guard (design §3): the current script already
# exits 10 with zero poll calls on a JSON-confirmed CONFLICTING/DIRTY
# precheck, unaffected by the c2 failure-path change. A would-be-green poll
# fixture is configured so an erroneous poll invocation would be caught.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_CONFLICTING_DIRTY"
GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
run_confirm --pr 42

assert_true "AC-C2-4: a JSON-confirmed CONFLICTING/DIRTY precheck still exits 10" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
assert_true "AC-C2-4: stderr still carries the reserved HANDOFF-INTERNAL-RETRY token (unchanged)" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qF 'HANDOFF-INTERNAL-RETRY'"
C2_4_POLL_COUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
C2_4_POLL_COUNT="${C2_4_POLL_COUNT:-0}"
assert_true "AC-C2-4: zero poll calls even though a (would-be-green) poll fixture is configured" \
  "[ \"\$C2_4_POLL_COUNT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-C2-5 (exit 14 is distinct and contracted) ==="

assert_true "AC-C2-5: the observed never-confirmed-mergeable outcome (AC-C2-1b) is exactly 14" \
  "[ \"\$C2_1B_EXIT\" -eq 14 ]"
assert_false "AC-C2-5: the never-confirmed-mergeable outcome is NOT any existing code (0/10/11/12/13/64)" \
  "[ \"\$C2_1B_EXIT\" -eq 0 ] || [ \"\$C2_1B_EXIT\" -eq 10 ] || [ \"\$C2_1B_EXIT\" -eq 11 ] || [ \"\$C2_1B_EXIT\" -eq 12 ] || [ \"\$C2_1B_EXIT\" -eq 13 ] || [ \"\$C2_1B_EXIT\" -eq 64 ]"

SCRIPT_SRC_FULL="$(cat "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-C2-5: confirm-ci-green.sh header exit-code table documents a 14 row" \
  "printf '%s' \"\$SCRIPT_SRC_FULL\" | grep -qE '^#[[:space:]]*14[[:space:]]'"

STEP5_BODY_C2="$(extract_section '^5\. Confirm CI is green' "$AUTOFLOW_GUIDE")"
STEP5_JOINED_C2="$(printf '%s' "$STEP5_BODY_C2" | tr '\n' ' ')"
assert_true "AC-C2-5: docs/autoflow-guide.md step 5 contract lists exit 14" \
  "printf '%s' \"\$STEP5_JOINED_C2\" | grep -qE '\\b14\\b'"

# =============================================================================
echo ""
echo "=== AC-C2-7 (header + doc consistency: bound applies to precheck, 14 documented, 10 clarified) ==="

GH_BOUNDED_DOC="$(sed -n '/^# Bounded execution/,/^gh_bounded()/p' "$SCRIPT" 2>/dev/null || true)"
assert_false "AC-C2-7: the gh_bounded comment no longer claims in-loop-only usage" \
  "printf '%s' \"\$GH_BOUNDED_DOC\" | grep -qF 'Used per in-loop \`gh\` round-trip so'"
assert_true "AC-C2-7: the gh_bounded doc-comment now also names the precheck (not just the exit-code table)" \
  "printf '%s' \"\$GH_BOUNDED_DOC\" | grep -qF 'precheck'"
assert_true "AC-C2-7: header documents the failed/timed-out/empty precheck falling through (10 clarified to a JSON-confirmed read only)" \
  "printf '%s' \"\$SCRIPT_SRC_FULL\" | grep -qF 'falls through'"
assert_true "AC-C2-7: autoflow-guide.md step 5 documents the precheck fall-through (not an immediate conflict)" \
  "printf '%s' \"\$STEP5_JOINED_C2\" | grep -qF 'falls through'"

# =============================================================================
echo ""
echo "=== AC-C2-8 (mid-poll mergeable_confirmed flag: gated symmetrically with the precheck) ==="
# verification design AC-C2-8 (static assessment): the in-loop tolerance
# guard is intact, and mergeable_confirmed=1 on a good in-loop read is gated
# inside the [ -n "$m" ] branch — symmetric with the precheck's
# [ -z "$pre_mergeable" ] fall-through arm — so a degraded-but-nonempty
# in-loop body does not set the flag.

assert_true "AC-C2-8: script tracks a mergeable_confirmed flag (post-loop classifier input)" \
  "printf '%s' \"\$SCRIPT_SRC_FULL\" | grep -qF 'mergeable_confirmed'"
assert_true "AC-C2-8: the in-loop tolerance guard (GH_TIMED_OUT/GH_RC/empty-body) is still present" \
  "printf '%s' \"\$SCRIPT_SRC_FULL\" | grep -qF 'GH_TIMED_OUT'"

M_GATE_CONTEXT="$(grep -A3 -F '-n "$m"' "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-C2-8: an -n \"\$m\" gate exists around the in-loop success path (symmetric w/ precheck's -z \$pre_mergeable arm)" \
  "[ -n \"\$M_GATE_CONTEXT\" ]"
assert_true "AC-C2-8: mergeable_confirmed=1 is set inside that -n \"\$m\" gate (not unconditionally after the m/s parse)" \
  "printf '%s' \"\$M_GATE_CONTEXT\" | grep -qF 'mergeable_confirmed=1'"

# =============================================================================
echo ""
echo "=== AC-C2-6 (bounding does not clip a fast, valid precheck — regression guard) ==="
# Passing-at-RED regression guard (design §3): the current unbounded script
# already proceeds to the poll and exits 0 on a fast, valid precheck; the c2
# bound must not make this spuriously fail.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-C2-6: a fast, valid precheck still proceeds to poll and exits 0 under the new bound" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
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
