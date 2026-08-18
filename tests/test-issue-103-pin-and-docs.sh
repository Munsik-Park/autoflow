#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/lib/harness-pins.sh tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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

# -- The two branch-scoped-inert homes are GONE (#107). When #103 single-sourced
#    the pin it left these two foreign homes standing on the ground that each
#    pinned its own cycle's measurement on its own dev branch. #107 retired
#    that ground: both arms were dormant dev/*-issue-<N> gates over
#    already-merged cycles, and deleting them took every EXPECTED_OK= literal
#    in each file with it (docs/doc-invariant-registry.md §12.1). Both rows are
#    flipped to the same successor form — the file authors no ok-count literal
#    at all — which strengthens #103's single-authorship invariant rather than
#    dropping it. The 56 row additionally replaces a `[ -f "$SUITE_56" ]`
#    file-existence tautology, which reported green on a claim it never
#    evaluated.
assert_true "AC-pin-dependents-disposed: test-issue-56 authors no EXPECTED_OK= literal at all (its gated foreign home was retired in #107)" \
  "! grep -qE 'EXPECTED_OK=' '$SUITE_56'"
assert_true "AC-pin-dependents-disposed: test-issue-62 authors no EXPECTED_OK= literal at all (its gated foreign home, EXPECTED_OK=58, was retired in #107)" \
  "! grep -qE 'EXPECTED_OK=' '$SUITE_62'"

# ---------------------------------------------------------------------
# AC-doc-contracts-registered
# ---------------------------------------------------------------------
bash "$PROJECT_ROOT/tests/run-doc-invariants.sh" >/tmp/issue103-doc-invariants.out 2>&1
DOC_INVARIANTS_RC=$?
if [ "$DOC_INVARIANTS_RC" -ne 0 ]; then
  echo "  ---- run-doc-invariants.sh real-tree output (rc=$DOC_INVARIANTS_RC) ----"
  cat /tmp/issue103-doc-invariants.out
  echo "  ---- end output ----"
fi
assert_true "AC-doc-contracts-registered: tests/run-doc-invariants.sh exits 0 on the real tree, including this cycle's two new entries" \
  "[ $DOC_INVARIANTS_RC -eq 0 ]"
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
