#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/e2e-dummy-target.yml docs/design-rationale.md docs/git-workflow.md docs/teammate-contracts.md setup/gen-manifest-hashes.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/manual/issue-52-manual-scenarios.md tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #52 — peer-teammate-facilitator premise, evidence-anchor
# correction (cycle-scoped suite)
# =============================================================================
# Verification design: .autoflow/issue-52-verification-design.md. AC -> lane
# -> method table: §1. Automated-lane composition: §4. Composition-oracle
# determination: §5.
#
# Deliverable class: this cycle ships an EVIDENCE RECORD + a corrected DESIGN
# RECORD, not runtime code. The nine origin_issue:52 permanent registry
# entries in tests/fixtures/doc-invariants.json (promoted at GREEN, in the
# SAME commit that creates the headings/pointer text they anchor) hold:
# claim-site-cited, consistency-propagated, scope-fence-held. What remains in
# THIS file (content the registry structurally cannot hold — predicates are
# limited to present|absent|ordered over STATE, and diff-shaped / real-
# execution assertions are outside its scope):
#
#   record-file-shape   — the manual-scenario file's section skeleton AND
#                          Observation-record field completeness: each of the
#                          13 fixed field labels, scoped to the Observation
#                          record section only, carries a non-empty value
#                          (content never asserted — outcome-neutral), per
#                          GATE:PLAN carry-forward (ledger E18 item 2)
#   (retired #107) scope-fence-held(b) — a dev/*-issue-52 branch gate over
#                          issue #52's own cycle diff. Off that branch it
#                          credited a PASS for a diff it never measured, the
#                          vacuous-PASS shape check-cycle-scope-guard.sh
#                          exists to keep out; see
#                          docs/doc-invariant-registry.md §12.1.
#   ci-wired             — both new files registered as paths: entries in the
#                          pull_request AND push blocks, plus a run: step
#
# RED expectation (this commit — the three claim-site docs are unedited, the
# manual-scenario Observation-record fields carry unfilled placeholder VALUES,
# e.g. "_(literal used this run)_" — non-empty, just not yet measured):
#   FAIL (discriminators): ci-wired (no paths:/run: entries yet),
#     registry-runner-green's overall-exit-0 sub-check (the six 52-*
#     discriminator registry entries still FAIL pre-edit).
#   PASS (guards, must stay green throughout): record-file-shape file-exists
#     + heading skeleton + field-completeness (the file is authored in full
#     at RED, per Test AI scope, with every field carrying a non-empty
#     placeholder value; only the VALUE's content changes at GREEN, which
#     this oracle never asserts), registry-runner-green's id-set-scoped sub-check (no
#     entry OUTSIDE 52-* fails, true from the outset).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MANUAL_REL="tests/manual/issue-52-manual-scenarios.md"
MANUAL="$PROJECT_ROOT/$MANUAL_REL"
SUITE_REL="tests/test-issue-52-peer-facilitator-premise.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"


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

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# =============================================================================
# record-file-shape — section skeleton + Observation-record field completeness
# (verification design §1; GATE:PLAN carry-forward, ledger E18 item 2)
# =============================================================================
echo "=== record-file-shape ==="

assert_true "record-file-shape-a: $MANUAL_REL exists in the tracked tree" \
  "[ -f '$MANUAL' ]"

if [ -f "$MANUAL" ]; then
  assert_true "record-file-shape-b: file title heading matches feature design > Data structures verbatim" \
    "grep -qxF '# Issue #52 — Manual/Environment-Dependent Verification Scenarios (Tier-3)' '$MANUAL'"
  assert_true "record-file-shape-c: scenario heading matches feature design > Data structures verbatim" \
    "grep -qxF \"## M1 — peer-teammate SendMessage injection into the lead's turn stream (Tier 3)\" '$MANUAL'"

  for label in '**Source AC:**' '**Why not automated:**' '**Steps:**' '**Pass condition:**' '**Non-goal:**' '**Observation record:**'; do
    assert_true "record-file-shape-d: part label '$label' present" \
      "grep -qF -- '$label' '$MANUAL'"
  done

  # Observation-record field completeness — the GATE:PLAN carry-forward
  # (ledger E18 item 2) requires the oracle to pin field COMPLETENESS (a
  # non-empty VALUE after each label), not headings/labels alone. A
  # whole-file substring grep is not enough here: blanking every field's
  # value, or deleting the whole Observation record section, would still
  # green most labels because the Steps/Pass-condition prose separately
  # names the same terms ("send confirmation", "receipt confirmation",
  # "positive control result", ...) in ordinary sentences, not as a
  # `- **label:**` bullet. So this check (1) scopes extraction to the
  # Observation record section only (everything from its heading to EOF —
  # it is the file's last section), and (2) requires each field's exact
  # `- **<label>:**` bullet to be followed by a non-empty value on that
  # same line. The VALUE's *content* is never asserted (outcome-neutral;
  # verification design §2 — the reproduction procedure a scorer uses to
  # re-check this discriminating power is recorded at ledger E23).
  OBS_SECTION="$(awk '/^\*\*Observation record:\*\*/{f=1} f' "$MANUAL" 2>/dev/null)"
  OBS_FIELDS=(
    'team shape'
    'peer nonce'
    'control nonce'
    'send confirmation (peer hop)'
    'send confirmation (control, direct to lead)'
    'receipt confirmation'
    'positive control result'
    "peer nonce in lead's stream — occurrences"
    "peer nonce in lead's stream — per-occurrence envelope"
    "control nonce in lead's stream — occurrences"
    "control nonce in lead's stream — per-occurrence envelope"
    'verdict'
    'date'
  )
  for field in "${OBS_FIELDS[@]}"; do
    FIELD_LINE="$(printf '%s\n' "$OBS_SECTION" | grep -F -- "- **$field:**" | head -1)"
    FIELD_VALUE="${FIELD_LINE#"- **$field:**"}"
    FIELD_VALUE_TRIMMED="$(printf '%s' "$FIELD_VALUE" | sed -E 's/^[[:space:]]+//')"
    if [ -n "$FIELD_VALUE_TRIMMED" ]; then FIELD_OK=yes; else FIELD_OK=no; fi
    assert_true "record-file-shape-e: Observation record field '$field' has a non-empty value, scoped to the Observation record section (got: $FIELD_OK)" \
      "[ '$FIELD_OK' = yes ]"
  done

  # Receipt-confirmation control (ledger E18 item 1) — the scenario text
  # itself must instruct a DERIVED token, never the raw peer nonce, echoed
  # back on receipt; a scenario that told the receiver to echo the nonce
  # verbatim would structurally block the "injection not observed" branch.
  assert_true "record-file-shape-f: receipt confirmation is specified as a derived token, not the raw nonce (ledger E18 item 1)" \
    "grep -qi 'derived token' '$MANUAL'"
  assert_false "record-file-shape-g: the scenario never instructs echoing the raw peer nonce back as the receipt confirmation" \
    "grep -qi 'echo the nonce verbatim\|echo the raw nonce back\|echoes the nonce back' '$MANUAL'"

  # Grounded-deviation note (GATE:PLAN carry-forward item 4) — the 2-member
  # probe team is recorded as a grounded deviation from the issue's written
  # 3-member procedure.
  assert_true "record-file-shape-h: the 2-member probe team is recorded as a grounded deviation from the issue's 3-member procedure" \
    "grep -qi 'deviation' '$MANUAL' && grep -qi '3-member\|three-member' '$MANUAL'"
else
  echo "  BLOCK: remaining record-file-shape arms unmeasurable ($MANUAL_REL missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 12)); FAIL=$((FAIL + 12))
fi

# =============================================================================
# ci-wired — both new files registered as trigger paths in the pull_request
# AND push blocks, plus a run: step invoking this suite.
# =============================================================================
echo ""
echo "=== ci-wired ==="

if [ -f "$CI_WORKFLOW" ]; then
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_HAS_SUITE=no;    printf '%s\n' "$PR_SECTION"   | grep -qF "'$SUITE_REL'"  && PR_HAS_SUITE=yes
  PUSH_HAS_SUITE=no;  printf '%s\n' "$PUSH_SECTION" | grep -qF "'$SUITE_REL'"  && PUSH_HAS_SUITE=yes
  PR_HAS_MANUAL=no;   printf '%s\n' "$PR_SECTION"   | grep -qF "'$MANUAL_REL'" && PR_HAS_MANUAL=yes
  PUSH_HAS_MANUAL=no; printf '%s\n' "$PUSH_SECTION" | grep -qF "'$MANUAL_REL'" && PUSH_HAS_MANUAL=yes

  assert_true "ci-wired-a1: $SUITE_REL appears in the pull_request paths: block (got: $PR_HAS_SUITE)" "[ '$PR_HAS_SUITE' = yes ]"
  assert_true "ci-wired-a2: $SUITE_REL appears in the push paths: block (got: $PUSH_HAS_SUITE)" "[ '$PUSH_HAS_SUITE' = yes ]"
  assert_true "ci-wired-a3: $MANUAL_REL appears in the pull_request paths: block (got: $PR_HAS_MANUAL)" "[ '$PR_HAS_MANUAL' = yes ]"
  assert_true "ci-wired-a4: $MANUAL_REL appears in the push paths: block (got: $PUSH_HAS_MANUAL)" "[ '$PUSH_HAS_MANUAL' = yes ]"

  RUN_STEP_CTX="$(grep -A2 -F "$SUITE_REL" "$CI_WORKFLOW" 2>/dev/null || true)"
  RUN_STEP_OK=no; printf '%s\n' "$RUN_STEP_CTX" | grep -qF "run: bash $SUITE_REL" && RUN_STEP_OK=yes
  assert_true "ci-wired-b: a 'run: bash $SUITE_REL' step exists" "[ '$RUN_STEP_OK' = yes ]"

  # Companion window guard — the fixed grep -A40 '^ *paths:' window (#799's
  # AC6-ci) must still contain an existing, pre-#52 literal after this
  # cycle's tail-append.
  PH="$(grep -A40 '^ *paths:' "$CI_WORKFLOW")"
  assert_true "ci-wired-window-guard: the fixed grep -A40 '^ *paths:' window still contains 'docs/git-workflow.md' (AC6-ci's own literal — this cycle must tail-append, not push it out)" \
    "printf '%s\n' \"\$PH\" | grep -qF \"'docs/git-workflow.md'\""
else
  assert_true "ci-wired: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: remaining ci-wired arms unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 5)); FAIL=$((FAIL + 5))
fi


echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
