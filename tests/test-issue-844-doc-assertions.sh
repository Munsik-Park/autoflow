#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: PREFLIGHT disposition & re-entry matrix consistency — Issue #844
# =============================================================================
# Tier-1 scripted static assertion suite per verification design
# (.autoflow/issue-844-verification-design.md). Docs-only surface (no
# jest/npm/network) — mirrors tests/test-issue-843-doc-assertions.sh /
# tests/test-issue-846-doc-assertions.sh: assert_true/assert_false over
# grep + doc-region extraction.
#
# AC1 flow-routing-1 — PR-less `active:false` (`awaiting-user`) PREFLIGHT
#   disposition (preserve, do NOT delete), mirrored in CLAUDE.md PR Wait Rule,
#   discriminated from the open-PR `awaiting-user` reading.
# AC2 midcycle-resume-1 — requested issue's own `active:true` → deterministic
#   Resume procedure (4 ordered steps), textually separate from
#   review-response entry, cross-referenced from CLAUDE.md.
# AC-B3 (branch-source, resolves C4) — PREFLIGHT Step 5 documents
#   `dev/YYYY-MM-DD-issue-N`; the review-response setup no longer claims the
#   branch is "recorded in `.autoflow/issue-{target}.json}`"; Resume step 2
#   resolves the branch via `git branch --list 'dev/*-issue-<N>'`.
# AC3 contracts-eval-3 — teammate-common-rules.md Absolute rule narrowed to
#   same-issue open-PR scope; cross-issue succession deferred to PR Wait Rule.
# AC4 flow-routing-3 — GATE:HYPOTHESIS/AUDIT escalation prose corrected to
#   "Third FAIL → human" (off-by-one vs `max 2×`); CLAUDE.md states the
#   per-gate (N+1)th-FAIL rule once; diagram mirror (`retry ≤2×`) unchanged.
#
# Not in this file (verification design AC2 §"Testability assessment" —
# residual manual item): step-3's "conservative default" soundness judgment
# is routed to the VALIDATE/GATE:PLAN manual checklist, not grep-checkable.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
TEAMMATE_MD="$PROJECT_ROOT/docs/teammate-common-rules.md"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_true/assert_false pattern per test-issue-843-doc-assertions.sh)
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

# Region extractors — the PREFLIGHT Step-1 cell, the Resume-procedure block
# (if any), and the review-response setup block. Extracted once and reused so
# the assertions below read a stable slice rather than re-deriving line
# ranges from a shifting doc.

# PREFLIGHT Step-1 table cell: the single "| 1 | ... |" row.
STEP1_CELL="$(grep -m1 '^| 1 |' "$GUIDE_MD" 2>/dev/null || true)"

# PREFLIGHT Step-5 table cell: the single "| 5 | ... |" row.
STEP5_CELL="$(grep -m1 '^| 5 |' "$GUIDE_MD" 2>/dev/null || true)"

# Review-response mode setup paragraph (bold-lead line).
REVIEW_RESPONSE_SETUP="$(grep -m1 '^\*\*Review-response mode setup\*\*' "$GUIDE_MD" 2>/dev/null || true)"

# Resume procedure block (heading through the next blank-line-delimited
# section) — grabbed with a wide window since GREEN may insert it anywhere
# under PREFLIGHT; absent on current HEAD (RED expectation).
RESUME_BLOCK="$(awk '/\*\*Resume procedure\*\*/{flag=1} flag{print} flag && /^---$/{exit}' "$GUIDE_MD" 2>/dev/null || true)"

# CLAUDE.md PR Wait Rule requested-issue mode-selection sentence — the
# specific paragraph AC1/AC2 edit, not the whole file (avoids vacuous
# passes against unrelated `phase:"awaiting-user"` / "no PR" occurrences
# elsewhere in CLAUDE.md, e.g. the HANDOFF review-triage rows).
PR_WAIT_MODE_PARA="$(grep -m1 '^For the \*\*requested\*\* issue, read its own state file' "$CLAUDE_MD" 2>/dev/null || true)"

# =============================================================================
echo "=== AC1 (flow-routing-1) — PR-less active:false(awaiting-user) PREFLIGHT disposition ==="
# =============================================================================

assert_true "AC1-a: PREFLIGHT Step-1 cell states a case keyed on active:false + awaiting-user + no PR" \
  "printf '%s' \"\$STEP1_CELL\" | grep -qF 'phase:\"awaiting-user\"' && printf '%s' \"\$STEP1_CELL\" | grep -qiE 'no PR (yet|exist)'"

assert_true "AC1-b: the new case's disposition is preserve / do NOT archive (issue #978 delete->archive rewrite)" \
  "printf '%s' \"\$STEP1_CELL\" | grep -qiE 'preserve.*do NOT archive|do NOT archive.*preserve'"

assert_true "AC1-c: the merged/closed archive path still requires an observed PR (safety net unchanged; issue #978 delete->archive rewrite)" \
  "printf '%s' \"\$STEP1_CELL\" | grep -qF 'merged or closed' && printf '%s' \"\$STEP1_CELL\" | grep -qF \"archive the issue's \\\`.autoflow/issue-{N}*\\\` files\""

assert_true "AC1-d: CLAUDE.md PR Wait Rule mode-selection sentence mirrors the PR-less awaiting-user reading" \
  "printf '%s' \"\$PR_WAIT_MODE_PARA\" | grep -qF 'phase:\"awaiting-user\"' && printf '%s' \"\$PR_WAIT_MODE_PARA\" | grep -qiE 'no PR'"

assert_true "AC1-e (discriminator): the same sentence keeps the open-PR review-response reading textually distinct from the new no-PR case" \
  "printf '%s' \"\$PR_WAIT_MODE_PARA\" | grep -qF 'active:false\` with an open PR'"

# =============================================================================
echo ""
echo "=== AC2 (midcycle-resume-1) — Resume procedure for requested issue's own active:true ==="
# =============================================================================

assert_true "AC2-a: PREFLIGHT Step-1 cell states a requested-issue active:true → resume branch, distinct from another-issue's report-and-hold" \
  "printf '%s' \"\$STEP1_CELL\" | grep -qiE \"requested issue'?s? own (state )?\\\`?active:true\\\`? → resume\" && printf '%s' \"\$STEP1_CELL\" | grep -qiE 'another issue \`?active:true\`? → report and hold'"

assert_true "AC2-b: a 'Resume procedure' heading exists under docs/autoflow-guide.md PREFLIGHT" \
  "grep -qF '**Resume procedure**' '$GUIDE_MD'"

assert_true "AC2-c: the Resume procedure documents reading the last confirmed point from phases/phase" \
  "printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 'last (confirmed|passed) (point|gate)' && printf '%s' \"\$RESUME_BLOCK\" | grep -qF 'phases'"

assert_true "AC2-d: the Resume procedure documents verifying resume prerequisites (dev branch + .autoflow artifacts)" \
  "printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 'verify the resume prerequisites|prerequisites' && printf '%s' \"\$RESUME_BLOCK\" | grep -qF '.autoflow/issue-'"

assert_true "AC2-e: the Resume procedure documents conservative re-entry after the last passed gate (re-run a gate lacking recorded scores)" \
  "printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 're-enter|re-run' && printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 'scores'"

assert_true "AC2-f (invariant 3): the Resume procedure states it does NOT increment cycle and does NOT reset phases" \
  "printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 'does not.*increment.*cycle|not.*increment \`?cycle\`?' && printf '%s' \"\$RESUME_BLOCK\" | grep -qiE 'does not.*reset.*phases|not.*reset \`?phases\`?'"

assert_true "AC2-g (invariant 3): the Resume procedure block is textually separate from the Review-response mode setup block" \
  "[ -n \"\$RESUME_BLOCK\" ] && [ -n \"\$REVIEW_RESPONSE_SETUP\" ] && ! printf '%s' \"\$REVIEW_RESPONSE_SETUP\" | grep -qF 'Resume procedure' && ! printf '%s' \"\$RESUME_BLOCK\" | grep -qF 'Review-response mode setup'"

assert_true "AC2-h: CLAUDE.md's active:true mode-selection reading cross-references the playbook Resume procedure section (not a dangling mention)" \
  "printf '%s' \"\$PR_WAIT_MODE_PARA\" | grep -qiE 'resume the in-progress cycle.*Resume procedure'"

# =============================================================================
echo ""
echo "=== AC-B3 (branch-source, invariant 7 — resolves C4) ==="
# =============================================================================

assert_true "AC-B3-a: PREFLIGHT Step 5 documents the issue-scoped dev-branch convention dev/YYYY-MM-DD-issue-N" \
  "printf '%s' \"\$STEP5_CELL\" | grep -qF 'dev/YYYY-MM-DD-issue-N'"

assert_false "AC-B3-b: the bare dev/YYYY-MM-DD create command (no -issue suffix) no longer stands alone as the create command" \
  "printf '%s' \"\$STEP5_CELL\" | grep -qF 'git checkout -b dev/YYYY-MM-DD main'"

assert_false "AC-B3-c: the review-response setup no longer claims the branch is recorded in .autoflow/issue-{target}.json" \
  "printf '%s' \"\$REVIEW_RESPONSE_SETUP\" | grep -qiE 'recorded in .*issue-\\{target\\}\\.json'"

assert_true "AC-B3-d: the review-response setup derives the branch from the Step-5 naming convention instead" \
  "printf '%s' \"\$REVIEW_RESPONSE_SETUP\" | grep -qiE 'naming convention|Step-?5'"

assert_true "AC-B3-e: the Resume procedure resolves the branch via git branch --list against the dev/*-issue-<N> convention" \
  "printf '%s' \"\$RESUME_BLOCK\" | grep -qF \"git branch --list 'dev/*-issue-<N>'\""

# =============================================================================
echo ""
echo "=== AC3 (contracts-eval-3) — teammate Absolute rule reconciled with PR Wait Rule ==="
# =============================================================================

assert_false "AC3-a: teammate-common-rules.md no longer contains the unqualified 'previous PR is still unmerged' prohibition" \
  "grep -qF 'No work on a new branch while the previous PR is still unmerged.' '$TEAMMATE_MD'"

assert_true "AC3-b: the narrowed rule scopes the new-branch prohibition to the SAME issue's open PR" \
  "grep -qiE 'same.issue' '$TEAMMATE_MD'"

assert_true "AC3-c: the narrowed rule references PR Wait Rule / the active flag for cross-issue succession" \
  "grep -qiE 'PR Wait Rule' '$TEAMMATE_MD' && grep -qF '\`active\`' '$TEAMMATE_MD'"

# =============================================================================
echo ""
echo "=== AC4 (flow-routing-3) — gate-FAIL escalation timing (prose = diagram) ==="
# =============================================================================

assert_false "AC4-a: docs/autoflow-guide.md no longer contains 'Two FAILs' at GATE:HYPOTHESIS or AUDIT" \
  "grep -qF 'Two FAILs' '$GUIDE_MD'"

assert_true "AC4-b: docs/autoflow-guide.md states 'Third FAIL → human' at GATE:HYPOTHESIS" \
  "grep -qF 'DIAGNOSE (max 2×). Third FAIL → human decision.' '$GUIDE_MD'"

assert_true "AC4-c: docs/autoflow-guide.md states 'Third FAIL → human' at AUDIT" \
  "grep -qF 're-evaluate (max 2×). Third FAIL → human.' '$GUIDE_MD'"

assert_false "AC4-d: CLAUDE.md no longer states the bare '3 regressions without pass'" \
  "grep -qF '3 regressions without pass' '$CLAUDE_MD'"

assert_true "AC4-e: CLAUDE.md's Human escalation line states the per-gate (N+1)th-FAIL rule, not a cross-gate total" \
  "grep -qiE 'per.gate' '$CLAUDE_MD' && grep -qiE '\\(N\\+1\\)' '$CLAUDE_MD'"

assert_true "AC4-f: the cap→escalation arithmetic is defined once on the Regressions line" \
  "grep -qiE '^\\*\\*Regressions\\*\\*.*\\(N\\+1\\)' '$CLAUDE_MD'"

assert_true "AC4-g (invariant 4, diagram-unchanged): the diagram mirror still reads retry ≤2× for GATE:HYPOTHESIS" \
  "grep -qF 'GATE:HYPOTHESIS (cause, bug only) ◄── retry ≤2×' '$GUIDE_MD'"

assert_true "AC4-g2 (invariant 4, diagram-unchanged): the diagram mirror still reads retry ≤2× for AUDIT" \
  "grep -qF 'AUDIT  ◄── retry ≤2×' '$GUIDE_MD'"

assert_true "AC4-h (single-definition): the (N+1)th-FAIL cap→escalation arithmetic is stated exactly once in CLAUDE.md" \
  "[ \"\$(grep -oE '\\(N\\+1\\)' '$CLAUDE_MD' | wc -l | tr -d ' ')\" = '1' ]"

# =============================================================================
echo ""
echo "=== AC-CI-REGISTER (guard) — suite wired into e2e-dummy-target.yml ==="
# =============================================================================

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-844-doc-assertions.sh" \
    "grep -q 'test-issue-844-doc-assertions' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B40 'test-issue-844-doc-assertions' '$CI_WORKFLOW' | head -40); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-844-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-844-doc-assertions.sh'"
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
