#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-ci-coverage.sh scripts/test/check-suite-manifest.sh scripts/test/invocation-scan.sh scripts/test/suite-manifest.sh tests/lib/harness-pins.sh
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
COVERAGE_LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"
LIBRARY="$PROJECT_ROOT/scripts/test/suite-manifest.sh"
PIN_HOME="$PROJECT_ROOT/tests/lib/harness-pins.sh"
INVSCAN_LIB="$PROJECT_ROOT/scripts/test/invocation-scan.sh"

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

  bash "$LINT" >/tmp/issue103-manifest-real.out 2>&1
  MANIFEST_REAL_RC=$?
  if [ "$MANIFEST_REAL_RC" -ne 0 ]; then
    echo "  ---- check-suite-manifest.sh real-tree output (rc=$MANIFEST_REAL_RC) ----"
    cat /tmp/issue103-manifest-real.out
    echo "  ---- end output ----"
  fi
  assert_true "check-suite-manifest.sh exits 0 on the post-change real tree" \
    "[ $MANIFEST_REAL_RC -eq 0 ]"

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
# cycle-arm: #103
# budget-secs: 30
allow_list=(
  "tests/fixture.sh"
)
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
  # SIGPIPE-safe: capture the streaming grep -A/-B context producer first,
  # then match the captured string with grep -q — piping a streaming
  # producer directly into a short-circuiting -q consumer under pipefail can
  # promote a producer SIGPIPE (exit 141) into a false pipeline failure
  # (docs/submodule-common-rules.md > Testing Standards item 6).
  # The three OR-fallback legs below reuse $MANIFEST_REAL_RC from the
  # real-tree run above rather than re-invoking the lint: it is the SAME
  # lint over the SAME real tree, so a fresh invocation would be redundant,
  # and reusing it means a fallback-branch failure surfaces through the
  # already-dumped output above instead of a second swallowed capture.
  CTX_INSTALL="$(grep -A3 'run: bash tests/plugin/verify-install-into-target.sh' "$PROJECT_ROOT/.github/workflows/contract-suites.yml")"
  INSTALL_HAS_ID=1; printf '%s\n' "$CTX_INSTALL" | grep -q 'id:' && INSTALL_HAS_ID=0
  assert_true "AC-ci-guard-shape governed-set boundary (positive, real tree): tests/plugin/verify-install-into-target.sh's step carries the guard shape or check-suite-manifest.sh reds the real tree" \
    "[ $INSTALL_HAS_ID -eq 0 ] || [ $MANIFEST_REAL_RC -ne 0 ]"

  # -- GATE:PLAN F2: the governed-set quantifier reaches three non-umbrella
  #    workflows hosting a governed step. Pinned down here as a real-tree
  #    requirement — check-suite-manifest.sh must not be scoped to the two
  #    umbrella workflows only.
  CTX_HOST_PURITY="$(grep -B3 'run: bash tests/test-issue-788-host-purity-delta.sh' "$PROJECT_ROOT/.github/workflows/host-purity-delta.yml")"
  HOST_PURITY_HAS_ID=1; printf '%s\n' "$CTX_HOST_PURITY" | grep -q 'id:' && HOST_PURITY_HAS_ID=0
  assert_true "GATE:PLAN F2: .github/workflows/host-purity-delta.yml's governed step (tests/test-issue-788-host-purity-delta.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "[ $HOST_PURITY_HAS_ID -eq 0 ] || [ $MANIFEST_REAL_RC -ne 0 ]"
  CTX_PLUGIN_PACKAGE="$(grep -B3 'run: bash tests/plugin/verify-package.sh' "$PROJECT_ROOT/.github/workflows/plugin-package.yml")"
  PLUGIN_PACKAGE_HAS_ID=1; printf '%s\n' "$CTX_PLUGIN_PACKAGE" | grep -q 'id:' && PLUGIN_PACKAGE_HAS_ID=0
  assert_true "GATE:PLAN F2: .github/workflows/plugin-package.yml's governed step (tests/plugin/verify-package.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "[ $PLUGIN_PACKAGE_HAS_ID -eq 0 ] || [ $MANIFEST_REAL_RC -ne 0 ]"
  CTX_SCHEMA_HOOK="$(grep -B3 'run: bash tests/test-issue-223-schema-hook-contract.sh' "$PROJECT_ROOT/.github/workflows/schema-hook-contract.yml")"
  SCHEMA_HOOK_HAS_ID=1; printf '%s\n' "$CTX_SCHEMA_HOOK" | grep -q 'id:' && SCHEMA_HOOK_HAS_ID=0
  assert_true "GATE:PLAN F2: .github/workflows/schema-hook-contract.yml's governed step (tests/test-issue-223-schema-hook-contract.sh) carries id/if/timeout-minutes, or check-suite-manifest.sh reds the real tree over it" \
    "[ $SCHEMA_HOOK_HAS_ID -eq 0 ] || [ $MANIFEST_REAL_RC -ne 0 ]"

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
  # AC-headroom-constant-single-homed — SUITE_BUDGET_HEADROOM_PERCENT is a
  # single named constant, integer >= 100, authored only in
  # scripts/test/suite-manifest.sh (revised feature/verification design,
  # budget re-deliberation).
  # ---------------------------------------------------------------------
  assert_true "AC-headroom-constant-single-homed: SUITE_BUDGET_HEADROOM_PERCENT=150 is authored in scripts/test/suite-manifest.sh" \
    "grep -qE '^SUITE_BUDGET_HEADROOM_PERCENT=150([[:space:]]|$)' '$LIBRARY'"

  HOMED_DIR="$(mktemp -d)"; mkdir -p "$HOMED_DIR/scripts/test" "$HOMED_DIR/tests"
  cp "$LIBRARY" "$HOMED_DIR/scripts/test/suite-manifest.sh"
  echo 'SUITE_BUDGET_HEADROOM_PERCENT=200' > "$HOMED_DIR/scripts/test/rogue-headroom.sh"
  bash "$LINT" --root "$HOMED_DIR" >/tmp/issue103-manifest-headroom-second-home.out 2>&1
  assert_true "AC-headroom-constant-single-homed: a second file assigning SUITE_BUDGET_HEADROOM_PERCENT= (outside scripts/test/suite-manifest.sh) FAILs" \
    "[ $? -ne 0 ] && grep -qF 'rogue-headroom.sh' /tmp/issue103-manifest-headroom-second-home.out"
  rm -f "$HOMED_DIR/scripts/test/rogue-headroom.sh"

  sed -i.bak -E 's/^SUITE_BUDGET_HEADROOM_PERCENT=.*/SUITE_BUDGET_HEADROOM_PERCENT=99/' "$HOMED_DIR/scripts/test/suite-manifest.sh" 2>/dev/null
  bash "$LINT" --root "$HOMED_DIR" >/tmp/issue103-manifest-headroom-below100.out 2>&1
  assert_true "AC-headroom-constant-single-homed: a value below 100 FAILs (a sub-100 multiplier derives a budget tighter than the measurement it is headroom over)" \
    "[ $? -ne 0 ]"

  sed -i.bak -E 's/^SUITE_BUDGET_HEADROOM_PERCENT=.*/SUITE_BUDGET_HEADROOM_PERCENT=notanumber/' "$HOMED_DIR/scripts/test/suite-manifest.sh" 2>/dev/null
  bash "$LINT" --root "$HOMED_DIR" >/tmp/issue103-manifest-headroom-noninteger.out 2>&1
  assert_true "AC-headroom-constant-single-homed: a non-integer value FAILs" \
    "[ $? -ne 0 ]"
  rm -rf "$HOMED_DIR"

  # ---------------------------------------------------------------------
  # AC-local-factor-derivation-recorded — automated half. SUITE_LOCAL_SLOWDOWN_FACTOR
  # is authored in exactly one file (scripts/test/suite-manifest.sh, beside
  # SUITE_BUDGET_CEILING_SECS), integer >= 1 (its identity value). Carrier
  # lint named explicitly per GATE:PLAN-2 F7 (mirrors AC-headroom-constant-
  # single-homed's row): check-suite-manifest.sh.
  # ---------------------------------------------------------------------
  assert_true "AC-local-factor-derivation-recorded automated half: SUITE_LOCAL_SLOWDOWN_FACTOR=8 is authored in scripts/test/suite-manifest.sh (single home, mirrors the PIN-group shape check-suite-manifest.sh already implements)" \
    "grep -qE '^SUITE_LOCAL_SLOWDOWN_FACTOR=8([[:space:]]|$)' '$LIBRARY'"

  FACTOR_DIR="$(mktemp -d)"; mkdir -p "$FACTOR_DIR/scripts/test" "$FACTOR_DIR/tests"
  cp "$LIBRARY" "$FACTOR_DIR/scripts/test/suite-manifest.sh"
  echo 'SUITE_LOCAL_SLOWDOWN_FACTOR=3' > "$FACTOR_DIR/scripts/test/rogue-factor.sh"
  bash "$LINT" --root "$FACTOR_DIR" >/tmp/issue103-manifest-factor-second-home.out 2>&1
  assert_true "AC-local-factor-derivation-recorded: a second file assigning SUITE_LOCAL_SLOWDOWN_FACTOR= (outside scripts/test/suite-manifest.sh) FAILs, carried by check-suite-manifest.sh" \
    "[ $? -ne 0 ] && grep -qF 'rogue-factor.sh' /tmp/issue103-manifest-factor-second-home.out"
  rm -f "$FACTOR_DIR/scripts/test/rogue-factor.sh"

  sed -i.bak -E 's/^SUITE_LOCAL_SLOWDOWN_FACTOR=.*/SUITE_LOCAL_SLOWDOWN_FACTOR=0/' "$FACTOR_DIR/scripts/test/suite-manifest.sh" 2>/dev/null
  bash "$LINT" --root "$FACTOR_DIR" >/tmp/issue103-manifest-factor-below-identity.out 2>&1
  assert_true "AC-local-factor-derivation-recorded: a value below its identity (1) FAILs — a sub-identity multiplier derives a local allowance tighter than a number already measured on the faster clock" \
    "[ $? -ne 0 ]"

  sed -i.bak -E 's/^SUITE_LOCAL_SLOWDOWN_FACTOR=.*/SUITE_LOCAL_SLOWDOWN_FACTOR=notanumber/' "$FACTOR_DIR/scripts/test/suite-manifest.sh" 2>/dev/null
  bash "$LINT" --root "$FACTOR_DIR" >/tmp/issue103-manifest-factor-noninteger.out 2>&1
  assert_true "AC-local-factor-derivation-recorded: a non-integer value FAILs" \
    "[ $? -ne 0 ]"
  rm -rf "$FACTOR_DIR"

  # ---------------------------------------------------------------------
  # AC-local-factor-does-not-reach-ci — falsifiability arm (GATE:PLAN-2 F1:
  # "currently passes vacuously — give it a falsifiability arm"). The
  # agreement check-suite-manifest.sh already implements
  # (scripts/test/check-suite-manifest.sh:227-228) computes 'want' from the
  # header's declared budget-secs ALONE (never multiplied by the local
  # factor); this arm constructs the exact bad case the AC exists to
  # exclude — a timeout-minutes inflated by the local factor — and requires
  # it to FAIL, not merely observes that the current (factor-blind)
  # agreement holds.
  # ---------------------------------------------------------------------
  LEAK_DIR="$(mktemp -d)"; mkdir -p "$LEAK_DIR/tests" "$LEAK_DIR/.github/workflows"
  cat > "$LEAK_DIR/tests/test-fixture-103-leak.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 60
true
SH
  # ceil(60 x 8 / 60) = 8 minutes -- the factor LEAKED into the CI timeout,
  # which is exactly the unbounded-CI-runtime purchase this AC exists to
  # prevent (correct agreement is ceil(60 / 60) = 1 minute).
  cat > "$LEAK_DIR/.github/workflows/fixture-leak.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-leak
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-leak.sh ')
        timeout-minutes: 8
        run: bash tests/test-fixture-103-leak.sh
YML
  bash "$LINT" --root "$LEAK_DIR" >/tmp/issue103-manifest-factor-leak.out 2>&1
  assert_true "AC-local-factor-does-not-reach-ci falsifiability arm: a governed step's timeout-minutes inflated by the local factor (ceil(60x8/60)=8, instead of the correct ceil(60/60)=1) FAILs — the local factor never buys CI runtime" \
    "[ $? -ne 0 ]"

  cat > "$LEAK_DIR/.github/workflows/fixture-leak.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-leak
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-leak.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture-103-leak.sh
YML
  bash "$LINT" --root "$LEAK_DIR" >/tmp/issue103-manifest-factor-noleak.out 2>&1
  assert_true "AC-local-factor-does-not-reach-ci: the correct CI-only agreement (ceil(60/60)=1, no factor applied) PASSes" \
    "[ $? -eq 0 ]"
  rm -rf "$LEAK_DIR"

  # ---------------------------------------------------------------------
  # AC-pin-single-home
  # ---------------------------------------------------------------------
  assert_true "AC-pin-single-home: tests/lib/harness-pins.sh (single committed pin constant) exists" \
    "[ -f '$PIN_HOME' ]"
  assert_true "AC-pin-single-home: the pin literal (-eq 85) is authored only in tests/lib/harness-pins.sh, not in test-issue-27" \
    "! grep -q -- '-eq 85 \]\"' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'"
  assert_true "AC-pin-single-home: the pin literal (EXPECTED_OK=85) is authored only in tests/lib/harness-pins.sh, not in test-issue-59" \
    "! grep -qF 'EXPECTED_OK=85' '$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh'"
  # Tightened in #107 from a bare path grep to a non-comment source/. line —
  # the same predicate check-suite-manifest.sh's header-matches-content rule
  # uses. A bare grep is satisfied by a `# ci-subject:` token or any comment
  # mention, so it reported green on a sourcing that had been removed. The
  # companion row over test-issue-59 was RETIRED in the same change: #107
  # deleted that suite's only reader of the pin, so the row's subject no
  # longer exists. #103's settled property — the literal is authored in
  # exactly one home — is carried entirely by the two negative rows above.
  assert_true "AC-pin-single-home: test-issue-27 sources tests/lib/harness-pins.sh on a non-comment source/. line (textual mention is not a sourcing)" \
    "grep -vE '^[[:space:]]*#' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh' | grep -qE '(^|[[:space:]])(source|\\.)[[:space:]]+[^[:space:]]*harness-pins\\.sh'"
  assert_true "AC-pin-single-home: check-suite-manifest.sh asserts single authorship of the pin literal (its own self-test exercises a duplicated-home fixture)" \
    "grep -qi 'harness-pins\|pin' '$LINT'"

  # ---------------------------------------------------------------------
  # AC-block-form-run-steps-are-governed-records — cycle 3
  # A governed suite invoked from a `run: |` block scalar is a governed step
  # record: it must carry id:/if:/timeout-minutes: exactly as a single-line
  # `run:` step does.
  # ---------------------------------------------------------------------
  BLK_DIR="$(mktemp -d)"; mkdir -p "$BLK_DIR/tests" "$BLK_DIR/.github/workflows"
  cat > "$BLK_DIR/tests/test-fixture-103-block-form.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH

  cat > "$BLK_DIR/.github/workflows/fixture-block.yml" <<'YML'
jobs:
  fixture:
    steps:
      - name: block-scalar-no-guard
        run: |
          bash tests/test-fixture-103-block-form.sh
YML
  bash "$LINT" --root "$BLK_DIR" >/tmp/issue103-manifest-block-noguard.out 2>&1
  assert_true "AC-block-form-run-steps-are-governed-records: a governed suite invoked from a 'run: |' block scalar with no id/if/timeout-minutes FAILs, exactly as the single-line form does" \
    "[ $? -ne 0 ]"

  cat > "$BLK_DIR/.github/workflows/fixture-block.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-103-block-form
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-103-block-form.sh ')
        timeout-minutes: 1
        run: |
          bash tests/test-fixture-103-block-form.sh
YML
  bash "$LINT" --root "$BLK_DIR" >/tmp/issue103-manifest-block-guard.out 2>&1
  assert_true "AC-block-form-run-steps-are-governed-records: the same suite invoked from a 'run: |' block scalar carrying the full id/if/timeout-minutes shape PASSes" \
    "[ $? -eq 0 ]"
  rm -rf "$BLK_DIR"

  # ---------------------------------------------------------------------
  # AC-no-currently-governed-step-loses-its-record — cycle 3
  # Over the real .github/workflows/ tree, every governed suite that has a
  # registering `run:` step yields a step record naming it, from the shared
  # step reader (scripts/test/invocation-scan.sh) — so a parser replacement
  # cannot silently shrink the governed set. The subject list is derived from
  # the real tree by a plain literal-text search (independent of the reader
  # under test), never hand-carried.
  # ---------------------------------------------------------------------
  assert_true "AC-no-currently-governed-step-loses-its-record: scripts/test/invocation-scan.sh (the shared step reader both lints must use) exists" \
    "[ -f '$INVSCAN_LIB' ]"

  if [ -f "$INVSCAN_LIB" ]; then
    # shellcheck source=scripts/test/invocation-scan.sh
    . "$INVSCAN_LIB"

    FLOOR_REGISTERED="$(mktemp)"
    for wf in "$PROJECT_ROOT"/.github/workflows/*.yml "$PROJECT_ROOT"/.github/workflows/*.yaml; do
      [ -f "$wf" ] || continue
      grep -ohE 'run:[[:space:]]*bash[[:space:]]+tests/[A-Za-z0-9_./-]+\.(sh|bats)' "$wf" 2>/dev/null \
        | sed -E 's#^run:[[:space:]]*bash[[:space:]]+##'
    done | sort -u > "$FLOOR_REGISTERED"

    FLOOR_SUBJECTS="$(suite_enumerate "$PROJECT_ROOT" | sort -u)"
    FLOOR_GOVERNED_REGISTERED="$(comm -12 <(printf '%s\n' "$FLOOR_SUBJECTS") "$FLOOR_REGISTERED")"

    FLOOR_RUNPATHS="$(mktemp)"
    for wf in "$PROJECT_ROOT"/.github/workflows/*.yml "$PROJECT_ROOT"/.github/workflows/*.yaml; do
      [ -f "$wf" ] || continue
      invscan_workflow_invocations "$wf" 2>/dev/null >> "$FLOOR_RUNPATHS"
    done
    sort -u -o "$FLOOR_RUNPATHS" "$FLOOR_RUNPATHS"

    while IFS= read -r floor_suite; do
      [ -n "$floor_suite" ] || continue
      assert_true "AC-no-currently-governed-step-loses-its-record: $floor_suite (a real, literal-text-registered governed suite) has a step record naming it from invscan_workflow_invocations" \
        "grep -qxF '$floor_suite' '$FLOOR_RUNPATHS'"
    done <<< "$FLOOR_GOVERNED_REGISTERED"

    rm -f "$FLOOR_REGISTERED" "$FLOOR_RUNPATHS"
  else
    echo "  SKIP: AC-no-currently-governed-step-loses-its-record per-suite floor arms — scripts/test/invocation-scan.sh absent"
  fi

  # ---------------------------------------------------------------------
  # AC-a-step-invoking-two-governed-suites-is-rejected — cycle 3
  # A single `run:` step whose body invokes more than one governed suite is a
  # violation (per-suite if:/timeout-minutes: cannot be expressed for it). A
  # step invoking one governed suite plus any number of ungoverned scripts/…
  # paths must PASS — the live select/reconcile steps take exactly this shape.
  # ---------------------------------------------------------------------
  MULTI_DIR="$(mktemp -d)"; mkdir -p "$MULTI_DIR/.github/workflows"

  cat > "$MULTI_DIR/.github/workflows/fixture-multi.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-multi
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/fixture-multi-a.sh ')
        timeout-minutes: 1
        run: |
          bash tests/fixture-multi-a.sh
          bash tests/fixture-multi-b.sh
YML
  bash "$LINT" --root "$MULTI_DIR" >/tmp/issue103-manifest-multi-two-governed.out 2>&1
  assert_true "AC-a-step-invoking-two-governed-suites-is-rejected: a block-scalar step invoking TWO governed suites FAILs, naming both" \
    "[ $? -ne 0 ]"

  cat > "$MULTI_DIR/.github/workflows/fixture-multi.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-select
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/fixture-multi-a.sh ')
        timeout-minutes: 1
        run: |
          bash scripts/test/check-suite-ci-coverage.sh
          bash tests/fixture-multi-a.sh
YML
  bash "$LINT" --root "$MULTI_DIR" >/tmp/issue103-manifest-multi-one-governed.out 2>&1
  assert_true "AC-a-step-invoking-two-governed-suites-is-rejected: a block-scalar step invoking one governed suite plus one ungoverned scripts/… path PASSes (the live select/reconcile shape)" \
    "[ $? -eq 0 ]"
  rm -rf "$MULTI_DIR"

  # ---------------------------------------------------------------------
  # AC-the-two-lints-agree-on-what-an-invocation-is — cycle 3
  # Over one shared fixture root, check-suite-manifest.sh and
  # check-suite-ci-coverage.sh must reach the SAME verdict about whether the
  # block-scalar step's invocation is a registration. Driven directly: a
  # step with NO guard invoking a suite that is registered NOWHERE else —
  # manifest's verdict is "registered" iff it FAILs (missing id/if/timeout on
  # a step it recognises as governed); coverage's verdict is "registered" iff
  # it PASSes (the suite is reachable, not an orphan). Today the two lints use
  # independent private logic and disagree by construction on this shape:
  # manifest's single-line-only reader misses the block scalar (registered =
  # false) while coverage's whole-file grep still finds the token
  # (registered = true).
  # ---------------------------------------------------------------------
  CROSS_DIR="$(mktemp -d)"; mkdir -p "$CROSS_DIR/tests" "$CROSS_DIR/.github/workflows"
  cat > "$CROSS_DIR/tests/test-fixture-103-cross-lint.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  cat > "$CROSS_DIR/.github/workflows/fixture-cross.yml" <<'YML'
jobs:
  fixture:
    steps:
      - name: block-scalar-no-guard
        run: |
          bash tests/test-fixture-103-cross-lint.sh
YML

  bash "$LINT" --root "$CROSS_DIR" >/tmp/issue103-manifest-crosslint.out 2>&1
  MANIFEST_CROSS_RC=$?
  bash "$COVERAGE_LINT" --root "$CROSS_DIR" >/tmp/issue103-coverage-crosslint.out 2>&1
  COVERAGE_CROSS_RC=$?

  MANIFEST_CROSS_REGISTERED=false
  [ "$MANIFEST_CROSS_RC" -ne 0 ] && MANIFEST_CROSS_REGISTERED=true
  COVERAGE_CROSS_REGISTERED=false
  [ "$COVERAGE_CROSS_RC" -eq 0 ] && COVERAGE_CROSS_REGISTERED=true

  assert_true "AC-the-two-lints-agree-on-what-an-invocation-is: check-suite-manifest.sh (registered=$MANIFEST_CROSS_REGISTERED, via missing-guard) and check-suite-ci-coverage.sh (registered=$COVERAGE_CROSS_REGISTERED, via reachability) agree on whether the block-scalar step's invocation counts as a registration" \
    "[ '$MANIFEST_CROSS_REGISTERED' = '$COVERAGE_CROSS_REGISTERED' ]"
  rm -rf "$CROSS_DIR"

  # ---------------------------------------------------------------------
  # GATE:PLAN-binding finding, ledger O20/F-1 — scripts/test/invocation-scan.sh's
  # own CI enrollment: (a) this suite's own ci-subject header includes it
  # (feature design §2 trigger-surface-completeness, "Header-side enrollment"),
  # and (b) contract-suites.yml — the sole real-tree host of this suite —
  # declares a paths: entry covering it. contract-suites.yml carries no
  # scripts/** directory glob (unlike host-purity-delta.yml), so the design's
  # "already covered by scripts/**" claim does not hold for this suite's own
  # host and an explicit paths: entry is required.
  # ---------------------------------------------------------------------
  assert_true "F-1: scripts/test/invocation-scan.sh (the shared invocation-scan library) exists" \
    "[ -f '$INVSCAN_LIB' ]"

  if [ -f "$INVSCAN_LIB" ]; then
    assert_true "F-1 header-side enrollment: this suite's own ci-subject header declares scripts/test/invocation-scan.sh" \
      "grep -qE '^# ci-subject:.*scripts/test/invocation-scan\.sh' '$PROJECT_ROOT/tests/test-issue-103-suite-manifest.sh'"

    assert_true "F-1 workflow-side enrollment: contract-suites.yml declares a paths: entry covering scripts/test/invocation-scan.sh" \
      "grep -qF \"'scripts/test/invocation-scan.sh'\" '$PROJECT_ROOT/.github/workflows/contract-suites.yml'"
  else
    echo "  SKIP: F-1 header-side/workflow-side enrollment arms — scripts/test/invocation-scan.sh absent"
  fi

  # =========================================================================
  # Issue #108 -- step-id convention enforcement, valued-flag hardening,
  # self-test summary agreement.
  # .autoflow/issue-108-verification-design.md:
  #   AC-step-id-value-conforms, AC-one-derivation-of-the-step-id (arms b/c
  #   -- arm (a), the lint's own self-test fixture class, is implementation
  #   surface and lands with GREEN), AC-governed-suite-basename-is-unique,
  #   AC-valued-flags-fail-closed (--root only), AC-selftest-summary-agrees-
  #   with-fixture-set.
  # =========================================================================
  RECONCILE108="$PROJECT_ROOT/scripts/test/check-step-reconciliation.sh"

  # ---------------------------------------------------------------------
  # AC-step-id-value-conforms -- a governed step's declared id: must equal
  # s-<basename-without-extension> of the suite it runs.
  # ---------------------------------------------------------------------
  IDVAL_DIR="$(mktemp -d)"; mkdir -p "$IDVAL_DIR/tests" "$IDVAL_DIR/.github/workflows"
  cat > "$IDVAL_DIR/tests/test-fixture-108-idval-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  cat > "$IDVAL_DIR/.github/workflows/fixture-idval.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-not-the-conforming-id
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-108-idval-a.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture-108-idval-a.sh
YML
  bash "$LINT" --root "$IDVAL_DIR" >/tmp/issue108-idval-nonconform.out 2>&1
  assert_true "AC-step-id-value-conforms: a governed step's id: present but NOT equal to s-<basename> (s-not-the-conforming-id vs s-test-fixture-108-idval-a) is a violation naming the declared and required values" \
    "[ $? -ne 0 ] && grep -qF 's-not-the-conforming-id' /tmp/issue108-idval-nonconform.out && grep -qF 's-test-fixture-108-idval-a' /tmp/issue108-idval-nonconform.out"

  cat > "$IDVAL_DIR/.github/workflows/fixture-idval.yml" <<'YML'
jobs:
  fixture:
    steps:
      - id: s-test-fixture-108-idval-a
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fixture-108-idval-a.sh ')
        timeout-minutes: 1
        run: bash tests/test-fixture-108-idval-a.sh
YML
  bash "$LINT" --root "$IDVAL_DIR" >/tmp/issue108-idval-conform.out 2>&1
  assert_true "AC-step-id-value-conforms: a governed step's id: equal to s-<basename> conforms (no violation)" \
    "[ $? -eq 0 ]"
  rm -rf "$IDVAL_DIR"

  # ---------------------------------------------------------------------
  # AC-one-derivation-of-the-step-id -- arm (b): a single definition site
  # under scripts/ and tests/ composes a step id from a basename. Detection
  # follows the design's own literal, line-anchored regex (§4), which is
  # what excludes the standing `s-…` fixture literals both host suites
  # already carry.
  # ---------------------------------------------------------------------
  ONEHOME_PATTERN='^[[:space:]]*suite_step_id[[:space:]]*\(\)|^[[:space:]]*(printf|echo)[^#]*s-(%s|\$\{)'
  ONEHOME_HITS="$(grep -rlE "$ONEHOME_PATTERN" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" 2>/dev/null | sed "s#^$PROJECT_ROOT/##" | sort -u)"
  ONEHOME_COUNT="$(printf '%s\n' "$ONEHOME_HITS" | grep -c .)"
  assert_true "AC-one-derivation-of-the-step-id arm (b): exactly one file under scripts/ or tests/ composes the step id from a basename (found: $ONEHOME_COUNT — $(printf '%s' "$ONEHOME_HITS" | tr '\n' ' '))" \
    "[ \"$ONEHOME_COUNT\" -eq 1 ]"
  assert_true "AC-one-derivation-of-the-step-id arm (b): the one definition site is scripts/test/suite-manifest.sh (post-consolidation home), not check-step-reconciliation.sh" \
    "printf '%s\n' \"$ONEHOME_HITS\" | grep -qxF 'scripts/test/suite-manifest.sh'"
  assert_true "AC-one-derivation-of-the-step-id arm (b) does-not-fire polarity: the detection expression excludes the standing 's-…' id-string fixture literals already carried by check-step-reconciliation.sh and its host suite (neither limb matches an 's-' not followed by a format placeholder or a parameter expansion)" \
    "! printf '%s\n' \"$ONEHOME_HITS\" | grep -qxF 'tests/test-issue-103-step-reconciliation.sh'"

  # -- arm (c): both consumers (the lint and the reconciler) reach the same
  #    id for a governed suite path. Driven black-box against the real
  #    check-step-reconciliation.sh: a SELECTED report naming the suite,
  #    reconciled against an outcome map keyed by suite_step_id's own
  #    output, must agree (exit 0) -- a disagreeing derivation leaves the
  #    entry outcome=absent and reds.
  #    Guarded on suite_step_id existing (post-consolidation): calling an
  #    undefined function is itself the RED signal pre-consolidation.
  if [ -f "$LIBRARY" ]; then
    # shellcheck source=scripts/test/suite-manifest.sh
    . "$LIBRARY"
    if declare -F suite_step_id >/dev/null 2>&1; then
      for gpath in tests/test-issue-103-step-reconciliation.sh tests/test-issue-103-suite-manifest.sh tests/test-issue-103-central-runner.sh; do
        oh_derived="$(suite_step_id "$gpath")"
        OH_SEL="$(mktemp)"; OH_STEPS="$(mktemp)"
        printf 'SELECTED: %s\n' "$gpath" > "$OH_SEL"
        printf '{"%s": {"outcome": "success"}}\n' "$oh_derived" > "$OH_STEPS"
        bash "$RECONCILE108" --selected "$OH_SEL" --steps "$OH_STEPS" >/tmp/issue108-onehome-c-"$(basename "$gpath")".out 2>&1
        assert_true "AC-one-derivation-of-the-step-id arm (c): suite_step_id('$gpath') = '$oh_derived' agrees with what the real check-step-reconciliation.sh resolves for the same path (reconciles as agreement)" \
          "[ $? -eq 0 ]"
        rm -f "$OH_SEL" "$OH_STEPS"
      done
    else
      assert_true "AC-one-derivation-of-the-step-id arm (c): scripts/test/suite-manifest.sh exports suite_step_id (consolidation not yet landed)" "false"
    fi
  else
    assert_true "AC-one-derivation-of-the-step-id arm (c): scripts/test/suite-manifest.sh exists" "false"
  fi

  # ---------------------------------------------------------------------
  # AC-governed-suite-basename-is-unique -- a collision within the
  # ENUMERATED GOVERNED SET is a violation naming both paths; a collision
  # involving an excluded path is not.
  # ---------------------------------------------------------------------
  COLL_DIR="$(mktemp -d)"; mkdir -p "$COLL_DIR/tests/sub"
  cat > "$COLL_DIR/tests/test-fixture-108-collide.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  cat > "$COLL_DIR/tests/sub/test-fixture-108-collide.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  bash "$LINT" --root "$COLL_DIR" >/tmp/issue108-collide-governed.out 2>&1
  assert_true "AC-governed-suite-basename-is-unique: two governed suites sharing a basename (tests/test-fixture-108-collide.sh, tests/sub/test-fixture-108-collide.sh) is a violation naming both paths" \
    "[ $? -ne 0 ] && grep -qF 'tests/test-fixture-108-collide.sh' /tmp/issue108-collide-governed.out && grep -qF 'tests/sub/test-fixture-108-collide.sh' /tmp/issue108-collide-governed.out"
  rm -rf "$COLL_DIR"

  EXCL_DIR="$(mktemp -d)"; mkdir -p "$EXCL_DIR/tests/lib"
  cat > "$EXCL_DIR/tests/test-fixture-108-collide-excl.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
true
SH
  cat > "$EXCL_DIR/tests/lib/test-fixture-108-collide-excl.sh" <<'SH'
#!/usr/bin/env bash
some fixture body, not a spec
SH
  bash "$LINT" --root "$EXCL_DIR" >/tmp/issue108-collide-excluded.out 2>&1
  assert_true "AC-governed-suite-basename-is-unique: a same-basename pair where one member is EXCLUDED (tests/lib/**, a sourced library) is not a collision -- excluded paths never reach an outcome key" \
    "[ $? -eq 0 ]"
  rm -rf "$EXCL_DIR"

  # ---------------------------------------------------------------------
  # AC-valued-flags-fail-closed -- --root on check-suite-manifest.sh
  # (its only valued flag: it has neither --base nor --event).
  # ---------------------------------------------------------------------
  bash "$LINT" --root "" >/tmp/issue108-manifest-vf-root-empty.out 2>&1
  assert_true "AC-valued-flags-fail-closed: check-suite-manifest.sh --root given an empty value is a usage error (exit 2) naming --root, not a silent fall-through to the real tree" \
    "[ $? -eq 2 ] && grep -qi -- '--root' /tmp/issue108-manifest-vf-root-empty.out"

  bash "$LINT" --root >/tmp/issue108-manifest-vf-root-last.out 2>&1
  assert_true "AC-valued-flags-fail-closed: check-suite-manifest.sh --root as the final argument (no value) is a usage error (exit 2) naming --root" \
    "[ $? -eq 2 ] && grep -qi -- '--root' /tmp/issue108-manifest-vf-root-last.out"

  # ---------------------------------------------------------------------
  # AC-selftest-summary-agrees-with-fixture-set -- the manifest lint's own
  # --self-test summary integer equals the number of per-class result
  # lines it actually emitted. The design records this pair as ALREADY
  # DISAGREEING on today's tree (the printed literal is lower than the
  # emitted line count), so this arm is expected to red on arrival
  # independent of any cascade/id-value work above.
  # ---------------------------------------------------------------------
  bash "$LINT" --self-test >/tmp/issue108-manifest-selftest.out 2>&1
  mst_emitted="$(grep -cE '^[[:space:]]+SELF-TEST (PASS|FAIL):' /tmp/issue108-manifest-selftest.out)"
  mst_reported="$(grep -oE '[0-9]+ of [0-9]+ fixture classes|[0-9]+/[0-9]+ fixture classes' /tmp/issue108-manifest-selftest.out | grep -oE '[0-9]+' | tail -1)"
  assert_true "AC-selftest-summary-agrees-with-fixture-set: check-suite-manifest.sh --self-test's emitted per-class line count ($mst_emitted) equals the integer in its own summary line ($mst_reported)" \
    "[ -n \"$mst_reported\" ] && [ \"$mst_emitted\" -eq \"$mst_reported\" ]"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
