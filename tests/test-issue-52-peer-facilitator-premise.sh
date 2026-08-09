#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
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
#                          Observation-record field completeness (send /
#                          receipt / positive-control values), per GATE:PLAN
#                          carry-forward (ledger E15 item 2)
#   scope-fence-held(b)  — no path under .claude/workflows/ appears in this
#                          cycle's own branch diff (diff-shaped, branch-scoped
#                          via tests/lib/base-ref.sh)
#   ci-wired             — both new files registered as paths: entries in the
#                          pull_request AND push blocks, plus a run: step
#   manifest-freshness   — composition oracle: real setup/gen-manifest-hashes.sh,
#                          non-destructive protocol (capture -> trap-restore-on-
#                          any-exit -> run -> compare -> restore), scoped to
#                          this cycle's three edited sources' sha256 rows plus
#                          a membership-unchanged assertion
#   registry-runner-green — composition oracle: real tests/run-doc-invariants.sh,
#                          id-set-scoped fence (no entry outside 52-* FAILs) +
#                          overall exit 0 required only on the post-edit tree
#
# RED expectation (this commit — the three claim-site docs are unedited, the
# manual-scenario Observation-record fields are unfilled placeholders):
#   FAIL (discriminators): record-file-shape field-completeness sub-checks
#     (the field labels ARE present as unfilled template lines, so the label-
#     presence assertions PASS; only a real GREEN measurement fills them —
#     the label-presence check is therefore a guard, not a discriminator; see
#     inline comment at that section), ci-wired (no paths:/run: entries yet),
#     registry-runner-green's overall-exit-0 sub-check (the six 52-*
#     discriminator registry entries still FAIL pre-edit).
#   PASS (guards, must stay green throughout): record-file-shape file-exists
#     + heading skeleton (the file is authored at RED, per Test AI scope),
#     scope-fence-held(b) workflow no-touch fence, manifest-freshness (both
#     sub-checks — a fence, true before and after GREEN), registry-runner-
#     green's id-set-scoped sub-check (no entry OUTSIDE 52-* fails, true from
#     the outset).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/base-ref.sh
. "$SCRIPT_DIR/lib/base-ref.sh"

MANUAL_REL="tests/manual/issue-52-manual-scenarios.md"
MANUAL="$PROJECT_ROOT/$MANUAL_REL"
SUITE_REL="tests/test-issue-52-peer-facilitator-premise.sh"
RUNNER="$SCRIPT_DIR/run-doc-invariants.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

EDITED_SOURCES=("CLAUDE.md" "docs/design-rationale.md" "docs/teammate-contracts.md")

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
# (verification design §1; GATE:PLAN carry-forward, ledger E15 item 2)
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
  # (ledger E15 item 2) requires the oracle to pin field COMPLETENESS
  # (send / receipt / positive-control value labels), not headings only.
  # These label-presence checks are GUARDS: the manual scenario is authored
  # in full at RED (Test AI scope), so the field labels already exist as
  # unfilled template lines — only a live GREEN measurement fills their
  # values, which this automated lane never asserts the content of
  # (verification design §2 "Outcome-neutrality is the load-bearing
  # constraint").
  for field in 'team shape' 'peer nonce' 'control nonce' 'send confirmation' 'receipt confirmation' 'positive control result' 'occurrences' 'envelope' 'verdict' 'date'; do
    assert_true "record-file-shape-e: Observation record field '$field' present" \
      "grep -qi -- '$field' '$MANUAL'"
  done

  # Receipt-confirmation control (ledger E15 item 1) — the scenario text
  # itself must instruct a DERIVED token, never the raw peer nonce, echoed
  # back on receipt; a scenario that told the receiver to echo the nonce
  # verbatim would structurally block the "injection not observed" branch.
  assert_true "record-file-shape-f: receipt confirmation is specified as a derived token, not the raw nonce (ledger E15 item 1)" \
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
# scope-fence-held(b) — no path under .claude/workflows/ appears in this
# cycle's own branch diff (diff-shaped, branch-scoped; the registry's
# permanent present-entry on the fence literal covers the STATE half).
# =============================================================================
echo ""
echo "=== scope-fence-held(b) — .claude/workflows/ no-touch fence (branch-scoped) ==="

BASE52="$(resolve_base_ref 2>/dev/null || true)"
if [ -n "$BASE52" ]; then
  WORKFLOW_TOUCHED="$(git -C "$PROJECT_ROOT" diff --name-only "${BASE52}...HEAD" 2>/dev/null | grep -c '^\.claude/workflows/' || true)"
  [ -z "$WORKFLOW_TOUCHED" ] && WORKFLOW_TOUCHED=0
  assert_true "scope-fence-held-b: git diff vs base touches no path under .claude/workflows/ (got: $WORKFLOW_TOUCHED)" \
    "[ '$WORKFLOW_TOUCHED' -eq 0 ]"
else
  assert_true "scope-fence-held-b: a comparison base is resolvable (resolve_base_ref, fail-loud per tests/lib/base-ref.sh contract)" "false"
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

# =============================================================================
# manifest-freshness — composition oracle (verification design §5,
# manifest-regen-clean; non-destructive protocol, ledger E15).
# =============================================================================
echo ""
echo "=== manifest-freshness (composition oracle: real setup/gen-manifest-hashes.sh) ==="

if [ -f "$GEN_MANIFEST" ] && [ -f "$MANIFEST" ]; then
  MANIFEST_BACKUP="$(mktemp)"
  cp "$MANIFEST" "$MANIFEST_BACKUP"
  restore_manifest() { cp "$MANIFEST_BACKUP" "$MANIFEST"; rm -f "$MANIFEST_BACKUP"; }
  trap restore_manifest EXIT

  PRE_SOURCES_JSON="$(jq -c '[.artifacts[].source] | sort' "$MANIFEST" 2>/dev/null)"

  ( cd "$PROJECT_ROOT" && bash "$GEN_MANIFEST" >/dev/null 2>&1 )
  GEN_RC=$?

  ROWS_UNCHANGED=yes
  if [ "$GEN_RC" -eq 0 ]; then
    for src in "${EDITED_SOURCES[@]}"; do
      PRE_SHA="$(jq -r --arg s "$src" '.artifacts[] | select(.source==$s) | .sha256' "$MANIFEST_BACKUP" 2>/dev/null)"
      POST_SHA="$(jq -r --arg s "$src" '.artifacts[] | select(.source==$s) | .sha256' "$MANIFEST" 2>/dev/null)"
      [ "$PRE_SHA" = "$POST_SHA" ] || ROWS_UNCHANGED=no
    done
  else
    ROWS_UNCHANGED=no
  fi

  POST_SOURCES_JSON="$(jq -c '[.artifacts[].source] | sort' "$MANIFEST" 2>/dev/null)"
  MEMBERSHIP_UNCHANGED=no
  [ "$PRE_SOURCES_JSON" = "$POST_SOURCES_JSON" ] && MEMBERSHIP_UNCHANGED=yes

  assert_true "manifest-freshness-a: real generator regen leaves this cycle's edited-source rows byte-identical (fence — true before and after GREEN)" \
    "[ '$ROWS_UNCHANGED' = yes ]"
  assert_true "manifest-freshness-b: regen does not change manifest artifacts[] membership (source set unchanged; guards the backticked-pointer-only rule)" \
    "[ '$MEMBERSHIP_UNCHANGED' = yes ]"

  restore_manifest
  trap - EXIT
else
  assert_true "manifest-freshness: setup/gen-manifest-hashes.sh and setup/manifest.json both exist" "false"
fi

# =============================================================================
# registry-runner-green — composition oracle (verification design §5,
# registry-runner-clean; id-set-scoped fence, overall exit 0 post-edit only).
# =============================================================================
echo ""
echo "=== registry-runner-green (composition oracle: real tests/run-doc-invariants.sh) ==="

RUNNER_OUT="$(bash "$RUNNER" 2>&1)"
RUNNER_RC=$?
FOREIGN_FAILS="$(printf '%s\n' "$RUNNER_OUT" | grep '^  FAIL: ' | grep -vc '^  FAIL: 52-' || true)"
[ -z "$FOREIGN_FAILS" ] && FOREIGN_FAILS=0

assert_true "registry-runner-green-a: no registry entry OUTSIDE this cycle's 52-* id set FAILs (fence — true from the outset) (got: $FOREIGN_FAILS)" \
  "[ '$FOREIGN_FAILS' -eq 0 ]"
assert_true "registry-runner-green-b: the runner reaches its results line rather than aborting on a dangling/ambiguous-anchor BLOCK" \
  "printf '%s\n' \"\$RUNNER_OUT\" | grep -qE '^Results:'"
assert_true "registry-runner-green-c: the real registry runner exits 0 (discriminator — required only on the post-edit tree)" \
  "[ '$RUNNER_RC' -eq 0 ]"

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
