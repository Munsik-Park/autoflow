#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/handoff/confirm-ci-green.sh docs/autoflow-guide.md tests/lib/confirm-ci-green-harness.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
#   AC7 — FAIL (docs not yet restructured; current text asserted against
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

# Shared harness: run_bounded, run_confirm, PRECHECK_MERGEABLE_CLEAN (issue #122).
# Sourced after SCRIPT and MOCK_GH_DIR, which run_confirm reads.
. "$PROJECT_ROOT/tests/lib/confirm-ci-green-harness.sh"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EXTERNAL_REVIEW_SEQ="$PROJECT_ROOT/docs/external-review-sequencing.md"
GIT_WORKFLOW="$PROJECT_ROOT/docs/git-workflow.md"

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

# Outer harness-watchdog slack for the run_bounded legs below (AC5,
# AC-C2-1a, AC-C2-1b, AC-C3-2, AC-C3-6, AC-C3-7). A shared CI runner adds
# real subprocess-spawn overhead (the gh mock invocation, jq, mktemp) on
# top of the script's own poll budget that a fixed guess does not reliably
# cover -- CI round 4 (run 31456233814) flipped one of these assertions on
# the ubuntu runner while the macOS/BSD run stayed clean at the same fixed
# bound. Each leg's outer bound is DERIVED from that leg's own
# CI_POLL_TIMEOUT_SECS + CI_POLL_INTERVAL_SECS plus this single named,
# overridable constant, rather than a widened ad-hoc sleep scattered per
# leg.
HARNESS_OVERHEAD_SLACK_SECS="${HARNESS_OVERHEAD_SLACK_SECS:-8}"

# Fixture bodies (JSON, one line each — feature §3.3 field shapes).
PRECHECK_CONFLICTING_DIRTY='{"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY"}'

POLL_ALL_GREEN_CHECKRUN='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"}]}'
POLL_ALL_GREEN_STATUSCONTEXT='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"StatusContext","context":"continuous-integration/jenkins/pr-merge","state":"SUCCESS"}]}'
POLL_EMPTY_ROLLUP='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[]}'
POLL_PENDING='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"IN_PROGRESS","conclusion":null}]}'
POLL_FAILURE='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"FAILURE"}]}'
POLL_FLIPPED_CONFLICTING='{"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY","statusCheckRollup":[]}'

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
# CI_POLL_TIMEOUT_SECS(2) + CI_POLL_INTERVAL_SECS(1) + HARNESS_OVERHEAD_SLACK_SECS.
# This tripwire must NOT fire once the script self-terminates on its own deadline.
AC5_LOG="$(mktemp)"
run_bounded "$((2 + 1 + HARNESS_OVERHEAD_SLACK_SECS))" "$AC5_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$GH_MOCK_PRECHECK_BODY" \
  GH_MOCK_POLL_BODY="$GH_MOCK_POLL_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC5: the outer harness watchdog never had to fire (script self-terminated via its own deadline)" \
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
# honored. Outer ceiling = CI_POLL_TIMEOUT_SECS(5) + interval(1) +
# HARNESS_OVERHEAD_SLACK_SECS.
#
# CI round 5 (run 31456977323) root cause: with CI_POLL_TIMEOUT_SECS=2, the
# script's own deadline is start+2s; the precheck is killed at
# pre_bound=~1s (confirm-ci-green.sh:238-246, clamp_to_interval(remaining)),
# so on a loaded runner the ~1s precheck kill plus subprocess/jq overhead
# alone can consume the whole 2s inner budget with `date +%s` integer-second
# granularity -- the poll loop body never runs, mergeable is never
# confirmed, and the script lands on exit 14 instead of the expected exit
# 0. This is an INNER-budget squeeze, distinct from the outer
# HARNESS_OVERHEAD_SLACK_SECS watchdog fixed in the prior round.
# CI_POLL_TIMEOUT_SECS=5 gives deterministic headroom for >=1 poll
# iteration after the ~1s-bounded precheck even with several seconds of
# runner overhead; CI_POLL_INTERVAL_SECS stays 1 (assertion semantics --
# "precheck self-bounds, recovers via poll" -- are unchanged).

C2_1A_LOG="$(mktemp)"
C2_1A_INV_LOG="$(mktemp)"
run_bounded "$((5 + 1 + HARNESS_OVERHEAD_SLACK_SECS))" "$C2_1A_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$C2_1A_INV_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_PRECHECK_SLEEP=100 \
  GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN" \
  CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-C2-1a: the outer harness watchdog never had to fire (precheck self-bounded, not the unbounded raw call)" \
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
#
# Round-5 headroom review: unlike AC-C2-1a, no leg here sleeps -- every gh
# call fails immediately (GH_MOCK_EXIT=1, no GH_MOCK_PRECHECK_SLEEP), so
# mergeable_confirmed stays 0 whether the poll loop runs zero or several
# iterations; the CI_POLL_TIMEOUT_SECS(2) inner budget is not knife-edge
# for THIS assertion's outcome and is left unchanged.

C2_1B_LOG="$(mktemp)"
C2_1B_INV_LOG="$(mktemp)"
run_bounded "$((2 + 1 + HARNESS_OVERHEAD_SLACK_SECS))" "$C2_1B_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$C2_1B_INV_LOG" \
  GH_MOCK_EXIT=1 \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$POLL_ALL_GREEN_CHECKRUN" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-C2-1b: the outer harness watchdog never had to fire (script self-terminated on its own budget)" \
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

M_GATE_CONTEXT="$(grep -A3 -F -e '-n "$m"' -e '-z "$m"' "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-C2-8: a mergeable-emptiness guard (-n \"\$m\" or -z \"\$m\") exists around the in-loop success path (symmetric w/ precheck's -z \$pre_mergeable arm)" \
  "[ -n \"\$M_GATE_CONTEXT\" ]"
assert_true "AC-C2-8: mergeable_confirmed=1 is set inside a guard that excludes the empty-\$m path (co-occurs with the captured guard context)" \
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
echo ""
echo "=== AC-C3-1 (mid-poll malformed/field-absent body != 10, recovers via later green poll) ==="
# verification design AC-C3-1: a mid-poll body that is non-empty, rc-0, but
# malformed / mergeable-absent must NOT exit 10 (RED at HEAD: is_not_mergeable
# "" "" -> true -> exit 10 on iter-1, iter-2 never reached). Parametrized over
# the same malformed shapes as AC-C2-3's precheck parametrization.
for MALFORMED_BODY in 'not json' '{}' '{"foo":1}'; do
  GH_INVOCATION_LOG="$(mktemp)"
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
  SEQ_FILE="$(mktemp)"
  printf '%s\n' "$MALFORMED_BODY" > "$SEQ_FILE"
  printf '%s\n' "$POLL_ALL_GREEN_CHECKRUN" >> "$SEQ_FILE"
  COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
  GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
  GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
  CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

  assert_false "AC-C3-1: malformed mid-poll body ($MALFORMED_BODY) does NOT exit 10" \
    "[ \"\$RUN_EXIT\" -eq 10 ]"
  assert_true "AC-C3-1: malformed mid-poll body ($MALFORMED_BODY) recovers via the later green poll -> exit 0" \
    "[ \"\$RUN_EXIT\" -eq 0 ]"
  rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"
done

# =============================================================================
echo ""
echo "=== AC-C3-2 (persistent malformed mid-poll, healthy precheck -> bounded, non-conflict terminal, never 10) ==="
# verification design AC-C3-2 / §0 environment note: this box has neither
# timeout nor gtimeout, so the finite-termination proof is driven under the
# suite's outer run_bounded watchdog (NOT a bare run_confirm) — load-bearing
# because at RED the malformed-continue path does not exist yet and a
# regression there could hang. D-C3-1 (resolved): healthy precheck already
# sets mergeable_confirmed=1 at :213, so the post-loop classifier lands on
# exit 11 (saw_checks==0), not 14. Primary assertion is the robust != 10;
# secondary is the firm == 11 binding.
#
# Round-5 headroom review: the precheck fixture here is healthy
# (PRECHECK_MERGEABLE_CLEAN, no GH_MOCK_PRECHECK_SLEEP), so it does not
# consume the pre_bound the way AC-C2-1a's does, and mergeable_confirmed=1
# is set at the precheck itself -- the exit-11 outcome does not depend on
# how many malformed-poll iterations the CI_POLL_TIMEOUT_SECS(2) inner
# budget allows, so this leg is not knife-edge and is left unchanged.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY='not json'
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""

AC_C3_2_LOG="$(mktemp)"
run_bounded "$((2 + 1 + HARNESS_OVERHEAD_SLACK_SECS))" "$AC_C3_2_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$GH_MOCK_PRECHECK_BODY" \
  GH_MOCK_POLL_BODY="$GH_MOCK_POLL_BODY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-C3-2: the outer harness watchdog never had to fire (finite termination of the malformed-continue loop)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_false "AC-C3-2: a persistently-malformed mid-poll under a healthy precheck does NOT exit 10 (the finding's actual kill)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 10 ]"
assert_true "AC-C3-2 (secondary, firm D-C3-1): exact terminal code is 11 (healthy precheck already confirmed mergeable at :213)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 11 ]"
rm -f "$GH_INVOCATION_LOG" "$AC_C3_2_LOG"

# =============================================================================
echo ""
echo "=== AC-C3-3 (genuine mid-poll flip MERGEABLE -> CONFLICTING still exit 10 — regression guard) ==="
# Passing-at-RED regression guard: reuses the existing AC-FLIP fixture. A
# well-formed CONFLICTING read has non-empty m, so the new [ -z "$m" ] arm
# never fires on it — holds both before and after GREEN.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"
printf '%s\n' "$POLL_EMPTY_ROLLUP" > "$SEQ_FILE"
printf '%s\n' "$POLL_FLIPPED_CONFLICTING" >> "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-C3-3: a genuine mid-poll flip to CONFLICTING still exits 10 (fix does not narrow the mid-poll-flip contract)" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
POLL_CALLS_AC_C3_3="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
POLL_CALLS_AC_C3_3="${POLL_CALLS_AC_C3_3:-0}"
assert_true "AC-C3-3: exactly 2 poll calls issued (flip observed on the 2nd, no 3rd call)" \
  "[ \"\$POLL_CALLS_AC_C3_3\" -eq 2 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC-C3-4 (mid-poll fall-through arm present + symmetric with precheck — static) ==="
# verification design AC-C3-4: a [ -z "$m" ] (empty parsed mergeable)
# fall-through arm exists BEFORE the is_not_mergeable call at the mid-poll
# site, and the degraded-read flag invariant (mergeable_confirmed=1
# unreachable on an empty $m) holds under EITHER the c2 -n "$m" wrapper form
# or the c3 early -z "$m" -> continue form (must not pin the literal -n "$m"
# wrapper — that would fail once Fix 1 lands).

MIDPOLL_BLOCK="$(sed -n '/D5 — re-read mergeable every iteration/,/^  fi$/p' "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-C3-4: a [ -z \"\$m\" ]-shaped guard exists in the mid-poll block, before is_not_mergeable is called" \
  "printf '%s' \"\$MIDPOLL_BLOCK\" | grep -qF -- '-z \"\$m\"'"

MIDPOLL_ZGUARD_TO_ISNOTMERGEABLE="$(awk '/D5 — re-read mergeable every iteration/{f=1} f{print} f && /is_not_mergeable/{exit}' "$SCRIPT" 2>/dev/null || true)"
ZGUARD_LINE="$(printf '%s\n' "$MIDPOLL_ZGUARD_TO_ISNOTMERGEABLE" | grep -nF -- '-z "$m"' | head -n 1 | cut -d: -f1 || true)"
ISNOTMERGEABLE_LINE="$(printf '%s\n' "$MIDPOLL_ZGUARD_TO_ISNOTMERGEABLE" | grep -nF 'is_not_mergeable "$m"' | head -n 1 | cut -d: -f1 || true)"
assert_true "AC-C3-4: the [ -z \"\$m\" ] guard appears BEFORE the is_not_mergeable \"\$m\" call in the mid-poll block" \
  "[ -n \"\$ZGUARD_LINE\" ] && [ -n \"\$ISNOTMERGEABLE_LINE\" ] && [ \"\$ZGUARD_LINE\" -lt \"\$ISNOTMERGEABLE_LINE\" ]"

# Degraded-read flag invariant: accept either the c2 -n "$m" wrapper form or
# the c3 -z "$m" -> continue form (same acceptance rule as the AC-C2-8
# relaxation above).
INVARIANT_GATE_CONTEXT="$(grep -A3 -F -e '-n "$m"' -e '-z "$m"' "$SCRIPT" 2>/dev/null || true)"
assert_true "AC-C3-4: mergeable_confirmed=1 co-occurs with a guard that excludes the empty-\$m path (either accepted form)" \
  "[ -n \"\$INVARIANT_GATE_CONTEXT\" ] && printf '%s' \"\$INVARIANT_GATE_CONTEXT\" | grep -qF 'mergeable_confirmed=1'"

# =============================================================================
echo ""
echo "=== AC-C3-5 (doc: exit-10 line generalized to name the mid-poll fall-through) ==="
# verification design AC-C3-5: docs/autoflow-guide.md step-5 exit-code
# contract and the script header no longer describe the "malformed/empty
# read falls through, never 10" guard as precheck-only.

SCRIPT_SRC_FULL_C3="$(cat "$SCRIPT" 2>/dev/null || true)"
TEN_ROW_C3="$(printf '%s' "$SCRIPT_SRC_FULL_C3" | grep -E '^#[[:space:]]*10[[:space:]]' -A5 2>/dev/null || true)"
assert_false "AC-C3-5: the script header's 10-row no longer scopes the fall-through to the precheck only" \
  "printf '%s' \"\$TEN_ROW_C3\" | grep -qF 'empty precheck read falls through'"

STEP5_BODY_C3="$(extract_section '^5\. Confirm CI is green' "$AUTOFLOW_GUIDE")"
STEP5_JOINED_C3="$(printf '%s' "$STEP5_BODY_C3" | tr '\n' ' ')"
assert_false "AC-C3-5: docs/autoflow-guide.md step 5's 10 line no longer restricts the fall-through wording to 'precheck read'" \
  "printf '%s' \"\$STEP5_JOINED_C3\" | grep -qF 'empty / non-JSON precheck read is'"
assert_true "AC-C3-5: docs/autoflow-guide.md step 5's 10 line names the mid-poll site alongside the precheck" \
  "printf '%s' \"\$STEP5_JOINED_C3\" | grep -qF 'mid-poll'"

# =============================================================================
echo ""
echo "=== AC-C3-6 (dangling --pr last token -> bounded termination + exit 64, not hang) ==="
# verification design AC-C3-6 / Finding 2: RED at HEAD is a genuine infinite
# loop (shift 2 at $#=1 fails without consuming any argument under set -uo
# pipefail, no -e), so this invocation MUST be wrapped in run_bounded — a
# bare run_confirm would hang the whole suite. GREEN reaches usage; exit 64.
#
# Round-5 headroom review: this leg never sets CI_POLL_TIMEOUT_SECS -- it
# exits via the argv-usage path before any gh call or poll loop, so it
# carries no inner-budget squeeze risk; only the outer
# HARNESS_OVERHEAD_SLACK_SECS watchdog applies.

AC_C3_6_LOG="$(mktemp)"
run_bounded "$HARNESS_OVERHEAD_SLACK_SECS" "$AC_C3_6_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  bash "$SCRIPT" --pr

assert_true "AC-C3-6: the outer harness watchdog never had to fire (script self-terminates, no hang)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-C3-6: a dangling --pr (no value) terminates finitely with exit 64 via the usage path" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 64 ]"
rm -f "$AC_C3_6_LOG"

# =============================================================================
echo ""
echo "=== AC-C3-7 (dangling --repo last token -> bounded termination + exit 64) ==="
# verification design AC-C3-7 / D-C3-2: a value-taking --repo as the
# dangling last token is a malformed invocation, not a silent REPO="".
#
# Round-5 headroom review: same shape as AC-C3-6 -- no CI_POLL_TIMEOUT_SECS,
# exits via the argv-usage path before any gh call, so no inner-budget
# squeeze risk.

AC_C3_7_LOG="$(mktemp)"
run_bounded "$HARNESS_OVERHEAD_SLACK_SECS" "$AC_C3_7_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  bash "$SCRIPT" --pr 42 --repo

assert_true "AC-C3-7: the outer harness watchdog never had to fire (script self-terminates, no hang)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-C3-7: a dangling --repo (no value) terminates finitely with exit 64 via the usage path" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 64 ]"
rm -f "$AC_C3_7_LOG"

# =============================================================================
echo ""
echo "=== AC-C3-8 (well-formed argv unaffected by the bounds check — regression guard) ==="
# Passing-at-RED regression guard: every argv shape here already terminates
# today; the fix must leave them untouched. Re-asserts AC9/AC1 shapes plus a
# new -h/--help -> exit 0 case.

GH_INVOCATION_LOG="$(mktemp)"
run_confirm
assert_true "AC-C3-8: missing --pr -> exit 64 (unaffected by the bounds check)" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm --pr abc
assert_true "AC-C3-8: non-numeric --pr -> exit 64 (unaffected by the bounds check)" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm --bogus-flag
assert_true "AC-C3-8: unknown flag -> exit 64 (unaffected by the bounds check)" "[ \"\$RUN_EXIT\" -eq 64 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_CONFLICTING_DIRTY"
run_confirm --pr 42 --repo owner/name
REPO_LOG_C3="$(cat "$GH_INVOCATION_LOG" 2>/dev/null || true)"
assert_true "AC-C3-8: --pr N --repo owner/name still forwards --repo to the gh pr view call argv" \
  "printf '%s' \"\$REPO_LOG_C3\" | grep -qF -- '--repo owner/name'"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm -h
assert_true "AC-C3-8: -h -> exit 0" "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

GH_INVOCATION_LOG="$(mktemp)"
run_confirm --help
assert_true "AC-C3-8: --help -> exit 0" "[ \"\$RUN_EXIT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNKNOWN-POLLS (transient UNKNOWN precheck enters the poll, settles green) — issue #81 ==="
# verification design AC-UNKNOWN-POLLS (.autoflow/issue-81-verification-design.md
# §"Acceptance criteria"): a precheck read of mergeable=UNKNOWN must NOT take
# the immediate exit-10 path. Today's bug: is_not_mergeable() returns true
# whenever $1 != "MERGEABLE" (confirm-ci-green.sh:202), so a still-computing
# UNKNOWN is classified identically to a confirmed CONFLICTING. The bounded
# poll must be entered instead, and a settling sequence must reach exit 0.

PRECHECK_UNKNOWN='{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN"}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_UNKNOWN"
SEQ_FILE="$(mktemp)"; printf '%s\n' "$POLL_ALL_GREEN_CHECKRUN" > "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNKNOWN-POLLS: exit code is 0 (a still-computing precheck is NOT a confirmed conflict)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
POLL_LINE_COUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
POLL_LINE_COUNT="${POLL_LINE_COUNT:-0}"
assert_true "AC-UNKNOWN-POLLS: at least one statusCheckRollup-bearing (poll) gh call was issued (the bounded poll was entered, not skipped)" \
  "[ \"\$POLL_LINE_COUNT\" -ge 1 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC-UNKNOWN-BOUNDED (persistent UNKNOWN terminates at the deadline, exit 14 EXACTLY) — issue #81 ==="
# verification design AC-UNKNOWN-BOUNDED / feature design issue Risk ①: a
# PERSISTENT UNKNOWN (precheck AND every poll body) must still terminate
# inside the deadline via the existing bounded loop -- never wait past it --
# and land on exit 14 exactly (mergeable_confirmed never set for this run).
# Fixture precondition (verification design, stated explicitly): every poll
# body carries an EMPTY statusCheckRollup so the fail>0/exit-12 branch is
# never reached and the flag-never-set path is the only reachable one -- the
# exactness assertion rests on this precondition. Wrapped in the outer
# run_bounded harness watchdog (AC-C3-6/AC-C3-7 convention) since a
# mis-implemented fix here would be a genuine hang, not a fast exit.

POLL_UNKNOWN_EMPTY='{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}'

AC_UNKNOWN_BOUNDED_LOG="$(mktemp)"
GH_INVOCATION_LOG="$(mktemp)"
run_bounded 10 "$AC_UNKNOWN_BOUNDED_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$POLL_UNKNOWN_EMPTY" \
  GH_MOCK_POLL_BODY="$POLL_UNKNOWN_EMPTY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-UNKNOWN-BOUNDED: the outer harness watchdog never had to fire (bounded loop self-terminates within CI_POLL_TIMEOUT_SECS)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-UNKNOWN-BOUNDED: a persistent UNKNOWN terminates with exit 14 EXACTLY (never 10/11/13, and NOT green)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 14 ]"
rm -f "$AC_UNKNOWN_BOUNDED_LOG" "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNDETERMINED-AFTER-CONFIRMED (sticky flag: confirmed-then-undetermined exits 11) — issue #81 ==="
# verification design AC-UNDETERMINED-AFTER-CONFIRMED / feature design "Flag
# lifetime": mergeable_confirmed is a RUN-SCOPED LATCH, not a per-read
# verdict -- once a confirmed read sets it, no later undetermined read clears
# it. A precheck that confirms MERGEABLE, followed by every poll going
# UNKNOWN through the deadline (empty rollup -- no check ever observed), must
# NOT regress to exit 14 ("could not confirm mergeable state" -- a FALSE
# sentence for a run whose precheck DID confirm it). It must report exit 11
# ("MERGEABLE but no check published"), the true statement of this run.

POLL_UNKNOWN_EMPTY_2='{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_UNKNOWN_EMPTY_2"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=3 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNDETERMINED-AFTER-CONFIRMED: exit code is 11 EXACTLY (not 14 -- the precheck's confirmation survives the later undetermined polls)" \
  "[ \"\$RUN_EXIT\" -eq 11 ]"
assert_true "AC-UNDETERMINED-AFTER-CONFIRMED: stderr carries the 'MERGEABLE but no check published' sentence" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qF 'MERGEABLE but no check published'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNDETERMINED-RED-CI (mid-poll UNKNOWN + failing rollup still routes to RED, exit 12) — issue #81 ==="
# verification design AC-UNDETERMINED-RED-CI / feature design third
# deliberate-decision bullet: an undetermined mid-poll read must still
# evaluate the rollup for a concluded failure -- withholding ONLY the
# green/mergeability verdict, never the red-CI verdict. A read of
# mergeable=UNKNOWN paired with a FAILURE rollup element must exit 12, never
# sleep to a deadline code (11/13/14) and never silently mask the red build.

POLL_UNKNOWN_FAILURE='{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"FAILURE"}]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
SEQ_FILE="$(mktemp)"; printf '%s\n' "$POLL_UNKNOWN_FAILURE" > "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNDETERMINED-RED-CI: exit code is 12 (a concluded failure under an undetermined mergeable read still routes to RED)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
assert_true "AC-UNDETERMINED-RED-CI: stderr carries the 'red CI (route to RED)' sentence" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qF 'red CI (route to RED)'"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC-UNDETERMINED-ALLGREEN-13 (confirmed-then-undetermined, all-green rollup, never re-settles -> exit 13 with a case-aware message) — issue #81 GATE:QUALITY FAIL#2 (ledger E31) ==="
# GATE:QUALITY FAIL#2 item 2(c): the exit-13 stderr message ("checks still
# pending ... slow CI") is emitted verbatim for BOTH exit-13 causes today --
# genuinely slow/incomplete CI, and this scenario: mergeability was CONFIRMED
# at precheck, every poll then goes UNKNOWN, and the rollup is ALREADY
# all-green -- the undetermined arm withholds the exit-0 verdict (feature
# design's third deliberate-decision bullet), so the run correctly lands on
# 13, but "still pending" misdescribes a rollup that is not pending at all.
# The exit-code routing itself is a pre-existing regression guard (already
# correct since the round-1 GREEN fix); the message-accuracy assertion is
# this lane's RED discriminator for #81 GATE:QUALITY FAIL#2.

POLL_UNKNOWN_ALLGREEN='{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"}]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_UNKNOWN_ALLGREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=3 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNDETERMINED-ALLGREEN-13: exit code is 13 (regression guard -- undetermined suppresses the exit-0 verdict, mergeable_confirmed stays sticky from the precheck so it is not 14)" \
  "[ \"\$RUN_EXIT\" -eq 13 ]"
assert_true "AC-UNDETERMINED-ALLGREEN-13: stderr names the confirmed-then-undetermined/never-re-settled cause, not only 'still pending', when the rollup is actually all-green" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qiE 'undetermined|re-settl|never settled'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNKNOWN-DIRTY-ORDER (UNKNOWN mergeable + confirmed DIRTY state still exits 10, no poll) — issue #81 GATE:QUALITY FAIL#2 (ledger E31, optional test_coverage item) ==="
# feature design "A. Interface" first deliberate-decision bullet: not-mergeable
# is tested BEFORE undetermined, so mergeable=UNKNOWN paired with a CONFIRMED
# mergeStateStatus=DIRTY read is a confirmed conflict, not a poll candidate --
# testing undetermined first would demote a real conflict to a poll and delay
# it, exactly the risk the issue's Risk (1) names. Regression guard, already
# correct since the round-1 GREEN fix (is_not_mergeable's DIRTY disjunct is
# unconditional on $1); added per E31's optional non-capping coverage note.

PRECHECK_UNKNOWN_DIRTY='{"mergeable":"UNKNOWN","mergeStateStatus":"DIRTY"}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_UNKNOWN_DIRTY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
run_confirm --pr 42

assert_true "AC-UNKNOWN-DIRTY-ORDER: exit code is 10 (a confirmed DIRTY state outranks the UNKNOWN mergeable enum -- order matters)" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
POLL_COUNT_DIRTY_ORDER="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
POLL_COUNT_DIRTY_ORDER="${POLL_COUNT_DIRTY_ORDER:-0}"
assert_true "AC-UNKNOWN-DIRTY-ORDER: no statusCheckRollup-bearing (poll) gh call was issued -- the confirmed conflict is never demoted to a poll" \
  "[ \"\$POLL_COUNT_DIRTY_ORDER\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNSETTLED-STATE-PRECHECK (MERGEABLE+UNKNOWN precheck falls through to poll; persistent -> exit 14, watchdog never fires) — issue #81 cycle 2 ==="
# verification design AC-UNSETTLED-STATE-PRECHECK (.autoflow/issue-81-verification-design.md
# row 1): today is_mergeable_undetermined() reduces to [ "$1" != "MERGEABLE" ],
# so mergeable=MERGEABLE + mergeStateStatus=UNKNOWN latches mergeable_confirmed=1
# in the precheck else arm; it must instead fall through to the bounded poll and,
# if the pair never settles, terminate INSIDE the deadline. Fixture precondition:
# every poll body carries the SAME pair with an EMPTY statusCheckRollup, keeping
# the fail>0/exit-12 and total>0/exit-11 arms unreachable so the oracle is exact.
# Wrapped in the outer run_bounded watchdog (AC-UNKNOWN-BOUNDED convention) since
# a mis-implemented fix here would be a genuine hang, not a fast exit.

PRECHECK_MERGEABLE_UNKNOWN='{"mergeable":"MERGEABLE","mergeStateStatus":"UNKNOWN"}'
POLL_MERGEABLE_UNKNOWN_EMPTY='{"mergeable":"MERGEABLE","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}'

AC_UNSETTLED_PRECHECK_LOG="$(mktemp)"
GH_INVOCATION_LOG="$(mktemp)"
run_bounded 10 "$AC_UNSETTLED_PRECHECK_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_INVOCATION_LOG="$GH_INVOCATION_LOG" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_UNKNOWN" \
  GH_MOCK_POLL_BODY="$POLL_MERGEABLE_UNKNOWN_EMPTY" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 42

assert_true "AC-UNSETTLED-STATE-PRECHECK: the outer harness watchdog never had to fire (bounded loop self-terminates within CI_POLL_TIMEOUT_SECS)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-UNSETTLED-STATE-PRECHECK: exit code is 14 EXACTLY (precheck fell through to the poll, never latched, never confirmed)" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 14 ]"
AC_UNSETTLED_PRECHECK_POLLCOUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
AC_UNSETTLED_PRECHECK_POLLCOUNT="${AC_UNSETTLED_PRECHECK_POLLCOUNT:-0}"
assert_true "AC-UNSETTLED-STATE-PRECHECK: at least one statusCheckRollup-bearing (poll) gh call was issued (the poll was entered, not skipped by a false precheck confirmation)" \
  "[ \"\$AC_UNSETTLED_PRECHECK_POLLCOUNT\" -ge 1 ]"
rm -f "$AC_UNSETTLED_PRECHECK_LOG" "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNSETTLED-STATE-SETTLES-GREEN (mid-poll MERGEABLE+UNKNOWN retried, settles to MERGEABLE/CLEAN -> exit 0) — issue #81 cycle 2 ==="
# verification design AC-UNSETTLED-STATE-SETTLES-GREEN: an unsettled mid-poll
# read must be retried, not terminal -- the ordinary "push then settle shortly
# after" path. The exit code alone would not discriminate today's bug (the
# precheck already confirms this pair and the first poll body is already
# all-green, so today's run exits 0 after ONE rollup-bearing call); the oracle
# therefore also requires >= 2 rollup-bearing calls, proving the unsettled
# iteration was actually retried rather than the precheck short-circuiting to
# green on the first poll read.

POLL_MERGEABLE_UNKNOWN_GREEN='{"mergeable":"MERGEABLE","mergeStateStatus":"UNKNOWN","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"}]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_UNKNOWN"
SEQ_FILE="$(mktemp)"; printf '%s\n%s\n' "$POLL_MERGEABLE_UNKNOWN_GREEN" "$POLL_ALL_GREEN_CHECKRUN" > "$SEQ_FILE"
COUNTER_FILE="$(mktemp)"; echo 0 > "$COUNTER_FILE"
GH_MOCK_POLL_SEQUENCE_FILE="$SEQ_FILE"
GH_MOCK_POLL_COUNTER_FILE="$COUNTER_FILE"
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNSETTLED-STATE-SETTLES-GREEN: exit code is 0 (the run settled to MERGEABLE/CLEAN and reached the confirmed-green verdict)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
AC_SETTLES_POLLCOUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
AC_SETTLES_POLLCOUNT="${AC_SETTLES_POLLCOUNT:-0}"
assert_true "AC-UNSETTLED-STATE-SETTLES-GREEN: at least 2 statusCheckRollup-bearing calls (the unsettled iteration was retried, not treated as terminal)" \
  "[ \"\$AC_SETTLES_POLLCOUNT\" -ge 2 ]"
rm -f "$GH_INVOCATION_LOG" "$SEQ_FILE" "$COUNTER_FILE"

# =============================================================================
echo ""
echo "=== AC-UNSETTLED-STATE-FALSE-GREEN (the reviewer's witness: MERGEABLE+UNKNOWN + an all-green rollup never exits 0) — issue #81 cycle 2 ==="
# verification design AC-UNSETTLED-STATE-FALSE-GREEN, the defect as it
# actually harms an operator: today the pair confirms at precheck and the
# all-green rollup reaches the exit-0 gate on the FIRST poll iteration. 13 is
# unreachable here (mergeable_confirmed is never latched under the fix, since
# the pair never settles), so 14 -- not 0, not 13 -- is the contracted code.

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_UNKNOWN"
GH_MOCK_POLL_BODY="$POLL_MERGEABLE_UNKNOWN_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=3 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNSETTLED-STATE-FALSE-GREEN: exit code is 14 EXACTLY (an all-green rollup under a persistently unsettled mergeStateStatus is never reported green)" \
  "[ \"\$RUN_EXIT\" -eq 14 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-UNSETTLED-AFTER-CONFIRMED (confirmed once, then unsettled through the deadline with an already-all-green rollup -> exit 13) — issue #81 cycle 2 ==="
# verification design AC-UNSETTLED-AFTER-CONFIRMED: precheck confirms
# MERGEABLE/CLEAN; every poll body then reads MERGEABLE/UNKNOWN with an
# all-green rollup. Today the mid-poll MERGEABLE/UNKNOWN read classifies as
# confirmed (is_mergeable_undetermined reduces to $1 != MERGEABLE), so
# undetermined stays 0 and the all-green rollup exits 0 on the first
# iteration -- must instead exit 13, and stderr must name the
# confirmed-then-undetermined/never-re-settled cause (the same case-aware
# sentence AC-UNDETERMINED-ALLGREEN-13 already binds).

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY="$POLL_MERGEABLE_UNKNOWN_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=3 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-UNSETTLED-AFTER-CONFIRMED: exit code is 13 EXACTLY (confirmed once, then unsettled -- not 0 and not 14)" \
  "[ \"\$RUN_EXIT\" -eq 13 ]"
assert_true "AC-UNSETTLED-AFTER-CONFIRMED: stderr names the confirmed-then-undetermined/never-re-settled cause" \
  "printf '%s' \"\$RUN_OUTPUT\" | grep -qiE 'undetermined|re-settl|never settled'"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-DIRTY-PRIORITY-OVER-STATE (MERGEABLE+DIRTY stays a confirmed conflict, exit 10, no poll) — issue #81 cycle 2 [INVARIANCE GUARD: green before AND after -- do NOT reshape] ==="
# verification design AC-DIRTY-PRIORITY-OVER-STATE: is_not_mergeable is
# [ "$1" = "CONFLICTING" ] || [ "$2" = "DIRTY" ], so DIRTY already decides and
# already exits 10 with no poll, independent of the undetermined predicate's
# widening. REGRESSION GUARD, not a Red discriminator: must pass at HEAD and
# must still pass after GREEN widens is_mergeable_undetermined -- do not
# reshape this lane to make it fail.

PRECHECK_MERGEABLE_DIRTY='{"mergeable":"MERGEABLE","mergeStateStatus":"DIRTY"}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_DIRTY"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
run_confirm --pr 42

assert_true "AC-DIRTY-PRIORITY-OVER-STATE: exit code is 10 (confirmed conflict, invariance guard)" \
  "[ \"\$RUN_EXIT\" -eq 10 ]"
AC_DIRTY_POLLCOUNT="$(grep -cF 'statusCheckRollup' "$GH_INVOCATION_LOG" 2>/dev/null)"
AC_DIRTY_POLLCOUNT="${AC_DIRTY_POLLCOUNT:-0}"
assert_true "AC-DIRTY-PRIORITY-OVER-STATE: no statusCheckRollup-bearing (poll) gh call was issued (invariance guard)" \
  "[ \"\$AC_DIRTY_POLLCOUNT\" -eq 0 ]"
rm -f "$GH_INVOCATION_LOG"

# =============================================================================
echo ""
echo "=== AC-SETTLED-NONCLEAN-CONFIRMS (a settled non-CLEAN state, e.g. BLOCKED, with an all-green rollup still confirms -> exit 0) — issue #81 cycle 2 [INVARIANCE GUARD: green before AND after -- do NOT reshape] ==="
# verification design AC-SETTLED-NONCLEAN-CONFIRMS: the anti-over-widening
# criterion -- only UNKNOWN is unsettled; BLOCKED/BEHIND/UNSTABLE/HAS_HOOKS/
# DRAFT are settled verdicts and must not be routed to the undetermined arm.
# REGRESSION GUARD: is_mergeable_undetermined reduces to
# [ "$1" != "MERGEABLE" ] today, false for this pair, so it already confirms
# and already exits 0 -- must stay green after the fix widens the predicate to
# reject ONLY UNKNOWN.

PRECHECK_MERGEABLE_BLOCKED='{"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED"}'
POLL_MERGEABLE_BLOCKED_GREEN='{"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"}]}'

GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_BLOCKED"
GH_MOCK_POLL_BODY="$POLL_MERGEABLE_BLOCKED_GREEN"
GH_MOCK_POLL_SEQUENCE_FILE=""
GH_MOCK_POLL_COUNTER_FILE=""
CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 42

assert_true "AC-SETTLED-NONCLEAN-CONFIRMS: exit code is 0 (a settled non-CLEAN mergeStateStatus still confirms, invariance guard)" \
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
