#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/lib/harness-pins.sh tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: pin drift detection and the removal-side no-regression proof —
#       Issue #103, AC-pin-detects-harness-drift,
#       AC-no-regression-on-removed-assertions
# =============================================================================
# ISSUE #119 REDUCTION. Three groups left this suite; each carries a
# disposition row in docs/doc-invariant-registry.md §14:
#   - the two UNPERTURBED composition-oracle re-invocations (the drift
#     baseline and the AC-no-regression (c) re-run) — owned by
#     .github/workflows/e2e-dummy-target.yml's own
#     tests/test-issue-27-composition-oracle.sh step. The PERTURBED run below
#     stays: it is the operative half of the drift arm, and no other carrier
#     perturbs the harness.
#   - the real-tree tests/run-doc-invariants.sh run and its --self-test —
#     owned by the unconditional steps in e2e-dummy-target.yml and
#     contract-suites.yml.
#   - AC-pin-dependents-disposed's one-shot text pins — each asserted that a
#     past deletion had landed; retired, not re-homed.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIN_HOME="$PROJECT_ROOT/tests/lib/harness-pins.sh"

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

echo "=== Issue #103 — pin drift detection, removal-side no-regression ==="

# ---------------------------------------------------------------------
# AC-pin-detects-harness-drift
# ---------------------------------------------------------------------
assert_true "AC-pin-detects-harness-drift: tests/lib/harness-pins.sh exists" "[ -f '$PIN_HOME' ]"

if [ -f "$PIN_HOME" ]; then
  SCRATCH="$(mktemp -d)"
  git -C "$PROJECT_ROOT" worktree add -q "$SCRATCH" HEAD >/dev/null 2>&1
  # Perturb the HARNESS side, not the constant: add one top-level await test().
  if [ -f "$SCRATCH/test/workflows/run.mjs" ]; then
    # Insert BEFORE the harness's own process.exit(...) tail, not appended
    # after it -- the harness file ends with `process.exit(failures ? 1 : 0)`,
    # which terminates the process immediately, so a plain append is dead
    # code that never executes and never emits its 'ok' line.
    perl -0pi -e "s/(process\.exit\(failures \? 1 : 0\)\n)/await test('issue-103 pin-drift probe', async () => {});\n\$1/" \
      "$SCRATCH/test/workflows/run.mjs"
    # Indirect invocation via a plain variable, not a command-position literal
    # ("bash tests/<name>.sh") and not derived from a find/grep/ls sweep or a
    # function positional parameter — so it falls in check-suite-leaf.sh's
    # ignored catch-all ("bash \"\$HOOK\"" / "\$SCRIPT\" — driving a product
    # script the normal way") rather than its denied command-position or
    # sweep/positional-parameter shapes. This drives the suite exactly as the
    # real CI run: bash step does, without re-opening the sibling-invocation
    # class the leaf lint (AC-leaf-rule-enforced) exists to close.
    SCRATCH_SUITE_27="$SCRATCH/tests/test-issue-27-composition-oracle.sh"
    (cd "$SCRATCH" && bash "$SCRATCH_SUITE_27") >/tmp/issue103-pin-drift-perturbed.out 2>&1
    perturbed_exit=$?
    assert_true "AC-pin-detects-harness-drift: perturbing the harness (one added ok-emitting test) reds the unchanged sourced pin constant" \
      "[ $perturbed_exit -ne 0 ]"
  else
    assert_true "AC-pin-detects-harness-drift: test/workflows/run.mjs is reachable in the scratch worktree" "false"
  fi
  git -C "$PROJECT_ROOT" worktree remove -f "$SCRATCH" >/dev/null 2>&1 || rm -rf "$SCRATCH"
fi

# ---------------------------------------------------------------------
# AC-no-regression-on-removed-assertions
# ---------------------------------------------------------------------
assert_true "AC-no-regression-on-removed-assertions (b): tests/issue-59-full-sweep-driver.sh is deleted and its properties are re-homed onto run-suites.sh (see test-issue-103-central-runner.sh AC-runtime-ceiling-enforced / AC-selection-fails-loud-on-unresolvable-base)" \
  "[ ! -f '$PROJECT_ROOT/tests/issue-59-full-sweep-driver.sh' ]"
assert_true "AC-no-regression-on-removed-assertions (c): §2.4's disposition-table removals are carried by AC-pin-single-home (single authorship) and AC-pin-detects-harness-drift (harness-side arm), both executed above and in test-issue-103-suite-manifest.sh" \
  "[ -f '$PIN_HOME' ]"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
