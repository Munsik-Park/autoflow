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
  ( cd "$STUB4" && unset GITHUB_BASE_REF; bash "$SELECT" --event pull_request >/tmp/issue103-select-unresolvable.out 2>&1 )
  unresolvable_exit=$?
  assert_true "AC-selection-fails-loud-on-unresolvable-base: an unresolvable base is a visible BLOCK and non-zero exit, never a silent empty selection" \
    "[ $unresolvable_exit -ne 0 ] && grep -qi 'block' /tmp/issue103-select-unresolvable.out"
  rm -rf "$STUB4"

  # ---------------------------------------------------------------------
  # AC-runtime-ceiling-enforced
  # ---------------------------------------------------------------------
  STUB5="$(mktemp -d)"
  mkdir -p "$STUB5/tests"
  cat > "$STUB5/tests/test-fixture-103-slow.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture-slow.txt
# lane: standing
# budget-secs: 1
sleep 5
exit 0
SH
  chmod +x "$STUB5/tests/test-fixture-103-slow.sh"
  bash "$RUNNER" --root "$STUB5" --all >/tmp/issue103-runner-timeout.out 2>&1
  timeout_exit=$?
  assert_true "AC-runtime-ceiling-enforced: a stub sleeping past its declared budget-secs drives run-suites.sh to non-zero exit with a TIMEOUT record" \
    "[ $timeout_exit -ne 0 ] && grep -qi 'TIMEOUT' /tmp/issue103-runner-timeout.out"
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
  assert_true "AC-runtime-ceiling-enforced: a stub under budget exits 0 (the ceiling gates, it does not falsely trip)" \
    "[ $underbudget_exit -eq 0 ]"
  rm -rf "$STUB6"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
