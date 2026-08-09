#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: Verification-depth justification at ARCHITECT / GATE:PLAN — Issue #69 (cycle-scoped)
# =============================================================================
# Cycle-scoped count/delta/diff/agreement predicates per the verification design
# (.autoflow/issue-69-verification-design.md). Simple shipped-text present/absent checks
# (the clause's risk/per-layer-failure-mode/removal-consequence literals, the Test AI
# contract mirror, and the GATE:PLAN mirror-home widening in docs/evaluation-system.md /
# docs/teammate-contracts.md) live in the PERMANENT registry
# (tests/fixtures/doc-invariants.json, ids "69-AC-*") — this suite carries the
# agreement/derivation-shaped criteria the registry structurally rejects: the ADR
# registry-home agreement, CI registration, the GATE:PLAN Scope sentence widening
# (sentence-scoped, not whole-section — the section also carries a pre-existing
# "verification design" occurrence in its ARCHITECT-input line, which a whole-section
# present/absent registry entry cannot distinguish from the target sentence), the
# amendment-route excerpt check, the rubric/composition-oracle invariance fences, the
# manifest and doc-invariant-registry composition oracles, the derived harness ok-count
# pin-agreement sweep, and the branch-scoped change-surface guard.
#
# Known-RED mid-cycle: the ADR file (docs/adr/0018-*.md) and its four registration rows,
# the GATE:PLAN Scope sentence widening, the mirror-home literals, and the two run.mjs
# prompt-delivery assertions are all GREEN-phase work — every assertion that depends on
# them is expected FAIL until GREEN lands, documented in-line, not a defect (mirrors the
# #62/#67 known-RED idiom).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EVAL_SYSTEM="$PROJECT_ROOT/docs/evaluation-system.md"
TEAMMATE_CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
ADR_README="$PROJECT_ROOT/docs/adr/README.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"

source "$PROJECT_ROOT/tests/lib/base-ref.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"

# Shared guard for the three branch-scoped checks below (AC:rubric-unchanged,
# AC:oracle-clause-untouched, change-surface-bounded): each is this cycle's own PR
# contract and stays inert off the issue-69 dev branch.
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-69|dev/*-issue-69-*) return 0 ;;
    *) return 1 ;;
  esac
}

# =============================================================================
echo "=== AC:adr-registration — the new verification-depth ADR is registered in all four homes that enumerate ADRs individually ==="

# Derived, not hard-coded (verification design method column): ls the ADR directory for a
# filename matching the topic slug rather than asserting the literal "0018-..." — a
# renumbered ADR still satisfies the criterion.
NEW_ADR_PATH="$(ls "$PROJECT_ROOT"/docs/adr/00*-verification-depth*.md 2>/dev/null | head -1)"
if [ -n "$NEW_ADR_PATH" ]; then
  NEW_ADR_BASENAME="$(basename "$NEW_ADR_PATH")"
else
  NEW_ADR_BASENAME="__no-verification-depth-adr-found__"
fi
echo "  derived ADR filename: $NEW_ADR_BASENAME"

assert_true "AC-69-ADR-readme: docs/adr/README.md Current Drafts names $NEW_ADR_BASENAME" \
  "grep -qF \"$NEW_ADR_BASENAME\" '$ADR_README'"
assert_true "AC-69-ADR-maintained: docs/maintained-docs.md > ADRs names $NEW_ADR_BASENAME" \
  "grep -qF \"$NEW_ADR_BASENAME\" '$MAINTAINED_DOCS'"
assert_true "AC-69-ADR-index: docs/INDEX.md AutoFlow-rules routing row names $NEW_ADR_BASENAME" \
  "grep -qF \"docs/adr/$NEW_ADR_BASENAME\" '$INDEX_MD'"
assert_true "AC-69-ADR-manifest: setup/manifest.json carries one artifacts[] row for docs/adr/$NEW_ADR_BASENAME" \
  "[ \"\$(jq -r --arg s \"docs/adr/$NEW_ADR_BASENAME\" '[.artifacts[] | select(.source==\$s)] | length' '$MANIFEST')\" = 1 ]"

# =============================================================================
echo ""
echo "=== AC:ci-registration — this suite is registered in e2e-dummy-target.yml at all three sites ==="

PR_PATHS_COUNT="$(awk '/^  pull_request:/{f=1} f&&/^  push:/{f=0} f' "$CI_WORKFLOW" | grep -cF "tests/test-issue-69-verification-depth.sh" || true)"
PUSH_PATHS_COUNT="$(awk '/^  push:/{f=1} f' "$CI_WORKFLOW" | grep -cF "tests/test-issue-69-verification-depth.sh" || true)"
RUN_STEP_COUNT="$(grep -cF "run: bash tests/test-issue-69-verification-depth.sh" "$CI_WORKFLOW" || true)"
assert_true "AC-69-CI-pr: e2e-dummy-target.yml pull_request paths: block admits this suite (got: $PR_PATHS_COUNT)" \
  "[ \"$PR_PATHS_COUNT\" -ge 1 ]"
assert_true "AC-69-CI-push: e2e-dummy-target.yml push paths: block admits this suite (got: $PUSH_PATHS_COUNT)" \
  "[ \"$PUSH_PATHS_COUNT\" -ge 1 ]"
assert_true "AC-69-CI-run: e2e-dummy-target.yml has a run: step invoking this suite (got: $RUN_STEP_COUNT)" \
  "[ \"$RUN_STEP_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC:scope-symmetry — the GATE:PLAN Scope interpretive sentence widens its subject to name the verification design ==="

# Sentence-scoped, not section-scoped: docs/autoflow-guide.md's GATE:PLAN section ALSO
# carries a pre-existing, unrelated "verification design" occurrence ("Input: feature
# design + verification design from ARCHITECT."), so a whole-section registry present
# check for that phrase would already PASS before GREEN lands — a false green. Extracting
# the specific interpretive sentence by its own fixed anchor and checking THAT excerpt
# avoids the false positive.
SCOPE_SENTENCE="$(grep -F 'duplicates an existing mechanism or over-engineers a new one where an extension suffices fails Scope' "$AUTOFLOW_GUIDE" || true)"
SCOPE_SENTENCE_FOUND="no"; [ -n "$SCOPE_SENTENCE" ] && SCOPE_SENTENCE_FOUND="yes"
# Reference by NAME in a single-quoted condition (deferred expansion inside assert_true's
# own subshell) rather than splicing the raw doc excerpt into the command string here —
# the sentence contains markdown backticks/parens that eval would otherwise re-parse as
# shell syntax (command substitution / a stray `(`).
assert_true "AC-69-SCOPE-SYMMETRY: the Scope over-engineering sentence names the verification design (found sentence: $SCOPE_SENTENCE_FOUND)" \
  'printf "%s" "$SCOPE_SENTENCE" | grep -q "verification design"'

# =============================================================================
echo ""
echo "=== AC:amendment-home — the amendment route names the issue register and does not name the ledger file directly ==="

# Anchored on the feature design's own quoted clause phrase ("may raise depth"); the
# excerpt is empty pre-GREEN, which correctly reds the register-named half below.
AMEND_EXCERPT="$(grep -A6 'may raise depth' "$AUTOFLOW_GUIDE" || true)"
# Referenced by NAME (see the AC-69-SCOPE-SYMMETRY comment above) — the excerpt is
# arbitrary doc prose once GREEN lands it.
assert_true "AC-69-AMENDMENT-HOME: amendment clause names the issue register and does not name .autoflow/issue-*-ledger.md directly" \
  'printf "%s" "$AMEND_EXCERPT" | grep -q "issue register" && ! printf "%s" "$AMEND_EXCERPT" | grep -qE "\.autoflow/issue-[^ ]*-ledger\.md"'

# =============================================================================
echo ""
echo "=== AC:no-quantity-cap — the Verification depth clause introduces no numeric layer/file/line cap, digit- or word-form ==="

# Moved here from the permanent registry (GATE:QUALITY attempt-2 finding): absent +
# match:"regex" has no negative-teeth-harness-injectable witness
# (tests/test-issue-951-registry.sh, FINDING 3-E) — the registry's teeth leg requires every
# entry to demonstrably FAIL against a mutated fixture, and there is no single-mutation
# witness for "a regex whose whole POINT is matching several literal shapes at once". The
# cycle suite has no such constraint, and covers the property HONESTLY per the finding: both
# digit ("at most 3 layers") and word-number ("at most three layers") cap forms, not just
# the digit form the retired registry regex alone caught.
VERIFICATION_DEPTH_SECTION="$(awk '/^#### Verification depth/{f=1} f&&/^#### Composition oracle/{f=0} f' "$AUTOFLOW_GUIDE")"
CAP_PATTERN='\b(at most|no more than|maximum of|up to) (one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+) (layers?|files?|lines?)\b'
assert_true "AC-69-NO-QUANTITY-CAP: the Verification depth section introduces no digit- or word-form layer/file/line cap" \
  '! printf "%s" "$VERIFICATION_DEPTH_SECTION" | grep -qE "$CAP_PATTERN"'

# =============================================================================
echo ""
echo "=== AC:rubric-unchanged — the GATE:PLAN rubric row set, PASS thresholds, and Regressions max-N multiset are unchanged from the base ref ==="

if on_issue_branch; then
  BASE_REF="$(resolve_base_ref)" || {
    echo "  BLOCK: no comparison base resolvable — AC-69-RUBRIC counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
    BASE_REF=""
  }
  if [[ -n "$BASE_REF" ]]; then
    ROWS_HEAD="$(awk '/^### Scoring \(5 items × 10 points\)/{f=1;c++} c==1&&f{print} /^### ADR-conformance check/{if(c==1)f=0}' "$AUTOFLOW_GUIDE" | grep -oE '^\| (Feasibility|Dependencies|Scope|Security|Test plan) ' | sort -u)"
    ROWS_BASE="$(git show "$BASE_REF:docs/autoflow-guide.md" | awk '/^### Scoring \(5 items × 10 points\)/{f=1;c++} c==1&&f{print} /^### ADR-conformance check/{if(c==1)f=0}' | grep -oE '^\| (Feasibility|Dependencies|Scope|Security|Test plan) ' | sort -u)"
    assert_true "AC-69-RUBRIC-rows: GATE:PLAN's 5 rubric row names are unchanged from $BASE_REF" \
      '[ "$ROWS_HEAD" = "$ROWS_BASE" ]'
    THRESH_HEAD="$(grep -c 'avg ≥ 7.5, each ≥ 7' "$AUTOFLOW_GUIDE" || true)"
    THRESH_BASE="$(git show "$BASE_REF:docs/autoflow-guide.md" | grep -c 'avg ≥ 7.5, each ≥ 7' || true)"
    assert_true "AC-69-RUBRIC-thresholds: PASS threshold phrasing count is unchanged (head: $THRESH_HEAD, base: $THRESH_BASE)" \
      "[ \"$THRESH_HEAD\" = \"$THRESH_BASE\" ]"
    REGR_HEAD="$(grep -oE 'GATE:PLAN FAIL → ARCHITECT \(max [0-9]+×[^)]*\)' "$CLAUDE_MD" || true)"
    REGR_BASE="$(git show "$BASE_REF:CLAUDE.md" | grep -oE 'GATE:PLAN FAIL → ARCHITECT \(max [0-9]+×[^)]*\)' || true)"
    assert_true "AC-69-RUBRIC-regressions: GATE:PLAN's Regressions max-N clause is unchanged from $BASE_REF" \
      '[ "$REGR_HEAD" = "$REGR_BASE" ]'
  fi
else
  note_deferred "AC-69-RUBRIC: change-surface-relative guard inert off the issue-69 dev branch (head: ${HEAD_BRANCH:-unknown})."
fi

# =============================================================================
echo ""
echo "=== AC:oracle-clause-untouched — the composition-oracle clause's text is byte-identical to the base ref ==="

if on_issue_branch; then
  if [[ -n "${BASE_REF:-}" ]]; then
    ORACLE_HEAD="$(awk '/^#### Composition oracle/{f=1} f&&/^### Testability-driven design/{f=0} f' "$AUTOFLOW_GUIDE")"
    ORACLE_BASE="$(git show "$BASE_REF:docs/autoflow-guide.md" | awk '/^#### Composition oracle/{f=1} f&&/^### Testability-driven design/{f=0} f')"
    # Referenced by NAME (see the AC-69-SCOPE-SYMMETRY comment above) — the clause text
    # carries parentheses/backticks that eval would otherwise re-parse as shell syntax.
    assert_true "AC-69-ORACLE-UNTOUCHED: composition-oracle clause text is byte-identical to $BASE_REF" \
      '[ "$ORACLE_HEAD" = "$ORACLE_BASE" ]'
  fi
else
  note_deferred "AC-69-ORACLE-UNTOUCHED: change-surface-relative guard inert off the issue-69 dev branch (head: ${HEAD_BRANCH:-unknown})."
fi

# =============================================================================
echo ""
echo "=== AC:manifest-fresh (O:manifest) — every manifest copy-row's recorded hash equals its source's live hash, for every source this cycle edits ==="

MANIFEST_SOURCES=(
  "docs/autoflow-guide.md"
  "docs/evaluation-system.md"
  "docs/teammate-contracts.md"
  "docs/adr/README.md"
  "docs/maintained-docs.md"
  "docs/INDEX.md"
)
# One jq pass over the manifest (source -> sha256 map) instead of one jq invocation per
# source — same result, fewer process spawns against the same static file.
declare -A MANIFEST_SHA_BY_SRC
while IFS=$'\t' read -r src sha; do
  MANIFEST_SHA_BY_SRC["$src"]="$sha"
done < <(jq -r '.artifacts[] | "\(.source)\t\(.sha256)"' "$MANIFEST")

for SRC in "${MANIFEST_SOURCES[@]}"; do
  MANIFEST_SHA="${MANIFEST_SHA_BY_SRC[$SRC]:-}"
  CUR_SHA="$(shasum -a 256 "$PROJECT_ROOT/$SRC" | awk '{print $1}')"
  assert_true "AC-69-MANIFEST: setup/manifest.json row for $SRC sha256 matches the live source" \
    "[ \"$MANIFEST_SHA\" = \"$CUR_SHA\" ]"
done
if [ -n "$NEW_ADR_PATH" ]; then
  ADR_MANIFEST_SHA="${MANIFEST_SHA_BY_SRC[docs/adr/$NEW_ADR_BASENAME]:-}"
  ADR_CUR_SHA="$(shasum -a 256 "$NEW_ADR_PATH" | awk '{print $1}')"
  assert_true "AC-69-MANIFEST-adr: setup/manifest.json row for docs/adr/$NEW_ADR_BASENAME sha256 matches the live source" \
    "[ \"$ADR_MANIFEST_SHA\" = \"$ADR_CUR_SHA\" ]"
else
  note_deferred "AC-69-MANIFEST-adr: no verification-depth ADR file found yet — manifest row check deferred until GREEN adds it."
fi

# =============================================================================
echo ""
echo "=== AC:registry-no-regression (O:registry) — the doc-invariant registry runner passes with the new #69 entries added and no pre-existing entry regressing ==="

REGISTRY_OUT="$(cd "$PROJECT_ROOT" && bash "$REGISTRY_RUNNER" 2>&1)"
REGISTRY_EXIT=$?
NON_69_FAIL="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL:' | grep -vc '^  FAIL: 69-' || true)"
assert_true "AC-69-REGISTRY-exit: tests/run-doc-invariants.sh exits 0 (KNOWN RED mid-cycle — the new 69-AC-* entries FAIL until GREEN authors the shipped clause text)" \
  "[ $REGISTRY_EXIT -eq 0 ]"
assert_true "AC-69-REGISTRY-no-regression: no PRE-EXISTING (non-69-*) registry entry regresses (got: $NON_69_FAIL foreign FAIL(s))" \
  "[ \"$NON_69_FAIL\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-69-HARNESS (fence) — the mock-runtime harness exits 0 and reports its pass line ==="

HARNESS_OUT="$(cd "$PROJECT_ROOT" && node test/workflows/run.mjs 2>&1)"
HARNESS_EXIT=$?
OK_COUNT="$(printf '%s\n' "$HARNESS_OUT" | grep -cE '^[[:space:]]*ok\b' || true)"
assert_true "AC-69-HARNESS-a: node test/workflows/run.mjs exits 0 (KNOWN RED mid-cycle until GREEN wires the Test-AI depth prompts)" \
  "[ $HARNESS_EXIT -eq 0 ]"
assert_true "AC-69-HARNESS-b: harness reports 'all workflow regression tests passed'" \
  "printf '%s\n' \"\$HARNESS_OUT\" | grep -qF 'all workflow regression tests passed'"

# =============================================================================
echo ""
echo "=== AC:harness-pins-agree (O:harness) — the shared harness ok-count pin's home set is DERIVED by sweeping tests/ for the pin idiom, and every live home agrees ==="

# Narrow, specific sweep keywords (not a generic '-eq [0-9]+' scan, which would false-
# positive on unrelated numeric assertions elsewhere in the suite): every existing pin
# home names the harness explicitly via EXPECTED_OK / OK_COUNT / "ok-line count".
SELF_BASENAME="$(basename "${BASH_SOURCE[0]}")"
SWEPT_HOMES="$(grep -lE 'EXPECTED_OK|ok-line count|OK_COUNT' "$PROJECT_ROOT"/tests/*.sh 2>/dev/null | xargs -n1 basename | grep -vF "$SELF_BASENAME" | sort)"
echo "  swept homes: $(printf '%s' "$SWEPT_HOMES" | paste -sd, -)"

CANON_LITERAL_27="$(grep -F 'AC-27-20c' "$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh" | grep -oE '\-eq [0-9]+ \]"$' | grep -oE '[0-9]+' | tail -1)"
EXPECTED_OK_59="$(grep -oE '^EXPECTED_OK=[0-9]+' "$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh" | grep -oE '[0-9]+' | tail -1)"
assert_true "AC-69-HARNESS-PINS-count: real harness ok-line count ($OK_COUNT) == test-issue-27's pin ($CANON_LITERAL_27) == test-issue-59's EXPECTED_OK ($EXPECTED_OK_59) (KNOWN RED mid-cycle — GREEN's prompt wiring has not landed yet)" \
  "[ \"$OK_COUNT\" = \"$CANON_LITERAL_27\" ] && [ \"$OK_COUNT\" = \"$EXPECTED_OK_59\" ]"

# Execute every swept home for real (composition oracle: no fixture stands in). A
# branch-scoped-inert home (e.g. tests/test-issue-56-carry-evidence-discipline.sh) stays
# inert by its OWN internal `case "$HEAD_BRANCH"` guard when run off its own dev branch —
# no special-casing needed here, matching the verification design's "the sweep's outcome
# is admitted to the surface whatever it returns" instruction.
for home in $SWEPT_HOMES; do
  homepath="$PROJECT_ROOT/tests/$home"
  [ -f "$homepath" ] || continue
  OUT="$(cd "$PROJECT_ROOT" && bash "$homepath" 2>&1)"
  EXIT=$?
  assert_true "AC-69-HARNESS-PINS: bash tests/$home exits 0 (swept pin home, KNOWN RED mid-cycle for the live homes until GREEN lands)" \
    "[ $EXIT -eq 0 ]"
done

# =============================================================================
echo ""
echo "=== change-surface-bounded (branch-scoped) — the cycle's diff stays within the declared allow_list ==="

allow_list=(
  "docs/autoflow-guide.md"
  "docs/evaluation-system.md"
  "docs/teammate-contracts.md"
  ".claude/workflows/architect-deliberation.js"
  "docs/adr/README.md"
  "docs/maintained-docs.md"
  "docs/INDEX.md"
  "setup/manifest.json"
  "test/workflows/run.mjs"
  "tests/test-issue-69-verification-depth.sh"
  "tests/fixtures/doc-invariants.json"
  "tests/test-issue-27-composition-oracle.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  # VERIFY cause-branch fix (RED-side): the 0018 ADR + this suite's own path also cross
  # these five sibling change-surface/manifest-closure guards' own allow_lists (#67
  # precedent — a cycle-scoped suite admits its own sibling-registration edits).
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  ".github/workflows/e2e-dummy-target.yml"
  "tests/test-issue-952-wizard-removal.sh"
  # GATE:QUALITY attempt-3 fix: e2d4a78 repaired this sibling's line-touch AC4-DELTA
  # detector (docs/doc-invariant-registry.md §1 anti-pattern), collateral to the
  # Plan-evaluation-row prose widening (#67-precedent guard-agreement obligation).
  "tests/test-issue-40-doc-assertions.sh"
  # post-merge collateral registrations (origin/main #52/#55 co-landing):
  # their scope guards required the same mechanical admission of this cycle's
  # paths, and those edits join this cycle's diff — self-registered here.
  "tests/test-issue-52-peer-facilitator-premise.sh"
  "tests/test-issue-55-score-format-contract.sh"
  # HANDOFF step 6.7 appends the cycle digest to the dev branch after reviewer review.
  "docs/cycle-digest.jsonl"
  # .autoflow/* rows removed (GATE:QUALITY dock, Quality item): .autoflow/ is
  # gitignored, so no path under it can ever appear in `git diff --name-only`
  # — those three rows could never fire.
)

# The new ADR file's exact path is derived, not enumerable in advance (it does not exist
# at RED time) — a glob member added to the allow_list set below when present.
if [ -n "$NEW_ADR_PATH" ]; then
  allow_list+=("docs/adr/$NEW_ADR_BASENAME")
fi

if on_issue_branch; then
  if [[ -n "${BASE_REF:-}" ]]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-69-SCOPE: cycle diff, set-differenced against the declared allow_list, is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  fi
else
  note_deferred "AC-69-SCOPE: change-surface guard inert off the issue-69 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
fi

# =============================================================================
echo ""
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
