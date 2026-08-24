#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/autoflow/spawn-policy.json scripts/spawn-policy/spawn-policy.sh tests/lib/architect-turn-harness.mjs
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #152 — ARCHITECT turn-based convergence
# =============================================================================
# The deliberation terminates ONLY when two consecutive turns both report
# `modified: false, accept: true`; everything else continues to the next
# participant. The retired convergence machinery — the ACCEPT/COUNTER/PARTIAL
# verdict enum, the cap-round closing half-round (#123), and the resume
# open-entry convergence guard (#127 cycle 3) — must stay retired, and the
# turn ceilings must live in .claude/autoflow/spawn-policy.json >
# deliberation_caps rather than as code literals.
#
# Two halves:
#   1. BEHAVIOR — tests/lib/architect-turn-harness.mjs executes the real
#      workflow script with stubbed runtime hooks and asserts the issue's own
#      simulation cases (A–D) plus the bounded / resume / missing-turn /
#      caps-fail-closed paths against the shipped config.
#   2. STATICS — the retired mechanisms are absent from the script and the
#      config, the ceilings are config-read (no numeric ceiling literal in the
#      script), and `spawn-policy.sh check` fails a caps-less config.
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
# silent SKIP would report turn semantics nobody executed.
# -----------------------------------------------------------------------------
echo "== behavior: turn-convergence simulations (issue #152 cases A-D + guards) =="
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
# 2. Statics — retired mechanisms stay retired; ceilings are config-read.
# -----------------------------------------------------------------------------
echo "== statics: retired convergence machinery is absent =="

# The verdict enum is retired: the per-turn schema reports modified/accept.
if grep -qE "enum: \['ACCEPT'" "$WF"; then
  failc "statics: the ACCEPT/COUNTER/PARTIAL verdict enum survives in $WF"
else
  pass "statics: no ACCEPT/COUNTER/PARTIAL verdict enum in the script"
fi
if grep -q "'modified', 'accept'" "$WF"; then
  pass "statics: the turn schema requires modified + accept"
else
  failc "statics: the turn schema does not require modified + accept"
fi

# The closing half-round (#123) and its site key are retired everywhere the
# three-way site-key join reads: script marker list, call sites, config rows.
if grep -q "test-closing" "$WF" || jq -e '.workflow_sites["architect-deliberation"]["test-closing"]' "$CONFIG" >/dev/null 2>&1; then
  failc "statics: the test-closing site key survives in the script or config"
else
  pass "statics: no test-closing site key in script or config"
fi
if grep -qi "closing half-round" "$WF"; then
  failc "statics: closing-half-round machinery survives in $WF"
else
  pass "statics: no closing half-round in the script"
fi

# The resume open-entry convergence guard (#127 cycle 3) is retired: the
# register is a record and the resume agenda, never a termination input.
if grep -q "openEntryDenied\|resume register still open at convergence" "$WF"; then
  failc "statics: the resume open-entry convergence guard survives in $WF"
else
  pass "statics: no register-based convergence guard in the script"
fi

# The termination predicate exists and pairs the previous turn with the
# current one — the issue's own suggested shape.
if grep -q "agreedWithoutChange(prevTurn) && agreedWithoutChange(result)" "$WF"; then
  pass "statics: convergence is the two-consecutive-unmodified-accepts pair"
else
  failc "statics: the paired-turn termination predicate is missing"
fi

echo "== statics: turn ceilings are config values =="

# No numeric ceiling literal in the script: the only ceiling sources are the
# config row and the resume's structural +2.
if grep -qE "MAX_ROUNDS|BOUNDED_ROUNDS|MAX_TURNS *= *[0-9]" "$WF"; then
  failc "statics: a hardcoded ceiling literal survives in $WF"
else
  pass "statics: no hardcoded ceiling literal in the script"
fi
if grep -q "deliberation_caps" "$WF" && grep -q "spawn policy deliberation caps incomplete" "$WF"; then
  pass "statics: the script reads deliberation_caps and fails closed without it"
else
  failc "statics: the script does not read deliberation_caps / carry its fail-closed sentinel"
fi
for capkey in max_turns bounded_max_turns; do
  if jq -e --arg k "$capkey" '.deliberation_caps["architect-deliberation"][$k] | (type == "number") and (. == floor) and (. >= 2)' "$CONFIG" >/dev/null 2>&1; then
    pass "statics: config deliberation_caps.architect-deliberation.$capkey is an integer >= 2"
  else
    failc "statics: config deliberation_caps.architect-deliberation.$capkey is absent or malformed"
  fi
done

# check rejects a caps-less config and passes the real one.
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/.claude/autoflow" "$SCRATCH/.claude/agents"
cp "$PROJECT_ROOT/.claude/agents/"*.md "$SCRATCH/.claude/agents/" 2>/dev/null
jq 'del(.deliberation_caps)' "$CONFIG" > "$SCRATCH/.claude/autoflow/spawn-policy.json"
if AUTOFLOW_SPAWN_POLICY="$SCRATCH/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1; then
  failc "statics: spawn-policy.sh check passed a config with no deliberation_caps"
else
  pass "statics: spawn-policy.sh check rejects a caps-less config"
fi
rm -rf "$SCRATCH"
if bash "$RESOLVER" check >/dev/null 2>&1; then
  pass "statics: the real config passes check"
else
  failc "statics: the real config fails check"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
