#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/autoflow/spawn-policy.json scripts/spawn-policy/spawn-policy.sh .claude/agents/autoflow-planner.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #166 / #179 — ARCHITECT deliberation: the record workflow and the
#       relay's policy rows (statics)
# =============================================================================
# Issue #166 restored the deliberation to its original form: the Developer AI
# and the Test AI discuss in relayed turns, the discussion ends when two
# consecutive turns both say "nothing further", each participant reports, a
# scribe writes the two design documents and the report, and the ledger
# records the agreed conclusions. Issue #179 (ADR-0023 D2) moved the relay
# out of the workflow: the two participants are persistent direct spawns the
# orchestrator wakes by agent ID, every turn and report is appended to the
# relay transcript file, and the workflow is the Record phase alone. The
# relay's own behavior — the transcript grammar, the end condition, the state
# the orchestrator reads — is fixed by tests/test-issue-179-relay-state.sh
# over scripts/architect/relay-state.sh; the Record workflow's control flow is
# fixed by test/workflows/run.mjs. What this suite holds are the STATICS that
# tie the pieces together:
#
#   1. the retired verdict machinery (issue #166) stays absent from the script;
#   2. the script's relay half is gone: no turn loop, no in-script report call,
#      no `brief` argument, and its two site keys are exactly the config's rows;
#   3. the two participants are governed by `phases` rows of the spawn policy
#      (architect-dev-participant / architect-test-participant) on the
#      `autoflow-planner` type, which is therefore no longer declared unmapped;
#   4. the participant prompt in `.claude/agents/autoflow-planner.md` carries
#      the relay contract: the transcript block grammar, the one-line return,
#      the VERIFY-scope sentence (ADR-0023 D1), and the no-authoring rule;
#   5. `spawn-policy.sh check` passes the shipped config and rejects a
#      malformed architect row.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
CONFIG="$PROJECT_ROOT/.claude/autoflow/spawn-policy.json"
RESOLVER="$PROJECT_ROOT/scripts/spawn-policy/spawn-policy.sh"
PLANNER="$PROJECT_ROOT/.claude/agents/autoflow-planner.md"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
# 1. The retired verdict machinery is gone from the script (issue #166).
# -----------------------------------------------------------------------------
echo "== statics: the retired verdict machinery is absent from the script =="

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

# -----------------------------------------------------------------------------
# 2. The relay half left the script (issue #179): it records, it does not discuss.
# -----------------------------------------------------------------------------
echo "== statics: the script is the Record phase only =="

relay_patterns=(
  "the turn schema (message + done)|'message', 'done'"
  "the two-consecutive-done loop predicate|prevDone"
  "a per-turn agent label|dev-t\\\$|test-t\\\$"
  "an in-script report call|dev-report|test-report"
  "the participant-missing sentinel|participant missing"
  "the report-missing sentinel|REASON_REPORT_MISSING"
  "a brief argument|argv\\.brief|From the orchestrator"
  "a dev-turn / test-turn site key|'dev-turn'|'test-turn'"
)
for row in "${relay_patterns[@]}"; do
  label="${row%%|*}"
  pattern="${row#*|}"
  if grep -qE "$pattern" "$WF"; then
    failc "statics: $label survives in $WF"
  else
    pass "statics: no $label in the script"
  fi
done
if grep -q "title: 'Record'" "$WF" && ! grep -q "title: 'Discuss'" "$WF" && ! grep -q "title: 'Report'" "$WF"; then
  pass "statics: meta.phases is Record alone"
else
  failc "statics: meta.phases is not Record alone"
fi
if grep -q 'architect-transcript\.md' "$WF" && grep -q '## Report — Developer AI' "$WF" && grep -q '## Report — Test AI' "$WF"; then
  pass "statics: the scribe is pointed at the relay transcript file and its two report sections"
else
  failc "statics: the scribe prompt does not name the transcript file and its report sections"
fi
if grep -qF "REASON_SCRIBE_MISSING = 'scribe missing'" "$WF"; then
  pass "statics: stop sentinel declared — REASON_SCRIBE_MISSING"
else
  failc "statics: stop sentinel missing — REASON_SCRIBE_MISSING"
fi

declared=$(sed -n '/site-keys:begin/,/site-keys:end/p' "$WF" | sed -n "s/^ *'\([^']*\)',$/\1/p" | sort)
rows=$(jq -r '.workflow_sites["architect-deliberation"] | keys[]' "$CONFIG" | sort)
expected=$(printf '%s\n' scribe ledger | sort)
if [ "$declared" = "$expected" ]; then
  pass "statics: the script declares exactly scribe / ledger"
else
  failc "statics: the script's declared site keys are [$(echo "$declared" | tr '\n' ' ')]"
fi
if [ "$rows" = "$expected" ]; then
  pass "statics: the config's architect-deliberation rows are exactly the two site keys"
else
  failc "statics: the config's architect-deliberation rows are [$(echo "$rows" | tr '\n' ' ')]"
fi
if jq -e 'has("deliberation_caps")' "$CONFIG" >/dev/null 2>&1; then
  failc "statics: the config still carries a deliberation_caps object"
else
  pass "statics: the config carries no deliberation_caps object"
fi

# -----------------------------------------------------------------------------
# 3. The participants are governed by phases rows on autoflow-planner.
# -----------------------------------------------------------------------------
echo "== statics: the relay participants' spawn-policy rows =="

for key in architect-dev-participant architect-test-participant; do
  t=$(jq -r --arg k "$key" '.phases[$k].agent_type // empty' "$CONFIG")
  if [ "$t" = "autoflow-planner" ] && jq -e --arg k "$key" '.phases[$k] | has("model") and has("effort")' "$CONFIG" >/dev/null 2>&1; then
    pass "statics: phases.$key names autoflow-planner with model and effort"
  else
    failc "statics: phases.$key is absent or does not name autoflow-planner (agent_type='$t')"
  fi
  if bash "$RESOLVER" model "$key" >/dev/null 2>&1; then
    pass "statics: spawn-policy.sh model $key resolves"
  else
    failc "statics: spawn-policy.sh model $key does not resolve"
  fi
done
if jq -e '.policy_unmapped_agent_types | has("autoflow-planner")' "$CONFIG" >/dev/null 2>&1; then
  failc "statics: autoflow-planner is still declared unmapped while phases rows name it"
else
  pass "statics: autoflow-planner is no longer declared unmapped"
fi
models=$(bash "$RESOLVER" models-for autoflow-planner 2>/dev/null | tr '\n' ' ')
if [ -n "$models" ]; then
  pass "statics: models-for autoflow-planner is non-empty ($models) — the hook advisory now governs the participants"
else
  failc "statics: models-for autoflow-planner is empty"
fi

# -----------------------------------------------------------------------------
# 4. The participant prompt carries the relay contract.
# -----------------------------------------------------------------------------
echo "== statics: the participant prompt (.claude/agents/autoflow-planner.md) =="

prompt_patterns=(
  "the relay-participant section|ARCHITECT relay participant"
  "the transcript block grammar|### Turn <n> — <Developer AI\\|Test AI> \\[further: <yes\\|none>\\]"
  "the one-line return|turn <n> — further: <yes\\|none>"
  "the VERIFY-scope sentence (ADR-0023 D1)|verified for both participants"
  "the no-authoring rule|do not create or edit any file other than the transcript block"
  "the append-only rule|never rewrite, reorder or delete"
  "the report section grammar|## Report — <Developer AI\\|Test AI>"
  "the foreground rule|never \`run_in_background\`"
)
for row in "${prompt_patterns[@]}"; do
  label="${row%%|*}"
  pattern="${row#*|}"
  if grep -qE -- "$pattern" "$PLANNER"; then
    pass "statics: the planner prompt carries $label"
  else
    failc "statics: the planner prompt lacks $label"
  fi
done
if cmp -s "$PLANNER" "$PROJECT_ROOT/plugin/autoflow/agents/autoflow-planner.md"; then
  pass "statics: the plugin copy of autoflow-planner.md is byte-identical"
else
  failc "statics: plugin/autoflow/agents/autoflow-planner.md differs from .claude/agents/autoflow-planner.md"
fi

# -----------------------------------------------------------------------------
# 5. spawn-policy.sh check over the architect rows.
# -----------------------------------------------------------------------------
echo "== statics: spawn-policy.sh check over the architect rows =="

if bash "$RESOLVER" check >/dev/null 2>&1; then
  pass "statics: the real config passes check"
else
  failc "statics: the real config fails check"
fi

SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/.claude/autoflow" "$SCRATCH/.claude/agents"
cp "$PROJECT_ROOT/.claude/agents/"*.md "$SCRATCH/.claude/agents/" 2>/dev/null
for key in scribe ledger; do
  jq --arg k "$key" 'del(.workflow_sites["architect-deliberation"][$k]["effort"])' "$CONFIG" \
    > "$SCRATCH/.claude/autoflow/spawn-policy.json"
  if AUTOFLOW_SPAWN_POLICY="$SCRATCH/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1; then
    failc "statics: check passed a config whose architect-deliberation.$key row carries no effort key"
  else
    pass "statics: check rejects an architect-deliberation.$key row carrying no effort key"
  fi
done
for key in architect-dev-participant architect-test-participant; do
  jq --arg k "$key" 'del(.phases[$k]["effort"])' "$CONFIG" > "$SCRATCH/.claude/autoflow/spawn-policy.json"
  if AUTOFLOW_SPAWN_POLICY="$SCRATCH/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1; then
    failc "statics: check passed a config whose phases.$key row carries no effort key"
  else
    pass "statics: check rejects a phases.$key row carrying no effort key"
  fi
done
# The partition rule: naming the type in a phases row AND declaring it unmapped is rejected.
jq '.policy_unmapped_agent_types["autoflow-planner"] = "stale"' "$CONFIG" > "$SCRATCH/.claude/autoflow/spawn-policy.json"
if AUTOFLOW_SPAWN_POLICY="$SCRATCH/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1; then
  failc "statics: check passed a config that both maps autoflow-planner and declares it unmapped"
else
  pass "statics: check rejects a config that both maps autoflow-planner and declares it unmapped"
fi
rm -rf "$SCRATCH"

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
