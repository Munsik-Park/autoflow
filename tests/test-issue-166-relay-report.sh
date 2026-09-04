#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/autoflow/spawn-policy.json scripts/spawn-policy/spawn-policy.sh tests/lib/architect-turn-harness.mjs
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #166 — ARCHITECT deliberation in its original form (relay + report)
# =============================================================================
# The Developer AI and the Test AI discuss the design in relayed turns: one
# fixed prompt per role plus the same Topic and the transcript so far. The
# discussion ends when two consecutive turns both report `done: true`. Each
# participant then reports what was agreed and what was not, a scribe writes
# the two design documents and the report, and the ledger records the agreed
# conclusions. The orchestrator judges the report; the workflow reaches no
# verdict of its own.
#
# Two halves:
#   1. BEHAVIOR — tests/lib/architect-turn-harness.mjs executes the real
#      workflow script with stubbed runtime hooks and asserts the relay,
#      the termination pair, the missing-turn dispositions, the Report and
#      Record calls, the ledger condition, the brief and the return shape,
#      against the shipped config.
#   2. STATICS — the retired verdict machinery is absent from the script and
#      the config, the four workflow site keys are exactly the config's rows,
#      and `spawn-policy.sh check` passes the shipped config while rejecting a
#      malformed architect row.
#
# Fail-closed on a MISSING required site row is the SCRIPT's property, not
# `check`'s: the workflow's own row-totality guard stops the run with
# `spawn policy row incomplete (<keys>)` before any other call, which the
# behavior half asserts per key. `check` validates each row that is present;
# the declaration = call sites = config rows join is
# tests/test-spawn-policy-single-source.sh > required-key-declaration-join.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
CONFIG="$PROJECT_ROOT/.claude/autoflow/spawn-policy.json"
RESOLVER="$PROJECT_ROOT/scripts/spawn-policy/spawn-policy.sh"
HARNESS="$PROJECT_ROOT/tests/lib/architect-turn-harness.mjs"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
# 1. Behavior — the harness runs the real script against the real config.
# Fail-loud on a missing node: the behavioral half is this suite's core, so a
# silent SKIP would report relay semantics nobody executed.
# -----------------------------------------------------------------------------
echo "== behavior: relay / report / record simulations (issue #166) =="
if command -v node >/dev/null 2>&1; then
  sim_out=$(node "$HARNESS" "$PROJECT_ROOT" 2>&1)
  sim_rc=$?
  printf '%s\n' "$sim_out" | sed 's/^/    /'
  if [ "$sim_rc" = "0" ] && ! printf '%s' "$sim_out" | grep -q "FAIL"; then
    pass "behavior: all harness scenarios pass"
  else
    failc "behavior: harness reported a failure (exit $sim_rc)"
  fi
else
  failc "behavior: node is required to execute the workflow harness and is not installed"
fi

# -----------------------------------------------------------------------------
# 2a. Statics — the retired verdict machinery is gone from the script.
# -----------------------------------------------------------------------------
echo "== statics: the retired verdict machinery is absent from the script =="

# Each row: <label>|<grep -E pattern>. A hit is a failure.
retired_patterns=(
  "the deliberation_caps turn ceilings|deliberation_caps"
  "the agreedWithoutChange convergence predicate|agreedWithoutChange"
  "the AC_CHANGE verdict|AC_CHANGE"
  "the CONVERGED / ESCALATE verdicts|CONVERGED|ESCALATE"
  "a returned verdict|verdict"
  "the architect-register file|architect-register"
  "the resume path|\\bresume\\b"
  "the bounded turn ceiling|\\bbounded\\b"
  "the Reconcile phase|Reconcile"
  "the retired dispositions turn-report field|'dispositions'|dispositions:"
)
for row in "${retired_patterns[@]}"; do
  label="${row%%|*}"
  pattern="${row#*|}"
  if grep -qE "$pattern" "$WF"; then
    failc "statics: $label survives in $WF"
  else
    pass "statics: no $label in the script"
  fi
done

echo "== statics: the relay's own vocabulary is present =="

if grep -q "'message', 'done'" "$WF"; then
  pass "statics: the turn schema requires message + done"
else
  failc "statics: the turn schema does not require message + done"
fi
if grep -q "prevDone && result.done === true" "$WF"; then
  pass "statics: the discussion ends on two consecutive done turns"
else
  failc "statics: the two-consecutive-done termination predicate is missing"
fi
for sentinel in \
  "REASON_PARTICIPANT_MISSING = 'participant missing'" \
  "REASON_REPORT_MISSING = 'report missing'" \
  "REASON_SCRIBE_MISSING = 'scribe missing'"; do
  if grep -qF "$sentinel" "$WF"; then
    pass "statics: stop sentinel declared — ${sentinel%% =*}"
  else
    failc "statics: stop sentinel missing — ${sentinel%% =*}"
  fi
done
if grep -q "phases: \[" "$WF" && grep -q "title: 'Discuss'" "$WF" && grep -q "title: 'Report'" "$WF" && grep -q "title: 'Record'" "$WF"; then
  pass "statics: meta.phases are Discuss / Report / Record"
else
  failc "statics: meta.phases are not Discuss / Report / Record"
fi

# -----------------------------------------------------------------------------
# 2b. Statics — the config's own shape.
# -----------------------------------------------------------------------------
echo "== statics: the config carries exactly the four workflow site rows =="

if jq -e 'has("deliberation_caps")' "$CONFIG" >/dev/null 2>&1; then
  failc "statics: the config still carries a deliberation_caps object"
else
  pass "statics: the config carries no deliberation_caps object"
fi

declared=$(sed -n '/site-keys:begin/,/site-keys:end/p' "$WF" | sed -n "s/^ *'\([^']*\)',$/\1/p" | sort)
rows=$(jq -r '.workflow_sites["architect-deliberation"] | keys[]' "$CONFIG" | sort)
expected=$(printf '%s\n' dev-turn test-turn scribe ledger | sort)
if [ "$declared" = "$expected" ]; then
  pass "statics: the script declares exactly dev-turn / test-turn / scribe / ledger"
else
  failc "statics: the script's declared site keys are [$(echo "$declared" | tr '\n' ' ')]"
fi
if [ "$rows" = "$expected" ]; then
  pass "statics: the config's architect-deliberation rows are exactly the four site keys"
else
  failc "statics: the config's architect-deliberation rows are [$(echo "$rows" | tr '\n' ' ')]"
fi

echo "== statics: spawn-policy.sh check over the architect rows =="

if bash "$RESOLVER" check >/dev/null 2>&1; then
  pass "statics: the real config passes check"
else
  failc "statics: the real config fails check"
fi

# A row that is PRESENT but malformed is check's own arm: dropping the `effort`
# key is a validation error, never an inherit (effort_contract.absent_means).
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/.claude/autoflow" "$SCRATCH/.claude/agents"
cp "$PROJECT_ROOT/.claude/agents/"*.md "$SCRATCH/.claude/agents/" 2>/dev/null
for key in dev-turn test-turn scribe ledger; do
  jq --arg k "$key" 'del(.workflow_sites["architect-deliberation"][$k]["effort"])' "$CONFIG" \
    > "$SCRATCH/.claude/autoflow/spawn-policy.json"
  if AUTOFLOW_SPAWN_POLICY="$SCRATCH/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1; then
    failc "statics: check passed a config whose architect-deliberation.$key row carries no effort key"
  else
    pass "statics: check rejects an architect-deliberation.$key row carrying no effort key"
  fi
done
rm -rf "$SCRATCH"

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
