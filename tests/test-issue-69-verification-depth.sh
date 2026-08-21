#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/e2e-dummy-target.yml docs/INDEX.md docs/adr/README.md docs/autoflow-guide.md docs/evaluation-system.md docs/maintained-docs.md docs/teammate-contracts.md scripts/test/check-suite-leaf.sh setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/lib/harness-pins.sh tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
ADR_README="$PROJECT_ROOT/docs/adr/README.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"

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
# AC:harness-pins-agree (AC-69-HARNESS-PINS-count / AC-69-HARNESS-PINS) is
# retired by issue #103.
# =============================================================================
# The lane swept tests/ for the pin idiom, asserted every discovered home agreed
# with the live measurement, and then EXECUTED each swept home. Both halves are
# gone with their subject:
#
#   - agreement — the pin now has one home, tests/lib/harness-pins.sh, which
#     both consumers source. An equality check between two reads of one constant
#     is unfalsifiable, so there is nothing left to agree.
#   - the execution sweep — a suite executing its siblings is what
#     scripts/test/check-suite-leaf.sh now denies; each swept home carries its
#     own `run:` step.
#
# The pin's teeth are unaffected and live where they always did:
# tests/test-issue-27-composition-oracle.sh compares the sourced constant
# against the live `node test/workflows/run.mjs` measurement.

# =============================================================================
echo ""
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
