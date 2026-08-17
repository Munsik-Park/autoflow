#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-leaf.sh scripts/test/invocation-scan.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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

  bash "$LINT" >/tmp/issue103-leaf-real.out 2>&1
  LEAF_REAL_RC=$?
  if [ "$LEAF_REAL_RC" -ne 0 ]; then
    echo "  ---- check-suite-leaf.sh real-tree output (rc=$LEAF_REAL_RC) ----"
    cat /tmp/issue103-leaf-real.out
    echo "  ---- end output ----"
  fi
  assert_true "check-suite-leaf.sh exits 0 on the post-change real tree (no sibling-suite invocation survives)" \
    "[ $LEAF_REAL_RC -eq 0 ]"

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

  # ===========================================================================
  # Issue #103 cycle 3 — AC-quoted-and-prefixed-sibling-invocations-are-denied
  # .autoflow/issue-103-verification-design.md:
  #   A command-position `bash` whose first argument is a literal sibling-suite
  #   path is denied whether the argument is bare, double-quoted, single-quoted,
  #   `./`-prefixed, or preceded by `--`. The bare form already has a fixture
  #   above ("denied shape 1"); the four remaining forms below are each
  #   currently undetected: G-mask-erases-the-argument blanks a quoted literal
  #   entirely, and check-suite-leaf.sh:248/:252 neither consume a `--`
  #   separator nor admit a `./` prefix. Ignored-shape arms are equally
  #   required in the same suite: an assertion label or heredoc body carrying
  #   the same quoting/`./`/`--` characters must stay undetected, because the
  #   distinguishing feature is whether the `bash` token itself sits in command
  #   position, not whether those characters appear in the file.
  # ===========================================================================

  # -- Denied-shape fixture: double-quoted literal argument ------------------
  DENY_DQ="$(mktemp -d)"
  mkdir -p "$DENY_DQ/tests"
  echo 'true' > "$DENY_DQ/tests/test-fixture-leaf-callee.sh"
  cat > "$DENY_DQ/tests/test-fixture-leaf-dquote.sh" <<'SH'
#!/usr/bin/env bash
bash "tests/test-fixture-leaf-callee.sh"
SH
  bash "$LINT" --root "$DENY_DQ" >/tmp/issue103-leaf-dquote.out 2>&1
  deny_dq_exit=$?
  assert_true "admitted form (double-quoted 'bash \"tests/<name>.sh\"') drives the lint to non-zero exit" \
    "[ $deny_dq_exit -ne 0 ] && grep -qF 'test-fixture-leaf-dquote.sh' /tmp/issue103-leaf-dquote.out"
  rm -rf "$DENY_DQ"

  # -- Denied-shape fixture: single-quoted literal argument ------------------
  DENY_SQ="$(mktemp -d)"
  mkdir -p "$DENY_SQ/tests"
  echo 'true' > "$DENY_SQ/tests/test-fixture-leaf-callee.sh"
  cat > "$DENY_SQ/tests/test-fixture-leaf-squote.sh" <<'SH'
#!/usr/bin/env bash
bash 'tests/test-fixture-leaf-callee.sh'
SH
  bash "$LINT" --root "$DENY_SQ" >/tmp/issue103-leaf-squote.out 2>&1
  deny_sq_exit=$?
  assert_true "admitted form (single-quoted bash argument) drives the lint to non-zero exit" \
    "[ $deny_sq_exit -ne 0 ] && grep -qF 'test-fixture-leaf-squote.sh' /tmp/issue103-leaf-squote.out"
  rm -rf "$DENY_SQ"

  # -- Denied-shape fixture: ./-prefixed literal argument ---------------------
  DENY_DOTSLASH="$(mktemp -d)"
  mkdir -p "$DENY_DOTSLASH/tests"
  echo 'true' > "$DENY_DOTSLASH/tests/test-fixture-leaf-callee.sh"
  cat > "$DENY_DOTSLASH/tests/test-fixture-leaf-dotslash.sh" <<'SH'
#!/usr/bin/env bash
bash ./tests/test-fixture-leaf-callee.sh
SH
  bash "$LINT" --root "$DENY_DOTSLASH" >/tmp/issue103-leaf-dotslash.out 2>&1
  deny_dotslash_exit=$?
  assert_true "admitted form (./-prefixed 'bash ./tests/<name>.sh') drives the lint to non-zero exit" \
    "[ $deny_dotslash_exit -ne 0 ] && grep -qF 'test-fixture-leaf-dotslash.sh' /tmp/issue103-leaf-dotslash.out"
  rm -rf "$DENY_DOTSLASH"

  # -- Denied-shape fixture: -- separator preceding the literal argument -----
  DENY_DASHDASH="$(mktemp -d)"
  mkdir -p "$DENY_DASHDASH/tests"
  echo 'true' > "$DENY_DASHDASH/tests/test-fixture-leaf-callee.sh"
  cat > "$DENY_DASHDASH/tests/test-fixture-leaf-dashdash.sh" <<'SH'
#!/usr/bin/env bash
bash -- tests/test-fixture-leaf-callee.sh
SH
  bash "$LINT" --root "$DENY_DASHDASH" >/tmp/issue103-leaf-dashdash.out 2>&1
  deny_dashdash_exit=$?
  assert_true "admitted form ('--'-preceded 'bash -- tests/<name>.sh') drives the lint to non-zero exit" \
    "[ $deny_dashdash_exit -ne 0 ] && grep -qF 'test-fixture-leaf-dashdash.sh' /tmp/issue103-leaf-dashdash.out"
  rm -rf "$DENY_DASHDASH"

  # -- Ignored-shape fixture: assertion label carrying the same quoting/./--
  #    characters as the admitted forms above -------------------------------
  IGNORE_NEWCHARS_LABEL="$(mktemp -d)"
  mkdir -p "$IGNORE_NEWCHARS_LABEL/tests"
  cat > "$IGNORE_NEWCHARS_LABEL/tests/test-fixture-leaf-label-newchars.sh" <<'SH'
#!/usr/bin/env bash
assert_true 'drives: bash "./tests/some-other-suite.sh" -- extra' "true"
SH
  bash "$LINT" --root "$IGNORE_NEWCHARS_LABEL" >/tmp/issue103-leaf-ignore-label-newchars.out 2>&1
  ignore_newchars_label_exit=$?
  assert_true "ignored shape (assertion label carrying quoted/./-- characters) does not false-positive" \
    "[ $ignore_newchars_label_exit -eq 0 ]"
  rm -rf "$IGNORE_NEWCHARS_LABEL"

  # -- Ignored-shape fixture: heredoc body carrying the same quoting/./--
  #    characters as the admitted forms above -------------------------------
  IGNORE_NEWCHARS_HEREDOC="$(mktemp -d)"
  mkdir -p "$IGNORE_NEWCHARS_HEREDOC/tests"
  cat > "$IGNORE_NEWCHARS_HEREDOC/tests/test-fixture-leaf-heredoc-newchars.sh" <<'SH'
#!/usr/bin/env bash
cat > /tmp/fixture-newchars.yml <<'YML'
      - run: bash -- ./tests/some-other-suite.sh
YML
SH
  bash "$LINT" --root "$IGNORE_NEWCHARS_HEREDOC" >/tmp/issue103-leaf-ignore-heredoc-newchars.out 2>&1
  ignore_newchars_heredoc_exit=$?
  assert_true "ignored shape (heredoc body carrying quoted/./-- characters) does not false-positive" \
    "[ $ignore_newchars_heredoc_exit -eq 0 ]"
  rm -rf "$IGNORE_NEWCHARS_HEREDOC"

  # ===========================================================================
  # Issue #103 cycle 3 —
  # AC-a-literal-suite-path-reaching-bash-through-a-variable-is-denied
  # .autoflow/issue-103-verification-design.md:
  #   A variable assigned a literal enumerated-suite path in the same file,
  #   then invoked via `bash "$v"`, is denied — assignment at top level and
  #   inside a function, with and without a $PROJECT_ROOT/$SCRIPT_DIR prefix on
  #   the literal. Non-firing: a variable holding a product-script path, a
  #   variable holding an excluded path, and — the required third conjunct-
  #   discriminating arm — a variable assigned a literal enumerated suite path
  #   but read only as a non-command operand (never invoked as `bash "$v"`).
  #   The feature design's denied row (D5,
  #   scripts/test/check-suite-leaf.sh header + §2
  #   leaf-detection-named-suite-variable) is a conjunction: an assignment
  #   carrying the literal AND a command-position `bash "$v"`.
  # ===========================================================================

  # -- Denied D5 fixture: top-level assignment, no directory prefix ----------
  D5_TOP_BARE="$(mktemp -d)"
  mkdir -p "$D5_TOP_BARE/tests"
  echo 'true' > "$D5_TOP_BARE/tests/test-fixture-leaf-d5-callee.sh"
  cat > "$D5_TOP_BARE/tests/test-fixture-leaf-d5-top-bare.sh" <<'SH'
#!/usr/bin/env bash
V="tests/test-fixture-leaf-d5-callee.sh"
bash "$V"
SH
  bash "$LINT" --root "$D5_TOP_BARE" >/tmp/issue103-leaf-d5-top-bare.out 2>&1
  d5_top_bare_exit=$?
  assert_true "D5: top-level variable assigned a literal enumerated-suite path, invoked via bash \"\$v\", is denied" \
    "[ $d5_top_bare_exit -ne 0 ] && grep -qF 'test-fixture-leaf-d5-top-bare.sh' /tmp/issue103-leaf-d5-top-bare.out"
  rm -rf "$D5_TOP_BARE"

  # -- Denied D5 fixture: top-level assignment, $PROJECT_ROOT-prefixed -------
  D5_TOP_PREFIXED="$(mktemp -d)"
  mkdir -p "$D5_TOP_PREFIXED/tests"
  echo 'true' > "$D5_TOP_PREFIXED/tests/test-fixture-leaf-d5-callee.sh"
  cat > "$D5_TOP_PREFIXED/tests/test-fixture-leaf-d5-top-prefixed.sh" <<'SH'
#!/usr/bin/env bash
V="$PROJECT_ROOT/tests/test-fixture-leaf-d5-callee.sh"
bash "$V"
SH
  bash "$LINT" --root "$D5_TOP_PREFIXED" >/tmp/issue103-leaf-d5-top-prefixed.out 2>&1
  d5_top_prefixed_exit=$?
  assert_true "D5: top-level variable assigned a \$PROJECT_ROOT-prefixed literal enumerated-suite path, invoked via bash \"\$v\", is denied" \
    "[ $d5_top_prefixed_exit -ne 0 ] && grep -qF 'test-fixture-leaf-d5-top-prefixed.sh' /tmp/issue103-leaf-d5-top-prefixed.out"
  rm -rf "$D5_TOP_PREFIXED"

  # -- Denied D5 fixture: assignment inside a function, no directory prefix --
  D5_FN_BARE="$(mktemp -d)"
  mkdir -p "$D5_FN_BARE/tests"
  echo 'true' > "$D5_FN_BARE/tests/test-fixture-leaf-d5-callee.sh"
  cat > "$D5_FN_BARE/tests/test-fixture-leaf-d5-fn-bare.sh" <<'SH'
#!/usr/bin/env bash
run_it() {
  local v="tests/test-fixture-leaf-d5-callee.sh"
  bash "$v"
}
run_it
SH
  bash "$LINT" --root "$D5_FN_BARE" >/tmp/issue103-leaf-d5-fn-bare.out 2>&1
  d5_fn_bare_exit=$?
  assert_true "D5: function-scoped variable assigned a literal enumerated-suite path, invoked via bash \"\$v\", is denied" \
    "[ $d5_fn_bare_exit -ne 0 ] && grep -qF 'test-fixture-leaf-d5-fn-bare.sh' /tmp/issue103-leaf-d5-fn-bare.out"
  rm -rf "$D5_FN_BARE"

  # -- Denied D5 fixture: assignment inside a function, $SCRIPT_DIR-prefixed -
  D5_FN_PREFIXED="$(mktemp -d)"
  mkdir -p "$D5_FN_PREFIXED/tests"
  echo 'true' > "$D5_FN_PREFIXED/tests/test-fixture-leaf-d5-callee.sh"
  cat > "$D5_FN_PREFIXED/tests/test-fixture-leaf-d5-fn-prefixed.sh" <<'SH'
#!/usr/bin/env bash
run_it() {
  local v="$SCRIPT_DIR/test-fixture-leaf-d5-callee.sh"
  bash "$v"
}
run_it
SH
  bash "$LINT" --root "$D5_FN_PREFIXED" >/tmp/issue103-leaf-d5-fn-prefixed.out 2>&1
  d5_fn_prefixed_exit=$?
  assert_true "D5: function-scoped variable assigned a \$SCRIPT_DIR-prefixed literal enumerated-suite path, invoked via bash \"\$v\", is denied" \
    "[ $d5_fn_prefixed_exit -ne 0 ] && grep -qF 'test-fixture-leaf-d5-fn-prefixed.sh' /tmp/issue103-leaf-d5-fn-prefixed.out"
  rm -rf "$D5_FN_PREFIXED"

  # -- Non-firing D5 arm: variable holds a product-script path ---------------
  D5_NF_PRODUCT="$(mktemp -d)"
  mkdir -p "$D5_NF_PRODUCT/tests"
  cat > "$D5_NF_PRODUCT/tests/test-fixture-leaf-d5-nf-product.sh" <<'SH'
#!/usr/bin/env bash
HOOK=".claude/hooks/check-autoflow-gate.sh"
bash "$HOOK"
SH
  bash "$LINT" --root "$D5_NF_PRODUCT" >/tmp/issue103-leaf-d5-nf-product.out 2>&1
  d5_nf_product_exit=$?
  assert_true "D5 non-firing: a variable holding a product-script path, invoked via bash \"\$v\", stays undetected" \
    "[ $d5_nf_product_exit -eq 0 ]"
  rm -rf "$D5_NF_PRODUCT"

  # -- Non-firing D5 arm: variable holds an excluded path ---------------------
  D5_NF_EXCLUDED="$(mktemp -d)"
  mkdir -p "$D5_NF_EXCLUDED/tests"
  echo 'true' > "$D5_NF_EXCLUDED/tests/run-doc-invariants.sh"
  cat > "$D5_NF_EXCLUDED/tests/test-fixture-leaf-d5-nf-excluded.sh" <<'SH'
#!/usr/bin/env bash
V="tests/run-doc-invariants.sh"
bash "$V"
SH
  bash "$LINT" --root "$D5_NF_EXCLUDED" >/tmp/issue103-leaf-d5-nf-excluded.out 2>&1
  d5_nf_excluded_exit=$?
  assert_true "D5 non-firing: a variable holding an excluded path (tests/run-doc-invariants.sh), invoked via bash \"\$v\", stays undetected" \
    "[ $d5_nf_excluded_exit -eq 0 ]"
  rm -rf "$D5_NF_EXCLUDED"

  # -- Non-firing D5 arm: literal enumerated-suite path read only as a
  #    non-command operand (a grep file argument), never invoked -------------
  D5_NF_OPERAND="$(mktemp -d)"
  mkdir -p "$D5_NF_OPERAND/tests"
  echo 'true' > "$D5_NF_OPERAND/tests/test-fixture-leaf-d5-nf-operand-callee.sh"
  cat > "$D5_NF_OPERAND/tests/test-fixture-leaf-d5-nf-operand.sh" <<'SH'
#!/usr/bin/env bash
V="tests/test-fixture-leaf-d5-nf-operand-callee.sh"
grep -q 'EXPECTED_OK=' "$V"
SH
  bash "$LINT" --root "$D5_NF_OPERAND" >/tmp/issue103-leaf-d5-nf-operand.out 2>&1
  d5_nf_operand_exit=$?
  assert_true "D5 non-firing (antecedent's first conjunct alone): a variable assigned a literal enumerated-suite path but read only as a non-command operand, never invoked as bash \"\$v\", stays undetected" \
    "[ $d5_nf_operand_exit -eq 0 ]"
  rm -rf "$D5_NF_OPERAND"

  # ===========================================================================
  # Issue #103 cycle 3 — AC-the-residual-paragraph-describes-the-implemented-rows
  # .autoflow/issue-103-verification-design.md:
  #   The leaf lint's own header paragraph naming what it does and does not
  #   detect must agree with the rows it implements after this cycle — checked
  #   against the denied-row identifiers the fixtures above exercise (D1-D5).
  #   Currently RED: the header (scripts/test/check-suite-leaf.sh:19-46) lists
  #   only D1-D4 and states the residual admits a quoted/./--/variable-mediated
  #   literal, which this cycle's D5 row and quoting/prefix fix are meant to
  #   narrow.
  # ===========================================================================
  LEAF_HEADER_TEXT="$(sed -n '1,/^# Usage:/p' "$LINT")"
  assert_true "the leaf lint's header names D5 among its denied rows (residual paragraph updated for this cycle)" \
    "[[ \"\$LEAF_HEADER_TEXT\" == *'D5'* ]]"

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
