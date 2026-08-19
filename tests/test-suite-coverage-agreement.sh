#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/suite-coverage.sh scripts/test/run-suites.sh scripts/test/suite-manifest.sh scripts/test/check-suite-manifest.sh tests/test-push-context-base-ref.sh docs/autoflow-guide.md docs/evaluation-system.md docs/adr/0019-scope-fit-verification-policy.md tests/fixtures/gate-schema.json .github/workflows/contract-suites.yml
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: suite-coverage agreement — Issue #112
#   Cross-artifact derivations the permanent doc-invariant registry cannot
#   hold (docs/doc-invariant-registry.md §1: a derivation across artifacts,
#   not a single-document state assertion) and the resolver's own hermetic
#   self-test does not reach (a fixture-suite property, not an artifact
#   agreement):
#
#   - the extracted out-of-tree call-site predicate has exactly one
#     definition site (scripts/test/suite-manifest.sh), with the one named
#     exception (tests/test-cycle-arm-residue.sh's quoted assertion string),
#     and both consumers call the extracted function rather than re-typing it;
#   - the evaluator's declared report-schema key (`inherited_verdicts`) is
#     present in docs/evaluation-system.md and absent from the state file's
#     closed-world `top_level_keys` (tests/fixtures/gate-schema.json);
#   - the resolver's hermetic self-test is registered as a standing,
#     unguarded CI step;
#   - the resolver's stdout is valid input to the real
#     `run-suites.sh --selected`, over a hermetic fixture root — a composition
#     contact point (T ∩ S), not a shape assertion;
#   - the playbook's cited flags/commands for the resolver idiom exist in the
#     shipped scripts (playbook <-> script agreement).
#
# .autoflow/issue-112-verification-design.md > "Acceptance criteria ->
# verification": *the call-site criterion has one definition site*,
# *evaluator citation-inheritance*, *the resolver's oracle is wired*,
# *step text and record grammar agree*; Composition-oracle determination >
# "resolver stdout -> run-suites.sh --selected".
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SELF_REL="tests/test-suite-coverage-agreement.sh"

RESOLVER="$PROJECT_ROOT/scripts/test/suite-coverage.sh"
RUNNER="$PROJECT_ROOT/scripts/test/run-suites.sh"
MANIFEST_LIB="$PROJECT_ROOT/scripts/test/suite-manifest.sh"
MANIFEST_LINT="$PROJECT_ROOT/scripts/test/check-suite-manifest.sh"
PUSH_CONTEXT_SUITE="$PROJECT_ROOT/tests/test-push-context-base-ref.sh"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EVAL_SYSTEM="$PROJECT_ROOT/docs/evaluation-system.md"
GATE_SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"
CONTRACT_WORKFLOW="$PROJECT_ROOT/.github/workflows/contract-suites.yml"

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

echo "=== Issue #112 — suite-coverage agreement ==="

# =============================================================================
# Leg 1 — the out-of-tree call-site predicate has one definition site.
#
# Domain: every *.sh file under scripts/** and tests/**, non-comment lines
# only (the same restriction the predicate itself carries in
# tests/test-push-context-base-ref.sh's derive_subjects()). A file matches
# when a non-comment line contains the ALTERNATION ITSELF, as executable
# regex text — `\bresolve_base_ref\b|\bgit\b[^#]*\bmerge-base\b` — not merely
# a call to resolve_base_ref or a `git ... merge-base` invocation (those are
# real, legitimate call sites in many files, e.g. tests/lib/base-ref.sh's own
# definition, and are not what this leg is about). Escaping is normalised
# (doubled backslashes collapsed to single) before matching, because the
# permitted quoted-string exception is itself written with doubled
# backslashes and a raw-literal comparison would not see it.
# =============================================================================

PATTERN_LITERAL='\bresolve_base_ref\b|\bgit\b[^#]*\bmerge-base\b'
predicate_matches_file() { # <abs-path>
  sed 's/\\\\/\\/g' "$1" 2>/dev/null | grep -vE '^[[:space:]]*#' | grep -qF "$PATTERN_LITERAL"
}

matched_files=""
while IFS= read -r -d '' f; do
  rel="${f#"$PROJECT_ROOT"/}"
  [ "$rel" = "$SELF_REL" ] && continue
  predicate_matches_file "$f" && matched_files="$matched_files$rel"$'\n'
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -name '*.sh' -print0 2>/dev/null)

single_def_site_ok=1
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  case "$rel" in
    scripts/test/suite-manifest.sh) ;;
    tests/test-cycle-arm-residue.sh) ;;
    *) single_def_site_ok=0 ;;
  esac
done <<< "$matched_files"

assert_true "single-definition-site: the out-of-tree call-site predicate occurs only in scripts/test/suite-manifest.sh and inside tests/test-cycle-arm-residue.sh's quoted assertion strings (matched files: $(printf '%s' "$matched_files" | tr '\n' ' '))" \
  "[ $single_def_site_ok -eq 1 ] && grep -qF 'suite_reads_out_of_tree_state' '$MANIFEST_LIB' 2>/dev/null"

assert_true "single-definition-site: derive_subjects() in tests/test-push-context-base-ref.sh calls suite_reads_out_of_tree_state rather than re-typing the regex" \
  "! predicate_matches_file '$PUSH_CONTEXT_SUITE' && grep -qF 'suite_reads_out_of_tree_state' '$PUSH_CONTEXT_SUITE' 2>/dev/null"

assert_true "single-definition-site: the new HEADER arm in scripts/test/check-suite-manifest.sh calls suite_reads_out_of_tree_state rather than re-typing the regex" \
  "! predicate_matches_file '$MANIFEST_LINT' && grep -qF 'suite_reads_out_of_tree_state' '$MANIFEST_LINT' 2>/dev/null"

# =============================================================================
# Leg 2 — evaluator citation carrier: positive shape (declared in the report
# schema) and negative shape (absent from the state file's closed-world key
# set) must both hold. The negative half is a standing guard that already
# holds today; the positive half is the one this issue must make true.
# =============================================================================

assert_true "evaluator-citation-inheritance: docs/evaluation-system.md > Evaluation Output Format declares 'inherited_verdicts' with member keys suite/source/head/result" \
  "grep -qF 'inherited_verdicts' '$EVAL_SYSTEM' && grep -qF '\"suite\"' '$EVAL_SYSTEM' && grep -qF '\"source\"' '$EVAL_SYSTEM' && grep -qF '\"head\"' '$EVAL_SYSTEM' && grep -qF '\"result\"' '$EVAL_SYSTEM'"

assert_true "evaluator-citation-inheritance: tests/fixtures/gate-schema.json top_level_keys stays closed-world — 'inherited_verdicts' is NOT one of them" \
  "! python3 -c \"import json,sys; d=json.load(open('$GATE_SCHEMA')); sys.exit(0 if 'inherited_verdicts' in d.get('top_level_keys', []) else 1)\""

# =============================================================================
# Leg 3 — the resolver's self-test is registered as a standing, unguarded CI
# step (a `run:` step invoking `--self-test`, alongside the existing
# self-test steps, carrying no `if:` guard).
# =============================================================================

resolver_selftest_step_unguarded() {
  awk '
    /^[[:space:]]*- name:/ {
      if (matched && found == "") found = blk
      blk = $0; matched = 0; next
    }
    { blk = blk "\n" $0 }
    /suite-coverage\.sh --self-test/ { matched = 1 }
    END {
      if (matched && found == "") found = blk
      if (found != "" && found !~ /if:/) print "UNGUARDED"
    }
  ' "$CONTRACT_WORKFLOW" 2>/dev/null | grep -qF 'UNGUARDED'
}

assert_true "the-resolvers-oracle-is-wired: contract-suites.yml registers a 'run: bash scripts/test/suite-coverage.sh --self-test' step" \
  "grep -qE 'run: *bash +scripts/test/suite-coverage\.sh +--self-test' '$CONTRACT_WORKFLOW'"

assert_true "the-resolvers-oracle-is-wired: the suite-coverage.sh --self-test step carries no if: guard" \
  "grep -qE 'run: *bash +scripts/test/suite-coverage\.sh +--self-test' '$CONTRACT_WORKFLOW' && resolver_selftest_step_unguarded"

# =============================================================================
# Leg 4 — composition oracle: resolver stdout -> run-suites.sh --selected.
# One resolver-produced plan file fed to the REAL run-suites.sh --selected in
# a hermetic fixture root; the executed set must equal the plan's lines.
# Guarded: the resolver does not exist yet at RED time, so this leg reports a
# named FAIL rather than aborting the whole suite on a missing binary.
# =============================================================================

if [ ! -f "$RESOLVER" ]; then
  assert_true "composition: scripts/test/suite-coverage.sh exists (resolver stdout -> run-suites.sh --selected cannot be exercised without it)" "false"
else
  FX="$(mktemp -d)"
  mkdir -p "$FX/tests" "$FX/.git" "$FX/.autoflow"
  WITNESS="$FX/witness.log"
  : > "$WITNESS"
  cat > "$FX/tests/test-fixture-112-agree-a.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-agree-a-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$WITNESS"
exit 0
SH
  cat > "$FX/tests/test-fixture-112-agree-b.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-agree-b-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$WITNESS"
exit 0
SH
  chmod +x "$FX/tests/test-fixture-112-agree-a.sh" "$FX/tests/test-fixture-112-agree-b.sh"
  (cd "$FX" && git init -q && git add -A && git -c user.email=t@example.com -c user.name=t commit -q -m init)

  LEDGER="$FX/.autoflow/issue-9999-ledger.md"
  : > "$LEDGER"
  PLAN_FILE="$FX/run-set.txt"
  bash "$RESOLVER" --ledger "$LEDGER" --cycle 1 --root "$FX" --candidates all > "$PLAN_FILE" 2>/tmp/issue112-agree-resolver.err
  RESOLVER_RC=$?

  if [ "$RESOLVER_RC" -ne 0 ] && [ "$RESOLVER_RC" -ne 1 ]; then
    assert_true "composition: resolver runs to a defined exit (0 normal / 1 BLOCK) over the fixture root" "false"
  else
    bash "$RUNNER" --root "$FX" --selected "$PLAN_FILE" > /tmp/issue112-agree-runner.out 2>&1
    EXECUTED_SET="$(sort "$WITNESS" 2>/dev/null | sed "s#^$FX/##" | sort -u)"
    PLAN_SET="$(sort -u "$PLAN_FILE" 2>/dev/null)"
    assert_true "composition: the resolver's stdout plan, fed to the real run-suites.sh --selected, executes exactly the planned set (executed: $(printf '%s' "$EXECUTED_SET" | tr '\n' ' ') | plan: $(printf '%s' "$PLAN_SET" | tr '\n' ' '))" \
      "[ \"\$EXECUTED_SET\" = \"\$PLAN_SET\" ] || [ -z \"\$PLAN_SET\" -a -z \"\$EXECUTED_SET\" ]"
  fi
  rm -rf "$FX"
fi

# =============================================================================
# Leg 4b — dirty composition (issue #112 cycle 2, review finding): the
# resolver's candidate set widens to the uncommitted delta at an interim
# capture point (--candidates selection), so a suite touched only in the
# worktree is both in the plan the resolver emits and in the set the real
# runner executes for it. One committed-delta suite and one uncommitted-delta
# suite in the same fixture — the composition assertion (executed == plan)
# holds either way, so the discriminating half is that the plan itself must
# NAME the uncommitted-delta suite.
# Guarded: the resolver does not exist yet at RED time.
# =============================================================================

if [ ! -f "$RESOLVER" ]; then
  assert_true "dirty-composition: scripts/test/suite-coverage.sh exists (cannot exercise the dirty candidate set without it)" "false"
else
  FXD="$(mktemp -d)"
  mkdir -p "$FXD/tests" "$FXD/.autoflow"
  WITNESS_D="$FXD/witness.log"
  : > "$WITNESS_D"
  cat > "$FXD/tests/test-fixture-112-agree-dirty-a.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-agree-dirty-a-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$WITNESS_D"
exit 0
SH
  cat > "$FXD/tests/test-fixture-112-agree-dirty-b.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-agree-dirty-b-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$WITNESS_D"
exit 0
SH
  chmod +x "$FXD/tests/test-fixture-112-agree-dirty-a.sh" "$FXD/tests/test-fixture-112-agree-dirty-b.sh"
  printf 'x\n' > "$FXD/tests/fixture-112-agree-dirty-a-subject.txt"
  printf 'x\n' > "$FXD/tests/fixture-112-agree-dirty-b-subject.txt"
  printf '.autoflow/\n' > "$FXD/.gitignore"
  (cd "$FXD" && git init -q -b main && git add -A \
    && git -c user.email=t@example.com -c user.name=t commit -q -m init)
  (cd "$FXD" && git checkout -q -b work)
  # committed delta: touch subject a; uncommitted (unstaged) delta: touch
  # subject b — the shape the review's finding names.
  printf 'changed\n' >> "$FXD/tests/fixture-112-agree-dirty-a-subject.txt"
  (cd "$FXD" && git add -A && git -c user.email=t@example.com -c user.name=t commit -q -m "touch a")
  printf 'uncommitted\n' >> "$FXD/tests/fixture-112-agree-dirty-b-subject.txt"

  LEDGER_D="$FXD/.autoflow/issue-9999-ledger.md"
  : > "$LEDGER_D"
  PLAN_FILE_D="$FXD/run-set.txt"
  bash "$RESOLVER" --ledger "$LEDGER_D" --cycle 1 --root "$FXD" --candidates selection \
    > "$PLAN_FILE_D" 2>/tmp/issue112-agree-dirty-resolver.err
  RESOLVER_RC_D=$?

  if [ "$RESOLVER_RC_D" -ne 0 ] && [ "$RESOLVER_RC_D" -ne 1 ]; then
    assert_true "dirty-composition: resolver runs to a defined exit (0 normal / 1 BLOCK) over the dirty fixture root" "false"
  else
    PLAN_SET_D="$(sort -u "$PLAN_FILE_D" 2>/dev/null)"
    assert_true "dirty-composition: the resolved plan names the suite whose subject is modified only in the worktree, not only the committed one (plan: $(printf '%s' "$PLAN_SET_D" | tr '\n' ' '))" \
      "printf '%s\\n' \"\$PLAN_SET_D\" | grep -qF 'tests/test-fixture-112-agree-dirty-a.sh' && printf '%s\\n' \"\$PLAN_SET_D\" | grep -qF 'tests/test-fixture-112-agree-dirty-b.sh'"

    bash "$RUNNER" --root "$FXD" --selected "$PLAN_FILE_D" > /tmp/issue112-agree-dirty-runner.out 2>&1
    EXECUTED_SET_D="$(sort "$WITNESS_D" 2>/dev/null | sed "s#^$FXD/##" | sort -u)"
    assert_true "dirty-composition: the resolver's dirty-tree plan, fed to the real run-suites.sh --selected, executes exactly the planned set (executed: $(printf '%s' "$EXECUTED_SET_D" | tr '\n' ' ') | plan: $(printf '%s' "$PLAN_SET_D" | tr '\n' ' '))" \
      "[ \"\$EXECUTED_SET_D\" = \"\$PLAN_SET_D\" ] || [ -z \"\$PLAN_SET_D\" -a -z \"\$EXECUTED_SET_D\" ]"
  fi
  rm -rf "$FXD"
fi

# =============================================================================
# Leg 5 — step text and record grammar agree: the flags/commands the
# playbook cites for the resolver idiom (GREEN step 5, VERIFY step 1) exist
# in the shipped scripts' real usage surface.
# =============================================================================

assert_true "step-text-agreement: docs/autoflow-guide.md cites 'scripts/test/suite-coverage.sh' somewhere in the phase-step text" \
  "grep -qF 'scripts/test/suite-coverage.sh' '$AUTOFLOW_GUIDE'"

assert_true "step-text-agreement: docs/autoflow-guide.md cites the '--selected' flag, and scripts/test/run-suites.sh actually accepts it" \
  "grep -qF -- '--selected' '$AUTOFLOW_GUIDE' && grep -qE -- '--selected\\)' '$RUNNER'"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
