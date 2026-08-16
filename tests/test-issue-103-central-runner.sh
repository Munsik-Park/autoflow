#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/select-suites.sh scripts/test/run-suites.sh scripts/test/suite-manifest.sh tests/lib/base-ref.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: central runner — one definition site of selection, positive per-
#       subject reporting, push/empty-delta full-set rule, fail-loud on an
#       unresolvable base, runtime-ceiling enforcement — Issue #103
#       AC-central-selection-multiplicity, AC-selection-reports-every-subject,
#       AC-selection-full-set-on-push-and-empty-delta,
#       AC-selection-fails-loud-on-unresolvable-base, AC-runtime-ceiling-enforced
# =============================================================================
# .autoflow/issue-103-verification-design.md:
#   "One central-runner spec under tests/" — the only carrier of "a suite
#   executed twice, or the wrong set executed, for one tree", of "a declared
#   ceiling is wired but non-gating", and of "the selected set and the
#   executed set disagree". All three arms drive the selected-set<->executed-
#   set correspondence over the same hermetic stub-suite fixture root.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SELECT="$PROJECT_ROOT/scripts/test/select-suites.sh"
RUNNER="$PROJECT_ROOT/scripts/test/run-suites.sh"

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

echo "=== Issue #103 — central runner: select-suites.sh / run-suites.sh ==="

assert_true "scripts/test/select-suites.sh exists" "[ -f '$SELECT' ]"
assert_true "scripts/test/run-suites.sh exists" "[ -f '$RUNNER' ]"

# ---------------------------------------------------------------------------
# Hermetic fixture root: stub suites that write their own path to a witness
# file when executed, so the witness -- not the runner's own summary -- is
# the oracle for "which suites ran, how many times".
# ---------------------------------------------------------------------------
build_stub_root() { # <dir>
  local dir="$1" witness="$1/witness.log"
  mkdir -p "$dir/tests" "$dir/.git"
  : > "$witness"

  cat > "$dir/tests/test-fixture-103-stub-a.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-a-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$witness"
exit 0
SH
  cat > "$dir/tests/test-fixture-103-stub-b.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-b-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$witness"
exit 0
SH
  chmod +x "$dir/tests/test-fixture-103-stub-a.sh" "$dir/tests/test-fixture-103-stub-b.sh"
}

if [ -f "$RUNNER" ] && [ -f "$SELECT" ]; then
  # ---------------------------------------------------------------------
  # AC-central-selection-multiplicity — each selected suite executes at
  # most once per tree; a runner that reports correctly while executing
  # twice is caught by the witness, not by the runner's summary.
  # ---------------------------------------------------------------------
  STUB1="$(mktemp -d)"
  build_stub_root "$STUB1"
  bash "$RUNNER" --root "$STUB1" --all >/tmp/issue103-runner-multi.out 2>&1
  WITNESS_A_COUNT="$(grep -c 'test-fixture-103-stub-a.sh' "$STUB1/witness.log" 2>/dev/null || echo 0)"
  WITNESS_B_COUNT="$(grep -c 'test-fixture-103-stub-b.sh' "$STUB1/witness.log" 2>/dev/null || echo 0)"
  assert_true "AC-central-selection-multiplicity: run-suites.sh --all runs each stub exactly once, per the execution witness (a: $WITNESS_A_COUNT, b: $WITNESS_B_COUNT)" \
    "[ \"$WITNESS_A_COUNT\" -eq 1 ] && [ \"$WITNESS_B_COUNT\" -eq 1 ]"
  rm -rf "$STUB1"

  # ---------------------------------------------------------------------
  # AC-selection-reports-every-subject — one SELECTED:/NOT-SELECTED: <path>
  # <reason> record per enumerated suite; every unselected subject carries
  # a non-empty reason.
  # ---------------------------------------------------------------------
  STUB2="$(mktemp -d)"
  build_stub_root "$STUB2"
  git -C "$STUB2" init -q 2>/dev/null || true
  git -C "$STUB2" add -A >/dev/null 2>&1 || true
  git -C "$STUB2" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1 || true
  bash "$SELECT" --root "$STUB2" --event pull_request --base "$(git -C "$STUB2" rev-parse HEAD 2>/dev/null)" >/tmp/issue103-select-out.out 2>/tmp/issue103-select-report.out
  assert_true "AC-selection-reports-every-subject: select-suites.sh emits exactly one SELECTED:/NOT-SELECTED: record per enumerated stub" \
    "grep -cE '^(SELECTED|NOT-SELECTED): tests/test-fixture-103-stub-[ab]\.sh' /tmp/issue103-select-report.out | grep -qx 2"
  assert_true "AC-selection-reports-every-subject: every NOT-SELECTED record carries a non-empty reason" \
    "! grep -qE '^NOT-SELECTED: [^ ]+ *\$' /tmp/issue103-select-report.out"
  rm -rf "$STUB2"

  # ---------------------------------------------------------------------
  # AC-selection-full-set-on-push-and-empty-delta
  # ---------------------------------------------------------------------
  STUB3="$(mktemp -d)"
  build_stub_root "$STUB3"
  bash "$SELECT" --root "$STUB3" --event push >/tmp/issue103-select-push.out 2>/tmp/issue103-select-push-report.out
  push_exit=$?
  assert_true "AC-selection-full-set-on-push-and-empty-delta: a push event selects both enumerated stubs" \
    "[ $push_exit -eq 0 ] && grep -qF 'test-fixture-103-stub-a.sh' /tmp/issue103-select-push.out && grep -qF 'test-fixture-103-stub-b.sh' /tmp/issue103-select-push.out"

  git -C "$STUB3" init -q 2>/dev/null || true
  git -C "$STUB3" add -A >/dev/null 2>&1 || true
  git -C "$STUB3" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1 || true
  HEAD_SHA="$(git -C "$STUB3" rev-parse HEAD 2>/dev/null)"
  bash "$SELECT" --root "$STUB3" --event pull_request --base "$HEAD_SHA" >/tmp/issue103-select-empty.out 2>/tmp/issue103-select-empty-report.out
  empty_exit=$?
  assert_true "AC-selection-full-set-on-push-and-empty-delta: an empty delta from a resolved base (base == HEAD) selects the full set" \
    "[ $empty_exit -eq 0 ] && grep -qF 'test-fixture-103-stub-a.sh' /tmp/issue103-select-empty.out && grep -qF 'test-fixture-103-stub-b.sh' /tmp/issue103-select-empty.out"
  rm -rf "$STUB3"

  # ---------------------------------------------------------------------
  # AC-selection-fails-loud-on-unresolvable-base
  # ---------------------------------------------------------------------
  STUB4="$(mktemp -d)"
  build_stub_root "$STUB4"
  git -C "$STUB4" init -q 2>/dev/null || true
  git -C "$STUB4" add -A >/dev/null 2>&1 || true
  git -C "$STUB4" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1 || true
  # Rename off the default branch so resolve_base_ref's origin/main / main
  # legs genuinely have nothing to resolve (git init's default-branch config
  # otherwise names this checkout's own branch "main", which is a resolvable
  # base and defeats the fixture's premise).
  git -C "$STUB4" branch -m __no-base-here__ >/dev/null 2>&1 || true
  # --root is explicit: select-suites.sh's default root is derived from its
  # own script location, not the caller's cwd (same convention as every other
  # scripts/test/check-*.sh lint), so a bare cd into the stub without --root
  # silently re-targets the real repo root instead of the fixture.
  ( cd "$STUB4" && unset GITHUB_BASE_REF; bash "$SELECT" --root "$STUB4" --event pull_request >/tmp/issue103-select-unresolvable.out 2>&1 )
  unresolvable_exit=$?
  assert_true "AC-selection-fails-loud-on-unresolvable-base: an unresolvable base is a visible BLOCK and non-zero exit, never a silent empty selection" \
    "[ $unresolvable_exit -ne 0 ] && grep -qi 'block' /tmp/issue103-select-unresolvable.out"
  rm -rf "$STUB4"

  # ---------------------------------------------------------------------
  # AC-runtime-ceiling-enforced (RE-BASED onto the EFFECTIVE local ceiling —
  # budget-secs of the fixture, TIMES scripts/test/suite-manifest.sh's
  # SUITE_LOCAL_SLOWDOWN_FACTOR (design value 8; feature design §2.5 "The
  # separation") — never the raw declared budget-secs directly. A stub whose
  # sleep sits between the declared budget and the effective ceiling is now
  # arm (a) of AC-local-enforcement-decoupled below, not this AC's subject:
  # written against the raw declared budget this arm would silently start
  # testing the multiplication instead of the gate (GATE:PLAN-2 F8).
  # ---------------------------------------------------------------------
  EFFECTIVE_CEILING_1S=8   # 1 (declared) x 8 (SUITE_LOCAL_SLOWDOWN_FACTOR, design value)

  STUB5="$(mktemp -d)"
  mkdir -p "$STUB5/tests"
  cat > "$STUB5/tests/test-fixture-103-slow.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-slow.txt
# lane: standing
# budget-secs: 1
sleep 9
exit 0
SH
  chmod +x "$STUB5/tests/test-fixture-103-slow.sh"
  bash "$RUNNER" --root "$STUB5" --all >/tmp/issue103-runner-timeout.out 2>&1
  timeout_exit=$?
  assert_true "AC-runtime-ceiling-enforced (re-based): a stub sleeping past its EFFECTIVE local ceiling ($EFFECTIVE_CEILING_1S s = declared budget-secs 1 x the local slowdown factor) drives run-suites.sh to non-zero exit with a TIMEOUT record naming both the declared budget and the effective ceiling" \
    "[ $timeout_exit -ne 0 ] && grep -qi 'TIMEOUT' /tmp/issue103-runner-timeout.out && grep -q 'declared budget-secs: 1' /tmp/issue103-runner-timeout.out && grep -qi 'effective' /tmp/issue103-runner-timeout.out"

  # VERIFY steps 3/4 delta pass (75ddbb1 -> de78d29): the guidance printed on
  # any TIMEOUT was corrected by the same commit and is otherwise untested --
  # the OLD text ("raise the budget deliberately... rather than treating the
  # run as green") is now actively wrong advice under the two-clock contract
  # (a local overrun of the effective ceiling is no evidence about the
  # CI-clock budget-secs header), and a regression that silently restored it
  # would tell a developer to edit the wrong number.
  assert_true "run-suites.sh's TIMEOUT guidance is corrected for the two-clock contract: it tells the reader to investigate a hang, not to bump the header" \
    "grep -qi 'do not bump the header' /tmp/issue103-runner-timeout.out && grep -qi 'investigate' /tmp/issue103-runner-timeout.out"
  assert_true "run-suites.sh's TIMEOUT guidance no longer carries the pre-revision 'raise the budget deliberately' advice (wrong under the two-clock contract -- a local overrun is no evidence about the CI-clock budget-secs header)" \
    "! grep -qi 'raise the budget deliberately' /tmp/issue103-runner-timeout.out"
  rm -rf "$STUB5"

  STUB6="$(mktemp -d)"
  mkdir -p "$STUB6/tests"
  cat > "$STUB6/tests/test-fixture-103-fast.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-fast.txt
# lane: standing
# budget-secs: 30
exit 0
SH
  chmod +x "$STUB6/tests/test-fixture-103-fast.sh"
  bash "$RUNNER" --root "$STUB6" --all >/tmp/issue103-runner-underbudget.out 2>&1
  underbudget_exit=$?
  assert_true "AC-runtime-ceiling-enforced: a stub comfortably under both its declared budget and its effective ceiling exits 0 (the ceiling gates, it does not falsely trip)" \
    "[ $underbudget_exit -eq 0 ]"
  rm -rf "$STUB6"

  # ---------------------------------------------------------------------
  # AC-local-enforcement-decoupled — local enforcement spends
  # budget-secs x SUITE_LOCAL_SLOWDOWN_FACTOR ("the effective local
  # ceiling"), never the raw CI-clock budget-secs directly.
  #
  # Injection mechanism for arm (c) (GATE:PLAN-2 F4): a plain environment
  # override (SUITE_LOCAL_SLOWDOWN_FACTOR=<n> in the caller's environment)
  # is deliberately NOT used to drive the identity-value arm — it would
  # convert a hard-coded resource control into an environment-settable one
  # while still passing check-suite-manifest.sh's single-authoring-home
  # lint (the assignment site itself is unchanged; only its effective value
  # would move). Route (a) instead: copy scripts/test/ into a scratch
  # directory, edit the COPIED suite-manifest.sh's assignment line in
  # place, and drive the COPIED run-suites.sh (which sources its library
  # from its own SCRIPT_DIR, so the edited copy — not the real constant —
  # is what it reads) against the real --root fixture tree.
  # ---------------------------------------------------------------------
  make_scratch_runner_with_factor() { # <factor-value> -> prints the scratch scripts/test dir path
    local factor="$1" dir
    dir="$(mktemp -d)"
    cp -r "$PROJECT_ROOT/scripts/test" "$dir/scripts-test"
    sed -i.bak -E "s/^SUITE_LOCAL_SLOWDOWN_FACTOR=.*/SUITE_LOCAL_SLOWDOWN_FACTOR=$factor  # test-override: identity value, scratch copy only/" \
      "$dir/scripts-test/suite-manifest.sh" 2>/dev/null
    rm -f "$dir/scripts-test/suite-manifest.sh.bak"
    printf '%s\n' "$dir/scripts-test"
  }

  # -- Arm (a): a stub sleeping BETWEEN its declared budget (1s) and its
  #    effective ceiling (8s) exits 0 -- this is the arm that reds if the
  #    factor is declared but never applied (the pre-change behaviour,
  #    which every other arm reads as correct).
  ARM_A_DIR="$(mktemp -d)"
  mkdir -p "$ARM_A_DIR/tests"
  cat > "$ARM_A_DIR/tests/test-fixture-103-decoupled-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-decoupled-a.txt
# lane: standing
# budget-secs: 1
sleep 5
exit 0
SH
  chmod +x "$ARM_A_DIR/tests/test-fixture-103-decoupled-a.sh"
  bash "$RUNNER" --root "$ARM_A_DIR" --all >/tmp/issue103-decoupled-a.out 2>&1
  arm_a_exit=$?
  assert_true "AC-local-enforcement-decoupled arm (a): a stub sleeping 5s -- past its declared budget-secs (1) but under its effective ceiling ($EFFECTIVE_CEILING_1S) -- exits 0 (proves the local gate spends the effective ceiling, not the raw declared budget)" \
    "[ $arm_a_exit -eq 0 ]"
  rm -rf "$ARM_A_DIR"

  # -- Arm (b): a stub sleeping past the effective ceiling -> non-zero with a
  #    TIMEOUT record naming declared budget AND effective ceiling
  #    separately (same fixture shape as the re-based AC-runtime-ceiling-
  #    enforced stub above; the record-shape assertion lives there, not
  #    duplicated here).
  ARM_B_DIR="$(mktemp -d)"
  mkdir -p "$ARM_B_DIR/tests"
  cat > "$ARM_B_DIR/tests/test-fixture-103-decoupled-b.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-decoupled-b.txt
# lane: standing
# budget-secs: 1
sleep 9
exit 0
SH
  chmod +x "$ARM_B_DIR/tests/test-fixture-103-decoupled-b.sh"
  bash "$RUNNER" --root "$ARM_B_DIR" --all >/tmp/issue103-decoupled-b.out 2>&1
  arm_b_exit=$?
  assert_true "AC-local-enforcement-decoupled arm (b): a stub sleeping 9s -- past the effective ceiling ($EFFECTIVE_CEILING_1S) -- drives a non-zero exit with a TIMEOUT record naming the declared budget AND the effective ceiling separately, so the record explains itself" \
    "[ $arm_b_exit -ne 0 ] && grep -qi 'TIMEOUT' /tmp/issue103-decoupled-b.out && grep -q 'declared budget-secs: 1' /tmp/issue103-decoupled-b.out && grep -qi 'effective' /tmp/issue103-decoupled-b.out"
  rm -rf "$ARM_B_DIR"

  # -- Arm (c): with the factor forced to its identity value (1) via the
  #    scratch-copy mechanism, behaviour is byte-identical to a raw
  #    declared-budget timeout -- a stub sleeping past the DECLARED budget
  #    (not the arm-(a)/(b) effective ceiling) times out, proving the factor
  #    is a multiplier over the declared budget rather than an unconditional
  #    widening (feature design §2.5 "any value below [identity] would
  #    derive a local allowance tighter than a number already measured").
  SCRATCH_IDENTITY_SCRIPTS="$(make_scratch_runner_with_factor 1)"
  ARM_C_DIR="$(mktemp -d)"
  mkdir -p "$ARM_C_DIR/tests"
  cat > "$ARM_C_DIR/tests/test-fixture-103-decoupled-c.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-decoupled-c.txt
# lane: standing
# budget-secs: 1
sleep 3
exit 0
SH
  chmod +x "$ARM_C_DIR/tests/test-fixture-103-decoupled-c.sh"
  bash "$SCRATCH_IDENTITY_SCRIPTS/run-suites.sh" --root "$ARM_C_DIR" --all >/tmp/issue103-decoupled-c.out 2>&1
  arm_c_exit=$?
  assert_true "AC-local-enforcement-decoupled arm (c): with the factor at its identity value (1, scratch-copy injection), a stub sleeping 3s -- past the declared budget (1) -- times out exactly as raw declared-budget enforcement would, proving the factor is a real multiplier and not a hidden bypass" \
    "[ $arm_c_exit -ne 0 ] && grep -qi 'TIMEOUT' /tmp/issue103-decoupled-c.out"
  rm -rf "$ARM_C_DIR" "$(dirname "$SCRATCH_IDENTITY_SCRIPTS")"

  # -- Anti-vacuity / F4 hole check: the mechanism chosen for arm (c) is a
  #    scratch-copy edit, NOT an environment override -- assert the REAL
  #    (unmodified) run-suites.sh ignores a SUITE_LOCAL_SLOWDOWN_FACTOR
  #    environment variable entirely, so the factor cannot be widened (or
  #    disabled) by an env-settable value that would still pass the
  #    single-authoring-home lint. Re-uses arm (a)'s fixture: if the real
  #    runner honoured the env var, forcing it to 1 here would make a 5s
  #    sleep exceed a now-identity 1s effective ceiling and time out.
  ENV_HOLE_DIR="$(mktemp -d)"
  mkdir -p "$ENV_HOLE_DIR/tests"
  cat > "$ENV_HOLE_DIR/tests/test-fixture-103-env-hole.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-env-hole.txt
# lane: standing
# budget-secs: 1
sleep 5
exit 0
SH
  chmod +x "$ENV_HOLE_DIR/tests/test-fixture-103-env-hole.sh"
  SUITE_LOCAL_SLOWDOWN_FACTOR=1 bash "$RUNNER" --root "$ENV_HOLE_DIR" --all >/tmp/issue103-env-hole.out 2>&1
  env_hole_exit=$?
  assert_true "GATE:PLAN-2 F4: the real run-suites.sh does not read a SUITE_LOCAL_SLOWDOWN_FACTOR environment variable -- setting one in the caller's environment has no effect (the arm-(a) stub still exits 0, not a forced identity-value timeout)" \
    "[ $env_hole_exit -eq 0 ]"
  rm -rf "$ENV_HOLE_DIR"

  # ---------------------------------------------------------------------
  # AC-real-sweep-clears-the-straddling-suite -- automated arithmetic half
  # (environment-dependent overall; the sweep itself is the manual/
  # environment-dependent witness, tests/manual/issue-103-manual-
  # scenarios.md M1). The margin criterion: the effective local ceiling for
  # a ceiling-symbol suite must exceed this repository's worst recorded
  # local suite runtime (test-issue-69 at 21m38s = 1298s under contention,
  # .autoflow/issue-103-phase-b.md:6).
  # ---------------------------------------------------------------------
  WORST_RECORDED_LOCAL_SECS=1298
  EFFECTIVE_CEILING_SYMBOL=$((600 * 8))  # SUITE_BUDGET_CEILING_SECS x SUITE_LOCAL_SLOWDOWN_FACTOR
  assert_true "AC-real-sweep-clears-the-straddling-suite margin criterion (arithmetic half): the effective local ceiling for a ceiling-symbol suite (600 x 8 = $EFFECTIVE_CEILING_SYMBOL s) exceeds the worst recorded local suite runtime ($WORST_RECORDED_LOCAL_SECS s, test-issue-69 under contention)" \
    "[ $EFFECTIVE_CEILING_SYMBOL -gt $WORST_RECORDED_LOCAL_SECS ]"

  # ---------------------------------------------------------------------
  # VERIFY step 3 (minimal-implementation check) additions — four real
  # implementation code paths the arms above never exercised:
  #   (1) select-suites.sh's OWN --self-test (its FULL-SET/REPORT/BLOCK/
  #       MATCHER legs) was never invoked by this suite — only its
  #       behaviour was re-tested externally through the fixture drives
  #       above.
  #   (2) run-suites.sh's DEFAULT (non---all) mode, which internally calls
  #       select-suites.sh (the "Local consumption" path feature design
  #       §2.2 names as the runner's second consumer of the one selection
  #       definition site) — every prior arm used --all, which bypasses
  #       that call entirely.
  #   (3) run-suites.sh --list.
  #   (4) run-suites.sh's SELECT_RC!=0 propagation when the internal
  #       select-suites.sh call BLOCKs.
  # ---------------------------------------------------------------------
  assert_true "select-suites.sh --self-test exits 0 (its own FULL-SET/REPORT/BLOCK/MATCHER legs)" \
    "bash '$SELECT' --self-test >/tmp/issue103-select-selftest.out 2>&1"

  STUB7="$(mktemp -d)"
  build_stub_root "$STUB7"
  git -C "$STUB7" init -q >/dev/null 2>&1
  git -C "$STUB7" add -A >/dev/null 2>&1
  git -C "$STUB7" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
  bash "$RUNNER" --root "$STUB7" --event push >/tmp/issue103-runner-default-mode.out 2>&1
  default_mode_exit=$?
  WITNESS7_A="$(grep -c 'test-fixture-103-stub-a.sh' "$STUB7/witness.log" 2>/dev/null || echo 0)"
  WITNESS7_B="$(grep -c 'test-fixture-103-stub-b.sh' "$STUB7/witness.log" 2>/dev/null || echo 0)"
  assert_true "run-suites.sh default (non---all) mode chains to select-suites.sh internally and runs the resolved full set exactly once each (a: $WITNESS7_A, b: $WITNESS7_B)" \
    "[ $default_mode_exit -eq 0 ] && [ \"$WITNESS7_A\" -eq 1 ] && [ \"$WITNESS7_B\" -eq 1 ]"

  bash "$RUNNER" --root "$STUB7" --event push --list >/tmp/issue103-runner-list.out 2>&1
  list_exit=$?
  WITNESS7_A_AFTER_LIST="$(grep -c 'test-fixture-103-stub-a.sh' "$STUB7/witness.log" 2>/dev/null || echo 0)"
  assert_true "run-suites.sh --list prints the selected set and exits 0 WITHOUT executing any suite (witness unchanged: $WITNESS7_A_AFTER_LIST)" \
    "[ $list_exit -eq 0 ] && grep -qF 'test-fixture-103-stub-a.sh' /tmp/issue103-runner-list.out && [ \"$WITNESS7_A_AFTER_LIST\" -eq 1 ]"
  rm -rf "$STUB7"

  STUB8="$(mktemp -d)"
  build_stub_root "$STUB8"
  git -C "$STUB8" init -q >/dev/null 2>&1
  git -C "$STUB8" add -A >/dev/null 2>&1
  git -C "$STUB8" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
  git -C "$STUB8" branch -m __no-base-here__ >/dev/null 2>&1
  ( cd "$STUB8" && unset GITHUB_BASE_REF; bash "$RUNNER" --root "$STUB8" --event pull_request >/tmp/issue103-runner-select-fail.out 2>&1 )
  select_fail_exit=$?
  WITNESS8="$(wc -l < "$STUB8/witness.log" 2>/dev/null | tr -d ' ')"; WITNESS8="${WITNESS8:-0}"
  assert_true "run-suites.sh propagates a non-zero SELECT_RC from an internally-BLOCKed select-suites.sh call (exit $select_fail_exit) and executes no suite (witness lines: $WITNESS8)" \
    "[ $select_fail_exit -ne 0 ] && grep -qi 'selection failed' /tmp/issue103-runner-select-fail.out && [ \"$WITNESS8\" -eq 0 ]"
  rm -rf "$STUB8"

  # VERIFY steps 3/4 delta pass (75ddbb1 -> de78d29): docs/submodule-common-
  # rules.md > Testing Standards carried the same pre-revision "raise a
  # budget deliberately... rather than treating a TIMEOUT as green" advice
  # the script guidance above corrected -- ONLY check-manifest-regen-clean.sh
  # guards this doc, and only for hash freshness (any edit without a
  # regenerated hash reds), which is silent about whether the CONTENT is
  # still correct. A regression that reverted to the old text while
  # regenerating the hash would pass that lint cleanly.
  DOC_RULES="$PROJECT_ROOT/docs/submodule-common-rules.md"
  assert_true "docs/submodule-common-rules.md > Testing Standards states the two-clock separation (budget-secs is CI-clock, local enforcement spends an effective ceiling derived by SUITE_LOCAL_SLOWDOWN_FACTOR)" \
    "grep -qF 'effective local ceiling = budget-secs' '$DOC_RULES' && grep -qF 'SUITE_LOCAL_SLOWDOWN_FACTOR' '$DOC_RULES'"
  assert_true "docs/submodule-common-rules.md > Testing Standards tells the reader to investigate a local TIMEOUT, not bump budget-secs" \
    "grep -qi 'investigate the suite' '$DOC_RULES' && grep -qi 'do not bump' '$DOC_RULES'"
  assert_true "docs/submodule-common-rules.md > Testing Standards no longer carries the pre-revision 'raise a budget deliberately... rather than treating a TIMEOUT as green' advice" \
    "! grep -qi 'raise a budget deliberately' '$DOC_RULES'"

  # =========================================================================
  # Issue #103 cycle 2 (review-response) -- runner-timeout-dependency.
  # .autoflow/issue-103-verification-design.md (cycle 2) §1:
  #   AC-runner-bounds-without-gnu-timeout, AC-runner-ceiling-survives-the-
  #   fallback. Inclusion-built sanitized PATH -- a scratch directory holding
  #   one symlink per allowlisted external, never a slice of real system bin
  #   directories (reused as a TECHNIQUE from tests/test-bounded-execution-
  #   fallback.sh, not copied as a value: that suite provisions for a probe
  #   CLI, this arm's subject is the runner and its enumerator, so the
  #   allowlist differs and is derived here per the verification design's own
  #   provisioning list).
  # =========================================================================
  RUNNER_SANITIZED_TAIL="$(mktemp -d)"
  RUNNER_ALLOWLIST="awk bash cat date dirname find git grep mkdir mktemp rm sed sort tr sleep"
  for _cmd in $RUNNER_ALLOWLIST; do
    _real="$(command -v "$_cmd" 2>/dev/null || true)"
    if [ -z "$_real" ]; then
      echo "FATAL: allowlist command not resolvable on this host: $_cmd" >&2
      exit 2
    fi
    ln -s "$_real" "$RUNNER_SANITIZED_TAIL/$_cmd"
  done

  # Fail-fast precondition (verification design §1, §3 "PATH, as composed for
  # a bounded-execution subject"): resolved in a real child shell under the
  # exact exported value, before any behavioural leg runs. neither timeout
  # nor gtimeout may resolve; sleep MUST resolve -- a missing sleep would read
  # as "every suite TIMEOUTs", not as a fallback defect, so both polarities
  # are asserted and either violation aborts the suite rather than let a
  # later leg silently drive the wrong branch.
  runner_path_precondition_ok=true
  if env -i PATH="$RUNNER_SANITIZED_TAIL" bash -c 'command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1'; then
    runner_path_precondition_ok=false
  fi
  if ! env -i PATH="$RUNNER_SANITIZED_TAIL" bash -c 'command -v sleep >/dev/null 2>&1'; then
    runner_path_precondition_ok=false
  fi
  assert_true "AC-runner-bounds precondition (fail-fast, before any behavioural leg): under the sanitized PATH, neither timeout nor gtimeout resolves, and sleep does" \
    "$runner_path_precondition_ok"
  if [ "$runner_path_precondition_ok" != "true" ]; then
    echo "ABORT: sanitized-PATH precondition violated -- aborting the runner-timeout-dependency arms rather than drive the wrong branch" >&2
    rm -rf "$RUNNER_SANITIZED_TAIL" 2>/dev/null
  else

  # -- AC-runner-bounds-without-gnu-timeout: on a host where neither timeout
  #    nor gtimeout resolves, a normally-exiting suite is reported PASS, not
  #    FAIL (exit 127).
  STUB_NOBIN_A="$(mktemp -d)"
  mkdir -p "$STUB_NOBIN_A/tests"
  cat > "$STUB_NOBIN_A/tests/test-fixture-103-nobin-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-nobin-a-subject.txt
# lane: standing
# budget-secs: 5
exit 0
SH
  chmod +x "$STUB_NOBIN_A/tests/test-fixture-103-nobin-a.sh"
  env -i PATH="$RUNNER_SANITIZED_TAIL" HOME="$HOME" bash "$RUNNER" --root "$STUB_NOBIN_A" --all >/tmp/issue103-runner-nobin.out 2>&1
  nobin_exit=$?
  assert_true "AC-runner-bounds-without-gnu-timeout: on a PATH where neither timeout nor gtimeout resolves, a normally-exiting suite is reported PASS, not FAIL (exit 127)" \
    "[ $nobin_exit -eq 0 ] && grep -qE '^PASS ' /tmp/issue103-runner-nobin.out && ! grep -qi 'exit 127' /tmp/issue103-runner-nobin.out"

  # -- Control leg (verification design §1, "Two entries carry the arm's
  #    whole provisioning risk"): the SAME sanitized tail, PLUS a real
  #    timeout symlink restored, must still report PASS for the same stub --
  #    otherwise a fallback failure above cannot be told apart from an
  #    under-provisioned PATH. A control-leg failure names the PATH as the
  #    problem, not the fallback, and aborts rather than record a fallback
  #    failure.
  RUNNER_CONTROL_TAIL="$(mktemp -d)"
  for _cmd in $RUNNER_ALLOWLIST; do
    ln -s "$(command -v "$_cmd")" "$RUNNER_CONTROL_TAIL/$_cmd"
  done
  _real_bound_tool="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"
  if [ -z "$_real_bound_tool" ]; then
    echo "  SKIP: AC-runner-bounds control leg -- this host resolves neither timeout nor gtimeout natively, so a restored-timeout tail cannot be composed" >&2
  else
    ln -s "$_real_bound_tool" "$RUNNER_CONTROL_TAIL/timeout"
    STUB_CONTROL="$(mktemp -d)"
    mkdir -p "$STUB_CONTROL/tests"
    cat > "$STUB_CONTROL/tests/test-fixture-103-control-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-control-a-subject.txt
# lane: standing
# budget-secs: 5
exit 0
SH
    chmod +x "$STUB_CONTROL/tests/test-fixture-103-control-a.sh"
    env -i PATH="$RUNNER_CONTROL_TAIL" HOME="$HOME" bash "$RUNNER" --root "$STUB_CONTROL" --all >/tmp/issue103-runner-control.out 2>&1
    control_exit=$?
    assert_true "AC-runner-bounds control leg: the same sanitized tail with a real timeout symlink restored still reports PASS for the same stub (a control-leg failure means the PATH is under-provisioned, not that the fallback is wrong)" \
      "[ $control_exit -eq 0 ] && grep -qE '^PASS ' /tmp/issue103-runner-control.out"
    rm -rf "$STUB_CONTROL"
  fi
  rm -rf "$RUNNER_CONTROL_TAIL"
  rm -rf "$STUB_NOBIN_A"

  # -- AC-runner-ceiling-survives-the-fallback: under the same sanitized
  #    PATH, a stub that overruns its declared budget must still be reported
  #    TIMEOUT, with the runner's overall exit non-zero. This is the arm that
  #    stops "delete the bound" (the fallback branch simply running the suite
  #    unwrapped) from passing the arm above.
  STUB_NOBIN_CEIL="$(mktemp -d)"
  mkdir -p "$STUB_NOBIN_CEIL/tests"
  cat > "$STUB_NOBIN_CEIL/tests/test-fixture-103-nobin-ceiling.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-nobin-ceiling-subject.txt
# lane: standing
# budget-secs: 1
sleep 9
exit 0
SH
  chmod +x "$STUB_NOBIN_CEIL/tests/test-fixture-103-nobin-ceiling.sh"
  env -i PATH="$RUNNER_SANITIZED_TAIL" HOME="$HOME" bash "$RUNNER" --root "$STUB_NOBIN_CEIL" --all >/tmp/issue103-runner-nobin-ceiling.out 2>&1
  ceiling_exit=$?
  assert_true "AC-runner-ceiling-survives-the-fallback: under the sanitized PATH, a stub sleeping past its effective local ceiling (9s > 1 x 8) is still reported TIMEOUT (not FAIL, not silently un-bounded), with the runner's overall exit non-zero" \
    "[ $ceiling_exit -ne 0 ] && grep -qi 'TIMEOUT' /tmp/issue103-runner-nobin-ceiling.out"
  rm -rf "$STUB_NOBIN_CEIL"

  rm -rf "$RUNNER_SANITIZED_TAIL"
  fi
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
