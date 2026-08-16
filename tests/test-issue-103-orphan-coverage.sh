#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-ci-coverage.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: no suite orphaned by the sibling-invocation removals; the coverage
#       lint's reachability clause is narrowed to a direct run: step and its
#       own header is corrected — Issue #103, AC-no-orphan-after-removal
# =============================================================================
# .autoflow/issue-103-verification-design.md, AC-no-orphan-after-removal:
#   `bash scripts/test/check-suite-ci-coverage.sh` (self-test then real tree)
#   exits 0 on the post-change tree, plus a fixture drive where a callee is
#   de-linked without CI registration -> FAIL. The only file without its own
#   run: step is tests/issue-59-full-sweep-driver.sh, already a named
#   exclusion; the header's stale REACHABLE-paragraph naming of
#   test-issue-40-hook-additive.sh must be corrected in the same change, since
#   that suite already carries a direct run: step
#   (.github/workflows/contract-suites.yml:268-269) and the transitive-closure
#   clause protects nothing.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"

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

echo "=== Issue #103 — AC-no-orphan-after-removal: check-suite-ci-coverage.sh (post-change) ==="

assert_true "check-suite-ci-coverage.sh --self-test exits 0" \
  "bash '$LINT' --self-test >/tmp/issue103-coverage-selftest.out 2>&1"

bash "$LINT" >/tmp/issue103-coverage-real.out 2>&1
COVERAGE_REAL_RC=$?
if [ "$COVERAGE_REAL_RC" -ne 0 ]; then
  echo "  ---- check-suite-ci-coverage.sh real-tree output (rc=$COVERAGE_REAL_RC) ----"
  cat /tmp/issue103-coverage-real.out
  echo "  ---- end output ----"
fi
assert_true "check-suite-ci-coverage.sh exits 0 on the post-change real tree (no orphan introduced by the sibling-invocation removals or the driver deletion)" \
  "[ $COVERAGE_REAL_RC -eq 0 ]"

assert_true "issue-59-full-sweep-driver.sh is deleted (§2.3, superseded by run-suites.sh --all)" \
  "[ ! -f '$PROJECT_ROOT/tests/issue-59-full-sweep-driver.sh' ]"

assert_true "the driver's named exclusion is removed from check-suite-ci-coverage.sh's is_excluded (it no longer needs one — there is no file left to exclude)" \
  "! grep -qF 'issue-59-full-sweep-driver.sh' '$LINT'"

assert_true "the coverage lint's stale REACHABLE-paragraph header no longer names test-issue-40-hook-additive.sh as the transitive-closure instance (that suite carries its own direct run: step)" \
  "! grep -q 'test-issue-40-hook-additive\.sh' <(sed -n '1,40p' '$LINT')"

assert_true "the reachability clause is narrowed to a direct run: step (the header no longer advertises a transitive-closure protection that protects nothing)" \
  "! grep -qi 'transitive closure' <(sed -n '1,40p' '$LINT') || grep -qi 'direct.*run:.*step' <(sed -n '1,40p' '$LINT')"

# -- Fixture drive: a callee de-linked from every workflow, without CI
#    registration, is reported as an orphan (the real defect this lint exists
#    to catch — not merely the self-test's own closure leg).
FIXTURE_DIR="$(mktemp -d)"
mkdir -p "$FIXTURE_DIR/.github/workflows" "$FIXTURE_DIR/tests"
cat > "$FIXTURE_DIR/.github/workflows/fixture-orphan-drive.yml" <<'YML'
name: fixture
on: [push]
jobs:
  fixture:
    runs-on: ubuntu-latest
    steps:
      - run: bash tests/test-fixture-103-still-wired.sh
YML
echo 'true' > "$FIXTURE_DIR/tests/test-fixture-103-still-wired.sh"
echo 'true' > "$FIXTURE_DIR/tests/test-fixture-103-delinked-callee.sh"
bash "$LINT" --root "$FIXTURE_DIR" >/tmp/issue103-coverage-delinked.out 2>&1
delinked_exit=$?
assert_true "a callee de-linked from every workflow, without a CI run: step, is reported as an orphan" \
  "[ $delinked_exit -ne 0 ] && grep -qF 'test-fixture-103-delinked-callee.sh' /tmp/issue103-coverage-delinked.out"
rm -rf "$FIXTURE_DIR"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
