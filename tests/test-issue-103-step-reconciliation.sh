#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-step-reconciliation.sh
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
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
