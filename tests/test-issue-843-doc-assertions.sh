#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: structure-gate hook-non-enforcement doc accuracy — Issue #843 AC3
# =============================================================================
# Tier-1 scripted static assertion suite per verification design
# (.autoflow/issue-843-verification-design.md AC3). Docs-only surface (no
# jest/npm/network) — mirrors tests/test-issue-800-doc-assertions.sh /
# tests/test-issue-796-doc-assertions.sh: assert_true/assert_false over
# grep + git diff.
#
# AC3 — structure-gate hook-non-enforcement stated accurately in docs +
# auto-close verification procedure defined:
#   A3-REMOVE      — RED discriminator: docs/phases/analysis.md no longer
#                    asserts the hook computes gate_hypothesis_structure
#                    pass/fail (the false clause is gone).
#   A3-STATE       — RED discriminator: analysis.md states the hook does
#                    NOT gate gate_hypothesis_structure (orchestrator-judged).
#   A3-EVALSYS     — RED discriminator: docs/evaluation-system.md's "phase
#                    keys used by the hook" list flags gate_hypothesis_structure
#                    as recorded-but-not-gated (not silently enumerated
#                    alongside the four keys the hook actually gates).
#   A3-CONSISTENCY — four-surface bijection guard (PASS pre+post): the
#                    corrected docs agree with the two already-correct
#                    surfaces — tests/fixtures/gate-schema.json:gated_phase_keys
#                    (omits the key) and docs/security-checklist.md:33
#                    (documents the omission as intentional, #245 R3) — and
#                    no doc reintroduces it as gated.
#   A3-PROCEDURE   — RED discriminator: analysis.md documents the issue
#                    auto-close pre-verification procedure (orchestrator
#                    confirms the recorded gate_hypothesis_structure scores
#                    actually meet the FAIL condition before executing the
#                    destructive `gh issue close`).
#   AC-CI-REGISTER — guard: this suite is wired into
#                    .github/workflows/e2e-dummy-target.yml (both `paths:`
#                    trigger blocks + a `run:` step), #798/#799/#800 precedent.
#
# Not in this file (verification design AC3 semantic caveat — MEDIUM
# testability): the "reads accurately end-to-end" prose-quality judgment is
# routed to a manual VALIDATE checklist line
# (.autoflow/issue-843-manual-checklist.md), not grep-checkable.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
EVALSYS_MD="$PROJECT_ROOT/docs/evaluation-system.md"
SECURITY_MD="$PROJECT_ROOT/docs/security-checklist.md"
SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_true/assert_false pattern per test-issue-800-doc-assertions.sh)
# ---------------------------------------------------------------------------

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
echo "=== A3-REMOVE (RED discriminator) — false hook-enforcement clause removed ==="
# analysis.md:7-9 currently says "(the hook computes pass/fail from them —
# see CLAUDE.md > AutoFlow State Tracking)" — false for gate_hypothesis_structure
# (verified: the hook's gate call-sites and its closed-world phase_ok list
# never reference this key). This clause must be gone.

assert_false "A3-REMOVE: analysis.md no longer claims the hook computes pass/fail from the structure-gate scores" \
  "grep -qF 'the hook computes pass/fail from' '$ANALYSIS_MD'"

# =============================================================================
echo ""
echo "=== A3-STATE (RED discriminator) — analysis.md states the hook does NOT gate the structure key ==="

assert_true "A3-STATE: analysis.md states the hook does not gate gate_hypothesis_structure" \
  "grep -qi 'does not gate' '$ANALYSIS_MD' && grep -qF 'gate_hypothesis_structure' '$ANALYSIS_MD'"
assert_true "A3-STATE-orchestrator: analysis.md attributes structure pass/fail judgment to the orchestrator" \
  "grep -qiE 'orchestrator (judges|decides|determines)' '$ANALYSIS_MD'"

# =============================================================================
echo ""
echo "=== A3-EVALSYS (RED discriminator) — evaluation-system.md phase-key list corrected ==="
# evaluation-system.md:111-118 currently lists gate_hypothesis_structure among
# "the phase keys used by the hook" with no non-gating flag — reads as if the
# hook enforces it. Must be corrected to state it is recorded in state but
# NOT gated by the hook.

assert_true "A3-EVALSYS: evaluation-system.md flags gate_hypothesis_structure as recorded-but-not-gated" \
  "grep -qi 'not gated' '$EVALSYS_MD' && grep -qF 'gate_hypothesis_structure' '$EVALSYS_MD'"

# =============================================================================
echo ""
echo "=== A3-CONSISTENCY (guard, PASS pre+post) — four-surface bijection ==="
# The corrected docs must AGREE with the two already-correct surfaces: the
# closed-world schema's gated_phase_keys (omits the structure key) and
# security-checklist.md:33 (documents the omission as intentional, #245 R3).

STRUCT_IN_SCHEMA=$(jq -r '.gated_phase_keys | map(select(. == "gate_hypothesis_structure")) | length' "$SCHEMA" 2>/dev/null || echo "ERR")
assert_true "A3-CONSISTENCY-a: gate_hypothesis_structure absent from gate-schema.json:gated_phase_keys (already correct)" \
  "[ '$STRUCT_IN_SCHEMA' = '0' ]"
assert_true "A3-CONSISTENCY-b: security-checklist.md:33 documents gate_hypothesis_structure as a non-gated phase (already correct)" \
  "grep -qF 'gate_hypothesis_structure' '$SECURITY_MD' && grep -qi 'non-gated' '$SECURITY_MD'"
assert_false "A3-CONSISTENCY-c: no doc surface reintroduces gate_hypothesis_structure as hook-gated" \
  "grep -riE 'hook (gates|enforces)[^.]*gate_hypothesis_structure|gate_hypothesis_structure[^.]*hook (gates|enforces)' '$ANALYSIS_MD' '$EVALSYS_MD' '$SECURITY_MD'"

# =============================================================================
echo ""
echo "=== A3-PROCEDURE (RED discriminator) — issue auto-close pre-verification procedure ==="
# The structure-gate FAIL disposition executes a destructive `gh issue close`
# (analysis.md's new-issue/gap-item-low path). Before that, the orchestrator
# must confirm the recorded gate_hypothesis_structure scores actually meet
# the FAIL condition per the CLAUDE.md thresholds — currently undocumented
# (analysis.md never mentions `gh issue close` or a pre-close score check).

assert_true "A3-PROCEDURE-a: analysis.md documents the 'gh issue close' auto-close step explicitly" \
  "grep -qF 'gh issue close' '$ANALYSIS_MD'"
assert_true "A3-PROCEDURE-b: analysis.md documents a pre-close confirmation that scores meet the FAIL condition" \
  "grep -qiE 'confirms?.*(FAIL condition|thresholds)' '$ANALYSIS_MD'"

# =============================================================================
echo ""
echo "=== AC-CI-REGISTER (guard) — suite wired into e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-843-doc-assertions.sh" \
    "grep -q 'test-issue-843-doc-assertions' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B20 'test-issue-843-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-843-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-843-doc-assertions.sh'"
else
  assert_true "AC-CI-a: $CI_WORKFLOW exists" "false"
  echo "  SKIP: AC-CI-b/c (workflow file missing)"
  TESTS=$((TESTS + 2))
fi

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
