#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-step-reconciliation.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: step reconciliation — a well-shaped CI guard that evaluates false at
#       run time is a red run, not a green one — Issue #103,
#       AC-ci-skip-reconciliation
# =============================================================================
# .autoflow/issue-103-verification-design.md:
#   check-step-reconciliation.sh exits non-zero when any selected suite's
#   step outcome is 'skipped' or when an unselected suite's step ran.
#   Governed-set boundary arm: a synthetic outcome map that also contains
#   ungoverned steps (standing-lint steps, the registry-runner step) must
#   reconcile as 0. Complementary arm: a governed suite absent from the
#   outcome map entirely (the missing-id case) -> non-zero.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RECONCILE="$PROJECT_ROOT/scripts/test/check-step-reconciliation.sh"
SELECT="$PROJECT_ROOT/scripts/test/select-suites.sh"

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

echo "=== Issue #103 — AC-ci-skip-reconciliation: check-step-reconciliation.sh ==="

assert_true "scripts/test/check-step-reconciliation.sh exists" "[ -f '$RECONCILE' ]"

if [ -f "$RECONCILE" ]; then
  assert_true "check-step-reconciliation.sh --self-test exits 0" \
    "bash '$RECONCILE' --self-test >/tmp/issue103-reconcile-selftest.out 2>&1"

  # -- A selected suite marked skipped -> non-zero --------------------------
  SELECTED_FILE="$(mktemp)"; STEPS_FILE="$(mktemp)"
  printf 'SELECTED: tests/test-fixture-a.sh\n' > "$SELECTED_FILE"
  cat > "$STEPS_FILE" <<'JSON'
{"s-test-fixture-a": {"outcome": "skipped"}}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-skipped.out 2>&1
  assert_true "a selected suite marked skipped drives the reconciler to non-zero exit" "[ $? -ne 0 ]"

  # -- An unselected suite marked success -> non-zero ------------------------
  printf 'NOT-SELECTED: tests/test-fixture-a.sh no delta match\n' > "$SELECTED_FILE"
  cat > "$STEPS_FILE" <<'JSON'
{"s-test-fixture-a": {"outcome": "success"}}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-unselected-ran.out 2>&1
  assert_true "an unselected suite marked success (ran while unselected) drives the reconciler to non-zero exit" "[ $? -ne 0 ]"

  # -- Agreement -> 0 --------------------------------------------------------
  printf 'SELECTED: tests/test-fixture-a.sh\n' > "$SELECTED_FILE"
  cat > "$STEPS_FILE" <<'JSON'
{"s-test-fixture-a": {"outcome": "success"}}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-agree.out 2>&1
  assert_true "a selected suite that ran successfully reconciles as agreement (exit 0)" "[ $? -eq 0 ]"

  # ---------------------------------------------------------------------
  # GATE:QUALITY F1 (mock-boundary fidelity, ledger O7): the arms above build
  # a SELECTED report matching exactly the outcome map's own suites -- a
  # shape strictly more favourable than production, where select-suites.sh's
  # SELECTED report is TREE-WIDE (63 suites) but toJSON(steps) is JOB-LOCAL
  # (only that one workflow's steps). Every umbrella/single-suite workflow
  # invokes the reconciler this way, so a suite hosted in a DIFFERENT
  # workflow resolves to outcome=absent unless the reconciled set is
  # narrowed to this job's own hosts, and every job reds on every run
  # without that narrowing.
  #
  # SPLIT FIXTURE (issue-103-f1-green-blocker.md): a single shared fixture
  # driven once with no flag (expect rc==0) and once with --governed naming
  # its own three keys (expect rc!=0) is mutually unsatisfiable -- set
  # equality between the derived governed set and the explicit one forces
  # identical verdicts, so no correct derivation can pass BOTH the no-flag
  # arm's rc==0 and the --governed arm's rc!=0 on the same map. The escape
  # that would separate them ("when the report holds both a resolved and an
  # unresolved entry, reconcile nothing") makes the reconciler inert on
  # every real run (contract-suites hosts 39 of 63 selected suites,
  # e2e-dummy-target 22 of 63) and is rejected on that ground.
  #
  # Chosen repair: option (b), split into two independently-falsifiable
  # fixtures, each isolating one property --
  #   arm (a) — no-flag, cross-workflow-only: a SELECTED set naming one
  #     suite hosted here (success) and one hosted ELSEWHERE (absent from
  #     this job's map) -- the derivation-based narrowing must resolve
  #     cleanly (rc==0), and must not report the elsewhere suite. This is
  #     F1 itself, isolated from any genuine mismatch.
  #   arm (b)/(c) — explicit --governed, job-local mismatches: unchanged
  #     three-suite fixture, still proving skip/ran detection survives
  #     narrowing.
  # A genuine no-flag mismatch (a real job-local suite skipped, no flag) is
  # independently covered by the "a selected suite marked skipped" arm
  # above (:47-53) -- so splitting out the mismatch cases here loses no
  # falsifiability at the no-flag level; each arm keeps exactly one crisp,
  # independently-breakable claim.
  # ---------------------------------------------------------------------

  # -- Arm (a), F1 itself: no --governed flag (the real, unwired invocation
  #    shape every workflow uses today) -- a suite hosted in ANOTHER
  #    workflow must not red this job.
  cat > "$SELECTED_FILE" <<'SEL'
SELECTED: tests/test-fixture-here-a.sh
SELECTED: tests/test-fixture-elsewhere.sh
SEL
  cat > "$STEPS_FILE" <<'JSON'
{"s-test-fixture-here-a": {"outcome": "success"}}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-f1-unwired.out 2>&1
  f1_unwired_exit=$?
  assert_true "GATE:QUALITY F1: the real (unwired) invocation shape -- a tree-wide SELECTED report against a job-local outcome map, no --governed -- must not red on a suite hosted in another workflow (tests/test-fixture-elsewhere.sh); this suite's own outcome (success) still reconciles" \
    "[ $f1_unwired_exit -eq 0 ] && ! grep -qF 'test-fixture-elsewhere.sh' /tmp/issue103-reconcile-f1-unwired.out"

  # -- Arms (b)/(c), the fix shape: a fixture with a genuine cross-workflow
  #    suite PLUS two genuine job-local mismatches, narrowed via --governed
  #    to exactly this job's own hosted suites (what the workflow wiring
  #    passes per hosted suite). Proves the reconciler script is not at
  #    fault -- narrowing to the real governed set both admits the
  #    cross-workflow suite AND still catches a real skip/ran mismatch in
  #    the same run.
  cat > "$SELECTED_FILE" <<'SEL'
SELECTED: tests/test-fixture-here-a.sh
SELECTED: tests/test-fixture-elsewhere.sh
SELECTED: tests/test-fixture-here-skip.sh
NOT-SELECTED: tests/test-fixture-here-ran.sh no delta match
SEL
  cat > "$STEPS_FILE" <<'JSON'
{
  "s-test-fixture-here-a": {"outcome": "success"},
  "s-test-fixture-here-skip": {"outcome": "skipped"},
  "s-test-fixture-here-ran": {"outcome": "success"}
}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" \
    --governed tests/test-fixture-here-a.sh \
    --governed tests/test-fixture-here-skip.sh \
    --governed tests/test-fixture-here-ran.sh \
    >/tmp/issue103-reconcile-f1-wired.out 2>&1
  f1_wired_exit=$?
  assert_true "GATE:QUALITY F1 fix shape: with --governed narrowed to this job's own hosted suites, arm (a) (cross-workflow suite) does NOT red, arm (b) (hosted here, selected, skipped) DOES red, and arm (c) (hosted here, unselected but ran) DOES red -- all in the same run" \
    "[ $f1_wired_exit -ne 0 ] && ! grep -qF 'test-fixture-elsewhere.sh' /tmp/issue103-reconcile-f1-wired.out && grep -qF 'test-fixture-here-skip.sh' /tmp/issue103-reconcile-f1-wired.out && grep -qF 'test-fixture-here-ran.sh' /tmp/issue103-reconcile-f1-wired.out && ! grep -qF 'test-fixture-here-a.sh' /tmp/issue103-reconcile-f1-wired.out"

  # -- Governed-set boundary: ungoverned steps in the outcome map reconcile
  #    as 0, not as 'ran while unselected'.
  printf 'SELECTED: tests/test-fixture-a.sh\n' > "$SELECTED_FILE"
  cat > "$STEPS_FILE" <<'JSON'
{
  "s-test-fixture-a": {"outcome": "success"},
  "check-suite-ci-coverage": {"outcome": "success"},
  "run-doc-invariants": {"outcome": "success"}
}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" --governed tests/test-fixture-a.sh >/tmp/issue103-reconcile-ungoverned.out 2>&1
  assert_true "governed-set boundary: standing-lint/registry-runner steps present in the outcome map but outside the governed set reconcile as agreement" \
    "[ $? -eq 0 ]"

  # -- Complementary arm: a governed suite absent from the outcome map
  #    entirely (the missing-id case) -> non-zero, silence is not agreement.
  printf 'SELECTED: tests/test-fixture-a.sh\n' > "$SELECTED_FILE"
  cat > "$STEPS_FILE" <<'JSON'
{}
JSON
  bash "$RECONCILE" --selected "$SELECTED_FILE" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-missing.out 2>&1
  assert_true "a governed selected suite absent from the outcome map entirely (missing-id case) drives the reconciler to non-zero exit" "[ $? -ne 0 ]"

  rm -f "$SELECTED_FILE" "$STEPS_FILE"

  # =========================================================================
  # Issue #103 cycle 2 (review-response) -- AC-reconcile-quiet-under-a-fail-
  # closed-select. .autoflow/issue-103-verification-design.md (cycle 2) §1.
  # A fail-closed select must not turn the reconcile step red for a SECOND,
  # unrelated reason -- the run's single reported cause stays the select
  # step. Driven with the REAL select-suites.sh on a genuinely unresolvable
  # base (not a hand-written BLOCK: line -- verification design §3, "Neither
  # a hand-written BLOCK: line nor a synthesised outcome vocabulary is
  # admitted, because both would encode the assumption the arm exists to
  # test"), fed to the real check-step-reconciliation.sh alongside a steps
  # map in the production job-local shape where every governed step is
  # skipped.
  # =========================================================================
  if [ -f "$SELECT" ]; then
    RECONQ_DIR="$(mktemp -d)"
    mkdir -p "$RECONQ_DIR/tests"
    cat > "$RECONQ_DIR/tests/test-fixture-reconq-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/reconq-subject-a.md
# lane: standing
# budget-secs: 30
true
SH
    git -C "$RECONQ_DIR" init -q >/dev/null 2>&1
    git -C "$RECONQ_DIR" add -A >/dev/null 2>&1
    git -C "$RECONQ_DIR" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
    # Rename off the default branch -- git init's default-branch config
    # otherwise names this checkout's own branch "main", which is a
    # resolvable base and defeats the fixture's premise (same convention as
    # tests/test-issue-103-central-runner.sh's own BLOCK fixture).
    git -C "$RECONQ_DIR" branch -m __no-base-here__ >/dev/null 2>&1

    RECONQ_REPORT="$(mktemp)"
    ( cd "$RECONQ_DIR" && unset GITHUB_BASE_REF; bash "$SELECT" --root "$RECONQ_DIR" --event pull_request >/dev/null 2>"$RECONQ_REPORT" )
    reconq_select_rc=$?
    assert_true "AC-reconcile-quiet-under-a-fail-closed-select: the real select-suites.sh on a genuinely unresolvable base BLOCKs (non-zero exit) and its stderr report carries a BLOCK: line and no SELECTED:/NOT-SELECTED: record" \
      "[ $reconq_select_rc -ne 0 ] && grep -qi 'block' '$RECONQ_REPORT' && ! grep -qE '^(SELECTED|NOT-SELECTED): ' '$RECONQ_REPORT'"

    # Production job-local shape: as if the capture-then-check fix had
    # exited the select step non-zero, so every guarded step's
    # contains(...) expression evaluated false and the step is skipped.
    cat > "$STEPS_FILE" <<'JSON'
{
  "select": {"outcome": "failure"},
  "s-test-fixture-reconq-a": {"outcome": "skipped"}
}
JSON
    bash "$RECONCILE" --selected "$RECONQ_REPORT" --steps "$STEPS_FILE" >/tmp/issue103-reconcile-fail-closed.out 2>&1
    reconq_reconcile_rc=$?
    assert_true "AC-reconcile-quiet-under-a-fail-closed-select: check-step-reconciliation.sh fed the real BLOCK-only report and a job-local steps map with every governed step skipped exits 0 with no MISMATCH line -- the reconcile step must not red for a second, unrelated reason" \
      "[ $reconq_reconcile_rc -eq 0 ] && ! grep -q 'MISMATCH' /tmp/issue103-reconcile-fail-closed.out"

    rm -rf "$RECONQ_DIR"
    rm -f "$RECONQ_REPORT"
  else
    assert_true "AC-reconcile-quiet-under-a-fail-closed-select: scripts/test/select-suites.sh exists (required to drive this arm against the real selector)" "false"
  fi
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
