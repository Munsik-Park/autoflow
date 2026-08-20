#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js test/workflows/run.mjs tests/lib/harness-pins.sh tests/lib/base-ref.sh
# lane: cycle-scoped
# retire-with: #123
# cycle-arm: #123
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
# =============================================================================
# Test: shipped-script / harness literal-drift guard — Issue #123
# =============================================================================
# Verification design (.autoflow/issue-123-verification-design.md) >
# Verification depth: the mock-runtime harness (test/workflows/run.mjs) loads
# .claude/workflows/architect-deliberation.js as source text and wraps it in an
# AsyncFunction (test/workflows/run.mjs:29-33) — it cannot `import` the script,
# so a module-level constant such as CLOSING_CALL_LABEL or
# REASON_CLOSING_AGENT_MISSING is unreachable from harness code. The harness
# therefore spells both literals itself (test/workflows/run.mjs, AC1-AC13
# fixtures under "ARCHITECT: cap-round closing half-round"); this suite is the
# ONLY layer that can catch the two spellings drifting apart, by grepping both
# copies out of the real files and comparing them directly — no other
# verification layer reads both sources at once (Verification depth: "no other
# layer runs the generator, the allocator, or the pin comparison").
#
# The composition oracle's other two rows stand elsewhere on purpose (leaf
# rule, scripts/test/check-suite-leaf.sh: a suite executes its own subject, not
# a sibling's): the HARNESS_OK_COUNT pin-vs-measurement oracle already lives in
# the standing tests/test-issue-27-composition-oracle.sh (AC-27-20c), which
# reruns automatically against this cycle's harness/pin edit; the
# setup/manifest.json freshness oracle for architect-deliberation.js already
# lives in the same suite (AC-27-21b). Neither is re-asserted here.
#
# RED-time expectation: architect-deliberation.js carries neither constant yet
# (Developer AI ships them at GREEN per the feature design's "Missing closing
# agent" / "Prompt composition" sections), so both AC-123-drift-* cases below
# FAIL until GREEN lands the two `const` declarations at the exact literal
# values the feature design commits to:
#   const CLOSING_CALL_LABEL = 'test-closing'
#   const REASON_CLOSING_AGENT_MISSING = 'closing agent missing'
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
HARNESS="$PROJECT_ROOT/test/workflows/run.mjs"
PINS="$PROJECT_ROOT/tests/lib/harness-pins.sh"

# shellcheck source=tests/lib/base-ref.sh
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

note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }

# Extracts a `const NAME = '...'` literal's quoted value from a file. Empty
# output means the constant is not declared there at all (the RED state for
# architect-deliberation.js) — that empty/present asymmetry is exactly what a
# plain string-equality comparison below turns into a FAIL rather than a
# vacuous pass.
extract_const() {            # const_name file
  local name="$1" file="$2"
  grep -m1 -E "const[[:space:]]+${name}[[:space:]]*=" "$file" 2>/dev/null \
    | sed -E "s/.*const[[:space:]]+${name}[[:space:]]*=[[:space:]]*'([^']*)'.*/\\1/"
}

# =============================================================================
echo "=== AC-123-drift-closing-label — CLOSING_CALL_LABEL identical in the shipped script and the harness ==="

SHIPPED_LABEL="$(extract_const CLOSING_CALL_LABEL "$WORKFLOW_JS")"
HARNESS_LABEL="$(extract_const CLOSING_CALL_LABEL "$HARNESS")"
echo "  (info) shipped script: '${SHIPPED_LABEL:-<absent>}'  harness: '${HARNESS_LABEL:-<absent>}'"
assert_true "AC-123-drift-closing-label: the shipped script declares CLOSING_CALL_LABEL and it matches the harness's own spelling ('test-closing')" \
  "[ -n \"$SHIPPED_LABEL\" ] && [ \"$SHIPPED_LABEL\" = \"$HARNESS_LABEL\" ]"

# =============================================================================
echo ""
echo "=== AC-123-drift-closing-missing-reason — REASON_CLOSING_AGENT_MISSING identical in the shipped script and the harness ==="

SHIPPED_REASON="$(extract_const REASON_CLOSING_AGENT_MISSING "$WORKFLOW_JS")"
HARNESS_REASON="$(extract_const REASON_CLOSING_AGENT_MISSING "$HARNESS")"
echo "  (info) shipped script: '${SHIPPED_REASON:-<absent>}'  harness: '${HARNESS_REASON:-<absent>}'"
assert_true "AC-123-drift-closing-missing-reason: the shipped script declares REASON_CLOSING_AGENT_MISSING and it matches the harness's own spelling ('closing agent missing')" \
  "[ -n \"$SHIPPED_REASON\" ] && [ \"$SHIPPED_REASON\" = \"$HARNESS_REASON\" ]"

# =============================================================================
echo ""
echo "=== AC-123-pin-sanity — the harness ok-count pin bump landed in tests/lib/harness-pins.sh ==="
# Fence, not a RED discriminator: confirms this cycle's own pin edit is
# present and well-formed. The pin-vs-measurement comparison itself is the
# standing tests/test-issue-27-composition-oracle.sh oracle (leaf rule).

assert_true "AC-123-pin-sanity: tests/lib/harness-pins.sh declares a positive-integer HARNESS_OK_COUNT" \
  "grep -qE '^HARNESS_OK_COUNT=[0-9]+' '$PINS'"

# =============================================================================
echo ""
echo "=== cycle-scope-respected — this cycle's own branch diff stays within its declared allow_list ==="

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-123|dev/*-issue-123-*) return 0 ;;
    *) return 1 ;;
  esac
}

# The feature design's Change surface table plus this cycle's own RED
# artifacts (.autoflow/* is gitignored scratch and never appears in a diff).
allow_list=(
  # Feature (GREEN/REFINE) surface
  ".claude/workflows/architect-deliberation.js"
  "docs/teammate-contracts.md"
  "docs/autoflow-guide.md"
  "CLAUDE.md"
  "setup/manifest.json"
  # Verification (RED, this suite's own commit) surface
  "test/workflows/run.mjs"
  "tests/lib/harness-pins.sh"
  "tests/fixtures/doc-invariants.json"
  "tests/test-issue-123-closing-half-round.sh"
  "tests/manual/issue-123-manual-scenarios.md"
  ".github/workflows/contract-suites.yml"
  # VERIFY step 1 SEQUENTIAL_FIX (this cycle's own re-anchoring commit): standing
  # tripwires whose fixed counts/literals moved with the closing half-round.
  "tests/test-issue-103-cycle-scope-repoint.sh"
  "tests/test-issue-56-carry-evidence-discipline.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
)

if on_issue_branch; then
  BASE_REF_SCOPE="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_SCOPE:-}" ]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF_SCOPE"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-123-SCOPE: cycle diff set-differenced against the declared allow_list is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  else
    echo "  BLOCK: no comparison base resolvable — AC-123-SCOPE counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-123-SCOPE: change-surface guard inert off the issue-123 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
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
