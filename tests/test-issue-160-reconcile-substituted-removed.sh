#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js tests/lib/architect-turn-harness.mjs docs/autoflow-guide.md docs/teammate-contracts.md
# lane: cycle-scoped
# retire-with: #160
# cycle-arm: #160
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #160 — Reconcile's `substituted` finding is retired
# =============================================================================
# `substituted` ("the row asserts a different property than the issue's") is a
# semantic reading. Asked of a comparison channel that is forbidden to judge,
# it degraded to a wording comparison and failed both ways: it paused #157
# cycle 1 on a legitimate one-AC-two-rows split, and it passes a real
# misreading that keeps the wording. The finding set narrows to the two kinds
# computable without reading meaning — `dropped` / `unreasoned` — and the
# "does the row verify the AC's property" judgment is named where an
# AC-reading rubric already exists (GATE:PLAN Test plan).
#
# Three halves:
#   1. BEHAVIOR — the #160 scenarios in tests/lib/architect-turn-harness.mjs
#      run the real script: the #157 shape converges (AC2), a stray legacy
#      `substituted` list is ignored, `dropped` / `unreasoned` still pause (AC3).
#   2. STATICS — the script's AC_DIFF schema, well-formedness predicate and
#      ac-diff prompt carry no `substituted` reading (AC1).
#   3. DOCS — the guide's Reconcile table and GATE:PLAN AC-authority check list
#      two states; the Test plan item names the property-judgment (AC4).
#
# CYCLE-SCOPED by construction: the behavioral half re-reads the harness the
# standing #152 suite executes on every run, so the two-kind contract stays
# protected after this suite retires. The literals and doc wording verify this
# issue's acceptance criteria once.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
allow_list=(
  ".claude/workflows/architect-deliberation.js"
  "tests/lib/architect-turn-harness.mjs"
  "tests/fixtures/issue-160-ac-diff-split-rows.json"
  "docs/autoflow-guide.md"
  "docs/teammate-contracts.md"
)
WF="$PROJECT_ROOT/${allow_list[0]}"
HARNESS="$PROJECT_ROOT/${allow_list[1]}"
FIXTURE="$PROJECT_ROOT/${allow_list[2]}"
GUIDE="$PROJECT_ROOT/${allow_list[3]}"
CONTRACTS="$PROJECT_ROOT/${allow_list[4]}"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
# 0. Fixture — the transcription of the #157 shape carries no `substituted` list
#    and every row is carried.
# -----------------------------------------------------------------------------
echo "== fixture: #157 cycle-1 split-rows transcription =="
if jq -e '.ac_source_present == true and (has("substituted") | not)
  and (([.ac_rows[] | select(.carried == true)] | length) == (.ac_rows | length))' "$FIXTURE" >/dev/null 2>&1; then
  pass "fixture: all rows carried, no substituted list"
else
  failc "fixture: $FIXTURE does not carry the expected shape"
fi

# -----------------------------------------------------------------------------
# 1. Behavior
# -----------------------------------------------------------------------------
echo "== behavior: #160 harness scenarios =="
if command -v node >/dev/null 2>&1; then
  sim_out=$(node "$HARNESS" "$PROJECT_ROOT" 2>&1)
  sim_rc=$?
  printf '%s\n' "$sim_out" | grep "issue-160" | sed 's/^/    /'
  for sc in issue-160-split-rows-no-pause \
            issue-160-ac-diff-prompt-no-property-comparison \
            issue-160-legacy-substituted-list-ignored \
            issue-160-dropped-still-pauses \
            issue-160-unreasoned-still-pauses \
            issue-160-dropped-authorized-by-ledger; do
    if printf '%s\n' "$sim_out" | grep -qx "$sc PASS"; then
      pass "behavior: $sc"
    else
      failc "behavior: $sc did not PASS"
    fi
  done
  if [ "$sim_rc" = "0" ]; then
    pass "behavior: harness exit 0 (no scenario regressed)"
  else
    failc "behavior: harness exit $sim_rc"
  fi
else
  failc "behavior: node is required to execute the workflow harness and is not installed"
fi

# -----------------------------------------------------------------------------
# 2. Statics — AC1: two kinds, no semantic instruction.
# -----------------------------------------------------------------------------
echo "== statics: script carries two kinds and no property comparison =="
if grep -q "required: \['ac_source_present', 'ac_rows', 'ledger_ac_decisions'\]," "$WF" \
   && ! grep -q "AC_SUBSTITUTION" "$WF" \
   && ! grep -q "kind: 'substituted'" "$WF"; then
  pass "statics: AC_DIFF has no substituted list and no substituted finding"
else
  failc "statics: a substituted schema/finding survives in $WF"
fi
if grep -q "DIFFERENT property" "$WF"; then
  failc "statics: the ac-diff prompt still asks for a property comparison"
else
  pass "statics: no property-comparison instruction in the ac-diff prompt"
fi
if grep -q "if (!row.carried) return 'dropped'" "$WF" \
   && grep -q "if (row.disposition === 'reduced' && !row.reason_stated) return 'unreasoned'" "$WF" \
   && [ "$(grep -c "return '[a-z]*'$" <(sed -n '/^const acKindOf/,/^}/p' "$WF"))" = "2" ]; then
  pass "statics: acKindOf derives exactly dropped / unreasoned"
else
  failc "statics: acKindOf's kind table is not the two-kind table"
fi

# -----------------------------------------------------------------------------
# 3. Docs — AC1 (two states) and AC4 (Test plan responsibility).
# -----------------------------------------------------------------------------
echo "== docs: two-state finding set; Test plan names the property judgment =="
# shellcheck disable=SC2016  # backticks are literal Markdown, not a command
if grep -qF '| `substituted` |' "$GUIDE"; then
  failc "docs: the Reconcile finding table still lists substituted"
else
  pass "docs: the Reconcile finding table lists no substituted row"
fi
# PR #163 review (Low): the ARCHITECT section's prose must not list "a row asserting a different
# property" as a tier-3 state — the token-free wording the substituted grep cannot catch. Scoped to
# the Acceptance-criterion change section (its heading to the next level-3 heading).
ac_section=$(sed -n '/^### Acceptance-criterion change/,/^### /p' "$GUIDE")
if [ -n "$ac_section" ] && ! printf '%s\n' "$ac_section" | grep -qiE "row asserting a different property|asserts a different property than the issue's"; then
  pass "docs: ARCHITECT prose lists no different-property tier-3 state"
else
  failc "docs: ARCHITECT > Acceptance-criterion change still lists a different-property state (or the section was not found)"
fi
if grep -q "exactly two states" "$GUIDE"; then
  pass "docs: GATE:PLAN AC-authority check describes two states"
else
  failc "docs: GATE:PLAN AC-authority check does not describe two states"
fi
if grep -q "^| Test plan .*property the AC" "$GUIDE"; then
  pass "docs: GATE:PLAN Test plan item names the AC-property judgment"
else
  failc "docs: GATE:PLAN Test plan item does not name the AC-property judgment"
fi
# shellcheck disable=SC2016  # backticks are literal Markdown, not a command
if grep -qF '`dropped` / `unreasoned` / `substituted`' "$CONTRACTS"; then
  failc "docs: teammate-contracts.md still lists the three-kind set"
else
  pass "docs: teammate-contracts.md lists no substituted kind"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
