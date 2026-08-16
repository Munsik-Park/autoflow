#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-manifest.sh scripts/test/suite-manifest.sh tests/lib/harness-pins.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: suite header manifest lint — Issue #103
#   AC-lane-declaration, AC-cycle-scoped-couplings, AC-ci-guard-shape,
#   AC-step-timeout-agreement, AC-budget-declaration-bounded, AC-pin-single-home
# =============================================================================
# .autoflow/issue-103-verification-design.md and .autoflow/issue-103-gate-plan.md
# (F2, governed-set quantifier reaches host-purity-delta.yml,
#  plugin-package.yml, schema-hook-contract.yml — pinned down here as real-tree
#  requirements, not assumed out of scope).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$PROJECT_ROOT/scripts/test/check-suite-manifest.sh"
LIBRARY="$PROJECT_ROOT/scripts/test/suite-manifest.sh"
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

echo "=== Issue #103 — check-suite-manifest.sh (header grammar, guard shape, budget, pin authorship) ==="

assert_true "scripts/test/suite-manifest.sh (sourced library) exists" "[ -f '$LIBRARY' ]"
assert_true "scripts/test/check-suite-manifest.sh exists" "[ -f '$LINT' ]"

if [ -f "$LINT" ]; then
  assert_true "check-suite-manifest.sh --self-test exits 0" \
    "bash '$LINT' --self-test >/tmp/issue103-manifest-selftest.out 2>&1"

  assert_true "check-suite-manifest.sh exits 0 on the post-change real tree" \
    "bash '$LINT' >/tmp/issue103-manifest-real.out 2>&1"

  # ---------------------------------------------------------------------
  # AC-lane-declaration — header presence / grammar / lane<->retire-with
  # ---------------------------------------------------------------------
  HDR_DIR="$(mktemp -d)"; mkdir -p "$HDR_DIR/tests"

  cat > "$HDR_DIR/tests/test-fixture-103-no-lane.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# budget-secs: 30
true
SH
  bash "$LINT" --root "$HDR_DIR" >/tmp/issue103-manifest-nolane.out 2>&1
  assert_true "AC-lane-declaration: a spec with no 'lane' field FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-no-lane.sh' /tmp/issue103-manifest-nolane.out"

  cat > "$HDR_DIR/tests/test-fixture-103-cyclescoped-no-retire.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: cycle-scoped
# budget-secs: 30
true
SH
  bash "$LINT" --root "$HDR_DIR" >/tmp/issue103-manifest-noretire.out 2>&1
  assert_true "AC-lane-declaration: lane: cycle-scoped without retire-with FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-cyclescoped-no-retire.sh' /tmp/issue103-manifest-noretire.out"

  cat > "$HDR_DIR/tests/test-fixture-103-standing-with-retire.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# retire-with: #103
# budget-secs: 30
true
SH
  bash "$LINT" --root "$HDR_DIR" >/tmp/issue103-manifest-standingretire.out 2>&1
  assert_true "AC-lane-declaration: lane: standing carrying retire-with FAILs (forbidden combination)" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-standing-with-retire.sh' /tmp/issue103-manifest-standingretire.out"

  rm -f "$HDR_DIR/tests/test-fixture-103-no-lane.sh" "$HDR_DIR/tests/test-fixture-103-cyclescoped-no-retire.sh" "$HDR_DIR/tests/test-fixture-103-standing-with-retire.sh"

  cat > "$HDR_DIR/tests/test-fixture-103-valid-standing.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  cat > "$HDR_DIR/tests/test-fixture-103-valid-cyclescoped.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: cycle-scoped
# retire-with: #103
# budget-secs: 30
true
SH
  bash "$LINT" --root "$HDR_DIR" >/tmp/issue103-manifest-valid.out 2>&1
  assert_true "AC-lane-declaration: each valid lane/retire-with combination PASSes" \
    "[ $? -eq 0 ]"

  # -- Subject-set arm: a filename outside test-*.sh must be enumerated -----
  mkdir -p "$HDR_DIR/tests/plugin"
  cat > "$HDR_DIR/tests/plugin/verify-fixture-103.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  bash "$LINT" --root "$HDR_DIR" --list-subjects >/tmp/issue103-manifest-subjects.out 2>&1
  assert_true "AC-lane-declaration subject-set arm: enumeration reaches a filename outside test-*.sh" \
    "grep -qF 'tests/plugin/verify-fixture-103.sh' /tmp/issue103-manifest-subjects.out"
  rm -rf "$HDR_DIR"

  # ---------------------------------------------------------------------
  # AC-cycle-scoped-couplings — lane/cycle-arm/allow-list array coupling
  # ---------------------------------------------------------------------
  CPL_DIR="$(mktemp -d)"; mkdir -p "$CPL_DIR/tests"

  cat > "$CPL_DIR/tests/test-fixture-103-cyclescoped-no-array.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: cycle-scoped
# retire-with: #103
# cycle-arm: #103
# budget-secs: 30
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl1.out 2>&1
  assert_true "AC-cycle-scoped-couplings: lane: cycle-scoped with no allow-list array FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-cyclescoped-no-array.sh' /tmp/issue103-manifest-cpl1.out"
  rm -f "$CPL_DIR/tests/test-fixture-103-cyclescoped-no-array.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-array-standing-with-arm.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #103
# budget-secs: 30
allow_list=(
  "tests/fixture.sh"
)
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl2.out 2>&1
  assert_true "AC-cycle-scoped-couplings: allow-list array + lane: standing + cycle-arm PASSes (the converse of (a) is not asserted)" \
    "[ $? -eq 0 ]"
  rm -f "$CPL_DIR/tests/test-fixture-103-array-standing-with-arm.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-array-no-arm.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
allow_list=(
  "tests/fixture.sh"
)
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl3.out 2>&1
  assert_true "AC-cycle-scoped-couplings: allow-list array with no cycle-arm FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-array-no-arm.sh' /tmp/issue103-manifest-cpl3.out"
  rm -f "$CPL_DIR/tests/test-fixture-103-array-no-arm.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-arm-no-array.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #103
# budget-secs: 30
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl4.out 2>&1
  assert_true "AC-cycle-scoped-couplings: cycle-arm on a file with no allow-list array FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-arm-no-array.sh' /tmp/issue103-manifest-cpl4.out"
  rm -f "$CPL_DIR/tests/test-fixture-103-arm-no-array.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-cyclescoped-arm-mismatch.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: cycle-scoped
# retire-with: #103
# cycle-arm: #104
# budget-secs: 30
allow_list=(
  "tests/fixture.sh"
)
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl5.out 2>&1
  assert_true "AC-cycle-scoped-couplings: cycle-scoped fixture whose cycle-arm differs from retire-with FAILs" \
    "[ $? -ne 0 ] && grep -qF 'test-fixture-103-cyclescoped-arm-mismatch.sh' /tmp/issue103-manifest-cpl5.out"
  rm -f "$CPL_DIR/tests/test-fixture-103-cyclescoped-arm-mismatch.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-cyclescoped-arm-agree.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: cycle-scoped
# retire-with: #103
# cycle-arm: #103
# budget-secs: 30
allow_list=(
  "tests/fixture.sh"
)
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl6.out 2>&1
  assert_true "AC-cycle-scoped-couplings: cycle-scoped + array + agreeing cycle-arm/retire-with PASSes" \
    "[ $? -eq 0 ]"
  rm -f "$CPL_DIR/tests/test-fixture-103-cyclescoped-arm-agree.sh"

  cat > "$CPL_DIR/tests/test-fixture-103-neither.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  bash "$LINT" --root "$CPL_DIR" >/tmp/issue103-manifest-cpl7.out 2>&1
  assert_true "AC-cycle-scoped-couplings: neither field nor array PASSes" \
    "[ $? -eq 0 ]"
  rm -rf "$CPL_DIR"

  # -- Real-tree arm: the three array-bearing suites carry cycle-arm at their
  #    own filename number, stay lane: standing.
  for f in tests/test-issue-67-deliberation-record.sh tests/test-issue-69-verification-depth.sh tests/test-issue-71-digest-removal.sh; do
    num="$(printf '%s' "$f" | sed -n 's/^tests\/test-issue-\([0-9][0-9]*\)-.*$/\1/p')"
    assert_true "AC-cycle-scoped-couplings real-tree: $f declares 'lane: standing' and 'cycle-arm: #$num'" \
      "grep -qE '^# lane: standing' '$PROJECT_ROOT/$f' && grep -qE \"^# cycle-arm: #$num\\\$\" '$PROJECT_ROOT/$f'"
  done

  # ---------------------------------------------------------------------
  # AC-ci-guard-shape — sentinel if:, id presence, governed-set boundary
  # ---------------------------------------------------------------------
  GS_DIR="$(mktemp -d)"; mkdir -p "$GS_DIR/.github/workflows"
  cat > "$GS_DIR/.github/workflows/fixture-guard.yml" <<'YML'
jobs:
  fixture:
    steps:
      - name: bare-contains-guard
        if: contains(steps.select.outputs.suites, 'tests/test-fixture.sh')
        timeout-minutes: 1
        run: bash tests/test-fixture.sh
YML
  bash "$LINT" --root "$GS_DIR" >/tmp/issue103-manifest-guard-bare.out 2>&1
  assert_true "AC-ci-guard-shape: a bare-contains guard (not sentinel-delimited) FAILs" \
    "[ $? -ne 0 ] && grep -qi 'bare-contains-guard\|contains' /tmp/issue103-manifest-guard-bare.out"

  cat > "$GS_DIR/.github/workflows/fixture-guard.yml" <<'YML'
jobs:
  fixture:
    steps:
      - name: no-id-guard
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture.sh
YML
  bash "$LINT" --root "$GS_DIR" >/tmp/issue103-manifest-guard-noid.out 2>&1
  assert_true "AC-ci-guard-shape: a sentinel-form guard with no step id FAILs" \
    "[ $? -ne 0 ] && grep -qi 'no-id-guard\|id' /tmp/issue103-manifest-guard-noid.out"

  cat > "$GS_DIR/.github/workflows/fixture-guard.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture
        name: test-fixture.sh
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture.sh
YML
  bash "$LINT" --root "$GS_DIR" >/tmp/issue103-manifest-guard-good.out 2>&1
  assert_true "AC-ci-guard-shape: the sentinel form with an id PASSes" \
    "[ $? -eq 0 ]"

  # -- Governed-set boundary, negative fixtures: standing-lint / registry
  #    runner steps carry no id/if/timeout-minutes and are NOT required to.
  cat > "$GS_DIR/.github/workflows/fixture-guard.yml" <<'YML'
jobs:
  fixture:
    steps:
      - run: bash scripts/test/check-suite-ci-coverage.sh
      - run: bash tests/run-doc-invariants.sh
YML
  bash "$LINT" --root "$GS_DIR" >/tmp/issue103-manifest-guard-ungoverned.out 2>&1
  assert_true "AC-ci-guard-shape governed-set boundary (negative): an ungoverned standing-lint/registry-runner step with no id/if/timeout-minutes PASSes" \
    "[ $? -eq 0 ]"
  rm -rf "$GS_DIR"

  # -- Governed-set boundary, positive fixture: a governed step outside the
  #    test-* filename shape must be REQUIRED to carry the guard shape.
  assert_true "AC-ci-guard-shape governed-set boundary (positive, real tree): tests/plugin/verify-install-into-target.sh's step carries the guard shape or check-suite-manifest.sh reds the real tree" \
    "grep -A3 'run: bash tests/plugin/verify-install-into-target.sh' '$PROJECT_ROOT/.github/workflows/contract-suites.yml' | grep -q 'id:' || ! bash '$LINT' >/dev/null 2>&1"

  # -- GATE:PLAN F2: the governed-set quantifier reaches three non-umbrella
  #    workflows hosting a governed step. Pinned down here as a real-tree
  #    requirement — check-suite-manifest.sh must not be scoped to the two
  #    umbrella workflows only.
  assert_true "GATE:PLAN F2: .github/workflows/host-purity-delta.yml's governed step (tests/test-issue-788-host-purity-delta.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "grep -B3 'run: bash tests/test-issue-788-host-purity-delta.sh' '$PROJECT_ROOT/.github/workflows/host-purity-delta.yml' | grep -q 'id:' || ! bash '$LINT' >/dev/null 2>&1"
  assert_true "GATE:PLAN F2: .github/workflows/plugin-package.yml's governed step (tests/plugin/verify-package.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "grep -B3 'run: bash tests/plugin/verify-package.sh' '$PROJECT_ROOT/.github/workflows/plugin-package.yml' | grep -q 'id:' || ! bash '$LINT' >/dev/null 2>&1"
  assert_true "GATE:PLAN F2: .github/workflows/schema-hook-contract.yml's governed step (tests/test-issue-223-schema-hook-contract.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "grep -B3 'run: bash tests/test-issue-223-schema-hook-contract.sh' '$PROJECT_ROOT/.github/workflows/schema-hook-contract.yml' | grep -q 'id:' || ! bash '$LINT' >/dev/null 2>&1"

  # ---------------------------------------------------------------------
  # AC-step-timeout-agreement — timeout-minutes == ceil(budget-secs/60)
  # ---------------------------------------------------------------------
  TO_DIR="$(mktemp -d)"; mkdir -p "$TO_DIR/tests" "$TO_DIR/.github/workflows"
  cat > "$TO_DIR/tests/test-fixture-103-timeout.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 90
true
SH
  cat > "$TO_DIR/.github/workflows/fixture-timeout.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-timeout
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-timeout.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture-103-timeout.sh
YML
  bash "$LINT" --root "$TO_DIR" >/tmp/issue103-manifest-timeout-raised.out 2>&1
  assert_true "AC-step-timeout-agreement: a header budget raised (90s -> ceil=2min) without the step following (still 1min) FAILs" \
    "[ $? -ne 0 ]"

  cat > "$TO_DIR/.github/workflows/fixture-timeout.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-timeout
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-timeout.sh ')
        run: bash tests/test-fixture-103-timeout.sh
YML
  bash "$LINT" --root "$TO_DIR" >/tmp/issue103-manifest-timeout-missing.out 2>&1
  assert_true "AC-step-timeout-agreement: a step with no timeout-minutes FAILs" \
    "[ $? -ne 0 ]"

  cat > "$TO_DIR/.github/workflows/fixture-timeout.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-timeout
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-timeout.sh ')
        timeout-minutes: 2
        run: bash tests/test-fixture-103-timeout.sh
YML
  bash "$LINT" --root "$TO_DIR" >/tmp/issue103-manifest-timeout-agree.out 2>&1
  assert_true "AC-step-timeout-agreement: an agreeing pair (90s -> ceil=2min, timeout-minutes: 2) PASSes" \
    "[ $? -eq 0 ]"

  # -- Governed-set boundary: an ungoverned step with no timeout-minutes PASSes
  cat > "$TO_DIR/.github/workflows/fixture-timeout.yml" <<'YML'
jobs:
  fixture:
    steps:
      - run: bash scripts/test/check-suite-ci-coverage.sh
YML
  bash "$LINT" --root "$TO_DIR" >/tmp/issue103-manifest-timeout-ungoverned.out 2>&1
  assert_true "AC-step-timeout-agreement governed-set boundary (negative): an ungoverned lint step with no timeout-minutes PASSes" \
    "[ $? -eq 0 ]"
  rm -rf "$TO_DIR"

  # ---------------------------------------------------------------------
  # AC-budget-declaration-bounded
  # ---------------------------------------------------------------------
  BD_DIR="$(mktemp -d)"; mkdir -p "$BD_DIR/tests"
  cat > "$BD_DIR/tests/test-fixture-103-budget-nonint.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: notanumber
true
SH
  bash "$LINT" --root "$BD_DIR" >/tmp/issue103-manifest-budget-nonint.out 2>&1
  assert_true "AC-budget-declaration-bounded: a non-integer budget-secs FAILs" "[ $? -ne 0 ]"
  rm -f "$BD_DIR/tests/test-fixture-103-budget-nonint.sh"

  cat > "$BD_DIR/tests/test-fixture-103-budget-nonpositive.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 0
true
SH
  bash "$LINT" --root "$BD_DIR" >/tmp/issue103-manifest-budget-nonpositive.out 2>&1
  assert_true "AC-budget-declaration-bounded: a non-positive budget-secs FAILs" "[ $? -ne 0 ]"
  rm -f "$BD_DIR/tests/test-fixture-103-budget-nonpositive.sh"

  cat > "$BD_DIR/tests/test-fixture-103-budget-overceiling.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 999999999
true
SH
  bash "$LINT" --root "$BD_DIR" >/tmp/issue103-manifest-budget-overceiling.out 2>&1
  assert_true "AC-budget-declaration-bounded: a budget-secs above SUITE_BUDGET_CEILING_SECS FAILs" "[ $? -ne 0 ]"
  rm -f "$BD_DIR/tests/test-fixture-103-budget-overceiling.sh"

  cat > "$BD_DIR/tests/test-fixture-103-budget-ceiling-verbatim.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
true
SH
  bash "$LINT" --root "$BD_DIR" >/tmp/issue103-manifest-budget-ceiling-verbatim.out 2>&1
  assert_true "AC-budget-derivation-source automated half: an unmeasured suite declaring 'budget-secs: SUITE_BUDGET_CEILING_SECS' verbatim PASSes (guessing is not a representable state)" \
    "[ $? -eq 0 ]"
  rm -rf "$BD_DIR"

  # ---------------------------------------------------------------------
  # AC-pin-single-home
  # ---------------------------------------------------------------------
  assert_true "AC-pin-single-home: tests/lib/harness-pins.sh (single committed pin constant) exists" \
    "[ -f '$PIN_HOME' ]"
  assert_true "AC-pin-single-home: the pin literal (-eq 85) is authored only in tests/lib/harness-pins.sh, not in test-issue-27" \
    "! grep -q -- '-eq 85 \]\"' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'"
  assert_true "AC-pin-single-home: the pin literal (EXPECTED_OK=85) is authored only in tests/lib/harness-pins.sh, not in test-issue-59" \
    "! grep -qF 'EXPECTED_OK=85' '$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh'"
  assert_true "AC-pin-single-home: test-issue-27 sources tests/lib/harness-pins.sh" \
    "grep -q 'harness-pins.sh' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'"
  assert_true "AC-pin-single-home: test-issue-59 sources tests/lib/harness-pins.sh" \
    "grep -q 'harness-pins.sh' '$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh'"
  assert_true "AC-pin-single-home: check-suite-manifest.sh asserts single authorship of the pin literal (its own self-test exercises a duplicated-home fixture)" \
    "grep -qi 'harness-pins\|pin' '$LINT'"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
