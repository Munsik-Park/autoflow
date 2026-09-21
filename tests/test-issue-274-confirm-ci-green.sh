#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/handoff/confirm-ci-green.sh docs/autoflow-guide.md tests/lib/confirm-ci-green-harness.sh
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: HANDOFF step-5 CI-green confirm helper — superseded cancelled run, Issue #274
# =============================================================================
# #30 dedups a stale CANCELLED against a same-identity (workflowName, name)
# replacement. It leaves alone a cancelled check whose NAME the replacement run
# never repeats: GitHub Actions does not expand the matrix of a run cancelled
# before it starts, so the cancelled run keeps "Tests: api (shard ${{ matrix.shard }})"
# while the replacement expands to "Tests: api (shard 1)"… That row sits alone
# in its identity group and was counted red — exit 12 on a head SHA whose
# replacement run is green (connev-llm/LibreChat PR 479; llmroute #607 / #630).
#
# The fix drops a CANCELLED CheckRun of a run superseded by a newer run of the
# same workflow, the run read from detailsUrl and the workflow resolved to its
# workflow_id through the Actions run API — never the workflowName display name,
# which two workflow files may share (PR #285 review, Medium 1). This suite pins
# that, the cases that must stay red, and the lookup's own contract: narrowed to
# the candidate runs, cached, and on failure delaying green without granting it
# or turning red. The lookup is answered by the mock's `gh api` arm
# (GH_MOCK_RUN_WORKFLOWS, tests/issue-25/mock-gh/gh). The unresolved-lookup
# case of exit 13 is named on stderr and in docs/autoflow-guide.md HANDOFF step 5
# (PR #285 review, Low 1), which AC-274-7 pins.
#
# Fixtures carry the real `gh pr view --json statusCheckRollup` CheckRun shape:
# the eight keys gh exports (cli/cli api/export_pr.go, the statusCheckRollup
# case), detailsUrl in the .../actions/runs/<run_id>/job/<job_id> form, and an
# in-progress / queued row as gh renders it — conclusion "" and a zero time
# "0001-01-01T00:00:00Z" (gh's Conclusion is a string type and StartedAt /
# CompletedAt are time.Time, cli/cli api/queries_pr.go CheckContext). Run and
# job ids, names and timestamps are the observed ones: cancelled run
# 35517948721 attempt 1 and replacement run 35517992531, workflow
# "Backend Unit Tests", connev-llm/LibreChat; both runs resolve to workflow_id
# 303841190 (.github/workflows/backend-review.yml) through
# `gh api repos/connev-llm/LibreChat/actions/runs/<id>`.
#
# The same-identity behaviour of #30 is tests/test-issue-30-confirm-ci-green.sh's
# subject and is not re-run here (suite leaf rule).
#
# Self-guard (SIGPIPE-safe pipes, docs/submodule-common-rules.md > Testing
# Standards item 6): every assertion captures its producer into a variable
# before matching.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/handoff/confirm-ci-green.sh"
MOCK_GH_DIR="$PROJECT_ROOT/tests/issue-25/mock-gh"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
LOOKUP_STDERR='superseded-run workflow lookup unresolved'

# Shared harness: run_bounded, run_confirm, PRECHECK_MERGEABLE_CLEAN (issue #122).
# Sourced after SCRIPT and MOCK_GH_DIR, which run_confirm reads.
. "$PROJECT_ROOT/tests/lib/confirm-ci-green-harness.sh"

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

# ---------------------------------------------------------------------------
# Fixture builders — one CheckRun row in gh's exported shape.
#   check_run <workflowName> <name> <status> <conclusion> <startedAt> <completedAt> <run_id> <job_id>
# <conclusion> is the literal string gh exports ("" for a non-terminal row).
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/connev-llm/LibreChat"
ZERO_TIME="0001-01-01T00:00:00Z"
WF="Backend Unit Tests"
RUN_OLD=35517948721
RUN_NEW=35517992531
UNEXPANDED='Tests: api (shard ${{ matrix.shard }})'
WF_ID=303841190
RUN_WFS="$RUN_OLD=$WF_ID $RUN_NEW=$WF_ID"

check_run() {
  jq -cn --arg w "$1" --arg n "$2" --arg s "$3" --arg c "$4" \
    --arg st "$5" --arg ct "$6" --arg u "$REPO_URL/actions/runs/$7/job/$8" \
    '{__typename:"CheckRun",completedAt:$ct,conclusion:$c,detailsUrl:$u,name:$n,startedAt:$st,status:$s,workflowName:$w}'
}

# rollup_body <row>... -> a MERGEABLE/CLEAN poll body carrying the rows in order.
rollup_body() {
  local rows
  rows="$(printf '%s\n' "$@" | jq -cs '.')"
  jq -cn --argjson r "$rows" '{mergeable:"MERGEABLE",mergeStateStatus:"CLEAN",statusCheckRollup:$r}'
}

# The cancelled run (attempt 1): every job CANCELLED, the api matrix unexpanded.
OLD_BUILD="$(check_run "$WF" "Build packages" COMPLETED CANCELLED 2026-09-20T14:55:14Z 2026-09-20T14:56:11Z $RUN_OLD 106096953312)"
OLD_MATRIX="$(check_run "$WF" "$UNEXPANDED" COMPLETED CANCELLED 2026-09-20T14:56:12Z 2026-09-20T14:56:11Z $RUN_OLD 106097082507)"
# The replacement run.
NEW_BUILD="$(check_run "$WF" "Build packages" COMPLETED SUCCESS 2026-09-20T14:56:30Z 2026-09-20T14:57:43Z $RUN_NEW 106102307867)"
NEW_SHARD1="$(check_run "$WF" "Tests: api (shard 1)" COMPLETED SUCCESS 2026-09-20T15:01:47Z 2026-09-20T15:05:27Z $RUN_NEW 106102295913)"
NEW_SHARD2="$(check_run "$WF" "Tests: api (shard 2)" COMPLETED SUCCESS 2026-09-20T15:04:52Z 2026-09-20T15:07:30Z $RUN_NEW 106102312879)"
NEW_SHARD1_RUNNING="$(check_run "$WF" "Tests: api (shard 1)" IN_PROGRESS "" 2026-09-20T15:01:47Z "$ZERO_TIME" $RUN_NEW 106102295913)"
NEW_SHARD2_QUEUED="$(check_run "$WF" "Tests: api (shard 2)" QUEUED "" "$ZERO_TIME" "$ZERO_TIME" $RUN_NEW 106102312879)"
NEW_SHARD2_FAILED="$(check_run "$WF" "Tests: api (shard 2)" COMPLETED FAILURE 2026-09-20T15:04:52Z 2026-09-20T15:07:30Z $RUN_NEW 106102312879)"

# run_poll <body> [<run_workflows>] — one confirm-ci-green run against a fixed poll
# body; exits on the first poll for a terminal verdict. <run_workflows> is the
# mock's run -> workflow_id map (default: both observed runs -> WF_ID). The gh
# invocation log is kept in API_CALLS as the `gh api` lines only.
run_poll() {
  GH_INVOCATION_LOG="$(mktemp)"
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
  GH_MOCK_POLL_BODY="$1"
  GH_MOCK_POLL_SEQUENCE_FILE=""
  GH_MOCK_POLL_COUNTER_FILE=""
  GH_MOCK_RUN_WORKFLOWS="${2-$RUN_WFS}"
  CI_POLL_TIMEOUT_SECS=5 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 479
  API_CALLS="$(grep '^api ' "$GH_INVOCATION_LOG" || true)"
  rm -f "$GH_INVOCATION_LOG"
}

# count_lines <text> -> number of non-empty lines.
count_lines() { printf '%s' "$1" | grep -c . || true; }

echo "=============================================="
echo "confirm-ci-green.sh superseded cancelled run (HANDOFF step-5, issue #274)"
echo "=============================================="

# =============================================================================
echo ""
echo "=== AC-274-5 (fixtures carry the real rollup shape) ==="

FIXTURE_KEYS="$(printf '%s' "$OLD_MATRIX" | jq -r 'keys_unsorted | join(",")')"
assert_true "AC-274-5: a fixture row carries exactly gh's eight exported CheckRun keys" \
  "[ \"\$FIXTURE_KEYS\" = '__typename,completedAt,conclusion,detailsUrl,name,startedAt,status,workflowName' ]"
FIXTURE_URL="$(printf '%s' "$OLD_MATRIX" | jq -r '.detailsUrl')"
assert_true "AC-274-5: detailsUrl has the .../actions/runs/<run_id>/job/<job_id> form" \
  "[ \"\$FIXTURE_URL\" = '$REPO_URL/actions/runs/$RUN_OLD/job/106097082507' ]"
FIXTURE_NAME="$(printf '%s' "$OLD_MATRIX" | jq -r '.name')"
assert_true "AC-274-5: the cancelled matrix row keeps the unexpanded name" \
  "[ \"\$FIXTURE_NAME\" = \"\$UNEXPANDED\" ]"
FIXTURE_RUNNING="$(printf '%s' "$NEW_SHARD1_RUNNING" | jq -r '[.conclusion, .completedAt] | join("|")')"
assert_true "AC-274-5: an in-progress row is rendered as gh renders it (conclusion \"\", zero completedAt)" \
  "[ \"\$FIXTURE_RUNNING\" = '|$ZERO_TIME' ]"

# =============================================================================
echo ""
echo "=== AC-274-1 (primary kill — issue repro: unmatched cancelled matrix row beside a green replacement -> exit 0) ==="

AC1_BODY="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$NEW_BUILD" "$NEW_SHARD1")"
run_poll "$AC1_BODY"
assert_true "AC-274-1: superseded run's CANCELLED rows (incl. the unexpanded matrix name) do not count -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_false "AC-274-1: exit code is NOT 12 (the false red this issue reports)" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
AC1_API_OLD="$(count_lines "$(printf '%s\n' "$API_CALLS" | grep -F "repos/connev-llm/LibreChat/actions/runs/$RUN_OLD " || true)")"
AC1_API_NEW="$(count_lines "$(printf '%s\n' "$API_CALLS" | grep -F "repos/connev-llm/LibreChat/actions/runs/$RUN_NEW " || true)")"
assert_true "AC-274-1: the workflow of both candidate runs is looked up on the check's own host and repository" \
  "[ \"\$AC1_API_OLD\" -eq 1 ] && [ \"\$AC1_API_NEW\" -eq 1 ] && printf '%s' \"\$API_CALLS\" | grep -qF -- '--hostname github.com'"

AC1_REVERSED="$(rollup_body "$NEW_SHARD1" "$NEW_BUILD" "$OLD_MATRIX" "$OLD_BUILD")"
run_poll "$AC1_REVERSED"
assert_true "AC-274-1: order-independent — the same rows reversed still exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"

# The unmatched row alone, no same-name pair at all: the #30 dedup has nothing to
# act on, so only the run-level supersession can clear it.
AC1_UNPAIRED="$(rollup_body "$OLD_MATRIX" "$NEW_SHARD1" "$NEW_SHARD2")"
run_poll "$AC1_UNPAIRED"
assert_true "AC-274-1: a superseded run whose every row is unmatched by name still exits 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-274-1 (replacement still running -> keeps polling, not exit 12) ==="

AC1_RUNNING="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$NEW_BUILD" "$NEW_SHARD1_RUNNING" "$NEW_SHARD2_QUEUED")"
AC1_LOG="$(mktemp)"
run_bounded 8 "$AC1_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC1_RUNNING" \
  GH_MOCK_RUN_WORKFLOWS="$RUN_WFS" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 479
assert_true "AC-274-1 (running): outer watchdog never fired (script self-terminated)" \
  "[ \"\$RB_KILLED\" -eq 0 ]"
assert_true "AC-274-1 (running): a replacement still in progress stays pending to the deadline -> exit 13" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
assert_false "AC-274-1 (running): exit code is NOT 12 on the first poll" \
  "[ \"\$RB_EXIT\" -eq 12 ]"
AC1_OUT="$(cat "$AC1_LOG")"
assert_false "AC-274-1 (running): a resolved lookup adds no unresolved-lookup stderr line to exit 13" \
  "printf '%s' \"\$AC1_OUT\" | grep -qF \"\$LOOKUP_STDERR\""
rm -f "$AC1_LOG"

# Poll sequence: running on the first read, complete on the second -> exit 0.
AC1_SEQ="$(mktemp)"; AC1_COUNTER="$(mktemp)"
printf '%s\n%s\n' "$AC1_RUNNING" "$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$NEW_BUILD" "$NEW_SHARD1" "$NEW_SHARD2")" >"$AC1_SEQ"
printf '0' >"$AC1_COUNTER"
GH_INVOCATION_LOG="$(mktemp)"
GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN"
GH_MOCK_POLL_BODY=""
GH_MOCK_POLL_SEQUENCE_FILE="$AC1_SEQ"
GH_MOCK_POLL_COUNTER_FILE="$AC1_COUNTER"
GH_MOCK_RUN_WORKFLOWS="$RUN_WFS"
CI_POLL_TIMEOUT_SECS=10 CI_POLL_INTERVAL_SECS=1 run_confirm --pr 479
AC1_POLLS="$(cat "$AC1_COUNTER")"
AC1_SEQ_API="$(count_lines "$(grep '^api ' "$GH_INVOCATION_LOG" || true)")"
assert_true "AC-274-1 (running -> done): the poll continues past the running read and exits 0 once the replacement completes" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
assert_true "AC-274-1 (running -> done): exit 0 came on the second poll, not the first" \
  "[ \"\$AC1_POLLS\" -eq 2 ]"
assert_true "AC-274-1 (running -> done): each run's workflow is looked up once across both polls (cached)" \
  "[ \"\$AC1_SEQ_API\" -eq 2 ]"
rm -f "$AC1_SEQ" "$AC1_COUNTER" "$GH_INVOCATION_LOG"
GH_MOCK_POLL_SEQUENCE_FILE=""; GH_MOCK_POLL_COUNTER_FILE=""

# =============================================================================
echo ""
echo "=== AC-274-2 (CANCELLED with no replacement run stays red -> exit 12) ==="

AC2_ALONE="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX")"
run_poll "$AC2_ALONE"
assert_true "AC-274-2: a cancelled run with no newer run of its workflow -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# A newer run of a DIFFERENT workflow does not supersede it.
OTHER_WF_NEW="$(check_run "Frontend Unit Tests" "Build" COMPLETED SUCCESS 2026-09-20T14:56:30Z 2026-09-20T14:58:00Z 35517992600 106102309999)"
AC2_OTHER_WF="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$OTHER_WF_NEW")"
run_poll "$AC2_OTHER_WF"
assert_true "AC-274-2: a newer run of another workflow does not supersede the cancelled run -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# The workflow's NEWEST run carrying a CANCELLED row is not superseded.
NEW_SHARD2_CANCELLED="$(check_run "$WF" "Tests: api (shard 2)" COMPLETED CANCELLED 2026-09-20T15:04:52Z 2026-09-20T15:07:30Z $RUN_NEW 106102312879)"
AC2_NEWEST="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$NEW_BUILD" "$NEW_SHARD1" "$NEW_SHARD2_CANCELLED")"
run_poll "$AC2_NEWEST"
assert_true "AC-274-2: a CANCELLED row of the workflow's newest run stays red -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# A CANCELLED check whose run cannot be read from detailsUrl (not an Actions run).
EXTERNAL_CANCELLED="$(jq -cn '{__typename:"CheckRun",completedAt:"2026-09-20T14:56:11Z",conclusion:"CANCELLED",detailsUrl:"https://ci.example.com/build/881",name:"external-ci",startedAt:"2026-09-20T14:55:14Z",status:"COMPLETED",workflowName:""}')"
AC2_EXTERNAL="$(rollup_body "$EXTERNAL_CANCELLED" "$NEW_BUILD" "$NEW_SHARD1")"
run_poll "$AC2_EXTERNAL"
assert_true "AC-274-2: a CANCELLED check with no Actions run in detailsUrl stays red -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# Two workflow files sharing one display name (PR #285 review, Medium 1): the
# cancelled run of workflow A is not superseded by a newer run of workflow B,
# although both carry workflowName "CI" and no job name is shared.
SHARED_A_OLD="$(check_run "CI" "workflow-a-only-job" COMPLETED CANCELLED 2026-09-20T14:55:14Z 2026-09-20T14:56:11Z 35517948800 106096960001)"
SHARED_B_NEW="$(check_run "CI" "workflow-b-only-job" COMPLETED SUCCESS 2026-09-20T14:56:30Z 2026-09-20T14:58:00Z 35517948801 106096960002)"
SHARED_A_NEW="$(check_run "CI" "workflow-a-only-job-2" COMPLETED SUCCESS 2026-09-20T14:57:00Z 2026-09-20T14:59:00Z 35517948802 106096960003)"
SHARED_WFS="35517948800=111 35517948801=222 35517948802=111"
AC2_SHARED="$(rollup_body "$SHARED_A_OLD" "$SHARED_B_NEW")"
run_poll "$AC2_SHARED" "$SHARED_WFS"
assert_true "AC-274-2: a newer run of another workflow with the same display name does not supersede -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"
assert_false "AC-274-2: exit code is NOT 0 (the false green of a display-name key)" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"
# ...while workflow A's own newer run, among them, still supersedes it.
AC2_SHARED_OWN="$(rollup_body "$SHARED_A_OLD" "$SHARED_B_NEW" "$SHARED_A_NEW")"
run_poll "$AC2_SHARED_OWN" "$SHARED_WFS"
assert_true "AC-274-2: the same rollup plus workflow A's own newer run is superseded -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-274-3 (a FAILURE in the replacement run stays red -> exit 12) ==="

AC3_BODY="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX" "$NEW_BUILD" "$NEW_SHARD1" "$NEW_SHARD2_FAILED")"
run_poll "$AC3_BODY"
assert_true "AC-274-3: replacement run with a FAILURE check -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# Only CANCELLED is dropped from a superseded run: its own FAILURE, unmatched by
# name, stays red.
OLD_MATRIX_FAILED="$(check_run "$WF" "$UNEXPANDED" COMPLETED FAILURE 2026-09-20T14:56:12Z 2026-09-20T14:56:40Z $RUN_OLD 106097082507)"
AC3_OLD_FAILURE="$(rollup_body "$OLD_BUILD" "$OLD_MATRIX_FAILED" "$NEW_BUILD" "$NEW_SHARD1")"
run_poll "$AC3_OLD_FAILURE"
assert_true "AC-274-3: a superseded run's own FAILURE row is not dropped -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-274-6 (the workflow lookup: narrowed, and a failed lookup never decides the verdict) ==="

# No candidate: a rollup with no CANCELLED row of a non-newest run issues no call.
AC6_NO_CANDIDATE="$(rollup_body "$NEW_BUILD" "$NEW_SHARD1" "$NEW_SHARD2")"
run_poll "$AC6_NO_CANDIDATE"
AC6_NONE="$(count_lines "$API_CALLS")"
assert_true "AC-274-6: a rollup with no superseded-run candidate is green without any gh api call -> exit 0" \
  "[ \"\$RUN_EXIT\" -eq 0 ] && [ \"\$AC6_NONE\" -eq 0 ]"

# Failed lookup on the issue repro: neither the false red nor a green verdict;
# the poll runs to the deadline.
AC6_LOG="$(mktemp)"
run_bounded 8 "$AC6_LOG" env PATH="$MOCK_GH_DIR:$PATH" \
  GH_MOCK_PRECHECK_BODY="$PRECHECK_MERGEABLE_CLEAN" \
  GH_MOCK_POLL_BODY="$AC1_BODY" \
  GH_MOCK_RUN_WORKFLOWS="" \
  CI_POLL_TIMEOUT_SECS=2 CI_POLL_INTERVAL_SECS=1 \
  bash "$SCRIPT" --pr 479
assert_true "AC-274-6: a failed lookup withholds green and does not turn red -> exit 13 at the deadline" \
  "[ \"\$RB_KILLED\" -eq 0 ] && [ \"\$RB_EXIT\" -eq 13 ]"
AC6_OUT="$(cat "$AC6_LOG")"
assert_true "AC-274-6: exit 13 names the unresolved lookup on stderr and points at actions: read" \
  "printf '%s' \"\$AC6_OUT\" | grep -qF \"\$LOOKUP_STDERR\" && printf '%s' \"\$AC6_OUT\" | grep -qF 'actions: read'"
rm -f "$AC6_LOG"

# Failed lookup beside a genuine FAILURE: still red.
run_poll "$AC3_BODY" ""
assert_true "AC-274-6: a failed lookup does not mask a FAILURE in the replacement run -> exit 12" \
  "[ \"\$RUN_EXIT\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-274-7 (HANDOFF step 5 exit-code contract names the superseded-run behaviour) ==="

# The `12` and `13` bullets of docs/autoflow-guide.md HANDOFF step 5, the
# operator's source of truth for this script's exit codes.
STEP5_12="$(grep -E '^   - `12` — ' "$AUTOFLOW_GUIDE" || true)"
STEP5_13="$(grep -E '^   - `13` — ' "$AUTOFLOW_GUIDE" || true)"
assert_true "AC-274-7: the step-5 \`12\` bullet states a superseded run's CANCELLED check is not counted" \
  "printf '%s' \"\$STEP5_12\" | grep -qF 'superseded' && printf '%s' \"\$STEP5_12\" | grep -qF 'workflow_id'"
assert_true "AC-274-7: the step-5 \`13\` bullet lists the unresolved lookup as a case, with its stderr line and actions: read" \
  "printf '%s' \"\$STEP5_13\" | grep -qF \"\$LOOKUP_STDERR\" && printf '%s' \"\$STEP5_13\" | grep -qF 'actions: read'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
