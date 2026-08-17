#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude-plugin/marketplace.json .claude/workflows/architect-deliberation.js .github/workflows/e2e-dummy-target.yml .github/workflows/workflow-regression.yml CLAUDE.md docs/autoflow-guide.md docs/design-rationale.md docs/submodule-common-rules.md docs/teammate-contracts.md plugin/autoflow/.claude-plugin/plugin.json setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/lib/base-ref.sh tests/lib/harness-pins.sh tests/manual/issue-62-manual-scenarios.md tests/manual/issue-67-manual-scenarios.md tests/run-doc-invariants.sh
# lane: standing
# cycle-arm: #67
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: ARCHITECT deliberation record redesign — Issue #67 (cycle-scoped)
# =============================================================================
# Cycle-scoped structural/count/hash/execution guards per the verification design
# (.autoflow/issue-67-verification-design.md §2/§4/§6). Behavioral assertions on the
# composed prompts (register carry, disposition mechanics, entry shape) live in
# test/workflows/run.mjs (lane A); this suite carries the S-lane criteria a mock-runtime
# test cannot express: the two composition oracles (§4), doc present/absent pairs, the
# doc-invariant registry fence, the version/manifest bump, CI registration, the
# carry-anchor re-anchoring (three halves), and the branch-scoped change-surface guard.
#
# The mid-cycle known-RED note this header used to carry described a synchronised
# bump across two foreign harness ok-count pin homes. Issue #103 single-sourced
# that pin into tests/lib/harness-pins.sh, so there are no foreign homes and no
# such window; the lane is disposed in place below.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
RUN_MJS="$PROJECT_ROOT/test/workflows/run.mjs"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
WORKFLOW_REGRESSION_CI="$PROJECT_ROOT/.github/workflows/workflow-regression.yml"
TEAMMATE_CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
DESIGN_RATIONALE="$PROJECT_ROOT/docs/design-rationale.md"
PLUGIN_JSON="$PROJECT_ROOT/plugin/autoflow/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$PROJECT_ROOT/.claude-plugin/marketplace.json"
SUITE_56="$PROJECT_ROOT/tests/test-issue-56-carry-evidence-discipline.sh"
SUITE_59="$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"

source "$PROJECT_ROOT/tests/lib/base-ref.sh"

# EXPECTED version for this cycle (0.1.7 -> 0.1.8, issue #88 retirement + version bump).
EXPECTED_VERSION="0.1.8"

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

# =============================================================================
echo "=== AC-67-HARNESS (fence) — the mock-runtime harness exits 0 and reports its pass line (harness-green) ==="

HARNESS_OUT="$(cd "$PROJECT_ROOT" && node test/workflows/run.mjs 2>&1)"
HARNESS_EXIT=$?
OK_COUNT="$(printf '%s\n' "$HARNESS_OUT" | grep -cE '^[[:space:]]*ok\b' || true)"
assert_true "AC-67-HARNESS-a: node test/workflows/run.mjs exits 0 (KNOWN RED mid-cycle until GREEN lands the register/disposition redesign)" \
  "[ $HARNESS_EXIT -eq 0 ]"
assert_true "AC-67-HARNESS-b: harness reports 'all workflow regression tests passed'" \
  "printf '%s\n' \"\$HARNESS_OUT\" | grep -qF 'all workflow regression tests passed'"

# The ok-count-pins-agree lane is retired by issue #103. It read the shared
# harness ok-count out of two FOREIGN homes by their literal text and asserted
# the three agreed. Single-sourcing the pin into
# tests/lib/harness-pins.sh leaves one home, so there is nothing to agree: an
# equality check between two reads of one constant is unfalsifiable. The
# property that survives — one authoring home — is carried by
# scripts/test/check-suite-manifest.sh's single-authorship arm, and the pin's
# teeth by tests/test-issue-27-composition-oracle.sh, which compares the sourced
# constant against the live `node test/workflows/run.mjs` measurement.

# =============================================================================
echo ""
echo "=== Element 2 (composition oracle, non-mock, unconditional) — setup/manifest.json artifact rows hash-match live sources; version agrees everywhere (manifest-regen, version-bump / AC14) ==="

for SRC in ".claude/workflows/architect-deliberation.js" "docs/teammate-contracts.md" "docs/autoflow-guide.md"; do
  MANIFEST_SHA="$(jq -r --arg s "$SRC" '.artifacts[] | select(.source==$s) | .sha256' "$MANIFEST")"
  CUR_SHA="$(shasum -a 256 "$PROJECT_ROOT/$SRC" | awk '{print $1}')"
  assert_true "AC-67-MANIFEST: setup/manifest.json row for $SRC sha256 matches the live source (manifest: $MANIFEST_SHA, current: $CUR_SHA)" \
    "[ \"$MANIFEST_SHA\" = \"$CUR_SHA\" ]"
done

PLUGIN_VERSION="$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || true)"
MARKETPLACE_VERSION="$(jq -r '.plugins[] | select(.name=="autoflow") | .version' "$MARKETPLACE_JSON" 2>/dev/null || true)"
MANIFEST_VERSION="$(jq -r '.version' "$MANIFEST" 2>/dev/null || true)"
assert_true "AC-67-VERSION-plugin: plugin.json version == $EXPECTED_VERSION (got: $PLUGIN_VERSION)" \
  "[ \"$PLUGIN_VERSION\" = \"$EXPECTED_VERSION\" ]"
assert_true "AC-67-VERSION-marketplace: marketplace.json autoflow entry version == $EXPECTED_VERSION (got: $MARKETPLACE_VERSION)" \
  "[ \"$MARKETPLACE_VERSION\" = \"$EXPECTED_VERSION\" ]"
assert_true "AC-67-VERSION-manifest: setup/manifest.json version == $EXPECTED_VERSION (got: $MANIFEST_VERSION)" \
  "[ \"$MANIFEST_VERSION\" = \"$EXPECTED_VERSION\" ]"

# =============================================================================
echo ""
echo "=== AC13 (contract-doc-updated / guide-doc-updated / no-stale-restatement) — record rules reach the contract + guide docs ==="

assert_true "AC-67-CONTRACT-register: Facilitator Return Contract states the register/disposition carry" \
  "grep -qi 'register' '$TEAMMATE_CONTRACTS'"
assert_true "AC-67-CONTRACT-rejected: Facilitator Return Contract names the ARCHITECT rejected authority" \
  "grep -qF 'ARCHITECT rejected' '$TEAMMATE_CONTRACTS'"
assert_true "AC-67-CONTRACT-nocap: the stale 80/120-cap sentence is gone from the Facilitator contract" \
  "! grep -qF 'capped by the script at 80 / 120 code points' '$TEAMMATE_CONTRACTS'"
# Capture-then-grep, not a piped grep -A/grep -q (tests/test-issue-964-sigpipe-safe-pipes.sh
# guards against exactly that compound context-mode-producer-into-short-circuit-consumer
# shape — docs/submodule-common-rules.md > Testing Standards).
# Fixed-literal (grep -F), not a loose `-qi 'register'`: the ARCHITECT section already
# contains "register" pre-#67 (the pre-existing "manifest-registered source" / "pre-register"
# derived-artifact bullets), so a loose case-insensitive match is vacuous — it passes even with
# the #67 "Record rules" subsection fully reverted (re-verified: `git show
# main:docs/autoflow-guide.md | grep -A200 '^## ARCHITECT ' | grep -ic register` = 3 on the
# pre-#67 baseline). The literal below is drawn from the shipped "Record rules" subsection
# itself and confirmed absent from that same pre-#67 baseline.
GUIDE_ARCHITECT_SECTION="$(grep -A200 '^## ARCHITECT ' "$AUTOFLOW_GUIDE")"
assert_true "AC-67-GUIDE-register: autoflow-guide.md > ARCHITECT states the register/record rules" \
  "printf '%s' \"\$GUIDE_ARCHITECT_SECTION\" | grep -qF 'The register is the durable channel'"

for FILE in "$TEAMMATE_CONTRACTS" "$AUTOFLOW_GUIDE" "$CLAUDE_MD" "$DESIGN_RATIONALE"; do
  assert_true "AC-67-NOSTALE ($(basename "$FILE")): no stale truncated-carry / in-document-closure restatement survives" \
    "! grep -qF '80 / 120 code points' '$FILE' && ! grep -qF 'record its argument as a named open-concern entry' '$FILE'"
done

# =============================================================================
echo ""
echo "=== AC13 (doc-invariants-preserved) — the permanent registry rows scoped to the edited ARCHITECT section still hold ==="

# AC-67-DOCINV is retired by issue #103's leaf rule: the registry runner carries
# its own `run:` steps in both plain and --self-test modes, so re-running it here
# was duplicate execution of an already-covered surface.
#
# The registry rows this AC named (949-AC3-arch-prereg, 949-AC3-arch-derived-member,
# 949-preserve-arch-fdd) are asserted where they live — in
# tests/fixtures/doc-invariants.json, executed by those steps.

# =============================================================================
echo ""
echo "=== AC19 (carry-anchor-guards-re-anchored) — no live shell assertion still greps the retired openCounters carry anchor ==="

# AC-67-ANCHOR-a1 / -a2 are retired by issue #103's leaf rule. Both re-ran a
# sibling suite to confirm it had not regressed; each sibling carries its own
# `run:` step, so the confirmation happens once per pass either way. The
# re-anchoring property itself is unaffected — AC-67-ANCHOR-b/-c1/-c2/-c3 below
# read the two files' TEXT, which is what "re-anchored" actually means, and
# needs no execution.

# Assembled from parts, not written as one contiguous literal: this suite's OWN source
# must not accidentally match its own sweep pattern (a literal grep argument would sit in
# this file too, making the sweep vacuously self-positive forever).
RETIRED_VAR="openCounters"
RETIRED_PATTERN="const carry = ${RETIRED_VAR}.length"
SELF="$(basename "${BASH_SOURCE[0]}")"
RETIRED_SWEEP="$(grep -rln -- "$RETIRED_PATTERN" "$PROJECT_ROOT/tests" | grep -vF "$SELF" || true)"
assert_true "AC-67-ANCHOR-b: no OTHER tests/ file still greps/comments the retired carry-anchor literal (found: $(printf '%s' "$RETIRED_SWEEP" | paste -sd, -))" \
  "[ -z \"\$(printf '%s' '$RETIRED_SWEEP')\" ]"

NEW_ANCHOR_PROD_COUNT="$(grep -c 'const carry = register.size' "$WORKFLOW_JS" || true)"
NEW_ANCHOR_56_COUNT="$(grep -c 'const carry = register.size' "$SUITE_56" || true)"
NEW_ANCHOR_59_COUNT="$(grep -c 'const carry = register.size' "$SUITE_59" || true)"
assert_true "AC-67-ANCHOR-c1: the fixed replacement literal 'const carry = register.size' appears exactly once in architect-deliberation.js (got: $NEW_ANCHOR_PROD_COUNT)" \
  "[ \"$NEW_ANCHOR_PROD_COUNT\" -eq 1 ]"
assert_true "AC-67-ANCHOR-c2: tests/test-issue-56-carry-evidence-discipline.sh's re-anchored sites grep the new literal (got: $NEW_ANCHOR_56_COUNT occurrence(s), need >= 2)" \
  "[ \"$NEW_ANCHOR_56_COUNT\" -ge 2 ]"
assert_true "AC-67-ANCHOR-c3: tests/test-issue-59-adoption-evidence-discipline.sh's re-anchored site greps the new literal (got: $NEW_ANCHOR_59_COUNT occurrence(s), need >= 1)" \
  "[ \"$NEW_ANCHOR_59_COUNT\" -ge 1 ]"

CARRY_NON_EVIDENTIARY_COUNT="$(grep -c '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" || true)"
assert_true "AC-59-8c-carry (regression, unaffected by re-anchoring): \${CARRY_NON_EVIDENTIARY} still interpolates exactly once (got: $CARRY_NON_EVIDENTIARY_COUNT)" \
  "[ \"$CARRY_NON_EVIDENTIARY_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== ci-registered — the new suite is registered in e2e-dummy-target.yml (both paths: blocks + a run: step); workflow-regression.yml still covers .claude/workflows/** ==="

PR_PATHS_COUNT="$(awk '/^  pull_request:/{f=1} f&&/^  push:/{f=0} f' "$CI_WORKFLOW" | grep -cF "tests/test-issue-67-deliberation-record.sh" || true)"
PUSH_PATHS_COUNT="$(awk '/^  push:/{f=1} f' "$CI_WORKFLOW" | grep -cF "tests/test-issue-67-deliberation-record.sh" || true)"
RUN_STEP_COUNT="$(grep -cF "run: bash tests/test-issue-67-deliberation-record.sh" "$CI_WORKFLOW" || true)"
assert_true "AC-67-CI-pr: e2e-dummy-target.yml pull_request paths: block admits tests/test-issue-67-deliberation-record.sh (got: $PR_PATHS_COUNT)" \
  "[ \"$PR_PATHS_COUNT\" -ge 1 ]"
assert_true "AC-67-CI-push: e2e-dummy-target.yml push paths: block admits tests/test-issue-67-deliberation-record.sh (got: $PUSH_PATHS_COUNT)" \
  "[ \"$PUSH_PATHS_COUNT\" -ge 1 ]"
assert_true "AC-67-CI-run: e2e-dummy-target.yml has a run: step invoking this suite (got: $RUN_STEP_COUNT)" \
  "[ \"$RUN_STEP_COUNT\" -eq 1 ]"
assert_true "AC-67-CI-workflowregression: workflow-regression.yml still triggers on .claude/workflows/** and test/workflows/**" \
  "grep -qF '.claude/workflows/**' '$WORKFLOW_REGRESSION_CI' && grep -qF 'test/workflows/**' '$WORKFLOW_REGRESSION_CI'"

# =============================================================================
echo ""
echo "=== change-surface-bounded (branch-scoped) — the cycle's diff stays within the declared surface ==="

allow_list=(
  ".claude/workflows/architect-deliberation.js"
  "docs/teammate-contracts.md"
  "docs/autoflow-guide.md"
  "plugin/autoflow/.claude-plugin/plugin.json"
  ".claude-plugin/marketplace.json"
  "setup/manifest.json"
  "test/workflows/run.mjs"
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-56-carry-evidence-discipline.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
  "tests/test-issue-27-composition-oracle.sh"
  "tests/fixtures/doc-invariants.json"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/manual/issue-62-manual-scenarios.md"
  "tests/manual/issue-67-manual-scenarios.md"
  ".github/workflows/e2e-dummy-target.yml"
  # HANDOFF step 6.7 appends the cycle digest to the dev branch (PR co-ride) after
  # the reviewer review, so the digest file is a mandated member of every cycle's diff.
  "docs/cycle-digest.jsonl"
  ".autoflow/issue-67-feature-design.md"
  ".autoflow/issue-67-verification-design.md"
  ".autoflow/issue-67-ledger.md"
)

case "$HEAD_BRANCH" in
  dev/*-issue-67|dev/*-issue-67-*)
    BASE_REF="$(resolve_base_ref)" || {
      echo "  BLOCK: no comparison base resolvable — AC-67-SCOPE counted FAIL, never skipped"
      TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
      BASE_REF=""
    }
    if [[ -n "$BASE_REF" ]]; then
      DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD)"
      UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
      assert_true "AC-67-SCOPE: cycle diff, set-differenced against the declared allow_list, is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
        "[ -z \"\$(printf '%s' '$UNCOVERED')\" ]"
    fi
    ;;
  *)
    note_deferred "AC-67-SCOPE: change-surface guard inert off the issue-67 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
    ;;
esac

# =============================================================================
echo ""
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
