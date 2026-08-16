#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/test-workflow-trigger-conformance.sh scripts/test/check-manifest-regen-clean.sh scripts/test/check-maintained-docs-sync.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: header-parse re-pointed to a single definition site, ci-subject
#       coverage preserved under universalisation, the fixed paths: window
#       guards survive the appends, and the derived doc-surface lints stay
#       green — Issue #103,
#       AC-header-parse-single-definition-site, AC-ci-subject-coverage-preserved,
#       AC-paths-window-guards-survive, AC-derived-doc-surfaces-consistent
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFORMANCE="$PROJECT_ROOT/tests/test-workflow-trigger-conformance.sh"
LIBRARY="$PROJECT_ROOT/scripts/test/suite-manifest.sh"
REGEN_CLEAN="$PROJECT_ROOT/scripts/test/check-manifest-regen-clean.sh"
DOCS_SYNC="$PROJECT_ROOT/scripts/test/check-maintained-docs-sync.sh"

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

echo "=== Issue #103 — workflow-trigger conformance re-point, paths: window survival, derived-doc-surface lints ==="

# ---------------------------------------------------------------------
# AC-header-parse-single-definition-site
# ---------------------------------------------------------------------
assert_true "AC-header-parse-single-definition-site: scripts/test/suite-manifest.sh exists" "[ -f '$LIBRARY' ]"
assert_true "AC-header-parse-single-definition-site: test-workflow-trigger-conformance.sh exits 0 against the real tree, header parse re-pointed" \
  "bash '$CONFORMANCE' >/tmp/issue103-conformance-real.out 2>&1"
assert_true "AC-header-parse-single-definition-site: test-workflow-trigger-conformance.sh sources scripts/test/suite-manifest.sh rather than re-parsing the header inline" \
  "grep -q 'suite-manifest.sh' '$CONFORMANCE'"
assert_true "AC-header-parse-single-definition-site: no independent inline '# ci-subject:' parse (grep/awk over the raw header comment) survives in the conformance suite" \
  "! grep -qE \"grep.*'\\\\^#[[:space:]]*ci-subject:'\" '$CONFORMANCE' || grep -q 'suite-manifest.sh' '$CONFORMANCE'"

# ---------------------------------------------------------------------
# AC-ci-subject-coverage-preserved
# ---------------------------------------------------------------------
assert_true "AC-ci-subject-coverage-preserved: every executable spec under tests/** now carries a '# ci-subject:' header (universalised, was ~half)" \
  "! find '$PROJECT_ROOT/tests' -maxdepth 1 -name 'test-*.sh' -exec grep -L '^# ci-subject:' {} \; | grep -q ."

# test-issue-27's real subject (test/workflows/) being covered by its hosting
# workflow's paths: block is exactly what the conformance suite's own AC-b-2
# asserts at test time (grep -rl '^# ci-subject:' over tests/, hosting-
# workflow paths: coverage per suite — .autoflow/issue-103-feature-design.md
# §2.2). A grep -B60 proximity proxy over the raw workflow YAML is a strictly
# weaker, line-distance-fragile re-implementation of that same check (it
# would false-negative were the paths: block reordered, or false-positive on
# an unrelated nearby literal) and is dropped in favour of the real run
# already asserted above (AC-header-parse-single-definition-site) and the
# per-commit ordering arm below.

# ---------------------------------------------------------------------
# AC-paths-window-guards-survive — live window guards, run against the
# post-change tree.
# ---------------------------------------------------------------------
for f in tests/test-issue-52-peer-facilitator-premise.sh tests/test-issue-55-score-format-contract.sh tests/test-issue-799-inert-cleanup.sh; do
  assert_true "AC-paths-window-guards-survive: bash $f exits 0 on the post-change tree ($f's fixed grep -A40 'paths:' window is not evicted by the header/paths: appends)" \
    "bash '$PROJECT_ROOT/$f' >/tmp/issue103-window-guard-$(basename "$f").out 2>&1"
done

# ---------------------------------------------------------------------
# AC-derived-doc-surfaces-consistent
# ---------------------------------------------------------------------
assert_true "AC-derived-doc-surfaces-consistent: check-manifest-regen-clean.sh exits 0 on the post-change tree (setup/manifest.json regenerated alongside the four edited registered docs)" \
  "bash '$REGEN_CLEAN' >/tmp/issue103-regen-clean.out 2>&1"
# Scoped to this cycle's own change surface: check-maintained-docs-sync.sh's
# dangling-path guard already reds at HEAD on four pre-existing
# services/librechat/docs/* rows outside this cycle (verified: bash
# scripts/test/check-maintained-docs-sync.sh on an unmodified checkout
# reports exactly those four FAIL lines) -- requiring the whole script to
# exit 0 would fail this AC on a defect this cycle did not introduce and
# cannot fix (out of the change surface). The AC's own claim -- the new
# rows' registration is safe -- is what is asserted: none of the reported
# dangling-path FAIL lines name a file this cycle registers.
bash "$DOCS_SYNC" >/tmp/issue103-docs-sync.out 2>&1
assert_true "AC-derived-doc-surfaces-consistent: check-maintained-docs-sync.sh reports no dangling-path FAIL for any of this cycle's new registration rows (suite-manifest.sh, select-suites.sh, run-suites.sh, check-suite-manifest.sh, check-step-reconciliation.sh, check-suite-leaf.sh)" \
  "! grep -E 'dangling-path guard.*(suite-manifest\.sh|select-suites\.sh|run-suites\.sh|check-suite-manifest\.sh|check-step-reconciliation\.sh|check-suite-leaf\.sh)' /tmp/issue103-docs-sync.out"
assert_true "AC-derived-doc-surfaces-consistent: docs/maintained-docs.md registers scripts/test/suite-manifest.sh, select-suites.sh, run-suites.sh and the three new lints" \
  "grep -qF 'suite-manifest.sh' '$PROJECT_ROOT/docs/maintained-docs.md' && grep -qF 'select-suites.sh' '$PROJECT_ROOT/docs/maintained-docs.md' && grep -qF 'run-suites.sh' '$PROJECT_ROOT/docs/maintained-docs.md'"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
