#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh plugin/autoflow/hooks/check-autoflow-gate.sh .claude/settings.json plugin/autoflow/hooks/hooks.json CLAUDE.md docs/teammate-common-rules.md docs/gate-matching-standard.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #165 — the TaskOutput blocking wait is denied at the tool
#       boundary, state-independently, and the wait discipline is documented.
# =============================================================================
# Origin: connev-llm/llmroute #595 session measurement (2026-09-02): 77
# TaskOutput(block:true) calls, 6h33m of an 8h01m session spent inside the
# block, other tasks' completion notifications and one user prompt queued
# behind it, two agent-timeout transcript dumps (16-27K tokens) read as
# progress evidence. Root gap: the methodology named no wait primitive.
#
# Harness idiom: printf json | CLAUDE_PROJECT_DIR=$tmp bash $HOOK, per
# tests/test-issue-245-schema-validation.sh:53. Fixtures live in a hermetic
# mktemp -d, never the repo's live .autoflow/ (tests/test-issue-18-fixture-
# glob-isolation.sh precedent).
#
# Cases:
#   T-DENY-NOSTATE   TaskOutput denied with no state file at all (P2: before
#                    the activity check)
#   T-DENY-ACTIVE    denied under an active:true state file
#   T-DENY-INACTIVE  denied under an active:false state file
#   T-DENY-NOARGS    denied with an empty tool_input (tool-name keyed, no
#                    argument condition)
#   T-GUIDANCE       the deny text names the CLAUDE.md anchor the operator
#                    reads for the replacement (turn end + task notification)
#   T-NO-OVERBLOCK   a Bash command merely mentioning the token is not denied
#   T-MATCHER-ROOT   .claude/settings.json routes TaskOutput to the hook — a
#                    P2 deny the matcher does not route is a deny that never runs
#   T-MATCHER-PLUGIN plugin/autoflow/hooks/hooks.json routes it identically
#   T-PLUGIN-PARITY  the plugin hook copy is byte-identical to the root hook
#   T-DOC-CLAUDE     CLAUDE.md carries the Wait discipline rule and the hook-gate
#                    row for TaskOutput
#   T-DOC-COMMON     docs/teammate-common-rules.md > Bash Execution Mode states
#                    the orchestrator's side of the wait
#   T-DOC-P2         docs/gate-matching-standard.md > Rule P2 lists the deny
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
PLUGIN_HOOK="$PROJECT_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh"
ROOT_SETTINGS="$PROJECT_ROOT/.claude/settings.json"
PLUGIN_HOOKS_JSON="$PROJECT_ROOT/plugin/autoflow/hooks/hooks.json"

PASS=0
FAIL=0

run_hook() {                  # run_hook <expected_exit> <desc> <project_dir> <json>
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (exit $actual)"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1))
  fi
}

hook_stderr() {                # hook_stderr <project_dir> <json> -> stderr on stdout
  { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" >/dev/null; } 2>&1
}

check() {                      # check <desc> <condition-exit>
  if [[ "$2" -eq 0 ]]; then
    echo "  PASS: $1"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"; FAIL=$((FAIL + 1))
  fi
}

TASKOUT_JSON='{"tool_name":"TaskOutput","tool_input":{"task_id":"abc123","block":true,"timeout":600000}}'
TASKOUT_EMPTY='{"tool_name":"TaskOutput","tool_input":{}}'
bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }

TMP_NOSTATE=$(mktemp -d); mkdir -p "$TMP_NOSTATE/.autoflow"
TMP_ACTIVE=$(mktemp -d);  mkdir -p "$TMP_ACTIVE/.autoflow"
TMP_INACTIVE=$(mktemp -d); mkdir -p "$TMP_INACTIVE/.autoflow"
trap 'rm -rf "$TMP_NOSTATE" "$TMP_ACTIVE" "$TMP_INACTIVE"' EXIT

cat > "$TMP_ACTIVE/.autoflow/issue-165.json" <<'JSON'
{"active":true,"issue":"#165","title":"t","date":"2026-09-03","cycle":1,"mode":"new-issue","phase":"in-progress",
 "phases":{"gate_hypothesis_structure":{"evaluator":"","scores":{}},
           "gate_hypothesis_cause":{"evaluator":"","scores":{},"verdict":"pending"},
           "gate_plan":{"evaluator":"","scores":{}},"audit":{"evaluator":"","scores":{}},
           "gate_quality":{"evaluator":"","scores":{}}}}
JSON
sed 's/"active":true/"active":false/; s/"in-progress"/"awaiting-external-review"/' \
  "$TMP_ACTIVE/.autoflow/issue-165.json" > "$TMP_INACTIVE/.autoflow/issue-165.json"

echo "== T-DENY: TaskOutput is denied regardless of state =="
run_hook 2 "T-DENY-NOSTATE: no state file"           "$TMP_NOSTATE"  "$TASKOUT_JSON"
run_hook 2 "T-DENY-ACTIVE: active:true state file"   "$TMP_ACTIVE"   "$TASKOUT_JSON"
run_hook 2 "T-DENY-INACTIVE: active:false state file" "$TMP_INACTIVE" "$TASKOUT_JSON"
run_hook 2 "T-DENY-NOARGS: empty tool_input"          "$TMP_NOSTATE"  "$TASKOUT_EMPTY"

echo "== T-GUIDANCE: the deny points at the replacement =="
ERR=$(hook_stderr "$TMP_NOSTATE" "$TASKOUT_JSON")
printf '%s' "$ERR" | grep -q "BLOCKED: 'TaskOutput'";                    check "T-GUIDANCE: BLOCKED line names TaskOutput" $?
printf '%s' "$ERR" | grep -q "Wait discipline";                           check "T-GUIDANCE: names the CLAUDE.md anchor (Wait discipline)" $?
printf '%s' "$ERR" | grep -qi "task notification";                        check "T-GUIDANCE: names the replacement (task notification)" $?

echo "== T-NO-OVERBLOCK: a Bash mention of the token is not a TaskOutput call =="
run_hook 0 "T-NO-OVERBLOCK: echo TaskOutput"                    "$TMP_NOSTATE" "$(bash_json 'echo TaskOutput')"
run_hook 0 "T-NO-OVERBLOCK: grep -rn TaskOutput docs/"          "$TMP_ACTIVE"  "$(bash_json 'grep -rn TaskOutput docs/')"

echo "== T-MATCHER: the hook is routed the TaskOutput tool =="
ROOT_M=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$ROOT_SETTINGS")
PLUG_M=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$PLUGIN_HOOKS_JSON")
printf '%s' "$ROOT_M" | grep -qE '(^|\|)TaskOutput(\||$)'; check "T-MATCHER-ROOT: .claude/settings.json PreToolUse matcher lists TaskOutput (=$ROOT_M)" $?
printf '%s' "$PLUG_M" | grep -qE '(^|\|)TaskOutput(\||$)'; check "T-MATCHER-PLUGIN: plugin hooks.json PreToolUse matcher lists TaskOutput (=$PLUG_M)" $?
[[ "$ROOT_M" == "$PLUG_M" ]];                              check "T-MATCHER-PARITY: root and plugin matchers are identical" $?

echo "== T-PLUGIN-PARITY: plugin hook copy is byte-identical =="
cmp -s "$HOOK" "$PLUGIN_HOOK"; check "T-PLUGIN-PARITY: plugin/autoflow/hooks/check-autoflow-gate.sh == .claude/hooks/check-autoflow-gate.sh" $?

echo "== T-DOC: the wait discipline is documented where the hook message points =="
grep -q '^\- \*\*\[MUST\] Wait discipline (orchestrator)\*\*' "$PROJECT_ROOT/CLAUDE.md"; check "T-DOC-CLAUDE: Execution Principles carries the [MUST] Wait discipline bullet" $?
grep -q '`TaskOutput` (any call) → \*\*denied state-independently\*\*' "$PROJECT_ROOT/CLAUDE.md"; check "T-DOC-CLAUDE: Hook gates list carries the TaskOutput row" $?
grep -q "The orchestrator's side of the wait (issue #165)" "$PROJECT_ROOT/docs/teammate-common-rules.md"; check "T-DOC-COMMON: Bash Execution Mode states the orchestrator's side of the wait" $?
grep -q 'TaskOutput` blocking wait, issue #165' "$PROJECT_ROOT/docs/gate-matching-standard.md"; check "T-DOC-P2: Rule P2 lists the TaskOutput deny" $?

echo
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
