#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-leaf.sh
# =============================================================================
# Test: leaf rule — no suite executes another suite, standing-lint enforced
#       — Issue #103, AC-leaf-rule-enforced
# =============================================================================
# .autoflow/issue-103-verification-design.md:
#   AC-leaf-rule-enforced — `bash scripts/test/check-suite-leaf.sh` exits 0 on
#   the post-change real tree. Self-test arms are bound one-to-one to the
#   closed shape table of feature design §2.3: one denied fixture per denied
#   row (command-position literal; find/grep derived-enumeration; function-
#   positional shape with a literal call site; loop-variable-over-literal-list
#   shape) -> FAIL, and one ignored fixture per ignored row (quoted assertion
#   label, YAML heredoc body, after '#', a `bash "$HOOK"` product-script drive)
#   -> PASS. Subject-set arm: a fixture root planted with a known set of
#   executable specs -- including one whose filename is outside test-*.sh --
#   must be enumerated exactly, so the lint cannot pass by enumerating nothing.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$PROJECT_ROOT/scripts/test/check-suite-leaf.sh"

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

echo "=== Issue #103 — AC-leaf-rule-enforced: check-suite-leaf.sh ==="

assert_true "check-suite-leaf.sh exists" "[ -f '$LINT' ]"

if [ -f "$LINT" ]; then
  assert_true "check-suite-leaf.sh --self-test exits 0 (built-in fixtures for every denied/ignored shape row)" \
    "bash '$LINT' --self-test >/tmp/issue103-leaf-selftest.out 2>&1"

  assert_true "check-suite-leaf.sh exits 0 on the post-change real tree (no sibling-suite invocation survives)" \
    "bash '$LINT' >/tmp/issue103-leaf-real.out 2>&1"

  # -- Denied-shape fixture: a command-position literal invocation ----------
  DENY_DIR="$(mktemp -d)"
  mkdir -p "$DENY_DIR/tests"
  cat > "$DENY_DIR/tests/test-fixture-leaf-command-position.sh" <<'SH'
#!/usr/bin/env bash
bash tests/test-fixture-leaf-callee.sh
SH
  echo 'true' > "$DENY_DIR/tests/test-fixture-leaf-callee.sh"
  bash "$LINT" --root "$DENY_DIR" >/tmp/issue103-leaf-deny1.out 2>&1
  deny1_exit=$?
  assert_true "denied shape 1 (command-position literal 'bash tests/<name>.sh') drives the lint to non-zero exit" \
    "[ $deny1_exit -ne 0 ] && grep -qF 'test-fixture-leaf-command-position.sh' /tmp/issue103-leaf-deny1.out"
  rm -rf "$DENY_DIR"

  # -- Denied-shape fixture: find/grep-derived enumeration sweep ------------
  DENY_DIR2="$(mktemp -d)"
  mkdir -p "$DENY_DIR2/tests"
  cat > "$DENY_DIR2/tests/test-fixture-leaf-sweep.sh" <<'SH'
#!/usr/bin/env bash
SWEPT_HOMES="$(find tests -name 'test-fixture-leaf-target-*.sh')"
for home in $SWEPT_HOMES; do
  bash "$home"
done
SH
  echo 'true' > "$DENY_DIR2/tests/test-fixture-leaf-target-a.sh"
  bash "$LINT" --root "$DENY_DIR2" >/tmp/issue103-leaf-deny2.out 2>&1
  deny2_exit=$?
  assert_true "denied shape 2 (find/grep-derived enumeration sweep) drives the lint to non-zero exit" \
    "[ $deny2_exit -ne 0 ] && grep -qF 'test-fixture-leaf-sweep.sh' /tmp/issue103-leaf-deny2.out"
  rm -rf "$DENY_DIR2"

  # -- Ignored-shape fixture: the token inside a quoted assertion label -----
  IGNORE_DIR="$(mktemp -d)"
  mkdir -p "$IGNORE_DIR/tests"
  cat > "$IGNORE_DIR/tests/test-fixture-leaf-label.sh" <<'SH'
#!/usr/bin/env bash
assert_true "the workflow registers: run: bash tests/some-other-suite.sh" "true"
SH
  bash "$LINT" --root "$IGNORE_DIR" >/tmp/issue103-leaf-ignore1.out 2>&1
  ignore1_exit=$?
  assert_true "ignored shape 1 (quoted assertion label) does not false-positive" \
    "[ $ignore1_exit -eq 0 ]"
  rm -rf "$IGNORE_DIR"

  # -- Ignored-shape fixture: YAML heredoc body ------------------------------
  IGNORE_DIR2="$(mktemp -d)"
  mkdir -p "$IGNORE_DIR2/tests"
  cat > "$IGNORE_DIR2/tests/test-fixture-leaf-heredoc.sh" <<'SH'
#!/usr/bin/env bash
cat > /tmp/fixture.yml <<'YML'
      - run: bash tests/some-other-suite.sh
YML
SH
  bash "$LINT" --root "$IGNORE_DIR2" >/tmp/issue103-leaf-ignore2.out 2>&1
  ignore2_exit=$?
  assert_true "ignored shape 2 (YAML heredoc fixture body) does not false-positive" \
    "[ $ignore2_exit -eq 0 ]"
  rm -rf "$IGNORE_DIR2"

  # -- Ignored-shape fixture: a bash "$HOOK" product-script drive ------------
  IGNORE_DIR3="$(mktemp -d)"
  mkdir -p "$IGNORE_DIR3/tests"
  cat > "$IGNORE_DIR3/tests/test-fixture-leaf-hook.sh" <<'SH'
#!/usr/bin/env bash
HOOK=".claude/hooks/check-autoflow-gate.sh"
bash "$HOOK"
SH
  bash "$LINT" --root "$IGNORE_DIR3" >/tmp/issue103-leaf-ignore3.out 2>&1
  ignore3_exit=$?
  assert_true "ignored shape 3 (indirect product-script drive via \$HOOK) does not false-positive" \
    "[ $ignore3_exit -eq 0 ]"
  rm -rf "$IGNORE_DIR3"

  # -- Subject-set arm: fixture root with a filename outside test-*.sh ------
  SUBJECT_DIR="$(mktemp -d)"
  mkdir -p "$SUBJECT_DIR/tests/plugin" "$SUBJECT_DIR/.github/workflows"
  echo 'true' > "$SUBJECT_DIR/tests/test-fixture-leaf-a.sh"
  echo 'true' > "$SUBJECT_DIR/tests/plugin/verify-fixture-leaf-b.sh"
  bash "$LINT" --root "$SUBJECT_DIR" --list-subjects >/tmp/issue103-leaf-subjects.out 2>&1
  subj_rc=$?
  assert_true "subject-set arm: enumeration reaches a filename outside test-*.sh (tests/plugin/verify-fixture-leaf-b.sh)" \
    "[ $subj_rc -eq 0 ] && grep -qF 'tests/plugin/verify-fixture-leaf-b.sh' /tmp/issue103-leaf-subjects.out && grep -qF 'tests/test-fixture-leaf-a.sh' /tmp/issue103-leaf-subjects.out"
  rm -rf "$SUBJECT_DIR"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
