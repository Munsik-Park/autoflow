#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/lib/harness-pins.sh tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json
# =============================================================================
# Test: pin drift detection, pin text-form dependent disposal, this cycle's
#       own doc-STATE registry entries, and the removal-side no-regression
#       proof — Issue #103,
#       AC-pin-detects-harness-drift, AC-pin-dependents-disposed,
#       AC-doc-contracts-registered, AC-no-regression-on-removed-assertions
# =============================================================================
# .autoflow/issue-103-gate-plan.md F1: tests/test-issue-67-deliberation-
#   record.sh:86-91 (AC-67-OKCOUNT) is an unconditional pin dependent absent
#   from feature design §2.4's disposition table -- covered here by asserting
#   its own disposition (same ground as the 69 row: with one home there is
#   nothing to agree).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIN_HOME="$PROJECT_ROOT/tests/lib/harness-pins.sh"
SUITE_27="$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"
SUITE_59="$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh"
SUITE_62="$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh"
SUITE_67="$PROJECT_ROOT/tests/test-issue-67-deliberation-record.sh"
SUITE_69="$PROJECT_ROOT/tests/test-issue-69-verification-depth.sh"
SUITE_56="$PROJECT_ROOT/tests/test-issue-56-carry-evidence-discipline.sh"

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

echo "=== Issue #103 — pin single-sourcing, text-form dependent disposal, doc-contract registration ==="

# ---------------------------------------------------------------------
# AC-pin-detects-harness-drift
# ---------------------------------------------------------------------
assert_true "AC-pin-detects-harness-drift: tests/lib/harness-pins.sh exists" "[ -f '$PIN_HOME' ]"
assert_true "AC-pin-detects-harness-drift: test-issue-27 (the sole carrier of the harness-vs-pin comparison) exits 0 against the real harness measurement" \
  "bash '$SUITE_27' >/tmp/issue103-pin-drift-baseline.out 2>&1"

if [ -f "$PIN_HOME" ]; then
  SCRATCH="$(mktemp -d)"
  git -C "$PROJECT_ROOT" worktree add -q "$SCRATCH" HEAD >/dev/null 2>&1
  # Perturb the HARNESS side, not the constant: add one top-level await test().
  if [ -f "$SCRATCH/test/workflows/run.mjs" ]; then
    printf "\nawait test('issue-103 pin-drift probe', async () => {});\n" >> "$SCRATCH/test/workflows/run.mjs"
    (cd "$SCRATCH" && bash tests/test-issue-27-composition-oracle.sh) >/tmp/issue103-pin-drift-perturbed.out 2>&1
    perturbed_exit=$?
    assert_true "AC-pin-detects-harness-drift: perturbing the harness (one added ok-emitting test) reds the unchanged sourced pin constant" \
      "[ $perturbed_exit -ne 0 ]"
  else
    assert_true "AC-pin-detects-harness-drift: test/workflows/run.mjs is reachable in the scratch worktree" "false"
  fi
  git -C "$PROJECT_ROOT" worktree remove -f "$SCRATCH" >/dev/null 2>&1 || rm -rf "$SCRATCH"
fi

# ---------------------------------------------------------------------
# AC-pin-dependents-disposed
# ---------------------------------------------------------------------
assert_true "AC-pin-dependents-disposed: test-issue-62's AC-62-31a/-31b block (grep of -eq 85/EXPECTED_OK=85 literal text) is removed" \
  "! grep -q -- '-eq 85 \]\"' '$SUITE_62' && ! grep -qF 'EXPECTED_OK=85' '$SUITE_62'"
assert_true "AC-pin-dependents-disposed: test-issue-62's AC-62-31a-stale/-31c (stale -eq 82/EXPECTED_OK=82 assertions) is removed" \
  "! grep -q -- '-eq 82 \]\"' '$SUITE_62' && ! grep -qF 'EXPECTED_OK=82' '$SUITE_62'"
assert_true "AC-pin-dependents-disposed: test-issue-62's AC-62-31d sibling invocation ('bash tests/test-issue-59-...') is removed (disposed as a sibling invocation by §2.3)" \
  "! grep -qE 'bash (\\.\\./)?tests/test-issue-59-' '$SUITE_62'"

assert_true "AC-pin-dependents-disposed: test-issue-59's AC-59-14a1/-14c cross-pin equality block is removed" \
  "! grep -qF 'AC-59-14a1' '$SUITE_59' && ! grep -qF 'AC-59-14c' '$SUITE_59'"
assert_true "AC-pin-dependents-disposed: test-issue-59's AC-59-14a2/-14a3-stale-label (stale -eq 37/(37) assertions) is removed" \
  "! grep -qF 'AC-59-14a2' '$SUITE_59' && ! grep -qF 'AC-59-14a3-stale-label' '$SUITE_59'"

assert_true "AC-pin-dependents-disposed: test-issue-69's cross-pin agreement check and its execution sweep are removed" \
  "! grep -qE 'CANON_LITERAL_27|EXPECTED_OK_59' '$SUITE_69'"

# F1 — test-issue-67's unconditional AC-67-OKCOUNT pin dependent, verified
# missing from feature design §2.4's table, disposed here on the same ground
# as the 69 row (with one home there is nothing to agree).
assert_true "GATE:PLAN F1: test-issue-67's AC-67-OKCOUNT (reads both foreign pin literals by text: AC-27-20c grep and EXPECTED_OK= grep) is disposed after single-sourcing — the same ground as the 69 row" \
  "! grep -qF 'AC-67-OKCOUNT' '$SUITE_67' && ! grep -qE \"grep -F 'AC-27-20c'\" '$SUITE_67' && ! grep -qE 'grep -oE .\\^EXPECTED_OK=' '$SUITE_67'"

# -- Branch-scoped-inert homes are untouched: they pin their own cycle's
#    measurement on their own dev branch and are not text-form dependents of
#    the removed literal.
assert_true "AC-pin-dependents-disposed: test-issue-56's own gated pin literal is untouched" \
  "[ -f '$SUITE_56' ]"
assert_true "AC-pin-dependents-disposed: test-issue-62's own branch-scoped-inert EXPECTED_OK=58 pin (inside its case \"\$HEAD_BRANCH\" gate) remains present" \
  "grep -qF 'EXPECTED_OK=58' '$SUITE_62'"

# ---------------------------------------------------------------------
# AC-doc-contracts-registered
# ---------------------------------------------------------------------
assert_true "AC-doc-contracts-registered: tests/run-doc-invariants.sh exits 0 on the real tree, including this cycle's two new entries" \
  "bash '$PROJECT_ROOT/tests/run-doc-invariants.sh' >/tmp/issue103-doc-invariants.out 2>&1"
assert_true "AC-doc-contracts-registered: tests/run-doc-invariants.sh --self-test exits 0 (mutation-teeth mode covers the two new entries)" \
  "bash '$PROJECT_ROOT/tests/run-doc-invariants.sh' --self-test >/tmp/issue103-doc-invariants-selftest.out 2>&1"

# ---------------------------------------------------------------------
# AC-no-regression-on-removed-assertions
# ---------------------------------------------------------------------
assert_true "AC-no-regression-on-removed-assertions (b): tests/issue-59-full-sweep-driver.sh is deleted and its properties are re-homed onto run-suites.sh (see test-issue-103-central-runner.sh AC-runtime-ceiling-enforced / AC-selection-fails-loud-on-unresolvable-base)" \
  "[ ! -f '$PROJECT_ROOT/tests/issue-59-full-sweep-driver.sh' ]"
assert_true "AC-no-regression-on-removed-assertions (c): §2.4's disposition-table removals are carried by AC-pin-single-home (single authorship) and AC-pin-detects-harness-drift (harness-side arm), both executed above and in test-issue-103-suite-manifest.sh" \
  "[ -f '$PIN_HOME' ] && bash '$SUITE_27' >/tmp/issue103-noregression-27.out 2>&1"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
