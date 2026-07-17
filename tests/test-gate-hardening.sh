#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: check-autoflow-gate.sh P1 (boundary matching) + P2 (unconditional deny)
# =============================================================================
# Verifies docs/gate-matching-standard.md:
#   P1 — gates match `cd x && git push` / chained forms, not only `^git push`
#   P2 — gh pr merge / default-branch push denied with NO/inactive state
#   blocked-by-review / blocked-by-subrepo — orchestrator removal of either gate
#     label denied (review gate = Codex reviewer's; merge-order gate = operator's),
#     label-name scoped across gh pr edit / gh issue edit / gh api DELETE;
#     unrelated label edits (status:in-progress) and other labels not blocked
#   spawn-model — Agent spawn without an explicit `model` denied regardless of
#     state (issue #475; CLAUDE.md > Spawn Model); research/evaluation included
#   no over-block — legit dev push + non-merge gh pr create allowed
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS=0
FAIL=0

# run_hook <expected_exit> <desc> <project_dir> <json>
run_hook() {
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
# agent_json carries an explicit model (default "sonnet") so the existing
# state-gate cases keep testing what they tested before the Section-1b
# model-declaration deny was added; the no-model form below exercises that deny.
agent_json() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s,"model":%s}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" "$(printf '%s' "${3:-sonnet}" | jq -Rs .)"; }
agent_json_nomodel() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)"; }
# team-spawn form: the role declaration travels in the teammate `name` prefix
# (impl-/test-/eval-/plan-/analysis-), not in subagent_type.
team_json() { printf '{"tool_name":"Agent","tool_input":{"team_name":"autoflow","name":%s,"prompt":%s,"model":"sonnet"}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)"; }
# mixed payload: team spawn carrying BOTH a name and a subagent_type (PR #506
# review) — the name prefix must decide; subagent_type must not be consulted.
team_json_subtype() { printf '{"tool_name":"Agent","tool_input":{"team_name":"autoflow","name":%s,"subagent_type":%s,"prompt":%s,"model":"sonnet"}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" "$(printf '%s' "$3" | jq -Rs .)"; }

# --- Fixtures ---------------------------------------------------------------
NOSTATE=$(mktemp -d)   # no .autoflow at all

ACTIVE=$(mktemp -d)    # active issue, empty audit/gate_quality scores
mkdir -p "$ACTIVE/.autoflow"
cat > "$ACTIVE/.autoflow/issue-9.json" <<'EOF'
{ "active": true, "issue": "#9",
  "phases": { "audit": {"scores":{}}, "gate_quality": {"scores":{}} } }
EOF

INACTIVE=$(mktemp -d)  # state present but active:false
mkdir -p "$INACTIVE/.autoflow"
cat > "$INACTIVE/.autoflow/issue-9.json" <<'EOF'
{ "active": false, "issue": "#9", "phases": {} }
EOF

PASSING=$(mktemp -d)   # active issue, every gate PASS (feat: hypothesis skipped)
mkdir -p "$PASSING/.autoflow"
cat > "$PASSING/.autoflow/issue-9.json" <<'EOF'
{ "active": true, "issue": "#9",
  "phases": {
    "gate_hypothesis_cause": {"verdict":"skipped (feat issue)"},
    "gate_plan":    {"scores":{"a":{"score":8},"b":{"score":8}}},
    "audit":        {"scores":{"a":{"score":8},"b":{"score":8}}},
    "gate_quality": {"scores":{"a":{"score":8},"b":{"score":8}}} } }
EOF

# issue #241 — active-state discovery must be JSON-semantic, not whitespace-textual.
# A valid active state file gates regardless of how `.active` is serialized; pre-fix
# the `grep -rl '"active": true'` locator matched only the one-space form, so a compact
# or space-before-colon active file silently bypassed every score gate.
ACTIVE_COMPACT=$(mktemp -d); mkdir -p "$ACTIVE_COMPACT/.autoflow"   # {"active":true} no space
printf '%s' '{"active":true,"issue":"#9","phases":{"audit":{"scores":{}},"gate_quality":{"scores":{}}}}' > "$ACTIVE_COMPACT/.autoflow/issue-9.json"
ACTIVE_SPACE=$(mktemp -d); mkdir -p "$ACTIVE_SPACE/.autoflow"       # {"active" : true} space before colon
printf '%s' '{"active" : true,"issue":"#9","phases":{"audit":{"scores":{}},"gate_quality":{"scores":{}}}}' > "$ACTIVE_SPACE/.autoflow/issue-9.json"

# issue #242 — corrupt (non-JSON) state file must FAIL CLOSED for gated commands,
# never silently skipped (jq -e '.active==true' returns non-zero for parse errors
# too; a truncated active file must not open the gate). A single malformed file:
MALFORMED=$(mktemp -d); mkdir -p "$MALFORMED/.autoflow"
printf '%s' '{"active": true, "issue":"#9", "phases":' > "$MALFORMED/.autoflow/issue-9.json"

# issue #242 — a non-numeric raw score makes check_scores' jq `tonumber` exit 5;
# the score gate must fail CLOSED (exit 2), never let set -e propagate the
# non-blocking exit 5. NONNUM_AUDIT trips the push/create gates (audit); NONNUM_PLAN
# trips the implementation-Agent gate (gate_plan), with verdict=skip so Gate-1 is bypassed.
NONNUM_AUDIT=$(mktemp -d); mkdir -p "$NONNUM_AUDIT/.autoflow"
printf '%s' '{"active":true,"issue":"#9","phases":{"audit":{"scores":{"a":{"score":"not-a-number"}}},"gate_quality":{"scores":{"a":{"score":8}}}}}' > "$NONNUM_AUDIT/.autoflow/issue-9.json"
NONNUM_PLAN=$(mktemp -d); mkdir -p "$NONNUM_PLAN/.autoflow"
printf '%s' '{"active":true,"issue":"#9","phases":{"gate_hypothesis_cause":{"verdict":"skipped (feat issue)"},"gate_plan":{"scores":{"a":{"score":"x"}}}}}' > "$NONNUM_PLAN/.autoflow/issue-9.json"

# issue #242 — jq is a stream parser; a valid state is EXACTLY ONE top-level JSON
# object. Two concatenated objects parse to "active\nactive" (not a parse error),
# and a non-object top-level (array/string) is also not a canonical state — both
# must fail closed rather than slip through as empty-state.
TWO_OBJ=$(mktemp -d); mkdir -p "$TWO_OBJ/.autoflow"
printf '%s\n%s' '{"active":true,"phases":{"audit":{"scores":{}},"gate_quality":{"scores":{}}}}' '{"active":true,"phases":{}}' > "$TWO_OBJ/.autoflow/issue-9.json"
NONOBJ=$(mktemp -d); mkdir -p "$NONOBJ/.autoflow"
printf '%s' '[{"active":true}]' > "$NONOBJ/.autoflow/issue-9.json"
EMPTYFILE=$(mktemp -d); mkdir -p "$EMPTYFILE/.autoflow"   # an empty state file is not a canonical object → fail closed
: > "$EMPTYFILE/.autoflow/issue-9.json"

# issue #242 — JSON-valid + single object + active, but a schema-corrupt `.phases`
# (a string, not an object). Downstream jq that indexes `.phases.*` errors → exit 5;
# gated paths must fail closed (git push via the score guard, Agent via the verdict guard).
SCHEMA_CORRUPT=$(mktemp -d); mkdir -p "$SCHEMA_CORRUPT/.autoflow"
printf '%s' '{"active":true,"phases":"corrupt-but-json-valid"}' > "$SCHEMA_CORRUPT/.autoflow/issue-9.json"

trap 'rm -rf "$NOSTATE" "$ACTIVE" "$INACTIVE" "$PASSING" "$ACTIVE_COMPACT" "$ACTIVE_SPACE" "$MALFORMED" "$NONNUM_AUDIT" "$NONNUM_PLAN" "$TWO_OBJ" "$NONOBJ" "$EMPTYFILE" "$SCHEMA_CORRUPT"' EXIT

echo "Spawn-model declaration — Agent without explicit model denied (state-independent, CLAUDE.md > Spawn Model)"
run_hook 2 "no-model implementation spawn, no state"     "$NOSTATE"  "$(agent_json_nomodel 'general-purpose' 'implement the fix and commit')"
run_hook 2 "no-model Explore spawn denied (no research exemption)" "$NOSTATE" "$(agent_json_nomodel 'Explore' 'search the repository')"
run_hook 2 "no-model evaluation spawn denied (no evaluation exemption)" "$NOSTATE" "$(agent_json_nomodel 'general-purpose' 'evaluation: score this plan against the rubric')"
run_hook 2 "deny holds with inactive state"              "$INACTIVE" "$(agent_json_nomodel 'general-purpose' 'plan the design approach')"
run_hook 2 "deny holds with passing scores"              "$PASSING"  "$(agent_json_nomodel 'general-purpose' 'implement the fix and commit')"
run_hook 0 "model-declared Explore allowed"              "$NOSTATE"  "$(agent_json 'Explore' 'search the repository')"
run_hook 0 "model-declared evaluation spawn allowed"     "$NOSTATE"  "$(agent_json 'general-purpose' 'evaluation: score this plan against the rubric' 'opus')"

echo "P2 — unconditional deny holds with NO state file"
run_hook 2 "gh pr merge"                "$NOSTATE" "$(bash_json 'gh pr merge 9 --squash')"
run_hook 2 "chained gh pr merge"        "$NOSTATE" "$(bash_json 'foo && gh pr merge 9')"
run_hook 2 "cd && push to main"         "$NOSTATE" "$(bash_json 'cd /x && git push origin main')"
run_hook 2 "git push -u origin main"    "$NOSTATE" "$(bash_json 'git push -u origin main')"

echo "P2 — deny holds even when state is inactive (active:false)"
run_hook 2 "gh pr merge w/ inactive state" "$INACTIVE" "$(bash_json 'gh pr merge 9')"

echo "No over-block — legit forms allowed (no active state)"
run_hook 0 "git push dev branch"        "$NOSTATE" "$(bash_json 'git push -u origin dev/2026-05-15')"
run_hook 0 "cd && gh pr create"         "$NOSTATE" "$(bash_json 'cd /x && gh pr create -t t -b b')"
run_hook 0 "plain git status"           "$NOSTATE" "$(bash_json 'git status')"

echo "Issue #3 (D2) — default-branch push segmentation (.autoflow/issue-3-verification-design.md §1 AC-2a..2g,2j)"
# All arms below are state-independent (Section 1, before the activity check)
# and pin CLAUDE_PROJECT_DIR to $NOSTATE (no origin/HEAD) so DEFAULT_BRANCH
# falls back to 'main' deterministically (gate:106).
AC2A_CMD=$'git checkout main && git pull --ff-only origin main\ngit branch -d dev/x\ngit push origin --delete dev/x'
run_hook 0 "AC-2a: compound cleanup (checkout+pull, branch -d, push --delete) allowed" \
  "$NOSTATE" "$(bash_json "$AC2A_CMD")"
run_hook 2 "AC-2b: bare 'git push origin main' denied" \
  "$NOSTATE" "$(bash_json 'git push origin main')"
run_hook 2 "AC-2c: same-segment compound 'cd x && git push origin main' denied" \
  "$NOSTATE" "$(bash_json 'cd x && git push origin main')"
run_hook 2 "AC-2d: alternate refspec 'git push origin HEAD:main' denied" \
  "$NOSTATE" "$(bash_json 'git push origin HEAD:main')"
run_hook 2 "AC-2d: alternate refspec 'git push origin :main' denied" \
  "$NOSTATE" "$(bash_json 'git push origin :main')"
run_hook 0 "AC-2e: delete-refspec safeguard 'git push origin --delete dev/x' allowed" \
  "$NOSTATE" "$(bash_json 'git push origin --delete dev/x')"
run_hook 0 "AC-2f: cross-segment false-negative guard (unrelated 'origin main' mention + push dev/x) allowed" \
  "$NOSTATE" "$(bash_json 'echo origin main && git push origin dev/x')"

echo "AC-2g: copy parity — plugin/autoflow/hooks and .claude/hooks copies are byte-identical"
if diff -q "$PROJECT_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh" "$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh" >/dev/null 2>&1; then
  echo "  PASS: AC-2g: hook copies byte-identical"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-2g: hook copies differ (plugin/autoflow/hooks vs .claude/hooks)"
  FAIL=$((FAIL + 1))
fi

echo "AC-2j: label-gate untouched — existing blocked-by-review/blocked-by-subrepo true-positive arms stay green (regression guard)"
run_hook 2 "AC-2j: gh pr edit --remove-label blocked-by-review still denied" \
  "$NOSTATE" "$(bash_json 'gh pr edit 9 --remove-label blocked-by-review')"
run_hook 2 "AC-2j: gh api -X DELETE .../labels/blocked-by-subrepo still denied" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-subrepo -X DELETE')"

echo "P1 — boundary match fires score gate on chained forms (active, empty scores)"
run_hook 2 "cd && git push (Gate 3)"    "$ACTIVE"  "$(bash_json 'cd /x && git push -u origin dev/x')"
run_hook 2 "a && gh pr create (Gate 4)" "$ACTIVE"  "$(bash_json 'true && gh pr create -t t')"

echo "No over-block — gates pass when scores PASS (active)"
run_hook 0 "dev push w/ passing scores" "$PASSING" "$(bash_json 'cd /x && git push -u origin dev/x')"
run_hook 0 "gh pr create w/ passing"    "$PASSING" "$(bash_json 'gh pr create -t t -b b')"

echo "Heredoc / body false-positive refinement (must NOT over-block)"
run_hook 0 "inline --body quotes merge token" "$NOSTATE" \
  "$(bash_json 'gh pr create -t t --body "see `gh pr merge` rule"')"
HEREDOC_CMD=$'gh pr create -t t --body "$(cat <<\'X\'\nthe agent never runs `gh pr merge`\n&& git push origin main is denied\nX\n)"'
run_hook 0 "heredoc body mentions merge+main" "$NOSTATE" "$(bash_json "$HEREDOC_CMD")"
run_hook 0 "git commit body quotes merge"     "$NOSTATE" \
  "$(bash_json 'git commit -m "doc: forbid `gh pr merge`"')"

echo "Refinement preserves real chained command after a body arg"
run_hook 2 "create --body then real && merge"  "$NOSTATE" \
  "$(bash_json 'gh pr create --body "x" && gh pr merge 1')"

echo "blocked-by-review — orchestrator removal denied (label-name scoped); reviewer & other paths preserved"
run_hook 2 "gh pr edit --remove-label blocked-by-review"           "$NOSTATE"  "$(bash_json 'gh pr edit 9 --remove-label blocked-by-review')"
run_hook 2 "gh issue edit --remove-label blocked-by-review"        "$NOSTATE"  "$(bash_json 'gh issue edit 9 --remove-label blocked-by-review')"
run_hook 2 "--remove-label=blocked-by-review (= form)"             "$NOSTATE"  "$(bash_json 'gh pr edit 9 --remove-label=blocked-by-review')"
run_hook 2 "gh api -X DELETE .../labels/blocked-by-review"         "$NOSTATE"  "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-review -X DELETE')"
run_hook 2 "deny holds even with inactive state"                   "$INACTIVE" "$(bash_json 'gh issue edit 9 --remove-label blocked-by-review')"
run_hook 0 "step-7 gh issue edit --remove-label status:in-progress allowed" "$NOSTATE" "$(bash_json 'gh issue edit 9 --remove-label status:in-progress')"
run_hook 0 "no co-occurrence FP: add-label && unrelated status removal"     "$NOSTATE" "$(bash_json 'gh pr edit 9 --add-label foo && gh issue edit 9 --remove-label status:in-progress')"
run_hook 0 "create-host-pr attach (gh pr create --label) allowed"           "$NOSTATE" "$(bash_json 'gh pr create --draft --label blocked-by-review')"
run_hook 0 "removing a different PR label allowed (scoped to the gate label)" "$NOSTATE" "$(bash_json 'gh pr edit 9 --remove-label wip')"
run_hook 0 "comment body mentioning the deny token not over-blocked (SCAN strip)" "$NOSTATE" \
  "$(bash_json 'gh pr comment 9 --body "later: gh pr edit 9 --remove-label blocked-by-review"')"

echo "blocked-by-subrepo — orchestrator removal denied (operator-owned merge-order gate); label-name scoped, same as blocked-by-review"
run_hook 2 "gh pr edit --remove-label blocked-by-subrepo"          "$NOSTATE"  "$(bash_json 'gh pr edit 9 --remove-label blocked-by-subrepo')"
run_hook 2 "gh issue edit --remove-label blocked-by-subrepo"       "$NOSTATE"  "$(bash_json 'gh issue edit 9 --remove-label blocked-by-subrepo')"
run_hook 2 "--remove-label=blocked-by-subrepo (= form)"            "$NOSTATE"  "$(bash_json 'gh pr edit 9 --remove-label=blocked-by-subrepo')"
run_hook 2 "gh api -X DELETE .../labels/blocked-by-subrepo"        "$NOSTATE"  "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-subrepo -X DELETE')"
run_hook 2 "blocked-by-subrepo deny holds even with inactive state" "$INACTIVE" "$(bash_json 'gh issue edit 9 --remove-label blocked-by-subrepo')"

echo "#241 — active-state discovery is serialization-independent (JSON-semantic, not whitespace grep)"
run_hook 2 "compact {\"active\":true} + empty scores → git push blocked" \
  "$ACTIVE_COMPACT" "$(bash_json 'git push origin dev/x')"
run_hook 2 "compact active + empty scores → gh pr create blocked" \
  "$ACTIVE_COMPACT" "$(bash_json 'gh pr create -t t -b b')"
run_hook 2 "space-before-colon {\"active\" : true} + empty scores → git push blocked" \
  "$ACTIVE_SPACE" "$(bash_json 'git push origin dev/x')"

echo "#242 — corrupt state file fails CLOSED for gated commands, without deadlocking the rest"
run_hook 2 "malformed-only state → git push blocked (fail-closed)" \
  "$MALFORMED" "$(bash_json 'git push origin dev/x')"
run_hook 2 "malformed-only state → gh pr create blocked (fail-closed)" \
  "$MALFORMED" "$(bash_json 'gh pr create -t t -b b')"
run_hook 0 "malformed-only state → non-gated git status allowed (no recovery deadlock)" \
  "$MALFORMED" "$(bash_json 'git status')"
run_hook 2 "malformed-only state → declared implementer blocked (fail-closed)" \
  "$MALFORMED" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
run_hook 2 "malformed-only state → undeclared general-purpose blocked (fail-closed)" \
  "$MALFORMED" "$(agent_json 'general-purpose' 'summarize the issue thread')"
run_hook 0 "malformed-only state → Explore agent allowed (research never gates)" \
  "$MALFORMED" "$(agent_json 'Explore' 'search the repository')"
run_hook 0 "malformed-only state → declared evaluator allowed (evaluation must stay spawnable)" \
  "$MALFORMED" "$(agent_json 'autoflow-evaluator' 'score this plan against the rubric')"
run_hook 2 "malformed-only state → evaluation KEYWORD alone no longer bypasses (declaration required)" \
  "$MALFORMED" "$(agent_json 'general-purpose' 'evaluation: score this plan against the rubric')"

echo "#242 — JSON-valid but schema-corrupt state (.phases not an object) fails closed for gated paths"
run_hook 2 "schema-corrupt .phases → git push blocked (score-guard fail-closed)" \
  "$SCHEMA_CORRUPT" "$(bash_json 'git push origin dev/x')"
run_hook 2 "schema-corrupt .phases → declared planner blocked (verdict-guard fail-closed)" \
  "$SCHEMA_CORRUPT" "$(agent_json 'autoflow-planner' 'synthesize the plan')"
run_hook 2 "schema-corrupt .phases → declared implementer blocked (verdict-guard fail-closed)" \
  "$SCHEMA_CORRUPT" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
run_hook 0 "schema-corrupt .phases → Explore agent allowed (research bypasses before verdict read)" \
  "$SCHEMA_CORRUPT" "$(agent_json 'Explore' 'search the repository')"

echo "#242 — only a single top-level JSON object is a canonical state; streams/non-objects fail closed"
run_hook 2 "two concatenated active objects → git push blocked (fail-closed)" \
  "$TWO_OBJ" "$(bash_json 'git push origin dev/x')"
run_hook 2 "two concatenated active objects → declared implementer blocked" \
  "$TWO_OBJ" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
run_hook 2 "top-level JSON array (non-object) → git push blocked (fail-closed)" \
  "$NONOBJ" "$(bash_json 'git push origin dev/x')"
run_hook 2 "empty state file → git push blocked (fail-closed)" \
  "$EMPTYFILE" "$(bash_json 'git push origin dev/x')"
run_hook 0 "empty state file → non-gated git status allowed (no deadlock)" \
  "$EMPTYFILE" "$(bash_json 'git status')"

echo "#242 — non-numeric raw score fails CLOSED (jq tonumber error must not leak a non-blocking exit 5)"
run_hook 2 "non-numeric audit score → git push blocked (fail-closed)" \
  "$NONNUM_AUDIT" "$(bash_json 'git push origin dev/x')"
run_hook 2 "non-numeric audit score → gh pr create blocked (fail-closed)" \
  "$NONNUM_AUDIT" "$(bash_json 'gh pr create -t t -b b')"
run_hook 2 "non-numeric gate_plan score → declared implementer blocked (fail-closed)" \
  "$NONNUM_PLAN" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"

echo "Spawn-role declaration — gate class comes from the declared role, never from prompt keywords"
# Old bypass closed: a keyword-free implementation prompt is still gated (role is structural).
run_hook 2 "declared implementer, keyword-free prompt → gate_plan gate fires (empty scores)" \
  "$ACTIVE" "$(agent_json 'autoflow-implementer' 'satisfy the acceptance criteria in the sub-repo')"
run_hook 2 "declared tester → gate_plan gate fires (empty scores)" \
  "$ACTIVE" "$(agent_json 'autoflow-tester' 'author the acceptance checks')"
# Old false positive closed: an analysis spawn whose prompt mentions fix/design/수정 is NOT gated.
run_hook 0 "declared analyzer with keyword-heavy prompt → allowed (no prompt inference)" \
  "$ACTIVE" "$(agent_json 'autoflow-analyzer' 'analyze the fix scope, 수정 범위와 design impact를 정리')"
run_hook 0 "declared evaluator → allowed (never score-gated)" \
  "$ACTIVE" "$(agent_json 'autoflow-evaluator' 'score the plan rubric')"
# Undeclared spawn during an active cycle fails LOUDLY.
run_hook 2 "undeclared general-purpose during active cycle → blocked" \
  "$ACTIVE" "$(agent_json 'general-purpose' 'summarize the issue thread')"
# Keyword evasion no longer helps: evaluation keyword in an undeclared prompt does not exempt.
run_hook 2 "undeclared spawn with evaluation keyword → still blocked" \
  "$ACTIVE" "$(agent_json 'general-purpose' 'implement and also evaluate the result')"
# Declared roles pass once their gate passes.
run_hook 0 "declared implementer w/ passing gate_plan → allowed" \
  "$PASSING" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
run_hook 0 "declared planner w/ hypothesis verdict skipped (feat) → allowed" \
  "$PASSING" "$(agent_json 'autoflow-planner' 'synthesize the plan')"
# Team-spawn form: the role declaration travels in the teammate name prefix.
run_hook 2 "team spawn name=impl-librechat → gate_plan gate fires (empty scores)" \
  "$ACTIVE" "$(team_json 'impl-librechat' 'satisfy the acceptance criteria')"
run_hook 2 "team spawn name=test-librechat → gate_plan gate fires (empty scores)" \
  "$ACTIVE" "$(team_json 'test-librechat' 'author the acceptance checks')"
run_hook 0 "team spawn name=eval-quality → allowed (evaluation role)" \
  "$ACTIVE" "$(team_json 'eval-quality' 'score the completion rubric')"
run_hook 2 "team spawn undeclared name → blocked" \
  "$ACTIVE" "$(team_json 'librechat-helper' 'assist with the task')"
# Mixed payload (PR #506 review, Medium): on a team spawn the name prefix decides;
# a research/autoflow-* subagent_type riding along must not override or exempt it.
run_hook 2 "mixed: subagent_type=Explore + name=impl-librechat → gate_plan fires (name wins)" \
  "$ACTIVE" "$(team_json_subtype 'impl-librechat' 'Explore' 'satisfy the acceptance criteria')"
run_hook 2 "mixed: subagent_type=Explore + name=test-librechat → gate_plan fires (name wins)" \
  "$ACTIVE" "$(team_json_subtype 'test-librechat' 'Explore' 'author the acceptance checks')"
run_hook 2 "mixed: subagent_type=autoflow-evaluator + name=impl-x → gate_plan fires (name wins)" \
  "$ACTIVE" "$(team_json_subtype 'impl-x' 'autoflow-evaluator' 'satisfy the acceptance criteria')"
run_hook 2 "mixed: subagent_type=Explore + undeclared name → blocked (contradiction not arbitrated)" \
  "$ACTIVE" "$(team_json_subtype 'librechat-helper' 'Explore' 'assist with the task')"
run_hook 0 "mixed: subagent_type=Explore + name=eval-quality → allowed (name wins, evaluation)" \
  "$ACTIVE" "$(team_json_subtype 'eval-quality' 'Explore' 'score the completion rubric')"
# No over-block outside a cycle: with no state file, undeclared spawns stay allowed.
run_hook 0 "undeclared general-purpose with NO state → allowed (pre-PREFLIGHT)" \
  "$NOSTATE" "$(agent_json 'general-purpose' 'summarize the issue thread')"
run_hook 0 "undeclared general-purpose with inactive state → allowed" \
  "$INACTIVE" "$(agent_json 'general-purpose' 'summarize the issue thread')"

echo "#11 — plugin-namespaced subagent_type (<plugin>:<agent>) resolves via resolve_spawn_role()"
# AC1 — namespaced form must resolve to the same role as its bare sibling.
# 0-flip discriminating oracles (verification-design AC1): the $ACTIVE→2 cases
# below are NOT self-distinguishing on exit code alone (an undeclared
# fall-through also exits 2), so each of the five widened arms additionally
# gets a case that flips 2→0 across the fix — analyzer/evaluator on $ACTIVE
# (never gated), implementer/tester/planner on $PASSING (gate already passing).
run_hook 0 "namespaced analyzer → allowed (analysis, never gated)" \
  "$ACTIVE" "$(agent_json 'autoflow:autoflow-analyzer' 'analyze the issue scope')"
run_hook 0 "namespaced evaluator → allowed (evaluation, never gated)" \
  "$ACTIVE" "$(agent_json 'autoflow:autoflow-evaluator' 'score the plan rubric')"
run_hook 2 "namespaced implementer → gate_plan fires (empty scores)" \
  "$ACTIVE" "$(agent_json 'autoflow:autoflow-implementer' 'make the failing tests pass')"
run_hook 2 "namespaced tester → gate_plan fires (empty scores)" \
  "$ACTIVE" "$(agent_json 'autoflow:autoflow-tester' 'author the acceptance checks')"
# NOTE: unlike implementer/tester, the planning gate only fires when
# gate_hypothesis_cause.verdict is present and does not contain "skip" (bug
# issues). $ACTIVE carries no gate_hypothesis_cause key at all, so VERDICT
# reads empty and the gate does NOT fire — bare `autoflow-planner` on $ACTIVE
# exits 0 too (no $ACTIVE arm exists for the bare planner above, for the same
# reason). The truthful, still-discriminating case mirrors the bare planner's
# existing SCHEMA_CORRUPT coverage (line ~251-252): a corrupt `.phases` makes
# the verdict read fail and the planning branch fails closed (exit 2).
run_hook 2 "namespaced planner, schema-corrupt state → blocked (verdict-guard fail-closed)" \
  "$SCHEMA_CORRUPT" "$(agent_json 'autoflow:autoflow-planner' 'synthesize the plan')"
# 0-flip mirrors on $PASSING — canonical RED oracles per verification design:
# pre-fix these fall through to undeclared → exit 2; post-fix the gate has
# already passed → exit 0. A typo in one widened arm would still satisfy the
# $ACTIVE→2 assertions above (undeclared also → 2) but fails here.
run_hook 0 "namespaced implementer w/ passing gate_plan → allowed" \
  "$PASSING" "$(agent_json 'autoflow:autoflow-implementer' 'make the failing tests pass')"
run_hook 0 "namespaced tester w/ passing gate_plan → allowed" \
  "$PASSING" "$(agent_json 'autoflow:autoflow-tester' 'author the acceptance checks')"
run_hook 0 "namespaced planner w/ skip-verdict (feat) → allowed" \
  "$PASSING" "$(agent_json 'autoflow:autoflow-planner' 'synthesize the plan')"

# AC1 second-consumer path — is_score_gated_surface() also calls
# resolve_spawn_role() (the corrupt/multi-active fail-closed branch, mirrors
# the bare autoflow-evaluator/$MALFORMED case at line 244). 0-flip oracle:
# pre-fix namespaced value falls through to _role="" → fail-closed deny → 2;
# post-fix → evaluation → exempt → 0. Proves the fix reaches BOTH call sites.
run_hook 0 "namespaced evaluator under malformed state → stays spawnable (fail-closed path)" \
  "$MALFORMED" "$(agent_json 'autoflow:autoflow-evaluator' 'score this plan against the rubric')"
# Defense-in-depth (optional per verification design): same fixture family,
# mirrors the bare research-only coverage at $SCHEMA_CORRUPT (line 256).
run_hook 0 "namespaced evaluator under schema-corrupt state → stays spawnable (fail-closed path)" \
  "$SCHEMA_CORRUPT" "$(agent_json 'autoflow:autoflow-evaluator' 'score this plan against the rubric')"

echo "#11 — AC3: research built-ins stay bare-only (no accidental widening by the fix)"
# Load-bearing caveat: this fails if the fix normalizes the plugin prefix
# BEFORE the whole case (a blanket strip), which would also admit a
# namespaced research spelling. It constrains the fix to a scoped,
# per-autoflow-arm dual-pattern (feature-design §1).
run_hook 2 "namespaced Explore does NOT resolve to research → blocked" \
  "$ACTIVE" "$(agent_json 'foo:Explore' 'search the repository')"
run_hook 0 "bare Explore → research allowed (guard both directions)" \
  "$ACTIVE" "$(agent_json 'Explore' 'search the repository')"

# AC4 (byte-identical hook copies) is already covered by the existing AC-2g
# diff check above (line ~167); it stays green pre-fix by design (the two
# copies are already byte-identical) and fails the instant GREEN edits only
# one copy. No duplicate case added here.

echo "#242 — gate decisions use the in-memory snapshot; the state file is never re-read (no TOCTOU)"
REREAD=$(grep -cE 'jq[^|]*"\$STATE_FILE"' "$HOOK" 2>/dev/null || true)
if [ "${REREAD:-0}" -eq 0 ]; then
  echo "  PASS: hook performs no jq re-read of \$STATE_FILE from disk (reads STATE_JSON snapshot)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: hook re-reads \$STATE_FILE from disk ${REREAD}x — reintroduces the multi-read TOCTOU; pipe STATE_JSON instead"
  FAIL=$((FAIL + 1))
fi

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
