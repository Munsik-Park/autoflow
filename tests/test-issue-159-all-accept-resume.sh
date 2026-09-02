#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js tests/lib/architect-turn-harness.mjs docs/autoflow-guide.md docs/teammate-contracts.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #159 — the all-accept terminal state is resumable
# =============================================================================
# Under the #152 turn model a modifying turn never converges, so a deliberation
# whose participants accept the design and still polish a document each turn
# ends at the ceiling in {both accept, both modified, no open entry}. The
# resume guard refused that register ("no open entry") and the only path left
# was a cold restart — #157 cycle 1. Two mechanisms close the gap:
#
#   A. the resume admission reads the register's `lastResponses` (reduced to
#      each side's modified/accept) and admits the all-accept state as a
#      CONFIRMATION EXCHANGE; every other no-open-entry shape stays refused;
#   B. every Converge turn prompt states the convergence rule and "accept
#      without editing" in one sentence.
#
# Three halves:
#   1. BEHAVIOR — the #159 scenarios in tests/lib/architect-turn-harness.mjs
#      run the real script against the fixture register (the #157 cycle-1
#      shape, tests/fixtures/issue-159-register-all-accept.json).
#   2. STATICS — the script carries both rules and the reduced load shape.
#   3. DOCS — the operator guide describes the confirmation-exchange admission
#      and does not describe editing the register by hand as a procedure.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
HARNESS="$PROJECT_ROOT/tests/lib/architect-turn-harness.mjs"
FIXTURE="$PROJECT_ROOT/tests/fixtures/issue-159-register-all-accept.json"
GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
# 0. Fixture — the regression register has the #157 cycle-1 shape.
# -----------------------------------------------------------------------------
echo "== fixture: #157 cycle-1 register shape =="
if jq -e '.verdict == "ESCALATE"
  and ([.entries[] | select(.status == "open")] | length == 0)
  and .lastResponses.dev.accept == true and .lastResponses.test.accept == true
  and .lastResponses.dev.modified == true and .lastResponses.test.modified == true' "$FIXTURE" >/dev/null 2>&1; then
  pass "fixture: ESCALATE, zero open entries, both sides accept:true / modified:true"
else
  failc "fixture: $FIXTURE does not carry the all-accept terminal shape"
fi

# -----------------------------------------------------------------------------
# 1. Behavior — the harness runs the real script; the #159 scenarios must PASS.
# -----------------------------------------------------------------------------
echo "== behavior: #159 harness scenarios =="
if command -v node >/dev/null 2>&1; then
  sim_out=$(node "$HARNESS" "$PROJECT_ROOT" 2>&1)
  sim_rc=$?
  printf '%s\n' "$sim_out" | grep "issue-159" | sed 's/^/    /'
  for sc in issue-159-all-accept-terminal-admitted \
            issue-159-no-open-not-all-accept-refused \
            issue-159-legacy-register-no-open-refused \
            issue-159-confirmation-exchange-still-editing \
            issue-159-convergence-rule-on-every-turn; do
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
# 2. Statics — both rules and the reduced load shape live in the script.
# -----------------------------------------------------------------------------
echo "== statics: script carries the two mechanisms =="
if grep -q "Convergence rule: this deliberation terminates only when two consecutive turns both report modified: false, accept: true" "$WF" \
   && grep -q "If you accept the current design, do not edit either document — report modified: false" "$WF"; then
  pass "statics: CONVERGENCE_RULE states the pair condition and accept-without-editing"
else
  failc "statics: CONVERGENCE_RULE sentence is missing or reworded in $WF"
fi
if grep -q "This is a confirmation exchange" "$WF"; then
  pass "statics: CONFIRMATION_EXCHANGE_RULE is present"
else
  failc "statics: CONFIRMATION_EXCHANGE_RULE is missing from $WF"
fi
if grep -q "allAcceptTerminal(loaded.lastResponses)" "$WF" && grep -q "REASON_RESUME_NO_OPEN_ENTRY" "$WF"; then
  pass "statics: the no-open-entry guard is retained and gated by the all-accept check"
else
  failc "statics: the guard / all-accept check pair is missing from $WF"
fi
if grep -q "REGISTER_LAST_RESPONSE" "$WF" && grep -q "required: \['modified', 'accept'\]" "$WF"; then
  pass "statics: lastResponses loads in the reduced modified/accept shape"
else
  failc "statics: the reduced lastResponses load schema is missing from $WF"
fi
# The load schema keeps `lastResponses` OPTIONAL so a pre-#159 register still loads.
if grep -q "required: \['found', 'artifacts_present', 'lastTurn', 'verdict', 'entries'\]," "$WF"; then
  pass "statics: lastResponses is optional in the register load schema"
else
  failc "statics: the register load schema's required list changed"
fi

# -----------------------------------------------------------------------------
# 3. Docs — the adopted path is documented; the by-hand register edit is not.
# -----------------------------------------------------------------------------
echo "== docs: adopted path documented, register hand-edit not a procedure =="
if grep -q "confirmation exchange" "$GUIDE"; then
  pass "docs: autoflow-guide.md describes the confirmation-exchange admission"
else
  failc "docs: autoflow-guide.md does not mention the confirmation exchange"
fi
if grep -q "all-accept terminal state" "$CONTRACTS"; then
  pass "docs: teammate-contracts.md records the guard's admitted shape"
else
  failc "docs: teammate-contracts.md does not record the admitted shape"
fi
if grep -qiE "(add|insert|write|append) (an? )?(open|confirmation|placeholder) (register )?entr(y|ies) (to|into|in) (the )?register" "$GUIDE" "$CONTRACTS"; then
  failc "docs: an operator procedure to hand-edit the register survives"
else
  pass "docs: no operator register hand-edit procedure"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
