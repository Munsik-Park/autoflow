#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/suite-coverage.sh scripts/test/run-suites.sh scripts/test/suite-manifest.sh scripts/test/check-suite-manifest.sh scripts/test/select-suites.sh scripts/test/green-tree-store.sh scripts/test/green-tree-register.sh scripts/cleanup/cleanup-issue.sh tests/test-push-context-base-ref.sh
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
#
# The walk skips DOT-PREFIXED directories for the same reason the
# definition-site scans below do: a sibling suite's fixture scratch under
# tests/fixtures/.tmp-<name>-<pid>/ holds copies of real scripts while it runs,
# and counting those copies as occurrences turns this leg red over a directory
# that is not part of the tree under review.
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
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -name '*.sh' -not -path '*/.*' -print0 2>/dev/null)

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
# Leg 5 — reason-vocabulary agreement between the resolver body and the
# resolver header's own `reason-tokens: begin/end` declaration block (the
# vocabulary's single normative home). Code-to-code only: the doc-narration
# half of this leg was retired with the doc-invariant layer.
#
# Extraction oracle (the leg's own contract, not re-derived by the
# implementation): the emitted domain is the quoted value of every
# `record["$suite"]=...` assignment on a NON-COMMENT line whose right-hand
# side carries NO parameter expansion, plus the literal reason word inside
# the body of block_fallback() (found by that function's own braces).
# =============================================================================

RESOLVER_RECORD_RE='record\["\$suite"\]="[^"]*"'

extract_resolver_emitted() { # -> declared-shape reason literals, sorted unique
  {
    grep -vE '^[[:space:]]*#' "$RESOLVER" \
      | grep -oE "$RESOLVER_RECORD_RE" \
      | sed -E 's/^.*\]="//; s/"$//' \
      | grep -vF '$'
    awk '
      /block_fallback\(\)[[:space:]]*\{/ { flag=1; next }
      flag { print }
      flag && /^[[:space:]]*\}[[:space:]]*$/ { exit }
    ' "$RESOLVER" | grep -oE 'block-fallback'
  } | sort -u
}

extract_declared_tokens() { # -> tokens between the header's begin/end markers
  awk '
    /^#[[:space:]]*reason-tokens:[[:space:]]*begin[[:space:]]*$/ { flag=1; next }
    /^#[[:space:]]*reason-tokens:[[:space:]]*end[[:space:]]*$/ { flag=0 }
    flag { print }
  ' "$RESOLVER" \
    | sed -E 's/^#[[:space:]]*//' \
    | grep -vE '^[[:space:]]*$' \
    | sort -u
}

RT_EMITTED="$(extract_resolver_emitted)"
RT_DECLARED="$(extract_declared_tokens)"
RT_MISSING_FROM_DECLARED="$(comm -23 <(printf '%s\n' "$RT_EMITTED") <(printf '%s\n' "$RT_DECLARED"))"
RT_PHANTOM_DECLARED="$(comm -13 <(printf '%s\n' "$RT_EMITTED") <(printf '%s\n' "$RT_DECLARED"))"

assert_true "reason-vocabulary: emitted ⊆ declared — every static reason literal the resolver body writes (record[\"\$suite\"]=... assignments with no parameter expansion, plus the block_fallback() printf literal) appears in the header's reason-tokens declaration block (missing: $(printf '%s' "$RT_MISSING_FROM_DECLARED" | tr '\n' ' '))" \
  "[ -z \"\$RT_MISSING_FROM_DECLARED\" ]"

assert_true "reason-vocabulary: declared ⊆ emitted — no reason-tokens entry is declared that no site in the resolver body actually writes (phantom: $(printf '%s' "$RT_PHANTOM_DECLARED" | tr '\n' ' '))" \
  "[ -z \"\$RT_PHANTOM_DECLARED\" ]"

# =============================================================================
# Leg 8 — runtime: the strings the resolver prints at run time are declared
# strings, and this gives `no-coverage` its first positive firing anywhere in
# the tree (the resolver's own --self-test names it only in a comment).
# Fixture: one committed entry covers suite B with a well-formed but
# unresolvable head (git object does not exist) and does not name suite A —
# suite A has no covering entry although n_entries > 0 (no-coverage), suite B
# has a covering entry whose head does not resolve (unresolvable-head).
# Guarded: the resolver does not exist yet at RED time.
# =============================================================================

if [ ! -f "$RESOLVER" ]; then
  assert_true "reason-vocabulary-runtime: scripts/test/suite-coverage.sh exists (cannot exercise no-coverage / unresolvable-head without it)" "false"
else
  FXRT="$(mktemp -d)"
  mkdir -p "$FXRT/tests" "$FXRT/.autoflow"
  cat > "$FXRT/tests/test-fixture-112-rr-a.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-rr-a-subject.txt
# lane: standing
# budget-secs: 5
exit 0
SH
  cat > "$FXRT/tests/test-fixture-112-rr-b.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-112-rr-b-subject.txt
# lane: standing
# budget-secs: 5
exit 0
SH
  chmod +x "$FXRT/tests/test-fixture-112-rr-a.sh" "$FXRT/tests/test-fixture-112-rr-b.sh"
  printf '.autoflow/\n' > "$FXRT/.gitignore"
  (cd "$FXRT" && git init -q && git add -A \
    && git -c user.email=t@example.com -c user.name=t commit -q -m init)

  LEDGER_RT="$FXRT/.autoflow/issue-9999-ledger.md"
  cat > "$LEDGER_RT" <<'LG'
### green-tree | cycle: 1
- tree: 1111111111111111111111111111111111111111
- head: 2222222222222222222222222222222222222222
- worktree: clean
- suites: tests/test-fixture-112-rr-b.sh
- result: 2 passed, 0 failed
- authority: Green-tree register
LG

  RT_ERR="$(mktemp)"
  bash "$RESOLVER" --ledger "$LEDGER_RT" --cycle 1 --root "$FXRT" --candidates all >/dev/null 2>"$RT_ERR"

  RT_REASON_A="$(grep -E '^RUN: tests/test-fixture-112-rr-a\.sh ' "$RT_ERR" | sed -E 's/^RUN: [^ ]+ //')"
  RT_REASON_B="$(grep -E '^RUN: tests/test-fixture-112-rr-b\.sh ' "$RT_ERR" | sed -E 's/^RUN: [^ ]+ //')"

  RT_A_DECLARED_OK=0; RT_B_DECLARED_OK=0
  printf '%s\n' "$RT_DECLARED" | grep -qxF "$RT_REASON_A" && RT_A_DECLARED_OK=1
  printf '%s\n' "$RT_DECLARED" | grep -qxF "$RT_REASON_B" && RT_B_DECLARED_OK=1

  assert_true "reason-vocabulary-runtime: the real resolver fires 'no-coverage' for a candidate no covering entry names, over a ledger with n_entries > 0 (observed: '$RT_REASON_A')" \
    "[ \"\$RT_REASON_A\" = no-coverage ]"

  assert_true "reason-vocabulary-runtime: the real resolver fires 'unresolvable-head' for a covering entry whose head is hash-shaped but not a resolvable commit (observed: '$RT_REASON_B')" \
    "[ \"\$RT_REASON_B\" = unresolvable-head ]"

  assert_true "reason-vocabulary-runtime: both observed runtime reasons are members of the header's declared reason-tokens, not a hand-written expectation (no-coverage declared: $RT_A_DECLARED_OK, unresolvable-head declared: $RT_B_DECLARED_OK)" \
    "[ \"\$RT_A_DECLARED_OK\" -eq 1 ] && [ \"\$RT_B_DECLARED_OK\" -eq 1 ]"

  rm -f "$RT_ERR"
  rm -rf "$FXRT"
fi


# =============================================================================
# Issue #130 — cross-artifact agreement for the repo-scoped shared store and
# the per-suite input-hash key. Every leg below names a drift no fixture leg
# can see: a fixture leg is scoped to one script and structurally cannot
# observe what a SECOND file defines, or fails to reach.
# =============================================================================

STORE_LIB="$PROJECT_ROOT/scripts/test/green-tree-store.sh"
REGISTER="$PROJECT_ROOT/scripts/test/green-tree-register.sh"
SELECTOR="$PROJECT_ROOT/scripts/test/select-suites.sh"
CLEANUP="$PROJECT_ROOT/scripts/cleanup/cleanup-issue.sh"

echo ""
echo "=== Issue #130 — shared store and input-hash key agreement ==="

# -----------------------------------------------------------------------------
# Leg 9 — repository-key agreement, AND the CWD at which the key is taken.
#
# The store path is $AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md,
# and <repo-key> is derived by the shipped `cleanup-issue.sh --print-repo-key`
# rather than re-typed. That subcommand resolves its root with a bare
# `git rev-parse --show-toplevel` and no `-C`, so it answers for the repository
# containing the CURRENT WORKING DIRECTORY: the CWD is a term of the call, not
# an incidental. Unpinned, a resolver given a fixture `--root` writes and reads
# a fixture store under THIS repository's key, and the symptom — a permanent
# cold start — is indistinguishable from correct fail-safe behaviour. The leg
# therefore invokes `--store-path` from a DIFFERENT directory than `--root`,
# which is the only shape in which the two answers can part.
# -----------------------------------------------------------------------------

if [ ! -f "$REGISTER" ]; then
  assert_true "repo-key-agreement: scripts/test/green-tree-register.sh exists (the store path cannot be resolved without it)" "false"
else
  FXK="$(mktemp -d)"
  ARK="$(mktemp -d)"
  mkdir -p "$FXK/tests"
  printf 'x\n' > "$FXK/tests/keep.txt"
  (cd "$FXK" && git init -q -b main && git add -A \
    && git -c user.email=t@example.com -c user.name=t commit -q -m init)

  FX_KEY="$(cd "$FXK" && bash "$CLEANUP" --print-repo-key 2>/dev/null)"
  SELF_KEY="$(cd "$PROJECT_ROOT" && bash "$CLEANUP" --print-repo-key 2>/dev/null)"
  EXPECTED_STORE="$ARK/$FX_KEY/green-trees/register.md"
  ACTUAL_STORE="$(cd "$PROJECT_ROOT" && AUTOFLOW_ARCHIVE_ROOT="$ARK" bash "$REGISTER" --store-path --root "$FXK" 2>/dev/null)"

  assert_true "repo-key-agreement: --store-path prints \$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md, the key taken by the shipped cleanup-issue.sh --print-repo-key (expected: '$EXPECTED_STORE', got: '$ACTUAL_STORE')" \
    "[ -n \"\$FX_KEY\" ] && [ \"\$ACTUAL_STORE\" = \"\$EXPECTED_STORE\" ]"

  assert_true "repo-key-agreement: the key is taken at the resolver's --root, not at the caller's CWD — invoked from this repository, --store-path still answers for the fixture repository (fixture key: '$FX_KEY', this repository's key: '$SELF_KEY')" \
    "[ -n \"\$FX_KEY\" ] && [ \"\$FX_KEY\" != \"\$SELF_KEY\" ] && printf '%s' \"\$ACTUAL_STORE\" | grep -qF \"/\$FX_KEY/\" && ! printf '%s' \"\$ACTUAL_STORE\" | grep -qF \"/\$SELF_KEY/\""

  rm -rf "$FXK" "$ARK"
fi

# -----------------------------------------------------------------------------
# Leg 10 — the glob expansion has ONE definition site, REACHED by every caller.
#
# The design collapses the two implementations to one, so a sampled-agreement
# assertion over answers now passes trivially and catches nothing. The
# reachable failure mode is a CALLER THAT STOPS REACHING THE SITE — a dropped
# source line, or a re-typed local copy shadowing it — which an
# answer-agreement leg cannot see. This leg asserts the definition count and
# then drives each caller's OWN source lines and calls the function through
# them, over an exact token, a directory token and a `**` token.
# -----------------------------------------------------------------------------

# Definition-site scans skip DOT-PREFIXED directories. A suite that builds a
# fixture repository under tests/fixtures/.tmp-<name>-<pid>/ copies real
# scripts into it for the duration of its run, and an unfiltered `grep -r`
# reads those copies as second definition sites — so a concurrent sibling
# suite, or a run interrupted before its scratch was removed, turns a
# single-site assertion red for a reason that has nothing to do with the tree
# under review. Observed against tests/fixtures/.tmp-push-context-base-ref-*.
def_sites() { # <ERE for the definition line> -> repo-relative paths, sorted
  grep -rlE "$1" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" 2>/dev/null \
    | sed "s#^$PROJECT_ROOT/##" \
    | grep -v '/\.' \
    | sort
}

GLOB_DEF_FILES="$(def_sites '^[[:space:]]*glob_matches\(\)')"

assert_true "glob-single-site: glob_matches() is defined exactly once in the tree, in scripts/test/suite-manifest.sh (definition sites: $(printf '%s' "$GLOB_DEF_FILES" | tr '\n' ' '))" \
  "[ \"\$GLOB_DEF_FILES\" = 'scripts/test/suite-manifest.sh' ]"

# glob_reaches <caller abs path> — source the caller's own `. "$SCRIPT_DIR/…"`
# lines, then call glob_matches through whatever they brought in. Nothing is
# re-typed here: the dialect's answers are the shipped function's answers.
glob_reaches() {
  local caller="$1"
  (
    SCRIPT_DIR="$(cd "$(dirname "$caller")" && pwd)"
    while IFS= read -r srcline; do
      eval "$srcline" >/dev/null 2>&1 || true
    done < <(grep -E '^[[:space:]]*\.[[:space:]]+"\$SCRIPT_DIR/[^"]+"[[:space:]]*$' "$caller")
    command -v glob_matches >/dev/null 2>&1 || exit 1
    glob_matches 'docs/subject-a.md' 'docs/subject-a.md' || exit 1
    glob_matches 'docs/subject-a.md' 'docs/subject-b.md' && exit 1
    glob_matches 'docs/' 'docs/nested/x.md' || exit 1
    glob_matches 'docs/glob/**' 'docs/glob/deep/g.md' || exit 1
    glob_matches 'docs/glob/**' 'docs/other.md' && exit 1
    exit 0
  )
}

for GLOB_CALLER in "$SELECTOR" "$RESOLVER" "$REGISTER"; do
  GLOB_CALLER_REL="${GLOB_CALLER#"$PROJECT_ROOT"/}"
  assert_true "glob-single-site: $GLOB_CALLER_REL reaches glob_matches through the file it sources, and the dialect answers correctly through it (exact / directory / ** tokens)" \
    "[ -f '$GLOB_CALLER' ] && glob_reaches '$GLOB_CALLER'"
done

# -----------------------------------------------------------------------------
# Leg 11 — the citation basis is declared in ONE place, BOTH ways.
#
# `via: <basis>` is the only textual difference between the two runs of the
# suite-grained-invalidation control pair, so a basis emitted that no
# declaration names — or declared that no site writes — leaves that control
# group unreadable while both runs still pass. The mirrored pair the reason
# vocabulary has (emitted ⊆ declared, declared ⊆ emitted) is therefore owed
# here as two legs of its own; a `citation-basis` block acquires none of it by
# sitting next to `reason-tokens`.
# -----------------------------------------------------------------------------

extract_declared_bases() {
  awk '
    /^#[[:space:]]*citation-basis:[[:space:]]*begin[[:space:]]*$/ { flag=1; next }
    /^#[[:space:]]*citation-basis:[[:space:]]*end[[:space:]]*$/ { flag=0 }
    flag { print }
  ' "$RESOLVER" \
    | sed -E 's/^#[[:space:]]*//' \
    | grep -vE '^[[:space:]]*$' \
    | sort -u
}

# Extraction oracle, stated here as the leg's own contract rather than
# re-derived by the implementation: the emitted domain is the quoted value of
# every `record["$suite"]=...` assignment on a NON-COMMENT line — the same
# record-site restriction the reason vocabulary uses. It must NOT be a
# whole-file `via:` grep: this script's own --self-test carries `via: <basis>`
# inside executable grep patterns, which the non-comment rule cannot exclude
# and which would make every basis look emitted whatever the body writes.
extract_emitted_bases() {
  grep -vE '^[[:space:]]*#' "$RESOLVER" \
    | grep -oE "$RESOLVER_RECORD_RE" \
    | grep -oE 'via: [a-z][a-z-]*' \
    | sed -E 's/^via: //' \
    | sort -u
}

CB_DECLARED="$(extract_declared_bases)"
CB_EMITTED="$(extract_emitted_bases)"
CB_MISSING="$(comm -23 <(printf '%s\n' "$CB_EMITTED") <(printf '%s\n' "$CB_DECLARED"))"
CB_PHANTOM="$(comm -13 <(printf '%s\n' "$CB_EMITTED") <(printf '%s\n' "$CB_DECLARED"))"

assert_true "citation-basis: the resolver header carries a citation-basis: begin/end declaration block, beside reason-tokens, naming the bases the records carry (declared: $(printf '%s' "$CB_DECLARED" | tr '\n' ' '))" \
  "[ -n \"\$CB_DECLARED\" ]"

assert_true "citation-basis: emitted ⊆ declared — every via: basis the resolver body writes appears in the declaration block (missing: $(printf '%s' "$CB_MISSING" | tr '\n' ' '))" \
  "[ -n \"\$CB_DECLARED\" ] && [ -n \"\$CB_EMITTED\" ] && [ -z \"\$CB_MISSING\" ]"

assert_true "citation-basis: declared ⊆ emitted — no basis is declared that no site in the resolver body actually writes (phantom: $(printf '%s' "$CB_PHANTOM" | tr '\n' ' '))" \
  "[ -n \"\$CB_DECLARED\" ] && [ -n \"\$CB_EMITTED\" ] && [ -z \"\$CB_PHANTOM\" ]"

# -----------------------------------------------------------------------------
# Leg 12 — the repository key and the in-repo refusal are CALLED, never
# re-typed. The guard has exactly one subject ($AUTOFLOW_ARCHIVE_ROOT) and the
# store lives beneath that same value, so there is nothing for two
# implementations to agree about — a second copy could only disagree. What is
# reachable is the store library re-typing either one, or ceasing to call the
# site at all; a fixture leg scoped to one script cannot observe that.
# -----------------------------------------------------------------------------

KEY_DEF_FILES="$(def_sites '^[[:space:]]*derive_repo_key\(\)')"
PHYS_DEF_FILES="$(def_sites '^[[:space:]]*physical_path\(\)')"

assert_true "single-site: derive_repo_key() is defined exactly once, in scripts/cleanup/cleanup-issue.sh, and the store library reaches it by invoking that script rather than re-typing it (definition sites: $(printf '%s' "$KEY_DEF_FILES" | tr '\n' ' '))" \
  "[ \"\$KEY_DEF_FILES\" = 'scripts/cleanup/cleanup-issue.sh' ] && [ -f '$STORE_LIB' ] && grep -qF 'cleanup-issue.sh' '$STORE_LIB' && ! grep -qE '^[[:space:]]*derive_repo_key\\(\\)' '$STORE_LIB'"

assert_true "single-site: physical_path() — the in-repo refusal's path canonicalization — is defined exactly once, in scripts/cleanup/cleanup-issue.sh, and the store library reaches the refusal by invoking that script rather than re-typing it (definition sites: $(printf '%s' "$PHYS_DEF_FILES" | tr '\n' ' '))" \
  "[ \"\$PHYS_DEF_FILES\" = 'scripts/cleanup/cleanup-issue.sh' ] && [ -f '$STORE_LIB' ] && grep -qF 'cleanup-issue.sh' '$STORE_LIB' && ! grep -qE '^[[:space:]]*physical_path\\(\\)' '$STORE_LIB'"

# -----------------------------------------------------------------------------
# Leg 15 — composition, extended: the ENTRY carries `<path>@<input-hash>`
# tokens while the PLAN carries bare repo-relative paths. The plan is consumed
# directly as a path list by run-suites.sh --selected, so a token echoed in
# place of its path hands the runner a file that does not exist — silent in
# the resolver, and surfacing only one layer downstream. The covering entry
# names two of three suites, so the leg needs the parsed lookup to work (an
# unparsed token covers nothing and the plan widens to all three).
# -----------------------------------------------------------------------------

if [ ! -f "$RESOLVER" ] || [ ! -f "$STORE_LIB" ]; then
  assert_true "hashed-token-composition: the resolver and the store library exist (the hashed-token plan cannot be exercised without them)" "false"
else
  FXH="$(mktemp -d)"
  # SCRATCH LIVES OUTSIDE THE FIXTURE REPOSITORY. Every artefact this leg
  # produces during the run — the witness log and the plan file — is written
  # to a sibling directory, never under $FXH. A plan file inside the fixture
  # is not a tidiness question: the shell creates and truncates a redirect's
  # target BEFORE the command runs, so `> "$FXH/run-set.txt"` leaves an
  # untracked file in the worktree at the instant the resolver takes its
  # capture point. Resolution order step 3 then routes every candidate to RUN
  # with reason `dirty-worktree`, before any store read — and the leg reads
  # as "the hashed tokens were not parsed" when nothing about token parsing
  # was exercised at all. (Observed at VERIFY round-trip 1 on tree 7b0f4abe.)
  FXH_SCRATCH="$(mktemp -d)"
  mkdir -p "$FXH/tests" "$FXH/.autoflow"
  WITNESS_H="$FXH_SCRATCH/witness.log"
  : > "$WITNESS_H"
  for hn in a b c; do
    cat > "$FXH/tests/test-fixture-130-hash-$hn.sh" <<SH
#!/usr/bin/env bash
# ci-subject: tests/fixture-130-hash-$hn-subject.txt
# lane: standing
# budget-secs: 5
echo "\$0" >> "$WITNESS_H"
exit 0
SH
    chmod +x "$FXH/tests/test-fixture-130-hash-$hn.sh"
    printf 'x\n' > "$FXH/tests/fixture-130-hash-$hn-subject.txt"
  done
  printf '.autoflow/\n' > "$FXH/.gitignore"
  (cd "$FXH" && git init -q -b main && git add -A \
    && git -c user.email=t@example.com -c user.name=t commit -q -m init)

  FXH_TREE="$(git -C "$FXH" rev-parse 'HEAD^{tree}')"
  FXH_HEAD="$(git -C "$FXH" rev-parse HEAD)"
  # The tokens are minted by the SHIPPED single site, never re-typed here.
  FXH_TOKENS=""
  for hn in a b; do
    FXH_HASH="$(
      SCRIPT_DIR="$PROJECT_ROOT/scripts/test"
      # shellcheck source=/dev/null
      . "$PROJECT_ROOT/scripts/test/suite-manifest.sh" 2>/dev/null
      # shellcheck source=/dev/null
      . "$STORE_LIB" 2>/dev/null
      command -v suite_input_hash >/dev/null 2>&1 \
        && suite_input_hash "$FXH" "$FXH_TREE" "tests/test-fixture-130-hash-$hn.sh"
    )"
    FXH_TOKENS="$FXH_TOKENS${FXH_TOKENS:+ }tests/test-fixture-130-hash-$hn.sh@$FXH_HASH"
  done

  LEDGER_H="$FXH/.autoflow/issue-9999-ledger.md"
  {
    printf '### green-tree | cycle: 1 | runner: VERIFY step 1\n'
    printf -- '- tree: %s\n' "$FXH_TREE"
    printf -- '- head: %s\n' "$FXH_HEAD"
    printf -- '- worktree: clean\n'
    printf -- '- suites: %s\n' "$FXH_TOKENS"
    printf -- '- result: run-suites: 2 passed, 0 failed, 0 timed out, of 2 executed\n'
    printf -- '- authority: Green-tree register\n\n'
  } > "$LEDGER_H"

  PLAN_FILE_H="$FXH_SCRATCH/run-set.txt"
  ARH="$(mktemp -d)"
  AUTOFLOW_ARCHIVE_ROOT="$ARH" bash "$RESOLVER" --ledger "$LEDGER_H" --cycle 1 --root "$FXH" \
    --candidates all > "$PLAN_FILE_H" 2>/dev/null
  PLAN_SET_H="$(sort -u "$PLAN_FILE_H" 2>/dev/null)"

  assert_true "hashed-token-composition: the entry's @<input-hash> tokens are parsed, so the plan narrows to the one uncovered suite and carries BARE repo-relative paths (tokens: '$FXH_TOKENS' | plan: $(printf '%s' "$PLAN_SET_H" | tr '\n' ' '))" \
    "[ \"\$PLAN_SET_H\" = 'tests/test-fixture-130-hash-c.sh' ] && ! printf '%s\\n' \"\$PLAN_SET_H\" | grep -q '@'"

  bash "$RUNNER" --root "$FXH" --selected "$PLAN_FILE_H" > /tmp/issue130-hash-runner.out 2>&1
  EXECUTED_SET_H="$(sort "$WITNESS_H" 2>/dev/null | sed "s#^$FXH/##" | sort -u)"

  assert_true "hashed-token-composition: that plan, fed to the real run-suites.sh --selected, executes exactly the planned set (executed: $(printf '%s' "$EXECUTED_SET_H" | tr '\n' ' ') | plan: $(printf '%s' "$PLAN_SET_H" | tr '\n' ' '))" \
    "[ \"\$EXECUTED_SET_H\" = \"\$PLAN_SET_H\" ]"

  rm -rf "$FXH" "$FXH_SCRATCH" "$ARH"
fi

# -----------------------------------------------------------------------------
# Leg 16 — cross-issue cold start, on THIS repository. The hermetic half lives
# in the resolver's own self-test; this half is what makes the criterion's
# "real output" wording true — the shipped resolver, this repository's own
# root, the real repository key, and a store seeded at the captured clean tree
# by a hypothetical prior issue.
#
# DECIDABILITY: resolution order step 3 routes a dirty worktree to RUN before
# any store read, so the empty-plan assertion is false on any checkout with
# uncommitted changes. The disposition is an EXPLICIT REPORTED SKIP naming the
# dirty worktree — a silent skip would make the leg green wherever a human
# runs it and executed only where nobody watches. Step 3 is not relaxed to
# rescue the leg.
#
# The expected plan is NOT empty: a suite declaring `out-of-tree-inputs: yes`
# executes unconditionally, ahead of every store read. The leg therefore
# derives its expectation from the shipped declaration rather than asserting a
# literal emptiness the floor forbids.
# -----------------------------------------------------------------------------

REAL_DIRTY="$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null)"
if [ -n "$REAL_DIRTY" ]; then
  echo "  SKIP: cross-issue-cold-start (real repository) — the worktree is dirty, and resolution order step 3 routes a dirty worktree to RUN before any store read, so the assertion is not decidable here"
elif [ ! -f "$STORE_LIB" ]; then
  assert_true "cross-issue-cold-start: scripts/test/green-tree-store.sh exists (the shared store cannot be read without it)" "false"
else
  ARR="$(mktemp -d)"
  REAL_KEY="$(cd "$PROJECT_ROOT" && bash "$CLEANUP" --print-repo-key 2>/dev/null)"
  REAL_STORE="$ARR/$REAL_KEY/green-trees/register.md"
  mkdir -p "$(dirname "$REAL_STORE")"
  REAL_TREE="$(git -C "$PROJECT_ROOT" rev-parse 'HEAD^{tree}')"
  REAL_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"

  REAL_ENUM="$(
    # shellcheck source=/dev/null
    . "$MANIFEST_LIB" 2>/dev/null
    suite_enumerate "$PROJECT_ROOT"
  )"
  REAL_OOT="$(
    # shellcheck source=/dev/null
    . "$MANIFEST_LIB" 2>/dev/null
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      [ "$(suite_header_field "$PROJECT_ROOT/$s" out-of-tree-inputs 2>/dev/null || true)" = yes ] && printf '%s\n' "$s"
    done <<< "$REAL_ENUM"
  )"
  REAL_OOT="$(printf '%s\n' "$REAL_OOT" | grep -c . || true)"

  {
    printf '### green-tree-shared | issue: #129 | cycle: 1 | runner: VERIFY step 1\n'
    printf -- '- tree: %s\n' "$REAL_TREE"
    printf -- '- head: %s\n' "$REAL_HEAD"
    printf -- '- worktree: clean\n'
    printf -- '- suites: %s\n' "$(printf '%s\n' "$REAL_ENUM" | tr '\n' ' ' | sed 's/ *$//')"
    printf -- '- result: run-suites: %s passed, 0 failed, 0 timed out, of %s executed\n' \
      "$(printf '%s\n' "$REAL_ENUM" | grep -c .)" "$(printf '%s\n' "$REAL_ENUM" | grep -c .)"
    printf -- '- authority: Green-tree register (shared store)\n\n'
  } > "$REAL_STORE"

  REAL_LEDGER="$(mktemp)"
  : > "$REAL_LEDGER"
  REAL_ERR="$(mktemp)"
  REAL_PLAN="$(AUTOFLOW_ARCHIVE_ROOT="$ARR" bash "$RESOLVER" --root "$PROJECT_ROOT" \
    --ledger "$REAL_LEDGER" --cycle 1 --candidates all 2>"$REAL_ERR")"
  REAL_PLAN_N="$(printf '%s\n' "$REAL_PLAN" | grep -c . || true)"
  REAL_INHERIT_N="$(grep -cE 'via: shared-tree( |$)' "$REAL_ERR" || true)"
  REAL_ENUM_N="$(printf '%s\n' "$REAL_ENUM" | grep -c .)"

  assert_true "cross-issue-cold-start: on a clean checkout of THIS repository, a shared entry a prior issue could have written — read through an EMPTY per-issue ledger — leaves nothing to run but the suites that declare out-of-tree inputs (planned: $REAL_PLAN_N, declared out-of-tree: $REAL_OOT, enumerated: $REAL_ENUM_N)" \
    "[ \"\$REAL_PLAN_N\" -eq \"\$REAL_OOT\" ]"

  assert_true "cross-issue-cold-start: every suite not planned is recorded INHERIT citing the shared entry, so the empty run set is attributable to the shared arm rather than to a resolver that produced nothing (via: shared-tree records: $REAL_INHERIT_N of $REAL_ENUM_N enumerated)" \
    "[ \"\$REAL_INHERIT_N\" -eq \$(( REAL_ENUM_N - REAL_OOT )) ]"

  rm -f "$REAL_LEDGER" "$REAL_ERR"
  rm -rf "$ARR"
fi

# =============================================================================
# Leg 17 — the archive-root half of the printed store path is anchored on the
# guard's --root, not the consuming process's cwd (issue #130 cycle 2, review
# finding). Fixture shape: .autoflow/issue-130-verification-design.md >
# "Fixture shape shared by the three new legs" — containment (fixture repo,
# archive root, ledger and every driving cwd share one mktemp -d scratch) and
# discrimination (the driving cwd, SCR/a/cwd, is NOT a sibling of SCR/repo, so
# a relative `../ark` names a different directory depending on the anchor).
# =============================================================================
echo ""

SCR17="$(mktemp -d)"
mkdir -p "$SCR17/repo" "$SCR17/ark" "$SCR17/a/cwd" "$SCR17/a/ark"
printf 'x\n' > "$SCR17/repo/keep.txt"
(cd "$SCR17/repo" && git init -q -b main && git add -A \
  && git -c user.email=t@example.com -c user.name=t commit -q -m init) >/dev/null

if [ ! -f "$REGISTER" ] || [ ! -f "$CLEANUP" ]; then
  assert_true "anchored-prefix: scripts/test/green-tree-register.sh and scripts/cleanup/cleanup-issue.sh exist (the anchoring leg cannot be driven without them)" "false"
else
  A17_KEY="$(cd "$SCR17/repo" && bash "$CLEANUP" --print-repo-key 2>/dev/null)"
  A17_OUT="$(cd "$SCR17/a/cwd" && AUTOFLOW_ARCHIVE_ROOT=../ark bash "$REGISTER" --store-path --root "$SCR17/repo" 2>/dev/null)"
  A17_SUFFIX="/$A17_KEY/green-trees/register.md"
  case "$A17_OUT" in
    *"$A17_SUFFIX") A17_PREFIX="${A17_OUT%$A17_SUFFIX}" ;;
    *) A17_PREFIX="" ;;
  esac
  A17_RIGHT="$(cd "$SCR17/ark" && pwd -P)"
  A17_WRONG="$(cd "$SCR17/a/ark" && pwd -P)"
  A17_RESOLVED=""
  [ -n "$A17_PREFIX" ] && A17_RESOLVED="$(cd "$A17_PREFIX" 2>/dev/null && pwd -P)"

  assert_true "AC-anchored-prefix: a relative \$AUTOFLOW_ARCHIVE_ROOT is resolved against --root, not the caller's cwd — --store-path invoked from a cwd that differs from --root, with 'ark' reachable both ways (key='$A17_KEY', printed='$A17_OUT', resolved-prefix='$A17_RESOLVED', expected(--root anchor)='$A17_RIGHT', caller-cwd-interpretation='$A17_WRONG')" \
    "[ -n \"\$A17_KEY\" ] && [ -n \"\$A17_RESOLVED\" ] && [ \"\$A17_RESOLVED\" = \"\$A17_RIGHT\" ] && [ \"\$A17_RESOLVED\" != \"\$A17_WRONG\" ]"

  assert_true "AC-absolute-answer: the printed store path begins with '/', openable from any cwd (printed='$A17_OUT')" \
    "case \"\$A17_OUT\" in /*) true ;; *) false ;; esac"
fi
rm -rf "$SCR17"

# =============================================================================
# Leg 18 — round trip: a write (--append) from one cwd and a read (--match)
# from a different cwd, both driven by the same relative $AUTOFLOW_ARCHIVE_ROOT
# and the same --root, must agree on where the bytes live
# (.autoflow/issue-130-verification-design.md > "write and read agree across
# cwds"). This is the layer no printed-value assertion reaches: the writer and
# the resolver each open the store in their OWN process, so only observing the
# actual landing site — and both repositories' own porcelain — catches a
# consumer that addresses a location the printed value does not name.
# =============================================================================
echo ""

SCR18="$(mktemp -d)"
mkdir -p "$SCR18/repo" "$SCR18/ark" "$SCR18/a/cwd" "$SCR18/b/cwd"
printf 'x\n' > "$SCR18/repo/keep.txt"
(cd "$SCR18/repo" && git init -q -b main && git add -A \
  && git -c user.email=t@example.com -c user.name=t commit -q -m init) >/dev/null

if [ ! -f "$REGISTER" ] || [ ! -f "$CLEANUP" ]; then
  assert_true "round-trip: scripts/test/green-tree-register.sh and scripts/cleanup/cleanup-issue.sh exist (the round-trip leg cannot be driven without them)" "false"
else
  R18_TREE="$(git -C "$SCR18/repo" rev-parse 'HEAD^{tree}')"
  R18_HEAD="$(git -C "$SCR18/repo" rev-parse HEAD)"
  R18_KEY="$(cd "$SCR18/repo" && bash "$CLEANUP" --print-repo-key 2>/dev/null)"
  R18_EXPECTED_STORE="$SCR18/ark/$R18_KEY/green-trees/register.md"
  R18_PORC_SELF_BEFORE="$(cd "$PROJECT_ROOT" && git status --porcelain)"
  R18_PORC_FX_BEFORE="$(cd "$SCR18/repo" && git status --porcelain)"

  (cd "$SCR18/a/cwd" \
    && AUTOFLOW_ARCHIVE_ROOT=../ark bash "$REGISTER" \
      --append --root "$SCR18/repo" --ledger "$SCR18/ledger.md" --issue 130 --cycle 2 \
      --runner "RED leg-18" --tree "$R18_TREE" --head "$R18_HEAD" \
      --result "run-suites: 1 passed, 0 failed, 0 timed out, of 1 executed" \
      --suites "keep.txt") >/dev/null 2>&1

  R18_MATCH_OUT="$(cd "$SCR18/b/cwd" && AUTOFLOW_ARCHIVE_ROOT=../ark bash "$REGISTER" --match --root "$SCR18/repo" 2>/dev/null)"
  R18_MATCH_RC=$?

  R18_PORC_SELF_AFTER="$(cd "$PROJECT_ROOT" && git status --porcelain)"
  R18_PORC_FX_AFTER="$(cd "$SCR18/repo" && git status --porcelain)"
  R18_REGISTER_COUNT="$(find "$SCR18" -name register.md 2>/dev/null | grep -c .)"

  assert_true "the-write-and-read-agree-across-cwds: --match (cwd b) exits 0 and prints the shared entry's heading written by --append (cwd a) — same relative \$AUTOFLOW_ARCHIVE_ROOT, different cwds (match rc=$R18_MATCH_RC, output: '$R18_MATCH_OUT')" \
    "[ \"\$R18_MATCH_RC\" -eq 0 ] && printf '%s' \"\$R18_MATCH_OUT\" | grep -qF 'issue: #130 | cycle: 2 | runner: RED leg-18'"

  assert_true "AC-single-anchor: the register file lands at exactly one path under scratch — \$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md resolved at --root, and at no other location a wrongly-anchored write could reach (found under scratch: $R18_REGISTER_COUNT, expected path exists: $([ -f "$R18_EXPECTED_STORE" ] && echo yes || echo no))" \
    "[ \"\$R18_REGISTER_COUNT\" -eq 1 ] && [ -f \"\$R18_EXPECTED_STORE\" ]"

  assert_true "round-trip: neither this repository's nor the fixture repository's porcelain moved across the write+read — a guard-bypassed write would make the store tracked content and a dirty-worktree contributor at a capture point" \
    "[ \"\$R18_PORC_SELF_BEFORE\" = \"\$R18_PORC_SELF_AFTER\" ] && [ \"\$R18_PORC_FX_BEFORE\" = \"\$R18_PORC_FX_AFTER\" ]"
fi
rm -rf "$SCR18"

# =============================================================================
# Leg 19 — resolution does not require the archive root to exist on disk, and
# does not create it (.autoflow/issue-130-verification-design.md >
# "resolution does not require the root to exist"). Every other leg in this
# file builds its archive root with `mktemp -d`, so the root is already
# present in all of them; this is the only leg to drive the first-call-in-a-
# fresh-environment shape, and the only one to assert the absence
# post-condition — a print-and-exit-0 assertion alone cannot see a resolver
# that materializes the root on the way to answering.
# =============================================================================
echo ""

SCR19="$(mktemp -d)"
mkdir -p "$SCR19/repo"
printf 'x\n' > "$SCR19/repo/keep.txt"
(cd "$SCR19/repo" && git init -q -b main && git add -A \
  && git -c user.email=t@example.com -c user.name=t commit -q -m init) >/dev/null

if [ ! -f "$REGISTER" ]; then
  assert_true "non-existent-root: scripts/test/green-tree-register.sh exists (the non-existent-root leg cannot be driven without it)" "false"
else
  N19_ABSENT="$SCR19/absent/ark"
  N19_OUT="$(AUTOFLOW_ARCHIVE_ROOT="$N19_ABSENT" bash "$REGISTER" --store-path --root "$SCR19/repo" 2>/dev/null)"
  N19_RC=$?

  assert_true "AC-nonexistent-root: an \$AUTOFLOW_ARCHIVE_ROOT that does not exist on disk still resolves — an absolute path is printed and the exit is 0, the shape of the first call in a fresh environment where the default \$HOME/.autoflow is absent (rc=$N19_RC, printed='$N19_OUT')" \
    "[ \"\$N19_RC\" -eq 0 ] && case \"\$N19_OUT\" in /*) true ;; *) false ;; esac"

  assert_true "AC-nonexistent-root (purity post-condition): resolving the path does not materialize it — \$SCR19/absent stays absent after the query, so a resolver that mkdir's its way to an answer would be caught here even though it would satisfy the print-and-exit-0 half above" \
    "[ ! -e \"\$SCR19/absent\" ]"
fi
rm -rf "$SCR19"

# =============================================================================
# Leg 20 — an operator-supplied trailing slash on $AUTOFLOW_ARCHIVE_ROOT does
# not compose a doubled slash before <repo-key> (issue #130 cycle 2, VERIFY
# step 3 — .autoflow/issue-130-c2-verify-report.md: the "${prefix%/}" trim in
# scripts/test/green-tree-store.sh:113 had no leg driving a trailing-slash
# input). The composed path must also still resolve to the guarded directory,
# trailing slash notwithstanding.
# =============================================================================
echo ""

SCR20="$(mktemp -d)"
mkdir -p "$SCR20/repo" "$SCR20/ark"
printf 'x\n' > "$SCR20/repo/keep.txt"
(cd "$SCR20/repo" && git init -q -b main && git add -A \
  && git -c user.email=t@example.com -c user.name=t commit -q -m init) >/dev/null

if [ ! -f "$REGISTER" ]; then
  assert_true "trailing-slash: scripts/test/green-tree-register.sh exists (the trailing-slash leg cannot be driven without it)" "false"
else
  T20_OUT="$(AUTOFLOW_ARCHIVE_ROOT="$SCR20/ark/" bash "$REGISTER" --store-path --root "$SCR20/repo" 2>/dev/null)"
  T20_RIGHT="$(cd "$SCR20/ark" && pwd -P)"
  T20_RESOLVED=""
  case "$T20_OUT" in
    *green-trees/register.md)
      T20_PREFIX="${T20_OUT%/green-trees/register.md}"
      T20_PREFIX="${T20_PREFIX%/*}"
      T20_RESOLVED="$(cd "$T20_PREFIX" 2>/dev/null && pwd -P)"
      ;;
  esac

  assert_true "trailing-slash-no-double: an operator-supplied trailing slash on \$AUTOFLOW_ARCHIVE_ROOT does not compose a doubled slash before <repo-key> (printed='$T20_OUT')" \
    "case \"\$T20_OUT\" in *//*) false ;; *) true ;; esac"

  assert_true "trailing-slash-still-anchored: the printed path, trailing slash notwithstanding, still resolves to the accepted archive root (resolved='$T20_RESOLVED', expected='$T20_RIGHT')" \
    "[ -n \"\$T20_RESOLVED\" ] && [ \"\$T20_RESOLVED\" = \"\$T20_RIGHT\" ]"
fi
rm -rf "$SCR20"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
